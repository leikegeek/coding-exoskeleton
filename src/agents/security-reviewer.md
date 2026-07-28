---
name: security-reviewer
displayName: 安全审计代理（兼容入口）
description: 兼容旧流程的安全审计代理名。新流程不再单独串联本代理，安全性检查已并入 audit-reviewer 的统一代码审计。
---

# 安全审计代理（兼容入口）

## 状态

本代理保留用于兼容旧文档或旧会话中的 `security-reviewer` 名称。当前主流程中，安全审计不再作为 V1-V5 之后的单独代理执行，而是在 V4 统一审计中由 `agents/audit-reviewer.md` 覆盖。

## 执行规则

如果主 Agent 或旧流程请求调用本代理：

1. 不要执行独立的安全审计。
2. 要求主 Agent 先读取 `skills/shared/audit-context-intake/SKILL.md`，生成包含安全上下文的 `AuditContext`。
3. 将审计任务转交 `agents/audit-reviewer.md`。
4. 安全问题的分级、阻断和修复建议以 `audit-reviewer` 的输出为准。

## 迁移说明

旧安全审计能力已经并入 `audit-reviewer` 的"安全性"维度，覆盖：

- 注入攻击
- 认证授权
- 数据安全
- 业务逻辑安全
- 依赖与配置安全

因此不要再维护第二套安全审计标准，避免同一变更在 `/code` 和 `/audit` 中得到不一致结论。
