# Launchers — sanitised summary

Three Chrome launchers exist on the desktop. All use the same pattern: ensure the proxy
service is active, export the X11 environment, create the profile directory, and start
Chrome with an isolated `--user-data-dir`.

## Common template

```bash
#!/usr/bin/env bash
export DISPLAY=${DISPLAY:-:10}
export XAUTHORITY=${XAUTHORITY:-/root/.Xauthority}
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}

USER_DATA_DIR="/root/.config/<profile>"
mkdir -p "$USER_DATA_DIR"

setsid /usr/bin/google-chrome-stable \
  --no-sandbox \
  --disable-dev-shm-usage \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir="$USER_DATA_DIR" \
  --class="<wm-class>" \
  --lang=en-US \
  --proxy-server="http://127.0.0.1:<port>" \
  --proxy-bypass-list="127.0.0.1,localhost" \
  --disable-quic \
  --webrtc-ip-handling-policy=disable_non_proxied_udp \
  --enforce-webrtc-ip-permission-check \
  --disable-features=DnsOverHttps \
  "$@"
```

## Instances

| Script | Profile | Proxy | WM class | Start URLs |
|---|---|---|---|---|
| `start_us_proxy_chrome.sh` | `~/.config/chrome-us-proxy` | `127.0.0.1:2080` | `us-proxy-chrome` | `ipinfo.io`, `claude.ai` |
| `start_residential_chrome.sh` | `~/.config/chrome-residential` | `127.0.0.1:18080` | `residential-proxy-chrome` | `ipinfo.io`, `ippure.com` |
| `start_tr_proxy_chrome.sh` | `~/.config/chrome-tr-proxy` | `127.0.0.1:18081` | `tr-proxy-chrome` | `ipinfo.io`, `ippure.com` |

## Observations

- The TR script header claims `tr-TR` UI, but the flag is `--lang=en-US` and the
  environment is `en_US.UTF-8`. This is a documentation/configuration mismatch.
- `--no-sandbox` is used everywhere, although `chrome-sandbox` is setuid.
- `--disable-dev-shm-usage` is used although `/dev/shm` is 1.9 GiB.
- No launcher enables WebGL. Headful WebGL is therefore `null` (see
  `docs/en/06-fingerprint-surface.md`).
- No launcher sets a timezone, locale, or per-profile DNS policy.
- The US and residential scripts start with two URLs; the TR script also starts with
  `ipinfo.io` and `ippure.com`.

## Desktop entries

`.desktop` files exist for the three profiles and launch the corresponding script. They
do not add flags; all behaviour comes from the script.
