{ config, pkgs, ... }:
let
service-paths = with pkgs; [
  bash
  coreutils
  curl
  gawk
  mdadm
  smartmontools
  util-linux
];
in
{

  systemd.services.homelab-disk-health = {
    description = "Check homelab disk space and inode usage";

    after = [
      "local-fs.target"
    ];

    requires = [
      "local-fs.target"
    ];

    path = service-paths;

    serviceConfig = {
      Type = "oneshot";

      ExecStart = "/etc/homelab/scripts/homelab-disk-health";
    };
  };

  systemd.timers.homelab-disk-health = {
    description = "Periodic homelab disk health check";
    wantedBy = [
      "timers.target"
    ];

    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };

  systemd.services.homelab-storage-health = {
    description = "Check homelab RAID and storage health";
    path = service-paths;

    after = [
      "local-fs.target"
    ];

    requires = [
      "local-fs.target"
    ];

    onFailure = [
      "homelab-storage-notify@%p.service"
    ];

    unitConfig.RequiresMountsFor = [
      config.server.storage.dataRoot
      config.server.storage.backupRoot
    ];

    serviceConfig = {
      Type = "oneshot";

      ExecStart = "/etc/homelab/scripts/homelab-storage-health";
    };
  };

  systemd.timers.homelab-storage-health = {
    description = "Periodic homelab storage health check";

    wantedBy = [
      "timers.target"
    ];

    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };

  systemd.services."homelab-backup-notify@" = {
    description = "Notify ntfy about failed backup service %i";
    path = service-paths;
    serviceConfig = {
      Type = "oneshot";

      ExecStart = "/etc/homelab/scripts/homelab-backup-ntfy %i";
    };
  };

  systemd.services."homelab-storage-notify@" = {
    description = "Notify ntfy about failed storage health service %i";
    path = service-paths;
    serviceConfig = {
      Type = "oneshot";

      ExecStart = "/etc/homelab/scripts/homelab-storage-ntfy %i";
    };
  };
}
