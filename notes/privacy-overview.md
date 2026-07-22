# 跨平台隐私方案总览（主索引）

> **用途**: 把 macOS / Windows / WSL2 / iOS 四套隐私文档串起来，说明两套不同架构与一致性规则
> **最后更新**: 2026-07-22
> **核心 VPN**: SakuraCat（机场/落地代理客户端）
> **DNS 加密**: macOS 用 Cloudflare WARP；Windows/WSL2/iOS 用 TUN/全隧道封装

---

## 一、两套架构（关键认知）

本方案在四类环境上运行，但 **DNS 加密机制不同**，这是最容易混淆的点：

| 环境 | 流量出口 | DNS 加密 | 应用层代理变量 | 浏览器 WebRTC 风险 |
|---|---|---|---|---|
| **Windows 宿主机** | SakuraCat **TUN**（Meta Tunnel）+ 本地混合端口 **7897** | 隧道封装（**无 WARP**） | 不需要（TUN 抓全流量） | 较低（TUN 已抓 UDP） |
| **WSL2 Ubuntu-24.04** | 继承 Windows TUN 隧道 | 隧道封装（**无 WARP**） | 默认不需要（TUN） | 不涉及（无浏览器） |
| **macOS 宿主机** | SakuraCat **代理 7897** | **Cloudflare WARP（DNS-only）** | **需要** `http_proxy=127.0.0.1:7897` | **较高**（代理不抓 UDP） |
| **iOS / iPadOS** | SakuraCat iOS **全隧道**（或代理） | 隧道封装（或 Cloudflare 1.1.1.1） | 不需要（全隧道抓全流量） | 中（Safari WebKit） |

> ?? **macOS 为什么不用 TUN？** 因为 macOS 端同时跑了 Cloudflare WARP，TUN 虚拟网卡会和 WARP 抢网卡/路由。
> 故 macOS 改为「SakuraCat 代理 7897（出口）+ WARP DNS-only（加密）」，职责分离、互不冲突。
> 若误把 WARP 开成全隧道，会覆盖 SakuraCat 出口 IP，变成 Cloudflare —— **务必 WARP = DNS 模式**。
>
> ?? **Windows / iOS 不用 WARP**：它们靠 TUN / 全隧道封装 DNS，无 WARP。Windows 宿主机虽同时监听 7897 混合端口，但那是给终端/Docker 容器显式用的（见 Windows 文档第七部分）。

---

## 二、四端一致性规则（必须遵守）

无论哪端，以下三项统一，否则指纹会被识破：

1. **时区**：`America/New_York`（IANA）= Windows `Eastern Standard Time` = iOS `New York`
2. **DNS**：`1.1.1.1`（macOS 经 WARP 加密；Windows/WSL2/iOS 经隧道封装）
3. **区域/语言**：`en_US` / `en_US.UTF-8` / iOS `United States` + `English (US)`

> 判读口诀：出口 IP 是美国，时区也得是美国，区域也得是美国 —— 三者一致才不露馅。

---

## 三、文档索引

| 文档 | 平台 | 说明 |
|---|---|---|
| `macos-host-privacy-setup.md` | macOS（实测） | 代理 7897 + WARP；含 Safari/Firefox/Chrome WebRTC、Apple Container |
| `macos-privacy.sh` | macOS | 一键 apply / verify / restore 脚本 |
| `windows-host-privacy-setup.md` | Windows 10/11 | SakuraCat TUN + 7897 混合端口；时区/DNS/区域 + WebRTC |
| `ios-privacy-setup.md` | iOS / iPadOS | SakuraCat iOS 全隧道（或代理 + Cloudflare 1.1.1.1）；时区/区域/WebRTC |
| `wsl2-ubuntu24-privacy-setup.md` | WSL2 Ubuntu-24.04 | 隔离环境；TUN 继承；DNS 锁定；无代理变量 |
| `wsl2-privacy-isolation-guide.md` | WSL2 | 隔离思路补充 |
| `wsl2-setup-plan.md` | WSL2 | 部署计划 |
| `wsl2-sakuracat-privacy-setup.md` | WSL2 | SakuraCat 专项 |
| `windows-host-privacy-setup` 相关 PDF | Windows/WSL2 进入 | `Windows WSL2 进入方法.pdf` |
| `前置代理.md` | 通用 | v2rayN TUN + 链式代理（前置机场 → 静态住宅 IP）原理 |
| `cat.md` / `computer-use-accuracy-report.md` | — | 待确认用途 |

---

## 四、跨平台一致性核对结论（2026-07-22）

| # | 发现 | 严重度 | 处理 |
|---|---|---|---|
| 1 | macOS 文档原写 TUN/utun，实际是代理 7897 + WARP | ? 高 | ? 已重写 `macos-host-privacy-setup.md` |
| 2 | Safari WebRTC 旧建议「禁用 mDNS」会暴露真实 IP | ? 高 | ? 已改为保留 mDNS / 关 WebRTC |
| 3 | Apple Container 段写「TUN 不需要代理」对 macOS 错误 | ? 高 | ? 已改为必须 `host.container.internal:7897` |
| 4 | macOS 旧版关掉网络时间导致时钟漂移 | ? 中 | ? 改为保留网络时间、只关自动时区 |
| 5 | 缺 IPv6 / iCloud 私有中继 / 防火墙 / 终端代理 处理 | ? 中 | ? macOS 文档已补 |
| 6 | 文末 `opencode` 残留 artifact | ? 低 | ? 已清理 |
| 7 | Windows 也用 7897 代理端口 | ? 已确认 | ? Windows 文档新增第七部分；iOS 文档已建 |

---

## 五、关键坑速记

- **Safari mDNS**：mDNS `.local` 是 Safari 隐藏真实 IP 的机制，**不要禁用**（macOS / iOS 同此）。
- **代理 vs TUN**：TUN 自动抓全流量（含 UDP/命令行）；代理只抓配置了代理的 App，**终端必须手设 `http_proxy`**。
- **WARP 模式**：macOS 上 WARP 必须是 **DNS-only**，不是全隧道。
- **iCloud 私有中继**：会和 WARP / VPN 抢 DNS，macOS / iOS 必须关。
- **容器 127.0.0.1 陷阱**：容器内 `127.0.0.1` ≠ 宿主机，macOS 用 `host.container.internal`，Windows Docker 用 `host.docker.internal`。
- **验证别用 ipinfo.io**（429 限流），统一用 `https://1.1.1.1/cdn-cgi/trace`。

---

## 六、待确认项（已全部确认 / 完成）

1. ? **Windows 代理端口 7897**：已确认 Windows 宿主机确实暴露 7897 混合端口。已在 `windows-host-privacy-setup.md` 新增「第七部分：7897 代理端口用法（终端 / Docker 容器）」，含 `host.docker.internal:7897`。
2. ? **WARP 在 Windows 端不用**：维持结论（Windows 靠 TUN 封装 DNS，无 WARP）。无需改动。
3. ? **iOS / iPadOS 端**：已新建 `ios-privacy-setup.md`（SakuraCat iOS 全隧道为主；仅代理模式时配 Cloudflare 1.1.1.1 / WARP；关私有中继；Safari WebRTC 保留 mDNS）。

---

**文档结束** _最后更新: 2026-07-22_
