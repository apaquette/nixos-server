{ config, lib, unstable, ... }:

let
  storage = config.server.storage;
  storageResolver = import ./lib/storage.nix { inherit config; };

  roleFilesystem = role: suffix:
    if builtins.hasAttr role storage.roles then
      "${storageResolver.mountPointForRole role "Beszel"}${suffix}"
    else
      null;

  agentPort = 45876;

  extraFilesystems = lib.filter
    (filesystem: filesystem != null)
    [
      (roleFilesystem "localBackup" "__Backup_Storage")
      (roleFilesystem "applicationData" "__RAID_Storage__")
    ];
in
{
  services.beszel.hub = {
    enable = true;
    package = unstable.beszel;
    host = "127.0.0.1";
    port = 8090;
    dataDir = "/var/lib/beszel-hub";

    environment = {
      APP_URL = "https://${config.server.services.beszel.hostname}";
    };
  };

  server.services.beszel.httpUpstream = lib.mkDefault
    "${config.services.beszel.hub.host}:${toString config.services.beszel.hub.port}";

  systemd.services.beszel-hub.serviceConfig.ExecStartPre = lib.mkForce [
    "${unstable.beszel}/bin/beszel-hub migrate up"
  ];

services.beszel.agent = {
  enable = true;
  package = unstable.beszel;

  environment = {
    DATA_DIR = "/var/lib/beszel-agent";
    LISTEN = toString agentPort;
    KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFDTGvwZ3qofUZxq9cVmeVz0n9dfA9IRHwxyYvyLyboP";
    HUB_URL = "http://127.0.0.1:8090";
    EXTRA_FILESYSTEMS = lib.concatStringsSep "," extraFilesystems;
  };

  environmentFile = config.sops.templates."beszel-agent.env".path;

  smartmon = {
    enable = true;
    deviceAllow = [
      "/dev/sda"
      "/dev/sdb"
    ];
  };

  openFirewall = false;
};

server.services.beszelAgent.tcpPorts = lib.mkDefault [ agentPort ];

systemd.services.beszel-agent.serviceConfig.StateDirectory = "beszel-agent";
}
