{ config, lib, pkgs, ... }:

{
  security.pki.certificateFiles = [
    ../certificates/caddy-local-ca.crt
  ];

  services.uptime-kuma = {
    enable = true;
    package = pkgs.uptime-kuma;

    settings = {
      DATA_DIR = "/var/lib/uptime-kuma/";
      HOST = "127.0.0.1";
      PORT = "3001";
      UPTIME_KUMA_DB_TYPE = "sqlite";
      NODE_EXTRA_CA_CERTS = config.security.pki.caBundle;
    };
  };

  server.services.status.httpUpstream = lib.mkDefault
    "${config.services.uptime-kuma.settings.HOST}:${config.services.uptime-kuma.settings.PORT}";
}
