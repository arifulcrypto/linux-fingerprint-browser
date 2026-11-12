# 10 — Collection Method

This document explains how the inventory was captured, what the scripts do, what was
deliberately not collected, and how to reproduce the snapshot.

---

## 1. Principles

1. **Read-only.** The collectors do not modify services, firewall rules, proxy configs,
   Chrome profiles, or user data. They write reports under `/tmp` and produce a tarball.
2. **Evidence over summary.** Raw command output is kept; the documents interpret it.
3. **Minimal footprint.** No packet capture, no brute force, no crawling, no account
   actions, no profile logins.
4. **Redaction before publication.** Real credentials, keys, UUIDs, session IDs, public
   IPs, and MAC addresses are removed from the public copy.
5. **Date-stamped.** A fingerprint is only valid for the software versions it was
   captured from.

---

## 2. Collectors

### Container

[`../../scripts/collect-container.sh`](../../scripts/collect-container.sh) runs inside
`c4-desktop` and writes 20 reports under `/tmp/fp-inventory`:

| File | Content |
|---|---|
| `00-system.txt` | hostname, OS, kernel, time, locale, timezone, machine-id hash |
| `01-hardware.txt` | CPU, memory, disk, mounts, DMI, devices, capabilities |
| `02-desktop.txt` | processes, sessions, XRDP, XFCE, window manager, packages |
| `03-display.txt` | xrandr, xdpyinfo, xrdb, xset, xinput, xprop, glxinfo, XRDP config |
| `04-fonts-locale.txt` | font count, families, files, fontconfig, locales, input methods |
| `05-chrome.txt` | binaries, version, package, policies, sandbox, debug ports, processes |
| `06-chrome-profiles.txt` | profile sizes, trees, extensions, prefs locations |
| `06b-chrome-profile-summary.json` | parsed Preferences / Local State summary |
| `07-chrome-launchers.txt` | desktop files, launchers, autostart, proxy cheat sheet |
| `08-proxy-services.txt` | units, status, versions, sanitised Xray/Hysteria configs |
| `09-network.txt` | addresses, routes, resolver, listeners, nftables, sysctl, DNS tests |
| `10-container-view.txt` | container identity, cgroup, mounts, limits |
| `11-software.txt` | package count, key packages, all packages, apt sources |
| `12-toolchain.txt` | compilers, languages, Python packages, build deps, disk budget |
| `13-docker.txt` | Docker version, info, containers, images, networks, volumes |
| `14-1panel.txt` | 1Panel presence (absent) |
| `15-autostart-cron-users.txt` | cron, enabled/running units, users, sshd, fail2ban |
| `16-security.txt` | AppArmor, ufw, sysctl, open ports, shadow algorithm, sudoers |
| `17-fingerprint-surface.txt` | screen, DPI, GPU, audio, timezone, locale, fonts, MAC, CPU |
| `18-headless-chrome-probe.*` | headless DOM/JSON probe and errors |
| `19-summary.txt` | collection time, file list, size |

### Host

[`../../scripts/collect-host.sh`](../../scripts/collect-host.sh) runs on the KVM host and
writes five reports under `/tmp/fp-host-inventory`:

| File | Content |
|---|---|
| `00-host-system.txt` | OS, kernel, CPU, memory, disk, PCI, GPU |
| `01-host-lxd.txt` | containers, `c4` config/devices, profiles, networks, storage |
| `02-host-network.txt` | addresses, routes, public IP, DNS, listeners, nftables |
| `03-host-services.txt` | running services, versions, Docker, cron |
| `04-host-ports.txt` | LXD port mappings, nftables excerpts, container IP |

### Running them

```bash
# container (from the host or over SSH)
scp -P 2204 scripts/collect-container.sh root@<host>:/tmp/
ssh -p 2204 root@<host> 'bash /tmp/collect-container.sh'

# host
scp -P <host-ssh-port> scripts/collect-host.sh root@<host>:/tmp/
ssh -p <host-ssh-port> root@<host> 'bash /tmp/collect-host.sh'
```

The scripts print the tarball path at the end. Copy it out and extract locally.

---

## 3. Headful probe

The headful probe is not part of the collector because it launches a browser. It was run
manually:

1. Write a local HTML page that computes the fingerprint object and stores it in
   `window.__fp`.
2. Launch a temporary profile on `:10`:

   ```bash
   DISPLAY=:10 XAUTHORITY=/root/.Xauthority \
   google-chrome-stable --no-sandbox --disable-dev-shm-usage \
     --no-first-run --no-default-browser-check \
     --user-data-dir=/tmp/fp-headful-profile \
     --remote-debugging-port=9222 --remote-allow-origins=* \
     --window-size=1280,720 --window-position=0,0 \
     file:///tmp/headful-probe.html
   ```

3. Connect to `http://127.0.0.1:9222/json`, find the page target, and evaluate
   `JSON.stringify(window.__fp)` over the WebSocket.
4. Query `SystemInfo.getInfo` and `Browser.getVersion` on the browser target.
5. Kill the temporary browser and remove the profile.

The probe used a temporary profile and a local-only CDP port. It did not touch the
existing `chrome-*` profiles. The resulting JSON is stored as
`inventory/container/headful-probe.json` and `gpu-info.json`.

### WebGL variant

A second headful run added:

```text
--enable-unsafe-swiftshader --ignore-gpu-blocklist
```

and evaluated a minimal WebGL check. The result is recorded in
`06-fingerprint-surface.md`. This was a measurement, not a change to the launchers.

---

## 4. What was not collected

| Not collected | Why |
|---|---|
| Cookies, localStorage, IndexedDB, history | Privacy; not needed for the environment inventory |
| Saved passwords, autofill, payment methods | Privacy and security |
| Proxy provider account details | Secrets |
| Packet captures | Out of scope; would be intrusive |
| TLS/JA3/JA4 fingerprint | Requires a controlled server; future work |
| Canvas/audio hash values | The probe captured capability, not a stable hash; future self-test |
| WebRTC candidate dump | Only the policy was captured; future leak test |
| DNS canary / leak test | The resolver path was captured; an active leak test is future work |
| Keyboard layout / keymap | Not captured; future probe |
| Screen screenshots | Not needed; avoid PII |
| Windows/WSL environment | Not available in this phase |
| GPU passthrough test | Host has `/dev/dri`, container does not; future work |

These are explicit gaps, not oversights. The roadmap adds them to the self-test harness.

---

## 5. Redaction

The public inventory applies these replacements:

| Real value class | Public placeholder |
|---|---|
| Public IPv4 | `203.0.113.10` (TEST-NET-3) |
| Secondary public IPv4 | `198.51.100.x` (TEST-NET-2) |
| Public IPv6 | `2001:db8::10` |
| Proxy username/password | `REDACTED` |
| VLESS UUID | `REDACTED` |
| REALITY private/public key, short ID | `REDACTED` |
| Hysteria2 password, obfs password | `REDACTED` |
| Session ID | `REDACTED` |
| MAC address | Last three octets masked |
| `machine-id` / `boot-id` hash | Removed |
| SSH password | Never collected |

The private archive retains the real values. It is not part of this repository.

---

## 6. Reproducibility

To reproduce the snapshot:

1. Use the same OS image and Chrome version. A different Chrome version changes UA-CH,
   feature flags, and possibly WebGL/canvas behaviour.
2. Use the same display geometry (1280×720, 96 DPI) or record the difference.
3. Use the same locale/timezone (`en_US.UTF-8`, `UTC`) or record the difference.
4. Run the collectors and the headful probe at the same time of day; some values
   (network quality, `connection.rtt`) vary.
5. Store the output with a date and a checksum.

A future `manifest.json` should record:

```json
{
  "captured_at": "2026-11-12T04:00:00Z",
  "host_os": "Ubuntu 20.04.6 LTS",
  "container_os": "Ubuntu 22.04.5 LTS",
  "kernel": "5.4.0-216-generic",
  "chrome": "156.0.8078.79",
  "xorg": "1.21.1.4",
  "xrdp": "0.9.17",
  "display": "1280x720@96dpi",
  "locale": "en_US.UTF-8",
  "timezone": "UTC",
  "sha256": "<inventory tarball hash>"
}
```

---

## 7. Limitations

- The inventory is a point-in-time snapshot. Chrome, Docker images, and proxy sessions
  change.
- The headful probe used a temporary profile, not the real `chrome-tr-proxy` profile. The
  values should match, but the real profile may have extensions or permissions that
  change them.
- The fingerprint checks are capability checks, not a full anti-detect vendor score.
- The latency numbers are from one client and one provider; they are indicative, not a
  benchmark of the residential market.
- The host and container share a filesystem; disk numbers are coupled.
- No Windows, macOS, or WSL environment was measured.

---

## 8. Safety

- Do not run the collectors on a host you do not own or have permission to inspect.
- Do not publish raw output without reviewing it for secrets.
- Do not run the headful probe against accounts you care about; it uses a throwaway
  profile for a reason.
- Do not disable the proxy or firewall on a live host to "test" a leak; use a canary and
  a maintenance window.
- Keep the private archive encrypted and access-controlled.
