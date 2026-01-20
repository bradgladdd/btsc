#!/bin/bash
set -euo pipefail

# btsc PostToolUse Hook - Test Execution Tracker
# Only provides feedback for test commands, returns empty JSON otherwise

HOOK_INPUT=$(cat)
STATE_FILE=".claude/tdd.local.md"
DEBUG_LOG=".claude/btsc-debug.log"

# Ensure .claude directory exists for logging
mkdir -p .claude 2>/dev/null || true

# Debug logging
debug_log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] POST-TOOL-USE: $1" >> "$DEBUG_LOG"
}

debug_log "INPUT: $HOOK_INPUT"

# Extract command from input - try multiple possible field names
COMMAND=""

# Try tool_input.command (nested)
if [[ -z "$COMMAND" ]]; then
  COMMAND=$(echo "$HOOK_INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || echo "")
fi

debug_log "Extracted COMMAND: $COMMAND"

# Extract exit code from tool result - try multiple patterns
EXIT_CODE=""

# Try exit_code
if [[ -z "$EXIT_CODE" ]]; then
  EXIT_CODE=$(echo "$HOOK_INPUT" | grep -oE '"exit_code"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+$' || echo "")
fi

# Try returncode
if [[ -z "$EXIT_CODE" ]]; then
  EXIT_CODE=$(echo "$HOOK_INPUT" | grep -oE '"returncode"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+$' || echo "")
fi

# Try exitCode (camelCase)
if [[ -z "$EXIT_CODE" ]]; then
  EXIT_CODE=$(echo "$HOOK_INPUT" | grep -oE '"exitCode"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+$' || echo "")
fi

# Try status
if [[ -z "$EXIT_CODE" ]]; then
  EXIT_CODE=$(echo "$HOOK_INPUT" | grep -oE '"status"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+$' || echo "")
fi

debug_log "Extracted EXIT_CODE: $EXIT_CODE"

# If no command found, return empty JSON
if [[ -z "$COMMAND" ]]; then
  debug_log "No command found - returning empty JSON"
  echo '{}'
  exit 0
fi

# If no state file, return empty JSON
if [[ ! -f "$STATE_FILE" ]]; then
  debug_log "No state file - returning empty JSON"
  echo '{}'
  exit 0
fi

# Test command patterns
TEST_PATTERNS=(
  "^npm test"
  "^npm run test"
  "^yarn test"
  "^pnpm test"
  "^bun test"
  "^npx jest"
  "^npx vitest"
  "^npx mocha"
  "^npx playwright"
  "^pytest"
  "^python -m pytest"
  "^python -m unittest"
  "^python3 -m pytest"
  "^python3 -m unittest"
  "^go test"
  "^cargo test"
  "^mvn test"
  "^gradle test"
  "^gradlew test"
  "^\./gradlew test"
  "^dotnet test"
  "^rspec"
  "^bundle exec rspec"
  "^rake test"
  "^phpunit"
  "^\./vendor/bin/phpunit"
  "^mix test"
  "^flutter test"
  "^dart test"
  "^elixir.*test"
)

# Check if command matches any test pattern
IS_TEST_COMMAND=false
for pattern in "${TEST_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern" 2>/dev/null; then
    IS_TEST_COMMAND=true
    debug_log "Matched test pattern: $pattern"
    break
  fi
done

# If not a test command, return empty JSON
if [[ "$IS_TEST_COMMAND" != "true" ]]; then
  debug_log "Not a test command - returning empty JSON"
  echo '{}'
  exit 0
fi

# Parse state file safely
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")
PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//' || echo "CORE")
SUBSTATE=$(echo "$FRONTMATTER" | grep '^substate:' | sed 's/substate: *//' || echo "RED")

# Default values if empty
PHASE=${PHASE:-CORE}
SUBSTATE=${SUBSTATE:-RED}

debug_log "Phase: $PHASE, Substate: $SUBSTATE"

# Determine if tests passed or failed
# Default to failed if no exit code (safer assumption)
TESTS_PASSED=false
if [[ "$EXIT_CODE" == "0" ]]; then
  TESTS_PASSED=true
fi

debug_log "Tests passed: $TESTS_PASSED"

# Build feedback message based on phase/substate and test result
MSG=""

if [[ "$SUBSTATE" == "RED" ]]; then
  if [[ "$TESTS_PASSED" == "true" ]]; then
    MSG="btsc: PROBLEM - Tests passed in RED phase. A new test should fail initially. Claude must autonomously: 1) Verify test isolates NEW behavior, 2) Check if feature already exists, 3) Ensure assertions can fail, 4) Rewrite test if needed. Do NOT transition to GREEN until test fails for the right reason."
  else
    MSG="btsc: Tests FAILED in RED phase - this is expected. Verify failure aligns with intended feature, then transition to GREEN and implement."
  fi
elif [[ "$SUBSTATE" == "GREEN" ]]; then
  if [[ "$TESTS_PASSED" == "true" ]]; then
    MSG="btsc: Tests PASSED in GREEN phase. Implementation complete. Transition to REFACTOR phase."
  else
    MSG="btsc: Tests FAILED in GREEN phase. Continue implementing to make tests pass."
  fi
elif [[ "$SUBSTATE" == "REFACTOR" ]]; then
  if [[ "$TESTS_PASSED" == "true" ]]; then
    MSG="btsc: Tests PASSED in REFACTOR phase. Continue refactoring or complete the cycle."
  else
    MSG="btsc: ALERT - Tests FAILED in REFACTOR phase! Refactoring broke something. Revert immediately and try a different approach."
  fi
fi

debug_log "Message: $MSG"

# Escape message for JSON
MSG=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"systemMessage": "%s"}\n' "$MSG"
exit 0