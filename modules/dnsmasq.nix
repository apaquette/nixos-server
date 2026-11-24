{ config, lib, ... }:

let
  network = config.server.network;
  serviceExposure = import ./lib/service-exposure.nix { inherit lib; };

  publishedServices =
    serviceExposure.publishedServices config.services.caddy.enable config.server.services;
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
        (service: "/${service.hostname}/${network.lanAddress}")
        (builtins.attrValues publishedServices);
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
