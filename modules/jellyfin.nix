{ config, lib, pkgs, ... }:

let
  storage = import ./lib/storage.nix { inherit config; };
  applicationDataRoot = storage.mountPointForRole "applicationData" "Jellyfin";
in
{
  hardware.graphics = {
    enable = true;

    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
      vpl-gpu-rt
    ];
  };

  services.jellyfin = {
    enable = true;
    user = "jellyfin";
    group = "jellyfin";
  };

  server.services.jellyfin.httpUpstream = lib.mkDefault
    "127.0.0.1:8096";

  systemd.services.jellyfin = {
    unitConfig.RequiresMountsFor = [ applicationDataRoot ];
    environment.LIBVA_DRIVER_NAME = "iHD";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/jellyfin 0750 jellyfin jellyfin -"
    "d /var/log/jellyfin 0750 jellyfin jellyfin -"
    "d /var/cache/jellyfin 0750 jellyfin jellyfin -"
    "Z /var/lib/jellyfin/plugins 0755 jellyfin jellyfin -"
    "Z /var/lib/jellyfin/metadata 0755 jellyfin jellyfin -"
    "Z /var/lib/jellyfin/root 0755 jellyfin jellyfin -"
    "Z /var/cache/jellyfin/images 0755 jellyfin jellyfin -"
    "Z /var/cache/jellyfin/omdb 0755 jellyfin jellyfin -"
    "Z /var/cache/jellyfin/transcodes 0755 jellyfin jellyfin -"
  ];
}
