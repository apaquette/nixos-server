{ config, lib, helpers, ... }:

let
  backups = config.services.restic.backups;

  backup = name: backups.${name};

  immichUploadLocation = builtins.dirOf config.services.immich.mediaLocation;

  serviceBackups = [
    "immich"
    "nextcloud"
    "minecraft"
    "jellyfin"
    "sonarr"
    "radarr"
    "beszel"
    "ntfy"
  ];

  allBackups = serviceBackups ++ [
    "maintenance"
    "check"
  ];

  nextcloudPrepare = (backup "nextcloud").backupPrepareCommand;
  nextcloudCleanup = (backup "nextcloud").backupCleanupCommand;

  assertBackupExists = name: {
    assertion = builtins.hasAttr name backups;
    message = "Restic backup '${name}' must be configured.";
  };

  assertRepository = name:
    helpers.assertEqual
      "Restic repository for ${name}"
      "/mnt/backup/Restic/homelab"
      (backup name).repository;

  assertPasswordFile = name:
    helpers.assertEqual
      "Restic password file for ${name}"
      config.sops.secrets."restic-repository-password".path
      (backup name).passwordFile;

  assertPersistentTimer = name:
    helpers.assertEqual
      "Restic backup ${name} Persistent"
      true
      (backup name).timerConfig.Persistent;

  assertInitialized = name:
    helpers.assertEqual
      "Restic backup ${name} initialize"
      true
      (backup name).initialize;

  assertRootUser = name:
    helpers.assertEqual
      "Restic backup ${name} user"
      "root"
      (backup name).user;

  assertFailureNotification = name: {
    assertion =
      builtins.elem
        "homelab-backup-notify@%p.service"
        config.systemd.services."restic-backups-${name}".onFailure;
    message =
      "Restic backup service '${name}' must notify on failure.";
  };

  assertTag = name: {
    assertion =
      builtins.elem "--tag" (backup name).extraBackupArgs
      && builtins.elem name (backup name).extraBackupArgs;
    message =
      "Restic backup '${name}' must tag snapshots with '${name}'.";
  };

  assertRepositoryMount = name: {
    assertion =
      builtins.elem
        "/mnt/backup/Restic/homelab"
        config.systemd.services."restic-backups-${name}".unitConfig.RequiresMountsFor;
    message =
      "Restic backup service '${name}' must require the local backup repository mount.";
  };

  assertBackupPathMount = name: path: {
    assertion =
      builtins.elem
        path
        config.systemd.services."restic-backups-${name}".unitConfig.RequiresMountsFor;
    message =
      "Restic backup service '${name}' must require mount path '${path}'.";
  };

  orderingAssertions =
    lib.flatten (
      lib.imap0
        (
          index: name:
          if index == 0 then
            [ ]
          else
            let
              previous = builtins.elemAt serviceBackups (index - 1);
            in
            [
              {
                assertion =
                  builtins.elem
                    "restic-backups-${previous}.service"
                    config.systemd.services."restic-backups-${name}".after;
                message =
                  "Restic backup '${name}' must run after '${previous}'.";
              }
            ]
        )
        serviceBackups
    );

  maintenanceOrderingAssertions =
    map
      (
        name:
        {
          assertion =
            builtins.elem
              "restic-backups-${name}.service"
              config.systemd.services.restic-backups-maintenance.after;
          message =
            "Restic maintenance must run after '${name}'.";
        }
      )
      serviceBackups;

  applicationMountAssertions = [
    (assertBackupPathMount
      "immich"
      immichUploadLocation)

    (assertBackupPathMount
      "nextcloud"
      config.services.nextcloud.home)

    (assertBackupPathMount
      "nextcloud"
      config.services.nextcloud.settings.datadirectory)

    (assertBackupPathMount
      "minecraft"
      config.services.minecraft-server.dataDir)

    (assertBackupPathMount
      "jellyfin"
      config.services.jellyfin.dataDir)

    (assertBackupPathMount
      "sonarr"
      config.services.sonarr.dataDir)

    (assertBackupPathMount
      "radarr"
      config.services.radarr.dataDir)

    (assertBackupPathMount
      "beszel"
      "/var/lib/private/beszel-hub")

    (assertBackupPathMount
      "ntfy"
      "/var/lib/private/ntfy-sh")
  ];

  resticCheckService =
    config.systemd.services."restic-backups-check" or {};

  offsiteCopy =
    config.systemd.services."restic-offsite-copy" or {};

  offsiteCopyTimer =
    config.systemd.timers."restic-offsite-copy" or {};

  restoreTest =
    config.systemd.services."restic-offsite-restore-test" or {};

  restoreTestTimer =
    config.systemd.timers."restic-offsite-restore-test" or {};

  offsiteFullCheck =
    config.systemd.services."restic-offsite-full-check" or {};

  offsiteFullCheckTimer =
    config.systemd.timers."restic-offsite-full-check" or {};

  offsiteFullCheckEnvironment =
    offsiteFullCheck.environment or {};

  offsiteFullCheckServiceConfig =
    offsiteFullCheck.serviceConfig or {};

  offsiteFullCheckTimerConfig =
    offsiteFullCheckTimer.timerConfig or {};

  restoreTestEnvironment =
    restoreTest.environment or {};

  restoreTestServiceConfig =
    restoreTest.serviceConfig or {};

  restoreTestTimerConfig =
    restoreTestTimer.timerConfig or {};

  restoreTestScript =
    if builtins.pathExists ../scripts/restic-offsite-restore-test
    then builtins.readFile ../scripts/restic-offsite-restore-test
    else "";
  r2EnvTemplate =
    config.sops.templates."restic-r2.env" or {};
  offsiteCopyScript =
    builtins.readFile ../scripts/restic-offsite-copy;


in
lib.flatten [
  # --------------------------------------------------------------------------
  # Overall Restic job structure
  # --------------------------------------------------------------------------

  (map assertBackupExists allBackups)
  (map assertRepository allBackups)
  (map assertPasswordFile allBackups)
  (map assertPersistentTimer allBackups)
  (map assertInitialized allBackups)
  (map assertRootUser allBackups)

  (map assertFailureNotification allBackups)

  (map assertTag serviceBackups)

  (map assertRepositoryMount allBackups)

  applicationMountAssertions

  orderingAssertions
  maintenanceOrderingAssertions

  {
    assertion =
      builtins.elem
        "restic-backups-maintenance.service"
        config.systemd.services.restic-backups-check.after;
    message =
      "Restic repository check must run after maintenance/pruning.";
  }

  {
    assertion = !(builtins.hasAttr "homelab-app-backup" config.systemd.services);
    message =
      "The obsolete monolithic homelab-app-backup service must not exist.";
  }

  {
    assertion = !(builtins.hasAttr "homepage" backups);
    message =
      "Homepage must remain excluded from the Restic application backup set.";
  }

  # --------------------------------------------------------------------------
  # Immich
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Immich backup media location"
    immichUploadLocation
    (backup "immich").paths)

  (helpers.assertContains
    "Immich database dump path"
    "/run/restic-backups-immich/immich.dump"
    (backup "immich").paths)

  {
    assertion =
      builtins.hasInfix
        "immich-server.service"
        (backup "immich").backupPrepareCommand;
    message =
      "Immich backup must stop immich-server before creating the backup.";
  }

  {
    assertion =
      builtins.hasInfix
        "immich-server.service"
        (backup "immich").backupCleanupCommand;
    message =
      "Immich backup must restart immich-server after the backup.";
  }

  {
    assertion =
      builtins.hasInfix
        "pg_dump"
        (backup "immich").backupPrepareCommand;
    message =
      "Immich backup must create a PostgreSQL database dump.";
  }

  {
    assertion =
      builtins.hasInfix
        "--format=custom"
        (backup "immich").backupPrepareCommand;
    message =
      "Immich database backup must use PostgreSQL custom format.";
  }

  {
    assertion =
      builtins.hasInfix
        "pg_restore --list"
        (backup "immich").backupPrepareCommand;
    message =
      "Immich backup must validate the PostgreSQL archive.";
  }

  # --------------------------------------------------------------------------
  # Nextcloud
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Nextcloud backup home"
    config.services.nextcloud.home
    (backup "nextcloud").paths)

  (helpers.assertContains
    "Nextcloud backup data directory"
    config.services.nextcloud.settings.datadirectory
    (backup "nextcloud").paths)

  (helpers.assertContains
    "Nextcloud database dump path"
    "/run/restic-backups-nextcloud/nextcloud.dump"
    (backup "nextcloud").paths)

  {
    assertion =
      builtins.hasInfix
        "nextcloud-occ status --output=json"
        nextcloudPrepare;
    message =
      "Nextcloud backup must inspect existing maintenance state.";
  }

  {
    assertion =
      builtins.hasInfix
        "maintenance:mode --on"
        nextcloudPrepare;
    message =
      "Nextcloud backup must enable maintenance mode when needed.";
  }

  {
    assertion =
      builtins.hasInfix
        "maintenance-enabled-by-backup"
        nextcloudPrepare;
    message =
      "Nextcloud backup must record when it enabled maintenance mode.";
  }

  {
    assertion =
      builtins.hasInfix
        "touch"
        nextcloudPrepare;
    message =
      "Nextcloud prepare hook must record state with a marker.";
  }

  {
    assertion =
      builtins.hasInfix
        "nextcloud-cron.timer"
        nextcloudPrepare;
    message =
      "Nextcloud backup must account for the cron timer.";
  }

  {
    assertion =
      builtins.hasInfix
        "nextcloud-cron.service"
        nextcloudPrepare;
    message =
      "Nextcloud backup must account for the cron service.";
  }

  {
    assertion =
      builtins.hasInfix
        "pg_dump"
        nextcloudPrepare;
    message =
      "Nextcloud backup must create a PostgreSQL database dump.";
  }

  {
    assertion =
      builtins.hasInfix
        "--format=custom"
        nextcloudPrepare;
    message =
      "Nextcloud database backup must use PostgreSQL custom format.";
  }

  {
    assertion =
      builtins.hasInfix
        "pg_restore --list"
        nextcloudPrepare;
    message =
      "Nextcloud backup must validate the PostgreSQL archive.";
  }

  {
    assertion =
      builtins.hasInfix
        "maintenance-enabled-by-backup"
        nextcloudCleanup;
    message =
      "Nextcloud cleanup must inspect the maintenance-state marker.";
  }

  {
    assertion =
      builtins.hasInfix
        "maintenance:mode --off"
        nextcloudCleanup;
    message =
      "Nextcloud cleanup must restore maintenance mode when this backup enabled it.";
  }

  {
    assertion =
      builtins.hasInfix
        "nextcloud-cron.service"
        nextcloudCleanup;
    message =
      "Nextcloud cleanup must restore the cron service state.";
  }

  {
    assertion =
      builtins.hasInfix
        "nextcloud-cron.timer"
        nextcloudCleanup;
    message =
      "Nextcloud cleanup must restore the cron timer state.";
  }

  {
    assertion =
      builtins.hasInfix
        "rm -f"
        nextcloudCleanup;
    message =
      "Nextcloud cleanup must remove temporary state.";
  }

  # --------------------------------------------------------------------------
  # Minecraft
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Minecraft backup data directory"
    config.services.minecraft-server.dataDir
    (backup "minecraft").paths)

  {
    assertion =
      builtins.hasInfix
        "minecraft-server.service"
        (backup "minecraft").backupPrepareCommand;
    message =
      "Minecraft backup must stop minecraft-server.";
  }

  {
    assertion =
      builtins.hasInfix
        "minecraft-server.service"
        (backup "minecraft").backupCleanupCommand;
    message =
      "Minecraft backup must restart minecraft-server.";
  }

  # --------------------------------------------------------------------------
  # Jellyfin
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Jellyfin backup data directory"
    config.services.jellyfin.dataDir
    (backup "jellyfin").paths)

  {
    assertion =
      builtins.hasInfix
        config.services.jellyfin.logDir
        (lib.concatStringsSep " " (backup "jellyfin").exclude);
    message =
      "Jellyfin backup must exclude the log directory.";
  }

  {
    assertion =
      !(builtins.elem
        "/mnt/myraid/Videos"
        (backup "jellyfin").paths);
    message =
      "Jellyfin backup must not include the media library.";
  }

  {
    assertion =
      builtins.hasInfix
        "jellyfin.service"
        (backup "jellyfin").backupPrepareCommand;
    message =
      "Jellyfin backup must stop jellyfin.";
  }

  {
    assertion =
      builtins.hasInfix
        "jellyfin.service"
        (backup "jellyfin").backupCleanupCommand;
    message =
      "Jellyfin backup must restart jellyfin.";
  }

  # --------------------------------------------------------------------------
  # Sonarr
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Sonarr backup data directory"
    config.services.sonarr.dataDir
    (backup "sonarr").paths)

  {
    assertion =
      builtins.hasInfix
        "sonarr.service"
        (backup "sonarr").backupPrepareCommand;
    message =
      "Sonarr backup must stop sonarr.";
  }

  {
    assertion =
      builtins.hasInfix
        "sonarr.service"
        (backup "sonarr").backupCleanupCommand;
    message =
      "Sonarr backup must restart sonarr.";
  }

  # --------------------------------------------------------------------------
  # Radarr
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Radarr backup data directory"
    config.services.radarr.dataDir
    (backup "radarr").paths)

  {
    assertion =
      builtins.hasInfix
        "radarr.service"
        (backup "radarr").backupPrepareCommand;
    message =
      "Radarr backup must stop radarr.";
  }

  {
    assertion =
      builtins.hasInfix
        "radarr.service"
        (backup "radarr").backupCleanupCommand;
    message =
      "Radarr backup must restart radarr.";
  }

  # --------------------------------------------------------------------------
  # Beszel
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Beszel backup data directory"
    "/var/lib/private/beszel-hub"
    (backup "beszel").paths)

  {
    assertion =
      builtins.hasInfix
        "beszel-hub.service"
        (backup "beszel").backupPrepareCommand;
    message =
      "Beszel backup must stop beszel-hub.";
  }

  {
    assertion =
      builtins.hasInfix
        "beszel-hub.service"
        (backup "beszel").backupCleanupCommand;
    message =
      "Beszel backup must restart beszel-hub.";
  }

  # --------------------------------------------------------------------------
  # ntfy
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "ntfy backup data directory"
    "/var/lib/private/ntfy-sh"
    (backup "ntfy").paths)

  {
    assertion =
      builtins.hasInfix
        "ntfy-sh.service"
        (backup "ntfy").backupPrepareCommand;
    message =
      "ntfy backup must stop ntfy-sh.";
  }

  {
    assertion =
      builtins.hasInfix
        "ntfy-sh.service"
        (backup "ntfy").backupCleanupCommand;
    message =
      "ntfy backup must restart ntfy-sh.";
  }

  # --------------------------------------------------------------------------
  # Retention / repository maintenance
  # --------------------------------------------------------------------------

  (helpers.assertContains
    "Restic daily retention"
    "--keep-daily 14"
    (backup "maintenance").pruneOpts)

  (helpers.assertContains
    "Restic weekly retention"
    "--keep-weekly 8"
    (backup "maintenance").pruneOpts)

  (helpers.assertContains
    "Restic monthly retention"
    "--keep-monthly 6"
    (backup "maintenance").pruneOpts)

  {
    assertion = (backup "maintenance").paths == [ ];
    message =
      "Restic maintenance must not create a backup snapshot.";
  }

  {
    assertion = (backup "maintenance").runCheck == false;
    message =
      "Restic maintenance must not run a repository check.";
  }

  {
    assertion = (backup "check").paths == [ ];
    message =
      "Restic check must not create a backup snapshot.";
  }

  {
    assertion = (backup "check").runCheck;
    message =
      "Restic check must run repository integrity checks.";
  }

  {
    assertion =
      builtins.elem
        "restic-backups-maintenance.service"
        config.systemd.services.restic-backups-check.after;
    message =
      "Restic check must wait for maintenance.";
  }

  # --------------------------------------------------------------------------
  # Timer schedule sanity
  # --------------------------------------------------------------------------

  {
    assertion =
      (backup "nextcloud").timerConfig.OnCalendar == "*-*-* 02:30:00";
    message =
      "Nextcloud backup must run at 02:30.";
  }

  {
    assertion =
      (backup "immich").timerConfig.OnCalendar == "*-*-* 03:00:00";
    message =
      "Immich backup must run at 03:00.";
  }

  {
    assertion =
      (backup "minecraft").timerConfig.OnCalendar == "*-*-* 03:30:00";
    message =
      "Minecraft backup must run at 03:30.";
  }

  {
    assertion =
      (backup "jellyfin").timerConfig.OnCalendar == "*-*-* 04:00:00";
    message =
      "Jellyfin backup must run at 04:00.";
  }

  {
    assertion =
      (backup "sonarr").timerConfig.OnCalendar == "*-*-* 04:15:00";
    message =
      "Sonarr backup must run at 04:15.";
  }

  {
    assertion =
      (backup "radarr").timerConfig.OnCalendar == "*-*-* 04:30:00";
    message =
      "Radarr backup must run at 04:30.";
  }

  {
    assertion =
      (backup "beszel").timerConfig.OnCalendar == "*-*-* 04:45:00";
    message =
      "Beszel backup must run at 04:45.";
  }

  {
    assertion =
      (backup "ntfy").timerConfig.OnCalendar == "*-*-* 05:00:00";
    message =
      "ntfy backup must run at 05:00.";
  }

  {
    assertion =
      (backup "maintenance").timerConfig.OnCalendar == "*-*-* 05:30:00";
    message =
      "Restic maintenance must run at 05:30.";
  }

  {
    assertion =
      (backup "check").timerConfig.OnCalendar == "Sun *-*-* 06:00:00";
    message =
      "Restic check must run Sunday at 06:00.";
  }

  # v1.1.0 — Off-site Restic replication

  {
    assertion =
      builtins.hasAttr "restic-offsite-copy"
        config.systemd.services;
    message =
      "Off-site Restic copy service must be defined.";
  }

  {
    assertion =
      builtins.hasAttr "restic-offsite-copy"
        config.systemd.timers;
    message =
      "Off-site Restic copy timer must be defined.";
  }

  {
    assertion =
      builtins.hasAttr "restic-r2.env"
        config.sops.templates;
    message =
      "R2 credentials must use a SOPS-managed environment template.";
  }

  {
    assertion =
      builtins.pathExists ../scripts/restic-offsite-copy;
    message =
      "Off-site Restic replication script must exist.";
  }

  (helpers.assertEqual
    "Off-site copy service type"
    "oneshot"
    (offsiteCopy.serviceConfig.Type or null))

  (helpers.assertContains
    "Off-site copy requires local backup storage"
    "mnt-backup.mount"
    (offsiteCopy.requires or []))

  (helpers.assertContains
    "Off-site copy requires local repository mount"
    "/mnt/backup/Restic/homelab"
    (offsiteCopy.unitConfig.RequiresMountsFor or []))

  (helpers.assertContains
    "Off-site copy failure notification"
    "homelab-backup-notify@%p.service"
    (offsiteCopy.onFailure or []))

  (helpers.assertEqual
    "Off-site copy EnvironmentFile"
    (r2EnvTemplate.path or null)
    (offsiteCopy.serviceConfig.EnvironmentFile or null))

  (helpers.assertEqual
    "Off-site copy runs Monday through Saturday at 08:00"
    "Mon..Sat *-*-* 08:00:00"
    (offsiteCopyTimer.timerConfig.OnCalendar or null))

  (helpers.assertEqual
    "Off-site timer does not replay missed weekday runs on Sunday"
    false
    (offsiteCopyTimer.timerConfig.Persistent or null))

  (helpers.assertContains
    "Off-site copy runs after Restic maintenance"
    "restic-backups-maintenance.service"
    (offsiteCopy.after or []))

  (helpers.assertContains
    "Off-site copy runs after Restic integrity check"
    "restic-backups-check.service"
    (offsiteCopy.after or []))

  {
    assertion =
      builtins.hasInfix "--from-repo" offsiteCopyScript;
    message =
      "Off-site copy must specify the source repository.";
  }

  {
    assertion =
      builtins.hasInfix "--from-password-file" offsiteCopyScript;
    message =
      "Off-site copy must use the source repository password.";
  }

  {
    assertion =
      builtins.hasInfix "--password-file" offsiteCopyScript;
    message =
      "Off-site copy must use the destination repository password.";
  }

  (helpers.assertEqual
    "Off-site source repository"
    "/mnt/backup/Restic/homelab"
    offsiteCopy.environment.RESTIC_FROM_REPOSITORY)

  (helpers.assertEqual
    "Off-site source password file"
    config.sops.secrets."restic-repository-password".path
    offsiteCopy.environment.RESTIC_FROM_PASSWORD_FILE)

  (helpers.assertEqual
    "Off-site destination password file"
    config.sops.secrets."restic-r2-repository-password".path
    offsiteCopy.environment.RESTIC_PASSWORD_FILE)

  (helpers.assertEqual
    "Cloudflare R2 region"
    "auto"
    offsiteCopy.environment.AWS_DEFAULT_REGION)

  (helpers.assertContains
    "Successful Restic integrity check triggers off-site replication"
    "restic-offsite-copy.service"
    (resticCheckService.onSuccess or []))
  # v1.1.0 — Automated off-site restore testing

  {
    assertion =
      builtins.hasAttr
        "restic-offsite-restore-test"
        config.systemd.services;
    message =
      "Automated off-site restore-test service must be defined.";
  }

  {
    assertion =
      builtins.hasAttr
        "restic-offsite-restore-test"
        config.systemd.timers;
    message =
      "Automated off-site restore-test timer must be defined.";
  }

  {
    assertion =
      builtins.pathExists ../scripts/restic-offsite-restore-test;
    message =
      "Automated off-site restore-test script must exist.";
  }

  (helpers.assertEqual
    "Off-site restore-test service type"
    "oneshot"
    (restoreTestServiceConfig.Type or null))

  (helpers.assertContains
    "Off-site restore test waits for network availability"
    "network-online.target"
    (restoreTest.after or []))

  (helpers.assertContains
    "Off-site restore test wants network availability"
    "network-online.target"
    (restoreTest.wants or []))

  (helpers.assertContains
    "Off-site restore-test failure notification"
    "homelab-backup-notify@%p.service"
    (restoreTest.onFailure or []))

  (helpers.assertEqual
    "Off-site restore-test EnvironmentFile"
    (r2EnvTemplate.path or null)
    (restoreTestServiceConfig.EnvironmentFile or null))

  (helpers.assertEqual
    "Off-site restore-test repository"
    offsiteCopy.environment.RESTIC_REPOSITORY
    (restoreTestEnvironment.RESTIC_REPOSITORY or null))

  (helpers.assertEqual
    "Off-site restore-test password file"
    config.sops.secrets."restic-r2-repository-password".path
    (restoreTestEnvironment.RESTIC_PASSWORD_FILE or null))

  (helpers.assertEqual
    "Off-site restore-test region"
    "auto"
    (restoreTestEnvironment.AWS_DEFAULT_REGION or null))

  (helpers.assertEqual
    "Off-site restore test runs Tuesdays at 09:00"
    "Tue *-*-* 09:00:00"
    (restoreTestTimerConfig.OnCalendar or null))

  (helpers.assertEqual
    "Off-site restore-test timer persists across downtime"
    true
    (restoreTestTimerConfig.Persistent or null))

  (helpers.assertContains
    "Off-site restore-test timer is enabled"
    "timers.target"
    (restoreTestTimer.wantedBy or []))

  {
    assertion =
      builtins.hasInfix "restic restore latest" restoreTestScript;
    message =
      "Off-site restore test must restore the latest selected snapshot.";
  }

  {
    assertion =
      builtins.hasInfix "--tag ntfy" restoreTestScript;
    message =
      "Off-site restore test must select an ntfy snapshot.";
  }

  {
    assertion =
      builtins.hasInfix "auth.db" restoreTestScript;
    message =
      "Off-site restore test must validate the restored auth.db file.";
  }

  {
    assertion =
      builtins.hasInfix "mktemp -d" restoreTestScript;
    message =
      "Off-site restore test must use an isolated temporary directory.";
  }

  {
    assertion =
      builtins.hasInfix "trap " restoreTestScript;
    message =
      "Off-site restore test must clean up its temporary directory.";
  }

  # v1.1.0 — Remote retention policy

  {
    assertion =
      builtins.hasInfix "--group-by host,tags" offsiteCopyScript;
    message =
      "Off-site copy must use host and tag retention grouping.";
  }

  {
    assertion =
      builtins.hasInfix "--keep-daily 14" offsiteCopyScript;
    message =
      "Off-site copy must retain 14 daily snapshots.";
  }

  {
    assertion =
      builtins.hasInfix "--keep-weekly 8" offsiteCopyScript;
    message =
      "Off-site copy must retain 8 weekly snapshots.";
  }

  {
    assertion =
      builtins.hasInfix "--keep-monthly 6" offsiteCopyScript;
    message =
      "Off-site copy must retain 6 monthly snapshots.";
  }

  {
    assertion =
      builtins.hasInfix "--prune" offsiteCopyScript;
    message =
      "Off-site copy must prune data removed by retention.";
  }

  # v1.1.0 — Quarterly R2 full-data verification

  {
    assertion =
      builtins.hasAttr
        "restic-offsite-full-check"
        config.systemd.services;
    message =
      "Quarterly R2 full-data-check service must be defined.";
  }

  {
    assertion =
      builtins.hasAttr
        "restic-offsite-full-check"
        config.systemd.timers;
    message =
      "Quarterly R2 full-data-check timer must be defined.";
  }

  (helpers.assertEqual
    "Quarterly R2 full-data-check service type"
    "oneshot"
    (offsiteFullCheckServiceConfig.Type or null))

   {
    assertion =
      builtins.hasInfix
        "--read-data"
        (offsiteFullCheckServiceConfig.ExecStart or "");
    message =
      "Quarterly R2 full-data check must use --read-data.";
  }

  (helpers.assertContains
    "Quarterly R2 full-data check waits for network"
    "network-online.target"
    (offsiteFullCheck.after or []))

  (helpers.assertContains
    "Quarterly R2 full-data-check failure notification"
    "homelab-backup-notify@%p.service"
    (offsiteFullCheck.onFailure or []))

  (helpers.assertEqual
    "Quarterly R2 check uses the R2 environment template"
    (r2EnvTemplate.path or null)
    (offsiteFullCheckServiceConfig.EnvironmentFile or null))

  (helpers.assertEqual
    "Quarterly R2 check uses the off-site repository"
    offsiteCopy.environment.RESTIC_REPOSITORY
    (offsiteFullCheckEnvironment.RESTIC_REPOSITORY or null))

  (helpers.assertEqual
    "Quarterly R2 check uses the R2 password file"
    config.sops.secrets."restic-r2-repository-password".path
    (offsiteFullCheckEnvironment.RESTIC_PASSWORD_FILE or null))

  (helpers.assertEqual
    "Quarterly R2 check uses the correct region"
    "auto"
    (offsiteFullCheckEnvironment.AWS_DEFAULT_REGION or null))

  (helpers.assertEqual
    "Off-site retention starts in dry-run mode"
    "enforce"
    (offsiteCopy.environment.RESTIC_OFFSITE_RETENTION_MODE or null))

  (helpers.assertEqual
    "Quarterly R2 full-data check runs at 03:00 on the first day of each quarter"
    "*-01,04,07,10-01 12:00:00"
    (offsiteFullCheckTimerConfig.OnCalendar or null))

  (helpers.assertEqual
    "Quarterly R2 full-data-check timer persists across downtime"
    true
    (offsiteFullCheckTimerConfig.Persistent or null))

  (helpers.assertContains
    "Quarterly R2 full-data-check timer is enabled"
    "timers.target"
    (offsiteFullCheckTimer.wantedBy or []))
]
