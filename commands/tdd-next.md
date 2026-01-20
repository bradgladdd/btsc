---
description: Advance to next TDD phase or sub-state
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

Advance the btsc TDD session to the next phase or sub-state. This is the primary development trigger.

## IMPORTANT: Check Loop Mode

First, read .claude/tdd.local.md and check if `loop_active: true`.

**If in loop mode (loop_active: true):**
- YOU must do ALL work yourself - write tests, write implementation, run tests
- **NEVER ask the user to write code**
- **NEVER say "Your turn" or wait for user input**
- Use Write/Edit tools to create all code files
- Use Bash to run tests
- Continue working until the phase is complete

**If NOT in loop mode:** You may provide guidance and let the user write code if appropriate.

## Advancement Logic

### Step 1: Load Current State

Read .claude/tdd.local.md:
- If no session exists: Report error, suggest /btsc:tdd-loop to start
- Parse current phase, substate, and test files

### Step 2: Run Tests

Execute the project's test suite:
- Detect test command (npm test, pytest, go test, etc.)
- Run tests and capture results
- Parse pass/fail counts

### Step 3: Determine Transition Type

Based on current substate:

**If RED:**
- Check if failing tests exist and are validated
- If validated: Transition to GREEN
- If not validated: Use test-validator agent first

**If GREEN:**
- Check if all tests pass
- If ALL PASS: Transition to REFACTOR
- If ANY FAIL: **IMPLEMENT CODE TO MAKE THEM PASS** (this is the key action!)

**If REFACTOR:**
- Check if all tests still pass
- If ALL PASS: Either continue refactoring OR transition to next phase
- If ANY FAIL: **FIX THE REGRESSION** (refactoring broke something)

### Step 4: Execute Transition

#### RED → GREEN Transition
1. Confirm tests are validated
2. Update state file: substate = GREEN
3. Provide implementation directives:
   - What code needs to be written
   - Where to create/modify files
   - Minimal implementation approach

#### GREEN → REFACTOR Transition (tests passing)
1. Update state file: substate = REFACTOR
2. Suggest refactoring opportunities:
   - Code duplication to remove
   - Naming improvements
   - Structural simplifications

#### GREEN Phase with Failing Tests (IMPLEMENT!)
**This is the critical development trigger:**
1. Analyze failing tests
2. Determine what implementation is needed
3. Write the minimal code to make tests pass
4. Run tests again
5. Repeat until all tests pass
6. Then transition to REFACTOR

#### REFACTOR → Next Phase
1. Verify all tests pass
2. Update state file: phase = [next phase], substate = RED
3. Consult tdd-coach agent for next phase directives
4. Provide guidance on what tests to write for new phase

### Step 5: Handle Phase Completion

**CORE → EDGE:**
- Verify CORE tests cover happy path
- Provide EDGE phase focus: boundaries, errors, edge cases

**EDGE → SECURITY:**
- Verify EDGE tests cover error handling
- Provide SECURITY phase focus: injection, auth, validation

**SECURITY → PERFORMANCE:**
- Verify SECURITY tests cover attack vectors
- Provide PERFORMANCE phase focus: timing, resources, scale

**PERFORMANCE → SIMPLICITY:**
- Verify PERFORMANCE tests set acceptable bounds
- Begin aggressive refactoring for minimal code

**SIMPLICITY Complete:**
- Remove .claude/tdd.local.md state file
- Provide final summary of behavioral contract
- Session remains open for continued refactoring (tests are the contract)

## Critical Implementation Behavior

When in GREEN phase with failing tests, DO NOT just report failures. Instead:

```
## Implementation Required

Tests failing: 2

### Failing Test 1: [test name]
**File:** [test file path]
**Assertion:** [what it expects]

**Implementation:**
[Write the actual code to make this test pass]

### Failing Test 2: [test name]
**File:** [test file path]
**Assertion:** [what it expects]

**Implementation:**
[Write the actual code to make this test pass]

---

Running tests again to verify...
```

Then actually write the code using Edit/Write tools, run tests, and continue until all pass.

## Output Format

```
## btsc Phase Transition

**From:** [PHASE]/[SUBSTATE]
**To:** [NEW_PHASE]/[NEW_SUBSTATE]

### Transition Summary
[What was accomplished]

### Current Test Status
- Passing: X
- Failing: Y

### Next Directive
[Specific next action based on new state]
```

## Example: GREEN with Failing Tests

```
## btsc Implementation Mode

**Phase:** CORE / GREEN
**Status:** 2 tests failing - implementing now

### Test 1: "should add two numbers"
File: src/calculator.test.ts:5

Implementing Calculator.add():

[Uses Edit tool to write the add method]

### Test 2: "should subtract two numbers"
File: src/calculator.test.ts:12

Implementing Calculator.subtract():

[Uses Edit tool to write the subtract method]

### Verification
Running tests...

All tests passing! Transitioning to REFACTOR.

**New State:** CORE / REFACTOR
```
