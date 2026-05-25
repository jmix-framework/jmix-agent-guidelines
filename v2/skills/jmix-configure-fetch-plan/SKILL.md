---
name: jmix-configure-fetch-plan
description: Configure or audit Jmix fetch plans in XML views, fragments, DataManager loads, repositories, and entity events when loading references, avoiding N+1 queries, fixing unfetched attribute errors, or tuning data loading.
---

# Configure Fetch Plan

Use this skill when a task changes what entity attributes or references are loaded.

## Steps

1. Identify every property read by the view, service, listener, renderer, mapper, or assertion.
2. Start with `_base` unless there is a measured reason to load a partial entity.
3. Add reference properties explicitly when a loaded entity is detached or when a list/grid displays reference attributes.
4. For list views, include only references and scalar columns that are displayed or used by renderers/actions.
5. For detail views and compositions, include edited reference properties and child collections that the form or grid uses.
6. For service/listener code, add a fluent `DataManager.fetchPlan(...)` or named plan before reading references after load.
7. Avoid deep nested collections; prefer a second focused load when a graph becomes wide or multi-collection.
8. Check custom fetch plans against every `getX()` call after load.
9. Compile or run the smallest test that exercises the load path.

## XML Pattern

```xml
<collection id="ordersDc" class="com.company.app.entity.Order">
    <fetchPlan extends="_base">
        <property name="customer" fetchPlan="_instance_name"/>
        <property name="lines" fetchPlan="_base"/>
    </fetchPlan>
    <loader id="ordersDl" readOnly="true">
        <query><![CDATA[select e from Order e]]></query>
    </loader>
</collection>
```

Use the JPA/Jmix entity name in JPQL, not the database table name.

## DataManager Pattern

```java
List<Order> orders = dataManager.load(Order.class)
        .query("select e from Order e")
        .fetchPlan(fp -> fp.addFetchPlan(FetchPlan.BASE)
                .add("customer", FetchPlan.INSTANCE_NAME))
        .list();
```

For an event listener that reads a reference:

```java
Order order = dataManager.load(event.getEntityId())
        .fetchPlan(fp -> fp.addFetchPlan(FetchPlan.BASE)
                .add("customer", FetchPlan.BASE))
        .one();
```

## Partial Entity Audit

Use a partial fetch plan only when it is intentionally narrower than `_base`:

- The loaded entity is wide or the result list is large.
- Every local property read later is listed in the plan.
- UI components, renderers, validators, and mappers do not access omitted attributes.
- Tests cover the path that previously caused the performance issue or unfetched attribute error.

## Shared Plans

Prefer inline XML or fluent `DataManager` fetch plans for feature-local needs.

Use `fetch-plans.xml` only when the same complex graph is reused in multiple places. If you add a shared plan, configure or verify the project's `jmix.core.fetch-plans-config` property and keep the name stable.

## Forbidden

- `FetchType.EAGER` to solve loading problems.
- Reading local attributes omitted from a partial fetch plan.
- Loading references inside loops when a fetch plan can load them with the root query.
- Deep multi-collection graphs in a single list load.
- Using fetch plans as a security boundary.
- `@Table` names in JPQL queries.
- Shared named fetch plans for one-off local view needs.
