---
name: jmix-liquibase
description: Database schema migration in Jmix using Liquibase - generating changelogs, managing schema updates, and handling database consistency. Covers workflow, directory structure, column types, and Studio integration.
---

# Liquibase (Database Schema Migrations)

Database schema migration is the process of updating the database schema in accordance with changes in the application data model. Jmix uses Liquibase as its core migration tool.

## When to Use

Use this Skill when:
- Creating a new entity and requiring a corresponding database table
- Adding, modifying, or removing columns in an existing entity
- Defining indexes, foreign keys, or unique constraints
- Managing data model changes across different environments (dev, test, prod)
- Implementing custom SQL scripts or data updates during migration

## Key Concepts

- **Purpose**: Synchronize the database schema with JPA entities using Liquibase changelogs.
- **Workflow**:
    - Create changelogs when modifying data model.
    - The application runs Liquibase automatically on startup to apply pending changelogs.
- **Directory Structure**: Changelogs are stored in `src/main/resources/<base_package>/liquibase/`.
    - Main data store: `changelog/` directory.
    - Additional data stores: `<store>-changelog/` directories.
    - Files are typically organized by date `year/month/day-time-description.xml` or in plain list `seq-description.xml`.
- **Configuration**: The root changelog path is defined by the `main.liquibase.change-log` property (or `<store>.liquibase.change-log` for additional stores) in `application.properties`.
- **Add-on Support**: Add-ons can contain their own Liquibase changelogs, which are executed before the application's changelogs.

## Usage

- **Changeset Definition**:
    - **ID Convention**: Use sequential integers for changeset IDs.
    - **Author**: Use a meaningful project name or developer identifier; avoid generic `dev`.
    - **Immutability**: Never modify a changeset that has already been applied to a database. Create a new changeset for subsequent modifications.
- **Column Definition**:
    - **Standard Types**:
        | Java Type | Liquibase Type |
        |-----------|----------------|
        | UUID | `${uuid.type}` |
        | String | `varchar(n)` |
        | Integer | `int` |
        | Long | `bigint` |
        | BigDecimal | `decimal(p,s)` |
        | Boolean | `boolean` |
        | LocalDate | `date` |
        | LocalDateTime | `timestamp` |
        | Enum | `varchar(50)` |
    - **Required Columns**: All Jmix entities typically require `ID` (primary key) and `VERSION` (optimistic locking) columns.
- **Constraints**:
    - **Foreign Keys**: Defined via `<addForeignKeyConstraint>`. Use naming convention `FK_<TABLE>_<COLUMN>`.
    - **Indexes**: Defined via `<createIndex>`.
- **Integration**:
    - **Changelog Naming**:
      - Use `seq-description.xml` name if the project contains only plain list of changelogs. For example: `030-customer.xml`.
      - Use `year/month/day-time-description.xml` name (time in `HHmmss` format) if the project already contains the time-based structure. For example: `2026/02/19-105244-customer.xml`.
    - **Changelog Inclusion**: New files must be included in the root `changelog.xml` using `<include file="..." relativeToChangelogFile="true"/>`.
    - **Contexts**: Use `context="dev"` or similar to restrict changesets to specific deployment environments.

If there are errors in your changelogs, the application will fail to start. Always verify syntax and ensure `changelog.xml` correctly includes your new files. Common errors include "Table already exists" (requires database cleaning) or "Invalid type UUID" (must use `${uuid.type}`).

See usage examples in [references/examples.md](references/examples.md).

## Forbidden

- **Directly using `type="UUID"`**: Always use `${uuid.type}` for cross-database compatibility.
- **Modifying applied changesets**: Causes checksum errors and prevents app startup.
- **Missing `VERSION` column**: Breaks optimistic locking for standard entities.
- **Duplicate IDs**: Every changeset must have a unique ID within its file.
