# Liquibase Usage Examples

## Changelog Template

A basic Liquibase changelog file for creating an entity table.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <changeSet id="1" author="yourproject">
        <createTable tableName="CUSTOMER">
            <column name="ID" type="${uuid.type}">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="VERSION" type="int">
                <constraints nullable="false"/>
            </column>
            <column name="NAME" type="varchar(255)">
                <constraints nullable="false"/>
            </column>
            <column name="EMAIL" type="varchar(255)"/>
        </createTable>
        <rollback>
            <dropTable tableName="CUSTOMER"/>
        </rollback>
    </changeSet>
</databaseChangeLog>
```

## Common Column Definitions

### Required Columns for Jmix Entities

```xml
<column name="ID" type="${uuid.type}">
    <constraints primaryKey="true" nullable="false"/>
</column>
<column name="VERSION" type="int">
    <constraints nullable="false"/>
</column>
```

### Foreign Key Constraint

```xml
<addForeignKeyConstraint
    baseTableName="ORDER_"
    baseColumnNames="CUSTOMER_ID"
    constraintName="FK_ORDER_CUSTOMER"
    referencedTableName="CUSTOMER"
    referencedColumnNames="ID"/>
```

## Advanced Features

### Using Contexts

Limit changeset execution to specific environments.

```xml
<changeSet id="1" author="project" context="dev">
    <insert tableName="CUSTOMER">
        <column name="ID" value="${uuid.type}:5ec56773-6a9c-487e-97f2-111111111111"/>
        <column name="NAME" value="Dev Customer"/>
        <column name="VERSION" value="1"/>
    </insert>
</changeSet>
```

### Including Changelogs

Including a new changelog file in the main `changelog.xml`:

```xml
<include file="020-customer.xml" relativeToChangelogFile="true"/>
```
