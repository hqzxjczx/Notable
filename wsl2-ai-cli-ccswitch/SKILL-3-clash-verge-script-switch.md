# SKILL-3: Clash Verge Rev 订阅拓展脚本切换

切换 Clash Verge Rev 订阅(如 SakuraCat)绑定的拓展脚本(如 us-routing ↔ stealth-domestic ↔ 任意自定义脚本)。支持 Windows / macOS / Linux。

## 入参

| 参数 | 必填 | 说明 |
|---|---|---|
| `--script <name>` | 是(非 list 模式) | 可读脚本名(如 `stealth-domestic`、`us-routing`、`my-custom`)。自动反查 uid;查不到则注册新条目 |
| `--subscription <name>` | 否 | 订阅名关键字(如 `sakura`)。默认:当前活跃订阅(`current` 字段),或按名字含 sakura/樱花 匹配 |
| `--list` | 否 | 只读模式:列出所有已注册脚本 + 各订阅当前绑定的脚本,不改动任何东西 |
| `--source <path>` | 否 | 新脚本注册时,源 `.js` 文件路径。若未给,先查 `profiles/<name>.js` 是否已存在 |

**设计原则:**
- 用户给**可读名字**,不给 uid —— uid 由技能从 `profiles.yaml` 反查
- 名字查不到 = 新脚本 → 自动注册(拷 `.js` 进 `profiles/` + 加 `items` 条目),支持任意自定义脚本
- `--list` 解决"不知道有哪些脚本可选"

## 平台差异表

`profiles.yaml` 的格式和编辑逻辑**平台无关**。差异只在配置目录、可执行路径、进程启停:

| | Windows | macOS | Linux |
|---|---|---|---|
| **配置目录** | `%APPDATA%\io.github.clash-verge-rev.clash-verge-rev\` | `~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/` | `~/.config/io.github.clash-verge-rev.clash-verge-rev/` |
| **停进程** | `Stop-Process -Name clash-verge -Force` | `pkill -f "Clash Verge"` | `pkill -f clash-verge` |
| **启进程** | `Start-Process "C:\Program Files\Clash Verge\clash-verge.exe"` | `open -a "Clash Verge"` | `nohup clash-verge >/dev/null 2>&1 &` |
| **探测条件** | `$env:APPDATA` 非空 | `$HOME` + `/Library/Application Support` 存在 | `$XDG_CONFIG_HOME` 或 `$HOME/.config` 存在 |
| **运行时配置** | `<configdir>\clash-verge.yaml` | `<configdir>/clash-verge.yaml` | `<configdir>/clash-verge.yaml` |
| **脚本目录** | `<configdir>\profiles\` | `<configdir>/profiles/` | `<configdir>/profiles/` |

> **macOS 路径基于 Tauri 应用标准约定**(bundle id `io.github.clash-verge-rev.clash-verge-rev`)。首次在 macOS 上用时,用 `--list` 验证一次路径是否正确。进程名可能是 "Clash Verge" 或 "Clash Verge Rev"(取决于版本),`pkill -f` 比 `pkill -x` 更稳。

## profiles.yaml 结构(参考)

```yaml
current: <订阅uid>           # 当前活跃 profile

items:
  # 订阅(remote)
  - uid: RSyfrpWwzDV9         # SakuraCat 订阅
    type: remote
    name: SakuraCat
    url: https://...
    option:
      script: stealth-domestic   # ← 要改的就是这个字段(指向脚本 uid)
      # ...其他选项

  # 脚本(script)
  - uid: stealth-domestic       # 脚本 uid(可直接用名字)
    type: script
    name: null
    file: stealth-domestic.js   # 对应 profiles/stealth-domestic.js
    updated: 1785839205

  - uid: sE8yLKCzu4nW           # 另一个脚本(us-routing)
    type: script
    file: sE8yLKCzu4nW.js
    updated: 1785000867
```

## 执行步骤

### 步骤 0 — 探测平台 + 解析路径

```
若 $env:APPDATA 非空 → Windows
  configDir = "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev"
若 $HOME/Library/Application Support 存在 → macOS
  configDir = "$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
否则 → Linux
  configDir = "$env:XDG_CONFIG_HOME/clash-verge-rev..." 或 "$HOME/.config/clash-verge-rev..."
```

确认 `profiles.yaml` 存在;不存在则报错(Clash Verge Rev 未安装或未运行过)。

### 步骤 1 — 读 profiles.yaml

读取并解析 YAML。提取:
- `current` 字段(当前活跃 profile uid)
- `items` 数组(所有 profile:remote=订阅、script=脚本)

### 步骤 2 — `--list` 模式(若指定)

打印:
```
=== 已注册脚本 ===
  stealth-domestic  (file: stealth-domestic.js, uid: stealth-domestic)
  us-routing        (file: sE8yLKCzu4nW.js, uid: sE8yLKCzu4nW)

=== 订阅 ===
  SakuraCat (uid: RSyfrpWwzDV9) → 当前脚本: stealth-domestic
```
然后退出,不做任何改动。

### 步骤 3 — 解析订阅

- 若 `--subscription <name>` 给了:在 `items` 里找 `type: remote` 且 `name` 含 `<name>`(大小写不敏感)的条目
- 否则:用 `current` 字段指向的 uid;若该 uid 是订阅(remote)直接用;若 `current` 指向的不是 remote,则在 remote 条目里按 name 含 "sakura/樱花" 匹配
- 找到后记录:订阅 uid、当前 `option.script` 值(旧脚本 uid)

### 步骤 4 — 解析脚本 uid

在 `items` 里找 `type: script` 且 `file` 匹配 `<name>.js` 的条目:

**找到:** 取其 `uid`。继续步骤 6。

**没找到(新脚本注册):**
1. 确认 `profiles/<name>.js` 文件存在:
   - 若 `--source <path>` 给了:拷贝 `<path>` → `profiles/<name>.js`
   - 若未给:查 `profiles/<name>.js` 是否已存在(GUI 可能已加过)
   - 都没有:报错,要求用户提供 `--source`
2. 在 `items` 数组追加一条:
   ```yaml
   - uid: <name>
     type: script
     name: null
     file: <name>.js
     updated: <unix时间戳>
   ```
   > uid 直接用脚本名(如 `stealth-domestic`),不用随机串 —— 可读、好排查,实测 Clash 接受。
3. 取这个新 uid 继续步骤 6。

### 步骤 5 — 备份 + 停 Clash

1. 拷 `profiles.yaml` → `profiles.yaml.bak.<时间戳>`
2. 停 Clash Verge Rev(按平台表执行停进程命令)
3. 等待 2-3 秒确认进程退出

> **必须先停再改!** Clash 运行时会在退出时把内存里的 profiles.yaml 写回磁盘,覆盖你的编辑。

### 步骤 6 — 改 profiles.yaml

把订阅项的 `option.script` 从旧 uid 改为新 uid:

```yaml
option:
  script: <新uid>      # 原来是 <旧uid>
```

只改这一个字段,其他不动。保持 YAML 缩进。

### 步骤 7 — 重启 Clash

按平台表执行启进程命令。等待 5-8 秒让 Clash 加载 profile、生成运行时配置。

### 步骤 8 — 验证

读取生成的运行时配置(平台对应的 `clash-verge.yaml`),检查 `rules:` 段顶部:

```powershell
# Windows(避免 PowerShell 5.1 的 UTF-8 乱码)
$text = [System.IO.File]::ReadAllText("$configDir\clash-verge.yaml", [System.Text.Encoding]::UTF8)

# macOS/Linux
$text = Get-Content "$configDir/clash-verge.yaml" -Raw
```

确认:
- rules 顶部的规则符合预期脚本的输出(REJECT 规则?美国代理路由?数量对?)
- 目标代理组(如 `🇺🇸|美国`)在 `proxy-groups` 段存在

> Windows 上 PowerShell 5.1 的 `Get-Content` 读 UTF-8 的 emoji/CJK 组名会乱码(`🇺🇸|美国` → `????|??`)。用 `[System.IO.File]::ReadAllText` + UTF8 编码读,或直接看 Clash GUI 的"配置"/"连接"页。

## 关键坑

| 坑 | 后果 | 解法 |
|---|---|---|
| Clash 运行时改 profiles.yaml | 退出时被覆盖,改动丢失 | **必须先停进程再改** |
| Windows `Get-Content` 读 UTF-8 | emoji/CJK 组名乱码,误判配置错 | 用 `[System.IO.File]::ReadAllText(path, UTF8)` |
| macOS 进程名不确定 | `pkill -x "Clash Verge"` 可能匹配不到 | 用 `pkill -f "Clash Verge"`(模糊匹配) |
| 新脚本 uid 用随机串 | 难排查,不知道哪个 uid 对应哪个脚本 | **uid 直接用脚本名**,可读 |
| YAML 缩进被破坏 | Clash 解析失败,profile 加载不了 | 改完 `cat -A` 回读校验缩进 |
| 订阅没有 `option` 字段 | 没法绑脚本 | 先在 GUI 里给订阅加一次任意脚本,生成 `option` 结构 |

## 使用示例

```bash
# 列出所有脚本和订阅当前绑定
--list

# 切到 stealth-domestic(已注册)
--script stealth-domestic

# 切到 us-routing(已注册,uid 是随机串 sE8yLKCzu4nW)
--script us-routing

# 注册并切到新自定义脚本(源文件在 ~/my-scripts/custom.js)
--script custom --source ~/my-scripts/custom.js

# 指定订阅(多订阅场景)
--script stealth-domestic --subscription sakura
```
