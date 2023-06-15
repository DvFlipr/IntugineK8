
resource "helm_release" "grafana" {
  name       = "grafana"
  chart = "oci://registry-1.docker.io/bitnamicharts/grafana"
  namespace  = local.config_variables.namespace

  values = [
    templatefile("${path.module}/templates/g.yaml", {
      prometheus_svc        = "${helm_release.prometheus.name}-server"
      admin                 = local.config_variables.admin_user
      password              = local.config_variables.admin_password
      replicas              = 1
    })
  ]
}