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
    "myraid filesystem UUID"
    "/dev/disk/by-uuid/f316b340-b988-4306-8164-9f7d11250a55"
    config.fileSystems."/mnt/myraid".device)
  (assertEqual
    "backup filesystem UUID"
    "/dev/disk/by-uuid/2f26abd3-1603-4c8d-890c-a8a8aea9c5f1"
    config.fileSystems."/mnt/backup".device)
  (assertContains "myraid mount options" "nofail" config.fileSystems."/mnt/myraid".options)
  (assertContains "backup mount options" "nofail" config.fileSystems."/mnt/backup".options)
]
