---
name: jmix-create-resource-role
description: Create or update Jmix resource roles with entity, attribute, view, and menu policies.
---

# Create Resource Role

Use this skill when adding or changing Jmix security access.

## Steps

1. List every entity the role must access.
2. For each entity, decide CRUD actions explicitly.
3. Add attribute policies for fields the role must view or edit.
4. List every view the role can open, including dialog-only detail views.
5. Add menu policies only for real menu item ids from `menu.xml`, not parent grouping ids.
6. Do not grant broader actions than the workflow requires.
7. Re-check create-only workflows: create forms need `MODIFY` attribute access even when update/delete are forbidden.
8. If saving an allowed record triggers service side effects on another entity, ensure the operation has the needed permissions or is implemented through an appropriate trusted service path.
9. Before finishing, compare `@MenuPolicy` values against `menu.xml` item `id` or `view` values.
10. If requirements say "view and create", grant `READ` and `CREATE` only; do not grant `ALL`, `UPDATE`, or `DELETE`.

## Read/Create Without Update/Delete

```java
import io.jmix.security.model.EntityAttributePolicyAction;
import io.jmix.security.model.EntityPolicyAction;
import io.jmix.security.role.annotation.EntityAttributePolicy;
import io.jmix.security.role.annotation.EntityPolicy;
import io.jmix.security.role.annotation.ResourceRole;
import io.jmix.securityflowui.role.annotation.MenuPolicy;
import io.jmix.securityflowui.role.annotation.ViewPolicy;

@ResourceRole(name = "Employee", code = EmployeeRole.CODE)
public interface EmployeeRole {
    String CODE = "employee";

    @EntityAttributePolicy(entityClass = OrderRequest.class,
            attributes = "*",
            action = EntityAttributePolicyAction.MODIFY)
    @EntityPolicy(entityClass = OrderRequest.class,
            actions = {EntityPolicyAction.READ, EntityPolicyAction.CREATE})
    void orderRequestEntity();

    @ViewPolicy(viewIds = {
            "OrderRequest.list",
            "OrderRequest.detail"
    })
    @MenuPolicy(menuIds = "OrderRequest.list")
    void orderRequestScreens();
}
```

## Role Matrix

Before finishing, check this matrix:

| Surface | Required? | Policy |
| --- | --- | --- |
| Entity CRUD | yes | `@EntityPolicy` |
| Entity attributes | yes | `@EntityAttributePolicy` |
| List view | if user opens it | `@ViewPolicy` |
| Detail/dialog view | if user opens it | `@ViewPolicy` |
| Menu item | if user opens it from menu | `@MenuPolicy` |

## Create-Only Checklist

- Entity actions include `READ` and `CREATE`.
- Entity actions do not include `UPDATE` or `DELETE` unless explicitly required.
- Editable attributes use `EntityAttributePolicyAction.MODIFY`; `VIEW` is not enough for a create form.
- The detail view used for creation has a `@ViewPolicy`.
- Related side effects are checked for permission requirements.

## View And Create Recipe

For workflows where records can be viewed and created but not changed afterward:

```java
@EntityAttributePolicy(entityClass = OrderRequest.class,
        attributes = "*",
        action = EntityAttributePolicyAction.MODIFY)
@EntityPolicy(entityClass = OrderRequest.class,
        actions = {EntityPolicyAction.READ, EntityPolicyAction.CREATE})
void orderRequestEntity();
```

This allows create forms to write field values while still denying entity update/delete operations. Do not replace this with `EntityPolicyAction.ALL`.

## Menu Policy Audit

Menu groups are navigation containers, not the user-facing item policies most roles need. Read `menu.xml` and grant the item ids that open views.

```xml
<menu id="sales" title="msg://menu.sales">
    <item view="Customer.list"/>
    <item id="orders" view="Order.list"/>
</menu>
```

```java
@MenuPolicy(menuIds = {"Customer.list", "orders"})
```

Do not grant only `sales` unless the role is intentionally controlling the parent group itself and the project's security checks use that group id.

## Forbidden

- `EntityPolicyAction.ALL` when update/delete are not required.
- `UPDATE` or `DELETE` entity actions for immutable or create-only records.
- Entity create permission without `MODIFY` attribute permission for editable fields.
- View policies only for list views while create/edit dialogs use detail views.
- Menu policy for a parent group when the user needs access to concrete menu items.
- Menu policy for views that are not menu entries.
