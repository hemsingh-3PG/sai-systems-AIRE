---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: QA - Validate Implementation. Run validation against test plan for full implementation, specific epic, or specific story.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# QA - Validate Implementation



## Agent

**QA** 

## Before Starting

1. Read `SPEC/agents/AIRE_QA.md`
2. Read `SPEC/rulebooks/aire-qa-rulebook.md`
3. Read `docs/requirements.md`

---

## Tell Me the Scope

**IMPORTANT**: Always ask the user to choose the scope before proceeding.

Present these options:

```
What scope should be validated?

📋 FULL IMPLEMENTATION:
  1. "full" - Validate entire implementation (uses test-plan-full.md)

📦 EPIC-LEVEL:
  2. "epic [N]" - Validate a specific epic (uses test-plan-epic-[N].md)

📝 STORY-LEVEL:
  3. "story [N.M]" - Validate a specific story (uses test-plan-story-[N.M].md)

Type your choice:
```

Based on the user's choice, set:
- **Scope**: `full` | `epic-[N]` | `story-[N.M]`
- **Input test plan**:
  - full → `docs/testing/test-plan-full.md`
  - epic → `docs/testing/test-plan-epic-[N].md`
  - story → `docs/testing/test-plan-story-[N.M].md`
- **Output file**:
  - full → `docs/testing/validation-report-full-[YYYY-MM-DD].md`
  - epic → `docs/testing/validation-report-epic-[N]-[YYYY-MM-DD].md`
  - story → `docs/testing/validation-report-story-[N.M]-[YYYY-MM-DD].md`

**If the corresponding test plan does not exist**, inform the user:
```
⚠️ No test plan found for [scope].
Run aire-qa-test-plan first to create: docs/testing/test-plan-[scope].md

Would you like to:
1. Create the test plan first (run aire-qa-test-plan)
2. Proceed without a test plan (not recommended)
```

---

## Execution Steps:

### Phase 1: Pre-Validation Checks
- [ ] Read the input test plan for chosen scope
- [ ] Read `docs/requirements.md` — identify requirements in scope
- [ ] Confirm all implementation steps are complete for the scope
- [ ] Identify test commands/scripts to run
- [ ] Confirm code is committed

### Phase 2: Test Execution
- [ ] Run unit tests — capture full output
- [ ] Run integration tests — capture full output
- [ ] Run E2E tests (if applicable) — capture full output
- [ ] Generate coverage reports
- [ ] Capture logs as evidence

### Phase 3: Requirements Verification
- [ ] For each requirement in scope: verify at least one passing test
- [ ] Document evidence per requirement
- [ ] Identify any gaps in coverage

### Phase 4: Quality Gate Verification
- [ ] Unit test coverage ≥85%
- [ ] All integration tests passing (100%)
- [ ] 0 critical bugs open
- [ ] 0 high bugs open
- [ ] Security scan passed (if applicable)
- [ ] Performance benchmarks met (if applicable)

### Phase 5: Functional Testing
- [ ] Happy path scenarios from test plan
- [ ] Edge cases from test plan
- [ ] Error handling scenarios
- [ ] Integration points

### Phase 6: Non-Functional Testing (if applicable)
- [ ] Performance testing
- [ ] Security testing
- [ ] Accessibility testing
- [ ] Browser compatibility

---

### Phase 7: Issue Identification
- [ ] Document bugs found with severity (🔴 Critical: BLOCKS / 🟠 High: BLOCKS / 🟡 Medium: can release / 🟢 Low: safe)
- [ ] Write reproduction steps
- [ ] Attach evidence (logs, screenshots)

### Phase 8: Generate Validation Report

**Output file path** (determined by scope chosen above):
- `docs/testing/validation-report-full-[YYYY-MM-DD].md`
- `docs/testing/validation-report-epic-[N]-[YYYY-MM-DD].md`
- `docs/testing/validation-report-story-[N.M]-[YYYY-MM-DD].md`

### Phase 9: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `QA`
  - **Progress Summary** → Set "QA" row to `✅ Done` (if full validation passed) or `🟡 In Progress` (if partial/failed)
  - **Current Step Details** → Document validation scope, overall result (PASS/PARTIAL/FAIL), and output file path
  - **Completed Steps** → Add validation report with evidence: `docs/testing/validation-report-[scope]-[YYYY-MM-DD].md`
  - **Agent Activity** → Update QA: last action = "Validation complete ([scope])", status = Idle

Report to user:
```
✅ docs/status.md updated
   Step: QA → [status]
   Validation: [PASS/PARTIAL/FAIL]
```

---

## Validation Report Template

```
# Validation Report - [Scope: Full / Epic N / Story N.M]

**Date**: [YYYY-MM-DD]
**Tested By**: QA Agent
**Scope**: [Full implementation / Epic N: <name> / Story N.M: <name>]
**Test Plan Used**: [path to test plan]
**Environment**: [Dev/Staging/Production]

---

## Executive Summary

**Overall Status**: 🔴 FAIL / 🟡 PARTIAL / 🟢 PASS

**Summary**: [2-3 sentence summary of validation results]

**Recommendation**:
- [ ] ✅ READY FOR RELEASE
- [ ] ⚠️ READY WITH MINOR ISSUES (documented below)
- [ ] ❌ NOT READY - CRITICAL ISSUES MUST BE FIXED
- [ ] 🚫 BLOCKED - [Describe blocker]

---

## Requirements Coverage

| Requirement ID | Description | Test Status | Evidence | Notes |
|----------------|-------------|-------------|----------|-------|
| REQ-1 | [text] | ✅ Pass | [test output ref] | - |
| REQ-2 | [text] | ❌ Fail | [bug ref] | See BUG-001 |

**Coverage Summary**:
- Total Requirements: [X]
- Fully Covered: [Y]
- Partially Covered: [Z]
- Not Covered: [W]
- Coverage %: [Y/X * 100]%

---

## Test Execution Summary

### Unit Tests
- Total: [X] | Passed: [Y] ([Z]%) | Failed: [W] | Skipped: [V]
- Coverage: [XX]%
- Evidence: [test output]

### Integration Tests
- Total: [X] | Passed: [Y] ([Z]%) | Failed: [W] | Skipped: [V]
- Evidence: [test output]

### E2E Tests (if applicable)
- Total: [X] | Passed: [Y] ([Z]%) | Failed: [W] | Skipped: [V]
- Evidence: [test output]

---

## Quality Gate Status

| Quality Gate | Target | Actual | Status | Notes |
|--------------|--------|--------|--------|-------|
| Unit Test Coverage | ≥85% | [X]% | ✅/❌ | - |
| Integration Tests | 100% pass | [X]% | ✅/❌ | - |
| Critical Bugs | 0 | [N] | ✅/❌ | - |
| High Bugs | 0 | [N] | ✅/❌ | - |
| Security Scan | No critical | [result] | ✅/❌ | - |

**Overall Quality Gate**: ✅ PASSED / ❌ FAILED

---

## Functional Testing Results

### Happy Path Scenarios
- [x] ✅ Scenario 1: [Description] - PASS
- [ ] ❌ Scenario 2: [Description] - FAIL (BUG-001)

### Edge Cases
- [x] ✅ Edge case 1 - PASS
- [x] ⚠️ Edge case 2 - PARTIAL

### Error Handling
- [x] ✅ Invalid input handling - PASS
- [x] ✅ Network failure handling - PASS

### Integration Points
- [x] ✅ API integration - PASS
- [ ] ❌ Third-party service - FAIL (BUG-002)

---

## Issues Found

| ID | Severity | Category | Description | Reproduction Steps | Status |
|----|----------|----------|-------------|-------------------|--------|
| BUG-001 | 🔴 Critical | Functional | [Description] | [Steps] | Open |
| BUG-002 | 🟠 High | Integration | [Description] | [Steps] | Open |

---

## Test Evidence

### Test Logs
[Paste relevant test output]

### Coverage Reports
- Unit Test Coverage: [result]

---

## Recommendations

### Must Fix Before Release (Blockers)
1. [BUG-001: description]

### Should Fix Before Release
1. [BUG-002: description]

### Can Fix After Release
1. [Minor issues]

---

## Sign-Off

**AIREQA Agent**
**Date**: [Date]
**Status**: APPROVED / CONDITIONAL / REJECTED
**Notes**: [Additional comments]
```

---

## Output

**Location**: `docs/testing/`
- `validation-report-full-[YYYY-MM-DD].md`
- `validation-report-epic-[N]-[YYYY-MM-DD].md`
- `validation-report-story-[N.M]-[YYYY-MM-DD].md`

---

## Rules

- 🔴 ALWAYS read the corresponding test plan first
- 🔴 ACTUALLY run tests — never assume they pass
- 🔴 Capture evidence (logs, coverage output) for every gate
- 🔴 Every requirement must have documented test evidence
- 🔴 Critical bugs = release blocked, no exceptions
- 🔴 Write ONLY to `docs/testing/` and `docs/reviews/`
- 🔴 Output file name MUST reflect chosen scope and date

---

## After Validation — Mandatory Next-Step Output (DO NOT IMPROVISE)

After writing the validation report, the ONLY message you present is the block below. Do NOT invent alternative paths or self-assign fixes.

```
📋 Validation complete — <validation report path>
   [P] tests passing | [F] failures | [B] bugs found

▶️ Next step:

1️⃣  **aire-qa-regression**   ← recommended next — confirm nothing else broke
2️⃣  **aire-qa-triage**        ← run if failures/bugs were found, to classify and prioritize

Type your choice (1 / 2).
```

If zero failures and zero bugs, present option 1 as "recommended" and dim options 2 & 3.

---

**Tell me the scope (full / epic N / story N.M), then type "proceed".**