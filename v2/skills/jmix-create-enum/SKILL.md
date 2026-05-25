---
name: jmix-create-enum
description: Create a Jmix enum for entity attributes with stable database ids and localization.
---

# Create Jmix Enum

Use this skill when an entity attribute has a fixed set of values.

## Steps

1. Create the enum in the `entity` package.
2. Implement `io.jmix.core.metamodel.datatype.EnumClass<T>`.
3. Use stable database ids, not display labels.
4. Add a typed `fromId()` method annotated with `@Nullable`.
5. Store the enum id type in the entity field.
6. Add getter/setter conversion in the entity.
7. Add Liquibase column matching the id type.
8. Add enum message keys in all locale files.

## Enum Template

```java
import io.jmix.core.metamodel.datatype.EnumClass;
import org.springframework.lang.Nullable;

public enum TransactionType implements EnumClass<String> {
    INCOME("INCOME"),
    OUTCOME("OUTCOME");

    private final String id;

    TransactionType(String id) {
        this.id = id;
    }

    @Override
    public String getId() {
        return id;
    }

    @Nullable
    public static TransactionType fromId(String id) {
        for (TransactionType value : TransactionType.values()) {
            if (value.getId().equals(id)) {
                return value;
            }
        }
        return null;
    }
}
```

## Entity Mapping

```java
@Column(name = "TYPE", nullable = false, length = 50)
private String type;

public TransactionType getType() {
    return type == null ? null : TransactionType.fromId(type);
}

public void setType(TransactionType type) {
    this.type = type == null ? null : type.getId();
}
```

## Forbidden

- `io.jmix.core.EnumClass`.
- Raw `EnumClass` without a type parameter.
- Storing display labels as ids.
- `ordinal()` or enum `.name()` persistence.
- Missing enum message keys.
