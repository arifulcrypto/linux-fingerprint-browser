# 06 — Fingerprint Surface

This document records what the browser actually exposes, compares headful and headless
modes, and identifies the gaps that matter for a fingerprint browser.

All values were captured on 2026-11-12 from Chrome 156.0.8078.79. "Detectability" ratings
are **inferred** from how unusual the value is; they are not the result of running a
commercial anti-bot vendor.

---

## 1. Probe method

Two probes were used:

1. **Headful** — a temporary Chrome profile launched on display `:10` with
   `--remote-debugging-port=9222` and `--remote-allow-origins=*`, navigating to a local
   `file://` page. The page computed a JSON object (UA, UA-CH, screen, WebGL, fonts,
   media devices, audio, storage, `Intl`, and more) and exposed it as `window.__fp`. A
   small CDP client read the value. The existing profiles were not modified.
2. **Headless** — `google-chrome --headless=new --no-sandbox --disable-gpu
   --disable-dev-shm-usage --dump-dom file:///tmp/fp-probe.html`, with a throwaway
   profile.

The headful probe is the reference for the real desktop. Headless results are included
only to show how much the mode changes the fingerprint.

---

## 2. Headful values

### 2.1 User agent and client hints

```text
navigator.userAgent =
  Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
  (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36

navigator.platform = Linux x86_64
navigator.vendor   = Google Inc.
navigator.product  = Gecko
navigator.productSub = 20030107

UA-CH brands = Not:A-Brand 8, Chromium 156, Google Chrome 156
UA-CH platform = Linux
UA-CH architecture = x86, bitness = 64, wow64 = false
UA-CH platformVersion = "" (empty on Linux)
UA-CH model = ""
UA-CH uaFullVersion = 156.0.8078.79
```

This is a normal Linux Chrome 156 identity. It is coherent with the binary and the OS,
but it is **not** coherent with a Turkish residential user if the expected persona is
Windows. The product must decide whether Linux is an acceptable persona or whether the
fork needs to present Windows UA-CH.

### 2.2 Screen and window

| Signal | Value |
|---|---|
| `screen.width × height` | `1280 × 720` |
| `screen.availWidth × availHeight` | `1280 × 693` |
| `screen.availLeft / availTop` | `0 / 27` |
| `window.outerWidth × outerHeight` | `1279 × 719` |
| `window.innerWidth × innerHeight` | `1271 × 572` |
| `devicePixelRatio` | `1` |
| `colorDepth / pixelDepth` | `24 / 24` |
| `screen.orientation` | `landscape-primary / 0` |
| `visualViewport` | `1271 × 572`, scale `1` |

The 27 px top inset is the XFCE panel. The 1280×720 screen is fixed by XRDP. Every
profile inherits it.

### 2.3 Hardware and storage

| Signal | Value | Note |
|---|---|---|
| `hardwareConcurrency` | `2` | Matches the 2 vCPU limit |
| `deviceMemory` | `4` | Chrome caps/reports 4 GiB |
| `maxTouchPoints` | `0` | No touch |
| `navigator.storage.estimate().quota` | `10 GiB` | Matches the 10 GB LXD root device |
| `navigator.storage.estimate().usage` | `0` | Fresh temp profile |
| `navigator.connection.effectiveType` | `4g` | Network Information API |
| `navigator.connection.downlink` | `1.5` | Synthetic/rounded |
| `navigator.connection.rtt` | `100` | Synthetic/rounded |
| `navigator.connection.saveData` | `false` | — |

`deviceMemory=4` and `hardwareConcurrency=2` are internally consistent with a small VPS,
but they are low for a modern desktop. A persona claiming a gaming PC would contradict
them.

### 2.4 GPU and WebGL

`SystemInfo.getInfo` from the headful browser:

```text
vendorString  = Google Inc. (Mesa)
deviceString  = ANGLE (Mesa, llvmpipe (LLVM 15.0.7 256 bits),
                OpenGL 4.5 (Core Profile) Mesa 23.2.1-1ubuntu3.1~22.04.4)
driverVendor  = Mesa
driverVersion = 23.2.1
glRenderer    = ANGLE (Mesa, llvmpipe ...)
glVendor      = Google Inc. (Mesa)
hardwareSupportsVulkan = false
sandboxed     = false
```

Feature status:

| Feature | Status |
|---|---|
| `webgl` | `disabled_off` |
| `webgl2` | `disabled_off` |
| `webgpu` | `disabled_off` |
| `gpu_compositing` | `disabled_software` |
| `2d_canvas` | `disabled_software` |
| `rasterization` | `disabled_software` |
| `video_decode` / `video_encode` | `disabled_software` |
| `vulkan` | `disabled_off` |
| `opengl` | `disabled_off` |

Page-level result:

```json
{
  "webglVendor": null,
  "webglRenderer": null,
  "webglParams": null,
  "webgl2Renderer": null
}
```

Chrome's log:

```text
ContextResult::kFatalFailure: WebGL1 blocklisted
ContextResult::kFatalFailure: WebGL2 blocklisted
```

This is not a subtle spoofing issue. A page that calls `canvas.getContext('webgl')` gets
`null`. Many real sites, including WebGL fingerprint tests, map applications, and some
anti-bot challenges, will treat that as an old/incapable/blocked browser.

### 2.5 Restoring WebGL

A second headful launch with:

```text
--enable-unsafe-swiftshader --ignore-gpu-blocklist
```

returns:

```json
{
  "webgl": true,
  "vendor": "Google Inc. (Mesa)",
  "renderer": "ANGLE (Mesa, llvmpipe (LLVM 15.0.7 256 bits), OpenGL 4.5)"
}
```

So the capability exists; the default blocklist is suppressing it. The current launchers
do not pass these flags, which means the real profiles have no WebGL.

Headless Chrome, with `--disable-gpu`, reports a different software path:

```text
ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)),
       SwiftShader driver)
```

Three different renderers are therefore possible on the same box:

| Mode | Renderer | WebGL |
|---|---|---|
| Headful, default | Mesa llvmpipe (blocked) | `null` |
| Headful, unsafe SwiftShader | Mesa llvmpipe | Available |
| Headless, `--disable-gpu` | SwiftShader | Available |

A fingerprint browser must pick one and make it stable across profiles and modes.

### 2.6 Fonts

- 166 font files, 46 families.
- `document.fonts.check()` reports 27/27 tested fonts present, but fontconfig aliases
  Arial, Segoe UI, PingFang SC, Microsoft YaHei, and Roboto to Liberation/DejaVu.
- Canvas text metrics will reflect Liberation/DejaVu, not the aliased names.
- Noto CJK fonts are installed, so CJK text renders with real CJK glyphs.

This is a **font-metric** gap, not a font-list gap. Spoofing the list without spoofing
the metrics is easy to detect with canvas width measurements.

### 2.7 Media, audio, speech

| Signal | Value |
|---|---|
| `navigator.mediaDevices.enumerateDevices()` | `[]` |
| `Notification.permission` | `default` |
| `speechSynthesis.getVoices()` | `[]` |
| `AudioContext.sampleRate` | `44100` |
| `AudioContext.baseLatency` | `0.01` |
| `crossOriginIsolated` | `false` |
| `history.length` | `1` |

No camera, no microphone, no speakers, no TTS voices. A real desktop usually exposes at
least a default audio output and often a microphone. This is a strong "headless/VM" signal.

### 2.8 Locale, timezone, and language

```text
timezone = UTC
locale   = en-US
calendar = gregory
numberingSystem = latn
languages = [en-US, en]
```

Combined with a Turkish residential IP, this is the clearest coherence failure in the
environment. See §4.

---

## 3. Headless values (for contrast)

| Signal | Headful | Headless |
|---|---|---|
| UA | `Chrome/156.0.0.0` | `HeadlessChrome/156.0.0.0` |
| Screen | `1280×720` | `800×600` |
| DPR | `1` | `1` |
| WebGL vendor | `null` | `Google Inc. (Google)` |
| WebGL renderer | `null` | `ANGLE (... SwiftShader ...)` |
| `webdriver` | `false` | `false` |
| Languages | `en-US,en` | `en-US,en` |
| Timezone | `UTC` | `UTC` |
| Media devices | none | none |

Headless mode is not a substitute for the real desktop. It changes the UA, the screen,
and the GPU path. Any QA harness must test the mode the product actually ships.

---

## 4. Coherence analysis

A fingerprint is coherent when independent layers agree. The current environment:

| Layer | Value | Agrees with TR residential? |
|---|---|---|
| Proxy exit | Turkey | — (reference) |
| Timezone | `UTC` | **No** (Turkey is UTC+3) |
| `Intl` locale | `en-US` | **No** (expected `tr-TR`) |
| `navigator.languages` | `en-US,en` | **No** |
| UI language | `en-US` | **No** |
| System locale | `en_US.UTF-8` | **No** |
| Geolocation permission | `default` (not granted) | Neutral; IP geolocation still says TR |
| Currency | not configured | **No** (expected TRY) |
| Fonts | Western + CJK | Partially; Turkish Latin is covered by DejaVu/Liberation |
| Keyboard layout | not probed | Unknown |
| GPU | llvmpipe / blocked | **No** (unusual for a real desktop) |
| Screen | 1280×720 | Possible but uncommon |
| CPU/RAM | 2 vCPU / 4 GiB | Possible but low |
| Media devices | none | **No** (unusual for a desktop) |
| Speech voices | none | **No** |
| `variations_country` | `tr` for the TR profile | Yes (but `cn`/`jp` in others) |

The mismatch is not one value; it is a cluster. A site that checks two or three of these
can separate the profile from a real Turkish desktop without any advanced fingerprinting.

---

## 5. Detectability ranking (inferred)

| Rank | Signal | Why it stands out | Fix difficulty |
|---|---|---|---|
| 1 | WebGL `null` | Most real browsers have WebGL; null is rare and often associated with headless/blocked environments | Low (flag) / medium (spoof) |
| 2 | No media devices / no speech voices | Real desktops almost always have audio | Medium (virtual devices) |
| 3 | Timezone/locale vs proxy country | Trivial cross-check | Low (per-profile env) |
| 4 | llvmpipe / SwiftShader renderer | Software rendering is uncommon on consumer desktops | High (GPU or patch) |
| 5 | Fixed 1280×720 geometry across profiles | Stable cross-profile identifier | Medium (per-profile display) |
| 6 | `variations_country` mismatch | Internal state, not JS-visible, but affects behaviour | Low (fresh profile) |
| 7 | 2 vCPU / 4 GiB | Low-end but plausible | Low (can't change without host) |
| 8 | Linux UA on a TR residential IP | Plausible but less common than Windows | Medium (fork/UA-CH) |
| 9 | `storage.quota = 10 GiB` | Container artefact | Low (can be patched) |
| 10 | `connection.rtt = 100`, `downlink = 1.5` | Synthetic values | Low (patch or ignore) |

This ranking is a prioritisation tool, not a guarantee. Commercial vendors use many more
signals and proprietary scoring.

---

## 6. What can be fixed without a Chromium fork

| Gap | Fix |
|---|---|
| WebGL null | Add `--enable-unsafe-swiftshader --ignore-gpu-blocklist` (or pass a GPU) |
| Timezone | Run each profile in a container/namespace with `TZ=Europe/Istanbul`, or patch |
| Locale / languages | Install `tr_TR.UTF-8`, set `LANG`/`LC_ALL`, pass `--accept-lang=tr-TR,tr` |
| `variations_country` | Create a fresh profile in the target environment; do not clone |
| Proxy / DNS / IPv6 | Per-profile network namespace, fail-closed firewall, DNS via proxy |
| Screen geometry | Per-profile X server or XRDP session with the target resolution |
| Media devices | Virtual camera/microphone (v4l2loopback, PulseAudio null sink) |
| Speech voices | Install speech-dispatcher voices, or accept the gap |
| Fonts | Install a persona-specific font set; accept metric differences |
| Automation | Controlled CDP port with an auth token, or Playwright launch |

## 7. What requires a fork or a native patch

| Gap | Why configuration is not enough |
|---|---|
| WebGL vendor/renderer strings | Chrome reads them from the GPU process; a page can cross-check many parameters |
| Canvas/audio noise | Must be deterministic per profile and consistent across APIs |
| Font metrics | Blink's font fallback and measurement happen in the renderer |
| UA-CH consistency | Client hints are generated in the browser process and must match the UA |
| Timezone per tab | `Intl` and `Date` are process-wide; per-profile isolation needs a renderer patch or separate processes |
| Screen per profile | `screen` is derived from the window/display; per-profile virtual displays are an OS problem |
| Media device labels | Blink enumerates devices from the OS; labels and capabilities need virtualisation |
| TLS/HTTP2 fingerprint | Network stack behaviour; can be influenced by flags but not fully spoofed |
| WebRTC SDP | Candidate and codec details are generated in the network stack |

The practical split: **configuration gets you a coherent network and profile**, but
**GPU, fonts, canvas, and client hints need code**.

---

## 8. A fingerprint self-test contract

Before a profile is considered usable, it should pass a self-test that records and checks:

- public IPv4 and IPv6 (must match the intended exit or be absent);
- DNS resolver and a DNS leak test;
- WebRTC candidates (must be proxied or empty);
- timezone, `Intl` locale, `navigator.languages`, `Accept-Language`;
- UA, UA-CH, platform, architecture, bitness;
- screen, window, DPR, color depth;
- WebGL vendor/renderer and a stable parameter set;
- canvas, audio, and font-metric hashes (deterministic per profile);
- media devices and speech voices;
- `variations_country` and profile creation metadata;
- Chrome version and profile schema version.

The test should run on every launch in CI, and the results should be diffed against the
profile's manifest. A profile that drifts should fail closed rather than launch.

---

## 9. Evidence

- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
- [`../../inventory/container/gpu-info.json`](../../inventory/container/gpu-info.json)
- [`../../inventory/container/18-headless-probe.json`](../../inventory/container/18-headless-probe.json)
- [`../../inventory/container/17-fingerprint-surface.txt`](../../inventory/container/17-fingerprint-surface.txt)
