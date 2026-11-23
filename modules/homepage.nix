{ config, lib, unstable, ... }:

let
  serviceUrl = name: "https://${config.server.services.${name}.hostname}";

  mediaServices = lib.concatLists [
    (lib.optional config.services.jellyfin.enable {
      Jellyfin = {
        icon = "jellyfin.png";
        href = serviceUrl "jellyfin";
        description = "Media server";
        widget = {
          type = "jellyfin";
          url = "http://127.0.0.1:8096";
          key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
          enableNowPlaying = true;
        };
      };
    })
    (lib.optional config.services.seerr.enable {
      Seerr = {
        icon = "seerr.png";
        href = serviceUrl "seerr";
        description = "Media requests";
      };
    })
    (lib.optional config.services.sonarr.enable {
      Sonarr = {
        icon = "sonarr.png";
        href = serviceUrl "sonarr";
        description = "TV management";
        widget = {
          type = "sonarr";
          url = "http://127.0.0.1:8989";
          key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
        };
      };
    })
    (lib.optional config.services.radarr.enable {
      Radarr = {
        icon = "radarr.png";
        href = serviceUrl "radarr";
        description = "Movie management";
        widget = {
          type = "radarr";
          url = "http://127.0.0.1:7878";
          key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
        };
      };
    })
    (lib.optional config.services.prowlarr.enable {
      Prowlarr = {
        icon = "prowlarr.png";
        href = serviceUrl "prowlarr";
        description = "Indexer management";
      };
    })
    (lib.optional config.services.qbittorrent.enable {
      qBittorrent = {
        icon = "qbittorrent.png";
        href = serviceUrl "qbittorrent";
        description = "Download client";
        widget = {
          type = "qbittorrent";
          url = "http://127.0.0.1:8080";
          key = "{{HOMEPAGE_VAR_QBITTORRENT_API_KEY}}";
          enableLeechProgress = true;
          enableLeechSize = true;
        };
      };
    })
  ];

  cloudServices = lib.concatLists [
    (lib.optional config.services.nextcloud.enable {
      Nextcloud = {
        icon = "nextcloud.png";
        href = serviceUrl "cloud";
        description = "Personal cloud";
        widget = {
          type = "nextcloud";
          url = "http://127.0.0.1:8081";
          key = "{{HOMEPAGE_VAR_NEXTCLOUD_TOKEN}}";
          fields = [
            "freespace"
            "activeusers"
            "numfiles"
            "numshares"
          ];
        };
      };
    })
    (lib.optional config.services.immich.enable {
      Immich = {
        icon = "immich.png";
        href = serviceUrl "immich";
        description = "Photo and video library";
        widget = {
          type = "immich";
          url = "http://127.0.0.1:2283";
          key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
          version = 2;
        };
      };
    })
    (lib.optional config.services."ntfy-sh".enable {
      ntfy = {
        icon = "ntfy.png";
        href = serviceUrl "ntfy";
        description = "Notifications";
      };
    })
  ];

  infrastructureServices = lib.concatLists [
    (lib.optional config.services.uptime-kuma.enable {
      "Uptime Kuma" = {
        icon = "uptime-kuma.png";
        href = serviceUrl "status";
        description = "Service monitoring";
        widget = {
          type = "uptimekuma";
          url = "http://127.0.0.1:3001";
          slug = "homelab";
        };
      };
    })
    (lib.optional config.services.beszel.hub.enable {
      Beszel = {
        icon = "beszel.png";
        href = serviceUrl "beszel";
        description = "System monitoring";
      };
    })
    (lib.optional config.services.cockpit.enable {
      Cockpit = {
        icon = "cockpit.png";
        href = serviceUrl "cockpit";
        description = "Server administration";
      };
    })
  ];

  developmentServices = lib.concatLists [
    (lib.optional config.services.jenkins.enable {
      Jenkins = {
        icon = "jenkins.png";
        href = serviceUrl "jenkins";
        description = "CI/CD";
      };
    })
  ];

  dashboardGroups = lib.concatLists [
    (lib.optional (mediaServices != [ ]) { Media = mediaServices; })
    (lib.optional (cloudServices != [ ]) { Cloud = cloudServices; })
    (lib.optional (infrastructureServices != [ ]) { Infrastructure = infrastructureServices; })
    (lib.optional (developmentServices != [ ]) { Development = developmentServices; })
  ];
in
{
  sops.templates."homepage.env" = { };

  services.homepage-dashboard = {
    enable = true;
    package = unstable.homepage-dashboard;

    listenPort = 3000;
    allowedHosts = config.server.services.homepage.hostname;
    openFirewall = false;

    environmentFiles = [
      config.sops.templates."homepage.env".path
    ];

    settings = {
      title = "Homelab";
      description = "Alex's Homelab";
      theme = "dark";
      color = "slate";

      layout = [
        {
          Media = {
            style = "row";
            columns = 4;
          };
        }
        {
          Cloud = {
            style = "row";
            columns = 3;
          };
        }
        {
          Infrastructure = {
            style = "row";
            columns = 3;
          };
        }
        {
          Development = {
            style = "row";
            columns = 1;
          };
        }
      ];

      providers = {
        openweathermap = "openweathermapapikey";
        weatherapi = "weatherapiapikey";
      };
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];

    services = dashboardGroups;
  };

  server.services.homepage.httpUpstream = lib.mkDefault
    "127.0.0.1:${toString config.services.homepage-dashboard.listenPort}";
}
