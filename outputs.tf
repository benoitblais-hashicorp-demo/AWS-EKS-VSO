# Copyright IBM Corp. 2024, 2026

output "vault_address" {
  description = "Vault UI address for this demo"
  value       = var.vault_address
}

output "vault_namespace" {
  description = "Vault namespace scoped to this demo deployment"
  value       = replace(vault_namespace.namespace.id, "admin/", "")
}

output "website" {
  description = "Public URL of the VSO demo web application (available after step_3 = true)"
  value       = var.step_2 && var.step_3 ? (var.public_hosted_zone != "" ? "https://${var.demo_subdomain}.${var.public_hosted_zone}" : "http://${try(data.kubernetes_service_v1.nginx_ingress[0].status[0].load_balancer[0].ingress[0].hostname, "load-balancer-pending")}") : ""
}
