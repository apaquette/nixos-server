{
  server.storage = {
    dataRoot = "/mnt/myraid";
    backupRoot = "/mnt/backup";
    dataDevice = "/dev/disk/by-uuid/f316b340-b988-4306-8164-9f7d11250a55";
    backupDevice = "/dev/disk/by-uuid/2f26abd3-1603-4c8d-890c-a8a8aea9c5f1";
    raidDevice = "/dev/md0";
  };

  # This RAID array is specific to the homelab's attached storage hardware.
  boot.swraid = {
    enable = true;
    mdadmConf = ''
      HOMEHOST <system>
      MAILADDR root
      ARRAY /dev/md/0 metadata=1.2 UUID=06feb5d7:8068ed2e:0d93f17f:649590b9
    '';
  };
}
