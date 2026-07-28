# coding-exoskeleton 项目画像

> 本项目是 exoskeleton V2 双平台架构的**开发仓库**，不是被治理的业务项目。AGENTS.md 由 exoskeleton 安装脚本在目标项目中生成。

## 技术栈

- 核心资产格式：Markdown（commands/agents/rules/skills）
- Hook 脚本：PowerShell 5.1+
- 平台适配：Cursor (`.cursor-plugin/`) + Claude Code (`.claude/`)
- 安装脚本：PowerShell

## 开发约束

本项目的 `src/rules/shared/` 中定义了治理规则，这些规则在**本项目自身开发中同样生效**。当前激活的规则：

### tool-call-budget（工具调用预算 — 最高优先级）

单次响应中 tool_calls 总数**不得超过 64 个**，这是硬门禁：

- 并行 Read 不超过 5 个文件
- 并行 Agent/Task 启动不超过 2 个
- 超过预算时主动分 2-3 轮执行，不要试图在一次响应中塞入所有操作
- 分批优先级：核心文件 → 补充材料 → 写入/子代理
- 禁止为了省预算而跳过必读文件

关键检查点：子代理派发前、审计上下文收集时、验证循环入口、代码审计执行时。

### coding-discipline（编码纪律）

- 最小实现、精准变更、假设透明
- 每行变更都可溯源

### subagent-orchestration（子代理编排）

- 上下文收窄协议、工具调用预算、串行派发
- 上下文准备时分批读取，不一次性塞给子代理

### context-compaction（上下文压缩）

- 阶段切换时评估压缩时机
- B1→B2 是最重要的压缩点

### performance（性能守护）

- 性能问题必须有证据来源

## 关键路径

- `src/` — 统一核心资产（权威源，唯一修改点）
- `platforms/` — 平台适配层（从 src 生成）
- `docs/` — 平台中立化文档