# SKILL-1: WSL2 AI-CLI 沙箱安装

在 WSL2 Ubuntu-24.04 里装一个隔离沙箱,装好 Node + Codex CLI + Claude Code,**不碰 Windows 宿主机**。

## 入参

| 参数 | 默认 | 说明 |
|---|---|---|
| `clis` | `codex,claude` | 装哪些 CLI,逗号分隔 |

## 前置条件

- Windows 10/11 + WSL2,已装 Ubuntu-24.04(`wsl -l -v` 确认)
- 默认发行版可能是 22.04,所有命令**必须带 `-d Ubuntu-24.04`**
- 宿主机有 Clash TUN 透明代理(域名解析到 198.18.0.45 fake-IP),WSL2 出站走宿主代理,**无需另配代理或国内镜像**

## 执行步骤

### 阶段 0 — 备份

```bash
mkdir -p ~/wsl2-backup
cp -a /etc/wsl.conf      ~/wsl2-backup/wsl.conf.pre-isolation.bak
cp -a /home/hqzxj/.bashrc ~/wsl2-backup/bashrc.pre-isolation.bak
```

### 阶段 1 — 隔离加固(`/etc/wsl.conf`)

保留原有 `[time]` `[network]`,追加两段,最终内容:

```ini
[time]
useWindowsTimezone = false

[network]
generateResolvConf = false
hostname = secure-sandbox

[automount]
enabled = false

[interop]
appendWindowsPath = false
```

- `automount=false` → 切断 `/mnt/c` 全盘可读(隔离的主要手段)
- `appendWindowsPath=false` → 清掉注入的 Windows PATH(**必须同时设**,否则 automount 关掉后 PATH 残留死条目)

生效(只终止 24.04,**不用 `wsl --shutdown`**,避免影响 22.04):

```powershell
wsl --terminate Ubuntu-24.04
```

重启后清理残留空壳:`/mnt/c`、`/mnt/e` 目录删掉。

**验证:**
```
mount | grep drvfs   → NO_DRVFS_MOUNTS
ls -A /mnt           → 只剩 wsl, wslg
command -v npm       → 无输出(Windows npm 泄漏已消除)
getent hosts registry.npmjs.org → 198.18.0.45(网络仍通)
```

### 阶段 2 — 装 unzip + fnm + Node 24

```bash
# root(用 wsl -u root 免密)
apt-get update && apt-get install -y unzip

# 用户:下载 fnm 二进制(不要用 curl|bash,会被安全策略拦截)
curl -fSL -o /tmp/fnm.zip https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip
unzip -o -j /tmp/fnm.zip fnm -d /tmp/fnmx
install -m 755 /tmp/fnmx/fnm /home/hqzxj/.local/share/fnm/fnm

fnm install 24 && fnm default 24
```

`~/.bashrc` 末尾追加 3 行:

```bash
# fnm (Node version manager)
export PATH="/home/hqzxj/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd --shell bash)"
```

**验证:** `node -v` → v24.19.0,`npm -v` → 11.17.0,
`npm config get prefix` → 用户级路径(全局装包**不需要 sudo**)。

> **注意:** 验证 Node/npm 必须用 `bash -ic`(交互式),因为 Ubuntu 的 `.bashrc` 对非交互 shell 会提前 return,fnm env 不加载。

### 阶段 3 — 装 CLI

```bash
npm install -g @openai/codex @anthropic-ai/claude-code
```

> npm 11 会拦截 `@anthropic-ai/claude-code` 的 postinstall 脚本(`node install.cjs`)。**不用放行** —— 原生二进制已就位,`claude --version` 正常。更新走 `npm i -g @anthropic-ai/claude-code` 即可。若确需放行:`npm install -g --allow-scripts=@anthropic-ai/claude-code`。

**验证:**
```
codex --version  → codex-cli 0.146.0
claude --version → 2.1.221 (Claude Code)
```

## 安全边界(必读)

1. **隔离是单向的**:`automount=false` 只切断 WSL→Windows。反方向 Windows 仍能通过 `\\wsl.localhost\Ubuntu-24.04\home\...` 读写 WSL 文件(9p 服务,关不掉)。
2. **沙箱挡的是误伤,不是定向攻击**:挡不住恶意代码主动逃逸、网络外发、凭据泄漏。真正敏感的东西不要放进 `~/`。
3. **凭据落盘**:`~/.codex/` 和 `~/.claude/` 都在 WSL ext4,不写 Windows 磁盘。删除发行版 = 凭据一起没。
4. **`claude.exe` 不是 Windows 程序**:它是 Linux 原生 ELF 二进制(Anthropic 跨平台统一用了 `.exe` 文件名)。隔离没破。
5. **网络走宿主 TUN 代理**:WSL 内所有请求对宿主透明代理可见。

## 回滚

见 `../chatgpt/WSL2-AI-CLI-回滚指南.md`(若存在)。核心:恢复 `/etc/wsl.conf` 的 `[automount] enabled=true` + `[interop] appendWindowsPath=true`,`wsl --terminate` 生效。
