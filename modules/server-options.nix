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
    volumes = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          device = mkOption {
            type = types.str;
            description = "Device identifier for this storage volume.";
          };
          mountPoint = mkOption {
            type = types.str;
            description = "Filesystem mount point for this storage volume.";
          };
          fsType = mkOption {
            type = types.str;
            description = "Filesystem type for this storage volume.";
          };
          options = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Mount options for this storage volume.";
          };
        };
      });
      default = { };
      description = "Host-defined local filesystem volumes, keyed by resource name.";
    };

    roles = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Optional logical storage roles mapped to names in server.storage.volumes.";
    };

    raidDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional RAID device monitored by the storage health check.";
    };
  };
}
