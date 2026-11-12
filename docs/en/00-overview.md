# 00 — Overview

**Snapshot:** 2026-11-12
**Target:** `c4-desktop` LXD container, KVM host, Tokyo datacenter
**Purpose:** establish the factual baseline for a Linux fingerprint browser

---

## 1. What this phase is — and is not

This phase collects information. It does not design the final product, choose a Chromium
fork strategy, or change the running environment. The collectors are read-only with
respect to system configuration; they write reports under `/tmp` and copy them out.

The output is deliberately boring: versions, paths, ports, flags, profile state, and
measured browser signals. That is the point. Fingerprint work fails when it starts from
assumptions about the environment.

---

## 2. Questions this inventory answers

1. What hardware and kernel does the browser actually see, and what is virtualised?
2. Which desktop stack renders the browser, at what geometry and DPI?
3. Which Chrome build is installed, how is it launched, and which policies apply?
4. What state exists in each Chrome profile, and what does it reveal about past proxies?
5. Where does traffic go — process by process, port by port — and where can it leak?
6. Which JavaScript-visible signals are exposed, and which are internally inconsistent?
7. What is missing to build or automate a Chromium-based product on this machine?

---

## 3. Environment in one table

| Item | Value |
|---|---|
| Host OS | Ubuntu 20.04.6 LTS (Focal), kernel `5.4.0-216-generic` |
| Host virtualisation | KVM, QEMU Standard PC (i440FX), SeaBIOS 1.16.3 |
| Host CPU | 2 vCPU, AMD EPYC-Rome, 2.3 GHz base, AVX2 |
| Host memory | 3.8 GiB RAM + 4 GiB swap |
| Host disk | 22 GB ext4, 91% used, ~2.1 GiB free |
| LXD | 5.21.9 LTS, `dir` storage pool, 4 containers (`c1-proxy`, `c2-app`, `c3-backup`, `c4-desktop`) |
| Container OS | Ubuntu 22.04.5 LTS (Jammy), LXC, minimal image `20261028` |
| Container limits | 2 vCPU, 4096 MB memory, `security.nesting=true` |
| Container disk | Declared 10 GB root device; reports the host's 22 GB ext4 at 91% |
| Container GPU | **none** — `/dev/dri` absent, while the host has `/dev/dri/card0` |
| Desktop | XFCE 4.16, Xorg 1.21.1.4, xorgxrdp 0.2.17, XRDP 0.9.17, display `:10` |
| Browser | Google Chrome `156.0.8078.79-1` (stable, amd64) |
| Profiles | 5 directories, 20 MB – 313 MB each |
| Fonts | 166 files, 46 families |
| Locale / timezone | `en_US.UTF-8` only / `Etc/UTC` |
| Toolchain | gcc 11.4, g++ 11.4, make 4.3, Python 3.10, git 2.34, Docker 29.9.3 |
| Missing toolchain | clang, cmake, ninja, node, npm, rust, go, java, chromedriver |

---

## 4. The five conclusions that matter

### 4.1 The browser is visually software-rendered and WebGL is absent

`SystemInfo.getInfo` from a real headful Chrome on `:10` reports:

```text
gpu.devices[0].deviceString = ANGLE (Mesa, llvmpipe (LLVM 15.0.7 256 bits), OpenGL 4.5 ...)
featureStatus.webgl        = disabled_off
featureStatus.webgpu       = disabled_off
featureStatus.gpu_compositing = disabled_software
featureStatus.2d_canvas    = disabled_software
```

The page-level probe returns `webglVendor: null`, `webglRenderer: null`. Chrome logs
`WebGL1 blocklisted` and `WebGL2 blocklisted`. With
`--enable-unsafe-swiftshader --ignore-gpu-blocklist`, WebGL becomes available again as
`ANGLE (Mesa, llvmpipe ...)`. Headless Chrome, by contrast, reports
`ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device ...), SwiftShader driver)`.

This is the single largest gap between the current box and a believable desktop profile.

### 4.2 Network identity and browser identity disagree

The residential exit is Turkish, but the browser reports `UTC` and `en-US`, and the
system has no Turkish locale installed. A site that compares IP geolocation, timezone,
`Intl` locale, and `Accept-Language` sees a contradiction.

### 4.3 The profiles remember previous countries

`Local State` contains `variations_country`:

| Profile | `variations_country` |
|---|---|
| `google-chrome` | `jp` |
| `chrome-residential` | `ph` |
| `chrome-tr-proxy` | `tr` |
| `chrome-us-proxy` | `cn` |
| `google-chrome-headless` | absent |

The value is not exposed to JavaScript, but it is a persistent artefact of where the
profile was first used. It affects Chrome's feature variations and is a consistency
signal when profiles are cloned, restored, or moved between proxies.

### 4.4 Isolation is per-process, not per-environment

Each profile has its own `--user-data-dir`, which isolates cookies, cache, and storage.
But all profiles share:

- the same Linux user (`root`) and the same X11 display (`:10`);
- the same X clipboard and window manager;
- the same font set, CPU count, memory, timezone, and locale;
- the same Chrome binary and crashpad handler;
- the same desktop geometry.

A site cannot read another profile's cookies, but the OS-level fingerprint is identical.
For a product, "profile" must eventually mean a separate environment, not just a
separate directory.

### 4.5 This machine cannot build Chromium

Chromium's build needs clang, a recent toolchain, ~100 GB of free disk, and 16 GB+ RAM.
This container has gcc only, no clang/cmake/ninja/Node, 2.1 GiB free, and 3.8 GiB RAM.
Builds belong on GitHub Actions, a dedicated builder, or a WSL2 machine — not here.

---

## 5. Evidence levels

| Level | Meaning | Example |
|---|---|---|
| Measured | Captured by a command or probe during this snapshot | `navigator.hardwareConcurrency = 2` |
| Configured | Read from a configuration file or unit | `WebRtcIPHandlingPolicy = disable_non_proxied_udp` |
| Inferred | Reasoned from measurements, not directly observed | "WebGL absence is highly detectable" |
| Planned | A design decision for later phases | "Use a deterministic profile seed" |

The inventory files under [`../../inventory/`](../../inventory/) are the primary evidence.
This document summarises; it does not replace them.

---

## 6. How the rest of the documentation is organised

| Document | Topic |
|---|---|
| `01-host-and-container.md` | Host, LXD, container limits, storage, port mappings |
| `02-desktop-stack.md` | XRDP, Xorg, XFCE, display, input, fonts, locale |
| `03-browser-installation.md` | Chrome package, binary, policies, launchers, flags |
| `04-chrome-profiles.md` | Profile sizes, state, extensions, `variations_country` |
| `05-proxy-and-network.md` | Proxy chains, public nodes, DNS, leak controls, latency |
| `06-fingerprint-surface.md` | JS-visible signals, headful vs headless, gap analysis |
| `07-build-toolchain.md` | What is installed, what is missing, build options |
| `08-architecture.md` | Target design for the fingerprint browser |
| `09-roadmap.md` | Phased plan from inventory to Chromium fork |
| `10-collection-method.md` | Scripts, commands, reproducibility, redaction |
| `11-ethics.md` | Intended use and boundaries |

---

## 7. What to do next

1. Keep this snapshot immutable; date-stamp any new capture.
2. Add automated coherence checks before adding more profiles.
3. Move the build off this VPS.
4. Decide whether the first product iteration uses stock Chrome plus a supervisor, or
   waits for the Chromium fork. The evidence says stock Chrome can cover network and
   profile isolation, but **not** WebGL, timezone coherence, or font coherence without
   patches or a GPU.
