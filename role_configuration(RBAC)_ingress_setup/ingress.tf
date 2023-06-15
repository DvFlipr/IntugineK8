resource "helm_release" "nginx-ingress-controller" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace =  "ingress"


  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  
  depends_on = [ kubernetes_namespace.example ]
}


resource "null_resource" "execute_command" {
  provisioner "local-exec" {
    command = <<EOT
      echo "host: \"$(kubectl get service nginx-ingress-controller -n ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")\"" > hostName.yml
    EOT
  }
  depends_on = [ helm_release.nginx-ingress-controller ]
}