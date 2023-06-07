terraform {
    # backend "local" {}
    # If you want to save state in Terraform Cloud:
    # Configure these env vars, uncomment cloud {} 
    # and comment out backend "local" {}
    #   TF_CLOUD_ORGANIZATION
    #   TF_WORKSPACE
    cloud {}
    required_providers {
        kubectl = {
            source  = "gavinbunney/kubectl"
            version = "~> 1.14"
        }
        helm = {
            source  = "hashicorp/helm"
            version = "~> 2.10"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = "~> 2.21"
        }
        digitalocean = {
            source = "digitalocean/digitalocean"
            version = "~> 2.27"
        }
        http = {
            source = "hashicorp/http"
            version = "~> 3.3"
        }
    }
}

provider "digitalocean" {
    token = var.DO_TOKEN
}

provider "helm" {
    repository_config_path = "${path.root}/.helm/repositories.yaml" 
    repository_cache       = "${path.root}/.helm"
    kubernetes {
        host                   = digitalocean_kubernetes_cluster.zrok_cluster.endpoint
        token                  = digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].token
        cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].cluster_ca_certificate)
    }
}

provider "kubernetes" {
    host                   = digitalocean_kubernetes_cluster.zrok_cluster.endpoint
    token                  = digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].cluster_ca_certificate)
}

provider "kubectl" {     # duplcates config of provider "kubernetes" for cert-manager module
    host                   = digitalocean_kubernetes_cluster.zrok_cluster.endpoint
    token                  = digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].cluster_ca_certificate)
    load_config_file       = false
}

resource "digitalocean_kubernetes_cluster" "zrok_cluster" {
    name        = var.cluster_name
    version = var.k8s_version
    region      = var.region
    tags        = var.tags

    node_pool {
        name       = "worker-pool"
        size       = "s-2vcpu-2gb"
        auto_scale = true
        min_nodes  = 1
        max_nodes  = 3
    }
}

resource "kubernetes_secret" "digitalocean_token" {
    type = "Opaque"
    metadata {
        name      = "digitalocean-dns"
        namespace = var.zrok_namespace
    }
    data = {
        token = var.DO_TOKEN
    }
    lifecycle {
        ignore_changes = [
            metadata[0].annotations
        ]
    }
}

# Install ingress-nginx in advance, instead of as a sub-chart of the Ziti
# controller, to get the external IP of the load balancer that is created by DO
# for the ingress-nginx controller service. We'll use the IP to create the
# wildcard DNS record for the cluster.
resource "helm_release" "ingress_nginx" {
    name             = "ingress-nginx"
    version          = "<5"
    namespace        = var.zrok_namespace
    create_namespace = true
    repository       = "https://kubernetes.github.io/ingress-nginx"
    chart            = "ingress-nginx"
    values           = [yamlencode({
        controller = {
            extraArgs = {
                enable-ssl-passthrough = "true"
            }
        }
    })]
}

# find the external IP of the Nodebalancer provisioned for ingress-nginx
data "kubernetes_service" "ingress_nginx_controller" {
    depends_on   = [helm_release.ingress_nginx]
    metadata {
        name = "ingress-nginx-controller"
        namespace = var.zrok_namespace
    }
}

resource "digitalocean_domain" "cluster_zone" {
    name = var.dns_zone
}

resource "digitalocean_record" "wildcard_record" {
    domain    = digitalocean_domain.cluster_zone.id
    name      = "*"
    type      = "A"
    value     = data.kubernetes_service.ingress_nginx_controller.status.0.load_balancer.0.ingress.0.ip
    ttl       = var.wildcard_ttl_sec
}

resource "terraform_data" "wait_for_dns" {
    depends_on = [digitalocean_record.wildcard_record]
    triggers_replace = [
        var.dns_zone,
        data.kubernetes_service.ingress_nginx_controller.status.0.load_balancer.0.ingress.0.ip
    ]
    provisioner "local-exec" {
        interpreter = [ "bash", "-c" ]
        command = <<-EOF
            set -euo pipefail
            # download a portable binary for resolving DNS records
            wget -q https://github.com/ameshkov/dnslookup/releases/download/v1.9.1/dnslookup-linux-amd64-v1.9.1.tar.gz
            tar -xzf dnslookup-linux-amd64-v1.9.1.tar.gz
            cd ./linux-amd64/
            ./dnslookup --version >/dev/null
            NOW=$(date +%s)
            END=$(($NOW + 310))
            EXPECTED=${data.kubernetes_service.ingress_nginx_controller.status.0.load_balancer.0.ingress.0.ip}
            OBSERVED=""
            until [[ $NOW -ge $END ]] || [[ $OBSERVED == $EXPECTED ]]; do
                sleep 5
                # find the last A record in the response
                OBSERVED=$(RRTYPE=A ./dnslookup wild.${var.dns_zone} 1.1.1.1 | mawk '/ANSWER SECTION/,/IN.*A/ {A=$5}; END {print A};')
                echo "OBSERVED=$OBSERVED, EXPECTED=$EXPECTED"
            done
            if [[ $OBSERVED != $EXPECTED ]]; then
                echo "DNS record not found after 5 minutes"
                exit 1
            fi
        EOF
    }
}

# fetch CRD manifests
data "http" "cert_manager_crds" {
    # url = "https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml"
    url = "https://github.com/cert-manager/cert-manager/releases/download/v1.12.1/cert-manager.crds.yaml"
}

data "http" "trust_manager_crds" {
    url = "https://raw.githubusercontent.com/cert-manager/trust-manager/v0.5.0/deploy/crds/trust.cert-manager.io_bundles.yaml"
}

# split CRD manifests
data "kubectl_file_documents" "cert_manager_crds" {
    content = data.http.cert_manager_crds.response_body
}

data "kubectl_file_documents" "trust_manager_crds" {
    content = data.http.trust_manager_crds.response_body
}

# apply each CRD
resource "kubectl_manifest" "split_manifests" {
    depends_on = [ terraform_data.wait_for_dns ]
    for_each   = merge(data.kubectl_file_documents.cert_manager_crds.manifests, data.kubectl_file_documents.trust_manager_crds.manifests)
    yaml_body  = each.value
}

module "ziti_controller" {
    depends_on = [ kubectl_manifest.split_manifests ]
    # source = "github.com/openziti-terraform-modules/terraform-k8s-openziti-controller?ref=v0.1.3"
    source = "github.com/openziti-terraform-modules/terraform-k8s-openziti-controller?ref=fix-timeout-seconds"
    chart_repo = "https://nuc2fsxoxep5.canary.openziti.io/"
    ziti_controller_release = var.ziti_controller_release
    ziti_namespace = var.zrok_namespace
    dns_zone = var.dns_zone
    storage_class = var.storage_class
    values = {
        # image = {
        #     repository = var.container_image_repository
        #     tag = var.container_image_tag != "" ? var.container_image_tag : ""
        #     pullPolicy = var.container_image_pull_policy
        # }
        fabric = {
            events = {
                enabled = true
            }
        }
        cert-manager = {
            enabled = true
        }
        trust-manager = {
            enabled = true
            app = {
                trust = {
                    namespace = var.zrok_namespace
                }
            }
        }
        defaultRouter = {
            enabled = true
        }
    }
}
