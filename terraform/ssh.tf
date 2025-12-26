resource "tls_private_key" "matrix_server" {
  algorithm = "ED25519"
}

# store ssh private key in 1password
resource "onepassword_item" "ssh_private_key" {
  vault    = var.onepassword_vault_id
  title    = "${var.ssh_key_name}-private"
  category = "secure_note"

  section {
    label = "SSH Key"

    field {
      label = "private_key"
      type  = "CONCEALED"
      value = tls_private_key.matrix_server.private_key_openssh
    }

    field {
      label = "public_key"
      type  = "STRING"
      value = tls_private_key.matrix_server.public_key_openssh
    }

    field {
      label = "server_ip"
      type  = "STRING"
      value = hcloud_server.matrix.ipv4_address
    }

    field {
      label = "server_fqdn"
      type  = "STRING"
      value = "${var.server_name}.${var.domain}"
    }
  }
}

# register ssh public key with hetzner
resource "hcloud_ssh_key" "matrix_server" {
  name       = var.ssh_key_name
  public_key = tls_private_key.matrix_server.public_key_openssh
}

# save private key locally for nixos-anywhere deployment
resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.matrix_server.private_key_openssh
  filename        = "${path.module}/../keys/${var.ssh_key_name}"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.matrix_server.public_key_openssh
  filename        = "${path.module}/../keys/${var.ssh_key_name}.pub"
  file_permission = "0644"
}

