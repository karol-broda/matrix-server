# matrix server

matrix homeserver running tuwunel on nixos, deployed to hetzner cloud via terraform.

## setup

1. copy and configure terraform variables:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform/terraform.tfvars with your values
```

2. initialize and apply terraform:

```bash
cd terraform
tf init
tf plan
tf apply
```

3. deploy nixos to the server:

```bash
deploy
```

## configuration

- **domain**: karolbroda.com
- **matrix server**: matrix.karolbroda.com
- **server type**: cx23 (2vcpu, 4gb ram)
- **location**: nbg1 (nuremberg)

## services

- **tuwunel**: matrix homeserver
- **caddy**: reverse proxy with automatic tls
