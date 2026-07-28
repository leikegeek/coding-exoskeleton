---
name: vue3-api-codegen
displayName: Vue 3 生成 API 接入
description: 在 Vue 3 项目中接入 swagger/codegen 生成 API、核对生成目录、临时补充接口或替换页面内请求时使用。强调不手改生成物和契约收敛。
triggers: ["Vue接口", "swagger生成", "codegen", "生成API", "team1api", "apiGenerate"]
autoTrigger: true
version: '1.0.0'
---

# Vue 3 生成 API 接入

## 前置检查

1. 读取 `AGENTS.md`，确认 `techStack == frontend-vue3`。
2. 读取项目脚本和已有 API 目录，确认生成命令、输出目录和统一 axios 注入方式。

## 接入流程

1. 优先使用已有生成 API 方法，不在页面重复封装同义请求。
2. 缺少接口时优先运行或建议运行项目 codegen 脚本。
3. 如任务必须先临时补充接口，放在项目允许的手写 API 区域，并注明后续由生成代码覆盖。
4. 页面层只做业务参数组装和展示转换；重复字段映射要收敛到小函数或既有工具。
5. 接入后核对空值、错误提示、分页、排序、筛选和导入导出 header。

## 禁止模式

- 长期手写生成目录内容。
- 页面内散落完整 URL 或重复请求 helper。
- 用 `any` 或类型断言绕过明显契约差异。

## 输出格式

1. API 来源与目录
2. 调用链调整
3. 字段映射策略
4. 临时例外说明
5. 回归建议
