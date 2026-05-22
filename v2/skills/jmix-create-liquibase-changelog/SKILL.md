---
name: jmix-create-liquibase-changelog
description: Create Liquibase changelogs that exactly match Jmix entity model changes.
---

# Create Liquibase Changelog

Use this skill for every persistent entity or schema change.

## Steps

1. Find the root changelog path from `application.properties`.
2. Follow the existing naming style: sequential files or date/time folders.
3. Create a new changelog file for the schema change.
4. Make sure it is reachable from the root `changelog.xml`: usually by placing it under the directory covered by the project's `<includeAll>`, or by adding an explicit `<include>` only when the project uses explicit includes.
5. Use a changeset id and author that match project style; do not reuse an id within the same changelog file.
6. Add `ID` and `VERSION` columns for standard Jmix entities.
7. Add every persistent entity field with exact type, length, precision, scale, and nullability.
8. Add foreign keys for references.
9. Add indexes and unique constraints required by the entity or domain.
10. Verify the table and column names match Java annotations.
11. Use only type macros already present in the project. If no macro exists, use the standard Liquibase type.

## Standard Types

| Java type | Liquibase type |
| --- | --- |
| UUID | `${uuid.type}` |
| String | `varchar(n)` |
| Integer | `int` |
| Long | `bigint` |
| BigDecimal | `decimal(p,s)` |
| Boolean | `boolean` |
| LocalDate | `date` |
| LocalDateTime | `timestamp` |
| Enum id string | `varchar(50)` |

## Entity Table Skeleton

```xml
<changeSet id="create-customer" author="app">
    <createTable tableName="CUSTOMER">
        <column name="ID" type="${uuid.type}">
            <constraints nullable="false" primaryKey="true" primaryKeyName="PK_CUSTOMER"/>
        </column>
        <column name="VERSION" type="int">
            <constraints nullable="false"/>
        </column>
        <column name="NAME" type="varchar(100)">
            <constraints nullable="false"/>
        </column>
    </createTable>
</changeSet>
```

## Root Changelog Reachability

```xml
<includeAll path="/com/company/app/liquibase/changelog"/>
```

If the project uses explicit includes instead of `includeAll`, follow that existing style:

```xml
<include file="/com/company/app/liquibase/changelog/030-customer.xml"/>
```

## Forbidden

- New changelog file that is not reachable from the root changelog.
- Reusing a changeset id in the same changelog file.
- Raw `UUID` type instead of `${uuid.type}`.
- Invented type macros such as `${datetime.type}` when the project does not define them.
- Missing `VERSION`.
- Nullable database column for a required Java field.
- Java precision/length different from Liquibase precision/length.
- Missing FK for persistent references.
