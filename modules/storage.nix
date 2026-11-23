{ ... }:

{
  boot.swraid = {
    enable = true;

    mdadmConf = ''
      HOMEHOST <system>
      MAILADDR root
      ARRAY /dev/md/0 metadata=1.2 UUID=06feb5d7:8068ed2e:0d93f17f:649590b9
    '';
  };

  services.fstrim.enable = true;

  fileSystems."/mnt/myraid" = {
    device = "/dev/disk/by-uuid/f316b340-b988-4306-8164-9f7d11250a55";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/2f26abd3-1603-4c8d-890c-a8a8aea9c5f1";
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
