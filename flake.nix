{
  description = "personal infrastructure - hetzner servers and raspberry pis managed with nixos";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    nixos-hardware,
    sops-nix,
  }: let
    lib = nixpkgs.lib;

    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

    forAllSystems = lib.genAttrs supportedSystems;

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config = {
          allowUnfree = false;
          allowUnfreePredicate = pkg: let
            name = lib.getName pkg;
          in
            name == "terraform";
        };
      };

    mkHost = {
      name,
      system ? "x86_64-linux",
      profile ? "server",
      extraModules ? [],
      isPi ? false,
      useHardwareModule ? true,
    }: let
      sshPubKeyPath = ./keys/${name}-key.pub;
      sshPubKeys =
        if builtins.pathExists sshPubKeyPath
        then [(lib.strings.trim (builtins.readFile sshPubKeyPath))]
        else [];

      hardwareModules = lib.optionals (isPi && useHardwareModule) [
        nixos-hardware.nixosModules.raspberry-pi-4
      ];
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit sshPubKeys;};
        modules =
          [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./nixos/modules
            ./nixos/profiles/${profile}.nix
            ./nixos/hosts/${name}
          ]
          ++ hardwareModules ++ extraModules;
      };

    hosts = {
      matrix = {
        name = "matrix";
        system = "x86_64-linux";
        profile = "server";
      };

      desk = {
        name = "desk";
        system = "x86_64-linux";
        profile = "server";
      };

      hytale-kiosk = {
        name = "hytale-kiosk";
        system = "aarch64-linux";
        profile = "raspberry-pi";
        isPi = true;
      };
    };

    piHosts = lib.filterAttrs (_: cfg: cfg.isPi or false) hosts;

    mkSdImage = hostCfg: let
      config = mkHost hostCfg;
    in
      (config.extendModules {
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          {
            sdImage.compressImage = true;
            image.baseName = hostCfg.name;
          }
        ];
      }).config.system.build.sdImage;

    mkShell = system: let
      pkgs = mkPkgs system;
    in
      pkgs.mkShell {
        packages = with pkgs; [
          terraform
          nixos-anywhere
          rsync
          jq
          zstd
          alejandra
          sops
          age
          ssh-to-age
        ];

        shellHook = ''
          export PATH="$(git rev-parse --show-toplevel)/scripts:$PATH"

          if [ -n "''${ZSH_VERSION:-}" ]; then
            _matrix_hosts() {
              local hosts
              hosts=(${lib.concatStringsSep " " (builtins.attrNames hosts)})
              _describe 'hostname' hosts
            }

            compdef _matrix_hosts deploy rebuild ssh-to pi-build pi-flash pi-rebuild
          fi

          if [ -n "''${PS1:-}" ]; then
            echo "terraform: $(terraform -version | head -1)"
            echo ""
            echo "available: tf, deploy, rebuild, ssh-to, pi-build, pi-flash, pi-rebuild"
          fi
        '';
      };
  in {
    devShells = forAllSystems (system: {
      default = mkShell system;
    });

    nixosConfigurations = lib.mapAttrs (_: hostCfg: mkHost hostCfg) hosts;

    images = lib.mapAttrs (_: hostCfg: mkSdImage hostCfg) piHosts;

    formatter = forAllSystems (system: (mkPkgs system).alejandra);
  };
}
