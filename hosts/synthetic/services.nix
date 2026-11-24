{
  server.services = {
    portal = {
      hostname = "portal.synthetic.test";
      exposure = "public";
      httpUpstream = "127.0.0.1:18080";
    };

    admin = {
      hostname = "admin.synthetic.test";
      exposure = "lan";
      httpUpstream = "127.0.0.1:19090";
    };

    game = {
      hostname = "game.synthetic.test";
      exposure = "public";
      tcpPorts = [ 25565 ];
      udpPorts = [ 19132 ];
    };

    agent = {
      hostname = "agent.synthetic.test";
      exposure = "lan";
      tcpPorts = [ 45876 ];
      udpPorts = [ 45877 ];
    };

    database = {
      hostname = "database.synthetic.test";
      exposure = "loopback";
      httpUpstream = "127.0.0.1:15432";
      tcpPorts = [ 15432 ];
      udpPorts = [ 15433 ];
    };
  };
}
