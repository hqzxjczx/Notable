# SKILL-2: WSL2 CLI → cc-switch 国产模型接线

把 WSL2 里的 Codex CLI / Claude Code 接到宿主机上的 cc-switch 本地代理,经 DeepSeek 等国产模型工作,同时确保官方 OpenAI/Anthropic 端点被 Clash REJECT。

## 入参

| 参数 | 默认 | 说明 |
|---|---|---|
| `--target` | `both` | `codex` \| `claude` \| `both`,控制写哪些配置 |

## 架构

```
WSL2 CLI ──http──▶ 192.168.144.1:<port> (cc-switch proxy, 宿主)
                        │  持真实 DeepSeek key,注入上游
                        ▼
                 api.deepseek.com
```

- cc-switch 装在**宿主机**,proxy 是网络服务,WSL2 通过默认网关 `192.168.144.1` 访问
- **不需要在 WSL2 里装 cc-switch**(会跑第二个 proxy,冲突)
- cc-switch 的"CLI 路由不支持"提示 ≠ proxy 不通;它指的是无法自动注入 WSL2 的 CLI 配置。手动同步配置即可补上

## 前置条件

1. SKILL-1 已执行(WSL2 里有 codex/claude)
2. 宿主机已装 cc-switch,`enableLocalProxy: true`
3. cc-switch GUI 里已添加 DeepSeek provider,**并为 Codex 和 Claude 都启动了路由**(两个独立的"启动"按钮)
4. Clash TUN 开启,且 `api.openai.com`/`api.anthropic.com` 在 REJECT 规则里(stealth-domestic 脚本)

## 确认 proxy 端口和绑定地址

```powershell
# 宿主机:查 cc-switch 监听
Get-NetTCPConnection -State Listen | Where-Object { $_.OwningProcess -in (Get-Process -Name 'cc-switch').Id }
```

**关键:** 绑定地址必须是 `192.168.144.1` 或 `0.0.0.0`(WSL2 可达)。若是 `127.0.0.1` 则 WSL2 连不上,需在 cc-switch 里改绑定。

## 执行步骤

### 步骤 1 — 从 WSL2 验证 proxy 可达

```bash
# 在 WSL2 里(bash -ic 加载 fnm 环境)
GW=$(ip route show default | awk '{print $3; exit}')
echo "gateway=$GW"   # 应为 192.168.144.1
curl -sS -m 6 -o /dev/null -w 'HTTP=%{http_code}\n' http://$GW:<port>/
# 期望 404(根路径不挂内容,但 TCP 通)
```

### 步骤 2 — 探路由(确认 API 端点存在)

```bash
BASE=http://192.168.144.1:<port>
for p in /v1/models /v1/responses /v1/messages; do
  code=$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "$BASE$p")
  echo "$p -> $code"
done
# 期望:/v1/models=200, /v1/responses=405, /v1/messages=405
# 405 = 路由存在,需 POST
```

查模型列表确认上游:
```bash
curl -sS -H 'Authorization: Bearer sk-dummy' "$BASE/v1/models" | head -c 600
# 应看到 deepseek-v4-flash / deepseek-v4-pro
```

> cc-switch 不校验 incoming key(它注入真实 key 到上游),`sk-dummy` 即可。

### 步骤 3 — 冒烟测上游(确认 provider 已配)

```bash
# OpenAI chat 路径(最简,验证 DeepSeek 上游通)
curl -sS -m 25 -X POST "$BASE/v1/chat/completions" \
  -H 'Content-Type: application/json' -H 'Authorization: Bearer sk-dummy' \
  -d '{"model":"deepseek-v4-flash","messages":[{"role":"user","content":"reply with exactly: PONG"}],"max_tokens":20}'
# 期望:choices[0].message.content = "PONG"

# Codex Responses 路径
curl -sS -m 25 -X POST "$BASE/v1/responses" \
  -H 'Content-Type: application/json' -H 'Authorization: Bearer sk-dummy' \
  -d '{"model":"deepseek-v4-flash","input":[{"role":"user","content":[{"type":"input_text","text":"reply with exactly: PONG"}]}]}'

# Anthropic Messages 路径
curl -sS -m 25 -X POST "$BASE/v1/messages" \
  -H 'Content-Type: application/json' -H 'x-api-key: sk-dummy' -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"claude-haiku-4-5","max_tokens":20,"messages":[{"role":"user","content":"reply with exactly: PONG"}]}'
```

**若 `/v1/messages` 返回 `{"error":"未配置供应商"}`:** cc-switch 里没为 Claude 启动路由。去 GUI 启动。

### 步骤 4 — 写配置(`--target` 控制)

#### target=codex —— 同步宿主配置(推荐)

cc-switch 在宿主机的 `~/.codex/` 生成了**完整的** `config.toml` + `cc-switch-model-catalog.json`,但检测不到 WSL2,没写进去。**同步这两个文件到 WSL2 即可**,不要手写精简版。

⚠️ **config.toml 不能原样拷!** 宿主版含 `requires_openai_auth = true` + `experimental_bearer_token = "PROXY_MANAGED"`,会让**交互式** `codex` 要求登录(`codex exec` 不受影响)。同步时必须打补丁:去掉这两行,改用 `env_key = "OPENAI_API_KEY"`(配合 `.bashrc` 里的 dummy key)。

**推荐:直接运行自动化脚本**(见 `scripts/sync-codex-config.ps1`,自动打补丁):

```powershell
.\scripts\sync-codex-config.ps1 -Test    # 同步(catalog 原样 + config 打补丁)+ 冒烟测
```

**或手动同步:**

```powershell
$src = "$env:USERPROFILE\.codex"
$dst = "\\wsl.localhost\Ubuntu-24.04\home\hqzxj\.codex"

# 1. catalog 原样拷
Copy-Item "$src\cc-switch-model-catalog.json" "$dst\cc-switch-model-catalog.json" -Force

# 2. config.toml 打补丁后写入
$cfg = Get-Content "$src\config.toml" -Raw
$cfg = $cfg -replace 'requires_openai_auth\s*=\s*true\r?\n', ''                    # 去掉(会让交互式 codex 要求登录)
$cfg = $cfg -replace 'experimental_bearer_token\s*=\s*"[^"]*"', 'env_key = "OPENAI_API_KEY"'  # 替换成 env_key
[System.IO.File]::WriteAllText("$dst\config.toml", $cfg, [System.Text.UTF8Encoding]::new($false))
```

同步后 WSL2 的 `~/.codex/config.toml` 应类似(注意:无 `requires_openai_auth`,有 `env_key`):

```toml
model_provider = "custom"
model = "deepseek-v4-flash"
model_reasoning_effort = "high"
disable_response_storage = true
model_catalog_json = "cc-switch-model-catalog.json"

[model_providers.custom]
name = "deepseek"
base_url = "http://192.168.144.1:<port>/v1"
wire_api = "responses"
env_key = "OPENAI_API_KEY"
```

**各字段作用:**

| 字段 | 作用 |
|---|---|
| `model_catalog_json` | 指向模型 metadata 文件,消除"Model metadata not found"警告,提供正确的 context_window / tool 支持等 |
| `disable_response_storage` | 非OpenAI 后端不支持 response 存储,必须 true |
| `env_key = "OPENAI_API_KEY"` | 从环境变量读 key(用 `.bashrc` 里的 dummy),替代 `experimental_bearer_token` |
| `model_reasoning_effort` | reasoning 强度(high/none) |
| `base_url` | cc-switch 会自动把它更新为 proxy 地址(`http://192.168.144.1:<port>/v1`) |

> **为什么同步优于手写:** 手写精简 config 会漏掉 `model_catalog_json`(→ metadata 警告 + 工具调用可能异常)、`disable_response_storage`(→ 非兼容后端报错)、`experimental_bearer_token`(→ 需要额外设 dummy key)。cc-switch 生成的完整 config 已处理好这些。

> **cc-switch 更新 provider 后需重新同步:** 用户在 cc-switch GUI 里改了 Codex provider(切模型/切上游),宿主 `~/.codex/config.toml` 会更新,WSL2 不会自动跟。重新跑一次上面的 `Copy-Item` 即可。

#### target=claude —— env 变量

Claude Code 没有 catalog 机制,用 env 变量。`~/.bashrc` 追加:

```bash
# ===== CLAUDE via cc-switch (DeepSeek) =====
export ANTHROPIC_BASE_URL="http://192.168.144.1:<port>"
export ANTHROPIC_API_KEY="sk-cc-switch-dummy"
export ANTHROPIC_MODEL="claude-haiku-4-5"
# ===== END CLAUDE via cc-switch =====
```

> `ANTHROPIC_BASE_URL` **不带 `/v1`**(Claude Code 自动拼 `/v1/messages`)。
>
> **模型映射关键:** cc-switch proxy 只认 `claude-*` 模型名做映射:
> - `claude-haiku-4-5` → `deepseek-v4-flash`(快/省)
> - `claude-sonnet-5` / `claude-opus-5` → `deepseek-v4-pro`(强)
>
> **不要**直接设 `ANTHROPIC_MODEL=deepseek-v4-flash` —— proxy 不认,会走默认 pro。要用 flash 就设 `claude-haiku-4-5`。

#### 写 Claude env 的推荐方式

PowerShell 驱动 WSL2 时,**复杂脚本走文件中转**(见 `REF-powershell-wsl-escaping.md`),不要走命令行内联。用幂等 heredoc 写脚本到 `/tmp/` 再执行:

```bash
#!/bin/bash
MARKER='# ===== CLAUDE via cc-switch (DeepSeek) ====='
if ! grep -qF "$MARKER" ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'

# ===== CLAUDE via cc-switch (DeepSeek) =====
export ANTHROPIC_BASE_URL="http://192.168.144.1:<port>"
export ANTHROPIC_API_KEY="sk-cc-switch-dummy"
export ANTHROPIC_MODEL="claude-haiku-4-5"
# ===== END CLAUDE via cc-switch =====
EOF
fi
```

### 步骤 5 — 端到端验证

```bash
# Codex
cd ~
codex exec --skip-git-repo-check --ephemeral -s read-only --color never \
  -o /tmp/codex_out.txt 'reply with exactly: PONG'
cat /tmp/codex_out.txt   # 期望 PONG

# Claude
claude -p 'reply with exactly: PONG'   # 期望 PONG
```

> **查 env 用 `printenv VAR`**,不要用 `echo "VAR=$VAR"`(PowerShell 会把双引号和 `$VAR` 一起坑掉)。
>
> **不应出现 "Model metadata not found" 警告** —— 若出现,说明 `cc-switch-model-catalog.json` 没同步到 WSL2 `~/.codex/`,回步骤 4 target=codex 重新同步。
>
> `codex exec` 可能报 bubblewrap 警告(用 bundled 的),非致命。

### 步骤 6 — 验证隐私(REJECT 生效)

```bash
# 这两个应被 REJECT(http=000, exit=35, 几十毫秒)
curl -sS -m 8 -o /dev/null -w 'http=%{http_code} exit=%{exitcode}\n' https://api.openai.com/v1/models
curl -sS -m 8 -o /dev/null -w 'http=%{http_code} exit=%{exitcode}\n' https://api.anthropic.com/v1/messages

# 对照:这两个应可达
curl -sS -m 8 -o /dev/null -w 'http=%{http_code}\n' https://api.deepseek.com/v1   # 401
curl -sS -m 8 -o /dev/null -w 'http=%{http_code}\n' https://registry.npmjs.org    # 200
```

`exit=35 SSL_ERROR_SYSCALL` + 几十毫秒 = Clash REJECT 的指纹(连接被接受后在 TLS 握手阶段切断)。

## 切换 provider / 模型

| 想做什么 | 怎么做 |
|---|---|
| 切到别家国产模型 | cc-switch GUI 切 Claude/Codex 的 provider(`currentProviderClaude`/`currentProviderCodex` 会更新),proxy 自动转发到新上游。**Codex 注意:** 宿主 `~/.codex/config.toml` 会更新,需重新同步到 WSL2(见步骤 4) |
| claude 用 flash ↔ pro | 改 `.bashrc` 的 `ANTHROPIC_MODEL`:`claude-haiku-4-5`(flash)↔ `claude-sonnet-5`(pro) |
| 绕过 cc-switch 直连 DeepSeek | `.bashrc` 改 `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic` + 真实 DeepSeek key(放 WSL2) |
| 回官方 Anthropic | 删三个 `ANTHROPIC_*` env + **去掉 Clash 里 `api.anthropic.com` 的 REJECT 规则** + `claude` 登录官方账号 |

## 常见错误

| 现象 | 原因 | 解法 |
|---|---|---|
| `/v1/messages` 返回"未配置供应商" | cc-switch 没为 Claude 启动路由 | GUI 里启动 Claude 路由 |
| WSL2 连不上 15721 | proxy 绑定 `127.0.0.1` 而非 `192.168.144.1`/`0.0.0.0` | cc-switch 里改绑定地址 |
| claude 响应总是 `deepseek-v4-pro` | `ANTHROPIC_MODEL` 设成了 `deepseek-v4-flash`(proxy 不认) | 改成 `claude-haiku-4-5` |
| `echo "VAR=$VAR"` 显示空 | PowerShell 双引号 + `$VAR` 被坑 | 用 `printenv VAR` |
| `codex exec` 报 "Model metadata for deepseek-v4-flash not found" | WSL2 `~/.codex/` 缺 `cc-switch-model-catalog.json`,或 config.toml 缺 `model_catalog_json` 字段 | 从宿主 `~/.codex/` 同步 `config.toml` + `cc-switch-model-catalog.json` 到 WSL2(见步骤 4) |
| codex 工具调用卡住/异常 | 同上 —— fallback metadata 的 tool 支持标志不对 | 同上,同步 catalog 后 metadata 提供正确的 `supports_parallel_tool_calls` 等字段 |
| cc-switch GUI 切了 provider 但 WSL2 codex 没生效 | 宿主 config.toml 更新了,WSL2 没同步 | 重新跑 `sync-codex-config.ps1` |
| **交互式 `codex` 要求登录** | config.toml 含 `requires_openai_auth = true`(从宿主原样拷来的) | 去掉该行,改用 `env_key = "OPENAI_API_KEY"`(见步骤 4 补丁说明);或跑 `sync-codex-config.ps1`(自动打补丁) |
