#!/bin/bash
# Test harness for btsc stop-hook.sh
# Tests various scenarios to verify hook behavior

# Don't exit on error - we want to run all tests
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STOP_HOOK="$PLUGIN_ROOT/hooks/stop-hook.sh"
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
  local loop_active="$3"
  local iteration="$4"
  local max_iterations="$5"

  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test feature"
phase: $phase
substate: $substate
loop_active: $loop_active
iteration: $iteration
max_iterations: $max_iterations
started_at: "2026-01-18T00:00:00Z"
test_files: []
---
EOF
}

# Helper to run hook with mock input
run_hook() {
  local hook_input="$1"
  cd "$TEST_DIR"
  echo "$hook_input" | bash "$STOP_HOOK" 2>&1
}

# Test runner
run_test() {
  local name="$1"
  local expected_decision="$2"
  local expected_pattern="$3"

  echo -n "Testing: $name... "

  local result
  result=$(run_hook '{"transcript_path": ""}')
  local exit_code=$?

  # Check if output contains expected decision
  if [[ "$expected_decision" == "block" ]]; then
    if echo "$result" | grep -q '"decision": "block"'; then
      echo -e "${GREEN}PASSED${NC}"
      ((PASSED++))
      return 0
    fi
  elif [[ "$expected_decision" == "allow" ]]; then
    # Allow means exit 0 with no JSON output (or empty)
    if [[ $exit_code -eq 0 ]] && ! echo "$result" | grep -q '"decision": "block"'; then
      echo -e "${GREEN}PASSED${NC}"
      ((PASSED++))
      return 0
    fi
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Expected: $expected_decision"
  echo "  Got: $result"
  ((FAILED++))
  return 1
}

echo "========================================"
echo "btsc Stop Hook Test Suite"
echo "========================================"
echo ""

# Test 1: No state file - should allow exit
echo -e "${YELLOW}Scenario 1: No state file${NC}"
rm -rf "$TEST_DIR/.claude"
mkdir -p "$TEST_DIR/.claude"
run_test "No state file allows exit" "allow"
echo ""

# Test 2: State file exists but loop_active is false
echo -e "${YELLOW}Scenario 2: Loop not active${NC}"
create_state_file "CORE" "RED" "false" "1" "10"
run_test "loop_active=false allows exit" "allow"
echo ""

# Test 3: Loop active, CORE phase - should block and continue
echo -e "${YELLOW}Scenario 3: Active loop in CORE phase${NC}"
create_state_file "CORE" "RED" "true" "1" "10"
run_test "CORE/RED blocks and continues loop" "block"
echo ""

# Test 4: Loop active, EDGE phase - should block and continue
echo -e "${YELLOW}Scenario 4: Active loop in EDGE phase${NC}"
create_state_file "EDGE" "GREEN" "true" "3" "10"
run_test "EDGE/GREEN blocks and continues loop" "block"
echo ""

# Test 5: Loop active, SIMPLICITY phase - should still block (no promise)
echo -e "${YELLOW}Scenario 5: Active loop in SIMPLICITY (no promise)${NC}"
create_state_file "SIMPLICITY" "REFACTOR" "true" "5" "10"
run_test "SIMPLICITY without promise blocks" "block"
echo ""

# Test 6: Max iterations reached - should allow exit
echo -e "${YELLOW}Scenario 6: Max iterations reached${NC}"
create_state_file "CORE" "GREEN" "true" "10" "10"
run_test "Max iterations allows exit" "allow"
echo ""

# Test 7: Max iterations exceeded - should allow exit
echo -e "${YELLOW}Scenario 7: Max iterations exceeded${NC}"
create_state_file "EDGE" "RED" "true" "15" "10"
run_test "Exceeded max iterations allows exit" "allow"
echo ""

# Test 8: Unlimited iterations (0) - should block
echo -e "${YELLOW}Scenario 8: Unlimited iterations${NC}"
create_state_file "SECURITY" "GREEN" "true" "100" "0"
run_test "Unlimited iterations (max=0) blocks" "block"
echo ""

# ========================================
# Promise Detection Tests
# ========================================

# Helper to create a mock transcript with promise
create_transcript_with_promise() {
  local promise_text="$1"
  local transcript_file="$TEST_DIR/transcript.jsonl"

  # Create a mock transcript with assistant message containing promise
  cat > "$transcript_file" << EOF
{"role":"user","message":{"content":[{"type":"text","text":"test"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"Working on it... <promise>${promise_text}</promise> Done!"}]}}
EOF
  echo "$transcript_file"
}

# Helper to run hook with transcript
run_hook_with_transcript() {
  local transcript_file="$1"
  cd "$TEST_DIR"
  echo "{\"transcript_path\": \"$transcript_file\"}" | bash "$STOP_HOOK" 2>&1
}

echo ""
echo -e "${YELLOW}Scenario 9: Promise in SIMPLICITY phase - should complete${NC}"
create_state_file "SIMPLICITY" "REFACTOR" "true" "5" "10"
transcript=$(create_transcript_with_promise "TDD_COMPLETE")
result=$(run_hook_with_transcript "$transcript")
if [[ $? -eq 0 ]] && ! echo "$result" | grep -q '"decision": "block"'; then
  echo -e "Testing: Promise in SIMPLICITY allows exit... ${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "Testing: Promise in SIMPLICITY allows exit... ${RED}FAILED${NC}"
  echo "  Got: $result"
  ((FAILED++))
fi
echo ""

echo -e "${YELLOW}Scenario 10: Promise in CORE phase - should be IGNORED${NC}"
create_state_file "CORE" "GREEN" "true" "2" "10"
transcript=$(create_transcript_with_promise "TDD_COMPLETE")
result=$(run_hook_with_transcript "$transcript")
if echo "$result" | grep -q '"decision": "block"'; then
  echo -e "Testing: Promise in CORE is ignored, loop continues... ${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "Testing: Promise in CORE is ignored, loop continues... ${RED}FAILED${NC}"
  echo "  Got: $result"
  ((FAILED++))
fi
echo ""

echo -e "${YELLOW}Scenario 11: Promise in EDGE phase - should be IGNORED${NC}"
create_state_file "EDGE" "REFACTOR" "true" "3" "10"
transcript=$(create_transcript_with_promise "TDD_COMPLETE")
result=$(run_hook_with_transcript "$transcript")
if echo "$result" | grep -q '"decision": "block"'; then
  echo -e "Testing: Promise in EDGE is ignored, loop continues... ${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "Testing: Promise in EDGE is ignored, loop continues... ${RED}FAILED${NC}"
  echo "  Got: $result"
  ((FAILED++))
fi
echo ""

echo -e "${YELLOW}Scenario 12: Wrong promise text - should be IGNORED${NC}"
create_state_file "SIMPLICITY" "REFACTOR" "true" "5" "10"
transcript=$(create_transcript_with_promise "WRONG_PROMISE")
result=$(run_hook_with_transcript "$transcript")
if echo "$result" | grep -q '"decision": "block"'; then
  echo -e "Testing: Wrong promise text is ignored... ${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "Testing: Wrong promise text is ignored... ${RED}FAILED${NC}"
  echo "  Got: $result"
  ((FAILED++))
fi
echo ""

echo -e "${YELLOW}Scenario 13: Iteration counter increments${NC}"
create_state_file "CORE" "RED" "true" "3" "10"
run_hook '{"transcript_path": ""}' > /dev/null
new_iteration=$(grep '^iteration:' "$TEST_DIR/.claude/tdd.local.md" | sed 's/iteration: *//')
if [[ "$new_iteration" == "4" ]]; then
  echo -e "Testing: Iteration incremented from 3 to 4... ${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "Testing: Iteration incremented from 3 to 4... ${RED}FAILED${NC}"
  echo "  Expected: 4, Got: $new_iteration"
  ((FAILED++))
fi
echo ""

echo "========================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
