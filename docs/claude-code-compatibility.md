# Exoskeleton 双平台兼容性说明

> 版本：V2.0.0+
> 适用范围：Cursor IDE + Claude Code CLI

## 一、概述

Exoskeleton V2 支持**双平台交付**——同一份核心资产（`src/`），通过平台适配层（`platforms/`）生成 Cursor 和 Claude Code 两种格式。

本文档说明两平台间的兼容性范围、差异点和迁移注意事项。

## 二、核心原则

### 2.1 一份权威源

所有命令流程、规则约束、技能定义、子代理角色和 Hook 策略只在 `src/` 中维护。平台层 `platforms/` 只做格式转换，不包含业务逻辑。

### 2.2 平台互不影响

- Cursor 安装不影响 Claude Code 项目配置
- Claude Code 安装不影响 Cursor 全局配置
- 两平台可在同一项目中**同时使用**（共享项目画像和治理日志）

### 2.3 治理能力等价

两平台覆盖的治理能力**语义等价**：

| 治理能力 | Cursor | Claude Code |
|---------|--------|------------|
| 危险命令拦截 | ✅ | ✅ |
| 路径门禁 | ✅ | ✅ |
| 模式识别与切换 | ✅ | ✅ |
| 文件编辑审计 | ✅ | ✅ |
| 斜杠命令（7 个） | ✅ | ✅ |
| 专职子代理（10 个） | ✅ | ✅ |
| 分层技能 | ✅ | ✅ |
| 分层规则 | ✅ | ✅ |
| 治理事件日志 | ✅ | ✅ |
| `/report` 统计 | ✅ | ✅ |

## 三、格式差异速查

### 3.1 命令

| 属性 | Cursor | Claude Code |
|------|--------|------------|
| 位置 | `platforms/cursor/` 生成的命令产物 | `.claude/commands/*.md` |
| Frontmatter | 无 | description, argument-hint, allowed-tools |
| 工具约束 | 隐式（通过流程描述） | 显式（allowed-tools 字段） |

### 3.2 子代理

| 属性 | Cursor | Claude Code |
|------|--------|------------|
| 位置 | `platforms/cursor/` 生成的子代理产物 | `.claude/agents/*.md` |
| 调用方式 | 主 Agent 读取 + Task 工具 | 主 Agent 委派 agents 目录 |
| Frontmatter | 无 | name, description, tools, model, color |

### 3.3 规则

| 属性 | Cursor | Claude Code |
|------|--------|------------|
| 格式 | `.mdc`（含 alwaysApply, globs frontmatter） | 无原生格式，通过 CLAUDE.md 引用 |
| 分级 | shared / family-common / profile 三级别 | 同左，通过 AGENTS.md.techStack 激活 |

### 3.4 技能

| 属性 | Cursor | Claude Code |
|------|--------|------------|
| 格式 | `SKILL.md`（文件夹式） | `SKILL.md`（相同的文件夹式结构） |
| 位置 | `.cursor/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` |
| 内容 | **完全相同**（无格式差异） | **完全相同** |

### 3.5 Hooks

| 属性 | Cursor | Claude Code |
|------|--------|------------|
| 配置位置 | `~/.cursor/hooks.json`（全局用户级） | `.claude/settings.json`（项目级） |
| 输入方式 | 命令行参数 | stdin JSON |
| 阻断方式 | `exit 2` + stderr | stdout `{decision: "block"}` 或 `exit 2` + stderr |
| 允许方式 | `exit 0` 或 JSON `{decision: "allow"}` | stdout JSON `{decision: "allow"}` |
| 询问方式 | JSON `{decision: "ask", reason: "..."}` | stdout JSON `{decision: "ask", reason: "..."}` |
| 事件名称 | afterFileEdit, beforeShellExecution, beforeSubmitPrompt | PreToolUse, PostToolUse, UserPromptSubmit |

## 四、行为差异

### 4.1 安装范围

- **Cursor**：安装到 `~/.cursor/plugins/local/coding-exoskeleton`（全局），所有项目受益
- **Claude Code**：安装到 `<project>/.claude/`（项目级），每个项目独立安装

这一差异是两平台的设计哲学决定的：
- Cursor 插件机制天然是全局的
- Claude Code 的 `.claude/` 项目级配置是推荐做法，避免全局污染

### 4.2 Hook 触发时机

| 事件 | Cursor 触发时机 | Claude Code 触发时机 |
|------|---------------|-------------------|
| 写文件前 | beforeShellExecution（匹配写工具） | PreToolUse（matcher: Write/Edit） |
| 写文件后 | afterFileEdit | PostToolUse（matcher: Write/Edit） |
| 命令执行前 | beforeShellExecution | PreToolUse（matcher: Bash/PowerShell） |
| Prompt 提交前 | beforeSubmitPrompt | UserPromptSubmit |

### 4.3 状态目录

两平台共享状态目录逻辑（`common.ps1` 中定义）：

1. 优先使用 `.exoskeleton/`（V2 统一目录）
2. Fallback 到 `.cursor/`（V1 兼容）
3. 双平台治理日志写入同一目录，`/report` 可统计两边事件

### 4.4 项目画像

- **Cursor**：直接使用 `AGENTS.md`
- **Claude Code**：`CLAUDE.md` 是导航入口，实际画像内容仍在 `AGENTS.md`

`AGENTS.md` 是双平台**唯一的项目画像权威文件**。`CLAUDE.md` 不重复画像内容，只做转发。

## 五、迁移指南

### 5.1 从 V1 迁移到 V2

V2 重新组织了代码结构，不做向后兼容。迁移步骤：

1. 克隆最新版本仓库（V2 分支）
2. 在目标项目中重新执行安装
3. 旧治理日志（`.cursor/hooks/logs/`）可保留，`common.ps1` 会自动 fallback 读取

### 5.2 从纯 Cursor 迁移到双平台

1. 先完成 V2 迁移
2. 在同一个项目中执行 Claude Code 安装
3. 两平台共享 `AGENTS.md` 和治理日志，无需额外配置

### 5.3 从纯 Claude Code 迁移到双平台

1. 安装 Cursor 插件（全局）
2. 两平台共享 `AGENTS.md` 和治理日志

## 六、已知限制

| 限制 | 影响 | 计划 |
|------|------|------|
| Windows only | 不支持 macOS / Linux | 后续版本 |
| Claude Code 无原生 .mdc 支持 | 规则无法按 glob 自动激活 | 通过 AGENTS.md 和 settings.json systemPrompt 注入 |
| Claude Code 子代理 model/color 字段 | 部分字段仅 Claude Code 支持 | 对 Cursor 无影响 |
| 双平台并行 Hook 日志 | 同一项目的两平台日志写入同一文件 | 通过 ts 字段区分 |

## 七、常见问题

### Q: 两个平台能同时用吗？

可以。Cursor 的 Hook 是全局用户级，Claude Code 的 Hook 是项目级，互不干扰。两平台的治理日志写入同一目录，`/report` 能统计两边事件。

### Q: 哪个平台的治理能力更强？

治理能力等价。差异仅在平台适配格式上（命令 frontmatter、Hook 配置方式等），核心治理逻辑完全一致。

### Q: 需要为两个平台分别维护规则吗？

不需要。规则只在 `src/rules/` 中维护一份，安装时按平台格式生成。

### Q: 切换到 Claude Code 后 Cursor 还能用吗？

能。两平台安装互不影响，可以随时切换使用。

### Q: 状态目录迁移是强制的吗？

不强制。`common.ps1` 优先使用 `.exoskeleton/`，找不到时自动 fallback 到 `.cursor/`。旧项目的治理数据不会丢失。