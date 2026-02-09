---
name: jmix-dto
description: Jmix DTO entities and plain POJOs/Records. Use when creating non-persistent presentation models for Jmix UI, building REST API request/response objects, interacting with external APIs or custom data stores.
---

# DTOs (Data Transfer Objects)

DTO entities in Jmix are used for data that exists only in memory or is mapped to external data sources through mechanisms other than JPA. They allow using Jmix's UI and data handling capabilities for non-persistent data.

## When to Use

Use this Skill when:
- Creating non-persistent presentation models for Jmix UI (e.g., in `DataGrid`, forms)
- Building REST API request/response objects
- Aggregating or transforming data from multiple JPA entities
- Interacting with external APIs or custom data stores
- Working with immutable data using Java Records (not for Jmix UI)

| Use Case                               | Pattern                   |
|----------------------------------------|---------------------------|
| Displayed in Jmix UI (dataGrid, forms) | Jmix DTO Entity           |
| Used only as REST API request/response | Plain POJO or Java Record |
| Used only in service layer             | Plain POJO or Java Record |

## Key Concepts

- **Jmix DTO Entity**: A Java class annotated with `@JmixEntity` that is registered in Jmix metadata. It can be used in data containers and UI components.
- **Identity**: Unlike JPA entities, DTOs use `@JmixId` instead of `@Id`. Use `@JmixGeneratedValue` to auto-generate UUIDs.
- **Attribute Definition**: By default, all fields with public accessors are entity attributes. Use `annotatedPropertiesOnly = true` in `@JmixEntity` to include only fields explicitly marked with `@JmixProperty`.
- **Data Stores**: DTOs can be associated with custom data stores via `@Store(name = "custom_store")` for CRUD operations.
- **Plain POJOs/Records**: Prefer for internal service logic or REST controllers where Jmix UI features are not required.

## Usage

- **Defining a DTO Entity**: 
  - Annotate with `@JmixEntity`. 
  - If the project is an add-on, specify entity name with prefix in `name` attribute: `@JmixEntity(name = "app_CustomerSummaryDto")`.
  - Define a unique ID field with `@JmixId`.
  - Use `@InstanceName` for display name attribute.
- **Key Annotations**:
  - `@JmixEntity`: Registers the class. Optional `annotatedPropertiesOnly` attribute.
  - `@JmixId`: Mandatory for Jmix UI-bound entities.
  - `@JmixGeneratedValue`: Enables UUID generation.
  - `@JmixProperty`: Customizes attributes (e.g., `mandatory = true`).
  - `@Store`: Links to a non-JPA data store.
- **Instantiating**: Use `dataManager.create(Dto.class)` or `metadata.create(Dto.class)` to ensure proper initialization of IDs and metadata.
- **Validation**: Use standard Jakarta Bean Validation annotations. Apply `@Valid` for nested objects and `@Validated` on service classes.
- **Localization**: Define messages in `messages.properties` using the entity name or FQN.
- **Java Records**: Use for immutable, non-UI DTOs to benefit from concise syntax and built-in immutability.

See usage examples in [references/examples.md](references/examples.md).

## Forbidden
  - Never use `@Entity` or `@Table` on DTOs.
  - Avoid Lombok `@EqualsAndHashCode` and `@Data` as they can interfere with Jmix enhancements.
  - Do not attempt to persist DTOs directly to the database via JPA.
  - Do not use `new Dto()` for UI-bound instances; use `DataManager.create()` instead.
