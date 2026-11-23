{ config, helpers, ... }:

with helpers;

[
  (assertEqual
    "network manager enabled"
    false
    config.networking.networkmanager.enable)

  (assertEqual
    "networkd enabled"
    true
    config.networking.useNetworkd)

  (assertEqual
    "systemd network enabled"
    true
    config.systemd.network.enable)

  (assertEqual
    "LAN interface MAC"
    config.server.network.interfaceMacAddress
    config.systemd.network.links."10-lan".matchConfig.PermanentMACAddress)

  (assertEqual
    "LAN interface name"
    config.server.network.interfaceName
    config.systemd.network.links."10-lan".linkConfig.Name)

  (assertContains
    "LAN static address"
    config.server.network.ipv4Address
    config.systemd.network.networks."10-lan".address)

  (assertEqual
    "LAN gateway"
    config.server.network.gateway
    (builtins.head config.systemd.network.networks."10-lan".routes).Gateway)

  (assertContains
    "LAN DNS servers"
    config.server.network.lanAddress
    config.systemd.network.networks."10-lan".dns)

  (assertContains
    "LAN DNS servers"
    "1.1.1.1"
    config.systemd.network.networks."10-lan".dns)

  (assertContains
    "LAN DNS servers"
    "8.8.8.8"
    config.systemd.network.networks."10-lan".dns)
]
