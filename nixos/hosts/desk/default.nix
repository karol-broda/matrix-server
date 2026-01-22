{
  sshPubKeys,
  config,
  ...
}: let
  domain = "karolbroda.com";
  deskDomain = "desk.${domain}";
  authDomain = "auth.${domain}";
in {
  imports = [
    ./disk-config.nix
  ];

  system.stateVersion = "25.11";

  sops = {
    defaultSopsFile = ../../../secrets/desk.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    secrets = {
      netbird_encryption_key = {
        mode = "0440";
      };
      netbird_coturn_password = {
        owner = "turnserver";
        mode = "0400";
      };
      pocketid_encryption_key = {
        mode = "0440";
      };
    };
  };

  networking = {
    hostName = "desk";
    firewall.enable = true;
  };

  personal = {
    ssh = {
      enable = true;
      authorizedKeys = sshPubKeys;
    };

    acme = {
      enable = true;
      email = "admin@${domain}";
    };

    firefly = {
      enable = true;
      domain = "firefly.${deskDomain}";
    };

    memos = {
      enable = true;
      domain = "memos.${deskDomain}";
    };

    affine = {
      enable = true;
      domain = "affine.${deskDomain}";
    };

    pocketid = {
      enable = true;
      domain = authDomain;
      encryptionKeyFile = config.sops.secrets.pocketid_encryption_key.path;
      appName = "karolbroda.com";
      accentColor = "#ca9ee6";
      sessionDuration = 1440;
      allowSignups = "disabled";
    };

    netbird = {
      enable = true;
      domain = "vpn.${domain}";

      dataStoreEncryptionKeyFile = config.sops.secrets.netbird_encryption_key.path;

      coturn = {
        enable = true;
        passwordFile = config.sops.secrets.netbird_coturn_password.path;
      };

      singleAccountModeDomain = domain;

      oidc = {
        configEndpoint = "https://${authDomain}/.well-known/openid-configuration";
        clientId = "fc2afc30-81ed-4d1e-9d0f-a6216798326c";
        audience = "fc2afc30-81ed-4d1e-9d0f-a6216798326c";
      };
    };
  };

  services.caddy.globalConfig = ''
    email admin@${domain}
  '';

  systemd.services.netbird-management = {
    after = ["podman-pocketid.service"];
    wants = ["podman-pocketid.service"];
  };
}
