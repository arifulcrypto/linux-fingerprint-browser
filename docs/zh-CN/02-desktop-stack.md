# 02 — 桌面栈

浏览器不是跑在裸 X 服务器上，而是跑在由 XRDP 导出的 XFCE 会话里，使用 Xorg，几何尺寸

固定。这些层中的每一层都会影响指纹和运维约束。

---

## 1. 组件与版本

| 组件 | 版本 | 包 |
|---|---|---|
| XRDP | 0.9.17 | `xrdp 0.9.17-2ubuntu3.1` |
| xorgxrdp | 0.2.17 | `xorgxrdp 1:0.2.17-1build1` |
| Xorg | 1.21.1.4 | `xserver-xorg-core 2:21.1.4-2ubuntu1.7~22.04.16` |
| XFCE | 4.16 | `xfce4 4.16` 元包 |
| D-Bus | 1.12.20 | `dbus`、`dbus-x11`、`dbus-user-session` |
| 显示 | `:10` | xrdp sesman `X11DisplayOffset=10` |
| 会话管理器 | `xfce4-session` | 通过 `/etc/xrdp/startwm.sh` → `/etc/X11/Xsession` 启动 |

没有 Wayland，没有 PipeWire，没有 PulseAudio 工具（`pactl`/`aplay` 不存在），没有
`/dev/snd`。XFCE 面板仍带 PulseAudio 插件，但音频实际上不可用。

---

## 2. XRDP 配置

来自 `/etc/xrdp/xrdp.ini` 和 `/etc/xrdp/sesman.ini`：

| 设置 | 值 | 后果 |
|---|---|---|
| 监听端口 | `3389` TCP（另有 UDP 映射） | 由 LXD 发布 |
| 安全层 | `negotiate`，TLS 1.2/1.3 | 标准 RDP 加密 |
| 最大 bpp | 32 | X 根窗口 24 位 |
| 位图缓存 / 压缩 | 启用 | 带宽优化 |
| 多显示器 | 允许 | 客户端可请求多显示器 |
| `AllowRootLogin` | `true` | 桌面以 root 运行 |
| `MaxSessions` | 50 | 可并发多个会话 |
| `KillDisconnected` | `false` | 断线后会话继续运行 |
| 剪贴板限制 | `false` | 剪贴板共享 |
| X11 显示偏移 | 10 | 固定 `:10` |
| Xorg 参数 | `-noreset -nolisten tcp` | 不监听 TCP X |
| Xvnc DPI 回退 | 96 | 与 Xorg 一致 |

会话长期存在，重新连接会回到同一个桌面。这对 VPS 很方便，但意味着所有浏览器窗口共享

一个会话、一个剪贴板和一个窗口管理器。

---

## 3. 显示几何

`xrandr` 和 `xdpyinfo`：

```text
Screen 0: minimum 256 x 256, current 1280 x 720, maximum 16384 x 16384
rdp0 connected 1280x720+0+0
  1280x720  46.080MHz  h: 1280  v: 720  clock 50.00Hz
dimensions:    1280x720 pixels (339x191 millimeters)
resolution:    96x96 dots per inch
depth of root window: 24 planes
```

有头 JavaScript 探针补充窗口管理器细节：

| 信号 | 值 |
|---|---|
| `screen.width × height` | `1280 × 720` |
| `screen.availWidth × availHeight` | `1280 × 693` |
| `screen.availTop` | `27`（顶部面板） |
| `window.outerWidth × outerHeight` | `1279 × 719` |
| `window.innerWidth × innerHeight` | `1271 × 572` |
| `devicePixelRatio` | `1` |
| `colorDepth` / `pixelDepth` | `24 / 24` |
| `screen.orientation` | `landscape-primary / 0` |

27 px 的差值是 XFCE 面板。内部高度更小是因为浏览器自己的界面。这些值稳定可复现，
因此也成为跨配置文件的稳定标识符。

### 为什么 1280×720 重要

720p 是合法分辨率，但在现代桌面上不常见，配 27 px 面板和 1279 px 外部宽度就更少见。
更重要的是，**每个配置文件报告相同的几何尺寸**。指纹浏览器必须：

- 给每个配置文件一个合理且独立的几何尺寸（窗口大小、屏幕大小、面板），或
- 保持一个几何尺寸，但接受配置文件在显示层可被关联。

XRDP 支持动态调整大小，但当前会话固定为 1280×720。没有按配置文件的显示服务器。

---

## 4. 输入设备

```text
Virtual core pointer
  ↳ Virtual core XTEST pointer
  ↳ xrdpMouse
Virtual core keyboard
  ↳ Virtual core XTEST keyboard
  ↳ xrdpKeyboard
```

`maxTouchPoints = 0`。没有触摸屏、手写笔或游戏手柄。这与远程 Linux 桌面一致，但也是
必须与声称的设备类型匹配的信号。一个假装是带触摸屏 Windows 笔记本的配置文件，如果
浏览器不虚拟化这一层，就会自相矛盾。

---

## 5. 字体

| 指标 | 值 |
|---|---|
| 字体文件 | 166 |
| 家族 | 46 |
| 包 | `fonts-dejavu-core`、`fonts-liberation`、`fonts-noto-cjk`、`fonts-noto-color-emoji`、`fonts-noto-mono`、`fonts-ubuntu-console`、`fonts-urw-base35`、`xfonts-*` |
| CJK | Noto Sans/Serif CJK，覆盖 SC、TC、JP、KR、HK |
| Emoji | Noto Color Emoji 2.047 |

家族包括 DejaVu、Liberation、Nimbus、URW base35、Bitstream Charter、C059、
Century Schoolbook L、Dingbats 和 Noto CJK 系列。

### fontconfig 别名让 JavaScript 字体检查不可靠

页面检查 `document.fonts.check('16px "Arial"')` 在这台机器上返回 `true`，因为 fontconfig
把 Arial 别名到 Liberation Sans。Segoe UI、PingFang SC、Microsoft YaHei 和 Roboto 也
一样，全部解析到 DejaVu Sans：

```text
Arial           -> LiberationSans-Regular.ttf "Liberation Sans"
Segoe UI        -> DejaVuSans.ttf "DejaVu Sans"
PingFang SC     -> DejaVuSans.ttf "DejaVu Sans"
Microsoft YaHei -> DejaVuSans.ttf "DejaVu Sans"
Roboto          -> DejaVuSans.ttf "DejaVu Sans"
Noto Sans CJK SC-> NotoSansCJK-Regular.ttc "Noto Sans CJK SC"
```

所以一个幼稚的字体探针会报告 27/27 全部存在。这不是字体存在的证据，而是 fontconfig
做了替换的证据。真正的字体指纹测量字形宽度和 canvas 渲染，而不只是 `check()`。这有
两层影响：

1. 当前机器对幼稚探针看起来“字体丰富”，但西文字体实际用 Liberation/DejaVu 的度量渲染；
2. 未来的伪造层必须伪造**度量和字形**，而不只是字体列表。

---

## 6. 区域设置与时区

```text
LANG / LC_ALL: en_US.UTF-8
locale -a:     C, C.utf8, en_US.utf8, POSIX
timezone:      Etc/UTC (UTC, +0000)
```

没有 `tr_TR.UTF-8`、`de_DE.UTF-8` 或 `ja_JP.UTF-8`。Chrome 以 `--lang=en-US` 运行；
有头探针报告 `language: en-US`、`languages: [en-US, en]`、`Intl` 区域 `en-US`、
日历 `gregory`、数字系统 `latn`。

对土耳其住宅配置文件，这是三方不一致：

| 层 | 当前 | TR 住宅的预期 |
|---|---|---|
| 代理出口 | 土耳其 | 土耳其 |
| 时区 | `UTC` | `Europe/Istanbul`（UTC+3） |
| 浏览器语言 | `en-US,en` | `tr-TR,tr` |
| `Intl` 区域 | `en-US` | `tr-TR` |
| 系统区域 | `en_US.UTF-8` | `tr_TR.UTF-8` |

Chrome 没有设置时区的命令行参数。时区必须在操作系统/容器层控制，通过 `TZ`，或修补
渲染器。对共享桌面来说，按配置文件的 `TZ` 环境变量不够，因为所有配置文件继承同一个
会话环境。

---

## 7. 会话启动与环境

`/etc/xrdp/startwm.sh` 加载 `/etc/profile` 并执行 `/etc/X11/Xsession`。XFCE 会话启动
`xfce4-session`、`xfce4-panel`、`xfce4-notifyd`、`xfconfd` 和 PulseAudio 面板插件。

没有按配置文件的环境。`DISPLAY`、`XAUTHORITY`、`LANG`、`LC_ALL`、`TZ` 都从会话继承。
Chrome 启动脚本把 `LANG` 和 `LC_ALL` 覆盖为 `en_US.UTF-8`，进一步强化了非英语代理下的
英语不一致。

---

## 8. 桌面层隔离缺口

| 缺口 | 影响 |
|---|---|
| 单一 X 显示 `:10` | 所有配置文件共享屏幕和窗口管理器 |
| 单一 Linux 用户 `root` | 没有按配置文件的 home、权限或进程边界 |
| 共享剪贴板 | 在一个配置文件复制，在另一个粘贴 |
| 共享 fontconfig | 每个配置文件字体度量相同 |
| 共享时区/区域 | 时钟和 `Intl` 行为相同 |
| 共享 D-Bus 会话 | 通知、电源和桌面服务共用 |
| 无锁屏/空闲策略 | 会话无限期存在 |
| `KillDisconnected=false` | 断线会话继续运行并占用内存 |

声称配置文件隔离的产品必须在容器或 VM 层解决这些问题，而不只是 `--user-data-dir`。

---

## 9. 证据

- [`../../inventory/container/02-desktop.txt`](../../inventory/container/02-desktop.txt)
- [`../../inventory/container/03-display.txt`](../../inventory/container/03-display.txt)
- [`../../inventory/container/04-fonts-locale.txt`](../../inventory/container/04-fonts-locale.txt)
- [`../../inventory/container/17-fingerprint-surface.txt`](../../inventory/container/17-fingerprint-surface.txt)
- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
