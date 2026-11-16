# Dynamic DNS

The homelab uses Namecheap Dynamic DNS with NixOS `services.ddclient` to keep public IPv4 A records synchronized with the residential WAN address.

The updater runs on the homelab host every five minutes. It discovers the current public IPv4 address through IPify and sends updates to Namecheap's Dynamic DNS endpoint over HTTPS.

## Managed records

The updater manages these host labels in the `alexpaquette.dev` DNS zone:

| Host label | Fully qualified name |
|---|---|
| `cloud` | `cloud.alexpaquette.dev` |
| `jellyfin` | `jellyfin.alexpaquette.dev` |
| `seerr` | `seerr.alexpaquette.dev` |
| `immich` | `immich.alexpaquette.dev` |
| `ntfy` | `ntfy.alexpaquette.dev` |

The module intentionally configures IPv4 only. It does not manage AAAA records.

## Namecheap prerequisites

1. Confirm that `alexpaquette.dev` uses Namecheap BasicDNS, PremiumDNS, or FreeDNS. Namecheap Dynamic DNS will not update records served by another authoritative DNS provider.
2. In Namecheap Advanced DNS, enable **Dynamic DNS** for the domain.
3. Generate or copy the domain's dedicated Dynamic DNS password. This is not the Namecheap account password and is not a general Namecheap API token.
4. Ensure each managed host label is configured as an **A + Dynamic DNS Record** in Namecheap Advanced DNS. The module supplies the host labels; the apex domain is supplied as the ddclient login.

Namecheap's endpoint is `dynamicdns.park-your-domain.com`.

## Secret management

The password is declared in `modules/sops.nix` under the SOPS key:

```yaml
namecheap:
  ddns_password: <encrypted by sops>
```

Add the actual Namecheap Dynamic DNS password locally using the repository's SOPS configuration:

```sh
sops secrets/homelab.yaml
```

In the editor, add or update the `namecheap.ddns_password` value. Save and exit; SOPS encrypts the value before writing the file. Do not put the plaintext password in Nix, shell history, commit messages, or unencrypted files.

The decrypted runtime secret is owned by `root:ddclient-secrets` with mode `0440`. The NixOS ddclient service uses `DynamicUser` and is granted membership in that group. The secret is not world-readable.

## Validation and operation

Before activation:

```sh
nix flake check
nix build .#nixosConfigurations.homelab.config.system.build.toplevel
```

After activating the configuration, inspect the timer and service:

```sh
systemctl status ddclient.timer
systemctl list-timers ddclient.timer
sudo systemctl start ddclient.service
sudo journalctl -u ddclient.service -n 100 --no-pager
```

Check the public DNS answers:

```sh
dig +short A cloud.alexpaquette.dev
dig +short A jellyfin.alexpaquette.dev
dig +short A seerr.alexpaquette.dev
dig +short A immich.alexpaquette.dev
dig +short A ntfy.alexpaquette.dev
```

The records should converge on the current public IPv4 address. DNS caching and TTLs can delay when external resolvers observe an update.

The updater does not modify the local `dnsmasq` overrides. LAN clients should continue resolving the service hostnames to the homelab's private address.

## Troubleshooting

- Check `systemctl status ddclient.service` and `journalctl -u ddclient.service` for Namecheap response errors.
- Confirm the domain still uses Namecheap DNS and Dynamic DNS remains enabled.
- Confirm all five host labels exist as Dynamic DNS A records.
- Confirm the SOPS key is present in `secrets/homelab.yaml` and the runtime secret exists at `/run/secrets/namecheap-ddns-password`.
- Do not print the secret or paste it into logs when troubleshooting.
