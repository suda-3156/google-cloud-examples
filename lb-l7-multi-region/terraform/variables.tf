variable "project_id_prefix" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "regions" {
  type = list(string)
}

variable "billing_account_id" {
  type = string
}

# load balancer
variable "lb_ssl_domains" {
  type = list(string)
}
