---
name: jmix-fetch-plans
description: Jmix Fetch Plans define what data to load. Use when loading entities with relationships, configuring data containers in views, using `DataManager` or `JmixDataRepository`. Covers built-in fetch plans (_base, _local), custom plans, N+1 problem prevention, and fetch modes.
---

# Fetch Plans

Fetch plans define what part of the entity graph (attributes and related entities) should be loaded from the database in a single operation. They enable modular composition of data requirements for views and services.

## When to Use

Use this Skill when:
- Loading entities with relationships (to-one, to-many, embedded)
- Optimizing data loading to prevent the N+1 problem
- Loading only a subset of attributes (partial entities) for performance optimization
- Configuring data containers in UI views
- Defining data access in `DataManager` or `JmixDataRepository`
- Controlling the depth and breadth of the object graph retrieved from the database

## Key Concepts

- **Purpose**: Promote performance by encapsulating data requirements. Jmix entities are "thin" by default; fetch plans allow for eager loading of selected relationships and attributes, avoiding lazy loading exceptions in detached states.
- **Built-in Plans**:
    - `_local`: Includes all local (non-reference) attributes. Constant: `FetchPlan.LOCAL`.
    - `_instance_name`: Includes attributes required to form the instance name (can include references). Constant: `FetchPlan.INSTANCE_NAME`.
    - `_base`: Includes `_local` + `_instance_name` + embedded attributes. Constant: `FetchPlan.BASE`.
- **Fetch Modes**:
    - `AUTO`: Framework chooses the optimal mode (default).
    - `JOIN`: Fetches related entity in the same SQL query using a JOIN. Best for to-one references.
    - `BATCH`: Fetches related entities in a separate query using an `IN` clause. Best for to-many collections.
    - `UNDEFINED`: Separate SELECT for each reference attribute.
- **Partial Entities**: Entities loaded with a restricted set of local attributes. Accessing a local attribute not in the fetch plan results in an `IllegalStateException`.
- **N+1 Problem**: Occurs when a collection of entities is loaded, and then related entities are accessed in a loop, triggering a separate query for each iteration.

## Usage

- **Declarative Definition**:
    - **In View XML**: Defined within `<data>` containers (e.g., `<instance>`, `<collection>`). Use `<fetchPlan extends="_base">` and `<property name="..." fetchPlan="..."/>`.
    - **In fetch-plans.xml**: Define reusable fetch plans globally using `<fetch-plan entity="..." name="..." extends="...">`. Useful for complex, shared data requirements. Generally NOT recommended.
- **Programmatic Usage**:
    - **DataManager**: Use `.fetchPlan(fpb -> ...)` for inline definitions or pass a `FetchPlan` object to the `fetchPlan()` method.
    - **FetchPlans Bean**: Use the `fetchPlans.builder(Entity.class)` to build complex plans programmatically with `addFetchPlan()` and `add()` methods.
    - **Partial Loading**: When used with `DataManager`, fetch plans are partial by default and local attributes not explicitly added are not loaded. Use `.partial(false)` in the builder load all local attributes.
- **JmixDataRepository**:
    - Pass `FetchPlan` as the last argument to repository methods.
    - Use the `@FetchPlan` annotation on repository method definitions to specify a shared fetch plan by name.
    - Pass a shared fetch plan name as a `String` parameter to repository methods.
- **Best Practices and Considerations**:
    - **Default Choice**: Use `_base` fetch plan by default until performance issues arise.
    - **List Views**: Don't load nested collections in list views unless displaying them. Use `_instance_name` for references in columns.
    - **Complexity**: Think carefully about nested collections (n×n×n problem). Avoid deep nesting (>3 levels).

See usage examples in [references/examples.md](references/examples.md).

## Forbidden
- Do not use `FetchType.EAGER` on entity relationships; use fetch plans instead.
- Do not load references without fetch plans in loops (N+1 problem).
- Do not use fetch plans as a security mechanism; use Jmix security instead.
