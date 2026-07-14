# AGENTS.md for Terraform Project

This file provides instructions for AI coding agents working on this Terraform Project.

## Project Overview

This project provisions an AWS Elastic Kubernetes Service (EKS) cluster integrated with Vault Secrets Operator (VSO) using Terraform. It demonstrates how Vault secrets can be delivered directly into Kubernetes pods via VSO native Kubernetes Secrets.

The configuration is deployed in three sequential steps controlled by boolean variables (`step_2`, `step_3`):

- **Step 1 (default):** AWS VPC, EKS cluster, Vault namespace, and static KV secrets.
- **Step 2:** Kubernetes tooling — nginx ingress, Route53 DNS and ACM Certificates, Uptycs EDR, VSO Helm chart, Vault Kubernetes auth backend, and RBAC bindings.
- **Step 3:** Application deployment — VaultStaticSecret CRD, Go web application with Vault-mounted secrets, and automated pod restarter CronJob.

## Module and Repository Structure

This project uses a numbered file naming convention to reflect the three deployment steps:

```text
├── .gitignore
├── LICENSE
├── README.md
├── terraform.tf          # Terraform version and provider requirements
├── outputs.tf            # Output value definitions (alphabetical order)
├── providers.tf          # Provider configurations
├── variables.tf          # Input variable definitions (alphabetical order)
├── variables_providers.tf # Dynamic credential variables (currently commented out)
├── 1_locals.tf           # Randomized global identifiers and prefixes (Step 1)
├── 1_aws_network.tf      # VPC and subnet provisioning (Step 1)
├── 1_aws_eks.tf          # EKS cluster and node groups (Step 1)
├── 1_vault_ns.tf         # Vault namespace creation (Step 1)
├── 1_vault_static_secrets.tf # KV v2 mount and static secrets (Step 1)
├── 2_starting.tf         # Step 2 gate (time_sleep dependency guard)
├── 2_aws_dns.tf          # ACM certificates and Route53 DNS for Ingress (Step 2)
├── 2_kube_tools.tf       # nginx ingress, service account, RBAC (Step 2)
├── 2_kube_edr.tf         # Uptycs EDR natively via k8sosquery Helm chart (Step 2)
├── 2_kube_vso.tf         # Vault Secrets Operator Helm release (Step 2)
├── 2_vault_kube.tf       # Vault Kubernetes auth backend (Step 2)
├── 2_vault_policy.tf     # Vault policy for app access (Step 2)
├── 3_starting.tf         # Step 3 gate (time_sleep dependency guard)
├── 3_kube_ingress.tf     # Kubernetes ingress rule (Step 3)
├── 3_kube_static_app.tf  # VaultStaticSecret CRD, deployment (demo-webapp), service, automation (Step 3)
├── docs/
│   ├── CODE_OF_CONDUCT.md
│   ├── CONTRIBUTING.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── README_footer.md
│   ├── README_header.md
│   ├── SECURITY.md
│   └── SPECIFICATION.md  # Technical architecture and design decisions
```

### Required Files and Directories

- `README.md` – Required in the root module. Generated automatically via terraform-docs CI. Do not edit manually.
- `docs/README_header.md` – Describe the purpose of the demo, key features, permissions, and authentication.
- `docs/README_footer.md` – External documentation links used to develop the code.
- `docs/SPECIFICATION.md` – Technical architecture, design decisions, and demo flow documentation.
- `terraform.tf` – Terraform version and provider requirements (`required_version`, `required_providers`).
- `providers.tf` – Provider configurations (AWS, Vault, Helm, Kubernetes).
- `outputs.tf` – Output value definitions (alphabetical order).
- `variables.tf` – Input variable definitions (alphabetical order with required variables at the top).
- `variables_providers.tf` – Legacy dynamic credential variable definitions kept as reference (workspace JWT/OIDC auth is used directly via environment variables).

## Tools and Frameworks

- AI Agents should format their generated HCL optimally as local `terraform fmt`, `terraform init`, and `terraform validate` cannot be run directly during the session due to the VCS-driven workflow.
- Formatting and CI/CD validation are handled by an automated VCS workflow, meaning the Agent does not need to run a local linter or validation operations locally. Do your best to output valid HCL code and do not try to run Terraform commands in the terminal.
- Use `terraform-docs` to generate the `README.md` file using the header and footer (you don't need to do this manually if the CI does it, but you must create the header/footer files).

## README_header.md

When editing or creating `docs/README_header.md`, ensure it contains:

- A description of the general purpose of the code.
- A `Permissions` section containing the permissions required to provision resources for each provider.
- An `Authentications` section containing the authentication details required for each provider.
- A `Demo Components` section containing key features and components managed by the code.

## README_footer.md

When editing or creating `docs/README_footer.md`, ensure it contains:

- An `External Documentation` section providing links to relevant external documentation used to develop the code (e.g., AWS, Kubernetes, Helm, and Vault Provider docs, HashiCorp learn guides for VSO ).

## Code Guidelines

Refer to CONTRIBUTING.md for general coding guidelines. HashiCorp's Terraform style guide should be applied for all code generated.

## Resource Naming

- Use descriptive nouns separated by underscores.
- Do not include the resource type in the resource name.
- Wrap resource type and name in double quotes.
- Example: `resource "aws_eks_cluster" "main"` not `resource "aws_eks_cluster" "eks_main"`.

## Version Management

- Prefer the pessimistic constraint operator (`~>`) for modules and providers to allow safe updates within a compatible version range.
- Avoid using only the equals (`=`) operator unless you must lock to a single version for reproducibility or known issues.
- Pin the Terraform version using `required_version` in the `terraform` block.

## Provider Configuration

- Always include a default provider configuration.
- Define all providers in the same file (`providers.tf`).
- Define the default provider first, then aliased providers.
- Use `alias` as the first parameter in non-default provider blocks.
- Do not explicitly declare the `address` field inside the `vault` provider configuration - rely on the `TFC_VAULT_ADDR` environment variable injected by HCP Terraform.

## Security and Secrets

- Never commit `.terraform` directories or local state files.
- The project uses HCP Terraform native dynamic credentials for AWS and JWT/OIDC workload identity for Vault provider authentication.
- Access secrets securely via workspace variables.
- Do not introduce static `VAULT_TOKEN` usage in documentation or examples for normal runs.
- Set `sensitive = true` for sensitive variables across all definitions.

## State Management

- State storage is managed natively by HCP Terraform workspaces. Data sharing between configurations relies on standard data sources or `tfe_outputs` where cross-workspace values are required.
