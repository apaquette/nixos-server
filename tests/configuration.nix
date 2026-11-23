{ pkgs, lib, config, unstable }:

let
  helpers = import ./common.nix { inherit lib; };

  tests = [
    { name = "networking"; result = import ./networking.nix { inherit config helpers; }; }
    { name = "storage"; result = import ./storage.nix { inherit config helpers; }; }
    { name = "users"; result = import ./users.nix { inherit config helpers; }; }
    { name = "caddy"; result = import ./caddy.nix { inherit config helpers; }; }
    { name = "dnsmasq"; result = import ./dnsmasq.nix { inherit config helpers; }; }
    { name = "jellyfin"; result = import ./jellyfin.nix { inherit config pkgs helpers; }; }
    { name = "media-services"; result = import ./media-services.nix { inherit config helpers; }; }
    { name = "seerr"; result = import ./seerr.nix { inherit config pkgs helpers; }; }
    { name = "minecraft"; result = import ./minecraft.nix { inherit config pkgs helpers; }; }
    { name = "sops"; result = import ./sops.nix { inherit config helpers; }; }
    { name = "ddclient"; result = import ./ddclient.nix { inherit config helpers; }; }
    { name = "monitoring"; result = import ./monitoring.nix { inherit config helpers; }; }
    { name = "backups"; result = import ./backups.nix { inherit config lib pkgs helpers; }; }
    { name = "smartd"; result = import ./smartd.nix { inherit config helpers; }; }
    { name = "scripts"; result = import ./scripts.nix { inherit config helpers; }; }
    { name = "hardware"; result = import ./hardware.nix { inherit config helpers; }; }
    { name = "invariants"; result = import ./invariants.nix { inherit config helpers; }; }
    { name = "hardware-specific"; result = import ./hardware-specific.nix { inherit config pkgs helpers; }; }
    { name = "cockpit"; result = import ./cockpit.nix { inherit config helpers; }; }
    { name = "homepage"; result = import ./homepage.nix { inherit config pkgs lib helpers unstable; }; }
    { name = "ntfy"; result = import ./ntfy.nix { inherit config unstable helpers; }; }
    { name = "uptime-kuma"; result = import ./uptime-kuma.nix { inherit config pkgs lib helpers; }; }
    { name = "beszel"; result = import ./beszel.nix { inherit config pkgs unstable lib helpers; }; }
    { name = "immich"; result = import ./immich.nix { inherit config lib unstable helpers; }; }
    { name = "jenkins"; result = import ./jenkins.nix { inherit config lib; }; }
    { name = "nextcloud"; result = import ./nextcloud.nix { inherit config pkgs lib helpers; }; }
    { name = "test-runner"; result = import ./test-runner.nix { inherit helpers; }; }

    {
      name = "repository and documentation";
      result = [
        (helpers.assertPathExists "flake.nix" ../flake.nix)
        (helpers.assertPathExists "homelab host" ../hosts/homelab/default.nix)
        (helpers.assertPathExists "hardware configuration" ../hosts/homelab/hardware-configuration.nix)
        (helpers.assertPathExists "users configuration" ../hosts/homelab/users.nix)
        (helpers.assertPathExists "homelab-backup-ntfy script" ../scripts/homelab-backup-ntfy)
        (helpers.assertPathExists "homelab-disk-health script" ../scripts/homelab-disk-health)
        (helpers.assertPathExists "homelab-storage-health script" ../scripts/homelab-storage-health)
        (helpers.assertPathExists "homelab-storage-ntfy script" ../scripts/homelab-storage-ntfy)
        (helpers.assertPathExists "README" ../README.md)
        (helpers.assertPathExists "architecture documentation" ../docs/architecture.md)
        (helpers.assertPathExists "backup documentation" ../docs/backup-and-restore.md)
        (helpers.assertEqual "NixOS state version" "26.05" config.system.stateVersion)
      ];
    }
  ];

  testCount = lib.foldl'
    (count: test: count + helpers.evaluateTest test.name test.result)
    0
    tests;
in
pkgs.runCommand "homelab-configuration-tests" {} ''
  echo "All ${toString testCount} configuration assertions passed."
  touch $out
''
