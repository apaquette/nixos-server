{ config }:

let
  storage = config.server.storage;

  volumeForRole = role: consumer:
    let
      volumeName = storage.roles.${role} or null;
    in
    if volumeName == null then
      throw "${consumer} requires server.storage.roles.${role} to be assigned."
    else if !(builtins.hasAttr volumeName storage.volumes) then
      throw "server.storage.roles.${role} references unknown volume '${volumeName}' for ${consumer}."
    else
      storage.volumes.${volumeName};
in
{
  inherit volumeForRole;

  mountPointForRole = role: consumer:
    (volumeForRole role consumer).mountPoint;
}
