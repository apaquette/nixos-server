{
  server.network = {
    interfaceName = "synthetic0";
    interfaceMacAddress = "02:42:ac:11:00:20";
    lanAddress = "10.42.0.10";
    ipv4Address = "10.42.0.10/24";
    gateway = "10.42.0.1";
    dnsServers = [ "9.9.9.9" "149.112.112.112" ];
    dhcpRange = "10.42.0.100,10.42.0.149,255.255.255.0,2h";
    dhcpHosts = [
      "02:42:ac:11:00:21,10.42.0.21,synthetic-client"
    ];
    trustedNetworks = [ "10.42.0.0/24" ];
    publicDomain = "synthetic.test";
  };
}
