---
name: jmix-i18n
description: Jmix message bundles (i18n/l10n). Use when adding messages and translations. Covers naming conventions, using messages in views.
---

# Internationalization (i18n)

Internationalization in Jmix allows for localized messages and data formats based on the user's locale. It relies on message bundles — collections of UTF-8 property files.

## When to Use

Use this Skill when:
- Creating or modifying any UI view
- Adding new entity fields or enumerations
- Adding buttons, actions, or notifications
- Externalizing validation messages
- Providing localized data formats

## Key Concepts

- **Message Bundles**: A set of `messages_<language>.properties` files. The default bundle is located in the base package under `src/main/resources`.
- **Message Groups**: Prefixes in message keys (e.g., `com.company.sample.view.user/`) that organize messages. Usually follow the package structure of the related component.
- **Critical Rule**: Every message key MUST exist in ALL locale files to avoid missing translations.
- **Encoding**: All property files must use UTF-8 encoding.
- **Naming Conventions**:
    - **Views**: `view.package/viewClassName.elementId=Value`
    - **Entities**: `entity.package/EntityName=Value` and `entity.package/EntityName.attributeName=Value`
    - **Enums**: `enum.package/EnumName.VALUE=Value`
    - **Common Actions**: Prefix with `actions.` (e.g., `actions.Ok`, `actions.Cancel`)

## Usage

- **XML View Descriptors**:
    - Use `msg://` prefix for keys (e.g., `<view title="msg://orderListView.title">`).
    - Visual components also support `msg://` in attributes like `text`, `header`, `label`, and `caption`.
    - Message group is automatically inferred from the view's package.
- **Java Controllers (MessageBundle)**:
    - Inject `MessageBundle` to retrieve messages. It automatically uses the view's package as the message group.
    - Use `messageBundle.getMessage("key")` or `messageBundle.formatMessage("key", params)`.
    - Message group is automatically inferred from the view's package.
- **Services and Beans (Messages)**:
    - Inject `Messages` bean.
    - Retrieve via `messages.getMessage(Class, "key")`, `messages.getMessage("group", "key")`, or `messages.getMessage("group/key")`.
- **Format messages**:
    - Use `%s` (string) and `%d` (integer) for `formatMessage("key", params)` parameter placeholders (as in `java.util.Formatter`). NEVER use `${n}` placeholders.
- **Bean Validation**:
    - Use `{msg://...}` syntax in validation annotations (e.g., `@Min(message = "{msg://...}", value = 14)`).

See usage examples in [references/examples.md](references/examples.md).

## Best Practices

- **Avoid Hardcoding**: Never use hardcoded strings in XML or Java code for user-visible text.
- **Consistency**: Maintain consistent naming patterns across all message bundles.
- **All Locales**: Always add new keys to all supported `messages_*.properties` files simultaneously.
 
## Checklist

- [ ] Key follows naming convention.
- [ ] Added to ALL locale files.
- [ ] Used `msg://` prefix in XML.
- [ ] No duplicate keys.
- [ ] No hardcoded text in XML views.

## Forbidden

- `${n}` placeholders for `formatMessage()` (use `%s` or `%d` instead).
