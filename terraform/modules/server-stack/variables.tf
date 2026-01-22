variable "name" {
  description = "server name"
  type        = string
}

variable "server_type" {
  description = "hetzner server type"
  type        = string
}

variable "location" {
  description = "hetzner datacenter location"
  type        = string
}

variable "labels" {
  description = "server labels"
  type        = map(string)
  default     = {}
}

variable "domain" {
  description = "base domain"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "cloudflare zone id"
  type        = string
}

variable "onepassword_vault_id" {
  description = "1password vault id"
  type        = string
}

variable "create_a" {
  description = "whether to create an A record"
  type        = bool
  default     = true
}

variable "create_aaaa" {
  description = "whether to create an AAAA record"
  type        = bool
  default     = true
}

variable "extra_dns_records" {
  description = "additional dns records"
  type = list(object({
    name    = string
    type    = string
    content = optional(string)
    data    = optional(map(any))
    ttl     = optional(number, 300)
    proxied = optional(bool, false)
  }))
  default = []
}

