# Jmix agent — operating instructions

## Step 0 — map the task to artifacts, READ the matching rules BEFORE writing

The most common cause of defects is writing a Jmix artifact from memory instead
of from the rule that governs it. The written guideline/skill is ground truth;
your Jmix/Vaadin priors are the single biggest source of wrong API names and
broken descriptors.

Before writing a single file:

1. List every artifact the task implies — each entity, enum, list view, detail
   view, composition child view, service, event listener, resource role,
   changelog, menu entry, message bundle.
2. For EACH artifact, READ the matching guideline section / skill BEFORE you
   write it (see **Skill routing**). Do not write an entity without the entity
   rules, a detail view without the detail-view rules, a role without the role
   rules, a button/selection/dialog flow without the dialog-flow rules, or a
   parent-child grid without the composition rules.
3. Only then start writing.

Reading only the verification skills (`idea-static-analysis`,
`jmix-verify-bootrun`) is NOT enough — those are the gates, not the how-to.

## Tooling — MCP servers FIRST when connected, universal floor when not

This profile may ship MCP servers — a Jmix-aware IDE inspection (e.g. JetBrains
`get_file_problems`), a docs lookup (Context7 `/jmix-framework/jmix-context7`),
and a browser-automation tool (Playwright). **When a server is connected, it is
your PRIMARY verification — reach for it first**: Context7 to confirm an API
before you type it, the IDE inspection on every file you write, the browser to
render-walk what you built. The MCP tools catch the expensive defects
(hallucinated APIs, broken `*-view.xml`, render failures) the cheap checks miss.
ANY server may be absent — when one is, do NOT skip the check; fall back to the
universal floor available to everyone: `compileJava`, `./gradlew clean test`, and
the mechanical checks below. MCP first; floor always.

## Gates before declaring a task done

A task is NOT done after the code compiles. Three gates, in order; never assert a
gate passed without showing the evidence. **At each gate use the MCP tool if it
is connected (primary); fall back to the universal check only when it is not.**

| Gate | Primary — MCP, if connected | Fallback — always available |
|------|------|------|
| 1 API & static | verify EVERY Jmix/Vaadin symbol via **Context7** (`/jmix-framework/jmix-context7`) before you type it, AND run the IDE inspection (**`get_file_problems`**) on every file you wrote — it catches `*-view.xml` semantics the compiler cannot | `compileJava` + the mechanical checks |
| 2 Context loads | *(no MCP substitute — always run the fallback)* | `./gradlew --no-daemon clean test` — boots the Spring/Jmix context, runs Liquibase + the project's tests, then EXITS |
| 3 Render | render-walk every view/button/field you created with the **browser tool** (Playwright) — confirm no error overlay, server exception, or raw `msg://` caption | no universal substitute — run the mechanical checks (the render-defect floor) incl. unresolved `msg://`, then state `render not browser-verified` |

NEVER use `bootRun` (or any non-terminating server start) as the Gate-2 check —
it does not exit and will hang your turn. Gate 2 is `clean test`. If you DO start
a server to render-walk, run it in the background and poll `/actuator/health`
until it is UP before driving the browser, then shut it down cleanly.

**`compileJava` is BLIND to XML descriptors.** Every `*-view.xml` defect — a
reference/enum field bound wrong, an `itemsQuery` missing `:searchString`, an
action opening a view id that does not exist (`NoSuchViewException`) — compiles
perfectly clean. A Jmix-aware inspection (if you have one) is the only STATIC
catch for unresolved `msg://`, invalid property paths, and missing data
containers. Without one, the mechanical checks are MANDATORY whenever Gate-3 is
skipped — they are then your ONLY render-defect catch.

**A green `clean test` is NOT evidence the UI renders or the policies are
correct.** The context-load tests boot the Spring/Jmix context but do NOT open your
new views or exercise your new roles. Gate 2 is necessary, never sufficient.

**Emit the evidence in your completion report.** Per file you touched: its
static-check verdict. Per view/button/field you created: how you verified it
(inspection, mechanical check, or render walk). "BUILD SUCCESSFUL, all done" with
no per-file check and no render evidence is a non-answer.

## Anti-hallucination — verify a symbol before you type it

Inventing plausible-looking API names is a top failure mode: they survive typing
but blow up at compile or runtime. RULE: before you type any Jmix/Vaadin symbol
not already used in this project's `src/`, verify it — **Context7
(`/jmix-framework/jmix-context7`) is your PRIMARY check when connected**, or an
IDE symbol search; only if neither is available, grep this project for a working
example. (If the exact symbol is already used in `src/`, copy that call site.)
Guessing and then brute-forcing compile errors is the single biggest time-sink.

High-frequency wrong→right traps (the full table lives in `verify-api-symbol`):

- Packages: `io.jmix.flowui.Dialogs` (NOT `io.jmix.flowui.dialogs.Dialogs`);
  `io.jmix.core.EntityStates` (NOT `io.jmix.core.entity.EntityStates`);
  `io.jmix.flowui.component.grid.DataGrid` (NOT `...component.datagrid.DataGrid`).
- A button `@Subscribe` / `@Install(subject="clickListener")` handler takes
  `ClickEvent<JmixButton>` — NOT `Component` or `ActionPerformedEvent`. The wrong
  type throws `IllegalArgumentException: argument type mismatch` AT THE CLICK; fix
  the HANDLER PARAM TYPE, not the dialog/InputParameter.
- Grid selection: `getSingleSelectedItem()` (NOT `getSingleSelected`).
- `VaadinIcon` constants are irregular — verify the exact constant exists.
- `JmixButton.ClickEvent`, `DataGrid.ReadEvent`, `Target.DATA_GRID` are invented
  inner-classes/enums — they do not exist.

## Static analysis & inspections

After writing each file, verify it — **inspection first**. If a Jmix-aware IDE
inspection is connected (e.g. JetBrains `get_file_problems`), run it on every
file you wrote: that is your PRIMARY static check, and for a `*-view.xml` it is
the only static catch for unresolved `msg://`, invalid property paths, and
missing data containers. Only if no inspection is available, fall back to
`compileJava` + the mechanical checks. Inspection findings arrive as WARNINGS;
act on them as blockers. Never treat an empty or unconfirmed inspection result as
"clean" — an unconfirmed EMPTY result is false-clean. See `idea-static-analysis`.

## Skill routing

READ the most specific section/skill for each artifact:

- Verify a Jmix/Vaadin API: `verify-api-symbol` (Context7 `/jmix-framework/jmix-context7` first if available, else IDE symbol search, else project search)
- Static checks / inspections: `idea-static-analysis`
- Gate-2 context-load test (+ optional Gate-3 render walk): `jmix-verify-bootrun`
- Persistent entity: `jmix-create-entity`
- Enum used by an entity: `jmix-create-enum`
- List view: `jmix-create-list-view`
- Detail view: `jmix-create-detail-view`
- Parent-child composition editing (property-bound container, NO query loader): `jmix-create-composition-detail-view`
- Service-layer business logic: `jmix-create-service`
- Detail dialog from a button/action, OR master-row selection → filtered child grid (`setParameter` + `load`, loader kept OUT of `auto` coordination): `jmix-add-dialog-detail-flow`
- Entity lifecycle/event business logic: `jmix-add-entity-event-listener`
- Database schema: `jmix-create-liquibase-changelog`
- Resource roles: `jmix-create-resource-role`
- User-visible text / entity-enum captions: `jmix-add-i18n-keys`
- Tests: `jmix-create-test`
- Fetch plans / unfetched-reference / N+1 tuning: `jmix-configure-fetch-plan`
- DTO / non-persistent UI-bound model: `jmix-create-dto-entity`
- Reusable Flow UI fragment: `jmix-create-fragment`

**Service and entity defaulting are separate concerns.** A service or listener
that mutates a required attribute at UPDATE time does NOT relieve the entity from
defaulting that field on initial persist (see **Required Cross-Cutting Work**).

## When tests fail — it is almost never "pre-existing"

If the project ships a passing test suite and a test goes red after your change,
assume you broke it. A red `clean test` means the task is not done; investigate
before declaring a red gate "pre-existing." Common causes:

- **`NoSuchViewException` after you added views** → you broke the VIEW REGISTRY;
  it scans all `@ViewController` classes at startup and one broken view poisons
  navigation to EVERY view, including pre-existing ones. Check, in order: (1) every new
  view `.java` has a `package` line matching its directory — a class in the
  default package registers its `@Route`/`@ViewController` wrong; (2) no two
  `@ViewController(id=…)` share an id; (3) every `@ViewDescriptor` path resolves
  to a real XML next to the class; (4) no `*-view.xml` is empty/malformed — an
  empty descriptor throws `SAXParseException: Premature end of file` and poisons
  the registry.
- **`MetaClass not found for class X`** → the entity is missing `@JmixEntity`, or
  its package is outside the application scan root.
- **`ConstraintViolationException` on save** → a `@NotNull` persistent field has
  no value on the `DataManager` path (see the entity-default rule below).

Fix the cause, re-run `clean test` until green. A test that goes red and you cannot
explain is a blocker, never a footnote in your "done" summary.

## File-write trap

Always pass absolute paths to file-writing tools; in nested-project layouts the
working directory may not be what you assume. After a batch of writes, `ls` the
path you intended AND confirm each file is NON-EMPTY — a tool that silently writes
a 0-byte file leaves a defect that compile and `clean test` will NOT catch (an
empty role class drops all its policies; an empty `*-view.xml` poisons the view
registry). If a file is missing or empty, find and rewrite it; do NOT `rm -rf` to
"clean up".

---

# Jmix Coding Guidelines

Use these instructions when working on a Jmix 2 application.

## Project Stack

- Java 17
- Jmix 2, Spring Boot 3, Vaadin 24
- Gradle
- Relational database with Liquibase migrations

## Global Rules

- Prefer Jmix APIs and generated project patterns over raw framework code.
- For change requests on an existing feature, preserve existing behavior and constraints unless the new request explicitly changes them. Inspect current entities, views, listeners, roles, and changelogs before editing.
- Use `DataManager` for normal CRUD. Use `EntityManager` only for bulk/native operations that `DataManager` cannot express, and only inside an explicit transaction.
- Consume the instance RETURNED by `dataManager.save(...)` — the argument you passed in is not updated in place.
- Keep business logic in services or Spring event listeners, not in view controllers.
- Do not use Lombok on Jmix entities.
- Do not instantiate Jmix entities with constructors. Use `DataManager.create()`, `Metadata.create()`, or `DataContext.create()` depending on context.
- Do not hardcode user-visible UI text. Use message keys.
- Do not invent XML component attributes, Vaadin icon names, or Jmix action ids. Reuse existing project patterns or omit optional decoration. When in doubt, verify the symbol exists (see `verify-api-symbol`).
- Before using a Jmix or Vaadin API not already used in the project, verify it BEFORE you type it — Context7 (`/jmix-framework/jmix-context7`) is your PRIMARY check when connected (or an IDE symbol search); only if no docs MCP is available, fall back to searching the project for a working example. See `verify-api-symbol`.
- Do not edit generated frontend files.

## Required Cross-Cutting Work

For each new persistent entity, complete all related artifacts:

- Entity class with Jmix/JPA metadata.
- **Defaults for required fields applied at the ENTITY layer.** For a constant
  default use a field initializer (`private Integer quantity = 0;`); for a runtime
  default (`now()`, generated keys) use `@PrePersist` / `@PreUpdate` or an
  `EntitySavingEvent` listener — NOT only the detail view's `InitEntityEvent`, and
  NOT only a service that updates the field. `EntityChangedEvent` listeners fire
  AFTER persist; they cannot satisfy `@NotNull` validation. The default must work
  through `DataManager.create()` + `DataManager.save()` directly — tests bypass the
  view layer.
- Liquibase changelog included from the root changelog. Create the referenced
  (parent) table before the table that holds the foreign key to it.
- Message keys for entity, attributes, enum values, view titles, buttons, and actions.
- List/detail views when the entity is user-facing.
- Resource role policies for entity operations, attributes, views, and menu items.
  - **If a role grants `EntityPolicyAction.CREATE`, the `@EntityAttributePolicy`
    MUST be `MODIFY` (not `VIEW`) for every attribute filled at creation** — even
    for an entity immutable after creation (`READ` + `CREATE`, no `UPDATE`).
    `CREATE` + `VIEW` produces a create form the user can submit but whose fields
    are all read-only at runtime.
  - Map the task's access phrasing to the right `EntityPolicyAction`. "Read-only
    list access" is an open MODE (read-only) — grant `READ`, not a `readOnly`
    descriptor. For an immutable entity grant explicit `READ, CREATE`, never `ALL`
    (`ALL` includes UPDATE/DELETE).

For each new user-facing view:

- Java controller and XML descriptor; stable view id.
- Menu entry for top-level list views only.
- Message keys for titles, labels, and buttons.
- View policies for every role that can open it, **including dialog-only detail views opened from a composition table**.
- Visible buttons or menu items for every action the user must trigger — a button/action with no resolved caption renders blank and a UI test that locates it by visible text cannot find it.
- Typed form components that match property types (a `BigDecimal` needs a typed numeric field, not plain text).
- An **enum attribute** uses `<comboBox>`, NOT `entityComboBox` — its "Range is enumeration," so it is not an entity reference. Use `entityComboBox` only for an entity reference.

For each new business operation:

- Put the operation in a service or listener, not in a view; define clear transaction boundaries; prefer `DataManager` for CRUD.
- Keep UI notifications, dialogs, and components out of services.
- Defaults for required persistent fields must work outside UI-only paths.

## View descriptor rules the compiler cannot check

- **Reference field `itemsQuery` needs `:searchString`.** An `entityComboBox` with
  `<itemsQuery>` passes a `searchString` parameter for type-ahead; a query that
  ignores it throws `DevelopmentException: Parameter searchString is not used in
  the query` when the dropdown fetches. Prefer the `itemsContainer`-bound
  `<collection>` form (needs no `searchString`); otherwise add
  `where e.<name> like :searchString` inside a nested `<query>`.
- **Parameterized loaders: never `load()` without the parameter set.** A loader
  whose JPQL has a manual `:param` (e.g. a child grid filtered by the selected
  master row, `where e.parent = :param`) must NEVER be `load()`-ed while that
  parameter is unset — it throws `IllegalStateException: Query argument <x> not
  found`. In the selection handler, RETURN EARLY when `getSingleSelectedItem()` is
  null; do NOT `removeParameter(...)` then `load()`. Keep manual-param loaders OUT
  of `<dataLoadCoordinator auto="true"/>`, which fires loaders at view open before
  any parameter exists — either omit the loader from auto coordination and load it
  explicitly after the parameter is set, or bind it via `:container_*` /
  `:component_*`.

  ```java
  @Subscribe("masterGrid")
  public void onSelect(SelectionEvent<DataGrid<Entity>, Entity> e) {
      Entity sel = masterGrid.getSingleSelectedItem();
      if (sel == null) { return; }          // early return — do NOT load() with no param
      childDl.setParameter("param", sel);
      childDl.load();
  }
  ```

- **A `@Composition` child grid uses a `property`-bound container, NOT a query
  loader.** Nest the child container in the parent instance as
  `<collection id="..." property="children"/>` — no loader, no query. The parent
  fetchPlan must `extends="_base"` AND include the child property
  (`<property name="children" fetchPlan="_base"/>`) or children do not persist or
  load. A standalone loader with `where e.parent = :param` does NOT cascade the
  child into a still-new parent (after save the parent has 0 children). The child
  entity's own detail view must EXIST or the `+` action throws
  `NoSuchViewException`. See `jmix-create-composition-detail-view`.
- **No raw Vaadin `Dialog` in a Jmix view.** A hand-built
  `com.vaadin.flow.component.dialog.Dialog` renders but a UI test can never find
  its fields/buttons. For a scalar prompt use `dialogs.createInputDialog(this)`
  with `InputParameter.intParameter(...)`; for an entity use
  `dialogWindows.detail(...)`. If those APIs "cannot resolve," FIX THE IMPORT
  (`io.jmix.flowui.app.inputdialog.*`, `io.jmix.flowui.Dialogs`) — do NOT abandon
  the Jmix API for a raw one. See `jmix-add-dialog-detail-flow`.
- **A `StandardListView` loads through its `<loader><query>` and needs NO load
  delegate.** If you do write an `@Install(... Target.DATA_LOADER)` delegate it
  must return `List<E>`; returning the `LoadContext` means the query never runs and
  the grid breaks at open.

## Validation Before Finishing

- Run the smallest relevant compile/test command available for the change; read compile and startup failures and fix deterministic ones before reporting completion.
- Search changed XML and Java for obvious drift: table names in JPQL, unresolved `msg://` keys, hardcoded visible labels, missing components referenced by `urlQueryParameters`, raw Vaadin dialogs for Jmix workflows, unsafe loader parameter handling, after-commit listeners used for validation or required mutations, and form components that do not match property types.
- Compare resource role menu/view policies against actual `menu.xml` item ids and view ids — `@MenuPolicy` lists leaf item ids, not the group id.
- For update tasks, compare touched artifacts against their previous constraints and defaults before reporting completion.
- If tests cannot be run, state the exact blocker and what was validated instead.

## Mechanical checks — run these EXACT checks, do not eyeball

Your static floor when you have no IDE inspection and no browser tool. Run from
the project directory and act on the output; each maps to a defect that passes a
clean compile (and even a green `clean test`).

Two kinds below: the `find` checks are pass/fail (any output = a defect to fix);
the `grep` checks only SURFACE candidates — a non-empty result is not automatically
a failure, but you MUST explain every hit (e.g. each `msg://` key must actually
resolve in a `messages_*.properties`; each `= :` loader param must be bound/guarded).

```bash
# package line on every new .java (missing → view-registry / import breakage)
find src/main/java -name '*.java' | while read f; do head -1 "$f" | grep -q '^package ' || echo "MISSING package: $f"; done
# every @NotNull / nullable=false needs an entity-layer default, not InitEntityEvent
grep -rn "nullable = false\|@NotNull" src/main/java --include='*.java'
# manual :param loaders must be bound (:container_* / :component_*) or guarded
grep -rn "= :" src/main/resources --include='*-view.xml'
# CREATE ⇒ MODIFY in every role; @MenuPolicy lists leaf item ids
grep -rn "CREATE\|MODIFY\|VIEW" src/main/java --include='*Role.java'
# itemsQuery must reference :searchString (or switch to itemsContainer)
grep -rn "itemsQuery" src/main/resources --include='*-view.xml'
# no raw Vaadin Dialog in a Jmix view
grep -rn "com.vaadin.flow.component.dialog.Dialog" src/main/java --include='*.java'
# every msg:// key must resolve in a messages_*.properties (else literal key renders)
grep -rhoE 'msg://[^"<> ]+' src/main/resources --include='*.xml' | sort -u
# no 0-byte source file (empty role drops policies; empty *-view.xml poisons registry)
find src/main -type f \( -name '*.java' -o -name '*.xml' \) -size 0
```

Then confirm `clean test` is GREEN — do not dismiss a newly-red test as "pre-existing" without proof.

## Render-time defects — mechanical checks first, then OPTIONAL render walk

The mechanical checks are your ONLY static catch for render-time defects when you
have no inspection and no browser tool — do not skip them. If you have a
browser/UI-automation tool, you may THEN walk every view you created (navigate,
click each button/action, fill each field; watch for an error overlay or server
exception) and shut the app down cleanly. A browser walk catches gross render
exceptions, but passing it does NOT guarantee a headless server-side UI test
passes — a required default set only in the view, or a non-standard action id, can
work in the browser and still fail the test suite. It is a render gate, not a
proxy for the test suite.
