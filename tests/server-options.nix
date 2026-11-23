{ config, helpers, ... }:

with helpers;

[
  (assertEqual "host LAN interface name" "lan0" config.server.network.interfaceName)
  (assertEqual "host LAN interface MAC" "2c:f0:5d:6e:6c:2d" config.server.network.interfaceMacAddress)
  (assertEqual "host LAN address" "192.168.2.20" config.server.network.lanAddress)
  (assertEqual "host static IPv4 address" "192.168.2.20/24" config.server.network.ipv4Address)
  (assertEqual "host LAN gateway" "192.168.2.1" config.server.network.gateway)
  (assertEqual "host upstream DNS servers" [ "1.1.1.1" "8.8.8.8" ] config.server.network.dnsServers)
  (assertEqual "host DHCP range" "192.168.2.50,192.168.2.199,255.255.255.0,12h" config.server.network.dhcpRange)
  (assertEqual "host DHCP reservations" [ "b4:2e:99:fb:61:ae,192.168.2.100,nixos-desktop" ] config.server.network.dhcpHosts)
  (assertEqual "host data root" "/mnt/myraid" config.server.storage.dataRoot)
  (assertEqual "host backup root" "/mnt/backup" config.server.storage.backupRoot)
  (assertEqual "host data device" "/dev/disk/by-uuid/f316b340-b988-4306-8164-9f7d11250a55" config.server.storage.dataDevice)
  (assertEqual "host backup device" "/dev/disk/by-uuid/2f26abd3-1603-4c8d-890c-a8a8aea9c5f1" config.server.storage.backupDevice)
]
