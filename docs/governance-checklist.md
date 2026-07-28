# Exoskeleton 治理基线检查清单

用于在 `/start`、`/code`、`/audit`、`/performance` 和交付前做快速一致性检查，确保流程、约束、产物和审计都处于可控状态。

## A. 会话启动检查（必检）

- [ ] 当前任务已声明 `SV-ID`（如 `SV-34577`）
- [ ] 当前模式已明确：设计模式 / 编码模式
- [ ] 项目根目录存在 `AGENTS.md`
- [ ] `.exoskeleton/harness-config.json` 存在且 `techStack` 正确（历史项目可兼容读取 `.cursor/harness-config.json`）
- [ ] 目标项目已安装 Hooks（至少 Standard 档位）
- [ ] 如团队要求作者注释，个人作者配置已位于 `~/.exoskeleton/user-config.json`（legacy `~/.cursor/coding-exoskeleton/user-config.json` 仅兼容读取），未写入业务仓库

## B. 规则与技能激活检查

- [ ] `AGENTS.md` 的 `techStack` 与当前项目一致
- [ ] 技术栈专项 skills 仅在匹配时触发（不匹配时应跳过）
- [ ] 技术栈专项 rules 通过 `globs` 限定作用范围，正文包含 `techStack` 跳过声明
- [ ] V5 规范验证只纳入 `rules/shared/*` + 当前 family-common + 当前 profile，未跨栈套用
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
- [ ] V2 单测审视：`unit-test-reviewer` 已独立检查测试是否覆盖需求文档、技术设计文档和生产逻辑，且无 Critical
- [ ] V2 连续失败升级：同一测试点若两次未通过，已停止自行降标准修复，并向用户反馈两次失败摘要、关联需求/设计依据和可能原因
- [ ] V3 性能验证：无当前 family-common/profile 规则定义的 Critical 性能问题
- [ ] V4 统一审计：`audit-context-intake` 已生成 `AuditContext`，`audit-reviewer` 已输出问题、Git 规范检查、注释/删除代码检查和评分，且无未解决 Critical
- [ ] V5 规范验证：lint / checkstyle 通过，架构分层合规
- [ ] 机器状态文件 `docs/delivery/.state/SV-xxxxx-verification.json` 已持久化（用于断点续验，不作为正式交付文档）
- [ ] 机器状态只记录结构化状态、失败摘要、修复动作、重验计划和日志引用，未粘贴大段原始日志
- [ ] 验证循环综合评判为 PASS（所有维度 ✅ 或 ⚠️）

## F. 交付物检查（/code B4 阶段）

- [ ] 技术方案文档存在且与 `SV-ID` 一致
- [ ] 变更清单 `docs/delivery/SV-xxxxx-changelist.md` 已增量维护并定稿
- [ ] 代码评审报告 `docs/delivery/SV-xxxxx-review-report.md` 已产出
- [ ] 技术参考文档 `docs/delivery/SV-xxxxx-tech-ref.md` 已产出
- [ ] 代码评审报告已包含 V1-V5 验证摘要、统一审计结论、Git 规范检查、注释/删除代码检查、评分和交付判定
- [ ] 统一审计已检查方案 / 变更清单 / git diff 的一致性，且无未闭环 Critical
- [ ] `doc-updater` 已检查三类正式交付文档，且无未闭环 Critical
- [ ] 三类正式交付文档分工明确，无大量重复：变更清单=文件事实，技术参考=测试验证，评审报告=问题/验证/统一审计结论
- [ ] 实施进度段落已更新为"已交付"状态

## G. 子代理执行检查

- [ ] 专职子代理在对应阶段被正确触发（architect / tdd-guide / build-error-resolver / unit-test-reviewer / audit-reviewer / doc-updater）
- [ ] 子代理接收的上下文经过收窄，仅包含必要信息
- [ ] 审查类子代理返回结果符合各自格式要求；`audit-reviewer` 使用 8 段式审计报告，其他审查类子代理使用三段式结构
- [ ] `coding-subagent` 仅在分配的业务边界和允许写入路径内改代码，不直接写主流程交付文档
- [ ] 子代理产出已被主 Agent 整合到流程中

## H. 独立审计检查（/audit）

- [ ] `/audit` 已建立只读任务契约，允许写入路径仅限 `docs/audit/`
- [ ] 审计对象已明确：GitLab MR、commit、commit SHA 或本地 diff 范围
- [ ] 已优先使用本地 Git 获取真实 diff 和变更文件完整上下文；GitLab MR 元信息只作为业务上下文增强
- [ ] `audit-context-intake` 已生成 `AuditContext`，并标明 `auditMode = gitlab-mr` 或本地审计模式
- [ ] `evidenceLevel` 已按业务资料可信度标注为 high / medium / low，低可信推断未写成确定需求
- [ ] `audit-reviewer` 已输出 8 段式统一审计报告，包含注释/删除代码检查、Git 规范检查和评分
- [ ] 独立审计报告已保存到 `docs/audit/*-audit-report.md`，未生成 `/code` 交付三件套
- [ ] 未在用户明确要求修复前修改业务代码、创建分支、提交 commit 或向远端写入评论

## I. 独立性能分析检查（/performance）

- [ ] `/performance` 已建立只读任务契约，默认不写入业务代码
- [ ] 分析对象已明确：项目整体、指定模块、接口、页面、操作路径或本地 diff
- [ ] 已读取 `performance-analysis`，并按 `AGENTS.md.techStack` 叠加当前 family-common/profile 性能 skill
- [ ] 已给出分析对象、证据与基线、瓶颈判断、优化优先级、验证方式和回滚策略
- [ ] 无证据时仅输出排查计划和待采集指标，未伪装成确定瓶颈结论
- [ ] 高风险结构调整、压测外部服务、批量请求或可能影响环境稳定性的动作已先获得用户明确确认

## J. Hook 失败策略矩阵

以下列出各 Hook 在异常（脚本错误、解析失败等）时的行为策略，团队需对此知情：

| Hook | 正常拦截行为 | 异常时策略 | 风险等级 | 说明 |
|------|------------|-----------|---------|------|
| `before-shell-execution` | deny / ask / allow | **ask + exit 0**（fail-open） | 中 | 异常时降级为人工确认，不会静默放行也不会阻断 |
| `pre-tool-use`（Full 档位） | deny / allow | **allow + exit 0**（fail-open） | 高 | 异常时静默放行，依赖后续审计发现；白名单未配置时也全部放行 |
| `after-file-edit` | 仅审计记录 | 不拦截（审计 Hook） | 低 | 审计 Hook，无阻断能力，异常仅导致审计日志缺失 |
| `before-submit-prompt-lite` | 模式解析 + 事件记录 | 不拦截（记录 Hook） | 低 | 解析/记录 Hook，异常仅导致模式状态不更新 |
| `before-submit-prompt`（Full） | ask（契约不完整时；交付/PR 意图下缺少核心交付物时） | 脚本级 `$ErrorActionPreference = "Stop"` | 中 | 无显式 catch，异常时依赖 PowerShell 默认行为（可能阻断）；artifact gate 仅 Full 档位生效 |

> **团队须知**：默认安装使用 `before-submit-prompt-lite`，只做模式记录，不是强门禁。若团队需要契约完整性和交付物齐套强约束，可将 hooks.json 中的 `before-submit-prompt-lite.ps1` 替换为 `before-submit-prompt.ps1`。`pre-tool-use` 和 `before-shell-execution` 在异常时选择 fail-open 策略以避免误阻断开发流程，安全敏感场景下建议定期检查 `harness-events.jsonl` 中是否存在异常放行记录。

## J. 可观测性与审计检查

- [ ] 治理事件日志持续记录（优先 `.exoskeleton/hooks/logs/`，兼容 `.cursor/hooks/logs/`）
- [ ] 可查看模式分布、拦截事件、编辑分布
- [ ] 可识别近期失败模式并触发规则/流程修正

## K. 每周治理复盘建议

- [ ] Top 被拦截命令是否需要补充培训或脚本护栏
- [ ] 变更清单遗漏率是否上升
- [ ] 一次通过率是否下降（验证循环/审查门禁）
- [ ] 验证循环平均迭代轮次是否上升（预期 ≤ 2）
- [ ] 是否需要扩展或收敛某类技术栈专项规范
