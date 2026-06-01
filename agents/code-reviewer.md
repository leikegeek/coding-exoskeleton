---
name: code-reviewer
displayName: 代码评审代理（兼容入口）
description: 兼容旧流程的代码评审代理名。新流程不再单独使用本代理，统一转交 audit-reviewer 执行统一代码审计。
---

# 代码评审代理（兼容入口）

## 状态

本代理保留用于兼容旧文档或旧会话中的 `code-reviewer` 名称。当前主流程中，`/code` B3 和 `/audit` 均应使用 `agents/audit-reviewer.md` 作为唯一审计提示词。

## 执行规则

如果主 Agent 或旧流程请求调用本代理：

1. 不要执行独立的三方对齐审查。
2. 要求主 Agent 先读取 `skills/shared/audit-context-intake/SKILL.md`，生成 `AuditContext`。
3. 将审计任务转交 `agents/audit-reviewer.md`。
4. 输出格式、严重级别和门禁判定以 `audit-reviewer` 为准。

## 迁移说明

旧的"变更记录 vs diff vs 技术方案"三方对齐能力已经并入 `audit-reviewer` 的统一审计维度和报告格式，包括逻辑正确性、兼容性与可维护性、Git 规范检查、注释/删除代码检查和评分。

因此不要再维护第二套代码评审标准，避免 `/code` 和 `/audit` 的审计结论漂移。
