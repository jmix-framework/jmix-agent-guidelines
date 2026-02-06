# Security Roles Usage Examples

## Resource Roles

### Basic Resource Role Template

```java
import io.jmix.security.model.EntityPolicyAction;
import io.jmix.security.model.EntityAttributePolicyAction;
import io.jmix.security.model.SecurityScope;
import io.jmix.security.role.annotation.*;
import io.jmix.securityflowui.role.annotation.MenuPolicy;
import io.jmix.securityflowui.role.annotation.ViewPolicy;

@ResourceRole(name = "Sales Manager", code = SalesManagerRole.CODE, scope = SecurityScope.UI)
public interface SalesManagerRole {

    String CODE = "app_SalesManager"; // Use prefix if the project is an add-on

    @EntityPolicy(entityClass = Customer.class, actions = EntityPolicyAction.ALL)
    @EntityAttributePolicy(entityClass = Customer.class, attributes = "*", action = EntityAttributePolicyAction.MODIFY)
    void customer();

    @ViewPolicy(viewIds = {"Customer.list", "Customer.detail"})
    void views();

    // Normally each list view should have a menu item
    @MenuPolicy(menuIds = {"Customer.list"})
    void menu();
}
```

### Entity and Attribute Policies

```java
public interface PolicyExamples {
    // All operations
    @EntityPolicy(entityClass = Customer.class, actions = EntityPolicyAction.ALL)
    void allCustomers();

    // Some operations
    @EntityPolicy(entityClass = Order.class, actions = {
        EntityPolicyAction.CREATE,
        EntityPolicyAction.READ,
        EntityPolicyAction.UPDATE
    })
    void orders();

    // Read-only
    @EntityPolicy(entityClass = Product.class, actions = EntityPolicyAction.READ)
    void readOnlyProducts();

    // Full attribute access
    @EntityAttributePolicy(entityClass = Customer.class, attributes = "*", action = EntityAttributePolicyAction.MODIFY)
    void fullAttributes();

    // View only attribute access
    @EntityAttributePolicy(entityClass = Customer.class, attributes = "*", action = EntityAttributePolicyAction.VIEW)
    void viewAttributes();

    // Hidden attributes — simply don't include them (additive system)
}
```

### Resource Role with Multiple Policies

```java
@ResourceRole(
        name = "Customers: non-confidential info only, cannot delete",
        code = "customer-nonconfidential-access")
public interface CustomerNonConfidentialAccessRole {

    @EntityPolicy(
            entityClass = Customer.class,
            actions = {EntityPolicyAction.READ,
                    EntityPolicyAction.CREATE,
                    EntityPolicyAction.UPDATE})
    @EntityAttributePolicy(
            entityClass = Customer.class,
            attributes = {"name", "region", "details"},
            action = EntityAttributePolicyAction.MODIFY)
    @ViewPolicy(
            viewIds = {"Customer.list"})
    @MenuPolicy(
            menuIds = {"Customer.list"})
    void customer();

    @EntityPolicy(
            entityClass = CustomerDetail.class,
            actions = EntityPolicyAction.ALL)
    @EntityAttributePolicy(
            entityClass = CustomerDetail.class,
            attributes = {"content"},
            action = EntityAttributePolicyAction.MODIFY)
    @ViewPolicy(
            viewIds = {"CustomerDetail.detail"})
    void customerDetail();
}
```

## Row-Level Roles

### JPQL Row-Level Policy

Restricts access on the database level (SQL). Note that JPQL policy affects only the root entity of a loaded object graph. If an entity can be loaded as a collection in another entity's object graph, you should define both JPQL and predicate policies for it to ensure consistent access control.

```java
@RowLevelRole(name = "Own Orders Only", code = "app_OwnOrdersOnly")
public interface OwnOrdersOnlyRole {

    @JpqlRowLevelPolicy(
        entityClass = Order.class,
        where = "{E}.createdBy = :current_user_username"
    )
    void orderPolicy();
}
```

### JPQL Policy with Session Attributes

```java
@RowLevelRole(
        name = "Can see Customers and Orders of their region",
        code = "same-region-rows")
public interface SameRegionRowsRole {

    @JpqlRowLevelPolicy(
            entityClass = Customer.class,
            where = "{E}.region = :current_user_region")
    void customer();

    @JpqlRowLevelPolicy(
            entityClass = Order.class,
            where = "{E}.customer.region = :current_user_region")
    void order();
}
```

### Predicate Row-Level Policy

In-memory check, useful for complex logic or when JPQL is not possible.

```java
@RowLevelRole(
        name = "Can see only non-confidential rows",
        code = "app_NonConfidentialRows")
public interface NonConfidentialRowsRole {

    @PredicateRowLevelPolicy(
            entityClass = CustomerDetail.class,
            actions = {RowLevelPolicyAction.READ})
    default RowLevelPredicate<CustomerDetail> customerDetailNotConfidential() {
        return customerDetail -> !Boolean.TRUE.equals(customerDetail.getConfidential());
    }
}
```

Accessing Spring beans from predicates:
```java
@RowLevelRole(
        name = "Can see Customers of their region",
        code = "same-region-customers-role")
public interface SameRegionCustomersRole {

    @PredicateRowLevelPolicy(
            entityClass = Customer.class,
            actions = {RowLevelPolicyAction.READ})
    default RowLevelBiPredicate<Customer, ApplicationContext> customerOfMyRegion() {
        return (customer, applicationContext) -> {
            CurrentAuthentication currentAuthentication = applicationContext.getBean(CurrentAuthentication.class);
            return customer.getRegion() != null
                    && customer.getRegion().equals(((User) currentAuthentication.getUser()).getRegion());
        };
    }
}
```

## Combining Roles

### Combining Resource Roles

Inherit policies from multiple parent roles.

```java
@ResourceRole(name = "SystemOwner", code = SystemOwnerRole.CODE)
public interface SystemOwnerRole extends BasicEmployeeRole, ManagerRole, SupervisorRole {
    String CODE = "system-owner";

    // System owner's additional policies
}
```

### Combining Row-Level Roles

```java
@RowLevelRole(name = "Can see data of their region", code = SameRegionRole.CODE)
public interface SameRegionRole extends SameRegionCustomersRole, SameRegionRowsRole {
    String CODE = "same-region-role";
}
```

## Permission Checks in Code

```java
@Autowired
private AccessManager accessManager;

public void checkAccess() {
    // Check if current user can update Order
    EntityOperationContext ctx = new EntityOperationContext(Order.class, EntityOp.UPDATE);
    accessManager.applyRegisteredConstraints(ctx);
    
    if (!ctx.isPermitted()) {
        throw new AccessDeniedException("Cannot update Order");
    }
}
```
