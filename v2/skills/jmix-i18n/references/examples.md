# Message Bundles Usage Examples

## Property File Definitions

Default location: `src/main/resources/<base_package>/messages_en.properties` (UTF-8 encoding).

```properties
# View messages
com.company.sample.view.user/userListView.title=Users
com.company.sample.view.user/userDetailPage.caption=User details
com.company.sample.view.user/infoMessage=Found %s items

# Entity messages
com.company.sample.entity/User=User
com.company.sample.entity/User.username=Username
com.company.sample.entity/User.firstName=First name

# Enum messages
com.company.sample.entity/OrderStatus.NEW=New
com.company.sample.entity/OrderStatus.PROCESSING=Processing

# Override common actions messages 
actions.Ok=OK
actions.Cancel=Cancel

# Validation messages
com.company.sample.entity/Person.age.validation.Min=Age must be at least %d
```

## Usage in XML View Descriptors

Using `msg://` prefix for keys:

```xml
<view xmlns="http://jmix.io/schema/flowui/view"
      title="msg://userListView.title">
    <layout>
        <button id="helloBtn" text="msg://helloWorld"/>
        <dataGrid id="usersDataGrid" dataContainer="usersDc">
            <columns>
                <column property="username" header="msg://com.company.sample.entity/User.username"/>
            </columns>
        </dataGrid>
    </layout>
</view>
```

## Usage in Java Controllers (MessageBundle)

`MessageBundle` can be injected into view controllers. It automatically determines the message group based on the view class.

```java
@ViewComponent
private MessageBundle messageBundle;

public void showNotification() {
    // view.package/infoMessage=Found %s items
    String message = messageBundle.formatMessage("infoMessage", itemCount);
    notifications.create(message).show();
}

public void setTitle() {
    // view.package/userListView.title=Users
    String title = messageBundle.getMessage("userListView.title");
}
```

## Usage in Services and Beans (Messages)

The `Messages` bean can be used anywhere in the application. It requires providing the message group (usually as a `Class`).

```java
@Autowired
private Messages messages;

public void doSomething() {
    // 1. Using class to identify group
    String msg1 = messages.getMessage(getClass(), "notificationKey");

    // 2. Using group name explicitly
    String msg2 = messages.getMessage("com.company.sample.view.user", "someMessage");

    // 3. Using full key
    String msg3 = messages.getMessage("com.company.sample.view.user/someMessage");

    // 4. Formatted message
    String formatted = messages.formatMessage(getClass(), "userInfo", username);
}
```

## Bean Validation

Localized validation messages using `{msg://...}`:

```java
@Min(message = "{msg://com.company.sample.entity/Person.age.validation.Min}", value = 14)
@Column(name = "AGE")
private Integer age;
```
