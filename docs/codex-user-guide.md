# Exoskeleton Codex 用户指南

> 受众：在 Codex CLI、IDE 扩展或 Codex app 中使用 Exoskeleton 治理框架的开发者。

## 一、安装前提

- Windows PowerShell 5.1+
- 已安装并可使用 Codex
- 已克隆 `coding-exoskeleton` 仓库
- 目标业务项目在本机可读写

## 二、项目级安装

在 Exoskeleton 仓库根目录执行：

```powershell
.\platforms\codex\install-codex.ps1 -ProjectRoot "C:\path\to\your-project"
.\platforms\codex\verify-codex.ps1 -ProjectRoot "C:\path\to\your-project"
```

安装器只写目标业务项目，不修改 `~/.codex/config.toml`。

安装后的主要产物：

```text
<project>/
├── .agents/
│   ├── skills/                 # Codex 可发现的 Exoskeleton skills
│   ├── references/
│   │   ├── commands/           # 平台中立 workflow 定义
│   │   ├── rules/              # 平台中立治理规则引用
│   │   └── agents/             # 平台中立 specialist agent 定义
│   └── plugins/marketplace.json
├── .codex/
│   ├── agents/                 # Codex custom agents
│   ├── hooks/                  # Codex hook adapters
│   ├── rules/                  # Codex command approval rules
│   └── hooks.json
└── plugins/coding-exoskeleton/   # repo-local Codex plugin bundle
```

安装后重启 Codex 或重新打开项目。首次启用项目 hooks 时，使用 `/hooks` 审查并信任 hook 定义。

## 三、入口映射

Codex 侧以技能为主入口，不依赖自定义 slash prompt。

| 原流程 | Codex 技能 |
| --- | --- |
| `/init` | `$exoskeleton-init` |
| `/start` | `$exoskeleton-start` |
| `/code` | `$exoskeleton-code` |
| `/audit` | `$exoskeleton-audit` |
| `/performance` | `$exoskeleton-performance` |
| `/deliver` | `$exoskeleton-deliver` |
| `/report` | `$exoskeleton-report` |

示例：

```text
$exoskeleton-start SV-34577 需求描述或需求文档
$exoskeleton-code SV-34577 @docs/design/SV-34577-tech-design.md
$exoskeleton-audit 当前分支相对 main 的 diff
$exoskeleton-performance 订单列表首屏慢
```

## 四、Codex 特有治理面

- `AGENTS.md`：项目画像和团队约定的权威入口。
- `.agents/skills`：工作流和专项技能，使用 Codex progressive disclosure 按需加载。
- `.codex/agents`：专职审查、编码、文档等 custom agents。
- `.codex/hooks.json`：项目级生命周期 hook，需在 `/hooks` 中审查信任。
- `.codex/rules`：稳定命令审批策略，例如阻断高风险 git 或删除命令。
- `.agents/plugins/marketplace.json`：将 Exoskeleton 作为 repo-local plugin 暴露给 Codex 插件目录。

## 五、验证与排障

结构校验：

```powershell
.\platforms\codex\verify-codex.ps1 -ProjectRoot "C:\path\to\your-project"
```

常见问题：

- 技能未出现：重启 Codex，确认 `.agents/skills/**/SKILL.md` 存在。
- hooks 未运行：执行 `/hooks`，确认项目 `.codex/hooks.json` 已被信任。
- custom agent 不可用：确认 `.codex/agents/*.toml` 存在；必要时重新运行安装器。
- plugin 未出现：确认 `.agents/plugins/marketplace.json` 和 `plugins/coding-exoskeleton/.codex-plugin/plugin.json` 存在，然后重启 Codex。
