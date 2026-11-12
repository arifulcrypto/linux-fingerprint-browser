# 03 — Browser Installation and Launchers

This document covers the Chrome build, its installation layout, policies, the launcher
scripts, and the exact flags that shape the browser's behaviour and fingerprint.

---

## 1. Installed browser

| Property | Value |
|---|---|
| Package | `google-chrome-stable 156.0.8078.79-1` (amd64) |
| Binary | `/opt/google/chrome/chrome` (302,792,008 bytes) |
| Wrapper | `/usr/bin/google-chrome`, `/usr/bin/google-chrome-stable` |
| Version | `Google Chrome 156.0.8078.79` |
| Channel | stable |
| Install date | 2026-10-28 (binary timestamp), package installed 2026-10-31 |
| `chrome-sandbox` | setuid root, mode `4755` |
| Crash handler | `chrome_crashpad_handler` |
| Management service | `chrome-management-service` present |
| `chromedriver` | **not installed** |
| Remote debugging | **not enabled** in any launcher |

No Chromium, no Edge, no Firefox. Chrome is the only browser.

### Why this matters

- Google Chrome includes proprietary codecs and Google branding that Chromium does not.
  A future fork based on Chromium will change the UA, codec support, and some feature
  behaviour unless those are patched back.
- The version is recent (156) and will move. Every fingerprint snapshot must record the
  exact version; a Chrome update can change UA-CH, feature flags, and canvas/WebGL
  behaviour.
- The setuid sandbox is installed but unused because every launcher passes
  `--no-sandbox`. The sandbox is therefore not a security boundary in practice.

---

## 2. Policies

Only one managed policy exists:

```json
// /etc/opt/chrome/policies/managed/webrtc_policy.json
{
  "WebRtcIPHandlingPolicy": "disable_non_proxied_udp"
}
```

This forces WebRTC to use only proxied UDP and prevents direct host-candidate leaks.
It is a good baseline. There is no policy for:

- URL allow/block lists;
- extension force-install or blocklist;
- `UserDataDir`;
- `ProxySettings` (proxy is passed on the command line instead);
- `DeveloperToolsAvailability`;
- `BrowserSignin`, sync, or metrics.

A production deployment should manage these centrally rather than relying on shell
scripts. Chrome policies are harder for a user to override and are visible in
`chrome://policy`.

---

## 3. Launchers

There are three shell launchers on the desktop, one per proxy profile, plus desktop
shortcuts. All follow the same template.

| Launcher | Profile | Proxy | CSS class | Start URLs |
|---|---|---|---|---|
| `start_us_proxy_chrome.sh` | `~/.config/chrome-us-proxy` | `http://127.0.0.1:2080` | `us-proxy-chrome` | `ipinfo.io`, `claude.ai` |
| `start_residential_chrome.sh` | `~/.config/chrome-residential` | `http://127.0.0.1:18080` | `residential-proxy-chrome` | `ipinfo.io`, `ippure.com` |
| `start_tr_proxy_chrome.sh` | `~/.config/chrome-tr-proxy` | `http://127.0.0.1:18081` | `tr-proxy-chrome` | `ipinfo.io`, `ippure.com` |

The default `google-chrome` profile (`~/.config/google-chrome`) has no dedicated launcher
and is used for ad-hoc browsing.

### Common flags

```bash
google-chrome-stable \
  --no-sandbox \
  --disable-dev-shm-usage \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir="$USER_DATA_DIR" \
  --class="$CLASS" \
  --lang=en-US \
  --proxy-server="http://127.0.0.1:<port>" \
  --proxy-bypass-list="127.0.0.1,localhost" \
  --disable-quic \
  --webrtc-ip-handling-policy=disable_non_proxied_udp \
  --enforce-webrtc-ip-permission-check \
  --disable-features=DnsOverHttps \
  "$@"
```

| Flag | Effect | Fingerprint / security note |
|---|---|---|
| `--no-sandbox` | Disables the Chromium sandbox | Security risk; `SystemInfo` reports `sandboxed: false` |
| `--disable-dev-shm-usage` | Uses `/tmp` instead of `/dev/shm` | Not a fingerprint signal; `/dev/shm` is 1.9 GiB here, so the flag is unnecessary |
| `--no-first-run` | Skips onboarding | Keeps profiles clean |
| `--no-default-browser-check` | Skips default-browser prompt | Cosmetic |
| `--user-data-dir` | Isolates profile state | The main isolation mechanism today |
| `--class` | Sets the X11 WM class | Visible to the window manager, not to websites |
| `--lang=en-US` | UI and `navigator.language` default | Conflicts with non-English proxy geography |
| `--proxy-server` | Routes HTTP(S) through a local bridge | Does not cover DNS, IPv6, or non-HTTP protocols by itself |
| `--proxy-bypass-list` | Bypasses proxy for localhost only | Correct for local bridges; keep it minimal |
| `--disable-quic` | Prevents QUIC/UDP bypass | Essential with an HTTP proxy that cannot carry UDP |
| `--webrtc-ip-handling-policy` | Restricts WebRTC to proxied UDP | Matches the managed policy |
| `--enforce-webrtc-ip-permission-check` | Requires permission for WebRTC IP exposure | Extra hardening |
| `--disable-features=DnsOverHttps` | Disables Chrome's DoH | Forces system DNS, which is **not** per-profile |

### Comment vs reality

`start_tr_proxy_chrome.sh` says "tr-TR UI" in its header comment, but the actual flag is
`--lang=en-US` and the environment is `LANG=en_US.UTF-8`. The TR profile therefore runs
an English UI and English `navigator.languages` while exiting through Turkey. This is a
documentation bug and a fingerprint mismatch.

### Missing flags

The current launchers do **not** set:

- `--disable-blink-features=AutomationControlled` (relevant only if automation is added);
- `--force-device-scale-factor` (DPR is fixed at 1 by the 96 DPI display);
- `--window-size` / `--window-position` (geometry is inherited from the session);
- `--user-agent` (UA is the real Chrome UA, which is good);
- `--accept-lang` (languages are inherited from the system);
- `--host-resolver-rules` (no per-profile DNS mapping);
- `--disable-ipv6` (IPv6 default route remains);
- any timezone override (Chrome has no such flag).

---

## 4. Process and privilege model

All Chrome processes run as `root`:

```text
root  /opt/google/chrome/chrome --no-sandbox ... --user-data-dir=/root/.config/chrome-us-proxy
root  /opt/google/chrome/chrome --type=zygote --no-zygote-sandbox --no-sandbox ...
root  /opt/google/chrome/chrome --type=gpu-process ... --no-sandbox ...
root  /opt/google/chrome/chrome --type=renderer ... --no-sandbox ...
```

Consequences:

- A renderer compromise is a root compromise of the container.
- Crashpad uses `/root/.config/google-chrome/Crash Reports` even for non-default profiles,
  so crash metadata is shared across profiles.
- The GPU process runs unsandboxed (`sandboxed: false` in `SystemInfo`).
- File permissions on profile directories are inconsistent: `google-chrome` is `0700`,
  while `chrome-*` profiles are `0755`. Any local user could read the latter.

This is acceptable for a single-tenant research VPS, but not for a product that hosts
untrusted profiles or multiple customers.

---

## 5. Headful vs headless

Two probes were captured:

| Signal | Headful (`:10`, XRDP) | Headless (`--headless=new`) |
|---|---|---|
| User-Agent | `Chrome/156.0.0.0` | `HeadlessChrome/156.0.0.0` |
| Screen | `1280×720`, avail `1280×693` | `800×600` |
| Window | outer `1279×719`, inner `1271×572` | viewport `800×600` |
| WebGL | **disabled / null** | SwiftShader via ANGLE |
| `webdriver` | `false` | `false` |
| Timezone | `UTC` | `UTC` |
| Languages | `en-US,en` | `en-US,en` |
| Media devices | none | none |

The headful probe was launched with a temporary profile and a local CDP port solely for
measurement. It did not modify the existing profiles. The headless probe used
`--disable-gpu`, which is why it fell back to SwiftShader rather than reproducing the
headful blocklist.

**Do not use headless results as a proxy for the real desktop.** The UA, screen, and WebGL
values differ. Any fingerprint test must state which mode it measured.

---

## 6. What the browser does not have

| Missing capability | Impact |
|---|---|
| `chromedriver` | No Selenium/Playwright automation out of the box |
| CDP port | No external automation or inspection |
| Per-profile timezone | All profiles share `UTC` |
| Per-profile locale | All profiles share `en-US` |
| Per-profile fonts | All profiles share 46 families |
| Per-profile display | All profiles share `:10` at 1280×720 |
| WebGL | Headful contexts are `null` |
| GPU | Software rendering only |
| Sandbox | Disabled at launch |
| Central policy | Only WebRTC is managed |

These are the concrete inputs to the architecture and roadmap documents.

---

## 7. Evidence

- [`../../inventory/container/05-chrome.txt`](../../inventory/container/05-chrome.txt)
- [`../../inventory/container/05-launchers.md`](../../inventory/container/05-launchers.md)
- [`../../inventory/container/06-profiles.md`](../../inventory/container/06-profiles.md)
- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
- [`../../inventory/container/gpu-info.json`](../../inventory/container/gpu-info.json)
- [`../../inventory/container/18-headless-probe.json`](../../inventory/container/18-headless-probe.json)
- [`../../configs/chrome/`](../../configs/chrome/)
