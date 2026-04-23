# Exoskeleton 用户手册（操作版）

本手册只保留操作步骤、核心流程图和跳转入口。机制解释、治理原理和设计细节统一以 `docs/plugin-core-workflow.md` 为准。

## 快速跳转

- 机制权威文档：`docs/plugin-core-workflow.md`
- 治理基线检查清单：`docs/governance-checklist.md`
- 故障处理 Runbook：`docs/operations-runbook.md`
- Profile 扩展模板：`docs/profile-extension-template.md`

## 平台要求

> **当前版本仅支持 Windows**（PowerShell 5.1+）。Hooks 脚本和安装脚本均基于 PowerShell 实现，macOS / Linux 支持在后续版本规划中。

## 标准操作步骤

### 1) 安装插件（每台机器一次）

执行环境与目录：

- 执行环境：`Windows PowerShell`
- 执行目录：任意目录（建议工具目录）

命令与作用：

```powershell
# 作用：克隆插件仓库到本地
git clone https://github.com/leikegeek/coding-exoskeleton.git

# 作用：进入插件仓库根目录，后续安装/验证命令都在这里执行
cd .\coding-exoskeleton

# 作用：安装插件到 Cursor 本地插件目录
.\install.ps1
```

已有仓库（可选）：

- 执行环境：`Windows PowerShell`
- 执行目录：已克隆的 `coding-exoskeleton` 仓库根目录

```powershell
# 作用：拉取远端最新代码（快进更新）
git pull --ff-only

# 作用：按最新代码重新安装插件
.\install.ps1
```

可选验证：

- 执行环境：`Windows PowerShell`
- 执行目录：`coding-exoskeleton` 仓库根目录

```powershell
# 作用：验证插件目录与组件完整性
.\verify.ps1 -PluginRoot "$env:USERPROFILE\.cursor\plugins\local\coding-exoskeleton"
```

### 2) 重启 Cursor

重启后，插件的 `skills` / `rules` / `commands` / `agents` 自动加载。

### 3) 在业务项目中开始使用

执行环境与目录：

- 执行环境：`Cursor 对话框`（不是 PowerShell）
- 执行目录：业务项目根目录（在 Cursor 中打开该项目）

命令与作用：

```text
# 作用：从需求启动完整流程（需求 -> 方案 -> 编码 -> 交付）
/start SV-34577 需求描述或需求文档

# 作用：从已有技术方案直接进入编码与交付流程
/code SV-34577 @docs/design/SV-34577-tech-design.md

# 作用：手动初始化或重建项目画像（AGENTS.md + techStack 配置）
/init

# 作用：在非标准流程下补救生成交付文档
/deliver

# 作用：查看 hooks 审计统计与治理指标
/report
```

首次在项目中使用会自动引导安装 Hooks 与生成 `AGENTS.md`。

已有业务仓库（可选）：

- 若你已在本地有业务仓库，只需在 Cursor 中直接打开该业务仓库目录，然后执行上述 `/start` 或 `/code`。
- 无需在业务仓库中再执行 `install.ps1`（安装脚本只在插件仓库执行）。

## 核心流程图

```mermaid
flowchart TD
    subgraph entry [用户入口]
        CMD_INIT["/init — 项目初始化"]
        CMD_START["/start — 从需求开始"]
        CMD_CODE["/code — 从技术方案编码"]
        CMD_DELIVER["/deliver — 补救交付文档"]
        CMD_REPORT["/report — 查看统计"]
    end

    subgraph preCheck [预检层: 自动执行]
        PC_Hooks{"Hooks 已安装?"}
        PC_InstallHooks["安装 Hooks"]
        PC_Agents{"AGENTS.md 存在?"}
        PC_Init["执行 /init 生成项目画像"]
        PC_Ready["项目上下文就绪"]
    end

    subgraph pipelineA [流水线 A: 需求到技术方案]
        A_Intake["需求录入 + 解析"]
        A_Design["技术方案设计 + 自评审 + 架构审查"]
        A_Compact["上下文压缩评估"]
        A_Choice{"继续编码 or 断开?"}
    end

    subgraph pipelineB [流水线 B: 技术方案到交付]
        B_Understand["理解技术方案 + 确认疑问 + 检查实施进度"]
        B_Prepare["创建分支 + 拆解任务 + 初始化进度"]
        B_Code["TDD 编码 + 增量记录变更 + TDD 纪律检查"]
        B_Verify["验证循环: 构建→测试→性能→对齐→规范"]
        B_Deliver["文档完整性检查 + 展示交付物"]
    end

    subgraph standalone [独立命令]
        DELIVER_FIX["从 git diff 补救生成文档"]
        REPORT_GEN["生成审计统计报告"]
    end

    CMD_INIT --> PC_Init
    CMD_START --> PC_Hooks
    CMD_CODE --> PC_Hooks
    CMD_DELIVER --> DELIVER_FIX
    CMD_REPORT --> REPORT_GEN

    PC_Hooks -->|"否"| PC_InstallHooks --> PC_Agents
    PC_Hooks -->|"是"| PC_Agents
    PC_Agents -->|"否"| PC_Init --> PC_Ready
    PC_Agents -->|"是"| PC_Ready

    PC_Ready -->|"/start"| A_Intake --> A_Design --> A_Compact --> A_Choice
    A_Choice -->|"继续"| B_Prepare
    A_Choice -->|"断开"| OUT_A["保存技术方案文档"]

    PC_Ready -->|"/code"| B_Understand --> B_Prepare
    B_Prepare --> B_Code --> B_Verify --> B_Deliver
```

## 命令速查

- `/init`：生成/更新项目画像 `AGENTS.md`
- `/start`：需求到技术方案（流水线 A）
- `/code`：技术方案到交付（流水线 B）
- `/deliver`：补救生成交付文档
- `/report`：查看治理统计

命令机制、门禁、产物细节统一查看：`docs/plugin-core-workflow.md`

## 新增机制速览（v1.0.2）

| 机制 | 作用 | 触发时机 |
|------|------|---------|
| 战略性上下文压缩 | 阶段切换时压缩上下文释放 token，快照保护关键信息 | A→B 衔接、B0→B1、B1→B2、B2→B3 等阶段切换点 |
| 结构化验证循环 | 五维度门禁（构建/测试/性能/对齐/规范），增量重验 | B3 审查阶段，由 `verification-loop` skill 编排 |
| 专职子代理 | 架构审查、TDD 检查、构建修复、安全审计、文档检查 | A2（architect）、B2（tdd-guide）、B3（build-error-resolver / security-reviewer）、B4（doc-updater） |
| 实施进度追踪 | 技术方案文档中自动维护进度段落，支持跨会话续做 | B1 初始化、B2 每个任务完成后更新、B3/B4 更新状态 |

## 进阶与运维入口

- 治理基线检查：`docs/governance-checklist.md`
- 异常处理与恢复：`docs/operations-runbook.md`
- 新技术栈 Profile 扩展：`docs/profile-extension-template.md`
