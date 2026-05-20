---
name: jmix-create-entity
description: Create or change a persistent Jmix JPA entity and its required surrounding artifacts.
---

# Create Persistent Entity

Use this skill when adding or changing a database-backed Jmix entity.

## Steps

1. Create or update the Java entity in `src/main/java/<base-package>/entity`.
2. Add Jmix and JPA metadata: `@JmixEntity`, `@Entity`, `@Table`.
3. Add UUID identity with `@Id` and `@JmixGeneratedValue`.
4. Add `@Version`.
5. Add `@InstanceName` on a stable human-readable field or method.
6. Define columns with exact `nullable`, `length`, `precision`, and `scale` constraints from requirements.
7. Use `FetchType.LAZY` for relationships.
8. Create the Liquibase changelog using `jmix-create-liquibase-changelog`.
9. Add entity and attribute message keys using `jmix-add-i18n-keys`.
10. Add or update views and security roles if the entity is user-facing.
11. Before finishing, compare every required constraint against the source requirements and the Liquibase changelog.

## Entity Template

```java
import io.jmix.core.entity.annotation.JmixGeneratedValue;
import io.jmix.core.metamodel.annotation.InstanceName;
import io.jmix.core.metamodel.annotation.JmixEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import java.util.UUID;

@JmixEntity
@Table(name = "CUSTOMER")
@Entity
public class Customer {
    @JmixGeneratedValue
    @Column(name = "ID", nullable = false)
    @Id
    private UUID id;

    @Version
    @Column(name = "VERSION", nullable = false)
    private Integer version;

    @InstanceName
    @Column(name = "NAME", nullable = false, length = 100)
    private String name;

    // getters and setters
}
```

## Composition Checklist

For parent-child aggregates:

- Parent collection has `@Composition`.
- Parent collection has `@OnDelete(DeletePolicy.CASCADE)` when child lifecycle belongs to parent.
- Child has a non-null back reference to parent.
- Child `@ManyToOne` uses `fetch = FetchType.LAZY` and `optional = false`.
- Child join column is `nullable = false`.
- Parent detail view supports editing the child collection.
- Child detail view and role policy exist if the UI opens the child in a dialog.

```java
import io.jmix.core.DeletePolicy;
import io.jmix.core.entity.annotation.OnDelete;
import io.jmix.core.metamodel.annotation.Composition;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;

@Composition
@OnDelete(DeletePolicy.CASCADE)
@OneToMany(mappedBy = "order")
private List<OrderLine> lines;

@JoinColumn(name = "ORDER_ID", nullable = false)
@ManyToOne(fetch = FetchType.LAZY, optional = false)
private Order order;
```

## Default Values

- If a required value can be created from UI and non-UI code, do not rely on the view alone.
- Use a service method, entity saving event, or other application lifecycle path that covers non-UI saves.
- Use `InitEntityEvent` only for UI-only defaults.

## Constraint Audit

Check Java annotations and Liquibase side by side:

- `nullable` / `@NotNull`
- `length`
- `precision` and `scale`
- enum id values and column type
- foreign key nullability
- indexes and unique constraints
- default values for required fields

## Semantic Constraint Checks

Apply common Java validation and persistence mappings when the field semantics are clear:

- Fields named `email` should usually have `@Email` unless the requirements explicitly say otherwise.
- Unlimited or large text should use the project pattern for long text, usually `@Lob` plus a matching Liquibase type, not an invented arbitrary length.
- `BigDecimal` columns must use the exact required precision and scale in both Java and Liquibase.
- Do not invent a length for a field when the requirements say it is unlimited or when the existing project uses long text for the same concept.

## Forbidden

- Missing `@JmixEntity`.
- Constructor-based entity creation.
- `FetchType.EAGER`.
- Missing Liquibase changelog for persistent changes.
- Nullable child back references in composition aggregates.
- Relying only on UI initialization for required persistence fields.
