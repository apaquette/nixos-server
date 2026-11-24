{ config, lib, ... }:

{
  services.cockpit = {
    enable = true;
    port = 9090;
  };

  server.services.cockpit.httpUpstream = lib.mkDefault
    "127.0.0.1:${toString config.services.cockpit.port}";
}