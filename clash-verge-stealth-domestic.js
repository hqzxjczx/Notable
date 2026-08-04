// Clash Verge Rev 扩展脚本 — 隐身模式（ccswitch + 国内模型）
// ==========================================================================
// 适用场景：
//   - 本地运行 Codex CLI / Claude Code
//   - 通过 ccswitch 将 API 调用转发到国内模型（DeepSeek / GLM / Qwen / NVIDIA NIM 等）
//   - 需屏蔽 OpenAI / Anthropic 的遥测，避免被官方感知到非官方模型使用
//
// 原理：
//   ccswitch 在本地起 HTTP 代理并把 CLI 的 OPENAI_BASE_URL / ANTHROPIC_BASE_URL
//   指向 localhost，因此 CLI 的模型 API 调用根本不出网（只到本地代理）。
//   但 CLI 二进制里硬编码的遥测端点（Statsig / Sentry / Datadog / GrowthBook）
//   不受 base_url 覆盖影响，仍会出网。本脚本用 REJECT 策略屏蔽这些端点。
//
// ⚠️ 与 clash-verge-us-routing.js 互斥，二选一启用：
//   - 走官方模型 → 用 us-routing.js（代理到美国）
//   - 走国内模型 → 用本脚本（屏蔽遥测）
// ==========================================================================

const BLOCK_POLICY = "REJECT";

// ===== Tier 1: 纯遥测端点（屏蔽不影响任何网站浏览，必屏蔽）=====
const TELEMETRY_RULES = [
  // --- Codex CLI 遥测 ---
  // Statsig OTLP 指标 → ab.chatgpt.com/otlp/v1/metrics
  "DOMAIN,ab.chatgpt.com",
  // Sentry 崩溃/反馈上报 → o33249.ingest.us.sentry.io
  "DOMAIN-SUFFIX,ingest.us.sentry.io",

  // --- Claude Code 遥测 ---
  // Datadog 日志 → us5.datadoghq.com （仅 1P 直连用户触发，ccswitch 场景一般不触发，屏蔽兜底）
  "DOMAIN-SUFFIX,datadoghq.com",
  // 注：Claude Code 的 1P 事件 / GrowthBook feature flags / BigQuery metrics /
  //     Remote Managed Settings / Settings Sync 全部走 api.anthropic.com，
  //     见下方 OFFICIAL_API_RULES 一并屏蔽。
  // 注：Claude Code 早期用 Statsig，现已切到 GrowthBook（端点即 api.anthropic.com），
  //     故无需单独屏蔽 statsig.anthropic.com。
];

// ===== 官方 API 端点（ccswitch 已拦截到本地，屏蔽只影响遥测和回退调用）=====
const OFFICIAL_API_RULES = [
  // Codex 官方 API：ccswitch 已把 OPENAI_BASE_URL 指向本地/国内端点，
  // 真正的 api.openai.com 流量只剩可能的回退或遥测，屏蔽掉更安全。
  "DOMAIN-SUFFIX,api.openai.com",

  // Claude 官方 API + 全部 1P 遥测：ccswitch 已把 ANTHROPIC_BASE_URL 指向本地/国内端点，
  // 真正的 api.anthropic.com 流量只剩遥测（event_logging / growthbook / metrics / settings），
  // 屏蔽即切断 Claude Code 所有官方感知通道。
  "DOMAIN-SUFFIX,api.anthropic.com",
];

// ===== Tier 2: 可选严格屏蔽（会破坏对应网站浏览器访问）=====
// 默认注释掉。如需最大隐身度（且不在浏览器用 ChatGPT/Claude.ai）可取消注释。
const OPTIONAL_STRICT_RULES = [
  // "DOMAIN-SUFFIX,chatgpt.com",    // Codex analytics 事件 + ChatGPT 网站
  //                                // 注：API key 鉴权场景下 analytics 通常不发，
  //                                // 仅 ChatGPT OAuth 鉴权才会发；屏蔽会断 chatgpt.com 浏览
  // "DOMAIN-SUFFIX,claude.ai",      // Claude 网站（CLI 不用，仅浏览器登录用）
  // "DOMAIN-SUFFIX,sentry.io",      // 所有 Sentry（含 Claude 未知 DSN；过宽，会影响其他应用）
];

function main(config) {
  if (!config) return config;

  const rules = config["rules"] || (config["rules"] = []);
  const block = (r) => `${r},${BLOCK_POLICY}`;

  const newRules = [
    ...TELEMETRY_RULES,
    ...OFFICIAL_API_RULES,
    ...OPTIONAL_STRICT_RULES,
  ].map(block);

  // 插入顶部，优先级最高
  config["rules"] = [...newRules, ...rules];

  return config;
}
