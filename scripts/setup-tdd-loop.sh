#!/bin/bash
set -euo pipefail

# btsc TDD Loop Setup Script
# Initializes a self-looping TDD session similar to ralph-wiggum

STATE_FILE=".claude/tdd.local.md"
DEBUG_LOG=".claude/btsc-debug.log"

# Ensure .claude directory exists
mkdir -p .claude

# Debug logging function
debug_log() {
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "[$timestamp] SETUP: $1" >> "$DEBUG_LOG"
}

debug_log "=== TDD Loop Setup Started ==="
debug_log "Arguments: $*"

# Defaults
MAX_ITERATIONS=0  # 0 = unlimited
FEATURE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --help|-h)
      cat <<EOF
Usage: /btsc:tdd-loop [FEATURE...] [OPTIONS]

Start an autonomous TDD session where Claude writes all code.

OPTIONS:
  --max-iterations <n>  Maximum iterations before auto-stop (default: unlimited)
  --help, -h            Show this help

EXAMPLES:
  /btsc:tdd-loop user authentication
  /btsc:tdd-loop user authentication --max-iterations 50
  /btsc:tdd-loop "REST API for todos with CRUD operations" --max-iterations 30

COMPLETION:
  The loop continues until SIMPLICITY phase completes with all tests passing.
  To exit early, output: <promise>TDD_COMPLETE</promise>
  To cancel: /btsc:cancel-loop

AUTONOMOUS MODE:
  Claude writes ALL code - tests AND implementation.
  The user can walk away while Claude completes the TDD cycle.
EOF
      exit 0
      ;;
    *)
      # Accumulate feature description
      if [[ -n "$FEATURE" ]]; then
        FEATURE="$FEATURE $1"
      else
        FEATURE="$1"
      fi
      shift
      ;;
  esac
done

# Validate feature
if [[ -z "$FEATURE" ]]; then
  debug_log "ERROR: No feature description provided"
  echo "Error: Feature description required" >&2
  echo "Usage: /btsc:tdd-loop <feature> [--max-iterations N]" >&2
  exit 1
fi

debug_log "Parsed: feature='$FEATURE', max_iterations=$MAX_ITERATIONS"

# Check for existing session
if [[ -f "$STATE_FILE" ]]; then
  debug_log "Existing state file found"
  EXISTING_LOOP=$(grep '^loop_active:' "$STATE_FILE" 2>/dev/null | sed 's/loop_active: *//' || echo "false")
  if [[ "$EXISTING_LOOP" == "true" ]]; then
    debug_log "ERROR: Active loop already exists"
    echo "Warning: An active TDD loop already exists." >&2
    echo "Use /btsc:cancel-loop to cancel it first, or /btsc:tdd-status to check progress." >&2
    exit 1
  fi
  debug_log "Existing session is not a loop - will overwrite"
fi

# Create state file with loop configuration
cat > "$STATE_FILE" <<EOF
---
feature: "$FEATURE"
phase: CORE
substate: RED
loop_active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
test_files: []
test_patterns: []
---

## Session Log

- Loop started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Feature: $FEATURE
- Mode: Self-looping TDD (auto-continues until complete)
EOF

debug_log "State file created: $STATE_FILE"
debug_log "=== TDD Loop Setup Complete ==="

# Output confirmation
cat <<EOF

## btsc TDD Loop Initialized

**Feature:** $FEATURE
**Phase:** CORE (1/5)
**Substate:** RED
**Mode:** Self-looping (auto-continues)
**Max Iterations:** $([ "$MAX_ITERATIONS" -eq 0 ] && echo "Unlimited" || echo "$MAX_ITERATIONS")

### How This Works

1. **YOU write ALL code yourself** - tests AND implementation
2. When you try to stop, the loop feeds the task back to you
3. You see your previous work in files and can continue iterating
4. Loop ends ONLY when SIMPLICITY phase completes with all tests passing

### CRITICAL: FULLY AUTONOMOUS MODE

**DO NOT ask the user to write any code.** The user started a loop so they can walk away.

You must:
- Write all test files using Write/Edit tools
- Write all implementation files using Write/Edit tools
- Run tests using Bash
- Refactor code yourself

**Never say "Your turn" or ask the user to implement anything.**

### Completion Rules

The loop ONLY ends when ALL of these are true:
1. You are in **SIMPLICITY** phase (all other phases complete)
2. All tests are passing
3. You output: \`<promise>TDD_COMPLETE</promise>\`

**The promise is IGNORED if you are not in SIMPLICITY phase.** You must complete:
CORE → EDGE → SECURITY → PERFORMANCE → SIMPLICITY (in order)

### CRITICAL: CORE Phase Priority

**Your feature MUST be implemented and working before moving to EDGE phase.**

Do not write EDGE/SECURITY/PERFORMANCE tests until:
- CORE tests are written (RED)
- Implementation passes all CORE tests (GREEN)
- Code is refactored (REFACTOR)
- CORE phase is COMPLETE

### First Directive

Write a failing test that verifies the core happy-path behavior of: $FEATURE

This test must FAIL initially (you haven't implemented anything yet).

EOF
