# WSL2 + SakuraCat VPN 隐私保护完整设置指南

> **用途**: 在 Windows WSL2 中集成 SakuraCat VPN 进行完整隐私保护
> **时间**: 2026-07-16
> **VPN 客户端**: SakuraCat (https://c1-sakuracat.com/dashboard)
> **VPN 监听端口**: 7897 (HTTP/SOCKS5)
> **目标**: 时区隐私 + 语言隐私 + DNS 隐私 + 完整网络隐私

---

## 快速查看表

| 项目 | 值 |
|------|-----|
| VPN 官方网站 | https://c1-sakuracat.com/dashboard |
| Windows 客户端 | SakuraCat |
| HTTP 代理端口 | 7897 |
| SOCKS5 代理端口 | 7897 |
| DNS 服务器 | 8.8.8.8, 1.1.1.1 |
| 推荐时区 | America/New_York (UTC-5) 或 UTC |
| 推荐语言 | en_US.UTF-8 |

---

## 第一部分：前置准备

### 准备步骤 1: 确认 SakuraCat 已正确安装和运行

**任务 P1.1: 启动 SakuraCat VPN 客户端**
- [ ] 在 Windows 开始菜单搜索 "SakuraCat"
- [ ] 打开 SakuraCat 应用
- [ ] 登录你的账号（使用 https://c1-sakuracat.com/dashboard 的凭证）
- [ ] 连接到任意节点
- [ ] 确认连接状态显示"已连接"或"Connected"

**任务 P1.2: 验证代理端口开放**
- [ ] 打开 PowerShell
- [ ] 执行测试命令:
  ```powershell
  Test-NetConnection -ComputerName 127.0.0.1 -Port 7897 -WarningAction SilentlyContinue
  ```
- [ ] 应显示 `TcpTestSucceeded: True`（表示 7897 端口可连接）

**任务 P1.3: 保持 SakuraCat 运行**
- [ ] 不要关闭 SakuraCat 应用
- [ ] 建议设置开机自启（SakuraCat 设置 → 自启）
- [ ] 配置最小化到托盘而非退出

### 准备步骤 2: 检查 WSL2 Ubuntu 环境

**任务 P2.1: 启动 WSL2**
- [ ] 打开 PowerShell
- [ ] 执行: `wsl`
- [ ] 确认进入 Ubuntu 终端

**任务 P2.2: 备份当前配置（预防恢复）**
- [ ] 执行以下备份命令:
  ```bash
  mkdir -p ~/wsl2-backup
  cp /etc/wsl.conf ~/wsl2-backup/wsl.conf.bak 2>/dev/null || true
  cp /etc/resolv.conf ~/wsl2-backup/resolv.conf.bak 2>/dev/null || true
  cp ~/.bashrc ~/wsl2-backup/bashrc.bak 2>/dev/null || true
  echo "备份完成，文件位置: ~/wsl2-backup/"
  ```

---

## 第二部分：WSL2 时区隐私配置

### Phase 1: 禁用 WSL2 自动时区同步

**任务 1.1: 编辑 WSL 配置文件**
- [ ] 进入 WSL2 Ubuntu
- [ ] 执行: `sudo nano /etc/wsl.conf`
- [ ] 添加或修改以下内容:
  ```ini
  [time]
  useWindowsTimezone = false
  ```
- [ ] 保存: `Ctrl + O` → `Enter`
- [ ] 退出: `Ctrl + X`

**任务 1.2: 重启 WSL 使配置生效**
- [ ] 打开 Windows PowerShell
- [ ] 执行: `wsl --shutdown`
- [ ] 等待 2-3 秒，WSL 完全关闭
- [ ] 重新打开 Ubuntu: `wsl`

**任务 1.3: 设置为海外时区**
- [ ] 执行: `sudo timedatectl set-timezone UTC`
  - 或改为美国东部: `sudo timedatectl set-timezone America/New_York`
- [ ] 验证: `timedatectl | grep "Time zone"`
- [ ] 应显示 `UTC` 或 `America/New_York`

**任务 1.4: 确保时区锁定**
- [ ] 检查时区是否已写入系统:
  ```bash
  cat /etc/timezone
  ```
- [ ] 应显示 `UTC` 或 `America/New_York`

---

## 第三部分：WSL2 语言环境隐私配置

### Phase 2: 隔离语言环境

**任务 2.1: 安装英文语言包**
- [ ] 执行:
  ```bash
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8
  ```

**任务 2.2: 编辑 ~/.bashrc 永久设置**
- [ ] 执行: `nano ~/.bashrc`
- [ ] 在文件末尾添加:
  ```bash
  # WSL2 隐私保护配置
  export LANG="en_US.UTF-8"
  export LC_ALL="en_US.UTF-8"
  export TZ="America/New_York"
  ```

**任务 2.3: 立即生效**
- [ ] 执行: `source ~/.bashrc`
- [ ] 验证: `echo $LANG` (应显示 `en_US.UTF-8`)
- [ ] 验证: `echo $TZ` (应显示 `America/New_York`)

**任务 2.4: 重启 WSL 验证持久化**
- [ ] 在 PowerShell 执行: `wsl --shutdown`
- [ ] 重新启动 Ubuntu
- [ ] 再次检查: `echo $LANG` 和 `echo $TZ`

---

## 第四部分：DNS 隐私配置

### Phase 3: 完全隔离 DNS 防止泄露

**任务 3.1: 禁用 WSL2 自动 DNS 生成**
- [ ] 编辑: `sudo nano /etc/wsl.conf`
- [ ] 添加或修改:
  ```ini
  [network]
  generateResolvConf = false
  hostname = secure-sandbox
  ```
- [ ] 保存并退出

**任务 3.2: 创建手动 DNS 配置**
- [ ] 删除旧的 DNS 文件:
  ```bash
  sudo rm -f /etc/resolv.conf
  ```
- [ ] 创建新的 DNS 配置:
  ```bash
  sudo nano /etc/resolv.conf
  ```
- [ ] 写入纯净的公网 DNS:
  ```
  nameserver 8.8.8.8
  nameserver 1.1.1.1
  options timeout:2 attempts:3
  ```
- [ ] 保存并退出

**任务 3.3: 锁定 DNS 文件防止被覆盖**
- [ ] 执行: `sudo chattr +i /etc/resolv.conf`
- [ ] 验证: `lsattr /etc/resolv.conf`
- [ ] 应显示 `i` 标志

**任务 3.4: 重启 WSL 应用所有配置**
- [ ] 在 PowerShell 执行: `wsl --shutdown`
- [ ] 重启 Ubuntu: `wsl`

---

## 第五部分：SakuraCat VPN 代理配置

### Phase 4: 在 WSL2 中配置 SakuraCat 代理

**任务 4.1: 配置 HTTP 和 SOCKS5 代理**
- [ ] 编辑: `nano ~/.bashrc`
- [ ] 在末尾添加以下代理配置:
  ```bash
  # SakuraCat VPN 代理配置（端口：7897）
  export http_proxy="http://127.0.0.1:7897"
  export https_proxy="http://127.0.0.1:7897"
  export all_proxy="socks5://127.0.0.1:7897"
  export HTTP_PROXY="http://127.0.0.1:7897"
  export HTTPS_PROXY="http://127.0.0.1:7897"
  export ALL_PROXY="socks5://127.0.0.1:7897"
  ```

**说明**:
- `127.0.0.1:7897` 是 SakuraCat 在 Windows 宿主机的代理地址
- HTTP/HTTPS 流量走 HTTP 代理
- 其他流量走 SOCKS5 代理

**任务 4.2: 立即生效**
- [ ] 执行: `source ~/.bashrc`

**任务 4.3: 测试代理连接**
- [ ] 确保 SakuraCat 仍然运行（Windows 侧）
- [ ] 在 WSL2 中测试:
  ```bash
  curl -v http://127.0.0.1:7897
  ```
- [ ] 应该有响应（不需要完全成功，有连接即可）

---

## 第六部分：隐私保护验证

### Phase 5: 完整验证隐私配置效果

**任务 5.1: 创建验证脚本**
- [ ] 创建脚本文件:
  ```bash
  cat > ~/check-privacy.sh << 'EOF'
  #!/bin/bash
  echo "========== WSL2 隐私保护检测 =========="
  echo ""
  echo "1️⃣ 时区检查:"
  echo "   当前时区: $(timedatectl | grep 'Time zone' | awk '{print $3, $4, $5}')"
  echo "   TZ 环境变量: $TZ"
  echo ""
  echo "2️⃣ 语言环境检查:"
  echo "   LANG: $LANG"
  echo "   LC_ALL: $LC_ALL"
  echo ""
  echo "3️⃣ DNS 隔离检查:"
  echo "   DNS 服务器:"
  grep nameserver /etc/resolv.conf | sed 's/^/   /'
  echo ""
  echo "4️⃣ DNS 解析测试:"
  echo "   DNS Server for github.com:"
  nslookup github.com 2>/dev/null | grep "Server:" | head -1 | sed 's/^/   /'
  echo ""
  echo "5️⃣ 代理环境变量:"
  echo "   http_proxy: ${http_proxy:-未设置}"
  echo "   https_proxy: ${https_proxy:-未设置}"
  echo "   all_proxy: ${all_proxy:-未设置}"
  echo ""
  echo "========== 检测完毕 =========="
  EOF
  chmod +x ~/check-privacy.sh
  ```

**任务 5.2: 运行验证脚本**
- [ ] 执行: `~/check-privacy.sh`
- [ ] 检查输出:
  - ✅ 时区应为 UTC 或 America/New_York
  - ✅ 语言应为 en_US.UTF-8
  - ✅ DNS 应为 8.8.8.8 或 1.1.1.1
  - ✅ DNS 解析应返回 8.8.8.8
  - ✅ 代理应为 127.0.0.1:7897

**任务 5.3: 验证 IP 和地理位置伪装（需要网络）**
- [ ] 安装 curl（通常已预装）
- [ ] 执行:
  ```bash
  curl -s https://ipinfo.io | grep -E '"country"|"timezone"|"city"|"ip"'
  ```
- [ ] ✅ 正确: 显示的国家/时区应为代理节点所在位置，而非中国
- [ ] ❌ 错误: 显示中国或你的真实物理位置

**任务 5.4: 完整网络隐私测试**
- [ ] 测试 DNS 是否真的走了代理:
  ```bash
  # 这会显示 DNS 查询通过的路径
  dig @8.8.8.8 google.com +short
  ```

---

## 第七部分：恢复步骤（应急）

### Recovery 1: 快速恢复到默认配置

**恢复 R1.1: 恢复时区同步**
```bash
# 重新启用 Windows 时区同步
sudo nano /etc/wsl.conf
# 修改或删除 [time] 部分，或改为：
# [time]
# useWindowsTimezone = true
```
然后在 PowerShell 执行:
```powershell
wsl --shutdown
```

**恢复 R1.2: 恢复 DNS 自动生成**
```bash
# 重新启用 DNS 自动生成
sudo chattr -i /etc/resolv.conf  # 先解锁
sudo nano /etc/wsl.conf
# 改为：
# [network]
# generateResolvConf = true
```

**恢复 R1.3: 移除代理配置**
```bash
# 编辑 ~/.bashrc，注释掉或删除代理相关行：
nano ~/.bashrc
# 删除或注释：
# export http_proxy="..."
# export https_proxy="..."
# export all_proxy="..."
source ~/.bashrc
```

**恢复 R1.4: 从备份恢复**
```bash
# 如果之前做过备份：
sudo cp ~/wsl2-backup/wsl.conf.bak /etc/wsl.conf
sudo cp ~/wsl2-backup/resolv.conf.bak /etc/resolv.conf
cp ~/wsl2-backup/bashrc.bak ~/.bashrc
source ~/.bashrc
```

---

### Recovery 2: 彻底重置 WSL2（终极恢复）

**恢复 R2.1: 完全重置 Ubuntu（删除所有配置）**
```powershell
# 在 Windows PowerShell 中执行
wsl --unregister Ubuntu
# 这会删除整个 Ubuntu 实例（包括所有文件！）
```

**恢复 R2.2: 重新安装 Ubuntu**
```powershell
# 从 Microsoft Store 重新安装 Ubuntu
# 或使用 WSL 官方安装
wsl --install -d Ubuntu
```

---

### Recovery 3: 部分恢复（保留用户数据）

**恢复 R3.1: 只恢复网络配置**
```bash
# 不重置整个系统，只恢复网络配置
sudo nano /etc/wsl.conf
# 删除 [network] 部分或改回默认
# 然后：
sudo nano /etc/resolv.conf
# 删除手动配置，让 WSL 自动生成
```

**恢复 R3.2: 只恢复语言和时区**
```bash
# 保留代理，只恢复其他配置
nano ~/.bashrc
# 删除以下行：
# export LANG="..."
# export LC_ALL="..."
# export TZ="..."
# 保留代理配置
source ~/.bashrc
```

---

## 第八部分：故障排查

### 问题 T1: DNS 不生效

**症状**: `nslookup` 仍然返回本地 IP
**解决**:
```bash
# 1. 检查 DNS 文件是否锁定
lsattr /etc/resolv.conf
# 应显示 i 标志

# 2. 检查是否真的改成了公网 DNS
cat /etc/resolv.conf
# 应显示 8.8.8.8 或 1.1.1.1

# 3. 重启 WSL
# 在 PowerShell: wsl --shutdown
# 然后重新启动

# 4. 检查 wsl.conf 配置
cat /etc/wsl.conf | grep -A 2 "\[network\]"
# 应显示 generateResolvConf = false
```

### 问题 T2: 代理不工作

**症状**: `curl` 无法连接，或超时
**解决**:
```bash
# 1. 检查 SakuraCat 是否运行（Windows 侧）
# 在 PowerShell: Get-Process SakuraCat
# 应显示多个 SakuraCat 进程

# 2. 验证代理端口开放
Test-NetConnection -ComputerName 127.0.0.1 -Port 7897

# 3. 检查代理环境变量
echo $http_proxy
# 应显示 http://127.0.0.1:7897

# 4. 如果仍不工作，检查 SakuraCat 设置
# 打开 SakuraCat GUI，确认代理已启用且端口是 7897
```

### 问题 T3: WSL 无法启动

**症状**: `wsl` 命令失败
**解决**:
```powershell
# 在 PowerShell 中：
# 1. 完全关闭 WSL
wsl --shutdown

# 2. 列出所有实例
wsl -l -v

# 3. 如果仍有问题，重启 Windows
# 或重新安装 WSL
wsl --install
```

### 问题 T4: 时区不生效

**症状**: `timedatectl` 仍然显示本地时区
**解决**:
```bash
# 1. 检查 wsl.conf 是否正确配置
sudo cat /etc/wsl.conf | grep -A 2 "\[time\]"

# 2. 检查时区文件
cat /etc/timezone

# 3. 重新设置时区
sudo timedatectl set-timezone UTC
# 等待几秒

# 4. 重启 WSL（PowerShell）
wsl --shutdown
wsl
```

---

## 第九部分：日常维护

### 定期检查清单

**周检查**:
- [ ] SakuraCat 是否仍在运行（检查 Windows 任务栏）
- [ ] 运行 `~/check-privacy.sh` 验证配置
- [ ] 测试 `curl https://ipinfo.io` 确认隐私配置有效

**月检查**:
- [ ] 检查 SakuraCat 是否有新版本
- [ ] 检查 DNS 文件锁定状态: `lsattr /etc/resolv.conf`
- [ ] 验证备份文件仍在: `ls -la ~/wsl2-backup/`

**季度检查**:
- [ ] 更新 WSL2: `wsl --update`
- [ ] 更新 Ubuntu 系统: `sudo apt update && sudo apt upgrade -y`
- [ ] 重新创建完整备份

---

## 附录 A: 快速命令速查

| 用途 | 命令 |
|------|------|
| 启动 WSL2 | `wsl` |
| 关闭 WSL2 | `wsl --shutdown` (PowerShell) |
| 设置时区为 UTC | `sudo timedatectl set-timezone UTC` |
| 设置时区为纽约 | `sudo timedatectl set-timezone America/New_York` |
| 查看当前时区 | `timedatectl` 或 `cat /etc/timezone` |
| 查看语言环境 | `echo $LANG` |
| 查看代理配置 | `echo $http_proxy` |
| 验证 DNS | `cat /etc/resolv.conf` |
| 测试 DNS 解析 | `nslookup github.com` |
| 测试 IP 伪装 | `curl https://ipinfo.io` |
| 运行完整检测 | `~/check-privacy.sh` |
| 生效 bashrc 改动 | `source ~/.bashrc` |
| 查看备份 | `ls ~/wsl2-backup/` |

---

## 附录 B: SakuraCat 端口参考

| 协议 | 端口 | 说明 |
|------|------|------|
| HTTP | 7897 | Web 代理，用于 HTTP/HTTPS 流量 |
| SOCKS5 | 7897 | 全协议代理，用于 UDP/TCP 流量 |
| 管理界面 | 可能为 6001 或其他 | SakuraCat 控制面板（仅 Windows 侧） |

---

## 附录 C: 故障排查树状图

```
WSL2 隐私配置问题
├─ 时区问题
│  ├─ wsl.conf 配置正确？
│  │  └─ 否 → 编辑 [time] 部分
│  ├─ timedatectl 命令执行？
│  │  └─ 否 → sudo timedatectl set-timezone ...
│  └─ WSL 重启了吗？
│     └─ 否 → wsl --shutdown + wsl
│
├─ DNS 问题
│  ├─ /etc/resolv.conf 内容正确？
│  │  └─ 否 → 重新编写 DNS 服务器
│  ├─ 文件被锁定了吗？
│  │  └─ 否 → sudo chattr +i /etc/resolv.conf
│  └─ WSL 重启了吗？
│     └─ 否 → wsl --shutdown + wsl
│
├─ 代理问题
│  ├─ SakuraCat 在 Windows 运行吗？
│  │  └─ 否 → 启动 SakuraCat
│  ├─ 端口 7897 开放吗？
│  │  └─ 否 → 检查 SakuraCat 设置，确认监听 7897
│  ├─ 环境变量设置正确？
│  │  └─ 否 → 编辑 ~/.bashrc，重新配置
│  └─ source ~/.bashrc 了吗？
│     └─ 否 → source ~/.bashrc
│
└─ WSL 无法启动
   ├─ wsl --shutdown 了吗？
   │  └─ 否 → 尝试 wsl --shutdown
   ├─ WSL 需要更新？
   │  └─ 否 → wsl --update
   └─ 需要重新安装？
      └─ 是 → wsl --unregister Ubuntu + wsl --install -d Ubuntu
```

---

## 注意事项与安全建议

### ⚠️ 必须遵守

1. **不要在 Windows `.wslconfig` 中启用 `dnsTunneling=true`**
   - 这会绕过你在 Linux 中的所有 DNS 隐私配置
   - 使用 SakuraCat 的 TUN 模式反而更安全

2. **不要使用本地路由器 IP 作为 DNS**
   - 例如 `192.168.1.1` 会暴露内网信息
   - 始终使用公网 DNS（8.8.8.8、1.1.1.1 等）

3. **不要删除 DNS 锁定**
   - `sudo chattr +i /etc/resolv.conf` 不是可选的
   - 这防止系统自动覆盖配置

4. **不要忘记启动 SakuraCat**
   - WSL2 代理依赖 Windows 侧的 VPN 运行
   - 建议设置 SakuraCat 开机自启

### ✅ 推荐做法

1. 定期验证隐私配置（每周一次）
2. 保持 SakuraCat 和 WSL2 更新
3. 定期备份配置文件
4. 使用脚本 `~/check-privacy.sh` 自动检测
5. 在进行重要操作前备份关键数据

---

**文档结束**

_最后更新: 2026-07-16_
_主要贡献者: Copilot CLI_
