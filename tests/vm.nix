{ pkgs, lib, ... }:

pkgs.testers.nixosTest {
  name = "homelab-vm";

  nodes.machine = {
    imports = [
      ../modules/server-options.nix
      ../modules/scripts.nix
      ../modules/monitoring.nix
    ];

    networking.hostName = "homelab-test";

    server.notifications.ntfy = {
      baseUrl = "https://notifications.example.test";
      systemTopic = "test-system";
      backupTopic = "test-backup";
    };

    server.storage.raidDevice = null;

    # Use the VM's normal test networking rather than the production
    # homelab interface configuration.
    networking.useDHCP = true;

    # The VM does not have the production storage devices.
    services.fstrim.enable = false;

    # The production scripts are installed declaratively.
    environment.systemPackages = [
      pkgs.curl
    ];

    # Keep the VM small and deterministic.
    virtualisation.memorySize = 2048;

    system.stateVersion = "26.05";
  };

  testScript = ''
    machine.start()

    machine.wait_for_unit("multi-user.target")

    # Basic NixOS runtime health.
    machine.succeed("systemctl is-system-running --wait")

    # Verify declaratively installed homelab scripts are present.
    machine.succeed("test -x /etc/homelab/scripts/homelab-disk-health")
    machine.succeed("test -x /etc/homelab/scripts/homelab-storage-health")

    # Monitoring timers should be loaded.
    machine.succeed("systemctl is-enabled homelab-disk-health.timer")
    machine.succeed("systemctl is-enabled homelab-storage-health.timer")

    # The timers should be active after reaching multi-user.target.
    machine.succeed("systemctl is-active homelab-disk-health.timer")
    machine.succeed("systemctl is-active homelab-storage-health.timer")
  '';
}
