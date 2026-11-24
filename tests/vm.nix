{ pkgs, lib, ... }:

pkgs.testers.nixosTest {
  name = "homelab-vm";

  nodes.machine = {
    imports = [
      ../modules/server-options.nix
      ../modules/storage.nix
      ../modules/scripts.nix
      ../modules/monitoring.nix
    ];

    networking.hostName = "homelab-test";

    server.notifications.ntfy = {
      baseUrl = "https://notifications.example.test";
      systemTopic = "test-system";
      backupTopic = "test-backup";
    };

    # Use a disposable tmpfs volume to exercise storage mount dependencies
    # without attaching or modifying any physical test/production device.
    server.storage = {
      raidDevice = null;
      volumes.vmTest = {
        device = "tmpfs";
        mountPoint = "/mnt/testvolume";
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };
    };

    # Declare the actual VM tmpfs mount explicitly. The logical storage
    # inventory above drives monitoring and systemd dependencies; this
    # disposable mount provides the runtime resource used by the test.
    fileSystems."/mnt/testvolume" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      auto = true;
    };

    # Use the VM's normal test networking rather than the production
    # homelab interface configuration.
    networking.useDHCP = true;

    # The VM does not have the production storage devices.
    services.fstrim.enable = lib.mkForce false;

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

    # Verify that the temporary storage volume is mounted and is a dependency
    # of the storage-health service.
    machine.wait_for_unit("mnt-testvolume.mount")
    machine.succeed("findmnt --target /mnt/testvolume")
    machine.succeed("systemctl show homelab-storage-health.service -p RequiresMountsFor --value | grep -F /mnt/testvolume")

    # Execute both health checks against the VM's root filesystem and tmpfs
    # storage volume. The storage check must create and remove its test file.
    machine.succeed("systemctl start homelab-disk-health.service")
    machine.succeed("systemctl start homelab-storage-health.service")
    machine.succeed("test ! -e /mnt/testvolume/.homelab-storage-health-test")

    # Verify the generated scripts consume this VM's notification settings.
    machine.succeed("grep -Fx 'NTFY_URL=https://notifications.example.test/test-system' /etc/homelab/scripts/homelab-disk-health")
    machine.succeed("grep -Fx 'NTFY_URL=https://notifications.example.test/test-system' /etc/homelab/scripts/homelab-storage-ntfy")
    machine.succeed("grep -Fx 'NTFY_URL=https://notifications.example.test/test-backup' /etc/homelab/scripts/homelab-backup-ntfy")
    machine.succeed("! grep -Fq '@NTFY_' /etc/homelab/scripts/homelab-disk-health /etc/homelab/scripts/homelab-storage-health /etc/homelab/scripts/homelab-storage-ntfy /etc/homelab/scripts/homelab-backup-ntfy")
  '';
}
