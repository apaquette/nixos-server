{ config, pkgs, lib, helpers, unstable,  ... }:

with helpers;

[
  (assertEqual
    "Homepage service enabled"
    true
    config.services.homepage-dashboard.enable)

  (assertEqual
    "Homepage package"
    unstable.homepage-dashboard
    config.services.homepage-dashboard.package)

(assertEqual
  "Homepage package version"
  "2.3.0"
  config.services.homepage-dashboard.package.version)

  (assertEqual
    "Homepage port"
    3000
    config.services.homepage-dashboard.listenPort)

  (assertEqual
    "Homepage allowed host"
    config.server.services.homepage.hostname
    config.services.homepage-dashboard.allowedHosts)

  (assertEqual
    "Homepage firewall disabled"
    false
    config.services.homepage-dashboard.openFirewall)

  (assertEqual
    "Homepage environment file"
    [ config.sops.templates."homepage.env".path ]
    config.services.homepage-dashboard.environmentFiles)

  (assertEqual
    "Homepage DynamicUser"
    true
    config.systemd.services.homepage-dashboard.serviceConfig.DynamicUser)

  (assertEqual
    "Homepage state directory"
    "homepage-dashboard"
    config.systemd.services.homepage-dashboard.serviceConfig.StateDirectory)

  (assertEqual
    "Homepage cache directory"
    "homepage-dashboard"
    config.systemd.services.homepage-dashboard.serviceConfig.CacheDirectory)

  (assertEqual
    "Homepage config directory"
    "/etc/homepage-dashboard"
    config.systemd.services.homepage-dashboard.environment.HOMEPAGE_CONFIG_DIR)

  (assertEqual
    "Homepage PORT"
    "3000"
    config.systemd.services.homepage-dashboard.environment.PORT)

  (assertEqual
    "Homepage HOMEPAGE_ALLOWED_HOSTS"
    config.server.services.homepage.hostname
    config.systemd.services.homepage-dashboard.environment.HOMEPAGE_ALLOWED_HOSTS)

  (assertEqual
    "Homepage settings title"
    "Homelab"
    config.services.homepage-dashboard.settings.title)

  (assertEqual
    "Homepage settings theme"
    "dark"
    config.services.homepage-dashboard.settings.theme)

  (assertEqual
    "Homepage service groups"
    4
    (builtins.length config.services.homepage-dashboard.services))

  (assertEqual
    "Homepage info widgets"
    2
    (builtins.length config.services.homepage-dashboard.widgets))

  (assertEqual
    "Homepage service secret placeholders"
    true
    (lib.hasInfix
      "HOMEPAGE_VAR_"
      (builtins.toJSON config.services.homepage-dashboard.services)))
(assertEqual
  "Homepage qBittorrent API key secret"
  true
  (builtins.hasAttr "homepage-qbittorrent-api-key" config.sops.secrets))
]
