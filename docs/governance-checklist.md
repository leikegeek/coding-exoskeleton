# Exoskeleton 治理基线检查清单

用于在 `/start`、`/code`、交付前做快速一致性检查，确保流程、约束、产物和审计都处于可控状态。

## A. 会话启动检查（必检）

- [ ] 当前任务已声明 `SV-ID`（如 `SV-34577`）
- [ ] 当前模式已明确：设计模式 / 编码模式
- [ ] 项目根目录存在 `AGENTS.md`
- [ ] `.cursor/harness-config.json` 存在且 `techStack` 正确
- [ ] 目标项目已安装 Hooks（至少 Standard 档位）
- [ ] 如团队要求作者注释，个人作者配置已位于 `~/.cursor/coding-exoskeleton/user-config.json`，未写入业务仓库

## B. 规则与技能激活检查

- [ ] `AGENTS.md` 的 `techStack` 与当前项目一致
- [ ] 技术栈专项 skills 仅在匹配时触发（不匹配时应跳过）
- [ ] 技术栈专项 rules 通过 `globs` 限定作用范围
- [ ] 通用 rules（任务契约 / 工作模式 / 上下文压缩 / 子代理编排 / 性能）正常生效

## C. 过程门禁检查

- [ ] 设计模式下未执行构建/提交/改业务代码
- [ ] 编码模式下写入路径符合边界约束
- [ ] 需求完整性门禁已通过，内部完整性清单已检查；只向用户确认了阻断性缺口
- [ ] 默认功能技术方案已包含 4 个核心部分：功能概述与边界、核心业务流程、代码实施位置、测试与验收；仅在用户明确要求架构设计方案时使用 8 部分架构模板
- [ ] 技术方案已包含业务核心流程图，并写明新增/修改代码的目录层次、模块、文件位置和参考实现
- [ ] 关键动作前后有用户确认（模式切换、继续编码、交付）
- [ ] 危险命令（force push / drop table 等）可被拦截
- [ ] 阶段切换时触发了上下文压缩评估（`context-compaction` skill）

## D. B2 编码记录门禁检查

- [ ] B1 已初始化 `docs/delivery/SV-xxxxx-changelist.md`
- [ ] 每个任务完成点均已记录变更文件、变更类型、功能说明、测试结果和 commit hash（无 commit 时记录原因）
- [ ] 编排模式下，每组子代理验收后已合并该组变更记录
- [ ] 技术方案文档「实施进度」已随任务/组完成同步更新
- [ ] 子代理返回的假设决策已审核；业务规则、数据口径、权限、安全、接口契约等关键缺口未被自行假设推进
- [ ] 子代理上下文只包含任务清单、方案摘录、项目摘要、接口契约和必要规则摘要，未传完整方案/完整 AGENTS/完整 diff
- [ ] 作者注释仅用于新增文件/类且读取自全局个人配置；未改写已有作者注释
- [ ] 进入 B3 前，`changelist.md` 已覆盖所有已知变更

## E. 验证循环检查（/code B3 阶段）

- [ ] V1 构建验证：编译通过，无 ERROR 级输出
- [ ] V2 测试验证：全量单元测试通过，覆盖率不低于项目基线
- [ ] V3 性能验证：无 Critical 级性能问题（N+1、循环内 RPC 等）
- [ ] V4 对齐验证：变更记录 vs diff vs 技术方案三方一致
- [ ] V5 规范验证：lint / checkstyle 通过，架构分层合规
- [ ] 机器状态文件 `docs/delivery/.state/SV-xxxxx-verification.json` 已持久化（用于断点续验，不作为正式交付文档）
- [ ] 机器状态只记录结构化状态、失败摘要、修复动作、重验计划和日志引用，未粘贴大段原始日志
- [ ] 验证循环综合评判为 PASS（所有维度 ✅ 或 ⚠️）

## F. 交付物检查（/code B4 阶段）

- [ ] 技术方案文档存在且与 `SV-ID` 一致
- [ ] 变更清单 `docs/delivery/SV-xxxxx-changelist.md` 已增量维护并定稿
- [ ] 代码评审报告 `docs/delivery/SV-xxxxx-review-report.md` 已产出
- [ ] 技术参考文档 `docs/delivery/SV-xxxxx-tech-ref.md` 已产出
- [ ] 代码评审报告已包含 V1-V5 验证摘要、安全审计结论和交付判定
- [ ] 三方对齐（方案 vs 变更清单 vs git diff）已通过
- [ ] `doc-updater` 已检查三类正式交付文档，且无未闭环 Critical
- [ ] 三类正式交付文档分工明确，无大量重复：变更清单=文件事实，技术参考=测试验证，评审报告=问题/验证/安全结论
- [ ] 实施进度段落已更新为"已交付"状态

## G. 子代理执行检查

- [ ] 专职子代理在对应阶段被正确触发（architect / tdd-guide / build-error-resolver / security-reviewer / doc-updater）
- [ ] 子代理接收的上下文经过收窄，仅包含必要信息
- [ ] 审查类子代理返回结果为三段式结构（结论 + 问题列表 + 建议）
- [ ] `coding-subagent` 仅在分配的业务边界和允许写入路径内改代码，不直接写主流程交付文档
- [ ] 子代理产出已被主 Agent 整合到流程中

## H. Hook 失败策略矩阵

以下列出各 Hook 在异常（脚本错误、解析失败等）时的行为策略，团队需对此知情：

| Hook | 正常拦截行为 | 异常时策略 | 风险等级 | 说明 |
|------|------------|-----------|---------|------|
| `before-shell-execution` | deny / ask / allow | **ask + exit 0**（fail-open） | 中 | 异常时降级为人工确认，不会静默放行也不会阻断 |
| `pre-tool-use`（Full 档位） | deny / allow | **allow + exit 0**（fail-open） | 高 | 异常时静默放行，依赖后续审计发现；白名单未配置时也全部放行 |
| `after-file-edit` | 仅审计记录 | 不拦截（审计 Hook） | 低 | 审计 Hook，无阻断能力，异常仅导致审计日志缺失 |
| `before-submit-prompt-lite` | 模式解析 + 事件记录 | 不拦截（记录 Hook） | 低 | 解析/记录 Hook，异常仅导致模式状态不更新 |
| `before-submit-prompt`（Full） | ask（契约不完整时；交付/PR 意图下缺少核心交付物时） | 脚本级 `$ErrorActionPreference = "Stop"` | 中 | 无显式 catch，异常时依赖 PowerShell 默认行为（可能阻断）；artifact gate 仅 Full 档位生效 |

> **团队须知**：默认安装使用 `before-submit-prompt-lite`，只做模式记录，不是强门禁。若团队需要契约完整性和交付物齐套强约束，可将 hooks.json 中的 `before-submit-prompt-lite.ps1` 替换为 `before-submit-prompt.ps1`。`pre-tool-use` 和 `before-shell-execution` 在异常时选择 fail-open 策略以避免误阻断开发流程，安全敏感场景下建议定期检查 `harness-events.jsonl` 中是否存在异常放行记录。

## I. 可观测性与审计检查

- [ ] `.cursor/hooks/logs/harness-events.jsonl` 持续记录
- [ ] 可查看模式分布、拦截事件、编辑分布
- [ ] 可识别近期失败模式并触发规则/流程修正

## J. 每周治理复盘建议

- [ ] Top 被拦截命令是否需要补充培训或脚本护栏
- [ ] 变更清单遗漏率是否上升
- [ ] 一次通过率是否下降（验证循环/审查门禁）
- [ ] 验证循环平均迭代轮次是否上升（预期 ≤ 2）
- [ ] 是否需要扩展或收敛某类技术栈专项规范
