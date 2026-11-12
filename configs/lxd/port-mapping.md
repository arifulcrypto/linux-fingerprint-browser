# LXD port mapping reference

The live host publishes container services through LXD `proxy` devices. This is a
reference for the documented environment; do not apply it blindly to another host.

## Mapping table

| Host listen | Protocol | Container target | Purpose | Notes |
|---|---|---|---|---|
| `2204` | TCP | `10.0.43.40:22` | SSH | Bound to `0.0.0.0` |
| `3389` | TCP | `10.0.43.40:3389` | XRDP | Also UDP |
| `3389` | UDP | `10.0.43.40:3389` | XRDP | RDP transport |
| `8088` | TCP | `10.0.43.40:8088` | goods24 web (Caddy) | Not 1Panel |
| `8088` | TCP (IPv6) | `10.0.43.40:8088` | goods24 web | Host global IPv6 |
| `10041` | TCP | `10.0.43.40:10041` | VLESS Reality + Vision | Active |
| `10042` | UDP | `10.0.43.40:10042` | Hysteria2 | Active |
| `10042` | TCP | `10.0.43.40:10042` | — | **Unused**; remove to reduce surface |

## Inspecting the live configuration

```bash
# All devices on the container
lxc config device show c4-desktop

# Only the published ports
lxc config device show c4-desktop | grep -A6 -E 'p10041|p10042|ph2_10042|p8088|prdp|ssh2204'

# Resulting nftables DNAT rules
nft list ruleset | grep -E 'c4-desktop|1004[0-9]|8088|3389|2204'
```

## Adding a mapping

```bash
lxc config device add c4-desktop p10043 proxy \
  listen=tcp:203.0.113.10:10043 \
  connect=tcp:10.0.43.40:10043 \
  nat=true
```

`nat=true` makes LXD DNAT the published address to the container address and masquerade
return traffic. Without it, the container must route back through the host.

## Removing the unused TCP mapping

```bash
lxc config device remove c4-desktop p10042
```

This removes only the TCP proxy device; keep `ph2_10042` (UDP) for Hysteria2. Confirm the
device list before removal:

```bash
lxc config device show c4-desktop | grep -E 'p10042|ph2_10042'
```

## Security notes

- Every published port is reachable from the internet unless an upstream firewall
  restricts it. `ufw` inside the container is inactive; exposure is controlled by LXD
  devices and the provider firewall.
- Publish only what is needed. The unused `10042/TCP` device is unnecessary surface.
- SSH on `2204` allows root login with a password in the documented setup. Prefer keys
  and a non-root user for any long-lived deployment.
- RDP on `3389` is published TCP and UDP. Restrict it by source address if possible.
