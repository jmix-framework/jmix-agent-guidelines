# DTOs Usage Examples

## Jmix DTO Entity Definition

Basic DTO entity with auto-generated ID:
```java
@JmixEntity(name = "app_CustomerSummaryDto")
public class CustomerSummaryDto {
    @JmixId
    @JmixGeneratedValue
    private UUID id;

    @InstanceName
    @JmixProperty(mandatory = true)
    private String customerName;

    private Integer orderCount;
    private BigDecimal totalAmount;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    // Other getters and setters
}
```
Entity name with prefix must be used in add-on projects.

DTO entity using only annotated properties:
```java
@JmixEntity(annotatedPropertiesOnly = true)
public class Metric {
    @JmixProperty(mandatory = true)
    @JmixId
    @JmixGeneratedValue
    private UUID id;

    @JmixProperty
    private String name;

    @JmixProperty
    private Double value;

    private Object ephemeral; // Ignored by Jmix metadata

    // Getters and setters
}
```

DTO entity with custom Data Store:
```java
@Store(name = "inmem")
@JmixEntity
public class ProductPart {
    @JmixId
    @InstanceName
    private String name;

    private Integer quantity;

    // Getters and setters
}
```

## Instantiating DTO Entities

Always use `DataManager` or `Metadata` for entities used in UI:
```java
@Autowired
private DataManager dataManager;

public void someMethod() {
    // CORRECT — use DataManager or Metadata
    CustomerSummaryDto dto = dataManager.create(CustomerSummaryDto.class);
    
    // WRONG — new breaks ID generation and metadata initialization
    // CustomerSummaryDto dto = new CustomerSummaryDto(); // ❌
}
```

## Validation

Bean validation on DTOs and in services:
```java
import jakarta.validation.constraints.*;

public class OrderRequest {
    @NotNull(message = "Customer is required")
    private UUID customerId;

    @NotBlank @Size(min = 3, max = 50)
    private String orderNumber;

    @Valid  // Validate nested objects
    private List<LineItemDto> items;
}

// In service:
@Service
@Validated
public class OrderService {
    public void createOrder(@Valid OrderRequest request) { 
        // ... 
    }
}
```

## Localization (i18n, Messages)

In `messages.properties` (or `messages_en.properties`):
```properties
com.company.project.dto/CustomerSummaryDto=Customer Summary
com.company.project.dto/CustomerSummaryDto.customerName=Customer
```

## Java Records

Prefer Records for immutable DTOs that are NOT displayed in Jmix UI (e.g. REST API, internal logic):
```java
public record OrderRequest(UUID customerId, List<LineItem> items) {}
public record CustomerSummary(String name, int orderCount, BigDecimal total) {}
```
