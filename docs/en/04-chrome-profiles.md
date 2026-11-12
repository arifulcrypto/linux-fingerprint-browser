# 04 — Chrome Profiles

Chrome profile isolation is the strongest part of the current setup, and also the source
of the most interesting consistency artefacts. This document inventories the five
profiles, their state, their extensions, and what they reveal about past network paths.

---

## 1. Inventory

| Profile directory | Size | Purpose | Proxy | `variations_country` | Extensions | Mode |
|---|---:|---|---|---|---:|---|
| `~/.config/google-chrome` | 177 MB | default / ad-hoc | none | `jp` | 5 | `0700` |
| `~/.config/chrome-residential` | 20 MB | PH rotating residential | `127.0.0.1:18080` | `ph` | 5 | `0755` |
| `~/.config/chrome-tr-proxy` | 175 MB | TR sticky residential | `127.0.0.1:18081` | `tr` | 6 | `0755` |
| `~/.config/chrome-us-proxy` | 313 MB | US VLESS line | `127.0.0.1:2080` | `cn` | 6 | `0755` |
| `~/.config/google-chrome-headless` | 4 KB | headless probe only | none | absent | 0 | `0700` |

All profiles use the same Chrome binary, the same Linux user, and the same display.

### Size observations

- `chrome-us-proxy` is the largest (313 MB) and is the profile that has been used for
  `claude.ai` and daily browsing. Cache and service-worker storage dominate.
- `chrome-tr-proxy` (175 MB) and `google-chrome` (177 MB) are similar in size.
- `chrome-residential` is only 20 MB, suggesting light use.
- The headless profile is empty except for the directory itself.

Profile size is operationally relevant: the container has ~2 GiB free, and Chrome does not
shrink `Default/` automatically. A profile lifecycle policy (ephemeral profiles, cache
caps, periodic compaction) is required.

---

## 2. Profile preferences

Each profile has `Default/Preferences` and a top-level `Local State`. The inspected values:

| Key | Value | Note |
|---|---|---|
| `profile.name` | `Your Chrome` | Default name in all profiles |
| `profile.avatar_index` | `26` | Same avatar in all profiles |
| `profile.exit_type` | `Normal` | Clean shutdown |
| `profile.default_content_setting_values` | `{has_migrated_local_network_access: true}` | No explicit camera/mic/geolocation policy |
| `profile.content_settings.exceptions` | 50+ keys | Mostly defaults and metadata, not user grants |
| `intl.accept_languages` | absent | Falls back to system locale |
| `intl.charset_default` | absent | Default |
| `browser.last_clear_browsing_data_time` | absent | Never cleared via UI |
| `browser.has_seen_welcome_page` | absent/false | First-run state not completed |
| `download.default_directory` | absent | Default `~/Downloads` |
| `signin.allowed` | `true` | Google sign-in permitted |
| `sync.requested` | absent | Sync not configured |
| `hardware_acceleration_mode` | absent | Default (enabled), but GPU is software |
| `media.autoplay_policy` | absent | Default |

The profiles are essentially factory-default Chrome with cookies/history accumulated.
There is no deliberate fingerprint configuration in `Preferences`.

### Content settings

The `content_settings.exceptions` object contains dozens of keys, but they are Chrome's
internal metadata (e.g., `cookies`, `geolocation`, `notifications`, `clipboard`,
`file_system_*`, `fedcm_*`, `automatic_downloads`). The inventory did not find explicit
user grants for camera, microphone, or geolocation. The headful probe confirms:

```text
Notification.permission = "default"
navigator.mediaDevices.enumerateDevices() = []
```

No camera, no microphone, no speakers. A profile claiming to be a real desktop with media
devices would contradict this.

---

## 3. `variations_country` — the country memory

`Local State` contains:

```json
"variations_country": "tr",
"variations_permanent_consistency_country": ["156.0.8078.79", "tr"]
```

Per profile:

| Profile | `variations_country` | Plausible origin |
|---|---|---|
| `google-chrome` | `jp` | Host/default browsing in Japan |
| `chrome-residential` | `ph` | PH residential exit at profile creation |
| `chrome-tr-proxy` | `tr` | TR residential exit |
| `chrome-us-proxy` | `cn` | A China exit at some point, despite the US proxy name |
| `google-chrome-headless` | absent | Never ran a variations seed fetch |

### What it is

Chrome's variations service assigns a country based on the network location when the
seed is fetched. The value is stored locally and used to select field trials. It is **not
exposed to JavaScript** and cannot be read by a website directly.

### Why it still matters

- It is a persistent trace of where the profile has been. Cloning a profile to a new
  proxy carries the old country with it.
- It changes feature rollout: a profile with `cn` may receive different experiments than
  one with `tr`, which can subtly change behaviour.
- It is a consistency signal for QA: if a profile is supposed to be Turkish, a `cn` or
  `jp` value indicates the profile was not created in the intended environment.
- It is a reminder that "fingerprint" is not only what JavaScript can read. Server-side
  state, local state, and feature flags all contribute to a profile's observable behaviour.

A profile provisioning pipeline should create a fresh `Local State` in the target
environment, or explicitly normalise this field, rather than copying it from a template.

---

## 4. Extensions

All installed extensions are component or external-component extensions shipped with
Chrome. There are no third-party extensions, no ad blockers, no automation extensions.

| Extension | Version | Profiles | Type |
|---|---|---|---|
| Chrome PDF Viewer | 1 | all | component |
| Chrome Web Store Payments | 1.0.0.6 | all | external component |
| Google Docs Offline | 1.111.1 | all | component/external |
| Google Hangouts | 1.3.26 / 1.4.5 | all | component |
| Google Network Speech | 1.0 | all | component |
| Gemini in Chrome | 1.2 | TR and US profiles | component |

The presence of `Gemini in Chrome` only in the newer profiles is a version/feature rollout
difference, not a user install. It is another reason two profiles can behave differently
even with identical flags.

`chrome://extensions` would show these as built-in. A website can detect some extension
artefacts (e.g., `chrome.runtime` exists in all Chrome pages), but the component set is
standard.

---

## 5. Isolation matrix

| Resource | Isolated per profile? | Evidence |
|---|---|---|
| Cookies / localStorage / IndexedDB | Yes | Separate `--user-data-dir` |
| Cache / service workers | Yes | Separate profile directories |
| History / downloads | Yes | Separate `Default/` |
| Extensions | Yes | Separate `Extensions` state |
| Proxy | Yes | Different `--proxy-server` per launcher |
| Crash reports | **No** | Crashpad uses `/root/.config/google-chrome/Crash Reports` |
| X11 display / clipboard | **No** | All windows on `:10` |
| Fonts / fontconfig | **No** | System-wide |
| Timezone / locale | **No** | System-wide |
| CPU / memory signals | **No** | Same cgroup limits |
| Screen geometry | **No** | Same XRDP session |
| Linux user / process boundary | **No** | All run as `root` |
| Chrome binary / version | **No** | One installation |

The right-hand column is the product gap. `--user-data-dir` solves the storage problem;
it does not solve the environment problem.

---

## 6. Profile lifecycle risks

1. **Copying a profile copies its history.** Cookies, local storage, service workers,
   and `Local State` all move together. A "fresh" profile must be created, not cloned.
2. **Copying a profile copies its country.** See `variations_country`.
3. **Copying a profile copies its permissions.** Camera/mic/geolocation grants, if any,
   move with it. The current profiles have none, but future ones might.
4. **Chrome version upgrades mutate profiles.** A profile created on 156 may be migrated
   on first launch of 157. Snapshot tests should pin the version and detect migrations.
5. **Disk growth is unbounded.** Cache, GPUCache, Code Cache, and service workers grow
   until trimmed. A profile quota and a cleanup policy are needed.
6. **Crashpad is shared.** A crash in one profile writes to the default profile's crash
   directory. That is both a privacy and a stability concern.

---

## 7. What a profile should contain (design input)

Based on the gaps above, a profile record should eventually include:

- a stable seed for deterministic fingerprint generation;
- proxy configuration and expected exit metadata (country, ASN, timezone, languages);
- timezone, locale, `Accept-Language`, and geolocation bundle;
- screen/window geometry and DPI;
- font set and font-metric profile;
- WebGL/WebGPU vendor and renderer strings, and the rendering backend;
- media device inventory;
- automation policy (CDP enabled/disabled, allowed origins);
- storage quota and lifecycle policy;
- a coherence manifest that can be validated before launch.

The current profiles have only the first two (implicitly) and none of the rest.

---

## 8. Evidence

- [`../../inventory/container/06-profiles.md`](../../inventory/container/06-profiles.md)
- [`../../inventory/container/06b-chrome-profile-summary.json`](../../inventory/container/06b-chrome-profile-summary.json)
- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
