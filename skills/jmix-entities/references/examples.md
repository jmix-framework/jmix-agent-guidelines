# Entities Usage Examples

## Basic Entity Template

```java
package com.company.sample.entity;

import io.jmix.core.entity.annotation.JmixGeneratedValue;
import io.jmix.core.metamodel.annotation.InstanceName;
import io.jmix.core.metamodel.annotation.JmixEntity;
import jakarta.persistence.*;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;

@JmixEntity
@Table(name = "CUSTOMER")
@Entity
public class Customer {

    @JmixGeneratedValue
    @Column(name = "ID", nullable = false)
    @Id
    private UUID id;

    @Column(name = "VERSION", nullable = false)
    @Version
    private Integer version;

    @InstanceName
    @Column(name = "NAME", nullable = false)
    @NotNull
    private String name;

    @Email
    @Column(name = "EMAIL")
    private String email;

    // Getters and setters (NO Lombok!)
    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    
    public Integer getVersion() { return version; }
    public void setVersion(Integer version) { this.version = version; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
}
```

## @InstanceName on Method

For computed display names:
```java
@InstanceName
@DependsOnProperties({"firstName", "lastName", "username"})
public String getDisplayName() {
    return String.format("%s %s [%s]", 
        firstName != null ? firstName : "",
        lastName != null ? lastName : "", 
        username).trim();
}
```

## Audit Fields

```java
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedBy;
import org.springframework.data.annotation.LastModifiedDate;
import java.time.OffsetDateTime;

@CreatedBy
@Column(name = "CREATED_BY")
private String createdBy;

@CreatedDate
@Column(name = "CREATED_DATE")
private OffsetDateTime createdDate;

@LastModifiedBy
@Column(name = "LAST_MODIFIED_BY")
private String lastModifiedBy;

@LastModifiedDate
@Column(name = "LAST_MODIFIED_DATE")
private OffsetDateTime lastModifiedDate;
```

## Soft Delete

```java
import io.jmix.core.annotation.DeletedBy;
import io.jmix.core.annotation.DeletedDate;
import java.time.OffsetDateTime;

@DeletedBy
@Column(name = "DELETED_BY")
private String deletedBy;

@DeletedDate
@Column(name = "DELETED_DATE")
private OffsetDateTime deletedDate;
```

## Relationships

### ManyToOne (Always LAZY!)
```java
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "CUSTOMER_ID")
private Customer customer;
```

### OneToMany
```java
@OneToMany(mappedBy = "order")
private List<OrderLine> lines;
```

### Composition (Parent-Child with Cascade Delete)
```java
import io.jmix.core.DeletePolicy;
import io.jmix.core.entity.annotation.OnDelete;
import io.jmix.core.metamodel.annotation.Composition;

@Composition                          // Child is part of parent
@OnDelete(DeletePolicy.CASCADE)       // Delete children when parent deleted
@OneToMany(mappedBy = "order")
private List<OrderLine> lines;
```

## Embedded Entities (Value Objects)

```java
@JmixEntity
@Embeddable
public class Address {
    @Column(name = "CITY")
    private String city;
    
    @Column(name = "STREET")
    private String street;
    // getters/setters
}

// In entity:
@EmbeddedParameters(nullAllowed = false)
@Embedded
@AttributeOverrides({
    @AttributeOverride(name = "city", column = @Column(name = "HOME_CITY")),
    @AttributeOverride(name = "street", column = @Column(name = "HOME_STREET"))
})
private Address homeAddress;
```

## Multiple Data Stores

```java
@Store(name = "archive")  // Must be defined in application.properties
@JmixEntity
@Table(name = "OLD_LOGS")
@Entity
public class OldLog {
    // ...
}
```

## Inheritance

```java
@JmixEntity
@Inheritance(strategy = InheritanceType.JOINED)
@DiscriminatorColumn(name = "TYPE", discriminatorType = DiscriminatorType.STRING)
@Table(name = "PARTNER")
@Entity(name = "Partner")
public class Partner { }

@JmixEntity
@Entity
@DiscriminatorValue("SUPPLIER")
public class Supplier extends Partner { }
```

## Transient/Calculated Fields

```java
@JmixProperty
@Transient
@DependsOnProperties({"quantity"})
public BigDecimal getTotal() {
    return price.multiply(BigDecimal.valueOf(quantity));
}
```

## Liquibase Changelog

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
        xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
                      http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">
    <changeSet id="020-customer-1" author="project">
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
    </changeSet>
</databaseChangeLog>
```

## Messages

Add localized names of the entity and its attributes to all `messages_*.properties` files:
```properties
com.company.project.entity/Customer=Customer
com.company.project.entity/Customer.name=Name
com.company.project.entity/Customer.email=Email
```

## Default Values with @PostConstruct

The annotated method can accept any Spring beans:
```java
import jakarta.annotation.PostConstruct;

@PostConstruct
void init(TimeSource timeSource) {
    setRegistrationDate(timeSource.now().toLocalDate());
}
```
