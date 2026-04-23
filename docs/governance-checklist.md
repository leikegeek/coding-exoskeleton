# Exoskeleton 治理基线检查清单

用于在 `/start`、`/code`、交付前做快速一致性检查，确保流程、约束、产物和审计都处于可控状态。

## A. 会话启动检查（必检）

- [ ] 当前任务已声明 `SV-ID`（如 `SV-34577`）
- [ ] 当前模式已明确：设计模式 / 编码模式
- [ ] 项目根目录存在 `AGENTS.md`
- [ ] `.cursor/harness-config.json` 存在且 `techStack` 正确
- [ ] 目标项目已安装 Hooks（至少 Standard 档位）

## B. 规则与技能激活检查

- [ ] `AGENTS.md` 的 `techStack` 与当前项目一致
- [ ] 技术栈专项 skills 仅在匹配时触发（不匹配时应跳过）
- [ ] 技术栈专项 rules 通过 `globs` 限定作用范围
- [ ] 通用 rules（任务契约 / 工作模式 / 上下文压缩 / 子代理编排 / 性能）正常生效

## C. 过程门禁检查

- [ ] 设计模式下未执行构建/提交/改业务代码
- [ ] 编码模式下写入路径符合边界约束
- [ ] 关键动作前后有用户确认（模式切换、继续编码、交付）
- [ ] 危险命令（force push / drop table 等）可被拦截
- [ ] 阶段切换时触发了上下文压缩评估（`context-compaction` skill）

## D. 验证循环检查（/code B3 阶段）

- [ ] V1 构建验证：编译通过，无 ERROR 级输出
- [ ] V2 测试验证：全量单元测试通过，覆盖率不低于项目基线
- [ ] V3 性能验证：无 Critical 级性能问题（N+1、循环内 RPC 等）
- [ ] V4 对齐验证：变更记录 vs diff vs 技术方案三方一致
- [ ] V5 规范验证：lint / checkstyle 通过，架构分层合规
- [ ] 验证检查点文件 `docs/delivery/SV-xxxxx-verification.md` 已持久化
- [ ] 验证循环综合评判为 PASS（所有维度 ✅ 或 ⚠️）

## E. 交付物检查（/code B4 阶段）

- [ ] 技术方案文档存在且与 `SV-ID` 一致
- [ ] 变更清单 `docs/delivery/SV-xxxxx-changelist.md` 已增量维护并定稿
- [ ] 代码评审报告 `docs/delivery/SV-xxxxx-review-report.md` 已产出
- [ ] 技术参考文档 `docs/delivery/SV-xxxxx-tech-ref.md` 已产出
- [ ] 验证检查点 `docs/delivery/SV-xxxxx-verification.md` 已产出
- [ ] 三方对齐（方案 vs 变更清单 vs git diff）已通过
- [ ] 实施进度段落已更新为"已交付"状态

## F. 子代理执行检查

- [ ] 专职子代理在对应阶段被正确触发（architect / tdd-guide / build-error-resolver / security-reviewer / doc-updater）
- [ ] 子代理接收的上下文经过收窄，仅包含必要信息
- [ ] 子代理返回结果为三段式结构（结论 + 问题列表 + 建议）
- [ ] 子代理产出已被主 Agent 整合到流程中

## G. Hook 失败策略矩阵

以下列出各 Hook 在异常（脚本错误、解析失败等）时的行为策略，团队需对此知情：

| Hook | 正常拦截行为 | 异常时策略 | 风险等级 | 说明 |
|------|------------|-----------|---------|------|
| `before-shell-execution` | deny / ask / allow | **ask + exit 0**（fail-open） | 中 | 异常时降级为人工确认，不会静默放行也不会阻断 |
| `pre-tool-use`（Full 档位） | deny / allow | **allow + exit 0**（fail-open） | 高 | 异常时静默放行，依赖后续审计发现；白名单未配置时也全部放行 |
| `after-file-edit` | 仅审计记录 | 不拦截（审计 Hook） | 低 | 审计 Hook，无阻断能力，异常仅导致审计日志缺失 |
| `before-submit-prompt-lite` | 模式解析 + 事件记录 | 不拦截（记录 Hook） | 低 | 解析/记录 Hook，异常仅导致模式状态不更新 |
| `before-submit-prompt`（Full） | ask（契约不完整时） | 脚本级 `$ErrorActionPreference = "Stop"` | 中 | 无显式 catch，异常时依赖 PowerShell 默认行为（可能阻断） |

> **团队须知**：`pre-tool-use` 和 `before-shell-execution` 在异常时选择 fail-open 策略以避免误阻断开发流程。安全敏感场景下，建议定期检查 `harness-events.jsonl` 中是否存在异常放行记录。

## H. 可观测性与审计检查

- [ ] `.cursor/hooks/logs/harness-events.jsonl` 持续记录
- [ ] 可查看模式分布、拦截事件、编辑分布
- [ ] 可识别近期失败模式并触发规则/流程修正

## I. 每周治理复盘建议

- [ ] Top 被拦截命令是否需要补充培训或脚本护栏
- [ ] 变更清单遗漏率是否上升
- [ ] 一次通过率是否下降（验证循环/审查门禁）
- [ ] 验证循环平均迭代轮次是否上升（预期 ≤ 2）
- [ ] 是否需要扩展或收敛某类技术栈专项规范
