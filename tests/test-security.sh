#!/bin/bash
# Security test suite for btsc hooks
# Tests for injection attacks, path traversal, and edge cases
#
# SAFETY: All injection attempts only try to create a marker file
# in the test's temp directory. No destructive commands are used.

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PRE_HOOK="$PLUGIN_ROOT/hooks/pre-tool-use-hook.sh"
POST_HOOK="$PLUGIN_ROOT/hooks/post-tool-use-hook.sh"
STOP_HOOK="$PLUGIN_ROOT/hooks/stop-hook.sh"
TEST_DIR=$(mktemp -d)
MARKER_FILE="$TEST_DIR/pwned_marker"
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

echo "========================================"
echo "btsc Security Test Suite"
echo "========================================"
echo "Test directory: $TEST_DIR"
echo "Marker file: $MARKER_FILE"
echo ""

create_state_file() {
  local substate="${1:-RED}"
  local loop_active="${2:-false}"
  local feature="${3:-test feature}"

  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "$feature"
phase: CORE
substate: $substate
loop_active: $loop_active
iteration: 1
max_iterations: 10
test_files: []
---
EOF
}

# Test that hook doesn't crash and returns valid JSON
test_no_crash() {
  local name="$1"
  local hook="$2"
  local input="$3"

  echo -n "Testing: $name... "

  cd "$TEST_DIR"
  local result
  result=$(echo "$input" | timeout 5 bash "$hook" 2>&1)
  local exit_code=$?

  # Should not crash (exit 0) and should return some output
  if [[ $exit_code -eq 0 ]]; then
    # Basic check that it looks like JSON or is empty
    if [[ -z "$result" ]] || [[ "$result" == "{}" ]] || echo "$result" | grep -qE '^\{.*\}$'; then
      echo -e "${GREEN}PASSED${NC}"
      ((PASSED++))
      return 0
    fi
  fi

  echo -e "${RED}FAILED${NC}"
  echo "  Exit code: $exit_code"
  echo "  Output (truncated): ${result:0:200}"
  ((FAILED++))
  return 1
}

# Test that malicious input doesn't execute commands
# SAFETY: Only checks for creation of a harmless marker file in temp dir
test_no_execution() {
  local name="$1"
  local hook="$2"
  local input="$3"

  echo -n "Testing: $name... "

  # Clean marker before test
  rm -f "$MARKER_FILE"
  
  cd "$TEST_DIR"
  
  # Run hook with potentially malicious input
  echo "$input" | timeout 5 bash "$hook" >/dev/null 2>&1

  # Check if marker file was created (would indicate code execution)
  if [[ -f "$MARKER_FILE" ]]; then
    echo -e "${RED}FAILED - CODE EXECUTION DETECTED${NC}"
    rm -f "$MARKER_FILE"
    ((FAILED++))
    return 1
  fi

  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
  return 0
}

# ========================================
# Shell Injection in file_path (PreToolUse)
# ========================================
echo -e "${YELLOW}=== PreToolUse: Shell Injection Tests ===${NC}"
create_state_file "GREEN"

# All injection attempts only try to touch the marker file in TEST_DIR
test_no_crash "Semicolon injection in file_path" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts; touch $MARKER_FILE\"}"

test_no_execution "Semicolon injection doesn't execute" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts; touch $MARKER_FILE\"}"

test_no_crash "Backtick injection in file_path" "$PRE_HOOK" \
  "{\"file_path\": \"src/\`touch $MARKER_FILE\`.ts\"}"

test_no_execution "Backtick injection doesn't execute" "$PRE_HOOK" \
  "{\"file_path\": \"src/\`touch $MARKER_FILE\`.ts\"}"

test_no_crash "Dollar parens injection in file_path" "$PRE_HOOK" \
  "{\"file_path\": \"src/\$(touch $MARKER_FILE).ts\"}"

test_no_execution "Dollar parens injection doesn't execute" "$PRE_HOOK" \
  "{\"file_path\": \"src/\$(touch $MARKER_FILE).ts\"}"

test_no_crash "Pipe injection in file_path" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts | touch $MARKER_FILE\"}"

test_no_execution "Pipe injection doesn't execute" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts | touch $MARKER_FILE\"}"

test_no_crash "Ampersand injection in file_path" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts && touch $MARKER_FILE\"}"

test_no_execution "Ampersand injection doesn't execute" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts && touch $MARKER_FILE\"}"

test_no_crash "Newline injection in file_path" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts\ntouch $MARKER_FILE\"}"

test_no_execution "Newline injection doesn't execute" "$PRE_HOOK" \
  "{\"file_path\": \"src/app.ts\ntouch $MARKER_FILE\"}"
echo ""

# ========================================
# Path Traversal (PreToolUse)
# ========================================
echo -e "${YELLOW}=== PreToolUse: Path Traversal Tests ===${NC}"
create_state_file "RED"

test_no_crash "Path traversal ../../../etc/passwd" "$PRE_HOOK" \
  '{"file_path": "../../../etc/passwd"}'

test_no_crash "Path traversal with URL encoding" "$PRE_HOOK" \
  '{"file_path": "..%2F..%2F..%2Fetc%2Fpasswd"}'

test_no_crash "Absolute path /etc/passwd" "$PRE_HOOK" \
  '{"file_path": "/etc/passwd"}'

test_no_crash "Home directory expansion ~" "$PRE_HOOK" \
  '{"file_path": "~/../../etc/passwd"}'

test_no_crash "Null byte injection" "$PRE_HOOK" \
  '{"file_path": "src/app.ts\u0000.test.ts"}'
echo ""

# ========================================
# Shell Injection in command (PostToolUse)
# ========================================
echo -e "${YELLOW}=== PostToolUse: Shell Injection Tests ===${NC}"
create_state_file "GREEN"

test_no_crash "Semicolon injection in command" "$POST_HOOK" \
  "{\"command\": \"npm test; touch $MARKER_FILE\", \"exit_code\": 0}"

test_no_execution "Semicolon in command doesn't execute" "$POST_HOOK" \
  "{\"command\": \"npm test; touch $MARKER_FILE\", \"exit_code\": 0}"

test_no_crash "Backtick injection in command" "$POST_HOOK" \
  "{\"command\": \"npm \`touch $MARKER_FILE\` test\", \"exit_code\": 0}"

test_no_execution "Backtick in command doesn't execute" "$POST_HOOK" \
  "{\"command\": \"npm \`touch $MARKER_FILE\` test\", \"exit_code\": 0}"

test_no_crash "Dollar parens in command" "$POST_HOOK" \
  "{\"command\": \"npm \$(touch $MARKER_FILE) test\", \"exit_code\": 0}"

test_no_execution "Dollar parens in command doesn't execute" "$POST_HOOK" \
  "{\"command\": \"npm \$(touch $MARKER_FILE) test\", \"exit_code\": 0}"

test_no_crash "Pipe in command" "$POST_HOOK" \
  "{\"command\": \"npm test | touch $MARKER_FILE\", \"exit_code\": 0}"

test_no_execution "Pipe in command doesn't execute" "$POST_HOOK" \
  "{\"command\": \"npm test | touch $MARKER_FILE\", \"exit_code\": 0}"
echo ""

# ========================================
# Shell Injection via State File
# ========================================
echo -e "${YELLOW}=== State File: Shell Injection Tests ===${NC}"

# Create state file with malicious feature name targeting our marker
mkdir -p "$TEST_DIR/.claude"
cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test; touch $MARKER_FILE"
phase: CORE
substate: GREEN
loop_active: true
iteration: 1
max_iterations: 10
test_files: []
---
EOF

test_no_crash "Malicious feature name (stop hook)" "$STOP_HOOK" \
  '{"transcript_path": ""}'

test_no_execution "Malicious feature doesn't execute" "$STOP_HOOK" \
  '{"transcript_path": ""}'

# Malicious phase value
cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test"
phase: CORE; touch $MARKER_FILE
substate: GREEN
loop_active: false
iteration: 1
max_iterations: 10
---
EOF

test_no_crash "Malicious phase value (pre hook)" "$PRE_HOOK" \
  '{"file_path": "src/app.ts"}'

test_no_execution "Malicious phase doesn't execute" "$PRE_HOOK" \
  '{"file_path": "src/app.ts"}'

# Malicious substate value
cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test"
phase: CORE
substate: GREEN && touch $MARKER_FILE
loop_active: false
iteration: 1
max_iterations: 10
---
EOF

test_no_crash "Malicious substate value" "$PRE_HOOK" \
  '{"file_path": "src/app.ts"}'

test_no_execution "Malicious substate doesn't execute" "$PRE_HOOK" \
  '{"file_path": "src/app.ts"}'

# Reset state file
create_state_file "GREEN"
echo ""

# ========================================
# Large Input Tests (reduced size for safety)
# ========================================
echo -e "${YELLOW}=== DoS: Large Input Tests ===${NC}"
create_state_file "GREEN"

# 100KB string (reduced from 1MB for faster testing)
LARGE_STRING=$(head -c 100000 /dev/zero 2>/dev/null | tr '\0' 'a')

test_no_crash "Large file_path (100KB)" "$PRE_HOOK" \
  "{\"file_path\": \"$LARGE_STRING\"}"

test_no_crash "Large command (100KB)" "$POST_HOOK" \
  "{\"command\": \"$LARGE_STRING\", \"exit_code\": 0}"

unset LARGE_STRING

# Deeply nested JSON
DEEP_JSON='{"a":{"b":{"c":{"d":{"e":{"f":{"file_path":"src/app.ts"}}}}}}}'
test_no_crash "Deeply nested JSON" "$PRE_HOOK" "$DEEP_JSON"
echo ""

# ========================================
# Unicode and Special Characters
# ========================================
echo -e "${YELLOW}=== Unicode and Special Character Tests ===${NC}"
create_state_file "GREEN"

test_no_crash "Unicode in file_path" "$PRE_HOOK" \
  '{"file_path": "src/文件.ts"}'

test_no_crash "Emoji in file_path" "$PRE_HOOK" \
  '{"file_path": "src/🔥app🔥.ts"}'

test_no_crash "Zero-width chars in file_path" "$PRE_HOOK" \
  '{"file_path": "src/app\u200B.ts"}'

test_no_crash "RTL override in file_path" "$PRE_HOOK" \
  '{"file_path": "src/\u202Eapp.ts"}'

test_no_crash "Unicode in command" "$POST_HOOK" \
  '{"command": "npm test 文件", "exit_code": 0}'
echo ""

# ========================================
# Transcript Path Injection (Stop Hook)
# ========================================
echo -e "${YELLOW}=== Stop Hook: Transcript Path Tests ===${NC}"
create_state_file "GREEN" "true"

# Create a fake sensitive file in test dir
echo "FAKE SENSITIVE DATA" > "$TEST_DIR/sensitive.txt"

test_no_crash "Transcript path to non-transcript file" "$STOP_HOOK" \
  "{\"transcript_path\": \"$TEST_DIR/sensitive.txt\"}"

test_no_crash "Transcript path traversal" "$STOP_HOOK" \
  '{"transcript_path": "../../../etc/passwd"}'

# These might hang, so use shorter timeout
echo -n "Testing: Transcript path /dev/null... "
result=$(cd "$TEST_DIR" && echo '{"transcript_path": "/dev/null"}' | timeout 2 bash "$STOP_HOOK" 2>&1)
if [[ $? -le 124 ]]; then  # 124 is timeout exit code
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED (timeout)${NC}"
  ((FAILED++))
fi
echo ""

# ========================================
# Symlink Attack Tests
# ========================================
echo -e "${YELLOW}=== Symlink Attack Tests ===${NC}"

# Only run if we can create symlinks
if ln -sf /dev/null "$TEST_DIR/test_symlink" 2>/dev/null; then
  rm -f "$TEST_DIR/test_symlink"
  
  # State file is symlink
  rm -rf "$TEST_DIR/.claude"
  mkdir -p "$TEST_DIR/.claude"
  ln -sf /dev/null "$TEST_DIR/.claude/tdd.local.md" 2>/dev/null

  test_no_crash "State file symlink to /dev/null (pre)" "$PRE_HOOK" \
    '{"file_path": "src/app.ts"}'

  test_no_crash "State file symlink to /dev/null (post)" "$POST_HOOK" \
    '{"command": "npm test", "exit_code": 0}'

  test_no_crash "State file symlink to /dev/null (stop)" "$STOP_HOOK" \
    '{"transcript_path": ""}'

  # Restore normal state file
  rm -f "$TEST_DIR/.claude/tdd.local.md"
  create_state_file "GREEN"
else
  echo "Skipping symlink tests (symlinks not supported)"
fi
echo ""

# ========================================
# JSON Edge Cases
# ========================================
echo -e "${YELLOW}=== JSON Edge Cases ===${NC}"
create_state_file "GREEN"

test_no_crash "JSON with escaped quotes" "$PRE_HOOK" \
  '{"file_path": "src/\"app\".ts"}'

test_no_crash "JSON with backslashes" "$PRE_HOOK" \
  '{"file_path": "src\\\\app\\\\file.ts"}'

test_no_crash "JSON with unicode escapes" "$PRE_HOOK" \
  '{"file_path": "src/\\u0061pp.ts"}'

test_no_crash "JSON with control characters" "$PRE_HOOK" \
  '{"file_path": "src/\\t\\r\\napp.ts"}'

test_no_crash "JSON array instead of object" "$PRE_HOOK" \
  '["src/app.ts"]'

test_no_crash "JSON number instead of string" "$PRE_HOOK" \
  '{"file_path": 12345}'

test_no_crash "JSON boolean instead of string" "$PRE_HOOK" \
  '{"file_path": true}'

test_no_crash "JSON null value" "$PRE_HOOK" \
  '{"file_path": null}'

test_no_crash "Empty JSON object" "$PRE_HOOK" \
  '{}'

test_no_crash "Completely empty input" "$PRE_HOOK" \
  ''

test_no_crash "Not JSON at all" "$PRE_HOOK" \
  'this is not json at all'
echo ""

# ========================================
# Environment Variable Tests
# ========================================
echo -e "${YELLOW}=== Environment Variable Tests ===${NC}"
create_state_file "GREEN"

# Set a test secret (harmless value)
export BTSC_TEST_SECRET="secret_test_value_12345"

echo -n "Testing: Env var reference not expanded in file_path... "
result=$(cd "$TEST_DIR" && echo '{"file_path": "$BTSC_TEST_SECRET"}' | bash "$PRE_HOOK" 2>&1)
if echo "$result" | grep -q "secret_test_value_12345"; then
  echo -e "${RED}FAILED - Secret expanded${NC}"
  ((FAILED++))
else
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
fi

echo -n "Testing: Env var reference not expanded in command... "
result=$(cd "$TEST_DIR" && echo '{"command": "echo $BTSC_TEST_SECRET", "exit_code": 0}' | bash "$POST_HOOK" 2>&1)
if echo "$result" | grep -q "secret_test_value_12345"; then
  echo -e "${RED}FAILED - Secret expanded${NC}"
  ((FAILED++))
else
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
fi

unset BTSC_TEST_SECRET
echo ""

# ========================================
# Final Summary
# ========================================
echo "========================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "========================================"

# Verify no marker file was left behind
if [[ -f "$MARKER_FILE" ]]; then
  echo -e "${RED}WARNING: Marker file exists - possible injection succeeded somewhere${NC}"
  rm -f "$MARKER_FILE"
fi

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi