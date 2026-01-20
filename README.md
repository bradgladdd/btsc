# btsc - Big Tests, Small Code

[![Version](https://img.shields.io/badge/version-0.3.5-blue.svg)](https://github.com/bradgladdd/btsc)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-1.0.33+-purple.svg)](https://claude.ai/code)

A rigorous 5-phase TDD plugin for Claude Code that builds behavioral contracts through comprehensive testing, enabling aggressive code simplification.

## Philosophy

**Tests define the contract. Code fulfills it.**

btsc enforces strict test-driven development discipline:
- Write tests FIRST, always
- Build tests incrementally through 5 phases
- End goal: minimal code that passes comprehensive tests

## The 5 Phases

| Phase | Focus | Tests Guarantee |
|-------|-------|-----------------|
| **CORE** | Happy path, basic functionality | Feature works for standard inputs |
| **EDGE** | Boundaries, edge cases, errors | Feature handles unexpected inputs |
| **SECURITY** | Input validation, auth, injection | Feature is secure |
| **PERFORMANCE** | Timing, resources, scale | Feature performs acceptably |
| **SIMPLICITY** | Refactor implementation | Code is minimal |

Each phase follows the **RED → GREEN → REFACTOR** cycle.

## Commands

### `/btsc:tdd-loop <feature> [--max-iterations N]`
Start an autonomous TDD session where Claude writes ALL code.

```bash
# Basic usage - Claude writes tests and implementation
/btsc:tdd-loop user authentication

# With iteration limit (recommended)
/btsc:tdd-loop user authentication --max-iterations 50

# Complex feature with higher limit
/btsc:tdd-loop shopping cart with add remove checkout --max-iterations 30
```

### `/btsc:tdd-status`
Show current session progress.

```
> /btsc:tdd-status
```

### `/btsc:tdd-next`
Advance to next phase/sub-state. When tests fail, Claude implements code to make them pass.

```
> /btsc:tdd-next
```

### `/btsc:cancel-loop`
Cancel an active TDD session (preserves state for manual continuation with `/btsc:tdd-next`).

```
> /btsc:cancel-loop
```

## Agents

### tdd-coach
Provides directive guidance on what to implement next. Activated:
- After phase transitions
- When stuck on failing tests
- On explicit request

### test-validator
Validates tests meet quality criteria. Ensures tests:
- Verify behavior, not implementation
- Have meaningful assertions
- Are implementation-agnostic
- Match current phase focus

## Enforcement

btsc enforces TDD discipline through hooks:

- **PreToolUse**: Blocks implementation edits during RED phase
- **PostToolUse**: Tracks test execution and results
- **Stop**: Prevents stopping with incomplete cycles, feeds task back until complete

## How It Works

btsc enables autonomous TDD development inspired by the [Ralph Wiggum technique](https://ghuntley.com/ralph/).

1. Start with `/btsc:tdd-loop <feature>`
2. Claude works through RED → GREEN → REFACTOR
3. When Claude tries to stop, the loop feeds the task back
4. Claude sees previous work in files and continues iterating
5. Loop ends ONLY when SIMPLICITY phase completes with all tests passing

### Completion Rules

The loop ends when ALL of these are true:
1. You are in **SIMPLICITY** phase (all other phases complete)
2. All tests are passing
3. You output `<promise>TDD_COMPLETE</promise>`

**The promise is IGNORED if not in SIMPLICITY phase.** This ensures your feature is fully implemented AND all TDD phases are complete.

### CORE Phase Priority

**Your feature MUST be implemented and working before moving to EDGE phase.**

The loop prioritizes completing CORE first:
- CORE tests written and failing (RED)
- Implementation passes all CORE tests (GREEN)
- Code refactored (REFACTOR)
- Only THEN move to EDGE, SECURITY, PERFORMANCE, SIMPLICITY

### Safety Controls

- `--max-iterations N` - Stop after N iterations to prevent runaway loops
- `/btsc:cancel-loop` - Manually cancel the loop at any time
- `<promise>TDD_COMPLETE</promise>` - Signal completion (only works in SIMPLICITY phase)

### When to Use btsc

**Good for:**
- Well-defined features with clear requirements
- Greenfield projects where you can walk away
- Tasks with automatic verification (tests passing)

**Not good for:**
- Tasks requiring human judgment or design decisions
- Unclear requirements needing clarification
- Production debugging

## State File

Session state stored in `.claude/tdd.local.md`:

```yaml
---
feature: "user-authentication"
phase: EDGE
substate: GREEN
loop_active: true
iteration: 5                   # current loop iteration
max_iterations: 50             # 0 = unlimited
test_files:
  - src/auth.test.ts
---
```

## Installation

### Prerequisites

- Claude Code 1.0.33 or later
- A project with a supported test framework

### Option 1: Direct Testing (Development)

For testing during development, load the plugin directly:

```bash
claude --plugin-dir /path/to/btsc
```

### Option 2: Install from Local Marketplace

Set up a local marketplace to manage this and other plugins:

**1. Create marketplace structure:**

```bash
mkdir -p ~/claude-plugins/.claude-plugin
```

**2. Create marketplace catalog** (`~/claude-plugins/.claude-plugin/marketplace.json`):

```json
{
  "name": "local-plugins",
  "owner": {
    "name": "Your Name"
  },
  "plugins": [
    {
      "name": "btsc",
      "source": "/path/to/btsc",
      "description": "Big Tests, Small Code - 5-phase TDD protocol"
    }
  ]
}
```

**3. Add marketplace and install:**

```
/plugin marketplace add ~/claude-plugins
/plugin install btsc@local-plugins
```

### Option 3: Install from GitHub

Install from the GitHub marketplace:

```
/plugin marketplace add bradgladdd/claude-plugins
/plugin install btsc@bradgladdd
```

### Verify Installation

After installation, run `/help` to see available commands. You should see:
- `/btsc:tdd-loop` - Start autonomous TDD session
- `/btsc:tdd-status` - Show session progress
- `/btsc:tdd-next` - Advance to next phase
- `/btsc:cancel-loop` - Cancel active loop

## Quick Start

```bash
/btsc:tdd-loop user login feature --max-iterations 50
```

1. Claude writes tests automatically (RED phase)
2. Claude writes implementation automatically (GREEN phase)
3. Claude refactors while keeping tests green (REFACTOR phase)
4. Loop continues through all 5 phases until complete
5. Cancel anytime with `/btsc:cancel-loop`

## Sample Projects

These projects demonstrate btsc's autonomous TDD capabilities across different complexity levels.

### Calculator (Simple)

A basic arithmetic module with 4 operations.

**Required Functions:**
- `add(a, b)`, `subtract(a, b)`, `multiply(a, b)`, `divide(a, b)`

| Metric | Result |
|--------|--------|
| Functions | 4 |
| Tests | 22 |
| Implementation | 31 lines |

**What btsc produced:**
- Shared `validateNumbers()` helper extracted during SIMPLICITY
- Input validation for non-numeric types (strings, null, objects)
- Division by zero handling
- EDGE phase caught JS floating point behavior (`0.1 + 0.2 = 0.30000000000000004`)
- Performance test: 100K operations timing benchmark

```bash
/btsc:tdd-loop calculator module per FEATURE.md --max-iterations 20
```

### Shopping Cart (Medium)

E-commerce cart with item management, pricing calculations, and discount support.

**Required Functions:**
- Cart: `createCart`, `addItem`, `removeItem`, `updateQuantity`, `clearCart`, `getItem`
- Pricing: `getSubtotal`, `applyDiscount`, `getTotal`, `getTax`
- Info: `getItemCount`, `isEmpty`, `getItems`

| Metric | Result |
|--------|--------|
| Functions | 13 |
| Tests | 56 |
| Implementation | 151 lines |
| Code Reduction | 21% in SIMPLICITY |

**What btsc produced:**
- Uses `Map` for O(1) item operations
- Prices in cents (avoids floating point issues)
- Validates IDs, prices, quantities, discounts, tax rates
- Handles edge cases: duplicate items increase quantity, discount can't exceed subtotal
- Performance tested with 10K items

```bash
/btsc:tdd-loop shopping cart module per FEATURE.md --max-iterations 30
```

### Conway's Game of Life (Complex)

Cellular automaton implementing the classic rules: cells with 2-3 neighbors survive, dead cells with exactly 3 neighbors become alive.

**Required Functions:**
- Grid: `createGrid`, `getCell`, `setCell`, `clearGrid`, `getWidth`, `getHeight`
- Simulation: `countNeighbors`, `nextGeneration`, `runGenerations`
- Patterns: `setPattern`, `getPattern` (block, blinker, glider, beacon, toad)
- Serialization: `toString`, `fromString`
- Analysis: `countLiveCells`, `isEmpty`, `equals`

| Metric | Result |
|--------|--------|
| Functions | 17 |
| Tests | 136 |
| Implementation | 268 lines |
| Test Suites | 8 |

**What btsc produced:**
- All 17 functions across 5 categories
- Optimized `nextGeneration()` with direct array access
- 5 classic patterns with correct definitions
- Non-wrapping boundary behavior
- Bonus: Terminal viewer component with real-time animation

```bash
/btsc:tdd-loop Conway Game of Life per FEATURE.md --max-iterations 40
```

### What to Expect

- **Autonomous execution**: Claude writes ALL tests and implementation code
- **Phase progression**: CORE → EDGE → SECURITY → PERFORMANCE → SIMPLICITY
- **Code reduction**: SIMPLICITY phase actively reduces implementation size
- **Comprehensive coverage**: Security validation, edge cases, performance benchmarks

## Plugin Structure

```
btsc/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   ├── tdd-loop.md           # Autonomous TDD session
│   ├── tdd-next.md           # Advance phases
│   ├── tdd-status.md         # Show progress
│   └── cancel-loop.md        # Cancel active loop
├── scripts/
│   └── setup-tdd-loop.sh     # Loop initialization
├── skills/
│   └── tdd-methodology/
│       ├── SKILL.md          # Core methodology
│       └── references/       # Detailed guides
├── agents/
│   ├── tdd-coach.md          # Implementation guidance
│   └── test-validator.md     # Test quality validation
├── hooks/
│   ├── hooks.json            # TDD enforcement rules
│   └── stop-hook.sh          # Loop continuation logic
└── README.md
```

## Framework Support

btsc is framework-agnostic and works with:
- JavaScript/TypeScript (Jest, Vitest, Mocha)
- Python (pytest, unittest)
- Go (go test)
- Rust (cargo test)
- Java/Kotlin (JUnit, Gradle)
- Ruby (RSpec)
- .NET (dotnet test)

## Disclaimer

This plugin is provided "as is" without warranty of any kind, express or implied. Use at your own risk. The authors are not responsible for any issues, damages, or losses that may occur resulting from the use of this plugin. No warranties or guarantees are being made regarding its functionality, reliability, or fitness for any particular purpose.
