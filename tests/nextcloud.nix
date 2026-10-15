{ config, pkgs, lib, helpers, ... }:

let
  nativeEnabled = config.services.nextcloud.enable;

  packageVersion =
    if nativeEnabled
    then config.services.nextcloud.package.version
    else null;

  databaseType =
    if nativeEnabled
    then config.services.nextcloud.config.dbtype
    else null;

  databaseName =
    if nativeEnabled
    then config.services.nextcloud.config.dbname
    else null;

  databaseUser =
    if nativeEnabled
    then config.services.nextcloud.config.dbuser
    else null;

  databaseHost =
    if nativeEnabled
    then config.services.nextcloud.config.dbhost
    else null;

  databasePasswordFile =
    if nativeEnabled
    then config.services.nextcloud.config.dbpassFile
    else null;

  dataDirectory =
    if nativeEnabled
    then config.services.nextcloud.settings.datadirectory
    else null;

  nginxListen =
    if nativeEnabled
    then config.services.nginx.virtualHosts."cloud.alexpaquette.dev".listen
    else null;

  redisEnabled =
    if nativeEnabled
    then config.services.redis.servers.nextcloud.enable
    else false;

  redisCaching =
    if nativeEnabled
    then config.services.nextcloud.caching.redis
    else false;

  extraApps =
    if nativeEnabled
    then builtins.attrNames config.services.nextcloud.extraApps
    else [ ];
  
  calendarVersion =
    if nativeEnabled then
      let
        calendarStorePath =
          builtins.unsafeDiscardStringContext
            (toString config.services.nextcloud.extraApps.calendar);
      in
        (builtins.parseDrvName
          (builtins.baseNameOf calendarStorePath)
        ).version
    else null;

in
[
  (helpers.assertEqual
    "Nextcloud native service enabled"
    true
    nativeEnabled)

  {
    assertion =
      packageVersion != null
      && lib.versionAtLeast packageVersion "35.0.1";
    message =  "Native Nextcloud must use exactly 35.0.1 during this migration; the live instance is 35.0.1.";
  }

  (helpers.assertEqual
    "Nextcloud hostname"
    "cloud.alexpaquette.dev"
    (if nativeEnabled then config.services.nextcloud.hostName else null))

  (helpers.assertEqual
    "Nextcloud home"
    "/var/lib/nextcloud"
    (if nativeEnabled then config.services.nextcloud.home else null))

  (helpers.assertEqual
  "Nextcloud data directory"
  "/mnt/myraid/Nextcloud"
  (if nativeEnabled
   then config.services.nextcloud.settings.datadirectory
   else null))

  (helpers.assertEqual
    "Nextcloud database type"
    "pgsql"
    databaseType)

  (helpers.assertEqual
    "Nextcloud database name"
    "nextcloud"
    databaseName)

  (helpers.assertEqual
    "Nextcloud database user"
    "oc_admin"
    databaseUser)

  (helpers.assertEqual
    "Nextcloud database host"
    "127.0.0.1:5432"
    databaseHost)

  (helpers.assertEqual
    "Nextcloud database password file"
    config.sops.secrets."nextcloud-postgres-password".path
    databasePasswordFile)

  (helpers.assertEqual
    "Nextcloud HTTPS"
    true
    (if nativeEnabled then config.services.nextcloud.https else false))

  (helpers.assertEqual
    "Nextcloud admin user disabled"
    null
    (if nativeEnabled then config.services.nextcloud.config.adminuser else null))

  (helpers.assertEqual
    "Nextcloud admin password file disabled"
    null
    (if nativeEnabled then config.services.nextcloud.config.adminpassFile else null))

  (helpers.assertEqual
    "Nextcloud Redis configuration"
    true
    (if nativeEnabled then config.services.nextcloud.configureRedis else false))

  (helpers.assertEqual
    "Nextcloud Redis server enabled"
    true
    redisEnabled)

  (helpers.assertEqual
    "Nextcloud Redis caching"
    true
    redisCaching)

  (helpers.assertEqual
    "Nextcloud extra apps"
    [ "calendar" "contacts" "notes" "pantry" "tasks" "tickbuddy" ]
    (lib.sort builtins.lessThan extraApps))

  (helpers.assertEqual
    "Nextcloud app store enabled"
    true
    (if nativeEnabled then config.services.nextcloud.appstoreEnable else false))

 (helpers.assertEqual
  "Nextcloud nginx listen address and port"
  [ { addr = "127.0.0.1"; port = 8081; } ]
  (map
    (listener: {
      inherit (listener) addr port;
    })
    nginxListen))

  (helpers.assertEqual
    "Native PostgreSQL enabled"
    true
    config.services.postgresql.enable)

  (helpers.assertEqual
    "Native PostgreSQL package"
    pkgs.postgresql_17
    config.services.postgresql.package)

  (helpers.assertContains
    "Native PostgreSQL database"
    "nextcloud"
    config.services.postgresql.ensureDatabases)

  (helpers.assertEqual
    "Nextcloud secret file"
    config.sops.templates."nextcloud-secret.json".path
    (if nativeEnabled then config.services.nextcloud.secretFile else null))
  (helpers.assertContains
    "Nextcloud filesystem access group"
    "www-data"
    config.users.users.nextcloud.extraGroups)

  (helpers.assertContains
    "Nextcloud config file tmpfiles rule"
    "f /var/lib/nextcloud/config/config.php 0640 nextcloud nextcloud - -"
    config.systemd.tmpfiles.rules)

  (helpers.assertEqual
    "Nextcloud Calendar version"
    "6.6.1"
    calendarVersion)

  {
    assertion = !(config.systemd.services ? "nextcloud-compose");
    message = "The old nextcloud-compose systemd service must be removed.";
  }
  (helpers.assertEqual
    "Nextcloud data directory ownership service"
    true
    (config.systemd.services ? "nextcloud-data-ownership"))

  (helpers.assertEqual
    "Nextcloud data ownership command"
    "${pkgs.coreutils}/bin/chown -R nextcloud:nextcloud /mnt/myraid/Nextcloud"
    config.systemd.services.nextcloud-data-ownership.serviceConfig.ExecStart)

  (helpers.assertContains
    "Nextcloud data ownership requires RAID mount"
    "mnt-myraid.mount"
    config.systemd.services.nextcloud-data-ownership.requires)
]
