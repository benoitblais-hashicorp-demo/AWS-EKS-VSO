# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# AWS DNS AND TLS CERTIFICATE MANAGEMENT
# ==============================================================================
# This file provisions the public DNS records and TLS certificates required for
# exposing the Kubernetes-hosted application to the internet securely. It requests
# an ACM certificate for the demo application, validates it via Route53, and 
# maps the subdomain to the NGINX Ingress Network Load Balancer (NLB) IPs.
# This execution is gated by the step_2 and public_hosted_zone variables.
# ==============================================================================

# ------------------------------------------------------------------------------
# ROUTE53 ZONE DATA DISCOVERY
# ------------------------------------------------------------------------------

# 1. Retrieve the Route53 Hosted Zone where our public DNS records will be published
data "aws_route53_zone" "demo" {
  count = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  name  = var.public_hosted_zone
}

# ------------------------------------------------------------------------------
# TLS CERTIFICATE PROVISIONING & VALIDATION (ACM)
# ------------------------------------------------------------------------------

# 2. Request a public TLS certificate in AWS Certificate Manager (ACM) for the application
resource "aws_acm_certificate" "public" {
  count             = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  domain_name       = "${var.demo_subdomain}.${var.public_hosted_zone}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# 3. Publish the DNS validation records provided by ACM into the Route53 zone
resource "aws_route53_record" "public_validation" {
  for_each = var.step_2 && var.public_hosted_zone != "" ? {
    for dvo in aws_acm_certificate.public[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  zone_id = data.aws_route53_zone.demo[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]

  allow_overwrite = true
}

# 4. Wait for AWS Certificate Manager to verify the DNS records and issue the certificate
resource "aws_acm_certificate_validation" "public" {
  count                   = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for record in aws_route53_record.public_validation : record.fqdn]
}

# ------------------------------------------------------------------------------
# APPLICATION DNS MAPPING
# ------------------------------------------------------------------------------

# 5. Map the public demo subdomain directly to the pre-allocated NGINX Ingress Elastic IPs
resource "aws_route53_record" "web_dns_record" {
  count   = var.step_2 && var.public_hosted_zone != "" ? 1 : 0
  zone_id = data.aws_route53_zone.demo[0].zone_id
  name    = "${var.demo_subdomain}.${var.public_hosted_zone}"
  type    = "A"
  ttl     = 300
  # Directly resolving the pre-allocated EIPs attached to the NLB!
  records = aws_eip.nginx_ingress[*].public_ip
}
