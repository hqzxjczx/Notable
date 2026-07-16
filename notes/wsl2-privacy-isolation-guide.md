# WSL2 隐私保护与容器隔离指南

> 从 PDF 文档提取: `Windows WSL2 进入⼊方法`  
> 提取时间: 2026-07-16  
> 用途: 为需要高隐私保护的用户提供详细配置方案

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

**背景信息**
- WSL2 默认会自动继承 Windows 宿主机的 DNS 配置
- 这包括你本地宽带的运营商 DNS 或公司内网 DNS
- Claude Code 等工具可以通过 DNS 缓存定位你的真实网络环境
- 核心策略是"完全切断 WSL2 与 Windows DNS 的强绑定"

**任务 8.1: 禁用 WSL2 自动 DNS 生成**
- [ ] 进入 WSL2，编辑: `sudo nano /etc/wsl.conf`
- [ ] 添加或修改:
  ```ini
  [network]
  generateResolvConf = false
  hostname = secure-sandbox
  ```
- [ ] 保存并退出 (`Ctrl + O`, `Enter`, `Ctrl + X`)

**说明**:
- `generateResolvConf = false` - 禁止 WSL 自动生成 DNS 配置
- `hostname = secure-sandbox` - 自定义主机名，防止暴露 Windows 计算机名

**任务 8.2: 手动配置纯净公网 DNS**
- [ ] 删除旧的 DNS 配置:
  ```bash
  sudo rm -f /etc/resolv.conf
  ```
- [ ] 创建新的 DNS 配置:
  ```bash
  sudo nano /etc/resolv.conf
  ```
- [ ] 写入纯净的公网 DNS（**不要使用本地路由器 IP**）:
  ```
  nameserver 8.8.8.8
  nameserver 1.1.1.1
  options timeout:2 attempts:3
  ```
- [ ] 保存退出

**DNS 选项说明**:
- `nameserver 8.8.8.8` - Google DNS（推荐）
- `nameserver 1.1.1.1` - Cloudflare DNS（备选）
- `options timeout:2 attempts:3` - 查询超时设置

**任务 8.3: 锁定 DNS 配置防止被篡改**
- [ ] 锁定文件:
  ```bash
  sudo chattr +i /etc/resolv.conf
  ```
- [ ] 验证锁定: `lsattr /etc/resolv.conf` (应显示 `i`)
- [ ] 以后如需修改，先解锁: `sudo chattr -i /etc/resolv.conf`
- [ ] 修改完后重新锁定: `sudo chattr +i /etc/resolv.conf`

**为什么需要锁定？**
- 防止系统更新或其他脚本自动篡改配置
- 确保 DNS 隔离持久有效

**任务 8.4: 重启 WSL 使配置生效**
- [ ] 在 Windows PowerShell 执行: `wsl --shutdown`
- [ ] 重新启动 Ubuntu 终端

**⚠️ 关键避坑指南**
- **不要**在 Windows 侧的 `%USERPROFILE%\.wslconfig` 中启用 `dnsTunneling=true`
- DNS 隧道技术会强制所有 DNS 请求回流到 Windows 系统 DNS 客户端
- 这会使你在 Linux 中精心隔离的 8.8.8.8 配置前功尽弃

---

### Phase 9: 网络代理配置（防 IP 泄露）

**背景信息**
- 仅仅修改 DNS 只能解决"域名解析路径泄露"
- 如果你的真实 IP 直接暴露，工具仍能通过公网 IP 判定你的位置
- 需要强制所有流量通过安全代理出口

**任务 9.1: 检查你的代理软件是否支持 TUN 模式**
- [ ] 打开你的 Windows 代理软件（Clash、v2rayN、Sing-box 等）
- [ ] 查找设置中的"TUN 模式"或"虚拟网卡"选项
- [ ] 如果支持，启用 TUN 模式
- [ ] TUN 模式会接管整台电脑的全局流量

**任务 9.2: 方案 A - 使用 TUN 模式（推荐，最省心）**
- [ ] 确认 Windows 代理软件已启用 TUN 模式
- [ ] WSL2 发出的所有请求（包括 DNS 查询）都会自动被 TUN 网卡拦截
- [ ] 流量自动加密并代理出去
- [ ] **不需要**在 WSL 中手动配置代理
- [ ] **不需要**在 `.wslconfig` 中启用 `dnsTunneling`

**任务 9.3: 方案 B - 传统 NAT 模式下手动指定代理**
- [ ] 如果不支持或未启用 TUN 模式，使用此方案
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

**代理端口说明**:
- Clash 默认: `7890`（HTTP）、`7891`（Socks5）
- v2rayN 默认: `10808`（HTTP）、`10808`（Socks5）
- 根据你的软件实际配置修改端口号

**任务 9.4: 重启 WSL 应用代理配置**
- [ ] 在 Windows PowerShell 执行: `wsl --shutdown`
- [ ] 重新启动 Ubuntu 终端

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
- [ ] 检查输出中的 "Server" 字段
- [ ] ✅ 正确: 应该显示 `8.8.8.8` 或 `1.1.1.1`
- [ ] ❌ 错误: 显示本地 IP（如 `192.168.1.1`）表示隔离失败

**任务 10.2: 验证 IP 伪装效果**
- [ ] 安装 curl（通常已预装）:
  ```bash
  sudo apt install -y curl
  ```
- [ ] 测试公网 IP:
  ```bash
  curl ipinfo.io
  ```
- [ ] 检查返回的 JSON 数据中：
  - `"country"` - 应为代理所在国家（不是你的真实位置）
  - `"timezone"` - 应为代理时区（不是北京/本地时区）
  - `"ip"` - 应为代理的公网 IP（不是你的真实 IP）
- [ ] ✅ 正确: 显示代理节点的地理位置
- [ ] ❌ 错误: 显示中国或你的真实物理位置

**任务 10.3: 检查时区设置**
- [ ] 验证当前时区:
  ```bash
  timedatectl
  ```
- [ ] ✅ 正确: 应显示 UTC 或 America/New_York
- [ ] ❌ 错误: 显示 Asia/Shanghai 或其他中国时区

**任务 10.4: 检查语言环境**
- [ ] 验证语言设置:
  ```bash
  echo $LANG
  echo $LC_ALL
  ```
- [ ] ✅ 正确: 两者都应显示 `en_US.UTF-8`
- [ ] ❌ 错误: 显示 `zh_CN.UTF-8` 或其他非英文语言

**任务 10.5: 综合测试脚本**
- [ ] 创建测试脚本，一次性验证所有隐私配置:
  ```bash
  cat > ~/check-privacy.sh << 'EOF'
  #!/bin/bash
  echo "=== WSL2 隐私保护检测 ==="
  echo ""
  echo "1. 时区检查:"
  timedatectl | grep "Time zone"
  echo ""
  echo "2. 语言环境检查:"
  echo "LANG=$LANG"
  echo "LC_ALL=$LC_ALL"
  echo ""
  echo "3. DNS 隔离检查:"
  echo "DNS 服务器:"
  grep nameserver /etc/resolv.conf
  echo ""
  echo "4. DNS 解析测试:"
  nslookup github.com 2>/dev/null | grep "Server:"
  echo ""
  echo "5. 公网 IP 和地理位置:"
  curl -s ipinfo.io | grep -E '"country"|"timezone"|"ip"'
  echo ""
  echo "=== 检测完毕 ==="
  EOF
  chmod +x ~/check-privacy.sh
  ~/check-privacy.sh
  ```

---

### Phase 11: Container 隔离（macOS/Linux 完全隔离方案）

**背景信息**
- 虽然上述配置能隐藏时区和语言，但可能仍存在微妙的系统指纹
- Claude Code 仍能通过本地网络 DNS 缓存、系统库版本、命令输出等推断位置
- 完全隔离需要使用 Docker 或 OrbStack，在完全独立的容器沙盒中运行

**任务 11.1: 安装容器运行时**
- [ ] macOS 用户: 安装 OrbStack（更轻量、比 Docker Desktop 快）
  - 访问: https://orbstack.dev/
  - 下载并安装
  
- [ ] macOS 用户: 或者安装 Docker Desktop
  - 访问: https://www.docker.com/products/docker-desktop
  - 下载并安装

- [ ] Linux 用户: 安装 Docker
  ```bash
  sudo apt update && sudo apt install -y docker.io
  sudo usermod -aG docker $USER
  ```

**任务 11.2: 一行命令运行隔离容器（快速方案）**
- [ ] 确保 Docker 或 OrbStack 已启动
- [ ] 执行命令（适用 macOS/Linux）:
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

**命令参数解析**:
- `-v "$(pwd)":/workspace` - 挂载当前项目目录（代码可读写）
- `-v "$HOME/.claude_mac_container:/root"` - 挂载配置目录（保存登录 Token）
- `-w /workspace` - 工作目录为 /workspace
- `-e TZ="America/New_York"` - 强制时区为纽约
- `-e LANG="en_US.UTF-8"` - 强制语言为美式英文
- `--dns 8.8.8.8` - 强制 DNS 为 Google DNS
- `node:20-slim` - 基础镜像（轻量级 Node.js）
- 最后命令 - 安装并启动 Claude Code

**任务 11.3: VS Code Dev Container 配置（推荐方案）**
- [ ] 前置条件:
  - 安装 VS Code
  - 在插件市场安装 "Dev Containers" 插件
  - 确保 Docker 或 OrbStack 已运行

- [ ] 在项目根目录创建 `.devcontainer` 文件夹
  ```bash
  mkdir -p .devcontainer
  ```

- [ ] 在其中创建 `devcontainer.json`
  ```bash
  nano .devcontainer/devcontainer.json
  ```

- [ ] 写入以下配置:
  ```json
  {
    "name": "Secure Claude Environment",
    "image": "mcr.microsoft.com/devcontainers/javascript-node:20",
    "containerEnv": {
      "TZ": "America/New_York",
      "LANG": "en_US.UTF-8",
      "LC_ALL": "en_US.UTF-8"
    },
    "runArgs": [
      "--dns=8.8.8.8"
    ],
    "postCreateCommand": "npm install -g @anthropic-ai/claude-code",
    "customizations": {
      "vscode": {
        "extensions": [
          "dbaeumer.vscode-eslint",
          "esbenp.prettier-vscode"
        ]
      }
    }
  }
  ```

- [ ] 保存并关闭

- [ ] 用 VS Code 打开项目
  ```bash
  code .
  ```

- [ ] 等待 VS Code 启动，右下角会出现提示
- [ ] 点击 "Reopen in Container"（在容器中重新打开）
- [ ] VS Code 会自动下载基础镜像、构建容器、安装依赖
- [ ] 构建完成后，VS Code 的所有操作都在隔离容器中进行

**任务 11.4: 验证容器隔离效果**
- [ ] 在 VS Code 内置终端或容器内运行:
  ```bash
  curl ipinfo.io
  timedatectl
  echo $LANG
  nslookup github.com
  ```
- [ ] 检查所有值是否符合预期（代理位置、UTC 或海外时区、en_US.UTF-8 等）

**任务 11.5: 持久化配置**
- [ ] 下次重启 VS Code 时，直接打开同一项目
- [ ] VS Code 会自动检测 `.devcontainer/devcontainer.json`
- [ ] 无需重复配置，容器会自动启动

**任务 11.6: 容器内安装其他工具**
- [ ] 在 `postCreateCommand` 中添加额外的安装命令
- [ ] 示例（添加 Python、Git 等）:
  ```json
  "postCreateCommand": "apt-get update && apt-get install -y python3 git && npm install -g @anthropic-ai/claude-code"
  ```
- [ ] 修改后需要重新构建容器: 在 VS Code 中执行 "Dev Containers: Rebuild Container"

---

## 完整隐私保护流程总结

### 最小隐私保护方案（15 分钟）
```
Phase 6.1 → Phase 7.2 → Phase 8.1-8.4 → Phase 10.1 & 10.2
时区隔离 → 语言隔离 → DNS 隔离 → 验证效果
```

### 中级隐私保护方案（30 分钟）
```
Phase 6 → Phase 7 → Phase 8 → Phase 9.2 → Phase 10
完整时区 → 完整语言 → DNS 隔离 → 代理配置 → 完整验证
```

### 最高隐私保护方案（1 小时）
```
Phase 6-10（全部完成）→ Phase 11（容器隔离）
配置所有 WSL2 隐私设置 → Docker/VS Code 完全沙盒隔离
```

---

## 常见问题

### Q1: 为什么要同时隐藏时区和语言？
**A:** 多个信息源结合可以更准确地定位用户。单独隐藏一个不够。

### Q2: DNS 隔离后还需要代理吗？
**A:** 需要。DNS 隐藏的是域名解析路径，代理隐藏的是出口 IP。两者独立。

### Q3: 使用代理后，WSL2 的网速会变慢吗？
**A:** 取决于代理节点质量。TUN 模式一般不会明显变慢。

### Q4: 可以在 Phase 8 之后直接用 Phase 11 吗？
**A:** 可以。容器隔离完全独立，不依赖 WSL2 的配置。

### Q5: VS Code Dev Container 每次启动都要重新下载吗？
**A:** 不会。第一次构建后，后续启动会直接使用现有容器。

### Q6: 如果容器镜像损坏了怎么办？
**A:** 执行 "Dev Containers: Rebuild Container" 重新构建。

### Q7: 多个项目可以使用不同的容器配置吗？
**A:** 可以。每个项目的 `.devcontainer/devcontainer.json` 独立。

### Q8: 容器内的文件会保存到宿主机吗？
**A:** 是的。通过 `-v` 挂载的目录（如 /workspace）会同步到宿主机。

---

## 安全建议

### ⚠️ 不要做这些事

1. **不要在 `.wslconfig` 中启用 `dnsTunneling=true`** - 会破坏 DNS 隔离
2. **不要使用本地路由器 IP 作为 DNS** - 会暴露内网信息
3. **不要跳过 DNS 锁定步骤** - 否则系统可能自动覆盖配置
4. **不要在隐私容器中保存敏感信息** - 容器重建时会丢失

### ✅ 应该做这些事

1. **定期验证隐私配置** - 使用 Phase 10 的验证脚本
2. **保持代理软件更新** - 修复安全漏洞
3. **定期检查 DNS 文件权限** - 确保 `+i` 锁定还在
4. **使用强代理节点** - 选择信誉良好的服务商

---

## 进阶话题

### 防范 CPU/GPU 指纹识别
- 某些工具可以通过 CPU 信息、GPU 驱动版本识别用户
- 完全防范需要虚拟机或云端运行

### 防范系统库版本指纹
- Docker 官方镜像可能包含指纹
- 使用最小化镜像（如 `alpine`、`node:20-slim`）可减少暴露

### 防范网络 WiFi 指纹
- 即使使用代理，连接的 WiFi SSID 仍可能暴露位置
- 最彻底的方案是使用 4G/5G 或不同网络

---

**文档结束**
