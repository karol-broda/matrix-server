terraform {
  required_version = "= 1.14.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "= 1.50.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 5.4.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "= 2.1.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.0.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "= 2.5.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "onepassword" {
  account = var.onepassword_account
}

