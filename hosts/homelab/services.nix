{
  server.services = {
    cloud = {
      hostname = "cloud.alexpaquette.dev";
      exposure = "public";
    };
    jellyfin = {
      hostname = "jellyfin.alexpaquette.dev";
      exposure = "public";
    };
    seerr = {
      hostname = "seerr.alexpaquette.dev";
      exposure = "public";
    };
    immich = {
      hostname = "immich.alexpaquette.dev";
      exposure = "public";
    };
    ntfy = {
      hostname = "ntfy.alexpaquette.dev";
      exposure = "public";
    };

    radarr = {
      hostname = "radarr.alexpaquette.dev";
      exposure = "lan";
    };
    sonarr = {
      hostname = "sonarr.alexpaquette.dev";
      exposure = "lan";
    };
    prowlarr = {
      hostname = "prowlarr.alexpaquette.dev";
      exposure = "lan";
    };
    qbittorrent = {
      hostname = "qbittorrent.alexpaquette.dev";
      exposure = "lan";
    };
    cockpit = {
      hostname = "cockpit.alexpaquette.dev";
      exposure = "lan";
    };
    status = {
      hostname = "status.alexpaquette.dev";
      exposure = "lan";
    };
    beszel = {
      hostname = "beszel.alexpaquette.dev";
      exposure = "lan";
    };
    jenkins = {
      hostname = "jenkins.alexpaquette.dev";
      exposure = "lan";
    };
    homepage = {
      hostname = "homepage.alexpaquette.dev";
      exposure = "lan";
    };

    minecraft = {
      hostname = "mc.alexpaquette.dev";
      exposure = "public";
    };
    beszelAgent.exposure = "lan";
    postgresql.exposure = "loopback";
  };
}
