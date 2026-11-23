{ config, ... }:

let
  network = config.server.network;

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
{
  services.dnsmasq = {
    enable = true;

    settings = {
      interface = network.interfaceName;
      listen-address = [ "127.0.0.1" network.lanAddress ];
      bind-dynamic = true;
      dhcp-range = network.dhcpRange;
      dhcp-option = [
        "option:router,${network.gateway}"
        "option:dns-server,${network.lanAddress}"
      ];
      log-dhcp = true;
      address = map
        (hostname: "/${hostname}/${network.lanAddress}")
        localHostnames;
      server = network.dnsServers;
      no-resolv = true;
      cache-size = 1000;
      dhcp-host = network.dhcpHosts;
    };
  };

  systemd.services.dnsmasq = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
