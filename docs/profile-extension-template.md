# Exoskeleton 技术栈 Profile 扩展模板

用于新增非 `cola-java` 的技术栈治理包（skills + rules + init 识别逻辑）。

## 1. 新增范围

以 `{profile-id}` 为例（如 `spring-boot`、`react-ts`）：

- `skills/{profile-id}/...`
- `rules/{profile-id}/...`
- `/init` 识别与映射逻辑
- `docs/plugin-core-workflow.md` 的 Profile 表

## 2. 最小目录模板

```text
skills/{profile-id}/
  ├── architecture/SKILL.md
  └── naming/SKILL.md

rules/{profile-id}/
  ├── architecture.mdc
  ├── naming.mdc
  └── performance.mdc
```

## 3. Skill 模板要求

- 必填 frontmatter：`name`、`displayName`、`description`、`triggers`、`autoTrigger`、`version`
- 必含“技术栈适配前置检查”：
  1. 读取 `AGENTS.md`
  2. 校验 `techStack == {profile-id}`
  3. 不匹配则跳过并回退到 shared skill
- 明确输入、输出、缺失信息追问机制

## 4. Rule 模板要求

- 必填 frontmatter：`description`
- 优先使用 `globs` 限定作用范围
- 非通用规则默认 `alwaysApply: false`
- 禁止写死项目私有实现名；采用“项目约定优先 + 默认示例”表达

## 5. /init 扩展要求

- 在项目扫描阶段补充该技术栈的识别特征：
  - 构建文件
  - 关键依赖
  - 目录结构信号
- 在 Profile 确认阶段支持用户手动切换到 `{profile-id}`
- 生成 `AGENTS.md` 时写入：

```yaml
techStack: {profile-id}
```

## 6. 文档与可观测性要求

- 在 `docs/plugin-core-workflow.md` 中补充 Profile 条目
- 在 `docs/user-guide.md` 保留跳转入口
- 在治理清单中确保可检查“Profile 命中与规则激活”

## 7. 验收清单

- [ ] `/init` 可识别并写入 `{profile-id}`
- [ ] 对应 skills 仅在匹配技术栈时执行
- [ ] 对应 rules 仅在目标文件范围触发
- [ ] `/start`、`/code` 流程无回归
- [ ] 审计日志可观测，`/report` 可看到关键指标
