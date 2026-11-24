{
  server.storage = {
    volumes = {
      fast = {
        device = "/dev/disk/by-label/synthetic-data";
        mountPoint = "/srv/synthetic-data";
        fsType = "xfs";
        options = [ "nofail" "noatime" ];
      };
      archive = {
        device = "/dev/disk/by-label/synthetic-archive";
        mountPoint = "/srv/synthetic-archive";
        fsType = "ext4";
        options = [ "nofail" ];
      };
    };

    roles = {
      applicationData = "fast";
      localBackup = "archive";
    };

    raidDevice = null;
  };
}
