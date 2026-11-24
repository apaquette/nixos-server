{ config, lib, pkgs, ... }:

let
  storage = config.server.storage;
  storageMountPoints = map
    (volume: volume.mountPoint)
    (builtins.attrValues storage.volumes);

  ntfy = config.server.notifications.ntfy;
  ntfyBaseUrl = lib.removeSuffix "/" ntfy.baseUrl;

  replaceConfiguration = name: source:
    pkgs.writeScript name (
      builtins.replaceStrings
        [
          "@STORAGE_MOUNT_POINTS@"
          "@RAID_DEVICE@"
          "@NTFY_SYSTEM_URL@"
          "@NTFY_BACKUP_URL@"
        ]
        [
          (lib.escapeShellArgs storageMountPoints)
          (if storage.raidDevice == null then "none" else storage.raidDevice)
          (lib.escapeShellArg "${ntfyBaseUrl}/${ntfy.systemTopic}")
          (lib.escapeShellArg "${ntfyBaseUrl}/${ntfy.backupTopic}")
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
    "homelab/scripts/homelab-backup-ntfy".source =
      replaceConfiguration "homelab-backup-ntfy" ../scripts/homelab-backup-ntfy;
    "homelab/scripts/homelab-disk-health".source =
      replaceConfiguration "homelab-disk-health" ../scripts/homelab-disk-health;
    "homelab/scripts/homelab-storage-health".source =
      replaceConfiguration "homelab-storage-health" ../scripts/homelab-storage-health;
    "homelab/scripts/homelab-storage-ntfy".source =
      replaceConfiguration "homelab-storage-ntfy" ../scripts/homelab-storage-ntfy;
    "homelab/scripts/restic-offsite-copy".source = ../scripts/restic-offsite-copy;
    "homelab/scripts/restic-offsite-restore-test".source = ../scripts/restic-offsite-restore-test;
  };
}
