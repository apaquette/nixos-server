{ config, lib, ... }:

let
  services = config.server.services;
  network = config.server.network;

  httpServices = lib.filterAttrs
    (_: service:
      service.httpUpstream != null
      && service.hostname != null
      && service.exposure != "loopback")
    services;

  mkVirtualHost = _: service:
    let
      accessControl =
        if service.exposure == "lan" then
          ''
            tls internal
            @denied not remote_ip ${lib.concatStringsSep " " network.trustedNetworks}
            respond @denied "Forbidden" 403
          ''
        else
          "";
    in
    lib.nameValuePair service.hostname {
      extraConfig = ''
        ${accessControl}reverse_proxy ${service.httpUpstream}
      '';
    };
in
{
  services.caddy = {
    enable = true;
    virtualHosts = lib.mapAttrs' mkVirtualHost httpServices;
  };
}
