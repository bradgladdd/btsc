# Phase Guidelines

Detailed guidance for each btsc phase. Each phase builds on the previous, creating a comprehensive behavioral contract.

## Phase 1: CORE

**Focus**: Basic functionality, happy path, expected behavior

### What to Test

- Primary use case with valid, typical inputs
- Expected outputs for standard scenarios
- Basic state transitions
- Core business logic

### Entry Criteria
- Feature requirements understood
- Test file(s) created and tracked

### Exit Criteria
- All happy path scenarios covered
- Tests verify the feature WORKS for normal use
- All tests passing

### Example Tests (CORE)

```javascript
// User authentication - CORE tests
describe('User Authentication - CORE', () => {
  it('authenticates valid user with correct password', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'valid123' })
    const result = await authenticate('test@example.com', 'valid123')
    expect(result.success).toBe(true)
    expect(result.user.email).toBe('test@example.com')
  })

  it('returns user token on successful login', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'valid123' })
    const result = await authenticate('test@example.com', 'valid123')
    expect(result.token).toBeDefined()
    expect(typeof result.token).toBe('string')
  })

  it('rejects incorrect password', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'valid123' })
    const result = await authenticate('test@example.com', 'wrongpassword')
    expect(result.success).toBe(false)
  })
})
```

```python
# Calculator - CORE tests
class TestCalculatorCore:
    def test_add_two_positive_numbers(self):
        calc = Calculator()
        assert calc.add(2, 3) == 5

    def test_subtract_returns_difference(self):
        calc = Calculator()
        assert calc.subtract(10, 4) == 6

    def test_multiply_returns_product(self):
        calc = Calculator()
        assert calc.multiply(3, 4) == 12

    def test_divide_returns_quotient(self):
        calc = Calculator()
        assert calc.divide(10, 2) == 5
```

### Anti-Patterns (CORE)

```javascript
// DON'T: Test edge cases in CORE
it('handles null input', () => { ... })  // Save for EDGE

// DON'T: Test security in CORE
it('prevents SQL injection', () => { ... })  // Save for SECURITY

// DON'T: Test performance in CORE
it('completes within 100ms', () => { ... })  // Save for PERFORMANCE
```

---

## Phase 2: EDGE

**Focus**: Boundary conditions, error handling, unexpected inputs

### What to Test

- Empty/null/undefined inputs
- Boundary values (0, -1, MAX_INT, empty string)
- Invalid input types
- Error conditions and error messages
- Unusual but valid inputs
- State edge cases (empty list, single item, maximum items)

### Entry Criteria
- CORE phase complete (all tests passing)
- Core functionality verified

### Exit Criteria
- All boundary conditions covered
- Error handling verified
- Feature gracefully handles unexpected inputs
- All tests passing

### Example Tests (EDGE)

```javascript
// User authentication - EDGE tests
describe('User Authentication - EDGE', () => {
  it('handles empty email', async () => {
    const result = await authenticate('', 'password123')
    expect(result.success).toBe(false)
    expect(result.error).toContain('email')
  })

  it('handles empty password', async () => {
    const result = await authenticate('test@example.com', '')
    expect(result.success).toBe(false)
    expect(result.error).toContain('password')
  })

  it('handles non-existent user', async () => {
    const result = await authenticate('nonexistent@example.com', 'password')
    expect(result.success).toBe(false)
    // Should not reveal whether user exists
    expect(result.error).toBe('Invalid credentials')
  })

  it('handles malformed email format', async () => {
    const result = await authenticate('not-an-email', 'password123')
    expect(result.success).toBe(false)
    expect(result.error).toContain('email')
  })

  it('handles null inputs', async () => {
    const result = await authenticate(null, null)
    expect(result.success).toBe(false)
  })

  it('handles extremely long email', async () => {
    const longEmail = 'a'.repeat(1000) + '@example.com'
    const result = await authenticate(longEmail, 'password')
    expect(result.success).toBe(false)
  })
})
```

```python
# Calculator - EDGE tests
class TestCalculatorEdge:
    def test_add_with_zero(self):
        calc = Calculator()
        assert calc.add(5, 0) == 5
        assert calc.add(0, 5) == 5

    def test_add_negative_numbers(self):
        calc = Calculator()
        assert calc.add(-2, -3) == -5
        assert calc.add(-2, 5) == 3

    def test_divide_by_zero_raises_error(self):
        calc = Calculator()
        with pytest.raises(ZeroDivisionError):
            calc.divide(10, 0)

    def test_handles_float_inputs(self):
        calc = Calculator()
        assert calc.add(1.5, 2.5) == 4.0

    def test_handles_very_large_numbers(self):
        calc = Calculator()
        result = calc.add(10**100, 10**100)
        assert result == 2 * 10**100
```

### Anti-Patterns (EDGE)

```javascript
// DON'T: Re-test happy paths
it('authenticates valid user', () => { ... })  // Already in CORE

// DON'T: Test security concerns
it('rate limits login attempts', () => { ... })  // Save for SECURITY
```

---

## Phase 3: SECURITY

**Focus**: Security vulnerabilities, input sanitization, authentication/authorization

### What to Test

- Input validation and sanitization
- SQL/NoSQL injection prevention
- XSS prevention
- Authentication bypass attempts
- Authorization checks
- Rate limiting
- Sensitive data handling
- CSRF protection

### Entry Criteria
- EDGE phase complete (all tests passing)
- Error handling verified

### Exit Criteria
- Common attack vectors tested
- Input sanitization verified
- Auth/authz boundaries enforced
- All tests passing

### Example Tests (SECURITY)

```javascript
// User authentication - SECURITY tests
describe('User Authentication - SECURITY', () => {
  it('prevents SQL injection in email field', async () => {
    const maliciousEmail = "'; DROP TABLE users; --"
    const result = await authenticate(maliciousEmail, 'password')
    expect(result.success).toBe(false)
    // Verify database still intact
    const users = await db.query('SELECT COUNT(*) FROM users')
    expect(users).toBeDefined()
  })

  it('rate limits failed login attempts', async () => {
    const email = 'test@example.com'
    // Attempt 10 failed logins
    for (let i = 0; i < 10; i++) {
      await authenticate(email, 'wrongpassword')
    }
    // 11th attempt should be rate limited
    const result = await authenticate(email, 'wrongpassword')
    expect(result.error).toContain('rate limit')
  })

  it('does not reveal user existence in error messages', async () => {
    const existingResult = await authenticate('existing@example.com', 'wrong')
    const nonExistingResult = await authenticate('nonexistent@example.com', 'wrong')
    // Error messages should be identical
    expect(existingResult.error).toBe(nonExistingResult.error)
  })

  it('hashes passwords before storage', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'mypassword' })
    const dbUser = await db.query('SELECT password FROM users WHERE id = ?', [user.id])
    expect(dbUser.password).not.toBe('mypassword')
    expect(dbUser.password.length).toBeGreaterThan(50)  // Hash length
  })

  it('invalidates token on password change', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'oldpassword' })
    const { token } = await authenticate('test@example.com', 'oldpassword')
    await changePassword(user.id, 'newpassword')
    const result = await validateToken(token)
    expect(result.valid).toBe(false)
  })

  it('prevents timing attacks on authentication', async () => {
    // Both should take similar time regardless of user existence
    const start1 = Date.now()
    await authenticate('existing@example.com', 'wrong')
    const time1 = Date.now() - start1

    const start2 = Date.now()
    await authenticate('nonexistent@example.com', 'wrong')
    const time2 = Date.now() - start2

    // Times should be within 50ms of each other
    expect(Math.abs(time1 - time2)).toBeLessThan(50)
  })
})
```

### Anti-Patterns (SECURITY)

```javascript
// DON'T: Test basic functionality
it('logs in valid user', () => { ... })  // Already in CORE

// DON'T: Test performance
it('handles 1000 concurrent logins', () => { ... })  // Save for PERFORMANCE
```

---

## Phase 4: PERFORMANCE

**Focus**: Efficiency, resource usage, scalability, timeouts

### What to Test

- Response time boundaries
- Memory usage limits
- Concurrent operation handling
- Large data set processing
- Timeout behavior
- Resource cleanup
- Caching effectiveness

### Entry Criteria
- SECURITY phase complete (all tests passing)
- Security concerns addressed

### Exit Criteria
- Performance boundaries defined and tested
- Resource limits enforced
- Feature scales within requirements
- All tests passing

### Example Tests (PERFORMANCE)

```javascript
// User authentication - PERFORMANCE tests
describe('User Authentication - PERFORMANCE', () => {
  it('authenticates within 200ms', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'password' })
    const start = Date.now()
    await authenticate('test@example.com', 'password')
    const duration = Date.now() - start
    expect(duration).toBeLessThan(200)
  })

  it('handles 100 concurrent authentication requests', async () => {
    const user = await createUser({ email: 'test@example.com', password: 'password' })
    const requests = Array(100).fill().map(() =>
      authenticate('test@example.com', 'password')
    )
    const results = await Promise.all(requests)
    const successCount = results.filter(r => r.success).length
    expect(successCount).toBeGreaterThan(95)  // Allow some rate limiting
  })

  it('token validation completes within 10ms', async () => {
    const { token } = await authenticate('test@example.com', 'password')
    const start = Date.now()
    await validateToken(token)
    const duration = Date.now() - start
    expect(duration).toBeLessThan(10)
  })

  it('cleans up expired sessions efficiently', async () => {
    // Create 1000 expired sessions
    await createExpiredSessions(1000)
    const start = Date.now()
    await cleanupExpiredSessions()
    const duration = Date.now() - start
    expect(duration).toBeLessThan(1000)  // Should complete within 1 second
  })

  it('password hashing does not block event loop', async () => {
    const otherOperation = async () => {
      const start = Date.now()
      await new Promise(resolve => setImmediate(resolve))
      return Date.now() - start
    }

    // Start password hash and other operation concurrently
    const [_, eventLoopDelay] = await Promise.all([
      createUser({ email: 'test@example.com', password: 'password' }),
      otherOperation()
    ])

    // Event loop should not be blocked significantly
    expect(eventLoopDelay).toBeLessThan(50)
  })
})
```

### Anti-Patterns (PERFORMANCE)

```javascript
// DON'T: Re-test functionality
it('successfully authenticates user', () => { ... })  // Already in CORE

// DON'T: Test new edge cases
it('handles empty password quickly', () => { ... })  // Already in EDGE
```

---

## Phase 5: SIMPLICITY

**Focus**: Code refactoring, reducing complexity, minimizing code footprint

### What to Do

- **No new tests** in this phase
- Refactor implementation for clarity
- Remove dead code
- Simplify complex logic
- Extract common patterns
- Reduce code duplication
- Improve naming
- Delete unnecessary abstractions

### Entry Criteria
- PERFORMANCE phase complete (all tests passing)
- Complete behavioral contract exists in tests

### Exit Criteria
- Code is minimal and clear
- All tests still passing
- No unnecessary complexity
- Session complete (state file removed)

### Refactoring Guidelines

1. **Make one change at a time**
2. **Run tests after each change**
3. **If tests fail, immediately revert**
4. **Commit working states frequently**

### Simplification Targets

```javascript
// BEFORE: Over-engineered
class UserAuthenticationServiceFactory {
  createService(config) {
    return new UserAuthenticationService(
      new PasswordHasherAdapter(new BCryptHasher()),
      new TokenGeneratorAdapter(new JWTGenerator()),
      new UserRepositoryAdapter(new PostgresUserRepository())
    );
  }
}

// AFTER: Simplified (if tests still pass)
async function authenticate(email, password) {
  const user = await db.users.findByEmail(email)
  if (!user || !await bcrypt.compare(password, user.password)) {
    return { success: false, error: 'Invalid credentials' }
  }
  return { success: true, token: jwt.sign({ id: user.id }) }
}
```

### Questions to Ask During SIMPLICITY

- Can this abstraction be removed?
- Is this code actually used?
- Can these two functions be combined?
- Does this indirection serve a purpose?
- Would a simpler approach pass the tests?

### The Ultimate Test

After SIMPLICITY phase, ask: **"Is this the smallest amount of code that passes all tests?"**

If no, continue refactoring. If yes, the session is complete.
