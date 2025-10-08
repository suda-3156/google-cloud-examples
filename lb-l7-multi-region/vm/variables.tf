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

variable "ssh_access_source_ranges" {
  type    = list(string)
  default = []
}

variable "ssh_access_members" {
  type    = list(string)
  default = []
}
