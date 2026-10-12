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

## Networking

The host provides the primary LAN infrastructure used by the server.

### dnsmasq

dnsmasq provides:

* DHCP
* LAN DNS
* local service records
* service discovery through the configured domain

Internal service names resolve to the host on the local network, while Caddy handles the corresponding HTTP/TLS routing.

### Caddy

Caddy is the single reverse-proxy entry point for HTTP services.

Two access patterns are used:

* **public services** use externally reachable TLS endpoints
* **internal services** use Caddy's internal TLS authority and are restricted to the LAN

This keeps application services bound to local interfaces where possible rather than exposing individual application listeners directly.

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

The host uses separate storage roles for operating-system state, primary application/media data, and backups.

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

The dedicated backup disk is mounted independently from the primary data volume and hosts the production Restic repository.

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
/mnt/backup/Restic/homelab
```

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
