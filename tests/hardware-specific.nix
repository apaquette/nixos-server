{ config, pkgs, helpers, ... }:

[
  # Intel graphics support required by Jellyfin.
  (helpers.assertContains
    "Intel media driver package"
    pkgs.intel-media-driver
    config.hardware.graphics.extraPackages)

  (helpers.assertContains
    "Intel compute runtime package"
    pkgs.intel-compute-runtime
    config.hardware.graphics.extraPackages)

  (helpers.assertContains
    "Intel VPL runtime package"
    pkgs.vpl-gpu-rt
    config.hardware.graphics.extraPackages)

  (helpers.assertEqual
    "Jellyfin VA-API driver"
    "iHD"
    config.systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME)

  # The production RAID array is represented by its existing mdadm UUID.
  (helpers.assertEqual
    "production RAID UUID"
    true
    (builtins.match
      ".*UUID=06feb5d7:8068ed2e:0d93f17f:649590b9.*"
      config.boot.swraid.mdadmConf
      != null))

  # SMART monitoring must remain explicitly configured rather than relying
  # on autodetection, since the production system has known disk identities.
  (helpers.assertEqual
    "SMART autodetection disabled"
    false
    config.services.smartd.autodetect)

  (helpers.assertEqual
    "SMART device count"
    3
    (builtins.length config.services.smartd.devices))

  # The production bootloader configuration must remain UEFI/systemd-boot.
  (helpers.assertEqual
    "systemd-boot enabled"
    true
    config.boot.loader.systemd-boot.enable)

  (helpers.assertEqual
    "EFI variable access enabled"
    true
    config.boot.loader.efi.canTouchEfiVariables)

  # The Seagate Expansion USB bridge (0bc2:2322) must use BOT instead of UAS.
  (helpers.assertContains
    "Seagate Expansion UAS compatibility quirk"
    "usb-storage.quirks=0bc2:2322:u"
    config.boot.kernelParams)
]
