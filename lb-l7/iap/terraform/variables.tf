variable "project_id_prefix" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "region" {
  type = string
}

variable "billing_account_id" {
  type = string
}

# load balancer
variable "lb_ssl_domains" {
  type = list(string)
}

# IAP
variable "iap_enabled" {
  type        = bool
  default     = false
}

variable "iap_oauth2_client_id" {
  description = "OAuth 2.0 Client ID for IAP"
  type        = string
}

variable "iap_oauth2_client_secret" {
  description = "OAuth 2.0 Client Secret for IAP"
  type        = string
}

# For details, see https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_iam#member/members-1
variable "allowed_iap_members" {
  description = "Members allowed to access the IAP-protected resources. e.g. ['domain:example.com', 'user:example@example.com']"
  type        = list(string)
}
