# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# ENDPOINT DETECTION AND RESPONSE (EDR)
# ==============================================================================
# This file provisions Endpoint Detection and Response (EDR) capabilities within 
# the Kubernetes cluster. It creates a dedicated namespace with the necessary 
# privileged pod security standards and deploys the Uptycs EDR agent 
# (via the k8sosquery Helm chart).
# This execution is gated by the step_2 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# KUBERNETES NAMESPACE & SECURITY LABELS
# ------------------------------------------------------------------------------

# 1. Create the 'uptycs' namespace with privileged access for the EDR daemonset
resource "kubernetes_namespace_v1" "edr" {
  count      = var.step_2 ? 1 : 0
  depends_on = [time_sleep.step_2]
  metadata {
    name = "uptycs"
    labels = {
      "app.kubernetes.io/managed-by"       = "terraform"
      "security.hashicorp.com/cluster"     = module.eks.cluster_name
      "security.hashicorp.com/addons"      = "edr"
      "security.hashicorp.com/rbac"        = "edr"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# ------------------------------------------------------------------------------
# EDR HELM RELEASE
# ------------------------------------------------------------------------------

# 2. Deploy the Uptycs EDR agent (k8sosquery) via Helm, configuring environment tags
resource "helm_release" "uptycs_edr" {
  count            = var.step_2 ? 1 : 0
  depends_on       = [kubernetes_namespace_v1.edr]
  name             = "uptycs-edr"
  repository       = "https://uptycslabs.github.io/kspm-helm-charts"
  chart            = "k8sosquery"
  namespace        = kubernetes_namespace_v1.edr[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      configmap = {
        name = "uptycs-config"
        data = {
          tags = var.uptycs_tags
        }
      }
    })
  ]
}
