# NixOS Server Architecture

## Overview

The server is implemented as a declarative NixOS system. Hardware, networking, services, persistent storage, secrets integration, monitoring, and backup policy are represented through Nix modules and systemd units.

The architecture separates three concerns:

1. **Declarative system state** — NixOS configuration stored in Git
2. **Mutable application state** — databases, application configuration, indexes, and user data
3. **Operational automation** — systemd timers, monitoring, notifications, and backups

This separation allows the operating environment to remain reproducible without treating application data as disposable configuration.

## System layers

```text
┌─────────────────────────────────────────────────────┐
│                    Git repository                   │
│                                                     │
│  flake.nix  modules/  hosts/  tests/  secrets/     │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│                       NixOS                         │
│                                                     │
│  system configuration                               │
│  users / groups                                     │
│  networking                                         │
│  storage mounts                                     │
│  packages                                            │
│  systemd units                                      │
└───────────────────────┬─────────────────────────────┘
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
      Services      PostgreSQL      Operations
                                    monitoring
                                    backups
                                    notifications
```

## Host configuration boundary

The reusable modules consume typed host values declared by `modules/server-options.nix`. The host composition root supplies the concrete environment through `hosts/<hostname>/network.nix` and `hosts/<hostname>/storage.nix`.

The current interfaces are:

- `server.network.*` for the interface identity, static LAN address, gateway, DNS servers, DHCP range, reservations, and host-owned local DNS names.
- `server.storage.*` for the data and backup mount roots, backing devices, and optional RAID device.

Networking, dnsmasq, filesystem mounts, monitoring, backup jobs, and storage-aware application modules consume these options rather than embedding the homelab's physical values. Application-specific subdirectories remain owned by the relevant service modules. Hardware-specific RAID assembly remains in the host's storage definition.

For the homelab, these values retain the current runtime configuration. A future host can provide different values through its own host files while reusing the same modules.

## Optional module composition

Hosts are composition roots. Each host selects its services and operational capabilities by importing the corresponding modules from its host configuration. A service module that is not imported should not configure that service or leave behind related integrations.

Cross-cutting modules such as Caddy, dnsmasq, backups, monitoring, and storage health checks must be independently selectable where practical. They must not assume that every application is installed. When such an integration is selected, it should consume a declared service interface or capability rather than directly coupling itself to a particular application's implementation.

Storage resources and logical roles are independent. A host may provide an `applicationData` role without a `localBackup` role, or omit host-provided data storage if its selected services do not need it. A backup volume and role are required only when the host selects modules that use local backup storage. RAID support is also optional.

The current configuration does not fully meet this target: the backup module aggregates jobs for several applications, storage/monitoring modules assume both data and backup mounts, and internal Caddy virtual hosts do not yet have explicit LAN source restrictions. These are v1.3.0 refactoring requirements, not guarantees of the current implementation.

The module design follows SOLID at the configuration boundary:

* **Single responsibility:** service modules own application configuration; capability modules own cross-cutting infrastructure.
* **Open/closed composition:** hosts add or omit modules instead of editing a central list of all services.
* **Interface segregation:** consumers receive focused options for the capabilities they use.
* **Dependency inversion:** integrations depend on typed service/capability contracts rather than concrete application-module details.

The synthetic second-host tests must verify that omitted services and capabilities produce no orphaned units, proxy routes, DNS records, backup jobs, or unused storage requirements.

## Networking

The host provides the primary LAN infrastructure used by the server.

### dnsmasq

dnsmasq provides:

* DHCP
* LAN DNS
* local service records
* service discovery through the configured domain

The host declares the local DNS names through `server.network.localDnsNames`; dnsmasq maps those names to the host's configured LAN address. This keeps deployment-specific names out of the reusable dnsmasq module. The later service-endpoint work should allow these records to be derived from declared, enabled services rather than maintaining another independent service list.

Internal service names resolve to the host on the local network, while Caddy handles the corresponding HTTP/TLS routing.

### Caddy

Caddy is the single reverse-proxy entry point for HTTP services.

The target design distinguishes three client access policies:

* **public** — accessible from outside the trusted LAN through an explicitly configured public ingress.
* **lan** — accessible only from configured trusted local networks. Caddy must enforce source restrictions, or another ingress mechanism must provide equivalent controls.
* **loopback** — accessible only to processes on the same host, with no LAN or public ingress.

These policies are independent of the backend listener. For example, Jellyfin can listen on loopback while Caddy provides public access; Homepage can listen on loopback while Caddy exposes it only to LAN clients. Direct TCP/UDP services such as Minecraft declare their own ingress protocol and port rather than using Caddy.

The homelab's intended assignments are Jellyfin (`public` through Caddy), Minecraft (`public` through direct TCP ingress), Beszel (`lan` through Caddy), and Homepage (`lan` through Caddy). These are target policies; the current configuration does not yet enforce all of them. Other services must be classified explicitly as part of the service inventory.

Caddy consumes HTTP(S) service contracts and applies the declared access policy. The firewall consumes the ingress requirements and opens only the necessary ports and sources. Direct service ingress is handled by the relevant service/network integration.

DNS is separate from exposure policy. Public DNS records and local DNS overrides do not authorize access. A public service may also have a local DNS override resolving to the server's LAN address. Conversely, a private DNS record does not make a route private.

**Current implementation limitation:** several internal virtual hosts currently use `tls internal`, but that only selects Caddy's internal certificate authority; it does not restrict clients to the LAN. Those hosts must not be considered securely LAN-only until explicit source restrictions or equivalent ingress controls are implemented and tested. Actual public reachability also depends on router/NAT forwarding outside this repository.

## Application services

Applications are managed as native NixOS services.

Representative service groups include:

| Group            | Services                                     |
| ---------------- | -------------------------------------------- |
| Infrastructure   | Caddy, dnsmasq, PostgreSQL                   |
| File and media   | Nextcloud, Immich, Jellyfin                  |
| Media automation | Sonarr, Radarr, Prowlarr, qBittorrent, Seerr |
| Development      | Jenkins                                      |
| Monitoring       | Beszel, Uptime Kuma, ntfy, Cockpit, Homepage |
| Game hosting     | Minecraft                                    |

Each service is configured through its own NixOS module where practical.

This keeps service-specific concerns isolated while allowing the host configuration to express dependencies between services.

## Persistent storage

The homelab currently uses separate physical storage resources for operating-system state, primary application/media data, and local backups. The reusable architecture should describe storage resources generically and assign optional logical roles to them.

```text
System NVMe
├── EFI system partition
├── NixOS root
└── swap

Primary storage
└── RAID-backed filesystem
    ├── application data
    ├── Nextcloud user data
    ├── Immich library
    └── media library

Backup storage
├── Restic repository
├── application recovery artifacts
└── other retained data
```

The large RAID-backed volume is treated as application/data storage rather than as an operating-system filesystem.

The dedicated backup disk is mounted independently from the primary data volume and hosts the production Restic repository. Keeping these resources physically separate provides a different failure domain for local backups.

The target host interface declares each volume once, for example:

```nix
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

Services consume logical roles rather than physical volume names or duplicated mount-path options. A host without local backups can omit the `localBackup` assignment and omit backup modules. A module that requires a role must declare that dependency and fail evaluation clearly if the host has not assigned it.

The roles are references, not additional storage resources. Multiple roles may refer to the same volume when intentional, but this does not provide physical failure isolation. For the homelab, `applicationData` and `localBackup` should continue to refer to separate physical resources.

The generic volume interface is initially intended for local filesystem mounts used by the current hosts. RAID assembly remains host-specific; network and object-storage backends should be introduced only when a concrete host requires them.

The existing Phase 1 implementation still uses `server.storage.dataRoot`, `server.storage.backupRoot`, `server.storage.dataDevice`, and `server.storage.backupDevice`. Replacing those transitional options with the generic inventory and role assignments is future v1.3.0 implementation work.

## Databases

PostgreSQL provides database storage for stateful applications.

The database layer is kept separate from application binaries and is managed by NixOS.

Database-backed backups use explicit PostgreSQL dumps rather than relying only on filesystem copies. Where application consistency requires it, the backup job temporarily places the relevant service into a consistent state before creating the dump and filesystem snapshot.

## Secrets

Secrets are managed with sops-nix.

The flow is:

```text
Encrypted SOPS file
        │
        ▼
      NixOS
        │
        ├── runtime secret files
        ├── generated environment files
        └── generated service configuration
```

Secrets remain encrypted in Git and are materialized only on the host.

Examples include:

* database credentials
* application API tokens
* monitoring credentials
* notification credentials
* service-specific authentication material

## Service lifecycle

systemd is used as the operational control plane.

Service definitions declare:

* startup ordering
* service dependencies
* persistent state requirements
* restart behavior
* scheduled execution
* failure handlers

This is particularly important for backup jobs. Application backups are represented as independent oneshot services and timers rather than as a single imperative backup script.

## Monitoring

Monitoring is split between application availability, host metrics, and local health checks.

### Beszel

Beszel provides host monitoring and collects system-level metrics.

### Uptime Kuma

Uptime Kuma monitors service availability from the application perspective.

### Local health checks

Custom systemd jobs monitor:

* filesystem capacity
* inode usage
* RAID/storage health
* backup failures

Failure paths send notifications through ntfy.

## Backup architecture

Restic provides both a local recovery path and an off-site copy. Application snapshots are written to the local repository on the dedicated backup disk:

```text
${server.storage.volumes.<localBackup-role>.mountPoint}/Restic/${networking.hostName}
```

The `localBackup` role resolves to the volume assigned by the host. For the homelab this will continue to resolve to `/mnt/backup/Restic/homelab`. The current Phase 1 implementation still uses `server.storage.backupRoot` until the generic volume/role interface is implemented.

The local repository is replicated to a separate Restic repository in Cloudflare R2:

```text
s3:https://<account-id>.r2.cloudflarestorage.com/homelab-restic/homelab
```

The account identifier and repository path are configuration, not credentials. R2 access keys and the remote repository password are managed through sops-nix; secret values must not be written into documentation or Git.

The operational flow is:

```text
Application backup timers (02:30–05:00)
                 │
                 ▼
       Local Restic repository
                 │
                 ▼
       Maintenance / pruning
       daily at 05:30
                 │
                 ▼
       Local integrity check
       Sundays at 06:00
                 │
                 ├── successful scheduled check triggers R2 copy
                 │
                 └── failed check sends failure notification

R2 replication timer: Monday–Saturday at 08:00
R2 restore test: Tuesday at 09:00
```

Application backup jobs are represented as individual oneshot services and timers. The jobs run in a declared order, prepare application state where necessary, capture database dumps where configured, and write application-tagged snapshots. Maintenance prunes the local repository. The weekly integrity check runs after maintenance; its successful completion triggers off-site replication. A separate timer handles Monday–Saturday replication.

The off-site copy service uses the local repository as its source and the R2 repository as its destination. Snapshot IDs in the two repositories may differ after copying; identify snapshots in the repository from which you intend to restore.

The automated restore test runs weekly on Tuesday at 09:00. It restores the latest remote snapshot tagged `ntfy` into an isolated temporary directory, checks that the restored `auth.db` exists and is non-empty, and cleans up the temporary directory. Failures are routed through the existing ntfy notification service.

The test demonstrates that a representative file can be retrieved from R2. It does not prove that every application can be fully recovered, nor does it replace a complete disaster-recovery rehearsal.

Current boundaries to keep visible:

* The weekly scheduled repository check is against the local repository. The R2 repository has been checked manually, but a recurring R2-side integrity-check job is not currently part of the described configuration.
* The configuration shown does not define a separate off-site `forget`/`prune` policy. Local retention settings must not be assumed to delete old snapshots from the R2 repository. Decide and test remote retention separately before enabling automated deletion there.
* Access to encrypted configuration and R2 data depends on recovering the SOPS age private key and the credentials/password needed to open the remote repository independently of the original host.

See [`backup-and-restore.md`](backup-and-restore.md) for backup scopes and operational details, and [`disaster-recovery.md`](disaster-recovery.md) for full-host recovery.

## Configuration validation

The repository uses Nix-based tests to assert important properties of the final system configuration.

Validation covers:

* module configuration
* service definitions
* dependency relationships
* networking
* storage
* secrets
* monitoring
* backup jobs
* NixOS VM behavior

The intended workflow is:

```text
edit configuration
      │
      ▼
nix flake check
      │
      ▼
nixos-rebuild build
      │
      ▼
activate configuration
      │
      ▼
verify runtime state
```

This makes configuration changes reviewable and repeatable instead of depending on undocumented manual setup.

## Design trade-offs

### Declarative configuration vs mutable application data

The Nix configuration defines how services are installed and operated, while application data remains outside the Nix store.

This allows application state to persist independently from configuration generations.

### Local and off-site backup repositories

The local Restic repository is on separate physical backup storage rather than the primary RAID volume, providing a fast recovery path when the host and backup disk remain available. A replicated Restic repository in Cloudflare R2 provides an off-host recovery path if the local host or its disks are lost.

The remote repository introduces additional recovery dependencies: the SOPS age private key, R2 access credentials, and the R2 repository password must be obtainable without the original host. Off-site retention and recurring remote integrity verification also need explicit policies; they should not be inferred from local repository maintenance.

### Native service management

Managing services directly through NixOS increases declarative coverage and reduces dependency on ad-hoc orchestration.

It also means that service-specific state paths, permissions, and lifecycle behavior must be understood explicitly and encoded into the configuration.
