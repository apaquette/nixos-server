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
| Quarterly: January, April, July, and October 1 at 12:00 | Full R2 data-integrity check using `restic check --read-data` |

### Off-site operations

| Schedule | Job |
|---|---|
| Monday–Saturday 08:00 | Copy new snapshots from the local repository to Cloudflare R2 |
| Sunday, after the 06:00 check succeeds | Copy snapshots to R2 through `OnSuccess=restic-offsite-copy.service` |
| Tuesday 09:00 | Restore-test the latest R2 snapshot tagged `ntfy` |

Local application backup timers, the maintenance timer, the integrity-check timer, and the restore-test timer are configured as persistent timers. The off-site copy timer deliberately uses `Persistent = false` and only schedules Monday through Saturday. This avoids replaying a missed weekday replication activation on Sunday before the scheduled integrity check succeeds.

The Sunday integrity check is a oneshot service with an `OnSuccess` trigger for the off-site copy. Manually starting that check and allowing it to succeed will also trigger off-site replication. Do not manually run it just to inspect service state.

## Retention

Snapshots in both repositories are grouped by:

```text
host,tags
```

Both the local and R2 repositories use the following retention policy:

```text
14 daily
8 weekly
6 monthly
```

### Local repository

Local Restic maintenance runs daily at 05:30 and applies the configured retention policy to the local repository.

### Cloudflare R2 repository

Off-site replication applies the same retention policy independently to the R2 repository. After a successful snapshot copy, `scripts/restic-offsite-copy` runs Restic `forget --prune` with the configured retention rules.

Local pruning does not automatically prune the R2 repository. Each repository maintains its own snapshot metadata and retention state.

The off-site retention mode is configured declaratively in `modules/backups.nix` and enforced by the replication script. Retention options and the configured enforcement mode are covered by assertions in `tests/backups.nix`.

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

R2 integrity verification is automated through `restic-offsite-restore-test.service`, which runs weekly on Tuesday at 09:00. The service first runs `restic check` against the R2 repository; only if that succeeds does it restore and validate the representative `ntfy` snapshot. The local repository has its own Sunday integrity check. A separate quarterly R2 full-data check runs `restic check --read-data`.

### Off-site retention and integrity verification

The R2 repository has an independently enforced retention policy matching the local policy: 14 daily, 8 weekly, and 6 monthly snapshots grouped by `host,tags`. Replication runs the retention operation after the snapshot copy succeeds.

R2 integrity verification has two levels:

- **Weekly structural verification:** `restic check` runs before the representative restore test on Tuesday.
- **Quarterly full-data verification:** `restic check --read-data` reads the repository's stored data in addition to checking its structure.

Both services use the SOPS-managed R2 credentials and repository password. The services have systemd failure notifications configured.

Backup-freshness monitoring is not currently configured. Automated checks validate repository integrity and representative recoverability, but they do not alert independently when an expected snapshot becomes stale.

## Automated restore test

`restic-offsite-restore-test.service` runs weekly on Tuesday at 09:00.

The script performs the following steps:

1. Create an isolated temporary directory.
2. Run `restic check` against the R2 repository.
3. Restore the latest snapshot tagged `ntfy`.
4. Verify that `var/lib/private/ntfy-sh/auth.db` exists in the restored tree and is non-empty.
5. Remove the temporary directory on exit, including failure paths.
6. Report failures through the existing systemd notification mechanism.

A successful run confirms that a representative file can be retrieved, decrypted, and restored from R2, and that the repository passes the structural check. It does not validate the semantic integrity of the database, test a live ntfy startup, or prove that every application can be recovered end-to-end.

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

- A desktop SOPS recovery key has been added as a recipient and successfully tested against `secrets/homelab.yaml`. The private key must remain backed up securely and independently of both the desktop and the homelab server.
- Recovery requires access to the Git repository, the SOPS recovery key, the Cloudflare account and R2 credentials, and the Restic repository password.
- The scheduled restore test validates one representative file from an `ntfy` snapshot. It is not a complete application-recovery test.
- Backup-freshness alerting is not configured.
- Full replacement-host recovery has not been rehearsed. The disaster-recovery procedure is documented, but its end-to-end execution on a separate recovery environment remains unverified.

Use [`disaster-recovery.md`](disaster-recovery.md) for the full-host procedure and its readiness checklist.
