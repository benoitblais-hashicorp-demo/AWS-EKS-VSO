# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# STEP 2 DEPENDENCY GATE
# ==============================================================================
# This file provisions a time_sleep resource that acts as a dependency gate
# for all Step 2 resources. It ensures that Step 1 core infrastructure (VPC, 
# EKS, Vault secrets) is completely provisioned and stable before any Step 2 
# Kubernetes tooling components are deployed.
# This execution is gated by the step_2 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# STEP 2 GATE
# ------------------------------------------------------------------------------

# 1. Act as a barrier: Wait for Step 1 dependencies, then add a 10s buffer to stabilize the environment
resource "time_sleep" "step_2" {
  count = var.step_2 ? 1 : 0
  depends_on = [
    module.eks,
    module.vpc,
    vault_generic_secret.webapp_config,
  ]
  create_duration  = "10s"
  destroy_duration = "10s"
}
