{
  config,
  lib,
  ...
}: let
  cfg = config.personal.pocketid;
in {
  options.personal.pocketid = {
    enable = lib.mkEnableOption "pocket-id oidc provider";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain for pocket-id";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1411;
      description = "internal port for pocket-id";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/pocketid";
      description = "directory for pocket-id data";
    };

    encryptionKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "path to file containing encryption key (base64 encoded, generate with: openssl rand -base64 32)";
    };

    allowSignups = lib.mkOption {
      type = lib.types.enum ["disabled" "open" "withToken"];
      default = "disabled";
      description = ''
        whether user signups are allowed:
        - disabled: no signups allowed
        - open: anyone can sign up (set this initially, then change to disabled)
        - withToken: signups require a token
      '';
    };

    appName = lib.mkOption {
      type = lib.types.str;
      default = "Pocket ID";
      description = "name displayed in the ui";
    };

    accentColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "#8b5cf6";
      description = "custom accent color (hex, rgb, or hsl)";
    };

    sessionDuration = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "session duration in minutes before user has to sign in again";
    };

    disableAnimations = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "disable all animations in the ui";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.encryptionKeyFile != null;
        message = "personal.pocketid.encryptionKeyFile must be set";
      }
    ];

    virtualisation.oci-containers = {
      backend = "podman";

      containers.pocketid = {
        image = "ghcr.io/pocket-id/pocket-id:v2";
        autoStart = true;

        ports = [
          "127.0.0.1:${toString cfg.port}:1411"
        ];

        volumes = [
          "${cfg.dataDir}:/app/data"
        ];

        environment =
          {
            APP_URL = "https://${cfg.domain}";
            TRUST_PROXY = "true";
            UI_CONFIG_DISABLED = "true";
            ALLOW_USER_SIGNUPS = cfg.allowSignups;
            APP_NAME = cfg.appName;
            SESSION_DURATION = toString cfg.sessionDuration;
            DISABLE_ANIMATIONS = lib.boolToString cfg.disableAnimations;
          }
          // lib.optionalAttrs (cfg.accentColor != null) {
            ACCENT_COLOR = cfg.accentColor;
          };

        extraOptions = [
          "--env-file=/run/pocketid/env"
        ];
      };
    };

    systemd.services.podman-pocketid = {
      preStart = lib.mkAfter ''
        mkdir -p /run/pocketid
        echo "ENCRYPTION_KEY=$(cat ${cfg.encryptionKeyFile})" > /run/pocketid/env
        chmod 600 /run/pocketid/env
      '';
      serviceConfig = {
        RuntimeDirectory = "pocketid";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
    ];

    services.caddy = {
      enable = true;

      virtualHosts."${cfg.domain}" = {
        extraConfig = ''
          reverse_proxy localhost:${toString cfg.port}
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
