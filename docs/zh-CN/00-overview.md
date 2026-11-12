# 00 — 概览

**快照：** 2026-11-12
**目标：** `c4-desktop` LXD 容器，KVM 主机，东京机房
**目的：** 为 Linux 指纹浏览器建立事实基线

---

## 1. 本阶段是什么，不是什么

本阶段只做信息采集。它不设计最终产品，不确定 Chromium 分支策略，也不修改正在运行的

环境。采集脚本对系统配置是只读的；它们把报告写到 `/tmp`，然后复制出来。

输出刻意保持“枯燥”：版本、路径、端口、参数、配置文件状态，以及浏览器实测信号。这正是

重点。指纹工作失败，往往是因为一开始就对环境做了假设。

---

## 2. 本清单回答的问题

1. 浏览器实际看到的硬件和内核是什么，哪些是虚拟化的？
2. 哪个桌面栈在渲染浏览器，几何尺寸和 DPI 是多少？
3. 安装的是哪个 Chrome 版本，如何启动，应用了哪些策略？
4. 每个 Chrome 配置文件里有什么状态，它暴露了过去哪些代理路径？
5. 流量按进程、按端口分别去哪里，哪里可能泄漏？
6. 哪些 JavaScript 可见信号被暴露，哪些内部不一致？
7. 要在这台机器上构建或自动化 Chromium 产品，还缺什么？

---

## 3. 一张表看环境

| 项目 | 值 |
|---|---|
| 主机系统 | Ubuntu 20.04.6 LTS（Focal），内核 `5.4.0-216-generic` |
| 主机虚拟化 | KVM，QEMU Standard PC（i440FX），SeaBIOS 1.16.3 |
| 主机 CPU | 2 vCPU，AMD EPYC-Rome，2.3 GHz 基频，AVX2 |
| 主机内存 | 3.8 GiB RAM + 4 GiB swap |
| 主机磁盘 | 22 GB ext4，已用 91%，剩余约 2.1 GiB |
| LXD | 5.21.9 LTS，`dir` 存储池，4 个容器（`c1-proxy`、`c2-app`、`c3-backup`、`c4-desktop`） |
| 容器系统 | Ubuntu 22.04.5 LTS（Jammy），LXC，最小镜像 `20261028` |
| 容器限制 | 2 vCPU，4096 MB 内存，`security.nesting=true` |
| 容器磁盘 | 声明 10 GB 根设备；实际看到主机 22 GB ext4，已用 91% |
| 容器 GPU | **无** —— 缺少 `/dev/dri`，而主机有 `/dev/dri/card0` |
| 桌面 | XFCE 4.16，Xorg 1.21.1.4，xorgxrdp 0.2.17，XRDP 0.9.17，显示 `:10` |
| 浏览器 | Google Chrome `156.0.8078.79-1`（stable，amd64） |
| 配置文件 | 5 个目录，每个 20 MB – 313 MB |
| 字体 | 166 个文件，46 个家族 |
| 区域 / 时区 | 仅 `en_US.UTF-8` / `Etc/UTC` |
| 工具链 | gcc 11.4、g++ 11.4、make 4.3、Python 3.10、git 2.34、Docker 29.9.3 |
| 缺失工具链 | clang、cmake、ninja、node、npm、rust、go、java、chromedriver |

---

## 4. 五个关键结论

### 4.1 浏览器是软件渲染，而且 WebGL 不可用

在 `:10` 上运行的真实有头 Chrome，通过 `SystemInfo.getInfo` 报告：

```text
gpu.devices[0].deviceString = ANGLE (Mesa, llvmpipe (LLVM 15.0.7 256 bits), OpenGL 4.5 ...)
featureStatus.webgl        = disabled_off
featureStatus.webgpu       = disabled_off
featureStatus.gpu_compositing = disabled_software
featureStatus.2d_canvas    = disabled_software
```

页面级探针返回 `webglVendor: null`、`webglRenderer: null`。Chrome 日志写着

`WebGL1 blocklisted` 和 `WebGL2 blocklisted`。加上

`--enable-unsafe-swiftshader --ignore-gpu-blocklist` 后，WebGL 以

`ANGLE (Mesa, llvmpipe ...)` 恢复。无头 Chrome 则报告

`ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device ...), SwiftShader driver)`。

这是当前机器与可信桌面配置之间最大的差距。

### 4.2 网络身份与浏览器身份不一致

住宅出口在土耳其，但浏览器报告 `UTC` 和 `en-US`，系统也没有安装土耳其语区域设置。

一个同时比较 IP 地理位置、时区、`Intl` 区域和 `Accept-Language` 的站点，会立刻看到矛盾。

### 4.3 配置文件记得过去的国家

`Local State` 中的 `variations_country`：

| 配置文件 | `variations_country` |
|---|---|
| `google-chrome` | `jp` |
| `chrome-residential` | `ph` |
| `chrome-tr-proxy` | `tr` |
| `chrome-us-proxy` | `cn` |
| `google-chrome-headless` | 无 |

这个值不暴露给 JavaScript，但它是配置文件首次使用地的持久痕迹。它影响 Chrome 的
feature variations，也是复制、恢复或在代理之间迁移配置文件时的一致性信号。

### 4.4 隔离是“按进程”，不是“按环境”

每个配置文件有自己的 `--user-data-dir`，因此 cookie、缓存和存储是隔离的。但所有配置文件
共享：

- 同一个 Linux 用户（`root`）和同一个 X11 显示（`:10`）；
- 同一个 X 剪贴板和窗口管理器；
- 同一套字体、CPU 数量、内存、时区和区域设置；
- 同一个 Chrome 二进制和 crashpad 处理器；
- 同一个桌面几何尺寸。

站点读不到另一个配置文件的 cookie，但操作系统层面的指纹完全相同。对产品而言，
“配置文件”最终必须意味着独立环境，而不仅是独立目录。

### 4.5 这台机器不能构建 Chromium

Chromium 构建需要 clang、较新的工具链、约 100 GB 空闲磁盘和 16 GB 以上内存。这个容器
只有 gcc，没有 clang/cmake/ninja/Node，剩余 2.1 GiB，内存 3.8 GiB。构建应放在 GitHub
Actions、专用构建机或 WSL2 机器上，而不是这里。

---

## 5. 证据等级

| 等级 | 含义 | 示例 |
|---|---|---|
| 实测 | 快照期间由命令或探针捕获 | `navigator.hardwareConcurrency = 2` |
| 配置 | 从配置文件或 systemd 单元读取 | `WebRtcIPHandlingPolicy = disable_non_proxied_udp` |
| 推断 | 基于测量值推理，未直接观测 | “WebGL 缺失很容易被检测” |
| 计划 | 后续阶段的设计决定 | “使用确定性的配置文件种子” |

[`../../inventory/`](../../inventory/) 下的清单文件是主要证据。本文档只做总结，不替代它们。

---

## 6. 其余文档的组织方式

| 文档 | 主题 |
|---|---|
| `01-host-and-container.md` | 主机、LXD、容器限制、存储、端口映射 |
| `02-desktop-stack.md` | XRDP、Xorg、XFCE、显示、输入、字体、区域设置 |
| `03-browser-installation.md` | Chrome 包、二进制、策略、启动脚本、参数 |
| `04-chrome-profiles.md` | 配置文件大小、状态、扩展、`variations_country` |
| `05-proxy-and-network.md` | 代理链、公网节点、DNS、泄漏控制、延迟 |
| `06-fingerprint-surface.md` | JavaScript 可见信号、有头与无头对比、差距分析 |
| `07-build-toolchain.md` | 已安装什么、缺什么、构建选项 |
| `08-architecture.md` | 指纹浏览器的目标设计 |
| `09-roadmap.md` | 从清单到 Chromium 分支的分阶段计划 |
| `10-collection-method.md` | 脚本、命令、可复现性、脱敏 |
| `11-ethics.md` | 预期用途与边界 |

---

## 7. 下一步

1. 保持这份快照不可变；任何新采集都要标注日期。
2. 在增加更多配置文件之前，先加入自动一致性检查。
3. 把构建迁出这台 VPS。
4. 决定第一版产品是用“原版 Chrome + 监管程序”，还是等待 Chromium 分支。证据表明，
   原版 Chrome 可以解决网络和配置文件隔离，但**不能**在不打补丁或不加 GPU 的情况下解决
   WebGL、时区一致性和字体一致性。
