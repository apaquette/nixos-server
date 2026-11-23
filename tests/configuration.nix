{ pkgs, lib, config, unstable }:

let
  helpers = import ./common.nix { inherit lib; };

  tests = [
    (import ./networking.nix { inherit config helpers; })
    (import ./storage.nix { inherit config helpers; })
    (import ./users.nix { inherit config helpers; })
    (import ./caddy.nix { inherit config helpers; })
    (import ./dnsmasq.nix { inherit config helpers; })
    (import ./jellyfin.nix { inherit config pkgs helpers; })
    (import ./media-services.nix { inherit config helpers; })
    (import ./seerr.nix { inherit config pkgs helpers; })
    (import ./minecraft.nix { inherit config pkgs helpers; })
    (import ./sops.nix { inherit config helpers; })
    (import ./ddclient.nix { inherit config helpers; })
    (import ./monitoring.nix { inherit config helpers; })
    (import ./backups.nix { inherit config lib pkgs helpers; })
    (import ./smartd.nix { inherit config helpers; })
    (import ./scripts.nix { inherit config helpers; })
    (import ./hardware.nix { inherit config helpers; })
    (import ./invariants.nix { inherit config helpers; })
    (import ./hardware-specific.nix { inherit config pkgs helpers; })
    (import ./cockpit.nix { inherit config helpers; })
    (import ./homepage.nix { inherit config pkgs lib  helpers unstable; })
    (import ./ntfy.nix { inherit config unstable helpers; })
    (import ./uptime-kuma.nix { inherit config pkgs lib helpers; })
    (import ./beszel.nix { inherit config pkgs unstable lib helpers; })
    (import ./immich.nix { inherit config lib unstable helpers; })
    (import ./jenkins.nix { inherit config lib; })
    (import ./nextcloud.nix { inherit config pkgs lib helpers; })

    # Test the assertion-evaluation contract itself.
    (import ./test-runner.nix { inherit helpers; })

    # Repository structure
    (helpers.assertPathExists "flake.nix" ../flake.nix)
    (helpers.assertPathExists "homelab host" ../hosts/homelab/default.nix)
    (helpers.assertPathExists "hardware configuration" ../hosts/homelab/hardware-configuration.nix)
    (helpers.assertPathExists "users configuration" ../hosts/homelab/users.nix)

    # Scripts
    (helpers.assertPathExists "homelab-backup-ntfy script" ../scripts/homelab-backup-ntfy)
    (helpers.assertPathExists "homelab-disk-health script" ../scripts/homelab-disk-health)
    (helpers.assertPathExists "homelab-storage-health script" ../scripts/homelab-storage-health)
    (helpers.assertPathExists "homelab-storage-ntfy script" ../scripts/homelab-storage-ntfy)

    # Documentation
    (helpers.assertPathExists "README" ../README.md)
    (helpers.assertPathExists "architecture documentation" ../docs/architecture.md)
    (helpers.assertPathExists "backup documentation" ../docs/backup-and-restore.md)

    # State version
    (helpers.assertEqual
      "NixOS state version"
      "26.05"
      config.system.stateVersion)
  ];

  flattenedTests = lib.flatten tests;
  testCount = lib.foldl'
    (count: test:
      builtins.seq test (count + 1)
    )
    0
    flattenedTests;
in
pkgs.runCommand "homelab-configuration-tests" {} ''
  echo "All ${toString (builtins.length flattenedTests)} configuration assertions passed."
  touch $out
''
