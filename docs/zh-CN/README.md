# 中文文档

英文是主语言，本目录是 [`docs/en/`](../en/) 的镜像翻译。事实、版本号、路径和测量值

以英文文档为准；如果两者不一致，请先修正英文原文，再同步翻译。

| # | 文档 | 内容 |
|---|---|---|
| 00 | [概览](00-overview.md) | 范围、方法、五个关键结论 |
| 01 | [主机与容器](01-host-and-container.md) | KVM、LXD、资源限制、磁盘、端口映射 |
| 02 | [桌面栈](02-desktop-stack.md) | XRDP、Xorg、XFCE、显示、字体、区域设置 |
| 03 | [浏览器安装](03-browser-installation.md) | Chrome 版本、策略、启动脚本、参数 |
| 04 | [Chrome 配置文件](04-chrome-profiles.md) | 配置文件状态、扩展、`variations_country` |
| 05 | [代理与网络](05-proxy-and-network.md) | 代理链、节点、DNS、IPv6、延迟 |
| 06 | [指纹面](06-fingerprint-surface.md) | JavaScript 可见信号、差距分析 |
| 07 | [构建工具链](07-build-toolchain.md) | 为什么这台 VPS 不能构建 Chromium |
| 08 | [目标架构](08-architecture.md) | 指纹浏览器的设计 |
| 09 | [路线图](09-roadmap.md) | 阶段、交付物、退出标准 |
| 10 | [采集方法](10-collection-method.md) | 脚本、探测、脱敏、局限 |
| 11 | [伦理与可接受使用](11-ethics.md) | 允许与禁止的用途 |

## 约定

- 快照日期为 **2026-11-12**，除非另有说明。
- `REDACTED`、`203.0.113.10`、`198.51.100.x`、`2001:db8::` 是占位符。
- “实测”表示由命令或浏览器探针捕获；“推断”表示基于测量值的分析；“计划”表示后续阶段的
  设计决定。
- Chrome/Chromium 版本会变化，任何快照都必须记录精确版本号。
