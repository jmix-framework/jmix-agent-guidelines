---
name: jmix-create-detail-view
description: Create a Jmix Flow UI detail view with XML descriptor, save-close action, messages, and policies.
---

# Create Detail View

Use this skill when creating a create/edit view for one entity.

## Steps

1. Create Java controller under `view/<entityname>/`.
2. Extend `StandardDetailView<Entity>`.
3. Add `@Route(value = ".../:id", layout = MainView.class)`.
4. Add `@ViewController(id = "Entity.detail")`.
5. Add `@ViewDescriptor(path = "entity-detail-view.xml")`.
6. Add `@EditedEntityContainer("<entity>Dc")`.
7. Create XML descriptor with instance container, loader, `dataLoadCoordinator`, typed form fields, `detail_saveClose`, and `detail_close`.
8. Configure reference fields with a verified data source: lookup action, `itemsContainer`, or `itemsQuery`.
9. Use `InitEntityEvent` for UI-only defaults. Required persistent defaults must also be set in a service or entity event path.
10. Add message keys for the title and field labels.
11. Add `@ViewPolicy("Entity.detail")` for roles that can open the detail view.
12. Before finishing, compare every form field component against the Java property type.

## Controller Template

```java
@Route(value = "customers/:id", layout = MainView.class)
@ViewController(id = "Customer.detail")
@ViewDescriptor(path = "customer-detail-view.xml")
@EditedEntityContainer("customerDc")
public class CustomerDetailView extends StandardDetailView<Customer> {
}
```

## XML Skeleton

```xml
<view xmlns="http://jmix.io/schema/flowui/view"
      title="msg://customerDetailView.title"
      focusComponent="form">
    <data>
        <instance id="customerDc" class="com.company.app.entity.Customer">
            <fetchPlan extends="_base"/>
            <loader id="customerDl"/>
        </instance>
    </data>
    <facets>
        <dataLoadCoordinator auto="true"/>
    </facets>
    <actions>
        <action id="saveCloseAction" type="detail_saveClose"/>
        <action id="closeAction" type="detail_close"/>
    </actions>
    <layout>
        <formLayout id="form" dataContainer="customerDc">
            <textField id="nameField" property="name"/>
        </formLayout>
        <hbox id="detailActions">
            <button id="saveAndCloseButton" action="saveCloseAction"/>
            <button id="closeButton" action="closeAction"/>
        </hbox>
    </layout>
</view>
```

## Field Component Mapping

Choose form components by property type:

| Property type | Component |
| --- | --- |
| `String` short text | `textField` |
| `String` long text | `textArea` |
| `Integer` | `integerField` |
| `Long` | `integerField` or `numberField` according to project usage |
| `BigDecimal` | `bigDecimalField` |
| `Boolean` | `checkbox` |
| `LocalDate` | `datePicker` |
| `LocalDateTime` | `dateTimePicker` |
| Jmix enum | `select` or `comboBox` |
| Entity reference | `entityComboBox` or `entityPicker` |

Do not expose technical fields (`id`, `version`) in user-facing forms. Hide parent/default fields only when they are initialized elsewhere.

## Final XML Type Audit

After creating or editing the descriptor, inspect each field:

- `Integer` is not a `textField`; use `integerField`.
- `BigDecimal` is not a `textField`; use `bigDecimalField`.
- Date/time properties use date/time picker components.
- Boolean properties use checkbox or the project's boolean component pattern.
- Entity references use reference components, not text fields.

If an existing project uses a different compiled pattern for a type, follow the existing pattern and keep it consistent.

## Reference Fields

For `@ManyToOne` and other entity references, prefer the simplest project-consistent pattern:

- `entityPicker` with lookup and clear actions when users need a full lookup screen.
- `entityComboBox` with an `itemsContainer` loaded by a collection loader when the candidate set should be preloaded.
- `entityComboBox` with `itemsQuery` for lazy loading only when that pattern already compiles in the project and query parameters are handled explicitly.

When using `itemsQuery`, use the JPA/Jmix entity name, not the database table name:

```xml
<entityComboBox id="productField" property="product">
    <itemsQuery class="com.company.app.entity.Product"
                fetchPlan="_instance_name">
        <query><![CDATA[select e from Product e order by e.name]]></query>
    </itemsQuery>
</entityComboBox>
```

`itemsQuery` does not automatically bind `container_` or `component_` parameters. Use an `itemsContainer` with a loader when the reference list depends on another component or container.

Before finishing, verify that saved reference entities can appear in the component data provider. If a field is required, do not leave a reference component without a working item source or lookup action.

## Forbidden

- Using list-view route or id patterns for detail views.
- Missing `detail_saveClose`.
- Using `textField` for numeric, date/time, boolean, or reference properties.
- Reference fields without a working lookup action, `itemsContainer`, or verified `itemsQuery`.
- Using `@Table` names in `itemsQuery`.
- `itemsQuery` with unresolved `container_` or `component_` parameters.
- Hardcoded labels or titles.
- Hiding required fields without setting defaults elsewhere.
- Missing view policy for dialog-opened detail views.
