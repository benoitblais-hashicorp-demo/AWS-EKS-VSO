<!-- BEGIN_TF_DOCS -->
# AWS EKS with Vault Secrets Operator Native Integration

## What this demo demonstrates

This demo provisions a production-oriented AWS environment to show how HashiCorp Vault secrets
can be delivered **natively into Kubernetes pods** via the Vault Secrets Operator (VSO)
— by syncing standard `Secret` objects mapped as environment variables.

## Demo Value Proposition

- Demonstrates **native Kubernetes Secret injection**: the Vault secret is synced to
  a `Secret` object in the Kubernetes API server and mapped to the application.
- Shows **Vault as the single source of truth**: secrets are maintained centrally in Vault
  and automatically synced to Kubernetes securely.
- Illustrates **automated secret rotation**: when a Vault secret is updated, VSO can
  natively perform a rollout restart on the deployment automatically to rapidly
  refresh the application.
- Provides a **reusable baseline** for enterprise patterns: dynamic Vault credentials, KV v2
  versioning, least-privilege Vault policies, and private EKS node placement.

## Demo Components

- **AWS Networking:** VPC with private/public subnets across multiple Availability Zones, Internet Gateway, and NAT-based outbound connectivity for EKS worker nodes.
- **Compute:** EKS cluster (v1.34) with a managed node group (t3.medium, 1–3 nodes) and core addons (CoreDNS, kube-proxy, VPC CNI, EKS Pod Identity Agent).
- **Ingress:** Nginx ingress controller backed by an internet-facing AWS Network Load Balancer (NLB) with 3 pre-allocated Elastic IPs.
- **Vault:** Isolated namespace, KV v2 mount (`webapp`), and static secret (`webapp/app/config`). Contains the Kubernetes auth backend wired to the EKS cluster using service account token review, plus required roles and policies.
- **Vault Secrets Operator (VSO):** Helm release v1.3.0 deployed with the native secrets integration.
- **Kubernetes Workload & RBAC:** Includes the Go web application deployment (`demo-webapp`, 3 replicas), ClusterIP service, and ingress rule. Configures a `vault-auth` service account, long-lived token secret, and `system:auth-delegator` cluster role binding.
- **VaultStaticSecret Custom Resource:** Maps the Vault KV v2 path to a native Kubernetes Secret, delivering secrets directly into pods as standard environment variables. VSO performs an automated rollout restart on the deployment when the secret rotates to seamlessly update the application.

## Secret Delivery Mechanism

### How Secrets Reach the Pod

The VSO native integration delivers secrets into Kubernetes Secret objects, which are mapped natively into the pod as environment variables. The flow is:

```text
Vault KV Secret
      │
      ▼
VSO reads secret using Kubernetes auth (service account JWT token)
      │
      ▼
VSO syncs secret data to a Kubernetes Secret (e.g., `webapp-config-secret`)
      │
      ▼
Pod maps Kubernetes Secret as environment variables
      │
      ▼
Application reads secret via standard environment variables (e.g., `$FIRST_MESSAGE`)
```

Key properties:

- **Kubernetes Secret objects are used.** The secret data enters the Kubernetes API server natively, enabling seamless integration with any deployment.
- **Secret data is mapped as environment variables.** The pod maps the secret directly via `valueFrom: secretKeyRef`.
- **Vault is the single source of truth.** Vault remains the origin of the secret data, while VSO acts as the bridging mechanism into standard Kubernetes workloads.

### VaultStaticSecret Custom Resource

The `VaultStaticSecret` custom resource (CRD installed by VSO) declares which Vault paths should be surfaced:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vso-secret
  namespace: demo-go-web-vso
spec:
  type: kv-v2
  mount: webapp
  path: app/config
  destination:
    create: true
    name: webapp-config-secret
  rolloutRestart:
    targets:
      - kind: Deployment
        name: demo-webapp
```

When the CR is created, VSO authenticates to Vault, retrieves the KV secret, creates the `webapp-config-secret` Kubernetes native Secret, and configures the automated rollout hook.

## Secret Rotation

### What Happens When a Secret is Rotated

When the Vault secret at `webapp/app/config` is updated (e.g., `message` field changed), the following sequence occurs:

1. **Vault stores the new secret version.** KV v2 retains previous versions; the new version becomes the current default.
2. **VSO detects the change.** The VSO operator continuously reconciles `VaultStaticSecret` resources and polls Vault for updates based on its refresh interval.
3. **VSO updates the Kubernetes Secret.** The updated secret data is synced into the native `webapp-config-secret` in the cluster.
4. **VSO triggers a Rollout Restart.** Because the `rolloutRestart` block is configured, VSO automatically tells the Kubernetes API to restart the `demo-webapp` deployment.
5. **New pods map the new environment variables.** The newly spawned pods start up with the environment variables pointing to the updated KV data.

## How this demo works

1. Terraform provisions the AWS VPC and the EKS cluster (Step 1).
2. Terraform creates a Vault namespace and a static KV v2 secret (`webapp/app/config`) with a
   `message` and `image_url` field (Step 1).
3. Terraform deploys the VSO Helm chart. The operator is ready to sync secrets (Step 2).
4. Terraform configures the Vault Kubernetes auth backend, pointing it at the EKS cluster API
   server and the `vault-auth` service account for token review (Step 2).
5. Terraform creates the `VaultStaticSecret` custom resource, which tells VSO which Vault path to expose
   and which namespace is authorised to consume it (Step 3).
6. Terraform deploys the Go web application. Each pod's spec references the Kubernetes Secret for environment variables:
   the application injects the native Kubernetes Secret via standard `valueFrom: secretKeyRef` configurations (Step 3).
7. The web application reads the standard environment variables and renders the `message` field on the demo page.

## How to Conduct the Demo

### Provisioning prerequisites

Before provisioning, configure the workspace with the required inputs:

1. Terraform variable `vault_address` (required).
2. Terraform variables `owner` and `repository` (optional, but highly recommended for resource tagging).
3. Terraform variable `doormat_username` (optional, but recommended to grant your AWS SSO role access to the EKS cluster).
4. HCP Terraform AWS Dynamic Provider Credentials enabled for the workspace (`TFC_AWS_PROVIDER_AUTH=true` and `TFC_AWS_RUN_ROLE_ARN` set).
5. HCP Terraform Vault provider authentication enabled with JWT/OIDC (`TFC_VAULT_PROVIDER_AUTH=true`).
6. Vault auth context variables set in the workspace (`TFC_VAULT_ADDR`, `TFC_VAULT_NAMESPACE`, `TFC_VAULT_RUN_ROLE`, and optional `TFC_VAULT_AUTH_PATH`).

After variables are configured, trigger runs from the workspace (VCS-driven) or via CLI-driven apply if your workflow uses local execution.

### Step 1 — Provision the infrastructure

1. Set `step_2 = false` and `step_3 = false` (default values).
2. Trigger Run #1.
3. Confirm the EKS cluster is healthy:
   - Open the **AWS Console → EKS → Clusters** and verify `<resources_prefix>-<random_id>-eks` (e.g. `vso-a1b2-eks`) shows **Active** status.
4. Confirm the Vault secret was created:
   - Open the **Vault UI** using the `vault_address` output.
   - Switch to the namespace shown in the `vault_namespace` output.
   - Navigate to **Secrets → webapp → app/config** and verify the secret exists.

### Step 2 — Deploy Kubernetes tooling

1. Set `step_2 = true` in the workspace variables.
2. Trigger Run #2.
3. Confirm the VSO pod is running:
   - Open the **AWS Console → EKS → Clusters → <resources\_prefix>-<random\_id>-eks** (e.g. `vso-a1b2-eks`).
   - Click the **Resources** tab → **Workloads → Pods**.
   - Filter by namespace `demo-go-web-vso` and verify a `vault-secrets-operator-*` pod shows **Running** status.
4. Confirm the Kubernetes Secrets:
   - In the same **Resources** tab, navigate to **Config and Secrets → Secrets**.
   - Verify the Kubernetes Secret `webapp-config-secret` appears in the list.

### Step 3 — Deploy the application

1. Set `step_3 = true` in the workspace variables.
2. Trigger Run #3.
3. Confirm all 3 replicas are ready:
   - Open the **AWS Console → EKS → Clusters → <resources\_prefix>-<random\_id>-eks**.
   - Click the **Resources** tab → **Workloads → Deployments**.
   - Filter by namespace `demo-go-web-vso` and verify `demo-webapp` shows **3/3** pods ready.
4. Open the demo website using the `website` Terraform output (e.g. `https://<demo_subdomain>.<public_hosted_zone>`).
5. The page displays the `message` value stored in Vault (`webapp/app/config`).

### Important behavior

- The step variables are not auto-updated by Terraform.
- You must change `step_2` and `step_3` manually at the workspace level.
- The full demo requires three separate runs in sequence.

### Walkthrough: Explaining the Configuration

Once the application is running, here is how you can explain the integration flow to your audience:

1. **Vault Policy (`2_vault_policy.tf`)**:
   - **Where:** Vault UI → Policies → `apps-policy`.
   - **What to say:** Explain that this policy grants read-only access strictly to the `webapp/*` path where the application's secret resides.
2. **Kubernetes Auth Method (`2_vault_kube.tf`)**:
   - **Where:** Vault UI → Access → `kubernetes` → Roles → `demo-go-web-vso`.
   - **What to say:** Explain how Vault is configured to trust the EKS cluster. Show the role that ties the `apps-policy` to the specific Kubernetes service account (`vault-auth`) and namespace (`demo-go-web-vso`), enforcing strict identity mapping.
3. **Vault Secrets Operator Helm Chart (`2_kube_vso.tf`)**:
   - **Where:** Terraform codebase (`2_kube_vso.tf`).
   - **What to say:** Highlight the `values.yaml` configuration mapping where the default Vault connection and auth method are configured.
4. **VaultStaticSecret Custom Resource (`3_kube_static_app.tf`)**:
   - **Where:** Terraform codebase (`3_kube_static_app.tf`).
   - **What to say:** Since the AWS EKS Console doesn't natively display Custom
     Resource instances, show the `kubernetes_manifest.vault_static_secret` block directly
     in your editor. Point out the `mount: webapp` and `path: app/config` mappings.
     Explain to the audience that this is the developer-facing manifest: they simply
     to fetch, without needing to know any Vault API logic.
5. **Pod Volume Mount (`3_kube_static_app.tf`)**:
   - **Where:** AWS Console → EKS → Clusters → `<resources_prefix>-<random_id>-eks` → Resources → Workloads → Pods → Select a `demo-webapp` pod → YAML / Raw view.
   - **What to say:** Scroll down to the `spec.containers.volumeMounts` block to
     highlight where the application mounts the ephemeral directory (`/var/run/secrets/vault`).
     Then, scroll down to the `spec.volumes` block to show how that specific volume
     Kubernetes Secret.
6. **No Kubernetes Secrets Generated**:
   - **Where:** AWS Console → EKS → Clusters → `<resources_prefix>-<random_id>-eks` → Resources → Config and secrets.
   - **What to say:** Filter by the `demo-go-web-vso` namespace. Prove to the audience that there are **no application secret objects** stored here. The only secrets present are standard Kubernetes service account tokens. The actual application secret remains entirely ephemeral.

### Secret Rotation Demo

This section walks through the deliberate secret rotation pattern that VSO enables.

#### Rotate the secret in Vault

1. Open the Vault UI using the `vault_address` output.
2. Switch to the namespace shown in the `vault_namespace` output.
3. Navigate to **Secrets > webapp > app/config** and click **Create new version**.
4. Change the `message` field to a new value (for example:
   `"Secret rotation in action — version 2!"`).
5. Save the new version.

#### Observe the behavior

1. Quickly reload the demo web application — the **original message is likely still displayed**. This is expected:
   environment variables are bound to the pod at startup and are not live-reloaded while the pod is running.
   Vault still holds the updated secret, but the running pod retains the prior version in its
   ephemeral volume.

#### Automated Pod Rotation

1. To remove the need for manual console access, this demo provisions a Kubernetes `CronJob` that executes a `kubectl rollout restart deployment/demo-webapp` every 3 minutes.
2. Wait for up to 3 minutes to allow the CronJob to trigger.
3. As the deployment rolls over and replacement pods start, VSO re-authenticates to Vault, reads
   the current secret version, and injects the new data into the pod's ephemeral volume.
4. Reload the demo web application — the **new message from Vault is now displayed**.

#### What this demonstrates

- The pod lifecycle controls the rotation window, giving operators a deliberate and auditable
  change boundary.
- Vault KV v2 retains the prior version; rolling back is as simple as re-pinning the secret
  version in the `VaultStaticSecret` resource and restarting pods.

## Permissions

### AWS Permissions

To provision the AWS resources managed by this code, the IAM role or user running Terraform
needs the following permissions:

- `acm:RequestCertificate` / `acm:DeleteCertificate` / `acm:DescribeCertificate` / `acm:AddTagsToCertificate`
- `ec2:DescribeAvailabilityZones`
- `ec2:DescribeImages`
- `ec2:DescribeVpcs`
- `ec2:CreateVpc` / `ec2:DeleteVpc`
- `ec2:CreateSubnet` / `ec2:DeleteSubnet`
- `ec2:CreateRouteTable` / `ec2:DeleteRouteTable`
- `ec2:CreateRoute` / `ec2:DeleteRoute`
- `ec2:AssociateRouteTable` / `ec2:DisassociateRouteTable`
- `ec2:CreateInternetGateway` / `ec2:AttachInternetGateway` / `ec2:DeleteInternetGateway`
- `ec2:AllocateAddress` / `ec2:ReleaseAddress`
- `ec2:CreateNatGateway` / `ec2:DeleteNatGateway`
- `ec2:CreateSecurityGroup` / `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress` / `ec2:RevokeSecurityGroupIngress`
- `ec2:AuthorizeSecurityGroupEgress` / `ec2:RevokeSecurityGroupEgress`
- `ec2:CreateTags` / `ec2:DeleteTags`
- `ec2:DescribeInstances` / `ec2:DescribeInstanceTypes`
- `ec2:DescribeNetworkInterfaces`
- `eks:CreateCluster` / `eks:DeleteCluster` / `eks:DescribeCluster`
- `eks:CreateNodegroup` / `eks:DeleteNodegroup` / `eks:DescribeNodegroup`
- `eks:CreateAddon` / `eks:DeleteAddon` / `eks:DescribeAddon`
- `eks:CreateAccessEntry` / `eks:DeleteAccessEntry` / `eks:AssociateAccessPolicy`
- `eks:TagResource` / `eks:UntagResource`
- `iam:CreateRole` / `iam:DeleteRole` / `iam:GetRole` / `iam:PassRole`
- `iam:CreatePolicy` / `iam:DeletePolicy` / `iam:GetPolicy` / `iam:GetPolicyVersion`
- `iam:AttachRolePolicy` / `iam:DetachRolePolicy`
- `iam:CreateInstanceProfile` / `iam:DeleteInstanceProfile` / `iam:GetInstanceProfile`
- `iam:AddRoleToInstanceProfile` / `iam:RemoveRoleFromInstanceProfile`
- `kms:CreateKey` / `kms:DescribeKey` / `kms:CreateAlias` / `kms:DeleteAlias`
- `kms:EnableKeyRotation` / `kms:GetKeyPolicy` / `kms:PutKeyPolicy`
- `kms:ScheduleKeyDeletion`
- `route53:ChangeResourceRecordSets` / `route53:GetChange` / `route53:ListHostedZones` / `route53:GetHostedZone`

### Vault Permissions

The Vault token or dynamic credential used by Terraform must have the following capabilities:

- Create and manage namespaces (`sys/namespaces/*`).
- Enable and configure secret engines (`sys/mounts/*`).
- Create and update KV v2 secrets (`<namespace>/webapp/*`).
- Enable and configure the Kubernetes auth backend (`sys/auth/*`, `auth/kubernetes/*`).
- Create and manage Vault policies (`sys/policies/acl/*`).

## Authentications

### AWS Authentication

#### HCP Terraform / Terraform Enterprise Dynamic Credentials (OIDC)

Use dynamic provider credentials via OpenID Connect (OIDC) for secure, short-lived credentials when running in HCP Terraform or Terraform Enterprise.

- **Using environment variables (HCP Terraform Workspace)**
  - `TFC_AWS_PROVIDER_AUTH=true`
  - `TFC_AWS_RUN_ROLE_ARN=<your_aws_iam_role_arn>`

Documentation:

- [Dynamic Provider Credentials in HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)

#### [Environment Variables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#environment-variables)

Credentials can be provided by using the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `AWS_SESSION_TOKEN` environment variables. The Region can be set using the `AWS_REGION` or `AWS_DEFAULT_REGION` environment variables.

For example:

```hcl
provider "aws" {}
```

```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_REGION="us-west-2"
terraform plan
```

Documentation:

- [AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication)

### Vault Authentication

#### Static Token

Use environment variables to authenticate with a static Vault token:

- `VAULT_ADDR`: Set to your HCP Vault Dedicated cluster address (e.g., `https://my-cluster.vault.hashicorp.cloud:8200`).
- `VAULT_TOKEN`: Set to a valid Vault token with the permissions listed above.
- `VAULT_NAMESPACE`: Set to the parent namespace (e.g., `admin`) if applicable.

Documentation:

- [Vault Provider Documentation](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)

#### HCP Terraform Dynamic Credentials (Recommended)

For enhanced security, use HCP Terraform's dynamic provider credentials to authenticate to Vault without storing static tokens.
This method uses workload identity (JWT/OIDC) to generate short-lived Vault tokens automatically.

- `TFC_VAULT_PROVIDER_AUTH`: Set to `true`.
- `TFC_VAULT_ADDR`: Set to your HCP Vault Dedicated cluster address.
- `TFC_VAULT_NAMESPACE`: Set to the parent namespace.
- `TFC_VAULT_RUN_ROLE`: Set to the JWT role name configured in Vault.

Documentation:

- [HCP Terraform Dynamic Credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)
- [Vault JWT Auth Method](https://developer.hashicorp.com/vault/docs/auth/jwt)

## Troubleshooting & Known Issues

- **Vault Enterprise Validation Errors:** The Vault Secrets Operator requires Vault to function and hard-validates this
  requirement by querying the `/sys/license/status` endpoint. If your pod's Vault policy does not grant `read` capability
  to this endpoint, the volume mount will throw a `vault enterprise client validation failed` error, completely blocking Pod scheduling.
- **Invalid Audience / Issuer Claims:** When mapping the Vault Kubernetes Auth backend against an EKS cluster, avoid hardcoding
  the `audience = "vault"` constraint on the role and set `disable_iss_validation = true` on the backend config. Short-lived
  Service Account tokens generated natively by EKS often omit specific audiences and rotate dynamic OIDC issuers, causing 403 Forbidden
  errors if strict matching is enforced.
- **Vault 403 Permission Denied during Token Review:** When mapping the Vault Kubernetes Auth backend inside an HCP Vault
  dedicated namespace, ensure that the `VaultAuth` custom resource refers to the Vault namespace using the **Namespace ID**
  instead of the FQDN path. Using the full namespace path generates a 403 error due to token evaluation logic.

## Documentation

## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (~> 6.0)

- <a name="requirement_helm"></a> [helm](#requirement\_helm) (3.1.1)

- <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) (3.0.1)

- <a name="requirement_random"></a> [random](#requirement\_random) (3.8.1)

- <a name="requirement_time"></a> [time](#requirement\_time) (0.13.1)

- <a name="requirement_vault"></a> [vault](#requirement\_vault) (5.8.0)

## Modules

The following Modules are called:

### <a name="module_eks"></a> [eks](#module\_eks)

Source: terraform-aws-modules/eks/aws

Version: 21.15.1

### <a name="module_vpc"></a> [vpc](#module\_vpc)

Source: terraform-aws-modules/vpc/aws

Version: ~> 5.16

## Required Inputs

The following input variables are required:

### <a name="input_vault_address"></a> [vault\_address](#input\_vault\_address)

Description: (Required) Full URL of the HashiCorp Vault cluster (for example `https://vault.example.com:8200`). Used by the Vault Secrets Operator VaultConnection custom resource.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_TFC_PROJECT_NAME"></a> [TFC\_PROJECT\_NAME](#input\_TFC\_PROJECT\_NAME)

Description: (Optional) Automatically populated by Terraform Cloud. Corresponds to the cdl-ddr-project tag in AWS.

Type: `string`

Default: `"local-project"`

### <a name="input_TFC_WORKSPACE_NAME"></a> [TFC\_WORKSPACE\_NAME](#input\_TFC\_WORKSPACE\_NAME)

Description: (Optional) Automatically populated by Terraform Cloud. Corresponds to the cdl-ddr-workspace-slug tag in AWS.

Type: `string`

Default: `"local-workspace"`

### <a name="input_customer_name"></a> [customer\_name](#input\_customer\_name)

Description: (Optional) Corresponds to the cdl-customer-name tag in AWS.

Type: `string`

Default: `"hashicat"`

### <a name="input_demo_subdomain"></a> [demo\_subdomain](#input\_demo\_subdomain)

Description: (Optional) The subdomain to prepend to the public\_hosted\_zone for the application (e.g., 'vso-demo').

Type: `string`

Default: `"vso-demo"`

### <a name="input_demo_webapp_image"></a> [demo\_webapp\_image](#input\_demo\_webapp\_image)

Description: (Optional) The container image reference for the demo web application.

Type: `string`

Default: `"ghcr.io/benoitblais-hashicorp-demo/demo-go-web-vso:v1.2.0"`

### <a name="input_doormat_username"></a> [doormat\_username](#input\_doormat\_username)

Description: (Optional) Doormat username used to construct the IAM developer role ARN for EKS cluster access and KMS key administration (e.g. firstname.lastname\_company). Leave empty to skip adding the doormat role as a KMS key administrator and EKS access entry.

Type: `string`

Default: `""`

### <a name="input_environment"></a> [environment](#input\_environment)

Description: (Optional) Corresponds to the environment tag in AWS.

Type: `string`

Default: `"dev"`

### <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type)

Description: (Optional) EC2 instance type for the EKS managed node group.

Type: `string`

Default: `"t3.medium"`

### <a name="input_owner"></a> [owner](#input\_owner)

Description: (Optional) Owner identifier (e.g., email) used for tagging.

Type: `string`

Default: `"user@example.com"`

### <a name="input_public_hosted_zone"></a> [public\_hosted\_zone](#input\_public\_hosted\_zone)

Description: (Optional) The Route 53 public hosted zone name (e.g., 'example.com') where DNS validation and A records will be published. If set, an ACM certificate will be provisioned directly on the NGINX Network Load Balancer.

Type: `string`

Default: `"benoit-blais.sbx.hashidemos.io"`

### <a name="input_region"></a> [region](#input\_region)

Description: (Optional) AWS region where all resources are provisioned.

Type: `string`

Default: `"ca-central-1"`

### <a name="input_repository"></a> [repository](#input\_repository)

Description: (Optional) The URL of the repository where the codebase resides.

Type: `string`

Default: `"github.com/hashicorp/terraform-demo"`

### <a name="input_resources_prefix"></a> [resources\_prefix](#input\_resources\_prefix)

Description: (Optional) Prefix applied to all resources.

Type: `string`

Default: `"vso"`

### <a name="input_salesforce_opportunity_id"></a> [salesforce\_opportunity\_id](#input\_salesforce\_opportunity\_id)

Description: (Optional) Corresponds to the salesforce\_id tag in AWS.

Type: `string`

Default: `"N/A"`

### <a name="input_step_2"></a> [step\_2](#input\_step\_2)

Description: (Optional) Set to true after Step 1 completes successfully. Deploys Kubernetes tooling: nginx ingress, Vault Secrets Operator, Vault Kubernetes auth backend, and RBAC resources.

Type: `bool`

Default: `false`

### <a name="input_step_3"></a> [step\_3](#input\_step\_3)

Description: (Optional) Set to true after Step 2 completes successfully. Deploys the VaultStaticSecret custom resource and the demo Go web application. Requires step\_2 = true.

Type: `bool`

Default: `false`

### <a name="input_uptycs_tags"></a> [uptycs\_tags](#input\_uptycs\_tags)

Description: (Optional) Comma-separated Uptycs tags in UPDATE/CCODE/UT/OWNER format.

Type: `string`

Default: `"UPDATE/PROD,CCODE/HashiCorp,UT/20A7V,OWNER/owner-email@hashicorp.com"`

### <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr)

Description: (Optional) IPv4 CIDR block for the AWS VPC.

Type: `string`

Default: `"10.1.0.0/16"`

## Resources

The following resources are used by this module:

- [aws_acm_certificate.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) (resource)
- [aws_acm_certificate_validation.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) (resource)
- [aws_eip.nginx_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) (resource)
- [aws_route53_record.public_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) (resource)
- [aws_route53_record.web_dns_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) (resource)
- [helm_release.nginx_ingress](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [helm_release.uptycs_edr](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [helm_release.vault_secrets_operator](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [kubernetes_cluster_role_binding_v1.vault](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/cluster_role_binding_v1) (resource)
- [kubernetes_deployment_v1.demo_webapp](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/deployment_v1) (resource)
- [kubernetes_ingress_v1.apps](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/ingress_v1) (resource)
- [kubernetes_manifest.vault_static_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/manifest) (resource)
- [kubernetes_namespace_v1.demo_app](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/namespace_v1) (resource)
- [kubernetes_namespace_v1.edr](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/namespace_v1) (resource)
- [kubernetes_namespace_v1.ingress_nginx](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/namespace_v1) (resource)
- [kubernetes_secret_v1.vault_token](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/secret_v1) (resource)
- [kubernetes_service_account_v1.vault](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/service_account_v1) (resource)
- [kubernetes_service_v1.demo_webapp](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/service_v1) (resource)
- [random_string.identifier](https://registry.terraform.io/providers/hashicorp/random/3.8.1/docs/resources/string) (resource)
- [time_sleep.eip_wait](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) (resource)
- [time_sleep.step_2](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) (resource)
- [time_sleep.step_3](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) (resource)
- [vault_auth_backend.kube_auth](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/auth_backend) (resource)
- [vault_generic_secret.webapp_config](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/generic_secret) (resource)
- [vault_kubernetes_auth_backend_config.kube_auth_cfg](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/kubernetes_auth_backend_config) (resource)
- [vault_kubernetes_auth_backend_role.demo_app_role](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/kubernetes_auth_backend_role) (resource)
- [vault_mount.webapp](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/mount) (resource)
- [vault_namespace.namespace](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/namespace) (resource)
- [vault_policy.apps_policy](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/policy) (resource)
- [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) (data source)
- [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) (data source)
- [aws_ec2_instance_type_offerings.supported](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type_offerings) (data source)
- [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) (data source)
- [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) (data source)
- [aws_route53_zone.demo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) (data source)

## Outputs

The following outputs are exported:

### <a name="output_vault_address"></a> [vault\_address](#output\_vault\_address)

Description: Vault UI address for this demo

### <a name="output_vault_namespace"></a> [vault\_namespace](#output\_vault\_namespace)

Description: Vault namespace scoped to this demo deployment

### <a name="output_website"></a> [website](#output\_website)

Description: Public URL of the VSO demo web application (available after step\_3 = true)

<!-- markdownlint-enable -->
<!-- END_TF_DOCS -->