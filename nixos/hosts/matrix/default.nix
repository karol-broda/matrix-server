{sshPubKeys, ...}: let
  domain = "karolbroda.com";
  matrixDomain = "matrix.${domain}";
in {
  imports = [
    ./disk-config.nix
  ];

  system.stateVersion = "25.11";

  networking = {
    hostName = "matrix";
    firewall.enable = true;
    interfaces.enp1s0.ipv6.addresses = [{
      address = "2a01:4f8:1c1f:ae33::1";
      prefixLength = 64;
    }];
    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp1s0";
    };
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

    matrix = {
      enable = true;
      domain = matrixDomain;
      cinnyThemeCss = ./catppuccin-frappe.css;
      adminEmail = "admin+matrix@${domain}";
    };
  };

  services.caddy.globalConfig = ''
    email admin@${domain}
  '';
}
