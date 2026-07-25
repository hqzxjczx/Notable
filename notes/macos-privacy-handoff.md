# macOS 隐私状态交接文档

> **生成时间**: 2026-07-24
> **生成者**: QoderCN（基于 notes/ 目录文档 + 实机检测）
> **目标机器**: macOS 26.5.2 (Build 25F84), Apple Silicon (arm64)
> **架构**: SakuraCat 代理模式 (127.0.0.1:7897) + 无 WARP（未安装）
> **配套文档**: `macos-host-privacy-setup.md`, `macos-privacy.sh`, `privacy-overview.md`

---

## 一、实机检测结果（2026-07-24）

### 已通过

| 项目 | 状态 | 证据 |
|------|------|------|
| SakuraCat 进程 | 运行中 | PID 52810, 自周二起 |
| 系统代理 (HTTP/HTTPS/SOCKS) | 已配置 127.0.0.1:7897 | `networksetup -getwebproxy Wi-Fi` 三项均 Enabled |
| iCloud 私有中继 | 已关闭 | `Relay = 0` (com.apple.networkextension.plist) |
| Quad101 DoH profile | 已禁用 | `Enabled = 0` |
| 系统防火墙 (ALF) | 已启用 | ContentFilter Enabled=1, FilterSockets=1 |
| Apple Container CLI | 已安装 v1.1.0 | `/usr/local/bin/container` |
| macOS 版本 | 26.5.2 | 完整支持 Apple Container |

### 未通过（需修复）

| # | 项目 | 当前值 | 目标值 | 严重度 | 修复方式 |
|---|------|--------|--------|--------|----------|
| 1 | 区域 | `zh-Hans_HK` | `en_US` | 高 | `defaults write NSGlobalDomain AppleLocale -string "en_US"` |
| 2 | 语言 | `zh-Hans-HK, zh-Hant-HK` | `en` | 高 | `defaults write NSGlobalDomain AppleLanguages -array "en"` |
| 3 | 终端 locale 环境 | `en_HK.UTF-8` | `en_US.UTF-8` | 高 | .zshrc 写入 LANG/LC_ALL |
| 4 | 自动时区 | `Active = 1`（开启） | 关闭 | 高 | `sudo systemsetup -setusingnetworktime off` + GUI 关定位设时区 |
| 5 | 时区值 | 未确认（需 sudo） | `America/New_York` | 高 | `sudo systemsetup -settimezone America/New_York` |
| 6 | 终端代理变量 | 未设置 | `http_proxy=http://127.0.0.1:7897` 等 | 高 | .zshrc 写入代理块 |
| 7 | .zshrc 隐私块 | 不存在 | 存在（MACOS-PRIVACY-PROXY + LOCALE） | 高 | 运行 `macos-privacy.sh apply us` |
| 8 | IPv6 | `Automatic` (Wi-Fi) | Off | 高 | `networksetup -setv6off Wi-Fi` |
| 9 | DNS 加密 | 明文走路由器 192.168.31.1 | WARP DNS-only 或 DoH 1.1.1.1 | 高 | 安装 WARP 或部署 DoH profile |
| 10 | 出口 IP 验证 | curl 失败（终端无代理） | `loc=US` + 节点 IP | 高 | 修复 #6 后验证 |
| 11 | Container privacy.env | ✅ 已创建 | `~/.config/container/privacy.env`（用 192.168.64.1:7897，实测 loc=US） |
| 12 | Container config.toml | 可选，未创建 | 按需 |
| 13 | WebRTC 浏览器防护 | 未确认 | Safari 保留 mDNS; Firefox 禁 WebRTC | 中 | 手动检查 |
| 14 | 定位服务 | 未确认 | 建议关闭（或至少关「设置时区」） | 中 | GUI |
| 15 | 诊断数据上报 | 未确认 | 关闭 | 低 | GUI |
| 16 | 个性化广告 | 未确认 | 关闭 | 低 | GUI |
| 17 | 出向防火墙 (LuLu) | ✅ 已安装 v4.3.2 | `/Applications/LuLu.app`，见文档 4.5 |

---

## 二、一键修复命令（推荐）

```bash
# 在 notes/ 目录下执行（修复 #1-8 + 写入 .zshrc）
cd /Users/fatestayzerotw/.copilot/repos/notable/notes
sudo ./macos-privacy.sh apply us

# 使终端生效
source ~/.zshrc

# 验证
./macos-privacy.sh verify us
```

脚本会自动处理：时区、区域/语言、IPv6 关闭、系统代理确认、.zshrc 代理+locale 块、DNS 缓存刷新。

**脚本不处理的**（需手动）：
- WARP 安装/DNS 加密（#9）— TUN dns-hijack 已部分覆盖
- 浏览器 WebRTC（#13）
- GUI 项：定位、诊断、广告（#14-16）

---

## 三、Apple Container 隐私配置（✅ 已创建 + 实测通过 2026-07-25）

已创建 `~/.config/container/privacy.env`：

```bash
TZ=America/New_York
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
http_proxy=http://192.168.64.1:7897
https_proxy=http://192.168.64.1:7897
all_proxy=socks5://192.168.64.1:7897
no_proxy=localhost,127.0.0.1,::1
```

**前置条件**：Clash Verge `allow-lan: true`（已通过 API + 配置文件持久化）

使用示例：
```bash
container run --rm \
  --env-file ~/.config/container/privacy.env \
  --dns 1.1.1.1 \
  alpine sh -c 'apk add --no-cache curl tzdata >/dev/null 2>&1; date; curl -s https://1.1.1.1/cdn-cgi/trace | grep -E "ip=|loc=|colo="'
```

实测结果（2026-07-25）：
- 时区: `Sat Jul 25 03:38:57 EDT 2026` ✓
- LANG: `en_US.UTF-8` ✓
- 出口: `ip=23.172.200.70  colo=SJC  loc=US` ✓

关键点（实测发现）：
- **不用 `host.container.internal`**：TUN `dns-hijack` 把它解析成 fake-ip（198.18.x.x），容器连不上
- 改用**网关 IP `192.168.64.1`**（Apple Container 固定子网，无需 DNS）
- **必须 `allow-lan: true`**：Clash 默认只监听 127.0.0.1，容器 VM 在 192.168.64.x 网段
- **TUN 不路由容器 TCP**：DNS 劫持有效但 TCP 不走 TUN，必须用代理变量
- TZ 生效需镜像含 tzdata（`apk add tzdata`）

---

## 四、DNS 加密方案选择（待决策）

当前 DNS 走路由器 192.168.31.1（明文 UDP 53），两个选项：

| 方案 | 优点 | 缺点 |
|------|------|------|
| **A: 安装 Cloudflare WARP (DNS-only)** | 文档已写好、与方案一致 | 多一个后台进程 |
| **B: 部署 DoH 配置描述文件到 1.1.1.1** | 无需额外 App、系统原生 | 需制作 .mobileconfig |

方案 B 参考（已有 Quad101 DoH profile 框架可改）：
- ServerURL: `https://1.1.1.1/dns-query`
- Servers: `1.1.1.1`, `1.0.0.1`, `2606:4700:4700::1111`, `2606:4700:4700::1001`

无论哪种，修好后验证：`scutil --dns | head -20` 应见 1.1.1.1。

---

## 五、网络接口备注

活跃接口：`Wi-Fi`, `Thunderbolt Bridge`
- `macos-privacy.sh` 会遍历所有活跃接口关 IPv6（含 Thunderbolt Bridge）
- 系统代理只设了 Wi-Fi（若用 Thunderbolt Bridge 联网需额外设）

---

## 六、验证清单（修复后逐项确认）

```bash
# 终端验证
sudo systemsetup -gettimezone          # → America/New_York
defaults read NSGlobalDomain AppleLocale  # → en_US
echo $http_proxy                       # → http://127.0.0.1:7897
networksetup -getinfo Wi-Fi | grep IPv6   # → IPv6: Off
scutil --dns | head -5                 # → nameserver 含 1.1.1.1
curl -s https://1.1.1.1/cdn-cgi/trace | grep -E 'ip=|loc='  # → loc=US

# 浏览器验证
# https://ipleak.net/ → WebRTC IP 应为空或节点 IP
# https://browserleaks.com/webrtc → No public IP leaked

# Container 验证
container run --rm --env-file ~/.config/container/privacy.env --dns 1.1.1.1 alpine \
  sh -c 'apk add --no-cache curl tzdata >/dev/null 2>&1; date; curl -s https://1.1.1.1/cdn-cgi/trace | grep -E "ip=|loc=|colo="'
```

---

## 七、注意事项

1. **WARP 绝不能开全隧道**：只能 DNS-only，否则覆盖 SakuraCat 出口
2. **SakuraCat 不开 TUN**：避免与 WARP 抢网卡
3. **改区域/语言后需注销或重启**才完全生效（GUI 层面）
4. **自动时区需 GUI 双保险**：系统设置 → 隐私与安全性 → 定位服务 → 系统服务 → 关「设置时区」
5. **验证别用 ipinfo.io**（429 限流），统一用 `https://1.1.1.1/cdn-cgi/trace`
6. **三端一致性**：macOS / Windows / WSL2 必须同时区 + 同 DNS + 同区域

---

_文档结束_
