# btsc Plugin Testing Guide

## Overview

This guide explains how to test the btsc plugin with clear separation between the auditing session and the test session.

## Prerequisites

- Two terminal windows (or VSCode with split terminals)
- The btsc plugin directory: `/mnt/c/Users/bradg/Documents/projects/btsc`
- The test project directory: `/mnt/c/Users/bradg/Documents/projects/btsc-test-project`

## Session Architecture

```
┌─────────────────────────────────────┐     ┌─────────────────────────────────────┐
│         AUDITOR SESSION             │     │          TEST SESSION               │
│     (This terminal/session)         │     │    (New terminal with plugin)       │
├─────────────────────────────────────┤     ├─────────────────────────────────────┤
│ - Reads debug logs                  │     │ - Runs /btsc:tdd-loop commands      │
│ - Inspects state files              │     │ - Executes TDD workflow             │
│ - Analyzes behavior                 │     │ - Creates tests and implementation  │
│ - Reports issues                    │     │                                     │
└─────────────────────────────────────┘     └─────────────────────────────────────┘
                │                                           │
                │           Files I Can Read                │
                ▼                                           ▼
        ┌───────────────────────────────────────────────────────────┐
        │              btsc-test-project/.claude/                    │
        │  ├── tdd.local.md      (State file - phase, iteration)    │
        │  └── btsc-debug.log    (Debug output from hooks)          │
        │                                                            │
        │              btsc-test-project/                            │
        │  ├── src/              (Implementation files)              │
        │  └── tests/            (Test files)                        │
        └───────────────────────────────────────────────────────────┘
```

## Step-by-Step Testing

### Step 1: Open Test Session Terminal

Open a NEW terminal window and navigate to the test project:

```bash
cd /mnt/c/Users/bradg/Documents/projects/btsc-test-project
```

### Step 2: Start Claude Code with Plugin

```bash
claude --plugin-dir /mnt/c/Users/bradg/Documents/projects/btsc
```

### Step 3: Start a TDD Loop (in test session)

```bash
/btsc:tdd-loop calculator module with add subtract multiply divide --max-iterations 10
```

### Step 4: Monitor from Auditor Session (this session)

While the test session runs, I can monitor:

**Watch the debug log:**
```bash
tail -f /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/btsc-debug.log
```

**Check current state:**
```bash
cat /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/tdd.local.md
```

**List created files:**
```bash
ls -la /mnt/c/Users/bradg/Documents/projects/btsc-test-project/src/
ls -la /mnt/c/Users/bradg/Documents/projects/btsc-test-project/tests/
```

## What to Verify

### 1. Loop Initialization
- [ ] State file created with `loop_active: true`
- [ ] Debug log shows "TDD Loop Setup Started"
- [ ] Phase starts at CORE, substate at RED

### 2. Stop Hook Behavior
- [ ] Debug log shows "Stop hook triggered" when Claude tries to exit
- [ ] Iteration increments each time
- [ ] Phase and substate are correctly read

### 3. CORE Phase Completion
- [ ] Tests are written first (RED)
- [ ] Implementation follows (GREEN)
- [ ] Refactoring happens (REFACTOR)
- [ ] Only after CORE complete does it move to EDGE

### 4. Promise Rejection (before SIMPLICITY)
- [ ] If Claude outputs `<promise>TDD_COMPLETE</promise>` before SIMPLICITY phase
- [ ] Debug log should show "PROMISE REJECTED"
- [ ] Loop should continue

### 5. Proper Completion
- [ ] Loop ends only in SIMPLICITY phase
- [ ] Debug log shows "COMPLETION ACCEPTED"
- [ ] `loop_active` changes to `false`

## Test Scenarios

### Scenario A: Loop Mode with Max Iterations
```bash
/btsc:tdd-loop calculator --max-iterations 5
```
Expected: Loop stops after 5 iterations regardless of phase

### Scenario B: Cancel Loop Mid-Session
```bash
/btsc:tdd-loop calculator --max-iterations 50
# ... let it run a few iterations ...
/btsc:cancel-loop
```
Expected: Loop stops, state preserved for manual continuation with `/btsc:tdd-next`

### Scenario C: Full TDD Cycle
```bash
/btsc:tdd-loop calculator --max-iterations 50
```
Expected: Completes all 5 phases, ends with `<promise>TDD_COMPLETE</promise>`

## Debugging Commands (for Auditor)

```bash
# View last 50 lines of debug log
tail -50 /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/btsc-debug.log

# Search for specific events
grep "PROMISE" /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/btsc-debug.log
grep "COMPLETION" /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/btsc-debug.log
grep "ERROR" /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/btsc-debug.log

# Check state file
cat /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/tdd.local.md

# Count iterations
grep "iteration=" /mnt/c/Users/bradg/Documents/projects/btsc-test-project/.claude/btsc-debug.log | tail -1
```

## Reporting Issues

When you find unexpected behavior, provide:
1. The debug log section around the issue
2. The state file contents at that moment
3. What you expected vs what happened
