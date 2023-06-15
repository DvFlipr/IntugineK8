# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = local.config_variables.region
}

data "aws_availability_zones" "available" {}

locals {
  config_variables = yamldecode(file("${path.module}/values.yml"))
}


# resource "aws_subnet" "subnetsAZ1" {
#   count      = length(local.config_variables.subnet_cidr_blocks_az1)
#   vpc_id     = local.config_variables.vpc_id
#   cidr_block = local.config_variables.subnet_cidr_blocks_az1[count.index]
#   map_public_ip_on_launch = true
#   availability_zone = "us-east-1a"  # Replace with your desired availability zone
# }

resource "aws_subnet" "public_subnet" {
  count                   = length(local.config_variables.subnet_cidr_blocks_public)
  vpc_id                  = local.config_variables.vpc_id
  cidr_block              = "${element(local.config_variables.subnet_cidr_blocks_public,count.index)}"
  availability_zone       = "${element(local.config_variables.availability_zones,count.index)}"
  map_public_ip_on_launch = true
  tags = {
    Name                  = "${local.config_variables.environment}-${element(local.config_variables.availability_zones, count.index)}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  count                   = length(local.config_variables.subnet_cidr_blocks_private)
  vpc_id                  = local.config_variables.vpc_id
  cidr_block              = "${element(local.config_variables.subnet_cidr_blocks_private,count.index)}"
  availability_zone       = "${element(local.config_variables.availability_zones,count.index)}"
  map_public_ip_on_launch = false
  tags = {
    Name                  = "${local.config_variables.environment}-${element(local.config_variables.availability_zones, count.index)}-private-subnet"
  }
}
# resource "aws_subnet" "subnetsAZ2" {
#   count      = length(local.config_variables.subnet_cidr_blocks_az2)
#   vpc_id     = local.config_variables.vpc_id
#   cidr_block = local.config_variables.subnet_cidr_blocks_az2[count.index]
#   map_public_ip_on_launch = true
#   availability_zone = "us-east-1c"  # Replace with your desired availability zone
# }

/* Route table associations */
resource "aws_route_table_association" "public" {
  count          = length(local.config_variables.subnet_cidr_blocks_public)
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = local.config_variables.public_rttable_id
}
resource "aws_route_table_association" "private" {
  count          = length(local.config_variables.subnet_cidr_blocks_private)
  subnet_id      = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id = local.config_variables.private_rttable_id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.config_variables.cluster_name
  cluster_version = local.config_variables.cluster_vrsn

  vpc_id                         = local.config_variables.vpc_id
  subnet_ids                     = concat(aws_subnet.public_subnet[*].id,aws_subnet.private_subnet[*].id)
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


