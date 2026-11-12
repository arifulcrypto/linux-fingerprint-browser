# English documentation

Primary language. Start with the overview, then follow the topic that matches your task.

| # | Document | Read it for |
|---|---|---|
| 00 | [Overview](00-overview.md) | The five conclusions and how the docs fit together |
| 01 | [Host and container](01-host-and-container.md) | KVM, LXD, limits, disk, port mappings |
| 02 | [Desktop stack](02-desktop-stack.md) | XRDP, Xorg, XFCE, display, fonts, locale |
| 03 | [Browser installation](03-browser-installation.md) | Chrome build, policies, launchers, flags |
| 04 | [Chrome profiles](04-chrome-profiles.md) | Profile state, extensions, `variations_country` |
| 05 | [Proxy and network](05-proxy-and-network.md) | Proxy chains, nodes, DNS, IPv6, latency |
| 06 | [Fingerprint surface](06-fingerprint-surface.md) | What Chrome exposes and where it breaks |
| 07 | [Build toolchain](07-build-toolchain.md) | Why this VPS cannot build Chromium |
| 08 | [Architecture](08-architecture.md) | Target design for the product |
| 09 | [Roadmap](09-roadmap.md) | Phases, deliverables, exit criteria |
| 10 | [Collection method](10-collection-method.md) | Scripts, probes, redaction, limitations |
| 11 | [Ethics](11-ethics.md) | Intended and prohibited uses |

## Evidence

The analysis is backed by sanitised raw output in [`../../inventory/`](../../inventory/):

- [`container/`](../../inventory/container/) — system, hardware, desktop, display, fonts,
  Chrome, profiles, proxies, network, Docker, security, fingerprint probes.
- [`host/`](../../inventory/host/) — host system, LXD, network, services, port mappings.

## Snapshot

- Date: 2026-11-12
- Chrome: 156.0.8078.79
- Container: Ubuntu 22.04.5 LTS, 2 vCPU, 4 GiB limit, no GPU
- Display: 1280×720 @ 96 DPI, XRDP `:10`
- Locale/timezone: `en_US.UTF-8` / `UTC`
