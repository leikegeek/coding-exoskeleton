# Exoskeleton Skill Index

本文件由 Exoskeleton Claude Code 安装器生成，用于说明 `.claude/skills/` 中技能的组织方式。

## 目录约定

- `shared/`：通用技能，适用于所有技术栈。
- `backend-common/`：后端通用技能。
- `frontend-common/`：前端通用技能。
- `cola-java/`：Java / COLA 技术栈技能。
- `frontend-vue3/`：Vue3 技术栈技能。
- `frontend-react-umi/`：React Umi 技术栈技能。

## 使用约束

1. 执行流程前先读取项目根目录 `AGENTS.md`，确认 `techStack`、架构模式和当前激活规则。
2. 优先读取与当前阶段直接相关的技能，避免一次性加载无关技能。
3. 技术栈专属技能仅在 `AGENTS.md` 声明匹配技术栈时使用。
4. 个人作者配置、项目画像、交付记录等职责边界以核心流程文档为准。
