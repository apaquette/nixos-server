{ pkgs, lib, homelab, synthetic }:

let
  production = homelab.config;
  testHost = synthetic.config;

  assertions = [
    {
      assertion =
        builtins.isString production.system.build.toplevel.drvPath
        && builtins.isString testHost.system.build.toplevel.drvPath;
      message = "Both host configurations must evaluate to NixOS system derivations.";
    }

    {
      assertion =
        production.server.network.interfaceName == "lan0"
        && testHost.server.network.interfaceName == "synthetic0"
        && production.server.network.interfaceName != testHost.server.network.interfaceName;
      message = "Each host must retain its own network interface identity.";
    }

    {
      assertion =
        production.server.network.lanAddress == "192.168.2.20"
        && testHost.server.network.lanAddress == "10.42.0.10";
      message = "Each host must retain its own LAN address.";
    }

    {
      assertion =
        production.server.network.gateway == "192.168.2.1"
        && testHost.server.network.gateway == "10.42.0.1"
        && production.server.network.gateway != testHost.server.network.gateway;
      message = "Each host must use its own LAN gateway.";
    }

    {
      assertion =
        production.server.network.dnsServers != testHost.server.network.dnsServers
        && testHost.server.network.dnsServers == [ "9.9.9.9" "149.112.112.112" ]
        && testHost.server.network.publicDomain == "synthetic.test";
      message = "Upstream DNS and public domain configuration must remain host-specific.";
    }

    {
      assertion =
        testHost.systemd.network.links."10-lan".matchConfig.PermanentMACAddress
        == "02:42:ac:11:00:20"
        && testHost.systemd.network.networks."10-lan".address == [ "10.42.0.10/24" ];
      message = "The shared network module must consume the synthetic host interface and address.";
    }

    {
      assertion =
        testHost.services.dnsmasq.settings.interface == [ "synthetic0" ]
        && testHost.services.dnsmasq.settings.listen-address == [ "127.0.0.1" "10.42.0.10" ]
        && testHost.services.dnsmasq.settings.dhcp-range
          == [ "10.42.0.100,10.42.0.149,255.255.255.0,2h" ]
        && testHost.services.dnsmasq.settings.server
          == [ "9.9.9.9" "149.112.112.112" ];
      message = "dnsmasq must derive its interface, LAN address, DHCP range, and upstream DNS from the synthetic host.";
    }

    {
      assertion =
        builtins.elem "/portal.synthetic.test/10.42.0.10" testHost.services.dnsmasq.settings.address
        && builtins.elem "/admin.synthetic.test/10.42.0.10" testHost.services.dnsmasq.settings.address
        && builtins.elem "/game.synthetic.test/10.42.0.10" testHost.services.dnsmasq.settings.address
        && builtins.elem "/agent.synthetic.test/10.42.0.10" testHost.services.dnsmasq.settings.address
        && !(builtins.elem "/database.synthetic.test/10.42.0.10" testHost.services.dnsmasq.settings.address);
      message = "Service-derived DNS must publish active public/LAN services and exclude loopback services.";
    }

    {
      assertion =
        lib.hasInfix "reverse_proxy 127.0.0.1:18080"
          testHost.services.caddy.virtualHosts."portal.synthetic.test".extraConfig
        && lib.hasInfix "reverse_proxy 127.0.0.1:19090"
          testHost.services.caddy.virtualHosts."admin.synthetic.test".extraConfig
        && lib.hasInfix "@denied not remote_ip 10.42.0.0/24"
          testHost.services.caddy.virtualHosts."admin.synthetic.test".extraConfig
        && !(builtins.hasAttr "database.synthetic.test" testHost.services.caddy.virtualHosts);
      message = "Caddy must apply synthetic endpoints, trusted LAN restrictions, and loopback exclusion.";
    }

    {
      assertion =
        builtins.elem 25565 testHost.networking.firewall.interfaces.synthetic0.allowedTCPPorts
        && builtins.elem 19132 testHost.networking.firewall.interfaces.synthetic0.allowedUDPPorts
        && !(builtins.elem 45876 testHost.networking.firewall.interfaces.synthetic0.allowedTCPPorts)
        && !(builtins.elem 45877 testHost.networking.firewall.interfaces.synthetic0.allowedUDPPorts)
        && !(builtins.elem 15432 testHost.networking.firewall.interfaces.synthetic0.allowedTCPPorts)
        && !(builtins.elem 15433 testHost.networking.firewall.interfaces.synthetic0.allowedUDPPorts);
      message = "Only public direct ports should be opened on the synthetic interface; LAN and loopback ports must remain restricted.";
    }

    {
      assertion =
        lib.hasInfix "ip saddr { 10.42.0.0/24 } tcp dport { 45876 } accept"
          testHost.networking.firewall.extraInputRules
        && lib.hasInfix "ip saddr { 10.42.0.0/24 } udp dport { 45877 } accept"
          testHost.networking.firewall.extraInputRules;
      message = "LAN-only direct service ports must be restricted to the synthetic trusted CIDR.";
    }

    {
      assertion =
        testHost.server.storage.roles.applicationData == "fast"
        && testHost.server.storage.roles.localBackup == "archive"
        && testHost.fileSystems."/srv/synthetic-data".device
          == "/dev/disk/by-label/synthetic-data"
        && testHost.fileSystems."/srv/synthetic-data".fsType == "xfs"
        && testHost.fileSystems."/srv/synthetic-archive".device
          == "/dev/disk/by-label/synthetic-archive"
        && testHost.fileSystems."/srv/synthetic-archive".fsType == "ext4";
      message = "The storage module must resolve synthetic logical roles to the synthetic host's distinct volumes.";
    }

    {
      assertion =
        !(builtins.hasAttr "/mnt/myraid" testHost.fileSystems)
        && !(builtins.hasAttr "/mnt/backup" testHost.fileSystems)
        && testHost.server.storage.raidDevice == null;
      message = "Homelab mount points and RAID configuration must not leak into the synthetic host.";
    }

    {
      assertion =
        builtins.hasAttr "/mnt/myraid" production.fileSystems
        && builtins.hasAttr "/mnt/backup" production.fileSystems
        && production.server.storage.raidDevice == "/dev/md0";
      message = "The production homelab storage configuration must remain unchanged.";
    }

    {
      assertion =
        !(lib.any (hostname: lib.hasSuffix ".alexpaquette.dev" hostname)
          (builtins.attrNames testHost.services.caddy.virtualHosts))
        && !(lib.any (entry: lib.hasInfix ".alexpaquette.dev" entry)
          testHost.services.dnsmasq.settings.address)
        && !(lib.any (address: lib.hasInfix "192.168.2." address)
          testHost.services.dnsmasq.settings.address);
      message = "Production domain names and LAN addresses must not leak into the synthetic host.";
    }
  ];

  failures = lib.filter (test: !test.assertion) assertions;

  assertionResult =
    if failures == [ ] then
      true
    else
      throw (lib.concatMapStringsSep "\n" (test: test.message) failures);
in
assert assertionResult;
pkgs.runCommand "multi-host-configuration-tests" { } ''
  echo "All ${toString (builtins.length assertions)} multi-host assertions passed."
  touch $out
''
