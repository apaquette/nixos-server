{ ... }:

{
  imports = [
    ./network.nix
    ./storage.nix
    ./services.nix

    ../../modules/server-options.nix
    ../../modules/networking.nix
    ../../modules/storage.nix
    ../../modules/dnsmasq.nix
    ../../modules/caddy.nix
  ];

  networking.hostName = "synthetic-lab";

  # This configuration is evaluated and checked in CI; it is not deployed.
  boot.isContainer = true;
  networking.useHostResolvConf = false;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  system.stateVersion = "26.05";
}
