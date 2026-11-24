{ config, lib, helpers, ... }:

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

  scriptText = name:
    builtins.readFile (script name).source;

  notificationTests = [
    (helpers.assertEqual
      "backup notification URL is generated from host settings"
      true
      (lib.hasInfix
        "NTFY_URL='${config.server.notifications.ntfy.baseUrl}/${config.server.notifications.ntfy.backupTopic}'"
        (scriptText "homelab-backup-ntfy")))

    (helpers.assertEqual
      "system notification URL is generated from host settings"
      true
      (lib.hasInfix
        "NTFY_URL='${config.server.notifications.ntfy.baseUrl}/${config.server.notifications.ntfy.systemTopic}'"
        (scriptText "homelab-storage-ntfy")))

    (helpers.assertEqual
      "disk-health notification URL is generated from host settings"
      true
      (lib.hasInfix
        "NTFY_URL='${config.server.notifications.ntfy.baseUrl}/${config.server.notifications.ntfy.systemTopic}'"
        (scriptText "homelab-disk-health")))

    (helpers.assertEqual
      "generated notification scripts contain no unresolved endpoint placeholders"
      false
      (lib.hasInfix
        "@NTFY_"
        (scriptText "homelab-disk-health")))
  ];

in
builtins.concatLists (map testsFor scripts) ++ notificationTests
