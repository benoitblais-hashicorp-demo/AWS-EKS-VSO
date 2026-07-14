# Copyright IBM Corp. 2024, 2026

# Disabled variables. For more information see https://hashicorp.atlassian.net/browse/VCDLD-464

# variable "tfc_vault_dynamic_credentials" {
#   description = "Object containing Vault dynamic credentials configuration"
#   type = object({
#     default = object({
#       token_filename = string
#       address        = string
#       namespace      = string
#       ca_cert_file   = string
#     })
#     aliases = map(object({
#       token_filename = string
#       address        = string
#       namespace      = string
#       ca_cert_file   = string
#     }))
#   })
#   default = {
#     default = {
#       token_filename = ""
#       address        = ""
#       namespace      = ""
#       ca_cert_file   = ""
#     }
#     aliases = {}
#   }
# }

# variable "tfc_aws_dynamic_credentials" {
#   description = "Object containing AWS dynamic credentials configuration"
#   type = object({
#     default = object({
#       shared_config_file = string
#     })
#     aliases = map(object({
#       shared_config_file = string
#     }))
#   })
#   default = {
#     default = {
#       shared_config_file = ""
#     }
#     aliases = {
#       default = {
#         shared_config_file = ""
#       }
#     }
#   }
# }
