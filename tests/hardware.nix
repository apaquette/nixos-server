{ config, helpers, ... }:

let
  applicationDataMountPoint =
    config.server.storage.volumes.${config.server.storage.roles.applicationData}.mountPoint;
  localBackupMountPoint =
    config.server.storage.volumes.${config.server.storage.roles.localBackup}.mountPoint;
in
[
  (helpers.assertEqual
    "root filesystem type"
    "ext4"
    config.fileSystems."/".fsType)

  (helpers.assertEqual
    "boot filesystem type"
    "vfat"
    config.fileSystems."/boot".fsType)

  (helpers.assertContains
    "boot filesystem options"
    "fmask=0077"
    config.fileSystems."/boot".options)

  (helpers.assertContains
    "boot filesystem options"
    "dmask=0077"
    config.fileSystems."/boot".options)

  (helpers.assertEqual
    "application-data filesystem type"
    "ext4"
    config.fileSystems.${applicationDataMountPoint}.fsType)

  (helpers.assertContains
    "application-data filesystem options"
    "nofail"
    config.fileSystems.${applicationDataMountPoint}.options)

  (helpers.assertEqual
    "local-backup filesystem type"
    "ext4"
    config.fileSystems.${localBackupMountPoint}.fsType)

  (helpers.assertContains
    "local-backup filesystem options"
    "nofail"
    config.fileSystems.${localBackupMountPoint}.options)

  (helpers.assertContains
    "initrd NVMe module"
    "nvme"
    config.boot.initrd.availableKernelModules)

  (helpers.assertContains
    "initrd AHCI module"
    "ahci"
    config.boot.initrd.availableKernelModules)

  (helpers.assertContains
    "initrd USB storage module"
    "usb_storage"
    config.boot.initrd.availableKernelModules)

  (helpers.assertContains
    "initrd HID module"
    "usbhid"
    config.boot.initrd.availableKernelModules)

  (helpers.assertContains
    "kernel Intel KVM module"
    "kvm-intel"
    config.boot.kernelModules)

  (helpers.assertEqual
    "systemd-boot enabled"
    true
    config.boot.loader.systemd-boot.enable)

  (helpers.assertEqual
    "EFI variables enabled"
    true
    config.boot.loader.efi.canTouchEfiVariables)

  (helpers.assertEqual
    "host platform system"
    "x86_64-linux"
    config.nixpkgs.hostPlatform.system)
]
