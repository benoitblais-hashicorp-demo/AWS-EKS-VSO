# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# VAULT KUBERNETES AUTHENTICATION BACKEND
# ==============================================================================
# This file provisions the Kubernetes authentication backend within the Vault 
# namespace. It configures Vault to authenticate Kubernetes Service Accounts by 
# validating their identities against the EKS cluster API. It also maps these 
# Service Accounts to Vault policies using auth roles.
# This execution is gated by the step_2 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# VAULT KUBERNETES AUTH CONFIGURATION
# ------------------------------------------------------------------------------

# 1. Enable the generic Kubernetes authentication method in Vault
resource "vault_auth_backend" "kube_auth" {
  count      = var.step_2 ? 1 : 0
  depends_on = [time_sleep.step_2]
  namespace  = vault_namespace.namespace.path
  type       = "kubernetes"
}

# 2. Configure Vault to trust the EKS cluster using its endpoints and the TokenReview service account secret
resource "vault_kubernetes_auth_backend_config" "kube_auth_cfg" {
  count                  = var.step_2 ? 1 : 0
  depends_on             = [time_sleep.step_2]
  namespace              = vault_namespace.namespace.path
  backend                = vault_auth_backend.kube_auth[0].path
  kubernetes_ca_cert     = base64decode(module.eks.cluster_certificate_authority_data)
  kubernetes_host        = module.eks.cluster_endpoint
  token_reviewer_jwt     = kubernetes_secret_v1.vault_token[0].data["token"]
  disable_iss_validation = true
}

# ------------------------------------------------------------------------------
# VAULT AUTHENTICATION ROLES
# ------------------------------------------------------------------------------

# 3. Create a Vault role binding the Kubernetes Service Account to a specific Vault policy
resource "vault_kubernetes_auth_backend_role" "demo_app_role" {
  count                            = var.step_2 ? 1 : 0
  depends_on                       = [time_sleep.step_2]
  namespace                        = vault_namespace.namespace.path
  backend                          = vault_auth_backend.kube_auth[0].path
  role_name                        = "demo-go-web-vso"
  bound_service_account_names      = [kubernetes_service_account_v1.vault[0].metadata.0.name]
  bound_service_account_namespaces = [kubernetes_namespace_v1.demo_app[0].metadata.0.name]
  token_max_ttl                    = 86400
  token_policies                   = [vault_policy.apps_policy[0].name]
}
