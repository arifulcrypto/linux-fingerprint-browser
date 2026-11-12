# 06 — 指纹面

本文档记录浏览器实际暴露的内容，比较有头和无头模式，并识别对指纹浏览器重要的缺口。

所有值于 2026-11-12 从 Chrome 156.0.8078.79 捕获。“可检测性”评级是**推断**，基于值有多

不寻常，而不是商业反机器人供应商的实测结果。

---

## 1. 探针方法

使用两个探针：

1. **有头** —— 在显示 `:10` 上启动临时 Chrome 配置文件，带
   `--remote-debugging-port=9222` 和 `--remote-allow-origins=*`，导航到本地 `file://`
   页面。页面计算一个 JSON 对象（UA、UA-CH、屏幕、WebGL、字体、媒体设备、音频、存储、
   `Intl` 等）并暴露为 `window.__fp`。一个小型 CDP 客户端读取该值。现有配置文件未被修改。
2. **无头** —— `google-chrome --headless=new --no-sandbox --disable-gpu
   --disable-dev-shm-usage --dump-dom file:///tmp/fp-probe.html`，使用一次性配置文件。

有头探针是真实桌面的参考。无头结果只用于展示模式对指纹的改变有多大。

---

## 2. 有头值

### 2.1 User agent 与 client hints

```text
navigator.userAgent =
  Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
  (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36

navigator.platform = Linux x86_64
navigator.vendor   = Google Inc.
navigator.product  = Gecko
navigator.productSub = 20030107

UA-CH brands = Not:A-Brand 8, Chromium 156, Google Chrome 156
UA-CH platform = Linux
UA-CH architecture = x86, bitness = 64, wow64 = false
UA-CH platformVersion = "" (Linux 上为空)
UA-CH model = ""
UA-CH uaFullVersion = 156.0.8078.79
```

这是正常的 Linux Chrome 156 身份。它与二进制和操作系统一致，但如果预期人格是 Windows，
它**不**与土耳其住宅用户一致。产品必须决定 Linux 是否是可接受的人格，还是分支需要呈现
Windows UA-CH。

### 2.2 屏幕与窗口

| 信号 | 值 |
|---|---|
| `screen.width × height` | `1280 × 720` |
| `screen.availWidth × availHeight` | `1280 × 693` |
| `screen.availLeft / availTop` | `0 / 27` |
| `window.outerWidth × outerHeight` | `1279 × 719` |
| `window.innerWidth × innerHeight` | `1271 × 572` |
| `devicePixelRatio` | `1` |
| `colorDepth / pixelDepth` | `24 / 24` |
| `screen.orientation` | `landscape-primary / 0` |
| `visualViewport` | `1271 × 572`，scale `1` |

27 px 的顶部内边距是 XFCE 面板。1280×720 屏幕由 XRDP 固定。每个配置文件都继承它。

### 2.3 硬件与存储

| 信号 | 值 | 说明 |
|---|---|---|
| `hardwareConcurrency` | `2` | 与 2 vCPU 限制一致 |
| `deviceMemory` | `4` | Chrome 上限/报告 4 GiB |
| `maxTouchPoints` | `0` | 无触摸 |
| `navigator.storage.estimate().quota` | `10 GiB` | 与 10 GB LXD 根设备一致 |
| `navigator.storage.estimate().usage` | `0` | 全新临时配置文件 |
| `navigator.connection.effectiveType` | `4g` | Network Information API |
| `navigator.connection.downlink` | `1.5` | 合成/取整值 |
| `navigator.connection.rtt` | `100` | 合成/取整值 |
| `navigator.connection.saveData` | `false` | — |

`deviceMemory=4` 和 `hardwareConcurrency=2` 与小 VPS 内部一致，但对现代桌面偏低。声称是
游戏 PC 的人格会与此矛盾。

### 2.4 GPU 与 WebGL

有头浏览器的 `SystemInfo.getInfo`：

```text
vendorString  = Google Inc. (Mesa)
deviceString  = ANGLE (Mesa, llvmpipe (LLVM 15.0.7 256 bits),
                OpenGL 4.5 (Core Profile) Mesa 23.2.1-1ubuntu3.1~22.04.4)
driverVendor  = Mesa
driverVersion = 23.2.1
glRenderer    = ANGLE (Mesa, llvmpipe ...)
glVendor      = Google Inc. (Mesa)
hardwareSupportsVulkan = false
sandboxed     = false
```

功能状态：

| 功能 | 状态 |
|---|---|
| `webgl` | `disabled_off` |
| `webgl2` | `disabled_off` |
| `webgpu` | `disabled_off` |
| `gpu_compositing` | `disabled_software` |
| `2d_canvas` | `disabled_software` |
| `rasterization` | `disabled_software` |
| `video_decode` / `video_encode` | `disabled_software` |
| `vulkan` | `disabled_off` |
| `opengl` | `disabled_off` |

页面级结果：

```json
{
  "webglVendor": null,
  "webglRenderer": null,
  "webglParams": null,
  "webgl2Renderer": null
}
```

Chrome 日志：

```text
ContextResult::kFatalFailure: WebGL1 blocklisted
ContextResult::kFatalFailure: WebGL2 blocklisted
```

这不是微妙的伪造问题。调用 `canvas.getContext('webgl')` 的页面得到 `null`。许多真实站点，
包括 WebGL 指纹测试、地图应用和某些反机器人挑战，会把它当作老旧/能力不足/被阻止的浏览器。

### 2.5 恢复 WebGL

第二次有头启动加上：

```text
--enable-unsafe-swiftshader --ignore-gpu-blocklist
```

返回：

```json
{
  "webgl": true,
  "vendor": "Google Inc. (Mesa)",
  "renderer": "ANGLE (Mesa, llvmpipe (LLVM 15.0.7 256 bits), OpenGL 4.5)"
}
```

所以能力存在，是默认黑名单压制了它。当前启动脚本没有传这些参数，意味着真实配置文件没有
WebGL。

无头 Chrome 带 `--disable-gpu` 时报告另一条软件路径：

```text
ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)),
       SwiftShader driver)
```

因此同一台机器可能有三种不同的渲染器：

| 模式 | 渲染器 | WebGL |
|---|---|---|
| 有头，默认 | Mesa llvmpipe（被阻止） | `null` |
| 有头，unsafe SwiftShader | Mesa llvmpipe | 可用 |
| 无头，`--disable-gpu` | SwiftShader | 可用 |

指纹浏览器必须选择一种，并让它在所有配置文件和模式间稳定。

### 2.6 字体

- 166 个字体文件，46 个家族。
- `document.fonts.check()` 报告测试的 27/27 字体存在，但 fontconfig 把 Arial、Segoe UI、
  PingFang SC、Microsoft YaHei 和 Roboto 别名到 Liberation/DejaVu。
- Canvas 文本度量反映 Liberation/DejaVu，而不是别名。
- 安装了 Noto CJK 字体，所以 CJK 文本用真实 CJK 字形渲染。

这是**字体度量**缺口，不是字体列表缺口。只伪造列表而不伪造度量，很容易被 canvas 宽度
测量检测。

### 2.7 媒体、音频、语音

| 信号 | 值 |
|---|---|
| `navigator.mediaDevices.enumerateDevices()` | `[]` |
| `Notification.permission` | `default` |
| `speechSynthesis.getVoices()` | `[]` |
| `AudioContext.sampleRate` | `44100` |
| `AudioContext.baseLatency` | `0.01` |
| `crossOriginIsolated` | `false` |
| `history.length` | `1` |

没有相机、麦克风、扬声器或 TTS 语音。真实桌面通常至少暴露一个默认音频输出，常常还有
麦克风。这是强烈的“无头/VM”信号。

### 2.8 区域、时区、语言

```text
timezone = UTC
locale   = en-US
calendar = gregory
numberingSystem = latn
languages = [en-US, en]
```

结合土耳其住宅 IP，这是环境中最明显的一致性问题。见第 4 节。

---

## 3. 无头值（对比）

| 信号 | 有头 | 无头 |
|---|---|---|
| UA | `Chrome/156.0.0.0` | `HeadlessChrome/156.0.0.0` |
| 屏幕 | `1280×720` | `800×600` |
| DPR | `1` | `1` |
| WebGL 厂商 | `null` | `Google Inc. (Google)` |
| WebGL 渲染器 | `null` | `ANGLE (... SwiftShader ...)` |
| `webdriver` | `false` | `false` |
| 语言 | `en-US,en` | `en-US,en` |
| 时区 | `UTC` | `UTC` |
| 媒体设备 | 无 | 无 |

无头模式不能替代真实桌面。它改变 UA、屏幕和 GPU 路径。任何 QA 工具必须测试产品实际
发布的模式。

---

## 4. 一致性分析

当独立层相互一致时，指纹才是一致的。当前环境：

| 层 | 值 | 与 TR 住宅一致？ |
|---|---|---|
| 代理出口 | 土耳其 | —（参考） |
| 时区 | `UTC` | **否**（土耳其是 UTC+3） |
| `Intl` 区域 | `en-US` | **否**（预期 `tr-TR`） |
| `navigator.languages` | `en-US,en` | **否** |
| UI 语言 | `en-US` | **否** |
| 系统区域 | `en_US.UTF-8` | **否** |
| 地理定位权限 | `default`（未授权） | 中性；IP 地理位置仍说 TR |
| 货币 | 未配置 | **否**（预期 TRY） |
| 字体 | 西方 + CJK | 部分；土耳其拉丁字母由 DejaVu/Liberation 覆盖 |
| 键盘布局 | 未探测 | 未知 |
| GPU | llvmpipe / 被阻止 | **否**（真实桌面不常见） |
| 屏幕 | 1280×720 | 可能但不常见 |
| CPU/RAM | 2 vCPU / 4 GiB | 可能但偏低 |
| 媒体设备 | 无 | **否**（桌面不常见） |
| 语音 | 无 | **否** |
| `variations_country` | TR 配置文件为 `tr` | 是（但其他为 `cn`/`jp`） |

不一致不是一个值，而是一簇。一个检查其中两三项的站点，不需要高级指纹技术就能把配置文件
与真实土耳其桌面区分开。

---

## 5. 可检测性排名（推断）

| 排名 | 信号 | 为什么显眼 | 修复难度 |
|---|---|---|---|
| 1 | WebGL `null` | 大多数真实浏览器有 WebGL；null 很少见，常与无头/被阻止环境相关 | 低（参数）/ 中（伪造） |
| 2 | 无媒体设备 / 无语音 | 真实桌面几乎总有音频 | 中（虚拟设备） |
| 3 | 时区/区域与代理国家不一致 | 轻易交叉检查 | 低（按配置文件环境） |
| 4 | llvmpipe / SwiftShader 渲染器 | 消费级桌面软件渲染不常见 | 高（GPU 或补丁） |
| 5 | 跨配置文件固定 1280×720 | 稳定的跨配置文件标识符 | 中（按配置文件显示） |
| 6 | `variations_country` 不一致 | 内部状态，JS 不可见，但影响行为 | 低（全新配置文件） |
| 7 | 2 vCPU / 4 GiB | 低端但合理 | 低（不改主机无法改变） |
| 8 | TR 住宅 IP 上的 Linux UA | 合理但不如 Windows 常见 | 中（分支/UA-CH） |
| 9 | `storage.quota = 10 GiB` | 容器痕迹 | 低（可修补） |
| 10 | `connection.rtt = 100`、`downlink = 1.5` | 合成值 | 低（修补或忽略） |

这个排名是优先级工具，不是保证。商业供应商使用更多信号和专有评分。

---

## 6. 不修改 Chromium 分支就能修复的

| 缺口 | 修复 |
|---|---|
| WebGL null | 加 `--enable-unsafe-swiftshader --ignore-gpu-blocklist`（或传 GPU） |
| 时区 | 在容器/命名空间中用 `TZ=Europe/Istanbul` 运行每个配置文件，或打补丁 |
| 区域 / 语言 | 安装 `tr_TR.UTF-8`，设置 `LANG`/`LC_ALL`，传 `--accept-lang=tr-TR,tr` |
| `variations_country` | 在目标环境创建全新配置文件；不要克隆 |
| 代理 / DNS / IPv6 | 按配置文件网络命名空间、fail-closed 防火墙、DNS 走代理 |
| 屏幕几何 | 按配置文件 X 服务器或 XRDP 会话，使用目标分辨率 |
| 媒体设备 | 虚拟摄像头/麦克风（v4l2loopback、PulseAudio null sink） |
| 语音 | 安装 speech-dispatcher 语音，或接受缺口 |
| 字体 | 安装人格特定字体集；接受度量差异 |
| 自动化 | 受控 CDP 端口带认证，或 Playwright 启动 |

## 7. 需要分支或原生补丁的

| 缺口 | 为什么配置不够 |
|---|---|
| WebGL 厂商/渲染器字符串 | Chrome 从 GPU 进程读取；页面可交叉检查许多参数 |
| Canvas/音频噪声 | 必须按配置文件确定，并在各 API 间一致 |
| 字体度量 | Blink 的字体回退和测量发生在渲染器 |
| UA-CH 一致性 | client hints 在浏览器进程生成，必须与 UA 匹配 |
| 按标签页时区 | `Intl` 和 `Date` 是进程级；按配置文件隔离需要渲染器补丁或独立进程 |
| 按配置文件屏幕 | `screen` 来自窗口/显示；按配置文件虚拟显示是操作系统问题 |
| 媒体设备标签 | Blink 从操作系统枚举设备；标签和能力需要虚拟化 |
| TLS/HTTP2 指纹 | 网络栈行为；可用参数影响，但不能完全伪造 |
| WebRTC SDP | 候选和编解码器细节在网络栈生成 |

实际分工：**配置能给你一致的网络和配置文件**，但 **GPU、字体、canvas 和 client hints
需要代码**。

---

## 8. 指纹自测契约

在配置文件被认为可用之前，应通过自测，记录并检查：

- 公网 IPv4 和 IPv6（必须匹配预期出口或不存在）；
- DNS 解析器和 DNS 泄漏测试；
- WebRTC 候选（必须经代理或为空）；
- 时区、`Intl` 区域、`navigator.languages`、`Accept-Language`；
- UA、UA-CH、platform、architecture、bitness；
- 屏幕、窗口、DPR、色深；
- WebGL 厂商/渲染器和稳定参数集；
- canvas、音频和字体度量哈希（按配置文件确定）；
- 媒体设备和语音；
- `variations_country` 和配置文件创建元数据；
- Chrome 版本和配置文件 schema 版本。

测试应在每次启动时运行，结果与配置文件清单做 diff。发生漂移的配置文件应 fail closed，
而不是启动。

---

## 9. 证据

- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
- [`../../inventory/container/gpu-info.json`](../../inventory/container/gpu-info.json)
- [`../../inventory/container/18-headless-probe.json`](../../inventory/container/18-headless-probe.json)
- [`../../inventory/container/17-fingerprint-surface.txt`](../../inventory/container/17-fingerprint-surface.txt)
