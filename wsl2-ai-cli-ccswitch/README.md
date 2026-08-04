# WSL2 AI-CLI 沙箱 + cc-switch 国产模型接线 + Clash 脚本切换 — 会话总结

- 执行日期:2026-08-04
- 目标环境:Windows 10 Pro 宿主 / WSL2 Ubuntu-24.04.4 / cc-switch v3.19.1(宿主) / Clash Verge Rev
- 相关原始记录:`../chatgpt/WSL2-AI-CLI-沙箱搭建记录.md`
- 覆盖范围:WSL2 CLI 安装、cc-switch 国产模型接线、Clash Verge Rev 订阅脚本切换(跨平台)

---

## 一、目标

把 Codex CLI 和 Claude Code 关进 WSL2 沙箱(不装宿主机),再让它们经宿主机上的 cc-switch 本地代理接入国产 DeepSeek 模型,同时用 Clash TUN 的 REJECT 规则切断官方 `api.openai.com`/`api.anthropic.com` 遥测,让 OpenAI/Anthropic 感知不到用量。

## 二、一路踩的坑(按时间顺序)

| # | 坑 | 现象 | 根因 | 解法 |
|---|---|---|---|---|
| 1 | 以为安装文档只是计划 | 用户说"之前只是计划没执行",但实测文档四阶段全部已落地(版本逐字吻合) | 文档是执行后写的记录,标题"搭建记录"被误记成计划 | 核对实际状态(版本/文件时间戳)后再决定是否重装;**不要盲目重装** |
| 2 | `echo "VAR=$VAR"` 显示空 | `.bashrc` 里明明 export 了,echo 却输出空 | PowerShell 5.1 原生参数传递把双引号剥掉,`$VAR` 又被提前展开成空串 | 改用 `printenv VAR` 查环境变量 |
| 3 | base64 中转被拦截 | `echo BASE64 \| base64 -d \| bash` 报 "Spawning a non-PowerShell shell" | 安全策略禁止从 PowerShell 工具派生非 PowerShell shell | 改走**文件中转**:`[System.IO.File]::WriteAllText` 写到 `\\wsl.localhost\...` 再 `wsl -- bash /tmp/x.sh` |
| 4 | here-string 里双引号仍丢失 | 单引号 here-string `@'...'@` 内的 `"..."` 被 PowerShell 剥掉 → bash 语法错误 | here-string 只保 `$` 不保双引号 | bash 命令内**只用单引号**,不用双引号 |
| 5 | cc-switch `/v1/messages` 返回"未配置供应商" | Codex 路径通,Claude 路径报错 | 用户只为 Codex 配了 DeepSeek provider,没为 Claude 配;后来配了但没点"启动路由" | 在 cc-switch GUI 里为 Claude 也加 DeepSeek provider 并**启动路由** |
| 6 | 模型映射意外 | 设 `ANTHROPIC_MODEL=deepseek-v4-flash`,响应却返回 `deepseek-v4-pro` | cc-switch proxy 的模型路由只认 `claude-*` 模型名,直接传 deepseek 名字走默认 pro | 改设 `ANTHROPIC_MODEL=claude-haiku-4-5`,proxy 映射到 `deepseek-v4-flash` |
| 7 | db 被进程锁住读不了 | `[System.IO.File]::ReadAllBytes` 报 "being used by another process" | cc-switch 运行时独占 db | 改用 `[System.IO.File]::Open(path, Open, Read, ReadWrite)` 共享读 |

## 三、最终状态

| 项 | 结果 |
|---|---|
| WSL2 隔离 | `/mnt` 仅 wsl/wslg,无 drvfs,PATH 无 /mnt/c |
| Node / npm | v24.19.0 / 11.17.0(fnm 1.39.0 管理) |
| Codex CLI | codex-cli 0.146.0 |
| Claude Code | 2.1.221 |
| Codex → DeepSeek | 经 cc-switch proxy(15721),`codex exec` 实测 PONG |
| Claude → DeepSeek | 经 cc-switch proxy(15721),`claude -p` 实测 PONG,模型走 flash(`claude-haiku-4-5` 映射) |
| 隐私 | `api.openai.com`/`api.anthropic.com` 从 WSL2 出站均被 Clash REJECT(SSL_ERROR_SYSCALL,几十毫秒) |
| DeepSeek 可达性 | `api.deepseek.com` 直连 401(TCP/TLS 通),未被 REJECT |

### 数据流

```
WSL2 CLI ──http──▶ 192.168.144.1:15721 (cc-switch proxy, 持真实 DeepSeek key)
                        │
                        ▼
                 api.deepseek.com  (OpenAI /v1 + Anthropic /anthropic)

官方 api.openai.com / api.anthropic.com ──▶ Clash TUN REJECT (切断)
```

## 四、技能粒度决策

采用 **3 个技能 + 1 个参考文档 + 1 个自动化脚本**,覆盖完整链条:装 CLI → 接 cc-switch → 切 Clash 脚本。

| 文件 | 类型 | 作用 | 入参 |
|---|---|---|---|
| `SKILL-1-install-wsl2-ai-cli.md` | 技能 | 在 WSL2 装隔离沙箱 + Node + codex/claude | `clis=codex,claude`(默认两个) |
| `SKILL-2-ccswitch-domestic-wiring.md` | 技能 | 把 WSL2 的 CLI 接到宿主 cc-switch proxy | `--target codex\|claude\|both` |
| `SKILL-3-clash-verge-script-switch.md` | 技能 | 切换 Clash Verge Rev 订阅的拓展脚本(跨平台) | `--script <name>`(支持自定义脚本) |
| `REF-powershell-wsl-escaping.md` | 参考 | PowerShell↔WSL2 转义陷阱 + 文件中转法 | — |
| `scripts/sync-codex-config.ps1` | 脚本 | 同步宿主 cc-switch Codex 配置到 WSL2 | `-Test`(可选冒烟测) |

**为什么不拆成更多个**:装 codex 和装 claude 共享 Node/fnm,一条 npm 命令装完,拆不开;配 codex 和配 claude 共享 80% 步骤(验证 proxy、探路由、冒烟测、验证 REJECT),拆了会重复。

**为什么不合成 1 个**:装、配、切脚本是不同生命周期,前置条件不同(装要 WSL2+apt,配要 cc-switch 跑起来,切脚本要 Clash Verge Rev),捆成 mega-skill 复用性差。

**SKILL-3 跨平台**:支持 Windows / macOS / Linux,自动探测平台和配置目录,入参用可读脚本名(不要求 uid),支持注册任意自定义脚本。

## 五、关键经验

1. **PowerShell 驱动 WSL2,复杂脚本一律走文件中转**,不要走命令行内联(双引号/`$`/`%{}`/反引号全会被坑)。文件中转 = `[System.IO.File]::WriteAllText` 写到 `\\wsl.localhost\Ubuntu-24.04\tmp\x.sh`(UTF-8 无 BOM)+ `wsl -- bash /tmp/x.sh`。
2. **查 WSL2 环境变量用 `printenv VAR`**,不用 `echo "VAR=$VAR"`(后者双引号被剥 + `$VAR` 被展开,会误判变量没设)。
3. **cc-switch 的 proxy 是网络服务,CLI 装哪都行**(宿主或 WSL2),只要 CLI 的 base_url 指向 `192.168.144.1:<port>`。不需要在 WSL2 里再装 cc-switch。
4. **cc-switch 的"路由不支持"提示 ≠ proxy 不通**。它指的是 cc-switch 无法自动检测/注入 WSL2 里的 CLI 配置。手动设 env 变量即可补上这一步。proxy 的 provider 路由(含切换)是正常的。
5. **模型映射**:cc-switch proxy 只认 `claude-*` 模型名做映射(haiku→flash, sonnet/opus→pro)。直接传 deepseek 模型名会走默认 pro。要用 flash 就设 `ANTHROPIC_MODEL=claude-haiku-4-5`。
