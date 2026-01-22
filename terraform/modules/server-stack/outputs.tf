output "ipv4" {
  value = module.server.ipv4
}

output "ipv6" {
  value = module.server.ipv6
}

output "fqdn" {
  value = "${var.name}.${var.domain}"
}

output "ssh_private_key" {
  value     = module.server.ssh_private_key
  sensitive = true
}

output "ssh_public_key" {
  value = module.server.ssh_public_key
}

