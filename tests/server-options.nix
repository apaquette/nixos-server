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
  (assertEqual "host RAID device" "/dev/md0" config.server.storage.raidDevice)
]
