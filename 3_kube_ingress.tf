# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# APPLICATION INGRESS ARCHITECTURE
# ==============================================================================
# This file provisions the Kubernetes Ingress resource for the demo application.
# It configures the routing rules for the NGINX Ingress Controller to direct
# external web traffic into the newly provisioned web application pods.
# This execution is gated by the step_3 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# KUBERNETES INGRESS ROUTING
# ------------------------------------------------------------------------------

# 1. Create an Ingress resource to route external traffic to the application service
resource "kubernetes_ingress_v1" "apps" {
  count = var.step_3 ? 1 : 0
  depends_on = [
    time_sleep.step_3,
    kubernetes_service_v1.demo_webapp,
  ]
  metadata {
    name      = "demo-go-web-vso"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "ingress.kubernetes.io/ssl-redirect"       = "false"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
      "nginx.ingress.kubernetes.io/use-regex"    = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.public_hosted_zone != "" ? "${var.demo_subdomain}.${var.public_hosted_zone}" : null
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.demo_webapp[0].metadata.0.name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
