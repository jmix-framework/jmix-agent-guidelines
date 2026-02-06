---
name: jmix-entities
description: Jmix JPA entities. Use when defining the data model, configuring persistence, implementing auditing, soft delete, and handling relationships. Covers mandatory Jmix annotations, ID generation, optimistic locking, and instance names.
---

# Entities

Entities are the backbone of a Jmix application, representing the data model and mapped to database tables via JPA (Jakarta Persistence API) with additional Jmix-specific metadata.

## When to Use

Use this Skill when:
- Defining or modifying the application data model using JPA entities
- Configuring entity persistence, including table names, columns, and indexes
- Implementing human-readable representation of entities via instance names
- Setting up entity relationships (associations and compositions)
- Enabling framework features like auditing, soft delete, and optimistic locking
- Working with multiple data stores or complex inheritance strategies
- Adding validation constraints to entity attributes
- Initializing default values or creating transient/calculated properties
- Creating Liquibase changelogs for database schema synchronization

## Key Concepts

- **Jmix Metadata**: The `@JmixEntity` annotation is mandatory. It registers the entity in Jmix metadata, enabling UI components, security, and DataManager to work with it.

| Annotation    | Purpose                           |
|---------------|-----------------------------------|
| `@Entity`     | JPA persistence                   |
| `@JmixEntity` | Includes entity to Jmix metadata  |

**Both are required!** Without `@JmixEntity`, the entity won't appear in UI and security won't apply.
- **Persistence Mapping**: Standard JPA annotations from `jakarta.persistence` (`@Entity`, `@Table`, `@Column`, `@Id`) define database mapping. `@Table` can include `indexes` and `uniqueConstraints`.
- **Identity & Versioning**: 
    - Jmix typically uses UUID primary keys with `@JmixGeneratedValue` for application-level generation.
    - `@Version` enables optimistic locking (recommended `Integer` or `Long`).
- **Instance Name**: Designated by `@InstanceName`, this provides a human-readable string for the entity, used automatically in UI components.
- **DataManager**: The primary way to interact with entities. It respects Jmix-specific features like soft delete and security.
- **Soft Delete**: Mark entities as deleted (via `@DeletedBy`/`@DeletedDate`) instead of DB removal. Filtered automatically from queries.
- **Composition**: A form of association where the child entity's lifecycle is bound to the parent (annotated with `@Composition`). AKA aggregate in DDD.
- **Inheritance**: Supports standard JPA strategies: `JOINED`, `SINGLE_TABLE`, and `TABLE_PER_CLASS`.

## Usage

- **Basic Definition**: 
    - Annotate with `@JmixEntity`, `@Entity`, and `@Table`.
    - If the project is an add-on, specify entity name with prefix in `name` attribute: `@Entity(name = "app_Customer")`.
    - Include a UUID field with `@Id` and `@JmixGeneratedValue`.
    - Include an `Integer` field with `@Version` for optimistic locking.
    - Use `@Column` for constraints (`nullable`, `length`, `precision`).
    - Use `@Lob` for large text or binary data.
    - Define `@Index` or `@UniqueConstraint` in `@Table` for DB-level constraints and performance.
- **Instance Names**: 
    - Use `@InstanceName` on a field or a method.
    - If using a method, always add `@DependsOnProperties` to ensure required fields are fetched.
- **Relationships**:
    - **Always use `FetchType.LAZY`** for `@ManyToOne` and `@OneToOne`.
    - Use `@Composition` and `@OnDelete` (e.g., `DeletePolicy.CASCADE`) for parent-child relations.
- **Auditing**: Add `@CreatedBy`, `@CreatedDate`, `@LastModifiedBy`, `@LastModifiedDate` for automatic tracking.
- **Validation**: Use standard Bean Validation annotations (e.g., `@NotNull`, `@Email`, `@Size`, `@Positive`).
- **Default Values**:
  - Use special collections: `NotInstantiatedList` or `NotInstantiatedSet` instead of `ArrayList` or `HashSet` if you need to initialize collection fields. 
  - Use `@PostConstruct` to initialize fields via Spring beans like `TimeSource`.
- **Calculated Fields**: Use `@JmixProperty` + `@Transient` + `@DependsOnProperties`.
- **Liquibase**: Every entity change requires a corresponding Liquibase changelog entry in `src/main/resources/.../liquibase/changelog/`.
- **Localization**: Map entity and attribute names in `messages.properties` using the `package/Entity.property` format.

See usage examples in [references/examples.md](references/examples.md).

## Checklist
- [ ] `@JmixEntity` + `@Entity` + `@Table` present
- [ ] UUID ID with `@JmixGeneratedValue`
- [ ] `@Version` field included
- [ ] `@InstanceName` defined on field or method
- [ ] Liquibase changelog created and included in `changelog.xml`
- [ ] Localized messages added to all `messages_*.properties`

## Forbidden
- New `ArrayList` or `HashSet` instances as default values of collection attributes (use `NotInstantiatedList` or `NotInstantiatedSet` instead).
- Lombok `@EqualsAndHashCode` and `@Data` (causes issues with entity identity)
- JPA `@GeneratedValue` (use Jmix-specific `@JmixGeneratedValue` for UUIDs)
- `FetchType.EAGER` on relationships (use fetch plans instead)
- Using `EntityManager` for regular CRUD (use `DataManager` instead)
