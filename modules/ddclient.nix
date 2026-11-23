{ config, lib, ... }:

let
  publicDomain = config.server.network.publicDomain;

  publicServices = lib.filterAttrs
    (_: service:
      service.exposure == "public"
      && service.hostname != null
      && (
        (service.httpUpstream != null && config.services.caddy.enable)
        || service.tcpPorts != [ ]
        || service.udpPorts != [ ]
      ))
    config.server.services;

  publicHostnames = map
    (service: service.hostname)
    (builtins.attrValues publicServices);

  domainLabels = lib.sort builtins.lessThan
    (map
      (hostname: lib.removeSuffix ".${publicDomain}" hostname)
      publicHostnames);
in
{
  assertions = lib.optional (publicHostnames != [ ]) {
    assertion = builtins.all
      (hostname: lib.hasSuffix ".${publicDomain}" hostname)
      publicHostnames;
    message = "Public service hostnames must belong to server.network.publicDomain.";
  };

  config = lib.mkIf (domainLabels != [ ]) {
    users.groups.ddclient-secrets = { };

    services.ddclient = {
      enable = true;

      protocol = "namecheap";
      server = "dynamicdns.park-your-domain.com";
      username = publicDomain;
      passwordFile = config.sops.secrets."namecheap-ddns-password".path;

      domains = domainLabels;

      interval = "5min";
      ssl = true;

      # Namecheap Dynamic DNS updates A records. Do not attempt an AAAA update.
      usev4 = "webv4, webv4=ipify-ipv4";
      usev6 = "";
    };

    # ddclient runs with DynamicUser=true. Grant it read access only to the
    # dedicated SOPS secret group rather than making the password world-readable.
    systemd.services.ddclient = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig.SupplementaryGroups = [
        "ddclient-secrets"
      ];
    };
  };
}
