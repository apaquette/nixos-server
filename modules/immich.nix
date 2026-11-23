{ config, lib, unstable, ... }:

let
  storage = import ./lib/storage.nix { inherit config; };
  applicationDataRoot = storage.mountPointForRole "applicationData" "Immich";
in
{
  services.immich = {
    enable = true;

    package = unstable.immich;

    host = "127.0.0.1";
    port = 2283;

    mediaLocation = "${applicationDataRoot}/Immich/library";

    machine-learning.enable = true;
    accelerationDevices = [ ];

    database = {
      enable = true;
      createDB = true;
      name = "immich";
      user = "immich";
      host = "/run/postgresql";
    };

    redis = {
      enable = true;
      port = 0;
    };

    settings = null;
  };

  server.services.immich.httpUpstream = lib.mkDefault
    "${config.services.immich.host}:${toString config.services.immich.port}";

  systemd.services.immich-server.unitConfig.RequiresMountsFor = [
    config.services.immich.mediaLocation
  ];
}
