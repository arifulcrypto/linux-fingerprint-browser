# Security policy

## Public repository, redacted data

This repository documents a live environment. The following classes of data are removed
before publication:

| Class | Handling |
|---|---|
| Passwords, proxy credentials, API signatures | Removed; replaced with `REDACTED` |
| VLESS UUID, REALITY keys, short IDs | Removed |
| Hysteria2 password, obfs password, TLS private key | Removed |
| SSH passwords and private keys | Never collected into the repository |
| Session IDs and provider account identifiers | Removed |
| Public IP addresses | Replaced with documentation ranges |
| MAC addresses | Last three octets masked |
| `machine-id`, `boot-id` hashes | Removed |
| Cookies, tokens, browsing history | Not collected |

The `scripts/check-redaction.sh` guard runs in CI and fails on UUIDs, PEM private keys,
common token prefixes, real-looking proxy URIs, and non-placeholder secrets.

## Reporting a leak

If you find a credential or identifying value in this repository, open a private security
advisory or contact the maintainer directly. Do not open a public issue containing the
value.

## Collection scripts

`collect-container.sh` and `collect-host.sh` are **read-only** with respect to system
configuration. They write reports under `/tmp` and produce a tarball. They do not change
services, firewall rules, proxy configuration, Chrome profiles, or user data.

Some reports intentionally include sanitised configuration excerpts. Review the output
before publishing it; the scripts redact known secret fields, but new services may add
fields the scripts do not know about.

## Operational security notes from the inventory

- Chrome runs as `root` with `--no-sandbox`; this is a container-wide risk.
- SSH permits root login and password authentication.
- `ufw` is inactive; host exposure is controlled by LXD proxy devices and upstream firewall.
- `kernel.dmesg_restrict=0` and `kptr_restrict=1`; consider hardening the host.
- The container shares the host's 22 GB filesystem and is 91% full.

These are observations, not recommendations to change the live service. Any hardening
should be planned and tested separately.
