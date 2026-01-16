# Framework-Agnostic Test Patterns

Common test patterns across languages and frameworks. Focus on behavior verification regardless of implementation.

## Test File Detection Patterns

btsc detects test files using these patterns:

```
*.test.{js,ts,jsx,tsx}     # Jest, Vitest, etc.
*.spec.{js,ts,jsx,tsx}     # Jasmine, Mocha, Angular
*_test.{go,py,rb}          # Go, Python, Ruby
test_*.py                   # Python pytest
*Test.{java,kt,cs}         # JUnit, NUnit
*Tests.{java,kt,cs}        # JUnit, NUnit (plural)
__tests__/**/*             # Jest convention
tests/**/*                 # Common convention
spec/**/*                  # RSpec, Jasmine
```

## Test Command Detection

Common test commands by ecosystem:

### JavaScript/TypeScript
```bash
npm test
npm run test
npx jest
npx vitest
npx mocha
yarn test
pnpm test
bun test
```

### Python
```bash
pytest
python -m pytest
python -m unittest
nosetests
```

### Go
```bash
go test
go test ./...
go test -v ./...
```

### Rust
```bash
cargo test
cargo test --release
```

### Java/Kotlin
```bash
mvn test
./mvnw test
gradle test
./gradlew test
```

### Ruby
```bash
rspec
bundle exec rspec
rake test
```

### .NET
```bash
dotnet test
```

## Common Test Patterns by Language

### JavaScript/TypeScript

```javascript
// Arrange-Act-Assert pattern
describe('Calculator', () => {
  it('adds two numbers', () => {
    // Arrange
    const calc = new Calculator()

    // Act
    const result = calc.add(2, 3)

    // Assert
    expect(result).toBe(5)
  })
})

// Async testing
it('fetches user data', async () => {
  const user = await fetchUser(123)
  expect(user.name).toBe('Alice')
})

// Error testing
it('throws on invalid input', () => {
  expect(() => parse(null)).toThrow(ValidationError)
})

// Mock testing (use sparingly)
it('calls external API', async () => {
  const mockFetch = jest.fn().mockResolvedValue({ data: 'test' })
  const result = await service.getData(mockFetch)
  expect(mockFetch).toHaveBeenCalledWith('/api/data')
})
```

### Python

```python
# pytest style
import pytest

class TestCalculator:
    def test_add_positive_numbers(self):
        calc = Calculator()
        assert calc.add(2, 3) == 5

    def test_divide_by_zero_raises(self):
        calc = Calculator()
        with pytest.raises(ZeroDivisionError):
            calc.divide(1, 0)

    @pytest.fixture
    def calculator(self):
        return Calculator()

    def test_with_fixture(self, calculator):
        assert calculator.add(1, 1) == 2

# Async testing
@pytest.mark.asyncio
async def test_async_fetch():
    result = await fetch_data()
    assert result['status'] == 'ok'

# Parametrized tests
@pytest.mark.parametrize('a,b,expected', [
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
])
def test_add_parametrized(a, b, expected):
    assert add(a, b) == expected
```

### Go

```go
package calculator

import "testing"

func TestAdd(t *testing.T) {
    calc := NewCalculator()
    result := calc.Add(2, 3)
    if result != 5 {
        t.Errorf("Add(2, 3) = %d; want 5", result)
    }
}

// Table-driven tests (Go idiom)
func TestAddTableDriven(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 2, 3, 5},
        {"zero", 0, 0, 0},
        {"negative", -1, -2, -3},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            if result != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d",
                    tt.a, tt.b, result, tt.expected)
            }
        })
    }
}

// Error testing
func TestDivideByZero(t *testing.T) {
    _, err := Divide(1, 0)
    if err == nil {
        t.Error("expected error for divide by zero")
    }
}
```

### Rust

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        let calc = Calculator::new();
        assert_eq!(calc.add(2, 3), 5);
    }

    #[test]
    #[should_panic(expected = "division by zero")]
    fn test_divide_by_zero() {
        let calc = Calculator::new();
        calc.divide(1, 0);
    }

    #[test]
    fn test_result_ok() {
        let result = parse("123");
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 123);
    }

    #[test]
    fn test_result_err() {
        let result = parse("invalid");
        assert!(result.is_err());
    }
}
```

### Java (JUnit 5)

```java
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

class CalculatorTest {

    private Calculator calc;

    @BeforeEach
    void setUp() {
        calc = new Calculator();
    }

    @Test
    void addPositiveNumbers() {
        assertEquals(5, calc.add(2, 3));
    }

    @Test
    void divideByZeroThrows() {
        assertThrows(ArithmeticException.class, () -> {
            calc.divide(1, 0);
        });
    }

    @ParameterizedTest
    @CsvSource({"1,2,3", "0,0,0", "-1,1,0"})
    void addParameterized(int a, int b, int expected) {
        assertEquals(expected, calc.add(a, b));
    }

    @Test
    void asyncOperation() throws Exception {
        CompletableFuture<String> future = service.fetchAsync();
        assertEquals("result", future.get(1, TimeUnit.SECONDS));
    }
}
```

## Universal Patterns

### Given-When-Then (BDD Style)

Works in any language:

```
Given [initial context]
When [action occurs]
Then [expected outcome]
```

```javascript
describe('Shopping Cart', () => {
  it('calculates total with discount', () => {
    // Given
    const cart = new Cart()
    cart.add({ price: 100 })
    cart.applyDiscount('10PERCENT')

    // When
    const total = cart.getTotal()

    // Then
    expect(total).toBe(90)
  })
})
```

### Arrange-Act-Assert

```python
def test_user_registration():
    # Arrange
    user_data = {"email": "test@example.com", "password": "secret"}

    # Act
    user = register_user(user_data)

    # Assert
    assert user.id is not None
    assert user.email == "test@example.com"
```

### Test Data Builders

```javascript
// Builder pattern for test data
const userBuilder = () => ({
  email: 'default@example.com',
  password: 'password123',
  name: 'Default User',
  withEmail: function(email) { this.email = email; return this },
  withName: function(name) { this.name = name; return this },
  build: function() { return { email: this.email, password: this.password, name: this.name } }
})

it('creates user with custom email', () => {
  const userData = userBuilder().withEmail('custom@example.com').build()
  const user = createUser(userData)
  expect(user.email).toBe('custom@example.com')
})
```

### Factory Functions

```python
def make_user(**overrides):
    defaults = {
        "email": "test@example.com",
        "password": "password123",
        "name": "Test User"
    }
    return User(**{**defaults, **overrides})

def test_user_with_custom_name():
    user = make_user(name="Custom Name")
    assert user.name == "Custom Name"
```

## Exit Code Interpretation

All test frameworks use exit codes:

| Exit Code | Meaning |
|-----------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2+ | Error (couldn't run tests, invalid config, etc.) |

btsc uses exit codes as primary pass/fail signal, with output parsing for details.

## Output Patterns

Common patterns in test output:

### Pass Indicators
```
✓ test name
✔ test name
PASS test name
ok      package/name
.       (single dot per passing test)
passed
```

### Fail Indicators
```
✗ test name
✘ test name
FAIL test name
FAILED test name
--- FAIL: TestName
F       (single F per failing test)
failed
```

### Summary Patterns
```
X passing, Y failing
X passed, Y failed
Tests: X passed, Y failed, Z total
PASSED: X  FAILED: Y
ok/FAIL followed by package name
```

btsc parses these patterns to track test state transitions.
