---
name: jmix-testing
description: Writing reliable tests for Jmix application — Unit, Integration and UI tests with proper authentication and cleanup.
---

# Testing

## When to Use

Use this Skill when:
- Writing tests for Jmix services and views
- Testing with authentication context

## Unit Tests (No Spring Context)

```java
class PriceCalculatorTest {
    private final PriceCalculator calculator = new PriceCalculator();

    @ParameterizedTest
    @CsvSource({"100, 10, 90", "100, 0, 100"})
    void shouldApplyDiscount(int price, int discount, int expected) {
        assertThat(calculator.applyDiscount(price, discount)).isEqualTo(expected);
    }
}
```

## Integration Tests

```java
@SpringBootTest
class OrderServiceTest {

    @Autowired OrderService orderService;
    @MockitoBean PaymentGateway paymentGateway;  // NOT @MockBean!

    @Test
    void shouldProcessPayment() {
        when(paymentGateway.charge(any())).thenReturn(true);
        orderService.checkout(order);
        verify(paymentGateway).charge(any());
    }
}
```

```java
@SpringBootTest
class CustomerServiceTest {
    @Autowired
    CustomerService customerService;
    @Autowired
    DataManager dataManager;
    
    @Test
    void testFindByEmail() {
        // given
        Customer customer = dataManager.create(Customer.class);
        customer.setEmail("customer@test.com");
        dataManager.save(customer);

        // when
        Optional<Customer> foundCustomer = customerService.findByEmail("customer@test.com");

        // then
        assertThat(foundCustomer)
                .isPresent();
    }
}
```

## UI Integration Tests

```java
@UiTest
@SpringBootTest(classes = {SampleApplication.class, FlowuiTestAssistConfiguration.class})
class UserUiTest {
    @Autowired
    DataManager dataManager;

    @Autowired
    ViewNavigators viewNavigators;

    @Test
    void test_createUser() {
        // Navigate to user list view
        viewNavigators.view(UiTestUtils.getCurrentView(), UserListView.class).navigate();

        UserListView userListView = UiTestUtils.getCurrentView();

        // click "Create" button
        JmixButton createBtn = findComponent(userListView, "createBtn");
        createBtn.click();
     
        // Get detail view
        UserDetailView userDetailView = UiTestUtils.getCurrentView();

        // Set username and password in the fields
        TypedTextField<String> usernameField = findComponent(userDetailView, "usernameField");
        String username = "test-user-" + System.currentTimeMillis();
        usernameField.setValue(username);

        JmixPasswordField passwordField = findComponent(userDetailView, "passwordField");
        passwordField.setValue("test-passwd");

        JmixPasswordField confirmPasswordField = findComponent(userDetailView, "confirmPasswordField");
        confirmPasswordField.setValue("test-passwd");

        // Click "OK"
        JmixButton commitAndCloseBtn = findComponent(userDetailView, "saveAndCloseBtn");
        commitAndCloseBtn.click();

        // Get navigated user list view
        userListView = UiTestUtils.getCurrentView();

        // Check the created user is shown in the table
        DataGrid<User> usersDataGrid = findComponent(userListView, "usersDataGrid");

        DataGridItems<User> usersDataGridItems = usersDataGrid.getItems();
        Assertions.assertNotNull(usersDataGridItems);

        usersDataGridItems.getItems().stream()
                .filter(u -> u.getUsername().equals(username))
                .findFirst()
                .orElseThrow();
    }   
    
    @AfterEach
    void tearDown() {
        dataManager.load(User.class)
                .query("e.username like ?1", "test-user-%")
                .list()
                .forEach(u -> dataManager.remove(u));
    }

    @SuppressWarnings("unchecked")
    private static <T> T findComponent(View<?> view, String componentId) {
        return (T) UiComponentUtils.getComponent(view, componentId);
    }
}
```

## Authentication in Tests

Use `SystemAuthenticator` via `AuthenticatedAsAdmin` JUnit extension available in the project at `src/test/java/**/test_support/AuthenticatedAsAdmin.java`:

```java
@SpringBootTest
@ExtendWith(AuthenticatedAsAdmin.class)
class MyServiceTest { ... }
```

## Cleanup

Always in `@AfterEach`:

```java
@AfterEach
void tearDown() {
    dataManager.remove(createdEntities);
}
```

## Checklist
- [ ] NO `@Transactional` on tests
- [ ] Cleanup in `@AfterEach`
- [ ] Use `@MockitoBean` (not `@MockBean`)
- [ ] Use `AuthenticatedAsAdmin` for auth
- [ ] AssertJ assertions

## Forbidden
- `@Transactional` on test classes/methods
- `@MockBean` (deprecated, use `@MockitoBean`)
- `@WithUserDetails` (use `SystemAuthenticator`)
- Cleanup at the end of test method
