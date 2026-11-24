{ config, lib, ... }:

let
  services = config.server.services;
  network = config.server.network;
  serviceExposure = import ./lib/service-exposure.nix { inherit lib; };

  httpServices = serviceExposure.httpServices services;

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
