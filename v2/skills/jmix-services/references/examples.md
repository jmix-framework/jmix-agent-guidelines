# Jmix Services Usage Examples

## Service Template

### Constructor Injection
```java
@Service("app_OrderService") // If the project is an add-on, use explicit bean name with prefix
public class OrderService {

    private final DataManager dataManager;

    public OrderService(DataManager dataManager) {
        this.dataManager = dataManager;
    }

    public Order createOrder() {
        return dataManager.create(Order.class);
    }
}
```

## DataManager Operations

### Loading Entities
```java
// Load by ID
Customer customer = dataManager.load(Customer.class)
    .id(customerId)
    .fetchPlan(fpb -> fpb.addFetchPlan(FetchPlan.BASE).add("contacts"))
    .one();

// Load List with abbreviated query
List<Order> orders = dataManager.load(Order.class)
    .query("e.customer = ?1", customer)
    .list();

// Load with Conditions (instead of JPQL)
List<Customer> companyCustomers = dataManager.load(Customer.class)
        .condition(LogicalCondition.and(
                PropertyCondition.contains("email", "@company.com"),
                PropertyCondition.equal("grade", CustomerGrade.PLATINUM)
        ))
        .list();

// Load and Lock (Pessimistic Locking in database)
Customer lockedCustomer = dataManager.load(Customer.class)
        .id(customerId)
        .lockMode(LockModeType.PESSIMISTIC_WRITE)
        .one();

// Load with full JPQL query and named parameters
List<Customer> customers = dataManager.load(Customer.class)
        .query("select c from Customer c where c.email like :email")
        .parameter("email", "%@company.com")
        .maxResults(1000)
        .list();

// Load scalar and aggregate values
List<KeyValueEntity> kvEntities = dataManager.loadValues(
                "select o.customer, sum(o.amount) from Order_ o " +
                        "where o.date >= :date group by o.customer")
        .store("main")
        .properties("customer", "sum")
        .parameter("date", fromDate)
        .list();

// Load a single scalar or aggregate value
BigDecimal total = dataManager.loadValue(
        "select sum(o.amount) from Order_ o where o.date >= :date",
        BigDecimal.class
    )
    .store("main")          
    .parameter("date", toDate)
    .one();

// Cross-Datastore Reference Usage
// Assuming Order (main store) has a reference to Customer (additional store)
// DataManager handles the join/loading automatically
Order order = dataManager.load(Order.class).id(orderId).fetchPlan("order-with-customer").one();
Customer customer = order.getCustomer(); // Automatically loaded from additional store
```

### Saving and Removing
```java
// Save
Customer savedCustomer = dataManager.save(customer);

// Save without reload (for better performance when saved instance is not needed)
dataManager.saveWithoutReload(customer);

// Save with SaveContext
SaveContext saveContext = new SaveContext();
saveContext.saving(order);
saveContext.removing(deletedLines);
EntitySet savedEntities = dataManager.save(saveContext);

// Save with SaveContext and discard saved instances
SaveContext saveContext = new SaveContext().setDiscardSaved(true);
saveContext.saving(order, customer);
dataManager.save(saveContext);

// Remove
dataManager.remove(entity);
```

## Advanced: EntityManager

### Bulk Operations
```java
@Service("app_BulkOperationService")
public class BulkOperationService {

    @PersistenceContext
    private EntityManager entityManager;

    @Transactional  // REQUIRED!
    public void archiveOldOrders() {
        entityManager.createQuery(
            "update Order o set o.status = :status where o.date < :cutoff")
            .setParameter("status", OrderStatus.ARCHIVED)
            .setParameter("cutoff", LocalDate.now().minusYears(1))
            .executeUpdate();
    }

    @Transactional
    public void hardDelete(Product product) {
        // Disable soft deletion for this transaction
        entityManager.setProperty(PersistenceHints.SOFT_DELETION, false);
        entityManager.remove(product);
    }
}
```

### Native Queries
```java
@PersistenceContext
private EntityManager entityManager;

@Transactional
public void executeNativeQuery() {
    entityManager.createNativeQuery("update SOME_TABLE set COLUMN = ?1 where ID = ?2")
            .setParameter(1, "value")
            .setParameter(2, someId)
            .executeUpdate();
}
```

## Advanced: JDBC (JdbcTemplate and JdbcClient)

### Modern API with JdbcClient (Jmix 2.x)
```java
@Autowired
private JdbcClient jdbcClient;

public List<String> getCustomerNames(CustomerGrade grade) {
    return jdbcClient.sql("select NAME from CUSTOMER where GRADE = :grade")
            .param("grade", grade.getId())
            .query(String.class)
            .list();
}
```

### Raw SQL with JdbcTemplate
```java
@Autowired
private JdbcTemplate jdbcTemplate;

public Map<String, BigDecimal> getCustomerAmounts(CustomerGrade grade) {
    return jdbcTemplate.query(
            """
            select c.NAME, sum(o.AMOUNT)
            from CUSTOMER c join ORDER_ o on c.ID = o.CUSTOMER_ID
            where c.GRADE = ?
            group by c.NAME
            """,
            (ResultSet rs) -> {
                Map<String, BigDecimal> result = new HashMap<>();
                while (rs.next()) {
                    result.put(rs.getString(1), rs.getBigDecimal(2));
                }
                return result;
            },
            grade.getId()
    );
}
```

### Using SimpleJdbcCall for Stored Procedures
```java
SimpleJdbcCall jdbcCall = new SimpleJdbcCall(jdbcTemplate)
        .withFunctionName("get_customer_stats")
        .withoutProcedureColumnMetaDataAccess()
        .declareParameters(
                new SqlParameter("p_customer_id", Types.OTHER),
                new SqlOutParameter("total_orders", Types.INTEGER),
                new SqlOutParameter("total_amount", Types.DECIMAL)
        );

Map<String, Object> result = jdbcCall.execute(customerId);
```

## Transactions

### Declarative Transactions
```java
@Transactional
public void complexOperation() {
    Order order = dataManager.save(newOrder);
    processPayment(order);
}

@Transactional(readOnly = true)
public List<Order> getReport() {
    return dataManager.load(Order.class).all().list();
}
```

### Programmatic Transactions
```java
@Service
public class ManualTxService {

    private final TransactionTemplate transactionTemplate;

    public ManualTxService(PlatformTransactionManager txManager) {
        this.transactionTemplate = new TransactionTemplate(txManager);
    }

    public void executeInTransaction() {
        transactionTemplate.execute(status -> {
            // Code in transaction
            if (somethingFails()) {
                status.setRollbackOnly();
            }
            return null;
        });
    }
}
```

## Jmix Data Repositories
```java
public interface UserRepository extends JmixDataRepository<User, UUID> {
    
    List<User> findByActiveTrue();
    
    // FetchPlan as LAST parameter
    List<User> findByLastName(String lastName, FetchPlan fetchPlan);
}
```