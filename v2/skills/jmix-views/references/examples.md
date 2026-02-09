# Views Usage Examples

## Standard List View

### Java Controller
```java
package com.company.project.view.customer;

import com.company.project.entity.Customer;
import com.company.project.view.main.MainView;
import com.vaadin.flow.router.Route;
import io.jmix.flowui.view.*;

@Route(value = "customers", layout = MainView.class)
@ViewController("Customer.list")
@ViewDescriptor("customer-list-view.xml")
@LookupComponent("customersDataGrid")
@DialogMode(width = "64em")
public class CustomerListView extends StandardListView<Customer> {
}
```

### XML Descriptor
```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<view xmlns="http://jmix.io/schema/flowui/view"
      title="msg://customerListView.title"
      focusComponent="customersDataGrid">
    <data readOnly="true">
        <collection id="customersDc" class="com.company.project.entity.Customer">
            <fetchPlan extends="_base"/>
            <loader id="customersDl">
                <query><![CDATA[select e from Customer e]]></query>
            </loader>
        </collection>
    </data>
    <facets>
        <dataLoadCoordinator auto="true"/>
    </facets>
    <layout>
        <hbox id="buttonsPanel" classNames="buttons-panel">
            <button id="createBtn" action="customersDataGrid.create"/>
            <button id="editBtn" action="customersDataGrid.edit"/>
            <button id="removeBtn" action="customersDataGrid.remove"/>
        </hbox>
        <dataGrid id="customersDataGrid" dataContainer="customersDc" width="100%">
            <actions>
                <action id="create" type="list_create"/>
                <action id="edit" type="list_edit"/>
                <action id="remove" type="list_remove"/>
            </actions>
            <columns resizable="true">
                <column property="name"/>
                <column property="email"/>
            </columns>
        </dataGrid>
    </layout>
</view>
```

## Standard Detail View

### Java Controller
```java
@Route(value = "customers/:id", layout = MainView.class)
@ViewController("Customer.detail")
@ViewDescriptor("customer-detail-view.xml")
@EditedEntityContainer("customerDc")
public class CustomerDetailView extends StandardDetailView<Customer> {
}
```

### XML Descriptor
```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<view xmlns="http://jmix.io/schema/flowui/view"
      title="msg://customerDetailView.title">
    <data>
        <instance id="customerDc" class="com.company.project.entity.Customer">
            <fetchPlan extends="_base"/>
            <loader/>
        </instance>
    </data>
    <facets>
        <dataLoadCoordinator auto="true"/>
    </facets>
    <actions>
        <action id="saveAction" type="detail_saveClose"/>
        <action id="closeAction" type="detail_close"/>
    </actions>
    <layout>
        <formLayout id="form" dataContainer="customerDc">
            <textField id="nameField" property="name"/>
            <textField id="emailField" property="email"/>
        </formLayout>
        <hbox id="detailActions">
            <button id="saveAndCloseBtn" action="saveAction"/>
            <button id="closeBtn" action="closeAction"/>
        </hbox>
    </layout>
</view>
```

## Dependency Injection

```java
@ViewComponent
private DataGrid<Customer> customersDataGrid;
@ViewComponent
private CollectionLoader<Customer> customersDl;
@ViewComponent
private MessageBundle messageBundle; // NOT @Autowired!
@ViewComponent
private DataContext dataContext;  // NOT @Autowired!

@Autowired
private DialogWindows dialogWindows;
@Autowired
private DataManager dataManager;
@Autowired
private Notifications notifications;
@Autowired
private Messages messages;
```

## Event Handlers (@Subscribe)

```java
// InitEntityEvent — set defaults for NEW entities
@Subscribe
public void onInitEntity(InitEntityEvent<Customer> event) {
    event.getEntity().setStatus(CustomerStatus.NEW);
}

// ValidationEvent — cross-field validation
@Subscribe
public void onValidation(ValidationEvent event) {
    Customer c = getEditedEntity();
    if (c.getEndDate() != null && c.getStartDate() != null 
            && c.getEndDate().isBefore(c.getStartDate())) {
        event.getErrors().add("End date must be after start date");
    }
}
```

## Renderers (@Supply)

```java
@Supply(to = "customersDataGrid.status", subject = "renderer")
private Renderer<Customer> statusRenderer() {
    return new ComponentRenderer<>(customer -> {
        Span badge = new Span(customer.getStatus().name());
        badge.getElement().getThemeList().add("badge");
        return badge;
    });
}
```

## Delegates (@Install)

```java
@Install(to = "departmentsDl", target = Target.DATA_LOADER) 
private List<Department> departmentsDlLoadDelegate(final LoadContext<Department> loadContext) { 
    LoadContext.Query query = loadContext.getQuery();
    return departmentService.loadDepartments( 
            query.getCondition(),
            query.getSort(),
            query.getFirstResult(),
            query.getMaxResults()
    );
}
```

## Validation
Cross-field validation in detail views:
```java
@Subscribe
public void onValidation(ValidationEvent event) {
    Customer c = getEditedEntity();
    if (c.getEndDate() != null && c.getEndDate().isBefore(c.getStartDate())) {
        event.getErrors().add("End date must be after start date");
    }
}
```

Manual validation using `ViewValidation` bean:
```java
@Autowired
private ViewValidation viewValidation;

ValidationErrors errors = viewValidation.validateUiComponents(getContent());
if (!errors.isEmpty()) {
    viewValidation.showValidationErrors(errors);
}
```

## Opening Views

### ViewNavigators (URL changes)
```java
@Autowired
private ViewNavigators viewNavigators;

viewNavigators.detailView(this, Customer.class)
    .editEntity(customer)
    .navigate();
```

### DialogWindows (Modal, no URL)
```java
@Autowired
private DialogWindows dialogWindows;

dialogWindows.detail(this, Customer.class)
    .editEntity(customer)
    .withAfterCloseListener(e -> {
        if (e.closedWith(StandardOutcome.SAVE)) {
            customersDl.load();
        }
    })
    .open();
```
