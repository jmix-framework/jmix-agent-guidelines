---
name: jmix-security-roles
description: Configuring access control - Resource Roles, Row-Level Roles, policies, and programmatic permission checks. Covers role composition, Entity/View/Menu, JPQL and Predicate policies, and data access control.
---

# Security (Roles & Policies)

Jmix Security provides a robust mechanism for managing access control through design-time or run-time roles, including Resource Roles for functional permissions and Row-level Roles for data-level restrictions.

## When to Use

Use this Skill when:
- Creating or configuring Resource Roles to define access to entities, attributes, views, and menus
- Implementing Row-level Roles to restrict access to specific data instances (rows)
- Configuring Entity Policies (CRUD), Attribute Policies (View/Modify), View Policies, and Menu Policies
- Implementing JPQL policies for database-level filtering or Predicate policies for in-memory checks
- Combining multiple roles into a single composite role via interface inheritance
- Performing programmatic permission checks in Java code using `AccessManager`
- Ensuring consistent data access control across all application layers

## Key Concepts

- **Resource Role**: Defines what the user can do. Contains policies for entities, attributes, UI views, menu items, and arbitrary logic.
- **Row-level Role**: Defines what data the user can see or update. Contains JPQL or Predicate policies to filter entity instances.
- **Entity Policy**: Specifies permitted CRUD operations (CREATE, READ, UPDATE, DELETE) for a particular entity.
- **Attribute Policy**: Controls access to specific entity attributes (VIEW or MODIFY).
- **View & Menu Policy**: Grants access to UI views and their corresponding menu items.
- **JPQL Policy**: Filters data at the database level using JPQL `where` and `join` clauses. Highly efficient.
- **Predicate Policy**: Filters data in-memory using Java predicates. Useful for complex logic that cannot be expressed in JPQL, and for permissions on update operations.
- **Role Composition**: Both Resource and Row-level roles can be combined by extending multiple role interfaces.
- **Additive System**: Resource permissions are additive; if any assigned resource role grants access, the user has it. Deny-policies are not supported in the standard model.

## Usage

- **Defining Resource Roles**:
    - Annotate an interface with `@ResourceRole`.
    - Use `@EntityPolicy`, `@EntityAttributePolicy`, `@ViewPolicy`, and `@MenuPolicy` on methods.
    - Policies can be grouped in one method or spread across several for better organization.
- **Defining Row-level Roles**:
    - Annotate an interface with `@RowLevelRole`.
    - Use `@JpqlRowLevelPolicy` for database-level filtering. Use `{E}` as an alias for the entity.
    - Use `@PredicateRowLevelPolicy` for in-memory filtering. Methods should return `RowLevelPredicate` or `RowLevelBiPredicate`.
- **Combining Roles**:
    - Simply extend multiple role interfaces in a new interface.
    - Example: `public interface ManagerRole extends EmployeeRole, SupervisorRole { ... }`
    - Combine only roles of the same type. That is a role cannot extend both Resource and Row-level roles.
- **Programmatic Checks**:
    - Inject `AccessManager` bean.
    - Use `EntityOperationContext`, `EntityAttributeContext`, or `SpecificPolicyContext` to check permissions.

See usage examples in [references/examples.md](references/examples.md).
