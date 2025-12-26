# main server record
resource "cloudflare_dns_record" "matrix_a" {
  zone_id = var.cloudflare_zone_id
  name    = var.server_name
  content = hcloud_server.matrix.ipv4_address
  type    = "A"
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "matrix_aaaa" {
  zone_id = var.cloudflare_zone_id
  name    = var.server_name
  content = hcloud_server.matrix.ipv6_address
  type    = "AAAA"
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "matrix_srv" {
  zone_id = var.cloudflare_zone_id
  name    = "_matrix._tcp.${var.server_name}"
  type    = "SRV"
  ttl     = 300
  data = {
    priority = 10
    weight   = 5
    port     = 8448
    target   = "${var.server_name}.${var.domain}"
  }
}


