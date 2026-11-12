# Inventory

Sanitised evidence collected on **2026-11-12** from the `c4-desktop` LXD container and
its KVM host. This is the primary evidence for the analysis in [`../docs/en/`](../docs/en/).

## Structure

```text
inventory/
├── container/
│   ├── 00-system.txt              OS, kernel, time, locale, machine-id hash (removed)
│   ├── 01-hardware.txt            CPU, memory, disk, mounts, DMI, devices
│   ├── 02-desktop.txt             processes, sessions, XRDP/XFCE packages
│   ├── 03-display.txt             xrandr, xdpyinfo, xinput, XRDP config
│   ├── 04-fonts-locale.txt        font count/families, fontconfig, locales
│   ├── 05-chrome.txt              Chrome package, version, policies, sandbox
│   ├── 05-launchers.md            launcher template and instances
│   ├── 06-chrome-profiles.txt     profile trees and sizes
│   ├── 06-profiles.md             profile summary and Local State
│   ├── 06b-chrome-profile-summary.json  parsed Preferences / Local State
│   ├── 08-proxy-services.txt      units, status, sanitised Xray/Hysteria configs
│   ├── 09-network.txt             addresses, routes, DNS, listeners, nftables
│   ├── 10-container-view.txt      cgroup, mounts, limits
│   ├── 11-software.txt            package inventory and apt sources
│   ├── 12-toolchain.txt           compilers, languages, build dependencies
│   ├── 13-docker.txt              Docker containers, images, networks
│   ├── 14-1panel.txt              1Panel presence check (absent)
│   ├── 15-autostart-cron-users.txt cron, units, users, sshd, fail2ban
│   ├── 16-security.txt            AppArmor, ufw, sysctl, ports, sudoers
│   ├── 17-fingerprint-surface.txt screen, DPI, timezone, locale, fonts, MAC
│   ├── 18-headless-probe.json     headless Chrome JS probe
│   ├── 18-headless-probe.err      headless Chrome stderr
│   ├── headful-probe.json         headful Chrome JS probe (real desktop)
│   ├── gpu-info.json              CDP SystemInfo / GPU feature status
│   └── proxy-latency.md           sanitised benchmark
└── host/
    ├── 00-system.txt              host OS, CPU, memory, disk, GPU
    ├── 01-lxd.txt                 containers, c4 config/devices, networks, storage
    ├── 02-network.txt             addresses, routes, DNS, listeners, nftables
    ├── 03-services.txt            services, versions, Docker, cron
    └── 04-ports.txt               LXD port mappings
```

## Redaction

| Removed / replaced | Placeholder |
|---|---|
| Public IPv4 | `203.0.113.10` or `198.51.100.99` |
| Public IPv6 | `2001:db8::99` |
| Proxy credentials / session IDs | `REDACTED` |
| VLESS UUID, REALITY keys, short IDs | `REDACTED` |
| Hysteria2 password / obfs key | `REDACTED` |
| MAC address | last three octets `xx:xx:xx` |
| `machine-id` / `boot-id` hash | `<removed>` |
| SSH password | never collected |

The real values are kept in a separate private archive, not in this repository.

## Evidence levels

- **Measured** — command output or browser probe.
- **Configured** — a configuration file or systemd unit.
- **Inferred** — analysis in the docs, not raw evidence.

## Reproducing

The collectors are in [`../scripts/`](../scripts/). They are read-only with respect to
system configuration and write to `/tmp`. See
[`../docs/en/10-collection-method.md`](../docs/en/10-collection-method.md).

## Caveats

- This is a point-in-time snapshot. Chrome, Docker images, and proxy sessions change.
- The headful probe used a temporary profile, not the real `chrome-*` profiles.
- No cookies, history, passwords, or local storage were collected.
- Journal lines that revealed browsing destinations were stripped from the proxy report.
- The host and container share a 22 GB filesystem; disk figures are coupled.
