
locals{
   config_variables = yamldecode(file("${path.module}/values.yml"))
}



resource "kubectl_manifest" "IngressConfig" {
    yaml_body = templatefile("${path.module}/configs/ingress.yaml",{
    env=local.config_variables.domain})
    depends_on = [ helm_release.grafana,helm_release.prometheus ]
}

resource "kubectl_manifest" "Certificate" {
    yaml_body = templatefile("${path.module}/configs/certificate.yaml",{env=local.config_variables.domain})
}