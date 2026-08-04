# Granola.ai 美国代理分流方案 — Hand-off 文档

> 关联文件：`clash-verge-us-routing.js`
> 日期：2026-08-04
> 状态：已实施

---

## 1. 背景与目标

Granola 是一款 AI 会议笔记应用（macOS / iOS / iPadOS / watchOS），后端基础设施位于美国，多家 AI/转录子处理器亦在美国。从国内直连其 API 与功能域不稳定，需统一走 `🇺🇸|美国` 代理组。

目标：在现有 `clash-verge-us-routing.js` 脚本中追加 Granola 相关出站域名规则，覆盖其完整功能链路。

---

## 2. 信息来源（权威性排序）

| 来源 | URL | 用途 |
|---|---|---|
| Granola Trust Center — Subprocessors | `https://trust.granola.ai/subprocessors` | **权威**子处理器清单（公司/域名/用途/托管地） |
| Granola API Docs | `https://docs.granola.ai/` | 确认 `public-api.granola.ai` REST API 端点 |
| Granola MCP 集成配置 | `https://www.mcpworld.com/zh/detail/a8df8b88093931c78cc5e6fd5056862e` | 旁证 `api.granola.ai` 为客户端 API 基址 |
| Granola Privacy Policy | `https://www.granola.ai/privacy` | 确认 `granola.so` 为公司备用域、AWS 为存储方 |
| Granola DPA | `https://docs.granola.ai/help-center/policies/data-processing-addendum` | 指向 Trust Center 子处理器清单 |

> **未采用**的推测来源：CSDN / 微博 / 36氪等中文媒体报道（仅背景信息，不作域名依据）。

---

## 3. 调研结论：Granola 出站域名全表

### 3.1 Granola 自有域

| 域名 | 子域示例 | 用途 |
|---|---|---|
| `granola.ai` | `public-api.granola.ai`（公开 REST API）、`api.granola.ai`（客户端 API）、`docs.granola.ai`、`trust.granola.ai`、`www.granola.ai` | 主域 |
| `granola.so` | `go.granola.so`（跳转）、`privacy@granola.so` | 公司备用域 |

### 3.2 子处理器清单（来自 `trust.granola.ai/subprocessors`）

| 服务商 | 域名 | 用途 | 托管地 | 处理方式 |
|---|---|---|---|---|
| Anthropic | `anthropic.com` | AI 模型 | US | **已覆盖**（现有 Claude Code 段） |
| OpenAI | `openai.com` | AI 模型 | US | **已覆盖**（现有 Codex 段） |
| Google Cloud | `cloud.google.com` / `googleapis.com` | 云托管/AI | US | **已覆盖**（现有 Google 段） |
| Amazon Web Services | `aws.amazon.com` | 云托管/存储 | US | **不加**（过于宽泛） |
| xAI | `x.ai` | Grok 模型 | US | 新增 |
| AssemblyAI | `assemblyai.com` | 转录 | US | 新增 |
| Deepgram | `deepgram.com` | 转录 | US | 新增 |
| Fireworks.ai | `fireworks.ai` | 模型推理 | US | 新增 |
| Braintrust | `braintrust.dev` | AI 评估 | US | 新增 |
| Parallel | `parallel.ai` | Web 搜索增强 | US | 新增 |
| Turbopuffer | `turbopuffer.com` | 向量搜索/嵌入存储 | US | 新增 |
| ClickHouse | `clickhouse.com` | 事件/遥测存储 | US | 新增 |
| Knock | `knock.app` | 通知编排 | US | 新增 |
| Plain | `plain.com` | 客服平台 | UK | 新增 |
| Twilio | `twilio.com` | in-product 电话 | US | 新增 |
| Stripe | `stripe.com` | 支付 | US | **不加**（仅支付，App 功能不依赖） |

---

## 4. 决策记录

### 4.1 范围选择

经与用户确认，采用 **全量方案**：
- 类别一：Granola 自有域 ✅
- 类别二：AI/转录子处理器 ✅
- 类别三：基础设施/遥测/通知 ✅
- `DOMAIN-KEYWORD,granola` 兜底 ✅

### 4.2 排除项与理由

| 排除项 | 理由 |
|---|---|
| AWS（`aws.amazon.com` / `amazonaws.com`） | 过于宽泛，会代理大半个互联网；Granola 的 AWS 流量走其自有 API 域，已间接覆盖 |
| Stripe（`stripe.com`） | 仅支付场景，App 核心功能（笔记/转录/AI）不依赖；如需订阅支付可后续单独加 |
| 客户端 SDK 第三方域名（Sentry/PostHog/Statsig/Clerk 等） | DPA 与 Trust Center 均未列出，无权威依据；需抓包确认后再补（见 §6） |

### 4.3 风险评估

| 规则 | 误伤风险 | 说明 |
|---|---|---|
| `DOMAIN-SUFFIX,x.ai` | 低 | 域名简短但独特，匹配 `api.x.ai` / `grok.x.ai` 等 |
| `DOMAIN-KEYWORD,granola` | 低 | 含 "granola" 的无关域名极少 |
| `DOMAIN-SUFFIX,clickhouse.com` | 低 | ClickHouse 虽为开源产品，但其云服务域为 `clickhouse.com`；本地自建实例不走此域 |
| `DOMAIN-SUFFIX,plain.com` | 中 | 较通用英文词，但作为域名后缀实际碰撞少 |
| `DOMAIN-SUFFIX,knock.app` | 低 | `.app` TLD 下的 `knock` 较独特 |

---

## 5. 实施记录

### 5.1 修改文件

`clash-verge-us-routing.js`

### 5.2 变更内容

**1. 头部注释（line 2）** — 在功能描述中加入 Granola：

```diff
- // 功能：将 NVIDIA NIM / OpenAI Codex / Anthropic Claude Code / Google 相关 API
+ // 功能：将 NVIDIA NIM / OpenAI Codex / Anthropic Claude Code / Google / Granola AI Notepad 相关 API
//      统一代理至 "🇺🇸|美国" 代理组
```

**2. ROUTING_RULES 数组（line 62–81）** — 在 Google 段后追加 Granola 段：

```js
// ===== Granola AI Notepad =====
// Granola 自有域 (含 public-api.granola.ai / api.granola.ai / docs.granola.ai / trust.granola.ai)
"DOMAIN-SUFFIX,granola.ai",
"DOMAIN-SUFFIX,granola.so",                    // 公司备用域 (privacy@granola.so / go.granola.so 跳转)
"DOMAIN-KEYWORD,granola",                      // 兜底捕获未来新增子域

// --- Granola AI / 转录子处理器 (核心功能依赖) ---
"DOMAIN-SUFFIX,x.ai",                          // xAI Grok 模型
"DOMAIN-SUFFIX,assemblyai.com",                // 转录
"DOMAIN-SUFFIX,deepgram.com",                  // 转录
"DOMAIN-SUFFIX,fireworks.ai",                  // 模型推理
"DOMAIN-SUFFIX,braintrust.dev",                // AI 评估测试
"DOMAIN-SUFFIX,parallel.ai",                   // Web 搜索增强

// --- Granola 基础设施 / 遥测 / 通知 ---
"DOMAIN-SUFFIX,turbopuffer.com",               // 向量搜索 / 嵌入存储
"DOMAIN-SUFFIX,clickhouse.com",                // 事件 / 遥测数据存储
"DOMAIN-SUFFIX,knock.app",                     // 通知编排 (邮件 / 推送)
"DOMAIN-SUFFIX,plain.com",                     // 客服平台 (UK)
"DOMAIN-SUFFIX,twilio.com",                    // in-product 电话功能
```

共新增 **14 条规则**。规则插入在 `rules` 顶部（由 `main()` 函数保证），优先级最高。

### 5.3 未改动部分

- `TARGET_GROUP` 常量
- `ensureGroup()` 函数
- `main()` 函数
- 其他服务的规则段（NVIDIA / OpenAI / Anthropic / Google）

---

## 6. 已知局限与后续跟进

### 6.1 客户端遥测域名不确定

DPA 与 Trust Center 的 sub-processor 清单覆盖的是**服务端**数据流。Granola 客户端 app（macOS/iOS）可能内嵌第三方 SDK，走独立域名，例如：

| 候选 SDK | 候选域名 | 用途 | 状态 |
|---|---|---|---|
| Sentry | `*.ingest.sentry.io` | 崩溃上报 | 未确认 |
| PostHog | `*.posthog.com` / `app.posthog.com` | 产品分析 | 未确认 |
| Statsig | `featuregates.org` / `api.statsig.com` | 功能开关/实验 | 未确认 |
| Clerk | `clerk.granola.ai` / `*.clerk.accounts.com` | 认证 | 未确认 |

**确认方法**（任选其一）：

```bash
# 方法 1：tcpdump 抓 DNS（macOS/Linux，需 sudo）
sudo tcpdump -i any -nn 'port 53' 2>/dev/null | grep -iE 'granola|sentry|posthog|statsig|clerk'

# 方法 2：mitmproxy 抓 HTTPS（需在 Granola 设置代理）
mitmproxy --listen-port 8080
# 然后在 Granola app 中配置 HTTP 代理 127.0.0.1:8080 并安装证书

# 方法 3：lsof 看进程连接（macOS）
lsof -i -n -P | grep -i granola
```

确认后按相同格式追加到 `ROUTING_RULES` 数组的 Granola 段即可。

### 6.2 子处理器清单会变动

`trust.granola.ai/subprocessors` 列表 Granola 会不定期更新（DPA 约定至少 10 天前通知）。建议每季度复查一次该页面，同步新增/移除的域名。

### 6.3 `granola.so` 的取舍

当前加入 `DOMAIN-SUFFIX,granola.so` 以覆盖 `go.granola.so` 跳转与 `privacy@granola.so` 邮件链接。若实际使用中发现无流量走此域，可移除以精简规则。

---

## 7. 验证步骤

### 7.1 加载 Profile

1. 打开 Clash Verge Rev → 配置 (Profiles)
2. 选中包含 `clash-verge-us-routing.js` 的 Script Profile
3. 保存并刷新

### 7.2 规则生效验证

在 Clash Verge Rev → 连接 (Connections) 页面观察：启动 Granola app 后，应看到 `*.granola.ai` / `*.granola.so` 及各子处理器域名的连接走 `🇺🇸|美国` 代理组。

### 7.3 命令行验证（可选）

```bash
# 测试 API 可达性（走代理）
curl -I https://public-api.granola.ai/v1/notes
# 期望：HTTP 401（未授权，但能连上）—— 说明代理通路正常

# 测试主站
curl -I https://www.granola.ai
# 期望：HTTP 200 / 301 / 302
```

---

## 8. 规则快速参考表

| 域名 | 规则类型 | 走代理组 | 类别 |
|---|---|---|---|
| `granola.ai` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 自有 |
| `granola.so` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 自有 |
| `granola` | DOMAIN-KEYWORD | 🇺🇸\|美国 | 自有兜底 |
| `x.ai` | DOMAIN-SUFFIX | 🇺🇸\|美国 | AI |
| `assemblyai.com` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 转录 |
| `deepgram.com` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 转录 |
| `fireworks.ai` | DOMAIN-SUFFIX | 🇺🇸\|美国 | AI |
| `braintrust.dev` | DOMAIN-SUFFIX | 🇺🇸\|美国 | AI 评估 |
| `parallel.ai` | DOMAIN-SUFFIX | 🇺🇸\|美国 | Web 搜索 |
| `turbopuffer.com` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 向量搜索 |
| `clickhouse.com` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 遥测存储 |
| `knock.app` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 通知 |
| `plain.com` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 客服 |
| `twilio.com` | DOMAIN-SUFFIX | 🇺🇸\|美国 | 电话 |

---

## 9. 回滚

如需回滚，删除 `clash-verge-us-routing.js` 中 line 62–81 的 Granola 段，并将 line 2 的 `/ Granola AI Notepad` 从头部注释中移除。其他部分不受影响。
