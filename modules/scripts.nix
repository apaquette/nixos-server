{ config, lib, pkgs, ... }:

let
  storage = config.server.storage;
  storageMountPoints = map
    (volume: volume.mountPoint)
    (builtins.attrValues storage.volumes);

  replaceStorageValues = name: source:
    pkgs.writeScript name (
      builtins.replaceStrings
        [ "@STORAGE_MOUNT_POINTS@" "@RAID_DEVICE@" ]
        [
          (lib.escapeShellArgs storageMountPoints)
          (if storage.raidDevice == null then "none" else storage.raidDevice)
        ]
        (builtins.readFile source)
    );
in
{
  environment.systemPackages = with pkgs; [
    curl
    gawk
  ];

  environment.etc = {
    "homelab/scripts/homelab-backup-ntfy".source = ../scripts/homelab-backup-ntfy;
    "homelab/scripts/homelab-disk-health".source =
      replaceStorageValues "homelab-disk-health" ../scripts/homelab-disk-health;
    "homelab/scripts/homelab-storage-health".source =
      replaceStorageValues "homelab-storage-health" ../scripts/homelab-storage-health;
    "homelab/scripts/homelab-storage-ntfy".source = ../scripts/homelab-storage-ntfy;
    "homelab/scripts/restic-offsite-copy".source = ../scripts/restic-offsite-copy;
    "homelab/scripts/restic-offsite-restore-test".source = ../scripts/restic-offsite-restore-test;
  };
}
