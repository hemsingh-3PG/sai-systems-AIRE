---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: QA - Regression Testing. Compare current test results against previous validation to detect regressions.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# QA - Regression Testing

## Agent

**QA** 

## Before Starting

1. Read `SPEC/agents/AIRE_QA.md`
2. Read `SPEC/rulebooks/aire-qa-rulebook.md`
3. **Check**: `docs/testing/` for any `validation-report-*.md` — if none found, **STOP**: Tell user to "Run `aire-qa-validate` first."
4. Read previous validation reports from `docs/testing/`

---

## Tell Me the Baseline

**IMPORTANT**: Always confirm which previous report to use as baseline.

Present these options:

```
Which previous validation report should I use as the regression baseline?

📋 AUTO-DETECT:
  1. "latest" - Use the most recent validation report in docs/testing/

📄 SPECIFIC REPORT:
  2. "report [filename]" - Use a specific report (e.g., "report validation-report-full-2024-01-15.md")

Type your choice:
```

After selecting baseline:
- **Baseline report**: `docs/testing/[chosen report]`
- **Output file**: `docs/testing/regression-report-[YYYY-MM-DD].md`

---

## Execution Steps:

### Phase 1: Baseline Comparison Setup
- [ ] Read the chosen baseline validation report
- [ ] Note previous test totals: passed / failed / skipped / coverage %
- [ ] Identify what has changed since baseline (read git log or ask user)
- [ ] Note any new tests added

### Phase 2: Full Test Suite Execution
- [ ] Run complete test suite — capture all output
- [ ] Generate coverage reports
- [ ] Capture logs

### Phase 3: Results Analysis
- [ ] Compare pass/fail counts vs baseline
- [ ] Identify any NEW failures (regressions)
- [ ] Identify previously failing tests that now pass (fixes)
- [ ] Identify flaky tests (intermittent failures)
- [ ] Check for coverage changes (increases or decreases)

---

### Phase 4: Issue Investigation
For each new failure:
- [ ] Determine if it's a genuine regression (was passing before)
- [ ] Identify probable root cause (relate to recent changes)
- [ ] Assign severity (🔴 Critical: BLOCKS / 🟠 High: should fix / 🟡 Medium: can release / 🟢 Low: safe)
- [ ] Document reproduction steps and evidence

### Phase 5: Generate Regression Report

**Output**: `docs/testing/regression-report-[YYYY-MM-DD].md`

---

## Regression Report Template

```
# Regression Test Report

**Date**: [YYYY-MM-DD]
**Build**: [Current] vs [Previous]
**Tested By**: QA Agent

---

## Summary

**Overall Status**: 🟢 NO REGRESSIONS / 🟡 MINOR REGRESSIONS / 🔴 MAJOR REGRESSIONS

**New Failures**: [X]
**Fixed Issues**: [Y]
**Flaky Tests**: [Z]

---

## Test Suite Comparison

| Category | Previous Build | Current Build | Change |
|----------|----------------|---------------|--------|
| Total Tests | 150 | 155 | +5 |
| Passed | 148 | 150 | +2 |
| Failed | 2 | 5 | +3 ⚠️ |
| Skipped | 0 | 0 | 0 |
| Coverage | 87% | 88% | +1% |

---

## New Failures (Regressions)

| Test ID | Test Name | Category | Previous | Current | Severity | Investigation |
|---------|-----------|----------|----------|---------|----------|---------------|
| TC-045 | User login flow | Integration | ✅ Pass | ❌ Fail | 🔴 Critical | REG-001 |
| TC-089 | Search pagination | Unit | ✅ Pass | ❌ Fail | 🟡 Medium | REG-002 |

---

## Regression Details

### REG-001: User login flow failure
**Test**: TC-045
**Severity**: 🔴 Critical
**Root Cause**: [Analysis of why this broke]
**Related Changes**: [Commits/PRs that may have caused this]
**Reproduction**: [Steps to reproduce]
**Evidence**: [Logs, screenshots]

### REG-002: Search pagination failure
**Test**: TC-089
**Severity**: 🟡 Medium
**Root Cause**: [Analysis]
**Related Changes**: [Commits/PRs]
**Reproduction**: [Steps]
**Evidence**: [Logs]

---

## Fixed Issues

| Test ID | Test Name | Previous | Current | Notes |
|---------|-----------|----------|---------|-------|
| TC-012 | Email validation | ❌ Fail | ✅ Pass | Fixed by PR-123 |

---

## Flaky Tests

| Test ID | Test Name | Pass Rate | Recommendation |
|---------|-----------|-----------|----------------|
| TC-067 | Async API call | 60% | Investigate timing issues |

---

## Coverage Changes

**New Code Coverage**: 88% (+1% from previous)

**Areas with Improved Coverage**:
- Module A: 75% → 85%
- Module B: 90% → 92%

**Areas with Decreased Coverage**:
- Module C: 88% → 82% ⚠️ (investigate)

---

## Recommendations

1. 🔴 **BLOCK RELEASE**: Fix REG-001 (critical login failure)
2. 🟡 Fix or document REG-002 before release
3. Investigate flaky test TC-067
4. Improve coverage in Module C

---

## Evidence
[Links to test runs, logs, coverage reports]
```

---

## Test Review

**Trigger**: `aire-qa-test-review` or `review tests`

**Prerequisites**:
1. Read test files
2. Read test plan
3. Review `SPEC/rulebooks/aire-qa-rulebook.md`

**Output**: `docs/testing/test-review-[YYYY-MM-DD].md`

**Execution Steps**:

### 1. Test Quality Assessment
- [ ] Tests follow existing patterns
- [ ] Tests are independent and isolated
- [ ] Tests have clear naming
- [ ] Tests have proper setup/teardown
- [ ] Tests assert on meaningful outcomes
- [ ] Tests are maintainable

### 2. Coverage Analysis
- [ ] All requirements covered
- [ ] All edge cases covered
- [ ] All error scenarios covered
- [ ] All integration points covered

### 3. Test Data Review
- [ ] Test data is realistic
- [ ] Test data covers edge cases
- [ ] Test data is properly managed

### 4. Recommendations
- List improvements needed
- Identify missing test scenarios
- Suggest refactoring opportunities

---

## Output

**Location**: `docs/testing/regression-report-[YYYY-MM-DD].md`

---

## Rules

- 🔴 ALWAYS load and read the baseline validation report before running tests
- 🔴 ACTUALLY run the full test suite — never assume results
- 🔴 Every new failure must be classified as regression or expected change
- 🔴 Capture evidence (logs, coverage diff) for every regression
- 🔴 Critical regressions = release blocked, no exceptions
- 🔴 Write ONLY to `docs/testing/`
- 🔴 Output file name MUST include the date

---

## After Regression — Mandatory Next-Step Output (DO NOT IMPROVISE)

After writing the regression report, the ONLY message you present is the block below. Do NOT invent alternative paths or self-assign fixes.

```
📋 Regression complete — <regression report path>
   [P] tests passing | [R] regressions | [F] new failures

▶️ Next step:

1️⃣  **aire-qa-triage**        ← recommended if any regressions or new failures were found
2️⃣  **done**                  ← zero regressions / failures — release path clear

Type your choice (1 / 2).
```

---

**Tell me which baseline report to use (latest / report [filename]), then type "proceed".**

