# Computer Use 精准度研究报告

> 生成时间：2026-07-16
> 
> 基于 Cua-Bench、OSWorld 2.0、MyPCBench 等权威基准测试数据

---

## 一、研究背景

本文档总结了 computer-use（桌面自动化）技术的当前精准度水平，涵盖：
- Claude computer-use（Anthropic）
- cua-driver（开源基础设施）
- 主流 AI 模型在桌面任务上的表现

---

## 二、基准测试数据

### 2.1 短任务 / 表单填写（OSWorld 1.0）

| 模型 | 准确率 |
|------|--------|
| Claude Opus 4.8 | **83.4%** |
| Claude Sonnet 5 | **81.2%** |
| Claude Opus 4.7 | ~75% |
| Claude Sonnet 4.6 | **72.5%** |
| GPT-5.5 | 78.7% |

**结论**：短任务已跨过生产可用阈值（72-83%）。

---

### 2.2 专业桌面软件（Cua-Bench KiCad）

**来源**: https://cua.ai/cuabench

测试应用：KiCad（专业电子设计自动化软件）

| 模型 | 完成数 | 完成率 |
|------|--------|--------|
| Claude Fable 5 | 6/25 | **24%** |
| GPT-5.5 | 6/25 | **24%** |
| Gemini 3.5 Flash | 5/25 | 20% |
| Claude Sonnet 4.5 | 5/25 | 20% |
| Claude Haiku 4.5 | 5/25 | 20% |
| Claude Opus 4.8 | 4/25 | **16%** |

cua 官方结论：
> "The best frontier agent cleared just 6 of 25 expert KiCad tasks — and none of the models reliably built a schematic from a blank canvas."

**结论**：专业桌面软件操作仍不可靠（24%）。

---

### 2.3 长任务 / 复杂工作流（OSWorld 2.0）

**来源**: https://arxiv.org/abs/2606.29537

测试范围：108 个长任务，平均 1.6 小时，318 次工具调用

| 模型 | 完成率 | 部分得分 | 成本/任务 |
|------|--------|----------|-----------|
| Claude Opus 4.8 (batch) | **20.6%** | 54.8% | ~$72.4 |
| Claude Opus 4.7 (batch) | **18.2%** | 48.9% | ~$33.6 |
| GPT-5.5 (batch) | **13.0%** | 49.5% | ~$25.5 |
| Claude Sonnet 4.6 | 8.3% | 41.5% | ~$22.3 |

论文结论：
> "Current agents are still far from professional-level computer use"

**结论**：长任务复杂工作流远未达标（20.6%）。

---

### 2.4 跨应用桌面任务（MyPCBench）

**来源**: https://arxiv.org/abs/2606.16748

测试范围：17 个 Web 应用 + LibreOffice 全套，平均 2.44 个应用/任务

| 模型 | 完全解决 | 7+ 应用任务 |
|------|----------|-------------|
| Claude Opus 4.6 | **55.4%** | **36%** |
| Claude Sonnet 4.6 | 39.1% | - |
| GPT-5.5 | 29.3% | **4.5%** |
| GPT-5.4 mini | 19.0% | - |

**结论**：跨应用任务勉强可用（55%），但 7+ 应用仅 36%。

---

## 三、综合评估

| 任务类型 | 最佳模型 | 成功率 | 生产建议 |
|----------|----------|--------|----------|
| 表单填写 / 简单操作 | Claude Opus 4.8 | 72-83% | ✅ 可自动化 |
| 单一桌面软件短操作 | Claude Opus 4.8 | 50-60% | ⚠️ 需人工监督 |
| 专业桌面软件（EDA等） | Claude Fable 5 | 24% | ❌ 仅限辅助 |
| 跨应用桌面任务 | Claude Opus 4.6 | 55% | ⚠️ 需重试机制 |
| 7+ 应用协作 | Claude Opus 4.6 | 36% | ❌ 不建议自动化 |
| 长任务复杂工作流 | Claude Opus 4.8 | 20.6% | ❌ 远未达标 |

---

## 四、cua-driver 技术分析

### 4.1 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| macOS | ✅ 完全支持 | 使用 SkyLight SPI |
| Windows | ✅ 完全支持 | v0.7.1 已支持 |
| Linux (X11) | ✅ 支持 | 需桌面环境 |
| Linux (Wayland) | ⚠️ 部分支持 | KDE/GNOME 需 libei |
| WSL2 | ❌ 不可用 | 无桌面环境 |
| Docker/容器 | ❌ 不可用 | 无桌面环境 |

### 4.2 已知问题（GitHub Issues）

| Issue | 问题描述 |
|-------|----------|
| #32766 | cua-driver 后端过于脆弱，破坏视觉路由 |
| #1979 | Windows 多显示器点击坐标错误 |
| #1982 | Linux Wayland 输入不派发 |
| #1882 | Windows DPI 缩放坐标混乱 |

### 4.3 精准度限制

cua-driver 本身是基础设施层，精准度取决于底层模型：
- 视觉识别不稳定（小按钮、模糊 UI 容易出错）
- 屏幕状态幻觉（模型有时会"脑补"屏幕状态）
- 复杂任务超时（从零开始的任务容易超出步骤预算）

---

## 五、来源汇总

| 来源 | 链接 | 类型 |
|------|------|------|
| Cua-Bench | https://cua.ai/cuabench | 桌面软件基准测试 |
| OSWorld 2.0 | https://arxiv.org/abs/2606.29537 | 长任务学术论文 |
| MyPCBench | https://arxiv.org/abs/2606.16748 | 跨应用桌面任务 |
| Anthropic 官方 | https://claude.com/blog/best-practices-for-computer-and-browser-use-with-claude | 最佳实践文档 |
| ResearchAudio | https://researchaudio.io/p/sonnet-4-6-scores-72-5-on-computer-use-opus-scores-72-7 | 生产阈值分析 |
| TokenMix | https://tokenmix.ai/blog/claude-computer-use-api-2026 | 操作层面分析 |
| Caylent | https://caylent.com/blog/claude-sonnet-4-6-in-production-capability-safety-and-cost-explained | 生产力分析 |
| cua-driver README | https://github.com/trycua/cua/blob/main/libs/cua-driver/README.md | 技术文档 |
| Hermes Agent | https://github.com/NousResearch/hermes-agent/issues/32766 | 已知问题 |

---

## 六、结论

1. **表单填写等简单任务**已跨过生产阈值（72-83%），可考虑自动化
2. **专业桌面软件操作**仍不可靠（24%），仅适合作为辅助工具
3. **跨应用协作**勉强可用（55%），需要重试和人工监督机制
4. **长任务复杂工作流**远未达标（20.6%），不建议生产环境自动化
5. **cua-driver** 是目前最好的开源桌面控制基础设施，但精准度受限于底层视觉模型

**核心观点**：computer-use 技术已从"有趣演示"进入"有限生产可用"阶段，但距离可靠自动化仍有很大差距。

---

*文档结束*
