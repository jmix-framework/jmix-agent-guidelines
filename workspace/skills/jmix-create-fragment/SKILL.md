---
name: jmix-create-fragment
description: Create or change reusable Jmix Flow UI fragments, embedded fragment instances, provided data components, fragment facets, host event subscriptions, or fragment renderers.
---

# Create Fragment

Use this skill when UI code should be reusable inside one or more views or fragments.

## Steps

1. Confirm the UI is reusable enough to justify a fragment; keep one-off layout inside the view.
2. Create a fragment controller in the relevant `view/...` package.
3. Extend `Fragment<RootComponentType>`.
4. Add `@FragmentDescriptor("fragment-file.xml")`.
5. Create the XML descriptor with the fragment namespace and a required `<content>` root.
6. Make the XML root component match the controller generic type.
7. Add `<data>` only for data the fragment owns, or mark host-owned containers/loaders with `provided="true"`.
8. Add fragment facets only when needed: `fragmentDataLoadCoordinator`, `fragmentSettings`, `timer`, or `urlQueryParameters`.
9. Give fragment instances an `id` when a facet requires stable state.
10. Pass parameters through public setters; use XML `<properties>` or call setters before adding the fragment.
11. Add message keys for user-visible labels, captions, and action text.
12. Compile the host view and fragment together.

## Controller Template

```java
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import io.jmix.flowui.fragment.Fragment;
import io.jmix.flowui.fragment.FragmentDescriptor;
import io.jmix.flowui.view.Subscribe;

@FragmentDescriptor("customer-summary-fragment.xml")
public class CustomerSummaryFragment extends Fragment<VerticalLayout> {
    @Subscribe
    public void onReady(final ReadyEvent event) {
        getFragmentData().loadAll();
    }
}
```

## XML Skeleton

```xml
<fragment xmlns="http://jmix.io/schema/flowui/fragment">
    <data>
        <collection id="customersDc" class="com.company.app.entity.Customer">
            <fetchPlan extends="_base"/>
            <loader id="customersDl" readOnly="true">
                <query><![CDATA[select e from Customer e]]></query>
            </loader>
        </collection>
    </data>
    <facets>
        <fragmentDataLoadCoordinator auto="true"/>
    </facets>
    <content>
        <vbox id="root">
            <dataGrid id="customersDataGrid" dataContainer="customersDc">
                <columns>
                    <column property="name"/>
                </columns>
            </dataGrid>
        </vbox>
    </content>
</fragment>
```

## Embedding

Declarative embedding:

```xml
<fragment id="customerSummaryFragment"
          class="com.company.app.view.customer.CustomerSummaryFragment"/>
```

Programmatic embedding:

```java
CustomerSummaryFragment fragment =
        fragments.create(this, CustomerSummaryFragment.class, "customerSummaryFragment");
targetLayout.add(fragment);
```

If the fragment subscribes to host events, create and add it before that host event fires.

## Provided Data Components

Use `provided="true"` when the fragment edits or displays the host view's entity/container:

```xml
<data>
    <instance id="customerDc"
              class="com.company.app.entity.Customer"
              provided="true"/>
</data>
<content>
    <formLayout id="form" dataContainer="customerDc">
        <textField id="nameField" property="name"/>
    </formLayout>
</content>
```

The host view or enclosing fragment must declare a data component with the same id.

## Fragment Renderers

Use a fragment renderer only when a grid/list cell needs reusable UI more complex than a simple renderer. Keep renderer fragments read-only unless the workflow explicitly supports editing from the cell.

## Forbidden

- Fragment controller without matching XML descriptor.
- XML root component different from `Fragment<...>` generic type.
- One-off view layout extracted into a fragment without reuse or isolation benefit.
- `provided="true"` without a same-id host data component.
- `dataLoadCoordinator` in fragments; use `fragmentDataLoadCoordinator`.
- `settings` in fragments; use `fragmentSettings`.
- `urlQueryParameters` entries referencing components that are not declared in the fragment.
- Hardcoded user-visible labels.
- Using `UiComponentUtils` to find inner fragment components by Vaadin ids.
