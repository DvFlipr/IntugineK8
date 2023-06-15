locals {
  config_variables = yamldecode(file("${path.module}/values.yml"))
  config_authDev = yamldecode(file("${path.module}/authDev.yml"))
  config_authAdm = yamldecode(file("${path.module}/authAdm.yml"))
  dev_iam_arns = [    for user in lookup(local.config_authDev, "Dev", []) :lookup(user, "iam", null) ]
  iams= concat(local.dev_iam_arns,local.config_authAdm.Admin)
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../stage1/terraform.tfstate"
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}




provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_namespace" "example" {
  
  for_each= { for namespace in local.config_variables.namespaces : namespace => namespace}

  metadata {
    labels = {
      "name" = each.value
    }
    name = each.value
  }
}



resource "kubernetes_config_map_v1_data" "aws_auth" {
  depends_on = [
    kubernetes_cluster_role_binding_v1.ClAdminRole_Binding,kubernetes_cluster_role_v1.ClAdminRole,kubernetes_role.roleDevs,kubernetes_role_binding.roleDev_bind
  ]
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapUsers = jsonencode([
      for i in local.iams:{
        userarn  = i
        username = "app:${split("/",i)[1]}"
      }
    ])
  }
  force = true
}



