{ config, helpers, ... }:

with helpers;

[
  (assertEqual
    "Caddy enabled"
    true
    config.services.caddy.enable)

  (assertEqual
    "Caddy virtual host count"
    14
    (builtins.length (builtins.attrNames config.services.caddy.virtualHosts)))

  (assertEqual
    "Caddy cloud upstream"
    "reverse_proxy 127.0.0.1:8081\n"
    config.services.caddy.virtualHosts."cloud.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Jellyfin upstream"
    "reverse_proxy ${config.server.network.lanAddress}:8096\n"
    config.services.caddy.virtualHosts."jellyfin.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Seerr upstream"
    "reverse_proxy 127.0.0.1:5055\n"
    config.services.caddy.virtualHosts."seerr.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Immich upstream"
    "reverse_proxy 127.0.0.1:2283\n"
    config.services.caddy.virtualHosts."immich.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy ntfy upstream"
    "reverse_proxy 127.0.0.1:8093\n"
    config.services.caddy.virtualHosts."ntfy.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Radarr configuration"
    "tls internal\nreverse_proxy 127.0.0.1:7878\n"
    config.services.caddy.virtualHosts."radarr.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Sonarr configuration"
    "tls internal\nreverse_proxy 127.0.0.1:8989\n"
    config.services.caddy.virtualHosts."sonarr.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Prowlarr configuration"
    "tls internal\nreverse_proxy 127.0.0.1:9696\n"
    config.services.caddy.virtualHosts."prowlarr.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy qBittorrent configuration"
    "tls internal\nreverse_proxy ${config.server.network.lanAddress}:8080\n"
    config.services.caddy.virtualHosts."qbittorrent.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Cockpit configuration"
    "tls internal\nreverse_proxy 127.0.0.1:9090\n"
    config.services.caddy.virtualHosts."cockpit.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy status configuration"
    "tls internal\nreverse_proxy 127.0.0.1:3001\n"
    config.services.caddy.virtualHosts."status.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Beszel configuration"
    "tls internal\nreverse_proxy 127.0.0.1:8090\n"
    config.services.caddy.virtualHosts."beszel.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Jenkins configuration"
    "tls internal\nreverse_proxy 127.0.0.1:8082\n"
    config.services.caddy.virtualHosts."jenkins.alexpaquette.dev".extraConfig)

  (assertEqual
    "Caddy Homepage configuration"
    "tls internal\nreverse_proxy 127.0.0.1:3000\n"
    config.services.caddy.virtualHosts."homepage.alexpaquette.dev".extraConfig)
]