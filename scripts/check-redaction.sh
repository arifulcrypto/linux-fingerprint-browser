#!/usr/bin/env bash
# Guard against publishing credentials, keys, UUIDs, and real addresses.
#
# Usage: ./scripts/check-redaction.sh [path ...]
# Exit code 0 = clean, 1 = findings.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(".")
fi

python3 - "${TARGETS[@]}" <<'PY'
import ipaddress
import os
import re
import sys

roots = sys.argv[1:]
skip_dirs = {".git", "node_modules", "__pycache__", ".venv", "venv"}
skip_files = {"check-redaction.sh"}

ALLOWED_V4 = [
    ipaddress.ip_network(n)
    for n in (
        "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
        "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24",
        "192.168.0.0/16", "198.18.0.0/15", "198.51.100.0/24",
        "203.0.113.0/24", "224.0.0.0/4", "240.0.0.0/4",
    )
]
ALLOWED_V4_EXACT = {
    "1.21.1.4",        # Xorg version, not an address
    "1.1.1.1", "1.0.0.1", "8.8.8.8", "9.9.9.9",
    "156.0.0.0",      # Chrome major version in a UA string
    "8.0.0.0",        # UA-CH "Not:A-Brand" version
    "1.0.0.6",        # Chrome Web Store Payments extension version
    "255.255.255.0", "255.255.255.255",
}
ALLOWED_V6 = [
    ipaddress.ip_network(n)
    for n in ("::1/128", "::/128", "fc00::/7", "fe80::/10", "ff00::/8", "2001:db8::/32")
]

V4_RE = re.compile(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])")
V6_RE = re.compile(r"(?<![\w:])(?:[0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}(?![\w:])")
UUID_RE = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                     r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")
MAC_RE = re.compile(r"\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b")
URL_USERINFO_RE = re.compile(r"https?://[^/@\s]+:[^/@\s]+@")
PEM_RE = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")
TOKEN_RES = [
    re.compile(r"\bghp_[A-Za-z0-9]{30,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{30,}\b"),
    re.compile(r"\bsk-(?!ssh-|ecdsa-)[A-Za-z0-9_-]{20,}\b"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    re.compile(r"\bBearer\s+[A-Za-z0-9._-]{20,}\b"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\."),
]
FORBIDDEN_STRINGS = ("ipcook",)
ASSIGN_RE = re.compile(
    r"(?i)\b(password|passwd|pass|secret|token|api[_-]?key|privateKey|publicKey|"
    r"shortId|uuid)\b\s*[:=]\s*[\"']?([A-Za-z0-9+/=_.-]{16,})"
)

findings = []


def add(path, lineno, rule, text):
    findings.append((path, lineno, rule, text.strip()[:160]))


def check_line(path, lineno, line):
    if line.lstrip().startswith(("#", "//")) and "BEGIN PRIVATE KEY" not in line:
        # Comments still matter for addresses; only skip obvious rule prose.
        pass

    for m in V4_RE.finditer(line):
        value = m.group(0)
        if value in ALLOWED_V4_EXACT:
            continue
        try:
            ip = ipaddress.ip_address(value)
        except ValueError:
            continue
        if any(ip in net for net in ALLOWED_V4):
            continue
        add(path, lineno, "public IPv4", value)

    for m in V6_RE.finditer(line):
        value = m.group(0)
        try:
            ip = ipaddress.ip_address(value)
        except ValueError:
            continue
        if any(ip in net for net in ALLOWED_V6):
            continue
        add(path, lineno, "public IPv6", value)

    m = UUID_RE.search(line)
    if m and "REDACTED" not in line[max(0, m.start() - 12):m.start()]:
        add(path, lineno, "UUID", m.group(0))

    m = MAC_RE.search(line)
    if m and not m.group(0).lower().endswith("xx:xx:xx"):
        add(path, lineno, "MAC address", m.group(0))

    m = URL_USERINFO_RE.search(line)
    if m and "REDACTED" not in m.group(0) and "<" not in m.group(0):
        add(path, lineno, "URL with credentials", m.group(0))

    if PEM_RE.search(line):
        add(path, lineno, "PEM private key", "-----BEGIN ... PRIVATE KEY-----")

    for word in FORBIDDEN_STRINGS:
        if word in line.lower():
            add(path, lineno, "provider identifier", word)

    for rx in TOKEN_RES:
        m = rx.search(line)
        if m:
            add(path, lineno, "token-like value", m.group(0))

    for m in ASSIGN_RE.finditer(line):
        key = m.group(1).lower()
        value = m.group(2)
        if "REDACTED" in value or value.startswith("<") or value.startswith("$"):
            continue
        if key == "uuid" and not re.fullmatch(
                r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", value):
            continue
        if set(value) <= {"x", "X", "*", "."}:
            continue
        add(path, lineno, f"credential-like assignment ({m.group(1)})", m.group(0))


def iter_files():
    for root in roots:
        if os.path.isfile(root):
            yield root
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in skip_dirs]
            for name in filenames:
                if name in skip_files:
                    continue
                if name.endswith((".png", ".jpg", ".jpeg", ".gif", ".pdf",
                                  ".tar", ".gz", ".zip", ".woff", ".woff2",
                                  ".ttf", ".otf", ".ico")):
                    continue
                yield os.path.join(dirpath, name)


for path in iter_files():
    try:
        with open(path, encoding="utf-8", errors="strict") as fh:
            for lineno, line in enumerate(fh, 1):
                check_line(path, lineno, line)
    except (UnicodeDecodeError, OSError):
        continue

if findings:
    print(f"Redaction check failed: {len(findings)} finding(s)\n")
    for path, lineno, rule, text in findings:
        print(f"{path}:{lineno}: [{rule}] {text}")
    print("\nReplace secrets with REDACTED and public addresses with "
          "203.0.113.10 / 198.51.100.x / 2001:db8::.")
    sys.exit(1)

print("Redaction check passed: no credentials, keys, UUIDs, or real addresses found.")
PY
