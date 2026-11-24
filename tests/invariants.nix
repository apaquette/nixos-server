{ config, helpers, ... }:

[
  # Storage-dependent native services
  (helpers.assertContains
    "Sonarr requires myraid"
    config.server.storage.volumes.${config.server.storage.roles.applicationData}.mountPoint
    config.systemd.services.sonarr.unitConfig.RequiresMountsFor)

  (helpers.assertContains
    "Radarr requires myraid"
    config.server.storage.volumes.${config.server.storage.roles.applicationData}.mountPoint
    config.systemd.services.radarr.unitConfig.RequiresMountsFor)

  (helpers.assertContains
    "qBittorrent requires myraid"
    config.server.storage.volumes.${config.server.storage.roles.applicationData}.mountPoint
    config.systemd.services.qbittorrent.unitConfig.RequiresMountsFor)

  # Backup failure notification handlers
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
