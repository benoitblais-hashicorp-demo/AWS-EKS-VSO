# Technical Specification: AWS EKS with Vault Secrets Operator Native Integration

## Overview

This document describes the technical architecture, deployment sequence, and design decisions for the AWS EKS + VSO demo. The configuration demonstrates how HashiCorp Vault secrets can be delivered securely and directly into Kubernetes pod workloads using the Vault Secrets Operator (VSO) natively — by syncing to standard Kubernetes `Secret` objects.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         HCP Terraform                           │
│  (VCS-driven, dynamic AWS + Vault credentials, 3-step apply)    │
└─────────────────────────┬───────────────────────────────────────┘
                          │ terraform apply (step_1)
          ┌───────────────▼───────────────┐
          │         AWS (ca-central-1)    │
          │  ┌─────────────────────────┐  │
          │  │      VPC (10.1.0.0/16)  │  │
          │  │ Private + Public Subnets│  │
          │  │ NAT Gateway             │  │
          │  └──────────┬──────────────┘  │
          │             │                 │
          │  ┌──────────▼──────────────┐  │
          │  │  EKS Cluster (1.34)     │  │
          │  │  Managed Node Group     │  │
          │  │  (t3.medium, 1–3 nodes) │  │
          │  └──────────┬──────────────┘  │
          └─────────────│─────────────────┘
                        │ step_2
          ┌─────────────▼────────────────────────────┐
          │          Kubernetes (EKS)                │
          │  namespaces: demo-go-web-vso,            │
          │              ingress-nginx, uptycs       │
          │  ┌────────────────────────────────────┐  │
          │  │  helm: ingress-nginx (NLB + EIP)   │  │
          │  │  helm: k8sosquery (Uptycs EDR)     │  │
          │  │  helm: vault-secrets-operator      │  │
          │  │    └─ Native Secrets enabled       │  │
          │  │  ServiceAccount: vault-auth        │  │
          │  │  ClusterRoleBinding: token-review  │  │
          │  └────────────────────────────────────┘  │
          └───────────────────────────────────────── ┘
                        │ step_3
          ┌─────────────▼───────────────────────────────────┐
          │          Kubernetes (EKS) — Application Layer   │
          │                                                 │
          │  VaultStaticSecret CR ──────────────► VSO       │
          │                                        │        │
          │  Kubernetes Secret ◄───────────────────┘        │
          │  (webapp-config-secret)                         │
          │           │                                     │
          │           ▼                                     │
          │  Pod (demo-webapp)      Vault KV read           │
          │  ├─ env: FIRST_MESSAGE     (webapp/app/config)  │
          │  └─ env: IMAGE_URL                              │
          └──────────────────────────────────────────────── ┘
                        │ reads KV secret
          ┌─────────────▼───────────────────┐
          │       HashiCorp Vault           │
          │  Namespace: <demo_id>-ns        │
          │  KV v2 mount: webapp            │
          │  Secret: webapp/app/config      │
          │    message: "Try VSO by..."     │
          │    image_url: "/resources/..."  │
          └──────────────────────────────── ┘
```

---

## Deployment Steps

This demo uses a three-step gated deployment pattern. Steps are controlled by boolean Terraform variables (`step_2`, `step_3`) to ensure that the EKS cluster and Vault resources are stable before building dependent layers on top of them.

### Step 1 — Infrastructure and Secrets (default)

Resources provisioned:

| Resource | Description |
| --- | --- |
| `module.vpc` | AWS VPC, private/public subnets across up to 3 AZs, NAT Gateway |
| `module.eks` | EKS cluster v1.34, managed node group, core addons |
| `vault_namespace.namespace` | Isolated Vault namespace scoped to this demo |
| `vault_mount.webapp` | KV v2 secrets engine mounted at `webapp` |
| `vault_generic_secret.webapp` | Static secret at `webapp/app/config` |

After Step 1, the AWS infrastructure is provisioned and the initial Vault secret is populated.

### Step 2 — Kubernetes Tooling (`step_2 = true`)

Resources provisioned:

| Resource | Description |
| --- | --- |
| `kubernetes_namespace_v1.demo_app` | Dedicated namespaces (`demo-go-web-vso`, `ingress-nginx`, `uptycs`) with PSS compliance |
| `aws_eip.nginx_ingress` | 3 Elastic IPs for the Network Load Balancer |
| `helm_release.nginx_ingress` | Nginx ingress controller (internet-facing NLB) |
| `helm_release.uptycs_edr` | IBM Uptycs EDR agent (k8sosquery Helm chart) |
| `helm_release.vault_secrets_operator` | VSO Helm chart v1.3.0 with Native Secrets enabled |
| `kubernetes_service_account_v1.vault` | Service account `vault-auth` for Vault authentication |
| `kubernetes_secret_v1.vault_token` | Long-lived service account token for Vault token reviewer |
| `kubernetes_cluster_role_binding_v1.vault` | Binds `system:auth-delegator` for token review |
| `vault_auth_backend.kube_auth` | Vault Kubernetes auth backend |
| `vault_kubernetes_auth_backend_config.kube_auth_cfg` | Configured with EKS CA cert and endpoint |
| `vault_kubernetes_auth_backend_role.demo_app_role` | Role `demo-go-web-vso` bound to `vault-auth` service account |
| `vault_policy.apps_policy` | Policy granting read access to `webapp/*` |

After Step 2, the VSO operator is running and Vault Kubernetes authentication is fully wired.

### Step 3 — Application Deployment (`step_3 = true`)

Resources provisioned:

| Resource | Description |
| --- | --- |
| `kubernetes_manifest.vault_static_secret` | `VaultStaticSecret` CR referencing `webapp/app/config` |
| `kubernetes_deployment_v1.demo_webapp` | Go web app (`drum0r/demo-go-web:v1.1.0`), 3 replicas |
| `kubernetes_service_v1.demo_webapp` | ClusterIP service exposing port 8080 |
| `kubernetes_ingress_v1.apps` | Ingress rule routing `/` to the static app |

After Step 3, the web application is accessible via the Elastic IP and renders Vault secret content sourced from the native Kubernetes Secret via standard environment variables.

---

## Networking

### Ingress Architecture

The nginx ingress controller is deployed with an internet-facing AWS Network Load Balancer (NLB). Three Elastic IPs are pre-allocated and associated with the NLB via `service.beta.kubernetes.io/aws-load-balancer-eip-allocations`. This ensures a stable, predictable public IP for the demo application.

Traffic flow:

```text
Internet → Elastic IP (NLB) → nginx ingress controller → demo-go-web-vso service → pod (port 8080)
```

### EKS Cluster Networking

The EKS cluster uses private subnets for worker nodes. The control plane endpoint is publicly accessible (`endpoint_public_access = true`) to allow Terraform (running in HCP Terraform) to configure the cluster. In production, this should be set to private-only.

---

## Vault Authentication

VSO authenticates to Vault using the Kubernetes auth method:

1. VSO reads the pod's service account JWT token.
2. VSO presents the JWT to Vault's Kubernetes auth backend (`kubernetes` mount).
3. Vault calls the EKS API server's TokenReview endpoint (using the `vault-auth` service account with `system:auth-delegator`).
4. Vault validates the token and maps it to the `demo-go-web-vso` role.
5. Vault issues a short-lived Vault token (max TTL: 24 hours) scoped to the `apps-policy`.

Terraform itself authenticates to Vault using HCP Terraform workload identity (JWT/OIDC)
at run time. The workspace identity is exchanged for a short-lived Vault token through the
configured Vault run role (`TFC_VAULT_RUN_ROLE`), avoiding long-lived static Vault tokens.

---

## Design Decisions

| Decision | Rationale |
| --- | --- |
| Numbered file naming (`1_`, `2_`, `3_`) | Makes the deployment order explicit and self-documenting |
| `time_sleep` gates between steps | Ensures cluster readiness before Helm charts and Kubernetes resources are applied |
| VaultStaticSecret CRD | Demonstrates native Vault operator syncing to Kubernetes Secret objects |
| KV v2 for secrets | Enables secret versioning, metadata, and rotation history |
| `pessimistic constraint operator (~>)` for providers | Allows patch-level provider upgrades without breaking the configuration |
| Workspace identity authentication | Uses JWT/OIDC workload identity for Vault and dynamic AWS credentials from HCP Terraform |
| 3 Elastic IPs for NLB | Required by AWS NLB with internet-facing scheme across 3 AZs |
| `sensitive = true` on `kubernetes_info` output | Prevents the kubeconfig update command from appearing in HCP Terraform plan logs |

---

## CI/CD

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `terraform.yml` | Pull request | Runs `terraform fmt` and pushes formatting fixes back to the PR branch |
| `documentation.yml` | Pull request | Runs `terraform-docs` to regenerate `README.md` from header/footer templates |
| `linter.yml` | Pull request | Runs Super Linter (GitHub Actions, JSON, Markdown, TFLint, YAML) |
| `tag_release.yml` | Push / tag | Manages semantic version tagging and releases |

The `README.md` is auto-generated by `terraform-docs` using the config at `.github/terraform-docs/.tfdocs-config.yml`. Do not edit `README.md` directly.
