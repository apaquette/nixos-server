{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.server.secrets = {
    sopsFile = mkOption {
      type = types.path;
      description = "Host-specific encrypted SOPS file.";
    };
    ageKeyFile = mkOption {
      type = types.str;
      description = "Host-specific path to the SOPS age identity.";
    };
  };

  options.server.notifications.ntfy = {
    baseUrl = mkOption {
      type = types.str;
      description = "Base URL used by host notification scripts to reach ntfy.";
    };
    systemTopic = mkOption {
      type = types.str;
      description = "ntfy topic for system and storage notifications.";
    };
    backupTopic = mkOption {
      type = types.str;
      description = "ntfy topic for backup notifications.";
    };
  };

  options.server.backups.remoteRepository = mkOption {
    type = types.str;
    description = "Host-specific remote Restic repository URI.";
  };

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
    trustedNetworks = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Trusted source CIDRs permitted to reach LAN-only service ingress.";
    };
    publicDomain = mkOption {
      type = types.str;
      description = "Public DNS zone used by host-declared public service names.";
    };
  };

  options.server.services = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        exposure = mkOption {
          type = types.enum [ "public" "lan" "loopback" ];
          default = "loopback";
          description = "Client access policy for this imported service.";
        };
        hostname = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional fully qualified hostname for HTTP or direct public ingress.";
        };
        httpUpstream = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional HTTP reverse-proxy backend in host:port form.";
        };
        tcpPorts = mkOption {
          type = types.listOf (types.ints.between 1 65535);
          default = [ ];
          description = "Direct TCP ingress ports required by this service.";
        };
        udpPorts = mkOption {
          type = types.listOf (types.ints.between 1 65535);
          default = [ ];
          description = "Direct UDP ingress ports required by this service.";
        };
      };
    });
    default = { };
    description = "Contracts for services imported by this host; the host supplies exposure and hostname policy.";
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
