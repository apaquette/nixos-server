{ config, lib, unstable, ... }:

{
  services.ntfy-sh = {
    enable = true;
    package = unstable.ntfy-sh;

    settings = {
      base-url = "https://${config.server.services.ntfy.hostname}";
      listen-http = "127.0.0.1:8093";

      auth-file = "/var/lib/ntfy-sh/auth.db";
      auth-default-access = "deny-all";

      cache-file = "/var/lib/ntfy-sh/cache.db";

      behind-proxy = true;
    };
  };

  server.services.ntfy.httpUpstream = lib.mkDefault
    config.services.ntfy-sh.settings.listen-http;
}
