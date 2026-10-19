---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: QA - Create Test Plan. Plan tests for full implementation, specific epic, or specific story.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# QA - Create Test Plan

## Agent

**QA** 

## Before Starting

1. Read `SPEC/agents/AIRE_QA.md`
2. Read `SPEC/rulebooks/aire-qa-rulebook.md`
3. **Check for source documents** — follow the Source Document Resolution below before asking for scope

---

## Source Document Resolution

**CRITICAL**: Before asking for scope, determine what source documents are available. Follow this order:

### Step 1 — Check for Implementation Plan & Stories

Check if `docs/plans/implementation-plan.md` exists.

**If YES**: Read it and proceed to [Tell Me the Scope](#tell-me-the-scope).
- For story scope: read individual story file from `docs/plans/stories/epic-[N]-story-[M]-*.md`
- For epic scope: read all story files under `docs/plans/stories/` matching `epic-[N]-*`
- For full scope: read `implementation-plan.md` in full

**If NO**: Go to Step 2.

---

### Step 2 — No Implementation Plan Found

Detect project type from existing docs (check in this order — `current/` is brownfield-only, but `design/` is populated for both project types):
- `docs/architecture/current/` exists (has `00-system-overview.md` or any `01-*-deep-dive.md`) → Brownfield project → suggest `aire-brownfield-plan`
- Otherwise, `docs/architecture/design/00-system-architecture-greenfield.md` exists → Greenfield project → suggest `aire-greenfield-plan`
- Neither found → suggest both

Present to the user:

```
⚠️ No implementation plan found.

A planning workflow must be run before QA test planning.

📋 OPTION A — Run the planning workflow first:
  [Greenfield] aire-greenfield-plan  → then return and run aire-qa-test-plan
  [Brownfield] aire-brownfield-plan  → then return and run aire-qa-test-plan

📝 OPTION B — Provide stories directly:
  Paste, describe, or refer to an external file with the stories/requirements
  you want the test plan to cover.

Type your choice (A/B):
```

- If user chooses `A`: **STOP** — do not proceed. Wait for user to run the plan workflow.
- If user chooses `B`: accept user input as source and proceed to scope selection

---

## Tell Me the Scope

**IMPORTANT**: Ask the user to choose scope after source documents are resolved.

Present these options:

```
What scope should the test plan cover?

📋 FULL IMPLEMENTATION:
  1. "full" - Test plan for entire implementation (all epics & stories)

📦 EPIC-LEVEL:
  2. "epic [N]" - Test plan for a specific epic (e.g., "epic 1")

📝 STORY-LEVEL:
  3. "story [N.M]" - Test plan for a specific story (e.g., "story 1.2")

⏭️  "skip" - I'll tell you later

Type your choice:
```

Based on the user's choice, set:
- **Scope**: `full` | `epic-[N]` | `story-[N.M]`
- **Output file**:
  - full → `docs/testing/test-plan-full.md`
  - epic → `docs/testing/test-plan-epic-[N].md`
  - story → `docs/testing/test-plan-story-[N.M].md`

---

## Execution Steps:

### Phase 1: Requirements Analysis
- [ ] Load source documents resolved above (implementation plan / architecture docs / user-provided stories)
- [ ] For story scope: read `docs/plans/stories/epic-[N]-story-[M]-*.md` if available
- [ ] For epic scope: read all story files under `docs/plans/stories/` matching `epic-[N]-*`
- [ ] Extract all testable requirements and acceptance criteria for the chosen scope
- [ ] Map requirements to test categories (unit / integration / E2E)

### Phase 2: Test Scenario Design
- [ ] Happy path scenarios
- [ ] Edge cases and boundary conditions
- [ ] Error scenarios and exception handling
- [ ] Integration scenarios
- [ ] Performance scenarios (if applicable)

### Phase 3: Test Data Planning
- [ ] Valid test data sets
- [ ] Invalid/malicious data sets
- [ ] Edge case data
- [ ] Test environment setup notes

### Phase 4: Coverage Goals
- [ ] Unit test coverage target (default: ≥85%)
- [ ] Integration test coverage
- [ ] E2E test coverage (if applicable)

### Phase 5: Generate Test Plan Document

**Output file path** (determined by scope chosen above):
- `docs/testing/test-plan-full.md`
- `docs/testing/test-plan-epic-[N].md`
- `docs/testing/test-plan-story-[N.M].md`
- Suggest next workflow to be 'QA-validate'

### Phase 6: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `QA`
  - **Progress Summary** → Set "QA" row to `🟡 In Progress`
  - **Current Step Details** → Document test plan scope (full/epic/story) and output file path
  - **Upcoming** → `aire-qa-validate` to execute the test plan
  - **Agent Activity** → Update QA: last action = "Test plan created ([scope])", status = Active

Report to user:
```
✅ docs/status.md updated
   Step: QA → 🟡 In Progress (test plan created)
   Next: Run aire-qa-validate
```

---

## Test Plan Template

```
# Test Plan - [Scope: Full / Epic N / Story N.M]

## Scope
**Coverage**: [Full implementation / Epic N: <name> / Story N.M: <name>]
**In Scope**: [What will be tested]
**Out of Scope**: [What won't be tested]

## Requirements Traceability
| Requirement ID | Description | Test Scenarios |
|----------------|-------------|----------------|
| REQ-1 | [Description] | TC-001, TC-002 |

## Test Categories

### Unit Tests
- [List of unit test areas]

### Integration Tests
- [List of integration scenarios]

### E2E Tests (if applicable)
- [List of end-to-end flows]

## Test Scenarios
| ID | Category | Scenario | Expected Result | Priority |
|----|----------|----------|-----------------|----------|
| TC-001 | Unit | [Description] | [Expected] | High |

## Test Data Requirements
- [Data set 1: Description]
- [Data set 2: Description]

## Environment Requirements
- [Environment 1: Configuration]
- [Environment 2: Configuration]

## Quality Gates
- Unit test coverage: ≥85%
- Integration tests: 100% passing
- No critical/high severity bugs
- [Custom gates from requirements]

## Schedule
- Test planning: [Date]
- Test implementation: [Date]
- Test execution: [Date]
- Results reporting: [Date]
```

---

## Output

**Location**: `docs/testing/test-plan-[scope].md`
- `test-plan-full.md` for full scope
- `test-plan-epic-[N].md` for epic scope
- `test-plan-story-[N.M].md` for story scope

---

## Rules

- 🔴 Always read requirements BEFORE writing test plan
- 🔴 Every requirement must map to at least one test scenario
- 🔴 Test plan must list quality gates explicitly
- 🔴 Write ONLY to `docs/testing/`
- 🔴 Output file name MUST reflect chosen scope

---

**Tell me the scope (full / epic N / story N.M), then type "proceed".**

---

## After Test Plan — Mandatory Next-Step Output (DO NOT IMPROVISE)

After writing the test plan, the ONLY message you present is the block below.

```
📋 Test plan complete — <test plan path>

▶️ Next step:

1️⃣  **aire-qa-validate**     ← recommended — execute the plan and produce a validation report

Type your choice (1).
```