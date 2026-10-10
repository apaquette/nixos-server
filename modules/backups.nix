
{ config, lib, pkgs, ... }:

let
  repository = "/mnt/backup/Restic/homelab";
  passwordFile = config.sops.secrets."restic-repository-password".path;

  r2AccountId = "08a653e653431727545c1cbbc844423d";
  r2Bucket = "homelab-restic";
  r2Prefix = "homelab";

  r2Repository = "s3:https://${r2AccountId}.r2.cloudflarestorage.com/${r2Bucket}/${r2Prefix}";

  immichUploadLocation = builtins.dirOf config.services.immich.mediaLocation;

  backupOrder = [
    "nextcloud"
    "immich"
    "minecraft"
    "jellyfin"
    "sonarr"
    "radarr"
    "beszel"
    "ntfy"
  ];

  mkServiceBackup =
    {
      name,
      schedule,
      paths,
      service,
      exclude ? [ ],
    }:
    let
      stateFile = "/run/restic-backups-${name}/service-was-active";
    in
    {
      inherit
        paths
        exclude
        repository
        passwordFile
        ;

      initialize = true;
      user = "root";

      extraBackupArgs = [
        "--tag"
        name
      ];

      timerConfig = {
        OnCalendar = schedule;
        Persistent = true;
      };

      backupPrepareCommand = ''
        set -euo pipefail

        state=${lib.escapeShellArg stateFile}

        ${pkgs.coreutils}/bin/rm -f "$state"

        if ${pkgs.systemd}/bin/systemctl is-active --quiet ${service}; then
          ${pkgs.coreutils}/bin/touch "$state"
          ${pkgs.systemd}/bin/systemctl stop ${service}
        fi
      '';

      backupCleanupCommand = ''
        set -euo pipefail

        state=${lib.escapeShellArg stateFile}

        if ${pkgs.coreutils}/bin/test -f "$state"; then
          ${pkgs.systemd}/bin/systemctl start ${service}
          ${pkgs.coreutils}/bin/rm -f "$state"
        fi
      '';
    };

  immichBackup = {
    repository = repository;
    passwordFile = passwordFile;
    initialize = true;
    user = "root";

    paths = [
      immichUploadLocation
      "/run/restic-backups-immich/immich.dump"
    ];

    extraBackupArgs = [
      "--tag"
      "immich"
    ];

    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };

    backupPrepareCommand = ''
      set -euo pipefail

      state="/run/restic-backups-immich/service-was-active"
      dump="/run/restic-backups-immich/immich.dump"

      ${pkgs.coreutils}/bin/rm -f "$state" "$dump"

      if ${pkgs.systemd}/bin/systemctl is-active --quiet immich-server.service; then
        ${pkgs.coreutils}/bin/touch "$state"
        ${pkgs.systemd}/bin/systemctl stop immich-server.service
      fi

      ${pkgs.util-linux}/bin/runuser -u postgres -- \
        ${pkgs.postgresql_17}/bin/pg_dump \
          --format=custom \
          --dbname=${lib.escapeShellArg config.services.immich.database.name} \
          > "$dump"

      ${pkgs.postgresql_17}/bin/pg_restore --list "$dump" > /dev/null
    '';

    backupCleanupCommand = ''
      set -euo pipefail

      exit_code=0

      ${pkgs.coreutils}/bin/rm -f \
        /run/restic-backups-immich/immich.dump \
        || exit_code=1

      if ${pkgs.coreutils}/bin/test -f \
        /run/restic-backups-immich/service-was-active
      then
        ${pkgs.systemd}/bin/systemctl start immich-server.service \
          || exit_code=1

        ${pkgs.coreutils}/bin/rm -f \
          /run/restic-backups-immich/service-was-active \
          || exit_code=1
      fi

      exit "$exit_code"
    '';
  };

  nextcloudBackup = {
    repository = repository;
    passwordFile = passwordFile;
    initialize = true;
    user = "root";

    paths = [
      config.services.nextcloud.home
      config.services.nextcloud.settings.datadirectory
      "/run/restic-backups-nextcloud/nextcloud.dump"
    ];

    extraBackupArgs = [
      "--tag"
      "nextcloud"
    ];

    timerConfig = {
      OnCalendar = "*-*-* 02:30:00";
      Persistent = true;
    };

    backupPrepareCommand = ''
      set -euo pipefail

      maintenance_state="/run/restic-backups-nextcloud/maintenance-enabled-by-backup"
      cron_service_state="/run/restic-backups-nextcloud/cron-service-was-active"
      cron_timer_state="/run/restic-backups-nextcloud/cron-timer-was-active"
      dump="/run/restic-backups-nextcloud/nextcloud.dump"

      ${pkgs.coreutils}/bin/rm -f \
        "$maintenance_state" \
        "$cron_service_state" \
        "$cron_timer_state" \
        "$dump"

      status_json="$(
        /run/current-system/sw/bin/nextcloud-occ \
          status \
          --output=json
      )"

      if [[ "$status_json" == *'"maintenance":true'* ]] ||
         [[ "$status_json" == *'"maintenance": true'* ]]
      then
        :
      else
        ${pkgs.coreutils}/bin/touch "$maintenance_state"

        /run/current-system/sw/bin/nextcloud-occ \
          maintenance:mode \
          --on
      fi

      if ${pkgs.systemd}/bin/systemctl is-active --quiet nextcloud-cron.timer; then
        ${pkgs.coreutils}/bin/touch "$cron_timer_state"
        ${pkgs.systemd}/bin/systemctl stop nextcloud-cron.timer
      fi

      if ${pkgs.systemd}/bin/systemctl is-active --quiet nextcloud-cron.service; then
        ${pkgs.coreutils}/bin/touch "$cron_service_state"
        ${pkgs.systemd}/bin/systemctl stop nextcloud-cron.service
      fi

      ${pkgs.util-linux}/bin/runuser -u postgres -- \
        ${pkgs.postgresql_17}/bin/pg_dump \
          --format=custom \
          --dbname=${lib.escapeShellArg config.services.nextcloud.config.dbname} \
          > "$dump"

      ${pkgs.postgresql_17}/bin/pg_restore --list "$dump" > /dev/null
    '';

    backupCleanupCommand = ''
      set -euo pipefail

      exit_code=0

      ${pkgs.coreutils}/bin/rm -f \
        /run/restic-backups-nextcloud/nextcloud.dump \
        || exit_code=1

      if ${pkgs.coreutils}/bin/test -f \
        /run/restic-backups-nextcloud/maintenance-enabled-by-backup
      then
        /run/current-system/sw/bin/nextcloud-occ \
          maintenance:mode \
          --off \
          || exit_code=1

        ${pkgs.coreutils}/bin/rm -f \
          /run/restic-backups-nextcloud/maintenance-enabled-by-backup \
          || exit_code=1
      fi

      if ${pkgs.coreutils}/bin/test -f \
        /run/restic-backups-nextcloud/cron-service-was-active
      then
        ${pkgs.systemd}/bin/systemctl start nextcloud-cron.service \
          || exit_code=1

        ${pkgs.coreutils}/bin/rm -f \
          /run/restic-backups-nextcloud/cron-service-was-active \
          || exit_code=1
      fi

      if ${pkgs.coreutils}/bin/test -f \
        /run/restic-backups-nextcloud/cron-timer-was-active
      then
        ${pkgs.systemd}/bin/systemctl start nextcloud-cron.timer \
          || exit_code=1

        ${pkgs.coreutils}/bin/rm -f \
          /run/restic-backups-nextcloud/cron-timer-was-active \
          || exit_code=1
      fi

      exit "$exit_code"
    '';
  };

  simpleBackups = {
    minecraft = mkServiceBackup {
      name = "minecraft";
      schedule = "*-*-* 03:30:00";
      paths = [
        config.services.minecraft-server.dataDir
      ];
      service = "minecraft-server.service";
    };

    jellyfin = mkServiceBackup {
      name = "jellyfin";
      schedule = "*-*-* 04:00:00";
      paths = [
        config.services.jellyfin.dataDir
      ];
      service = "jellyfin.service";
      exclude = [
        config.services.jellyfin.logDir
      ];
    };

    sonarr = mkServiceBackup {
      name = "sonarr";
      schedule = "*-*-* 04:15:00";
      paths = [
        config.services.sonarr.dataDir
      ];
      service = "sonarr.service";
    };

    radarr = mkServiceBackup {
      name = "radarr";
      schedule = "*-*-* 04:30:00";
      paths = [
        config.services.radarr.dataDir
      ];
      service = "radarr.service";
    };

    beszel = mkServiceBackup {
      name = "beszel";
      schedule = "*-*-* 04:45:00";
      paths = [
        "/var/lib/private/beszel-hub"
      ];
      service = "beszel-hub.service";
    };

    ntfy = mkServiceBackup {
      name = "ntfy";
      schedule = "*-*-* 05:00:00";
      paths = [
        "/var/lib/private/ntfy-sh"
      ];
      service = "ntfy-sh.service";
    };
  };

  mountPaths = {
    immich = [
      immichUploadLocation
    ];

    nextcloud = [
      config.services.nextcloud.home
      config.services.nextcloud.settings.datadirectory
    ];

    minecraft = [
      config.services.minecraft-server.dataDir
    ];

    jellyfin = [
      config.services.jellyfin.dataDir
    ];

    sonarr = [
      config.services.sonarr.dataDir
    ];

    radarr = [
      config.services.radarr.dataDir
    ];

    beszel = [
      "/var/lib/private/beszel-hub"
    ];

    ntfy = [
      "/var/lib/private/ntfy-sh"
    ];

    maintenance = [ ];
    check = [ ];
  };

  databaseBackups = [
    "nextcloud"
    "immich"
  ];

  appBackupSystemdOverrides =
    lib.listToAttrs (
      lib.imap0
        (
          index: name:
          let
            previous =
              if index == 0
              then null
              else builtins.elemAt backupOrder (index - 1);
          in
          {
            name = "restic-backups-${name}";

            value = {
              after =
                lib.optional
                  (previous != null)
                  "restic-backups-${previous}.service"
                ++ lib.optional
                  (builtins.elem name databaseBackups)
                  "postgresql.service";

              requires =
                lib.optional
                  (builtins.elem name databaseBackups)
                  "postgresql.service";

              onFailure = [
                "homelab-backup-notify@%p.service"
              ];

              unitConfig.RequiresMountsFor =
                [ repository ] ++ mountPaths.${name};
            };
          }
        )
        backupOrder
    )
    // {
      "restic-backups-maintenance" = {
        after =
          map
            (name: "restic-backups-${name}.service")
            backupOrder;

        onFailure = [
          "homelab-backup-notify@%p.service"
        ];

        unitConfig.RequiresMountsFor = [
          repository
        ];
      };

      "restic-backups-check" = {
        after = [
          "restic-backups-maintenance.service"
        ];
        onSuccess = [
          "restic-offsite-copy.service"
        ];
        onFailure = [
          "homelab-backup-notify@%p.service"
        ];

        unitConfig.RequiresMountsFor = [
          repository
        ];
      };
    


      "restic-offsite-copy" = {
        description = "Copy Restic snapshots to Cloudflare R2";

        after = [
          "network-online.target"
          "mnt-backup.mount"
          "restic-backups-maintenance.service"
          "restic-backups-check.service"
        ];

        wants = [
          "network-online.target"
        ];

        requires = [
          "mnt-backup.mount"
        ];

        onFailure = [
          "homelab-backup-notify@%p.service"
        ];

        unitConfig.RequiresMountsFor = [
          repository
        ];

        path = [
          pkgs.restic
	  pkgs.bash
        ];

        environment = {
          RESTIC_REPOSITORY = r2Repository;
          RESTIC_PASSWORD_FILE =
            config.sops.secrets."restic-r2-repository-password".path;

          RESTIC_FROM_REPOSITORY = repository;
          RESTIC_FROM_PASSWORD_FILE = passwordFile;

          AWS_DEFAULT_REGION = "auto";

	  HOME = "/var/lib/restic-offsite";
	  XDG_CACHE_HOME = "/var/cache/restic-offsite";
        };

        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.sops.templates."restic-r2.env".path;
	  StateDirectory = "restic-offsite";
	  CacheDirectory = "restic-offsite";
          ExecStart = "/etc/homelab/scripts/restic-offsite-copy";
        };
      };
   };
in
{
  services.restic.backups =
    simpleBackups
    // {
      immich = immichBackup;
      nextcloud = nextcloudBackup;

      maintenance = {
        repository = repository;
        passwordFile = passwordFile;
        initialize = true;
        user = "root";

        paths = [ ];

        timerConfig = {
          OnCalendar = "*-*-* 05:30:00";
          Persistent = true;
        };

   pruneOpts = [
    "--group-by host,tags"
    "--keep-daily 14"
    "--keep-weekly 8"
    "--keep-monthly 6"
  ];
      };

      check = {
        repository = repository;
        passwordFile = passwordFile;
        initialize = true;
        user = "root";

        paths = [ ];

        timerConfig = {
          OnCalendar = "Sun *-*-* 06:00:00";
          Persistent = true;
        };

        runCheck = true;
      };
    };

  systemd.services = appBackupSystemdOverrides;
  systemd.timers."restic-offsite-copy" = {
    wantedBy = [ "timers.target" ];
  
    timerConfig = {
      OnCalendar = "Mon..Sat *-*-* 08:00:00";
      Persistent = false;
    };
  };
}
