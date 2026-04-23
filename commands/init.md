# /init — 项目初始化：生成项目画像与技术栈配置

当用户输入 `/init` 时，扫描当前项目并生成项目画像文件（`AGENTS.md`）和技术栈配置。

也可由 `/start` 或 `/code` 的预检步骤自动引导触发。

## 触发方式

- `/init` — 手动触发
- 自动引导 — 当 `/start` 或 `/code` 检测到项目根目录不存在 `AGENTS.md` 时

## 执行流程

### 预检：已有画像检查

1. 检查项目根目录是否存在 `AGENTS.md`
2. **如果已存在**：展示当前画像摘要，询问用户：
   > 检测到项目已有 `AGENTS.md`，请选择：
   > 1. **覆盖重新生成** — 重新扫描项目，生成全新画像
   > 2. **增量更新** — 保留已有内容，仅补充缺失信息
   > 3. **跳过** — 保持现有画像不变
3. **如果不存在**：直接进入第一步

### 第一步：项目扫描

读取 `project-profiling` skill，执行项目扫描：

1. **构建文件扫描**：识别 `pom.xml` / `build.gradle` / `package.json` / `go.mod` / `Cargo.toml` / `pyproject.toml` / `requirements.txt` 等
2. **目录结构扫描**：识别分层模式（COLA / DDD / MVC / 前端组件化等）
3. **已有文档扫描**：读取 README、已有的 `.cursor/rules/` 规则文件等
4. **技术栈推断**：从构建文件和依赖中推断语言、框架、构建工具、测试框架

### 第二步：技术栈确认

向用户展示扫描结果和推断的技术栈，让用户确认或修正：

> ## 项目扫描结果
>
> - 检测到构建文件：`pom.xml`（Maven）
> - 检测到分层结构：adapter / application / domain / infrastructure（COLA）
> - 推断技术栈：**cola-java**
>
> 可选的预设 Profile：
> 1. **cola-java** — COLA 分层 + Maven + Java + JUnit 5（匹配当前项目）
> 2. **自定义** — 手动描述技术栈，AI 生成定制画像
>
> 请确认或选择其他 Profile。

**预设 Profile 说明**：

| Profile | 适用场景 | 对应的 Skills | 对应的 Rules |
|---------|----------|---------------|-------------|
| `cola-java` | COLA Java（基于 COLA 分层）项目 | `skills/cola-java/*` | `rules/cola-java/*` |
| 自定义 | 其他技术栈或混合项目 | 仅 `skills/shared/*` | 仅 `rules/shared/*` |

> **扩展说明**：`spring-boot`、`react-ts`、`go-service` 等 Profile 为规划中的扩展方向，当前版本尚未内置。欢迎按 `docs/profile-extension-template.md` 模板贡献新 Profile。

### 第三步：交互补充

对扫描无法确定的信息，逐项询问用户（优先选择题，一次一个）：

**必填项**（无法推断时必须询问）：
- 项目名称与简要描述
- 测试框架偏好（如扫描不到测试依赖）

**可选项**（有合理默认值，用户可跳过）：
- 分支策略：Git Flow / Trunk-based / 其他（默认：Git Flow）
- commit 格式：`feat(SV-xxxxx): 描述`（默认：Exoskeleton 标准格式）
- 代码审查要求：无 / 团队 Review / CI 自动检查（默认：无）
- 其他团队特殊约定

对每个可选项，提示用户：

> 按 Enter 使用默认值，或输入自定义内容。

### 第四步：生成 AGENTS.md

读取 `project-profiling` skill 中的模板，结合扫描结果和用户确认信息，生成 `AGENTS.md` 文件到项目根目录。

文件结构参见 `project-profiling` skill 中的模板定义。

### 第五步：更新配置

将技术栈标识写入 `.cursor/harness-config.json`：

```json
{
  "techStack": "cola-java",
  "pathWhitelist": ["..."]
}
```

如果 `harness-config.json` 已存在，仅更新 `techStack` 字段，保留其他配置。

### 第六步：确保文档目录存在

检查并创建后续流程所需的文档目录（如不存在则自动创建）：

- `docs/design/` — 存放技术方案文档
- `docs/delivery/` — 存放变更清单、技术参考文档、代码评审报告

### 第七步：完成提示

> ## 项目初始化完成
>
> - 项目画像：`AGENTS.md`（已保存到项目根目录）
> - 技术栈：cola-java
> - 激活的专项规范：`skills/cola-java/*` + `rules/cola-java/*`
>
> 后续使用 `/start` 或 `/code` 时，AI 会自动读取项目画像作为上下文。
> 如需更新画像，随时执行 `/init`。

如果是由 `/start` 或 `/code` 自动引导触发的，完成后告知用户：

> 项目初始化已完成，继续执行 /start（或 /code）流程...

然后回到原命令的正式流程。

## 关键约束

- `AGENTS.md` 保存在**业务项目根目录**（Cursor 生态约定），不在插件目录内
- 技术栈 Profile 影响 AI 在后续流程中对 skills/rules 的引用优先级，但不影响 Cursor 的插件加载（所有 skills/rules 始终加载，Profile 决定哪些被主动使用）
- 增量更新模式下，已有内容保留，仅补充空缺字段
- 扫描过程为只读，不修改任何项目文件（仅在第四、五步写入 `AGENTS.md` 和 `harness-config.json`）

