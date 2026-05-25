---
name: jmix-add-dialog-detail-flow
description: Open a Jmix entity detail view from a button/action and refresh related data after save.
---

# Add Dialog Detail Flow

Use this skill when a button or action should create or edit an entity in a modal detail view, or collect a small scalar value through a Jmix input dialog.

## Steps

1. Inject `DialogWindows` with `@Autowired`.
2. Inject selected grid, loaders, and any child containers that must be cleared with `@ViewComponent`.
3. On click/action, get the selected master entity if needed.
4. Open `DialogWindows.detail(this, Entity.class).newEntity()` or `.editEntity(entity)`.
5. Use `.withInitializer(...)` to set parent/default fields.
6. Use `.withAfterCloseListener(...)` and refresh every affected loader only after `StandardOutcome.SAVE`.
7. Make sure the opened detail view exists and roles have its `@ViewPolicy`.
8. Use valid listener signatures when installing grid selection listeners.

## Create Child Entity From Selected Master

```java
@Autowired
private DialogWindows dialogWindows;

@ViewComponent
private DataGrid<Order> ordersDataGrid;

@ViewComponent
private CollectionLoader<Order> ordersDl;

@ViewComponent
private CollectionContainer<OrderLine> orderLinesDc;

@ViewComponent
private CollectionLoader<OrderLine> orderLinesDl;

@Subscribe("createLineButton")
public void onCreateLineButtonClick(final ClickEvent<JmixButton> event) {
    Order order = ordersDataGrid.getSingleSelectedItem();
    if (order == null) {
        return;
    }

    dialogWindows.detail(this, OrderLine.class)
            .newEntity()
            .withInitializer(line -> line.setOrder(order))
            .withAfterCloseListener(closeEvent -> {
                if (closeEvent.closedWith(StandardOutcome.SAVE)) {
                    ordersDl.load();
                    orderLinesDl.load();
                }
            })
            .open();
}
```

## Related Grid Loader

Prefer binding to the selected master container when possible:

```xml
<loader id="transactionsDl" readOnly="true">
    <query><![CDATA[
        select e from OrderLine e
        where e.order = :container_ordersDc
        order by e.createdDate desc
    ]]></query>
</loader>
```

If passing an entity manually, compare the entity-valued property to the entity parameter:

```xml
where e.order = :order
```

If passing only an id manually, compare to the id field:

```xml
where e.order.id = :orderId
```

When a loader query has a required manual parameter, never call `load()` after removing that parameter. Either bind to the selected master container, skip loading until a master is selected, or clear the child container when no master is selected.

```java
Order order = ordersDataGrid.getSingleSelectedItem();
if (order == null) {
    orderLinesDc.getMutableItems().clear();
    return;
}

orderLinesDl.setParameter("order", order);
orderLinesDl.load();
```

## Grid Selection Listener

When refreshing related data from a master grid selection, use a listener signature accepted by the component. A no-argument installed selection listener is invalid.

```java
import com.vaadin.flow.data.selection.SelectionEvent;

@Install(to = "ordersDataGrid", subject = "selectionListener")
private void ordersDataGridSelectionListener(SelectionEvent<DataGrid<Order>, Order> event) {
    Order order = ordersDataGrid.getSingleSelectedItem();
    if (order == null) {
        orderLinesDc.getMutableItems().clear();
        return;
    }

    orderLinesDl.setParameter("order", order);
    orderLinesDl.load();
}
```

If the project uses `@Subscribe("ordersDataGrid")` for selection changes, copy that existing compiled pattern instead of inventing a new listener form.

Do not append `.selected` to a container parameter. The container parameter itself represents the selected item for this loader binding.

```xml
where e.order = :container_ordersDc
```

Do not write:

```xml
where e.order = :container_ordersDc.selected
```

## Scalar Input Dialog

For a button that collects a simple scalar value and then calls a service, use the Jmix input dialog API instead of a raw Vaadin dialog.

```java
import io.jmix.flowui.Dialogs;
import io.jmix.flowui.app.inputdialog.DialogActions;
import io.jmix.flowui.app.inputdialog.DialogOutcome;
import io.jmix.flowui.app.inputdialog.InputParameter;

@Autowired
private Dialogs dialogs;

@Subscribe("adjustButton")
public void onAdjustButtonClick(final ClickEvent<JmixButton> event) {
    dialogs.createInputDialog(this)
            .withHeader(messageBundle.getMessage("adjustDialog.header"))
            .withParameters(
                    InputParameter.intParameter("quantity")
                            .withLabel(messageBundle.getMessage("adjustDialog.quantity"))
                            .withDefaultValue(0)
            )
            .withActions(DialogActions.OK_CANCEL)
            .withCloseListener(closeEvent -> {
                if (closeEvent.closedWith(DialogOutcome.OK)) {
                    Integer quantity = closeEvent.getValue("quantity");
                    if (quantity != null) {
                        service.adjust(quantity);
                        affectedDl.load();
                    }
                }
            })
            .open();
}
```

Use message keys for dialog headers, labels, and notifications. Keep service calls in services; the view should only collect input, call the service, and reload loaders.

## Forbidden

- Raw Vaadin `Dialog` for entity create/edit flows.
- Raw Vaadin `Dialog` for ordinary scalar input workflows.
- Direct service update when the domain requires creating an entity record.
- Refreshing loaders after cancel/close when no save occurred.
- Refreshing grids with `getDataProvider().refreshAll()` instead of loader reload.
- Comparing entity-valued JPQL properties to UUID parameters.
- Using `.selected` inside a `:container_*` JPQL parameter.
- Calling `load()` on a loader after removing a JPQL parameter required by its query.
- No-argument installed selection listeners for `DataGrid` selection changes.
