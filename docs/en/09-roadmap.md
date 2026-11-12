# 09 — Roadmap

The roadmap is ordered by **risk reduction per unit of effort**. It deliberately delays
the Chromium fork until the profile contract and measurement harness are stable.

---

## Phase 0 — Inventory (complete)

**Goal:** know exactly what the current environment is.

Deliverables:

- read-only host and container collectors;
- sanitised inventory under `inventory/`;
- fingerprint probes (headful + headless);
- proxy and network map;
- this documentation.

Exit criteria:

- every claim about the environment has an evidence file or a reproducible command;
- no credential or public address is published;
- the snapshot is date- and version-stamped.

**Status:** complete on 2026-11-12.

---

## Phase 1 — Foundation (4–6 weeks)

**Goal:** make the measurements repeatable and the build path real.

Deliverables:

1. **Self-test harness** — a page + runner that captures the contract in
   `06-fingerprint-surface.md` and diffs it against a manifest.
2. **Profile schema v1** — JSON/YAML with seed, persona, network, automation, lifecycle.
3. **Network namespace prototype** — per-profile netns with a proxy, DNS, IPv6 off, and a
   kill switch.
4. **Build environment** — a separate builder with `depot_tools`, clang, ninja, ccache,
   ≥100 GB disk.
5. **CI** — redaction check (already), docs link check, schema validation, patch apply
   check.
6. **Baseline canary suite** — 10–20 public fingerprint/leak test pages, run headful.

Exit criteria:

- the self-test runs on the current VPS and produces a stable JSON report;
- a profile can be launched in a network namespace with no direct egress;
- a Chromium checkout configures (`gn gen`) on the builder;
- CI blocks a commit that leaks a UUID, key, or real IP.

**Risks:** namespace networking is fiddly; the VPS has no spare disk; the builder is a
new dependency.

---

## Phase 2 — MVP profile manager (6–8 weeks)

**Goal:** a usable product on **stock Chrome**, without a fork.

Deliverables:

1. **Profile service** — create, list, start, stop, delete, snapshot, restore.
2. **Runtime supervisor** — per-profile container or namespace, display, Chrome launch,
   resource limits, crash restart.
3. **Fingerprint bundle** — timezone, locale, `Accept-Language`, screen, fonts, WebGL
   flags (`--enable-unsafe-swiftshader --ignore-gpu-blocklist`).
4. **Network plane** — proxy per profile, remote DNS, IPv6 off, fail-closed, leak test.
5. **UI/API** — a minimal web UI and a REST API; API tokens; audit log.
6. **Self-test on launch** — block or warn on a failed check.
7. **Profile lifecycle** — ephemeral profiles, storage quotas, cache cleanup.

Exit criteria:

- 10 concurrent profiles on one host, each with a distinct exit and coherent
  timezone/locale;
- zero direct-egress leaks in the canary suite;
- a profile survives a host reboot and returns to the same state;
- a failed proxy blocks the profile (no direct fallback);
- an operator can create and launch a profile in under two minutes.

**Risks:** memory (3.8 GiB is tight), disk (2 GiB free), shared Docker stack. The MVP may
need a larger host or fewer concurrent profiles.

---

## Phase 3 — Chromium fork alpha (8–12 weeks)

**Goal:** control the signals that configuration cannot fix.

Deliverables:

1. **Pinned Chromium checkout** and a reproducible build.
2. **Patch set v1:**
   - UA-CH/platform coherence;
   - per-profile timezone/locale in the renderer;
   - WebGL/WebGPU vendor/renderer and parameter virtualisation;
   - deterministic canvas/audio noise;
   - font metric virtualisation (or a curated font set);
3. **Self-test integration** — every patch has a test and a diff.
4. **Packaging** — `.deb`/AppImage, versioning, signing, rollback.
5. **Patch rebase runbook** — how to move to the next Chromium milestone.

Exit criteria:

- the fork passes the same self-test as stock Chrome, plus the patched checks;
- WebGL is available and coherent with the claimed GPU;
- a Windows persona is either supported or explicitly out of scope;
- a Chromium milestone update can be rebased within the planned window.

**Risks:** patch maintenance, build time, binary size, codec/Widevine gaps, security
response.

---

## Phase 4 — Automation, AI/MCP, and collaboration (8–12 weeks)

**Goal:** make profiles programmable and shareable.

Deliverables:

1. **CDP gateway** with authentication, per-profile authorization, and audit.
2. **Playwright/Puppeteer integration** via `connectOverCDP`.
3. **MCP server** with profile/browser/fingerprint tools.
4. **Team features** — roles, sharing, quotas, activity log.
5. **Import/export** — encrypted profile bundles.
6. **Observability** — dashboards, alerts, self-test history.

Exit criteria:

- an automated session cannot override proxy/fingerprint flags;
- `navigator.webdriver` and automation artefacts match the profile policy;
- a team can share a profile without sharing credentials;
- every automated action is attributable.

**Risks:** automation detection, credential handling, multi-tenant isolation.

---

## Phase 5 — Production hardening (ongoing)

**Goal:** operate safely at scale.

Deliverables:

- sandboxed, non-root browser runtime;
- encrypted storage and key rotation;
- signed updates and rollback;
- host fleet management and scheduling;
- incident response and disclosure policy;
- Windows/WSL support if the market requires it;
- performance and density tuning;
- compliance review (privacy, export, provider terms).

Exit criteria:

- no shared secrets in process lists or logs;
- a compromised profile cannot reach another profile's data or network;
- a failed update rolls back automatically;
- a security review has signed off.

---

## Cross-cutting workstreams

| Workstream | When | Notes |
|---|---|---|
| Measurement / canary suite | Phase 1 onward | Grows with every patch |
| Security hardening | Phase 1 onward | Non-root, sandbox, secrets, audit |
| Documentation / i18n | Every phase | English first, Chinese mirror |
| Build/release engineering | Phase 1 onward | Separate from runtime |
| Proxy quality / cost | Phase 2 onward | Residential is metered; no auto-test loops |
| Legal / ToS review | Before launch | Fingerprint isolation is dual-use |

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Detection arms race | High | High | Coherence + measurement, not one-shot spoofing |
| Chromium patch maintenance | High | High | Small patches, tests, rebase budget |
| Proxy cost / quality | Medium | High | Session benchmarking, quotas, provider diversification |
| Disk exhaustion | High | High | Separate browser host, quotas, cleanup |
| Memory pressure | High | Medium | Fewer profiles per host, limits, monitoring |
| Credential leak | Medium | High | Secret manager, redaction CI, least privilege |
| Legal/ToS challenge | Medium | High | Clear acceptable-use policy, counsel review |
| Single VPS failure | Medium | High | Control plane separate, backups, placement |
| Windows persona gap | High | Medium | Native Linux first; VM/fork later |

---

## KPIs

- profile launch success rate;
- self-test pass rate by check;
- leak incidents per 1,000 launches (target: 0);
- canary detection rate (internal, not a guarantee);
- median launch time;
- Chrome crash rate per version;
- build cadence and rebase time;
- cost per active profile per month.

---

## Immediate next actions

1. Add the self-test harness to this repository.
2. Provision a builder with ≥100 GB disk.
3. Prototype one network namespace with a proxy and a kill switch.
4. Decide the first persona tier (native Linux recommended).
5. Keep the current VPS as the measurement host; do not build on it.
