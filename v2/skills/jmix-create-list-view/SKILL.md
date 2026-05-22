---
name: jmix-create-list-view
description: Create a Jmix Flow UI list view with XML descriptor, data loading, menu, messages, and policies.
---

# Create List View

Use this skill when creating a top-level list/search view for an entity.

## Steps

1. Create Java controller under `view/<entityname>/`.
2. Extend `StandardListView<Entity>`.
3. Add `@Route(value = "...", layout = MainView.class)`.
4. Add `@ViewController(id = "Entity.list")`.
5. Add `@ViewDescriptor(path = "entity-list-view.xml")`.
6. Add `@LookupComponent("<entities>DataGrid")`.
7. Create XML descriptor with collection container, loader, `dataLoadCoordinator`, grid actions, toolbar buttons, and columns.
8. Verify every JPQL query uses the JPA/Jmix entity name, not the database table name.
9. Render a visible button for every grid action that users must trigger.
10. If `urlQueryParameters` references a component id, declare a real component with that id.
11. Add a `menu.xml` item for list views that should appear in navigation.
12. Add message keys for title, menu, and custom button captions.
13. Add `@ViewPolicy("Entity.list")` and `@MenuPolicy("Entity.list")` for roles that can open the view.

## Controller Template

```java
@Route(value = "customers", layout = MainView.class)
@ViewController(id = "Customer.list")
@ViewDescriptor(path = "customer-list-view.xml")
@LookupComponent("customersDataGrid")
@DialogMode(width = "64em")
public class CustomerListView extends StandardListView<Customer> {
}
```

## XML Skeleton

```xml
<view xmlns="http://jmix.io/schema/flowui/view"
      title="msg://customerListView.title"
      focusComponent="customersDataGrid">
    <data>
        <collection id="customersDc" class="com.company.app.entity.Customer">
            <fetchPlan extends="_base"/>
            <loader id="customersDl" readOnly="true">
                <query><![CDATA[select e from Customer e]]></query>
            </loader>
        </collection>
    </data>
    <facets>
        <dataLoadCoordinator auto="true"/>
    </facets>
    <layout>
        <hbox id="buttonsPanel" classNames="buttons-panel">
            <button id="createButton" action="customersDataGrid.createAction"/>
            <button id="editButton" action="customersDataGrid.editAction"/>
            <button id="removeButton" action="customersDataGrid.removeAction"/>
        </hbox>
        <dataGrid id="customersDataGrid" dataContainer="customersDc">
            <actions>
                <action id="createAction" type="list_create"/>
                <action id="editAction" type="list_edit"/>
                <action id="removeAction" type="list_remove"/>
            </actions>
            <columns>
                <column property="name"/>
            </columns>
        </dataGrid>
    </layout>
</view>
```

Use `list_read` only for read-only workflows. Use `list_edit` when the user should edit records.

## URL Query Parameters

Only add `urlQueryParameters` entries for components that actually exist in the descriptor.

If you add pagination state:

```xml
<facets>
    <dataLoadCoordinator auto="true"/>
    <urlQueryParameters>
        <pagination component="pagination"/>
    </urlQueryParameters>
</facets>
```

the layout must declare the matching component:

```xml
<simplePagination id="pagination" dataLoader="customersDl"/>
```

If the view does not need visible pagination, omit the pagination URL parameter. The same rule applies to generic filters and every other referenced component id.

## JPQL Entity Names

JPQL queries use entity names, not table names. If an entity has a table suffix or custom table name, keep the JPQL entity name as the Java entity name unless the entity declares a custom JPA entity name.

```java
@Table(name = "PRODUCT_")
@Entity
public class Product {
}
```

```xml
<query><![CDATA[select e from Product e]]></query>
```

Do not write `select e from PRODUCT_ e` or `select e from Product_ e` unless the entity itself is named that way in JPA metadata.

## Forbidden

- Declaring actions without visible buttons or another reachable UI trigger.
- Using `@Table` names in JPQL.
- `urlQueryParameters` references to component ids that are not declared in the XML.
- Java controller without matching XML descriptor.
- XML descriptor without matching `@ViewDescriptor`.
- Hardcoded title text.
- Invented or unverified icon names.
- Missing role view policy.
- Adding menu policy for dialog-only detail views.
