{ config, lib, pkgs, ... }:

{
  services.seerr = {
    enable = true;
    package = pkgs.seerr;
    configDir = "/var/lib/seerr";
  };

  server.services.seerr.httpUpstream = lib.mkDefault "127.0.0.1:5055";
}
