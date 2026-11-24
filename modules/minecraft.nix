{ pkgs, ... }:

{
  services.minecraft-server = {
    enable = true;
    eula = true;
    declarative = true;

    package = pkgs.minecraft-server;
    dataDir = "/var/lib/minecraft";

    jvmOpts = "-Xms2048M -Xmx4096M";

    openFirewall = false;

    serverProperties = {
      server-port = 4300;
      enable-query = true;
      "query.port" = 25565;

      difficulty = "normal";
      gamemode = "survival";

      "allow-cheats" = true;
      "allow-flight" = false;

      "max-players" = 5;
      motd = "Alex's Minecraft server!";

      "online-mode" = true;
      "white-list" = true;

      "generate-structures" = true;
      "level-name" = "world";

      "view-distance" = 10;
      "simulation-distance" = 10;

      "spawn-protection" = 16;
      "player-idle-timeout" = 0;

      "enable-status" = true;
      "enforce-secure-profile" = true;

      "force-gamemode" = false;
      hardcore = false;

      "max-world-size" = 29999984;
      "max-tick-time" = 60000;

      "network-compression-threshold" = 256;
      "rate-limit" = 0;

      "entity-broadcast-range-percentage" = 100;

      "function-permission-level" = 2;
      "op-permission-level" = 4;

      "pause-when-empty-seconds" = 60;

      "use-native-transport" = true;
      "sync-chunk-writes" = true;

      "region-file-compression" = "deflate";
    };

    whitelist = {
      elismart13 = "9603bf04-c7f4-4a08-a0c7-8cdd1ec41d51";
      godlesscleric = "c63f635d-43cb-48de-8a6d-032203300cf5";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0700 minecraft minecraft -"
  ];
}
