#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Chrome profile launcher template (reference, not the live script)
#
# Usage:
#   ./launcher.template.sh <url> [<url> ...]
#
# Environment:
#   PROFILE_DIR   user-data-dir              (required)
#   PROXY_URL     http://127.0.0.1:<port>    (required)
#   WM_CLASS      X11 WM class               (default: fingerprint-chrome)
#   LANG_TAG      Chrome UI language         (default: en-US)
#   ACCEPT_LANG   navigator.languages value  (default: en-US,en)
#   TZ_VALUE      IANA timezone              (default: UTC)
#
# The template assumes it runs inside the profile's own container or namespace,
# where TZ, locale, fonts, and display already belong to that profile. Do not use
# it to run several personas on one shared desktop: environment isolation is the
# point (see docs/en/08-architecture.md).
# ---------------------------------------------------------------------------
set -euo pipefail

: "${PROFILE_DIR:?set PROFILE_DIR to the profile user-data directory}"
: "${PROXY_URL:?set PROXY_URL to the local proxy endpoint}"

WM_CLASS="${WM_CLASS:-fingerprint-chrome}"
LANG_TAG="${LANG_TAG:-en-US}"
ACCEPT_LANG="${ACCEPT_LANG:-en-US,en}"
TZ_VALUE="${TZ_VALUE:-UTC}"
DISPLAY_VALUE="${DISPLAY_VALUE:-:10}"
XAUTHORITY_VALUE="${XAUTHORITY_VALUE:-$HOME/.Xauthority}"

export DISPLAY="$DISPLAY_VALUE"
export XAUTHORITY="$XAUTHORITY_VALUE"
export TZ="$TZ_VALUE"
export LANG="${LANG_VALUE:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

mkdir -p "$PROFILE_DIR"
chmod 700 "$PROFILE_DIR"

exec /usr/bin/google-chrome-stable \
  --user-data-dir="$PROFILE_DIR" \
  --class="$WM_CLASS" \
  --lang="$LANG_TAG" \
  --accept-lang="$ACCEPT_LANG" \
  --proxy-server="$PROXY_URL" \
  --proxy-bypass-list="127.0.0.1,localhost" \
  --disable-quic \
  --webrtc-ip-handling-policy=disable_non_proxied_udp \
  --enforce-webrtc-ip-permission-check \
  --disable-features=DnsOverHttps \
  --enable-unsafe-swiftshader \
  --ignore-gpu-blocklist \
  --no-first-run \
  --no-default-browser-check \
  "$@"
