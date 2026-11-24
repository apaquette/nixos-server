# Continuous Integration

GitHub Actions validates pull requests and pushes targeting `main` or `dev`.

The workflow is defined in `.github/workflows/ci.yml` and separates evaluation, declarative tests, system builds, and VM integration so failures are attributable to a specific validation stage.

## Required CI jobs

| Job | Validation |
|---|---|
| **Flake evaluation** | Evaluates the flake outputs and both NixOS configurations without building derivations |
| **Declarative configuration tests** | Builds the host configuration and multi-host regression checks |
| **Build homelab system** | Builds the production homelab system closure |
| **Build synthetic system** | Builds the non-production synthetic system closure |
| **Homelab VM integration test** | Boots the NixOS test VM and exercises health-check services, systemd timers, generated notification scripts, and a disposable storage mount |

The VM test uses a tmpfs-backed volume. It does not require production disks, RAID devices, secrets, or access to the real homelab.

## Local validation

Run the complete check suite from the repository root:

```bash
nix flake check --print-build-logs
```

The equivalent individual CI stages are:

```bash
nix flake check --no-build --print-build-logs

nix build --no-link --print-build-logs \
  .#checks.x86_64-linux.configuration \
  .#checks.x86_64-linux.multi-host

nix build --no-link --print-build-logs \
  .#nixosConfigurations.homelab.config.system.build.toplevel

nix build --no-link --print-build-logs \
  .#nixosConfigurations.synthetic.config.system.build.toplevel

nix build --no-link --print-build-logs \
  .#checks.x86_64-linux.homelab-vm
```

The VM test requires a Linux builder with KVM support. GitHub Actions runs it on `ubuntu-latest`.

## Required checks and branch ruleset

The repository's active `quality-gate` ruleset applies to:

- `dev`
- `main` (the repository's default branch)

It requires all five CI checks to pass before a pull request can merge:

- `Flake evaluation`
- `Declarative configuration tests`
- `Build homelab system`
- `Build synthetic system`
- `Homelab VM integration test`

The ruleset also requires pull requests and prevents branch deletion and non-fast-forward updates. Both long-lived branches therefore use the same CI quality gate.

To inspect or maintain the ruleset, open **Settings → Rules → Rulesets → quality-gate**. When changing a workflow job's display name, update the required-check entry in the ruleset as part of the same change; otherwise GitHub may wait for a status name that the workflow no longer emits.

A successful Actions workflow is not itself a deployment. CI evaluates and builds the configurations and runs the VM test, but it does not activate the homelab. Production deployment remains a deliberate operator action documented in [Production deployment](deployment.md).
