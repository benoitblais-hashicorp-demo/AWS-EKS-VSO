# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# EKS CLUSTER ARCHITECTURE
# ==============================================================================
# This file provisions the Amazon Elastic Kubernetes Service (EKS) cluster.
# It establishes the control plane, managed node groups, standard add-ons, 
# and integrates AWS IAM roles natively into Kubernetes RBAC (Access Entries).
# ==============================================================================

# ------------------------------------------------------------------------------
# AWS IDENTITY & AUTHENTICATION CONTEXT
# ------------------------------------------------------------------------------
# Discover information about the currently executing Terraform identity. 
# This ensures the EKS cluster creator and key administrators retain access.
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  # Dynamically construct an AWS Doormat developer role ARN if a username is provided.
  # This allows operators to authenticate via kubectl using their corporate SSO.
  extra_doormat_role = var.doormat_username != "" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws_${var.doormat_username}-developer" : null
  partition          = data.aws_partition.current.partition
}

# ------------------------------------------------------------------------------
# EKS CLUSTER DEPLOYMENT
# ------------------------------------------------------------------------------
module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "21.15.1"
  name                                     = "${local.resources_prefix}-eks"
  kubernetes_version                       = "1.34"
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets

  # Grant EKS Cluster Admin rights natively to the human Doormat role 
  access_entries = local.extra_doormat_role != null ? {
    doormat_human_admin = {
      kubernetes_groups = []
      principal_arn     = local.extra_doormat_role

      policy_associations = {
        admin = {
          policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  } : {}

  # Add the human Doormat role and Terraform's identity to the cluster's KMS Key policy
  kms_key_administrators = local.extra_doormat_role != null ? [
    local.extra_doormat_role,
    data.aws_iam_session_context.current.issuer_arn,
    ] : [
    data.aws_iam_session_context.current.issuer_arn,
  ]

  # Critical cluster Add-ons defined to run before workloads
  addons = {
    coredns = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {
      before_compute = true
    }
    vpc-cni = {
      before_compute = true
    }
  }

  # Provision the worker nodes using the instance type mapped against healthy AZs
  eks_managed_node_groups = {
    nodes = {
      instance_types = [var.instance_type]
      min_size       = 1
      max_size       = 3
      desired_size   = 1
    }
  }
}
