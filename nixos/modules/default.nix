{...}: {
  imports = [
    ./ssh.nix
    ./acme.nix
    ./matrix.nix
    ./firefly.nix
    ./memos.nix
    ./affine.nix
    ./kiosk.nix
    ./netbird.nix
    ./pocketid.nix
  ];
}
