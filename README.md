# Notable

一个私人知识库和研究笔记项目，涵盖两部分内容：

- **AI 前沿技术分析** — Computer Use（桌面自动化）能力评估、基准测试与开源基础设施研究。
- **跨平台隐私设置文档** — macOS / Windows / WSL2 / iOS 的隐私与指纹一致性设置清单，以及一键应用脚本。

## 📋 项目概述

Notable 用于记录、整理和分析技术研究成果，重点包括：

- **Computer Use（桌面自动化）** - AI 模型在桌面环境的自动化能力评估
- **基准测试数据** - 收集和整理各类权威性能测试结果
- **开源基础设施分析** - cua-driver 等开源工具的深度研究
- **跨平台隐私设置** - 在 macOS / Windows / WSL2 / iOS 上保持时区、区域、DNS、语言的一致指纹，规避隐私泄露

## 📁 项目结构

```
Notable/
├── notes/
│   ├── computer-use-accuracy-report.md     # Computer Use 精准度研究报告
│   ├── Untitled.md / cat.md / 前置代理.md  # 其他笔记
│   ├── privacy-overview.md                 # ★ 隐私文档总览 / 跨平台一致性索引
│   ├── macos-host-privacy-setup.md         # macOS 隐私设置清单（SakuraCat 代理 + WARP DNS）
│   ├── windows-host-privacy-setup.md       # Windows / WSL2 隐私设置清单
│   ├── ios-privacy-setup.md                # iOS 隐私设置清单
│   ├── wsl2-*.md                           # WSL2 隔离 / SakuraCat / 方案规划 等
│   ├── macos-privacy.sh                    # ★ macOS 一键 apply / verify / check / restore
│   └── qoderclicn/                         # 借鉴的 AI 编码防封配套脚本（多区域切换 / 容器）
│       ├── ai-coding-security-privacy-guide.md
│       ├── switch-env-macos.sh
│       ├── switch-env-wsl2.sh
│       └── switch-env-container.sh
└── README.md
```

> ★ 标记为入口文件：先看 `privacy-overview.md` 了解全貌，再按需进入各平台文档；macOS 用户可直接用 `macos-privacy.sh` 落地。

## 📊 主要内容

### 1. Computer Use 精准度研究报告

基于权威基准测试（Cua-Bench、OSWorld 2.0、MyPCBench）的综合分析，涵盖：

- **表单填写/简单操作**：准确率 72-83% ✅ 可自动化
- **单一桌面软件短操作**：准确率 50-60% ⚠️ 需人工监督
- **专业桌面软件（EDA）**：准确率 24% ❌ 仅限辅助
- **跨应用桌面任务**：准确率 55% ⚠️ 需重试机制
- **长任务复杂工作流**：准确率 20.6% ❌ 远未达标

**关键发现**：Computer Use 已从"演示阶段"进入"有限生产阶段"；简单任务可靠，复杂工作流仍待改进；Claude Opus 4.8 表现最佳；cua-driver 是目前最好的开源桌面控制基础设施。

### 2. 跨平台隐私设置文档

目标：在多端保持一致的隐私指纹（`America/New_York` 时区 + `1.1.1.1` DNS + `en_US` 区域），降低被关联/泄露风险。

**核心架构（macOS）**：SakuraCat **代理模式（端口 7897）** 负责流量出口 + **Cloudflare WARP（仅 DNS 模式）** 负责 DNS 加密。二者职责分离，互不冲突。

- **`macos-privacy.sh`** 子命令：
  - `sudo ./macos-privacy.sh apply [us|jp|uk|sg|cn]` — 应用时区 / 区域 / 系统代理 / 终端代理 / 全接口 IPv6 关闭（默认 us）
  - `./macos-privacy.sh verify [区域]` — 验证关键项（无需 sudo）
  - `./macos-privacy.sh check` — 打印当前环境状态
  - `sudo ./macos-privacy.sh restore` — 恢复默认
- **WARP 模式要点**：macOS 必须选 **「仅 DNS（HTTPS）」或「仅 DNS（TLS）」**；**切勿**选「流量和 DNS（UDP/TLS/HTTPS）」全隧道模式（会接管全部流量、覆盖 SakuraCat 出口）。
- **Windows / WSL2**：SakuraCat 走 **TUN 模式**，由隧道封装 DNS，无需 WARP；参考 `windows-host-privacy-setup.md` 与 `wsl2-*.md`。
- **一致性规则与跨平台对照**详见 `privacy-overview.md`。

## 🔍 代理与隐私检测网址

用于验证代理出口 IP、DNS 泄漏、链式代理是否生效等。

### IP 出口检测

| 网址                        | 说明                              |
| --------------------------- | --------------------------------- |
| <https://ip.sb>               | 显示当前出口 IP 和归属地          |
| <https://ipinfo.io>           | 详细 IP 信息（城市、ASN、运营商） |
| <https://www.iplocation.net>  | 对比多个数据库的 IP 归属          |
| <https://browserleaks.com/ip> | 更详细的 IP 指纹信息              |

### DNS 泄漏检测

| 网址                        | 说明                            |
| --------------------------- | ------------------------------- |
| <https://www.dnsleaktest.com> | 测试 DNS 是否泄漏到入口节点     |
| <https://ipleak.net>          | 综合检测 IP + DNS + WebRTC 泄漏 |

### 链式代理专项验证

| 网址                              | 说明                                                           |
| --------------------------------- | -------------------------------------------------------------- |
| <https://browserleaks.com/webrtc>   | 检查 WebRTC 是否暴露真实 IP（链式代理后如有泄漏会暴露入口 IP） |
| <https://www.astrill.com/leak-test> | 综合泄漏测试                                                   |

> **链式代理最直观的验证方式**：在 Clash Verge → 连接（Connections）面板中查看发起请求时的 **chains** 列，若显示两跳（入口 → 出口），说明 dialer-proxy 已生效。

---

## 🔗 参考资源

- [Cua-Bench](https://cua.ai/cuabench) - 桌面软件基准测试
- [OSWorld 2.0](https://arxiv.org/abs/2606.29537) - 长任务学术论文
- [MyPCBench](https://arxiv.org/abs/2606.16748) - 跨应用桌面任务
- [cua-driver](https://github.com/trycua/cua) - 开源桌面控制库

## 📝 使用说明

- 所有笔记采用 Markdown 格式编写，支持本地编辑和 Git 版本控制。
- 脚本均为 Bash，macOS 端 `macos-privacy.sh` 需 `sudo` 执行 apply / restore。

## 📅 更新时间

- 最后更新：2026-07-22
- Computer Use 报告基准数据时间：2026-07-16

## 📄 许可证

私人知识库，仅供个人参考使用。

---

**声明**：本项目内容基于公开发布的研究数据和官方文档，用于学习和研究目的。
