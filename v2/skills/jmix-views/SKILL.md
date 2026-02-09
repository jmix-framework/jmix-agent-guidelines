---
name: jmix-views
description: Jmix UI views — controllers and XML descriptors, lifecycle events, annotations, and programmatic opening. Use when creating new UI views, customizing visual components, opening views programmatically.
---

# Views

Views are the main building blocks of the Jmix Flow UI, defined by a Java controller class and an XML descriptor.

## When to Use

Use this Skill when:
- Creating new UI views (List, Detail, or custom)
- Adding event handlers or renderers to visual components
- Opening views programmatically via `ViewNavigators` or `DialogWindows`
- Handling view lifecycle events for initialization, data loading, or validation
- Customizing view behavior via annotations and controller methods
- Implementing custom data loading or cross-field validation

## Key Concepts

- **View Classes**:
    - `StandardView`: Base class for views not linked to a specific entity.
    - `StandardListView`: Base class for views showing a list of entities (typically uses `DataGrid`).
    - `StandardDetailView`: Base class for creating or editing a single entity instance.
    - `StandardMainView`: The root view of the application, typically containing the main menu.
- **View Controller**: Java class annotated with `@ViewController` that handles view logic.
- **View Descriptor**: XML file defining the layout and data components, linked via `@ViewDescriptor`.
- **View Lifecycle**: Sequence of events (Init, BeforeShow, Ready, BeforeClose, AfterClose) managing the view's state.
- **Navigation & Dialogs**: Views can be opened via URL navigation (`@Route`, `ViewNavigators`) or as modal dialogs (`@DialogMode`, `DialogWindows`).
- **Validation**: Support for component-level and cross-field validation during the saving process.

## Usage

### View Declaration
Views are declared as Java classes extending one of the standard base classes.

```java
@Route(value = "customers", layout = MainView.class)
@ViewController("Customer.list")
@ViewDescriptor("customer-list-view.xml")
@LookupComponent("customersDataGrid") // For List views
@DialogMode(width = "64em")
public class CustomerListView extends StandardListView<Customer> {
}
```

Common annotations:
- `@ViewController`: Defines the unique view ID.
- `@ViewDescriptor`: Specifies the path to the XML descriptor.
- `@Route`: Defines the URL path and parent layout.
- `@DialogMode`: Configures dialog parameters (width, height, etc.).
- `@LookupComponent`: Identifies the component for entity selection in list views.
- `@EditedEntityContainer`: Identifies the data container for the edited entity in detail views.
- `@PrimaryDetailView` / `@PrimaryLookupView`: Marks the view as the default detail/lookup view for an entity.
- `@AnonymousAllowed`: Allows access without authentication.

### View Lifecycle
| Order | Event | Purpose |
|-------|-------|---------|
| 1 | `InitEvent` | View and components created; data NOT loaded. |
| 2 | `InitEntityEvent<T>` | (Detail view only) New entity instance created; set defaults here. |
| 3 | `BeforeShowEvent` | Before view is visible; trigger data loaders here. |
| 4 | `ReadyEvent` | View fully initialized and visible. |
| 5 | `ValidationEvent` | (Detail view only) Cross-field validation before save. |
| 5 | `BeforeSaveEvent` | (Detail view only) Before saving changes to the database. |
| 5 | `AfterSaveEvent` | (Detail view only) After successful save. |
| 6 | `BeforeCloseEvent` | Before closing; can prevent closing |
| 7 | `AfterCloseEvent` | After the view is closed; use for cleanup. |

### Dependency Injection
Inject visual components, `MessageBundle` and `DataContext` using `@ViewComponent`. Inject services and infrastructure beans using `@Autowired`.

### Annotated Methods 

- Event Handlers: `@Subscribe`
- Renderers: `@Supply`
- Delegates: `@Install`

### Common Methods

The following methods are frequently used in view controllers:
- `close(StandardOutcome)`: Closes the view with a given outcome.
- `closeWithDefaultAction()`: Closes the view with `StandardOutcome.CLOSE` (or `SAVE` if changed).
- `getEditedEntity()`: (Detail views) Returns the entity being edited.
- `loadAll()`: (List views) Triggers all data loaders.
- `setPageTitle(String)`: Dynamically sets the view's page title.

### Opening Views

- Navigation (URL change): use `ViewNavigators`
- Dialog Windows (Modal): use `DialogWindows`

### Best Practices

- Add each list view to the main menu.
- Always add `entity_lookup` and `entity_clear` actions to `entityPicker` components.
- Always add `<properties><property name="openMode" value="DIALOG"/></properties>` to `list_create` and `list_edit` actions of `dataGrid` displaying a `@Composition` collection attribute.
- Use `BeforeShowEvent` to trigger data loaders unless `auto="true"` is set in `dataLoadCoordinator`.
- Use `dataLoader.load()` to refresh data in visual components.
- Use handler methods with `@Subscribe`, `@Supply`, `@Install` annotations instead of programmatically adding event listeners and delegates.

See usage examples in [references/examples.md](references/examples.md).

## Workflow & Verification

### Checklist
- [ ] Java controller extends `StandardListView`, `StandardDetailView` or `StandardView`
- [ ] XML descriptor in `resources/.../view/`
- [ ] `@Route`, `@ViewController`, `@ViewDescriptor` annotations added
- [ ] Menu entry in `menu.xml` for each created list view
- [ ] Messages for title/labels added to all `messages_*.properties`

### Check Views with Jetbrains MCP
Jetbrains MCP catches many errors at design-time through Jmix Studio. To verify, use `get_file_problems("path/to/view.xml", onlyErrors=false)` to check for missing components, wrong attributes, or annotation errors.

## Forbidden
- Business logic in view controllers (move to services)
- EntityManager usage (use DataManager)
- Direct database transactions
- Use of `dataGrid.getDataProvider().refreshAll()` to refresh data in a dataGrid