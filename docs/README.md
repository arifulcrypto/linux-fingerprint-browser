# Documentation

English is the primary language. Chinese translations mirror the English structure.

| English | Chinese | Topic |
|---|---|---|
| [00-overview.md](en/00-overview.md) | [00-overview.md](zh-CN/00-overview.md) | Scope, method, key conclusions |
| [01-host-and-container.md](en/01-host-and-container.md) | [01-host-and-container.md](zh-CN/01-host-and-container.md) | Host, LXD, container, storage, ports |
| [02-desktop-stack.md](en/02-desktop-stack.md) | [02-desktop-stack.md](zh-CN/02-desktop-stack.md) | XRDP, Xorg, XFCE, display, fonts, locale |
| [03-browser-installation.md](en/03-browser-installation.md) | [03-browser-installation.md](zh-CN/03-browser-installation.md) | Chrome build, policies, launchers, flags |
| [04-chrome-profiles.md](en/04-chrome-profiles.md) | [04-chrome-profiles.md](zh-CN/04-chrome-profiles.md) | Profiles, state, extensions, `variations_country` |
| [05-proxy-and-network.md](en/05-proxy-and-network.md) | [05-proxy-and-network.md](zh-CN/05-proxy-and-network.md) | Proxy chains, nodes, DNS, leaks, latency |
| [06-fingerprint-surface.md](en/06-fingerprint-surface.md) | [06-fingerprint-surface.md](zh-CN/06-fingerprint-surface.md) | JS-visible signals, gaps, detectability |
| [07-build-toolchain.md](en/07-build-toolchain.md) | [07-build-toolchain.md](zh-CN/07-build-toolchain.md) | Toolchain gap, Chromium build options |
| [08-architecture.md](en/08-architecture.md) | [08-architecture.md](zh-CN/08-architecture.md) | Target design |
| [09-roadmap.md](en/09-roadmap.md) | [09-roadmap.md](zh-CN/09-roadmap.md) | Phased plan |
| [10-collection-method.md](en/10-collection-method.md) | [10-collection-method.md](zh-CN/10-collection-method.md) | Scripts, probes, redaction, limits |
| [11-ethics.md](en/11-ethics.md) | [11-ethics.md](zh-CN/11-ethics.md) | Acceptable use |

## Conventions

- Values are dated **2026-11-12** unless stated otherwise.
- `REDACTED`, `203.0.113.10`, `198.51.100.x`, and `2001:db8::` are placeholders.
- "Measured" means captured by a command or probe. "Inferred" means reasoned from
  measurements. "Planned" means a design decision for a later phase.
- Chrome and Chromium versions move; always record the exact version with a snapshot.
