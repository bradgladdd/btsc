---
description: Cancel active btsc TDD loop
allowed-tools:
  - Bash
  - Read
---

Cancel the active btsc TDD loop.

## Steps

### Step 1: Check if Loop Exists

```bash
test -f .claude/tdd.local.md && echo "EXISTS" || echo "NOT_FOUND"
```

### Step 2: Handle Result

**If NOT_FOUND:**
Report: "No active btsc session found."

**If EXISTS:**

1. Read `.claude/tdd.local.md` to get current state:
   - Check `loop_active` field
   - Get `iteration` count
   - Get `phase` and `substate`
   - Get `feature` name

2. If `loop_active` is not `true`:
   Report: "No active loop found. Session exists but is in manual mode."

3. If `loop_active` is `true`:
   - Set `loop_active` to `false` in the state file:
   ```bash
   sed -i 's/^loop_active: true/loop_active: false/' .claude/tdd.local.md
   ```
   - Report: "Cancelled btsc TDD loop at iteration N (Phase: PHASE/SUBSTATE). Session preserved for manual continuation with /btsc:tdd-next."

## Output Format

```
## btsc Loop Cancelled

**Feature:** [feature name]
**Was at:** Iteration N, Phase PHASE/SUBSTATE

The session state is preserved. You can:
- Resume manually with `/btsc:tdd-next`
- View status with `/btsc:tdd-status`
- Start fresh with a new `/btsc:tdd-loop <feature>`
```
