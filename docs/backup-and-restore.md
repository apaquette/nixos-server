# NixOS Server Backup and Restore

## Overview

Application backups are implemented declaratively with NixOS systemd units and Restic.

The design goal is to produce recoverable snapshots of application state while preserving database consistency and keeping backup behavior reproducible.

The local production repository is:

```text
/mnt/backup/Restic/homelab
```

The off-site repository is a separate Restic repository in Cloudflare R2:

```text
s3:https://<account-id>.r2.cloudflarestorage.com/homelab-restic/homelab
```

The actual account identifier is configured in `modules/backups.nix`. R2 credentials and the remote repository password are managed through sops-nix. Do not copy credential values into docs, shell history, or Git. The local and remote repositories have different repository IDs; use snapshot IDs from the repository you are restoring.

## Backup model

Each application has its own Restic backup job.

```text
systemd timer
    │
    ▼
backup service
    │
    ├── prepare state
    ├── stop application when required
    ├── create database dump when required
    └── snapshot persistent data
```

Application backups run sequentially.

This gives the backup system deterministic ordering and avoids having several large snapshots compete for disk and CPU resources simultaneously.

## Application backup scopes

| Application | Backup scope                    | Database handling             |
| ----------- | ------------------------------- | ----------------------------- |
| Nextcloud   | Application state and user data | PostgreSQL custom-format dump |
| Immich      | Full persistent Immich storage  | PostgreSQL custom-format dump |
| Minecraft   | Server data directory           | Filesystem snapshot           |
| Jellyfin    | Application state               | Filesystem snapshot           |
| Sonarr      | Application data directory      | Filesystem snapshot           |
| Radarr      | Application data directory      | Filesystem snapshot           |
| Beszel      | Persistent hub state            | Filesystem snapshot           |
| ntfy        | Persistent state directory      | Filesystem snapshot           |

The Jellyfin media library is intentionally excluded from the application backup scope. Media stored on the primary media volume is treated differently from mutable application state.

Homepage and other fully declarative services are not backed up as application state when their configuration is reproducible directly from Git.

## Special cases

### Nextcloud

Nextcloud backups include:

```text
/var/lib/nextcloud
/mnt/myraid/Nextcloud
PostgreSQL dump
```

The database dump is created in the same temporary runtime area as the backup operation and is included in the same Restic snapshot as the application state.

The backup process:

1. checks whether Nextcloud is already in maintenance mode
2. enables maintenance mode only when necessary
3. stops the Nextcloud cron timer/service as required
4. creates a PostgreSQL custom-format dump
5. validates the dump with `pg_restore --list`
6. creates the Restic snapshot
7. removes the temporary dump
8. restores the application to its previous operational state

If maintenance mode was already enabled before the backup started, the backup does not disable it during cleanup.

### Immich

Immich backups include the parent storage root:

```text
/mnt/myraid/Immich
```

This captures the complete persistent Immich storage layout rather than only the library subdirectory.

A PostgreSQL custom-format dump is created before the Restic snapshot.

The dump is validated with:

```bash
pg_restore --list
```

### DynamicUser services

Some NixOS services use systemd `DynamicUser` and `StateDirectory`.

For these services, the public `/var/lib/...` path may be a symlink to a private state directory.

The backup configuration therefore targets the actual persistent state paths:

```text
Beszel:
  /var/lib/private/beszel-hub

ntfy:
  /var/lib/private/ntfy-sh
```

This is important because backing up only the public symlink can result in a successful Restic command that contains no application data.

## Schedule

All times are local server time.

### Local application backups and repository jobs

| Time | Job |
|---|---|
| Daily 02:30 | Nextcloud snapshot |
| Daily 03:00 | Immich snapshot |
| Daily 03:30 | Minecraft snapshot |
| Daily 04:00 | Jellyfin snapshot |
| Daily 04:15 | Sonarr snapshot |
| Daily 04:30 | Radarr snapshot |
| Daily 04:45 | Beszel snapshot |
| Daily 05:00 | ntfy snapshot |
| Daily 05:30 | Local Restic maintenance / pruning |
| Sunday 06:00 | Local Restic repository integrity check |

### Off-site operations

| Schedule | Job |
|---|---|
| Monday–Saturday 08:00 | Copy new snapshots from the local repository to Cloudflare R2 |
| Sunday, after the 06:00 check succeeds | Copy snapshots to R2 through `OnSuccess=restic-offsite-copy.service` |
| Tuesday 09:00 | Restore-test the latest R2 snapshot tagged `ntfy` |

Local application backup timers, the maintenance timer, the integrity-check timer, and the restore-test timer are configured as persistent timers. The off-site copy timer deliberately uses `Persistent = false` and only schedules Monday through Saturday. This avoids replaying a missed weekday replication activation on Sunday before the scheduled integrity check succeeds.

The Sunday integrity check is a oneshot service with an `OnSuccess` trigger for the off-site copy. Manually starting that check and allowing it to succeed will also trigger off-site replication. Do not manually run it just to inspect service state.

## Retention

Snapshots are grouped by:

```text
host,tags
```

Retention policy:

```text
14 daily
8 weekly
6 monthly
```

Maintenance performs snapshot pruning and repository cleanup.

The configuration deliberately keeps retention policy in Nix so it is version-controlled alongside the backup architecture.

## Failure handling

Backup services use systemd failure dependencies to trigger ntfy notifications when a backup fails.

This provides two layers of protection:

```text
backup failure
     │
     ├── systemd records failure
     │
     └── notification service
              │
              ▼
             ntfy
```

Health checks also monitor storage capacity and inode usage.

## Repository verification

Repository integrity is checked independently from normal backup execution.

The integrity job runs:

```bash
restic check
```

and validates:

* repository indexes
* packs
* snapshots
* trees
* blobs

The intended operating pattern is:

```text
backup
  ↓
maintenance / prune
  ↓
integrity check
```

A repository check is also performed after significant cleanup operations.

## Off-site replication to Cloudflare R2

The `restic-offsite-copy.service` runs `scripts/restic-offsite-copy`. It copies snapshots from the local repository at `/mnt/backup/Restic/homelab` to the configured Cloudflare R2 repository. Source and destination repository passwords are separate SOPS-managed secrets. R2 access keys are supplied using the generated `restic-r2.env` environment file.

The copy service is a systemd oneshot with a failure notification through `homelab-backup-notify@%p.service`. The schedule and Sunday success-trigger are declared in `modules/backups.nix` and tested in `tests/backups.nix`.

A remote `restic check` and a representative remote restore have been run manually and succeeded. The weekly scheduled check currently validates the local repository; it should not be described as a scheduled R2 integrity check.

### Off-site retention and integrity boundary

The local repository has a declared retention policy grouped by `host,tags` (14 daily, 8 weekly, 6 monthly). The current configuration does not show an independent R2 pruning policy. Do not assume that local pruning deletes the corresponding snapshots from R2, and do not add automatic remote deletion until its retention rules and recovery implications have been tested.

A separate recurring R2-side integrity check and backup-freshness alert are also not configured in the definitions reviewed for v1.1.0. These are outstanding reliability improvements, not completed functionality.

## Automated restore test

`restic-offsite-restore-test.service` runs weekly on Tuesday at 09:00. It uses the R2 repository and its SOPS-managed credentials to:

1. Create an isolated temporary directory.
2. Restore the latest snapshot tagged `ntfy` from R2.
3. Verify that `var/lib/private/ntfy-sh/auth.db` exists in the restored tree and is non-empty.
4. Remove the temporary directory on exit, including failure paths.
5. Send a failure notification through the existing systemd notification template if the service fails.

A successful run confirms that a representative file can be downloaded, decrypted, and restored from R2. It does **not** validate the semantic integrity of the database, test a live ntfy startup, or prove that Nextcloud, Immich, PostgreSQL, and all other applications can be recovered end-to-end. The test is deliberately small to reduce runtime and remote reads.

Inspect the service and timer with:

```bash
systemctl status restic-offsite-restore-test.service --no-pager
systemctl list-timers --all restic-offsite-restore-test.timer
sudo journalctl -u restic-offsite-restore-test.service -n 100 --no-pager
```

Run the test intentionally with:

```bash
sudo systemctl start restic-offsite-restore-test.service
```

This manual start is appropriate for the restore-test service; avoid manually running the integrity-check service solely for testing because its successful completion triggers off-site replication.

## Restore validation

Backups are not considered validated merely because `restic backup` exits successfully.

Validation is performed against actual snapshots.

### Database validation

Database dumps are extracted directly from Restic snapshots and inspected with:

```bash
pg_restore --list backup.dump
```

This verifies that the snapshot contains a structurally valid PostgreSQL dump.

### Filesystem validation

Representative files are restored directly from Restic snapshots and compared against known-good source data using SHA-256 hashes.

Example:

```bash
sha256sum restored-file
sha256sum source-file
```

This verifies that the bytes retrieved from the repository match the expected source data.

### Repository validation

The Restic repository is also checked with:

```bash
restic check
```

A successful check reports that no repository errors were found.

## Recovery workflow

For full-host recovery, use [`disaster-recovery.md`](disaster-recovery.md). The checklist below is for recovery of one application when the host and necessary secrets are still available.

A normal application recovery consists of:

```text
1. Identify the required snapshot
2. Inspect snapshot contents
3. Restore application files to a temporary location
4. Restore or validate the database dump
5. Stop the affected application
6. Restore the required production paths
7. Start the application
8. Verify service health
9. Verify application-level functionality
```

Recovery should be performed selectively whenever possible rather than blindly overwriting the entire host.

## Example inspection commands

List snapshots:

```bash
sudo nix shell nixpkgs#restic -c restic \
  --repo /mnt/backup/Restic/homelab \
  --password-file /run/secrets/restic-repository-password \
  snapshots --compact
```

Inspect a snapshot:

```bash
sudo nix shell nixpkgs#restic -c restic \
  --repo /mnt/backup/Restic/homelab \
  --password-file /run/secrets/restic-repository-password \
  ls <snapshot-id>
```

Extract a file:

```bash
sudo nix shell nixpkgs#restic -c restic \
  --repo /mnt/backup/Restic/homelab \
  --password-file /run/secrets/restic-repository-password \
  dump <snapshot-id> <path> > restored-file
```

Check the repository:

```bash
sudo nix shell nixpkgs#restic -c restic \
  --repo /mnt/backup/Restic/homelab \
  --password-file /run/secrets/restic-repository-password \
  check
```

## Recovery limitations and remaining work

The local repository on a separate physical disk provides a fast recovery path for failures isolated to the primary data volume. The Cloudflare R2 repository adds a separate off-host copy, but a reliable full-host recovery still depends on recovering the credentials and configuration needed to access it.

The following limitations remain explicit:

* The SOPS age private key must have a protected copy independent of the original host. Without it, encrypted secrets in Git may not be decryptable.
* The R2 repository password and the R2 access credentials must be recoverable through the encrypted configuration or another documented secure recovery mechanism.
* The scheduled restore test checks one representative file from an `ntfy` snapshot; it is not a full application recovery test.
* R2-side integrity verification is currently manual rather than scheduled.
* The configuration reviewed for v1.1.0 has no separately declared R2 retention/pruning policy. Remote snapshot growth and cleanup need to be assessed before release completion.
* A complete recovery from a replacement host has not been claimed merely because a representative file restore succeeded.

Use [`disaster-recovery.md`](disaster-recovery.md) for the full-host procedure and its readiness checklist.
