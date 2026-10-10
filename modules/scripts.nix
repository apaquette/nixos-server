{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    curl
    gawk
  ];

  environment.etc = {
    "homelab/scripts/homelab-backup-ntfy".source = ../scripts/homelab-backup-ntfy;
    "homelab/scripts/homelab-disk-health".source = ../scripts/homelab-disk-health;
    "homelab/scripts/homelab-storage-health".source = ../scripts/homelab-storage-health;
    "homelab/scripts/homelab-storage-ntfy".source = ../scripts/homelab-storage-ntfy;
    "homelab/scripts/restic-offsite-copy".source = ../scripts/restic-offsite-copy;
  };
}
