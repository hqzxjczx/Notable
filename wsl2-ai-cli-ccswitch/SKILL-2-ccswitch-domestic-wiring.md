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
- cc-switch 的"CLI 路由不支持"提示 ≠ proxy 不通;它指的是无法自动注入 WSL2 的 CLI 配置。手动设 env 即可补上

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

#### target=codex

写 `~/.codex/config.toml`:

```toml
model = "deepseek-v4-flash"
model_provider = "cc-switch"

[model_providers.cc-switch]
name = "cc-switch local proxy"
base_url = "http://192.168.144.1:<port>/v1"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
```

`~/.bashrc` 追加:

```bash
# ===== CODEX via cc-switch (DeepSeek) =====
export OPENAI_API_KEY="sk-cc-switch-dummy"
# ===== END CODEX via cc-switch =====
```

> `base_url` 末尾带 `/v1`,Codex 会自动拼 `/responses`、`/models`。`wire_api="responses"` 对应 cc-switch 的 `/v1/responses` 端点。`env_key` 指定从哪个环境变量读 key,值是 dummy(cc-switch 上游注入真 key)。

#### target=claude

`~/.bashrc` 追加:

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

#### 写配置的推荐方式

PowerShell 驱动 WSL2 时,**复杂脚本走文件中转**(见 `REF-powershell-wsl-escaping.md`),不要走命令行内联。用幂等 heredoc:

```bash
#!/bin/bash
mkdir -p ~/.codex
cat > ~/.codex/config.toml <<'EOF'
... (config 内容) ...
EOF

MARKER='# ===== CODEX via cc-switch (DeepSeek) ====='
if ! grep -qF "$MARKER" ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
... (env 内容) ...
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
> `codex exec` 可能报两个非致命警告:bubblewrap 用 bundled、模型 metadata 走 fallback。不影响功能。

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
| 切到别家国产模型 | cc-switch GUI 切 Claude/Codex 的 provider(`currentProviderClaude`/`currentProviderCodex` 会更新),proxy 自动转发到新上游,**WSL2 零改动** |
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
| `codex exec` 报找不到模型 metadata | deepseek-v4-flash 非官方 OpenAI 模型 | 非致命,走 fallback metadata,正常用 |
