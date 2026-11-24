{ config, lib, ... }:

let
  storage = config.server.storage;
  volumeMountPoints = map
    (volume: volume.mountPoint)
    (builtins.attrValues storage.volumes);

  roleAssertions = lib.mapAttrsToList
    (role: volumeName: {
      assertion = builtins.hasAttr volumeName storage.volumes;
      message = "server.storage.roles.${role} references unknown volume '${volumeName}'.";
    })
    storage.roles;
in
{
  assertions = [
    {
      assertion =
        builtins.length volumeMountPoints
        == builtins.length (lib.unique volumeMountPoints);
      message = "Each server.storage.volumes entry must use a unique mountPoint.";
    }
  ] ++ roleAssertions;

  services.fstrim.enable = true;

  fileSystems = lib.mapAttrs'
    (_: volume:
      lib.nameValuePair volume.mountPoint {
        inherit (volume) device fsType options;
      })
    storage.volumes;
}
