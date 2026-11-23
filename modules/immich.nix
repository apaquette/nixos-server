{ config, unstable, ... }:

{
  services.immich = {
    enable = true;

    package = unstable.immich;

    host = "127.0.0.1";
    port = 2283;

    mediaLocation = "${config.server.storage.dataRoot}/Immich/library";

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

  systemd.services.immich-server.unitConfig.RequiresMountsFor = [
    config.services.immich.mediaLocation
  ];
}
