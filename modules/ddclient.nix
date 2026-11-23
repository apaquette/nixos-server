{ config, lib, ... }:

let
  publicHostnames = lib.filter
    (hostname: hostname != null)
    (lib.mapAttrsToList
      (_: service:
        if service.exposure == "public" then service.hostname else null)
      config.server.services);

  domainLabels = lib.sort builtins.lessThan
    (map
      (hostname: lib.removeSuffix ".${config.server.network.publicDomain}" hostname)
      publicHostnames);
in
{
  users.groups.ddclient-secrets = { };

  services.ddclient = {
    enable = true;

    protocol = "namecheap";
    server = "dynamicdns.park-your-domain.com";
    username = config.server.network.publicDomain;
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
}
