{ config, lib, ... }:

let
  network = config.server.network;
  services = config.server.services;

  publicServices = lib.filterAttrs (_: service: service.exposure == "public") services;
  lanServices = lib.filterAttrs (_: service: service.exposure == "lan") services;

  publicTcpPorts = lib.unique (lib.concatMap (service: service.tcpPorts) (builtins.attrValues publicServices));
  publicUdpPorts = lib.unique (lib.concatMap (service: service.udpPorts) (builtins.attrValues publicServices));
  lanTcpPorts = lib.unique (lib.concatMap (service: service.tcpPorts) (builtins.attrValues lanServices));
  lanUdpPorts = lib.unique (lib.concatMap (service: service.udpPorts) (builtins.attrValues lanServices));

  trustedIPv4 = lib.filter (cidr: !(lib.hasInfix ":" cidr)) network.trustedNetworks;
  trustedIPv6 = lib.filter (cidr: lib.hasInfix ":" cidr) network.trustedNetworks;

  mkRule = family: sourceCidrs: protocol: ports:
    if sourceCidrs == [ ] || ports == [ ] then
      null
    else
      "${family} saddr { ${lib.concatStringsSep ", " sourceCidrs} } ${protocol} dport { ${lib.concatMapStringsSep ", " toString ports} } accept";

  lanInputRules = lib.filter (rule: rule != null) [
    (mkRule "ip" trustedIPv4 "tcp" lanTcpPorts)
    (mkRule "ip" trustedIPv4 "udp" lanUdpPorts)
    (mkRule "ip6" trustedIPv6 "tcp" lanTcpPorts)
    (mkRule "ip6" trustedIPv6 "udp" lanUdpPorts)
  ];

  servicesRequiringLanAccess = lib.any
    (service:
      service.exposure == "lan"
      && (service.httpUpstream != null || service.tcpPorts != [ ] || service.udpPorts != [ ]))
    (builtins.attrValues services);

  exposureAssertions = [
    {
      assertion = !servicesRequiringLanAccess || network.trustedNetworks != [ ];
      message = "LAN-only service ingress requires server.network.trustedNetworks to be configured.";
    }
  ];
in
{
  assertions = exposureAssertions;

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
    allowedTCPPorts = [ 53 80 443 ] ++ publicTcpPorts;
    allowedUDPPorts = [ 53 67 ] ++ publicUdpPorts;
  };

  networking.nftables.enable = lanInputRules != [ ];
  networking.firewall.extraInputRules = lanInputRules;
}
