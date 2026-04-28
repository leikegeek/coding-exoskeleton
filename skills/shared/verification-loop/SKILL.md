---
name: verification-loop
displayName: 结构化验证循环
description: 将 B3 代码审查阶段从单次线性检查升级为结构化验证循环，编排构建、测试、性能、对齐、规范五个验证维度，支持增量重验、检查点保存和综合门禁评判。
triggers: ["验证循环", "代码验证", "B3审查", "verification loop", "全量验证"]
autoTrigger: true
version: '1.0.2'
---

# 结构化验证循环

## 定位

本 Skill 是 B3（代码审查与对齐）阶段的**编排层**，不替换现有的 `testing` skill、`performance-analysis` skill、`code-reviewer` agent，而是按结构化流程调用它们，统一收集结果，管理迭代循环，直到所有维度通过或达到最大迭代次数。

## 验证维度矩阵

每轮验证依次执行以下 5 个维度，每个维度产出三种状态之一：

| 维度 | 编号 | 检查内容 | 通过标准 | 调用的组件 |
|------|------|---------|---------|-----------|
| 构建验证 | V1 | 编译通过、无错误、无阻断性警告 | 构建命令返回 0，无 ERROR 级别输出 | 直接执行项目构建命令 |
| 测试验证 | V2 | 全量单元测试通过、覆盖率达标 | 全部测试 PASS，覆盖率不低于项目基线 | `testing` skill |
| 性能验证 | V3 | 无 N+1 查询、无循环内 RPC、批量操作合规 | 无 Critical 级性能问题 | `performance-analysis` skill |
| 对齐验证 | V4 | 变更记录 vs diff vs 技术方案三方对齐 | 无 Critical 级业务偏差 | `code-reviewer` agent |
| 规范验证 | V5 | lint/checkstyle 通过、命名规范、架构分层合规 | 无 ERROR 级违规 | 项目 lint 工具 + `rules/*.mdc` |

**状态定义**：

| 状态 | 含义 | 后续动作 |
|------|------|---------|
| ✅ 通过 | 该维度检查全部达标 | 无需重验 |
| ⚠️ 有警告 | 存在非阻断性问题（Warning / Info 级别） | 记录后可继续，需在报告中说明 |
| ❌ 未通过 | 存在阻断性问题（Critical / Error 级别） | 必须修复后重新验证该维度 |

## 执行流程

### 第一步：初始化验证上下文

1. 读取需求编号（SV-ID），确定机器状态文件路径：`docs/delivery/.state/SV-xxxxx-verification.json`
2. 检查是否存在未完成的验证状态（支持断点续验）：
   - **存在且未完成**：读取 JSON 状态，从上次中断的位置继续
   - **不存在**：创建新的 JSON 状态文件，初始化所有维度为"待验证"
3. 记录当前迭代轮次（初始为第 1 轮）

### 第二步：执行验证维度

按 V1 → V2 → V3 → V4 → V5 顺序依次执行。**如果是重验轮次，只执行状态为 ❌ 的维度，已通过的维度跳过。**

#### V1：构建验证

1. 执行项目构建命令（从 `AGENTS.md` 读取构建命令，如 `mvn compile -q`）
2. 判定结果：
   - 构建成功（exit code 0）且无 ERROR 输出 → ✅
   - 构建成功但有警告 → ⚠️，记录警告内容
   - 构建失败 → ❌，记录错误信息
3. 更新机器状态文件

#### V2：测试验证

1. 读取 `testing` skill
2. 执行全量单元测试命令（从 `AGENTS.md` 读取测试命令，如 `mvn test`）
3. 判定结果：
   - 全部通过 → ✅
   - 全部通过但覆盖率低于基线 → ⚠️，记录覆盖率数据
   - 有失败用例 → ❌，记录失败用例列表
4. 更新机器状态文件

#### V3：性能验证

1. 读取 `performance-analysis` skill
2. 对本次变更涉及的代码执行性能扫描
3. 判定结果：
   - 无性能问题 → ✅
   - 仅有 Warning 级建议 → ⚠️，记录建议列表
   - 存在 Critical 级问题（N+1、循环内 RPC 等） → ❌，记录问题详情
4. 更新机器状态文件

#### V4：对齐验证

1. 读取 `code-reviewer` agent
2. 准备三份输入材料：
   - 变更记录文档：`docs/delivery/SV-xxxxx-changelist.md`
   - git diff：`git diff main...HEAD`
   - 技术方案文档：`docs/design/SV-xxxxx-tech-design.md`
3. 执行三方对齐审查
4. 判定结果：
   - 三方一致，无遗漏无偏差 → ✅
   - 存在 Warning 级不一致（如细节差异但不影响业务） → ⚠️
   - 存在 Critical 级偏差（业务功能遗漏、超范围变更、需求跑偏） → ❌
5. 更新机器状态文件

#### V5：规范验证

1. 执行项目 lint/checkstyle 命令（从 `AGENTS.md` 读取，如 `mvn checkstyle:check`）
2. 对照 `rules/` 下适用的规则文件检查命名规范、架构分层
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
| **PASS** | 所有维度 ✅ 或 ⚠️（Warning 已在报告中记录） | 五维验证完成；**进入 B4 前**还须 `security-reviewer`（见下方） |
| **FAIL** | 任何维度 ❌ 且已达最大迭代次数 | 阻断，需人工介入 |
| **BLOCKED** | 依赖条件不满足（如构建环境异常、Subagent 结果未汇总） | 阻断，需排除障碍后重试 |

> **与 B3 安全审计的衔接**（与 `rules/shared/subagent-orchestration.mdc` 一致）：上表 **PASS** 仅表示 V1–V5 结束。在 **进入 B4、调用 `doc-updater` 前**，须再执行 `security-reviewer`；安全结论不占用 V1–V5 编号。若安全侧存在未闭环的 Critical，**不得**进入 B4，应修复后按需重验相关维度。

FAIL 时的处理：
1. 输出完整的验证报告，包含每轮迭代的问题和修复记录
2. 明确告知用户哪些维度未通过、已尝试的修复措施
3. 建议人工介入的方向

### 第五步：产出验证状态与正式交付摘要

验证循环结束后（无论 PASS 还是 FAIL），产出以下内容：

1. **机器状态文件**（`docs/delivery/.state/SV-xxxxx-verification.json`）：保存 V1-V5 当前状态、迭代轮次、失败摘要、修复动作、日志引用和下一轮重验计划，供 Agent 断点续验使用。该文件**不是正式交付文档**，不进入 B4 交付展示。
2. **代码评审报告**（`docs/delivery/SV-xxxxx-review-report.md`）：整合三方对齐结论、问题列表、V1-V5 最终验证摘要、安全审计结论和交付判定，作为人类阅读的质量结论文档。
3. **变更清单定稿**：对 B2 阶段积累的变更记录做最终校验和格式化。
4. **技术参考文档**（`docs/delivery/SV-xxxxx-tech-ref.md`）：从变更记录和审查结果中提炼。

正式交付文档必须保持摘要化：不复制完整命令输出、完整 diff 或完整测试日志；只记录结论、阻断问题、修复动作、剩余风险和必要的日志引用。机器状态文件保存结构化字段，不写叙述性长文。

## 交付文档齐套门禁

当综合结果为 PASS 且安全审计可交付时，进入 B4 前必须确认以下三类**正式交付文档**全部存在且需求编号一致：

| 交付物 | 路径 | 最低要求 |
|--------|------|---------|
| 变更清单 | `docs/delivery/SV-xxxxx-changelist.md` | 已与 `git diff main...HEAD` 对账，无遗漏文件 |
| 技术参考文档 | `docs/delivery/SV-xxxxx-tech-ref.md` | 面向测试人员，包含接口、核心功能、数据流、配置和注意事项 |
| 代码评审报告 | `docs/delivery/SV-xxxxx-review-report.md` | 包含 V4 对齐结论、V1-V5 验证摘要、安全审计结论、Critical 闭环状态和交付判定 |

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
    ├── V2 测试验证 ──→ testing skill
    ├── V3 性能验证 ──→ performance-analysis skill
    ├── V4 对齐验证 ──→ code-reviewer agent
    └── V5 规范验证 ──→ rules/*.mdc + lint 工具
```

- 本 Skill 负责**流程编排、状态管理、迭代控制、门禁评判**
- 各维度的**具体检查逻辑**由对应的 Skill / Agent / 工具负责
- 验证结果统一收集到机器状态文件，并将最终摘要写入 `review-report.md` 供人类阅读

## 配置项

以下配置从 `AGENTS.md` 读取，若未配置则使用默认值：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `maxIterations` | 3 | 最大迭代轮次，超过后标记 FAIL 需人工介入 |
| `buildCommand` | `mvn compile -q` | 构建命令 |
| `testCommand` | `mvn test` | 测试命令 |
| `lintCommand` | `mvn checkstyle:check` | 规范检查命令 |
| `coverageBaseline` | 项目现有覆盖率 | 覆盖率基线，低于此值标记 ⚠️ |
