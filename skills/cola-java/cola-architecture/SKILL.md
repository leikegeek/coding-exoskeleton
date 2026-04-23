---
name: cola-architecture
displayName: COLA 架构方案设计
description: 针对 COLA 架构项目的架构方案设计，基于已有的 COLA 架构、技术栈和规范，设计符合项目约束的新功能或模块的架构方案。关注与现有系统的集成、核心流程设计、数据模型和关键实现细节。
triggers: ["架构方案", "架构设计", "系统设计", "COLA设计"]
autoTrigger: true
version: '1.0.2'
---

# COLA 架构方案设计

## 技能目标
当用户提出 COLA 架构项目的新功能或模块需求时，基于已有的 COLA 架构体系、技术栈和项目规范，引导并生成一份结构完整、符合约束的架构方案设计文档。

## 核心行为准则
**最重要的规则：必须严格遵守项目的现有技术栈、架构规范和约束条件。当你无法从对话上下文或已提供信息中推断出某个模版部分的内容时，你必须主动、明确地向用户提问，等待用户补充。**

### 信息缺失处理流程
1. **识别缺失**：在填充模版过程中，遇到信息空白时先识别关键缺失项。
2. **主动提问**：停止生成，直接向用户提问以获取必要信息。
3. **处理回复**：
   - 如果用户提供了信息：整合到对应部分，继续生成。
   - 如果用户未回复：在该部分标记为`[待补充：具体缺失信息]`。
   - 如果用户明确回复"不需要"或"略过"：删除整个相关小节或部分，并在必要时注明已省略。

## 前置检查：技术栈适用性

在执行本 skill 之前，先检查项目的技术栈声明：

1. 读取项目根目录的 `AGENTS.md` 文件
2. 检查 frontmatter 中的 `techStack` 字段或"技术栈"章节
3. **如果技术栈为 `cola-java`**：继续执行本 skill
4. **如果技术栈不是 `cola-java`**：跳过本 skill，提示：
   > 当前项目的技术栈为 {techStack}，COLA 架构方案设计 skill 不适用。将使用通用 `tech-design` skill 进行方案设计。
5. **如果 `AGENTS.md` 不存在**：退回到通用 `tech-design` skill，并建议用户先执行 `/init` 初始化项目画像

## 操作步骤
1. **确认需求**：确认需求目标、范围和与现有系统的关系。
2. **约束检查**：确保设计符合项目的技术栈、分层规范、命名约定等约束条件。
3. **结构化生成**：严格遵循下方模板的标题层级和结构生成文档，不得擅自改变核心章节顺序。
4. **交互式填充**：按顺序填充每个部分，一旦发现信息不足，立即提问澄清。
5. **最终输出**：生成完整 Markdown 文档，并总结设计决策。

## 文档输出约定
- 文件名格式：`SV-xxxxx-architecture.md`（关联需求编号）
- 保存到 `docs/design/` 目录
- 生成完成后，在对话中同步告知文档路径，并给出简短摘要

---

## 架构方案文档标准模版

补充规则：核心章节必须保留；标记为"如涉及""如需"的章节，仅在当前需求确实涉及时展开，不涉及时可整节省略。

# 架构方案：{需求名称}

## 一、需求理解与业务目标

### 1.1 业务价值
- **核心问题**：[这个功能要解决什么业务问题]
- **用户场景**：[在什么场景下使用，用户是谁]
- **成功指标**：[如何衡量这个功能的成功]

### 1.2 功能范围
- **包含功能**：[本次要实现的完整功能列表]
- **不包含功能**：[明确排除的功能边界]
- **与现有功能关系**：[与项目中已有功能的关系]

## 二、与现有系统集成设计

### 2.1 集成位置（基于简化版 COLA 分层架构）
```text
adapter 层新增：
  - controller/web/模块名/XxxController.java（前端页面，路径 /web/）
  - controller/api/模块名/XxxApiController.java（对外接口，路径 /api/）
  - controller/center/模块名/XxxCenterController.java（内部服务，路径 /center/）
  - consumer/模块名/XxxConsumer.java（MQ 消费者，如涉及）
  - scheduler/模块名/XxxScheduler.java（定时任务，如涉及）

application 层新增：
  - executor/模块名/cmd/XxxCmdExe.java（命令执行器）
  - executor/模块名/qry/XxxQryExe.java（查询执行器）
  - service/模块名/XxxService.java（服务编排）
  - convertor/模块名/XxxConvertor.java（MapStruct 转换器，如需）

client 层新增：
  - 模块名/api/IXxxApi.java（API 接口定义）
  - 模块名/command/XxxCmd.java / XxxQry.java（Command / Query DTO）
  - 模块名/dto/XxxDTO.java（返回 DTO）

infrastructure 层新增/修改：
  - gateway/模块名/IXxxGateway.java（Gateway 接口）
  - gateway/模块名/impl/XxxGateway.java（Gateway 实现，@DS + ServiceRepository）
  - repository/模块名/IXxxRepository.java（MyBatis Mapper 接口）
  - dataobject/模块名/XxxDO.java（数据库实体）
  - convertor/模块名/XxxConvertor.java（MapStruct DO↔DTO 转换器，如需）
  - mongodb/gateway/模块名/XxxMongoGateway.java（MongoDB Gateway，如涉及）
  - mongodb/dataobject/模块名/XxxMongoDO.java（MongoDB 数据对象，如涉及）
  - es/模块名/XxxEsGateway.java（Elasticsearch Gateway，如涉及）
```

### 2.2 数据流设计
### 2.3 依赖的现有组件

## 三、核心业务设计
### 3.1 业务流程
### 3.2 状态流转设计
### 3.3 关键业务规则

## 四、数据模型设计
### 4.1 表结构设计
### 4.2 数据源选择（如涉及多数据源）
说明使用哪个数据源（`db-mysql-auto-choose` / `db-sharding` / `db-sqlserver-write`），Gateway 的 `@DS` 注解值。
### 4.3 分库分表设计（如需）
说明分表策略（`amazon-site-code` / `year-month-code` / `hash-code` 等）、分片列、分片数量。
### 4.4 缓存设计（如涉及）
说明缓存范围（`CacheScope.REMOTE` / `LOCAL` / `BOTH`）、过期策略、缓存 key 规则。

## 五、核心逻辑设计
### 5.1 类设计
### 5.2 关键算法与逻辑
### 5.3 事务管理

## 六、非功能性设计
### 6.1 性能设计
### 6.2 可用性设计
### 6.3 可扩展性设计

## 七、消息队列设计（如涉及）
## 八、分布式事务设计（如涉及）
## 九、安全与权限设计
## 十、可观测性设计
## 十一、部署与回滚
## 十二、测试策略
## 十三、后续演进

---

## 附录：架构决策记录

1. **ADR-001：采用现有 COLA 架构扩展**
   - 状态：已确认
   - 背景：新功能需要在现有项目中开发
   - 决策：遵循现有分层架构、技术栈和规范
   - 后果：确保与现有系统一致性和可维护性
