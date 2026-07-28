# Exoskeleton Codex 平台架构说明

> 版本：2.1.0-dev  
> 状态：Codex 适配器已完成首版实现  
> 范围：Cursor + Claude Code + Codex 三平台架构

## 1. 适配性评估

Exoskeleton 的核心理念与 Codex 比较契合。

本项目不是业务代码生成器，而是一套面向编码 Agent 的治理 harness：它把持久项目画像、可复用工作流、规则、技能、Hooks、验证循环和审计记录放进一个可预期的系统中。Codex 的原生能力可以比较自然地承接这套模型：

| Exoskeleton 能力 | Codex 原生承载面 |
| --- | --- |
| 项目画像与团队长期约定 | `AGENTS.md` |
| 可复用工作流与专项指导 | `.agents/skills/**/SKILL.md` 或 plugin skills |
| 可安装分发包 | 带 `.codex-plugin/plugin.json` 的 Codex plugin |
| 生命周期治理与拦截 | `.codex/hooks.json` 与 `.codex/hooks/*.ps1` |
| 命令权限治理 | Codex sandbox、approval 与 `.rules` |
| 长期或周期性治理 | Codex automations 与 skills |

主要不匹配点是历史上的 `/command` 心智模型。Codex 中，自定义 slash prompt 已不再适合作为可复用工作流的主抽象；因此 Codex 适配器把 `/start`、`/code`、`/audit`、`/performance` 等 Exoskeleton 入口包装为显式技能：`exoskeleton-start`、`exoskeleton-code`、`exoskeleton-audit` 等。这样既保留原流程语义，又符合 Codex 的 progressive disclosure 与 plugin 分发模型。

## 2. 当前结构评估

仓库已经具备合适的一层目录拆分：

```text
src/        统一核心资产与权威源
platforms/ 平台适配层
docs/      平台中立文档
```

这适合扩展为三平台架构，但平台层职责需要保持显式：Cursor、Claude Code 与 Codex 不应在大型脚本里各自隐式发明安装语义。每个平台适配器都应清晰定义：

- 平台 manifest 或配置模板
- Hook 事件适配器
- 工作流暴露格式
- 安装脚本
- 校验脚本
- 平台使用指南

## 3. 目标三平台架构

```text
coding-exoskeleton/
  src/
    commands/        平台中立工作流定义
    agents/          专职子代理角色定义
    rules/           治理规则
    skills/          可复用任务技能
    hooks/           共享 Hook 函数库与历史 Hook 策略
  platforms/
    cursor/
      install.ps1
      verify.ps1
      hooks/
      .cursor-plugin/
    claude/
      install-claude.ps1
      verify-claude.ps1
      commands/
      agents/
      hooks/
      templates/
    codex/
      install-codex.ps1
      verify-codex.ps1
      workflow-skills/
      hooks/
      templates/
  docs/
    v2-architecture.md
    codex-platform-architecture.md
```

平台职责边界：

| 层级 | 职责 |
| --- | --- |
| `src/` | 工作流语义、治理策略、技能内容和共享 Hook 行为的唯一权威源。 |
| `platforms/*/templates` | 仅存放平台特定 manifest 与配置模板。 |
| `platforms/*/hooks` | 基于 `src/hooks/common.ps1` 的轻量事件与 payload 适配器。 |
| `platforms/*/install*.ps1` | 将平台资产生成或复制到目标项目或插件位置。 |
| `platforms/*/verify*.ps1` | 只读结构校验，不修改目标项目。 |

## 4. Codex 适配器设计

Codex 适配器默认采用项目级安装，不修改用户全局 Codex 配置：

- `.agents/skills` 接收 Exoskeleton 原始 skills 与 Codex workflow wrapper skills。
- `.agents/references/commands` 接收 workflow wrapper skills 引用的原始平台中立命令定义。
- `.agents/references/rules` 与 `.agents/references/agents` 接收平台中立治理引用，供 workflow skills 与 custom agents 使用。
- `.codex/agents` 接收由 `src/agents/*.md` 生成的 Codex custom-agent TOML wrapper。
- `.codex/rules` 接收 Codex 命令审批规则，用于稳定的高风险命令策略。
- `.codex/hooks.json` 启用目标项目中的生命周期 hooks。
- `.codex/hooks` 存放 Codex 事件适配器。
- `.agents/plugins/marketplace.json` 暴露 repo-local Codex plugin。
- `plugins/coding-exoskeleton` 存放 plugin bundle，包含 `.codex-plugin/plugin.json`、skills 以及 command/rule/agent references。

这种设计有意避免写入 `~/.codex/config.toml` 或全局 hooks。安装结果保留在目标仓库内，便于 review、信任和回滚，也符合 Codex 的项目 trust 与 sandbox 模型。

## 5. Codex 工作流映射

| 现有入口 | Codex skill | 来源引用 |
| --- | --- | --- |
| `/init` | `exoskeleton-init` | `src/commands/init.md` |
| `/start` | `exoskeleton-start` | `src/commands/start.md` |
| `/code` | `exoskeleton-code` | `src/commands/code.md` |
| `/audit` | `exoskeleton-audit` | `src/commands/audit.md` |
| `/performance` | `exoskeleton-performance` | `src/commands/performance.md` |
| `/deliver` | `exoskeleton-deliver` | `src/commands/deliver.md` |
| `/report` | `exoskeleton-report` | `src/commands/report.md` |

旧入口名称继续保留在 `src/commands` 引用中；Codex 用户应优先直接调用技能，例如：

```text
$exoskeleton-start SV-34577
$exoskeleton-code SV-34577
$exoskeleton-audit
```

## 6. Hook 策略

Codex hooks 不作为隐藏的全局强制策略处理，而是安装到目标项目的 `.codex/` 层。Codex 会展示 hook 定义，并要求用户在 `/hooks` 中审查和信任。

当前映射事件：

| Codex 事件 | Matcher | Exoskeleton 行为 |
| --- | --- | --- |
| `PreToolUse` | `Bash|PowerShell|Write|Edit|MultiEdit|NotebookEdit|apply_patch` | 高风险命令拦截与路径白名单检查 |
| `PermissionRequest` | `Bash|PowerShell|apply_patch` | 针对高风险 shell 或 patch 行为的审批请求治理 |
| `UserPromptSubmit` | 所有 prompt | 模式与任务信号识别 |
| `PreCompact` | `manual|auto` | 在 `.exoskeleton/compaction/` 写入轻量压缩检查点 |
| `PostCompact` | `manual|auto` | 将压缩完成事件记录到 harness events |
| `PostToolUse` | 写工具与 `apply_patch` | 编辑审计日志记录 |

后续增强方向：

- 随着稳定审批前缀沉淀，继续扩展 `.codex/rules` 覆盖范围。
- 为需要集中管控的团队补充 managed/team config 示例。
- 补充 recurring governance report、PR follow-up check 等 automation recipes。

## 7. 实施状态

本轮 Codex 适配已完成：

- 新增 `platforms/codex/install-codex.ps1`。
- 新增 `platforms/codex/verify-codex.ps1`。
- 新增 `platforms/codex/hooks` 下的 Codex hook adapters。
- 新增项目级 hook 模板 `platforms/codex/templates/hooks.project.json`。
- 新增 Codex plugin manifest 与 marketplace 模板。
- 为全部 7 个 Exoskeleton workflow 入口新增 Codex workflow skills。
- 从 `src/agents/*.md` 生成 Codex custom agents。
- 生成 Codex `.rules`，承接稳定命令审批策略。
- 增加 `PermissionRequest`、`PreCompact` 与 `PostCompact` hook 覆盖。
- 新增 `docs/codex-user-guide.md`。

建议下一轮继续处理：

- 抽取共享 PowerShell 安装辅助函数到 `platforms/shared/install-lib.ps1`。
- 用一个小型 platform manifest 生成 Cursor、Claude Code 与 Codex 平台资产，减少安装器内的重复映射逻辑。
- 为所有平台 verifier 增加 CI 校验。

## 8. 验证方式

针对目标业务项目执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File platforms\codex\install-codex.ps1 -ProjectRoot "C:\path\to\project" -Force
powershell -NoProfile -ExecutionPolicy Bypass -File platforms\codex\verify-codex.ps1 -ProjectRoot "C:\path\to\project"
```

安装完成后，重启 Codex 或重新打开项目；随后使用 `/hooks` 审查并信任项目 hooks。
