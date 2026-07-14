# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# VAULT NAMESPACE CONFIGURATION
# ==============================================================================
# This file provisions a dedicated child namespace within the HCP Vault cluster.
# By isolating the demonstration resources in their own namespace, we prevent
# cluttering the root namespace or colliding with other teams' deployments.
# ==============================================================================

resource "vault_namespace" "namespace" {
  path = "${local.resources_prefix}-ns"
}
