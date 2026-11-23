{ config, pkgs, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts = {
      "cloud.alexpaquette.dev".extraConfig = ''
        reverse_proxy 127.0.0.1:8081
      '';

      "jellyfin.alexpaquette.dev".extraConfig = ''
        reverse_proxy ${config.server.network.lanAddress}:8096
      '';

      "seerr.alexpaquette.dev".extraConfig = ''
        reverse_proxy 127.0.0.1:5055
      '';

      "immich.alexpaquette.dev".extraConfig = ''
        reverse_proxy 127.0.0.1:2283
      '';

      "ntfy.alexpaquette.dev".extraConfig = ''
        reverse_proxy 127.0.0.1:8093
      '';

      "radarr.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:7878
      '';

      "sonarr.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8989
      '';

      "prowlarr.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:9696
      '';

      "qbittorrent.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy ${config.server.network.lanAddress}:8080
      '';

      "cockpit.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:9090
      '';

      "status.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:3001
      '';

      "beszel.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8090
      '';

      "jenkins.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8082
      '';

      "homepage.alexpaquette.dev".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:3000
      '';
    };
  };
}