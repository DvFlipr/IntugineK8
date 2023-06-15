# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  config_variables = yamldecode(file("${path.module}/values.yml"))
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = local.config_variables.VPC_NAME

  cidr = local.config_variables.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = local.config_variables.vpc_private_subnets
  public_subnets  = local.config_variables.vpc_public_subnets

  enable_nat_gateway   = local.config_variables.vpc_enable_nat_gateway
  single_nat_gateway   = local.config_variables.vpc_single_nat_gateway
  enable_dns_hostnames = local.config_variables.vpc_enable_dns_hostnames

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.config_variables.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.config_variables.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.config_variables.cluster_name
  cluster_version = local.config_variables.cluster_vrsn

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = local.config_variables.cluster_endpoint_public_access

  eks_managed_node_group_defaults = {
    ami_type = local.config_variables.ami_type

  }

    eks_managed_node_groups = {
    for node_group in local.config_variables.eks_node_groups:
      node_group.name => {
        name           = node_group.name
        instance_types = node_group.instance_types
        min_size       = node_group.min_size
        max_size       = node_group.max_size
        desired_size   = node_group.desired_size
      }
  }

}
    


data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.5.2-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}

