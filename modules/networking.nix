{ config, lib, ... }:

let
  network = config.server.network;
  services = config.server.services;
  serviceExposure = import ./lib/service-exposure.nix { inherit lib; };

  publicTcpPorts = serviceExposure.portsForExposure "public" "tcp" services;
  publicUdpPorts = serviceExposure.portsForExposure "public" "udp" services;
  lanTcpPorts = serviceExposure.portsForExposure "lan" "tcp" services;
  lanUdpPorts = serviceExposure.portsForExposure "lan" "udp" services;

  dnsmasqEnabled = config.services.dnsmasq.enable;
  caddyIngressEnabled =
    config.services.caddy.enable
    && config.services.caddy.virtualHosts != { };

  baseTcpPorts =
    lib.optionals dnsmasqEnabled [ 53 ]
    ++ lib.optionals caddyIngressEnabled [ 80 443 ];

  baseUdpPorts = lib.optionals dnsmasqEnabled [ 53 67 ];

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
    allowedTCPPorts = lib.unique (baseTcpPorts ++ publicTcpPorts);
    allowedUDPPorts = lib.unique (baseUdpPorts ++ publicUdpPorts);
  };

  networking.nftables.enable = lanInputRules != [ ];
  networking.firewall.extraInputRules = lib.concatStringsSep "\n" lanInputRules;
}
