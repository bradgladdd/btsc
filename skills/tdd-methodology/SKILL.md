---
name: TDD Methodology (btsc)
description: This skill should be used when working within a btsc TDD session, when needing to understand "TDD phases", "RED GREEN REFACTOR cycle", "behavioral contracts", "test-first development", "phase transition criteria", or when determining what tests to write for CORE, EDGE, SECURITY, PERFORMANCE, or SIMPLICITY phases. Provides the rigorous TDD protocol that builds behavioral contracts enabling aggressive code simplification.
version: 0.1.0
---

# btsc: Big Tests, Small Code

btsc is a rigorous 5-phase TDD protocol that builds comprehensive behavioral contracts through testing. The end goal: minimal, optimized code that passes all tests. Tests are the specification—any implementation passing them is correct.

## Core Philosophy

**Tests define the contract. Code fulfills it.**

- Write tests that verify BEHAVIOR, not implementation
- Tests must be implementation-agnostic: any code passing them is valid
- Build tests incrementally through phases to create a complete behavioral specification
- In the final phase, aggressively simplify code—if tests pass, the implementation is correct

## The 5 Phases

Execute phases in strict order. Each phase adds to the behavioral contract.

| Phase | Focus | Tests Guarantee |
|-------|-------|-----------------|
| **CORE** | Happy path, basic functionality | Feature works for standard inputs |
| **EDGE** | Boundaries, edge cases, error handling | Feature handles unexpected inputs gracefully |
| **SECURITY** | Security concerns, input validation, auth | Feature is secure against common attacks |
| **PERFORMANCE** | Efficiency, resource usage, timeouts | Feature performs within acceptable bounds |
| **SIMPLICITY** | Refactor implementation | Code is minimal while maintaining all guarantees |

### Phase Progression Rules

1. Complete all RED→GREEN→REFACTOR cycles within a phase before advancing
2. All tests must pass to transition phases
3. Never skip phases—each builds on the previous
4. SIMPLICITY phase focuses on implementation refactoring, not new tests

## RED → GREEN → REFACTOR Cycle

Within each phase, follow this strict cycle:

```
┌─────────────────────────────────────────────────────────────┐
│                    RED → GREEN → REFACTOR                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   RED ──────────────────────────────────────────────────►   │
│   │  Write a failing test that defines expected behavior    │
│   │  Test MUST fail (proves it tests something real)        │
│   │  Test must be VALIDATED before proceeding               │
│   │                                                         │
│   ▼                                                         │
│   GREEN ────────────────────────────────────────────────►   │
│   │  Write MINIMAL code to make the test pass               │
│   │  Do not optimize, do not add unrequested features       │
│   │  Only goal: make the red test turn green                │
│   │                                                         │
│   ▼                                                         │
│   REFACTOR ─────────────────────────────────────────────►   │
│   │  Improve code quality while keeping tests green         │
│   │  Remove duplication, improve naming, simplify           │
│   │  If any test fails, revert and fix                      │
│   │                                                         │
│   └──────────────────► (next RED cycle or phase)            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### RED Phase Rules

- Write ONE failing test at a time
- Test must fail for the RIGHT reason (missing behavior, not syntax error)
- Test must be validated for quality before proceeding to GREEN
- Never write implementation code during RED

### GREEN Phase Rules

- Write the MINIMUM code to pass the failing test
- Do not refactor during GREEN
- Do not add functionality beyond what the test requires
- Ugly code is acceptable—it will be cleaned in REFACTOR

### REFACTOR Phase Rules

- Only refactor when all tests are GREEN
- Run tests after each refactor step
- If tests fail, immediately revert
- Focus: remove duplication, improve readability, simplify

## Test Validation Criteria

Every test must pass these criteria before proceeding:

1. **Behavioral Focus**: Tests behavior/outcome, not implementation details
2. **Meaningful Assertions**: Has substantive assertions (not `expect(true)`)
3. **Implementation Agnostic**: Any correct implementation would pass this test
4. **Phase Appropriate**: Matches current phase focus (see `references/phase-guidelines.md`)
5. **Isolated**: Does not depend on other test execution order
6. **Deterministic**: Same input always produces same result

### Invalid Test Patterns (Always Reject)

```
// BAD: Tests implementation, not behavior
expect(user.hashPassword).toHaveBeenCalled()

// BAD: Trivial assertion
expect(true).toBe(true)

// BAD: Tests internal state
expect(service._privateCache.size).toBe(3)

// BAD: Order-dependent
expect(globalCounter).toBe(5)  // depends on previous tests
```

### Valid Test Patterns

```
// GOOD: Tests observable behavior
expect(user.authenticate('password')).toBe(true)

// GOOD: Tests output for given input
expect(calculator.add(2, 3)).toBe(5)

// GOOD: Tests error handling behavior
expect(() => parser.parse(null)).toThrow(ValidationError)

// GOOD: Tests side effects through observable outcomes
const result = await api.createUser(data)
expect(result.id).toBeDefined()
expect(await api.getUser(result.id)).toEqual(expect.objectContaining(data))
```

## State Management

btsc tracks session state in `.claude/tdd.local.md`:

```yaml
---
feature: "feature-name"
phase: CORE
substate: RED
test_files:
  - path/to/tests.test.ts
test_patterns:  # optional user overrides
  - "**/*.spec.ts"
---
```

### State Transitions

```
Session Start → CORE/RED
                    │
    ┌───────────────┴───────────────┐
    │         Within Phase          │
    │   RED → GREEN → REFACTOR ─┐   │
    │     ▲                     │   │
    │     └─────────────────────┘   │
    └───────────────┬───────────────┘
                    │ (all tests pass)
                    ▼
              Next Phase/RED
                    │
                   ...
                    │
              SIMPLICITY/REFACTOR
                    │
                    ▼
              Session Complete
              (state file removed)
```

## Framework-Agnostic Patterns

btsc works with any test framework. Detect test files by common patterns:

**Default test file patterns:**
- `*.test.*` (Jest, Vitest, etc.)
- `*.spec.*` (Jasmine, Mocha, etc.)
- `*_test.*` (Go, Python pytest)
- `test_*.*` (Python pytest)
- `*Test.*` (Java JUnit, C# NUnit)
- `__tests__/*` (Jest convention)

**Common test commands:**
- JavaScript: `npm test`, `npx jest`, `npx vitest`
- Python: `pytest`, `python -m pytest`
- Go: `go test ./...`
- Rust: `cargo test`
- Java: `mvn test`, `gradle test`

## Enforcement Rules

btsc enforces strict TDD discipline:

1. **No implementation without tests**: Block Edit/Write on implementation files until tests exist and are validated
2. **No skipping validation**: All tests must be validated before GREEN phase
3. **No weakening tests**: Tests cannot be modified to pass artificially
4. **No forced passes**: Never modify tests just to make them pass
5. **Patient iteration**: If tests fail, fix the implementation, not the tests (unless test itself is flawed)

### When Test Modification Is Allowed

Only modify tests when:
- Test has a bug (syntax error, wrong assertion logic)
- Test specification was incorrect (behavior requirement changed)
- Test is testing implementation details instead of behavior

Never modify tests to:
- Make failing tests pass without fixing underlying issue
- Reduce test coverage
- Skip difficult edge cases

## Additional Resources

### Reference Files

Consult these for detailed guidance:

- **`references/phase-guidelines.md`** - Detailed criteria and examples for each phase
- **`references/test-quality.md`** - Comprehensive test validation patterns
- **`references/patterns.md`** - Framework-agnostic test patterns by language

### Quick Phase Reference

| Phase | Write Tests For | Do NOT Test |
|-------|-----------------|-------------|
| CORE | Happy path, basic inputs, expected outputs | Edge cases, errors, security |
| EDGE | Boundaries, nulls, empty, large inputs, errors | Security, performance |
| SECURITY | Injection, auth, validation, sanitization | Performance optimization |
| PERFORMANCE | Timeouts, resource limits, efficiency | Already covered behaviors |
| SIMPLICITY | (No new tests) | (Focus on refactoring code) |
