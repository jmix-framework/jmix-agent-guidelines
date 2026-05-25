---
name: jmix-create-dto-entity
description: Create or change Jmix DTO entities and other non-persistent transfer models for UI data containers, REST/API payloads, custom data stores, external data, or calculated read models.
---

# Create DTO Entity

Use this skill when a non-JPA model must participate in Jmix metadata, UI data containers, or DataManager-backed custom data stores.

## Steps

1. Decide whether the model needs Jmix metadata.
2. Use a plain Java class or record for internal service/API payloads that are not shown in Jmix UI.
3. Use a Jmix DTO entity when the model is bound to Flow UI components, localized as an entity, or handled by a custom data store.
4. Create the DTO class in a package consistent with the project, usually `entity` or a dedicated DTO package if the project already has one.
5. Add `@JmixEntity`; use `annotatedPropertiesOnly = true` when only selected fields should become entity attributes.
6. Add `@JmixId` on a stable unique attribute. Add `@JmixGeneratedValue` for generated UUID ids.
7. Add `@InstanceName` when the DTO appears in pickers, grids, or captions.
8. Add `@JmixProperty(mandatory = true)` for required DTO attributes that have no JPA `@Column`.
9. Instantiate UI-bound DTO entities with `Metadata.create()` or `DataManager.create()`, not constructors.
10. Add message keys for DTO entity and attributes when user-facing.
11. Do not create Liquibase changes for pure DTO entities.

## DTO Entity Template

```java
import io.jmix.core.entity.annotation.JmixGeneratedValue;
import io.jmix.core.entity.annotation.JmixId;
import io.jmix.core.metamodel.annotation.InstanceName;
import io.jmix.core.metamodel.annotation.JmixEntity;
import io.jmix.core.metamodel.annotation.JmixProperty;

import java.math.BigDecimal;
import java.util.UUID;

@JmixEntity(annotatedPropertiesOnly = true)
public class CustomerSummary {
    @JmixId
    @JmixGeneratedValue
    @JmixProperty(mandatory = true)
    private UUID id;

    @InstanceName
    @JmixProperty(mandatory = true)
    private String name;

    @JmixProperty
    private BigDecimal totalAmount;

    // getters and setters
}
```

## Plain DTO Pattern

Use a record or plain POJO when Jmix metadata is not needed:

```java
public record CustomerSummaryResponse(UUID customerId, String name, BigDecimal totalAmount) {
}
```

Do not add `@JmixEntity` just because a class is called DTO.

## UI Usage

For a DTO collection shown in a view, use a collection container and load it explicitly from a service or load delegate:

```xml
<collection id="customerSummariesDc" class="com.company.app.entity.CustomerSummary"/>
```

```java
@Install(to = "customerSummariesDl", target = Target.DATA_LOADER)
private List<CustomerSummary> customerSummariesDlLoadDelegate(LoadContext<CustomerSummary> loadContext) {
    return summaryService.loadSummaries();
}
```

## Custom Data Store

Use `@Store(name = "...")` only when a real custom data store exists and the DTO should support generic CRUD through `DataManager`.

If the task only needs a calculated grid or API response, prefer a service-returned DTO list instead of inventing a store.

## Forbidden

- `@Entity`, `@Table`, `@Column`, or Liquibase for pure DTO entities.
- Constructor calls for UI-bound DTO entities with generated ids.
- Missing `@JmixId` when identity matters in UI, data containers, or stores.
- Lombok `@Data` or generated `equals()` / `hashCode()` on Jmix entities.
- Making every API record a Jmix DTO entity by default.
- Using a DTO entity to bypass proper fetch plans or security policies.
