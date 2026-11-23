{ config, pkgs, ... }:

let
  replaceStorageRoots = name: source:
    pkgs.writeScript name (
      builtins.replaceStrings
        [ "@DATA_ROOT@" "@BACKUP_ROOT@" "@RAID_DEVICE@" ]
        [
          config.server.storage.dataRoot
          config.server.storage.backupRoot
          (if config.server.storage.raidDevice == null then "none" else config.server.storage.raidDevice)
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
      replaceStorageRoots "homelab-disk-health" ../scripts/homelab-disk-health;
    "homelab/scripts/homelab-storage-health".source =
      replaceStorageRoots "homelab-storage-health" ../scripts/homelab-storage-health;
    "homelab/scripts/homelab-storage-ntfy".source = ../scripts/homelab-storage-ntfy;
    "homelab/scripts/restic-offsite-copy".source = ../scripts/restic-offsite-copy;
    "homelab/scripts/restic-offsite-restore-test".source = ../scripts/restic-offsite-restore-test;
  };
}
