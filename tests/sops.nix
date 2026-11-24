{ config, helpers, ... }:

with helpers;

[
  (assertEqual
    "SOPS default file"
    config.server.secrets.sopsFile
    config.sops.defaultSopsFile)

  (assertEqual
    "SOPS age key file"
    config.server.secrets.ageKeyFile
    config.sops.age.keyFile)

  (assertEqual
    "Nextcloud SOPS key"
    "nextcloud/postgres_password"
    config.sops.secrets."nextcloud-postgres-password".key)

  (assertEqual
    "Immich SOPS key"
    "immich/db_password"
    config.sops.secrets."immich-db-password".key)

  (assertEqual
    "SMART notification SOPS key"
    "smartd/ntfy_token"
    config.sops.secrets."smartd-ntfy-token".key)
(helpers.assertEqual
  "Restic repository password SOPS key"
  "restic/repository_password"
  config.sops.secrets."restic-repository-password".key)
]
