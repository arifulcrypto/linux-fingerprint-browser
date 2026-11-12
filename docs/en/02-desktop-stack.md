# 02 — Desktop Stack

The browser does not run on a bare X server. It runs inside an XFCE session exported by
XRDP, on Xorg, at a fixed geometry. Every one of those layers contributes to the
fingerprint and to the operational constraints.

---

## 1. Components and versions

| Component | Version | Package |
|---|---|---|
| XRDP | 0.9.17 | `xrdp 0.9.17-2ubuntu3.1` |
| xorgxrdp | 0.2.17 | `xorgxrdp 1:0.2.17-1build1` |
| Xorg | 1.21.1.4 | `xserver-xorg-core 2:21.1.4-2ubuntu1.7~22.04.16` |
| XFCE | 4.16 | `xfce4 4.16` meta-package |
| D-Bus | 1.12.20 | `dbus`, `dbus-x11`, `dbus-user-session` |
| Display | `:10` | xrdp sesman `X11DisplayOffset=10` |
| Session manager | `xfce4-session` | started via `/etc/xrdp/startwm.sh` → `/etc/X11/Xsession` |

No Wayland. No PipeWire. No PulseAudio tools (`pactl`/`aplay` absent), no `/dev/snd`.
The XFCE panel still ships a PulseAudio plugin, but audio is effectively unavailable.

---

## 2. XRDP configuration

From `/etc/xrdp/xrdp.ini` and `/etc/xrdp/sesman.ini`:

| Setting | Value | Consequence |
|---|---|---|
| Listen port | `3389` TCP (+ UDP mapping) | Published by LXD |
| Security layer | `negotiate`, TLS 1.2/1.3 | Standard RDP encryption |
| Max bpp | 32 | 24-bit root depth in X |
| Bitmap cache / compression | enabled | Bandwidth optimisation |
| Multimon | allowed | Client can request multiple monitors |
| `AllowRootLogin` | `true` | The desktop runs as root |
| `MaxSessions` | 50 | Many concurrent sessions possible |
| `KillDisconnected` | `false` | Sessions survive disconnect |
| Clipboard restriction | `false` | Clipboard is shared |
| X11 display offset | 10 | Fixed `:10` |
| Xorg params | `-noreset -nolisten tcp` | No TCP X listener |
| Xvnc DPI fallback | 96 | Consistent with Xorg |

The session is long-lived and reconnecting returns to the same desktop. That is convenient
for a VPS, but it means all browser windows share one session, one clipboard, and one
window manager.

---

## 3. Display geometry

`xrandr` and `xdpyinfo`:

```text
Screen 0: minimum 256 x 256, current 1280 x 720, maximum 16384 x 16384
rdp0 connected 1280x720+0+0
  1280x720  46.080MHz  h: 1280  v: 720  clock 50.00Hz
dimensions:    1280x720 pixels (339x191 millimeters)
resolution:    96x96 dots per inch
depth of root window: 24 planes
```

The headful JavaScript probe adds the window-manager details:

| Signal | Value |
|---|---|
| `screen.width × height` | `1280 × 720` |
| `screen.availWidth × availHeight` | `1280 × 693` |
| `screen.availTop` | `27` (top panel) |
| `window.outerWidth × outerHeight` | `1279 × 719` |
| `window.innerWidth × innerHeight` | `1271 × 572` |
| `devicePixelRatio` | `1` |
| `colorDepth` / `pixelDepth` | `24 / 24` |
| `screen.orientation` | `landscape-primary / 0` |

The 27 px difference is the XFCE panel. The inner height is smaller because of browser
chrome. These are stable, reproducible values — which makes them a stable identifier
across profiles.

### Why 1280×720 matters

720p is a legitimate resolution, but it is uncommon on modern desktops and very uncommon
with a 27 px panel and a 1279 px outer width. More importantly, **every profile reports
the same geometry**. A fingerprint browser must either:

- give each profile a plausible, independent geometry (window size, screen size, panel),
  or
- keep one geometry but accept that profiles are linkable at the display layer.

XRDP supports dynamic resize, but the current session is fixed at 1280×720. There is no
per-profile display server.

---

## 4. Input devices

```text
Virtual core pointer
  ↳ Virtual core XTEST pointer
  ↳ xrdpMouse
Virtual core keyboard
  ↳ Virtual core XTEST keyboard
  ↳ xrdpKeyboard
```

`maxTouchPoints = 0`. There is no touchscreen, no stylus, no gamepad. That is consistent
with a remote Linux desktop, but it is another signal that must match the claimed device
class. A profile pretending to be a Windows laptop with a touchscreen would contradict
this layer unless the browser virtualises it.

---

## 5. Fonts

| Metric | Value |
|---|---|
| Font files | 166 |
| Families | 46 |
| Packages | `fonts-dejavu-core`, `fonts-liberation`, `fonts-noto-cjk`, `fonts-noto-color-emoji`, `fonts-noto-mono`, `fonts-ubuntu-console`, `fonts-urw-base35`, `xfonts-*` |
| CJK | Noto Sans/Serif CJK for SC, TC, JP, KR, HK |
| Emoji | Noto Color Emoji 2.047 |

Families include DejaVu, Liberation, Nimbus, URW base35, Bitstream Charter, C059,
Century Schoolbook L, Dingbats, and the Noto CJK sets.

### Fontconfig aliases make JS font checks unreliable

A page that checks `document.fonts.check('16px "Arial"')` gets `true` on this box, because
fontconfig aliases Arial to Liberation Sans. The same happens for Segoe UI, PingFang SC,
Microsoft YaHei, and Roboto — all resolve to DejaVu Sans:

```text
Arial           -> LiberationSans-Regular.ttf "Liberation Sans"
Segoe UI        -> DejaVuSans.ttf "DejaVu Sans"
PingFang SC     -> DejaVuSans.ttf "DejaVu Sans"
Microsoft YaHei -> DejaVuSans.ttf "DejaVu Sans"
Roboto          -> DejaVuSans.ttf "DejaVu Sans"
Noto Sans CJK SC-> NotoSansCJK-Regular.ttc "Noto Sans CJK SC"
```

So a naive font probe reports 27/27 fonts present. That is not evidence that the fonts
exist; it is evidence that fontconfig substitutes them. Real font fingerprinting measures
glyph widths and canvas rendering, not just `check()`. This matters twice:

1. the current box looks "font-rich" to a naive probe but renders Western fonts with
   Liberation/DejaVu metrics;
2. a future spoofing layer must spoof **metrics and glyphs**, not just the font list.

---

## 6. Locale and timezone

```text
LANG / LC_ALL: en_US.UTF-8
locale -a:     C, C.utf8, en_US.utf8, POSIX
timezone:      Etc/UTC (UTC, +0000)
```

There is no `tr_TR.UTF-8`, no `de_DE.UTF-8`, no `ja_JP.UTF-8`. Chrome runs with
`--lang=en-US`; the headful probe reports `language: en-US`, `languages: [en-US, en]`,
`Intl` locale `en-US`, calendar `gregory`, numbering system `latn`.

For a Turkish residential profile, this is a three-way mismatch:

| Layer | Current | Expected for TR residential |
|---|---|---|
| Proxy exit | Turkey | Turkey |
| Timezone | `UTC` | `Europe/Istanbul` (UTC+3) |
| Browser language | `en-US,en` | `tr-TR,tr` |
| `Intl` locale | `en-US` | `tr-TR` |
| System locale | `en_US.UTF-8` | `tr_TR.UTF-8` |

Chrome does not expose a command-line flag for timezone. Timezone must be controlled at
the OS/container level, via `TZ`, or by patching the renderer. A per-profile `TZ`
environment variable is not sufficient for a shared desktop because all profiles inherit
the same session environment.

---

## 7. Session startup and environment

`/etc/xrdp/startwm.sh` sources `/etc/profile` and executes `/etc/X11/Xsession`. The XFCE
session starts `xfce4-session`, `xfce4-panel`, `xfce4-notifyd`, `xfconfd`, and the
PulseAudio panel plugin.

There is no per-profile environment. `DISPLAY`, `XAUTHORITY`, `LANG`, `LC_ALL`, and `TZ`
are inherited from the session. The Chrome launchers override `LANG` and `LC_ALL` to
`en_US.UTF-8`, which reinforces the English mismatch for non-English proxies.

---

## 8. Desktop-level isolation gaps

| Gap | Impact |
|---|---|
| Single X display `:10` | All profiles share the same screen and window manager |
| Single Linux user `root` | No per-profile home, permissions, or process boundary |
| Shared clipboard | Copy in one profile, paste in another |
| Shared fontconfig | Identical font metrics for every profile |
| Shared timezone/locale | Identical clock and `Intl` behaviour |
| Shared D-Bus session | Notifications, power, and desktop services are common |
| No screen lock / idle policy | Session persists indefinitely |
| `KillDisconnected=false` | Disconnected sessions keep running and consuming RAM |

A product that claims profile isolation must address these at the container or VM level,
not only with `--user-data-dir`.

---

## 9. Evidence

- [`../../inventory/container/02-desktop.txt`](../../inventory/container/02-desktop.txt)
- [`../../inventory/container/03-display.txt`](../../inventory/container/03-display.txt)
- [`../../inventory/container/04-fonts-locale.txt`](../../inventory/container/04-fonts-locale.txt)
- [`../../inventory/container/17-fingerprint-surface.txt`](../../inventory/container/17-fingerprint-surface.txt)
- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
