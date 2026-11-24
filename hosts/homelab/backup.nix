{ ... }:

{
  # Public repository location; credentials and repository password remain in SOPS.
  server.backups.remoteRepository =
    "s3:https://08a653e653431727545c1cbbc844423d.r2.cloudflarestorage.com/homelab-restic/homelab";
}
