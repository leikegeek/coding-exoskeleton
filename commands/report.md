# /report — 查看 Harness 统计报告

当用户输入 `/report` 时，解析 Harness 审计日志并展示统计信息。

## 数据来源

- `.cursor/hooks/logs/harness-events.jsonl` — Hooks 记录的结构化事件日志
- `.cursor/hooks/logs/edit-audit.log` — 文件编辑审计日志

## 执行流程

1. 执行 `harness-report.ps1` 脚本（插件 hooks 目录下），获取 JSON 格式的统计数据：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\plugins\local\coding-exoskeleton\hooks\harness-report.ps1" -Project "<项目根目录>" -Days 7 -OutputJson
```

2. 将 JSON 结果解析为结构化报告，按以下格式展示

### 运行态指标（核心）

| 指标 | 说明 | JSON 字段 |
|------|------|-----------|
| 总事件数 | 统计周期内所有 Hook 触发的事件总数 | `totalEvents` |
| 编辑操作 | 文件编辑事件数 | `edits` |
| 拦截次数 | deny + ask 事件数 | `denials` + `asks` |
| 模式切换 | 设计/编码模式切换次数 | `modeChanges` |
| 新任务 | 新任务契约建立次数 | `newTasks` |

### 详细分布

#### 模式分布
- 设计模式占比 vs 编码模式占比（来自 `modeDistribution`）

#### Top 5 被拦截事件
- 被拒绝的命令及其出现次数（来自 `topDenied`）

#### Top 5 编辑分布
- 按 COLA 层级或文件类型分类的编辑分布（来自 `topEdited`）

### 输出格式

以 Markdown 表格形式直接在对话中展示。如果用户需要文件形式，保存到 `docs/harness-report-YYYYMMDD.md`。

用户可传入 `-Days` 参数调整统计周期（默认 7 天）。

## 无数据时

如果找不到日志文件或日志为空，提示：

> 未找到 Harness 事件日志。请确认 Hooks 已正确配置且有过 AI 交互记录。
