---
name: react-umi-request-routing
displayName: React Umi 请求与路由核对
description: 在 React Umi 项目中修改路由、菜单权限、代理前缀、request 封装、服务模块、下载导出或全局请求参数注入时使用。
triggers: ["Umi路由", "router.config", "request封装", "代理前缀", "菜单权限", "React接口"]
autoTrigger: true
version: '1.0.0'
---

# React Umi 请求与路由核对

## 前置检查

1. 读取 `AGENTS.md`，确认 `techStack == frontend-react-umi`。
2. 修改请求或路由前，先读 `config/router.config.js`、`config/config.js`、`src/global.js` 和 `src/utils/request`。

## 核对流程

1. 路由变更：确认 hash URL、菜单 path、权限字段、重定向和 `noNeedPermission`。
2. 请求变更：确认代理前缀、`pathRewrite`、runtime `urlPrefix` 和全局参数注入。
3. 服务变更：优先新增到 `src/services/modules/`，函数命名与同域保持一致。
4. 下载导出：使用项目文件请求 helper，保留鉴权、loading、错误处理和文件类型约定。
5. 广告或 campaign 类接口：核对 `src/global.js` 中按 hash 改写请求路径的逻辑。

## 风险提示

- 路由 path 与后端菜单不匹配会导致 403 或跳转到其它菜单。
- 删除或改名全局注入字段可能影响后端审计、语言、站点或菜单上下文。
- 代理前缀和 runtime override 不一致会造成本地可用、环境失败。

## 输出格式

1. 路由/请求影响范围
2. 配置核对结果
3. 修改方案
4. 兼容性风险
5. 回归路径
