---
name: react-umi-feature-delivery
displayName: React Umi 功能实现
description: 在 React Umi 2 + DVA + Ant Design 项目中新增或修改页面、列表、查询表单、弹窗、DVA model、业务组件和国际化文案时使用。
triggers: ["Umi功能", "React页面", "DVA", "Ant Design", "查询表单", "React弹窗"]
autoTrigger: true
version: '1.0.0'
---

# React Umi 功能实现

## 前置检查

1. 读取 `AGENTS.md`，确认 `techStack == frontend-react-umi`。
2. 不匹配时跳过本 skill，使用对应 profile 或通用前端 skill。

## 工作流

1. 阅读 `config/router.config.js`、目标页面、相邻页面、model、service、utils/request 和样式。
2. 判断列表/表单/弹窗是否已有扩展组件或同域模式可复用。
3. 新增状态前确认是否应进 DVA model，还是只保留为页面局部状态。
4. 用户可见文案接入国际化；样式默认 Less + CSS Modules。
5. 保持 hash 路由、菜单权限、请求注入字段和 IE11 兼容。

## 专项检查

- 是否误改生成目录 `src/pages/.umi/`。
- 是否新增裸请求或硬编码后端域名。
- 是否在普通业务页直接混用 `antd` 与 `antd4`。
- 查询、分页、排序、弹窗关闭刷新是否与同域页面一致。

## 输出格式

1. Umi/DVA 影响点
2. 复用的现有模式
3. 实现方案
4. 风险点
5. 回归清单
