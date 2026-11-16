{ config, ... }:

{
  users.groups.ddclient-secrets = {};

  services.ddclient = {
    enable = true;

    protocol = "namecheap";
    server = "dynamicdns.park-your-domain.com";
    username = "alexpaquette.dev";
    passwordFile = config.sops.secrets."namecheap-ddns-password".path;

    domains = [
      "cloud"
      "jellyfin"
      "seerr"
      "immich"
      "ntfy"
    ];

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
