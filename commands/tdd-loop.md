---
description: Start autonomous TDD loop - Claude writes all code
argument-hint: <feature> [--max-iterations N]
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Task
---

# AUTONOMOUS TDD LOOP

**YOU ARE THE DEVELOPER. THE USER WILL WALK AWAY.**

Run the setup script first:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-tdd-loop.sh" $ARGUMENTS
```

---

## MANDATORY RULES - VIOLATION IS FAILURE

1. **YOU write ALL test files** - Use Write tool
2. **YOU write ALL implementation** - Use Write/Edit tools
3. **YOU run ALL tests** - Use Bash tool
4. **YOU do ALL refactoring** - Use Edit tool

## FORBIDDEN - NEVER DO THESE

- Say "Your turn" or "Your directive"
- Say "Write a test..." or "Add an assertion..."
- Ask the user to write ANY code
- Ask questions about implementation
- Wait for user input
- Create TODO items for the user
- Provide "guidance" for the user to follow

## REQUIRED - ALWAYS DO THESE

- Write complete test files with real assertions
- Run tests after writing them
- Write implementation code when tests fail
- Run tests again to verify GREEN
- Refactor code yourself
- Update state file phase/substate as you progress

---

## EXECUTION FLOW

### 1. ANALYZE FEATURE
Parse the feature from arguments. Identify what functions/modules are needed.

### 2. WRITE TESTS (RED PHASE)
Create test file with ACTUAL tests. Example for calculator:

```javascript
const assert = require('assert');
const { add, subtract, multiply, divide } = require('../src/calculator');

test('add returns sum of two numbers', () => {
  assert.strictEqual(add(2, 3), 5);
  assert.strictEqual(add(-1, 1), 0);
});

test('subtract returns difference', () => {
  assert.strictEqual(subtract(5, 3), 2);
});
```

### 3. RUN TESTS - CONFIRM FAILURE
```bash
npm test
```
Tests MUST fail (module doesn't exist yet). This confirms RED state.

### 4. WRITE IMPLEMENTATION (GREEN PHASE)
Create the implementation file:

```javascript
function add(a, b) {
  return a + b;
}

function subtract(a, b) {
  return a - b;
}

module.exports = { add, subtract };
```

### 5. RUN TESTS - CONFIRM PASS
```bash
npm test
```
All tests must pass. This confirms GREEN state.

### 6. REFACTOR
Improve code quality while keeping tests green.

### 7. ADVANCE PHASE
Update .claude/tdd.local.md and continue to next phase:
CORE → EDGE → SECURITY → PERFORMANCE → SIMPLICITY

### 8. COMPLETION
When SIMPLICITY phase is complete and all tests pass, output:
```
<promise>TDD_COMPLETE</promise>
```

---

## STATE FILE FORMAT

The setup script creates `.claude/tdd.local.md`:

```yaml
---
feature: "description"
phase: CORE
substate: RED
loop_active: true
iteration: 1
max_iterations: 10
---
```

Update `phase` and `substate` as you progress through the TDD cycle.

---

## PHASE REQUIREMENTS

### CORE (do first - feature must work)
- Happy path tests only
- Basic functionality
- Standard inputs/outputs

### EDGE (after CORE complete)
- Boundary conditions
- Empty/null inputs
- Error cases

### SECURITY (after EDGE complete)
- Input validation
- Type checking
- Injection prevention

### PERFORMANCE (after SECURITY complete)
- Large inputs
- Timing constraints
- Resource limits

### SIMPLICITY (final phase)
- Aggressive refactoring
- Remove duplication
- Minimize code while keeping tests green

---

## START NOW

1. Run the setup script
2. Write your first test file
3. Run tests (should fail)
4. Write implementation
5. Run tests (should pass)
6. Continue until complete
