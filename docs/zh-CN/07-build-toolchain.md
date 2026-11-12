# 07 — 构建工具链与 Chromium 构建选项

当前 VPS 是运行时，不是构建机。本文档记录工具链缺口，并给出生产 Chromium 分支的现实选项。

---

## 1. 已安装什么

| 工具 | 版本 | 存在 |
|---|---|---|
| gcc | 11.4.0（Ubuntu 11.4.0-1ubuntu1~22.04.3） | 是 |
| g++ | 11.4.0 | 是 |
| make | GNU Make 4.3 | 是 |
| Python | 3.10.12 | 是 |
| pip | 22.0.2 | 是 |
| git | 2.34.1 | 是 |
| Docker | 29.9.3 | 是 |
| containerd | 2.4.2 | 是 |
| pkg-config | — | **否** |
| clang / clang++ | — | **否** |
| cmake | — | **否** |
| ninja | — | **否** |
| node / npm / pnpm / yarn | — | **否** |
| rustc / cargo | — | **否** |
| go | — | **否** |
| java / javac | — | **否** |
| chromedriver | — | **否** |

已安装的 Python 包是 Ubuntu 默认值（Babel、cryptography、dbus-python、Jinja2、jsonschema
等），不是浏览器自动化栈。没有 Playwright、Puppeteer、Selenium 或 websocket 客户端。

---

## 2. Chromium 构建需要什么

现代 Chromium 检出和构建通常需要：

| 资源 | 需求 | 本机 |
|---|---|---|
| 磁盘 | 约 100 GB 空闲（源码 + 构建 + 缓存） | **2.1 GiB** |
| 内存 | 推荐 16 GB+；窄构建最低 8 GB | **3.8 GiB** |
| CPU | 推荐 8+ 核；2 核会耗时很多小时 | **2 vCPU** |
| 系统 | Linux，较新 glibc；Ubuntu 22.04 可接受 | Ubuntu 22.04 |
| 工具链 | clang、ninja、Python 3、pkg-config、部分工具需要 Node | 大多缺失 |
| `depot_tools` | 需要 `gclient`、`gn`、`autoninja` | 缺失 |

磁盘是硬阻塞。即使是裁剪目标集的组件构建也放不进 2 GiB。在这台 VPS 上编译不可行。

---

## 3. 选项

### 选项 A —— GitHub Actions 托管运行器

**优点：** 无需维护基础设施；可复现；公共仓库有免费分钟数。
**缺点：** 标准运行器约 14 GB SSD 空闲，不够完整 Chromium 构建。更大运行器要付费。构建慢
且排队。

适用：

- 文档检查和脱敏检查（本仓库已配置）；
- 补丁应用测试；
- 针对预构建 Chromium 的小型单元测试；
- 不适合完整浏览器构建，除非配置更大运行器。

### 选项 B —— GitHub Actions 更大运行器 / 自托管运行器

**优点：** ≥100 GB 磁盘、更多核心、持久 ccache、完全控制。
**缺点：** 成本、维护、构建不受信任补丁的运行器安全。

这是第一次分支构建的推荐路径。自托管运行器可以是专用机器（不是这台 VPS），8–16 核、
32 GB 内存、500 GB NVMe。

### 选项 C —— 专用构建服务器

独立 Linux 机器或云 VM：

- 8–16 vCPU；
- 32 GB 内存；
- 500 GB NVMe；
- Ubuntu 22.04/24.04；
- `depot_tools`、clang、ninja、Node、ccache。

构建一次，发布产物，把 VPS 保留为运行时/控制平面。这是最清晰的关注点分离。

### 选项 D —— 用户 Windows 机器上的 WSL2

**优点：** 本地迭代、无云成本、一台机器可构建 Windows 和 Linux。
**缺点：** 磁盘/内存消耗大；WSL2 I/O 较慢；Windows 构建仍需要 Windows 工具链和独立检出。

适合开发和后续 Windows 目标，不适合作为主要 Linux CI。

### 选项 E —— 在这台 VPS 上构建

不可行。不要尝试在这里安装工具链并构建；它会填满磁盘并破坏在线服务。

---

## 4. 推荐构建架构

```mermaid
flowchart LR
    Dev[开发者 / 补丁分支] --> CI[GitHub Actions 或自托管运行器]
    CI -->|gclient sync| SRC[Chromium 源码缓存]
    SRC -->|gn + autoninja| OUT[构建输出]
    OUT -->|签名 + 打包| ART[产物 / 发布]
    ART --> VPS[运行时 VPS / 配置文件主机]
    VPS -->|遥测 + 自测| OBS[可观测性]
```

原则：

1. **永远不要在运行时 VPS 上构建。** 磁盘和内存已经很紧。
2. **固定 Chromium 版本。** 分支名不是版本。记录 commit hash。
3. **积极缓存。** `ccache`/`sccache` 和持久 `depot_tools` 检出能显著缩短构建时间。
4. **只构建要发布的东西。** 完整 Chrome 构建非常庞大；自定义浏览器可以禁用不需要的目标，
   但在补丁集稳定前不要过度优化。
5. **签名并验证产物。** 浏览器是高价值二进制；未签名构建不可发布。
6. **保留回滚构建。** 每个版本都应有上一个已知良好产物。

---

## 5. 分支策略

### 5.1 Chromium 与 Chrome

| 方面 | Chromium | Google Chrome |
|---|---|---|
| 许可证 | BSD 风格，开源 | 专有 |
| 品牌 | Chromium | Google |
| 专有编解码器 | 默认不含 | 含 |
| Widevine | 不含 | 含 |
| 同步 / Google 服务 | 不含 | 含 |
| 构建 | 自行构建 | Google 构建 |
| 指纹基线 | 更“通用” | 更常见 |

对指纹浏览器，Chromium 是实用基础。如果产品需要视频播放（很多站点需要），专有编解码器和
Widevine 可以后续加入。编解码器缺失本身可检测（`canPlayType`），所以要尽早决定。

### 5.2 补丁面

保持补丁集小而分层：

| 层 | 示例 | 维护成本 |
|---|---|---|
| 构建配置 | 品牌、参数、功能、编解码器 | 低 |
| 浏览器策略 | 默认值、配置文件处理、代理 | 低 |
| 网络 | DNS、代理、IPv6、泄漏防护 | 中 |
| Blink | UA、语言、屏幕、字体、canvas、WebGL | 高 |
| GPU | 渲染器字符串、参数虚拟化 | 高 |
| 自动化 | CDP 策略、无头行为 | 中 |

优先顺序：

1. 命令行参数或功能开关；
2. 托管策略；
3. `chrome/browser/` 或 `components/` 中的小补丁；
4. Blink/GPU 补丁。

每个补丁都必须有测试和 rebase 说明。Chromium 大约每四周发布一次；无法低成本 rebase 的
补丁会变成技术债。

### 5.3 候选补丁点

路径会随里程碑变化；在固定版本上核实。典型区域：

| 区域 | 路径（示意） |
|---|---|
| UA / UA-CH | `components/embedder_support/user_agent_utils.cc` |
| Navigator | `third_party/blink/renderer/core/frame/navigator.cc` |
| Screen | `third_party/blink/renderer/core/frame/screen.cc` |
| WebGL | `third_party/blink/renderer/modules/webgl/` |
| Canvas | `third_party/blink/renderer/modules/canvas/` |
| Audio | `third_party/blink/renderer/modules/webaudio/` |
| Fonts | `third_party/blink/renderer/platform/fonts/` |
| Timezone | `third_party/blink/renderer/core/timezone/` |
| Client hints | `third_party/blink/renderer/core/loader/` 和 `services/network/` |
| Proxy / DNS | `services/network/`、`net/dns/` |
| Profile / policy | `chrome/browser/profiles/`、`components/policy/` |
| Switches | `content/public/common/content_switches.cc` |

比直接修补 Blink 更安全的替代方案是在 **Mojo/网络服务边界**和**渲染器进程启动**层注入，
那里表面更小。权衡是某些值（canvas、字体）本质上在渲染器侧。

### 5.4 构建配置

- 发布用 `is_debug = false`、`is_component_build = false`。
- `symbol_level = 1`，获得可用崩溃栈而不过分增大二进制。
- 初期 `enable_nacl = false`、`enable_widevine = false`。
- 品牌：设置 `chrome/browser/resources` 和 `BRANDING` 文件；不要发布 Google 商标。
- 编解码器：如需要，`proprietary_codecs = true` + `ffmpeg_branding = "Chrome"`。
- 官方构建：`is_official_build = true` 获得优化发布版。
- 签名：平台特定；Linux 包可以是 `.deb`/`.rpm`/AppImage。

---

## 6. CI 设计

最小流水线：

```text
lint（文档、脱敏）
  → 补丁应用（git apply --check）
  → 配置（gn gen）
  → 编译（autoninja，缓存）
  → 打包
  → 冒烟测试（启动、版本、指纹探针）
  → 发布产物
```

冒烟测试应尽可能有头运行浏览器；无头不具代表性（见 `06-fingerprint-surface.md`）。无 GPU
的 CI 运行器会复现与本 VPS 相同的 WebGL 问题，因此要么传 GPU，要么用 SwiftShader 参数测试。

---

## 7. 之后的 Windows 与 WSL

简报提到可能的 Windows 目标。要规划，但不要阻塞 Linux 产品：

- Chromium 的 Windows 构建需要 Visual Studio、Windows SDK 和 Windows 检出；不能从 Linux
  交叉编译。
- WSL2 对 Linux 侧和开发者一致性有用，但不能生成 Windows 二进制。
- Windows 产物需要 Windows 运行器（自托管或 GitHub 托管）。
- 指纹值（字体、GPU、屏幕、媒体设备）是平台特定的；配置文件 schema 必须从第一天就
  平台感知。

---

## 8. 成本与时间估算（数量级）

| 项目 | 估算 |
|---|---|
| 首次完整检出 | 快速链路 30–60 分钟，约 40 GB |
| 首次构建（16 核） | 1–3 小时 |
| 增量构建 | 5–30 分钟 |
| 每个 Chromium 里程碑的补丁 rebase | 1–5 天，取决于补丁面 |
| CI 运行器 | 16 vCPU / 32 GB / 500 GB，月成本不定 |
| 存储 | 最低 500 GB NVMe |

这些是规划数字，不是承诺。在选定的构建机上实测。

---

## 9. 决定

下一阶段：

1. 把这台 VPS 保留为**运行时和测量**主机。
2. 配置**独立构建机**（自托管或更大 CI 运行器）。
3. 先用**原版 Chrome + 监管程序**验证配置文件契约。
4. 等自测工具和一致性清单稳定后，再分支 Chromium。
5. 先构建 Linux x64；Linux 补丁集可维护后，再加 Windows x64。

---

## 10. 证据

- [`../../inventory/container/12-toolchain.txt`](../../inventory/container/12-toolchain.txt)
- [`../../inventory/container/11-software.txt`](../../inventory/container/11-software.txt)
- [`../../inventory/host/00-system.txt`](../../inventory/host/00-system.txt)
