# WSL2 AI CLI 沙箱 — 回滚指南

- 对应搭建记录：同目录 `WSL2-AI-CLI-沙箱搭建记录.md`
- 变更日期：2026-08-04
- 适用发行版：**Ubuntu-24.04**（注意系统默认发行版是 Ubuntu-22.04，命令必须带 `-d`）

---

## 0. 本次到底改了什么

回滚前先明确改动清单，按需选择回滚粒度：

| # | 改动 | 位置 | 可独立回滚 |
|---|---|---|---|
| A | 追加 `[automount] enabled=false` + `[interop] appendWindowsPath=false` | `/etc/wsl.conf` | ✅ |
| B | 追加 fnm 初始化 3 行 | `~/.bashrc` | ✅ |
| C | 安装 fnm 1.39.0 + Node v24.19.0（约 837MB） | `~/.local/share/fnm/` | ✅ |
| D | 全局安装 `@openai/codex`、`@anthropic-ai/claude-code` | fnm 的 node installation 目录内 | ✅ |
| E | apt 安装 `unzip` | 系统 | ✅ |
| F | 删除残留空壳目录 `/mnt/c`、`/mnt/e` | 文件系统 | 自动重建 |

**宿主机 Windows 未做任何改动**，无需回滚。

### 备份文件位置（WSL 内）

```
~/wsl2-backup/wsl.conf.pre-isolation.bak    # 本次改动前的 /etc/wsl.conf
~/wsl2-backup/bashrc.pre-isolation.bak      # 本次改动前的 ~/.bashrc
~/wsl2-backup/wsl.conf.bak                  # 你更早（2026-07-16）自己留的备份
~/wsl2-backup/bashrc.bak                    # 同上
~/wsl2-backup/resolv.conf.bak               # 同上
```

> ⚠️ 用 `*.pre-isolation.bak` 回滚本次改动。
> 那两个 `2026-07-16` 的旧备份是**更早的状态**，用它们会连带撤销你自己后来做的其它配置。

---

## 1. 只解除隔离，保留 Node 和两个 CLI（最常用）

适用场景：要用 VS Code Remote-WSL、要访问 C 盘上的项目、`explorer.exe` 之类命令要能用。

```bash
# 1) 恢复 wsl.conf
wsl -d Ubuntu-24.04 -u root -- cp -a /home/hqzxj/wsl2-backup/wsl.conf.pre-isolation.bak /etc/wsl.conf

# 2) 使配置生效（只终止 24.04，不要用 wsl --shutdown）
wsl --terminate Ubuntu-24.04
```

**验证：**

```bash
wsl -d Ubuntu-24.04 -- bash -ic 'ls /mnt; mount | grep drvfs; echo $PATH | tr ":" "\n" | grep -c /mnt/c'
```

预期：`/mnt` 下重新出现 `c`、`e`；有 drvfs 挂载；PATH 中 `/mnt/c` 计数 > 0。

> 💡 **也可以只回滚一半**：如果只想恢复 C 盘访问、但不希望 Windows PATH 再污染 WSL，
> 就手工编辑 `/etc/wsl.conf`，**只删 `[automount]` 段、保留 `[interop] appendWindowsPath=false`**，
> 然后 `wsl --terminate Ubuntu-24.04`。这是隐私与便利的折中档。

---

## 2. 卸载两个 CLI，保留 Node

```bash
wsl -d Ubuntu-24.04 -- bash -ic 'npm uninstall -g @openai/codex @anthropic-ai/claude-code'
```

**同时清除凭据与配置**（含登录态，谨慎）：

```bash
wsl -d Ubuntu-24.04 -- rm -rf /home/hqzxj/.codex /home/hqzxj/.claude /home/hqzxj/.claude.json
```

> 凭据只存在于 WSL 内部 ext4，删掉即彻底失效，Windows 侧没有副本。

---

## 3. 卸载 Node 与 fnm

```bash
# 1) 移除 fnm + 所有 Node 版本 + 全局包（一并带走两个 CLI，约 837MB）
wsl -d Ubuntu-24.04 -- rm -rf /home/hqzxj/.local/share/fnm

# 2) 恢复 .bashrc（去掉 fnm 初始化）
wsl -d Ubuntu-24.04 -- cp -a /home/hqzxj/wsl2-backup/bashrc.pre-isolation.bak /home/hqzxj/.bashrc
```

若不想整体覆盖 `.bashrc`（比如之后又手工加过别的内容），改为手动删除末尾这 3 行 + 注释：

```bash
# fnm (Node version manager)
export PATH="/home/hqzxj/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd --shell bash)"
```

**验证：** 重开终端后 `command -v node fnm` 应无输出。

### 可选：卸载 unzip

```bash
wsl -d Ubuntu-24.04 -u root -- apt-get remove -y unzip
```

一般没必要 —— `unzip` 是常用基础工具，留着无害。

---

## 4. 完整回滚（恢复到 2026-08-04 改动前）

按顺序执行：

```bash
# 1) 删 CLI 凭据与配置
wsl -d Ubuntu-24.04 -- rm -rf /home/hqzxj/.codex /home/hqzxj/.claude /home/hqzxj/.claude.json

# 2) 删 fnm + Node + 全局包
wsl -d Ubuntu-24.04 -- rm -rf /home/hqzxj/.local/share/fnm

# 3) 恢复 .bashrc
wsl -d Ubuntu-24.04 -- cp -a /home/hqzxj/wsl2-backup/bashrc.pre-isolation.bak /home/hqzxj/.bashrc

# 4) 恢复 wsl.conf
wsl -d Ubuntu-24.04 -u root -- cp -a /home/hqzxj/wsl2-backup/wsl.conf.pre-isolation.bak /etc/wsl.conf

# 5) 卸载 unzip（可选）
wsl -d Ubuntu-24.04 -u root -- apt-get remove -y unzip

# 6) 生效
wsl --terminate Ubuntu-24.04
```

**完整验证：**

```bash
wsl -d Ubuntu-24.04 -- bash -ic 'ls /mnt; command -v node || echo NO_NODE; command -v codex || echo NO_CODEX; command -v claude || echo NO_CLAUDE; cat /etc/wsl.conf'
```

预期：`/mnt` 下有 `c`、`e`；三个命令均无（或 node 指回 `/mnt/c/...`）；`wsl.conf` 只剩 `[time]` 和 `[network]` 两段。

---

## 5. 核弹级：删掉整个发行版

只在发行版里没有任何需要保留的东西时使用。

```powershell
# 先导出留档（强烈建议）
wsl --export Ubuntu-24.04 D:\backup\Ubuntu-24.04-20260804.tar

# 再注销
wsl --unregister Ubuntu-24.04
```

⚠️ `wsl --unregister` **不可撤销**，会永久删除该发行版的整个文件系统，包括：
`~/` 下所有代码、`~/.codex` 与 `~/.claude` 凭据、`~/wsl2-backup/` 里的所有备份。

导入回来：

```powershell
wsl --import Ubuntu-24.04 D:\wsl\Ubuntu-24.04 D:\backup\Ubuntu-24.04-20260804.tar --version 2
```

> 注意：`--import` 回来后默认用户会变成 root，需要在 `/etc/wsl.conf` 里补 `[user] default=hqzxj`。

---

## 6. 执行回滚时的注意事项

1. **命令一律带 `-d Ubuntu-24.04`** —— 默认发行版是 Ubuntu-22.04，不带会操作错环境。

2. **用 `wsl --terminate Ubuntu-24.04`，不要用 `wsl --shutdown`** —— 后者会连带停掉 Ubuntu-22.04 和所有其它发行版。

3. **`wsl.conf` 改动必须 terminate 才生效**，改完不重启看不到任何变化，别以为没改上。

4. **改完配置务必回读校验**：

   ```bash
   wsl -d Ubuntu-24.04 -- cat -A /etc/wsl.conf
   ```

   `cat -A` 能同时看出行尾是 `$`（LF，正确）还是 `^M$`（CRLF，会导致 WSL 解析异常）。

5. **不要从 Windows 侧直接编辑 `/etc/wsl.conf`** —— 容易写入 CRLF 行尾。
   若必须从 Windows 传文件进去，用 `cp` 而不是 `tr`/`sed` 管道（经工具层调用时反斜杠会被吞，实测曾把 `[network]` 写成 `[netwok]`）。

6. **`/mnt/c`、`/mnt/e` 空壳目录已被删除**，重新开启 automount 后 WSL 会自动重建，无需手工创建。

7. **`~/wsl2-backup/` 在 WSL 内部**。如果打算 `wsl --unregister`，先把它复制到 Windows：

   ```powershell
   Copy-Item -Recurse "\\wsl.localhost\Ubuntu-24.04\home\hqzxj\wsl2-backup" "D:\backup\"
   ```
