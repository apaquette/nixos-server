# Production Deployment

This runbook defines the controlled deployment and release process for the homelab NixOS configuration.

Production activation is deliberately operator-controlled. GitHub Actions evaluates and builds configurations and executes the NixOS VM test; it does not connect to or activate the production host. This keeps the final activation decision, runtime inspection, and rollback under the control of the operator.

## Branch and release flow

Use the repository's protected branches as follows:

1. Develop changes on a feature or fix branch.
2. Open a pull request targeting `dev`. Merge only after all five required CI checks pass.
3. When a milestone is ready for production, open a release pull request from `dev` to `main`. Merge it only after the same required checks pass.
4. Deploy from a clean checkout of `main`, not from an unmerged development branch.
5. Create the version tag and GitHub Release only after the deployed `main` commit passes post-switch runtime validation.

The active `quality-gate` ruleset requires pull requests and the five CI checks on `dev` and `main`. See [CI and required checks](ci.md).

## 1. Prepare the production checkout

Run these commands on the homelab from the infrastructure repository root. The examples use the existing `~/Projects/homelab` checkout.

```bash
cd ~/Projects/homelab

git fetch --prune origin
git switch main
git pull --ff-only origin main

git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
```

Confirm all of the following before continuing:

- The current branch is `main`.
- The working tree is clean; there are no staged, unstaged, or untracked changes.
- `HEAD` matches `origin/main`.
- The commit is the intended release candidate and its pull request has passed all required checks.
- Any storage, data-path, ownership, database, or secret migration has been reviewed separately. A successful Nix build does not prove that a data migration is safe.

Stop if the checkout contains local changes or does not match the intended `main` commit. Do not deploy from a dirty working tree.

## 2. Evaluate and build

Run the complete local flake check suite, followed by a build of the production host:

```bash
nix flake check --print-build-logs

sudo nixos-rebuild build \
  --flake .#homelab \
  --print-build-logs
```

A successful build creates the `result` symlink to the candidate system closure. It does not activate the new configuration.

## 3. Review the activation and generation

First ask NixOS to show the activation changes without applying them:

```bash
sudo nixos-rebuild dry-activate --flake .#homelab
```

Review the reported service, mount, user, and system changes. Stop if the output is unexpected or includes an unreviewed disruptive change.

Record the currently running system, the built candidate, and the existing boot generations:

```bash
printf 'Running system:  '
readlink -f /run/current-system

printf 'Candidate system: '
readlink -f ./result

sudo nixos-rebuild list-generations
```

The candidate and the currently running system may be different. Confirm that the candidate corresponds to the intended `main` checkout and that a previous known-good generation remains available for recovery.

## 4. Temporarily activate and test

Activate the candidate on the running host without making it the default boot generation:

```bash
sudo nixos-rebuild test --flake .#homelab --print-build-logs
```

**This is a live activation, not a VM or isolated test.** It can restart services and interrupt applications. The distinction is that `test` does not make the candidate the default configuration for the next boot. See the [NixOS nixos-rebuild reference](https://wiki.nixos.org/wiki/Nixos-rebuild).

Validate the host immediately:

```bash
systemctl is-system-running
systemctl --failed
sudo journalctl -b -p err --no-pager
```

For the current homelab layout, also verify both declared persistent mounts:

```bash
findmnt --target /mnt/myraid
findmnt --target /mnt/backup
```

Then check the services and capabilities affected by the change. Depending on the scope, this can include:

- The changed systemd services and timers.
- Reverse proxy and DNS resolution for affected services.
- Public and LAN-only reachability from the appropriate networks.
- Application access and any changed database-backed functionality.
- Backup, monitoring, and notification services when their configuration changed.

The expected baseline is `systemctl is-system-running` returning `running` and `systemctl --failed` reporting no failed units. Investigate warnings and failures individually; a completed activation does not make every warning harmless.

**Do not run `switch` if the temporary activation has unexplained failures or important service checks do not pass.** Since `test` leaves the previous generation as the boot default, rebooting returns the host to that previously selected generation. Ensure local or out-of-band access is available before testing changes that could affect network connectivity or remote administration.

## 5. Persist the configuration

Only after the temporary activation and runtime checks succeed, make the candidate the active configuration and default boot generation:

```bash
sudo nixos-rebuild switch --flake .#homelab --print-build-logs
```

Repeat the runtime checks:

```bash
systemctl is-system-running
systemctl --failed
sudo journalctl -b -p err --no-pager
sudo nixos-rebuild list-generations
readlink -f /run/current-system
```

Verify that the newly selected generation corresponds to the candidate and that the relevant services, mounts, and application endpoints remain healthy.

A reboot may still be required for changes such as a new kernel or bootloader configuration to take full effect. When a reboot is required, perform it as a separate planned step and repeat the post-boot health checks.

## 6. Roll back when necessary

If the persistent switch introduces a regression, return to the preceding system generation:

```bash
sudo nixos-rebuild switch --rollback
```

Then repeat the systemd, storage, service, and application checks. If the host is no longer reachable over the network, use the bootloader to select the previous known-good generation or recover through local console access.

Do not publish a release for a deployment that has been rolled back or has unresolved runtime failures.

## 7. Tag and publish the release

After production validation succeeds:

1. Confirm the working tree is still clean and the deployed commit is still the current `main` commit.
2. Record the deployed commit SHA alongside the validation results.
3. Create and push an annotated tag on that exact commit.
4. Publish a GitHub Release using Markdown release notes.

For the v1.3.0 milestone, run these checks before creating the tag:

```bash
git status --short
test -z "$(git status --porcelain)"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
git rev-parse HEAD
```

Only when those checks pass, create and push the tag:

```bash
git tag -a v1.3.0 -m "NixOS server v1.3.0"
git push origin v1.3.0
```

Publish the GitHub Release after the tag exists. Release notes should summarize the architecture and CI changes, the deployment validation performed, and any known limitations; do not describe CI-only checks as production runtime validation.

## Deployment acceptance record

For each production deployment, retain the following in the pull request or release notes:

- Deployed `main` commit SHA and version tag.
- Successful `nix flake check` and homelab build.
- Review of `dry-activate` output.
- Result of the temporary `nixos-rebuild test`.
- Post-switch system health and failed-unit check.
- Verification of affected services, storage mounts, and relevant external access.
- Any warnings, deviations, and rollback actions.

This record links the source revision, generated system, and observed production state. It also provides a clear basis for deciding whether a version is ready to be treated as a stable infrastructure release.
