---
name: jmix-fragments
description: Jmix UI Fragments - reusable UI building blocks. Use when encapsulating UI layouts, components, actions, and data for modularity and reusability, or implementing custom renderers for visual components. Covers defining and embedding fragments, passing parameters, subscribing to events, and managing data.
---

# Fragments

Fragments are reusable UI building blocks in Jmix Flow UI, enabling modular composition of views with declarative XML and controller logic.

## When to Use

Use this Skill when:
- Creating reusable UI components that can be embedded in multiple views
- Encapsulating UI layouts, components, actions, and data for modularity and reusability
- Embedding fragments declaratively in XML or programmatically in controllers
- Passing parameters to customize fragment appearance and behavior
- Subscribing to and handling events between fragments and host views
- Sharing data contexts or using provided containers for seamless integration
- Implementing custom renderers for lists, grids, or other visual components

## Key Concepts

- **Purpose**: Promote reusability by encapsulating UI components, layouts, actions, and data that can be embedded in views or other fragments.
- **Creation**: Define via a controller class annotated with `@FragmentDescriptor` (pointing to an XML descriptor file). XML includes `<content>` for layout, optional `<actions>` and `<data>` for components.
- **Features**:
    - Inject Spring beans, UI components, and data containers.
    - Use `@Subscribe` for event handlers (e.g., `ReadyEvent` for post-init setup).
    - Share `DataContext` across view and all embedded fragments.
    - Support data sharing with host views via "provided" containers.
    - Can act as renderers for lists/grids via `FragmentRenderer`.
- Limitations: No facets; shortcuts bound to fragment root (requires focus).

## Usage

- **Declaration/Embedding**:
  - **Declarative**: Use `<fragment class="com.company.FragmentClass"/>` in view XML layouts.
  - **Programmatic**: Via `Fragments` bean: `fragments.create(this, FragmentClass.class).addTo(layout)`.
- **Parameter Passing**:
    - Set via public setters in controller.
    - Declarative: `<properties><property name="param" value="value" type="TYPE"/></properties>`.
    - Programmatic: Direct setter calls (e.g., `fragment.setParam(value)`).
- **Event Handling**:
    - Subscribe to host events: `@Subscribe(target = Target.HOST_CONTROLLER) protected void onHostEvent(Event event) { ... }`.
    - Use `ReadyEvent` for fragment init; ensure timely addition for event subscription.
- **Data Management**:
    - Define self-contained data or use `provided="true"` for host integration.

See usage examples in [references/examples.md](references/examples.md).
