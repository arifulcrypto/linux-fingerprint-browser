# Proxy configuration examples

Reference topology from the inventory (all addresses and secrets are placeholders):

```text
Chrome profile
  → local HTTP bridge 127.0.0.1:<port>
  → residential HTTP proxy
  → internet

Remote client
  → VLESS Reality :10041/TCP ─┐
  → Hysteria2 :10042/UDP ─────┴→ residential HTTP proxy → internet
```

## Files

| File | Purpose |
|---|---|
| `xray-server-vless-reality.json` | VLESS + REALITY + Vision inbound, HTTP residential outbound |
| `xray-client-vless-reality.json` | Local HTTP/SOCKS inbound, VLESS Reality outbound |
| `hysteria2-server.yaml` | Hysteria2 server with Salamander obfs and HTTP upstream |
| `hysteria2-client.yaml` | Hysteria2 client exposing local HTTP/SOCKS |
| `mihomo-example.yaml` | Mihomo/Clash Meta client with manual node selection |
| `pproxy-bridge.service` | Local HTTP bridge with credentials in an EnvironmentFile |
| `xray-server.service` | Hardened systemd unit for Xray |
| `hysteria-server.service` | Hardened systemd unit for Hysteria2 |

## Design notes from the live environment

1. **The residential upstream is plain HTTP.** TLS terminates at the VPS; from there to
   the provider the credentials and request metadata are unencrypted. Prefer an HTTPS
   provider endpoint or wrap the hop in TLS.
2. **Do not put metered residential nodes in `url-test` or `fallback` groups.** The
   health checks consume quota and add jitter. Use `select` and test manually.
3. **Pin the Xray version.** The live node pins `26.6.27` because newer REALITY
   implementations failed against some clients. Record and test any upgrade.
4. **Hysteria2 cannot provide end-to-end UDP** when the upstream is an HTTP proxy. Keep
   `disableUDP: true`; do not claim UDP support the chain cannot deliver.
5. **Self-signed certificates require `insecure: true`.** That removes server
   authentication. Use a real certificate or a pinned public key in production.
6. **Credentials belong in `EnvironmentFile` (mode 0600) or a secret manager**, never in
   `ExecStart`, where `ps` and `systemctl cat` expose them.
7. **Kill switch belongs outside the proxy.** A dead proxy process must not leave direct
   egress available; enforce that in the profile network namespace/firewall.

## Validation

```bash
# Xray configuration syntax
xray run -test -c /etc/xray/config.json

# Hysteria2 configuration syntax
hysteria server -c /etc/hysteria/config.yaml --help >/dev/null

# systemd unit syntax
systemd-analyze verify ./xray-server.service
```

## Session rotation

A 24-hour sticky residential session must be replaced in every place that embeds it:

- the bridge unit's `UPSTREAM_URL`;
- the Xray outbound user/password;
- the Hysteria2 outbound URL.

Update the files, restart the units, and verify the exit country before switching
browser traffic. Automate this with a script that benchmarks candidates and rolls back on
failure; never rotate a session that is serving live profiles without a health check.
