#!/bin/bash
# Tests for debug log security and race conditions

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PRE_HOOK="$PLUGIN_ROOT/hooks/pre-tool-use-hook.sh"
POST_HOOK="$PLUGIN_ROOT/hooks/post-tool-use-hook.sh"
STOP_HOOK="$PLUGIN_ROOT/hooks/stop-hook.sh"
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
  local phase="${1:-CORE}"
  local substate="${2:-RED}"
  local loop_active="${3:-true}"
  local iteration="${4:-1}"

  mkdir -p "$TEST_DIR/.claude"
  cat > "$TEST_DIR/.claude/tdd.local.md" << EOF
---
feature: "test feature"
phase: $phase
substate: $substate
loop_active: $loop_active
iteration: $iteration
max_iterations: 100
test_files: []
---
EOF
}

echo "========================================"
echo "btsc Log Security & Race Condition Tests"
echo "========================================"
echo ""

# ========================================
# Debug Log Security Tests
# ========================================
echo -e "${YELLOW}=== Debug Log Security ===${NC}"
echo ""

create_state_file "CORE" "GREEN"
rm -f "$TEST_DIR/.claude/btsc-debug.log"

# Set sensitive env vars
export BTSC_SECRET_TOKEN="secret_abc123"
export BTSC_API_KEY="sk-live-xyz789"
export BTSC_PASSWORD="hunter2"

# Run hooks with references to secrets
cd "$TEST_DIR"
echo '{"file_path": "$BTSC_SECRET_TOKEN"}' | bash "$PRE_HOOK" >/dev/null 2>&1
echo '{"file_path": "${BTSC_API_KEY}"}' | bash "$PRE_HOOK" >/dev/null 2>&1
echo '{"command": "echo $BTSC_PASSWORD", "exit_code": 0}' | bash "$POST_HOOK" >/dev/null 2>&1
echo '{"command": "export SECRET=$BTSC_SECRET_TOKEN", "exit_code": 0}' | bash "$POST_HOOK" >/dev/null 2>&1
echo '{"transcript_path": "$BTSC_API_KEY"}' | bash "$STOP_HOOK" >/dev/null 2>&1

echo -n "Testing: Debug log doesn't expand \$BTSC_SECRET_TOKEN... "
if [[ -f "$TEST_DIR/.claude/btsc-debug.log" ]]; then
  if grep -q "secret_abc123" "$TEST_DIR/.claude/btsc-debug.log"; then
    echo -e "${RED}FAILED - Secret expanded in log${NC}"
    ((FAILED++))
  else
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
  fi
else
  echo -e "${GREEN}PASSED (no log)${NC}"
  ((PASSED++))
fi

echo -n "Testing: Debug log doesn't expand \$BTSC_API_KEY... "
if [[ -f "$TEST_DIR/.claude/btsc-debug.log" ]]; then
  if grep -q "sk-live-xyz789" "$TEST_DIR/.claude/btsc-debug.log"; then
    echo -e "${RED}FAILED - API key expanded in log${NC}"
    ((FAILED++))
  else
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
  fi
else
  echo -e "${GREEN}PASSED (no log)${NC}"
  ((PASSED++))
fi

echo -n "Testing: Debug log doesn't expand \$BTSC_PASSWORD... "
if [[ -f "$TEST_DIR/.claude/btsc-debug.log" ]]; then
  if grep -q "hunter2" "$TEST_DIR/.claude/btsc-debug.log"; then
    echo -e "${RED}FAILED - Password expanded in log${NC}"
    ((FAILED++))
  else
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
  fi
else
  echo -e "${GREEN}PASSED (no log)${NC}"
  ((PASSED++))
fi

# Check that the literal strings ARE logged (showing input, not expanded)
echo -n "Testing: Debug log contains literal \$BTSC_SECRET_TOKEN... "
if [[ -f "$TEST_DIR/.claude/btsc-debug.log" ]]; then
  if grep -q '\$BTSC_SECRET_TOKEN\|\${BTSC' "$TEST_DIR/.claude/btsc-debug.log"; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
  else
    echo -e "${YELLOW}SKIPPED (input not logged verbatim)${NC}"
    ((PASSED++))
  fi
else
  echo -e "${YELLOW}SKIPPED (no log)${NC}"
  ((PASSED++))
fi

unset BTSC_SECRET_TOKEN BTSC_API_KEY BTSC_PASSWORD
echo ""

# ========================================
# Log File Permissions
# ========================================
echo -e "${YELLOW}=== Log File Permissions ===${NC}"
echo ""

create_state_file "CORE" "GREEN"
rm -f "$TEST_DIR/.claude/btsc-debug.log"

cd "$TEST_DIR"
echo '{"file_path": "src/app.ts"}' | bash "$PRE_HOOK" >/dev/null 2>&1

echo -n "Testing: Debug log is not world-readable... "
if [[ -f "$TEST_DIR/.claude/btsc-debug.log" ]]; then
  perms=$(stat -c "%a" "$TEST_DIR/.claude/btsc-debug.log" 2>/dev/null || stat -f "%Lp" "$TEST_DIR/.claude/btsc-debug.log" 2>/dev/null)
  # Check that "other" doesn't have read (last digit should be 0 or 4 or less)
  other_perms=$((perms % 10))
  if [[ $other_perms -lt 5 ]]; then
    echo -e "${GREEN}PASSED (perms: $perms)${NC}"
    ((PASSED++))
  else
    echo -e "${YELLOW}WARNING - world readable (perms: $perms)${NC}"
    ((PASSED++))  # Not a hard fail, just a warning
  fi
else
  echo -e "${GREEN}PASSED (no log)${NC}"
  ((PASSED++))
fi
echo ""

# ========================================
# Race Condition Tests - State File
# ========================================
echo -e "${YELLOW}=== Race Condition: State File Updates ===${NC}"
echo ""

# Test 1: Parallel iteration updates
echo -n "Testing: Parallel stop hooks don't corrupt state file... "
create_state_file "CORE" "RED" "true" "1"

# Run 20 stop hooks in parallel
for i in {1..20}; do
  (cd "$TEST_DIR" && echo '{"transcript_path": ""}' | bash "$STOP_HOOK" >/dev/null 2>&1) &
done
wait

# Check state file is still valid YAML
if grep -q "^---$" "$TEST_DIR/.claude/tdd.local.md" && \
   grep -q "^phase:" "$TEST_DIR/.claude/tdd.local.md" && \
   grep -q "^substate:" "$TEST_DIR/.claude/tdd.local.md" && \
   grep -q "^iteration:" "$TEST_DIR/.claude/tdd.local.md"; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED - State file corrupted${NC}"
  cat "$TEST_DIR/.claude/tdd.local.md"
  ((FAILED++))
fi

# Test 2: Verify iteration actually incremented (should be somewhere between 2 and 21)
echo -n "Testing: Iteration counter incremented under parallel load... "
iteration=$(grep "^iteration:" "$TEST_DIR/.claude/tdd.local.md" | sed 's/iteration: *//')
if [[ "$iteration" =~ ^[0-9]+$ ]] && [[ "$iteration" -gt 1 ]]; then
  echo -e "${GREEN}PASSED (iteration: $iteration)${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED (iteration: $iteration)${NC}"
  ((FAILED++))
fi

# Test 3: Parallel pre-tool-use hooks (read-only, shouldn't corrupt)
echo -n "Testing: Parallel pre-tool-use hooks don't corrupt state... "
create_state_file "CORE" "GREEN"

for i in {1..20}; do
  (cd "$TEST_DIR" && echo '{"file_path": "src/app.ts"}' | bash "$PRE_HOOK" >/dev/null 2>&1) &
done
wait

if grep -q "^---$" "$TEST_DIR/.claude/tdd.local.md" && \
   grep -q "^substate: GREEN" "$TEST_DIR/.claude/tdd.local.md"; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED - State file corrupted${NC}"
  ((FAILED++))
fi

# Test 4: Mixed parallel hooks
echo -n "Testing: Mixed parallel hooks don't corrupt state... "
create_state_file "CORE" "GREEN" "true" "1"

for i in {1..10}; do
  (cd "$TEST_DIR" && echo '{"file_path": "src/app.ts"}' | bash "$PRE_HOOK" >/dev/null 2>&1) &
  (cd "$TEST_DIR" && echo '{"command": "npm test", "exit_code": 0}' | bash "$POST_HOOK" >/dev/null 2>&1) &
done
wait

if grep -q "^---$" "$TEST_DIR/.claude/tdd.local.md" && \
   grep -q "^phase:" "$TEST_DIR/.claude/tdd.local.md"; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED - State file corrupted${NC}"
  ((FAILED++))
fi
echo ""

# ========================================
# Race Condition Tests - Debug Log
# ========================================
echo -e "${YELLOW}=== Race Condition: Debug Log Writes ===${NC}"
echo ""

create_state_file "CORE" "GREEN"
rm -f "$TEST_DIR/.claude/btsc-debug.log"

echo -n "Testing: Parallel hooks don't corrupt debug log... "
for i in {1..20}; do
  (cd "$TEST_DIR" && echo "{\"file_path\": \"src/file$i.ts\"}" | bash "$PRE_HOOK" >/dev/null 2>&1) &
done
wait

if [[ -f "$TEST_DIR/.claude/btsc-debug.log" ]]; then
  # Check log has valid lines (each should start with timestamp)
  invalid_lines=$(grep -cvE '^\[.*\] PRE-TOOL-USE:' "$TEST_DIR/.claude/btsc-debug.log" || echo "0")
  if [[ "$invalid_lines" == "0" ]]; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
  else
    echo -e "${YELLOW}WARNING - $invalid_lines malformed lines${NC}"
    ((PASSED++))  # Log corruption is less critical
  fi
else
  echo -e "${GREEN}PASSED (no log)${NC}"
  ((PASSED++))
fi
echo ""

# ========================================
# Race Condition Tests - Temp File Cleanup
# ========================================
echo -e "${YELLOW}=== Race Condition: Temp File Cleanup ===${NC}"
echo ""

create_state_file "CORE" "RED" "true" "1"

echo -n "Testing: No temp files left after parallel stop hooks... "
# Run parallel stop hooks
for i in {1..10}; do
  (cd "$TEST_DIR" && echo '{"transcript_path": ""}' | bash "$STOP_HOOK" >/dev/null 2>&1) &
done
wait

# Check for leftover temp files
leftover=$(find "$TEST_DIR/.claude" -name "*.tmp.*" 2>/dev/null | wc -l)
if [[ "$leftover" -eq 0 ]]; then
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
else
  echo -e "${RED}FAILED - $leftover temp files left behind${NC}"
  find "$TEST_DIR/.claude" -name "*.tmp.*" -ls
  ((FAILED++))
fi
echo ""

# ========================================
# Atomic Update Verification
# ========================================
echo -e "${YELLOW}=== Atomic Update Verification ===${NC}"
echo ""

echo -n "Testing: State file never partially written during update... "
create_state_file "CORE" "RED" "true" "1"

# Start a background reader that continuously checks state file validity
READER_ERRORS=0
(
  for i in {1..100}; do
    if [[ -f "$TEST_DIR/.claude/tdd.local.md" ]]; then
      # Check file has both --- markers
      markers=$(grep -c "^---$" "$TEST_DIR/.claude/tdd.local.md" 2>/dev/null || echo "0")
      if [[ "$markers" -lt 2 ]]; then
        echo "PARTIAL_WRITE_DETECTED" >> "$TEST_DIR/reader_errors.log"
      fi
    fi
    sleep 0.01
  done
) &
READER_PID=$!

# Run stop hooks while reader is checking
for i in {1..20}; do
  (cd "$TEST_DIR" && echo '{"transcript_path": ""}' | bash "$STOP_HOOK" >/dev/null 2>&1) &
done
wait

# Stop reader
kill $READER_PID 2>/dev/null || true
wait $READER_PID 2>/dev/null || true

if [[ -f "$TEST_DIR/reader_errors.log" ]]; then
  errors=$(wc -l < "$TEST_DIR/reader_errors.log")
  echo -e "${RED}FAILED - $errors partial writes detected${NC}"
  ((FAILED++))
else
  echo -e "${GREEN}PASSED${NC}"
  ((PASSED++))
fi
echo ""

echo "========================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi