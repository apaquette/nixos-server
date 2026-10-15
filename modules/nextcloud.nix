{ config, pkgs, lib, unstable, ... }:
let
  calendar661 =
    unstable.nextcloud35Packages.apps.calendar.overrideAttrs (_: {
      name = "nextcloud-app-calendar-6.6.1";
      version = "6.6.1";

      src = pkgs.fetchurl {
        url =
          "https://github.com/nextcloud-releases/calendar/releases/download/v6.6.1/calendar-v6.6.1.tar.gz";
        hash = "sha256-/WYw3uxWg2h4TFae8Bx9ntisyhq2gzzxKiv/WYSj+ns=";
      };
    });
  nextcloud35 = unstable.nextcloud35.overrideAttrs (old: {
    version = "35.0.1";

    src = pkgs.fetchurl {
      url =
        "https://github.com/nextcloud-releases/server/releases/download/v35.0.1/nextcloud-35.0.1.tar.bz2";
      hash = "sha256-ftMF6IAZLYBLqDF5oZ3SIldnlgjWMWGmEc4/ipGNKqY=";
    };
  });
  pantry0370 = pkgs.fetchNextcloudApp {
    appName = "pantry";
    appVersion = "0.37.0";

    url = "https://github.com/chenasraf/nextcloud-pantry/releases/download/v0.37.0/pantry-v0.37.0.tar.gz";
    hash = "sha256-PboKBw8IrEDKAiBwqQLE4IvD974d73nnZpZDt5s/b5Y=";

    license = "agpl3Plus";
  };
  tickbuddy210 = pkgs.fetchNextcloudApp {
    appName = "tickbuddy";
    appVersion = "2.1.0";
    url = "https://github.com/martinhammer/tickbuddy/releases/download/v2.1.0/tickbuddy-v2.1.0.tar.gz";
    hash = "sha256-ZltacT+eJS36kTdvAlDU1yC2Gh9OieOjTqoG2DGMzcg=";
    license = "agpl3Plus";
  };
in
{
  services.nextcloud = {
    enable = true;

    package = nextcloud35;

    hostName = "cloud.alexpaquette.dev";

    home = "/var/lib/nextcloud";
    datadir = "/var/lib/nextcloud";
    secretFile = config.sops.templates."nextcloud-secret.json".path;

    database.createLocally = false;

    config = {
      dbtype = "pgsql";
      dbname = "nextcloud";
      dbuser = "oc_admin";
      dbhost = "127.0.0.1:5432";
      dbpassFile = config.sops.secrets."nextcloud-postgres-password".path;

      adminuser = null;
      adminpassFile = null;
    };

    https = true;

    settings = {
      datadirectory = "/mnt/myraid/Nextcloud";

      trusted_domains = [
        "cloud.alexpaquette.dev"
      ];

      trusted_proxies = [
        "192.168.2.20"
      ];

      overwriteprotocol = "https";
      "overwrite.cli.url" = "https://cloud.alexpaquette.dev";
    };

    configureRedis = true;

    extraApps = with unstable.nextcloud35Packages.apps; {
      calendar = calendar661;
      inherit contacts notes tasks;
      pantry = pantry0370;
      tickbuddy = tickbuddy210;
    };

    extraAppsEnable = true;

    appstoreEnable = true;
  };

  users.users.nextcloud.extraGroups = [
    "www-data"
  ];

  systemd.tmpfiles.rules = [
    "f /var/lib/nextcloud/config/config.php 0640 nextcloud nextcloud - -"
  ];

  services.nginx.virtualHosts."cloud.alexpaquette.dev" = {
    listen = lib.mkForce [
      {
        addr = "127.0.0.1";
        port = 8081;
      }
    ];
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    ensureDatabases = [
      "nextcloud"
    ];

    ensureUsers = [
      {
        name = "oc_admin";
      }
    ];
  };

  systemd.services.nextcloud-data-ownership = {
    description = "Normalize Nextcloud data directory ownership";

    after = [ "mnt-myraid.mount" ];
    requires = [ "mnt-myraid.mount" ];

    before = [
      "nextcloud-setup.service"
      "phpfpm-nextcloud.service"
    ];

    requiredBy = [
      "nextcloud-setup.service"
      "phpfpm-nextcloud.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart =
        "${pkgs.coreutils}/bin/chown -R nextcloud:nextcloud /mnt/myraid/Nextcloud";
      RemainAfterExit = true;
    };
  };
}
