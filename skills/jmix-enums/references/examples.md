# Enumerations Usage Examples

## Enum Definition (String ID)

Jmix enumerations should implement `EnumClass<T>` where `T` is the type of the identifier stored in the database (usually `String` or `Integer`).

```java
import io.jmix.core.metamodel.datatype.EnumClass;
import org.springframework.lang.Nullable;

public enum OrderStatus implements EnumClass<String> {

    NEW("N"),
    CONFIRMED("C"),
    DELIVERED("D"),
    CANCELLED("A");

    private final String id;

    OrderStatus(String id) {
        this.id = id;
    }

    @Override
    public String getId() {
        return id;
    }

    @Nullable
    public static OrderStatus fromId(String id) {
        for (OrderStatus status : values()) {
            if (status.getId().equals(id)) {
                return status;
            }
        }
        return null;
    }
}
```

## Enum Definition (Integer ID)

```java
import io.jmix.core.metamodel.datatype.EnumClass;
import org.springframework.lang.Nullable;

public enum CustomerGrade implements EnumClass<Integer> {

    BRONZE(10),
    GOLD(20),
    PLATINUM(30);

    private final Integer id;

    CustomerGrade(Integer id) {
        this.id = id;
    }

    @Override
    public Integer getId() {
        return id;
    }

    @Nullable
    public static CustomerGrade fromId(Integer id) {
        for (CustomerGrade grade : values()) {
            if (grade.getId().equals(id)) {
                return grade;
            }
        }
        return null;
    }
}
```

## Integration into Entity

The entity field stores the ID type, while getter and setter use the Enum type.

```java
@JmixEntity
@Table(name = "ORDER")
@Entity
public class Order {
    // ...
    
    @Column(name = "STATUS")
    private String status;  // Store ID (String), not enum itself!

    public OrderStatus getStatus() {
        return status == null ? null : OrderStatus.fromId(status);
    }

    public void setStatus(OrderStatus status) {
        this.status = status == null ? null : status.getId();
    }
}
```

## Liquibase Changelog

The column type must match the enumeration's ID type.

```xml
<!-- For EnumClass<String> -->
<column name="STATUS" type="varchar(5)"/>

<!-- For EnumClass<Integer> -->
<column name="GRADE" type="int"/>
```

## Localization (Messages)

Enum values are localized in `messages_*.properties` files using the full class name and the enum constant name.

```properties
# com.company.project.entity/EnumClassName.CONSTANT_NAME=Localized Name

com.company.project.entity/OrderStatus=Order Status
com.company.project.entity/OrderStatus.NEW=New
com.company.project.entity/OrderStatus.CONFIRMED=Confirmed
com.company.project.entity/OrderStatus.DELIVERED=Delivered
com.company.project.entity/OrderStatus.CANCELLED=Cancelled

com.company.project.entity/CustomerGrade=Customer Grade
com.company.project.entity/CustomerGrade.BRONZE=Bronze
com.company.project.entity/CustomerGrade.GOLD=Gold
com.company.project.entity/CustomerGrade.PLATINUM=Platinum
```
