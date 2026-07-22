# WSL2 (Ubuntu-24.04) + SakuraCat 隐私保护设置清单

> **用途**: 在独立的 Ubuntu-24.04 隔离环境中配置隐私保护，不污染现有 Ubuntu-22.04
> **时间**: 2026-07-16
> **VPN 客户端**: SakuraCat (https://c1-sakuracat.com/dashboard)
> **VPN 运行模式**: **TUN 模式**（Meta Tunnel 虚拟网卡，无本地代理端口）
> **目标**: 时区隐私 + 语言隐私 + DNS 隐私

---

## 实测环境事实（执行前已确认）

| 项目 | 实测结果 |
|------|---------|
| 现有发行版 | `Ubuntu-22.04`（保持不动，本方案不修改它）|
| 隔离环境 | `Ubuntu-24.04 LTS`（新装，专用于隐私操作）|
| SakuraCat 进程 | 运行中（5 个进程）|
| SakuraCat 监听端口 | **无任何 TCP 监听端口** |
| 网络适配器 | 存在 `Meta` / `Meta Tunnel` 虚拟网卡 |
| 结论 | SakuraCat 使用 **TUN 模式**，流量经虚拟网卡全局路由，**不需要** `127.0.0.1:7897` 端口代理 |
| 时区 | America/New_York (UTC-5) |
| 语言 | en_US.UTF-8 |

> ⚠️ **重要**：因为是 TUN 模式，本清单中的代理环境变量（http_proxy 等）**默认注释掉**。
> 若强行启用指向 7897 的代理变量，WSL2 里所有 `curl`/`apt`/`git` 会因端口未监听而**连接失败**。
> TUN 模式下 WSL2 流量本身即经 Windows 主机路由走隧道，进入系统后用第 6 步的 `ipinfo.io` 验证即可。

---

## 快速命令速查

| 用途 | 命令 |
|------|------|
| 安装 Ubuntu-24.04 | `wsl --install -d Ubuntu-24.04` (PowerShell) |
| 进入 Ubuntu-24.04 | `wsl -d Ubuntu-24.04` (PowerShell) |
| 设为默认发行版 | `wsl --set-default Ubuntu-24.04` (PowerShell) |
| 查看所有实例 | `wsl -l -v` (PowerShell) |
| 关闭 WSL2 | `wsl --shutdown` (PowerShell) |
| 卸载隔离环境 | `wsl --unregister Ubuntu-24.04` (PowerShell) |
| 查看时区 | `timedatectl` |
| 查看语言 | `echo $LANG` |
| 查看 DNS | `cat /etc/resolv.conf` |
| DNS 锁定状态 | `lsattr /etc/resolv.conf` |
| 验证 IP 伪装 | `curl -s https://1.1.1.1/cdn-cgi/trace \| grep -E 'ip=\|loc='` |

---

## 第一步：安装隔离环境（Windows PowerShell）

```powershell
# 安装 Ubuntu 24.04 LTS（不影响现有 Ubuntu-22.04）
wsl --install -d Ubuntu-24.04
```

- 安装完成后会**自动进入**新系统，并要求你**创建用户名和密码**。
- ⚠️ 这个密码就是后续 `sudo` 使用的密码，请牢记，此步无法脚本代做。

之后如需再次进入：

```powershell
wsl -d Ubuntu-24.04
```

可选：设为默认（之后直接 `wsl` 即进入 24.04；若想保留 22.04 为默认则跳过）：

```powershell
wsl --set-default Ubuntu-24.04
```

确认版本与 WSL 版本号（应为 2）：

```powershell
wsl -l -v
```

---

## 第二步：备份当前配置（Ubuntu-24.04 内，无需 sudo）

```bash
mkdir -p ~/wsl2-backup
cp /etc/wsl.conf ~/wsl2-backup/wsl.conf.bak 2>/dev/null || true
cp /etc/resolv.conf ~/wsl2-backup/resolv.conf.bak 2>/dev/null || true
cp ~/.bashrc ~/wsl2-backup/bashrc.bak 2>/dev/null || true
echo "备份完成: ~/wsl2-backup/"
```

---

## 第三步：系统配置（Ubuntu-24.04 内，需 sudo）

一次性完成 时区 + DNS + 语言 配置：

```bash
# --- wsl.conf: 时区 + DNS 一次性写入 ---
sudo tee /etc/wsl.conf > /dev/null << 'EOF'
[time]
useWindowsTimezone = false

[network]
generateResolvConf = false
hostname = secure-sandbox
EOF

# --- 时区: America/New_York ---
sudo timedatectl set-timezone America/New_York

# --- 语言包: en_US.UTF-8 ---
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

# --- DNS: 解锁旧文件 -> 重写公网 DNS -> 锁定 ---
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2 attempts:3
EOF
sudo chattr +i /etc/resolv.conf

echo "系统配置完成"
```

---

## 第四步：追加 ~/.bashrc（Ubuntu-24.04 内，无需 sudo）

使用 `grep` 防止重复追加，可安全多次执行：

```bash
grep -q "WSL2 隐私保护配置" ~/.bashrc || cat >> ~/.bashrc << 'EOF'

# ===== WSL2 隐私保护配置 =====
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export TZ="America/New_York"

# ===== SakuraCat 代理配置（默认注释：当前为 TUN 模式，无需端口代理）=====
# 仅当你在 SakuraCat 中切换到"端口/系统代理模式"并确认真实端口后，
# 才取消下面注释，并把 7897 替换为实际端口。
# export http_proxy="http://127.0.0.1:7897"
# export https_proxy="http://127.0.0.1:7897"
# export all_proxy="socks5://127.0.0.1:7897"
# export HTTP_PROXY="http://127.0.0.1:7897"
# export HTTPS_PROXY="http://127.0.0.1:7897"
# export ALL_PROXY="socks5://127.0.0.1:7897"
EOF
echo "bashrc 配置完成"
```

---

## 第五步：重启 WSL 使配置生效（Windows PowerShell）

```powershell
wsl --shutdown
```

等待 3 秒后重新进入：

```powershell
wsl -d Ubuntu-24.04
```

---

## 第六步：验证（Ubuntu-24.04 内）

```bash
echo "===== WSL2 隐私保护检测 ====="
echo "时区: $(timedatectl | grep 'Time zone')"
echo "LANG=$LANG  LC_ALL=$LC_ALL  TZ=$TZ"
echo "DNS 配置:"; cat /etc/resolv.conf
echo "DNS 锁定标志:"; lsattr /etc/resolv.conf
echo "代理: ${http_proxy:-未设置(TUN模式正常)}"
echo "----- IP / 地理位置伪装验证 -----"
# 使用 Cloudflare 官方 trace 接口（不限流，稳定）
curl -s https://1.1.1.1/cdn-cgi/trace | grep -E 'ip=|loc='
```

> ⚠️ **不要用 `ipinfo.io` 验证**：其免费接口有速率限制，频繁调用会返回
> `429 Rate limit hit`（并非网络故障）。请统一使用上面的 `1.1.1.1/cdn-cgi/trace`。

**判读标准**：
- ✅ 时区显示 `America/New_York`
- ✅ LANG / TZ 为 `en_US.UTF-8` / `America/New_York`
- ✅ DNS 为 `8.8.8.8` / `1.1.1.1`，锁定标志含 `i`
- ✅ 代理显示"未设置(TUN模式正常)"
- ✅ `trace` 输出的 `loc=` 为**代理节点所在国家**（如 `US`），`ip=` 为节点 IP → TUN 隧道生效
- ❌ 若 `loc=CN` 或显示真实位置 → 检查 SakuraCat 是否处于全局/TUN 模式且已连接

> 💡 可选：安装 DNS 工具 `nslookup`/`dig`（Ubuntu-24.04 未预装）：
> ```bash
> sudo apt update && sudo apt install -y bind9-dnsutils
> ```

---

## 第七步：恢复步骤（应急）

### 卸载整个隔离环境（不影响 Ubuntu-22.04）

```powershell
wsl --unregister Ubuntu-24.04
```

> 这会删除 Ubuntu-24.04 的**全部数据**，但你的 Ubuntu-22.04 完全不受影响。
> 需要时重新 `wsl --install -d Ubuntu-24.04` 即可从头再来。

### 从备份局部恢复（Ubuntu-24.04 内）

```bash
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo cp ~/wsl2-backup/wsl.conf.bak /etc/wsl.conf
sudo cp ~/wsl2-backup/resolv.conf.bak /etc/resolv.conf
cp ~/wsl2-backup/bashrc.bak ~/.bashrc
source ~/.bashrc
echo "已从备份恢复，请在 PowerShell 执行 wsl --shutdown 后重进"
```

### 恢复 DNS 自动生成

```bash
sudo chattr -i /etc/resolv.conf   # 先解锁
# 编辑 /etc/wsl.conf，将 generateResolvConf 改为 true
sudo nano /etc/wsl.conf
# 然后 PowerShell: wsl --shutdown
```

---

## 第八步：故障排查

### T1: DNS 不生效
```bash
lsattr /etc/resolv.conf          # 应含 i 标志
cat /etc/resolv.conf             # 应为 8.8.8.8 / 1.1.1.1
grep -A2 "\[network\]" /etc/wsl.conf   # 应为 generateResolvConf = false
# 需要 nslookup/dig 排查时先安装（24.04 未预装）：
sudo apt update && sudo apt install -y bind9-dnsutils
# 之后 PowerShell: wsl --shutdown 再重进
```

### T2: WSL 里无法联网（curl 超时）
```bash
# 1. 确认 SakuraCat 在 Windows 侧已连接（Meta Tunnel 网卡存在）
# 2. 确认 .bashrc 里代理变量仍是【注释】状态（TUN 模式不该启用端口代理）
echo "${http_proxy:-未设置}"    # 应显示"未设置"
# 3. 若之前误开了代理，注释掉后 source ~/.bashrc
```

### T3: 时区不生效
```bash
grep -A2 "\[time\]" /etc/wsl.conf     # 应含 useWindowsTimezone = false
sudo timedatectl set-timezone America/New_York
# 之后 PowerShell: wsl --shutdown 再重进
```

### T4: WSL 无法启动（PowerShell）
```powershell
wsl --shutdown
wsl -l -v
wsl --update
```

---

## 注意事项与安全建议

### ⚠️ 必须遵守
1. **本方案针对 TUN 模式**：SakuraCat 当前无本地代理端口，代理变量默认注释，切勿盲目启用。
2. **不要在 `.wslconfig` 启用 `dnsTunneling=true`**：会绕过 Linux 内的 DNS 隐私配置。
3. **不要用路由器 IP（如 192.168.1.1）作 DNS**：会暴露内网信息，始终用公网 DNS。
4. **不要解除 DNS 锁定**：`chattr +i /etc/resolv.conf` 防止系统自动覆盖。
5. **保持 SakuraCat 运行并连接**：WSL2 隐私依赖 Windows 侧 VPN 隧道。

### ✅ 推荐做法
1. 所有隐私操作都在 Ubuntu-24.04 里进行，保持 22.04 干净。
2. 每周运行第六步验证脚本一次。
3. 定期 `curl https://1.1.1.1/cdn-cgi/trace` 确认伪装有效。
4. 保留 `~/wsl2-backup/` 备份。

---

## 第九步：浏览器 WebRTC 泄露提醒（重要，不在 WSL2 内）

> ⚠️ **平台特性**：WSL2 的隐私配置（时区/DNS/代理）**不涵盖浏览器 WebRTC 泄露**。
> 浏览器通常运行在 **Windows 宿主机**（或 macOS 宿主机），不在 WSL2 内；而 WebRTC 可在 VPN 已连接时
> 仍直接探测真实网卡并暴露本地/公网 IP。这是独立于 VPN 隧道的另一层泄露面。

**结论**：WebRTC 防护需在**宿主机浏览器**处理，而非 WSL2：

- **Windows 宿主机**：见 `windows-host-privacy-setup.md` 第四部分 4.1（Firefox/Chrome/Edge 详细步骤）。
- **macOS 宿主机**：见 `macos-host-privacy-setup.md` 第四部分 4.1（含 Safari 专属步骤）。
- **Apple Container**：纯 CLI/服务容器，无浏览器层，无需处理。

> 在 WSL2 里即使 `curl` 出口 IP 已是美国，也**不代表**你在宿主机浏览器里安全——
> 请用 https://browserleaks.com/webrtc 在宿主机浏览器实测确认无泄露。

---

**文档结束**

_最后更新: 2026-07-16_
_环境实测 + 方案定制: opencode_
