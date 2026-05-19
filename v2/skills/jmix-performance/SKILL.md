---
name: jmix-performance
description: Performance pitfalls in Jmix applications that are invisible on small datasets but cause severe degradation or outages in production. Use when loading entities with relationships, configuring data containers in views, writing JPQL, implementing background jobs, or working with transactions.
---

# Performance Pitfalls

This skill covers patterns that compile correctly and work fine on small test datasets but cause severe performance degradation — up to complete production outages — under real data volumes. Most of these issues produce no errors or warnings at development time.

See also: [jmix-fetch-plans](../jmix-fetch-plans/SKILL.md) for the full fetch plan API reference.

## When to Use

Use this skill when:
- Defining fetch plans for views or services
- Configuring data containers and loaders in view XML descriptors
- Loading entities with relationships using `DataManager`
- Writing JPQL queries
- Implementing background jobs or batch processing
- Writing `@Transactional` service methods

## Key Concepts

### 1. Reference Attribute Not in Fetch Plan (N+1)

**The most common cause of production performance issues in Jmix applications.**

EclipseLink performs a separate `SELECT` for each access to a reference attribute (`@ManyToOne`, `@OneToOne`, `@OneToMany`, `@ManyToMany`) that was not included in the fetch plan. Accessing such an attribute on N loaded entities triggers N additional queries. On a local database with 10 records this is imperceptible; on production with thousands of records under concurrent load it brings the server down.

EclipseLink does not throw an exception — it silently issues the extra query. The problem is only visible as performance degradation.

**In view XML (most common):**

```xml
<!-- WRONG: customer not in fetch plan, but referenced in column -->
<collection id="ordersDc" class="com.company.app.entity.Order">
    <fetchPlan extends="_local"/>
</collection>

<dataGrid dataContainer="ordersDc">
    <columns>
        <column property="customer.name"/>  <!-- triggers N SELECT queries -->
    </columns>
</dataGrid>
```

```xml
<!-- CORRECT: customer explicitly included -->
<collection id="ordersDc" class="com.company.app.entity.Order">
    <fetchPlan extends="_local">
        <property name="customer" fetchPlan="_instance_name"/>
    </fetchPlan>
</collection>
```

**In Java (DataManager):**

```java
// WRONG: customer not in fetch plan, accessed in loop
List<Order> orders = dataManager.load(Order.class)
        .all()
        .fetchPlan(FetchPlan.LOCAL)
        .list();
orders.forEach(o -> log.info(o.getCustomer().getName())); // N SELECT queries

// CORRECT: customer loaded with a JOIN
List<Order> orders = dataManager.load(Order.class)
        .all()
        .fetchPlan(fpb -> fpb
                .addFetchPlan(FetchPlan.LOCAL)
                .add("customer", FetchPlan.INSTANCE_NAME))
        .list();
```

**Diagnosing in development:** Enable `jmix.eclipselink.disable-lazy-loading=true` in `application-local.properties`. With this setting, accessing an unfetched reference attribute throws `IllegalStateException` immediately instead of silently issuing a query — making the problem visible in tests before it reaches production. The property is marked `@Experimental` and defaults to `false`.

**Fetch mode guidance:**

| Relationship | Recommended fetch mode | Result |
|---|---|---|
| `@ManyToOne`, `@OneToOne` | `JOIN` (default AUTO) | Single SQL JOIN |
| `@OneToMany`, `@ManyToMany` | `BATCH` | Single `IN (...)` query |
| any | `UNDEFINED` | Separate SELECT per instance — never use |

### 2. Duplicate Loading via DataLoadCoordinator

`DataLoadCoordinator` manages a dependency tree of loaders: when its trigger fires, it loads the root loader and cascades to all dependent loaders. Explicitly loading any loader in this tree from the view controller causes the entire affected branch to load twice.

Three trigger points: explicit `loadAll()` or root loader call in `BeforeShowEvent`; child loader call in `ItemChangeEvent` of the master container; any load call in `InitEvent` (fires before `BeforeShowEvent`, so the coordinator reloads afterward).

**Important:** calling the root loader explicitly triggers the full cascade. In a three-level chain `customersDl → ordersDl → orderLinesDl`, a redundant call to `customersDl.load()` doubles all three queries, not just one.

**Correct approach:** let the coordinator handle all loading. To set loader parameters before loading, use `setParameter()` in `BeforeShowEvent` without calling `.load()` — the coordinator will call it with the parameters already set.

### 3. Duplicate Loading with GenericFilter

`GenericFilter.apply()` sets conditions on the bound loader and calls `load()` internally. `DataLoadCoordinator` with `configureFlexibleFilter` intercepts the Apply action and does the same automatically. Combining these with explicit load calls causes a duplicate query on every filter interaction — not just on screen open.

Three patterns that cause this:

**B1 — `configureFlexibleFilter` in coordinator + explicit load in code:**
```xml
<genericFilter id="filter" dataLoaderId="customersDl"/>
<dataLoadCoordinator id="dlc">
    <configureFlexibleFilter dataLoader="customersDl" component="filter"/>
</dataLoadCoordinator>
```
```java
// WRONG: coordinator already handles Apply — this fires twice per user interaction
@Subscribe("filter")
public void onFilterApply(GenericFilter.FilterApplyEvent event) {
    customersDl.load();
}
```

**B2 — `filter.apply()` followed by `loader.load()`:**
```java
// WRONG: apply() already calls load() internally
genericFilter.apply();
customersDl.load(); // redundant
```

**B3 — `filter.apply()` in `BeforeShowEvent` with coordinator present:**
```java
// WRONG: coordinator fires on BeforeShowEvent too
@Subscribe
public void onBeforeShow(BeforeShowEvent event) {
    genericFilter.apply();
}
```

**Correct approach:** Let the coordinator manage loading entirely. To set default filter conditions before the first load, set them on the condition objects directly without calling `apply()` or `load()` — the coordinator will pick them up when it fires.

### 4. DataManager.load() Inside a DataGrid Column Renderer

Column renderers are called by the framework for every row in the DataGrid — on screen open, page change, sort, and refresh. A `DataManager.load()` call inside a renderer issues N separate database queries per grid render. Unlike pitfall #1, the developer explicitly writes the load call and may not realize it executes in a per-row loop.

Applies to any form of renderer — lambda in `addColumn()`, `@Install(subject = "renderer")`, and `addComponentColumn()`:

```java
// WRONG: DataManager.load() called for every row on every grid render
ordersDataGrid.addColumn(order -> {
    return dataManager.load(Customer.class)
            .id(order.getCustomer().getId())
            .one()
            .getFullName();
});
```

**Correct approach:** include the required data in the collection container's fetch plan so it is already available when the renderer runs:

```xml
<collection id="ordersDc" class="com.company.app.entity.Order">
    <fetchPlan extends="_local">
        <property name="customer" fetchPlan="_instance_name"/>
        <property name="status" fetchPlan="_instance_name"/>
    </fetchPlan>
</collection>
```
```java
// No database call — data already loaded
ordersDataGrid.addColumn(order -> order.getCustomer().getFullName());
```

### 5. Initializing @OneToMany/@ManyToMany Collection with new ArrayList<>()

EclipseLink implements lazy loading for collections using its own `IndirectList` proxy. To set this proxy, EclipseLink expects the field to be `null`. If the field is already initialized with `new ArrayList<>()`, EclipseLink either forces an immediate load for every entity instance created (N entities = N extra queries inside the ORM layer), or leaves the field as a plain empty list (silent data loss).

Initialization in a `@PostConstruct` method is worse: it may execute **after** EclipseLink has already set its proxy, replacing it with a plain `ArrayList`.

```java
// WRONG — field initializer
@OneToMany(mappedBy = "order")
private List<OrderLine> lines = new ArrayList<>(); // breaks EclipseLink proxy

// WRONG — @PostConstruct
@PostConstruct
private void init() {
    lines = new ArrayList<>(); // may replace EclipseLink proxy after it was set
}

// CORRECT — Java: no initializer
@OneToMany(mappedBy = "order")
private List<OrderLine> lines;
```

```kotlin
// WRONG — Kotlin
@OneToMany(mappedBy = "order")
private var lines: List<OrderLine> = ArrayList()

// CORRECT — Kotlin: use NotInstantiatedList as a marker for EclipseLink
@OneToMany(mappedBy = "order")
private var lines: List<OrderLine> = NotInstantiatedList()
```

### 6. Constant hashCode() on Entities Without a @JmixGeneratedValue UUID Field

Jmix computes `hashCode()` via `JmixEntityEntry`. For entities with a UUID `@Id` annotated with `@JmixGeneratedValue`, the UUID is generated immediately on `new Entity()`, so `hashCode()` is always unique and stable.

For entities with numeric (`Long`, `Integer`) or user-assigned identifiers, the ID is `null` at object creation time (the database or user assigns it later). `NullableIdEntityEntry.hashCode()` therefore returns the constant `111`. **All instances of such an entity share the same hashCode**, causing `HashSet`, `HashMap`, and all hash-based collections to degenerate — every object lands in the same bucket, turning O(1) lookups into O(n).

```java
// WRONG — no UUID field: hashCode() == 111 for every instance
private Long id;

// CORRECT — add a UUID field with @JmixGeneratedValue
@JmixGeneratedValue
@Column(name = "UUID", nullable = false, updatable = false)
private UUID uuid;
```

The Jmix Gradle plugin detects the `@JmixGeneratedValue` UUID field during bytecode enhancement and implements `EntityEntryHasUuid` — `hashCode()` uses the UUID instead of the constant.

**Always add a `@JmixGeneratedValue UUID` field to entities with numeric or user-assigned identifiers.**

### 7. Over-fetching with _base in List Views

`_base` loads **all** local attributes of an entity, all `@InstanceName` attributes, and all embedded objects. In a list view where a DataGrid displays only a few columns, this transfers far more data from the database than needed. The overhead grows with the number of entity attributes and the number of rows.

**Rule for list views:** define an explicit fetch plan containing only the attributes actually displayed in the DataGrid columns, used in filters, or required for sorting. Do not use `_base` as a default for collection containers in list views.

```xml
<!-- WRONG — loads all 35 attributes of Order for a 4-column grid -->
<collection id="ordersDc" class="com.company.app.entity.Order">
    <fetchPlan extends="_base"/>
</collection>

<!-- CORRECT — only what the view actually uses -->
<collection id="ordersDc" class="com.company.app.entity.Order">
    <fetchPlan>
        <property name="number"/>
        <property name="date"/>
        <property name="amount"/>
        <property name="status"/>
        <property name="customer" fetchPlan="_instance_name"/>
    </fetchPlan>
</collection>
```

`_base` remains appropriate for detail views (editing a single entity) where most attributes are displayed and edited.

### 8. @Lob Fields: Three Hidden Problems

**8.1 — `@Basic(fetch=FetchType.LAZY)` is silently overridden to EAGER**

Jmix's `FetchTypeMappingProcessor` forces all basic (scalar) fields to EAGER at the EclipseLink mapping level. `@Basic(fetch = FetchType.LAZY)` on a `@Lob` field is ignored — a `WARN` is logged but the field is still loaded eagerly.

```java
// WRONG — annotation is overridden, field always loads eagerly
@Lob
@Basic(fetch = FetchType.LAZY)
@Column(name = "CONTENT")
private byte[] content;
```

The only way to avoid loading a `@Lob` field is to exclude it from the fetch plan.

**8.2 — `_base` always loads all `@Lob` fields**

Since `_base` includes all local attributes and `@Lob` fields cannot be made lazy, using `_base` in a list view loads all `@Lob` data for every row. Define an explicit fetch plan that excludes `@Lob` fields not needed for display — same approach as pitfall #7.

**8.3 — `DISTINCT` + CLOB fails on Oracle**

Oracle does not support `DISTINCT` on CLOB columns. If a JPQL query uses `DISTINCT` (or Jmix generates it for JOIN deduplication) and the entity has a `@Lob String` field, the query will fail on Oracle with a database error.

```java
// WRONG — fails on Oracle if Document has @Lob String body
"select distinct d from Document d join d.tags t where t.name = :tag"

// CORRECT — use EXISTS to avoid DISTINCT
"select d from Document d where exists (select 1 from d.tags t where t.name = :tag)"
```

### 9. FetchMode: Silent Overrides and Non-Obvious Behavior

FetchMode controls how EclipseLink executes queries for relationship attributes in a fetch plan. Incorrect or misunderstood FetchMode choices lead to silent query explosions, Cartesian-product-sized result sets, or attributes silently not loaded.

**Background — four modes:**

| Mode | Effect |
|---|---|
| `AUTO` | Jmix chooses: JOIN for @ManyToOne/@OneToOne, BATCH for @OneToMany/@ManyToMany |
| `JOIN` | SQL `LEFT OUTER JOIN` — loads in one query |
| `BATCH` | Single `IN (...)` query per collection — safe for large sets |
| `UNDEFINED` | Falls through to JPA default (EclipseLink lazy loading), NOT hard exclusion |

**9.1 — UNDEFINED does not exclude the attribute; it triggers JPA lazy loading**

`FetchMode.UNDEFINED` is often assumed to mean "don't load this". It does not. EclipseLink issues a separate `SELECT` on first access — the same N+1 behavior as pitfall #1. Child attributes nested under an UNDEFINED parent are also silently skipped from the fetch group.

```xml
<!-- WRONG — UNDEFINED triggers lazy SELECT on access, child attributes skipped -->
<property name="department" fetchMode="UNDEFINED">
    <property name="location"/>  <!-- silently excluded from fetch group -->
</property>
```

**9.2 — Multiple JOINs on collection attributes are silently converted to BATCH**

EclipseLink cannot join multiple collections without a Cartesian product. Jmix's `FetchGroupManager` detects this and silently replaces all collection JOINs with BATCH. Explicit `fetchMode="JOIN"` on a `@OneToMany`/`@ManyToMany` attribute is silently ignored when more than one such attribute is joined.

```xml
<!-- Both will execute as BATCH, not JOIN, despite the explicit annotation -->
<property name="orderLines" fetchMode="JOIN"/>
<property name="tags" fetchMode="JOIN"/>
```

**9.3 — JOIN on @OneToMany is removed for single-entity loads**

When loading a single entity by ID (`DataManager.load(...).id(...)`), Jmix's `FetchGroupManager` strips JOIN hints from `@OneToMany` attributes and falls back to a separate query. This is intentional (avoids inflating the result set for a single entity) but means explicit `fetchMode="JOIN"` on a collection has no effect in detail views.

**9.4 — AUTO inheritance: parent FetchMode propagates to nested attributes**

The AUTO mode is inherited down the fetch plan tree:
- A parent attribute with `BATCH` causes all its child AUTO attributes to also use BATCH.
- A parent attribute with `UNDEFINED` causes all nested child attributes to be skipped from the fetch group entirely — not just the parent.
- `IS NULL`/`IS NOT NULL` conditions on a relationship remove it from the JOIN.

```xml
<!-- steps loaded via BATCH (AUTO on @OneToMany); department loaded via JOIN (AUTO on @ManyToOne) -->
<instance id="userDc" class="com.company.onboarding.entity.User">
    <fetchPlan extends="_base">
        <property name="department" fetchPlan="_base"/>
        <property name="steps" fetchPlan="_base"/>
    </fetchPlan>
    <loader/>
    <collection id="stepsDc" property="steps"/>
</instance>
```

In this example `steps` is `@OneToMany` → AUTO resolves to BATCH → a single `IN (...)` query is issued for steps when the user entity loads. This is correct behavior and requires no change.

**9.5 — BATCH on @ManyToOne/@OneToOne is suboptimal**

For to-one relationships, BATCH issues one `IN (...)` per collection of parent IDs instead of a single JOIN. For small to-one relationships this is less efficient than the default JOIN. Avoid explicit `fetchMode="BATCH"` on `@ManyToOne`/`@OneToOne` attributes; rely on AUTO.

**Correct approach:**

- Rely on AUTO for most cases — it picks JOIN for to-one, BATCH for to-many.
- Override to explicit BATCH only when a specific to-one has many distinct values and JOIN produces too wide a result set.
- Never use UNDEFINED on attributes you intend to load.
- Do not force JOIN on `@OneToMany`/`@ManyToMany` — it is ignored when multiple collections are present, and removed on single-entity loads.

### 10. Locking Strategy Pitfalls

Jmix provides two concurrency control mechanisms:

- **Optimistic locking (`@Version`):** standard JPA. A `version` column is incremented on each UPDATE. If another user saved first, EclipseLink throws `OptimisticLockException`; Jmix FlowUI catches it and shows a notification. No blocking — concurrent reads and writes proceed freely until commit.
- **Pessimistic locking (`@PessimisticLock`):** the `jmix-pessimisticlock` add-on. When a user opens a detail view, `StandardDetailView` acquires a lock via `LockManager`. If already locked, the view opens read-only with a notification. Lock is released on view close. A Quartz job (default: every minute) cleans up expired locks.

**Critical technical fact:** `@PessimisticLock` is **application-level only** — no `SELECT FOR UPDATE`, no database row locks. Locks are stored in a Spring Cache named `"jmix-locks-cache"` (default: in-memory).

**Multi-node deployment without distributed cache (silent failure in production)**

The in-memory cache exists independently on each JVM. User A on node 1 acquires a lock — it is only visible in node 1's cache. User B whose request reaches node 2 sees an empty cache and acquires the same lock. The pessimistic lock silently provides **no protection** in a clustered deployment.

**Jmix cache architecture:** all built-in framework caches — pessimistic lock (`jmix-locks-cache`), query cache (`jmix-eclipselink-query-cache`), security (`resource-roles-cache`, `row-level-roles-cache`), dynamic attributes (`jmix-dyn-attr-cache`) — are registered in a single shared Spring `CacheManager` via `JCacheManagerCustomizer`. Configuring **one** JCache provider makes all of them cluster-aware simultaneously.

**Recommended solution: Hazelcast.** When a `HazelcastInstance` is on the classpath, Jmix auto-configures it for both cache distribution and cluster event propagation (application events, EclipseLink cache invalidation via Hazelcast topics). Without Hazelcast (or another distributed JCache provider), `@PessimisticLock` works correctly only in single-node deployments.

**Entity without `@Version` and without `@PessimisticLock`:** no concurrency protection at all. Concurrent edits silently overwrite each other (lost update). Always add `@Version` as the minimum level of concurrency control on editable entities.

### 11. @GeneratedValue(strategy=IDENTITY) Without @JmixGeneratedValue

Using JPA's standard `@GeneratedValue(strategy=GenerationType.IDENTITY)` on an entity PK without `@JmixGeneratedValue` has two hidden performance consequences.

**1. JDBC batch writes are not possible.**
With IDENTITY, the database generates the ID during INSERT. The JDBC driver must retrieve that key (`getGeneratedKeys()`) after each INSERT individually — it cannot group multiple INSERTs into a single batch. With `SaveContext` and N entities this means N separate database round-trips instead of one batch.

**2. Entity ID is null until saved.**
`metadata.create(MyEntity.class)` returns an entity with `id == null`. The ID appears only after `dataManager.save()`. This destabilizes `hashCode()` (returns the constant `111` — see pitfall #6) and breaks any code that uses the new entity as a reference before it is saved.

`@JmixGeneratedValue` on a numeric field uses Jmix's own sequence with an in-memory cache (default 100 values, `jmix.data.numberIdCacheSize`). The ID is assigned at `metadata.create()` time, before any database access. Only one DB call per 100 entities is needed to refill the cache.

```java
// WRONG — IDENTITY: ID null before save, no batch writes, unstable hashCode
@JmixEntity
@Entity
public class Order {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ID")
    private Long id;
}

// CORRECT — Jmix sequence: ID available immediately, 100x fewer DB calls
@JmixEntity
@Entity
public class Order {
    @Id
    @JmixGeneratedValue
    @Column(name = "ID")
    private Long id;
}
```

**`@GeneratedValue(strategy=TABLE)` is forbidden.** The TABLE strategy stores a counter in a separate table and acquires a row-level lock for every INSERT — all concurrent inserts serialize on that lock. Jmix uses this strategy nowhere; it is incompatible with any meaningful load.

### 12. UUID v4 vs v7: B-tree Index Fragmentation

UUID v4 is fully random — new values insert at arbitrary positions in the B-tree index, causing constant page splits. At scale, this produces severe index fragmentation: INSERT and UPDATE performance degrades significantly compared to a monotonically increasing key.

UUID v7 is time-ordered: each new value is larger than all previous values, so inserts always append to the rightmost leaf — no page splits. Index behavior is equivalent to `BIGINT IDENTITY`.

**Jmix UUID generation:**

`GeneratedIdEntityInitializer` (priority `HIGHEST_PRECEDENCE`) calls `EntityUuidGenerator.generate()` for every new entity:

- **Since Jmix 2.5.0 (default):** UUID v7 via `UuidCreator.getTimeOrderedEpoch()` (library `com.github.f4b6a3:uuid-creator`). Character at position 14 of the string representation is `'7'`.
- **Before Jmix 2.5.0 and when `jmix.core.legacy-entity-uuid=true`:** UUID v4 via `UuidProvider.createUuid()` using `ThreadLocalRandom` (not `SecureRandom`).

```properties
# WRONG: reverts to random UUID v4, causes B-tree fragmentation
jmix.core.legacy-entity-uuid=true
```

**Database column types for UUID fields:**

| Database | Column type | Size | Notes |
|---|---|---|---|
| PostgreSQL | `uuid` (native) | 16 bytes | Optimal |
| H2 | `uuid` (native) | 16 bytes | |
| MySQL / MariaDB | `varchar(32)` | 32-char hex | String comparisons; larger indexes |
| Oracle | `varchar2(32)` | 32-char hex | Same as MySQL |
| SQL Server | `uniqueidentifier` | 16 bytes | Native; stored via uppercase string |

On MySQL and Oracle, UUID is stored as a string — indexes are larger and slower than native 16-byte types. With UUID v4, fragmentation on `varchar` indexes is more pronounced because of lexicographic ordering of random strings.

**Upgrading from v4 to v7:** only affects newly created entities. Existing rows keep their v4 UUIDs — fragmentation improves gradually as new rows are written.

### 13. Predicate Row-Level Security Policies Disable Database Pagination

Jmix supports two types of row-level security policies:

- **JPQL policy** — adds a WHERE/JOIN clause to the JPQL query; filtering happens in the database; pagination works normally.
- **Predicate policy** — a Java lambda `∀x P(x)`: evaluated per entity in memory.

When at least one predicate policy is active for an entity, Jmix (`BaseDataStoreInMemoryCrudListener`, `AbstractDataStore`) does the following:

1. Detects the predicate via `hasInMemoryRead()` and sets `countByItems = true`.
2. **Removes pagination** — calls `setFirstResult(0)` and `setMaxResults(0)` — loads **all rows** from the database.
3. Applies the predicate to each loaded entity in memory.
4. Slices the result to the requested page (`loadListByBatches`).

Result: a request for page 1 of 50 rows actually reads the entire table. Invisible on 1 000 rows; full table scan on every user interaction at 100 000 rows.

```java
// WRONG: predicate policy — pagination is disabled for the entire Order table
@PredicateRowLevelPolicy(entityClass = Order.class, actions = {READ})
default RowLevelPredicate<Order> onlyMyOrders() {
    return order -> Objects.equals(order.getManager().getId(), currentUser().getId());
}

// CORRECT: JPQL policy — database-level filter, pagination works
@JpqlRowLevelPolicy(
    entityClass = Order.class,
    where = "{E}.manager.id = :current_user_id"
)
```

**Additional danger: database queries inside a predicate.** `RowLevelBiPredicate<T, ApplicationContext>` receives `ApplicationContext` as the second argument. Calling `applicationContext.getBean(DataManager.class).load(...)` inside the predicate issues a separate SELECT for each evaluated entity — N+1 inside the security layer, on top of the full table scan:

```java
// EXTREMELY WRONG: N SELECT queries inside a predicate called for every loaded row
default RowLevelBiPredicate<Order, ApplicationContext> orderVisible() {
    return (order, applicationContext) -> {
        DataManager dm = applicationContext.getBean(DataManager.class);
        List<Permission> perms = dm.load(Permission.class).all().list(); // called N times
        return perms.stream().anyMatch(p -> p.matches(order));
    };
}
```

**When predicate policies are justified:** the condition cannot be expressed in JPQL (complex business logic, external system call), or the table is permanently small (reference data with tens of rows).

**If JPQL cannot express the condition directly**, consider denormalization: add a field that captures the filtering criterion directly on the entity (e.g., `managerId`) so a simple JPQL `WHERE` clause becomes possible.

### 14. Missing readOnly on DataContext in List Views

`DataContext.merge()` performs a full recursive deep copy of the entity graph: creates a new instance via reflection, copies all properties, recursively traverses and copies all reference attributes and collections, and registers a `PropertyChangeListener` for change tracking. The cost scales with graph size.

In a list view the DataContext is never used for editing — the user only browses. If `readOnly="true"` is absent from the `<data>` element, Jmix creates a full `DataContextImpl` and calls `merge()` for every loaded entity. With a 50-row grid and a few reference attributes this means dozens of recursive graph traversals on every refresh. Invisible on small datasets; measurable CPU overhead in production under load.

`readOnly="true"` on `<data>` replaces `DataContextImpl` with `NoopDataContext`, whose `merge()` simply returns the entity unchanged — zero cost. Loaders receive `dataContext = null` and store results directly in containers without any copying.

Jmix Studio generates `<data readOnly="true">` by default for list views. The problem occurs when a developer removes this attribute — the fix is simply restoring it.

**Granular exclusion in detail views:** to exclude a single auxiliary loader (e.g., a reference list) from DataContext in a detail view without making the entire context read-only, set `readOnly="true"` on the individual `<loader>` element, or call `loader.setDataContext(null)` programmatically. This prevents merge for that loader's results only.

### 15. Inefficient Bulk Save: Post-Save Reload

`DataManager.save()` reloads every saved entity after the transaction commits — one `SELECT` per entity (`loadAllAfterSave` in `AbstractDataStore`). For N entities this is N additional queries on top of the actual INSERT/UPDATE. Invisible with 10 records; linear degradation on bulk operations.

**Two anti-patterns:**

**Pattern A — `dataManager.save(entity)` in a loop:**

```java
// WRONG: N transactions + N reload queries
for (Order order : orders) {
    dataManager.save(order);
}

// CORRECT: single transaction, no reload (Jmix 2.6+)
dataManager.saveWithoutReload(orders.toArray());

// CORRECT: single transaction, no reload (all versions)
SaveContext ctx = new SaveContext().setDiscardSaved(true);
orders.forEach(ctx::saving);
dataManager.save(ctx);
```

**Pattern B — `SaveContext` without `setDiscardSaved(true)` when the result is unused:**

```java
// WRONG: N reload queries execute even though EntitySet is never used
SaveContext ctx = new SaveContext();
orders.forEach(ctx::saving);
dataManager.save(ctx);

// CORRECT
SaveContext ctx = new SaveContext().setDiscardSaved(true);
orders.forEach(ctx::saving);
dataManager.save(ctx);
```

**When you do need the reloaded result**, use `saving(entity, fetchPlan)` to specify a minimal fetch plan per entity instead of its full fetch plan:

```java
SaveContext ctx = new SaveContext()
        .saving(order, fetchPlans.of(Order.class, "_instance_name"));
EntitySet saved = dataManager.save(ctx);
```

**Bypassing security** when not needed (background system jobs): `dataManager.unconstrained().save(ctx)` skips Row-Level Security and attribute access constraint checks, reducing overhead on large batches.

**Beyond ~1000 entities:** `SaveContext` uses JPA `em.persist`/`em.merge` per entity without JDBC batch write. For truly bulk inserts, use `JdbcTemplate.batchUpdate` directly — Jmix does not configure JDBC batching at the JPA level.

**API availability:**
- `setDiscardSaved(true)` and `saving(entity, fetchPlan)` — available since Jmix 1.0
- `dataManager.saveWithoutReload(entities...)` — added in Jmix 2.6.0

### 16. Excessive ComponentRenderer Columns in DataGrid

`ComponentRenderer` (`<componentRenderer/>` in XML) creates a full server-side Vaadin component for every cell in every visible row. With 50 rows and 3 `ComponentRenderer` columns → 150 server-side objects instantiated on every grid render (page open, page change, refresh), each with its own state and event listeners.

This increases server memory consumption (proportional to rows × columns), grid render time, and client-server synchronization payload. The effect is invisible on 10 dev rows; measurable under real pagination and concurrent sessions in production. **The page can load noticeably slowly** when many ComponentRenderers are present.

**For inline editing: use `InlineEditor` instead.** It creates edit components only for the row currently being edited — the rest render as plain text with no server-side components. Once editing completes, the components are destroyed.

**For display-only formatting:** use a text or HTML renderer instead of ComponentRenderer — no server object, no state.

```xml
<!-- WRONG: 50 rows × 3 columns = 150 server components per render -->
<column property="name"><componentRenderer/></column>
<column property="attr1"><componentRenderer/></column>
<column property="attr2"><componentRenderer/></column>

<!-- CORRECT for editable grid: InlineEditor -->
<columns>
    <column property="name"/>
    <column property="attr1"/>
    <column property="attr2"/>
</columns>
<!-- InlineEditor creates components only for the active row -->

<!-- CORRECT for display-only: text/HTML renderer, no server component -->
<column property="grade"><renderer/></column>
```

1–2 ComponentRenderer columns (e.g., an action button column) is acceptable. 3+ is a warning sign; all columns using ComponentRenderer is a clear performance problem.

### 17. GenericFilter Without Property Restrictions

`GenericFilter` lets users build arbitrary filter conditions including nested relationship attributes (e.g., `Properties → City → First name`). Each combination translates to a unique JPQL query with JOINs and WHERE clauses that the developer cannot predict or optimize for in advance.

Three compounding problems:

1. **Heavy queries on demand.** Users can accidentally construct conditions that scan non-indexed columns on large tables, chain multiple JOINs, or use leading-wildcard LIKE — all generating full table scans.

2. **Combinatorial explosion.** With N filterable attributes, the number of possible condition combinations grows as 2^N. Covering even a fraction with indexes is impractical. Nested relationship attributes multiply this further.

3. **Unpredictability.** The problematic query only appears when a specific user enters a specific combination on production data. It does not reproduce in dev or load tests.

**The root problem is at the business analysis level.** Technical mitigations reduce risk but do not eliminate it. The right question at design time is: **"Do users actually need this level of filter variability?"**

If users realistically need only 3–5 filter patterns, replace `GenericFilter` with explicit `PropertyFilter` components for each. The set of database queries becomes finite and known — indexes can be designed for them.

**When GenericFilter is genuinely required:**
- Explicitly configure a property whitelist to limit available filter attributes.
- Restrict nesting depth to prevent multi-join conditions on related entities.

```xml
<!-- RISKY: arbitrary queries including nested joins -->
<genericFilter id="filter" dataLoaderId="customersDl"/>

<!-- SAFER: explicit property whitelist -->
<genericFilter id="filter" dataLoaderId="customersDl">
    <properties include="name, email, status"/>
</genericFilter>

<!-- BEST when combinations are known: explicit PropertyFilter components -->
<propertyFilter property="status" operation="EQUAL" parameterName="status"/>
<propertyFilter property="name" operation="CONTAINS" parameterName="name"/>
```

## Usage

### Cluster Configuration

In a multi-node Jmix deployment, all built-in framework caches must use a shared distributed backend. All caches are registered in a single Spring `CacheManager` via `JCacheManagerCustomizer` beans — configuring **one** JCache provider makes all of them cluster-aware simultaneously.

**Caches that require cluster-awareness:**

| Cache name | Purpose |
|---|---|
| `jmix-locks-cache` | Pessimistic lock state |
| `jmix-eclipselink-query-cache` | EclipseLink query result cache |
| `resource-roles-cache` | Security resource role definitions |
| `row-level-roles-cache` | Row-level security role definitions |
| `jmix-dyn-attr-cache` | Dynamic attribute metadata |

**Recommended solution: Hazelcast.** When a `HazelcastInstance` is on the classpath, Jmix auto-configures it for:
1. **Distributed caching** — all JCache-registered caches above use the Hazelcast-backed provider.
2. **Cluster event channels** — `HazelcastApplicationEventChannelSupplier` publishes application events cluster-wide via topic `"jmix-cluster-application-event-topic"`.
3. **EclipseLink cache invalidation** — `EclipseLinkHazelcastChannelSupplier` propagates entity cache invalidation via topic `"jmix-eclipselink-topic"` so each node's L2 cache stays consistent.

Without a distributed provider, each JVM maintains its own independent in-memory caches. Pessimistic locks are invisible across nodes, security role changes on one node do not propagate to others, and EclipseLink L2 cache becomes stale after another node writes to the database.

**Redis:** Jmix has no native Redis integration at the framework level. Redis can be used as a JCache provider manually, but Hazelcast is the primary supported solution with built-in auto-configuration.

### Async Data Loading

When a view is heavy — many rows, complex queries, slow joins — loading everything synchronously blocks the UI thread and delays the page open. The user stares at a blank screen.

**The pattern:** open the view immediately (empty, instant), load data off the UI thread in the background, and populate the containers when done. **The screen opens at maximum speed with no data; data arrives shortly after.**

Jmix provides two APIs for this. The Javadoc is explicit about when to use each:

> *"Use `UiAsyncTasks` when you don't need to handle asynchronous task progress or display a modal dialog with a progress indicator. Otherwise, consider using `BackgroundTask`."*

**UiAsyncTasks (since Jmix 2.4.0):** CompletableFuture-based, functional API. No subclassing required. Only Security context is propagated (not full HTTP session attributes). No built-in spinner — add a `ProgressBar` manually if needed.

**BackgroundTask:** Abstract class with lifecycle overrides (`run()`, `done()`, `progress()`). Propagates Security context, HTTP session attributes, and Vaadin request. Has built-in progress dialog via `dialogs.createBackgroundTaskDialog()`. Supports progress reporting via `taskLifeCycle.publish()`.

### Decision guide

| | `UiAsyncTasks` | `BackgroundTask` |
|---|---|---|
| Available since | Jmix 2.4.0 | All versions |
| API style | CompletableFuture, functional | Abstract class with overrides |
| Progress dialog | No (manual if needed) | Yes — built-in |
| Progress reporting | No | Yes — `taskLifeCycle.publish()` |
| Security context | Yes | Yes |
| HTTP session attributes | No | Yes |
| Boilerplate | Minimal | Moderate |
| Use for | Simple data load, timers, cleanup | Batch with progress, operations needing full session |

**Common constraint for both:** use `DataManager` (thread-safe) inside the background method, never `DataLoader` (UI-bound). Do not access `DataContext` from the background thread — update containers in the result handler / `done()` which run on the UI thread.

### HikariCP Connection Pool

Spring Boot (and therefore Jmix) uses HikariCP as the default connection pool. Misconfiguration is a common source of production incidents that appear only under real load.

**The counterintuitive rule: more connections is not always better.**
Too many connections cause context switching overhead on the database server and can degrade throughput. Too few cause connection starvation — requests queue up waiting for a free connection.

**Sizing formula** (from HikariCP documentation):

```
pool_size = T_n × (C_m - 1) + 1
```

Where `T_n` is the number of concurrent threads making DB requests and `C_m` is the maximum number of simultaneous connections each thread holds at once (usually 1 for simple request/response flows, 2 if a transaction opens a nested transaction). For most Jmix applications with 10–20 concurrent users: `maximumPoolSize` in the range of 10–20 is a reasonable starting point.

**Key properties:**

| Property | Default | Notes |
|---|---|---|
| `maximumPoolSize` | 10 | Upper bound on DB connections. Raising to 100+ without analysis usually makes things worse. |
| `minimumIdle` | = maximumPoolSize | Connections kept warm at idle. Set equal to `maximumPoolSize` to avoid cold-start spikes. |
| `idleTimeout` | 600 000 ms | How long an idle connection above `minimumIdle` is kept before eviction. |
| `connectionTimeout` | 30 000 ms | How long a request waits for a pool connection before throwing an exception. |

**Jmix-specific consideration:** Vaadin server-push and long-running transactions hold a connection for the entire transaction duration. Slow queries (e.g., from an unconstrained `GenericFilter`) hold connections longer, reducing effective pool capacity for other requests. This means pool starvation can be a symptom of query performance problems elsewhere.

**Key monitoring metrics:**
- **Pending connection queue size** (`hikaricp.pending` in Micrometer) — the most important signal. Any sustained queue > 0 means the pool is undersized or queries are too slow.
- **Active connection time** — average time a connection is held; spikes indicate slow queries or long transactions.

**pgBouncer** is worth considering when:
- Multiple Jmix application instances connect to one PostgreSQL server.
- The sum of `maximumPoolSize` across all instances approaches PostgreSQL's `max_connections` limit.
- pgBouncer multiplexes many application-side connections through a smaller number of actual server connections in transaction-pooling mode.

```properties
# Example baseline for a moderately loaded Jmix app
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=20
spring.datasource.hikari.idle-timeout=300000
spring.datasource.hikari.connection-timeout=10000
```

## Forbidden

- Accessing reference attributes in loops without including them in the fetch plan.
- Using `FetchType.EAGER` on entity relationships — use fetch plans instead.
- `property="reference.field"` in view XML without `reference` present in the container's fetch plan.
- `FetchMode.UNDEFINED` on collection attributes.
- `getScreenData().loadAll()` or explicit `loader.load()` calls in view event handlers when `DataLoadCoordinator` manages those loaders.
- Loading coordinator-managed loaders in `InitEvent` — they will load again when the coordinator fires on `BeforeShowEvent`.
- `loader.load()` after `GenericFilter.apply()` — `apply()` already triggers the load internally.
- Explicit `filter.apply()` or `loader.load()` when `DataLoadCoordinator` is configured with `configureFlexibleFilter` for the same loader.
- `DataManager.load()` inside DataGrid column renderers (`addColumn()`, `addComponentColumn()`, `@Install(subject = "renderer")`) — include required data in the container's fetch plan instead.
- `= new ArrayList<>()` (or any concrete collection type) as a field initializer on `@OneToMany`/`@ManyToMany` fields — leave the field without an initializer in Java, use `NotInstantiatedList()` in Kotlin.
- Assigning `new ArrayList<>()` to a collection field inside a `@PostConstruct` method — may replace EclipseLink's lazy-loading proxy.
- Numeric or user-assigned `@Id` without a `@JmixGeneratedValue UUID` field — `hashCode()` returns a constant, degrading all hash-based collections to O(n).
- `_base` fetch plan in list view collection containers when the entity has many attributes — define an explicit fetch plan with only the attributes used in the view.
- `@Basic(fetch = FetchType.LAZY)` on `@Lob` fields — Jmix overrides it to EAGER; exclude the field from the fetch plan instead.
- `@Lob` fields in fetch plans used for list views — they are always loaded eagerly and transfer large data for every row.
- `DISTINCT` in JPQL queries on entities with `@Lob String` fields — fails on Oracle; use `EXISTS` instead of `JOIN + DISTINCT`.
- `fetchMode="UNDEFINED"` on any attribute you intend to load — it does not exclude the attribute, it triggers JPA lazy loading (N+1).
- `fetchMode="JOIN"` on `@OneToMany`/`@ManyToMany` attributes — silently converted to BATCH when multiple collections are present; ignored on single-entity loads.
- `fetchMode="BATCH"` on `@ManyToOne`/`@OneToOne` attributes — less efficient than the default JOIN; rely on AUTO instead.
- Multiple `ComponentRenderer` columns in a DataGrid — each creates a server-side Vaadin component per visible row; use `InlineEditor` for editable grids and text/HTML renderers for display-only columns.
- `GenericFilter` without a property whitelist on entities with many attributes or relationships — users can build arbitrary multi-join queries that cannot be indexed; prefer explicit `PropertyFilter` components when filter patterns are known.
- `@PessimisticLock` without a distributed JCache provider (Hazelcast) in multi-node deployments — the default in-memory cache is not shared between nodes; all Jmix framework caches (locks, query cache, security, dynamic attributes) silently lose cluster-awareness.
- `@GeneratedValue(strategy=IDENTITY)` on a numeric PK without `@JmixGeneratedValue` — entity ID is null until saved, JDBC batch writes are impossible, `hashCode()` is unstable (returns 111).
- `@GeneratedValue(strategy=TABLE)` anywhere — row-level lock on the sequence table for every INSERT; serializes all concurrent inserts.
- `jmix.core.legacy-entity-uuid=true` — reverts UUID generation to random v4, causing B-tree index fragmentation; remove this property to use UUID v7 (default since Jmix 2.5.0).
- `@PredicateRowLevelPolicy` on entities displayed in paginated grids — predicate policies disable database pagination, causing full table scans on every page load; use `@JpqlRowLevelPolicy` instead.
- `DataManager.load()` inside a `RowLevelBiPredicate` body — issues N additional SELECT queries (one per evaluated entity) on top of the full table scan; rewrite as `@JpqlRowLevelPolicy` or cache the lookup outside the predicate.
- Missing `readOnly="true"` on `<data>` in list views — `DataContext.merge()` executes a full recursive deep copy of every loaded entity; use `<data readOnly="true">` in all list views.
- `dataManager.save(entity)` in a loop — each call opens a separate transaction and reloads the entity; use `SaveContext` with `setDiscardSaved(true)` instead.
- `SaveContext` without `setDiscardSaved(true)` when the returned `EntitySet` is not used — post-save reload executes N SELECT queries for nothing.
- `JPA em.persist`/`em.merge` for bulk operations over ~1000 entities — no JDBC batch write is configured at the JPA level; use `JdbcTemplate.batchUpdate` for truly large batches.
