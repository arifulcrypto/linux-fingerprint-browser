# Configuration examples

These files are **templates and reference examples**, not a deployment of the live VPS.
Every credential, UUID, key, hostname, and public address is a placeholder.

| Directory | Content |
|---|---|
| [`chrome/`](chrome/) | Chrome launcher template and managed WebRTC policy |
| [`proxy/`](proxy/) | Xray, Hysteria2, Mihomo, pproxy, and systemd examples |
| [`lxd/`](lxd/) | Port-mapping reference for the `c4-desktop` container |

## Placeholder conventions

| Placeholder | Meaning |
|---|---|
| `203.0.113.10` | Public IPv4 (TEST-NET-3) |
| `198.51.100.20` | Secondary public IPv4 (TEST-NET-2) |
| `2001:db8::10` | Public IPv6 (documentation range) |
| `REDACTED` | Secret value: password, UUID, key, or session ID |
| `<profile>` | Profile name, e.g. `chrome-tr-proxy` |
| `<port>` | Local proxy port, e.g. `18081` |

## Safety

- Do not commit real values. Run [`../scripts/check-redaction.sh`](../scripts/check-redaction.sh).
- The systemd examples read credentials from `EnvironmentFile`; prefer that over
  embedding them in `ExecStart`.
- The launcher template is deliberately conservative: it does not enable remote
  debugging, does not disable the sandbox, and does not add automation flags.
