---
name: cola-naming
displayName: COLA 命名规范指导
description: 在 COLA 架构项目中，指导新类、接口、方法的命名，确保符合项目已有的命名约定。
triggers: ["命名规范", "类命名", "COLA命名"]
autoTrigger: false
version: '1.0.2'
---

# COLA 命名规范指导

## 技能目标
当用户需要在 COLA 架构项目中创建新类、接口或方法时，指导其使用正确的命名约定，与项目已有风格保持一致。

## 前置检查：技术栈适用性

在执行本 skill 之前，先检查项目的技术栈声明：

1. 读取项目根目录的 `AGENTS.md` 文件
2. 检查 frontmatter 中的 `techStack` 字段或"技术栈"章节
3. **如果技术栈为 `cola-java`**：继续执行本 skill
4. **如果技术栈不是 `cola-java`**：跳过本 skill，不应用 COLA 命名规范
5. **如果 `AGENTS.md` 不存在**：跳过本 skill，建议用户先执行 `/init`

## 命名规则速查

### 按层级

| 层级 | 类型 | 命名规则 | 路径/说明 | 示例 |
|------|------|----------|-----------|------|
| adapter | API Controller | XxxApiController | `controller/api/模块名/`，URL `/api/` | AiTitleBuildApiController |
| adapter | 页面 Controller | XxxController | `controller/web/模块名/`，URL `/web/` | AmazonStockBlackController |
| adapter | 内部服务入口 | XxxCenterController | `controller/center/模块名/`，URL `/center/` | AmazonFbaStockOutViewController |
| adapter | MQ 消费者 | XxxConsumer | `consumer/模块名/` | AdjustPriceStrategyConsumer |
| adapter | 定时任务 | XxxScheduler | `scheduler/模块名/` | InventorySyncScheduler |
| application | 命令执行器 | XxxCmdExe | `executor/模块名/cmd/` | AdjustPriceBatchCmdExe |
| application | 查询执行器 | XxxQryExe | `executor/模块名/qry/` | FbaAsinDataQryExe |
| application | 服务编排 | XxxService | `service/模块名/` | OrderService |
| infrastructure | Gateway 接口 | IXxxGateway | `gateway/模块名/` | IAdjustPriceStrategyGateway |
| infrastructure | Gateway 实现 | XxxGateway | `gateway/模块名/impl/` | AdjustPriceStrategyGateway |
| infrastructure | MyBatis Mapper | IXxxRepository | `repository/模块名/` | IOrderRepository |
| infrastructure | 数据对象 | XxxDO | `dataobject/模块名/` | OrderDO |
| infrastructure | 转换器 | XxxConvertor | `convertor/模块名/` | OrderConvertor |
| client | API 接口 | IXxxApi | `模块名/api/` | IAmazonFbaVineReasonsApi |
| client | 命令 DTO | XxxCmd / XxxQry | `模块名/command/` | AmazonFbaVineReasonsAddCmd |
| client | 返回 DTO | XxxDTO | `模块名/dto/` | AmazonFbaVineReasonsDTO |

### 通用规则
- 新增类名先匹配现有职责和目录，再决定后缀
- 避免使用模糊命名：Manager、Helper、UtilService
- 方法命名使用动词开头：findXxx、createXxx、updateXxx、deleteXxx
- 布尔方法使用 isXxx、hasXxx、canXxx

## 使用方式
在编码阶段，当需要创建新类时，参照以上规则确定命名。如果现有项目中有偏差（已有类名不符合规范），以项目已有风格为准，保持一致性。
