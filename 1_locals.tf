# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# LOCAL IDENTIFIERS
# ==============================================================================
# This file generates a randomized suffix to attach to the demo's global prefix.
# This ensures that multiple instances of this demo can securely run in the 
# same AWS account without causing naming collisions (e.g., Load Balancers, VPCs).
# ==============================================================================

locals {
  global_id        = random_string.identifier.result
  resources_prefix = "${var.resources_prefix}-${local.global_id}"
}

# Generate a 4-character random lowercase string (e.g., 'a1b2')
resource "random_string" "identifier" {
  length  = 4
  special = false
  numeric = false
  upper   = false
}
