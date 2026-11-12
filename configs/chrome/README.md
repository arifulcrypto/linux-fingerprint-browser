# Chrome configuration

## Files

| File | Purpose |
|---|---|
| `launcher.template.sh` | Conservative per-profile launcher with proxy and WebRTC controls |
| `webrtc-policy.json` | Managed policy to place in `/etc/opt/chrome/policies/managed/` |

## What the launcher changes compared to the live VPS scripts

| Live scripts | Template | Reason |
|---|---|---|
| `--no-sandbox` | sandbox enabled | A sandbox that is installed but always disabled is not a security boundary |
| `--disable-dev-shm-usage` | omitted | `/dev/shm` is adequate; the flag changes crash behaviour |
| fixed `--lang=en-US` | `LANG_TAG` / `ACCEPT_LANG` | Language must follow the persona |
| no timezone control | `TZ` from the profile environment | Timezone must follow the proxy geography |
| no WebGL flags | `--enable-unsafe-swiftshader --ignore-gpu-blocklist` | Headful WebGL is otherwise `null` on this GPU-less box |
| `setsid ... >/dev/null` | `exec` | The supervisor should own the process and collect logs |

The template still uses **stock Chrome**. It cannot fix WebGL strings, canvas or font
metrics, or UA-CH/platform coherence; those need the Chromium fork or a GPU
(see [`../../docs/en/06-fingerprint-surface.md`](../../docs/en/06-fingerprint-surface.md)).

## Managed policy

Copy `webrtc-policy.json` to:

```bash
sudo install -D -m 0644 webrtc-policy.json \
  /etc/opt/chrome/policies/managed/webrtc-policy.json
```

Verify at `chrome://policy`. Policy is preferable to command-line flags because it
cannot be overridden by a page or an extension.

## What is deliberately absent

- `--remote-debugging-port` — automation is a supervisor decision, not a default.
- `--enable-automation` — changes `navigator.webdriver` and the UI.
- `--user-agent` overrides — a false UA that disagrees with UA-CH is worse than the
  real one.
- `--host-resolver-rules` — DNS belongs to the network namespace, not a flag.
- `--disable-ipv6` — IPv6 must be disabled at the namespace/firewall level so it also
  covers non-Chrome processes.

## Per-profile checklist

Before launching, the supervisor should assert:

- proxy health check passed;
- IPv6 is disabled or routed through the proxy;
- DNS resolver is the profile resolver;
- `TZ`, `LANG`, `LC_ALL`, fonts, and display belong to the profile;
- the profile manifest matches the installed Chrome version;
- the self-test from `docs/en/06-fingerprint-surface.md` passes.
