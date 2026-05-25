---
name: jmix-create-service
description: Create Jmix service-layer business logic with DataManager, transactions, and no UI coupling.
---

# Create Service Logic

Use this skill when implementing business operations, calculations, or persistence workflows.

## Steps

1. Create a Spring `@Service` in the `service` package.
2. Use constructor injection.
3. Prefer `DataManager` for normal loading and saving.
4. Add `@Transactional` when the operation changes multiple entities or must be atomic.
5. Validate business invariants in the service before saving.
6. Return domain values or saved entities, not UI components.
7. Keep view controllers thin: they should call services, not implement business rules.

## Service Template

```java
import io.jmix.core.DataManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
public class AccountService {

    private final DataManager dataManager;

    public AccountService(DataManager dataManager) {
        this.dataManager = dataManager;
    }

    @Transactional
    public Account applyDelta(UUID accountId, int delta) {
        Account account = dataManager.load(Account.class)
                .id(accountId)
                .one();

        account.setBalance(account.getBalance() + delta);
        account.setLastUpdated(LocalDateTime.now());

        return dataManager.save(account);
    }
}
```

## DataManager Loading

```java
Customer customer = dataManager.load(Customer.class)
        .id(customerId)
        .one();

List<Customer> activeCustomers = dataManager.load(Customer.class)
        .query("select e from Customer e where e.active = true")
        .list();
```

## Forbidden

- Business logic in view controllers.
- UI components, dialogs, or notifications in services.
- Constructor calls for Jmix entities.
- `EntityManager` for regular CRUD.
- Missing transaction boundary for multi-step updates that must be atomic.
