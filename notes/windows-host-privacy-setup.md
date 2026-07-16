# Windows 宿主机隐私保护设置清单

> **用途**: 在 Windows 10 宿主机层面配置隐私保护，与 WSL2 (Ubuntu-24.04) 隐私方案配套
> **时间**: 2026-07-16
> **VPN 客户端**: SakuraCat（TUN 模式，Meta Tunnel 虚拟网卡）
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

Windows 10 19045 支持 DoH，可防止 DNS 明文被中间人窥探：

```powershell
# 为 1.1.1.1 注册 DoH 模板（若系统支持）
netsh dns add encryption server=1.1.1.1 dohtemplate=https://cloudflare-dns.com/dns-query
netsh dns add encryption server=8.8.8.8 dohtemplate=https://dns.google/dns-query
```

> 之后在「设置 → 网络 → Wi-Fi → 硬件属性 → DNS 服务器分配 → 编辑」中，
> 将「DNS over HTTPS」设为「加密(仅限)」。

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

WebRTC 会绕过 VPN 暴露真实内网/公网 IP。**这不是系统设置，需在浏览器处理**：

- **Chrome/Edge**：安装扩展 "WebRTC Leak Prevent"，或在 `chrome://flags` 禁用相关项。
- **Firefox**：`about:config` → `media.peerconnection.enabled` 设为 `false`。
- 验证：访问 https://browserleaks.com/webrtc ，确认不泄露真实 IP。

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

**文档结束**

_最后更新: 2026-07-16_
_环境实测 + 方案定制: opencode_
