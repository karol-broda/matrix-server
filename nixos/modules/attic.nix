{ config
, lib
, ...
}:
let
  cfg = config.personal.attic;
in
{
  options.personal.attic = {
    enable = lib.mkEnableOption "attic nix binary cache";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain for the attic server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8199;
      description = "internal port for atticd";
    };

    s3 = {
      bucket = lib.mkOption {
        type = lib.types.str;
        description = "s3 bucket name";
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        description = "s3 endpoint url";
      };

      region = lib.mkOption {
        type = lib.types.str;
        default = "eu-central";
        description = "s3 region";
      };

    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        env file with secrets for atticd. must contain:
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64 - base64-encoded RSA PKCS1 private key
        AWS_ACCESS_KEY_ID - s3 access key
        AWS_SECRET_ACCESS_KEY - s3 secret key
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.atticd = {
      enable = true;
      environmentFile = cfg.environmentFile;

      settings = {
        listen = "127.0.0.1:${toString cfg.port}";

        storage = {
          type = "s3";
          bucket = cfg.s3.bucket;
          endpoint = cfg.s3.endpoint;
          region = cfg.s3.region;
        };

        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "6 months";
        };
      };
    };

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
