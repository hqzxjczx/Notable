# macOS 宿主机隐私保护设置清单

> **用途**: 在 macOS 上配置隐私保护，与 WSL2 (Ubuntu-24.04) / Windows 隐私方案配套
> **时间**: 2026-07-16
> **VPN 客户端**: SakuraCat（TUN 模式，虚拟隧道网卡）
> **配套文档**: `wsl2-ubuntu24-privacy-setup.md`, `windows-host-privacy-setup.md`
> **目标**: 时区隐私 + DNS 隐私 + 区域隐私（+ 可选进阶项）

---

## 前置说明（重要）

> ⚠️ **本文档为 macOS 通用最佳实践，非在本机实测**（当前操作机为 Windows）。
> 请在 macOS 上执行前，先用第五部分「验证」确认现状，再逐段应用。

- 需安装并运行 **SakuraCat macOS 客户端**，且处于 **TUN / 全局模式**（会创建 `utun` 虚拟网卡）。
- 多数命令需 `sudo`，会提示输入你的用户密码。
- 命令基于 macOS 12+（Monterey 及以上），旧版本个别命令可能略有差异。
- 沿用双端一致原则：**时区 `America/New_York` + DNS `1.1.1.1` / `8.8.8.8`**。

---

## 快速命令速查

| 用途 | 命令 |
|------|------|
| 查看时区 | `sudo systemsetup -gettimezone` |
| 设时区为美东 | `sudo systemsetup -settimezone America/New_York` |
| 列出可用时区 | `sudo systemsetup -listtimezones` |
| 查看 DNS | `networksetup -getdnsservers Wi-Fi` |
| 设 DNS | `networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8` |
| 刷新 DNS 缓存 | `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| 查看语言/区域 | `defaults read NSGlobalDomain AppleLocale` |
| 验证出口 IP | `curl -s https://1.1.1.1/cdn-cgi/trace \| grep -E 'ip=\|loc='` |

---

## 第一部分：时区隐私（最高优先级）

### 1.1 关闭自动时区，设为美东

```bash
# 关闭「根据当前位置自动设置时区」（先关自动，否则会被改回）
sudo systemsetup -setusingnetworktime off 2>/dev/null || true

# 设置时区为美东（与 WSL2 / Windows 一致）
sudo systemsetup -settimezone America/New_York

# 验证
sudo systemsetup -gettimezone
```

- ✅ 应显示 `Time Zone: America/New_York`

### 1.2 关闭「基于位置自动设置时区」（GUI）

> 命令行无法完全关闭定位驱动的自动时区，建议同时在 GUI 关闭：
> **系统设置 → 隐私与安全性 → 定位服务 → 系统服务 → 关闭「设置时区」**
> （旧版：系统偏好设置 → 日期与时间 → 时区 → 取消「根据当前位置自动设置时区」）

---

## 第二部分：DNS 隐私（高优先级）

### 2.1 将 Wi-Fi DNS 改为公网 DNS

```bash
# 查看当前网络服务名（确认联网接口，通常是 "Wi-Fi"）
networksetup -listallnetworkservices

# 设置 Wi-Fi DNS 为 Cloudflare + Google
networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8

# 刷新 DNS 缓存
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 验证
networksetup -getdnsservers Wi-Fi
```

> ⚠️ 若你用网线，接口名可能是 "Ethernet"，把命令里的 `Wi-Fi` 换掉。
> ⚠️ **不要修改 SakuraCat 创建的 `utun` 隧道相关配置**（那是 VPN 内部路由，正常）。

### 2.2 （可选）启用 DNS over HTTPS (DoH)

macOS 支持通过**配置描述文件 (.mobileconfig)** 启用系统级 DoH：

- 从可信来源（如 Cloudflare / dns.google 官方）下载 DoH 配置描述文件，
  双击安装后到 **系统设置 → 通用 → 设备管理** 中确认已启用。
- 或在浏览器内单独开启 DoH（见第四部分 WebRTC 同处）。

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

> ⚠️⚠️ **以下命令有副作用，默认注释，请逐条评估后再手动执行**。
> 关闭定位/诊断可能影响「查找」、地图、天气等功能。

### 4.1 WebRTC 本地 IP 泄露（浏览器层，推荐优先做）

WebRTC 会绕过 VPN 暴露真实 IP。需在浏览器处理。

> ⚠️ **macOS 平台特性**：浏览器走 SakuraCat 的 `utun` 隧道，但 **WebRTC 防护与 VPN 隧道是两个独立层**。
> 即使 VPN 已连接，WebRTC 仍可能直接探测真实网卡地址并暴露本地/公网 IP。两者必须分别配置：
> ① 全局 VPN（隧道，已在第二/三部分配置）；② 浏览器内 WebRTC 防护（本节）。

#### 4.1.1 Safari 配置（macOS 独有）

Safari 默认对 WebRTC 较严格（使用 mDNS `.local` 候选隐藏真实 IP），可进一步加固：

```text
1. 打开「Safari → 设置 → 高级」，勾选「在菜单栏中显示"开发"菜单」
2. 顶部菜单「开发」→「WebRTC」子菜单
3. 勾选：「Disable WebRTC mDNS ICE candidates」（禁用 mDNS 候选）
   - 或根据版本选择「Disable ICE Candidate Restrictions」以收紧候选范围
4. 重启 Safari 生效
```

> 若需彻底关闭 Safari 的 WebRTC：在「开发 → WebRTC」中关闭「Allow Media Peer Connection」类选项
> （不同 macOS 版本菜单名称略有差异，以实际为准）。

#### 4.1.2 Firefox 配置（详细步骤，与 Windows 同源）

**第一步：about:config 配置三项**（地址栏输入 `about:config`）：

| 配置项 | 现值 | 改为 | 作用 |
|-------|------|------|------|
| `media.peerconnection.ice.default_address_only` | false | **true** | 仅用默认网络地址，隐匿其他网卡 IP |
| `media.peerconnection.ice.no_host` | false | **true** | 禁用 host 候选（防暴露真实公网 IP） |
| `media.peerconnection.enabled` | true | **false** | 彻底禁用 WebRTC（最彻底，影响音视频通话）|

**第二步：扩展（推荐 uBlock Origin）**
- Firefox 附加组件搜索 **"uBlock Origin"** → 添加 → ⚙️ 设置 → 高级用户 → 勾选 **"Block WebRTC IP leak"**。

> 或安装 **"WebRTC Leak Prevent"** 轻量扩展，选项里勾选 Prevent WebRTC Leaks + Block all。

#### 4.1.3 Chrome / Edge 配置（macOS 上同 Windows 同源）

> macOS 上 Chrome/Edge 基于 Chromium，行为一致；`chrome://` 在 Edge 为 `edge://`。

- **扩展（推荐）**：Chrome 网上应用店搜 "WebRTC Leak Prevent" → Options → 勾选 Prevent WebRTC Leaks + Block all。
- **flags（高级）**：`chrome://flags` 搜索 WebRTC → 将 `WebRTC Peer Connection Event Logging`、
  `Restrict WebRTC IP Handling Policy` 改为 Disabled → 重启。

#### 4.1.4 验证

完成后访问：
- https://ipleak.net/ —— 检查 "WebRTC IP" 应为空或显示 VPN IP；"Your country" 应为美国。
- https://www.browserleaks.com/webrtc —— 显示 **"No public IP address leaked"** 即成功。

> 验证结果对比：
> - ❌ 泄露前：看到 `192.168.x.x` / `10.0.x.x`（内网）或真实公网 IP
> - ✅ 防护后：显示 VPN IP 或完全隐匿

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

---

## 第五部分：验证

在终端执行完整检测：

```bash
echo "===== macOS 宿主机隐私检测 ====="
echo "时区:"; sudo systemsetup -gettimezone
echo "DNS (Wi-Fi):"; networksetup -getdnsservers Wi-Fi
echo "语言/区域:"; defaults read NSGlobalDomain AppleLocale 2>/dev/null
echo "----- 出口 IP / 地理位置（不限流接口）-----"
curl -s https://1.1.1.1/cdn-cgi/trace | grep -E 'ip=|loc=|colo='
```

**判读标准**：
- ✅ 时区为 `America/New_York`
- ✅ Wi-Fi DNS 为 `1.1.1.1` / `8.8.8.8`
- ✅ 区域为 `en_US`
- ✅ `loc=US`，`ip=` 为节点 IP → VPN 生效且与时区一致

> ⚠️ 不要用 `ipinfo.io` 验证，其免费接口会返回 `429 Rate limit`，请统一用 `1.1.1.1/cdn-cgi/trace`。
> 综合自查可访问 https://browserleaks.com （IP / 时区 / WebRTC / DNS）。

---

## 第六部分：恢复步骤

```bash
# 恢复自动时区
sudo systemsetup -setusingnetworktime on
# 或手动改回中国时区
sudo systemsetup -settimezone Asia/Shanghai

# 恢复 DNS 为自动获取（清空手动 DNS）
networksetup -setdnsservers Wi-Fi "Empty"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 恢复语言/区域
defaults write NSGlobalDomain AppleLanguages -array "zh-Hans-CN" "en"
defaults write NSGlobalDomain AppleLocale -string "zh_CN"
```

> `networksetup -setdnsservers Wi-Fi "Empty"` 会清除手动 DNS，恢复 DHCP 自动获取。
> 语言/区域改回后需注销或重启生效。

---

## 注意事项与安全建议

### ⚠️ 必须遵守
1. **时区必须改**：出口 IP 与时区不一致（如 IP 美国、时区中国）会被指纹识别识破。
2. **改时区/DNS 需要 `sudo`**。
3. **不要动 SakuraCat 的 `utun` 隧道网卡**（VPN 内部路由，正常）。
4. **进阶项（第四部分）默认不执行**，逐条评估副作用后再手动启用。
5. **保持 SakuraCat 连接**：macOS 与其它端的网络隐私都依赖它。

### ✅ 推荐做法
1. 三端（macOS / Windows / WSL2）时区与 DNS 保持一致（美东 / 8.8.8.8·1.1.1.1）。
2. 每周运行第五部分验证脚本一次。
3. 优先处理 WebRTC 泄露（浏览器层，见 4.1）。
4. 用 https://browserleaks.com 综合自查。

---

## 第七部分：Apple Container 容器隐私

> **适用**: Apple `container` CLI（WWDC 2025 发布，在 macOS 26+ 完整支持，macOS 15 功能受限）
> 在 macOS 上用轻量级 VM 原生运行 Linux 容器。每个容器跑在独立微型 VM 中。
> **前置**: 宿主机 SakuraCat 需处于 **TUN / 全局模式**——容器流量经宿主机 vmnet 路由，
> 从而自动走 VPN 隧道（与 WSL2 TUN 逻辑一致）。本节为通用最佳实践，非本机实测。

### 7.1 核心机制速览

| 机制 | 说明 |
|------|------|
| 网络 | 容器接宿主机 vmnet 虚拟网络，默认从 vmnet 网关代理 DNS |
| DNS | `container run` 支持 `--dns` / `--dns-search` / `--dns-option` / `--no-dns` |
| 环境变量 | `-e KEY=value`、`--env-file <file>`（可注入 `TZ` / `LANG` / 代理）|
| 全局配置 | `~/.config/container/config.toml`（`[dns]` / `[network]` 段）|
| 属性设置 | `container system property set <id> <value>` |
| 时区 | 宿主机 macOS 时区**不会**自动传入容器，需 `-e TZ=...`（镜像需含 tzdata）|

### 7.2 DNS 隐私

**单容器（推荐，最直接）**：

```bash
container run --rm \
  --dns 1.1.1.1 --dns 8.8.8.8 \
  alpine/curl curl -s https://1.1.1.1/cdn-cgi/trace
```

**全局默认 DNS**（对所有新容器生效，编辑配置文件）：

```bash
# ~/.config/container/config.toml
[dns]
# 可选：本地 DNS 域（服务发现用），与公网 DNS 不冲突
# domain = "test"
```

> 若需完全禁用容器 DNS 配置（自行在容器内管理）：`container run --no-dns ...`

### 7.3 时区 + 语言隐私

容器基于 Linux 镜像，宿主机时区不自动继承，用环境变量注入：

```bash
container run --rm \
  -e TZ=America/New_York \
  -e LANG=en_US.UTF-8 \
  -e LC_ALL=en_US.UTF-8 \
  --dns 1.1.1.1 --dns 8.8.8.8 \
  ubuntu:latest date
```

> ⚠️ `TZ` 生效需镜像内含 **tzdata** 包。Debian/Ubuntu：`apt-get install -y tzdata`；
> Alpine：`apk add --no-cache tzdata`。轻量镜像可能无此包，`date` 会回落到 UTC。

### 7.4 代理配置（TUN 模式默认不需要）

- **TUN 模式（当前）**：容器流量经宿主机路由自动走 SakuraCat 隧道，**无需**代理变量。
- **仅端口代理模式才用**（默认注释）：

```bash
# 【默认不用】容器内 127.0.0.1 指向容器自身，不是 macOS 宿主机！
# 必须用 host.container.internal 指向宿主机上的代理端口：
# container run --rm \
#   -e http_proxy=http://host.container.internal:7890 \
#   -e https_proxy=http://host.container.internal:7890 \
#   alpine/curl curl -s https://1.1.1.1/cdn-cgi/trace
```

> ⚠️ **关键陷阱**：容器里的 `127.0.0.1` 是容器本身，不是 macOS。指向宿主机服务须用
> `host.container.internal`（可用 `sudo container system dns create host.container.internal --localhost <IP>` 配置）。

### 7.5 可复用的 privacy.env 模板 + 完整示例

创建 `~/.config/container/privacy.env`：

```bash
cat > ~/.config/container/privacy.env << 'EOF'
TZ=America/New_York
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
# 端口代理模式才取消注释（并确认端口）：
# http_proxy=http://host.container.internal:7890
# https_proxy=http://host.container.internal:7890
EOF
```

使用（一条命令同时套用时区/语言 + 公网 DNS）：

```bash
container run --rm \
  --env-file ~/.config/container/privacy.env \
  --dns 1.1.1.1 --dns 8.8.8.8 \
  ubuntu:latest bash -c 'apt-get update -qq && apt-get install -y -qq tzdata curl >/dev/null 2>&1; date; curl -s https://1.1.1.1/cdn-cgi/trace | grep -E "ip=|loc="'
```

### 7.6 验证

```bash
container run --rm \
  --env-file ~/.config/container/privacy.env \
  --dns 1.1.1.1 --dns 8.8.8.8 \
  alpine/curl sh -c 'apk add --no-cache tzdata >/dev/null 2>&1; echo "时区: $(TZ=America/New_York date)"; echo "LANG=$LANG"; echo "----- 出口 IP -----"; curl -s https://1.1.1.1/cdn-cgi/trace | grep -E "ip=|loc="'
```

**判读标准**：
- ✅ `date` 显示美东时间（EDT/EST）
- ✅ `LANG=en_US.UTF-8`
- ✅ `loc=US`，`ip=` 为节点 IP → 容器经宿主机 TUN 隧道走 VPN

### 7.7 清理 / 恢复

```bash
# 删除本地 DNS 域（若创建过）
sudo container system dns delete <domain>
container system dns list

# 移除全局配置：编辑 ~/.config/container/config.toml 删除 [dns] 段
# 删除 privacy.env
rm -f ~/.config/container/privacy.env

# 停止 container 服务
container system stop
```

### 7.8 故障排查

```bash
# 容器无法解析域名 (Could not resolve host)
container run -it --rm alpine/curl curl -v https://google.com   # 复现
scutil --dns                       # 查看宿主机 DNS 解析链
sudo lsof -i :53                   # 查看谁在监听 53 端口
# 显式指定公网 DNS 通常可绕过：--dns 1.1.1.1 --dns 8.8.8.8
```

### 7.9 注意事项

1. **127.0.0.1 陷阱**：容器内 `127.0.0.1` ≠ macOS 宿主机，指向宿主机须用 `host.container.internal`。
2. **时区需 tzdata**：轻量镜像无 tzdata 时 `TZ` 不生效，会回落 UTC。
3. **VPN 依赖宿主机**：容器走 VPN 完全依赖宿主机 SakuraCat TUN 模式在线。
4. **macOS 15 受限**：`container network` 命令、多网络等需 macOS 26+。
5. **DNS 一致性**：容器 DNS 与宿主机/WSL2 保持一致（1.1.1.1 / 8.8.8.8）。

---

**文档结束**

_最后更新: 2026-07-16_
_通用最佳实践（非本机实测）+ 结合 apple/container 官方文档: opencode_
