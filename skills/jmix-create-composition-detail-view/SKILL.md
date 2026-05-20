---
name: jmix-create-composition-detail-view
description: Add editable parent-child composition UI in a Jmix detail view.
---

# Create Composition Detail Editing

Use this skill when a parent entity owns child entities edited inside the parent detail view.

## Steps

1. Ensure the entity model is a real composition:
   - parent collection has `@Composition`;
   - child has non-null parent back reference;
   - parent has cascade delete if child lifecycle belongs to parent.
2. Create a child detail view with `jmix-create-detail-view`.
3. In the parent detail XML, add a collection container for the child collection.
4. Add a child `dataGrid` bound to that collection container.
5. Add `list_create`, `list_edit`, and `list_remove` actions to the child grid.
6. Render visible child-grid buttons for create, edit, and remove.
7. Add `openMode=DIALOG` to create/edit actions.
8. Add view policy for the child detail view.
9. Add messages for child entity and view title.

## XML Pattern

```xml
<instance id="orderDc" class="com.company.app.entity.Order">
    <fetchPlan extends="_base">
        <property name="lines" fetchPlan="_base"/>
    </fetchPlan>
    <loader id="orderDl"/>
    <collection id="linesDc" property="lines"/>
</instance>

<hbox id="lineButtonsPanel" classNames="buttons-panel">
    <button id="createLineButton" action="linesDataGrid.createAction"/>
    <button id="editLineButton" action="linesDataGrid.editAction"/>
    <button id="removeLineButton" action="linesDataGrid.removeAction"/>
</hbox>

<dataGrid id="linesDataGrid" dataContainer="linesDc">
    <actions>
        <action id="createAction" type="list_create">
            <properties>
                <property name="openMode" value="DIALOG"/>
            </properties>
        </action>
        <action id="editAction" type="list_edit">
            <properties>
                <property name="openMode" value="DIALOG"/>
            </properties>
        </action>
        <action id="removeAction" type="list_remove"/>
    </actions>
</dataGrid>
```

## Forbidden

- Child collection actions without a child detail view.
- Child collection actions without visible buttons or another reachable UI trigger.
- Nullable child parent reference.
- Missing child detail view policy.
- Editing composition children outside the parent aggregate when the domain says they are owned.
