---
name: verification-loop
displayName: 结构化验证循环
description: 将 B3 阶段组织为结构化验证循环，编排构建、测试、性能、统一审计、规范五个验证维度，支持增量重验、检查点保存和综合门禁评判。
triggers: ["验证循环", "代码验证", "B3审查", "verification loop", "全量验证"]
autoTrigger: true
version: '1.0.2'
---

# 结构化验证循环

## 定位

本 Skill 是 B3（验证与统一审计）阶段的**编排层**，不替换现有的 `testing` skill、`performance-analysis` skill、`audit-context-intake` skill 和 `audit-reviewer` agent，而是按结构化流程调用它们，统一收集结果，管理迭代循环，直到所有维度通过或达到最大迭代次数。

## 验证维度矩阵

每轮验证依次执行以下 5 个维度，每个维度产出三种状态之一：

| 维度 | 编号 | 检查内容 | 通过标准 | 调用的组件 |
|------|------|---------|---------|-----------|
| 构建验证 | V1 | 项目构建或类型检查通过、无阻断性错误 | 项目画像中的构建命令返回 0；无构建命令时先询问用户 | 直接执行项目构建命令 |
| 测试验证 | V2 | 项目测试通过，且单元测试由独立审视代理确认覆盖需求与生产逻辑 | 全部测试 PASS；覆盖率不低于项目基线或标注未配置；`unit-test-reviewer` 无 Critical | `testing` skill + `unit-test-reviewer` agent |
| 性能验证 | V3 | 无当前 family-common/profile 规则定义的 Critical 性能问题 | 无 Critical 级性能问题 | `performance-analysis` skill + 当前 family-common/profile 性能 skill/rules |
| 统一审计 | V4 | 基于 AuditContext 执行统一代码审计，审计维度和报告格式由 `audit-reviewer` 定义 | `audit-reviewer` 无未解决 Critical | `audit-context-intake` skill + `audit-reviewer` agent |
| 规范验证 | V5 | 项目 lint/格式/架构/命名等规范通过 | 无 ERROR 级违规 | 项目规范工具 + shared rules + 当前 family-common rules + 匹配 `techStack` 的 profile rules |

**状态定义**：

| 状态 | 含义 | 后续动作 |
|------|------|---------|
| ✅ 通过 | 该维度检查全部达标 | 无需重验 |
| ⚠️ 有警告 | 存在非阻断性问题（Warning / Info 级别） | 记录后可继续，需在报告中说明 |
| ❌ 未通过 | 存在阻断性问题（Critical / Error 级别） | 必须修复后重新验证该维度 |

## 执行流程

> **上下文分批**：V1-V5 循环中避免在同一轮同时做"读取文件 + 执行命令 + 启动子代理 + 更新状态"。如果 V2（启动 unit-test-reviewer）或 V4（audit-context-intake + audit-reviewer）的上下文材料较多，先按 `context-batching` 规则收窄，再委派或更新状态。

### 第一步：初始化验证上下文

1. 读取需求编号（SV-ID），确定机器状态文件路径：`docs/delivery/.state/SV-xxxxx-verification.json`
2. 检查是否存在未完成的验证状态（支持断点续验）：
   - **存在且未完成**：读取 JSON 状态，从上次中断的位置继续
   - **不存在**：创建新的 JSON 状态文件，初始化所有维度为"待验证"
3. 记录当前迭代轮次（初始为第 1 轮）

### 第二步：执行验证维度

按 V1 → V2 → V3 → V4 → V5 顺序依次执行。**如果是重验轮次，只执行状态为 ❌ 的维度，已通过的维度跳过。**

#### V1：构建验证

1. 执行项目构建命令（优先从 `AGENTS.md` 读取；未配置时根据技术栈推断或询问用户）
2. 判定结果：
   - 构建成功（exit code 0）且无 ERROR 输出 → ✅
   - 构建成功但有警告 → ⚠️，记录警告内容
   - 构建失败 → ❌，记录错误信息
3. 更新机器状态文件

#### V2：测试验证

1. 读取 `testing` skill
2. 执行测试命令（优先从 `AGENTS.md` 读取；未配置时根据技术栈推断或询问用户）
3. 测试命令执行后，必须启动独立子代理，并按 `agents/unit-test-reviewer.md` 的角色约束执行单元测试审视：
   - 输入材料必须包含需求文档或需求摘录、技术设计文档或设计摘录、生产代码 diff、测试代码 diff、测试执行结果和 `testing` skill 核心原则
   - 审视标准以需求和技术设计为准，不以“现有测试能通过”为准
   - 测试第一目标必须覆盖本次改动点，且必须验证生产逻辑；禁止只断言测试内自造增量、集合非空或恒真条件
   - 禁止通过降低断言强度、删除用例、跳过失败用例、过度 mock 核心逻辑来换取通过
4. 判定结果：
   - 测试命令全部通过，且 `unit-test-reviewer` 结论为通过 → ✅
   - 测试命令全部通过，但覆盖率低于基线或 `unit-test-reviewer` 仅返回 Warning → ⚠️，记录覆盖率数据和审视警告
   - 有失败用例、覆盖关键需求缺失、生产逻辑未被有效断言，或 `unit-test-reviewer` 返回 Critical → ❌，记录失败用例和审视问题
5. 连续失败升级：
   - 同一个测试点在两轮 V2 中连续未通过时，不得继续在本轮自行修复或降低标准
   - 必须将该测试点、两次失败摘要、关联需求/设计依据和可能原因反馈给用户查看，综合结果标记为 BLOCKED 或 FAIL（视是否达到最大迭代次数）
6. 更新机器状态文件

#### V3：性能验证

1. 读取 `performance-analysis` skill
2. 对本次变更涉及的代码执行性能扫描
3. 判定结果：
   - 无性能问题 → ✅
   - 仅有 Warning 级建议 → ⚠️，记录建议列表
   - 存在 Critical 级问题（如当前 family-common/profile 规则定义的后端循环远程调用、前端重复渲染/请求等） → ❌，记录问题详情
4. 更新机器状态文件

#### V4：统一审计

1. 读取 `audit-context-intake` skill，归一化本地流程产物：
   - 变更记录文档：`docs/delivery/SV-xxxxx-changelist.md`
   - git diff：`git diff main...HEAD`
   - 技术方案文档：`docs/design/SV-xxxxx-tech-design.md`
   - V1-V5 已执行结果、测试审视结果、性能扫描摘要和规范验证摘要
   - `AGENTS.md` 中的技术栈、架构模式和当前激活规则
2. 生成 `auditMode = local-flow` 的 `AuditContext`
3. 启动 `audit-reviewer` agent 执行统一代码审计；具体维度、Git 规范检查、注释/删除代码检查、评分和报告格式以 `agents/audit-reviewer.md` 为准
4. 判定结果：
   - 无 Critical，且审计结论为通过 → ✅
   - 仅存在 Warning / Info / Question，且不影响交付 → ⚠️
   - 存在 Critical 级问题，或发现 `test` 分支向功能分支合并代码 → ❌
5. 更新机器状态文件

#### V5：规范验证

1. 执行项目 lint、格式、checkstyle 或类型检查命令（优先从 `AGENTS.md` 读取；未配置时根据技术栈推断或询问用户）
2. 对照适用规则检查：`rules/shared/*` + 当前 family-common 规则 + 当前 `techStack` 对应的 profile 规则；禁止把其它技术栈规则纳入本项目判定
3. 判定结果：
   - 无违规 → ✅
   - 仅 Warning 级违规 → ⚠️，记录违规项
   - ERROR 级违规 → ❌，记录违规详情
4. 更新机器状态文件

### 第三步：迭代判定

所有维度执行完毕后，汇总结果：

**情况 A — 全部通过**：所有维度状态为 ✅ 或 ⚠️ → 进入第四步（综合评判）

**情况 B — 存在失败维度**：
1. 检查当前迭代轮次是否已达上限（默认 3 次）
   - **未达上限**：进入修复流程
   - **已达上限**：标记综合结果为 FAIL，进入第四步

**修复流程**：
1. 汇总所有 ❌ 维度的问题清单，按严重程度排序
2. 向用户展示问题摘要，确认修复方向
3. 执行修复（遵循 `coding` skill 的编码规范）
4. 修复完成后，迭代轮次 +1，回到第二步（仅重验 ❌ 维度）

### 第四步：综合评判与门禁

| 综合结果 | 条件 | 后续动作 |
|----------|------|---------|
| **PASS** | 所有维度 ✅ 或 ⚠️（Warning / Question 已在报告中记录，且无未解决 Critical） | 可进入 B4 交付文档齐套检查 |
| **FAIL** | 任何维度 ❌ 且已达最大迭代次数 | 阻断，需人工介入 |
| **BLOCKED** | 依赖条件不满足（如构建环境异常、Subagent 结果未汇总） | 阻断，需排除障碍后重试 |

> **安全审计已并入 V4 统一审计**：V4 由 `audit-reviewer` 一次性覆盖统一代码审计维度，不再在 V1-V5 之后额外串联 `security-reviewer`。若存在未闭环 Critical，V4 必须判定为 ❌，不得进入 B4。

FAIL 时的处理：
1. 输出完整的验证报告，包含每轮迭代的问题和修复记录
2. 明确告知用户哪些维度未通过、已尝试的修复措施
3. 建议人工介入的方向

### 第五步：产出验证状态与正式交付摘要

验证循环结束后（无论 PASS 还是 FAIL），产出以下内容：

1. **机器状态文件**（`docs/delivery/.state/SV-xxxxx-verification.json`）：保存 V1-V5 当前状态、迭代轮次、失败摘要、修复动作、日志引用和下一轮重验计划，供 Agent 断点续验使用。该文件**不是正式交付文档**，不进入 B4 交付展示。
2. **代码评审报告**（`docs/delivery/SV-xxxxx-review-report.md`）：整合统一审计结论、注释/删除代码检查、严重问题、改进建议、疑问与确认、Git 规范检查、评分、V1-V5 最终验证摘要、Critical 闭环状态和交付判定，作为人类阅读的质量结论文档。
3. **变更清单定稿**：对 B2 阶段积累的变更记录做最终校验和格式化。
4. **技术参考文档**（`docs/delivery/SV-xxxxx-tech-ref.md`）：从变更记录和审查结果中提炼。

正式交付文档必须保持摘要化：不复制完整命令输出、完整 diff 或完整测试日志；只记录结论、阻断问题、修复动作、剩余风险和必要的日志引用。机器状态文件保存结构化字段，不写叙述性长文。

## 交付文档齐套门禁

当综合结果为 PASS 时，进入 B4 前必须确认以下三类**正式交付文档**全部存在且需求编号一致：

| 交付物 | 路径 | 最低要求 |
|--------|------|---------|
| 变更清单 | `docs/delivery/SV-xxxxx-changelist.md` | 已与 `git diff main...HEAD` 对账，无遗漏文件 |
| 技术参考文档 | `docs/delivery/SV-xxxxx-tech-ref.md` | 面向测试人员，包含接口、核心功能、数据流、配置和注意事项 |
| 代码评审报告 | `docs/delivery/SV-xxxxx-review-report.md` | 包含 V4 统一审计结论、注释/删除代码检查、Git 规范检查、评分、V1-V5 验证摘要、Critical 闭环状态和交付判定 |

任一正式交付文档缺失或不满足最低要求时，综合结果不得视为可交付；必须补齐后重新执行对应维度或交付物检查。`docs/delivery/.state/SV-xxxxx-verification.json` 只作为机器状态使用，可用于排障和续验，但不作为交付物齐套条件展示给用户。

## 机器状态文件格式

每完成一个维度的验证或每完成一轮迭代，更新机器状态文件：

为控制 token 和文档体积，状态文件只记录结构化摘要信息，不粘贴大段原始日志。构建、测试、lint 等命令的完整输出应保留在终端、CI 或日志文件中，状态文件只写失败摘要、关键错误、修复动作和日志引用路径。

```json
{
  "requirementId": "SV-xxxxx",
  "techDesign": "docs/design/SV-xxxxx-tech-design.md",
  "branch": "feature/SV-xxxxx-xxx",
  "baseBranch": "main",
  "status": "running",
  "currentIteration": 1,
  "maxIterations": 3,
  "dimensions": {
    "V1_BUILD": {
      "status": "pending",
      "lastRunAt": null,
      "passedIteration": null,
      "summary": "",
      "logRef": ""
    },
    "V2_TEST": {
      "status": "pending",
      "lastRunAt": null,
      "passedIteration": null,
      "summary": "",
      "failedItems": [],
      "logRef": ""
    },
    "V3_PERFORMANCE": {
      "status": "pending",
      "lastRunAt": null,
      "passedIteration": null,
      "summary": "",
      "criticalItems": [],
      "warningItems": [],
      "logRef": ""
    },
    "V4_ALIGNMENT": {
      "status": "pending",
      "lastRunAt": null,
      "passedIteration": null,
      "summary": "",
      "criticalItems": [],
      "warningItems": [],
      "logRef": ""
    },
    "V5_STANDARD": {
      "status": "pending",
      "lastRunAt": null,
      "passedIteration": null,
      "summary": "",
      "criticalItems": [],
      "warningItems": [],
      "logRef": ""
    }
  },
  "rerunPlan": [],
  "fixHistory": [],
  "finalSummaryWrittenTo": "docs/delivery/SV-xxxxx-review-report.md"
}
```

## 断点续验

验证循环支持中途中断后恢复：

1. 每完成一个维度即更新机器状态文件并保存
2. 如果会话中断（用户关闭、上下文耗尽等），下次执行 B3 时：
   - 检测到已有机器状态文件
   - 读取已完成的维度状态，跳过已通过的维度
   - 从未完成的维度继续执行
3. 如果用户希望全部重验，可以删除机器状态文件后重新执行

## 与现有组件的协作关系

```
verification-loop（编排层）
    │
    ├── V1 构建验证 ──→ 直接执行构建命令
    ├── V2 测试验证 ──→ testing skill + unit-test-reviewer agent
    ├── V3 性能验证 ──→ performance-analysis skill
    ├── V4 统一审计 ──→ audit-context-intake skill + audit-reviewer agent
    └── V5 规范验证 ──→ shared rules + 当前 family-common/profile rules + lint 工具
```

- 本 Skill 负责**流程编排、状态管理、迭代控制、门禁评判**
- 各维度的**具体检查逻辑**由对应的 Skill / Agent / 工具负责
- 验证结果统一收集到机器状态文件，并将最终摘要写入 `review-report.md` 供人类阅读

## 配置项

以下配置从 `AGENTS.md` 读取，若未配置则使用默认值：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `maxIterations` | 3 | 最大迭代轮次，超过后标记 FAIL 需人工介入 |
| `buildCommand` | 按 `techStack` 推断或询问用户 | 构建/类型检查命令 |
| `testCommand` | 按 `techStack` 推断或询问用户 | 测试命令 |
| `lintCommand` | 按 `techStack` 推断或询问用户 | 规范检查命令 |
| `coverageBaseline` | 项目现有覆盖率 | 覆盖率基线，低于此值标记 ⚠️ |
