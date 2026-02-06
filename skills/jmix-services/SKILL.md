---
name: jmix-services
description: Data access and transactions in services. Use when implementing business logic, loading/saving entities with security and cross-datastore support, or performing bulk and native data operations.
---

# Services

Services in Jmix encapsulate business logic and provide a central point for data access and manipulation, ensuring security constraints and entity lifecycle events are respected.

## When to Use

Use this Skill when:
- Implementing business logic in Spring beans (annotated with `@Service` or `@Component`)
- Loading and saving entities using `DataManager` (preferred primary API)
- Filtering data using `Condition` objects in `DataManager`
- Working with graphs of entities including cross-datastore references
- Performing bulk updates or native SQL queries via `EntityManager`
- Executing raw SQL or stored procedures using `JdbcTemplate` or `JdbcClient`
- Managing transactions declaratively (`@Transactional`) or programmatically (`TransactionTemplate`)
- Creating Jmix Data Repositories
- Using pessimistic locking via `DataManager.lockMode()`

## Key Concepts

- **DataManager**: The primary interface for CRUD operations. It acts as a hub for all data stores (JPA, DTO, etc.), enforces security, handles cross-datastore references, and triggers entity events.
- **EntityManager**: A lower-level standard JPA interface. Use it only when `DataManager` is insufficient (e.g., bulk updates, native queries). Must be used within a transaction. By default, it works with the main data store; use `@PersistenceContext(unitName = "...")` for additional data stores.
- **JDBC / JdbcTemplate**: Used for direct database access when JPA is not suitable (e.g., complex SQL, vendor-specific features, batch operations). Participates in Spring-managed transactions.
- **Cross-Datastore References**: `DataManager` can automatically load related entities from different data stores if the reference is defined using a persistent ID attribute and a transient reference attribute (using `@JmixProperty` and `@DependsOnProperties`).
- **Transactions**: Jmix uses Spring's transaction management. `@Transactional` can be applied to service methods. `DataManager` handles transactions automatically if no external transaction exists, but `EntityManager` requires an active transaction.

## Usage

- **DataManager Operations**: Use the fluent API for loading (`load(Class).id(id).one()`, `load(Class).query(jpql).list()`) and saving (`save(entity)`, `save(saveContext)`).
- **Service Template**: Define services as Spring beans with constructor injection for dependencies like `DataManager`.
- **Performance Optimization**: Use `loadValues()` for scalar/aggregate data, and `saveWithoutReload()` or `SaveContext.setDiscardSaved(true)` when the saved instance is not needed.
- **EntityManager**: Inject via `@PersistenceContext`. Requires `@Transactional`. Useful for `executeUpdate()` on JPQL/Native queries. Support for hard deletion via `PersistenceHints.SOFT_DELETION`.
- **JDBC**: Inject `JdbcTemplate` or `JdbcClient` (Spring 6+) for the main data store. For additional data stores, inject the specific `DataSource` and create a new instance (e.g., `JdbcClient.create(dataSource)`).
- **Transaction Management**: 
    - Use `@Transactional` for declarative boundaries.
    - Use `TransactionTemplate` for programmatic control.
- **Data Repositories**: Define interfaces extending `JmixDataRepository<Entity, ID>` for a Spring Data-like experience, with support for Jmix `FetchPlan`.

See usage examples in [references/examples.md](references/examples.md).

## Checklist
- [ ] Use `@Service` for business logic beans
- [ ] Prefer `DataManager` over `EntityManager` for standard CRUD
- [ ] Ensure `@Transactional` is present when using `EntityManager` or multiple `DataManager` saves
- [ ] Keep business logic in services, not in UI view controllers
- [ ] Define cross-datastore references correctly with `@DependsOnProperties`

## Forbidden
- Using `EntityManager` without an active transaction
- Accessing UI components (e.g., buttons, notifications) inside service beans
- Hardcoding SQL when JPQL or `DataManager` can be used
