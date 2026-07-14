# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# NETWORKING ARCHITECTURE
# ==============================================================================
# This file provisions the foundational AWS Virtual Private Cloud (VPC) required 
# for the EKS cluster. It securely calculates which Availability Zones (AZs) can 
# physically support the requested EC2 instance types before generating the subnets.
# ==============================================================================

# ------------------------------------------------------------------------------
# AVAILABILITY ZONE FILTERING
# ------------------------------------------------------------------------------

# 1. Discover all healthy Availability Zones in the selected AWS region
data "aws_availability_zones" "available" {
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 2. Discover which of those AZs possess the physical hardware to support our node instance type
data "aws_ec2_instance_type_offerings" "supported" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

locals {
  # 3. Intersect the two data sources to find AZs that are both healthy AND support our instances
  candidate_azs = [
    for az in data.aws_availability_zones.available.names : az
    if contains(data.aws_ec2_instance_type_offerings.supported.locations, az)
  ]

  # 4. Sort the list alphabetically for stability across Terraform deployments
  sorted_candidate_azs = sort(local.candidate_azs)

  # 5. Take the first 3 valid AZs (or less, if the region has fewer compatible zones)
  azs = slice(
    local.sorted_candidate_azs,
    0,
    min(length(local.sorted_candidate_azs), 3)
  )
}

# ------------------------------------------------------------------------------
# VPC CONFIGURATION
# ------------------------------------------------------------------------------

# Provision the VPC utilizing the public Terraform AWS module
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "~> 5.16"
  name               = "${local.resources_prefix}-vpc"
  cidr               = var.vpc_cidr
  azs                = local.azs
  enable_nat_gateway = true
  single_nat_gateway = true
  private_subnets    = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx)]
  public_subnets     = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 8, idx + 48)]

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
