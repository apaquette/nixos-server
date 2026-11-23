{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.server.network = {
    interfaceName = mkOption {
      type = types.str;
      description = "Name assigned to the host's LAN interface.";
    };
    interfaceMacAddress = mkOption {
      type = types.str;
      description = "Permanent MAC address used to identify the host's LAN interface.";
    };
    lanAddress = mkOption {
      type = types.str;
      description = "Host LAN IPv4 address without a prefix length.";
    };
    ipv4Address = mkOption {
      type = types.str;
      description = "Static host IPv4 address in CIDR notation.";
    };
    gateway = mkOption {
      type = types.str;
      description = "Default IPv4 gateway for the host's LAN.";
    };
    dnsServers = mkOption {
      type = types.listOf types.str;
      description = "Upstream DNS servers used by the host and its local DNS resolver.";
    };
    dhcpRange = mkOption {
      type = types.str;
      description = "dnsmasq DHCP range declaration.";
    };
    dhcpHosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Static DHCP host reservations for the LAN.";
    };
    localDnsNames = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Hostnames that the local DNS resolver should map to the host's LAN address.";
    };
  };

  options.server.storage = {
    dataRoot = mkOption {
      type = types.str;
      description = "Filesystem mount point for application and media data.";
    };
    backupRoot = mkOption {
      type = types.str;
      description = "Filesystem mount point for local backups.";
    };
    dataDevice = mkOption {
      type = types.str;
      description = "Device identifier mounted at server.storage.dataRoot.";
    };
    backupDevice = mkOption {
      type = types.str;
      description = "Device identifier mounted at server.storage.backupRoot.";
    };
    raidDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional RAID device monitored by the storage health check.";
    };
  };
}
