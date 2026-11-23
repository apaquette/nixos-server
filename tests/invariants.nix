{ config, helpers, ... }:

[
  # Storage-dependent native services
  (helpers.assertContains
    "Sonarr requires myraid"
    "mnt-myraid.mount"
    config.systemd.services.sonarr.requires)

  (helpers.assertContains
    "Radarr requires myraid"
    "mnt-myraid.mount"
    config.systemd.services.radarr.requires)

  (helpers.assertContains
    "qBittorrent requires myraid"
    "mnt-myraid.mount"
    config.systemd.services.qbittorrent.requires)

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
