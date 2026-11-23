{ ... }:

{
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network.enable = true;

  systemd.network.links."10-lan" = {
    matchConfig.PermanentMACAddress = "2c:f0:5d:6e:6c:2d";
    linkConfig.Name = "lan0";
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "lan0";

    address = [
      "192.168.2.20/24"
    ];

    routes = [
      {
        Gateway = "192.168.2.1";
      }
    ];

    dns = [
      "192.168.2.20"
      "1.1.1.1"
      "8.8.8.8"
    ];

    linkConfig.RequiredForOnline = "routable";
  };

  networking.firewall = {
    interfaces.lan0 = {
      allowedTCPPorts = [
        53
        80
        443
        4300
      ];

      allowedUDPPorts = [
        53
        67
      ];
    };
  };
}

