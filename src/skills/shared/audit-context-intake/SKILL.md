---
name: audit-context-intake
displayName: 统一审计上下文接入
description: 将本地 /code 流程产物、Git 可获取变更或 GitLab Merge Request 链接归一化为统一 AuditContext，供 audit-reviewer 执行业务、质量、安全一体化审计。
triggers: ["代码审计", "PR审计", "MR审计", "/audit", "audit context"]
autoTrigger: true
version: '1.0.0'
---

# 统一审计上下文接入

## 定位

本 Skill 是审计入口的接入层，负责把不同来源的审计材料归一化为同一种 `AuditContext`。审计标准和问题判定不在本 Skill 中实现，而由 `agents/audit-reviewer.md` 统一负责。

## 支持入口

| 入口 | 模式 | 典型来源 | 是否允许修改代码 |
|------|------|----------|------------------|
| `/code` B3 | `local-flow` | 技术方案、变更清单、本地 diff、构建/测试/lint 结果 | 允许在 Critical 后按 `/code` 修复流程修改 |
| `/audit <gitlab-mr-url>` | `gitlab-mr` | 本地 Git diff、变更文件完整代码、可选 GitLab MR 元信息 | 默认只读，不修改业务代码 |

## 标准输出：AuditContext

主 Agent 调用 `audit-reviewer` 前，必须整理出以下结构化输入：

```markdown
# AuditContext

## 1. 元信息
- auditMode: local-flow / gitlab-mr
- auditDepth: quick / standard / deep
- requirementId: SV-xxxxx / 无 / 从 MR 推断
- repository:
- baseRef:
- headRef:
- sourceUrl: 本地分支 / GitLab MR URL / GitLab commit URL

## 2. 业务上下文
- primaryBusinessSource: 技术方案 / 需求文档 / 关联 issue / MR 描述 / commit message / diff 与代码上下文反推
- evidenceLevel: high / medium / low
- businessSummary:
- acceptanceCriteria:
- openBusinessQuestions:

## 3. 变更上下文
- changedFiles:
- diffSummary:
- fullDiffRef: diff 文件路径 / git 命令引用 / API 结果引用
- highRiskFiles:

## 4. 测试与验证上下文
- buildStatus:
- testStatus:
- lintStatus:
- pipelineStatus:
- testDiffSummary:
- unverifiedItems:

## 5. 项目与规则上下文
- techStack:
- architectureSummary:
- activeRules: shared + 当前 family-common + 当前 profile
- projectConventions:

## 6. 安全上下文
- changedInterfaces:
- authzChanges:
- dataSensitivity:
- configOrDependencyChanges:
- securityUnknowns:

## 7. Git 规范上下文
- commitGraphSummary:
- mergeCommits:
- sourceBranch:
- targetBranch:
- testBranchMergeEvidence:

## 8. 注释与删除代码线索
- commentedOutCode:
- deletedBusinessLogic:
```

## local-flow 接入规则

> **上下文分批**：收集 AuditContext 的 8 个段落时，如果涉及大量变更文件，优先收集变更摘要（段落 3），再收集业务上下文（段落 2），其他段落按需收集。完整上下文可跨多轮逐步补齐；具体工具调用上限遵循当前平台适配层约束。

用于 `/code` B3：

1. 读取 `docs/design/SV-xxxxx-tech-design.md` 作为主业务依据。
2. 读取 `docs/delivery/SV-xxxxx-changelist.md` 作为开发者变更说明。
3. 使用 `git diff <baseRef>...HEAD` 获取实际变更。
4. 汇总 V1-V5 中已经执行的构建、测试、性能、规范结果；尚未执行的维度必须标注为"未验证"，不得写成 PASS。
5. `evidenceLevel` 默认设为 `high`；若技术方案缺失或只存在 draft，则降为 `medium` 或 `low` 并说明原因。

## gitlab-mr 接入规则

用于 `/audit <gitlab-mr-url>` 或 GitLab commit URL：

1. 解析 MR URL、commit URL 或 commit SHA，获得 GitLab host、project path、MR IID 或 commit SHA。
2. 优先使用本地 Git 获取真实变更：
   - commit URL / SHA：执行 `git fetch origin` 后使用 `git show --stat <sha>`、`git show --name-only <sha>`、`git show <sha>`。
   - 本地 ref 范围：执行 `git diff <baseRef>...<headRef>`。
   - MR IID：可尝试 `git fetch origin merge-requests/<iid>/head:mr-<iid>` 后与目标分支 diff。
3. 读取变更涉及文件的当前完整代码或关键上下文，用于补足调用链、配置、权限和数据流判断。
4. 在 GitLab CLI 或 token 可用时，额外获取 MR 元信息：
   - `glab auth status` 可用时，使用 `glab` 拉取标题、描述、源/目标分支、comments、pipeline。
   - `GITLAB_TOKEN` / `GLAB_TOKEN` 可用时，使用 GitLab REST API。
   - 如果两者都不可用，不阻断 Git 审计；将 MR 元信息、comments、pipeline 标记为未验证。
5. 从 MR 描述、commit message、测试、diff 和完整代码上下文中提取业务意图：
   - 有关联需求/issue 且内容完整：`evidenceLevel = high`
   - MR 描述能说明目标和验收点：`evidenceLevel = medium`
   - 只能从 diff、commit 和代码上下文反推：`evidenceLevel = low`
6. 若无法确定 MR 的目标分支，应提示用户补充；如继续审计，必须在 `openBusinessQuestions` 中标注目标分支假设。
7. 汇总 Git 规范线索：
   - commit 列表、merge commit 摘要、源/目标分支名。
   - 是否存在 `test` 分支向功能分支合并的可疑证据。
   - 无法确认时只标注未知，不得推断为通过。
8. 汇总注释和删除代码线索：
   - diff 中新增的疑似功能代码注释。
   - diff 中删除的完整函数、类、权限校验、数据校验、异常处理、事务处理、配置或测试。

## GitLab 登录态边界

浏览器中的 GitLab 登录态不能被 Cursor Agent 或命令行直接复用。直接给 MR 链接能否拿到信息取决于以下条件：

- 公开仓库 / 公开 MR：通常可直接通过 URL 或 API 读取公开信息。
- 私有仓库且本地 Git 可访问远端：可通过 Git 获取 commit、分支和 diff，作为 `/audit` 的基础审计材料。
- 私有仓库且 `glab` 已登录：可通过 `glab` 额外读取 MR、comments、pipeline。
- 私有仓库且环境中有 `GITLAB_TOKEN` / `GLAB_TOKEN`：可通过 GitLab REST API 额外读取授权范围内的信息。
- 只有浏览器登录、无 CLI/token：Agent 不能自动使用浏览器 cookie；不阻断 Git 审计，但应提示用户 MR 元信息缺失。

禁止要求用户提供高权限 token。审计只需要只读权限：读取项目、仓库、MR、issue、pipeline 即可。

## 输出约束

- 本 Skill 只整理上下文，不直接下审计结论。
- 无法获取的信息必须进入 `unverifiedItems` 或 `openBusinessQuestions`。
- 对低可信度业务推断必须标注依据，不得把推断写成确定需求。
- Git 规范和注释/删除代码只收集证据，是否阻断由 `audit-reviewer` 判定。
- `/audit` 默认只读，不创建分支、不修改业务代码、不生成 `/code` 的交付三件套。
