{ config, helpers, ... }:

let
  scripts = [
    "homelab-backup-ntfy"
    "homelab-disk-health"
    "homelab-storage-health"
    "homelab-storage-ntfy"
  ];

  script = name: config.environment.etc."homelab/scripts/${name}";

  testsFor = name: [
    (helpers.assertEqual
      "${name} enabled"
      true
      (script name).enable)

    (helpers.assertEqual
      "${name} target"
      "homelab/scripts/${name}"
      (script name).target)

    (helpers.assertEqual
      "${name} mode"
      "symlink"
      (script name).mode)

    (helpers.assertEqual
      "${name} uid"
      0
      (script name).uid)

    (helpers.assertEqual
      "${name} gid"
      0
      (script name).gid)

    (helpers.assertPathExists
      "${name} repository source"
      ../scripts/${name})
  ];


in
builtins.concatLists (map testsFor scripts)
