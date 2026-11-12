# 01 — 主机与容器

本文档描述物理/虚拟边界：KVM 主机、LXD 层、`c4-desktop` 容器、资源限制、存储，以及

对外暴露服务的端口映射。

---

## 1. 主机

| 属性 | 值 |
|---|---|
| 主机名 | `tql` |
| 系统 | Ubuntu 20.04.6 LTS（Focal Fossa） |
| 内核 | `5.4.0-216-generic`（SMP Fri Apr 11 2025） |
| 虚拟化 | KVM 客户机，QEMU Standard PC（i440FX + PIIX），SeaBIOS 1.16.3 |
| CPU | 2 vCPU，AMD EPYC-Rome，2.3 GHz，AVX2，32 MiB L3 |
| 内存 | 3.8 GiB RAM，4.0 GiB swap（采集时已用 1.2 GiB swap） |
| 磁盘 | 22 GB ext4，已用 20 GB，剩余 2.1 GiB（91%） |
| LXD | 5.21.9 LTS（snap），`dir` 存储驱动，位于 `/var/snap/lxd/common/lxd/storage-pools/default` |
| GPU | 主机有 `/dev/dri/card0`，未传入 `c4-desktop` |
| 主机 SSH | TCP `39822` |
| 公网地址 | 本仓库中已脱敏（`203.0.113.10`） |

主机还运行 Xray/x-ui 和若干 LXD proxy 设备。它们不属于指纹浏览器的范围，只在影响容器时
记录。

### 主机容器

| 名称 | IPv4 | 角色 |
|---|---|---|
| `c1-proxy` | `10.0.43.10` | 代理 |
| `c2-app` | `10.0.43.20` | 应用 |
| `c3-backup` | `10.0.43.30` | 备份 |
| `c4-desktop` | `10.0.43.40` | 浏览器桌面（本次研究对象） |

四个容器都在 `lxdbr0`（`10.0.43.1/24`，IPv6 `fd42:43::/64`）上，由 LXD 的 dnsmasq 管理。

---

## 2. 容器

| 属性 | 值 |
|---|---|
| 名称 | `c4-desktop` |
| 系统 | Ubuntu 22.04.5 LTS（Jammy Jellyfish） |
| 镜像 | `ubuntu 22.04 LTS amd64 (minimal release) (20261028)` |
| 虚拟化 | LXC（`systemd-detect-virt = lxc`） |
| 内核 | 共享主机 `5.4.0-216-generic` |
| CPU 限制 | `limits.cpu = 2` |
| 内存限制 | `limits.memory = 4096MB`，启用 swap |
| 可见内存 | 总计 3.8 GiB，swap 0 B |
| 根磁盘设备 | `size=10GB`，存储池 `default`，`path=/` |
| `df` 看到的文件系统 | 22 GB ext4，已用 20 GB，剩余 2.2 GiB（91%） |
| GPU | 无 `/dev/dri`，无 `/dev/snd` |
| Nesting | `security.nesting=true`（LXD 内运行 Docker） |
| 系统调用拦截 | `mknod`、`setxattr` |
| 主机名 | `vps` |
| 地址 | `10.0.43.40/24`（eth0），IPv6 `fd42:43::216:3eff:fe41:db37/64` |
| MAC | `00:16:3e:xx:xx:xx`（公开副本已掩码） |
| DNS | `systemd-resolved` stub `127.0.0.53`，上游 `10.0.43.1` |
| 时区 | `Etc/UTC` |
| 区域 | `C`、`C.utf8`、`en_US.utf8`、`POSIX` |
| SSH | 容器 sshd 监听 `22`，通过主机 `2204` 发布 |
| Docker | 29.9.3，4 个桥接网络，8 个容器（goods24 栈） |

### 2.1 磁盘数字有误导性

LXD 设备声明 10 GB 根磁盘，但容器看到的是主机 22 GB ext4 文件系统。`df` 报告已用 20 GB，
剩余 2.1–2.2 GiB。Chrome 的 `navigator.storage.estimate()` 报告 10 GiB 配额，这与声明的
设备大小一致，而不是与 `df` 一致。

运维上：**把可用空间当作约 2 GiB**，不是 10 GB。Chrome 更新、配置文件增长、Docker 镜像
和日志都在争抢同一个底层文件系统。

### 2.2 容器内没有 GPU

主机暴露 `/dev/dri/card0`，但容器没有 `/dev/dri` 节点，因此 Chrome 无法使用硬件 GL。
第 06 节展示后果：有头 WebGL 被列入黑名单，合成器走软件路径。

未来的配置文件运行时可以：

- 把 `/dev/dri` 传入容器并使用主机 GPU（视觉真实度最好，但 GPU 字符串会变成主机特定值，
  必须一致地虚拟化），或
- 保持软件渲染，并在 Chromium 层修补/伪造 WebGL 表面，或
- 在真实桌面上运行浏览器，把 VPS 只作为控制平面。

当前状态——软件渲染且 WebGL 被禁用——是三种方案里最差的。

### 2.3 `/dev/shm`

`/dev/shm` 为 1.9 GiB（内存的一半）。启动脚本仍然传 `--disable-dev-shm-usage`，强制 Chrome
使用 `/tmp` 存放共享内存。这里无害，但值得重新考虑：它改变崩溃行为，并可能拖慢渲染密集
页面。它本身不是指纹信号。

---

## 3. LXD 端口映射

主机通过 LXD `proxy` 设备发布容器服务。当前映射：

| 主机监听 | 容器目标 | 协议 | 用途 |
|---|---|---|---|
| `2204` | `10.0.43.40:22` | TCP | SSH |
| `3389` | `10.0.43.40:3389` | TCP + UDP | XRDP |
| `8088` | `10.0.43.40:8088` | TCP | goods24 web（Caddy），不是 1Panel |
| `10041` | `10.0.43.40:10041` | TCP | VLESS Reality + Vision（TR 住宅） |
| `10042` | `10.0.43.40:10042` | UDP | Hysteria2（TR 住宅） |
| `10042` | `10.0.43.40:10042` | TCP | **未使用**；旧直连节点已移除 |
| `8088`（IPv6） | `10.0.43.40:8088` | TCP | Web 容器的 IPv6 路径 |

说明：

- `10042/TCP` 仍有映射，但没有监听者。方便时应移除；它不属于当前节点集合。
- `8088` 由 `goods24-web-1` Caddy 容器提供。**没有**安装 1Panel。
- LXD 设备使用 `nat=true`，因此 nftables 规则把公网地址 DNAT 到容器地址，并对返回流量
  做 masquerade。

---

## 4. 容器内的 Docker

Docker 29.9.3 运行一个类生产栈：

| 容器 | 镜像 | 端口 | 状态 |
|---|---|---|---|
| `goods24-web-1` | `ghcr.io/arifulcrypto/goods24-web:main` | `8088` | healthy |
| `goods24-api-1` | `ghcr.io/arifulcrypto/goods24-api:main` | 内部 8000–8002、8081 | healthy |
| `goods24-delivery-1` | 同一 API 镜像 | 内部 | healthy |
| `goods24-redis-1` | `redis:7-alpine` | 6379 | healthy |
| `goods24-postgres-1` | `postgres:17-alpine` | 5432 | healthy |
| `goods24-bepusdt-1` | `v03413/bepusdt` | 8080 | running |
| `goods24-migrate-1` | API 镜像 | — | exited 0 |
| `goods24-seed-1` | API 镜像 | — | exited 0 |

Docker 网络：`docker0`（`172.17.0.0/16`）加四个用户桥接
`10.89.10.0/24`、`10.89.11.0/24`、`10.89.12.0/24`、`10.89.13.0/24`。

**不要干扰这个栈。** 它与浏览器桌面共享 CPU、内存和磁盘，也是容器内存和磁盘受限的主要
原因。生产级指纹浏览器不应与在线电商栈共处一室。

---

## 5. 资源压力

采集时：

```text
container: 3.8 GiB total, 2.0 GiB used, 1.4 GiB free, 406 MiB buff/cache
host:      3.8 GiB total, 2.9 GiB used, 123 MiB free, 782 MiB buff/cache, 1.2 GiB swap used
disk:      20 GB / 22 GB used (91%)
load:      ~1.15 (container), 2 vCPU
```

Chrome 加上 5 个配置文件和多个渲染进程，已经接近内存上限。再加入自动化、构建或更多并发
配置文件，会触发 swap 和渲染进程崩溃。容量规划是一等需求，不是事后补充。

---

## 6. 复现这一层

主机采集脚本捕获 LXD 配置、设备、网络、存储和 nftables 规则。见
[`../../scripts/collect-host.sh`](../../scripts/collect-host.sh)。

脱敏证据：

- [`../../inventory/host/00-system.txt`](../../inventory/host/00-system.txt)
- [`../../inventory/host/01-lxd.txt`](../../inventory/host/01-lxd.txt)
- [`../../inventory/host/02-network.txt`](../../inventory/host/02-network.txt)
- [`../../inventory/host/03-services.txt`](../../inventory/host/03-services.txt)
- [`../../inventory/host/04-ports.txt`](../../inventory/host/04-ports.txt)
