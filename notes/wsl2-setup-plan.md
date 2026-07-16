# Windows WSL2 进入方法 - Agent 执行计划

> 基于 PDF 文档: `Windows WSL2 进入⼊方法`  
> 生成时间: 2026-07-16  
> 用途: 为 Agent 提供可直接执行的任务清单

---

## 第一部分：WSL2 基础进入方法

### Phase 1: 快速进入 WSL2（命令行方式）

**任务 1.1: 使用命令行进入默认 Linux 系统**
- [ ] 打开 PowerShell 或 CMD（Win + R → 输入 `cmd` 或 `powershell`）
- [ ] 执行命令: `wsl`
- [ ] 验证进入成功（出现 Linux 终端提示符）

**任务 1.2: 进阶命令 - 进入指定的 Linux 分发版**
- [ ] 如需进入特定分发版（例如 Ubuntu），执行: `wsl -d Ubuntu`
- [ ] 以 root 身份进入，执行: `wsl -u root`
- [ ] 查看已安装系统和版本，执行: `wsl -l -v`

**任务 1.3: 配置默认 Linux 系统（可选）**
- [ ] 列出所有已安装的分发版: `wsl -l -v`
- [ ] 选择一个作为默认，执行: `wsl -s <DistroName>`

---

### Phase 2: 使用 Windows Terminal（推荐方式）

**任务 2.1: 检查 Windows Terminal 是否安装**
- [ ] 如使用 Windows 11，按 Win → 搜索 "Terminal" 或 "终端"
- [ ] 确认是否已经预装（Windows 11 通常内置）

**任务 2.2: 如果未安装 Windows Terminal（Windows 10）**

**选项 A: 通过 Microsoft Store 安装**
- [ ] 打开 Microsoft Store
- [ ] 搜索 "Windows Terminal"
- [ ] 确认发布者为 "Microsoft Corporation"
- [ ] 点击"获取"或"安装"按钮
- [ ] 等待安装完成

**选项 B: 使用 PowerShell 命令一键安装**
- [ ] 打开 PowerShell（无需管理员）
- [ ] 执行命令: `winget install Microsoft.WindowsTerminal`
- [ ] 等待系统后台自动下载并安装

**选项 C: 从 GitHub 下载安装包（离线环境）**
- [ ] 访问 Windows Terminal GitHub Releases: https://github.com/microsoft/terminal/releases
- [ ] 下载最新版本的 `.msixbundle` 文件
- [ ] 双击该文件
- [ ] 点击"安装"或"更新"

**任务 2.3: 启动 Windows Terminal**
- [ ] 打开 Windows Terminal
- [ ] 点击顶部标签栏旁的下拉箭头 ▼
- [ ] 在菜单中选择你的 Linux 分发版（如 Ubuntu）
- [ ] 确认在新标签页中打开 Linux 环境

**任务 2.4: 将 Windows Terminal 设为默认终端**
- [ ] 打开 Windows Terminal
- [ ] 按快捷键 `Ctrl + ,`（或点击下拉菜单 → 设置）
- [ ] 在左侧导航栏选择"启动"（Startup）
- [ ] 找到"默认终端应用程序"
- [ ] 改为"Windows Terminal"
- [ ] 点击右下角"保存"

---

### Phase 3: 从开始菜单直接打开 Linux

**任务 3.1: 从开始菜单启动 Linux**
- [ ] 按 Win 键打开开始菜单（或点击左下角开始图标）
- [ ] 在搜索框输入你的 Linux 系统名称（如 "Ubuntu"）
- [ ] 看到对应应用图标后双击打开
- [ ] 确认弹出专属的 Linux 终端窗口

---

## 第二部分：WSL2 与 Windows 文件系统交互

### Phase 4: 文件系统访问配置

**任务 4.1: 在 Linux 中访问 Windows 文件**
- [ ] 进入 WSL2 Ubuntu 终端
- [ ] Windows 盘符被挂载在 `/mnt/` 目录下
- [ ] 访问 C 盘示例: `cd /mnt/c`
- [ ] 列出 C 盘文件: `ls /mnt/c`
- [ ] 导航到特定文件夹，如用户目录: `cd /mnt/c/Users/你的用户名`

**任务 4.2: 在 Windows 文件管理器中访问 Linux 文件**
- [ ] 打开 Windows 文件管理器
- [ ] 在地址栏输入: `\\wsl$`
- [ ] 确认可以看到 Linux 发行版文件夹
- [ ] 像管理普通文件夹一样浏览 WSL 内部文件

---

## 第三部分：WSL2 Ubuntu 用户初始化

### Phase 5: 首次启动 Ubuntu 并创建用户

**任务 5.1: 首次启动 Ubuntu**
- [ ] 使用 `wsl` 或 Windows Terminal 打开 Ubuntu
- [ ] Ubuntu 首次启动时会自动初始化（可能需要几分钟）
- [ ] 系统会提示创建新用户

**任务 5.2: 设置 Linux 用户名**
- [ ] 出现提示后，输入用户名
- [ ] 用户名要求:
  - 全小写字母、数字或下划线组合（如 `alex`, `ubuntu`, `john_doe`）
  - 不能包含空格或特殊字符
  - 不需要与 Windows 用户名一致（但保持一致会更方便）
- [ ] 按 Enter 确认

**任务 5.3: 设置 Linux 用户密码**
- [ ] 系统提示输入密码: "New password"
- [ ] 输入密码（屏幕不会显示任何字符，这是正常的安全保护）
- [ ] 按 Enter
- [ ] 系统提示重新输入密码确认: "Retype new password"
- [ ] 再次输入相同密码
- [ ] 按 Enter 完成
- [ ] 验证进入 Linux 终端提示符

**任务 5.4: 密码管理提示**
- [ ] 记住你的密码（后续使用 `sudo` 命令时需要）
- [ ] 建议设置简单密码（如 `1` 或 `123456`），因为 WSL 运行在本地
- [ ] 如果忘记密码，可以通过 `wsl -u root` 重置

**任务 5.5: 重置忘记的密码**
- [ ] 在 Windows PowerShell 中执行: `wsl -u root`
- [ ] 进入 root 用户后，执行: `passwd 你的用户名`
- [ ] 按照提示输入两次新密码

---

## 第四部分：高级配置 - 隐私保护与隔离

### Phase 6: 隔离时区防止信息泄露

**任务 6.1: 禁用 WSL2 自动时区同步**
- [ ] 进入 WSL2 Ubuntu
- [ ] 编辑配置文件: `sudo nano /etc/wsl.conf`
- [ ] 如果文件不存在，会自动创建
- [ ] 添加以下内容:
  ```ini
  [time]
  useWindowsTimezone = false
  ```
- [ ] 保存: 按 `Ctrl + O`, 然后 `Enter`
- [ ] 退出: 按 `Ctrl + X`
- [ ] 重启 WSL: 在 Windows PowerShell 执行 `wsl --shutdown`

**任务 6.2: 设置 UTC 或海外时区**
- [ ] 重新进入 WSL2 Ubuntu
- [ ] 设置为 UTC: `sudo timedatectl set-timezone UTC`
- [ ] 或设置为美国东部: `sudo timedatectl set-timezone America/New_York`
- [ ] 验证设置: `timedatectl`

**任务 6.3: 临时运行时伪装时区（单次方式）**
- [ ] 启动应用时在命令前添加环境变量:
  ```bash
  TZ=America/New_York claude
  ```

**任务 6.4: 永久设置时区环境变量**
- [ ] 编辑 `~/.bashrc` 或 `~/.zshrc`
- [ ] 在末尾添加:
  ```bash
  export TZ="America/New_York"
  ```
- [ ] 保存并运行: `source ~/.bashrc`

---

### Phase 7: 隔离语言环境防止地域信息泄露

**任务 7.1: 临时设置英文语言环境（单次）**
- [ ] 启动应用时添加环境变量:
  ```bash
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 claude
  ```

**任务 7.2: 永久修改 WSL 语言环境**
- [ ] 编辑 `~/.bashrc`:
  ```bash
  nano ~/.bashrc
  ```
- [ ] 在末尾添加:
  ```bash
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  ```
- [ ] 保存并生效: `source ~/.bashrc`

**任务 7.3: 安装英文语言包**
- [ ] 执行命令:
  ```bash
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8
  ```
- [ ] 重启 WSL: `wsl --shutdown` (在 Windows PowerShell)

**任务 7.4: 创建一键启动别名（终极防护）**
- [ ] 编辑 `~/.bashrc`
- [ ] 在末尾添加:
  ```bash
  alias claude="TZ=America/New_York LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 claude"
  ```
- [ ] 保存并生效: `source ~/.bashrc`
- [ ] 以后直接运行 `claude` 即可自动使用隐私配置

---

### Phase 8: DNS 隔离 - 防止网络泄露

**任务 8.1: 禁用 WSL2 自动 DNS 生成**
- [ ] 进入 WSL2，编辑: `sudo nano /etc/wsl.conf`
- [ ] 添加或修改:
  ```ini
  [network]
  generateResolvConf = false
  hostname = secure-sandbox
  ```
- [ ] 保存并退出 (`Ctrl + O`, `Enter`, `Ctrl + X`)

**任务 8.2: 手动配置纯净公网 DNS**
- [ ] 删除旧的 DNS 配置:
  ```bash
  sudo rm -f /etc/resolv.conf
  ```
- [ ] 创建新的 DNS 配置:
  ```bash
  sudo nano /etc/resolv.conf
  ```
- [ ] 写入纯净的公网 DNS（不要使用本地路由器 IP）:
  ```
  nameserver 8.8.8.8
  nameserver 1.1.1.1
  options timeout:2 attempts:3
  ```
- [ ] 保存退出

**任务 8.3: 锁定 DNS 配置防止被篡改**
- [ ] 锁定文件:
  ```bash
  sudo chattr +i /etc/resolv.conf
  ```
- [ ] 验证锁定: `lsattr /etc/resolv.conf` (应显示 `i`)
- [ ] 以后如需修改，先解锁: `sudo chattr -i /etc/resolv.conf`

**任务 8.4: 重启 WSL 使配置生效**
- [ ] 在 Windows PowerShell 执行: `wsl --shutdown`
- [ ] 重新启动 Ubuntu 终端

---

### Phase 9: 网络代理配置（防 IP 泄露）

**任务 9.1: 配置代理环境变量**
- [ ] 编辑 `~/.bashrc`:
  ```bash
  nano ~/.bashrc
  ```
- [ ] 在末尾添加动态获取宿主机 IP 并设置代理:
  ```bash
  # 动态获取宿主机在虚拟网卡中的 IP
  export HOST_IP=$(ip route | grep default | awk '{print $3}')
  # 假设你的 Windows 代理软件开放的本地局域网端口是 7890
  export http_proxy="http://${HOST_IP}:7890"
  export https_proxy="http://${HOST_IP}:7890"
  export all_proxy="socks5://${HOST_IP}:7890"
  ```
- [ ] 保存并生效: `source ~/.bashrc`

**任务 9.2: 注意事项 - 避免 DNS 隧道陷阱**
- [ ] 在 Windows 侧的 `%USERPROFILE%\.wslconfig` 中**不要**启用 `dnsTunneling=true`
- [ ] 因为 DNS 隧道会绕过你在 Linux 中精心配置的 DNS 隔离

**任务 9.3: 使用 TUN 模式（最推荐）**
- [ ] 在你的 Windows 代理软件（如 Clash Verge Rev、v2rayN）中启用 TUN 模式
- [ ] TUN 模式会接管全局流量，自动保护所有 WSL2 请求
- [ ] 验证: WSL2 中的所有网络流量都会被代理

---

### Phase 10: 验证隐私保护效果

**任务 10.1: 验证 DNS 隔离**
- [ ] 进入 WSL2 Ubuntu
- [ ] 安装 DNS 工具:
  ```bash
  sudo apt update && sudo apt install -y dnsutils
  ```
- [ ] 测试 DNS:
  ```bash
  nslookup github.com
  ```
- [ ] 检查输出中的 "Server" 应该是 `8.8.8.8`（而非本地 IP）

**任务 10.2: 验证 IP 伪装效果**
- [ ] 安装 curl（通常已预装）:
  ```bash
  sudo apt install -y curl
  ```
- [ ] 测试公网 IP:
  ```bash
  curl ipinfo.io
  ```
- [ ] 检查返回的 `country` 和 `timezone` 应该对应你的代理节点位置
- [ ] 如果显示代理所在地，说明隐私保护成功

**任务 10.3: 检查时区设置**
- [ ] 验证当前时区:
  ```bash
  timedatectl
  ```
- [ ] 应显示为 UTC 或你设定的海外时区

**任务 10.4: 检查语言环境**
- [ ] 验证语言设置:
  ```bash
  echo $LANG
  echo $LC_ALL
  ```
- [ ] 应显示为 `en_US.UTF-8`

---

## 第五部分：Container 隔离（macOS 参考方案）

### Phase 11: 使用 Docker Container 进行完全隔离

**任务 11.1: 一行命令运行隔离容器**
- [ ] 确保 Docker 或 OrbStack 已安装
- [ ] 执行命令:
  ```bash
  docker run -it --rm \
    -v "$(pwd)":/workspace \
    -v "$HOME/.claude_mac_container:/root" \
    -w /workspace \
    -e TZ="America/New_York" \
    -e LANG="en_US.UTF-8" \
    --dns 8.8.8.8 \
    node:20-slim \
    sh -c "npm install -g @anthropic-ai/claude-code && claude"
  ```
- [ ] 验证应用在隔离容器中运行

**任务 11.2: VS Code Dev Container 配置（推荐）**
- [ ] 在项目根目录创建 `.devcontainer` 文件夹
- [ ] 在其中创建 `devcontainer.json`
- [ ] 写入配置内容（见文档第 9 页）
- [ ] 用 VS Code 打开项目
- [ ] 点击右下角"在容器中重新打开"
- [ ] VS Code 会自动构建隔离沙盒

---

## 执行优先级建议

### 最小必需（快速开始）
1. ✅ Phase 1: 快速进入 WSL2
2. ✅ Phase 2: 安装 Windows Terminal

### 推荐配置（日常使用）
3. ✅ Phase 4: 文件系统访问
4. ✅ Phase 5: 用户初始化

### 隐私保护（根据需要）
5. ⚠️ Phase 6-8: 时区、语言、DNS 隔离（如需防泄漏）
6. ⚠️ Phase 9-10: 代理配置与验证

### 高级隔离（极端隐私需求）
7. 🔒 Phase 11: Container 完全隔离

---

## 快速参考命令表

| 用途 | 命令 |
|------|------|
| 进入默认 Linux | `wsl` |
| 进入指定系统（Ubuntu） | `wsl -d Ubuntu` |
| 以 root 身份进入 | `wsl -u root` |
| 查看已安装系统 | `wsl -l -v` |
| 关闭 WSL | `wsl --shutdown` |
| 设置时区为 UTC | `sudo timedatectl set-timezone UTC` |
| 查看时区 | `timedatectl` |
| 查看 DNS 配置 | `cat /etc/resolv.conf` |
| 测试 DNS 隔离 | `nslookup github.com` |
| 测试 IP 伪装 | `curl ipinfo.io` |
| 重置 Ubuntu 用户密码 | `wsl -u root` → `passwd username` |

---

## 常见问题速查

### Q1: 用户名必须和 Windows 一致吗？
**A:** 不必须，但建议一致（方便记忆路径）。Linux 用户名要求全小写、无空格、无中文。

### Q2: Linux 密码能为空吗？
**A:** 不能。Ubuntu 初始化不接受空密码。

### Q3: 忘记了 Linux 密码怎么办？
**A:** 执行 `wsl -u root` 进入 root，然后 `passwd username` 重置。

### Q4: 为什么输入密码时没有任何显示？
**A:** 这是 Linux 的安全特性。屏幕不显示字符是正常的。

### Q5: WSL2 和宿主机如何共享文件？
**A:** 
- Linux 中访问 Windows: `cd /mnt/c/Users/username`
- Windows 中访问 Linux: 文件管理器地址栏输入 `\\wsl$`

### Q6: DNS 锁定后如何修改？
**A:** 先解锁 `sudo chattr -i /etc/resolv.conf`，修改后重新锁定。

---

## 文档信息

- **来源**: Google Gemini 对话记录
- **提取时间**: 2026-07-16
- **总页数**: 16 页 (PDF)
- **主要话题**: Windows WSL2 进入方法、用户配置、隐私保护、网络隔离
- **目标用户**: WSL2 初学者、开发者、隐私保护需求用户

---

**END OF PLAN**
