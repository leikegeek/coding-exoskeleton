---
name: frontend-knowledge-maintenance
displayName: 前端项目知识沉淀
description: 维护前端项目 AI 上下文文档、模块映射、API 契约、已知问题、性能基线、生成代码修正记录和变更日志时使用。用于减少重复摸索和重复返工。
triggers: ["知识沉淀", "前端文档", "模块映射", "API契约文档", "已知问题", "生成代码修改记录"]
autoTrigger: false
version: '1.0.0'
---

# 前端项目知识沉淀

## 使用时机

- 初始化或补齐前端项目上下文文档。
- 任务结束后沉淀改动、风险、回滚和未覆盖验证。
- 多次遇到同类 API、性能、生成代码或组件使用问题。

## 前置检查

1. 读取 `AGENTS.md`，确认 `techStack` 为 `frontend-vue3` 或 `frontend-react-umi`。
2. 若不是前端 profile，跳过本 skill，使用通用交付或项目画像能力。

## 推荐文档集

- `docs/ai-index.md`：文档导航和阅读顺序。
- `docs/ai-project-context.md`：技术栈、关键入口、默认开发策略。
- `docs/ai-module-map.md`：业务模块到页面、API、公共依赖的映射。
- `docs/ai-api-contract-notes.md`：高频高风险接口契约和历史坑。
- `docs/ai-regression-checklist.md`：分层回归清单。
- `docs/ai-performance-baseline.md`：性能指标、阈值和采样记录。
- `docs/ai-known-issues.md`：已知问题、规避方式和状态。
- `docs/ai-change-log.md`：每次任务的改动账本。
- `docs/generated-code-changelog.md`：AI 或脚手架初稿被修正后的规则级记录。

## 维护原则

- 只记录可复用知识，不把一次性过程日志搬进长期文档。
- 每条记录包含场景、结论、影响范围、验证方式和更新时间。
- 已修复问题不要删除，标记状态并补充修复版本或时间。
- 生成代码修正记录聚焦“规则级差异”，避免逐行流水账。

## 输出格式

1. 建议新增/更新的文档
2. 每份文档的记录要点
3. 与本次任务相关的沉淀内容
4. 后续维护建议
