{ config, helpers, ... }:

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
    "192.168.2.20:8096"
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
    "reverse_proxy 192.168.2.20:8096"
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

  (assertContains
    "LAN-only Beszel agent port is restricted to trusted source networks"
    "ip saddr { 192.168.2.0/24 } tcp dport { 45876 } accept"
    config.networking.firewall.extraInputRules)

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
    "local DNS records derive from enabled HTTP services"
    14
    (builtins.length config.services.dnsmasq.settings.address))
]
