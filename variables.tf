# Copyright IBM Corp. 2024, 2026

#------------------------------------------------------------------------------
# Required variables
#------------------------------------------------------------------------------

variable "vault_address" {
  description = "(Required) Full URL of the HashiCorp Vault cluster (for example `https://vault.example.com:8200`). Used by the Vault Secrets Operator VaultConnection custom resource."
  type        = string

  validation {
    condition     = can(regex("^https?://", var.vault_address))
    error_message = "`vault_address` must be a valid URL starting with http:// or https://."
  }
}

#------------------------------------------------------------------------------
# Optional variables
#------------------------------------------------------------------------------

variable "customer_name" {
  description = "(Optional) Corresponds to the cdl-customer-name tag in AWS."
  type        = string
  default     = "hashicat"
}

variable "demo_subdomain" {
  description = "(Optional) The subdomain to prepend to the public_hosted_zone for the application (e.g., 'vso-demo')."
  type        = string
  default     = "vso-demo"
}

variable "demo_webapp_image" {
  description = "(Optional) The container image reference for the demo web application."
  type        = string
  default     = "ghcr.io/benoitblais-hashicorp-demo/demo-go-web-vso:v1.2.0"
}

variable "doormat_username" {
  description = "(Optional) Doormat username used to construct the IAM developer role ARN for EKS cluster access and KMS key administration (e.g. firstname.lastname_company). Leave empty to skip adding the doormat role as a KMS key administrator and EKS access entry."
  type        = string
  default     = ""

  validation {
    condition     = var.doormat_username == "" || can(regex("^[a-zA-Z0-9._-]+$", var.doormat_username))
    error_message = "`doormat_username` must contain only letters, numbers, dots, underscores, or hyphens."
  }
}

variable "environment" {
  description = "(Optional) Corresponds to the environment tag in AWS."
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "(Optional) EC2 instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"

  validation {
    condition = contains([
      "t3.medium",
      "t3.large",
      "t3.xlarge",
      "m6i.large",
      "m6i.xlarge",
      "m6a.large",
      "m6a.xlarge",
    ], var.instance_type)
    error_message = "`instance_type` must be one of: t3.medium, t3.large, t3.xlarge, m6i.large, m6i.xlarge, m6a.large, or m6a.xlarge."
  }
}

variable "owner" {
  description = "(Optional) Owner identifier (e.g., email) used for tagging."
  type        = string
  default     = "user@example.com"
}

variable "public_hosted_zone" {
  description = "(Optional) The Route 53 public hosted zone name (e.g., 'example.com') where DNS validation and A records will be published. If set, an ACM certificate will be provisioned directly on the NGINX Network Load Balancer."
  type        = string
  default     = "benoit-blais.sbx.hashidemos.io"
}

variable "region" {
  description = "(Optional) AWS region where all resources are provisioned."
  type        = string
  default     = "ca-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "`region` must be a valid AWS region identifier (e.g. ca-central-1, eu-central-1)."
  }
}

variable "repository" {
  description = "(Optional) The URL of the repository where the codebase resides."
  type        = string
  default     = "github.com/hashicorp/terraform-demo"
}

variable "resources_prefix" {
  description = "(Optional) Prefix applied to all resources."
  type        = string
  default     = "vso"
}

variable "salesforce_opportunity_id" {
  description = "(Optional) Corresponds to the salesforce_id tag in AWS."
  type        = string
  default     = "N/A"
}

variable "step_2" {
  description = "(Optional) Set to true after Step 1 completes successfully. Deploys Kubernetes tooling: nginx ingress, Vault Secrets Operator, Vault Kubernetes auth backend, and RBAC resources."
  type        = bool
  default     = false
}

variable "step_3" {
  description = "(Optional) Set to true after Step 2 completes successfully. Deploys the VaultStaticSecret custom resource and the demo Go web application. Requires step_2 = true."
  type        = bool
  default     = false
}

# tflint-ignore: terraform_naming_convention
variable "TFC_PROJECT_NAME" {
  description = "(Optional) Automatically populated by Terraform Cloud. Corresponds to the cdl-ddr-project tag in AWS."
  type        = string
  default     = "local-project"
}

# tflint-ignore: terraform_naming_convention
variable "TFC_WORKSPACE_NAME" {
  description = "(Optional) Automatically populated by Terraform Cloud. Corresponds to the cdl-ddr-workspace-slug tag in AWS."
  type        = string
  default     = "local-workspace"
}

variable "uptycs_tags" {
  description = "(Optional) Comma-separated Uptycs tags in UPDATE/CCODE/UT/OWNER format."
  type        = string
  default     = "UPDATE/PROD,CCODE/HashiCorp,UT/20A7V,OWNER/owner-email@hashicorp.com"
}

variable "vpc_cidr" {
  description = "(Optional) IPv4 CIDR block for the AWS VPC."
  type        = string
  default     = "10.1.0.0/16"
}
