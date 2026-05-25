# Jmix Coding Guidelines

Use these instructions when working on a Jmix 2 application.

## Project Stack

- Java 17
- Jmix 2, Spring Boot 3, Vaadin 24
- Gradle
- Relational database with Liquibase migrations

## Skill Routing

Use the most specific skill for the task:

- Creating or changing a persistent entity: `jmix-create-entity`
- Creating an enum used by an entity: `jmix-create-enum`
- Creating a list view: `jmix-create-list-view`
- Creating a detail view: `jmix-create-detail-view`
- Creating parent-child composition editing: `jmix-create-composition-detail-view`
- Implementing service-layer business logic: `jmix-create-service`
- Opening an entity detail dialog from a button/action: `jmix-add-dialog-detail-flow`
- Adding entity lifecycle/event business logic: `jmix-add-entity-event-listener`
- Adding or changing database schema: `jmix-create-liquibase-changelog`
- Creating or changing resource roles: `jmix-create-resource-role`
- Adding user-visible text or entity/enum captions: `jmix-add-i18n-keys`
- Configuring fetch plans or fixing unfetched/N+1 loading issues: `jmix-configure-fetch-plan`
- Creating DTO entities or UI-bound non-persistent models: `jmix-create-dto-entity`
- Creating reusable Flow UI fragments or fragment renderers: `jmix-create-fragment`
- Adding or changing tests: `jmix-create-test`

## Tooling

- If Context7 MCP is available, use it to confirm unfamiliar Jmix APIs and to find Jmix code examples.
- If JetBrains MCP is available and the project is open in IntelliJ IDEA, use it to check modified files for inspections and errors.
- For UI changes, if Playwright is available and the application can be run, use it to verify navigation and user interactions in the browser.
- Do not block work if these tools are unavailable; state what was checked manually instead.

## Global Rules

- Prefer Jmix APIs and generated project patterns over raw framework code.
- For change requests on an existing feature, preserve existing behavior and constraints unless the new request explicitly changes them. Inspect current entities, views, listeners, roles, and changelogs before editing.
- Use `DataManager` for normal CRUD. Use `EntityManager` only for bulk/native operations that `DataManager` cannot express, and only inside an explicit transaction.
- Keep business logic in services or Spring event listeners, not in view controllers.
- Do not use Lombok on Jmix entities.
- Do not instantiate Jmix entities with constructors. Use `DataManager.create()`, `Metadata.create()`, or `DataContext.create()` depending on context.
- Do not hardcode user-visible UI text. Use message keys.
- Do not invent XML component attributes, Vaadin icon names, or Jmix action ids. Reuse existing project patterns or omit optional decoration.
- Before using a Jmix or Vaadin API that is not already used in the project, search the current project for a working example; if none exists and Context7 MCP is available, use it to confirm the API and follow official examples.
- Do not edit generated frontend files.

## Required Cross-Cutting Work

For each new persistent entity, complete all related artifacts:

- Entity class with Jmix/JPA metadata.
- Liquibase changelog included from the root changelog.
- Message keys for entity, attributes, enum values, view titles, buttons, and actions.
- List/detail views when the entity is user-facing.
- Resource role policies for entity operations, attributes, views, and menu items.

For each new user-facing view:

- Java controller and XML descriptor.
- Stable view id.
- Menu entry for top-level list views only.
- Message keys for titles, labels, and buttons.
- View policies for every role that can open it, including dialog-only detail views.
- Visible buttons or menu items for every action the user must be able to trigger.
- Typed form components that match property types.

For each new business operation:

- Put the operation in a service or listener, not in a view.
- Define clear transaction boundaries.
- Prefer `DataManager` for CRUD.
- Keep UI notifications, dialogs, and components out of services.
- Defaults for required persistent fields must work outside UI-only paths.

For each DTO entity or UI-bound non-persistent model:

- Use Jmix DTO metadata, not JPA annotations.
- Provide a stable `@JmixId` when identity matters.
- Add message keys when the model is shown in UI or exposed with localized captions.
- Keep DTO entities out of Liquibase unless they are backed by an explicit custom persistence mechanism.

For each reusable UI fragment:

- Create both controller and XML descriptor.
- Keep fragment XML self-contained or explicitly mark host-provided data components.
- Use fragment-specific facets when needed.
- Add message keys for user-visible fragment text.

## Validation Before Finishing

- Run the smallest relevant compile/test command available for the change.
- Read compile and startup failures; fix deterministic failures before reporting completion.
- Search changed XML and Java for obvious drift before reporting completion: table names in JPQL, unresolved `msg://` keys, hardcoded visible labels, missing components referenced by `urlQueryParameters`, raw Vaadin dialogs for Jmix workflows, unsafe loader parameter handling, after-commit listeners used for validation or required mutations, and form components that do not match property types.
- Compare resource role menu policies against actual `menu.xml` item ids or view ids.
- For update tasks, compare touched artifacts against their previous constraints and defaults before reporting completion.
- If tests cannot be run, state the exact blocker and what was validated instead.
