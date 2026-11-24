# Roadmap

This document describes planned improvements to the NixOS server infrastructure beyond the completed v1.0 infrastructure baseline.

The v1.0 milestone established the production foundation: declarative NixOS infrastructure, native service management, encrypted secrets, automated application backups, monitoring, and infrastructure tests.

Future work is therefore focused primarily on **architecture, reliability, automation, observability, and infrastructure resilience**.

---

## v1.0.0 — Completed

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

**Priority: High**

**Status: Complete**

v1.1.0 establishes an off-site backup strategy, independently managed remote retention, automated repository verification, representative restore testing, and documented disaster recovery.

### Off-site Restic backups

**Status: Complete**

- Replicate the local Restic repository to Cloudflare R2.
- Preserve the local repository for faster recovery.
- Keep R2 access credentials and the remote repository password managed through sops-nix.
- Apply independent R2 retention grouped by `host,tags`, retaining 14 daily, 8 weekly, and 6 monthly snapshots.
- Trigger replication Monday through Saturday at 08:00.
- Trigger Sunday replication after successful completion of the scheduled 06:00 local integrity check.
- Retain systemd failure notifications through ntfy.

### Automated restore testing

**Status: Complete**

The weekly restore test runs Tuesday at 09:00 and:

1. Checks the R2 repository using `restic check`.
2. Restores the latest snapshot tagged `ntfy` to an isolated temporary directory.
3. Verifies that `auth.db` exists and is non-empty.
4. Cleans up temporary restore data on exit.
5. Uses the existing systemd notification mechanism to report failures.

This verifies representative file recovery from R2. It does not establish that every application can be recovered end-to-end.

### Remote repository verification

**Status: Complete**

- Run weekly structural integrity verification against R2 before the representative restore test.
- Run quarterly full-data verification using `restic check --read-data`.
- Notify through the existing failure-notification mechanism if verification fails.

The quarterly full-data check was manually executed successfully during release validation, reading all 1,219 packs without finding repository errors.

### Disaster-recovery procedure

**Status: Documented**

The `docs/disaster-recovery.md` runbook documents the replacement-host recovery sequence:

1. Prepare a replacement NixOS installation.
2. Recover access to the Git repository and the SOPS age private key.
3. Recover the credentials and repository password required for R2 access.
4. Apply the declarative NixOS configuration.
5. Restore application state and databases from Restic.
6. Validate service health and application functionality before returning production traffic.

An independent SOPS age recipient has been added for desktop recovery, and decryption using the desktop recovery key has been verified.

A complete replacement-host recovery has not been rehearsed because a separate recovery machine is unavailable. The runbook documents the intended process and must not be interpreted as proof of a successful full-host recovery.

### Remaining limitations

The following limitations are accepted for v1.1.0 and do not block completion of the agreed milestone:

- Backup-freshness alerting is not configured.
- The scheduled restore test validates a representative `ntfy` file rather than performing a complete recovery of all applications.
- Full replacement-host recovery is documented but has not been rehearsed.
- The SOPS recovery private key must remain protected in storage independent of the original server.

These limitations provide input for future reliability improvements.

### Acceptance summary

The v1.1.0 implementation provides off-site replication, independent remote retention, automated repository verification, representative restore testing, and a documented disaster-recovery procedure. Core backup, restore, and full-data integrity operations have been validated successfully.

The next release is v1.2.0, which adds Namecheap Dynamic DNS for the homelab's public IPv4 records. The host-agnostic architecture and engineering workflow work is moved to v1.3.0.

# v1.2.0 — Namecheap Dynamic DNS

**Priority: High**

**Status: Complete**

v1.2.0 adds automated Namecheap Dynamic DNS updates to keep the homelab's public IPv4 records synchronized with the residential WAN address.

### Automated DNS updates

**Status: Complete**

- Use the NixOS `services.ddclient` integration with the Namecheap Dynamic DNS protocol.
- Discover the current public IPv4 address through IPify.
- Update the `cloud`, `jellyfin`, `seerr`, `immich`, `ntfy`, and `mc` host records in the `alexpaquette.dev` zone.
- Run the updater on a five-minute systemd timer.
- Use HTTPS for requests to Namecheap's Dynamic DNS endpoint.
- Manage IPv4 A records only; do not attempt to configure IPv6 AAAA records.

### Secret management

**Status: Complete**

- Store the domain-specific Namecheap Dynamic DNS password in the encrypted SOPS secrets file.
- Expose the decrypted password only through the sops-nix runtime secret.
- Grant the ddclient `DynamicUser` access through a dedicated secret group rather than making the password world-readable.
- Keep the Namecheap account password and API credentials out of the updater configuration.

### Configuration tests and operations

**Status: Complete**

- Add declarative assertions for the ddclient protocol, server, account, managed host labels, update interval, IPv4-only behaviour, timer, and secret permissions.
- Document Namecheap DNS prerequisites, secret setup, deployment, verification, and troubleshooting.
- Verify the timer, service execution, and all six public DNS A records after activation.

### Acceptance criteria

The v1.2.0 acceptance criteria are complete:

- [x] All six host labels exist in Namecheap as A+ Dynamic DNS records.
- [x] The encrypted Namecheap Dynamic DNS password is present in the SOPS file and the system build succeeds.
- [x] `nix flake check` and the complete NixOS system build pass.
- [x] The ddclient timer is active and a service execution completes successfully.
- [x] All six public A records resolve to the current public IPv4 address.
- [x] Local dnsmasq overrides continue resolving service hostnames to the homelab's private LAN address.

---

# v1.3.0 — Architecture & Engineering Workflow

**Priority: High**

v1.3.0 focuses on making the infrastructure **host-agnostic, testable, and safe to evolve**.

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
* Make services and operational capabilities independently optional through host-level module composition.
* Ensure modules do not require configuration or create resources for services and capabilities that a host has not selected.
* Define explicit service access policies for public, LAN-only, and host-local exposure.
* Enforce access policy at the appropriate ingress boundary, including reverse-proxy and direct TCP/UDP services.
* Separate generic storage resources from optional logical storage roles.

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

### Optional module composition and dependency boundaries

Modularity must provide both reuse and **selective composition**. A host should import only the services and infrastructure capabilities it needs. Importing a module is the opt-in mechanism; a host should not need to import every service and disable unwanted ones through a growing collection of flags.

The intended boundaries are:

* Each application module owns that application's configuration and runtime integration. A host that does not import `jellyfin.nix` should not configure Jellyfin.
* Cross-cutting capabilities such as reverse proxying, local DNS, backups, monitoring, and storage health checks remain independently selectable where practical.
* Integration modules must not assume that every known application exists. They should consume declared service interfaces or capabilities and create configuration only for those that are present.
* Dependencies must be explicit. A selected module may require a storage root, database, network interface, secret, or another service, but it must not impose that requirement on hosts that do not select the module.
* Storage resources and logical storage roles must remain separate. A host without local backup storage must be able to omit the `localBackup` role and backup modules without supplying placeholder volumes or mount paths.
* Generic backup repository and maintenance logic should be separated from application-specific backup procedures. A service's backup integration should only be present when both the service and the backup capability are selected.
* Optional RAID, external disks, reverse proxying, and other hardware or operational features must not be unconditional assumptions in general-purpose modules.

This applies the relevant SOLID principles at the module boundary: single responsibility for service and capability modules, open/closed composition through adding or omitting modules rather than editing central service lists, focused interfaces for consumers, and dependency inversion through typed service/capability contracts instead of direct references to concrete application modules.

The generic volume and optional-role interfaces are implemented, so storage and monitoring consumers no longer require both application-data and local-backup volumes by default. One known boundary remains: `modules/backups.nix` still groups several application-specific backup jobs in one capability module. That is a candidate for a later service-owned backup integration refactor; it should not be conflated with the host network, storage, or service-exposure interfaces.

### Service exposure and ingress policy

Service availability must be declared explicitly rather than inferred from TLS settings, DNS records, or the address on which an application process listens.

Each network-accessible service should declare an access policy with three supported levels:

* **`public`:** intended to be reachable from outside the trusted LAN through an explicitly configured ingress path. This may be an HTTP(S) reverse proxy or a direct TCP/UDP service such as Minecraft.
* **`lan`:** reachable from trusted local network clients only. The ingress layer must enforce the trusted source networks; using Caddy's internal certificate authority or a private DNS record alone does not make a service LAN-restricted.
* **`loopback`:** host-local only. The service must not receive a LAN or public ingress route, and its network listener should remain bound to loopback where the application supports it.

Access policy is separate from the service's backend bind address and from its ingress mechanism. For example, a Jellyfin process may listen on loopback while Caddy exposes it publicly. A LAN-only Homepage instance may also listen on loopback while Caddy proxies it to trusted LAN clients.

The homelab's intended exposure assignments include:

| Service | Access policy | Ingress |
|---|---|---|
| Jellyfin | `public` | HTTPS through Caddy |
| Minecraft | `public` | Direct TCP on its configured game port |
| Beszel | `lan` | HTTPS through Caddy, restricted to trusted LAN sources |
| Homepage | `lan` | HTTPS through Caddy, restricted to trusted LAN sources |

The homelab declares these policies in its host service inventory. Other imported services are classified there rather than inheriting exposure merely because a Caddy virtual host exists.

Service modules should declare their endpoint, access policy, and the kind of ingress they require. Consumers should use focused service contracts:

* Caddy consumes HTTP(S) service endpoints and applies the appropriate public or LAN-only access policy.
* Direct TCP/UDP services declare their own protocol and port requirements; they must not be forced through an HTTP reverse proxy.
* Firewall configuration is derived from the selected ingress requirements and restricts LAN-only traffic to configured trusted networks.
* Services with `loopback` access produce no external ingress or firewall openings.

DNS publication is a separate concern. Public DNS, split-horizon/local DNS overrides, and access control must not be treated as interchangeable. A public service may also have a local DNS override that resolves to the LAN address for local clients. A private DNS record does not enforce access restrictions, and the existence of a public DNS record does not itself grant network access.

LAN-only Caddy routes combine `tls internal` with an explicit remote-source matcher that returns HTTP 403 to clients outside configured trusted networks. LAN-only direct TCP/UDP ingress is restricted by nftables source rules. Loopback services receive no external ingress. Actual public reachability still depends on router/NAT forwarding outside this repository.

Tests must verify that:

* public HTTP and direct TCP/UDP services receive only their declared ingress;
* LAN-only services cannot be reached from outside the configured trusted networks;
* loopback-only services have no network ingress;
* omitting a service removes its reverse-proxy route, firewall rules, and service-derived DNS records;
* changing a service's access policy changes the generated ingress policy without duplicating endpoint or port declarations.

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

server.storage.volumes = {
  primary = {
    device = "/dev/disk/by-uuid/<primary-volume-uuid>";
    mountPoint = "/mnt/myraid";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  backup = {
    device = "/dev/disk/by-uuid/<backup-volume-uuid>";
    mountPoint = "/mnt/backup";
    fsType = "ext4";
    options = [ "nofail" ];
  };
};

server.storage.roles = {
  applicationData = "primary";
  localBackup = "backup";
};
```

A service module consumes a logical storage role and resolves it to the selected volume's mount point. The physical volume is declared once; the role is a reference to that resource. A host that has no local backup storage can omit the `localBackup` role entirely:

```nix
server.storage.roles = {
  applicationData = "primary";
};
```

The option definitions and defaults should make absent optional roles explicit. A module that is imported and requires a role must fail evaluation with a clear dependency message when that role is not assigned. Hosts that do not import that module must not be required to assign the role.

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

The host declares generic storage volumes once. Each volume describes the resource and its mount configuration; it does not encode whether the volume is intended for application data, backups, media, or another purpose.

Logical roles provide semantic references to those volumes. Initial roles should remain focused on real consumers, such as:

* `applicationData` — persistent data required by applications.
* `localBackup` — local Restic repository storage.

The service modules consume the role they require and retain ownership of their application-specific subdirectories. For example, Nextcloud can derive its data path from the `applicationData` role without knowing which physical device or mount point the host uses.

A role is optional unless an imported module requires it. A host without a backup disk can omit the `localBackup` role and omit backup modules entirely. If a backup module is imported without its required role, configuration evaluation should fail clearly rather than generating an invalid path or silently disabling backups.

Multiple roles may intentionally reference the same volume, but this is a placement choice, not independent redundancy. Placing local backups on the same physical failure domain as application data does not protect against loss of that device. The homelab should continue to assign its local backup role to a physically separate volume.

This generic inventory should initially cover the local filesystem resources required by the current hosts. Do not build a universal storage backend abstraction for network filesystems, object storage, or cloud volumes until there is a concrete use case. RAID assembly and other device-specific preparation remain host-owned.

The same principle should be applied consistently to:

* application data
* local backup repositories
* media or other persistent service data when it has distinct placement requirements
* other host-specific filesystem resources

Hosts that do not enable backups must not be required to declare a backup volume or role. Services that do not require host-provided persistent storage must not acquire a dependency on the `applicationData` role.

### Architectural acceptance criterion

The architectural refactor is considered successful when:

> A second host can be defined by composing only the required modules and supplying its own environment-specific values. It must be possible to omit individual applications, local backup storage, and the backup capability without modifying unrelated reusable modules or supplying unused configuration values.

The absence of an optional module must also mean the absence of its configuration: no orphaned service units, reverse-proxy routes, firewall openings, service-derived DNS entries, backup jobs, or storage dependencies should remain for an omitted capability. Public/LAN/loopback policies must be enforced, not merely documented. Generic volumes must be declared once and assigned to zero or more logical roles without creating mandatory data and backup mounts for every host.

---

## Multi-host configuration testing

Add a synthetic second host to the test suite before introducing a real second server.

The test configuration should intentionally differ from the `homelab` host in values such as:

```text
LAN address
storage volumes and logical role assignments
selected application services
public, LAN-only, and loopback exposure policies
backup capability
```

The synthetic host should deliberately omit at least one application service (for example, Jellyfin) and the local backup-storage/backup capability. It should import a smaller subset of the reusable modules rather than reproducing the homelab's complete service list. It should also assign different services to public, LAN-only, and loopback exposure levels and demonstrate that the same ingress rules are generated from their declarations. Modules shared by both hosts must remain the same implementations.

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

**Status: CI jobs implemented and passing; required branch protection remains outstanding.**

The GitHub Actions workflow runs for pushes and pull requests targeting `main` or `dev`. It separates validation into stable jobs:

* Flake evaluation without building derivations.
* Declarative configuration and multi-host regression tests.
* Production homelab system build.
* Synthetic system build.
* NixOS VM integration test.

Separating these checks makes failures attributable to a specific validation stage and exposes stable status names that can be selected as required checks in GitHub branch protection.

The exact job names and local commands are documented in [CI and required checks](ci.md).

**Merge protection:** CI failures produce failed checks, but GitHub will not block merges until the required status checks are enabled in a branch protection rule or repository ruleset. The `dev` branch currently has no active required-status-check enforcement. It must require all five CI jobs before Phase 6 can be considered fully enforced.

---

## NixOS VM testing

**Status: Integrated into CI and passing.**

The existing VM test is exposed as `checks.x86_64-linux.homelab-vm` and executed by GitHub Actions.

The test boots a minimal NixOS VM and verifies:

* system health reaches `running`;
* disk-health and storage-health timers are enabled and active;
* a disposable tmpfs storage volume is mounted;
* the storage-health systemd service declares the mount dependency and completes successfully;
* the disk-health service executes against the VM filesystems;
* generated notification scripts use the VM's configured ntfy endpoint and topics;
* generated scripts contain no unresolved notification placeholders.

The temporary volume exercises storage and systemd dependencies without requiring production disks, RAID, secrets, or physical homelab access.

VM testing complements rather than replaces declarative configuration assertions. It validates both the configuration contract and selected runtime behaviour before changes reach the production host.

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

# v1.4.0 — Observability

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

The architectural work in v1.3.0 is intentionally separated from this milestone. v1.3.0 makes the system capable of supporting multiple hosts; v2.0 introduces additional infrastructure that actually uses that capability.

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
| **v1.1.0** | Off-site backups, automated restore testing, disaster recovery | Complete |
| **v1.2.0** | Namecheap Dynamic DNS for public IPv4 records | Complete |
| **v1.3.0** | Host-agnostic architecture, multi-host testing, CI, deployment validation | In progress |
| **v1.4.0** | Backup observability, SMART monitoring, recovery alerting | Planned |
| **v2.0.0** | Secondary host, WireGuard, selective redundancy | Future |

The v1.1.0 milestone establishes an independently hosted backup copy, automated repository verification, representative restore testing, and documented disaster recovery.

v1.2.0 is complete. v1.3.0 is in progress: the typed network, storage, service-exposure, secrets, notification, and remote-backup interfaces are implemented in the current architecture work. The remaining phases are to add a synthetic second-host regression configuration, integrate VM tests into CI, validate both host builds, and formalize deployment validation and release.
