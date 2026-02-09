# Fragments Usage Examples

## Fragment Definition

Controller:
```java
@FragmentDescriptor("customer-list-fragment.xml")
public class CustomerListFragment extends Fragment<VerticalLayout> {
    @Subscribe
    public void onReady(final ReadyEvent event) {
        getFragmentData().loadAll(); // Triggers load() on all loaders
    }
}
```

XML Descriptor:
```xml
<fragment xmlns="http://jmix.io/schema/flowui/fragment">
    <data>
        <collection id="customersDc" class="com.company.onboarding.entity.Customer">
            <fetchPlan extends="_base">
                <property name="city" fetchPlan="_base"/>
            </fetchPlan>
            <loader id="customersDl" readOnly="true">
                <query><![CDATA[select e from Customer e]]></query>
            </loader>
        </collection>
    </data>
    <content>
        <vbox id="root" padding="false">
            <genericFilter id="genericFilter" dataLoader="customersDl">
                <properties include=".*"/>
            </genericFilter>
            <hbox id="buttonsPanel" classNames="buttons-panel">
                <button id="createBtn" action="customersDataGrid.create"/>
                <button id="editBtn" action="customersDataGrid.edit"/>
                <button id="removeBtn" action="customersDataGrid.remove"/>
                <simplePagination id="pagination" dataLoader="customersDl"/>
            </hbox>
            <dataGrid id="customersDataGrid"
                      width="100%"
                      minHeight="20em"
                      dataContainer="customersDc"
                      columnReorderingAllowed="true">
                <actions>
                    <action id="create" type="list_create"/>
                    <action id="edit" type="list_edit"/>
                    <action id="remove" type="list_remove"/>
                </actions>
                <columns resizable="true">
                    <column property="city"/>
                    <column property="level"/>
                    <column property="age"/>
                    <column property="martialStatus"/>
                    <column property="hobby"/>
                </columns>
            </dataGrid>
        </vbox>
    </content>
</fragment>
```

## Autowiring and Event Handling

```java
@ViewComponent
public JmixButton button; // Injects a UI component

@ViewComponent
public CollectionContainer<Customer> collectionDc; // Injects a data container

@Subscribe
public void onReady(ReadyEvent event) {
    // Initialization logic
}

@Subscribe(value = "button", subject = "clickListener")
public void onButtonClick(ClickEvent<JmixButton> event) {
    // Handle button click
}
```

### Subscribing to Host Events

```java
@Subscribe(target = Target.HOST_CONTROLLER)
public void onHostInit(View.InitEvent event) {
    // Handle view initialization
}

@Subscribe(target = Target.HOST_CONTROLLER)
public void onHostBeforeShow(View.BeforeShowEvent event) {
    // Handle before view is shown
}

@Subscribe(target = Target.HOST_CONTROLLER)
public void onHostReady(View.ReadyEvent event) {
    // Handle when host view is ready
}
```

## Declarative Embedding

```xml
<view xmlns="http://jmix.io/schema/flowui/view">
    <layout>
        <details id="addressDetails" summaryText="Address" opened="true" alignSelf="STRETCH">
            <fragment class="com.company.onboarding.view.address.var1.AddressFragment"/>
        </details>
    </layout>
</view>
```

## Programmatic Embedding

```java
@Route(value = "HostView", layout = MainView.class)
@ViewController("HostView")
@ViewDescriptor("host-view.xml")
public class HostView extends StandardView {

    @ViewComponent
    private Details addressDetails;

    @Autowired
    private Fragments fragments;

    @Subscribe
    public void onInit(InitEvent event) {
        AddressFragment addressFragment = fragments.create(this, AddressFragment.class);
        addressDetails.add(addressFragment);
    }
}
```

## Fragment Renderer

Fragment XML descriptor:
```xml
<fragment xmlns="http://jmix.io/schema/flowui/fragment">
    <data>
        <instance id="userDc" class="com.company.onboarding.entity.User">
            <loader id="userDl"/>
            <fetchPlan extends="_base"/>
        </instance>
    </data>
    <content>
        <hbox>
            <icon icon="ANGLE_DOUBLE_RIGHT"/>
            <formLayout id="form" dataContainer="userDc">
                <textField property="username" readOnly="true"/>
                <textField property="firstName" readOnly="true"/>
                <textField property="lastName" readOnly="true"/>
                <textField property="email" readOnly="true"/>
            </formLayout>
        </hbox>
    </content>
</fragment>
```

Fragment controller:
```java
@FragmentDescriptor("user-fragment.xml")
@RendererItemContainer("userDc")
public class UserFragment extends FragmentRenderer<HorizontalLayout, User> {
}
```

Usage in a visual component:
```xml
<virtualList itemsContainer="usersDc">
    <fragmentRenderer
            class="com.company.onboarding.view.component.virtuallist.UserFragment"/>
</virtualList>
```

## Passing Parameters

```java
@FragmentDescriptor("address-fragment.xml")
public class AddressFragment extends Fragment<FormLayout> {

    @ViewComponent
    private EntityComboBox<City> cityField;
    @ViewComponent
    private TypedTextField<String> zipcodeField;

    public void setCitiesContainer(CollectionContainer<City> citiesContainer) {
        cityField.setItems(citiesContainer);
    }

    public void setZipcodePlaceholder(String placeholder) {
        zipcodeField.setPlaceholder(placeholder);
    }
}
```

### Declarative Parameter Passing

```xml
<view xmlns="http://jmix.io/schema/flowui/view">
    <data>
        <collection id="citiesDc" class="com.company.onboarding.entity.City">
            <fetchPlan extends="_base"/>
            <loader id="citiesDl" readOnly="true">
                <query><![CDATA[select e from City e]]></query>
            </loader>
        </collection>
    </data>
    <layout>
        <details id="addressDetails" summaryText="Address" opened="true" alignSelf="STRETCH">
            <fragment class="com.company.onboarding.view.address.var2.AddressFragment">
                <properties>
                    <property name="citiesContainer" value="citiesDc" type="CONTAINER_REF"/>
                    <property name="zipcodePlaceholder" value="Zipcode"/>
                </properties>
            </fragment>
        </details>
    </layout>
</view>
```

### Programmatic Parameter Passing

```java
@ViewComponent
private CollectionContainer<City> citiesDc;

@Autowired
private Fragments fragments;

@Subscribe
public void onInit(InitEvent event) {
    AddressFragment addressFragment = fragments.create(this, AddressFragment.class);
    addressFragment.setCitiesContainer(citiesDc);
    addressFragment.setZipcodePlaceholder("Zipcode");
    getContent().add(addressFragment);
}
```

## Own Data Components

```xml
<fragment xmlns="http://jmix.io/schema/flowui/fragment">
    <data>
        <collection id="citiesDc" class="com.company.onboarding.entity.City">
            <fetchPlan extends="_base"/>
            <loader id="citiesDl" readOnly="true">
                <query><![CDATA[select e from City e]]></query>
            </loader>
        </collection>
    </data>
    <content>
        <formLayout id="addressForm">
            <entityComboBox id="cityField" label="City" itemsContainer="citiesDc"/>
            <textField id="zipcodeField" label="Zipcode"/>
        </formLayout>
    </content>
</fragment>
```

```java
@FragmentDescriptor("address-fragment.xml")
public class AddressFragment extends Fragment<FormLayout> {

    @ViewComponent
    private CollectionLoader<City> citiesDl;

    @Subscribe(target = Target.HOST_CONTROLLER)
    protected void onHostBeforeShow(View.BeforeShowEvent event) {
        citiesDl.load();
    }
}
```

## Provided Data Components

Host view:
```xml
<view xmlns="http://jmix.io/schema/flowui/view">
    <data>
        <instance id="addressDc"
                  class="com.company.onboarding.entity.Address">
            <fetchPlan extends="_base"/>
            <loader/>
        </instance>

        <collection id="citiesDc"
                    class="com.company.onboarding.entity.City">
            <fetchPlan extends="_base"/>
            <loader id="citiesDl" readOnly="true">
                <query>
                    <![CDATA[select e from City e]]>
                </query>
            </loader>
        </collection>
    </data>
    <facets>
        <dataLoadCoordinator auto="true"/>
    </facets>
    <layout>
        <details id="addressDetails" summaryText="Address" opened="true" alignSelf="STRETCH">
            <fragment class="com.company.onboarding.view.address.var4.AddressFragment"/>
        </details>
    </layout>
</view>
```

Fragment XML descriptor:
```xml
<fragment xmlns="http://jmix.io/schema/flowui/fragment">
    <data>
        <!-- containers with the same id must exist in a host view or enclosing fragment -->
        <instance id="addressDc" class="com.company.onboarding.entity.Address" provided="true"/>
        <collection id="citiesDc" class="com.company.onboarding.entity.City" provided="true"/>
    </data>
    <content>
        <formLayout id="addressForm" dataContainer="addressDc">
            <entityComboBox id="cityField" itemsContainer="citiesDc" property="city"/>
            <textField id="zipcodeField" property="zipcode"/>
        </formLayout>
    </content>
</fragment>
```