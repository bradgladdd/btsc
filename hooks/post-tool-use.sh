#!/bin/bash
set -euo pipefail

# btsc PostToolUse Hook - Test Execution Tracker
# Only provides feedback for test commands, returns empty JSON otherwise

HOOK_INPUT=$(cat)
STATE_FILE=".claude/tdd.local.md"

# Extract command from input
COMMAND=$(echo "$HOOK_INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

# Extract exit code from tool result (look for exit_code or returncode patterns)
EXIT_CODE=$(echo "$HOOK_INPUT" | grep -oE '"(exit_code|returncode)"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+$' || echo "")

# If no state file, return empty JSON
if [[ ! -f "$STATE_FILE" ]]; then
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
)

# Check if command matches any test pattern
IS_TEST_COMMAND=false
for pattern in "${TEST_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    IS_TEST_COMMAND=true
    break
  fi
done

# If not a test command, return empty JSON
if [[ "$IS_TEST_COMMAND" != "true" ]]; then
  echo '{}'
  exit 0
fi

# Parse state file
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//' || echo "CORE")
SUBSTATE=$(echo "$FRONTMATTER" | grep '^substate:' | sed 's/substate: *//' || echo "RED")

# Determine if tests passed or failed
TESTS_PASSED=false
if [[ "$EXIT_CODE" == "0" ]]; then
  TESTS_PASSED=true
fi

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

# Escape message for JSON
MSG=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"systemMessage": "%s"}\n' "$MSG"
exit 0