# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# VAULT ACCESS POLICIES
# ==============================================================================
# This file provisions Vault policies required by the demo application to access
# stored secrets. It defines the specific paths and capabilities granted when 
# authenticating from the Kubernetes cluster.
# This execution is gated by the step_2 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# APPLICATION ACCESS POLICY
# ------------------------------------------------------------------------------

# 1. Create the Vault policy granting explicit read access to the webapp secrets
resource "vault_policy" "apps_policy" {
  count      = var.step_2 ? 1 : 0
  depends_on = [time_sleep.step_2]
  namespace  = vault_namespace.namespace.path
  name       = "apps-policy"

  policy = <<EOT
path "${vault_mount.webapp.path}/*" {
  capabilities = ["create", "read", "update", "patch", "list"]
}

# Vault Secrets Operator actively requires Vault Enterprise.
# It identifies Vault Enterprise by checking the `/sys/license/status` endpoint
# using the Pod's authenticated identity. We must grant read access.
path "sys/license/status" {
  capabilities = ["read"]
}
EOT
}
