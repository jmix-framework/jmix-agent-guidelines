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
4. Include it from the root `changelog.xml`.
5. Add `ID` and `VERSION` columns for standard Jmix entities.
6. Add every persistent entity field with exact type, length, precision, scale, and nullability.
7. Add foreign keys for references.
8. Add indexes and unique constraints required by the entity or domain.
9. Verify the table and column names match Java annotations.
10. Use only type macros already present in the project. If no macro exists, use the standard Liquibase type.

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
<changeSet id="1" author="app">
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

## Include Pattern

```xml
<include file="030-customer.xml" relativeToChangelogFile="true"/>
```

## Forbidden

- Missing root changelog include.
- Raw `UUID` type instead of `${uuid.type}`.
- Invented type macros such as `${datetime.type}` when the project does not define them.
- Missing `VERSION`.
- Nullable database column for a required Java field.
- Java precision/length different from Liquibase precision/length.
- Missing FK for persistent references.
