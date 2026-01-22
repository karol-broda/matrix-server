locals {
  domain           = "karolbroda.com"
  default_location = "nbg1"

  servers = {
    matrix = {
      server_type = "cx23"
      labels      = { purpose = "matrix" }
      dns = {
        extra = [
          {
            name = "_matrix._tcp.matrix"
            type = "SRV"
            data = {
              priority = 10
              weight   = 5
              port     = 8448
              target   = "matrix.karolbroda.com"
            }
          }
        ]
      }
    }

    desk = {
      server_type = "cx23"
      labels      = { purpose = "desk" }
      dns = {
        extra = [
          {
            name    = "firefly.desk"
            type    = "CNAME"
            content = "desk.karolbroda.com"
          },
          {
            name    = "memos.desk"
            type    = "CNAME"
            content = "desk.karolbroda.com"
          },
          {
            name    = "affine.desk"
            type    = "CNAME"
            content = "desk.karolbroda.com"
          },
          {
            name    = "vpn"
            type    = "CNAME"
            content = "desk.karolbroda.com"
          },
          {
            name    = "auth"
            type    = "CNAME"
            content = "desk.karolbroda.com"
          }
        ]
      }
    }
  }
}
