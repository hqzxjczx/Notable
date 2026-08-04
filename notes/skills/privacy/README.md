# privacy · 跨平台隐私加固技能（CodeBuddy Skill）

> 一个统一的 CodeBuddy Code 技能，把 `notes/` 下四套隐私文档（Windows / WSL2 / macOS / iOS）封装成 `apply / verify / check / restore` 四子命令的调度器，按 `env + region` 入参分派到对应脚本/文档。

## 文件结构

```
notes/skills/privacy/
├── README.md    # 本文件（使用说明 + 安装 + 设计说明）
└── SKILL.md     # 技能本体（CodeBuddy 加载的指令文件）
```

本目录是**规范源（canonical）**。`SKILL.md` 的活跃安装位于 `.codebuddy/skills/privacy/SKILL.md`，由本目录同步过去（见下文「更新与同步」）。

## 这是什么

CodeBuddy Code 的 Skill 是 AI 助手可自动调用的领域知识包。本技能让 AI 能根据用户一句话（如「帮我把 WSL2 隐私加固到美东」「验证 macOS 隐私配置」）自动：

1. 解析 `action + env + region` 三个维度
2. 读取 `notes/` 下对应的脚本/文档
3. **生成命令 + 说明**（不自动执行特权命令 —— 需管理员/sudo 的由用户在对应终端粘贴）
4. 给出验证方法与期望值

## 设计决策：统一技能 vs 每环境一技能

采用**统一技能 + env 入参**，原因：

- `macos-privacy.sh` 与 `wsl2-privacy.sh` 已收敛成相同的 `apply/verify/check/restore` 接口，每环境一个技能会逆这个设计
- 「四柱一致性」（时区/DNS/locale/Accept-Language）是跨端硬约束，拆开会重复且易漂移（正是 `notes/privacy-overview.md` 第四节踩过的坑）
- iOS 没有脚本，但能复用同一套 verify 清单

## 安装（激活技能）

本技能是**项目级 Skill**（路径里用相对 `notes/...` 引用，假设 cwd = 本仓库根）。两种安装方式：

### 方式 A：项目级（推荐，本仓库内生效）

```bash
# 在仓库根目录执行
mkdir -p .codebuddy/skills/privacy
cp notes/skills/privacy/SKILL.md .codebuddy/skills/privacy/SKILL.md
```

### 方式 B：用户级（所有项目可用，但 `notes/...` 路径会失效，需改绝对路径）

不推荐 —— 本技能强依赖本仓库 `notes/` 下的脚本与文档。如确需用户级，把 `SKILL.md` 里所有 `notes/...` 改成仓库绝对路径再安装到 `~/.codebuddy/skills/privacy/`。

安装后用 `/skills` 命令应能看到 `privacy` 技能。

## 使用示例

```
/privacy apply wsl2 us         # WSL2 应用美东隐私配置（生成 sudo 命令）
/privacy verify wsl2           # WSL2 验证（可直接跑 verify 子命令）
/privacy apply macos jp        # macOS 切到日本区域
/privacy check windows         # Windows 当前状态检测
/privacy restore macos         # macOS 恢复默认（回 cn）
/privacy apply ios             # iOS 给 GUI 步骤清单
```

参数：
- **action**（必填）: `apply` | `verify` | `check` | `restore`
- **env**（可自动推断）: `windows` | `wsl2` | `macos` | `ios`
- **region**（默认 `us`）: `us` | `jp` | `uk` | `sg` | `cn`

## 依赖

技能分派到这些 `notes/` 下的文件，缺一不可：

| env | 脚本/文档 |
|---|---|
| wsl2 | `notes/wsl2-privacy.sh`、`notes/wsl2-ubuntu22-privacy-setup.md`、`notes/wsl2-ubuntu24-privacy-setup.md`、`notes/net-test.sh` |
| macos | `notes/macos-privacy.sh`、`notes/macos-host-privacy-setup.md` |
| windows | `notes/windows-host-privacy-setup.md` |
| ios | `notes/ios-privacy-setup.md` |
| 共享 | `notes/privacy-overview.md`、`notes/privacy-cheatsheet-beginner.md` |

## 执行边界

按设计选择「仅生成命令 + 说明」：

- 特权命令（HKLM 注册表、`Set-TimeZone`、`sudo`、`chattr +i`）→ 输出命令文本，由用户在 Admin PowerShell / sudo 终端粘贴
- 无特权命令（`uname`、`bash wsl2-privacy.sh verify`、`curl 1.1.1.1/cdn-cgi/trace`）→ 技能可直接执行
- 符合 CodeBuddy 工具安全策略（不自我提权）与用户 memory 中的护栏（保中文输入法、.ps1 UTF-8 BOM、禁 `bash -ic`）

## 更新与同步

`notes/skills/privacy/SKILL.md` 是规范源。改完同步到活跃安装：

```bash
cp notes/skills/privacy/SKILL.md .codebuddy/skills/privacy/SKILL.md
```

或用 PowerShell：

```powershell
Copy-Item notes/skills/privacy/SKILL.md .codebuddy/skills/privacy/SKILL.md -Force
```

> 提示：可在仓库根加一个 git pre-commit hook 自动做这个同步，避免两边漂移。

## 内嵌的护栏（已写入 SKILL.md）

1. 不自动执行特权命令
2. Windows 语言列表必须用 `New-WinUserLanguageList` + `Add`（保中文输入法）
3. 写含中文的 .ps1 必须 UTF-8 BOM
4. WSL2 禁用 `bash -ic`
5. 验证出口 IP 用 `1.1.1.1/cdn-cgi/trace`，不用 `ipinfo.io`
6. 不动 Meta 接口 DNS `198.18.0.2`

## 相关文档

- `notes/privacy-overview.md` — 跨平台总览与四端一致性规则
- `notes/privacy-cheatsheet-beginner.md` — 小白速查 + 三大坑
- CodeBuddy Skill 系统文档 — `https://cnb.cool/codebuddy/codebuddy-code/-/blob/main/docs/cn/cli/skills.md`
