{ config, lib, helpers, ... }:

let
  serviceExposure = import ../modules/lib/service-exposure.nix { inherit lib; };

  loopbackFixture = {
    internalDatabase = {
      exposure = "loopback";
      hostname = "database.example.test";
      httpUpstream = "127.0.0.1:5432";
      tcpPorts = [ 5432 ];
      udpPorts = [ 5433 ];
    };
  };
in
with helpers;

[
  (assertEqual
    "host trusted network ranges"
    [ "192.168.2.0/24" ]
    config.server.network.trustedNetworks)

  (assertEqual
    "host public DNS domain"
    "alexpaquette.dev"
    config.server.network.publicDomain)

  (assertEqual
    "Jellyfin exposure policy"
    "public"
    config.server.services.jellyfin.exposure)

  (assertEqual
    "Jellyfin public hostname"
    "jellyfin.alexpaquette.dev"
    config.server.services.jellyfin.hostname)

  (assertEqual
    "Jellyfin HTTP upstream"
    "127.0.0.1:8096"
    config.server.services.jellyfin.httpUpstream)

  (assertEqual
    "Minecraft exposure policy"
    "public"
    config.server.services.minecraft.exposure)

  (assertEqual
    "Minecraft direct TCP ingress"
    [ 4300 ]
    config.server.services.minecraft.tcpPorts)

  (assertEqual
    "Minecraft query UDP ingress"
    [ 25565 ]
    config.server.services.minecraft.udpPorts)

  (assertEqual
    "Beszel dashboard exposure policy"
    "lan"
    config.server.services.beszel.exposure)

  (assertEqual
    "Homepage exposure policy"
    "lan"
    config.server.services.homepage.exposure)

  (assertEqual
    "Beszel agent exposure policy"
    "lan"
    config.server.services.beszelAgent.exposure)

  (assertEqual
    "PostgreSQL host-local exposure policy"
    "loopback"
    config.server.services.postgresql.exposure)

  (assertEqual "Nextcloud HTTP endpoint is provided by its service module" "127.0.0.1:8081" config.server.services.cloud.httpUpstream)
  (assertEqual "Seerr HTTP endpoint is provided by its service module" "127.0.0.1:5055" config.server.services.seerr.httpUpstream)
  (assertEqual "Immich HTTP endpoint is provided by its service module" "127.0.0.1:2283" config.server.services.immich.httpUpstream)
  (assertEqual "ntfy HTTP endpoint is provided by its service module" "127.0.0.1:8093" config.server.services.ntfy.httpUpstream)
  (assertEqual "Radarr HTTP endpoint is provided by its service module" "127.0.0.1:7878" config.server.services.radarr.httpUpstream)
  (assertEqual "Sonarr HTTP endpoint is provided by its service module" "127.0.0.1:8989" config.server.services.sonarr.httpUpstream)
  (assertEqual "Prowlarr HTTP endpoint is provided by its service module" "127.0.0.1:9696" config.server.services.prowlarr.httpUpstream)
  (assertEqual "qBittorrent HTTP endpoint is provided by its service module" "127.0.0.1:8080" config.server.services.qbittorrent.httpUpstream)
  (assertEqual "Cockpit HTTP endpoint is provided by its service module" "127.0.0.1:9090" config.server.services.cockpit.httpUpstream)
  (assertEqual "Uptime Kuma HTTP endpoint is provided by its service module" "127.0.0.1:3001" config.server.services.status.httpUpstream)
  (assertEqual "Beszel Hub HTTP endpoint is provided by its service module" "127.0.0.1:8090" config.server.services.beszel.httpUpstream)
  (assertEqual "Jenkins HTTP endpoint is provided by its service module" "127.0.0.1:8082" config.server.services.jenkins.httpUpstream)
  (assertEqual "Homepage HTTP endpoint is provided by its service module" "127.0.0.1:3000" config.server.services.homepage.httpUpstream)

  (assertEqual
    "Beszel agent firewall is managed by the exposure module"
    false
    config.services.beszel.agent.openFirewall)

  (assertEqual
    "Beszel agent port is not globally opened"
    false
    (builtins.elem 45876 config.networking.firewall.allowedTCPPorts))

  (assertContains
    "LAN-only Homepage route requires internal TLS"
    "tls internal"
    config.services.caddy.virtualHosts."homepage.alexpaquette.dev".extraConfig)

  (assertContains
    "LAN-only Homepage route denies non-trusted clients"
    "@denied not remote_ip 192.168.2.0/24"
    config.services.caddy.virtualHosts."homepage.alexpaquette.dev".extraConfig)

  (assertContains
    "LAN-only Beszel route denies non-trusted clients"
    "@denied not remote_ip 192.168.2.0/24"
    config.services.caddy.virtualHosts."beszel.alexpaquette.dev".extraConfig)

  (assertContains
    "public Jellyfin route has no LAN-only matcher"
    "reverse_proxy 127.0.0.1:8096"
    config.services.caddy.virtualHosts."jellyfin.alexpaquette.dev".extraConfig)

  (assertEqual
    "public Minecraft TCP port is allowed"
    true
    (builtins.elem
      4300
      config.networking.firewall.interfaces.lan0.allowedTCPPorts))

  (assertEqual
    "public Minecraft query UDP port is allowed"
    true
    (builtins.elem
      25565
      config.networking.firewall.interfaces.lan0.allowedUDPPorts))

  (assertEqual
    "LAN-only Beszel agent port is restricted to trusted source networks"
    true
    (lib.hasInfix
      "ip saddr { 192.168.2.0/24 } tcp dport { 45876 } accept"
      config.networking.firewall.extraInputRules))

  (assertEqual
    "loopback PostgreSQL port is not publicly opened"
    false
    (builtins.elem
      5432
      config.networking.firewall.interfaces.lan0.allowedTCPPorts))

  (assertEqual
    "Namecheap records derive from public service hostnames"
    [ "cloud" "immich" "jellyfin" "mc" "ntfy" "seerr" ]
    config.services.ddclient.domains)

  (assertEqual
    "local DNS records derive from enabled HTTP and direct services"
    15
    (builtins.length config.services.dnsmasq.settings.address))

  (assertContains
    "public Minecraft has a local DNS override"
    "/mc.alexpaquette.dev/192.168.2.20"
    config.services.dnsmasq.settings.address)
  (assertEqual
    "loopback HTTP endpoint is excluded from Caddy routes"
    { }
    (serviceExposure.httpServices loopbackFixture))

  (assertEqual
    "loopback endpoint is excluded from local DNS publication"
    { }
    (serviceExposure.publishedServices true loopbackFixture))

  (assertEqual
    "loopback endpoint is excluded from public DDNS publication"
    { }
    (serviceExposure.publicServices true loopbackFixture))

  (assertEqual
    "loopback TCP ports are excluded from public firewall openings"
    [ ]
    (serviceExposure.portsForExposure "public" "tcp" loopbackFixture))

  (assertEqual
    "loopback UDP ports are excluded from public firewall openings"
    [ ]
    (serviceExposure.portsForExposure "public" "udp" loopbackFixture))

  (assertEqual
    "loopback TCP ports are excluded from LAN firewall openings"
    [ ]
    (serviceExposure.portsForExposure "lan" "tcp" loopbackFixture))

  (assertEqual
    "loopback UDP ports are excluded from LAN firewall openings"
    [ ]
    (serviceExposure.portsForExposure "lan" "udp" loopbackFixture))
]
