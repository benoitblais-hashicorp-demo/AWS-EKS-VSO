# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# VAULT SECRETS OPERATOR (VSO) DEPLOYMENT
# ==============================================================================
# This file deploys the Vault Secrets Operator (VSO) using the official Helm chart
# and provisions the Custom Resources (VaultConnection and VaultAuth) required by 
# VSO to communicate and authenticate securely with the Vault cluster.
# This execution is gated by the step_2 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# VSO HELM RELEASE
# ------------------------------------------------------------------------------

# 1. Deploy Vault Secrets Operator via Helm, configuring the default Vault connection and auth method
resource "helm_release" "vault_secrets_operator" {
  count = var.step_2 ? 1 : 0
  depends_on = [
    time_sleep.step_2,
    vault_kubernetes_auth_backend_role.demo_app_role
  ]
  name       = "vault-secrets-operator"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  namespace  = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  version    = "1.3.0"
  values = [<<-EOT
  defaultVaultConnection:
    enabled: true
    address: "${var.vault_address}"
  defaultAuthMethod:
    enabled: true
    namespace: "${trim(vault_namespace.namespace.id, "/")}"
    method: "${vault_auth_backend.kube_auth[0].type}"
    mount: "${vault_auth_backend.kube_auth[0].path}"
    kubernetes:
      role: "${vault_kubernetes_auth_backend_role.demo_app_role[0].role_name}"
      serviceAccount: "${kubernetes_service_account_v1.vault[0].metadata.0.name}"
EOT
  ]
}
