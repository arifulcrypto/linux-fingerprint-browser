# 04 — Chrome 配置文件

Chrome 配置文件隔离是当前设置中最强的部分，也是最有趣的一致性痕迹来源。本文档盘点五个

配置文件、它们的状态、扩展，以及它们暴露的过去网络路径。

---

## 1. 清单

| 配置文件目录 | 大小 | 用途 | 代理 | `variations_country` | 扩展 | 权限 |
|---|---:|---|---|---|---:|---|
| `~/.config/google-chrome` | 177 MB | 默认 / 临时 | 无 | `jp` | 5 | `0700` |
| `~/.config/chrome-residential` | 20 MB | PH 轮换住宅 | `127.0.0.1:18080` | `ph` | 5 | `0755` |
| `~/.config/chrome-tr-proxy` | 175 MB | TR 粘性住宅 | `127.0.0.1:18081` | `tr` | 6 | `0755` |
| `~/.config/chrome-us-proxy` | 313 MB | US VLESS 线路 | `127.0.0.1:2080` | `cn` | 6 | `0755` |
| `~/.config/google-chrome-headless` | 4 KB | 仅无头探针 | 无 | 无 | 0 | `0700` |

所有配置文件使用同一个 Chrome 二进制、同一个 Linux 用户和同一个显示。

### 大小观察

- `chrome-us-proxy` 最大（313 MB），是用于 `claude.ai` 和日常浏览的配置文件。缓存和
  service worker 存储占主导。
- `chrome-tr-proxy`（175 MB）和 `google-chrome`（177 MB）大小相近。
- `chrome-residential` 只有 20 MB，说明使用很少。
- 无头配置文件除目录本身外为空。

配置文件大小在运维上很重要：容器只剩约 2 GiB，而 Chrome 不会自动缩小 `Default/`。需要
配置文件生命周期策略（临时配置文件、缓存上限、定期压缩）。

---

## 2. 配置文件首选项

每个配置文件都有 `Default/Preferences` 和顶层 `Local State`。检查到的值：

| 键 | 值 | 说明 |
|---|---|---|
| `profile.name` | `Your Chrome` | 所有配置文件都是默认名 |
| `profile.avatar_index` | `26` | 所有配置文件同一头像 |
| `profile.exit_type` | `Normal` | 正常关闭 |
| `profile.default_content_setting_values` | `{has_migrated_local_network_access: true}` | 没有显式相机/麦克风/地理定位策略 |
| `profile.content_settings.exceptions` | 50+ 键 | 多为默认值和元数据，不是用户授权 |
| `intl.accept_languages` | 缺失 | 回退到系统区域 |
| `intl.charset_default` | 缺失 | 默认 |
| `browser.last_clear_browsing_data_time` | 缺失 | 从未通过 UI 清除 |
| `browser.has_seen_welcome_page` | 缺失/false | 首次运行状态未完成 |
| `download.default_directory` | 缺失 | 默认 `~/Downloads` |
| `signin.allowed` | `true` | 允许 Google 登录 |
| `sync.requested` | 缺失 | 未配置同步 |
| `hardware_acceleration_mode` | 缺失 | 默认（启用），但 GPU 是软件 |
| `media.autoplay_policy` | 缺失 | 默认 |

这些配置文件基本上就是出厂默认 Chrome，加上累积的 cookie 和历史。`Preferences` 中没有
任何刻意的指纹配置。

### 内容设置

`content_settings.exceptions` 对象包含几十个键，但它们是 Chrome 的内部元数据（例如
`cookies`、`geolocation`、`notifications`、`clipboard`、`file_system_*`、`fedcm_*`、
`automatic_downloads`）。清单没有发现相机、麦克风或地理定位的显式用户授权。有头探针
确认：

```text
Notification.permission = "default"
navigator.mediaDevices.enumerateDevices() = []
```

没有相机、麦克风或扬声器。一个声称是真实桌面并带媒体设备的配置文件会与此矛盾。

---

## 3. `variations_country` —— 国家记忆

`Local State` 包含：

```json
"variations_country": "tr",
"variations_permanent_consistency_country": ["156.0.8078.79", "tr"]
```

按配置文件：

| 配置文件 | `variations_country` | 可能的来源 |
|---|---|---|
| `google-chrome` | `jp` | 主机/默认浏览在日本 |
| `chrome-residential` | `ph` | 创建配置文件时的 PH 住宅出口 |
| `chrome-tr-proxy` | `tr` | TR 住宅出口 |
| `chrome-us-proxy` | `cn` | 某个时刻的中国出口，尽管名字是 US 代理 |
| `google-chrome-headless` | 无 | 从未获取 variations seed |

### 它是什么

Chrome 的 variations 服务在获取 seed 时，根据网络位置分配国家。该值存储在本地，用于
选择 field trial。它**不暴露给 JavaScript**，网站无法直接读取。

### 为什么仍然重要

- 它是配置文件去过哪里的持久痕迹。把配置文件克隆到新代理会带着旧国家。
- 它改变功能推送：`cn` 配置文件可能收到与 `tr` 不同的实验，从而微妙地改变行为。
- 它是 QA 的一致性信号：如果一个配置文件本应是土耳其，却出现 `cn` 或 `jp`，说明它不是在
  目标环境中创建的。
- 它提醒我们：“指纹”不只是 JavaScript 能读到的东西。服务端状态、本地状态和功能开关都
  影响配置文件的可观察行为。

配置文件供应流水线应在目标环境中创建全新的 `Local State`，或显式规范化该字段，而不是从
模板复制。

---

## 4. 扩展

所有已安装扩展都是 Chrome 自带的组件扩展或外部组件扩展。没有第三方扩展、广告拦截器或
自动化扩展。

| 扩展 | 版本 | 配置文件 | 类型 |
|---|---|---|---|
| Chrome PDF Viewer | 1 | 全部 | component |
| Chrome Web Store Payments | 1.0.0.6 | 全部 | external component |
| Google Docs Offline | 1.111.1 | 全部 | component/external |
| Google Hangouts | 1.3.26 / 1.4.5 | 全部 | component |
| Google Network Speech | 1.0 | 全部 | component |
| Gemini in Chrome | 1.2 | TR、US | component |

`Gemini in Chrome` 只出现在较新的配置文件中，这是版本/功能推送差异，不是用户安装。这也是
为什么两个配置文件即使参数相同也可能行为不同。

`chrome://extensions` 会把它们显示为内置。网站可以检测某些扩展痕迹（例如所有 Chrome 页面
都有 `chrome.runtime`），但组件集是标准的。

---

## 5. 隔离矩阵

| 资源 | 按配置文件隔离？ | 证据 |
|---|---|---|
| Cookie / localStorage / IndexedDB | 是 | 独立 `--user-data-dir` |
| 缓存 / service worker | 是 | 独立配置文件目录 |
| 历史 / 下载 | 是 | 独立 `Default/` |
| 扩展 | 是 | 独立 `Extensions` 状态 |
| 代理 | 是 | 每个启动脚本不同 `--proxy-server` |
| 崩溃报告 | **否** | Crashpad 使用 `/root/.config/google-chrome/Crash Reports` |
| X11 显示 / 剪贴板 | **否** | 所有窗口在 `:10` |
| 字体 / fontconfig | **否** | 系统级 |
| 时区 / 区域 | **否** | 系统级 |
| CPU / 内存信号 | **否** | 同一 cgroup 限制 |
| 屏幕几何 | **否** | 同一 XRDP 会话 |
| Linux 用户 / 进程边界 | **否** | 全部以 `root` 运行 |
| Chrome 二进制 / 版本 | **否** | 单一安装 |

右列就是产品缺口。`--user-data-dir` 解决存储问题，不解决环境问题。

---

## 6. 配置文件生命周期风险

1. **复制配置文件会复制历史。** Cookie、localStorage、service worker 和 `Local State`
   一起移动。“全新”配置文件必须创建，不能克隆。
2. **复制配置文件会复制国家。** 见 `variations_country`。
3. **复制配置文件会复制权限。** 相机/麦克风/地理定位授权（如果有）会跟着走。当前配置
   文件没有，但未来可能有。
4. **Chrome 版本升级会改变配置文件。** 在 156 上创建的配置文件，首次用 157 启动时可能
   被迁移。快照测试应固定版本并检测迁移。
5. **磁盘增长无上限。** 缓存、GPUCache、Code Cache 和 service worker 会一直增长，直到
   被清理。需要配置文件配额和清理策略。
6. **Crashpad 共享。** 一个配置文件崩溃会写入默认配置文件的崩溃目录。这既是隐私问题，
   也是稳定性问题。

---

## 7. 配置文件应包含什么（设计输入）

基于上述缺口，配置文件记录最终应包括：

- 用于确定性指纹生成的稳定 seed；
- 代理配置和预期出口元数据（国家、ASN、时区、语言）；
- 时区、区域、`Accept-Language` 和地理定位包；
- 屏幕/窗口几何和 DPI；
- 字体集和字体度量配置；
- WebGL/WebGPU 厂商和渲染器字符串，以及渲染后端；
- 媒体设备清单；
- 自动化策略（CDP 启用/禁用、允许的来源）；
- 存储配额和生命周期策略；
- 启动前可验证的一致性清单。

当前配置文件只有前两项（隐含），其余都没有。

---

## 8. 证据

- [`../../inventory/container/06-profiles.md`](../../inventory/container/06-profiles.md)
- [`../../inventory/container/06b-chrome-profile-summary.json`](../../inventory/container/06b-chrome-profile-summary.json)
- [`../../inventory/container/headful-probe.json`](../../inventory/container/headful-probe.json)
