---
name: jmix-add-i18n-keys
description: Add complete Jmix message keys for entities, enums, views, actions, and validation text.
---

# Add I18n Keys

Use this skill whenever adding user-visible text, entities, enum values, views, or validation messages.

## Steps

1. Find all locale files in the application message bundle.
2. Add the same keys to every locale file.
3. Use entity keys for entity captions and attributes.
4. Use enum keys for every enum constant.
5. Use view-local keys for titles, button text, labels, and dialog text.
6. Use `msg://` in XML descriptors.
7. Use `MessageBundle` in view controllers and `Messages` in services/beans.
8. Check every `msg://` reference against the bundle key exactly; key lookup is case-sensitive.

## Key Patterns

```properties
com.company.app.entity/Customer=Customer
com.company.app.entity/Customer.name=Name

com.company.app.entity/OrderStatus=Order status
com.company.app.entity/OrderStatus.NEW=New

customerListView.title=Customers
customerDetailView.title=Customer
createOrderButton.text=Create order
```

## XML Usage

```xml
<view title="msg://customerListView.title">
    <button id="createOrderButton" text="msg://createOrderButton.text"/>
</view>
```

## Java Usage In Views

```java
@ViewComponent
private MessageBundle messageBundle;

String text = messageBundle.getMessage("createOrderButton.text");
```

## Exact Reference Audit

Before finishing, search changed XML and Java for message references and verify the keys exist in the correct bundle with identical casing.

```xml
<button id="createOrderButton" text="msg://createOrderButton.text"/>
```

```properties
createOrderButton.text=Create order
```

Do not rely on similar casing such as `CreateOrderButton.text` or `createorderButton.text`.

## Forbidden

- Hardcoded user-visible text in XML or Java controllers.
- Adding a key to only one locale file.
- `msg://` keys that differ from properties keys only by case.
- Missing enum constant messages.
- `${0}` placeholders in `formatMessage`; use Java formatter placeholders such as `%s`.
