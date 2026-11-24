{ ... }:

{
  # The encrypted file and decryption identity are deployment-specific.
  server.secrets = {
    sopsFile = ../../secrets/homelab.yaml;
    ageKeyFile = "/var/lib/sops-nix/key.txt";
  };
}
