{ config, helpers, ... }:

with helpers;

[
  (assertEqual
    "Namecheap DDNS enabled"
    true
    config.services.ddclient.enable)

  (assertEqual
    "Namecheap DDNS protocol"
    "namecheap"
    config.services.ddclient.protocol)

  (assertEqual
    "Namecheap DDNS server"
    "dynamicdns.park-your-domain.com"
    config.services.ddclient.server)

  (assertEqual
    "Namecheap DDNS account"
    "alexpaquette.dev"
    config.services.ddclient.username)

  (assertEqual
    "Namecheap DDNS host labels"
    [
      "cloud"
      "jellyfin"
      "seerr"
      "immich"
      "ntfy"
    ]
    config.services.ddclient.domains)

  (assertEqual
    "Namecheap DDNS interval"
    "5min"
    config.services.ddclient.interval)

  (assertEqual
    "Namecheap DDNS TLS"
    true
    config.services.ddclient.ssl)

  (assertEqual
    "Namecheap DDNS IPv4 discovery"
    "webv4, webv4=ipify-ipv4"
    config.services.ddclient.usev4)

  (assertEqual
    "Namecheap DDNS password file"
    config.sops.secrets."namecheap-ddns-password".path
    config.services.ddclient.passwordFile)

  (assertEqual
    "Namecheap DDNS SOPS key"
    "namecheap/ddns_password"
    config.sops.secrets."namecheap-ddns-password".key)

  (assertEqual
    "Namecheap DDNS secret owner"
    "root"
    config.sops.secrets."namecheap-ddns-password".owner)

  (assertEqual
    "Namecheap DDNS secret group"
    "ddclient-secrets"
    config.sops.secrets."namecheap-ddns-password".group)

  (assertEqual
    "Namecheap DDNS secret permissions"
    "0440"
    config.sops.secrets."namecheap-ddns-password".mode)

  (assertEqual
    "Namecheap DDNS secret group exists"
    true
    (builtins.hasAttr "ddclient-secrets" config.users.groups))

  (assertEqual
    "Namecheap DDNS IPv6 discovery disabled"
    ""
    config.services.ddclient.usev6)

  (assertEqual
    "Namecheap DDNS DynamicUser"
    true
    config.systemd.services.ddclient.serviceConfig.DynamicUser)

  (assertContains
    "Namecheap DDNS supplementary secret group"
    "ddclient-secrets"
    config.systemd.services.ddclient.serviceConfig.SupplementaryGroups)

  (assertEqual
    "Namecheap DDNS timer interval"
    "5min"
    config.systemd.timers.ddclient.timerConfig.OnBootSec)

  (assertEqual
    "Namecheap DDNS timer repeat interval"
    "5min"
    config.systemd.timers.ddclient.timerConfig.OnUnitInactiveSec)
]
