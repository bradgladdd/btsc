#!/bin/bash
# Test harness for btsc post-tool-use.sh
# Tests various scenarios to verify hook behavior

# Don't exit on error - we want to run all tests
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
POST_HOOK="$PLUGIN_ROOT/hooks/post-tool-use.sh"
TEST_DIR=$(mktemp -d)
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Helper to create a state file
create_state_file() {
  local phase="$1"
  local substate="$2"

  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test feature"
phase: $phase
substate: $substate
loop_active: true
iteration: 1
max_iterations: 10
started_at: "2026-01-18T00:00:00Z"
test_files: []
---
EOF
}

# Helper to run hook with mock input
run_hook() {
  local command="$1"
  local exit_code="$2"
  
  cd "$TEST_DIR"
  echo "{\"command\": \"$command\", \"exit_code\": $exit_code}" | bash "$POST_HOOK" 2>&1
}

# Test runner for empty JSON response
test_empty_json() {
  local name="$1"
  local command="$2"
  local exit_code="${3:-0}"

  echo -n "Testing: $name... "

  local result
  result=$(run_hook "$command" "$exit_code")

  # Should return exactly {} or empty
  if [[ "$result" == "{}" ]] || [[ -z "$result" ]]; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
    return 0
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Expected: {}"
  echo "  Got: $result"
  ((FAILED++))
  return 1
}

# Test runner for systemMessage response
test_system_message() {
  local name="$1"
  local command="$2"
  local exit_code="$3"
  local expected_pattern="$4"

  echo -n "Testing: $name... "

  local result
  result=$(run_hook "$command" "$exit_code")

  # Should contain systemMessage with expected pattern
  if echo "$result" | grep -q '"systemMessage"' && echo "$result" | grep -qi "$expected_pattern"; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
    return 0
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Expected pattern: $expected_pattern"
  echo "  Got: $result"
  ((FAILED++))
  return 1
}

echo "========================================"
echo "btsc PostToolUse Hook Test Suite"
echo "========================================"
echo ""

# ========================================
# No State File Tests
# ========================================
echo -e "${YELLOW}Scenario 1: No state file${NC}"
rm -rf "$TEST_DIR/.claude"
mkdir -p "$TEST_DIR"
test_empty_json "No state file returns empty JSON" "npm test" 0
echo ""

# ========================================
# Non-Test Command Tests
# ========================================
echo -e "${YELLOW}Scenario 2: Non-test commands return empty JSON${NC}"
create_state_file "CORE" "RED"
test_empty_json "git status" "git status" 0
test_empty_json "npm install" "npm install" 0
test_empty_json "ls -la" "ls -la" 0
test_empty_json "cat file.txt" "cat file.txt" 0
test_empty_json "mkdir test" "mkdir test" 0
test_empty_json "echo hello" "echo hello" 0
test_empty_json "node script.js" "node script.js" 0
test_empty_json "python app.py" "python app.py" 0
test_empty_json "setup-tdd-loop.sh" "/path/to/setup-tdd-loop.sh feature" 0
echo ""

# ========================================
# Test Command Detection Tests
# ========================================
echo -e "${YELLOW}Scenario 3: Test commands are detected${NC}"
create_state_file "CORE" "GREEN"

# JavaScript/TypeScript
test_system_message "npm test detected" "npm test" 0 "GREEN"
test_system_message "npm run test detected" "npm run test" 0 "GREEN"
test_system_message "yarn test detected" "yarn test" 0 "GREEN"
test_system_message "pnpm test detected" "pnpm test" 0 "GREEN"
test_system_message "bun test detected" "bun test" 0 "GREEN"
test_system_message "npx jest detected" "npx jest" 0 "GREEN"
test_system_message "npx vitest detected" "npx vitest" 0 "GREEN"
test_system_message "npx mocha detected" "npx mocha" 0 "GREEN"
test_system_message "npx playwright detected" "npx playwright test" 0 "GREEN"

# Python
test_system_message "pytest detected" "pytest" 0 "GREEN"
test_system_message "pytest with args" "pytest -v tests/" 0 "GREEN"
test_system_message "python -m pytest detected" "python -m pytest" 0 "GREEN"
test_system_message "python -m unittest detected" "python -m unittest" 0 "GREEN"

# Go
test_system_message "go test detected" "go test ./..." 0 "GREEN"

# Rust
test_system_message "cargo test detected" "cargo test" 0 "GREEN"

# Java
test_system_message "mvn test detected" "mvn test" 0 "GREEN"
test_system_message "gradle test detected" "gradle test" 0 "GREEN"
test_system_message "./gradlew test detected" "./gradlew test" 0 "GREEN"

# .NET
test_system_message "dotnet test detected" "dotnet test" 0 "GREEN"

# Ruby
test_system_message "rspec detected" "rspec" 0 "GREEN"
test_system_message "bundle exec rspec detected" "bundle exec rspec" 0 "GREEN"
test_system_message "rake test detected" "rake test" 0 "GREEN"

# PHP
test_system_message "phpunit detected" "phpunit" 0 "GREEN"
test_system_message "./vendor/bin/phpunit detected" "./vendor/bin/phpunit" 0 "GREEN"

# Elixir
test_system_message "mix test detected" "mix test" 0 "GREEN"

# Dart/Flutter
test_system_message "flutter test detected" "flutter test" 0 "GREEN"
test_system_message "dart test detected" "dart test" 0 "GREEN"
echo ""

# ========================================
# RED Phase Tests
# ========================================
echo -e "${YELLOW}Scenario 4: RED phase feedback${NC}"
create_state_file "CORE" "RED"
test_system_message "RED + FAIL = expected" "npm test" 1 "expected"
test_system_message "RED + FAIL mentions GREEN" "npm test" 1 "GREEN"

create_state_file "CORE" "RED"
test_system_message "RED + PASS = problem" "npm test" 0 "PROBLEM"
test_system_message "RED + PASS warns not to transition" "npm test" 0 "NOT transition to GREEN"
echo ""

# ========================================
# GREEN Phase Tests
# ========================================
echo -e "${YELLOW}Scenario 5: GREEN phase feedback${NC}"
create_state_file "EDGE" "GREEN"
test_system_message "GREEN + PASS = transition to REFACTOR" "pytest" 0 "REFACTOR"

create_state_file "EDGE" "GREEN"
test_system_message "GREEN + FAIL = continue implementing" "pytest" 1 "Continue implementing"
echo ""

# ========================================
# REFACTOR Phase Tests
# ========================================
echo -e "${YELLOW}Scenario 6: REFACTOR phase feedback${NC}"
create_state_file "SECURITY" "REFACTOR"
test_system_message "REFACTOR + PASS = continue or complete" "cargo test" 0 "complete"

create_state_file "SECURITY" "REFACTOR"
test_system_message "REFACTOR + FAIL = ALERT revert" "cargo test" 1 "ALERT"
test_system_message "REFACTOR + FAIL mentions revert" "cargo test" 1 "Revert"
echo ""

# ========================================
# All Phases Test
# ========================================
echo -e "${YELLOW}Scenario 7: All phases work${NC}"
for phase in CORE EDGE SECURITY PERFORMANCE SIMPLICITY; do
  create_state_file "$phase" "GREEN"
  test_system_message "$phase phase returns feedback" "npm test" 0 "GREEN"
done
echo ""

# ========================================
# Exit Code Variations
# ========================================
echo -e "${YELLOW}Scenario 8: Various exit codes${NC}"
create_state_file "CORE" "GREEN"
test_system_message "Exit code 0 = pass" "npm test" 0 "PASSED"

create_state_file "CORE" "GREEN"
test_system_message "Exit code 1 = fail" "npm test" 1 "FAILED"

create_state_file "CORE" "GREEN"
test_system_message "Exit code 2 = fail" "npm test" 2 "FAILED"

create_state_file "CORE" "GREEN"
test_system_message "Exit code 127 = fail" "npm test" 127 "FAILED"
echo ""

echo "========================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi