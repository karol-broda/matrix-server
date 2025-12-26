{ pkgs, modulesPath, sshPubKey, ... }:

let
  domain = "karolbroda.com";
  matrixDomain = "matrix.${domain}";
  tuwunelPort = 6167;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
    kernelModules = [ "kvm-intel" ];
  };

  networking = {
    hostName = "matrix";
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22    # ssh
        80    # http (for acme)
        443   # https
        8448  # matrix federation
      ];
    };
  };

  time.timeZone = "UTC";

  users.users.root = {
    openssh.authorizedKeys.keys = [
      sshPubKey
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  services.caddy = {
    enable = true;
    globalConfig = ''
      email admin@${domain}
    '';

    virtualHosts = {
      # main matrix server endpoint
      "${matrixDomain}" = {
        extraConfig = ''
          reverse_proxy /_matrix/* localhost:${toString tuwunelPort}
          reverse_proxy /_conduwuit/* localhost:${toString tuwunelPort}

          header /.well-known/matrix/* Content-Type application/json
          header /.well-known/matrix/* Access-Control-Allow-Origin *

          respond /.well-known/matrix/server `{"m.server": "${matrixDomain}:443"}`
          respond /.well-known/matrix/client `{
            "m.homeserver": {"base_url": "https://${matrixDomain}"},
            "m.identity_server": {"base_url": "https://matrix.org"},
            "org.matrix.msc3575.proxy": {"url": "https://${matrixDomain}"}
          }`
        '';
      };

      # federation port - uses same cert as main domain (http challenge)
      "${matrixDomain}:8448" = {
        extraConfig = ''
          reverse_proxy localhost:${toString tuwunelPort}
        '';
      };
    };
  };

  services.matrix-tuwunel = {
    enable = true;
    settings = {
      global = {
        server_name = matrixDomain;
        address = [ "127.0.0.1" "::1" ];
        port = [ tuwunelPort ];
        allow_registration = false;
        allow_federation = true;
        allow_encryption = true;
        trusted_servers = [ "matrix.org" ];
        max_request_size = 20000000;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    xh
    jq
    ghostty.terminfo
  ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@${domain}";
  };
}

