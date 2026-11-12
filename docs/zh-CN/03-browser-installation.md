# 03 — 浏览器安装与启动脚本

本文档覆盖 Chrome 构建、安装布局、策略、启动脚本，以及影响浏览器行为和指纹的具体参数。

---

## 1. 已安装的浏览器

| 属性 | 值 |
|---|---|
| 包 | `google-chrome-stable 156.0.8078.79-1`（amd64） |
| 二进制 | `/opt/google/chrome/chrome`（302,792,008 字节） |
| 包装脚本 | `/usr/bin/google-chrome`、`/usr/bin/google-chrome-stable` |
| 版本 | `Google Chrome 156.0.8078.79` |
| 通道 | stable |
| 安装日期 | 2026-10-28（二进制时间戳），包安装于 2026-10-31 |
| `chrome-sandbox` | setuid root，模式 `4755` |
| 崩溃处理器 | `chrome_crashpad_handler` |
| 管理服务 | 存在 `chrome-management-service` |
| `chromedriver` | **未安装** |
| 远程调试 | 任何启动脚本都**未启用** |

没有 Chromium、Edge 或 Firefox。Chrome 是唯一的浏览器。

### 为什么重要

- Google Chrome 包含 Chromium 没有的专有编解码器和 Google 品牌。未来基于 Chromium 的
  分支会改变 UA、编解码器支持和部分功能行为，除非把这些补回去。
- 版本很新（156），而且会继续变化。每个指纹快照都必须记录精确版本；Chrome 更新可能改变
  UA-CH、功能开关以及 canvas/WebGL 行为。
- setuid 沙箱已安装但未使用，因为每个启动脚本都传 `--no-sandbox`。因此沙箱在实际运行中
  不是安全边界。

---

## 2. 策略

只有一个托管策略：

```json
// /etc/opt/chrome/policies/managed/webrtc_policy.json
{
  "WebRtcIPHandlingPolicy": "disable_non_proxied_udp"
}
```

这强制 WebRTC 只使用经代理的 UDP，并阻止直接的主机候选泄漏。这是良好基线。但没有以下
策略：

- URL 允许/阻止列表；
- 扩展强制安装或黑名单；
- `UserDataDir`；
- `ProxySettings`（代理通过命令行传入）；
- `DeveloperToolsAvailability`；
- `BrowserSignin`、同步或指标。

生产部署应集中管理这些，而不是依赖 shell 脚本。Chrome 策略更难被用户覆盖，并可在
`chrome://policy` 查看。

---

## 3. 启动脚本

桌面上有三个 shell 启动脚本，每个代理配置文件一个，另有桌面快捷方式。它们遵循同一模板。

| 启动脚本 | 配置文件 | 代理 | CSS class | 启动 URL |
|---|---|---|---|---|
| `start_us_proxy_chrome.sh` | `~/.config/chrome-us-proxy` | `http://127.0.0.1:2080` | `us-proxy-chrome` | `ipinfo.io`、`claude.ai` |
| `start_residential_chrome.sh` | `~/.config/chrome-residential` | `http://127.0.0.1:18080` | `residential-proxy-chrome` | `ipinfo.io`、`ippure.com` |
| `start_tr_proxy_chrome.sh` | `~/.config/chrome-tr-proxy` | `http://127.0.0.1:18081` | `tr-proxy-chrome` | `ipinfo.io`、`ippure.com` |

默认的 `google-chrome` 配置文件（`~/.config/google-chrome`）没有专用启动脚本，用于临时
浏览。

### 公共参数

```bash
google-chrome-stable \
  --no-sandbox \
  --disable-dev-shm-usage \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir="$USER_DATA_DIR" \
  --class="$CLASS" \
  --lang=en-US \
  --proxy-server="http://127.0.0.1:<port>" \
  --proxy-bypass-list="127.0.0.1,localhost" \
  --disable-quic \
  --webrtc-ip-handling-policy=disable_non_proxied_udp \
  --enforce-webrtc-ip-permission-check \
  --disable-features=DnsOverHttps \
  "$@"
```

| 参数 | 作用 | 指纹/安全说明 |
|---|---|---|
| `--no-sandbox` | 禁用 Chromium 沙箱 | 安全风险；`SystemInfo` 报告 `sandboxed: false` |
| `--disable-dev-shm-usage` | 使用 `/tmp` 而非 `/dev/shm` | 不是指纹信号；这里 `/dev/shm` 有 1.9 GiB，参数没有必要 |
| `--no-first-run` | 跳过首次运行 | 保持配置文件干净 |
| `--no-default-browser-check` | 跳过默认浏览器提示 | 外观问题 |
| `--user-data-dir` | 隔离配置文件状态 | 当前主要隔离机制 |
| `--class` | 设置 X11 WM class | 窗口管理器可见，网站不可见 |
| `--lang=en-US` | UI 与 `navigator.language` 默认值 | 与非英语代理地理位置冲突 |
| `--proxy-server` | 通过本地桥接路由 HTTP(S) | 本身不覆盖 DNS、IPv6 或非 HTTP 协议 |
| `--proxy-bypass-list` | 仅 localhost 绕过代理 | 对本地桥接正确；保持最小 |
| `--disable-quic` | 阻止 QUIC/UDP 绕过 | 对不能承载 UDP 的 HTTP 代理至关重要 |
| `--webrtc-ip-handling-policy` | 限制 WebRTC 只走代理 UDP | 与托管策略一致 |
| `--enforce-webrtc-ip-permission-check` | WebRTC IP 暴露需要权限 | 额外加固 |
| `--disable-features=DnsOverHttps` | 禁用 Chrome DoH | 强制系统 DNS，而系统 DNS **不是**按配置文件的 |

### 注释与现实不符

`start_tr_proxy_chrome.sh` 的文件头注释写着“tr-TR UI”，但实际参数是 `--lang=en-US`，
环境是 `LANG=en_US.UTF-8`。因此 TR 配置文件在通过土耳其出口的同时，运行英语 UI 和英语
`navigator.languages`。这是文档错误，也是指纹不一致。

### 缺失的参数

当前启动脚本**没有**设置：

- `--disable-blink-features=AutomationControlled`（只在加入自动化时相关）；
- `--force-device-scale-factor`（DPR 由 96 DPI 显示固定为 1）；
- `--window-size` / `--window-position`（几何尺寸从会话继承）；
- `--user-agent`（UA 是真实 Chrome UA，这是好事）；
- `--accept-lang`（语言从系统继承）；
- `--host-resolver-rules`（没有按配置文件的 DNS 映射）；
- `--disable-ipv6`（IPv6 默认路由仍然存在）；
- 任何时区覆盖（Chrome 没有这种参数）。

---

## 4. 进程与权限模型

所有 Chrome 进程以 `root` 运行：

```text
root  /opt/google/chrome/chrome --no-sandbox ... --user-data-dir=/root/.config/chrome-us-proxy
root  /opt/google/chrome/chrome --type=zygote --no-zygote-sandbox --no-sandbox ...
root  /opt/google/chrome/chrome --type=gpu-process ... --no-sandbox ...
root  /opt/google/chrome/chrome --type=renderer ... --no-sandbox ...
```

后果：

- 渲染进程被攻破就是容器的 root 被攻破。
- Crashpad 即使对非默认配置文件也使用 `/root/.config/google-chrome/Crash Reports`，因此
  崩溃元数据跨配置文件共享。
- GPU 进程无沙箱运行（`SystemInfo` 中 `sandboxed: false`）。
- 配置文件目录权限不一致：`google-chrome` 是 `0700`，而 `chrome-*` 是 `0755`。任何本地
  用户都能读取后者。

对单租户研究 VPS 可以接受，但对托管不受信任配置文件或多客户的产品不行。

---

## 5. 有头与无头

采集了两个探针：

| 信号 | 有头（`:10`，XRDP） | 无头（`--headless=new`） |
|---|---|---|
| User-Agent | `Chrome/156.0.0.0` | `HeadlessChrome/156.0.0.0` |
| 屏幕 | `1280×720`，可用 `1280×693` | `800×600` |
| 窗口 | 外部 `1279×719`，内部 `1271×572` | 视口 `800×600` |
| WebGL | **禁用 / null** | 通过 ANGLE 使用 SwiftShader |
| `webdriver` | `false` | `false` |
| 时区 | `UTC` | `UTC` |
| 语言 | `en-US,en` | `en-US,en` |
| 媒体设备 | 无 | 无 |

有头探针使用临时配置文件和本地 CDP 端口，仅用于测量，没有修改现有配置文件。无头探针
使用 `--disable-gpu`，因此回退到 SwiftShader，而不是复现有头的黑名单状态。

**不要把无头结果当作真实桌面的代理。** UA、屏幕和 WebGL 值都不同。任何指纹测试都必须
说明测量的是哪种模式。

---

## 6. 浏览器缺少什么

| 缺失能力 | 影响 |
|---|---|
| `chromedriver` | 开箱没有 Selenium/Playwright 自动化 |
| CDP 端口 | 没有外部自动化或检查 |
| 按配置文件时区 | 所有配置文件共享 `UTC` |
| 按配置文件区域 | 所有配置文件共享 `en-US` |
| 按配置文件字体 | 所有配置文件共享 46 个家族 |
| 按配置文件显示 | 所有配置文件共享 `:10` 的 1280×720 |
| WebGL | 有头上下文为 `null` |
| GPU | 仅软件渲染 |
| 沙箱 | 启动时禁用 |
| 集中策略 | 只有 WebRTC 受管理 |

这些是架构和路线图文档的具体输入。

---

## 7. 证据

- [`../../inventory/container/05-chrome.txt`](../../inventory/container/05-chrome.txt)
- [`../../inventory/container/06-profiles.md`](../../inventory/container/06-profiles.md)
- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
- [`../../inventory/container/gpu-info.json`](../../inventory/container/gpu-info.json)
- [`../../inventory/container/18-headless-probe.json`](../../inventory/container/18-headless-probe.json)
- [`../../configs/chrome/`](../../configs/chrome/)
