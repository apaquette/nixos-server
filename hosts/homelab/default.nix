{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  time.timeZone = "America/Halifax";
  nixpkgs.config.allowUnfreePackages = [
    "minecraft-server"
  ];
  services.openssh.enable = true;
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ../../modules/networking.nix
    ../../modules/ddclient.nix
    ../../modules/storage.nix
    ../../modules/caddy.nix
    ../../modules/dnsmasq.nix
    ../../modules/jellyfin.nix
    ../../modules/media-services.nix
    ../../modules/seerr.nix
    ../../modules/minecraft.nix
    ../../modules/sops.nix
    ../../modules/scripts.nix
    ../../modules/monitoring.nix
    ../../modules/backups.nix
    ../../modules/smartd.nix
    ../../modules/cockpit.nix
    ../../modules/system-tools.nix
    ../../modules/homepage.nix
    ../../modules/ntfy.nix
    ../../modules/uptime-kuma.nix
    ../../modules/beszel.nix
    ../../modules/immich.nix
    ../../modules/jenkins.nix
    ../../modules/nextcloud.nix
  ];

  networking.hostName = "homelab";

  system.stateVersion = "26.05";
}
