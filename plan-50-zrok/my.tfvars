ziti_charts = "/home/kbingham/Sites/netfoundry/github/openziti-helm-charts/charts"

# container_image_repository = "kbinghamnetfoundry/zrok"
container_image_repository = "openziti/zrok"
# container_image_tag = "v0__4__0"
container_image_tag = "v0__3__6-backport-container"
zrok_controller_spec_version = 2
container_image_pull_policy = "Always"

storage_class = "linode-block-storage"

# resource "kubernetes_manifest" "influxdb_cert" {
#     manifest = {
#         "apiVersion" = "cert-manager.io/v1"
#         "kind" = "Certificate"
#         "metadata" = {
#             "name" = local.influxdb_tls_cert_name
#         }
#         "spec" = {
#             "dnsNames" = [
#                 "influxdb.${data.terraform_remote_state.k8s_state.outputs.dns_zone}"
#             ]
#             "issuerRef" = {
#                 "group" = "cert-manager.io"
#                 "kind" = "Issuer"
#                 "name" = "letsencrypt-prod"
#             }
#             "secretName" = "acme-crt-secret"
#         }
#     }
# }

email_from = "no-reply@bingnet.cloud"
email_username = "no-reply@bingnet.cloud"
email_password = "9UT6jynAR9HPwy"
email_host = "mail.privateemail.com"
email_port = 587