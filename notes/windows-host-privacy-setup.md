# Windows 宿主机隐私保护设置清单

> **用途**: 在 Windows 10 宿主机层面配置隐私保护，与 WSL2 (Ubuntu-24.04) 隐私方案配套
> **时间**: 2026-07-16
> **VPN 客户端**: SakuraCat（**TUN 模式**，Meta Tunnel 虚拟网卡；宿主机同时暴露**本地混合端口 7897** 供终端 / Docker 容器显式使用，与 macOS 端端口一致）
> **配套文档**: `wsl2-ubuntu24-privacy-setup.md`
> **目标**: 时区隐私 + DNS 隐私 + 区域隐私（+ 可选进阶项）

---

## 实测环境现状（执行前已确认）

| 项目 | 现状 | 隐患评估 |
|------|------|---------|
| 系统 | Windows 10 Pro 19045 | — |
| **时区** | `China Standard Time (UTC+8)` | ⚠️ **高危**：浏览器 JS 可读取，暴露真实地理位置 |
| 系统区域 | English (United States) | ✅ 已是英文，良好 |
| **DNS (Wi-Fi)** | `114.114.114.114` 等国内 DNS | ⚠️ **高危**：DNS 泄露，暴露中国 |
| DNS (Meta 隧道) | `198.18.0.2`（SakuraCat 内部）| ✅ 正常，**勿动** |
| 出口 IP | `38.45.155.82  loc=US  colo=LAX` | ✅ VPN 已生效（洛杉矶）|

> **核心结论**：出口 IP 已伪装为美国，但**时区仍是中国**、**Wi-Fi DNS 仍是国内 114** ——
> 这是宿主机层面最大的两个漏洞。时区与出口 IP 不一致，是浏览器指纹识别的典型破绽。

> ⚠️ **以下命令多数需要「以管理员身份运行 PowerShell」**。
> （开始菜单 → 搜索 PowerShell → 右键「以管理员身份运行」）

---

## 快速命令速查

| 用途 | 命令 |
|------|------|
| 查看时区 | `Get-TimeZone` |
| 设时区为美东 | `Set-TimeZone -Id "Eastern Standard Time"` |
| 查看 DNS | `Get-DnsClientServerAddress -AddressFamily IPv4` |
| 清 DNS 缓存 | `Clear-DnsClientCache` |
| 查看区域 | `Get-WinSystemLocale; Get-Culture` |
| 验证出口 IP | `(Invoke-RestMethod https://1.1.1.1/cdn-cgi/trace)` |
| 宿主代理端口 | `127.0.0.1:7897`（SakuraCat 混合端口，终端 / Docker 用） |

---

## 第一部分：时区隐私（最高优先级）

### 1.1 设置时区为美东（与 WSL2 一致）

以管理员 PowerShell 执行：

```powershell
Set-TimeZone -Id "Eastern Standard Time"
Get-TimeZone | Select-Object Id, DisplayName
```

- ✅ 应显示 `Eastern Standard Time (UTC-05:00) Eastern Time (US & Canada)`
- 该时区对应 IANA `America/New_York`，与你的 WSL2 配置统一。

### 1.2 关闭「自动设置时区」（防止被 Windows 改回）

```powershell
# 停用自动时区服务，防止系统根据位置/网络自动改回 UTC+8
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name Start -Value 4
```

> `Start = 4` 表示禁用。恢复见「恢复步骤」。
> 也可在「设置 → 时间和语言 → 日期和时间」里关闭「自动设置时区」开关。

---

## 第二部分：DNS 隐私（高优先级）

### 2.1 将 Wi-Fi DNS 从国内 114 改为公网 DNS

以管理员 PowerShell 执行：

```powershell
# 查看当前接口名（确认物理联网接口，通常是 "Wi-Fi" 或 "以太网"）
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses }

# 将 Wi-Fi 接口 DNS 改为 Cloudflare + Google
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses ("1.1.1.1","8.8.8.8")

# 清除 DNS 缓存使其立即生效
Clear-DnsClientCache
```

> ⚠️ **不要修改 `Meta` 接口的 DNS（198.18.0.2）** —— 那是 SakuraCat 隧道内部 DNS，属正常。
> 若你联网接口不是 "Wi-Fi"（如插网线为 "以太网"），把 `-InterfaceAlias` 换成对应名称。

### 2.2 （可选）启用 DNS over HTTPS (DoH)

> ⚠️ **版本限制**：系统级 DoH 的 `netsh dns add encryption` 命令**仅 Windows 11 及更新版本可用**。
> 本机为 **Windows 10 Pro 19045**，该命令会报"未找到命令/无效参数"，属正常，**直接跳过即可**。
> 确认方式：`netsh dns /?` 输出中若无 `add encryption` 即不支持。

**系统级 DoH（仅 Windows 11+，不可用则跳过）**：

```powershell
# 为 1.1.1.1 注册 DoH 模板（仅 Windows 11+）
netsh dns add encryption server=1.1.1.1 dohtemplate=https://cloudflare-dns.com/dns-query
netsh dns add encryption server=8.8.8.8 dohtemplate=https://dns.google/dns-query
# 之后在「设置 → 网络 → Wi-Fi → 硬件属性 → DNS 服务器分配 → 编辑」中将 DoH 设为「加密(仅限)」
```

**浏览器层 DoH（Windows 10 也可用的推荐替代）**：

- **Chrome / Edge**：`设置 → 隐私和安全 → 安全 → 使用安全 DNS`，选择 Cloudflare 或 Google。
- **Firefox**：`设置 → 常规 → 网络设置 → 启用基于 HTTPS 的 DNS`（选 Cloudflare/NextDNS）。
- 浏览器层 DoH 与系统版本无关，且能加密 DNS 查询防本地窥探，是 Win10 下的实用方案。

> 说明：即使无 DoH，DNS 设为 1.1.1.1 / 8.8.8.8 后关闭 VPN 仍能正常联网（仅 DNS 查询为明文 UDP 53）。
> 真正依赖 VPN 的是**出口 IP 伪装**（TUN 隧道），而非 DNS 配置。

---

## 第三部分：区域 / 语言隐私

系统区域已是 `English (United States)`，无需改动。若想彻底统一（可选）：

```powershell
# 统一 Culture / 系统区域 / 地理位置为美国
Set-Culture en-US
Set-WinSystemLocale en-US
Set-WinHomeLocation -GeoId 244   # 244 = United States
```

> 更改后需**注销或重启**才完全生效。仅为强化一致性，非必需。

---

## 第四部分：进阶隐私（可选，默认不执行）

> ⚠️⚠️ **以下命令有副作用，默认注释，请逐条评估后再手动执行**。
> 修改系统服务/遥测可能影响 Windows 更新、应用商店或部分功能。

### 4.1 WebRTC 本地 IP 泄露（浏览器层，推荐优先做）

WebRTC 会绕过 VPN 暴露真实内网/公网 IP。**这不是系统设置，需在浏览器处理**。

#### 浏览器对比

| 浏览器 | 方案 | 难度 | 隐私级别 |
|-------|------|------|---------|
| **Firefox** ⭐ 推荐 | `about:config` 配置 + uBlock Origin | 中 | 最强 |
| **Chrome/Edge** | `chrome://flags` + 扩展 | 易 | 强 |

#### 4.1.1 Firefox 隐私配置（详细步骤）

**第一步：about:config 配置三项**

在 Firefox 地址栏输入 `about:config`，逐项搜索并配置（双击切换布尔值）：

| 配置项 | 现值 | 改为 | 作用 |
|-------|------|------|------|
| `media.peerconnection.ice.default_address_only` | false | **true** | 仅使用默认网络地址，隐匿其他网卡 IP |
| `media.peerconnection.ice.no_host` | false | **true** | 禁用 host 候选地址（防暴露真实公网 IP） |
| `media.peerconnection.identity.enabled` | false | **true** | 启用身份验证与隐私保护 |

**第二步：选择扩展方案（两种可选）**

#### 方案 A：uBlock Origin（⭐ 推荐，功能全面）

1. Firefox 附加组件页面搜索 **"uBlock Origin"**
2. 点击 **"添加到 Firefox"** → 确认权限
3. 点击 uBlock 图标 → **⚙️ 设置** → **"高级用户"** 标签页
4. 勾选 **"Block WebRTC IP leak"** ✅
5. 刷新浏览器或重启 Firefox

**优势**：
- ✅ 功能最全（WebRTC 防护 + 广告拦截 + 追踪防护）
- ✅ 社区活跃，持续更新
- ✅ 性能优秀，占用资源少
- ✅ 同时保护其他隐私维度

---

#### 方案 B：WebRTC Leak Prevent（轻量级，专门防护）

1. Firefox 附加组件页面搜索 **"WebRTC Leak Prevent"** 或 **"WebRTC Leak Prevent ex"**
2. 点击 **"添加到 Firefox"** → 确认权限
3. 点击扩展图标 → **Options** 或 **选项**
4. 勾选以下设置：
   - ✅ **Prevent WebRTC Leaks** （启用防护）
   - ✅ **Block all** （阻止所有泄露）
   - ✅ **Hide non-proxied UDP traffic** （隐匿未代理的 UDP）

**优势**：
- ✅ 体积极小，资源占用低
- ✅ 功能单一，配置简单
- ✅ 专门针对 WebRTC，防护精准
- ✅ 无关功能干扰

---

#### 方案对比表

| 维度 | uBlock Origin | WebRTC Leak Prevent |
|------|--------------|-------------------|
| **WebRTC 防护** | ✅ 完整 | ✅ 专精 |
| **广告拦截** | ✅ 强大 | ❌ 无 |
| **追踪防护** | ✅ 完整 | ❌ 无 |
| **扩展大小** | 中等 | 极小 |
| **配置复杂度** | 中 | 低 |
| **资源占用** | 中等 | 极低 |
| **推荐场景** | 全方位隐私保护 | 纯 WebRTC 防护 |

**推荐选择**：
- 👍 **首选 uBlock Origin**：一个扩展解决多个隐私问题，综合价值高
- 🤏 **备选 WebRTC Leak Prevent**：如果设备配置低或想极简配置

**第三步：验证配置**

完成后访问这两个测试网站，确保不泄露本地 IP：

- https://ipleak.net/（综合隐私检测）
  - 检查 "WebRTC IP" 是否为空或显示 VPN IP
  - 检查 "Your country" 是否为 VPN 目标国家（美国）
  
- https://www.browserleaks.com/webrtc（WebRTC 专项测试）
  - 如果显示 **"No public IP address leaked"** → ✅ 防护成功
  - 如果显示你的真实 IP 或内网 IP → ❌ 需要重新配置

> **验证结果对比**：
> - ❌ 泄露前：可能看到 `192.168.x.x` 或 `10.0.x.x`（内网）或你真实的公网 IP
> - ✅ 防护后：显示 VPN IP 或完全隐匿

---

#### 4.1.2 Chrome / Edge 配置（可选）

> **Edge 与 Chrome 同源**：Microsoft Edge 基于 Chromium 内核，配置方式**完全一致**，
> 仅地址栏前缀不同——下文 `chrome://` 在 Edge 中替换为 `edge://` 即可（如 `edge://flags`、`edge://extensions`）。
> 两者都走 Chrome 网上应用店扩展生态，扩展通用。

**方案一：扩展（推荐）**
```
1. Chrome/Edge 应用商店搜索 "WebRTC Leak Prevent"
2. 添加扩展 → 点击图标 → Options
3. 勾选 "Prevent WebRTC Leaks" + "Block all"
4. 验证：访问 https://browserleaks.com/webrtc
```

**方案二：flags 配置（高级）**
```
1. 地址栏输入 chrome://flags（Edge 用 edge://flags）
2. 搜索 "WebRTC"
3. 找到以下项，改为 "Disabled"：
   - WebRTC Peer Connection Event Logging
   - Restrict WebRTC IP Handling Policy
4. 重启浏览器生效
```

**Edge 专属提示**：
- Edge 默认集成 **"增强型安全模式"** 与 **SmartScreen**，但与 WebRTC 防护无关，不影响上述配置。
- 若启用了 Edge 的 **"VPN 集成/安全网络"**（部分版本内置 Cloudflare 中转），会与 SakuraCat TUN 叠加，
  建议在 `edge://settings/privacy` 中确认未启用冲突的浏览器内代理，避免路由异常。
- Edge 企业策略可能锁定 flags，公司设备管理下部分项不可用，此时以方案一（扩展）为准。

---

#### 4.1.3 综合验证对比表

| 检测项 | 网站 | 检查内容 | 期望结果 |
|-------|------|--------|--------|
| **总体隐私** | ipleak.net | WebRTC IP / Country / ISP | VPN IP / 美国 / VPN ISP |
| **WebRTC 专项** | browserleaks.com/webrtc | 候选 IP 列表 | "No public IP" 或仅显示 VPN IP |
| **DNS 泄露** | ipleak.net | DNS 服务器 | 显示 1.1.1.1 / 8.8.8.8（非国内 DNS） |
| **时区检测** | ipleak.net | Timezone | America/New_York（与 Windows 时区一致） |

> 💡 **建议流程**：
> 1. 配置 Firefox about:config → 重启浏览器
> 2. 安装 uBlock Origin → 启用 WebRTC 防护
> 3. 访问 ipleak.net 检测是否泄露
> 4. 访问 browserleaks.com/webrtc 专项验证
> 5. 若有泄露，检查配置是否生效（可能需要清缓存 + 重启浏览器）

### 4.2 关闭部分 Windows 遥测（风险：影响诊断/反馈）

```powershell
# 【风险项，默认不执行】将遥测级别降到最低（企业版才支持 0，专业版最低为 1）
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -Value 1

# 【风险项】禁用「连接用户体验和遥测」服务 DiagTrack
# Stop-Service -Name DiagTrack -Force
# Set-Service -Name DiagTrack -StartupType Disabled
```

> 恢复：`Set-Service -Name DiagTrack -StartupType Automatic; Start-Service DiagTrack`

### 4.3 关闭广告 ID / 位置服务（风险：影响定位类应用）

```powershell
# 【风险项，默认不执行】禁用广告 ID
# Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name Enabled -Value 0

# 【风险项】通过 设置 → 隐私 → 位置，关闭「位置服务」总开关（GUI 操作更安全）
```

---

## 第五部分：验证

以管理员 PowerShell 执行完整检测：

```powershell
Write-Output "===== Windows 宿主机隐私检测 ====="
Write-Output "时区:"; Get-TimeZone | Select-Object Id, DisplayName
Write-Output "自动时区服务(Start=4为禁用):"
(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate").Start
Write-Output "DNS 配置:"
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias, ServerAddresses
Write-Output "----- 出口 IP / 地理位置（不限流接口）-----"
Invoke-RestMethod -Uri "https://1.1.1.1/cdn-cgi/trace" | Select-String -Pattern "ip=|loc=|colo="
```

**判读标准**：
- ✅ 时区为 `Eastern Standard Time`
- ✅ 自动时区服务 `Start = 4`（已禁用）
- ✅ Wi-Fi DNS 为 `1.1.1.1` / `8.8.8.8`（Meta 接口 198.18.0.2 属正常）
- ✅ `loc=US`，`ip=` 为节点 IP → VPN 生效且与时区一致

> ⚠️ 不要用 `ipinfo.io` 验证，其免费接口会返回 `429 Rate limit`，请统一用 `1.1.1.1/cdn-cgi/trace`。

---

## 第六部分：恢复步骤

```powershell
# 恢复时区为中国
Set-TimeZone -Id "China Standard Time"

# 恢复自动时区服务（默认 Start=3）
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name Start -Value 3

# 恢复 DNS 为自动获取（DHCP）
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses
Clear-DnsClientCache

# 移除 DoH 加密模板（若之前添加）
netsh dns delete encryption server=1.1.1.1
netsh dns delete encryption server=8.8.8.8

# 恢复遥测服务（若之前禁用）
# Set-Service -Name DiagTrack -StartupType Automatic; Start-Service DiagTrack
```

---

## 注意事项与安全建议

### ⚠️ 必须遵守
1. **时区必须改**：出口 IP 是美国而时区是中国，会被指纹识别技术直接识破。
2. **改 DNS/时区/服务需管理员 PowerShell**，否则报权限错误。
3. **不要动 `Meta` 隧道适配器**（DNS 198.18.0.2 是 SakuraCat 内部，正常）。
4. **进阶项（第四部分）默认注释**，逐条评估副作用后再手动启用。
5. **保持 SakuraCat 连接**：宿主机与 WSL2 的网络隐私都依赖它。

### ✅ 推荐做法
1. 宿主机与 WSL2 时区/DNS 保持一致（均为美东 / 8.8.8.8·1.1.1.1）。
2. 每周运行第五部分验证脚本一次。
3. 优先处理 WebRTC 泄露（浏览器层，见 4.1），这是常被忽略的破绽。
4. 用 https://browserleaks.com 综合自查（IP/时区/WebRTC/DNS）。

---

## 第七部分：Windows 宿主机 7897 代理端口用法（终端 / Docker 容器）

> **背景**：SakuraCat 在 Windows 上以 **TUN 模式**运行（Meta Tunnel 已抓全系统流量，含终端 / Git / 浏览器），
> 因此绝大多数程序**无需**手动设代理。但客户端**同时监听本地混合端口 7897**（HTTP + SOCKS5），
> 在以下场景需显式使用：① Docker 容器（独立网络命名空间，不继承 TUN）；② 个别绕过 TUN 的 App；③ 与 macOS 端保持端口一致（同为 7897）。

### 7.1 设置 Windows 系统代理（可选，与 macOS 对齐）

若希望宿主机某些 App 显式走 7897（而非 TUN），可在「设置 → 网络 → 代理」填入：
- 地址 `127.0.0.1`，端口 `7897`（HTTP / HTTPS）
- 或用 PowerShell：

```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "127.0.0.1:7897"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
```

> ⚠️ TUN 已在更底层抓包，设系统代理通常冗余但无害；**容器场景才真正需要**。

### 7.2 终端 / PowerShell 临时代理

```powershell
$env:http_proxy  = "http://127.0.0.1:7897"
$env:https_proxy = "http://127.0.0.1:7897"
$env:all_proxy   = "socks5://127.0.0.1:7897"
# 验证
(Invoke-RestMethod https://1.1.1.1/cdn-cgi/trace) | Select-String -Pattern "ip=|loc="
```

### 7.3 Docker 容器（Windows 宿主机）

Docker 容器在独立网络，**不继承 TUN**，必须显式指向宿主机 7897。Docker Desktop 用 `host.docker.internal` 解析到宿主机：

```powershell
docker run --rm `
  -e http_proxy=http://host.docker.internal:7897 `
  -e https_proxy=http://host.docker.internal:7897 `
  -e all_proxy=socks5://host.docker.internal:7897 `
  alpine/curl curl -s https://1.1.1.1/cdn-cgi/trace
```

> 若用 **WSL2 后端**的 Docker，容器实际跑在 WSL2 内、已继承 TUN，可能无需代理；但 Hyper-V 后端下显式设 `host.docker.internal:7897` 更稳妥。
> DNS 同 macOS 容器：显式 `--dns 1.1.1.1`。

### 7.4 一致性提示

- Windows 宿主机与 macOS 端 SakuraCat **端口统一为 7897**（跨平台一致）。
- 若关闭 TUN 只留代理模式，则宿主机所有流量都需依赖 7897（与 macOS 代理模式等价）。

---


## 相关资源

- 跨平台总览与 qoderclicn 配套（AI 编码防封）见 `privacy-overview.md` 第七章。
- 终端 / Docker 多区域切换可参考 `qoderclicn/switch-env-wsl2.sh`（端口需改 7897）。

**文档结束**

_最后更新: 2026-07-22（补充 Firefox WebRTC 详细配置 + 第七部分 7897 代理端口用法）_
_环境实测 + 方案定制: opencode_
