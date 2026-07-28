---
name: react-antd-compatibility
displayName: React Ant Design 兼容实现
description: 在 Ant Design 3.x 为主、局部 antd4 隔离共存的 React 项目中处理表单、弹窗、表格、样式、prefixCls 和组件兼容问题时使用。
triggers: ["antd3", "antd4", "Ant Design兼容", "prefixCls", "React表单", "React表格"]
autoTrigger: true
version: '1.0.0'
---

# React Ant Design 兼容实现

## 前置检查

1. 读取 `AGENTS.md`，确认 `techStack == frontend-react-umi`。
2. 阅读当前模块相邻 Ant Design 用法，确认是否已有 antd4 隔离封装。

## 实现流程

1. 默认使用当前模块已经采用的 Ant Design 版本和组件封装。
2. 若必须使用 antd4，只能接入已有隔离组件或新增隔离封装，并保留 scoped `prefixCls`。
3. 表单校验、弹窗确认、表格分页和 loading 行为与相邻页面保持一致。
4. 样式写入 CSS Modules 或既有 less 文件，避免新增全局污染。
5. IE11 目标项目中，确认组件和样式能力已有兼容处理。

## 回归重点

- v3/v4 样式是否互相污染。
- Form 校验、默认值、重置和提交状态是否一致。
- Modal 关闭、销毁、二次打开是否残留状态。
- 表格分页、固定列、滚动、空态和 loading 是否正常。

## 输出格式

1. 使用的 Ant Design 版本路径
2. 兼容隔离策略
3. 表单/弹窗/表格行为说明
4. 样式影响范围
5. 回归清单
