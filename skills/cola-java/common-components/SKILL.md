---
name: common-components
displayName: cola-java 公共组件使用指南
description: 在 cola-java 项目中使用公共组件（缓存、分布式锁、MongoDB、MQ、XxlJob、异步工具、重试、Gateway 模板、Executor 模板）时，参考本指南选择正确的 API 和模式。
triggers: ["缓存", "分布式锁", "MongoDB", "MQ", "消费者", "XxlJob", "定时任务", "异步", "AsyncUtils", "重试", "Gateway模板", "Executor模板", "bulkInsert", "bulkUpsert"]
autoTrigger: true
version: '1.0.2'
---

# cola-java 公共组件使用指南

## 技能目标

当用户在 cola-java 项目中涉及缓存、锁、消息队列、MongoDB、定时任务、异步批处理、重试等场景时，指导其使用项目统一的公共组件 API，避免重复造轮子或引入不一致的实现方式。

## 前置检查：技术栈适用性

1. 读取项目根目录的 `AGENTS.md` 文件
2. 检查技术栈声明是否为 `cola-java`
3. 不匹配或不存在时跳过本 skill

## Redis 缓存

### @ZnyfCached 注解式缓存
```java
// cacheScope：CacheScope.REMOTE（Redis）/ LOCAL（Caffeine）/ BOTH（双缓存）
@ZnyfCached(name = "product:detail", key = "#{id}", expireInSeconds = 1800,
            cacheScope = CacheScope.REMOTE)
public ProductDTO getProductById(Long id) {
    return productGateway.getById(id);
}
```

### @ZnyfLock 注解式分布式锁
```java
@ZnyfLock(name = "order:create", key = "#{cmd.userId}_#{cmd.productId}", expireInSeconds = 120)
public Result<Void> createOrder(CreateOrderCmd cmd) { ... }
```

### 编程式分布式锁（动态 key 或条件加锁）
```java
@Resource
private ILockGateway lockGateway;

boolean locked = lockGateway.autoLock(OrderDO.class,
        cmd.getUserId() + "_" + cmd.getProductId(),
        () -> orderGateway.create(cmd));

if (!locked) {
    throw new BusinessException("操作过于频繁，请稍后重试");
}
```

## 分库分表（Sharding-JDBC）

### Gateway 标准实现
```java
// 接口继承 IServiceRepository
public interface IOrderGateway extends IServiceRepository<OrderDO> {
}

// 实现类加 @DS 指定数据源，继承 ServiceRepository 获得 bulkInsert/bulkUpsert 等方法
@DS("db-sharding")
@Component
public class OrderGateway extends ServiceRepository<IOrderRepository, OrderDO>
        implements IOrderGateway {
}
```

### 分表策略枚举（shardingRuleCode）
| 策略值 | 分表规则 |
|--------|---------|
| `amazon-site-code` | 按 Amazon 站点 |
| `hash-code` | 哈希值求余 |
| `number-code` | 数字值求余 |
| `year-month-code` | 按月 |
| `year-month-day-code` | 按天 |

### 批量操作
```java
orderGateway.bulkInsert(orders);
orderGateway.bulkUpsert(orders);
```

## MongoDB

### bulkUpsert 批量更新插入
```java
// filterFields：匹配条件字段；onlyUpdateFields：仅更新这些字段（null 表示全量更新）
gateway.bulkUpsert(products, List.of("sourceId", "sku"),
        List.of("priceInfo.price", "title"), null, true, "");
```

## RabbitMQ 消费者

标准实现参见 `mq-consumer.mdc` 规则，核心模式：
```java
@Component
public class XxxConsumer extends RabbitBaseHandler {

    @RabbitListener(queues = "queue_name", concurrency = "1")
    public void listener(Message message, Channel channel) {
        super.onMessage(message, channel, XxxDTO.class,
                mqModel -> processMessage(mqModel));
    }
}
```

## 定时任务（XxlJob）

### 按 Amazon 站点分片处理
```java
@XxlJob("syncAmazonDataTask")
public ReturnT<String> syncAmazonData() {
    int shardIndex = XxlJobHelper.getShardIndex();
    int shardTotal = XxlJobHelper.getShardTotal();
    List<String> siteList = AmazonSiteCodeEnum.findConditionSiteCode(
            site -> XXLShardingUtil.needProcess(shardIndex, shardTotal, site.getIndex())
    );
    siteList.forEach(this::processAmazonSite);
    return ReturnT.SUCCESS;
}
```

## 异步分批处理（AsyncUtils）

```java
// 将 skus 按每批 100 条并发处理，收集结果
List<String> result = AsyncUtils.doPartitionAsync(skus, 100,
        (params, allWrappers) -> params.stream()
                .map(this::processAndReturn)
                .collect(Collectors.toList()));
```

## 重试机制（RetryUtils）

```java
// 重试 3 次，每次间隔 1000ms
ProductDTO product = RetryUtils.retry(
        () -> amazonApiGateway.getProduct(asin), 3, 1000);
```

## 完整 Executor 模板

展示日志、参数校验、事务、异常处理的标准组合写法：
```java
@Component
@Slf4j
public class OrderCreateCmdExe {

    @Resource private IOrderGateway orderGateway;
    @Resource private IInventoryGateway inventoryGateway;

    @Transactional(rollbackFor = Exception.class)
    public Result<Long> execute(CreateOrderCmd cmd) {
        log.info("创建订单开始, userId={}, productId={}", cmd.getUserId(), cmd.getProductId());

        // 1. 参数校验
        if (cmd.getUserId() == null) throw new BusinessException("用户ID不能为空");
        if (cmd.getQuantity() == null || cmd.getQuantity() <= 0)
            throw new BusinessException("购买数量必须大于0");

        // 2. 业务校验
        InventoryDO inventory = inventoryGateway.getByProductId(cmd.getProductId());
        if (inventory == null || inventory.getStock() < cmd.getQuantity()) {
            throw new BusinessException("库存不足");
        }

        // 3. 写操作
        OrderDO order = new OrderDO();
        order.setUserId(cmd.getUserId());
        order.setProductId(cmd.getProductId());
        order.setQuantity(cmd.getQuantity());
        orderGateway.save(order);
        inventoryGateway.deduct(cmd.getProductId(), cmd.getQuantity());

        log.info("创建订单成功, orderId={}", order.getId());
        return Result.success(order.getId());
    }
}
```
