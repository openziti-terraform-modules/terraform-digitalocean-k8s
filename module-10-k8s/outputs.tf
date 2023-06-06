output "kubeconfig" {
    value = digitalocean_kubernetes_cluster.zrok_cluster.kube_config[0].raw_config
    sensitive = true
}

# resource "local_sensitive_file" "kubeconfig" {
#     depends_on   = [linode_lke_cluster.linode_lke]
#     filename     = "../kube-config-${terraform.workspace}"
#     content      = base64decode(linode_lke_cluster.linode_lke.kubeconfig)
#     file_permission = 0600
# }

output "dns_zone" {
    description = "consumed by router plan to build ingress names"
    value = var.dns_zone
}

output "zrok_namespace" {
    description = "consumed by router plan to install release in same namespace as controller which is convenient but not necessary"
    value = var.zrok_namespace
}

output "cluster_issuer_name" {
    description = "issues Let's Encrypt certificate for the console"
    value = var.cluster_issuer_name
}

output "cluster_name" {
    value = var.cluster_name
}
