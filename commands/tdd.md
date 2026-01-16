---
description: Start a btsc TDD session for a feature
argument-hint: [feature-description or user-story]
allowed-tools: Read, Write, Grep, Glob, Bash, Task
---

Initialize a btsc (Big Tests, Small Code) TDD session.

## Session Initialization Process

### Step 1: Identify the Feature

Analyze the context to determine what feature is being developed:
- If $ARGUMENTS provided, use it as the feature description
- If no arguments, examine recent conversation context for feature details
- If a user story file is referenced, read and extract the feature

### Step 2: Check for Existing Session

Read .claude/tdd.local.md to check if a session already exists:
- If exists for SAME feature: Resume that session, report current state
- If exists for DIFFERENT feature: Ask user if they want to save current session and start new one
- If no session exists: Proceed to create new session

### Step 3: Create Session State

Create .claude/tdd.local.md with initial state:

```yaml
---
feature: "[extracted feature name]"
phase: CORE
substate: RED
test_files: []
test_patterns: []
---

## Session Log

- Session started: [timestamp]
- Feature: [description]
```

### Step 4: Analyze the Feature

Before writing tests:
1. Identify the core behavior that needs to be implemented
2. List the primary happy-path scenarios (for CORE phase)
3. Identify what files/modules will be involved

### Step 5: Begin RED Phase

Provide directives for the first test:
1. Identify the first behavior to test
2. Suggest test file location and name
3. Provide guidance on what the first test should verify
4. Remind: This test MUST fail initially (we haven't implemented anything)

### Step 6: Report Session Status

Output a summary:

```
## btsc Session Started

**Feature:** [feature name]
**Phase:** CORE (1/5)
**Substate:** RED

### First Directive
Write a failing test that verifies: [specific behavior]

Suggested test file: [path]

### Phase Overview
CORE phase focuses on happy-path, basic functionality.
Write tests for standard inputs and expected outputs only.
Edge cases, security, and performance come in later phases.
```

## Critical Rules

- Always start at CORE phase
- Always start in RED substate
- First action must be writing a failing test
- Do NOT write any implementation code until tests are validated
- Load the tdd-methodology skill for detailed phase guidance
