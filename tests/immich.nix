{ config,lib, unstable, helpers, ... }:

let
  cfg = config.services.immich;
  server = config.systemd.services.immich-server;
  machineLearning = config.systemd.services.immich-machine-learning;
  postgres = config.services.postgresql;
  redis = config.services.redis.servers.immich;
in

[
  (helpers.assertEqual
    "immich enabled"
    true
    cfg.enable)

  (helpers.assertEqual
    "immich package"
    unstable.immich
    cfg.package)

(helpers.assertEqual
  "immich package is unstable package"
  true
  (cfg.package == unstable.immich))

  (helpers.assertEqual
    "immich host"
    "127.0.0.1"
    cfg.host)

  (helpers.assertEqual
    "immich port"
    2283
    cfg.port)

  (helpers.assertEqual
    "immich machine learning enabled"
    true
    cfg.machine-learning.enable)

  (helpers.assertEqual
    "immich acceleration devices"
    [ ]
    cfg.accelerationDevices)

  (helpers.assertEqual
    "immich database enabled"
    true
    cfg.database.enable)

  (helpers.assertEqual
    "immich database createDB"
    true
    cfg.database.createDB)

  (helpers.assertEqual
    "immich database name"
    "immich"
    cfg.database.name)

  (helpers.assertEqual
    "immich database user"
    "immich"
    cfg.database.user)

  (helpers.assertEqual
    "immich database host"
    "/run/postgresql"
    cfg.database.host)

  (helpers.assertEqual
    "immich redis enabled"
    true
    cfg.redis.enable)

  (helpers.assertEqual
    "immich redis TCP port disabled"
    0
    cfg.redis.port)

  (helpers.assertEqual
    "immich application settings remain database-managed"
    null
    cfg.settings)

  (helpers.assertEqual
    "immich server user"
    "immich"
    server.serviceConfig.User)

  (helpers.assertEqual
    "immich server group"
    "immich"
    server.serviceConfig.Group)

  (helpers.assertEqual
    "immich server ExecStart"
    (lib.getExe cfg.package)
    server.serviceConfig.ExecStart)

  (helpers.assertContains
    "immich server requires PostgreSQL"
    "postgresql.target"
    server.requires)

  (helpers.assertContains
    "immich server starts after PostgreSQL"
    "postgresql.target"
    server.after)

  (helpers.assertContains
    "immich server requires its host data filesystem"
    cfg.mediaLocation
    server.unitConfig.RequiresMountsFor)

  (helpers.assertEqual
    "immich PostgreSQL enabled"
    true
    postgres.enable)

  (helpers.assertContains
    "immich PostgreSQL database"
    "immich"
    postgres.ensureDatabases)

  (helpers.assertEqual
    "immich Redis enabled"
    true
    redis.enable)

  (helpers.assertEqual
    "immich Redis TCP port"
    0
    redis.port)

  (helpers.assertEqual
    "immich-compose removed"
    null
    (config.systemd.services.immich-compose or null))
]
