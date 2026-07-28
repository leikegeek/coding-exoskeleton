---
description: 执行独立代码审计或本地分支审计
argument-hint: [MR/commit URL | --local base...head] [--depth quick|standard|deep]
allowed-tools: Read, Write, Glob, Grep, Bash, PowerShell, Agent
---
# /audit — 独立代码审计入口

当用户输入 `/audit` 时，启动独立代码审计流程。该入口用于审计外部 PR/MR 或本地分支，不进入 `/code` 编码交付流程。

## 触发方式

- `/audit <gitlab-mr-url>` — 审计 GitLab Merge Request
- `/audit <gitlab-commit-url>` — 审计 GitLab commit 对应变更
- `/audit <gitlab-mr-url> --depth quick` — 只审 Critical 阻断风险
- `/audit <gitlab-mr-url> --depth standard` — 默认审计深度
- `/audit <gitlab-mr-url> --depth deep` — 强化业务、权限、数据和兼容性审计
- `/audit --local <baseRef>...<headRef>` — 审计本地分支 diff

## 定位

`/audit` 与 `/code` B3 共用同一个审计内核：

```text
/code B3
  → 本地流程产物接入
  → audit-context-intake 归一化 AuditContext
  → audit-reviewer 统一审计
  → 可修复、可重验、进入交付文档

/audit
  → Git 可获取变更或 PR/MR 接入
  → audit-context-intake 归一化 AuditContext
  → audit-reviewer 统一审计
  → 默认只读，输出独立审计报告
```

入口差异只体现在信息获取、可信度和输出形态；审计标准统一由 `agents/audit-reviewer.md` 定义。

## 预检步骤

### 1. 项目画像检查

检查当前项目是否存在 `AGENTS.md`：

- 存在：读取技术栈、架构模式、规则激活范围。
- 不存在：不强制初始化，但应提示审计会缺少项目特有规则；用户可选择先执行 `/init`。

### 2. 建立任务契约

- 模式：设计模式 / 只读审计
- 目标：对指定 PR/MR 或 diff 进行代码审计
- 允许写入路径：`docs/audit/`
- 禁止项：不修改业务代码、不创建分支、不提交 commit、不合并分支、不向远端写入评论（除非用户明确要求）
- 验收标准：输出审计结论、严重问题、改进建议、未验证项和需确认问题

## Git 优先的信息获取

### 信息优先级

`/audit` 的核心审计依据是本地 Git 能拿到的增量 diff 与当前工作区完整代码。GitLab MR 元信息用于增强业务上下文，但不是启动审计的硬依赖。

1. **本地 Git 仓库可访问远端**：优先通过 `git fetch`、`git diff`、`git show` 获取真实变更。
2. **当前工作区有完整代码**：读取变更涉及文件及其上下文，补足纯 diff 难以判断的调用链、配置和约束。
3. **本机 `glab` 已登录**：可额外获取 MR 标题、描述、comments、pipeline、源/目标分支。
4. **存在 `GITLAB_TOKEN` / `GLAB_TOKEN`**：可额外通过 GitLab REST API 获取授权范围内的 MR 信息。
5. **只有浏览器登录态**：不能直接复用浏览器 cookie；不阻断 Git 审计，只把 MR 元信息标记为未获取。

### Git 方式

当输入为 commit URL 或 commit SHA 时：

```bash
git fetch origin
git show --stat <commitSha>
git show --name-only <commitSha>
git show <commitSha>
```

当输入为本地分支范围时：

```bash
git fetch origin
git diff <baseRef>...<headRef>
```

当输入为 GitLab MR URL 且已知 MR IID 时，可尝试 GitLab 默认 ref：

```bash
git fetch origin merge-requests/<iid>/head:mr-<iid>
git diff origin/<target-branch>...mr-<iid>
```

若未知 `target-branch`，应提示用户补充，或根据当前仓库默认分支做低可信度审计假设并在报告中标明。

### glab 方式

如果 `glab auth status` 显示已登录，可增强获取：

```bash
glab mr view <iid> --repo <group/project> --json title,description,sourceBranch,targetBranch,author,labels,state,commits,notes,pipeline
```

### REST API 方式

当存在只读 token 时，按需调用：

```text
GET /projects/:id/merge_requests/:iid
GET /projects/:id/merge_requests/:iid/changes
GET /projects/:id/merge_requests/:iid/commits
GET /projects/:id/merge_requests/:iid/discussions
GET /projects/:id/merge_requests/:iid/pipelines
GET /projects/:id/issues/:iid
```

token 权限应控制为只读，禁止要求用户提供高权限 token。

## 执行流程

### A1: 接入审计对象

1. 解析 MR URL、commit URL、commit SHA 或本地 diff 范围。
2. 识别 GitLab host、project path、MR IID、commit SHA、baseRef、headRef。
3. 判断审计深度，默认 `standard`。
4. 若无法访问私有 MR 元信息，但 Git 能获取变更，则降级为 Git 审计并标记 MR 元信息未验证；只有 Git 与 API 都无法获取变更时才停止。

### A2: 收集上下文

读取 `audit-context-intake` skill，按 `gitlab-mr` 或本地模式收集：

- Git diff / `git show` / 变更文件列表。
- 变更涉及文件的当前完整代码或关键上下文。
- 可获取时的 MR 标题、描述、作者、labels、源/目标分支。
- commit 列表。
- 可获取时的 discussions / review comments。
- 可获取时的 pipeline / job 状态。
- 可获取时的关联 issue 或需求编号。
- `AGENTS.md` 项目画像和当前激活规则。

### A3: 重建业务意图

按可信度从高到低提取业务依据：

1. 关联需求文档 / issue。
2. MR 描述中的目标、范围、验收点。
3. commit message。
4. 测试用例。
5. diff 与完整代码上下文反推。

必须在 `AuditContext` 中标注 `evidenceLevel`：

- `high`：有完整需求/issue 或明确技术方案。
- `medium`：MR 描述足以说明目标和主要验收点。
- `low`：只能从 commit、测试、diff 或代码上下文反推。

### A4: 统一审计

启动 `audit-reviewer` agent，传入归一化后的 `AuditContext`。审计维度、严重级别、评分和报告格式统一由 `agents/audit-reviewer.md` 定义；本入口不得另行定义一套审计标准。

### A5: 输出报告

保存独立审计报告：

```text
docs/audit/MR-<iid>-audit-report.md
```

若无法识别 MR IID，则使用：

```text
docs/audit/<日期>-audit-report.md
```

报告必须包含：

- 变更摘要、审计结论、证据可信度和未验证项。
- 注释或删除代码专项检查。
- 严重问题、改进建议、疑问与确认。
- 维度摘要、Git 规范检查、总结与评分。
- `gitlab-mr` 模式下可附加建议 MR 评论摘要。

## 门禁与约束

- `/audit` 默认只读，不修改业务代码。
- 缺少业务资料时，不得把 diff 反推结果伪装成确定需求。
- 对低可信度业务判断，优先输出 Question。
- 发现安全、数据、权限类确定问题时，即使业务资料不足，也可以判定 Critical。
- 只有用户明确要求“修复这个 MR/分支”时，才可另行建立编码模式任务契约并进入修复流程。

