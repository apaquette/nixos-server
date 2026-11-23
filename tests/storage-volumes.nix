{ config, helpers, ... }:

with helpers;

[
  (assertEqual
    "host storage volume inventory"
    {
      primary = {
        device = "/dev/disk/by-uuid/f316b340-b988-4306-8164-9f7d11250a55";
        mountPoint = "/mnt/myraid";
        fsType = "ext4";
        options = [ "nofail" ];
      };
      backup = {
        device = "/dev/disk/by-uuid/2f26abd3-1603-4c8d-890c-a8a8aea9c5f1";
        mountPoint = "/mnt/backup";
        fsType = "ext4";
        options = [ "nofail" ];
      };
    }
    config.server.storage.volumes)

  (assertEqual
    "host storage role assignments"
    {
      applicationData = "primary";
      localBackup = "backup";
    }
    config.server.storage.roles)

  (assertEqual
    "application data role resolves to its volume mount point"
    "/mnt/myraid"
    config.server.storage.volumes.${config.server.storage.roles.applicationData}.mountPoint)

  (assertEqual
    "local backup role resolves to its volume mount point"
    "/mnt/backup"
    config.server.storage.volumes.${config.server.storage.roles.localBackup}.mountPoint)

  (assertEqual
    "primary volume mounted at declared mount point"
    "/dev/disk/by-uuid/f316b340-b988-4306-8164-9f7d11250a55"
    config.fileSystems."/mnt/myraid".device)

  (assertEqual
    "primary volume filesystem type"
    "ext4"
    config.fileSystems."/mnt/myraid".fsType)

  (assertEqual
    "primary volume mount options"
    [ "nofail" ]
    config.fileSystems."/mnt/myraid".options)

  (assertEqual
    "backup volume mounted at declared mount point"
    "/dev/disk/by-uuid/2f26abd3-1603-4c8d-890c-a8a8aea9c5f1"
    config.fileSystems."/mnt/backup".device)

  (assertEqual
    "backup volume filesystem type"
    "ext4"
    config.fileSystems."/mnt/backup".fsType)

  (assertEqual
    "backup volume mount options"
    [ "nofail" ]
    config.fileSystems."/mnt/backup".options)
]
