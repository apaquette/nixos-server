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

## Require CI before merging

Workflow jobs produce the following stable GitHub check names:

- `Flake evaluation`
- `Declarative configuration tests`
- `Build homelab system`
- `Build synthetic system`
- `Homelab VM integration test`

Configure these as required status checks for the `dev` branch (and `main` if direct pull requests to the production branch are permitted):

1. Open the repository's **Settings → Branches** and add a branch protection rule for `dev`, or create an equivalent repository ruleset.
2. Enable **Require a pull request before merging**.
3. Enable **Require status checks to pass before merging**.
4. Select all five check names listed above.
5. Save the rule and verify that a pull request cannot merge while one of the required checks is failing.

**Current repository state:** the `dev` branch is not enforcing required status checks. Its branch-protection status currently reports no active required-check enforcement. The five checks above must still be added to the branch protection rule or repository ruleset.

A successful Actions workflow is not, by itself, a merge block. Required status checks must be enabled in repository settings for GitHub to enforce them.
