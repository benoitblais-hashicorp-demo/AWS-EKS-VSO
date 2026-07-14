# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# DEMO WEB APPLICATION & SECRETS INJECTION
# ==============================================================================
# This file provisions the core Go web application and configures the Vault 
# Secrets Operator to sync Vault secrets directly to Kubernetes Secrets. 
# The application consumes the synced Kubernetes Secret transparently as 
# standard environment variables. VSO is configured to natively perform a 
# rollout restart of the deployment whenever the secret rotates.
# This execution is gated by the step_3 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# VAULT SECRETS OPERATOR (NATIVE KUBERNETES SECRET)
# ------------------------------------------------------------------------------

# 1. Provide VSO with instructions on which internal Vault path to sync to a Kubernetes Secret
resource "kubernetes_manifest" "vault_static_secret" {
  count = var.step_3 ? 1 : 0
  depends_on = [
    time_sleep.step_3,
    helm_release.vault_secrets_operator,
    vault_generic_secret.webapp_config,
  ]

  field_manager {
    force_conflicts = true
  }

  manifest = yamldecode(<<-EOF
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vso-secret
  namespace: ${kubernetes_namespace_v1.demo_app[0].metadata.0.name}
spec:
  namespace: ${trim(vault_namespace.namespace.id, "/")}
  vaultAuthRef: default
  mount: ${vault_mount.webapp.path}
  type: kv-v2
  path: app/config
  refreshAfter: 5s
  destination:
    create: true
    name: webapp-config-secret
  rolloutRestart:
    targets:
      - kind: Deployment
        name: demo-webapp
EOF
  )
}

# ------------------------------------------------------------------------------
# APPLICATION DEPLOYMENT & SERVICE
# ------------------------------------------------------------------------------

# 2. Deploy the web application pods and mount the Kubernetes secret
resource "kubernetes_deployment_v1" "demo_webapp" {
  count            = var.step_3 ? 1 : 0
  wait_for_rollout = false
  depends_on = [
    time_sleep.step_3,
    kubernetes_manifest.vault_static_secret,
  ]
  metadata {
    name      = "demo-webapp"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }

  spec {
    replicas = 3

    strategy {
      rolling_update {
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        app = "demo-webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "demo-webapp"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.vault[0].metadata.0.name
        container {
          name              = "demo-webapp"
          image             = var.demo_webapp_image
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health"
              scheme = "HTTP"
              port   = 8080
            }
          }

          env {
            name = "FIRST_MESSAGE"
            value_from {
              secret_key_ref {
                name = "webapp-config-secret"
                key  = "message"
              }
            }
          }

          env {
            name = "IMAGE_URL"
            value_from {
              secret_key_ref {
                name = "webapp-config-secret"
                key  = "image_url"
              }
            }
          }

          env {
            name  = "TITLE"
            value = "Vault Secrets Operator!"
          }

          env {
            name  = "SUB_TITLE"
            value = "You are now managing static secrets via VSO natively."
          }

          env {
            name  = "LEARN_LINK"
            value = "https://developer.hashicorp.com/vault/docs/platform/k8s/vso"
          }
        }
      }
    }
  }
}

# 3. Expose the web application internally within the Kubernetes cluster
resource "kubernetes_service_v1" "demo_webapp" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = kubernetes_deployment_v1.demo_webapp[0].metadata.0.name
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8080
      target_port = 8080
    }

    selector = {
      app = "demo-webapp"
    }
  }
}

