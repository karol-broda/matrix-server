{
  sshPubKeys,
  config,
  ...
}: {
  system.stateVersion = "25.11";

  sops = {
    defaultSopsFile = ../../../secrets/hytale-kiosk.yaml;
    age.keyFile = "/etc/sops-age-key.txt";
    secrets = {
      wifi_ssid = {};
      wifi_psk = {};
    };
  };

  # pre-generated age key for first-boot decryption
  environment.etc."sops-age-key.txt" = {
    text = builtins.readFile (builtins.getEnv "MATRIX_SERVER_ROOT" + "/keys/age/hytale-kiosk.txt");
    mode = "0400";
  };

  networking = {
    hostName = "hytale-kiosk";
    firewall.enable = true;
    wireless.enable = true;
  };

  # generate wpa_supplicant.conf from sops secrets at boot
  systemd.services.wpa-supplicant-config = {
    description = "Generate wpa_supplicant config from sops secrets";
    wantedBy = ["multi-user.target"];
    before = ["wpa_supplicant.service"];
    after = ["sops-nix.service"];
    wants = ["sops-nix.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      SSID=$(cat ${config.sops.secrets.wifi_ssid.path})
      PSK=$(cat ${config.sops.secrets.wifi_psk.path})
      cat > /etc/wpa_supplicant.conf << EOF
      ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
      network={
        ssid="$SSID"
        psk="$PSK"
        key_mgmt=WPA-PSK
      }
      EOF
      chmod 600 /etc/wpa_supplicant.conf
    '';
  };

  services.timesyncd.enable = true;

  personal = {
    ssh = {
      enable = true;
      authorizedKeys = sshPubKeys;
    };

    kiosk = {
      enable = true;
      url = "https://hytale.com/countdown";
      disableCursor = true;
      rotation = "normal";
    };
  };

  time.timeZone = "Europe/London";
}
