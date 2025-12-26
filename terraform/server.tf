resource "hcloud_server" "matrix" {
  name        = var.server_name
  image       = "debian-12"
  server_type = var.server_type
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.matrix_server.id]

  labels = {
    purpose = "matrix"
    managed = "terraform"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

