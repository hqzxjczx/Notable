// Clash Verge Rev 扩展脚本
// 功能：将 NVIDIA NIM / OpenAI Codex / Anthropic Claude Code / Google 相关 API
//      统一代理至 "🇺🇸|美国" 代理组
//
// 使用方法：
//   1. 打开 Clash Verge Rev → 配置 (Profiles)
//   2. 新建一个"脚本 (Script)"类型的配置，或将其作为 Merge/Script 链接到现有订阅
//   3. 将本文件内容粘贴进去并保存
//   4. 选中该 Profile 生效
//
// 说明：
//   - 若订阅中已存在 "🇺🇸|美国" 代理组，脚本直接复用
//   - 若不存在，脚本会自动从节点名含 "美国/美/US/USA" 的节点中创建一个 select 组
//   - 规则插入在 rules 顶部，优先级最高；脚本每次加载时运行一次，不会累积

const TARGET_GROUP = "🇺🇸|美国";

// 需要走美国代理的域名规则（按服务分组，便于维护）
const ROUTING_RULES = [
  // ===== NVIDIA NIM 免费 API =====
  "DOMAIN-SUFFIX,integrate.api.nvidia.com",   // 主推理 API 端点
  "DOMAIN-SUFFIX,build.nvidia.com",            // API Key 申请 / 控制台
  "DOMAIN-SUFFIX,api.nvidia.com",
  "DOMAIN-SUFFIX,catalog.api.nvidia.com",
  "DOMAIN-SUFFIX,cdn.nvidia.com",
  "DOMAIN-KEYWORD,nvidia",

  // ===== OpenAI / Codex CLI =====
  "DOMAIN-SUFFIX,openai.com",                  // api.openai.com + platform.openai.com
  "DOMAIN-SUFFIX,chatgpt.com",                 // Codex CLI 后端 (chatgpt.com/backend-api/codex)
  "DOMAIN-SUFFIX,oaistatic.com",
  "DOMAIN-SUFFIX,oaiusercontent.com",
  "DOMAIN-SUFFIX,openaiapi-site.azureedge.net",
  "DOMAIN-KEYWORD,openai",
  "DOMAIN-KEYWORD,chatgpt",

  // ===== OpenAI / Codex 遥测 (Telemetry) =====
  // Statsig OTLP 指标 + analytics 事件 (已被上面 chatgpt.com 覆盖，显式列出便于维护)
  "DOMAIN,ab.chatgpt.com",                     // Statsig OTLP: ab.chatgpt.com/otlp/v1/metrics
  "DOMAIN-SUFFIX,ingest.us.sentry.io",         // Sentry 崩溃/反馈上报: o33249.ingest.us.sentry.io
  // 若想更精准只走 OpenAI 的 Sentry，可改用: "DOMAIN,o33249.ingest.us.sentry.io"
  // 若想覆盖所有 Sentry 上报（含其他应用），可改用: "DOMAIN-SUFFIX,sentry.io"

  // ===== Anthropic / Claude Code =====
  "DOMAIN-SUFFIX,anthropic.com",               // api.anthropic.com + console.anthropic.com
  "DOMAIN-SUFFIX,claude.ai",
  "DOMAIN-SUFFIX,statsig.anthropic.com",       // Claude Code 遥测
  "DOMAIN-KEYWORD,anthropic",
  "DOMAIN-KEYWORD,claude",

  // ===== Google / Gemini API =====
  "DOMAIN-SUFFIX,googleapis.com",              // generativelanguage.googleapis.com 等所有 Google API
  "DOMAIN-SUFFIX,generativelanguage.googleapis.com",
  "DOMAIN-SUFFIX,gemini.google.com",
  "DOMAIN-SUFFIX,aistudio.google.com",
  "DOMAIN-SUFFIX,ai.google.dev",
  "DOMAIN-SUFFIX,google.com",
  "DOMAIN-SUFFIX,googlevideo.com",
  "DOMAIN-SUFFIX,gstatic.com",
  "DOMAIN-KEYWORD,google",
];

// 确保目标代理组存在；不存在则按节点名筛选美国节点自动创建
function ensureGroup(config, name) {
  const groups = config["proxy-groups"] || (config["proxy-groups"] = []);
  if (groups.some(g => g.name === name)) return true;

  const proxies = (config.proxies || []).map(p => p.name);
  const usProxies = proxies.filter(n => /美国|🇺🇸|美|US|USA|United States/i.test(n));
  const candidates = usProxies.length > 0 ? usProxies : proxies;

  groups.push({
    name: name,
    type: "select",
    proxies: candidates.length > 0 ? candidates : ["DIRECT"],
  });
  return false;
}

function main(config) {
  if (!config) return config;

  ensureGroup(config, TARGET_GROUP);

  const rules = config["rules"] || (config["rules"] = []);
  const newRules = ROUTING_RULES.map(r => `${r},${TARGET_GROUP}`);

  // 插入到顶部，优先级最高
  config["rules"] = [...newRules, ...rules];

  return config;
}
