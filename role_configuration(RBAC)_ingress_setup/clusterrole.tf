
# Cluster Role for Iam Users ----------------------------------

resource "kubernetes_cluster_role_v1" "ClAdminRole" {
  depends_on = [
    kubernetes_namespace.example
  ] 
  metadata {
    name = "ClusterAdminRole"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# -------------------------------------------------------------


# Cluster role binding for groups in kubernetes

resource "kubernetes_cluster_role_binding_v1" "ClAdminRole_Binding" {
  for_each = {for i in local.config_authAdm.Admin : i=>i}
  depends_on = [
    kubernetes_namespace.example,kubernetes_cluster_role_v1.ClAdminRole
  ]
  metadata {
    name = "${kubernetes_cluster_role_v1.ClAdminRole.metadata[0].name}-${split("/",each.value)[1]}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.ClAdminRole.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = "app:${split("/",each.value)[1]}"
    api_group = "rbac.authorization.k8s.io"
  }
}

#----------------------------------------------------------------
