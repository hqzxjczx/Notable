# WSL2 (Ubuntu-22.04) 隐私保护设置清单

> **用途**: 在默认实例 Ubuntu-22.04 中配置与 Ubuntu-24.04 一致的隐私保护
> **时间**: 2026-07-26
> **VPN 客户端**: SakuraCat（**TUN 模式**，Meta Tunnel 虚拟网卡；宿主机同时暴露本地混合端口 7897）
> **配套文档**: `wsl2-ubuntu24-privacy-setup.md`、`wsl2-privacy.sh`、`windows-host-privacy-setup.md`
> **目标**: 时区隐私 + 语言隐私 + DNS 隐私（与 24.04 / Windows / macOS 四端一致）

---

## 背景：为什么 22.04 也要做

历史上本方案的政策是「保持 22.04 干净」，只在隔离的 24.04 里做隐私配置。但实测发现：

- **22.04 是 `wsl --set-default` 的默认实例**（`wsl` 直接进的是 22.04），日常使用频率最高
- 22.04 的 `/etc/resolv.conf` 自动指向 Windows 网关（`192.168.144.1`），**DNS 查询走 Windows 宿主机 DNS**，绕过了 24.04 里精心锁定的 8.8.8.8/1.1.1.1
- 22.04 时区 `Asia/Shanghai`、`LANG=C.UTF-8`，与 24.04 不一致

结论：**22.04 也必须做完整加固**，与 24.04 配置一致。原「保持干净」政策废止。

---

## 与 Ubuntu-24.04 的差异（关键）

| 项 | Ubuntu-22.04 | Ubuntu-24.04 |
|---|---|---|
| systemd | **已启用**（wsl.conf `[boot] systemd=true`，PID 1 = systemd）| 未启用（PID 1 = init）|
| 设置时区命令 | `sudo timedatectl set-timezone America/New_York` ✅ 可用 | timedatectl 不可用，用 `sudo ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime` |
| 现有 wsl.conf | 已有 `[boot] systemd=true` + `[user] default=...`，**必须保留** | 仅有 `[time]` + `[network]` |
| 其他 | 完全一致 | 完全一致 |

> **关键**：22.04 的 wsl.conf 已有 `[boot] systemd=true`，加固时**不能覆盖整个文件**，必须合并写入（只改 `[time]` 和 `[network]` 段，保留 `[boot]` 和 `[user]`）。`wsl2-privacy.sh` 脚本已用 awk 处理这个合并逻辑。

---

## 一键脚本（推荐）

与 `macos-privacy.sh` 对应的 WSL2 版一键脚本：`wsl2-privacy.sh`。

**在 Ubuntu-22.04 里执行**：

```bash
# 脚本位于 Windows 侧的 Notable 项目目录，WSL 里通过 /mnt/c/ 访问
cd /mnt/c/Users/hqzxj/Documents/Notable/notes
chmod +x wsl2-privacy.sh

# 应用（需 sudo，会提示密码）
sudo ./wsl2-privacy.sh apply

# 验证（无需 sudo）
./wsl2-privacy.sh verify

# 查看当前状态
./wsl2-privacy.sh check
```

脚本会自动：
1. 检测 systemd 与否，选择正确的时区设置方式（22.04 走 timedatectl）
2. **合并写入 /etc/wsl.conf**（保留现有 `[boot] systemd=true` 和 `[user]` 段，只追加/替换 `[time]` 和 `[network]` 段）
3. `locale-gen en_US.UTF-8` + `update-locale`
4. 锁定 `/etc/resolv.conf` 为 `8.8.8.8` / `1.1.1.1` + `chattr +i`
5. 幂等追加 `~/.bashrc` 的 `LANG/LC_ALL/TZ` export 块

**执行后在 Windows PowerShell 里**：

```powershell
wsl --shutdown   # 使 wsl.conf 生效
wsl -d Ubuntu-22.04   # 重新进入
```

---

## 手动步骤（如需逐步核对）

### 第一步：备份

```bash
mkdir -p ~/wsl2-backup
cp /etc/wsl.conf ~/wsl2-backup/wsl.conf.bak 2>/dev/null || true
cp /etc/resolv.conf ~/wsl2-backup/resolv.conf.bak 2>/dev/null || true
cp ~/.bashrc ~/wsl2-backup/bashrc.bak 2>/dev/null || true
```

### 第二步：合并写入 /etc/wsl.conf（保留 systemd）

```bash
# 移除旧的 [time] 和 [network] 段（如果有），保留 [boot] 和 [user]
sudo awk '/^\[time\]/{skip=1;next} /^\[network\]/{skip=1;next} /^\[/{skip=0} !skip{print}' /etc/wsl.conf > /tmp/wsl.conf.tmp
sudo tee -a /tmp/wsl.conf.tmp > /dev/null << 'EOF'

[time]
useWindowsTimezone = false

[network]
generateResolvConf = false
hostname = secure-sandbox
EOF
sudo mv /tmp/wsl.conf.tmp /etc/wsl.conf
cat /etc/wsl.conf   # 确认 [boot] systemd=true 仍在
```

### 第三步：时区（22.04 有 systemd，timedatectl 可用）

```bash
sudo timedatectl set-timezone America/New_York
timedatectl | grep "Time zone"   # 应显示 America/New_York (EST, -0500)
```

### 第四步：语言环境

```bash
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8
```

### 第五步：DNS 锁定

```bash
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2 attempts:3
EOF
sudo chattr +i /etc/resolv.conf
lsattr /etc/resolv.conf   # 应含 i 标志
```

### 第六步：~/.bashrc export 块（幂等）

```bash
MARK="# ===== WSL2 PRIVACY HARDENING ====="
END="# ===== END WSL2 PRIVACY HARDENING ====="
grep -q "$MARK" ~/.bashrc && sed -i "/$MARK/,/$END/d" ~/.bashrc
cat >> ~/.bashrc << EOF

$MARK
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export TZ="America/New_York"
$END
EOF
source ~/.bashrc
```

### 第七步：重启 WSL 使 wsl.conf 生效

```powershell
# Windows PowerShell
wsl --shutdown
wsl -d Ubuntu-22.04
```

### 第八步：验证

```bash
./wsl2-privacy.sh verify
# 或手动：
echo "时区: $(timedatectl | grep 'Time zone')"
echo "LANG=$LANG  LC_ALL=$LC_ALL  TZ=$TZ"
cat /etc/resolv.conf
lsattr /etc/resolv.conf
curl -s https://1.1.1.1/cdn-cgi/trace | grep -E '^ip=|^loc=|^colo='
```

**判读标准**：
- ✅ 时区 = `America/New_York`
- ✅ LANG / LC_ALL / TZ = `en_US.UTF-8` / `America/New_York`
- ✅ DNS = `8.8.8.8` / `1.1.1.1`，`lsattr` 含 `i`
- ✅ `loc=US`，`ip=` 为节点 IP（依赖 Windows 侧 SakuraCat TUN 已连接）
- ✅ http_proxy 未设置（TUN 模式正常）

---

## 恢复

```bash
# 一键恢复
sudo ./wsl2-privacy.sh restore

# 或手动从备份
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo cp ~/wsl2-backup/wsl.conf.bak /etc/wsl.conf
sudo cp ~/wsl2-backup/resolv.conf.bak /etc/resolv.conf
cp ~/wsl2-backup/bashrc.bak ~/.bashrc
# PowerShell: wsl --shutdown 后重进
```

---

## 注意事项

1. **systemd 必须保留**：22.04 的 `[boot] systemd=true` 是其他服务（snapd、cron 等）正常工作的前提。`wsl2-privacy.sh` 用 awk 合并写入，不会破坏它。
2. **不要在 .wslconfig 启用 dnsTunneling=true**：会绕过 Linux 内的 DNS 锁定。
3. **不要用本地路由器 IP 作 DNS**：会暴露内网信息。
4. **不要解除 DNS 锁定**：`chattr +i` 防止 WSL 自动覆盖。
5. **保持 SakuraCat TUN 连接**：WSL2 隐私依赖 Windows 侧 TUN 隧道。
6. **22.04 的 systemd user session 警告**：若 `wsl` 启动时报 `Failed to start the systemd user session`，通常是 PAM / logind 状态问题，`wsl --shutdown` 后重进即可，不影响隐私配置。

---

## 相关文档

- 跨平台总览：`privacy-overview.md`
- Windows 宿主机：`windows-host-privacy-setup.md`
- Ubuntu-24.04 隔离环境：`wsl2-ubuntu24-privacy-setup.md`
- 一键脚本：`wsl2-privacy.sh`（apply / verify / check / restore）
- macOS 端对照：`macos-host-privacy-setup.md` + `macos-privacy.sh`

**文档结束**

_最后更新: 2026-07-26_
