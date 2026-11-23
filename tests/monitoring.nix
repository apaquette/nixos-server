{ config, helpers, ... }:

with helpers;

[
  (assertEqual
    "disk health timer interval"
    "15min"
    config.systemd.timers.homelab-disk-health.timerConfig.OnUnitActiveSec)

  (assertEqual
    "storage health timer interval"
    "15min"
    config.systemd.timers.homelab-storage-health.timerConfig.OnUnitActiveSec)

  (assertEqual
    "storage health required mounts"
    [
      config.server.storage.dataRoot
      config.server.storage.backupRoot
    ]
    config.systemd.services.homelab-storage-health.unitConfig.RequiresMountsFor)

  (assertEqual
    "storage health failure notification"
    [ "homelab-storage-notify@%p.service" ]
    config.systemd.services.homelab-storage-health.onFailure)

  # Keep the aggregate backup-notification invariant as one boolean test item.
  (builtins.all
    (name:
      builtins.elem
        "homelab-backup-notify@%p.service"
        config.systemd.services."restic-backups-${name}".onFailure)
    [
      "nextcloud"
      "immich"
      "minecraft"
      "jellyfin"
      "sonarr"
      "radarr"
      "beszel"
      "ntfy"
    ])
]
