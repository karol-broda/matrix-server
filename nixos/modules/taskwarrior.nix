{ config
, lib
, ...
}:
let
  cfg = config.personal.taskwarrior;
in
{
  options.personal.taskwarrior = {
    enable = lib.mkEnableOption "taskwarrior todo sync server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain for taskwatrrior sync";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5230;
      description = "internal port for taskwarrior-sync";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/taskwarrior-sync";
      description = "directory for taskwarrior sync data";
    };

    accessTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "path to file containing the ACCESS_TOKEN for restricting access";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "podman";

      containers.taskwarrior-sync = {
        image = "ghcr.io/gothenburgbitfactory/taskchampion-sync-server";
        autoStart = true;

        ports = [
          "127.0.0.1:${toString cfg.port}:8080"
        ];

        volumes = [
          "${cfg.dataDir}:/var/lib/taskchampion-sync-server/data"
        ];

        environment = {
          LISTEN = "0.0.0.0:8080";
        };

        environmentFiles = lib.optional (cfg.accessTokenFile != null) cfg.accessTokenFile;
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

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
