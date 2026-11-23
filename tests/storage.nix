{ config, helpers, ... }:

with helpers;

[
  (assertEqual "fstrim enabled" true config.services.fstrim.enable)
  (assertEqual "RAID enablement" true config.boot.swraid.enable)
  (assertEqual
    "RAID array configuration"
    "HOMEHOST <system>
MAILADDR root
ARRAY /dev/md/0 metadata=1.2 UUID=06feb5d7:8068ed2e:0d93f17f:649590b9
"
    config.boot.swraid.mdadmConf)
  (assertEqual
    "data filesystem device"
    config.server.storage.dataDevice
    config.fileSystems.${config.server.storage.dataRoot}.device)
  (assertEqual
    "backup filesystem device"
    config.server.storage.backupDevice
    config.fileSystems.${config.server.storage.backupRoot}.device)
  (assertContains "myraid mount options" "nofail" config.fileSystems.${config.server.storage.dataRoot}.options)
  (assertContains "backup mount options" "nofail" config.fileSystems.${config.server.storage.backupRoot}.options)
]
