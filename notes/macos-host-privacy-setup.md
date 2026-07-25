# macOS 宿主机隐私保护设置清单

> **用途**: 在 macOS 上配置隐私保护，与 WSL2 (Ubuntu-24.04) / Windows 隐私方案配套
> **最后更新**: 2026-07-22
> **架构**: SakuraCat **代理模式（端口 7897）** 负责流量出口 + **Cloudflare WARP（1.1.1.1 DNS 模式，非全隧道）** 负责 DNS 加密
> **配套文档**: `wsl2-ubuntu24-privacy-setup.md`, `windows-host-privacy-setup.md`, `privacy-overview.md`
> **目标**: 时区隐私 + DNS 隐私 + 区域隐私（+ 可选进阶项）

---

## ?? 架构说明（必须先读）

> 本机**实测**环境（当前操作机即 macOS）。与 Windows / WSL2 的 **TUN 隧道**架构不同，macOS 采用：
>
> - **SakuraCat 客户端**：运行于**代理模式**，本地混合端口 **7897**（同时提供 HTTP 与 SOCKS5）。**不开启 TUN** —— 因为 TUN 虚拟网卡会与 Cloudflare WARP 抢网卡/路由，造成冲突。
> - **Cloudflare WARP**：运行于 **"1.1.1.1" / DNS-only 模式（仅加密 DNS，不开全隧道）**。它负责把系统 DNS 查询以 DoH/DoT 加密发往 1.1.1.1。
>
> 因此：**流量出口走 SakuraCat 代理 7897，DNS 加密走 WARP**。二者职责分离，互不冲突。
>
> 若误把 WARP 设为「流量和 DNS（UDP/TLS/HTTPS）」全隧道模式，它会接管全部流量并覆盖 SakuraCat 出口，导致出口 IP 变成 Cloudflare 而非你的节点 —— **务必保持 WARP 为「仅 DNS（HTTPS）」或「仅 DNS（TLS）」模式**（二者的（HTTPS）/（TLS）只是 DNS 查询自身的加密传输方式，都会 100% 加密全部 DNS 解析，与应用流量协议无关）。

### 与 Windows / WSL2 的核心差异

| 项 | Windows / WSL2 | macOS（本机） |
|---|---|---|
| VPN 形态 | SakuraCat **TUN**（Meta Tunnel） | SakuraCat **代理 7897**（无 TUN） |
| DNS 加密 | 由 TUN 隧道封装（无 WARP） | 由 **Cloudflare WARP** DNS-only 提供 |
| 应用层代理变量 | 默认不需要（TUN 已抓全流量） | **需要** `http_proxy=127.0.0.1:7897`（终端/容器/CLI） |
| 浏览器 WebRTC | TUN 已抓 UDP，相对不易漏 | 代理模式**不自动抓 UDP**，WebRTC 必须靠浏览器设置 |

> 通用约定三端一致：**时区 `America/New_York` + DNS `1.1.1.1` + 区域 `en_US`**。

---

## 快速命令速查

| 用途 | 命令 |
|------|------|
| 查看时区 | `sudo systemsetup -gettimezone` |
| 设时区为美东 | `sudo systemsetup -settimezone America/New_York` |
| 关「自动设时区」 | `sudo systemsetup -setusingnetworktime off`（仅关自动时区，**保留网络时间**见 1.1） |
| 查看系统 HTTP 代理 | `networksetup -getwebproxy Wi-Fi` |
| 设 SakuraCat 系统代理 | `networksetup -setwebproxy Wi-Fi 127.0.0.1 7897` 等（见 2.3） |
| 关闭系统代理 | `networksetup -setwebproxystate Wi-Fi off` 等（见 2.3） |
| 查看 DNS（被 WARP 接管） | `scutil --dns` |
| 查看 WARP 状态/模式 | `warp-cli status` / `warp-cli settings` |
| 刷新 DNS 缓存 | `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| 查看语言/区域 | `defaults read NSGlobalDomain AppleLocale` |
| 验证出口 IP | `curl -s https://1.1.1.1/cdn-cgi/trace \| grep -E 'ip=\|loc='` |

> ?? 若联网接口不是 `Wi-Fi`（如网线为 `Ethernet`），把命令里的 `Wi-Fi` 替换掉。
> ?? **不要修改 SakuraCat / WARP 创建的虚拟网卡配置**（VPN/DNS 内部路由，正常）。

---

## 第一部分：时区隐私（最高优先级）

### 1.1 关「自动设时区」，设为美东（保留网络时间防漂移）

> ?? **修正点**：旧版文档让你 `setusingnetworktime off` 完全关掉网络时间，会导致时钟漂移、TLS 证书校验出错。
> 正确做法：**只关「根据位置自动设时区」，保留网络时间**（网络时间只校时，不会改时区，只要自动时区开关关掉即可）。

```bash
# 关闭「根据当前位置自动设置时区」（防止被定位改回）
sudo systemsetup -setusingnetworktime off 2>/dev/null || true

# 设置时区为美东（与 Windows / WSL2 一致）
sudo systemsetup -settimezone America/New_York

# 验证
sudo systemsetup -gettimezone
```

- ? 应显示 `Time Zone: America/New_York`

### 1.2 GUI 关闭定位驱动自动时区（建议同步做）

> 命令行无法完全关闭定位驱动的自动时区，建议同时在 GUI 关闭：
> **系统设置 → 隐私与安全性 → 定位服务 → 系统服务 → 关闭「设置时区」**
> （旧版：系统偏好设置 → 日期与时间 → 时区 → 取消「根据当前位置自动设置时区」）

---

## 第二部分：DNS 隐私（高优先级，由 WARP 负责）

### 2.1 主方案：用 Cloudflare WARP 做 DNS 加密（推荐）

macOS 上 DNS 加密统一交给 **WARP 的 1.1.1.1 DNS 模式**：WARP 接管系统 DNS 并以加密协议发往 1.1.1.1，**不要**再手动给 Wi-Fi 设明文 `1.1.1.1/8.8.8.8`（会被 WARP 覆盖，且明文无意义）。

```bash
# 确认 WARP 已安装并能运行（GUI 或 CLI 均可）
warp-cli status            # 应显示已注册/已连接

# 关键：WARP 必须处于「DNS only / 仅 DNS」模式，而【不是】「流量和 DNS（全隧道）」
#   - GUI: Cloudflare 应用 → 偏好设置 → 连接模式 → 选「仅 DNS（HTTPS）」或「仅 DNS（TLS）」
#         （切勿选「流量和 DNS（UDP / TLS / HTTPS）」——那会接管全部流量、覆盖 SakuraCat 出口）
#   - （HTTPS）/（TLS）仅指 DNS 查询自身的加密传输协议，二者都会加密全部 DNS 解析，与应用流量协议无关
#   - CLI: warp-cli 无直接 "dns-only" 开关时，以 GUI 为准
warp-cli settings          # 检查当前模式

# 刷新 DNS 缓存使 WARP 接管生效
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 验证 DNS 已由 WARP 处理
scutil --dns | head -20    # 应看到 resolver 指向 1.1.1.1 / WARP
```

> ? **判读**：`scutil --dns` 中 `nameserver` 解析链出现 `1.1.1.1` 且 WARP 状态为 DNS 模式即成功。
> ?? **绝不能**把 WARP 设为「流量和 DNS（UDP / TLS / HTTPS）」任一种全隧道模式——否则全部流量改走
> Cloudflare，出口 IP 会变成 Cloudflare 而非你的 SakuraCat 节点。只能选「仅 DNS（HTTPS）」或「仅 DNS（TLS）」。

### 2.2 iCloud 私有中继冲突（必须关闭）

> iCloud 私有中继会**覆盖**系统 DNS，使 WARP 的 DNS 加密失效。启用 WARP 前必须关掉它：
> **系统设置 → [你的 Apple ID] → iCloud → 私有中继 → 关闭**。

### 2.3 IPv6 泄露（必须处理）

> WARP 的 DNS-only 模式通常只加密 **IPv4** DNS。若系统启用 IPv6，IPv6 的 DNS 查询 / WebRTC 可能绕过 WARP 暴露真实网络。
> 最稳妥：在联网接口**关闭 IPv6**（或把 IPv6 DNS 也指向加密通道）。

```bash
# 关闭 Wi-Fi 的 IPv6（如用网线把 Wi-Fi 换为 Ethernet）
networksetup -setv6off Wi-Fi

# 验证
networksetup -getinfo Wi-Fi | grep -i 'IPv6'
```

> 若你确实需要 IPv6，至少把 IPv6 DNS 设为加密通道（WARP 支持时）或 `2606:4700:4700::1111`（Cloudflare IPv6 DNS）。

### 2.4 （可选）手动 DNS 兜底（仅当未用 WARP 时）

若你**没**用 WARP，可手动设 Wi-Fi DNS 为公网 DNS（注意这仍是明文 UDP 53，不如 WARP 加密）：

```bash
networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

---

## 第三部分：区域 / 语言隐私

将系统语言与区域统一为美国英语，减少指纹特征：

```bash
# 语言设为英文优先
defaults write NSGlobalDomain AppleLanguages -array "en"

# 区域设为美国
defaults write NSGlobalDomain AppleLocale -string "en_US"

# 度量单位（可选）
defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"
defaults write NSGlobalDomain AppleMetricUnits -bool false
```

> 更改后需**注销或重启**才完全生效。仅为强化一致性，非必需。

---

## 第四部分：进阶隐私（可选，默认不执行）

> ???? **以下命令有副作用，默认注释，请逐条评估后再手动执行**。
> 关闭定位/诊断可能影响「查找」、地图、天气等功能。

### 4.1 WebRTC 本地 IP 泄露（浏览器层，推荐优先做）

> ?? **macOS 代理模式的特殊性**：SakuraCat 走 7897 代理，**不会自动抓取 UDP**（不像 TUN 一把抓全流量）。
> 因此 WebRTC 的 STUN/UDP 流量很可能**绕过代理**直接暴露真实网卡 IP。WebRTC 防护在 macOS 上**比 Windows 更关键**，必须靠浏览器自身设置，不能依赖 VPN。

#### 4.1.1 Safari 配置（?? 已修正，旧版建议是错的）

> **旧版文档让你「禁用 mDNS ICE candidates」——这是反效果！** Safari 正是用 mDNS `.local` 候选来**隐藏真实本地 IP** 的；禁用 mDNS 会让它回退暴露真实网卡地址。正确做法：

```text
1. 打开「Safari → 设置 → 高级」，勾选「在菜单栏中显示"开发"菜单」
2. 顶部菜单「开发」→「WebRTC」子菜单
3. ? 正确做法：保持 mDNS 候选开启（不要禁用）；
   若要更严格，选「Disable ICE Candidate Restrictions」收紧候选范围；
   若想彻底关闭 WebRTC：在「开发 → WebRTC」中关闭 "Allow Media Peer Connection" 类选项
4. 重启 Safari 生效
```

#### 4.1.2 Firefox 配置（详细步骤）

**第一步：about:config 配置三项**（地址栏输入 `about:config`）：

| 配置项 | 现值 | 改为 | 作用 |
|-------|------|------|------|
| `media.peerconnection.ice.default_address_only` | false | **true** | 仅用默认网络地址，隐匿其他网卡 IP |
| `media.peerconnection.ice.no_host` | false | **true** | 禁用 host 候选（防暴露真实公网 IP） |
| `media.peerconnection.enabled` | true | **false** | 彻底禁用 WebRTC（最彻底，影响音视频通话）|

**第二步：扩展（推荐 uBlock Origin）**
- Firefox 附加组件搜索 **"uBlock Origin"** → 添加 → ?? 设置 → 高级用户 → 勾选 **"Block WebRTC IP leak"**。

> 或安装 **"WebRTC Leak Prevent"** 轻量扩展，选项里勾选 Prevent WebRTC Leaks + Block all。

#### 4.1.3 Chrome / Edge 配置（macOS 上同 Windows 同源）

> macOS 上 Chrome/Edge 基于 Chromium，行为一致；`chrome://` 在 Edge 为 `edge://`。

- **扩展（推荐）**：Chrome 网上应用店搜 "WebRTC Leak Prevent" → Options → 勾选 Prevent WebRTC Leaks + Block all。
- **flags（高级）**：`chrome://flags` 搜索 WebRTC → 将 `Restrict WebRTC IP Handling Policy` 等改为 Disabled → 重启。

#### 4.1.4 验证

完成后访问：
- https://ipleak.net/ —— 检查 "WebRTC IP" 应为空或显示节点 IP；"Your country" 应为美国。
- https://www.browserleaks.com/webrtc —— 显示 **"No public IP address leaked"** 即成功。

#### 4.1.5 终端 / CLI 代理（WebRTC 之外，必须设）

> 浏览器以外的程序（终端 `curl`、Git、Claude Code 等）**不会**自动走 SakuraCat 代理。需导出环境变量：

```bash
export http_proxy="http://127.0.0.1:7897"
export https_proxy="http://127.0.0.1:7897"
export all_proxy="socks5://127.0.0.1:7897"
# 验证：应显示节点 IP
curl -s https://1.1.1.1/cdn-cgi/trace | grep -E 'ip=|loc='
```

> 可把这些写入 `~/.zshrc`（macOS 默认 shell 为 zsh）。仅 SakuraCat 代理运行时生效。

### 4.6 浏览器 Accept-Language 指纹（推荐做）

> **问题**：浏览器在每个 HTTP 请求头中携带 `Accept-Language`，如果值为 `zh-CN,zh,en`，即使 IP 在美国、时区是 `America/New_York`，网站仍能判定你是中文用户 — 三者不一致即露馅。

| 浏览器 | Accept-Language 来源 | 系统改了够不够 |
|---|---|---|
| **Safari** | 跟随系统 `AppleLanguages` | ✅ 够（`macos-privacy.sh apply` 已设）|
| **Chrome** | **独立的 per-profile `intl.accept_languages`** | ❌ 不够 — Chrome 会覆盖系统语言 |
| **Firefox** | `about:config` → `intl.accept_languages` | ❌ 不够 — 需手动设 |

#### Chrome 修复（脚本已自动处理）

`macos-privacy.sh apply` 会自动修改 Chrome 的 `Local State` 和所有 Profile 的 `Preferences` JSON：

```bash
# apply us 时自动执行（等价命令）:
python3 -c "
import json, os, glob
cd = os.path.expanduser('~/Library/Application Support/Google/Chrome')
for p in [os.path.join(cd,'Local State')] + sorted(glob.glob(os.path.join(cd,'Default*/Preferences'))):
    d = json.load(open(p)); d.setdefault('intl',{})
    d['intl']['accept_languages'] = 'en-US,en'
    d['intl']['selected_languages'] = 'en-US,en'
    json.dump(d, open(p,'w'), indent=2)
"
```

> **注意**：Chrome 运行时修改 Preferences 可能被覆盖。**必须完全退出 Chrome 后重新打开**才生效。

#### Firefox 修复（手动）

地址栏输入 `about:config` → 搜索 `intl.accept_languages` → 设为 `en-US,en`。

#### 验证

访问 https://browserleaks.com/ip → 查看 HTTP Headers 中 `Accept-Language` 是否为 `en-US,en;q=0.9`（无 `zh` 字样）。

---

### 4.2 关闭定位服务（风险：影响查找/地图/天气）

```bash
# 【风险项，默认不执行】建议用 GUI 更安全：
# 系统设置 → 隐私与安全性 → 定位服务 → 关闭总开关
```

### 4.3 关闭诊断与分析数据上报（风险：影响向 Apple 反馈）

```bash
# 【风险项，默认不执行】关闭向 Apple 发送诊断数据：
# 系统设置 → 隐私与安全性 → 分析与改进 → 关闭「共享 Mac 分析」「共享 Siri 与听写」
```

### 4.4 关闭个性化广告（低风险）

```bash
# 系统设置 → 隐私与安全性 → Apple 广告 → 关闭「个性化广告」
```

### 4.5 出向防火墙 LuLu（推荐）

> macOS 自带防火墙（ALF）只防**入站**连接（别人连你），不管你的 App 往外发什么。
> **LuLu** 是 Objective-See 开源的**出向**防火墙，监控每个 App 的出站连接，弹窗让你决定放行还是拦截。
> 配合 TUN + 系统防火墙形成三层防护：TUN 接管流量出口，ALF 拦外部攻击，LuLu 管 App 联网行为。

#### macOS 自带防火墙 vs LuLu

| | 系统 ALF | LuLu |
|---|---|---|
| 方向 | **入站**（阻止外部连入） | **出站**（监控/拦截 App 联网） |
| 粒度 | 按服务/端口 | 按 App × 目标 IP/端口 |
| 交互 | 无弹窗 | 新连接弹窗询问 |
| 资源占用 | 系统内置 | ~15 MB 磁盘，< 20 MB RAM |
| 开源 | 否 | 是（Objective-See） |

#### 安装

**方式一：Homebrew（推荐）**

```bash
brew install --cask lulu
```

> 如果 Homebrew API 报错（`undefined method 'to_sym'`），先 `brew update` 再试，或用方式二。

**方式二：直接下载 DMG**

```bash
# 下载最新版（约 7 MB）
curl -L -o /tmp/LuLu.dmg "https://github.com/objective-see/LuLu/releases/latest/download/LuLu.dmg"
# 挂载、复制、卸载
hdiutil attach /tmp/LuLu.dmg -nobrowse
cp -R "/Volumes/LuLu"*/LuLu.app /Applications/
hdiutil detach "/Volumes/LuLu"*
rm /tmp/LuLu.dmg
```

> 当前已安装版本：v4.3.2，位于 `/Applications/LuLu.app`。

#### 首次运行设置

1. 打开 `/Applications/LuLu.app`
2. 系统提示「无法验证开发者」→ 系统设置 → 隐私与安全性 → 点击「仍要打开」
3. 系统扩展授权弹窗 → 系统设置 → 隐私与安全性 → 允许 LuLu 的系统扩展
4. LuLu 启动后进入规则界面

#### 规则策略（隐私优先）

| 进程 | 策略 | 说明 |
|------|------|------|
| Clash Verge / verge-mihomo | ✅ 允许 | 代理核心，必须联网 |
| Chrome / Safari / Firefox | ✅ 允许 | 浏览器 |
| warp-cli / Cloudflare WARP | ✅ 允许 | DNS 加密 |
| curl / git / ssh / node | ✅ 允许 | 开发工具 |
| locationd | ❌ 阻止 | 定位服务上报 |
| cloudd / iCloud 服务 | ⚠️ 按需 | 如已关 iCloud 私有中继可阻止 |
| 未知进程 / 可疑后台 | ❌ 阻止 | 首次弹窗先拦，确认安全后再放行 |

> 头几天弹窗会比较频繁（每个新 App 首次联网都弹），习惯后基本只有新 App 才弹。
> 已放行/阻止的规则保存在 LuLu 规则列表中，可在主界面修改。

#### 验证

```bash
# 确认 LuLu 安装
ls /Applications/LuLu.app && echo "已安装"

# 确认 LuLu 运行
pgrep -x LuLu && echo "运行中" || echo "未运行"
```

> LuLu 是可选增强项，不装也不影响代理+TUN+DNS 的核心防护。装了等于多一层「哪个 App 能联网」的知情权和控制权。

---

## 第五部分：验证

在终端执行完整检测：

```bash
echo "===== macOS 宿主机隐私检测 ====="
echo "[时区]"; sudo systemsetup -gettimezone
echo "[区域]"; defaults read NSGlobalDomain AppleLocale 2>/dev/null
echo "[WARP 模式]"; warp-cli status 2>/dev/null || echo "warp-cli 未安装/未运行"
echo "[系统代理]"; networksetup -getwebproxy Wi-Fi; networksetup -getsecurewebproxy Wi-Fi
echo "[IPv6]"; networksetup -getinfo Wi-Fi | grep -i 'IPv6'
echo "[DNS 解析链]"; scutil --dns | grep -A3 'nameserver'
echo "----- 出口 IP / 地理位置 -----"
curl -s https://1.1.1.1/cdn-cgi/trace | grep -E 'ip=|loc=|colo='
```

**判读标准**：
- ? 时区为 `America/New_York`
- ? 区域为 `en_US`
- ? WARP 处于 **DNS 模式**（非全隧道）
- ? 系统代理指向 `127.0.0.1:7897`
- ? IPv6 已关闭（或已加密）
- ? DNS 解析链含 `1.1.1.1`
- ? `loc=US`，`ip=` 为节点 IP → SakuraCat 代理 + WARP 生效且与时区一致

> ?? 不要用 `ipinfo.io` 验证，其免费接口会返回 `429 Rate limit`，请统一用 `1.1.1.1/cdn-cgi/trace`。
> 综合自查可访问 https://browserleaks.com （IP / 时区 / WebRTC / DNS）。

---

## 第六部分：恢复步骤

```bash
# 恢复自动时区（保留网络时间）
sudo systemsetup -setusingnetworktime on
# 或手动改回中国时区
sudo systemsetup -settimezone Asia/Shanghai

# 关闭 SakuraCat 系统代理
networksetup -setwebproxystate Wi-Fi off
networksetup -setsecurewebproxystate Wi-Fi off
networksetup -setsocksfirewallproxystate Wi-Fi off
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# 恢复 WARP 默认（关闭 DNS 接管）
#   GUI: Cloudflare 应用 → 断开 / 关闭；或 warp-cli disconnect
warp-cli disconnect 2>/dev/null || true

# 恢复语言/区域
defaults write NSGlobalDomain AppleLanguages -array "zh-Hans-CN" "en"
defaults write NSGlobalDomain AppleLocale -string "zh_CN"

# 恢复 IPv6
networksetup -setv6automatic Wi-Fi
```

> 语言/区域改回后需注销或重启生效。

---

## 注意事项与安全建议

### ?? 必须遵守
1. **时区必须改**：出口 IP 与时区不一致（如 IP 美国、时区中国）会被指纹识别识破。
2. **WARP 必须保持 DNS-only 模式**：开全隧道会覆盖 SakuraCat 出口，冲突。
3. **SakuraCat 不开 TUN**：避免与 WARP 抢网卡/路由。
4. **改时区/代理/DNS 需要 `sudo`**。
5. **不要动 SakuraCat / WARP 的虚拟网卡**（内部路由，正常）。
6. **进阶项（第四部分）默认不执行**，逐条评估副作用后再手动启用。
7. **终端/CLI 必须手设 `http_proxy`**：代理模式不自动抓命令行流量。

### ? 推荐做法
1. 三端（macOS / Windows / WSL2）时区与 DNS 保持一致（美东 / 1.1.1.1 / en_US）。
2. 每周运行第五部分验证脚本一次。
3. 优先处理 WebRTC 泄露（macOS 代理模式下更关键，见 4.1）。
4. 用 https://browserleaks.com 综合自查。

---

## 第七部分：Apple Container 容器隐私（实测通过 2026-07-25）

> **适用**: Apple `container` CLI（WWDC 2025 发布，在 macOS 26+ 完整支持，macOS 15 功能受限）
> 在 macOS 上用轻量级 VM 原生运行 Linux 容器。每个容器跑在独立微型 VM 中。

### 7.1 核心机制速览（实测修正：TUN + 代理模式下的真相）

| 机制 | 说明 |
|------|------|
| 网络 | 容器接宿主机 vmnet 虚拟网络，网关 `192.168.64.1`（宿主机） |
| DNS | `container run` 支持 `--dns` / `--dns-search` / `--no-dns` |
| 环境变量 | `-e KEY=value`、`--env-file <file>`（注入 `TZ` / `LANG` / 代理）|
| 全局配置 | `~/.config/container/config.toml` |
| 时区 | 宿主机 macOS 时区**不会**自动传入容器，需 `-e TZ=...`（镜像需含 tzdata）|
| **出口** | **必须显式注入代理变量指向 `192.168.64.1:7897`**（见下方说明）|

> **实测发现（2026-07-25）**：
> 1. **TUN `dns-hijack` 会劫持容器 DNS**：容器查询 `host.container.internal` → TUN 返回 fake-ip（198.18.x.x）→ 无法连接宿主机代理。
>    → **改用网关 IP `192.168.64.1`**（Apple Container 固定子网，无需 DNS 解析）。
> 2. **TUN 不路由容器 VM 的 TCP 流量**：DNS 劫持有效（返回 fake-ip），但 TCP 连接到 fake-ip 失败（连接被重置）。
>    → 容器**必须**走代理变量（`http_proxy=http://192.168.64.1:7897`），不能依赖 TUN 兜底。
> 3. **`allow-lan` 必须开启**：容器 VM 在 `192.168.64.x` 网段，Clash 默认 `allow-lan: false` 只允许 `127.0.0.1`。
>    → 需在 Clash Verge 设置 `allow-lan: true`（GUI: 设置 → 系统设置 → 允许局域网连接）。

### 7.2 DNS 隐私（容器内）

```bash
container run --rm \
  --dns 1.1.1.1 \
  alpine sh -c 'nslookup google.com; wget -q -O- https://1.1.1.1/cdn-cgi/trace'
```

> 容器内 DNS 不会自动走 WARP/TUN 加密，故显式 `--dns 1.1.1.1`（TUN `dns-hijack` 会接管，返回 fake-ip）。

### 7.3 时区 + 语言隐私

```bash
container run --rm \
  -e TZ=America/New_York \
  -e LANG=en_US.UTF-8 \
  -e LC_ALL=en_US.UTF-8 \
  --dns 1.1.1.1 \
  alpine sh -c 'apk add --no-cache tzdata >/dev/null 2>&1; date'
```

> `TZ` 生效需镜像内含 **tzdata** 包。Alpine: `apk add --no-cache tzdata`；Debian/Ubuntu: `apt-get install -y tzdata`。

### 7.4 代理配置（必须：allow-lan + 网关 IP）

> **关键陷阱（三处）**：
> 1. 容器里的 `127.0.0.1` 是容器本身，**不是 macOS 宿主机**。
> 2. **不能用 `host.container.internal`**：TUN `dns-hijack` 会把它解析成 fake-ip（198.18.x.x），容器连不上。
>    → 改用**网关 IP `192.168.64.1`**（Apple Container 固定子网 `192.168.64.0/24`，无需 DNS）。
> 3. **必须开 `allow-lan: true`**：Clash 默认只监听 `127.0.0.1`，容器 VM 在 `192.168.64.x` 网段访问不了。
>    → Clash Verge GUI: 设置 → 系统设置 → 允许局域网连接（或编辑 `clash-verge.yaml` 改 `allow-lan: true`）。

```bash
container run --rm \
  -e http_proxy=http://192.168.64.1:7897 \
  -e https_proxy=http://192.168.64.1:7897 \
  -e all_proxy=socks5://192.168.64.1:7897 \
  alpine/curl curl -s https://1.1.1.1/cdn-cgi/trace
```

### 7.5 可复用的 privacy.env 模板 + 完整示例

创建 `~/.config/container/privacy.env`：

```bash
mkdir -p ~/.config/container

cat > ~/.config/container/privacy.env << 'EOF'
TZ=America/New_York
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
http_proxy=http://192.168.64.1:7897
https_proxy=http://192.168.64.1:7897
all_proxy=socks5://192.168.64.1:7897
no_proxy=localhost,127.0.0.1,::1
EOF
```

使用：

```bash
container run --rm \
  --env-file ~/.config/container/privacy.env \
  --dns 1.1.1.1 \
  alpine sh -c 'apk add --no-cache curl tzdata >/dev/null 2>&1; date; curl -s https://1.1.1.1/cdn-cgi/trace | grep -E "ip=|loc="'
```

### 7.6 验证

```bash
container run --rm \
  --env-file ~/.config/container/privacy.env \
  --dns 1.1.1.1 \
  alpine sh -c 'apk add --no-cache curl tzdata >/dev/null 2>&1; echo "时区: $(date)"; echo "LANG=$LANG"; echo "----- 出口 IP -----"; curl -s https://1.1.1.1/cdn-cgi/trace | grep -E "ip=|loc=|colo="'
```

**判读标准**：
- `date` 显示美东时间（EDT/EST，如 `Sat Jul 25 03:38:57 EDT 2026`）
- `LANG=en_US.UTF-8`
- `loc=US`，`ip=` 为节点 IP，`colo=` 为 Cloudflare 节点 → 容器经 `192.168.64.1:7897` 走 SakuraCat 代理

### 7.7 清理 / 恢复

```bash
rm -f ~/.config/container/privacy.env
container system stop 2>/dev/null || true
# 可选：恢复 Clash allow-lan=false（GUI 或编辑 clash-verge.yaml）
```

### 7.8 故障排查

```bash
# 容器无法解析域名 → 显式指定公网 DNS（TUN dns-hijack 会接管，返回 fake-ip）
container run -it --rm --dns 1.1.1.1 alpine sh -c 'nslookup google.com; wget -q -O- https://1.1.1.1/cdn-cgi/trace'

# 容器出口连不上（超时/Connection reset）→ 检查代理变量 + allow-lan
container run --rm alpine sh -c 'env | grep -i proxy; ip route show default'
# 确认 http_proxy=192.168.64.1:7897 且网关=192.168.64.1
# 确认 Clash Verge allow-lan=true

# 宿主机侧确认代理可达
curl -s -x http://127.0.0.1:7897 https://1.1.1.1/cdn-cgi/trace | grep -E 'ip=|loc='
```

### 7.9 注意事项

1. **127.0.0.1 陷阱**：容器内 `127.0.0.1` ≠ macOS 宿主机，用网关 IP `192.168.64.1`。
2. **不用 `host.container.internal`**：TUN `dns-hijack` 把它解析成 fake-ip（198.18.x.x），容器连不上。改用 `192.168.64.1`。
3. **`allow-lan` 必须开**：Clash 默认 `allow-lan: false`，容器 VM 在 `192.168.64.x` 网段无法访问 `127.0.0.1:7897`。
4. **TUN 不路由容器 TCP**：TUN 的 `dns-hijack` 对容器 DNS 有效（返回 fake-ip），但容器的 TCP 流量不走 TUN。必须用代理变量。
5. **时区需 tzdata**：轻量镜像无 tzdata 时 `TZ` 不生效，回落 UTC。Alpine: `apk add tzdata`。
6. **WARP 不覆盖容器 DNS**：容器内显式 `--dns 1.1.1.1`。
7. **macOS 15 受限**：`container network` 命令、多网络等需 macOS 26+。
8. **网关 IP 稳定性**：Apple Container 固定使用 `192.168.64.0/24` 子网，网关恒为 `192.168.64.1`。

---


## 相关资源

- 跨平台总览与 qoderclicn 配套（AI 编码防封）见 `privacy-overview.md` 第七章。
- 一键脚本：`macos-privacy.sh`（`apply [区域]` / `verify` / `check` / `restore`）。

**文档结束**

_最后更新: 2026-07-22_
_架构实测（SakuraCat 代理 7897 + Cloudflare WARP DNS 模式） + 跨平台一致性修订_
