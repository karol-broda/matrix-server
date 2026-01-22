module "server" {
  source = "../server"

  name        = var.name
  server_type = var.server_type
  location    = var.location
  labels      = var.labels
}

module "dns" {
  source = "../dns"

  zone_id       = var.cloudflare_zone_id
  domain        = var.domain
  name          = var.name
  create_a      = var.create_a
  create_aaaa   = var.create_aaaa
  ipv4          = module.server.ipv4
  ipv6          = module.server.ipv6
  extra_records = var.extra_dns_records
}

module "onepassword" {
  source = "../onepassword-ssh"

  vault_id    = var.onepassword_vault_id
  name        = "${var.name}-key"
  private_key = module.server.ssh_private_key
  public_key  = module.server.ssh_public_key
  server_ip   = module.server.ipv4
  server_fqdn = "${var.name}.${var.domain}"
}

