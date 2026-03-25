{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.personal.matrix;

  cinnyConfig = pkgs.writeText "cinny-config.json" (builtins.toJSON {
    defaultHomeserver = 0;
    homeserverList = [cfg.domain];
    allowCustomHomeservers = true;
  });

  cinnyWithConfig = pkgs.runCommand "cinny-configured" {} ''
    mkdir -p $out
    cp -r ${pkgs.cinny}/* $out/
    chmod -R u+w $out
    cp ${cinnyConfig} $out/config.json

    if [ -n "${cfg.cinnyThemeCss}" ]; then
      cp ${cfg.cinnyThemeCss} $out/assets/custom-theme.css
      ${pkgs.gnused}/bin/sed -i 's|href="/assets/index-[^"]*\.css">|&\n    <link rel="stylesheet" href="/assets/custom-theme.css">|' $out/index.html
    fi
  '';
in {
  options.personal.matrix = {
    enable = lib.mkEnableOption "matrix homeserver with tuwunel";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain for the matrix server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6167;
      description = "internal port for tuwunel";
    };

    enableCinny = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "enable cinny web client";
    };

    cinnyThemeCss = lib.mkOption {
      type = lib.types.path;
      default = "";
      description = "path to custom css theme for cinny";
    };

    allowRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "allow open registration";
    };

    trustedServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["matrix.org"];
      description = "trusted servers for federation";
    };

    adminEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "admin email for /.well-known/matrix/support (MSC1929)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;

      virtualHosts = {
        "${cfg.domain}" = {
          extraConfig = ''
            reverse_proxy /_matrix/* localhost:${toString cfg.port}
            reverse_proxy /_conduwuit/* localhost:${toString cfg.port}

            header /.well-known/matrix/* Content-Type application/json
            header /.well-known/matrix/* Access-Control-Allow-Origin *

            respond /.well-known/matrix/server `{"m.server": "${cfg.domain}:443"}`
            respond /.well-known/matrix/client `{
              "m.homeserver": {"base_url": "https://${cfg.domain}"},
              "m.identity_server": {"base_url": "https://matrix.org"},
              "org.matrix.msc3575.proxy": {"url": "https://${cfg.domain}"}
            }`
            ${lib.optionalString (cfg.adminEmail != null) ''
              respond /.well-known/matrix/support `{"contacts":[{"email_address":"${cfg.adminEmail}","role":"m.role.admin"}]}`
            ''}

            ${lib.optionalString cfg.enableCinny ''
              root * ${cinnyWithConfig}
              file_server
            ''}
          '';
        };

        "${cfg.domain}:8448" = {
          extraConfig = ''
            reverse_proxy localhost:${toString cfg.port}
          '';
        };
      };
    };

    services.matrix-tuwunel = {
      enable = true;
      settings = {
        global = {
          server_name = cfg.domain;
          address = ["127.0.0.1" "::1"];
          port = [cfg.port];
          allow_registration = cfg.allowRegistration;
          allow_federation = true;
          allow_encryption = true;
          trusted_servers = cfg.trustedServers;
          max_request_size = 20000000;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [80 443 8448];
  };
}
