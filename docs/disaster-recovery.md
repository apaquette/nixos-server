# Homelab Disaster Recovery Runbook

This runbook describes recovery when the original homelab host is unavailable, including loss of the host's local Restic repository. It complements [`backup-and-restore.md`](backup-and-restore.md), which documents the normal backup model and application scopes.

The steps are intentionally conservative. Review the target disks and the host's Disko configuration before running installation or rebuild commands that might format storage.

## Recovery goals and assumptions

The intended recovery source is the off-site Restic repository in Cloudflare R2:

```text
s3:https://<account-id>.r2.cloudflarestorage.com/homelab-restic/homelab
```

The account identifier and bucket/prefix are configured in `modules/backups.nix`. Use the configuration in the repository as the source of truth for the current endpoint. The R2 repository is distinct from `/mnt/backup/Restic/homelab`; snapshot IDs may differ between them.

This runbook assumes that an authorized operator can independently obtain:

* Access to the Git repository containing the NixOS flake and encrypted SOPS configuration.
* The SOPS age private key corresponding to the recipients in `secrets/homelab.yaml`.
* The R2 access credentials and the R2 Restic repository password, either by decrypting the SOPS file with that key or through a separately documented secure recovery method.
* Access to a replacement host and a safe installation path that does not overwrite any disks or data that must be preserved.

**A copy of the age private key on the original server is not an off-site recovery copy.** Before declaring disaster recovery ready, verify that the key is stored securely outside the server and that an authorized operator can retrieve it when the server is unavailable. Do not commit the private key or plaintext credentials to Git.

## 1. Prepare a replacement host

1. Install a compatible NixOS release and establish working network access to the Git host and Cloudflare R2.
2. Confirm which physical disks are present. Do not assume device names match the old host.
3. Inspect `hosts/homelab/hardware-configuration.nix`, any Disko configuration, and `modules/storage.nix` before using any installation or rebuild command. Do not run Disko against disks that contain data to preserve.
4. Restore or clone the infrastructure repository using its actual remote URL:

   ```bash
   GIT_REMOTE='replace-with-the-infrastructure-repository-URL'
   git clone "$GIT_REMOTE" homelab
   cd homelab
   ```

5. Review `flake.nix`, `hosts/homelab/`, networking settings, storage mounts, and the intended machine identity. Adapt hardware-specific settings before switching the configuration.

A replacement server may not be ready to run every public service immediately. Restore storage and secrets first, validate the core host, and bring applications online in a controlled order.

## 2. Restore the SOPS age key securely

The existing host is configured to use the age key at:

```text
/var/lib/sops-nix/key.txt
```

Obtain the key from the approved independent secure copy—not from the failed host. Transfer it using a secure channel, and never place it in the Git working tree.

On the replacement host, install the key with restrictive permissions. Replace the source placeholder with the path of the securely retrieved file:

```bash
RECOVERY_KEY='/path/to/securely-retrieved/key.txt'
sudo install -d -o root -g root -m 0700 /var/lib/sops-nix
sudo install -o root -g root -m 0600 \
  "$RECOVERY_KEY" \
  /var/lib/sops-nix/key.txt
```

Verify that the encrypted secrets file can be decrypted without displaying its plaintext:

```bash
cd /path/to/homelab
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
  nix shell nixpkgs#sops -c sops -d secrets/homelab.yaml >/dev/null
```

If this fails, stop and resolve the key/recipient/configuration issue before attempting R2 access. Do not paste the key, decrypted file, R2 access key, or repository password into logs, tickets, or this repository.

## 3. Re-establish the declarative host

1. Confirm the replacement host's hardware configuration and target filesystems are correct.
2. Confirm the network is configured well enough to reach Git and R2.
3. Build and evaluate the intended host configuration before activating it:

   ```bash
   nix flake check --show-trace
   sudo nixos-rebuild build --flake .#homelab
   ```

4. Review any failures rather than bypassing them. In particular, verify the paths expected by storage and application modules before starting services.
5. Switch to the configuration only after reviewing the generated configuration and confirming that it will not format or mount the wrong device:

   ```bash
   sudo nixos-rebuild switch --flake .#homelab
   ```

6. Confirm SOPS secrets and the generated R2 environment file are present on the replacement host:

   ```bash
   sudo test -r /run/secrets/restic-r2-repository-password
   sudo test -r /run/secrets/rendered/restic-r2.env
   ```

These checks confirm file availability only. They do not print the secrets.

## 4. Confirm access to the R2 repository

First run the configured restore test. This exercises the SOPS-managed R2 credentials and password through the same service configuration used during normal operation:

```bash
sudo systemctl start restic-offsite-restore-test.service
systemctl show restic-offsite-restore-test.service \
  -p Result -p ExecMainStatus
sudo journalctl -u restic-offsite-restore-test.service -n 100 --no-pager
```

Proceed only if the service succeeds and its logs confirm a restore from R2. This test currently restores the latest snapshot tagged `ntfy` and validates that `auth.db` exists and is non-empty. It is an access smoke test, not proof that all applications are recoverable.

If the test fails, inspect the error without printing environment-file contents. Confirm network access, R2 credential decryption, the R2 repository password, the bucket/prefix, and repository availability. Do not initialize a new repository at the configured R2 path as a troubleshooting shortcut; that risks creating or modifying the wrong repository.

## 5. Select the right snapshot and restore to staging

Use [`backup-and-restore.md`](backup-and-restore.md) for the current application backup scopes and database-dump locations. Decide which services and data must be restored first. Prefer restoring into a staging directory and inspecting the result before replacing live paths.

A full application restore must use a snapshot ID from the R2 repository, not the local repository. The repositories can have different snapshot IDs after replication. Select the snapshot by application tag and timestamp using the Restic tools and credentials configured for R2. Do not use a remembered snapshot ID from a prior restore test as the ID for a different repository state.

For a recovery operation, use the `restic` executable available on the replacement system and invoke Restic in a root-owned transient systemd unit so it can read the SOPS-managed R2 environment file without putting access keys in a command line. The command shape is:

```bash
RESTIC_BIN="$(nix shell nixpkgs#restic --command sh -c 'command -v restic')"
RESTORE_SNAPSHOT_ID='replace-with-a-snapshot-id-from-R2'

sudo install -d -o root -g root -m 0700 /restore/staging
sudo systemd-run --wait --pipe --collect \
  --unit=restic-r2-recovery-restore \
  --property=EnvironmentFile=/run/secrets/rendered/restic-r2.env \
  --property=Environment=AWS_DEFAULT_REGION=auto \
  --property=Environment=HOME=/root \
  --property=Environment=XDG_CACHE_HOME=/root/.cache \
  "$RESTIC_BIN" \
  --repo 's3:https://<account-id>.r2.cloudflarestorage.com/homelab-restic/homelab' \
  --password-file /run/secrets/restic-r2-repository-password \
  restore "$RESTORE_SNAPSHOT_ID" \
  --target /restore/staging
```

Replace the placeholders only after confirming the endpoint and snapshot. Ensure `/restore/staging` is an appropriate, access-controlled filesystem with enough free space; `restic restore` reconstructs snapshot paths below the target directory. Do not restore an entire large media/application tree to the root filesystem by accident. For a small recovery, use the Restic include/exclude options appropriate to the snapshot and inspect the restored paths before installing them.

If the command reports an unknown option or if `/restore/staging` is not suitable, stop and consult the installed Restic help rather than improvising against the live data paths.

## 6. Restore system data and databases in a safe order

The detailed steps depend on the application being recovered. Use the current NixOS configuration and the snapshot contents to determine exact paths; do not assume database names, users, or directory layouts that are not verified.

Recommended order:

1. Confirm target filesystems are mounted at the expected paths, especially the application/data volume and any separately retained media storage.
2. Apply and validate the declarative NixOS configuration and SOPS secrets.
3. Restore required persistent application files from the selected R2 snapshot into staging, then inspect ownership, permissions, symlinks, and file contents.
4. Locate and validate any PostgreSQL custom-format dump included in the application snapshot. The existing backup process validates dumps with `pg_restore --list`; repeat that validation on the recovered dump before attempting a database import.
5. Create or restore the necessary PostgreSQL databases, roles, and ownership according to the current service configuration. Stop affected applications while replacing their data or importing database state. Do not run generic `pg_restore --clean` commands against an unknown or shared database without reviewing the target and recovery plan.
6. Copy or restore verified files to their intended production paths only after checking that the target paths and backups are correct.
7. Start services in dependency order: storage and PostgreSQL first, then databases/application state, followed by application services and their dependent reverse-proxy/monitoring services.
8. Verify each affected systemd unit and application-level functionality before returning public traffic.

The configuration currently covers Nextcloud and Immich PostgreSQL dumps and the application state listed in `backup-and-restore.md`. Their recovery details should be validated against the current service options rather than copied from an old host without review.

## 7. Validate recovery

For each restored application:

* Confirm the expected service is active and inspect its journal for errors.
* Confirm persistent directories and mount points resolve to the intended storage.
* Verify database imports and schema availability where applicable.
* Verify application login and a representative read/write workflow where safe.
* Confirm expected user data or representative files are present.
* Confirm reverse-proxy routes and TLS only after backend service health is established.
* Record any manual recovery action that should be made declarative or added to this runbook.

Example unit checks:

```bash
systemctl --failed
systemctl status postgresql.service --no-pager
sudo journalctl -p warning..alert --since today --no-pager
```

Not all services are required to return at once. Prioritize the system's essential services and data, then restore lower-priority workloads.

## 8. Security and post-recovery tasks

If the incident might involve credential exposure or host compromise:

* Rotate R2 access keys and other affected credentials.
* Update the SOPS-encrypted configuration and re-deploy secrets only after the replacement is trusted.
* Review access logs and restore points for signs of tampering.
* Avoid treating a successful Restic check as proof that snapshots are free from unwanted changes; confirm snapshot timestamps and application data with known-good information where possible.
* Protect the restored host and the recovery key according to the normal security model.

Keep recovery logs free of secret values. Securely remove temporary plaintext database dumps and staging directories after recovery is complete and the restored system has been verified.

## Recovery readiness checklist

Before considering this procedure operationally proven, verify each item:

- [ ] The Git remote can be accessed from a separate machine.
- [ ] An authorized operator can retrieve the SOPS age private key without access to the original host.
- [ ] The recovered key decrypts `secrets/homelab.yaml` without revealing plaintext to logs or shell history.
- [ ] R2 access credentials and the Restic repository password can be recovered independently of the failed server.
- [ ] The configured restore-test service can restore the latest `ntfy` snapshot from R2.
- [ ] The R2 retention policy and recurring R2-side integrity-check approach have been decided and documented.
- [ ] The steps above have been walked through from a separate machine or tested against a replacement environment without endangering production data.

A completed checklist should be recorded in the project's operational history without storing secret values.
