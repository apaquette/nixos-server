{ config, ... }:

let
  network = config.server.network;
in
{
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network.enable = true;

  systemd.network.links."10-lan" = {
    matchConfig.PermanentMACAddress = network.interfaceMacAddress;
    linkConfig.Name = network.interfaceName;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = network.interfaceName;
    address = [ network.ipv4Address ];
    routes = [ { Gateway = network.gateway; } ];
    dns = [ network.lanAddress ] ++ network.dnsServers;
    linkConfig.RequiredForOnline = "routable";
  };

  networking.firewall.interfaces.${network.interfaceName} = {
    allowedTCPPorts = [ 53 80 443 4300 ];
    allowedUDPPorts = [ 53 67 ];
  };
}
