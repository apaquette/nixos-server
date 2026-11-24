{ config, pkgs, helpers, ... }:

with helpers;

[
  (assertEqual
    "Jellyfin enabled"
    true
    config.services.jellyfin.enable)

  (assertContains
    "Jellyfin graphics packages"
    pkgs.intel-media-driver
    config.hardware.graphics.extraPackages)

  (assertContains
    "Jellyfin graphics packages"
    pkgs.intel-compute-runtime
    config.hardware.graphics.extraPackages)

  (assertContains
    "Jellyfin graphics packages"
    pkgs.vpl-gpu-rt
    config.hardware.graphics.extraPackages)

  (assertEqual
    "Jellyfin VA-API driver"
    "iHD"
    config.systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME)
  (assertContains
    "Jellyfin requires its application-data volume"
    config.server.storage.volumes.${config.server.storage.roles.applicationData}.mountPoint
    config.systemd.services.jellyfin.unitConfig.RequiresMountsFor)
]
