{ ... }:

{
  services.dnsmasq = {
    enable = true;

    settings = {
      interface = "lan0";

      listen-address = [
        "127.0.0.1"
        "192.168.2.20"
      ];

      bind-dynamic = true;

      dhcp-range = "192.168.2.50,192.168.2.199,255.255.255.0,12h";

      dhcp-option = [
        "option:router,192.168.2.1"
        "option:dns-server,192.168.2.20"
      ];

      log-dhcp = true;

      address = [
        "/jellyfin.alexpaquette.dev/192.168.2.20"
        "/seerr.alexpaquette.dev/192.168.2.20"
        "/immich.alexpaquette.dev/192.168.2.20"
        "/cloud.alexpaquette.dev/192.168.2.20"
        "/ntfy.alexpaquette.dev/192.168.2.20"
        "/radarr.alexpaquette.dev/192.168.2.20"
        "/sonarr.alexpaquette.dev/192.168.2.20"
        "/prowlarr.alexpaquette.dev/192.168.2.20"
        "/qbittorrent.alexpaquette.dev/192.168.2.20"
        "/cockpit.alexpaquette.dev/192.168.2.20"
        "/status.alexpaquette.dev/192.168.2.20"
        "/beszel.alexpaquette.dev/192.168.2.20"
        "/jenkins.alexpaquette.dev/192.168.2.20"
        "/homepage.alexpaquette.dev/192.168.2.20"
      ];

      server = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      no-resolv = true;
      cache-size = 1000;

      dhcp-host = [
        "b4:2e:99:fb:61:ae,192.168.2.100,nixos-desktop"
      ];
    };
  };

  systemd.services.dnsmasq = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
