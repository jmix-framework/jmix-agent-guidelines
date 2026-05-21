---
name: jmix-add-entity-event-listener
description: Add Jmix entity event listeners for lifecycle defaults, immutable records, and side effects.
---

# Add Entity Event Listener

Use this skill when business logic must react to entity creation, update, delete, or save.

## Steps

1. Create a Spring `@Component` listener in `service` or `listener`.
2. Use `org.springframework.context.event.EventListener`.
3. Use exact Jmix imports:
   - `io.jmix.core.event.EntityChangedEvent`
   - `io.jmix.core.event.EntitySavingEvent`
4. For created entities, load by `event.getEntityId()` when related data is needed.
5. If you specify a custom fetch plan, include every scalar and reference property read later.
6. Use `EntitySavingEvent` or a before-commit `@EventListener` path for validation and required defaults.
7. Put multi-entity changes in a transactional service method when atomicity matters.
8. Reject unsupported updates/deletes inside the event path before treating work as complete.
9. Search the changed code for `@TransactionalEventListener`; if the listener performs validation, rejects updates/deletes, sets required defaults, or performs required synchronous side effects, replace it with `@EventListener` plus `EntitySavingEvent`/`EntityChangedEvent`/`EntityRemovingEvent` or another before-commit path.
10. Add tests or at least compile/startup validation for the event listener.

## Listener Template

```java
import io.jmix.core.DataManager;
import io.jmix.core.event.EntityChangedEvent;
import io.jmix.core.event.EntitySavingEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class LedgerEntryEventListener {

    private final DataManager dataManager;
    private final LedgerService ledgerService;

    public LedgerEntryEventListener(DataManager dataManager,
                                    LedgerService ledgerService) {
        this.dataManager = dataManager;
        this.ledgerService = ledgerService;
    }

    @EventListener
    public void onLedgerEntryChanged(EntityChangedEvent<LedgerEntry> event) {
        if (event.getType() == EntityChangedEvent.Type.CREATED) {
            LedgerEntry entry = dataManager.load(event.getEntityId()).one();
            ledgerService.applyEntry(entry);
            return;
        }

        throw new UnsupportedOperationException("This record cannot be updated or deleted");
    }

    @EventListener
    public void onLedgerEntrySaving(EntitySavingEvent<LedgerEntry> event) {
        if (event.getEntity().getCreatedDate() == null) {
            event.getEntity().setCreatedDate(LocalDateTime.now());
        }
    }
}
```

## Fetch Plan Safety

The loaded entity must contain every property the listener reads. The safest default is loading by event id with the normal plan:

```java
LedgerEntry entry = dataManager.load(event.getEntityId()).one();
```

If you use a custom fetch plan, add all accessed scalar fields and references:

```java
LedgerEntry entry = dataManager.load(LedgerEntry.class)
        .id(event.getEntityId())
        .fetchPlan(fp -> fp.addFetchPlan("_base")
                .add("account", "_base"))
        .one();

ledgerService.apply(entry.getAccount().getId(), entry.getAmount(), entry.getType());
```

After writing the listener, scan the method: every `entry.getX()` used after loading must be available in the fetch plan.

## Event Timing

Use normal Spring `@EventListener` for logic that must affect the current save/remove operation:

- required default values;
- rejecting unsupported updates or deletes;
- synchronous changes to related persistent state;
- validation whose exception must propagate to `DataManager.save()` or `DataManager.remove()`.

`@TransactionalEventListener` is for after-transaction reactions such as notifications or integration events. Do not use it when failure must roll back or reject the current persistence operation.

## Forbidden

- `io.jmix.core.entity.EntityChangedEvent`.
- Assuming `EntityChangedEvent` directly contains the full entity instance.
- Reading an entity property that is omitted from a custom fetch plan.
- `@TransactionalEventListener` for validation, required synchronous side effects, or immutable-record enforcement.
- Required persistence defaults set only by `InitEntityEvent`.
- Putting UI code in entity listeners.
- Side effects without an explicit service method when several entities must stay consistent.
