#!/bin/bash
set -euo pipefail

# btsc PreToolUse Hook - TDD Enforcement
# Blocks implementation edits during RED phase

HOOK_INPUT=$(cat)
STATE_FILE=".claude/tdd.local.md"

# Extract file path from input
FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

# If no file path, approve (not a file edit)
if [[ -z "$FILE_PATH" ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# If no state file, approve (btsc not active)
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# STATE/CONFIG files - always approve
if [[ "$FILE_PATH" == .claude/* ]] || [[ "$FILE_PATH" == */.claude/* ]]; then
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
  
  # Suffix (PascalCase conventions)
  'Test\.[^/]+$'       # FileTest.java, FileTest.kt
  'Tests\.[^/]+$'      # FileTests.java, FileTests.cs
  'Spec\.[^/]+$'       # FileSpec.scala
  
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
  if echo "$FILE_PATH" | grep -qE "$pattern"; then
    echo '{"decision": "approve"}'
    exit 0
  fi
done

# Check custom test patterns from state file
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
CUSTOM_PATTERNS=$(echo "$FRONTMATTER" | grep '^test_patterns:' | sed 's/test_patterns: *//' | tr -d '[]"' | tr ',' '\n')

for pattern in $CUSTOM_PATTERNS; do
  pattern=$(echo "$pattern" | xargs)  # trim whitespace
  if [[ -n "$pattern" ]] && echo "$FILE_PATH" | grep -qE "$pattern"; then
    echo '{"decision": "approve"}'
    exit 0
  fi
done

# It's an implementation file - check substate
SUBSTATE=$(echo "$FRONTMATTER" | grep '^substate:' | sed 's/substate: *//' || echo "RED")

if [[ "$SUBSTATE" == "RED" ]]; then
  echo '{"decision": "deny", "reason": "btsc: Cannot edit implementation during RED phase. Write and validate tests first, then transition to GREEN."}'
  exit 0
fi

# GREEN or REFACTOR - approve implementation edits
echo '{"decision": "approve"}'
exit 0