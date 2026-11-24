{ config, lib, ... }:

{
  services.jenkins = {
    enable = true;

    home = "/var/lib/jenkins";

    listenAddress = "127.0.0.1";
    port = 8082;

    plugins = null;
    packages = [ ];
  };

  server.services.jenkins.httpUpstream = lib.mkDefault
    "${config.services.jenkins.listenAddress}:${toString config.services.jenkins.port}";
}
