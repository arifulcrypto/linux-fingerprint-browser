# 10 — 采集方法

本文档说明清单如何捕获、脚本做什么、刻意不采集什么，以及如何复现快照。

---

## 1. 原则

1. **只读。** 采集脚本不修改服务、防火墙规则、代理配置、Chrome 配置文件或用户数据。
   它们把报告写到 `/tmp` 并生成 tarball。
2. **证据优先于总结。** 保留原始命令输出；文档负责解释。
3. **最小足迹。** 不做抓包、不暴力破解、不爬取、不执行账户操作、不登录配置文件。
4. **发布前脱敏。** 真实凭据、密钥、UUID、会话 ID、公网 IP 和 MAC 地址从公开副本移除。
5. **标注日期。** 指纹只对捕获时的软件版本有效。

---

## 2. 采集脚本

### 容器

[`../../scripts/collect-container.sh`](../../scripts/collect-container.sh) 在 `c4-desktop`
内运行，向 `/tmp/fp-inventory` 写入约 20 份报告：

| 文件 | 内容 |
|---|---|
| `00-system.txt` | 主机名、系统、内核、时间、区域、时区、machine-id 哈希 |
| `01-hardware.txt` | CPU、内存、磁盘、挂载、DMI、设备、capabilities |
| `02-desktop.txt` | 进程、会话、XRDP、XFCE、窗口管理器、包 |
| `03-display.txt` | xrandr、xdpyinfo、xrdb、xset、xinput、xprop、glxinfo、XRDP 配置 |
| `04-fonts-locale.txt` | 字体数量、家族、文件、fontconfig、区域、输入法 |
| `05-chrome.txt` | 二进制、版本、包、策略、沙箱、调试端口、进程 |
| `06-chrome-profiles.txt` | 配置文件大小、目录树、扩展、首选项位置 |
| `06b-chrome-profile-summary.json` | 解析后的 Preferences / Local State 摘要 |
| `07-chrome-launchers.txt` | desktop 文件、启动脚本、自启动、代理速查表 |
| `08-proxy-services.txt` | 单元、状态、版本、脱敏 Xray/Hysteria 配置 |
| `09-network.txt` | 地址、路由、解析器、监听、nftables、sysctl、DNS 测试 |
| `10-container-view.txt` | 容器身份、cgroup、挂载、限制 |
| `11-software.txt` | 包数量、关键包、全部包、apt 源 |
| `12-toolchain.txt` | 编译器、语言、Python 包、构建依赖、磁盘预算 |
| `13-docker.txt` | Docker 版本、信息、容器、镜像、网络、卷 |
| `14-1panel.txt` | 1Panel 是否存在（不存在） |
| `15-autostart-cron-users.txt` | cron、启用/运行单元、用户、sshd、fail2ban |
| `16-security.txt` | AppArmor、ufw、sysctl、开放端口、shadow 算法、sudoers |
| `17-fingerprint-surface.txt` | 屏幕、DPI、GPU、音频、时区、区域、字体、MAC、CPU |
| `18-headless-chrome-probe.*` | 无头 DOM/JSON 探针和错误 |
| `19-summary.txt` | 采集时间、文件列表、大小 |

### 主机

[`../../scripts/collect-host.sh`](../../scripts/collect-host.sh) 在 KVM 主机运行，向
`/tmp/fp-host-inventory` 写入五份报告：

| 文件 | 内容 |
|---|---|
| `00-host-system.txt` | 系统、内核、CPU、内存、磁盘、PCI、GPU |
| `01-host-lxd.txt` | 容器、`c4` 配置/设备、profile、网络、存储 |
| `02-host-network.txt` | 地址、路由、公网 IP、DNS、监听、nftables |
| `03-host-services.txt` | 运行服务、版本、Docker、cron |
| `04-host-ports.txt` | LXD 端口映射、nftables 片段、容器 IP |

### 运行方式

```bash
# 容器（从主机或通过 SSH）
scp -P 2204 scripts/collect-container.sh root@<host>:/tmp/
ssh -p 2204 root@<host> 'bash /tmp/collect-container.sh'

# 主机
scp -P <host-ssh-port> scripts/collect-host.sh root@<host>:/tmp/
ssh -p <host-ssh-port> root@<host> 'bash /tmp/collect-host.sh'
```

脚本最后打印 tarball 路径。复制出来并在本地解压。

---

## 3. 有头探针

有头探针不属于采集脚本，因为它会启动浏览器。它手动运行：

1. 写一个本地 HTML 页面，计算指纹对象并存入 `window.__fp`。
2. 在 `:10` 上启动临时配置文件：

   ```bash
   DISPLAY=:10 XAUTHORITY=/root/.Xauthority \
   google-chrome-stable --no-sandbox --disable-dev-shm-usage \
     --no-first-run --no-default-browser-check \
     --user-data-dir=/tmp/fp-headful-profile \
     --remote-debugging-port=9222 --remote-allow-origins=* \
     --window-size=1280,720 --window-position=0,0 \
     file:///tmp/headful-probe.html
   ```

3. 连接 `http://127.0.0.1:9222/json`，找到页面 target，通过 WebSocket 求值
   `JSON.stringify(window.__fp)`。
4. 在浏览器 target 上查询 `SystemInfo.getInfo` 和 `Browser.getVersion`。
5. 杀掉临时浏览器并删除配置文件。

探针使用临时配置文件和仅本地 CDP 端口，没有触碰现有 `chrome-*` 配置文件。结果 JSON 存为
`inventory/container/headful-probe.json` 和 `gpu-info.json`。

### WebGL 变体

第二次有头运行加上：

```text
--enable-unsafe-swiftshader --ignore-gpu-blocklist
```

并执行最小 WebGL 检查。结果记录在 `06-fingerprint-surface.md`。这是测量，不是修改启动脚本。

---

## 4. 未采集什么

| 未采集 | 原因 |
|---|---|
| Cookie、localStorage、IndexedDB、历史 | 隐私；环境清单不需要 |
| 保存的密码、自动填充、支付方式 | 隐私和安全 |
| 代理供应商账户详情 | 密钥 |
| 抓包 | 超出范围；侵入性强 |
| TLS/JA3/JA4 指纹 | 需要受控服务器；未来工作 |
| Canvas/音频哈希值 | 探针捕获能力，不是稳定哈希；未来自测 |
| WebRTC 候选转储 | 只捕获策略；未来泄漏测试 |
| DNS canary / 泄漏测试 | 捕获解析器路径；主动泄漏测试是未来工作 |
| 键盘布局/键位 | 未捕获；未来探针 |
| 屏幕截图 | 不需要；避免 PII |
| Windows/WSL 环境 | 本阶段不可用 |
| GPU 直通测试 | 主机有 `/dev/dri`，容器没有；未来工作 |

这些是明确的缺口，不是疏忽。路线图把它们加入自测工具。

---

## 5. 脱敏

公开清单应用以下替换：

| 真实值类别 | 公开占位符 |
|---|---|
| 公网 IPv4 | `203.0.113.10`（TEST-NET-3） |
| 次要公网 IPv4 | `198.51.100.x`（TEST-NET-2） |
| 公网 IPv6 | `2001:db8::10` |
| 代理用户名/密码 | `REDACTED` |
| VLESS UUID | `REDACTED` |
| REALITY 私钥/公钥、short ID | `REDACTED` |
| Hysteria2 密码、obfs 密码 | `REDACTED` |
| 会话 ID | `REDACTED` |
| MAC 地址 | 后三字节掩码 |
| `machine-id` / `boot-id` 哈希 | 移除 |
| SSH 密码 | 从不采集 |

私有归档保留真实值。它不属于本仓库。

---

## 6. 可复现性

复现快照：

1. 使用相同系统镜像和 Chrome 版本。不同 Chrome 版本会改变 UA-CH、功能开关，可能改变
   WebGL/canvas 行为。
2. 使用相同显示几何（1280×720，96 DPI），或记录差异。
3. 使用相同区域/时区（`en_US.UTF-8`、`UTC`），或记录差异。
4. 在一天中相同时间运行采集脚本和有头探针；某些值（网络质量、`connection.rtt`）会变化。
5. 保存输出，附日期和校验和。

未来的 `manifest.json` 应记录：

```json
{
  "captured_at": "2026-11-12T04:00:00Z",
  "host_os": "Ubuntu 20.04.6 LTS",
  "container_os": "Ubuntu 22.04.5 LTS",
  "kernel": "5.4.0-216-generic",
  "chrome": "156.0.8078.79",
  "xorg": "1.21.1.4",
  "xrdp": "0.9.17",
  "display": "1280x720@96dpi",
  "locale": "en_US.UTF-8",
  "timezone": "UTC",
  "sha256": "<inventory tarball hash>"
}
```

---

## 7. 局限

- 清单是时间点快照。Chrome、Docker 镜像和代理会话会变化。
- 有头探针使用临时配置文件，不是真实的 `chrome-tr-proxy`。值应相同，但真实配置文件可能
  有扩展或权限改变它们。
- 指纹检查是能力检查，不是完整反检测供应商评分。
- 延迟数字来自一个客户端和一个供应商；它们是指示性的，不是住宅市场基准。
- 主机和容器共享文件系统；磁盘数字是耦合的。
- 没有测量 Windows、macOS 或 WSL 环境。

---

## 8. 安全

- 不要在你没有所有权或检查许可的主机上运行采集脚本。
- 不要在未审查密钥的情况下发布原始输出。
- 不要用你关心的账户运行有头探针；它使用一次性配置文件是有原因的。
- 不要为了“测试”泄漏而禁用在线主机的代理或防火墙；使用 canary 和维护窗口。
- 保持私有归档加密并受访问控制。
