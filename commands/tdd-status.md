---
description: Show current btsc TDD session status
allowed-tools: Read, Grep, Glob, Bash
---

Display the current btsc TDD session status.

## Status Check Process

### Step 1: Check for Active Session

Read .claude/tdd.local.md:
- If file doesn't exist: Report "No active btsc session. Use /btsc:tdd-loop to start one."
- If file exists: Parse the YAML frontmatter for session state

### Step 2: Gather Session Information

Extract from state file:
- feature: Current feature being developed
- phase: Current phase (CORE, EDGE, SECURITY, PERFORMANCE, SIMPLICITY)
- substate: Current sub-state (RED, GREEN, REFACTOR)
- test_files: List of tracked test files
- test_patterns: Any custom test patterns configured

### Step 3: Analyze Test Status

Run the test suite to determine current state:
- Detect test command for the project (npm test, pytest, go test, etc.)
- If tests exist, run them and capture results
- Count passing vs failing tests

### Step 4: Generate Status Report

Output comprehensive status:

```
## btsc Session Status

**Feature:** [feature name]

### Progress
┌──────────┬──────────┬──────────┬─────────────┬────────────┐
│   CORE   │   EDGE   │ SECURITY │ PERFORMANCE │ SIMPLICITY │
├──────────┼──────────┼──────────┼─────────────┼────────────┤
│ [status] │ [status] │ [status] │  [status]   │  [status]  │
└──────────┴──────────┴──────────┴─────────────┴────────────┘

Current: [PHASE] / [SUBSTATE]

### Test Files
- [file1.test.ts]
- [file2.test.ts]

### Test Results
- Passing: X
- Failing: Y
- Total: Z

### Current Directive
[Based on phase and substate, what should be done next]

### Next Steps
1. [Immediate next action]
2. [Following action]
```

### Step 5: Provide Contextual Guidance

Based on current state, explain:

**If RED:**
- A failing test should be written (or is in progress)
- Next: Validate the test, then transition to GREEN

**If GREEN:**
- Tests are failing, implementation needed
- Next: Write minimal code to make tests pass

**If REFACTOR:**
- Tests are passing, refactoring allowed
- Next: Improve code quality, then start new RED cycle or advance phase

### Phase Progress Indicators

Use these symbols in the progress table:
- `[✓]` - Phase complete
- `[→]` - Current phase
- `[ ]` - Not yet started

## Example Output

```
## btsc Session Status

**Feature:** user-authentication

### Progress
┌──────────┬──────────┬──────────┬─────────────┬────────────┐
│   CORE   │   EDGE   │ SECURITY │ PERFORMANCE │ SIMPLICITY │
├──────────┼──────────┼──────────┼─────────────┼────────────┤
│   [✓]    │   [→]    │   [ ]    │    [ ]      │    [ ]     │
└──────────┴──────────┴──────────┴─────────────┴────────────┘

Current: EDGE / GREEN

### Test Files
- src/auth.test.ts
- src/session.test.ts

### Test Results
- Passing: 8
- Failing: 2
- Total: 10

### Current Directive
Implement code to handle the 2 failing edge case tests.

### Next Steps
1. Fix failing tests in src/auth.test.ts (null email handling)
2. Fix failing test in src/session.test.ts (expired session)
3. Run tests to verify all pass
4. Transition to REFACTOR sub-state
```
