{
  config,
  lib,
  ...
}: let
  cfg = config.personal.netbird;

  oidcAuthority =
    if cfg.oidc.configEndpoint != ""
    then builtins.replaceStrings ["/.well-known/openid-configuration"] [""] cfg.oidc.configEndpoint
    else "https://${cfg.domain}";

  managementPort = 8011;
  signalPort = 8012;
  coturnPort = 3478;
in {
  options.personal.netbird = {
    enable = lib.mkEnableOption "netbird vpn server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain for netbird services";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/netbird";
      description = "directory for netbird data";
    };

    dataStoreEncryptionKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "path to file containing data store encryption key (base64 encoded 32 bytes)";
    };

    coturn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "enable integrated coturn stun/turn server";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "path to file containing coturn password";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "netbird";
        description = "username for coturn authentication";
      };

      minPort = lib.mkOption {
        type = lib.types.port;
        default = 49152;
        description = "minimum port for coturn relay";
      };

      maxPort = lib.mkOption {
        type = lib.types.port;
        default = 65535;
        description = "maximum port for coturn relay";
      };
    };

    oidc = {
      configEndpoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "oidc discovery endpoint; leave empty to use embedded idp";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "netbird";
        description = "oidc client id";
      };

      audience = lib.mkOption {
        type = lib.types.str;
        default = "netbird";
        description = "oidc audience";
      };
    };

    singleAccountModeDomain = lib.mkOption {
      type = lib.types.str;
      default = "netbird.selfhosted";
      description = "domain for single account mode grouping";
    };

    disableSingleAccountMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "disable single account mode (each user gets separate account)";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum ["ERROR" "WARN" "INFO" "DEBUG"];
      default = "INFO";
      description = "log level for netbird services";
    };

    exitNode = {
      enable = lib.mkEnableOption "netbird exit node client on this server";

      setupKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          path to file containing the setup key for automatic registration.
          if null, the client starts but you must manually run:
            netbird-exit up --setup-key YOUR_KEY
          or authenticate via the dashboard.
        '';
      };

      managementUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          management server url. if null and server is enabled, uses local server.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 51820;
        description = "wireguard port for the exit node client";
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "nb-exit";
        description = "network interface name for the exit node";
      };

      logLevel = lib.mkOption {
        type = lib.types.enum ["panic" "fatal" "error" "warn" "warning" "info" "debug" "trace"];
        default = "info";
        description = "log level for the netbird exit node client";
      };
    };
  };

  config = lib.mkMerge [
    # separated from exit node config to allow independent enable/disable
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.coturn.enable -> (cfg.coturn.passwordFile != null);
          message = "netbird coturn requires passwordFile to be set";
        }
      ];

      services.netbird.server = {
        enable = true;
        domain = cfg.domain;
        enableNginx = false;

        management = {
          enable = true;
          domain = cfg.domain;
          port = managementPort;
          logLevel = cfg.logLevel;
          disableAnonymousMetrics = true;
          singleAccountModeDomain = cfg.singleAccountModeDomain;
          disableSingleAccountMode = cfg.disableSingleAccountMode;
          turnDomain = cfg.domain;
          turnPort = coturnPort;

          oidcConfigEndpoint =
            if cfg.oidc.configEndpoint != ""
            then cfg.oidc.configEndpoint
            else "https://${cfg.domain}/api/v1/.well-known/openid-configuration";

          settings = {
            DataStoreEncryptionKey = lib.mkIf (cfg.dataStoreEncryptionKeyFile != null) {
              _secret = cfg.dataStoreEncryptionKeyFile;
            };

            TURNConfig = lib.mkIf cfg.coturn.enable {
              Turns = [
                {
                  Proto = "udp";
                  URI = "turn:${cfg.domain}:${toString coturnPort}";
                  Username = cfg.coturn.user;
                  Password = lib.mkIf (cfg.coturn.passwordFile != null) {
                    _secret = cfg.coturn.passwordFile;
                  };
                }
              ];
              CredentialsTTL = "12h";
              TimeBasedCredentials = false;
            };

            Stuns = [
              {
                Proto = "udp";
                URI = "stun:${cfg.domain}:${toString coturnPort}";
                Username = "";
                Password = null;
              }
            ];

            Signal = {
              Proto = "https";
              URI = "${cfg.domain}:443";
              Username = "";
              Password = null;
            };

            HttpConfig = {
              Address = "127.0.0.1:${toString managementPort}";
              IdpSignKeyRefreshEnabled = true;
            };

            PKCEAuthorizationFlow = {
              ProviderConfig = {
                Audience = cfg.oidc.audience;
                ClientID = cfg.oidc.clientId;
                ClientSecret = "";
                Scope = "openid profile email offline_access";
                RedirectURLs = ["http://localhost:53000"];
                UseIDToken = true;
              };
            };

            DeviceAuthorizationFlow = {
              Provider = "none";
              ProviderConfig = {
                Audience = cfg.oidc.audience;
                ClientID = cfg.oidc.clientId;
                Scope = "openid profile email offline_access";
                UseIDToken = true;
              };
            };
          };
        };

        signal = {
          enable = true;
          domain = cfg.domain;
          port = signalPort;
          logLevel = cfg.logLevel;
          enableNginx = false;
        };

        dashboard = {
          enable = true;
          domain = cfg.domain;
          enableNginx = false;
          managementServer = "https://${cfg.domain}";

          settings = {
            AUTH_AUTHORITY = oidcAuthority;
            AUTH_AUDIENCE = cfg.oidc.audience;
            AUTH_CLIENT_ID = cfg.oidc.clientId;
            AUTH_SUPPORTED_SCOPES = "openid profile email groups";
            NETBIRD_TOKEN_SOURCE = "idToken";
            USE_AUTH0 = false;
          };
        };

        coturn = lib.mkIf cfg.coturn.enable {
          enable = true;
          domain = cfg.domain;
          user = cfg.coturn.user;
          passwordFile = cfg.coturn.passwordFile;
          useAcmeCertificates = false;
        };
      };

      services.coturn = lib.mkIf cfg.coturn.enable {
        min-port = cfg.coturn.minPort;
        max-port = cfg.coturn.maxPort;
        listening-port = coturnPort;
      };

      services.caddy = {
        enable = true;

        virtualHosts."${cfg.domain}" = {
          extraConfig = ''
            handle /api/* {
              reverse_proxy localhost:${toString managementPort}
            }

            handle /.well-known/* {
              reverse_proxy localhost:${toString managementPort}
            }

            handle /management.ManagementService/* {
              reverse_proxy h2c://localhost:${toString managementPort} {
                transport http {
                  versions h2c
                }
                flush_interval -1
              }
            }

            handle /signalexchange.SignalExchange/* {
              reverse_proxy h2c://localhost:${toString signalPort} {
                transport http {
                  versions h2c
                }
                flush_interval -1
              }
            }

            handle {
              root * ${config.services.netbird.server.dashboard.finalDrv}
              try_files {path} {path}.html {path}/ /index.html
              file_server
            }
          '';
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 root root -"
      ];

      networking.firewall = {
        allowedTCPPorts = [80 443];
        allowedUDPPorts = [coturnPort];
        allowedUDPPortRanges = lib.mkIf cfg.coturn.enable [
          {
            from = cfg.coturn.minPort;
            to = cfg.coturn.maxPort;
          }
        ];
      };
    })

    (lib.mkIf cfg.exitNode.enable (let
      exitNodeManagementUrl =
        if cfg.exitNode.managementUrl != null
        then cfg.exitNode.managementUrl
        else if cfg.enable
        then "https://${cfg.domain}"
        else throw "netbird exit node requires either managementUrl or server to be enabled";
    in {
      assertions = [
        {
          assertion = cfg.exitNode.managementUrl != null || cfg.enable;
          message = "netbird exit node requires either managementUrl or the server to be enabled";
        }
      ];

      services.netbird.useRoutingFeatures = "server";

      services.netbird.clients.exit = {
        port = cfg.exitNode.port;
        interface = cfg.exitNode.interface;
        autoStart = true;
        openFirewall = true;
        hardened = false;
        logLevel = cfg.exitNode.logLevel;
      };

      # allows peers to route traffic through this node to the internet
      networking.nat = {
        enable = true;
        internalInterfaces = [cfg.exitNode.interface];
      };

      # peers need unrestricted communication through the vpn tunnel
      networking.firewall.trustedInterfaces = [cfg.exitNode.interface];

      # avoids manual intervention after deployment or reboot
      systemd.services.netbird-exit-autoconnect = lib.mkIf (cfg.exitNode.setupKeyFile != null) {
        description = "netbird exit node auto-connect";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"] ++ lib.optional cfg.enable "netbird-management.service";
        after = ["network-online.target" "netbird-exit.service"] ++ lib.optional cfg.enable "netbird-management.service";
        requires = ["netbird-exit.service"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          sleep 2

          STATUS=$(${config.services.netbird.clients.exit.wrapper}/bin/netbird-exit status 2>&1 || true)
          if echo "$STATUS" | grep -q "Connected"; then
            echo "already connected"
            exit 0
          fi

          if [ ! -f "${cfg.exitNode.setupKeyFile}" ]; then
            echo "setup key file not found: ${cfg.exitNode.setupKeyFile}"
            exit 1
          fi

          SETUP_KEY=$(cat "${cfg.exitNode.setupKeyFile}")
          if [ -z "$SETUP_KEY" ]; then
            echo "setup key is empty"
            exit 1
          fi

          echo "connecting to management server..."
          ${config.services.netbird.clients.exit.wrapper}/bin/netbird-exit up \
            --setup-key "$SETUP_KEY" \
            --management-url "${exitNodeManagementUrl}"

          echo "connected"
        '';
      };
    }))
  ];
}
