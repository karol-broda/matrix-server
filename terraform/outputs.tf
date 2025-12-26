output "server_ipv4" {
  description = "public ipv4 address of the matrix server"
  value       = hcloud_server.matrix.ipv4_address
}

output "server_ipv6" {
  description = "public ipv6 address of the matrix server"
  value       = hcloud_server.matrix.ipv6_address
}

output "server_fqdn" {
  description = "fully qualified domain name of the matrix server"
  value       = "${var.server_name}.${var.domain}"
}

output "ssh_command" {
  description = "ssh command to connect to the server"
  value       = "ssh -i keys/${var.ssh_key_name} root@${hcloud_server.matrix.ipv4_address}"
}

output "nixos_anywhere_command" {
  description = "command to deploy nixos to the server"
  value       = "nix run github:nix-community/nixos-anywhere -- --flake .#matrix root@${hcloud_server.matrix.ipv4_address} -i keys/${var.ssh_key_name}"
}

