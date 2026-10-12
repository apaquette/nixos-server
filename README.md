# NixOS Server Infrastructure

Declarative infrastructure for a self-hosted server, built around NixOS, systemd, Caddy, PostgreSQL, sops-nix, and Restic.

The project treats the server as infrastructure-as-code: system configuration, service definitions, networking, secrets integration, monitoring, and backup policy are maintained in Git and reproduced through NixOS configuration.

## Technical Highlights

This project focuses on infrastructure engineering rather than simply hosting applications.

* **Declarative infrastructure** — The complete host configuration is defined in NixOS modules and managed through a flake, making system state reproducible, reviewable, and version-controlled.
* **Service orchestration with systemd** — Application lifecycle, ordering, dependencies, scheduled jobs, persistent mounts, and failure handling are expressed through native systemd units rather than ad-hoc shell orchestration.
* **Database-aware backups** — Stateful applications such as Nextcloud and Immich use PostgreSQL custom-format dumps captured alongside their persistent application data, providing a consistent recovery boundary.
* **Automated backup lifecycle** — Restic backups are scheduled and ordered declaratively, with service quiescing, cleanup, retention, pruning, repository integrity checks, and failure notifications handled automatically.
* **Off-site backup replication** — The local Restic repository is copied to a separate Cloudflare R2 repository, with scheduled weekday replication and a Sunday integrity-check success trigger.
* **Automated restore validation** — A weekly restore test retrieves a representative `ntfy` snapshot from R2, validates a restored database file, cleans up temporary data, and uses the existing failure-notification path. This smoke test complements, but does not replace, full application recovery testing.
* **Encrypted secret management** — sops-nix keeps credentials and API tokens encrypted in Git while exposing them to services only through controlled runtime secret files and generated environment configuration.
* **Layered monitoring** — Beszel, Uptime Kuma, custom storage-health checks, and failure notifications provide complementary views of host health, service availability, filesystem capacity, and operational failures.
* **Internal and external service isolation** — Caddy provides reverse-proxy and TLS termination, with separate public and LAN-only service exposure and dnsmasq providing local service discovery.
* **Infrastructure testing** — Declarative assertions and NixOS VM tests verify service configuration, dependencies, storage, networking, secrets, monitoring, and backup invariants before production activation.
* **Explicit state boundaries** — Declarative configuration is kept separate from mutable application state, allowing services to be rebuilt or reconfigured without treating persistent data as disposable.


## Highlights

* **NixOS 26.05** for declarative system and service management
* **Nix flakes** for reproducible configuration and pinned dependencies
* **systemd** for service lifecycle, scheduling, dependencies, and failure handling
* **Caddy** for public reverse proxying and internal TLS
* **dnsmasq** for LAN DNS and DHCP
* **PostgreSQL 17** for stateful applications
* **sops-nix** for encrypted secrets and runtime secret deployment
* **Restic** for local application backups, retention/pruning, integrity checks, Cloudflare R2 replication, and restore testing
* **Declarative monitoring** for storage, services, and system health
* **Automated configuration tests** plus NixOS VM validation

## Architecture

```text
                         Internet
                            │
                            ▼
                         Caddy
                    ┌───────┴────────┐
                    │                │
               Public TLS       Internal TLS
                    │                │
                    ▼                ▼
              Public services    LAN services
                    │                │
                    └───────┬────────┘
                            │
                       NixOS host
                            │
          ┌─────────────────┼──────────────────┐
          │                 │                  │
      Native services    PostgreSQL       systemd timers
          │                 │                  │
          └─────────────────┼──────────────────┘
                            │
                       Persistent data
                            │
              ┌─────────────┴─────────────┐
              │                           │
         RAID storage                Backup storage
              │                           │
              │                    Restic repository
              │                           │
              └───────────────────────────┘
```

Application services are managed as native NixOS services where practical. Persistent application state remains separate from the declarative configuration so that service upgrades and configuration rebuilds do not implicitly replace application data.

## Services

| Service     | Role                                   | Management |
| ----------- | -------------------------------------- | ---------- |
| Caddy       | Reverse proxy and TLS termination      | NixOS      |
| dnsmasq     | LAN DNS and DHCP                       | NixOS      |
| PostgreSQL  | Database backend                       | NixOS      |
| Nextcloud   | File synchronization and collaboration | NixOS      |
| Immich      | Photo and video management             | NixOS      |
| Jellyfin    | Media server                           | NixOS      |
| Sonarr      | TV library management                  | NixOS      |
| Radarr      | Movie library management               | NixOS      |
| Prowlarr    | Indexer management                     | NixOS      |
| qBittorrent | Download client                        | NixOS      |
| Seerr       | Media request management               | NixOS      |
| Minecraft   | Game server                            | NixOS      |
| Jenkins     | CI/CD server                           | NixOS      |
| Beszel      | Host monitoring                        | NixOS      |
| ntfy        | Notification service                   | NixOS      |
| Uptime Kuma | Service availability monitoring        | NixOS      |
| Homepage    | Service dashboard                      | NixOS      |
| Cockpit     | Host administration                    | NixOS      |

## Configuration structure

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   └── homelab/
│       ├── default.nix
│       ├── hardware-configuration.nix
│       └── users.nix
├── modules/
│   ├── backups.nix
│   ├── networking.nix
│   ├── storage.nix
│   ├── sops.nix
│   ├── monitoring.nix
│   ├── caddy.nix
│   ├── dnsmasq.nix
│   └── service modules...
├── scripts/
│   └── operational health and notification scripts
├── secrets/
│   └── homelab.yaml
├── tests/
│   └── declarative and VM-level validation
└── docs/
    ├── architecture.md
    ├── backup-and-restore.md
    ├── disaster-recovery.md
    └── roadmap.md
```

The configuration is organized around composable NixOS modules rather than a single monolithic host definition.

## Secrets

Secrets are stored in an encrypted SOPS file and rendered into the system at activation/runtime as required by individual services.

The repository contains encrypted secret material, not plaintext credentials.

Applications consume secrets through declarative NixOS configuration rather than checked-in `.env` files.

## Backup design

Application backups are implemented as declarative systemd + Restic jobs.

The backup system provides:

* application-specific backup scopes
* PostgreSQL dumps for database-backed applications
* consistent filesystem snapshots
* service stop/start handling where required
* sequential backup ordering
* retention and pruning
* repository integrity checks
* failure notifications through ntfy

The primary Restic repository is stored on dedicated local backup storage rather than the primary application volume. It is replicated to a separate Cloudflare R2 repository. A weekly scheduled restore test retrieves a representative snapshot from R2 and validates a restored file.

The remote repository has been checked and restored from manually, and the automated restore test has passed. The full recovery path still depends on secure off-host recovery of the SOPS age key and repository credentials. The current configuration also requires an explicit decision on independent R2 retention and recurring remote integrity checks.

Operational schedules and limitations are documented in [`docs/backup-and-restore.md`](docs/backup-and-restore.md). The full-host runbook is [`docs/disaster-recovery.md`](docs/disaster-recovery.md).

## Validation

Configuration changes are validated before activation:

```bash
nix flake check
sudo nixos-rebuild build --flake ~/Projects/homelab#homelab
```

The project contains declarative configuration assertions and NixOS VM tests for important invariants such as:

* enabled services
* service dependencies
* storage configuration
* DNS configuration
* secret wiring
* backup configuration
* monitoring
* removal of obsolete service definitions

The production configuration is then activated with:

```bash
sudo nixos-rebuild switch --flake ~/Projects/homelab#homelab
```

## Design principles

### Declarative infrastructure

Configuration belongs in Git wherever practical. The desired server state should be represented by Nix rather than by undocumented manual changes.

### Explicit dependencies

Systemd dependencies, persistent storage requirements, service ordering, backup ordering, and secret relationships are declared rather than inferred from startup timing.

### Recoverability

Backups are treated as an operational feature rather than an afterthought. Database dumps and application state are captured together where consistency requires it, and restore paths are tested against real Restic snapshots.

### Minimal privilege

Services use dedicated users where supported by their NixOS modules, while secrets and administrative operations remain restricted to the system components that require them.

### Test before activation

Configuration changes are validated with the Nix test suite and a build before being activated on the host.


## Roadmap

The v1.0 migration establishes the production baseline. Future development is focused on improving recovery, automation, observability, and infrastructure resilience.

| Version  | Focus                                                               | Status   |
| -------- | ------------------------------------------------------------------- | -------- |
| **v1.0.0** | Debian → NixOS migration, native services, sops-nix, Restic backups | Complete |
| **v1.1.0** | Off-site backups, automated restore testing, disaster recovery | Implementation delivered; readiness checks open |
| **v1.2.0** | CI, NixOS VM testing, deployment validation | Planned |
| **v1.3.0** | Backup observability, SMART monitoring, recovery alerting | Planned |
| **v2.0.0** | Second host, WireGuard, selective infrastructure redundancy | Future |

The v1.1.0 core implementation provides off-site replication, automated representative restore testing, and a disaster-recovery runbook. Release completion still requires verification of off-host age-key recovery, an explicit R2 retention/integrity policy, and a review or rehearsal of the documented recovery procedure.

See [`docs/roadmap.md`](docs/roadmap.md) for release acceptance criteria and planned engineering work.


## Documentation

* [Architecture](docs/architecture.md)
* [Backup and Restore](docs/backup-and-restore.md)
* [Disaster Recovery](docs/disaster-recovery.md)
* [Roadmap](docs/roadmap.md)

## License

This project is licensed under the [MIT License](LICENSE).
