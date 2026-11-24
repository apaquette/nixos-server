{ config, ... }:

{
  # The endpoint follows the host-selected ntfy service hostname.
  server.notifications.ntfy = {
    baseUrl = "https://${config.server.services.ntfy.hostname}";
    systemTopic = "homelab-system";
    backupTopic = "homelab-backups";
  };
}
