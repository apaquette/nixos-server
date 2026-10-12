# Roadmap

This document describes planned improvements to the NixOS server infrastructure beyond the completed v1.0 infrastructure baseline.

The v1.0 milestone established the production foundation: declarative NixOS infrastructure, native service management, encrypted secrets, automated application backups, monitoring, and infrastructure tests.

Future work is therefore focused primarily on **architecture, reliability, automation, observability, and infrastructure resilience**.

---

## v1.0 — Completed

### Infrastructure migration

* Migrated the server infrastructure to NixOS.
* Introduced a flake-based system configuration.
* Added Disko for declarative storage configuration.
* Preserved existing RAID-backed application and media data.
* Retained rollback paths throughout the migration.
* Established a reproducible system configuration that can be rebuilt from version-controlled source.

### Native service architecture

* Migrated application workloads to native NixOS/systemd services where appropriate.
* Preserved application state and existing service behaviour wherever practical.
* Declaratively configured service dependencies, storage paths, users, permissions, and networking.
* Replaced application-specific container orchestration with native systemd service management where appropriate.

### Infrastructure services

* Declarative Caddy reverse proxy configuration.
* Local DNS/DHCP through dnsmasq.
* PostgreSQL managed as system infrastructure.
* systemd-based service orchestration and scheduled jobs.
* sops-nix for encrypted secret management.

### Backup and recovery

* Migrated application backups to Restic.
* Added application-aware backup procedures for stateful services.
* Added PostgreSQL database dumps for database-backed applications.
* Added retention and repository maintenance policies.
* Validated backup integrity and representative restore operations.

### Monitoring and maintenance

* Added health checks and service monitoring.
* Integrated operational notifications.
* Added storage and disk health checks.
* Added scheduled maintenance and backup verification.

### Infrastructure testing

* Added repository-level configuration tests.
* Established `nix flake check` as part of the infrastructure development workflow.
* Added regression tests for service configuration and operational invariants.
* Established a test-first approach for infrastructure changes where practical.

---

# v1.1.0 — Reliability

**Priority: High — implementation delivered; recovery-readiness validation remains open.**

The purpose of this milestone is to add an off-host backup copy, automate a representative restore test, and document recovery after complete host loss. The configuration and test currently implement the items below, but the milestone should not be marked fully complete until the remaining readiness items are resolved.

### Off-site Restic backups

**Implemented and runtime-verified:**

* The local Restic repository at `/mnt/backup/Restic/homelab` is copied to a separate Cloudflare R2 Restic repository.
* Scheduled replication runs Monday–Saturday at 08:00.
* A successful Sunday 06:00 local repository integrity check triggers replication through a systemd `OnSuccess` relationship.
* Replication failures use the existing ntfy failure-notification service.
* A manual remote integrity check and representative restore have succeeded; subsequent scheduled Sunday and Monday replication runs were also confirmed successful.

**Remaining reliability work:**

* Confirm that the SOPS age private key and all credentials required to reach and decrypt R2 are recoverable independently of the original host.
* Define and test an R2-specific retention/pruning policy. The local policy is not proof of remote pruning, and the current reviewed configuration does not declare automatic R2 retention.
* Decide whether to add a recurring R2-side repository integrity check and replication-freshness monitoring.

### Automated restore testing

**Implemented and manually verified:**

* A weekly Tuesday 09:00 systemd timer runs `restic-offsite-restore-test.service`.
* The script restores the latest remote snapshot tagged `ntfy` into a temporary directory.
* It verifies that the restored `auth.db` exists and is non-empty, cleans up the temporary directory, and reports failures through the existing notification path.
* The first manual service execution passed, restoring an `auth.db` file of 118,784 bytes.

This proves that a representative file can be retrieved from the R2 repository. It does not prove a complete database or whole-application recovery. Broader application recovery tests may be added when useful, without expanding the scheduled smoke test unnecessarily.

### Disaster-recovery procedure

**Documentation added in this milestone:**

* [`docs/disaster-recovery.md`](disaster-recovery.md) describes independent prerequisites, bootstrap of a replacement NixOS host, restoration from R2, application/data recovery order, and validation.
* [`docs/backup-and-restore.md`](backup-and-restore.md) describes the current schedules, retention boundary, integrity checks, restore-test behavior, and known limitations.

**Before v1.1.0 is declared complete:**

1. Verify and document that the age private key is stored securely outside the host and can be recovered by an authorized operator.
2. Review the R2 retention and recurring integrity-check policy; implement the decisions appropriate for this system.
3. Perform a recovery walkthrough or rehearsal from a separate machine, using the runbook without relying on the original host for secrets.
4. Run `nix flake check --show-trace`, review the configuration and documentation diffs, and commit the release changes.

The runbook deliberately avoids storing secrets in Git and warns operators to inspect target disks before running any installation or Disko-related operation that could format storage.

---

# v1.2 — Architecture & Engineering Workflow

**Priority: High**

v1.2 focuses on making the infrastructure **host-agnostic, testable, and safe to evolve**.

The first part of this milestone addresses an architectural limitation in the v1.0 implementation: reusable service modules still contain assumptions about the concrete deployment environment.

For example, a reverse-proxy module should describe a service endpoint rather than hardcoding the IP address of a particular physical host.

The objective is to establish a clean separation between:

```text
Host configuration
        ↓
environment-specific values

Reusable modules
        ↓
infrastructure behaviour

Tests
        ↓
contracts and invariants
```

Adding a new host should therefore require a new host definition and its environment-specific values rather than editing reusable service modules simply because the host's IP address, storage root, or other environmental properties differ.

---

## Host-agnostic module architecture

Move host-specific configuration out of reusable modules and into host definitions.

### Goals

* Move host-specific network configuration into `hosts/<hostname>`.
* Move host-specific storage locations into `hosts/<hostname>`.
* Introduce typed `server.*` module options for environment-specific configuration.
* Ensure reusable modules consume declared configuration interfaces rather than hardcoded host assumptions.
* Remove hardcoded LAN addresses from Caddy and other reusable modules.
* Represent service connectivity through service endpoints rather than physical host addresses wherever practical.
* Avoid duplicating service ports and connection details between modules.
* Keep application-specific path names inside service modules while allowing the storage root to be supplied by the host.
* Preserve clear module boundaries rather than introducing a monolithic global configuration structure.

### Configuration boundary

The intended separation is:

```text
hosts/homelab/
    host identity
    hardware
    users
    network values
    storage values
    enabled roles
```

versus:

```text
modules/
    service implementation
    system integration
    dependencies
    service-specific defaults
```

Hosts should act as **composition roots**: they assemble reusable modules and provide environment-specific values.

Reusable modules should not need to know which physical or virtual host they are being deployed to.

### Typed configuration interfaces

Introduce focused module options such as:

```nix
server.network.*
server.storage.*
server.services.*
```

rather than relying on arbitrary attributes or a single large configuration object.

For example, a host could provide:

```nix
server.network.lanAddress = "192.168.2.20";
server.storage.dataRoot = "/mnt/myraid";
server.storage.backupRoot = "/mnt/backup";
```

A service module would then consume those values without embedding the physical host's layout in its implementation.

The exact option structure should remain intentionally small. Abstraction should be introduced where it removes real coupling, not merely to increase the number of configuration layers.

### Service endpoint abstraction

Where services communicate locally, prefer eliminating unnecessary network coupling entirely.

For example:

```text
Jellyfin → 127.0.0.1:8096
```

is preferable to:

```text
Jellyfin → 192.168.2.20:8096
```

when both processes are on the same host.

Where a genuinely configurable endpoint is required, represent it as a service interface that another module can consume.

Conceptually:

```nix
server.services.jellyfin.endpoint
```

rather than having Caddy independently encode Jellyfin's address and port.

The goal is to express:

> "Caddy depends on the Jellyfin service endpoint."

rather than:

> "Caddy knows that Jellyfin happens to run on this IP and port."

### Storage abstraction

Application-specific storage paths should be derived from host-provided storage roots.

For example:

```text
host:
    dataRoot = /mnt/myraid

service:
    Nextcloud data = ${dataRoot}/Nextcloud
```

This allows another host to provide a different storage layout without modifying the service implementation.

The same principle should be applied consistently to:

* application data
* backup repositories
* persistent service state
* other host-specific filesystem roots

### Architectural acceptance criterion

The architectural refactor is considered successful when:

> A second host can be defined using the existing reusable modules without modifying those modules solely to account for differences in host address, storage root, or other deployment-specific values.

---

## Multi-host configuration testing

Add a synthetic second host to the test suite before introducing a real second server.

The test configuration should intentionally differ from `homelab` host in values such as:

```text
LAN address
storage root
backup root
```

Both configurations should use the same reusable module set.

The objective is to verify:

```text
different host values
        ↓
same reusable modules
        ↓
valid configuration
```

This should become a regression test for host independence.

A future architectural change that accidentally introduces a hardcoded host assumption should cause the test suite to fail.

---

## Continuous integration

Add CI validation for the repository.

Initial checks:

* `nix flake check`
* Nix evaluation
* configuration builds
* repository-level tests

As the host abstraction develops, CI should validate more than a single concrete deployment.

The intended direction is:

```text
Shared modules
      ↓
Host A evaluation
      ↓
Host B evaluation
      ↓
Configuration tests
      ↓
Build validation
```

Future checks can include formatting, static analysis, and other repository-level quality gates.

---

## NixOS VM testing

Expand the existing configuration tests into realistic VM-based integration tests.

Potential scenarios:

* service startup
* storage declarations
* networking configuration
* reverse-proxy configuration
* secret wiring
* systemd dependency behaviour
* backup service configuration
* host-specific configuration overrides
* service dependency ordering

VM tests should complement, rather than replace, the existing declarative configuration tests.

The goal is to test both:

```text
configuration contract
```

and:

```text
runtime behaviour
```

before changes reach the production host.

---

## Deployment validation

Formalize the production deployment workflow:

```text
Change
  ↓
flake check
  ↓
build
  ↓
test
  ↓
inspect generation
  ↓
switch
  ↓
runtime validation
  ↓
commit / release
```

This provides a predictable path from configuration change to production deployment.

The workflow should continue to preserve the project's TDD approach: a new invariant or regression should be expressed as a failing test before the corresponding implementation change is considered complete.

---

## Versioned infrastructure releases

Use Git tags for stable infrastructure milestones.

Example:

```text
v1.0.0
v1.0.1
v1.1.0
v1.2.0
```

Semantic versioning should be used consistently:

* **Patch** releases for backward-compatible bug fixes.
* **Minor** releases for backward-compatible features and architectural enhancements.
* **Major** releases for changes that require a breaking migration or materially alter the supported deployment model.

Each release should represent a known-good infrastructure state that can be referenced during incident response or rollback.

---

# v1.3 — Observability

**Priority: Medium**

Once the architecture is more reusable and the backup strategy is independently recoverable, the next stage is improving visibility into the operational state of the infrastructure.

### Backup freshness monitoring

Monitor whether each expected backup has completed recently.

Examples:

* latest successful snapshot timestamp
* expected backup frequency
* age of oldest successful application backup
* repository availability
* off-site replication freshness

A backup job that silently stops running should become an observable incident.

### Backup dashboard

Expose backup and recovery status through the existing monitoring stack.

Useful information could include:

* last successful backup per application
* backup age
* repository size
* recent failures
* restore-test results
* off-site replication status

### SMART and hardware monitoring

Improve hardware-health monitoring where current devices or interfaces limit automatic SMART collection.

This includes investigating:

* USB-attached storage
* NVMe devices
* devices where `smartctl` requires additional parameters or capabilities

The goal is to distinguish genuine hardware-health problems from monitoring limitations.

### Recovery-focused alerting

Extend alerts beyond "service is down" to include conditions such as:

* backup failure
* stale backup
* failed restore test
* storage degradation
* repository integrity problems
* unexpected filesystem capacity growth

---

# v2.0 — Infrastructure Expansion

**Priority: Future**

These improvements move the project from a well-recoverable single host toward a more resilient distributed setup.

The architectural work in v1.2 is intentionally separated from this milestone. v1.2 makes the system capable of supporting multiple hosts; v2.0 introduces additional infrastructure that actually uses that capability.

### Secondary host

Introduce a second physical or virtual host for selected workloads or recovery purposes.

Possible roles:

* backup target
* monitoring node
* disaster-recovery host
* replicated services

The second host should be introduced only where it provides a concrete reliability or operational benefit.

### WireGuard-based private networking

Create a secure private network between hosts and trusted remote systems.

Potential uses:

* off-site backup transport
* administrative access
* service-to-service communication
* remote recovery

### Redundancy

Move selected components from single-instance to redundant operation where the additional complexity is justified.

Examples:

* monitoring
* backup infrastructure
* DNS
* selected application services

This should be introduced selectively rather than turning a single-host server into a distributed system without a concrete reliability benefit.

---

# Longer-Term Architecture

As the project evolves, the general direction is to reduce unnecessary mutable infrastructure state while keeping application data in appropriate persistent storage.

The desired model is:

```text
Declarative configuration
        +
Version-controlled infrastructure
        +
Typed configuration interfaces
        +
Encrypted secrets
        +
Persistent application state
        +
Independent backups
        +
Tested recovery procedures
```

The objective is not to eliminate all mutable state.

Application data, databases, caches, and other runtime state should remain mutable where that is operationally appropriate. The goal is instead to make the **infrastructure required to recreate the system deterministic, reusable, and reproducible**.

A mature version of the architecture should make the following separation explicit:

```text
Host
    defines environment

Modules
    define behaviour

Options
    define interfaces

Applications
    own runtime state

Restic
    provides recoverability

Tests
    protect contracts

CI/CD
    protects the path to production
```

This allows the project to evolve from a single-host infrastructure configuration into a reusable infrastructure system without introducing abstraction for its own sake.

---

# Priorities

The roadmap is intentionally ordered by operational and architectural value:

| Version | Focus | Status |
|---|---|---|
| **v1.0.0** | NixOS infrastructure and native service architecture | Complete |
| **v1.1.0** | Off-site backups, automated restore testing, disaster recovery | Implementation delivered; readiness items open |
| **v1.2.0** | Host-agnostic architecture, multi-host testing, CI, deployment validation | Planned |
| **v1.3.0** | Backup observability, SMART monitoring, recovery alerting | Planned |
| **v2.0.0** | Secondary host, WireGuard, selective redundancy | Future |

The v1.1.0 implementation now includes off-site replication, a scheduled representative restore test, and a disaster-recovery runbook. Do not treat v1.1.0 as fully closed until off-host recovery of the SOPS age key is verified, R2 retention/integrity decisions are addressed, and the documented recovery procedure has been reviewed or rehearsed.

The next major development milestone after v1.1.0 remains **v1.2.0**: make the current infrastructure genuinely reusable across hosts before introducing distributed infrastructure.
