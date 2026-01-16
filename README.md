# btsc - Big Tests, Small Code

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/bradgladdd/btsc)
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

### `/btsc:tdd [feature]`
Start a TDD session for a feature.

```
> /btsc:tdd user authentication
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
- **Stop**: Prevents stopping with incomplete cycles

## State File

Session state stored in `.claude/tdd.local.md`:

```yaml
---
feature: "user-authentication"
phase: EDGE
substate: GREEN
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

Install directly from the GitHub repository:

```
/plugin marketplace add bradgladdd/btsc
/plugin install btsc@btsc
```

### Verify Installation

After installation, run `/help` to see available commands. You should see:
- `/btsc:tdd` - Start a TDD session
- `/btsc:tdd-status` - Show session progress
- `/btsc:tdd-next` - Advance to next phase

## Quick Start

1. Start a session: `/btsc:tdd user login feature`
2. Write a failing test (RED phase)
3. Run `/btsc:tdd-next` to transition and implement
4. Refactor when tests pass
5. Repeat through all 5 phases
6. End with minimal, tested code

## Plugin Structure

```
btsc/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   ├── tdd.md                # Start TDD session
│   ├── tdd-next.md           # Advance phases
│   └── tdd-status.md         # Show progress
├── skills/
│   └── tdd-methodology/
│       ├── SKILL.md          # Core methodology
│       └── references/       # Detailed guides
├── agents/
│   ├── tdd-coach.md          # Implementation guidance
│   └── test-validator.md     # Test quality validation
├── hooks/
│   └── hooks.json            # TDD enforcement rules
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
