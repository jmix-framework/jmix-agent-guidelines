---
name: jmix-enums
description: Jmix Enumerations - type-safe enums for proper data modeling, UI integration, and localization. Covers implementing EnumClass, fromId pattern, entity field integration, Liquibase mapping, and message bundles.
---

# Enums

Enumerations in Jmix are Java enums that implement the `EnumClass` interface, allowing them to be stored in the database by a custom identifier (String or Integer) and automatically localized in the UI.

## When to Use

Use this Skill when:
- Creating enumerations for entity attributes.
- Needing localized display names for enum constants in UI components (ComboBox, DataGrid, etc.).
- Defining custom database mapping for enum values instead of using ordinal or name.
- Integrating enums with Jmix data model for proper metadata handling.

## Key Concepts

- **EnumClass Interface**: Mandatory interface for Jmix integration. Defines `getId()` method which returns the value stored in the database.
- **Identifier Type**: Usually `String` or `Integer`. Determines the database column type (e.g., `VARCHAR` or `INT`).
- **Static fromId()**: A standard pattern for looking up an enum constant by its database identifier. Must be annotated with `@Nullable`.
- **Entity Mapping**: The entity field stores the identifier type (e.g., `String`), while getter/setter handle the conversion to the enum type.
- **Localization**: Display names are defined in message bundles (`messages_*.properties`) using the pattern `package/ClassName.CONSTANT_NAME`.
- **Metadata**: Jmix uses `EnumClass` to automatically select appropriate UI components and apply localization.

## Usage

- **Defining Enums**:
    - Implement `EnumClass<String>` or `EnumClass<Integer>`.
    - Use `Integer` ID when you need to sort or compare rows by this enum, otherwise use `String` as more readable in the database.
    - Provide a private field for the ID and an `getId()` method.
    - Implement a static `fromId(ID id)` method for reverse lookup.
- **Integrating with Entities**:
    - Declare a field with the ID type (e.g., `private String status`).
    - Annotate with `@Column`.
    - Implement getter/setter that convert between ID and Enum using `fromId()` and `getId()`.
- **Database Schema**:
    - Ensure Liquibase changelog uses the correct column type matching the ID type.
- **Localization**:
    - Add entries to `messages_*.properties` files for the enum class itself and each of its constants.

See usage examples in [references/examples.md](references/examples.md).

## Checklist
- [ ] Enum implements `EnumClass<String>` or `EnumClass<Integer>`
- [ ] `getId()` method is implemented
- [ ] Static `fromId()` method is implemented with `@Nullable`
- [ ] Entity field stores ID type (not enum class directly)
- [ ] Getter/Setter in entity perform conversion
- [ ] Localized messages are added to all `messages_*.properties` files
- [ ] Liquibase column type matches ID type

## Forbidden
- Using plain Java enums without `EnumClass` for entity attributes.
- Using `@Convert` or `AttributeConverter` for Jmix enums.
- Storing enum `.name()` or `.ordinal()` directly in the database.
- Missing `@Nullable` on `fromId()` return value.
