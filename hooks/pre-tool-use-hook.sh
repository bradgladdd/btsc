#!/bin/bash
set -euo pipefail

# btsc PreToolUse Hook - TDD Enforcement
# Blocks implementation edits during RED phase

HOOK_INPUT=$(cat)
STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/tdd.local.md"
DEBUG_LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/btsc-debug.log"

# Ensure .claude directory exists for logging
mkdir -p .claude 2>/dev/null || true

# Debug logging
debug_log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PRE-TOOL-USE: $1" >> "$DEBUG_LOG"
}

debug_log "INPUT: $HOOK_INPUT"

# Extract file path from input - try multiple possible field names
FILE_PATH=""

# Try file_path (Write tool)
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || echo "")
fi

# Try path (some Edit variations)
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || echo "")
fi

# Try file (another variation)
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || echo "")
fi

debug_log "Extracted FILE_PATH: $FILE_PATH"

# If no file path, approve (not a file edit or unrecognized format)
if [[ -z "$FILE_PATH" ]]; then
  debug_log "No file path found - approving"
  echo '{"decision": "approve"}'
  exit 0
fi

# If no state file, approve (btsc not active)
if [[ ! -f "$STATE_FILE" ]]; then
  debug_log "No state file - approving"
  echo '{"decision": "approve"}'
  exit 0
fi

# STATE/CONFIG files - always approve
if [[ "$FILE_PATH" == .claude/* ]] || [[ "$FILE_PATH" == */.claude/* ]]; then
  debug_log "State/config file - approving"
  echo '{"decision": "approve"}'
  exit 0
fi

# TEST file patterns
TEST_PATTERNS=(
  # Extension-based (dot separator)
  '\.test\.'           # file.test.ts, file.test.js
  '\.spec\.'           # file.spec.ts, file.spec.js
  
  # Extension-based (underscore separator)
  '_test\.'            # file_test.go, file_test.py
  '_spec\.'            # file_spec.rb
  
  # Prefix
  '/test_'             # test_file.py (in any directory)
  '^test_'             # test_file.py (at root)
  
  # Suffix (PascalCase conventions) - require character before suffix
  '[A-Za-z0-9]Test\.[^/]+$'    # UserTest.java, FileTest.kt (not Test.ts)
  '[A-Za-z0-9]Tests\.[^/]+$'   # UserTests.java, FileTests.cs (not Tests.ts)
  '[A-Za-z0-9]Spec\.[^/]+$'    # UserSpec.scala (not Spec.scala)
  
  # Directory-based
  '__tests__/'         # Jest/React
  '/tests/'            # tests/ (plural)
  '/test/'             # test/ (singular)
  '/spec/'             # RSpec
  '/specs/'            # specs/ (plural)
  
  # E2E/Integration
  '/e2e/'              # e2e tests
  '/cypress/'          # Cypress
  '/playwright/'       # Playwright
)

# Check if file matches test patterns
for pattern in "${TEST_PATTERNS[@]}"; do
  # Skip comment lines
  [[ "$pattern" =~ ^# ]] && continue
  if echo "$FILE_PATH" | grep -qE "$pattern" 2>/dev/null; then
    debug_log "Matched test pattern: $pattern - approving"
    echo '{"decision": "approve"}'
    exit 0
  fi
done

# Parse state file safely
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")

# Check custom test patterns from state file
CUSTOM_PATTERNS=$(echo "$FRONTMATTER" | grep '^test_patterns:' | sed 's/test_patterns: *//' | tr -d '[]"' | tr ',' '\n' || echo "")

for pattern in $CUSTOM_PATTERNS; do
  pattern=$(echo "$pattern" | xargs 2>/dev/null || echo "")  # trim whitespace
  if [[ -n "$pattern" ]] && echo "$FILE_PATH" | grep -qE "$pattern" 2>/dev/null; then
    debug_log "Matched custom pattern: $pattern - approving"
    echo '{"decision": "approve"}'
    exit 0
  fi
done

# It's an implementation file - check substate
SUBSTATE=$(echo "$FRONTMATTER" | grep '^substate:' | sed 's/substate: *//' || echo "RED")
SUBSTATE=${SUBSTATE:-RED}  # Default to RED if empty

debug_log "Implementation file, substate: $SUBSTATE"

if [[ "$SUBSTATE" == "RED" ]]; then
  debug_log "RED phase - denying implementation edit"
  echo '{"decision": "deny", "reason": "btsc: Cannot edit implementation during RED phase. Write and validate tests first, then transition to GREEN."}'
  exit 0
fi

# GREEN or REFACTOR - approve implementation edits
debug_log "GREEN/REFACTOR phase - approving implementation edit"
echo '{"decision": "approve"}'
exit 0