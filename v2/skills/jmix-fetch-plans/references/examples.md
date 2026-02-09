# Fetch Plans Usage Examples

## XML Definitions

### Inline in View XML
Recommended for view-specific data loading.

```xml
<instance id="orderDc" class="Order">
    <fetchPlan extends="_base">
        <property name="customer" fetchPlan="_instance_name"/>
        <property name="lines" fetchPlan="_base"/>
    </fetchPlan>
    <loader/>
</instance>
```

### In fetch-plans.xml
Useful for reusable fetch plans across the application.

```xml
<fetch-plans xmlns="http://jmix.io/schema/core/fetch-plans">
    <fetch-plan entity="Order" name="order-full" extends="_base">
        <property name="customer" fetchPlan="_base"/>
        <property name="lines" fetchPlan="_base">
            <property name="product" fetchPlan="_instance_name"/>
        </property>
    </fetch-plan>
</fetch-plans>
```

Requires setting the path to `fetch-plans.xml` in `jmix.core.fetch-plans-config` property.

## Programmatic Use

### Using DataManager with FetchPlanBuilder (Recommended)
Concise way to specify fetch plans directly in load operations.

```java
List<Order> orders = dataManager.load(Order.class)
    .query("select o from Order o")
    .fetchPlan(fpb -> fpb.addFetchPlan(FetchPlan.BASE).add("customer"))
    .list();
```

### Using FetchPlans Bean
Provides more granular control, especially for complex or nested plans.

```java
@Autowired
private FetchPlans fetchPlans;

public void loadWithPlan() {
    FetchPlan plan = fetchPlans.builder(Order.class)
        .addFetchPlan(FetchPlan.BASE)
        .add("customer", builder -> builder.addFetchPlan(FetchPlan.INSTANCE_NAME))
        .add("lines", FetchPlan.BASE)
        .build();

    List<Order> orders = dataManager.load(Order.class)
        .query("select o from Order o")
        .fetchPlan(plan)
        .list();
}
```

### Loading Partial Entities
Restrict loading to explicitly defined attributes.

```java
FetchPlan partialPlan = fetchPlans.builder(Order.class)
    .addAll("number", "date", "customer.name")
    .partial()
    .build();

List<Order> orders = dataManager.load(Order.class)
    .all()
    .fetchPlan(partialPlan)
    .list();
```

## JmixDataRepository
Fetch plans can be passed as parameters or referenced by name.

```java
public interface OrderRepository extends JmixDataRepository<Order, UUID> {
    
    // FetchPlan as the LAST parameter
    List<Order> findByStatus(OrderStatus status, FetchPlan fetchPlan);

    // Or by name (defined in fetch-plans.xml or built-in)
    List<Order> findByCustomer(Customer customer, String fetchPlanName);
    
    // Using @FetchPlan annotation
    @FetchPlan("order-full")
    List<Order> findByDateAfter(LocalDate date);
}
```

## N+1 Problem Prevention
Always fetch required associations in a single query instead of lazy-loading in a loop.

```java
// ❌ BAD: N+1 queries (one for orders, and one for each customer access)
List<Order> orders = dataManager.load(Order.class).all().list();
for (Order o : orders) {
    System.out.println(o.getCustomer().getName()); // Triggers extra query per order
}

// ✅ GOOD: Single query with JOIN
List<Order> orders = dataManager.load(Order.class)
        .fetchPlan(fpb -> fpb.addFetchPlan(FetchPlan.BASE).add("customer.name"))
        .list();
for (Order o : orders) {
    System.out.println(o.getCustomer().getName()); // Already loaded
}
```

## Unfetched Attributes
Attempting to access a local attribute not included in the fetch plan results in an `IllegalStateException`.

```java
// Load only 'number'
Order order = dataManager.load(Order.class)
    .id(orderId)
    .fetchPlan(fpb -> fpb.add("number"))
    .one();

String date = order.getDate().toString(); // Throws IllegalStateException
```
