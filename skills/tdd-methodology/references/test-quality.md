# Test Quality Validation

Comprehensive criteria for validating tests. Every test must meet these standards to become part of the behavioral contract.

## The Golden Rule

**A valid test guarantees that ANY implementation passing it correctly implements the specified behavior.**

This means:
- Test the WHAT (behavior), not the HOW (implementation)
- If you could rewrite the entire implementation differently and it still passes, the test is good
- If the test would break from internal refactoring, it's testing implementation details

## Validation Checklist

### 1. Behavioral Focus

**Pass**: Tests observable behavior or output
**Fail**: Tests internal implementation details

```javascript
// PASS: Tests behavior
it('returns sum of two numbers', () => {
  expect(add(2, 3)).toBe(5)
})

// FAIL: Tests implementation
it('uses reduce internally', () => {
  const spy = jest.spyOn(Array.prototype, 'reduce')
  add(2, 3)
  expect(spy).toHaveBeenCalled()
})
```

```python
# PASS: Tests behavior
def test_user_can_login():
    user = create_user(password="secret")
    assert login(user.email, "secret").success == True

# FAIL: Tests implementation
def test_password_hashed_with_bcrypt():
    user = create_user(password="secret")
    assert user._hash_algorithm == "bcrypt"  # Internal detail
```

### 2. Meaningful Assertions

**Pass**: Assertions verify actual behavior
**Fail**: Trivial or tautological assertions

```javascript
// PASS: Meaningful assertion
it('calculates total with tax', () => {
  const cart = new Cart([{ price: 100 }])
  expect(cart.totalWithTax(0.1)).toBe(110)
})

// FAIL: Trivial assertion
it('creates cart', () => {
  const cart = new Cart([])
  expect(cart).toBeDefined()  // Proves nothing
})

// FAIL: Tautological
it('returns what it returns', () => {
  const result = calculate()
  expect(result).toBe(result)  // Always true
})
```

### 3. Implementation Agnostic

**Pass**: Test would pass with any correct implementation
**Fail**: Test assumes specific internal structure

```javascript
// PASS: Implementation agnostic
it('sorts numbers ascending', () => {
  expect(sort([3, 1, 2])).toEqual([1, 2, 3])
})

// FAIL: Implementation specific
it('uses quicksort algorithm', () => {
  const spy = jest.spyOn(sorter, 'quicksort')
  sort([3, 1, 2])
  expect(spy).toHaveBeenCalled()
})
```

```python
# PASS: Any caching implementation works
def test_caches_expensive_computation():
    start = time.time()
    result1 = expensive_function(42)
    first_call_time = time.time() - start

    start = time.time()
    result2 = expensive_function(42)
    second_call_time = time.time() - start

    assert result1 == result2
    assert second_call_time < first_call_time / 10  # Significantly faster

# FAIL: Assumes specific cache implementation
def test_uses_lru_cache():
    assert hasattr(expensive_function, '_lru_cache')
```

### 4. Phase Appropriate

Tests must match current phase focus:

| Phase | Appropriate Tests | Inappropriate Tests |
|-------|-------------------|---------------------|
| CORE | Happy path, basic I/O | Edge cases, security, performance |
| EDGE | Boundaries, errors, unusual inputs | Security, performance |
| SECURITY | Injection, auth, validation | Performance benchmarks |
| PERFORMANCE | Timing, resources, scale | New functionality |
| SIMPLICITY | (No new tests) | Any new tests |

```javascript
// In CORE phase:
// PASS: Happy path
it('creates user with valid data', () => { ... })

// FAIL: Edge case (belongs in EDGE)
it('handles null email', () => { ... })

// FAIL: Security (belongs in SECURITY)
it('prevents SQL injection', () => { ... })
```

### 5. Isolated

**Pass**: Test runs independently
**Fail**: Test depends on other tests or shared mutable state

```javascript
// PASS: Isolated
it('adds item to cart', () => {
  const cart = new Cart()  // Fresh instance
  cart.add({ id: 1, price: 10 })
  expect(cart.items.length).toBe(1)
})

// FAIL: Depends on shared state
let sharedCart = new Cart()

it('adds first item', () => {
  sharedCart.add({ id: 1 })
  expect(sharedCart.items.length).toBe(1)
})

it('adds second item', () => {
  sharedCart.add({ id: 2 })
  expect(sharedCart.items.length).toBe(2)  // Fails if run alone
})
```

### 6. Deterministic

**Pass**: Same input always produces same result
**Fail**: Test relies on randomness, time, or external state

```javascript
// PASS: Deterministic
it('generates greeting', () => {
  expect(greet('Alice')).toBe('Hello, Alice!')
})

// FAIL: Time-dependent
it('shows correct time', () => {
  expect(getCurrentTime()).toBe('10:30 AM')  // Flaky!
})

// BETTER: Mock time
it('shows formatted time', () => {
  jest.useFakeTimers().setSystemTime(new Date('2024-01-01T10:30:00'))
  expect(getCurrentTime()).toBe('10:30 AM')
})

// FAIL: Random-dependent
it('generates random ID', () => {
  expect(generateId()).toBe('abc123')  // Different each run!
})

// BETTER: Test properties
it('generates unique IDs', () => {
  const ids = new Set(Array(100).fill().map(() => generateId()))
  expect(ids.size).toBe(100)  // All unique
})
```

## Anti-Patterns Catalog

### Snapshot Testing Abuse

```javascript
// DANGEROUS: Snapshots can hide implementation coupling
it('renders correctly', () => {
  expect(render(<Component />)).toMatchSnapshot()
})
```

**When snapshots are OK**: UI components where visual output IS the behavior
**When snapshots are bad**: Testing internal data structures, API responses with irrelevant fields

### Mock Everything

```javascript
// BAD: Over-mocking hides integration issues
it('processes order', () => {
  jest.mock('./database')
  jest.mock('./payment')
  jest.mock('./email')
  jest.mock('./inventory')

  // Test is now just testing mock interactions
  const result = processOrder(order)
  expect(mockDatabase.save).toHaveBeenCalled()
})
```

**Better**: Test integration points separately, use real implementations where practical

### Testing Framework Code

```javascript
// BAD: Testing the framework, not your code
it('express routes work', () => {
  app.get('/test', (req, res) => res.send('ok'))
  // This tests Express, not your application
})
```

### Conditional Test Logic

```javascript
// BAD: Tests should not have conditionals
it('handles input', () => {
  const result = process(input)
  if (input.type === 'A') {
    expect(result).toBe('A result')
  } else {
    expect(result).toBe('B result')
  }
})

// BETTER: Separate tests
it('handles type A input', () => {
  expect(process({ type: 'A' })).toBe('A result')
})

it('handles type B input', () => {
  expect(process({ type: 'B' })).toBe('B result')
})
```

### Testing Private Methods

```javascript
// BAD: Exposing internals for testing
class Calculator {
  // Made public just for testing - BAD
  public _parseExpression(expr) { ... }
}

it('parses expression', () => {
  expect(calc._parseExpression('2+3')).toEqual({ op: '+', args: [2, 3] })
})

// BETTER: Test through public interface
it('evaluates expression', () => {
  expect(calc.evaluate('2+3')).toBe(5)
})
```

## Strength Levels

Categorize test strength:

### Level 1: Existence Tests (Weak)
```javascript
expect(result).toBeDefined()
expect(user).not.toBeNull()
```
Only appropriate for checking error-free execution, not behavior.

### Level 2: Type Tests (Moderate)
```javascript
expect(typeof result).toBe('string')
expect(Array.isArray(items)).toBe(true)
```
Verifies shape but not correctness.

### Level 3: Value Tests (Strong)
```javascript
expect(result).toBe(42)
expect(items).toEqual([1, 2, 3])
```
Verifies actual behavior.

### Level 4: Behavioral Tests (Strongest)
```javascript
// Tests complete behavior including side effects
const user = await createUser(data)
expect(user.id).toBeDefined()
const retrieved = await getUser(user.id)
expect(retrieved.email).toBe(data.email)
```
Verifies the feature works end-to-end.

**Target Level 3-4 for most tests.**

## Test Smells

Warning signs a test may be invalid:

| Smell | Example | Problem |
|-------|---------|---------|
| **Long setup** | 50 lines of setup for 1 assertion | Testing too much, or poor design |
| **Magic numbers** | `expect(result).toBe(42)` without context | Unclear what 42 represents |
| **Commented assertions** | `// expect(x).toBe(y)` | Incomplete test |
| **Multiple concepts** | Testing auth AND email in one test | Should be separate |
| **Test name doesn't match** | "should work" for specific behavior | Unclear purpose |
| **Excessive mocking** | 5+ mocks in setup | Integration test disguised as unit |
| **Time-based assertions** | `expect(Date.now() - start).toBeLessThan(10)` | Flaky on slow systems |

## Validation Questions

Before approving a test, ask:

1. **"What behavior does this test verify?"**
   - If you can't answer clearly, test is unclear

2. **"Would a different correct implementation pass?"**
   - If no, test is implementation-coupled

3. **"If this test passes, what am I confident about?"**
   - If the answer is vague, test is weak

4. **"Could this test pass with a wrong implementation?"**
   - If yes, test is too weak

5. **"Is this testing my code or the framework/libraries?"**
   - Focus on your code's behavior

6. **"Does this test belong in the current phase?"**
   - Keep tests phase-appropriate
