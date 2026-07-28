# Exoskeleton V2 — 双平台架构设计文档

> 版本：2.0.0-dev  
> 分支：V2  
> 日期：2026-06-15  
> 状态：已完成

---

## 一、背景与目标

### 1.1 背景

`coding-exoskeleton` 当前以 Cursor 插件形态交付，通过 `commands/`、`skills/`、`rules/`、`agents/`、`hooks/` 提供 AI 编程治理能力。用户希望在保持 Cursor 兼容的前提下，增加对 **Claude Code CLI** 的支持。

### 1.2 目标

- **核心资产不分叉**：commands、skills、rules、agents、hooks 保持一份权威源
- **双平台交付**：安装时按平台格式（Cursor `.mdc` + `hooks.json` / Claude Code `.md` + `settings.json`）二次处理生成
- **不兼容旧版本**：V2 重新组织代码结构，不做向后兼容
- **首版边界**：Windows + PowerShell 5.1+ + Claude Code CLI 项目级配置

---

## 二、V2 代码组织结构

```
coding-exoskeleton/
├── src/                          # 统一核心资产（权威源）
│   ├── commands/                 # 7 个命令入口
│   │   ├── init.md
│   │   ├── start.md
│   │   ├── code.md
│   │   ├── audit.md
│   │   ├── performance.md
│   │   ├── deliver.md
│   │   └── report.md
│   ├── agents/                   # 10 个专职子代理定义
│   │   ├── architect.md
│   │   ├── audit-reviewer.md
│   │   ├── build-error-resolver.md
│   │   ├── code-reviewer.md
│   │   ├── coding-subagent.md
│   │   ├── design-reviewer.md
│   │   ├── doc-updater.md
│   │   ├── security-reviewer.md
│   │   ├── tdd-guide.md
│   │   └── unit-test-reviewer.md
│   ├── rules/                    # 分层规则（.mdc 格式）
│   │   ├── shared/               # 通用规则（所有技术栈生效）
│   │   ├── backend-common/       # 后端通用规则
│   │   ├── frontend-common/      # 前端通用规则
│   │   ├── cola-java/            # Java 技术栈规则
│   │   ├── frontend-vue3/        # Vue3 技术栈规则
│   │   └── frontend-react-umi/   # React Umi 技术栈规则
│   ├── skills/                   # 分层技能（SKILL.md 格式）
│   │   ├── shared/               # 通用技能
│   │   ├── backend-common/       # 后端通用技能
│   │   ├── frontend-common/      # 前端通用技能
│   │   ├── cola-java/            # Java 技能
│   │   ├── frontend-vue3/        # Vue3 技能
│   │   └── frontend-react-umi/   # React Umi 技能
│   ├── hooks/                    # 治理 Hook 脚本（PowerShell）
│   │   ├── common.ps1            # 公共函数库
│   │   ├── before-shell-execution.ps1
│   │   ├── before-submit-prompt-lite.ps1
│   │   ├── before-submit-prompt.ps1
│   │   ├── after-file-edit.ps1
│   │   ├── pre-tool-use.ps1
│   │   └── harness-report.ps1
│   └── profiles/                 # 技术栈 Profile 定义
│
├── platforms/                    # 平台适配层
│   ├── cursor/                   # Cursor 平台
│   │   ├── .cursor-plugin/
│   │   │   └── plugin.json
│   │   ├── hooks/                # Cursor 格式 Hook 脚本（从 src/hooks 适配）
│   │   │   └── *.ps1
│   │   ├── install.ps1           # Cursor 安装脚本
│   │   └── verify.ps1            # Cursor 校验脚本
│   │
│   └── claude/                   # Claude Code 平台
│       ├── commands/             # Claude Code 格式命令（从 src/commands 生成）
│       │   └── *.md
│       ├── agents/               # Claude Code 格式子代理（从 src/agents 生成）
│       │   └── *.md
│       ├── hooks/                # Claude Code 格式 Hook 适配器
│       │   ├── claude-pre-tool-use.ps1
│       │   ├── claude-user-prompt-submit.ps1
│       │   └── claude-post-tool-use.ps1
│       ├── templates/            # 安装模板
│       │   ├── settings.project.json
│       │   ├── CLAUDE.md
│       │   └── exoskeleton-skill-index.md
│       ├── install-claude.ps1    # Claude Code 安装脚本
│       └── verify-claude.ps1     # Claude Code 校验脚本
│
├── docs/                         # 文档（平台中立化）
│   ├── user-guide.md
│   ├── plugin-core-workflow.md
│   ├── governance-checklist.md
│   ├── operations-runbook.md
│   ├── profile-extension-template.md
│   ├── claude-code-guide.md              # 新增：Claude Code 用户指南
│   ├── claude-code-compatibility.md       # 新增：双平台兼容性说明1
│   └── v2-architecture.md                # 本文档
│
├── README.md
└── AGENTS.md                     # 项目画像（双平台共用）
```

---

## 三、核心设计原则

### 3.1 资产分层

```
┌─────────────────────────────────┐
│         src/  统一核心资产        │  ← 权威源，唯一修改点
│  commands / agents / rules      │
│  skills  / hooks  / profiles    │
└───────────────┬─────────────────┘
                │
        ┌───────┴───────┐
        │               │
┌───────┴──────┐ ┌──────┴───────┐
│  Cursor 平台  │ │ Claude Code  │  ← 安装时从 src 生成
│  .mdc 规则    │ │ .md 命令     │
│  hooks.json  │ │ settings.json│
└──────────────┘ └──────────────┘
```

### 3.2 不变原则

1. **src/ 是唯一修改点**：所有流程语义、规则内容、技能定义只在 src/ 修改
2. **平台层只做格式转换**：不包含业务逻辑，仅做平台格式适配
3. **安装脚本负责生成**：从 src/ 读取源文件，按目标平台格式写入
4. **AGENTS.md 是双平台唯一画像权威**：CLAUDE.md 只做导航入口

### 3.3 平台格式差异

| 资产类型 | Cursor 格式 | Claude Code 格式 |
|---------|------------|-----------------|
| 命令 | `platforms/cursor/` 生成的命令产物（无 frontmatter） | `.claude/commands/*.md`（含 description、argument-hint、allowed-tools frontmatter） |
| 子代理 | 通过 Task 工具调用的平台产物 | `.claude/agents/*.md`（含 name、description、tools、model、color frontmatter） |
| 规则 | `src/rules/**/*.mdc` 生成的 Cursor 规则产物（含 alwaysApply、globs frontmatter） | 无原生规则概念，通过 CLAUDE.md + settings.json 实现 |
| 技能 | `.cursor/skills/*/SKILL.md`（文件夹式） | `.claude/skills/<name>/SKILL.md`（相同的文件夹式结构） |
| Hooks | `~/.cursor/hooks.json`（全局用户级） | `.claude/settings.json`（项目级，events: PreToolUse、PostToolUse、UserPromptSubmit 等） |
| 项目画像 | `AGENTS.md` | `CLAUDE.md`（导航入口，指向 AGENTS.md） |

### 3.4 Hook 输出差异

| 平台 | 输入 | 输出（阻断） | 输出（允许） | 输出（询问） |
|------|------|------------|------------|------------|
| Cursor | 命令行参数 | `exit 2` + stderr | `exit 0` 或 JSON `{decision: "allow"}` | JSON `{decision: "ask", reason: "..."}` |
| Claude Code | stdin JSON | stderr + exit 2，或 stdout JSON `{decision: "block", reason: "..."}` | stdout JSON `{decision: "allow"}` | stdout JSON `{decision: "ask", reason: "..."}` |

---

## 四、实施阶段

### Phase 1 — 代码重组（已完成）

- [x] 创建 V2 分支
- [x] 建立 `src/` 目录结构
- [x] 复制所有核心资产到 `src/`（commands、agents、rules、skills、hooks）
- [x] 迁移 Cursor 平台文件到 `platforms/cursor/`（hooks、plugin.json、install.ps1、verify.ps1）
- [x] 清理旧顶层目录（commands/、agents/、rules/、skills/）
- [x] 清理旧 install.ps1、verify.ps1

### Phase 2 — Claude Code 最小安装骨架（已完成）

- [x] 新增 `platforms/claude/install-claude.ps1`
- [x] 新增 `platforms/claude/verify-claude.ps1`
- [x] 新增 `platforms/claude/templates/settings.project.json`
- [x] 新增 `platforms/claude/templates/CLAUDE.md`
- [x] 新增 `platforms/claude/templates/exoskeleton-skill-index.md`

### Phase 3 — Claude Code 命令与子代理包装（已完成）

- [x] 新增 `platforms/claude/commands/*.md`（7 个命令，含 Claude Code frontmatter）
- [x] 新增 `platforms/claude/agents/*.md`（10 个子代理，含 Claude Code frontmatter）
- [x] 平台中立化 `src/commands/code.md`（去除 "Task 工具"、"generalPurpose" 等 Cursor 绑定表述）
- [x] 平台中立化 `src/rules/shared/subagent-orchestration.mdc`

### Phase 4 — Claude Code Hooks Adapter（已完成）

- [x] 平台无关化 `src/hooks/common.ps1`（增加 Resolve-ProjectRoot、Resolve-HarnessDir、Claude hook response helpers）
- [x] 新增 `platforms/claude/hooks/claude-pre-tool-use.ps1`
- [x] 新增 `platforms/claude/hooks/claude-user-prompt-submit.ps1`
- [x] 新增 `platforms/claude/hooks/claude-post-tool-use.ps1`

### Phase 5 — 状态与报告兼容（已完成）

- [x] `src/hooks/common.ps1` 支持 `.exoskeleton/` 状态目录（优先）→ `.cursor/` fallback
- [x] `src/hooks/harness-report.ps1` 支持双平台日志统计

### Phase 6 — 文档平台中立化（已完成）

- [x] 新增 `docs/claude-code-guide.md`
- [x] 新增 `docs/claude-code-compatibility.md`
- [x] 新增 `docs/v2-architecture.md`（本文档）
- [x] 更新 `README.md`（增加 Claude Code 入口）
- [x] 更新 `docs/user-guide.md`
- [x] 更新 `docs/plugin-core-workflow.md`（平台中立表述）

---

## 五、关键设计决策

### 5.1 为什么 src/ 不直接放平台格式？

- 保持单一权威源，避免两个平台格式漂移
- 安装时按需生成，灵活适配不同平台版本
- 新增平台只需增加安装脚本，不改核心资产

### 5.2 为什么状态目录兼容 .cursor/ 而非直接迁移？

- 首版最小风险：不强制迁移已有用户的治理数据
- 后续通过 `.exoskeleton/` 统一，优先读取 `.exoskeleton/`，fallback `.cursor/`
- 双平台共用治理日志，`/report` 能统计两边事件

### 5.3 为什么首版只支持 Windows？

- 与当前 V1 约束一致，降低风险
- Hook 脚本全部基于 PowerShell 5.1+
- 跨平台支持另立阶段

### 5.4 为什么 Claude Code 用项目级安装？

- Claude Code CLI 的项目级 `.claude/` 目录是推荐做法
- 避免全局安装污染用户环境
- 与 Cursor 的全局 `~/.cursor/hooks.json` 模式互补

---

## 六、平台映射关系

### 6.1 命令映射

| 命令 | Cursor 路径 | Claude Code 路径 |
|------|-----------|-----------------|
| /init | `.cursor/commands/init.md` | `.claude/commands/init.md` |
| /start | `.cursor/commands/start.md` | `.claude/commands/start.md` |
| /code | `.cursor/commands/code.md` | `.claude/commands/code.md` |
| /audit | `.cursor/commands/audit.md` | `.claude/commands/audit.md` |
| /performance | `.cursor/commands/performance.md` | `.claude/commands/performance.md` |
| /deliver | `.cursor/commands/deliver.md` | `.claude/commands/deliver.md` |
| /report | `.cursor/commands/report.md` | `.claude/commands/report.md` |

### 6.2 子代理映射

| 子代理 | Cursor 调用方式 | Claude Code 调用方式 |
|--------|--------------|-------------------|
| architect | 主 Agent 读取 agents/architect.md + Task 工具 | 主 Agent 委派 .claude/agents/architect.md |
| audit-reviewer | 同上 | 同上 |
| build-error-resolver | 同上 | 同上 |
| coding-subagent | Task + generalPurpose | 委派 .claude/agents/coding-subagent.md |
| tdd-guide | 主 Agent 读取 agents/tdd-guide.md | 委派 .claude/agents/tdd-guide.md |
| unit-test-reviewer | 主 Agent 读取 + Task | 委派 .claude/agents/unit-test-reviewer.md |
| doc-updater | 主 Agent 读取 + Task | 委派 .claude/agents/doc-updater.md |

### 6.3 Hook 映射

| 治理能力 | Cursor 事件 | Claude Code 事件 |
|---------|-----------|-----------------|
| 危险命令拦截 | `beforeShellExecution` | `PreToolUse`（Bash/PowerShell） |
| 路径门禁 | `beforeShellExecution`（写工具） | `PreToolUse`（Write/Edit/MultiEdit） |
| 模式识别 | `beforeSubmitPrompt` | `UserPromptSubmit` |
| 编辑审计 | `afterFileEdit` | `PostToolUse`（写工具） |

### 6.4 规则映射

| Cursor | Claude Code |
|--------|------------|
| `.cursor/rules/shared/*.mdc` | `CLAUDE.md` 中引用，或通过 `settings.json` 的 `systemPrompt` 注入 |
| `.cursor/rules/{profile}/*.mdc` | 同上，按 `AGENTS.md` 的 `techStack` 动态激活 |

---

## 七、验收标准

- [x] Cursor 现有安装和使用方式完全不变
- [x] Claude Code 项目级安装后能使用 7 个 slash commands
- [x] Claude Code 能识别核心 subagents
- [x] Claude Code 下危险命令拦截、prompt 模式状态、文件编辑审计三类 hooks 可工作
- [x] `/report` 能展示 Claude Code 产生的治理日志
- [x] `AGENTS.md` 在 Cursor 和 Claude Code 间保持唯一项目画像权威
- [x] 文档清楚区分核心 Exoskeleton 流程与 Cursor/Claude Code 平台适配层

---

## 八、风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| Claude Code hooks schema 与预期不一致 | `hooks/adapters/` 隔离，核心策略不直接依赖平台 payload |
| 双平台 Markdown 漂移 | 核心资产保持一份（src/），平台侧只做 wrapper |
| 状态目录语义不清 | 首版兼容 `.cursor/`，文档说明历史原因，后续迁移 `.exoskeleton/` |
| 子代理触发机制差异 | 命令和规则中避免写死具体工具名，统一写"委派专职子代理" |
| Windows-only 限制 | 首版明确声明，跨平台支持另立阶段 |