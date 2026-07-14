# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# STEP 3 DEPENDENCY GATE
# ==============================================================================
# This file provisions a time_sleep resource that acts as a dependency gate
# for all Step 3 resources. It ensures that Step 2 Kubernetes tooling
# (Ingress Controller, Vault Secrets Operator, authentication roles) is fully 
# deployed and stable before deploying the demo application.
# This execution is gated by the step_3 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# STEP 3 GATE
# ------------------------------------------------------------------------------

# 1. Act as a barrier: Wait for Step 2 dependencies, then add a 10s buffer to stabilize the environment
resource "time_sleep" "step_3" {
  count = var.step_3 ? 1 : 0
  depends_on = [
    helm_release.nginx_ingress,
    helm_release.vault_secrets_operator,
    kubernetes_cluster_role_binding_v1.vault,
    kubernetes_secret_v1.vault_token[0],
    vault_kubernetes_auth_backend_role.demo_app_role[0],
    vault_policy.apps_policy[0],
  ]
  create_duration  = "10s"
  destroy_duration = "10s"
}
