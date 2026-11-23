{ config, lib, helpers, ... }:

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
    "dnsmasq local DNS entries for enabled HTTP and direct services"
    [
      "/beszel.alexpaquette.dev/${config.server.network.lanAddress}"
      "/cloud.alexpaquette.dev/${config.server.network.lanAddress}"
      "/cockpit.alexpaquette.dev/${config.server.network.lanAddress}"
      "/homepage.alexpaquette.dev/${config.server.network.lanAddress}"
      "/immich.alexpaquette.dev/${config.server.network.lanAddress}"
      "/jenkins.alexpaquette.dev/${config.server.network.lanAddress}"
      "/jellyfin.alexpaquette.dev/${config.server.network.lanAddress}"
      "/mc.alexpaquette.dev/${config.server.network.lanAddress}"
      "/ntfy.alexpaquette.dev/${config.server.network.lanAddress}"
      "/prowlarr.alexpaquette.dev/${config.server.network.lanAddress}"
      "/qbittorrent.alexpaquette.dev/${config.server.network.lanAddress}"
      "/radarr.alexpaquette.dev/${config.server.network.lanAddress}"
      "/seerr.alexpaquette.dev/${config.server.network.lanAddress}"
      "/sonarr.alexpaquette.dev/${config.server.network.lanAddress}"
      "/status.alexpaquette.dev/${config.server.network.lanAddress}"
    ]
    (lib.sort builtins.lessThan config.services.dnsmasq.settings.address))
]
