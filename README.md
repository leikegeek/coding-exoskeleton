# Exoskeleton — AI 编程治理框架

Exoskeleton 是面向企业级研发场景的 Cursor 插件框架，目标是把 AI 协作从"能完成任务"升级为"可治理、可演进、可稳定交付"。

## 核心理念

Exoskeleton 基于 harness 思想构建治理闭环：不是把 Agent 当黑箱执行器，而是将其放入一个可约束、可观测、可迭代的工程系统。

- 以**双流水线 + 任务契约**收敛执行路径，确保任务从需求到交付始终围绕主线推进
- 以 `Rules + Skills` 持续迭代上下文与执行策略，避免一次配置长期失效
- 以 `Hooks` 承担关键动作拦截和审计，实现高风险操作前置治理
- 以**战略性上下文压缩**在阶段切换时主动释放 token 空间，通过结构化快照确保关键信息不丢失
- 以**结构化验证循环**编排构建、测试、性能、对齐、规范五个维度的质量门禁，支持增量重验与断点续验
- 以**专职子代理**在流水线关键节点自动委派专业审查，通过上下文收窄防止子代理漂移
- 以人机协同做关键决策兜底，在风险节点保留确认与回滚能力

这套机制的目标是：针对真实复杂项目做深度定制，通过持续反馈迭代，保证交付可靠、质量稳定、风险可控。

## 解决的问题

在复杂项目中，Agent 的主要挑战通常不在代码生成能力，而在工程可控性。Exoskeleton 重点解决三类问题：

- **主线漂移与任务混乱**：上下文复杂后，Agent 容易偏离目标主线，任务拆解和推进节奏失稳，导致目标丢失与 token 膨胀。Exoskeleton 通过**任务契约约束执行边界**、**战略性上下文压缩释放 token 空间**、**实施进度追踪支持跨会话断点续做**来系统性应对。
- **未知风险被引入交付**：对业务边界、历史约束和系统耦合理解不充分时，Agent 可能引入看似正确但未经风险识别的改动。Exoskeleton 通过**结构化验证循环**（构建→测试→性能→对齐→规范五维度门禁）和**专职子代理**（架构审查、安全审计、TDD 纪律检查）层层拦截。
- **高风险命令误执行**：缺少前置门禁时，破坏性命令可能直接执行，给代码库、环境或数据带来不可逆影响。Exoskeleton 通过**模式隔离 + Hooks 行为拦截 + 路径门禁**构建纵深防线。

Exoskeleton 通过治理闭环把"用起来"变成"越用越稳"。

## 核心能力一览

| 能力 | 说明 | 关联组件 |
|------|------|---------|
| 双流水线 | 设计与编码可断开/续接，适配实际协作分工 | `/start`、`/code` |
| 需求编号全链路贯穿 | SV-ID 串联方案、分支、commit、文档、审计 | 任务契约 |
| 三层治理 | Skills 指导 + Rules 约束 + Hooks 拦截审计 | 全流程 |
| 战略性上下文压缩 | 阶段切换时主动压缩，快照保护关键信息 | `context-compaction` rule + skill |
| 结构化验证循环 | 五维度门禁 + 增量重验 + 断点续验 | `verification-loop` skill |
| 专职子代理编排 | 关键节点自动委派，上下文收窄防漂移 | `architect`、`tdd-guide`、`security-reviewer` 等 |
| 实施进度追踪 | 技术方案文档中自动维护进度，跨会话断点续做 | `coding` skill |
| 三方对齐审查 | 变更记录 + diff + 方案三方对账 | `code-reviewer` agent |
| 增量变更记录 | 编码时同步维护文档，审查时定稿 | `coding` skill |
| 模式隔离与命令拦截 | 设计/编码模式 + 危险命令 deny | Hooks |

## 持续迭代闭环

```mermaid
flowchart LR
    pluginInfra[插件沉淀治理基础设施] --> teamUse[团队按标准流程使用插件]
    teamUse --> pluginObserve[插件收集反馈与案例]
    pluginObserve --> pluginEvaluate[插件评测人效质量稳定性]
    pluginEvaluate --> pluginOptimize[插件优化规则流程上下文]
    pluginOptimize --> pluginInfra
```
**欢迎大家结合自己的项目和使用经验提出宝贵意见，更欢迎大家分享各种编程语言的skill&rule来丰富Exoskeleton生态**

**感谢一下同学提出的宝贵意见和建议**
> @liuxuesen

## 文档入口（先看这里）

> **用户手册（安装与使用入口）**  
> [docs/user-guide.md](docs/user-guide.md)

> **核心原理（架构与流程解释）**  
> [docs/plugin-core-workflow.md](docs/plugin-core-workflow.md)

> **治理基线检查清单**  
> [docs/governance-checklist.md](docs/governance-checklist.md)

> **故障处理 Runbook**  
> [docs/operations-runbook.md](docs/operations-runbook.md)

> **Profile 扩展模板**  
> [docs/profile-extension-template.md](docs/profile-extension-template.md)

## 平台支持

当前版本仅支持 **Windows**（PowerShell 5.1+）。Hooks 脚本和安装脚本均基于 PowerShell 实现，macOS / Linux 支持在后续版本规划中。

## 版本

当前版本：1.0.3
