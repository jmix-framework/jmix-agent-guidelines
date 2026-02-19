# Coding Guidelines

This file provides guidance to AI coding agents when working with code in this repository.

## Skills and MCP

- For detailed guidance on specific Jmix features, ALWAYS use the Skill tool and available Jmix skills.
- If you don't have enough information, use Context7 MCP to search for Jmix documentation and code samples.
- Use Jetbrains MCP to check file problems with `get_file_problems("path/to/file.ext", onlyErrors=false)`

## Project

Technology Stack:
- Java 17
- Jmix 2.7 (Spring Boot 3, Vaadin Flow UI)
- Relational database
- Gradle build system

### Project Structure

Standard Gradle project layout with `src/main` and `src/test` directories. Java classes are placed in `src/main/java`, resources in `src/main/resources`.

The codebase follows a modular organization under the base package:

- `entity/` - Domain entities
- `service/` - Business logic layer
- `view/` - UI layer
    - Each view has a Java controller and XML layout descriptor
    - Views are organized by entity (client, order, etc.)
- `security/` - Role-based access control with roles interfaces

Tests are organized in packages by feature domain. The `test_support` package provides utilities for testing.

## Build & Run Commands

### Development

```bash
# Run application (starts on http://localhost:8080, log in as admin/admin)
./gradlew bootRun
```

### Testing

```bash
# Run all tests
./gradlew test

# Run specific test class
./gradlew test --tests "com.company.sample.order.OrderServiceTest"

# Run with specific test method
./gradlew test --tests "com.company.sample.order.OrderServiceTest.testOrderCalculations"
```

## Development Guidelines

Refer to the relevant skills for detailed implementation patterns.

### Working with Entities

- JPA entities: use `@JmixEntity`, UUID + `@JmixGeneratedValue`, `@Version`, `@InstanceName`
- Relationships: Use `@Composition` for parent-child aggregates
- Computed properties: Use `@JmixProperty` with `@DependsOnProperties` for caching expensive calculations
- No Lombok on entities
- When asked to create entity:
  - Java class with UUID + Version + InstanceName
  - Liquibase changelog + include in `changelog.xml`
  - Messages in ALL locale files (`messages.properties`, `messages_*.properties`)

### Working with Services

- Injection: Use constructor injection, not field injection

### Data Access

- Data access: Use `DataManager` (NOT `EntityManager`) and its fluent data loading interface for queries (see jmix-services skill))
- Fetch plans: Build optimized fetch plans to avoid N+1 queries (see jmix-fetch-plans skill))
- Transactions: Annotate with `@Transactional` when needed

### Working with Views

- View descriptors: XML files in `src/main/resources/**/view/**`
- Controllers: Java classes with `@ViewController` and `@ViewDescriptor` annotations, extend `StandardListView` / `StandardDetailView`
- Navigation: Use `ViewNavigators` for programmatic navigation between views
- When asked to create view:
  - XML descriptor + Java controller
  - Menu entry in `menu.xml`
  - Messages for title/labels in ALL locale files

### Working with Security

- Resource roles: Define as interfaces annotated with `@ResourceRole` in `security/` package and add policy annotations on methods
- Entity policies: Use `@EntityPolicy` for CRUD operations
- Attribute policies: Use `@EntityAttributePolicy` for field-level access
- View/Menu policies: Use `@ViewPolicy` and `@MenuPolicy` for UI access control

### Database Migrations

Liquibase changelogs are in `src/main/resources/**/liquibase/changelog/**.xml`:
- Organized by step numbers (010, 020, 030, etc.)
- Include new changelogs to the main `changelog.xml`
- Run automatically on application startup

### Tests

- Prefer integration tests with `@SpringBootTest` for business logic and UI tests with `@UiTest`.
- Test database with automatic schema creation via Liquibase.

### Patterns

- Business logic in services, not in views
- Dependency Injection
    - Views: `@ViewComponent` for components defined in XML (visual components, data containers, data loaders, MessageBundle, DataContext)
    - Views: `@Autowired` for Spring beans (DataManager, DialogWindows, etc.)
    - Services: Constructor injection only

### Forbidden

- Lombok on entities
- Field `@Autowired` in services (use constructor injection)
- EntityManager
- Business logic in views
- Edits in `frontend/generated/`
- Hardcoded UI text — ALL labels, titles, buttons MUST use `msg://` keys
- Single-locale messages — ALWAYS add to ALL locale files

### Validation Checklist

- Entity: UUID + Version + InstanceName present
- Changelog added to `changelog.xml`
- Messages added for all components (entity, enum, view titles, labels)
- View: XML + Java pair; menu updated
- Security: role covers entity/view/menu

## Development Workflow

After writing or modifying code, validate using this sequence:

1. **Check file problems** — if `jetbrains` MCP available, use it to check file problems for each modified file with `get_file_problems("path/to/file.ext", onlyErrors=false)`
2. **Write tests** — create/update tests for new functionality
3. **Run tests** — `./gradlew test` to verify nothing is broken
4. **UI verification** (for views) — if `playwright` MCP available and app is running:
    - Navigate to the view
    - Verify data displays correctly
    - Click or do things that should trigger UI logic
    - Test CRUD operations
