{ config, lib, pkgs, ... }:
let
  storage = import ./lib/storage.nix { inherit config; };
  applicationDataRoot = storage.mountPointForRole "applicationData" "Media services";

  mediaServiceRequirements = {
    unitConfig.RequiresMountsFor = [ applicationDataRoot ];
  };
in
{
  services.sonarr = {
    enable = true;
    package = pkgs.sonarr;
    dataDir = "/var/lib/sonarr";
    user = "sonarr";
    group = "sonarr";
  };

  systemd.services.sonarr = mediaServiceRequirements;

  services.radarr = {
    enable = true;
    package = pkgs.radarr;
    dataDir = "/var/lib/radarr";
    user = "radarr";
    group = "radarr";
  };

   systemd.services.radarr = mediaServiceRequirements;

  services.prowlarr = {
    enable = true;
    package = pkgs.prowlarr;
    dataDir = "/var/lib/prowlarr";
  };

  services.qbittorrent = {
    enable = true;
    package = pkgs.qbittorrent-nox;

    user = "qbittorrent";
    group = "qbittorrent";

    profileDir = "/var/lib/qBittorrent";
    webuiPort = 8080;
  };

  systemd.services.qbittorrent =
    mediaServiceRequirements
    // {
      serviceConfig = {
        SupplementaryGroups = config.users.users.qbittorrent.extraGroups;
      };
    };

  server.services.radarr.httpUpstream = lib.mkDefault "127.0.0.1:7878";
  server.services.sonarr.httpUpstream = lib.mkDefault "127.0.0.1:8989";
  server.services.prowlarr.httpUpstream = lib.mkDefault "127.0.0.1:9696";
  server.services.qbittorrent.httpUpstream = lib.mkDefault
    "127.0.0.1:${toString config.services.qbittorrent.webuiPort}";

  systemd.tmpfiles.rules = [
    "d /var/lib/radarr 0750 radarr radarr -"
    "d /var/lib/sonarr 0750 sonarr sonarr -"
    "d /var/lib/prowlarr 0755 prowlarr prowlarr -"
    "d /var/lib/qBittorrent 0755 qbittorrent qbittorrent -"
  ];
}
