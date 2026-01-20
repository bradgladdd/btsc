#!/bin/bash
set -euo pipefail

# btsc TDD Loop Stop Hook
# Intercepts exit attempts and feeds the TDD task back to continue the loop

HOOK_INPUT=$(cat)
STATE_FILE=".claude/tdd.local.md"
DEBUG_LOG=".claude/btsc-debug.log"

# Debug logging function
debug_log() {
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "[$timestamp] STOP-HOOK: $1" >> "$DEBUG_LOG"
}

# JSON output helpers (no jq required)
json_continue() {
  local msg="${1:-}"
  if [[ -n "$msg" ]]; then
    # Escape quotes and backslashes in message
    msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"continue": true, "systemMessage": "%s"}\n' "$msg"
  else
    printf '{"continue": true}\n'
  fi
}

json_block() {
  local reason="$1"
  local msg="${2:-}"
  # Escape quotes, backslashes, and newlines
  reason=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
  msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"decision": "block", "reason": "%s", "systemMessage": "%s"}\n' "$reason" "$msg"
}

# Simple JSON value extractor (no jq required)
# Usage: json_get "$json_string" "key"
json_get() {
  local json="$1"
  local key="$2"
  echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed "s/\"$key\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//' | head -1
}

# Ensure .claude directory exists for logging
mkdir -p .claude

debug_log "=== Stop hook triggered ==="

# If no state file, allow exit (no active session)
if [[ ! -f "$STATE_FILE" ]]; then
  debug_log "No state file found - allowing exit (no active session)"
  json_continue
  exit 0
fi

debug_log "State file exists: $STATE_FILE"

# Parse frontmatter from state file
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")

# Extract session info
LOOP_ACTIVE=$(echo "$FRONTMATTER" | grep '^loop_active:' | sed 's/loop_active: *//' || echo "false")
FEATURE=$(echo "$FRONTMATTER" | grep '^feature:' | sed 's/feature: *//' | sed 's/^"\(.*\)"$/\1/')
PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//' || echo "CORE")
SUBSTATE=$(echo "$FRONTMATTER" | grep '^substate:' | sed 's/substate: *//' || echo "RED")
TEST_FILES=$(echo "$FRONTMATTER" | grep '^test_files:' | sed 's/test_files: *//' || echo "[]")

debug_log "Loop active: $LOOP_ACTIVE"
debug_log "Phase: $PHASE, Substate: $SUBSTATE"

# Handle non-loop sessions - approve with summary
if [[ "$LOOP_ACTIVE" != "true" ]]; then
  debug_log "Not in loop mode - approving stop with summary"
  json_continue "btsc session paused | Phase: $PHASE/$SUBSTATE | Resume with /btsc:tdd-next"
  exit 0
fi

# From here on, we're handling loop mode

# Parse loop state
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "0")

debug_log "Parsed state: iteration=$ITERATION, max=$MAX_ITERATIONS, phase=$PHASE, substate=$SUBSTATE"
debug_log "Feature: $FEATURE"

# Validate iteration is numeric
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: btsc loop state corrupted, resetting iteration count" >&2
  ITERATION=1
fi

# Check max iterations
if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  debug_log "MAX ITERATIONS REACHED: $ITERATION >= $MAX_ITERATIONS - stopping loop"
  # Clean up loop state but keep session for manual continuation
  TEMP_FILE="${STATE_FILE}.tmp.$$"
  sed 's/^loop_active: true/loop_active: false/' "$STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$STATE_FILE"
  json_continue "btsc: Max iterations ($MAX_ITERATIONS) reached. Loop stopped. Continue manually with /btsc:tdd-next"
  exit 0
fi

debug_log "Max iterations check passed ($ITERATION < $MAX_ITERATIONS or unlimited)"

# Get transcript path and check for completion promise
TRANSCRIPT_PATH=$(json_get "$HOOK_INPUT" "transcript_path")
debug_log "Transcript path: ${TRANSCRIPT_PATH:-'(not provided)'}"

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  debug_log "Checking transcript for completion signals..."
  # Get last assistant message content (simplified extraction)
  LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || echo "")

  if [[ -n "$LAST_LINE" ]]; then
    # Extract text content - look for the promise pattern directly
    LAST_OUTPUT="$LAST_LINE"

    # Check for completion promise - ONLY valid in SIMPLICITY phase
    if echo "$LAST_OUTPUT" | grep -q '<promise>TDD_COMPLETE</promise>'; then
      debug_log "PROMISE DETECTED in output"
      if [[ "$PHASE" == "SIMPLICITY" ]]; then
        debug_log "COMPLETION ACCEPTED - Phase is SIMPLICITY, ending loop"
        # Clean up loop state
        TEMP_FILE="${STATE_FILE}.tmp.$$"
        sed 's/^loop_active: true/loop_active: false/' "$STATE_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$STATE_FILE"
        json_continue "btsc: TDD complete! All phases finished."
        exit 0
      else
        # Promise detected but not in SIMPLICITY phase - ignore and continue
        debug_log "PROMISE REJECTED - Phase is $PHASE (not SIMPLICITY), ignoring promise"
        echo "btsc: Promise detected but phase is $PHASE (not SIMPLICITY). Continuing loop..." >&2
      fi
    else
      debug_log "No completion promise found in output"
    fi

    # Check if SIMPLICITY phase is complete (all tests passing, session done)
    if [[ "$PHASE" == "SIMPLICITY" ]] && [[ "$SUBSTATE" == "REFACTOR" ]]; then
      debug_log "In SIMPLICITY/REFACTOR - checking for completion indicators"
      # Check if output indicates completion
      if echo "$LAST_OUTPUT" | grep -qi "simplicity.*complete\|all.*phases.*complete\|tdd.*session.*complete"; then
        debug_log "COMPLETION ACCEPTED - Found completion indicator text"
        TEMP_FILE="${STATE_FILE}.tmp.$$"
        sed 's/^loop_active: true/loop_active: false/' "$STATE_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$STATE_FILE"
        json_continue "btsc: TDD complete! All phases finished."
        exit 0
      fi
    fi
  fi
else
  debug_log "No transcript available or file not found"
fi

# Loop continues - increment iteration
NEXT_ITERATION=$((ITERATION + 1))
debug_log "LOOP CONTINUING - incrementing to iteration $NEXT_ITERATION"

# Update state file atomically
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build phase-aware guidance
PHASE_GUIDANCE=""
case "$PHASE" in
  CORE)
    if [[ "$SUBSTATE" == "RED" ]]; then
      PHASE_GUIDANCE="Write a failing test for the core happy-path behavior. The test must FAIL initially."
    elif [[ "$SUBSTATE" == "GREEN" ]]; then
      PHASE_GUIDANCE="IMPLEMENT the feature to make the failing tests pass. Write the actual code now."
    else
      PHASE_GUIDANCE="Refactor the implementation while keeping tests green. Then complete CORE phase."
    fi
    ;;
  EDGE)
    PHASE_GUIDANCE="Write tests for edge cases, boundaries, and error handling."
    ;;
  SECURITY)
    PHASE_GUIDANCE="Write tests for security concerns: input validation, injection, auth."
    ;;
  PERFORMANCE)
    PHASE_GUIDANCE="Write tests for performance: timing, resources, scale."
    ;;
  SIMPLICITY)
    PHASE_GUIDANCE="Aggressively simplify the code while keeping all tests green."
    ;;
esac

# Construct the prompt to feed back
LOOP_PROMPT="## btsc TDD Loop - Iteration $NEXT_ITERATION

**Feature:** $FEATURE
**Current Phase:** $PHASE
**Current Substate:** $SUBSTATE

### CRITICAL: YOU ARE IN AUTONOMOUS MODE

**DO NOT ask the user to write any code.** You must do ALL work yourself:
- Write tests using Write/Edit tools
- Write implementation using Write/Edit tools
- Run tests using Bash
- Refactor code yourself

**Never say \"Your turn\" or ask the user to implement anything.**

### Your Task

Continue the TDD process for this feature. $PHASE_GUIDANCE

### TDD Cycle Reminder

- **RED**: YOU write a failing test that defines expected behavior
- **GREEN**: YOU write minimal code to make the test pass
- **REFACTOR**: YOU improve code quality while keeping tests green

### Phase Progression

CORE → EDGE → SECURITY → PERFORMANCE → SIMPLICITY

**IMPORTANT:** Complete CORE phase fully before moving to EDGE. Your feature must be implemented and working first.

### Completion Rules

The loop ONLY ends when:
1. You are in SIMPLICITY phase (all other phases complete)
2. All tests are passing
3. You output: <promise>TDD_COMPLETE</promise>

**The promise is IGNORED if you are not in SIMPLICITY phase.** You must complete CORE, EDGE, SECURITY, and PERFORMANCE first.

---

Continue working on: $FEATURE"

# Build system message
SYSTEM_MSG="btsc iteration $NEXT_ITERATION | Phase: $PHASE/$SUBSTATE | To complete: <promise>TDD_COMPLETE</promise>"

debug_log "Feeding prompt back to Claude with system message: $SYSTEM_MSG"
debug_log "=== Stop hook complete - blocking exit ==="

# Output JSON to block exit and feed prompt back
json_block "$LOOP_PROMPT" "$SYSTEM_MSG"

exit 0