
# Developer Role  --------------------------------------------------

resource "kubernetes_role" "roleDevs"{
  depends_on = [
    kubernetes_namespace.example
  ]
for_each = { for i in local.config_authDev.Dev: i.id => i}   
    metadata {
    name = "role-${split("/",each.value.iam)[1]}"
    namespace = each.value.namespace
    labels = {
      test = "roletest"
    }
  }

  rule {
    api_groups = [  "",  "apps",  "batch",  "extensions"]
    resources  = [  "configmaps",  "cronjobs",  "deployments",  "events",  "ingresses",  "jobs",  "pods",  "pods/attach",  "pods/exec",  "pods/log",  "pods/portforward",  "secrets",  "services"]
    verbs      = [  "create",  "delete",  "describe",  "get",  "list",  "patch",  "update"]
  }
}

#----------------------------------------------------------------------


# Developer Role Binding -----------------------------------------------


 resource "kubernetes_role_binding" "roleDev_bind" {
  depends_on = [
    kubernetes_namespace.example,kubernetes_role.roleDevs
  ]
   for_each = { for i in local.config_authDev.Dev : i.id => i}
   metadata {
     name      = "role-${split("/",each.value.iam)[1]}"
     namespace = each.value.namespace
   }
   subject {
     kind      = "User"
     name      = "app:${split("/",each.value.iam)[1]}"
     api_group = "rbac.authorization.k8s.io"
   }
   role_ref {
     kind      = "Role"
     name      = "role-${split("/",each.value.iam)[1]}"
     api_group = "rbac.authorization.k8s.io"
   }
 }

#---------------------------------------------------------------------------------

