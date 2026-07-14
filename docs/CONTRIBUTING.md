# Contributing

Thank you for your interest in contributing. This repository uses Terraform to provision an AWS EKS cluster integrated with the HashiCorp Vault Secrets Operator (VSO). The target architecture synchronizes Vault secrets to native Kubernetes Secrets, mapping them as standard environment variables into Kubernetes pods across three sequential deployment steps. Please review these guidelines before contributing.

## Architecture Paradigm: HCP Terraform Workspaces

This project leverages standard Terraform configurations and uses HCP Terraform workspaces for remote execution and state management.

* **No Local State or CLI Applies:** Do not run `terraform apply` locally. All pushes to the main branch are evaluated and deployed by HCP Terraform natively via a VCS-driven workflow.
* **State Management:** Data sharing between distinct configurations relies on standard data sources or workspace output patterns where cross-workspace values are required.
* **Dynamic Credentials:** The project leverages dynamic provider credentials natively supported by Terraform Cloud/Enterprise.

## Development Workflow

1. **Fork & Branch:** Create a branch for your feature or bug fix.
2. **Write Code:** Modify the Terraform configurations following the numbered file naming convention (`1_`, `2_`, `3_` prefixes reflect the deployment step). Follow the styling guidelines in AGENTS.md.
3. **Preserve Deployment Order:** Changes to Step 1 resources (VPC, EKS, Vault namespace) must not introduce dependencies on Step 2 or Step 3 resources. Keep the `time_sleep` gates and `count = var.step_N ? 1 : 0` pattern intact.
4. **Preserve Secret Delivery Pattern:** Keep Vault secrets synchronized via the VSO `VaultStaticSecret` CRD into native Kubernetes Secrets, and consumed by the application as standard environment variables. Do not revert to CSI volume mounts or Vault Agent injection.
5. **Format:** Formatting checks are enforced by CI/CD. The `terraform.yml` workflow runs `terraform fmt` and pushes fixes automatically on pull requests.
6. **Open a Pull Request:** Fill out the provided PR template outlining your changes.

## Code Guidelines

* **Minimalism:** Favor readability and simplicity over highly complex abstractions.
* **Variable Descriptions:** Every variable must have a clear `description` and `type`. Prefix descriptions with `(Required)` or `(Optional)`.
* **Version Constraints:** Use the pessimistic operator (`~>`) for provider and module versions to ensure stability without strict lock-in. Pin the Terraform version using `required_version` in the `terraform` block.
* **Naming Conventions:** Use `snake_case` for all resource and variable names. Avoid including the resource type in the name (i.e., `resource "aws_eks_cluster" "main"`, not `resource "aws_eks_cluster" "eks_main"`).
* **Outputs:** Keep outputs alphabetical. Use concise factual descriptions without `(Required)`/`(Optional)` prefixes.

## Security Check

* Never commit `.terraform` folders, `.tfstate` files, or `.tfvars` files containing actual secrets.
* Never commit Vault tokens, AWS credentials, API keys, or any plaintext credentials.
* Access secrets securely via workspace variables. Set `sensitive = true` for sensitive variables across all definitions.

If you find a security vulnerability, please refer to our `SECURITY.md` for reporting procedures.

## Documentation

* **Auto-generated README:** Do not edit `README.md` directly. It is generated automatically by `terraform-docs` via GitHub Actions CI. To modify the README content, edit `docs/README_header.md` or `docs/README_footer.md` instead.
