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
7. Create XML descriptor with collection container, loader, `dataLoadCoordinator`, grid actions, toolbar buttons, and columns. Do NOT add `<urlQueryParameters>` unless you also add the matching components (see below) — omitting it entirely is the safe default.
8. Verify every JPQL query uses the JPA/Jmix entity name, not the database table name.
9. Render a visible button for every grid action that users must trigger.
10. For every `<urlQueryParameters>` child, confirm a component with the matching `id` exists in the same descriptor — otherwise the view crashes at init with `Component with id '<x>' not found`.
11. Add a `menu.xml` item for list views that should appear in navigation.
12. Add message keys for title, menu, and custom button captions.
13. Grant access for roles that can open the view with `@ViewPolicy(viewIds = "Entity.list")` and `@MenuPolicy(menuIds = "Entity.list")` — declared on a method of a `@ResourceRole` interface (both are `@Target(METHOD)`), not the view controller. Neither annotation has a `value()` member: `@ViewPolicy("...")` / `@MenuPolicy("...")` do not compile. See `jmix-create-resource-role`.

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

## Choosing list-action types

The grid action that opens a row is one of:

- `list_create` — opens detail view for a new entity.
- `list_edit` — opens detail view in edit mode.
- `list_read` — opens detail view in an open read-only MODE (existing
  records are viewed but not modified). It is a mode, not a `readOnly`
  descriptor attribute.
- `list_remove` — deletes the selected entity.

`list_read` REPLACES `list_edit`, not the whole CRUD bar. When a spec
says "the list opens records in read mode" or "use `read` instead of
`edit`", still keep `list_create` and `list_remove` unless the spec
explicitly forbids creation or deletion. A list with only a read action
and no create/remove is almost always wrong unless a fully read-only
list was specifically requested.

## Custom (non-standard) buttons MUST carry their own caption

A button bound to a standard grid action (`createAction`, `editAction`,
`removeAction`) auto-resolves its caption from the action. A CUSTOM
button or action you add (e.g. one that calls a service or opens a
dialog) has NO caption unless you give it one — and a UI test locates a
button by its visible text, so a blank button is untargetable and the
test fails. Always add `text="msg://..."` and a matching message key.

```xml
<hbox id="buttonsPanel" classNames="buttons-panel">
    <button id="createButton" action="customersDataGrid.createAction"/>
    <button id="removeButton" action="customersDataGrid.removeAction"/>
    <!-- custom button: needs its OWN caption (action-bound buttons do not) -->
    <button id="actionButton" text="msg://actionButton.text"/>
</hbox>
```

If you instead wire a custom `<action>` (not a standard `list_*` type),
the action carries the caption: `<action id="customAction"
text="msg://customAction.text"/>`. Either way the visible text must
resolve, or it cannot be clicked. Add the key to
`messages_en.properties`.

A custom button's `clickListener` / `@Subscribe` handler takes
`ClickEvent<JmixButton>` (import `io.jmix.flowui.kit.component.button.JmixButton`).
The wrong event type fails `compileJava` with an argument type mismatch
at the click handler.

## Icons

DO NOT invent Vaadin icon names. The `VaadinIcon` enum is small and
irregular; a single typo like `VaadinIcon.ARROW_UP_DOWN` — no such
constant — crashes the entire view at render time.

- When unsure which icon to use, OMIT the `icon` attribute entirely.
  The button works without it.
- Reuse only icon names you have seen in this project. Grep existing
  view XML for `icon="` and copy what you find.
- Before typing a new `VaadinIcon` constant, verify it exists (grep the
  project, or use Context7 / IDE symbol lookup) — see `verify-api-symbol`.

## URL Query Parameters — the #1 copy-paste crash

**Default: do NOT add `<urlQueryParameters>` at all.** It is optional
decoration; a list view works fine without it. The skeleton above has
none on purpose — start from that.

Every `<urlQueryParameters>` child binds to a layout component BY ID,
and if that component is missing the view CRASHES AT INIT with
`Component with id '<x>' not found` — taking down every test that opens
the view. This is the single most expensive list-view defect.

The seed-scaffolded `user-list-view.xml` ships the binding and the
component TOGETHER:

```xml
<facets>
    <urlQueryParameters>
        <genericFilter component="genericFilter"/>   <!-- binding -->
        <pagination component="pagination"/>          <!-- binding -->
    </urlQueryParameters>
</facets>
...
<genericFilter id="genericFilter" dataLoader="customersDl">...</genericFilter>  <!-- component -->
<simplePagination id="pagination" dataLoader="customersDl"/>                    <!-- component -->
```

If you model a new view on the seed, copy BOTH halves or NEITHER.
Copying only the `<urlQueryParameters>` block (and dropping the
`simplePagination` / `genericFilter` components) is exactly what
crashes the view. The safe default is NEITHER.

Self-check: for EVERY `<urlQueryParameters>` child, grep the SAME file
for a component whose `id` equals the `component="..."` value. If it is
absent, either add the matching component to the layout
(`<simplePagination id="pagination" dataLoader="...Dl"/>` or
`<genericFilter id="genericFilter" dataLoader="...Dl">`) or delete that
entry.

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
