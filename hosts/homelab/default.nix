{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # The Seagate Expansion USB bridge (0bc2:2322) has a reported UAS
  # compatibility issue. Force USB Mass Storage Bulk-Only Transport.
  boot.kernelParams = [
    "usb-storage.quirks=0bc2:2322:u"
  ];
  time.timeZone = "America/Halifax";
  nixpkgs.config.allowUnfreePackages = [
    "minecraft-server"
  ];
  services.openssh.enable = true;
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ./network.nix
    ./storage.nix
    ../../modules/server-options.nix
    ../../modules/networking.nix
    ../../modules/storage.nix
    ../../modules/ddclient.nix
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
