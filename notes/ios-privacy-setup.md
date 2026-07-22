# iOS / iPadOS 隐私保护设置清单

> **用途**: 在 iPhone / iPad 上配置隐私保护，与 macOS / Windows / WSL2 方案配套
> **最后更新**: 2026-07-22
> **VPN / 代理**: SakuraCat iOS 客户端（优先全隧道 VPN 模式；若仅代理则配合 Cloudflare 1.1.1.1 / WARP 做 DNS 加密）
> **配套文档**: `macos-host-privacy-setup.md`, `windows-host-privacy-setup.md`, `privacy-overview.md`
> **目标**: 时区隐私 + DNS 隐私 + 区域隐私（+ Safari WebRTC）

---

## ⚠️ 架构说明（必须先读）

> iOS 上 VPN App（含 SakuraCat iOS）走系统 **NETunnelProvider（包隧道 / 全隧道）**，
> 一旦连接即**抓全设备流量（含 DNS）**，行为与 Windows 的 TUN 模式一致 —— 即 **不需要**额外代理端口，
> 这一点**不同于 macOS（macOS 是 SakuraCat 代理 + WARP 并存）**。
>
> 因此 iOS 推荐做法：**SakuraCat iOS 跑全隧道 VPN 模式** → DNS 由隧道封装加密，无需 WARP。
>
> 仅当 SakuraCat iOS **只提供代理（非全隧道）** 时，才需另开 **Cloudflare 1.1.1.1 App / WARP iOS** 做 DNS 加密（与 macOS 思路相同）。
> 无论哪种，都需**关闭 iCloud 私有中继**（否则覆盖 DNS / VPN）。

### 与三端的一致性

| 项 | 值 |
|---|---|
| 时区 | `America/New_York`（纽约，东部） |
| DNS | `1.1.1.1`（经隧道封装，或经 Cloudflare 1.1.1.1 App 加密） |
| 区域 | 美国（United States） |
| 语言 | English (US) |

---

## 快速操作速查

| 用途 | 路径 / 命令 |
|------|------|
| 关自动时区 | 设置 → 通用 → 日期与时间 → 关闭「自动设置」 |
| 设时区纽约 | 同上 → 时区 → 选 `New York` |
| 区域设美国 | 设置 → 通用 → 语言与地区 → 地区 → `United States` |
| 语言设英文 | 设置 → 通用 → 语言与地区 → iPhone 语言 → `English (US)` |
| 关私有中继 | 设置 → [Apple ID] → iCloud → 私有中继 → 关闭 |
| 系统 DNS | 设置 → Wi-Fi → 当前网络 ⓘ → 配置 DNS → 手动 → 1.1.1.1 / 8.8.8.8 |
| Safari WebRTC | 设置 → Safari → 高级 → 关闭「检查 Apple Pay 与 Apple 卡片」等；用内容拦截器 |
| 验证出口 | Safari 打开 https://1.1.1.1/cdn-cgi/trace 或 ipleak.net |

---

## 第一部分：时区隐私（最高优先级）

### 1.1 关自动时区，设为纽约

```text
设置 → 通用 → 日期与时间
  • 关闭「自动设置」
  • 时区 → 搜索并选择 New York（America/New_York，UTC-5/-4）
```

- ✅ 应显示 `New York`（与 macOS `America/New_York`、Windows `Eastern Standard Time` 一致）。

> ⚠️ 不关「自动设置」会被定位改回中国时区，破坏指纹一致性。

---

## 第二部分：DNS 隐私

### 2.1 主方案：SakuraCat iOS 全隧道（推荐）

> 连接 SakuraCat iOS 的 VPN / 全隧道模式后，设备全部流量（含 DNS）经隧道出口，
> DNS 被隧道封装加密，**无需**额外配置。确认「设置 → 顶部 VPN 图标亮起」即可。

### 2.2 备选：仅代理模式 + Cloudflare 1.1.1.1 / WARP

> 若 SakuraCat iOS 只提供代理（不抓全流量），则需另开 DNS 加密：
> - 安装 **Cloudflare 1.1.1.1 App** 或 **WARP App** → 启用（保持「1.1.1.1」DNS 模式，不要全隧道以免与 SakuraCat 出口冲突）。
> - 或手动设系统 DNS（明文，弱于上者）：`设置 → Wi-Fi → ⓘ → 配置 DNS → 手动 → 添加 1.1.1.1、8.8.8.8`。

### 2.3 iCloud 私有中继（必须关闭）

> 私有中继会**覆盖**系统 DNS / VPN，使上述加密失效：
> `设置 → [你的 Apple ID] → iCloud → 私有中继 → 关闭`。

### 2.4 IPv6

> iOS 默认双栈。若担心 IPv6 DNS 绕过，可在 SakuraCat / 1.1.1.1 App 内开启 IPv6 支持，
> 或仅依赖全隧道（全隧道通常同时处理 IPv4/IPv6）。

---

## 第三部分：区域 / 语言隐私

```text
设置 → 通用 → 语言与地区
  • 地区 → United States
  • iPhone 语言 → English (US)
  • 日历 / 温度单位（可选）→ 美式
```

> 改语言后需重启 SpringBoard（系统会提示）。仅为强化一致性，非必需。

---

## 第四部分：Safari WebRTC 泄露（进阶）

> iOS 浏览器内核统一为 WebKit（Safari 引擎），WebRTC 行为与 macOS Safari 同源。
> **关键：保持 mDNS 候选开启** —— iOS/macOS Safari 用 mDNS `.local` 隐藏真实本地 IP，**不要**禁用它。

```text
设置 → Safari → 高级
  • 保留默认（WebKit 默认以 mDNS 隐藏本地 IP）
  • 关闭不必要的权限：设置 → Safari → 相机 / 麦克风 → 设为「询问」或关闭，
    减少 WebRTC 媒体权限触发
```

> 进一步加固：安装 **内容拦截器**（如 1Blocker / AdGuard）并在 Safari 扩展中启用，
> 可过滤部分追踪与 WebRTC 探测脚本。

### 验证

Safari 打开：
- https://ipleak.net/ —— "WebRTC IP" 应为空或节点 IP；"Your country" 应为美国。
- https://www.browserleaks.com/webrtc —— 显示无公网 IP 泄露即成功。

---

## 第五部分：验证

```text
1. 设置 → 顶部确认 VPN 已连接（全隧道模式）
2. Safari 打开 https://1.1.1.1/cdn-cgi/trace
   • 应看到 loc=US，ip= 节点 IP
3. Safari 打开 https://browserleaks.com/webrtc 确认无 WebRTC 泄露
4. 确认 iCloud 私有中继已关闭
```

**判读标准**：
- ✅ 时区 `New York`
- ✅ 区域 / 语言 `United States` / `English (US)`
- ✅ VPN 图标亮起（全隧道）或 Cloudflare 1.1.1.1 已启用
- ✅ `loc=US`，`ip=` 为节点 IP
- ✅ 私有中继关闭
- ✅ WebRTC 无泄露

> ⚠️ 综合自查：https://browserleaks.com （IP / 时区 / WebRTC / DNS）。

---

## 第六部分：恢复步骤

```text
设置 → 通用 → 日期与时间 → 开启「自动设置」（或改回 China）
设置 → 通用 → 语言与地区 → 地区 → China mainland；iPhone 语言 → 简体中文
设置 → [Apple ID] → iCloud → 私有中继 → 开启（如需要）
SakuraCat iOS → 断开 VPN / 关闭代理
Cloudflare 1.1.1.1 / WARP → 断开
```

---

## 注意事项与安全建议

### ⚠️ 必须遵守
1. **时区必须改**：出口 IP（美国）与时区（中国）不一致会被指纹识破。
2. **关闭 iCloud 私有中继**：否则覆盖 DNS / VPN。
3. **SakuraCat iOS 优先全隧道**：与 Windows TUN 一致，无需额外代理端口。
4. **不要禁用 Safari mDNS**：那是隐藏真实 IP 的机制。
5. **保持 SakuraCat 连接**：iOS 网络隐私依赖它。

### ✅ 推荐做法
1. 四端（macOS / Windows / WSL2 / iOS）时区 DNS 区域保持一致（美东 / 1.1.1.1 / en_US）。
2. 每周用第五部分验证一次。
3. 优先处理 WebRTC 泄露（Safari，见第四部分）。
4. 用 https://browserleaks.com 综合自查。

---

**文档结束** _最后更新: 2026-07-22_
_架构实测参考 + 与三端一致性修订_
