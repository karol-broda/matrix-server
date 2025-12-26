{
  description = "matrix server with tuwunel and caddy on hetzner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko }:
    let
      lib = nixpkgs.lib;

      mkPkgs = system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = false;
            allowUnfreePredicate = pkg:
              let name = lib.getName pkg;
              in name == "terraform";
          };
        };

      mkShellFor = system:
        let
          pkgs = mkPkgs system;
        in
        pkgs.mkShell {
          packages = with pkgs; [
            terraform
            nixos-anywhere
            rsync
            (writeShellScriptBin "tf" ''
              #!/usr/bin/env bash
              set -euo pipefail
              exec "${lib.getExe pkgs.terraform}" "$@"
            '')
            (writeShellScriptBin "deploy" ''
              #!/usr/bin/env bash
              set -euo pipefail
              cd "$(git rev-parse --show-toplevel)"
              
              if [ ! -f terraform/terraform.tfstate ]; then
                echo "error: terraform state not found. run 'tf apply' first."
                exit 1
              fi
              
              SERVER_IP=$(cd terraform && terraform output -raw server_ipv4)
              SSH_KEY="keys/matrix-server-key"
              
              if [ ! -f "$SSH_KEY" ]; then
                echo "error: ssh key not found at $SSH_KEY"
                exit 1
              fi
              
              echo "deploying nixos to $SERVER_IP..."
              nix run github:nix-community/nixos-anywhere -- \
                --flake ".#matrix" \
                "root@$SERVER_IP" \
                -i "$SSH_KEY"
            '')
            (writeShellScriptBin "ssh-matrix" ''
              #!/usr/bin/env bash
              set -euo pipefail
              cd "$(git rev-parse --show-toplevel)"
              
              SERVER_IP=$(cd terraform && terraform output -raw server_ipv4 2>/dev/null || echo "")
              if [ -z "$SERVER_IP" ]; then
                echo "error: could not get server ip. run 'tf apply' first."
                exit 1
              fi
              
              exec ssh -4 -i keys/matrix-server-key -o IdentitiesOnly=yes "root@$SERVER_IP" "$@"
            '')
            (writeShellScriptBin "rebuild" ''
              #!/usr/bin/env bash
              set -euo pipefail
              cd "$(git rev-parse --show-toplevel)"
              
              SERVER_IP=$(cd terraform && terraform output -raw server_ipv4 2>/dev/null || echo "")
              if [ -z "$SERVER_IP" ]; then
                echo "error: could not get server ip. run 'tf apply' first."
                exit 1
              fi
              
              SSH_KEY="keys/matrix-server-key"
              SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
              
              echo "copying configuration to server..."
              ${pkgs.rsync}/bin/rsync -avz --delete \
                --filter=':- .gitignore' \
                --exclude='.git' \
                --exclude='terraform' \
                --exclude='keys/matrix-server-key' \
                --exclude='.direnv' \
                -e "ssh $SSH_OPTS" \
                . "root@$SERVER_IP:/etc/nixos/"
              
              echo "rebuilding nixos..."
              ssh $SSH_OPTS "root@$SERVER_IP" "cd /etc/nixos && nixos-rebuild switch --flake .#matrix"
            '')
          ];

          shellHook = ''
            if [ -n "''${PS1:-}" ]; then
              echo "terraform: $(terraform -version | head -1)"
            fi
          '';
        };
    in
    {
      devShells.x86_64-linux.default = mkShellFor "x86_64-linux";
      devShells.aarch64-linux.default = mkShellFor "aarch64-linux";
      devShells.x86_64-darwin.default = mkShellFor "x86_64-darwin";
      devShells.aarch64-darwin.default = mkShellFor "aarch64-darwin";

      nixosConfigurations.matrix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          sshPubKey = builtins.readFile ./keys/matrix-server-key.pub;
        };
        modules = [
          disko.nixosModules.disko
          ./nixos/configuration.nix
        ];
      };
    };
}
