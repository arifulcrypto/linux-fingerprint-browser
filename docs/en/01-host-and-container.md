# 01 — Host and Container

This document describes the physical/virtual envelope: the KVM host, the LXD layer, the
`c4-desktop` container, its limits, storage, and the port mappings that expose services.

---

## 1. Host

| Property | Value |
|---|---|
| Hostname | `tql` |
| OS | Ubuntu 20.04.6 LTS (Focal Fossa) |
| Kernel | `5.4.0-216-generic` (SMP Fri Apr 11 2025) |
| Virtualisation | KVM guest, QEMU Standard PC (i440FX + PIIX), SeaBIOS 1.16.3 |
| CPU | 2 vCPU, AMD EPYC-Rome, 2.3 GHz, AVX2, 32 MiB L3 |
| Memory | 3.8 GiB RAM, 4.0 GiB swap (1.2 GiB swap in use at capture) |
| Disk | 22 GB ext4, 20 GB used, 2.1 GiB free (91%) |
| LXD | 5.21.9 LTS (snap), `dir` storage driver at `/var/snap/lxd/common/lxd/storage-pools/default` |
| GPU | `/dev/dri/card0` present on the host; not passed into `c4-desktop` |
| Host SSH | TCP `39822` |
| Public address | Redacted in this repository (`203.0.113.10`) |

The host also runs Xray/x-ui and several LXD proxy devices. Those are outside the
fingerprint browser scope and are documented only where they affect the container.

### Host containers

| Name | IPv4 | Role |
|---|---|---|
| `c1-proxy` | `10.0.43.10` | proxy |
| `c2-app` | `10.0.43.20` | application |
| `c3-backup` | `10.0.43.30` | backup |
| `c4-desktop` | `10.0.43.40` | browser desktop (this study) |

All four are on `lxdbr0` (`10.0.43.1/24`, IPv6 `fd42:43::/64`), managed by LXD's dnsmasq.

---

## 2. Container

| Property | Value |
|---|---|
| Name | `c4-desktop` |
| OS | Ubuntu 22.04.5 LTS (Jammy Jellyfish) |
| Image | `ubuntu 22.04 LTS amd64 (minimal release) (20261028)` |
| Virtualisation | LXC (`systemd-detect-virt = lxc`) |
| Kernel | Shares host `5.4.0-216-generic` |
| CPU limit | `limits.cpu = 2` |
| Memory limit | `limits.memory = 4096MB`, swap enabled |
| Visible memory | 3.8 GiB total, 0 B swap |
| Root disk device | `size=10GB`, pool `default`, `path=/` |
| Filesystem seen by `df` | 22 GB ext4, 20 GB used, 2.2 GiB free (91%) |
| GPU | No `/dev/dri`, no `/dev/snd` |
| Nesting | `security.nesting=true` (Docker inside LXD) |
| Syscall interception | `mknod`, `setxattr` |
| Hostname | `vps` |
| Address | `10.0.43.40/24` (eth0), IPv6 `fd42:43::216:3eff:fe41:db37/64` |
| MAC | `00:16:3e:xx:xx:xx` (masked) |
| DNS | `systemd-resolved` stub `127.0.0.53`, upstream `10.0.43.1` |
| Timezone | `Etc/UTC` |
| Locale | `C`, `C.utf8`, `en_US.utf8`, `POSIX` |
| SSH | Container sshd on `22`, published as host `2204` |
| Docker | 29.9.3, 4 bridge networks, 8 containers (goods24 stack) |

### 2.1 The disk number is misleading

The LXD device declares a 10 GB root disk, but the container sees the host's 22 GB ext4
filesystem. `df` reports 20 GB used and 2.1–2.2 GiB free. Chrome's
`navigator.storage.estimate()` reports a 10 GiB quota, which is consistent with the
declared device size, not with `df`.

Operationally: **treat free space as ~2 GiB**, not 10 GB. Chrome updates, profile growth,
Docker images, and logs all compete for the same underlying filesystem.

### 2.2 No GPU inside the container

The host exposes `/dev/dri/card0`, but the container has no `/dev/dri` node. Chrome
therefore cannot use hardware GL. Section 06 shows the consequences: headful WebGL is
blocklisted and the compositor runs in software.

A future profile runtime can either:

- pass `/dev/dri` into the container and use the host GPU (best visual realism, but the
  GPU string becomes host-specific and must be virtualised consistently), or
- keep software rendering and patch/spoof the WebGL surface at the Chromium level, or
- run the browser on a real desktop machine and keep the VPS as a control plane.

The current state — software rendering with WebGL disabled — is the worst of the three.

### 2.3 `/dev/shm`

`/dev/shm` is 1.9 GiB (half of RAM). The launchers still pass
`--disable-dev-shm-usage`, which forces Chrome to use `/tmp` for shared memory. That is
harmless here but worth revisiting: it changes crash behaviour and can slow down
renderer-heavy pages. It is not a fingerprint signal by itself.

---

## 3. LXD port mappings

The host publishes container services with LXD `proxy` devices. Current mappings:

| Host listen | Container target | Protocol | Purpose |
|---|---|---|---|
| `2204` | `10.0.43.40:22` | TCP | SSH |
| `3389` | `10.0.43.40:3389` | TCP + UDP | XRDP |
| `8088` | `10.0.43.40:8088` | TCP | goods24 web (Caddy), not 1Panel |
| `10041` | `10.0.43.40:10041` | TCP | VLESS Reality + Vision (TR residential) |
| `10042` | `10.0.43.40:10042` | UDP | Hysteria2 (TR residential) |
| `10042` | `10.0.43.40:10042` | TCP | **unused**; old direct node removed |
| `8088` (IPv6) | `10.0.43.40:8088` | TCP | IPv6 path for the web container |

Notes:

- `10042/TCP` still has a mapping but no listener. It should be removed when convenient;
  it is not part of the current node set.
- `8088` is served by the `goods24-web-1` Caddy container. 1Panel is **not** installed.
- The LXD devices use `nat=true`, so the nftables rules DNAT the public address to the
  container address and masquerade return traffic.

---

## 4. Docker inside the container

Docker 29.9.3 runs a production-like stack:

| Container | Image | Port | State |
|---|---|---|---|
| `goods24-web-1` | `ghcr.io/arifulcrypto/goods24-web:main` | `8088` | healthy |
| `goods24-api-1` | `ghcr.io/arifulcrypto/goods24-api:main` | internal 8000–8002, 8081 | healthy |
| `goods24-delivery-1` | same API image | internal | healthy |
| `goods24-redis-1` | `redis:7-alpine` | 6379 | healthy |
| `goods24-postgres-1` | `postgres:17-alpine` | 5432 | healthy |
| `goods24-bepusdt-1` | `v03413/bepusdt` | 8080 | running |
| `goods24-migrate-1` | API image | — | exited 0 |
| `goods24-seed-1` | API image | — | exited 0 |

Docker networks: `docker0` (`172.17.0.0/16`) plus four user bridges
`10.89.10.0/24`, `10.89.11.0/24`, `10.89.12.0/24`, `10.89.13.0/24`.

**Do not disturb this stack.** It shares CPU, RAM, and disk with the browser desktop and
is the main reason the container is memory- and disk-constrained. A production fingerprint
browser should not cohabit with a live commerce stack.

---

## 5. Resource pressure

At capture time:

```text
container: 3.8 GiB total, 2.0 GiB used, 1.4 GiB free, 406 MiB buff/cache
host:      3.8 GiB total, 2.9 GiB used, 123 MiB free, 782 MiB buff/cache, 1.2 GiB swap used
disk:      20 GB / 22 GB used (91%)
load:      ~1.15 (container), 2 vCPU
```

Chrome with 5 profiles and multiple renderer processes is already near the memory ceiling.
Adding automation, a build, or more concurrent profiles will trigger swapping and
renderer crashes. Capacity planning is a first-class requirement, not an afterthought.

---

## 6. Reproducing this layer

The host collector captures the LXD configuration, devices, networks, storage, and
nftables rules. See [`../../scripts/collect-host.sh`](../../scripts/collect-host.sh).

Sanitised evidence:

- [`../../inventory/host/00-system.txt`](../../inventory/host/00-system.txt)
- [`../../inventory/host/01-lxd.txt`](../../inventory/host/01-lxd.txt)
- [`../../inventory/host/02-network.txt`](../../inventory/host/02-network.txt)
- [`../../inventory/host/03-services.txt`](../../inventory/host/03-services.txt)
- [`../../inventory/host/04-ports.txt`](../../inventory/host/04-ports.txt)
