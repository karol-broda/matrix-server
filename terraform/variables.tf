variable "hcloud_token" {
  description = "hetzner cloud api token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "cloudflare api token with dns edit permissions"
  type        = string
  sensitive   = true
}

variable "onepassword_account" {
  description = "1password account name or id (used with op cli)"
  type        = string
}

variable "onepassword_vault_id" {
  description = "1password vault uuid to store/retrieve secrets"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "cloudflare zone id for the domain"
  type        = string
}

variable "domain" {
  description = "base domain for the matrix server"
  type        = string
  default     = "karolbroda.com"
}

variable "server_name" {
  description = "hostname for the matrix server"
  type        = string
  default     = "matrix"
}

variable "server_type" {
  description = "hetzner server type"
  type        = string
  default     = "cx23"
}

variable "server_location" {
  description = "hetzner datacenter location (nbg1 = nuremberg)"
  type        = string
  default     = "nbg1"
}

variable "ssh_key_name" {
  description = "name for the ssh key in hetzner and 1password"
  type        = string
  default     = "matrix-server-key"
}

