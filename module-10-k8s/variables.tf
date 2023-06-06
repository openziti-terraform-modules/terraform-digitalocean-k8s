variable "DO_TOKEN" {
    type = string
    description = "Digital Ocean API token for creating the K8s cluster and stored as a K8s secret for cert-manager to use when solving ACME DNS01 challenges."
}
variable "email" {
    description = "The email address cert-manager should submit during ACME request to Let's Encrypt for server certs. (required)"
}

variable "dns_zone" {
    description = "The domain name zone to maintain for this cluster, e.g., ziti.example.com. (required)"
}

variable "cluster_name" {
    description = "The unique label to assign to this cluster."
    default = "my-zrok-cluster"
}

variable "k8s_version" {
    description = "The DO slug for the Kubernetes version to use for this cluster."
    default = "1.27.2-do.0"
}

variable "region" {
    description = "The DO region where your cluster will be located."
    default = "nyc3"
}

variable "tags" {
    description = "Tags to apply to your cluster for organizational purposes."
    type = list(string)
    default = ["zrok"]
}

variable "cluster_issuer_name" {
    description = "name of the cluster-wide certificate issuer for Let's Encrypt"
    default     = "cert-manager-staging"
}

variable "cluster_issuer_server" {
    description = "The ACME server URL"
    type        = string
    default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "wildcard_ttl_sec" {
    description = "max seconds recursive nameservers should cache the wildcard record"
    default = "3600"
}

variable "zrok_namespace" {
    default     = "zrok"
}

variable "ziti_controller_release" {
    description = "Helm release name for ziti-controller"
    default = "zrok-ziti-ctrl"
}

variable "storage_class" {
    description = "Storage class to use for persistent volumes"
    default = ""
}
