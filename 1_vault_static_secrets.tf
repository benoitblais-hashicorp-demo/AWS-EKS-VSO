# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# VAULT SECRETS CONFIGURATION
# ==============================================================================
# This file initializes the KV v2 secrets engine that the Vault Secrets Operator
# will monitor and synchronize into the Kubernetes cluster.
# ==============================================================================

# Enable a new KV v2 secrets engine mounted dedicated to the demo application
resource "vault_mount" "webapp" {
  namespace   = vault_namespace.namespace.path
  path        = "webapp"
  type        = "kv"
  description = "KV v2 mount for the Go web application"
  options = {
    version = "2"
  }
}

# Provision the initial secret key-value pairs that the frontend relies upon
resource "vault_generic_secret" "webapp_config" {
  namespace = vault_namespace.namespace.path
  path      = "${vault_mount.webapp.path}/app/config"
  data_json = jsonencode({
    message   = "Try VSO native Secret syncing by changing this text from Vault!"
    image_url = "/resources/logo.png"
  })
}
