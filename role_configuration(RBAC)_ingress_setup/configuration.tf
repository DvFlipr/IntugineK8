resource "helm_release" "cert-manager" {
  chart      = "cert-manager"
  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = "1.11.0"

  set {
    name="installCRDs"
    value=true
  }

depends_on = [ helm_release.nginx-ingress-controller ]
}

resource "kubectl_manifest" "clusterIssuer" {
    yaml_body = file("${path.module}/issuer.yaml")
    depends_on = [ helm_release.cert-manager]
}

