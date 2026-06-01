---
name: backend-implementation-planning
displayName: 后端实施计划拆解
description: 将后端技术方案拆解为接口、应用服务、领域/业务逻辑、数据访问、消息/定时任务、迁移脚本和测试任务时使用。用于补充通用 implementation-planning 的后端归组口径。
triggers: ["后端任务拆解", "接口实现计划", "服务实现计划", "数据库迁移", "消息任务", "后端实施计划"]
autoTrigger: true
version: '1.0.0'
---

# 后端实施计划拆解

## 前置检查

1. 读取 `AGENTS.md`，确认 `techStack` 属于后端 profile（当前内置：`cola-java`）。
2. 不匹配时跳过本 skill，使用通用 `implementation-planning` 或对应前端 skill。
3. 先读取技术方案中的代码落点、数据与接口改动、测试与验收。

## 拆解维度

- 接口入口：Controller、API handler、RPC handler、GraphQL resolver 等。
- 应用编排：Service、UseCase、Command/Query handler、Executor 等。
- 业务逻辑：领域服务、策略、校验、状态流转、幂等。
- 数据访问：Repository、Gateway、DAO、Mapper、ORM、缓存、搜索、对象存储。
- 异步任务：消息消费者、定时任务、事件发布、重试和补偿。
- 基础设施：配置、迁移脚本、依赖、公共错误处理、观测埋点。
- 测试：单测、集成测试、契约测试和回归验证。

## 归组规则

1. 基础设施任务先行，业务编码任务按业务边界归组。
2. 同一接口主链路的入口、编排、数据访问和测试可归为一组。
3. 消息/定时任务与同步接口存在强依赖时标注前后顺序。
4. 前后端分离需求中，后端 API 契约组应先于前端联调组。
5. 跨模块集成、迁移验证和回滚演练单独标为顺序执行组。

## 输出格式

1. 后端任务清单
2. 基础设施任务
3. 编码任务分组
4. 组间契约与依赖
5. 测试策略
