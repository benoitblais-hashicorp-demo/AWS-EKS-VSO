# Copyright IBM Corp. 2024, 2026

provider "vault" {
  # Authentication is provided by HCP Terraform workload identity
  # when TFC_VAULT_PROVIDER_AUTH=true is set at the workspace level.
  # The address is automatically injected via the TFC_VAULT_ADDR environment variable.
}

provider "aws" {
  # shared_config_files = [var.tfc_aws_dynamic_credentials.default.shared_config_file]
  region = var.region

  default_tags {
    tags = {
      hc-repo                = var.repository
      hc-owner               = var.owner
      cdl-customer-name      = var.customer_name
      cdl-name               = var.resources_prefix
      cdl-ddr-workspace-slug = var.TFC_WORKSPACE_NAME
      cdl-ddr-project        = var.TFC_PROJECT_NAME
      environment            = var.environment
      region                 = var.region
      salesforce_id          = var.salesforce_opportunity_id
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}
