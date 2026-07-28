# Exoskeleton Claude Code 用户指南

> 适用版本：Exoskeleton V2.0.0+
> 受众：在 Claude Code CLI 中使用 Exoskeleton 治理框架的开发者

## 一、前置条件

- **操作系统**：Windows（PowerShell 5.1+）
- **Git**：已安装并可用
- **Claude Code CLI**：已安装并可用（`claude` 命令可执行）
- **业务项目**：一个已初始化的 Git 仓库

## 二、安装（项目级）

Exoskeleton V2 的 Claude Code 安装是**项目级**的——每个需要使用治理框架的业务项目都需要分别安装。

### 2.1 克隆 Exoskeleton 仓库

```powershell
git clone https://github.com/leikegeek/coding-exoskeleton.git
cd .\coding-exoskeleton
```

### 2.2 在目标项目中安装

```powershell
.\platforms\claude\install-claude.ps1 -ProjectRoot "C:\path\to\your-project"
```

参数说明：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-ProjectRoot` | 目标业务项目根目录 | 当前目录 |
| `-SourceRoot` | Exoskeleton 仓库根目录 | 自动推断 |
| `-Force` | 覆盖已存在的生成文件 | 不覆盖 |

### 2.3 验证安装

```powershell
.\platforms\claude\verify-claude.ps1 -ProjectRoot "C:\path\to\your-project"
```

验证通过后会列出所有已生成的文件清单。

### 2.4 安装后目录结构

安装完成后，业务项目中会产生如下结构：

```
your-project/
├── CLAUDE.md                           # Claude Code 导航入口（指向 AGENTS.md）
├── AGENTS.md                           # 项目画像权威文件（由 /init 生成）
└── .claude/
    ├── settings.json                   # Hook 配置（项目级）
    ├── commands/                       # 7 个斜杠命令
    │   ├── init.md
    │   ├── start.md
    │   ├── code.md
    │   ├── audit.md
    │   ├── performance.md
    │   ├── deliver.md
    │   └── report.md
    ├── agents/                         # 10 个专职子代理
    │   └── *.md
    ├── skills/                         # 分层技能
    │   ├── shared/
    │   └── ...
    ├── hooks/                          # Hook 脚本
    │   ├── common.ps1
    │   ├── claude-pre-tool-use.ps1
    │   ├── claude-user-prompt-submit.ps1
    │   └── claude-post-tool-use.ps1
    └── exoskeleton-skill-index.md      # 技能索引
```

## 三、项目初始化

进入业务项目目录，启动 Claude Code：

```powershell
cd C:\path\to\your-project
claude
```

在 Claude Code 对话中输入 `/init` 启动项目画像生成流程。Exoskeleton 会分析项目技术栈、架构模式和模块结构，生成 `AGENTS.md`。

## 四、命令速查

| 命令 | 作用 | 示例 |
|------|------|------|
| `/init` | 初始化项目画像 | `/init` |
| `/start` | 流水线 A：需求→技术方案 | `/start SV-34577 需求描述` |
| `/code` | 流水线 B：技术方案→编码→交付 | `/code SV-34577 @docs/design/SV-34577-tech-design.md` |
| `/audit` | 独立代码审计 | `/audit` + PR/MR 链接或本地 diff |
| `/performance` | 独立性能分析 | `/performance` + 场景描述或本地 diff |
| `/deliver` | 交付文档检查 | `/deliver` |
| `/report` | 治理事件统计报告 | `/report` |

## 五、治理能力

### 5.1 三层治理模型

| 层级 | 说明 | Claude Code 实现 |
|------|------|-----------------|
| Skills | 能力指导层 | `.claude/skills/` 目录 |
| Rules | 规范约束层 | `CLAUDE.md` + `AGENTS.md` 中引用 |
| Hooks | 行为拦截层 | `.claude/settings.json` 中配置（由安装器生成） |

### 5.2 Hook 事件映射

| 治理能力 | Claude Code 事件 | Hook 脚本 |
|---------|-----------------|-----------|
| 危险命令拦截 | `PreToolUse`（Bash/PowerShell） | `claude-pre-tool-use.ps1` |
| 路径门禁 | `PreToolUse`（Write/Edit） | `claude-pre-tool-use.ps1` |
| 模式识别 | `UserPromptSubmit` | `claude-user-prompt-submit.ps1` |
| 编辑审计 | `PostToolUse`（Write/Edit） | `claude-post-tool-use.ps1` |

### 5.3 子代理委派

Claude Code 子代理通过 `.claude/agents/` 目录定义，主 Agent 按流水线阶段自动委派：

| 子代理 | 绑定阶段 | 触发条件 |
|--------|---------|---------|
| architect | A2 方案设计 | 新增模块/引入新技术/跨模块变更 |
| coding-subagent | B2 编码 | 编码任务分组数 ≥ 2 |
| tdd-guide | B2 编码 | 每个任务 commit 后 |
| build-error-resolver | B3 V1 构建 | V1 构建失败 |
| unit-test-reviewer | B3 V2 测试 | 每次测试执行后 |
| audit-reviewer | B3 V4 / `/audit` | 审计上下文就绪 |
| doc-updater | B4 交付 | B3 通过后 |

## 六、与 Cursor 版的差异

| 方面 | Cursor | Claude Code |
|------|--------|------------|
| 安装范围 | 全局（用户级 `~/.cursor/`） | 项目级（`.claude/`） |
| Hook 配置 | `~/.cursor/hooks.json` | `.claude/settings.json` |
| Hook 输入 | 命令行参数 | stdin JSON |
| Hook 阻断 | `exit 2` + stderr | stdout JSON `{decision: "block"}` 或 `exit 2` + stderr |
| 命令格式 | 无 frontmatter | 含 description、argument-hint、allowed-tools frontmatter |
| 子代理格式 | 通过 Task 工具调用 | agents 目录 + frontmatter（name, description, tools） |
| 规则格式 | `.mdc` + alwaysApply/globs | `CLAUDE.md` 中引用或 settings.json systemPrompt 注入 |
| 项目画像 | `AGENTS.md` | `CLAUDE.md` → `AGENTS.md`（导航） |

详细兼容性说明见 `docs/claude-code-compatibility.md`。

## 七、故障排查

### 7.1 Hook 脚本报错 "common.ps1 not found"

确认 `.claude/hooks/common.ps1` 已存在。如果缺失，重新执行 `install-claude.ps1`。

### 7.2 settings.json 中 hook command 路径无效

确保 `.claude/settings.json` 中的 hook command 使用 Windows 路径分隔符（反斜杠），且 PowerShell 脚本路径相对项目根目录。

### 7.3 子代理未自动委派

检查 `.claude/agents/` 目录下对应子代理的 `.md` 文件是否存在，以及 frontmatter 中的 `name` 字段是否正确。

### 7.4 命令未识别

确认 `.claude/commands/` 目录存在且包含 7 个命令文件。重新运行 `install-claude.ps1 -Force`。

## 八、卸载

Claude Code 安装是项目级的，卸载只需删除目标项目中的生成文件：

```powershell
Remove-Item -Recurse -Force "C:\path\to\your-project\.claude"
Remove-Item -Force "C:\path\to\your-project\CLAUDE.md"
```

注意：`AGENTS.md` 是项目画像文件，包含项目技术栈和架构信息，**不要删除**。如果不再需要 Exoskeleton 治理，可以保留 `AGENTS.md` 作为项目文档。