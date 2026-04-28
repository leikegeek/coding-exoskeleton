---
name: project-profiling
displayName: 项目画像生成
description: 扫描项目文件和目录结构，推断技术栈和架构模式，通过交互确认生成项目画像文件（AGENTS.md）。适用于项目初始化阶段。
triggers: ["项目初始化", "生成画像", "/init", "AGENTS.md"]
autoTrigger: true
version: '1.0.2'
---

# 项目画像生成

## 技能目标

扫描当前业务项目的文件结构、构建配置和已有文档，推断技术栈和架构模式，通过交互式确认生成标准化的项目画像文件（`AGENTS.md`），为后续所有流程提供持久化的项目上下文。

## 核心原则

1. **扫描优先，推断辅助**：尽可能从项目实际文件中获取信息，仅在信息不足时推断
2. **交互确认，不猜测**：对无法确定的信息主动询问用户，不做假设
3. **预设 + 自定义**：提供预设 Profile 快速匹配，同时支持完全自定义

## 扫描策略

### 1. 构建文件识别

按优先级扫描以下文件，确定语言和构建工具：

| 文件 | 语言 | 构建工具 |
|------|------|----------|
| `pom.xml` | Java | Maven |
| `build.gradle` / `build.gradle.kts` | Java/Kotlin | Gradle |
| `package.json` | JavaScript/TypeScript | npm/yarn/pnpm |
| `go.mod` | Go | Go Modules |
| `Cargo.toml` | Rust | Cargo |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python | pip/poetry |
| `*.csproj` / `*.sln` | C# | .NET |
| `Gemfile` | Ruby | Bundler |

### 2. 框架识别

从依赖声明中识别主要框架：

**Java 生态**：
- `pom.xml` 中包含 `com.alibaba.cola` → COLA 架构
- `pom.xml` 中包含 `org.springframework.boot` → Spring Boot
- `pom.xml` 中包含 `io.quarkus` → Quarkus

**JavaScript/TypeScript 生态**：
- `package.json` 中包含 `react` → React
- `package.json` 中包含 `vue` → Vue
- `package.json` 中包含 `next` → Next.js
- `package.json` 中包含 `express` / `koa` / `nestjs` → Node.js 后端

**Python 生态**：
- `requirements.txt` 或 `pyproject.toml` 中包含 `django` → Django
- 包含 `fastapi` → FastAPI
- 包含 `flask` → Flask

### 3. 目录结构识别

扫描顶层和二级目录，推断架构模式：

| 目录特征 | 架构模式 |
|----------|----------|
| `adapter/` + `application/` + `domain/` + `infrastructure/` | COLA |
| `controller/` + `service/` + `dao/` 或 `repository/` | MVC 分层 |
| `src/` + `components/` + `pages/` | 前端组件化 |
| `cmd/` + `internal/` + `pkg/` | Go 标准布局 |
| `src/` + `tests/` + `benches/` | Rust 标准布局 |

### 4. 测试框架识别

从依赖和测试目录推断：

| 标志 | 测试框架 |
|------|----------|
| `junit-jupiter` / `junit-platform` | JUnit 5 |
| `testng` | TestNG |
| `jest` / `vitest` | Jest / Vitest |
| `pytest` | pytest |
| `testing` (Go 标准库) | Go testing |

### 5. 已有文档扫描

- 读取 `README.md`：提取项目描述
- 读取 `.cursor/rules/` 下的规则文件：理解已有规范
- 读取 `.gitignore`：辅助判断项目类型

## 预设 Profile 定义

### cola-java

**匹配条件**：`pom.xml` 存在 + `com.alibaba.cola` 依赖 + COLA 目录结构

**激活的专项规范**：
- Skills：`skills/cola-java/cola-architecture/`（COLA 架构方案设计）、`skills/cola-java/cola-naming/`（COLA 命名规范）
- Rules：`rules/cola-java/cola-architecture.mdc`、`rules/cola-java/java-naming.mdc`、`rules/cola-java/transaction-executor.mdc`、`rules/cola-java/mq-consumer.mdc`

**AGENTS.md 预填内容**：
- 架构：COLA 4.x 分层
- 命名：COLA 命名规范（XxxCmdExe、XxxQryExe、IXxxGateway 等）
- 事务：仅在 Executor 层使用 `@Transactional`
- 分层约束：domain 不依赖 infrastructure

### 自定义

**匹配条件**：不符合任何预设 Profile，或用户主动选择自定义

**激活的专项规范**：仅 `skills/shared/*` 和 `rules/shared/*`

**AGENTS.md 预填内容**：基于扫描结果填写，未识别的字段标记为 `[待补充]` 并交互确认

## 交互确认清单

扫描完成后，按以下顺序确认或补充信息：

如果 `/init` 预检发现业务项目已存在 `AGENTS.md`，个人本地配置仍必须单独检查；项目画像的“跳过/增量/覆盖”不应隐式跳过 `~/.cursor/coding-exoskeleton/user-config.json` 的配置入口。

### 必确认项

1. **项目名称**：从 README 或构建文件提取，请用户确认
2. **项目简述**：一句话描述项目做什么
3. **技术栈 Profile**：展示推断结果，让用户确认或切换

### 条件确认项（仅在无法推断时询问）

4. **测试框架**：如果依赖中未检测到测试框架
5. **架构模式**：如果目录结构不匹配任何已知模式

### 可选补充项（有默认值，用户可跳过）

6. **分支策略**：默认 Git Flow
7. **commit 格式**：默认 `feat(SV-xxxxx): 描述`
8. **需求编号正则**：用于自动识别需求编号，默认 `SV-\d+`；JIRA 项目可设为 `[A-Z]+-\d+`，GitHub 可设为 `#\d+`
9. **编码规范偏好**：如有团队特殊约定
10. **部署方式**：如有特殊说明

### 个人本地配置项（不写入 AGENTS.md）

以下信息属于开发者个人配置，只能写入 `~/.cursor/coding-exoskeleton/user-config.json`，不得写入业务项目或 `AGENTS.md`：

11. **作者显示名**：用于新建代码文件作者注释（如 Java `@author`）
12. **作者邮箱**：默认读取 `git config --global user.email`
13. **commit trailer 开关**：默认 `false`；仅当团队要求在 commit message 追加作者说明时开启

若用户未填写作者显示名，默认读取 `git config --global user.name`；仍为空则跳过作者注释生成。

触发规则：
- 已有 `AGENTS.md` 且用户选择“仅配置个人作者信息”时，只执行本节，不扫描或改写项目画像。
- 已有 `AGENTS.md` 且用户选择“增量更新”时，仍执行本节的配置检查。
- 用户明确选择“跳过”时不写任何文件，但需要提示后续可通过 `/init` 的“仅配置个人作者信息”进入本节。

## AGENTS.md 模板

```markdown
---
techStack: {profile_id}
---

# {项目名称}

## 项目简介

{一段简短描述，说明项目的业务目标和定位}

## 技术栈

- **语言**：{语言及版本}
- **框架**：{主要框架及版本}
- **架构**：{架构模式及分层说明}
- **构建工具**：{构建工具}
- **测试框架**：{测试框架}
- **数据库**：{如已知}

## 模块结构

{自动扫描生成的模块列表，格式如下}

\```
project-root/
├── module-a/          # 模块A说明
├── module-b/          # 模块B说明
└── ...
\```

## 编码规范

{基于 Profile 预填或用户补充}

- 命名规范：{概要}
- 分层约束：{概要}
- 事务管理：{概要}
- 其他：{团队特殊约定}

## 协作约定

- **分支策略**：{Git Flow / Trunk-based / 其他}
- **commit 格式**：`feat(SV-xxxxx): 描述`
- **需求编号格式**：{SV-12345 或团队自定义格式}
- **需求编号正则**：{如 `SV-\d+`、`[A-Z]+-\d+`、`#\d+` 等，用于自动匹配识别}
```

## 产出

- `AGENTS.md`：保存到业务项目根目录
- `.cursor/harness-config.json` 中的 `techStack` 字段更新
- `~/.cursor/coding-exoskeleton/user-config.json`：可选的全局个人配置（作者名、邮箱等），不进入业务仓库

## 个人配置隔离规则

- `AGENTS.md` 只记录项目共享画像，不记录开发者个人作者名、邮箱或签名偏好。
- `.cursor/harness-config.json` 只记录项目级 harness 配置，不记录个人作者信息。
- 全局个人配置路径固定为 `~/.cursor/coding-exoskeleton/user-config.json`，位于业务项目之外，天然不会被 git 提交。
- 后续编码阶段若需要生成 `@author`，只能读取全局个人配置或 git 全局配置，不得从项目文档推断。

