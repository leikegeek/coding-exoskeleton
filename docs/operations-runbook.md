# Exoskeleton 故障处理 Runbook

本 Runbook 用于治理相关常见故障的快速排查与恢复。默认在业务项目根目录执行命令。

## 1. Hooks 拦截异常（误拦截/全拦截）

### 现象

- 正常工具调用被拒绝
- Shell 命令几乎全部被阻断
- 设计模式与编码模式行为异常

### 处理步骤

1. 确认当前目录是业务项目，而不是插件仓库目录。
2. 检查 `.cursor/harness-config.json` 是否存在、`pathWhitelist` 是否覆盖当前目标路径。
3. 检查 `~/.cursor/hooks.json` 是否存在且指向 `plugins/local/coding-exoskeleton/hooks/*.ps1`；缺失或损坏时重跑插件安装器修复：

```powershell
& "$env:USERPROFILE\.cursor\plugins\local\coding-exoskeleton\install.ps1"
```

4. 确认业务项目内没有残留的 `.cursor/hooks.json`（本项目已全面切换为全局 hooks，发现残留应直接删除）。
5. 重启 Cursor 后重试核心命令（如 `/start` 或 `/code`）。
6. 仍失败时，查看审计日志定位拒绝原因：
   - `.cursor/hooks/logs/harness-events.jsonl`

## 2. 项目画像缺失或失真

### 现象

- 无法激活正确技术栈规则
- AI 对项目结构理解明显偏差

### 处理步骤

1. 执行 `/init` 重新扫描并确认 Profile。
2. 若已有画像，优先选择“增量更新”；结构变化较大时选择“覆盖重建”。
3. 检查 `AGENTS.md` 的 `techStack` 与实际是否一致。
4. 校验 `.cursor/harness-config.json` 中 `techStack` 是否同步更新。

## 3. 升级后行为异常

### 现象

- 插件升级后 hooks 行为与预期不一致
- 新文档/新规则未生效

### 处理步骤

1. 在插件仓库执行升级（`install.ps1` 会同时刷新 `~/.cursor/hooks.json`，全局生效）：

```powershell
git pull --ff-only
.\install.ps1
```

2. 重启 Cursor。
3. 用 `/report` 验证审计是否恢复正常记录。

## 4. 作者注释配置异常

### 现象

- 新增 Java 类未生成预期的 `@author`
- 作者名不符合当前开发者身份
- 业务仓库中出现了个人作者配置文件

### 处理步骤

1. 检查全局用户配置是否存在：

```powershell
Test-Path "$env:USERPROFILE\.cursor\coding-exoskeleton\user-config.json"
```

2. 如不存在，执行 `/init`。如果项目已有 `AGENTS.md`，请选择「仅配置个人作者信息」；选择「跳过」不会生成作者配置。
3. 确认业务项目中没有提交个人配置：作者配置不得出现在 `AGENTS.md`、`.cursor/harness-config.json`、技术方案或交付文档中。
4. 若全局配置缺失，编码阶段可回退读取 `git config --global user.name`；仍为空时不生成作者注释。
5. 已有类的 `@author` 不应被自动新增或改写，如发现误改，按本次变更回退对应注释。

## 5. 交付文档缺失或不完整

### 现象

- `docs/delivery/` 下缺少变更清单/技术参考/评审报告

### 处理步骤

1. 优先使用标准 `/code` 流程重跑审查阶段补齐产物。
2. 如属历史任务补救，执行 `/deliver` 从 diff 回溯生成文档。
3. 对高风险变更进行人工复核，防止回溯误差。

## 6. V2 单元测试审视阻塞

### 现象

- 测试命令本身通过，但 B3/V2 仍被判定为未通过
- `unit-test-reviewer` 返回 Critical，指出单测未覆盖需求、技术设计或生产逻辑
- 同一个测试点连续两轮未通过，流程要求反馈给用户确认

### 处理步骤

1. 查看 `docs/delivery/.state/SV-xxxxx-verification.json` 中 V2 的失败摘要和失败测试点。
2. 对照 `docs/design/SV-xxxxx-tech-design.md` 的测试与验收章节，确认失败点对应的需求/设计依据。
3. 如果是测试缺口，补充能验证生产逻辑的断言或测试数据；不得通过删除用例、跳过用例、放宽断言或过度 mock 核心逻辑来换取通过。
4. 如果是生产实现缺陷，修复生产代码后重跑 V2。
5. 如果同一测试点已连续两次失败，停止自动修复，将两次失败摘要、关联需求/设计依据和可能原因反馈给用户，由用户判断是调整需求/设计、修复实现，还是接受明确记录的不测范围。

## 7. 独立审计信息不足或边界异常

### 现象

- `/audit` 无法读取私有 GitLab MR 的标题、描述、comments 或 pipeline
- 审计报告中大量业务判断被标为低可信或需确认
- 独立审计过程中出现修改代码、创建分支或提交 commit 的倾向

### 处理步骤

1. 优先确认本地 Git 是否能访问远端仓库；能访问时，使用 Git diff 和变更文件完整上下文作为基础审计材料。
2. 如需补充 MR 元信息，确认 `glab auth status` 是否可用，或是否存在只读 `GITLAB_TOKEN` / `GLAB_TOKEN`。不要提供高权限 token。
3. 只有浏览器已登录 GitLab 时，不要假设 Agent 能复用浏览器 cookie；将 MR 元信息、comments 和 pipeline 标记为未验证。
4. 检查 `AuditContext.evidenceLevel`：业务资料不足时应为 `medium` 或 `low`，相关业务判断进入“疑问与确认”，不得伪装成确定需求。
5. 确认 `/audit` 仍处于只读审计模式，允许写入路径仅为 `docs/audit/`。只有用户明确要求“修复这个 MR/分支”时，才另行建立编码模式任务契约。

## 8. 模式状态异常（设计模式/编码模式错位）

### 现象

- 允许操作与当前流程阶段不匹配

### 处理步骤

1. 确认当前任务契约字段完整（SV-ID、模式、边界、验收标准）。
2. 明确发起模式切换并写明原因与写入边界。
3. 检查 `.cursor/harness-state.json` 是否与预期一致。

## 9. 恢复后验收

恢复完成后至少确认以下项目：

- [ ] `/start` 或 `/code` 可正常运行
- [ ] Hooks 拦截只发生在危险操作
- [ ] `AGENTS.md` 与 `harness-config.json` 一致
- [ ] 审计日志持续产生新事件
