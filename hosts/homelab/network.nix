{
  server.network = {
    interfaceName = "lan0";
    interfaceMacAddress = "2c:f0:5d:6e:6c:2d";
    lanAddress = "192.168.2.20";
    ipv4Address = "192.168.2.20/24";
    gateway = "192.168.2.1";
    dnsServers = [ "1.1.1.1" "8.8.8.8" ];
    dhcpRange = "192.168.2.50,192.168.2.199,255.255.255.0,12h";
    dhcpHosts = [
      "b4:2e:99:fb:61:ae,192.168.2.100,nixos-desktop"
    ];
    trustedNetworks = [ "192.168.2.0/24" ];
    publicDomain = "alexpaquette.dev";
  };
}
