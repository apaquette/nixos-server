{ config, helpers, ... }:

let
  localHostnames = [
    "jellyfin.alexpaquette.dev"
    "seerr.alexpaquette.dev"
    "immich.alexpaquette.dev"
    "cloud.alexpaquette.dev"
    "ntfy.alexpaquette.dev"
    "radarr.alexpaquette.dev"
    "sonarr.alexpaquette.dev"
    "prowlarr.alexpaquette.dev"
    "qbittorrent.alexpaquette.dev"
    "cockpit.alexpaquette.dev"
    "status.alexpaquette.dev"
    "beszel.alexpaquette.dev"
    "jenkins.alexpaquette.dev"
    "homepage.alexpaquette.dev"
  ];
in
with helpers;

[
  (assertEqual
    "dnsmasq enabled"
    true
    config.services.dnsmasq.enable)

  (assertEqual
    "dnsmasq interface"
    [ config.server.network.interfaceName ]
    config.services.dnsmasq.settings.interface)

  (assertEqual
    "dnsmasq listen addresses"
    [ "127.0.0.1" config.server.network.lanAddress ]
    config.services.dnsmasq.settings.listen-address)

  (assertEqual
    "dnsmasq DHCP range"
    [ config.server.network.dhcpRange ]
    config.services.dnsmasq.settings.dhcp-range)

  (assertEqual
    "dnsmasq DHCP options"
    [
      "option:router,${config.server.network.gateway}"
      "option:dns-server,${config.server.network.lanAddress}"
    ]
    config.services.dnsmasq.settings.dhcp-option)

  (assertEqual
    "dnsmasq upstream DNS"
    config.server.network.dnsServers
    config.services.dnsmasq.settings.server)

  (assertEqual
    "dnsmasq no-resolv"
    [true]
    config.services.dnsmasq.settings.no-resolv)

  (assertEqual
    "dnsmasq cache size"
    [1000]
    config.services.dnsmasq.settings.cache-size)

  (assertEqual
    "dnsmasq desktop reservation"
    config.server.network.dhcpHosts
    config.services.dnsmasq.settings.dhcp-host)

  (assertEqual
    "dnsmasq local DNS entries"
    (map
      (hostname: "/${hostname}/${config.server.network.lanAddress}")
      localHostnames)
    config.services.dnsmasq.settings.address)
]
