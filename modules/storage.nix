{ config, ... }:

let
  storage = config.server.storage;
in
{
  services.fstrim.enable = true;

  fileSystems.${storage.dataRoot} = {
    device = storage.dataDevice;
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems.${storage.backupRoot} = {
    device = storage.backupDevice;
    fsType = "ext4";
    options = [ "nofail" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/radarr 0750 radarr radarr -"
    "d /var/lib/sonarr 0750 sonarr sonarr -"
    "d /var/lib/prowlarr 0755 prowlarr prowlarr -"
    "d /var/lib/qBittorrent 0755 qbittorrent qbittorrent -"
    "d /var/lib/minecraft 0700 minecraft minecraft -"
    "d /var/lib/jellyfin 0750 jellyfin jellyfin -"
    "d /var/log/jellyfin 0750 jellyfin jellyfin -"
    "d /var/cache/jellyfin 0750 jellyfin jellyfin -"
  ];
}
