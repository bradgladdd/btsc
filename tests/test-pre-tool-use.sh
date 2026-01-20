#!/bin/bash
# Test harness for btsc pre-tool-use-hook.sh
# Tests TDD enforcement for file edits

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PRE_HOOK="$PLUGIN_ROOT/hooks/pre-tool-use-hook.sh"
TEST_DIR=$(mktemp -d)
PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

create_state_file() {
  local substate="$1"
  local custom_patterns="${2:-}"

  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test feature"
phase: CORE
substate: $substate
loop_active: true
iteration: 1
max_iterations: 10
test_files: []
test_patterns: [$custom_patterns]
---
EOF
}

run_hook() {
  local json_input="$1"
  cd "$TEST_DIR"
  echo "$json_input" | bash "$PRE_HOOK" 2>&1
}

run_hook_file_path() {
  local file_path="$1"
  run_hook "{\"file_path\": \"$file_path\"}"
}

test_approve() {
  local name="$1"
  local file_path="$2"

  echo -n "Testing: $name... "
  local result
  result=$(run_hook_file_path "$file_path")

  if echo "$result" | grep -q '"decision": "approve"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
    return 0
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Expected: approve"
  echo "  Got: $result"
  ((FAILED++))
  return 1
}

test_deny() {
  local name="$1"
  local file_path="$2"

  echo -n "Testing: $name... "
  local result
  result=$(run_hook_file_path "$file_path")

  if echo "$result" | grep -q '"decision": "deny"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
    return 0
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Expected: deny"
  echo "  Got: $result"
  ((FAILED++))
  return 1
}

test_approve_raw() {
  local name="$1"
  local json_input="$2"

  echo -n "Testing: $name... "
  local result
  result=$(run_hook "$json_input")

  if echo "$result" | grep -q '"decision": "approve"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
    return 0
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Expected: approve"
  echo "  Got: $result"
  ((FAILED++))
  return 1
}

echo "========================================"
echo "btsc PreToolUse Hook Test Suite"
echo "========================================"
echo ""

# ========================================
# No State File
# ========================================
echo -e "${YELLOW}Scenario 1: No state file - all edits allowed${NC}"
rm -rf "$TEST_DIR/.claude"
mkdir -p "$TEST_DIR"
test_approve "No state file approves impl edit" "src/app.ts"
test_approve "No state file approves test edit" "src/app.test.ts"
echo ""

# ========================================
# State/Config Files Always Approved
# ========================================
echo -e "${YELLOW}Scenario 2: State/config files always approved${NC}"
create_state_file "RED"
test_approve ".claude/tdd.local.md" ".claude/tdd.local.md"
test_approve ".claude/settings.json" ".claude/settings.json"
test_approve ".claude/settings.local.json" ".claude/settings.local.json"
test_approve "nested .claude path" "project/.claude/config.json"
echo ""

# ========================================
# Test File Patterns - Extension Based
# ========================================
echo -e "${YELLOW}Scenario 3: Test files (extension-based) always approved${NC}"
create_state_file "RED"

# .test. pattern
test_approve "file.test.ts" "src/file.test.ts"
test_approve "file.test.js" "src/file.test.js"
test_approve "file.test.tsx" "src/components/Button.test.tsx"
test_approve "file.test.jsx" "src/components/Button.test.jsx"

# .spec. pattern
test_approve "file.spec.ts" "src/file.spec.ts"
test_approve "file.spec.js" "src/file.spec.js"
test_approve "file.spec.tsx" "src/components/Button.spec.tsx"

# _test. pattern
test_approve "file_test.go" "pkg/handler_test.go"
test_approve "file_test.py" "src/utils_test.py"

# _spec. pattern
test_approve "file_spec.rb" "app/models/user_spec.rb"
echo ""

# ========================================
# Test File Patterns - Prefix Based
# ========================================
echo -e "${YELLOW}Scenario 4: Test files (prefix-based) always approved${NC}"
create_state_file "RED"
test_approve "test_file.py in dir" "src/test_utils.py"
test_approve "test_file.py at root" "test_main.py"
echo ""

# ========================================
# Test File Patterns - Suffix PascalCase
# ========================================
echo -e "${YELLOW}Scenario 5: Test files (PascalCase suffix) always approved${NC}"
create_state_file "RED"
test_approve "FileTest.java" "src/main/java/UserTest.java"
test_approve "FileTest.kt" "src/test/kotlin/UserTest.kt"
test_approve "FileTests.java" "src/test/java/UserTests.java"
test_approve "FileTests.cs" "Tests/UserTests.cs"
test_approve "FileSpec.scala" "src/test/scala/UserSpec.scala"
echo ""

# ========================================
# Test File Patterns - Directory Based
# ========================================
echo -e "${YELLOW}Scenario 6: Test files (directory-based) always approved${NC}"
create_state_file "RED"
test_approve "__tests__/ directory" "src/__tests__/app.js"
test_approve "tests/ directory" "tests/unit/test_app.py"
test_approve "test/ directory" "test/app_test.rb"
test_approve "spec/ directory" "spec/models/user_spec.rb"
test_approve "specs/ directory" "specs/integration/api_spec.js"
echo ""

# ========================================
# Test File Patterns - E2E/Integration
# ========================================
echo -e "${YELLOW}Scenario 7: E2E/Integration test files always approved${NC}"
create_state_file "RED"
test_approve "e2e/ directory" "e2e/login.spec.ts"
test_approve "cypress/ directory" "cypress/e2e/login.cy.js"
test_approve "cypress/integration" "cypress/integration/login.spec.js"
test_approve "playwright/ directory" "playwright/tests/login.spec.ts"
echo ""

# ========================================
# Custom Test Patterns
# ========================================
echo -e "${YELLOW}Scenario 8: Custom test patterns from state file${NC}"
create_state_file "RED" '"myCustomTest", "special/"'
test_approve "Custom pattern myCustomTest" "src/myCustomTest_utils.ts"
test_approve "Custom pattern special/" "special/helpers.ts"
echo ""

# ========================================
# Implementation Files - RED Phase
# ========================================
echo -e "${YELLOW}Scenario 9: Implementation files blocked in RED phase${NC}"
create_state_file "RED"
test_deny "src/app.ts in RED" "src/app.ts"
test_deny "src/utils.js in RED" "src/utils.js"
test_deny "lib/helper.py in RED" "lib/helper.py"
test_deny "pkg/main.go in RED" "pkg/main.go"
test_deny "src/index.tsx in RED" "src/index.tsx"
echo ""

# ========================================
# Implementation Files - GREEN Phase
# ========================================
echo -e "${YELLOW}Scenario 10: Implementation files allowed in GREEN phase${NC}"
create_state_file "GREEN"
test_approve "src/app.ts in GREEN" "src/app.ts"
test_approve "src/utils.js in GREEN" "src/utils.js"
test_approve "lib/helper.py in GREEN" "lib/helper.py"
test_approve "pkg/main.go in GREEN" "pkg/main.go"
echo ""

# ========================================
# Implementation Files - REFACTOR Phase
# ========================================
echo -e "${YELLOW}Scenario 11: Implementation files allowed in REFACTOR phase${NC}"
create_state_file "REFACTOR"
test_approve "src/app.ts in REFACTOR" "src/app.ts"
test_approve "src/utils.js in REFACTOR" "src/utils.js"
test_approve "lib/helper.py in REFACTOR" "lib/helper.py"
echo ""

# ========================================
# Edge Cases - Empty/Missing Fields
# ========================================
echo -e "${YELLOW}Scenario 12: Edge cases - empty/missing fields${NC}"
create_state_file "RED"
test_approve "Empty file path" ""
test_approve_raw "Empty JSON object" "{}"
test_approve_raw "Null file_path" '{"file_path": null}'
test_approve_raw "Missing file_path entirely" '{"tool": "Write", "other": "data"}'
echo ""

# ========================================
# Edge Cases - Alternative Field Names
# ========================================
echo -e "${YELLOW}Scenario 13: Edge cases - alternative field names${NC}"
create_state_file "GREEN"
test_approve_raw "Uses 'path' instead of 'file_path'" '{"path": "src/app.ts"}'
test_approve_raw "Uses 'file' instead of 'file_path'" '{"file": "src/app.ts"}'

create_state_file "RED"
echo -n "Testing: 'path' field blocked in RED... "
result=$(run_hook '{"path": "src/app.ts"}')
if echo "$result" | grep -q '"decision": "deny"'; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED${NC}"
  echo "  Expected: deny"
  echo "  Got: $result"
  ((FAILED++))
fi

echo -n "Testing: 'file' field blocked in RED... "
result=$(run_hook '{"file": "src/app.ts"}')
if echo "$result" | grep -q '"decision": "deny"'; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED${NC}"
  echo "  Expected: deny"
  echo "  Got: $result"
  ((FAILED++))
fi
echo ""

# ========================================
# Edge Cases - Malformed Input
# ========================================
echo -e "${YELLOW}Scenario 14: Edge cases - malformed input${NC}"
create_state_file "RED"
test_approve_raw "Completely empty input" ""
test_approve_raw "Not JSON at all" "this is not json"
test_approve_raw "Partial JSON" '{"file_path": '
test_approve_raw "Array instead of object" '["src/app.ts"]'
echo ""

# ========================================
# Edge Cases - Malformed State File
# ========================================
echo -e "${YELLOW}Scenario 15: Edge cases - malformed state file${NC}"
mkdir -p "$TEST_DIR/.claude"
echo "this is not valid frontmatter" > "$TEST_DIR/.claude/tdd.local.md"
echo -n "Testing: Malformed state file defaults to RED... "
result=$(run_hook_file_path "src/app.ts")
if echo "$result" | grep -q '"decision": "deny"'; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED${NC}"
  echo "  Expected: deny (default RED)"
  echo "  Got: $result"
  ((FAILED++))
fi

# Empty state file
echo "" > "$TEST_DIR/.claude/tdd.local.md"
echo -n "Testing: Empty state file defaults to RED... "
result=$(run_hook_file_path "src/app.ts")
if echo "$result" | grep -q '"decision": "deny"'; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED${NC}"
  echo "  Expected: deny (default RED)"
  echo "  Got: $result"
  ((FAILED++))
fi
echo ""

# ========================================
# Edge Cases - File Name Tricks
# ========================================
echo -e "${YELLOW}Scenario 16: Edge cases - tricky file names${NC}"
create_state_file "RED"
test_deny "File with test in name but not pattern" "src/testing_utils.ts"
test_deny "File with spec in name but not pattern" "src/specification.ts"
test_approve "Deeply nested test file" "src/features/auth/components/__tests__/Login.test.tsx"
test_deny "File named Test.ts (no dot after)" "src/Test.ts"
test_approve "File named SomethingTest.ts" "src/SomethingTest.ts"
echo ""

# ========================================
# Cross-Language Coverage
# ========================================
echo -e "${YELLOW}Scenario 17: Cross-language test patterns${NC}"
create_state_file "RED"

# JavaScript/TypeScript
test_approve "Jest test" "src/components/Button.test.tsx"
test_approve "Vitest test" "src/utils.spec.ts"

# Python
test_approve "pytest test" "tests/test_api.py"
test_approve "unittest test" "tests/test_models.py"

# Go
test_approve "Go test" "internal/handler_test.go"

# Rust
test_approve "Rust test" "tests/integration_test.rs"

# Java
test_approve "JUnit test" "src/test/java/UserServiceTest.java"

# Kotlin
test_approve "Kotlin test" "src/test/kotlin/UserServiceTest.kt"

# C#
test_approve "NUnit/xUnit test" "Tests/UserServiceTests.cs"

# Ruby
test_approve "RSpec test" "spec/models/user_spec.rb"

# Scala
test_approve "ScalaTest" "src/test/scala/UserSpec.scala"

# Elixir
test_approve "ExUnit test" "test/user_test.exs"

# PHP
test_approve "PHPUnit test" "tests/UserTest.php"
echo ""

echo "========================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi