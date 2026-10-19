---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Reviewer - Code Review. Review code for quality and patterns.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---
 
# Reviewer - Code Review

> 🔴 **REVIEW-ONLY WORKFLOW.** The REVIEWER agent MUST NOT edit source code, tests, configs, or anything outside `docs/reviews/` and `docs/status.md`. Findings are produced as a report; fixes are performed by DEV via `aire-dev-remediate`. If issues are found, this workflow MUST recommend `aire-dev-remediate` as the next step.

## Agent

**REVIEWER** 

## Before Starting

1. Read `SPEC/agents/AIRE_REVIEWER.md`
2. Read `SPEC/rulebooks/aire-review-rulebook.md`
3. **Check**: `docs/plans/implementation-plan.md` — if missing, **STOP**: Tell user to "Run `aire-greenfield-plan` or `aire-brownfield-plan` first."
4. Read pattern docs from `docs/architecture/`

---

## Tell Me What to Review

**DO NOT guess or assume which story to review. Present this prompt to the user and wait for their response:**

```text
What would you like me to review? 

Please specify the target story:
- example "review story 1.2"
```

---

## Execution Steps:

#### Phase 0: Review History Check (CRITICAL - Prevents Endless Loops)

**Before starting any review, ALWAYS check**:

1. **Check for Previous Review**
   - [ ] Does `docs/reviews/story-[N.M]-code-review*.md` exist?
   - [ ] If yes, read the LATEST version
   - [ ] Note previous status: APPROVED / CHANGES_REQUESTED
   - [ ] Note previous issues found

2. **Determine Review Mode**
   - [ ] **If NO previous review** → INITIAL_REVIEW mode (full review, all severities)
   - [ ] **If previous APPROVED + code UNCHANGED** → SKIP review, respond: "✅ Story already approved. Code unchanged since last review."
   - [ ] **If previous APPROVED + code CHANGED** → NEW_CHANGES mode (review only changed files, Blocker + High only)
   - [ ] **If previous CHANGES_REQUESTED** → FIX_VERIFICATION mode (verify fixes applied + new Blocker/High only)

3. **Check Code Changes** (for re-reviews)
   - [ ] Compare file timestamps with previous review date
   - [ ] OR ask user: "Has code changed since last review?"
   - [ ] If unchanged and approved → STOP, don't re-review

4. **Set Severity Threshold**
   - [ ] **INITIAL_REVIEW**: Report all severities (🔴 🟠 🟡 🟢)
   - [ ] **FIX_VERIFICATION**: Only Blocker (🔴) + High (🟠) + verification of previous issues
   - [ ] **NEW_CHANGES**: Only Blocker (🔴) + High (🟠) in changed files

**Review Mode Decision Tree**:
```
Previous review exists?
├─ NO → INITIAL_REVIEW (all severities)
└─ YES → Read previous review
    ├─ Status = APPROVED?
    │   ├─ Code changed? NO → SKIP (don't re-review)
    │   └─ Code changed? YES → NEW_CHANGES (Blocker+High in changed files)
    └─ Status = CHANGES_REQUESTED?
        └─ FIX_VERIFICATION (verify fixes + Blocker+High only)
```

#### Phase 1: Preparation

1. **Identify and Load Review Scope**
   - MANDATORY: Locate and read the exact story file specified by the user: docs/plans/stories/epic-N-story-N.M-*.md
   - [ ] Extract the Acceptance Criteria directly from the story file.
   - [ ] Identify which specific files/components were modified to implement this story.
   - [ ] Note the architecture patterns and context files listed in the story that must be applied.
   - [ ] Note explicitly what is IN scope and OUT of scope for this review.

2. **Read Context**
   - [ ] Review implementation plan step
   - [ ] Read error handling patterns from docs
   - [ ] Read logging patterns from docs
   - [ ] Read testing patterns from docs
   - [ ] Read naming conventions from docs

3. **Read the Code**
   - [ ] Open all files to review
   - [ ] Understand what the code does
   - [ ] Identify entry points
   - [ ] Trace through main flows

#### Phase 2: Review Checklist

4. **Correctness Review**
   - [ ] Code does what it's supposed to do
   - [ ] Logic is correct
   - [ ] Edge cases handled
   - [ ] Error conditions handled
   - [ ] No obvious bugs
   - [ ] No race conditions
   - [ ] No memory leaks

5. **Pattern Adherence Review**
   - [ ] Error handling follows documented pattern
   - [ ] Logging follows documented pattern
   - [ ] Naming conventions followed
   - [ ] File organization correct
   - [ ] Code style consistent
   - [ ] Function size reasonable (< 30 lines)
   - [ ] No magic numbers/strings

6. **Testing Review**
   - [ ] Unit tests exist
   - [ ] Unit tests are meaningful (not just coverage)
   - [ ] Integration tests exist (if applicable)
   - [ ] Tests cover happy path
   - [ ] Tests cover edge cases
   - [ ] Tests cover error scenarios
   - [ ] Test patterns followed
   - [ ] Test coverage meets threshold (≥85%)

7. **Documentation Review**
   - [ ] Code comments where needed
   - [ ] No commented-out code
   - [ ] Function/method docs complete
   - [ ] Complex logic explained
   - [ ] Self-review document exists
   - [ ] No TODO comments in production code

8. **Security Review**
   - [ ] No hardcoded secrets/credentials
   - [ ] No hardcoded API keys
   - [ ] Input validation present
   - [ ] Output encoding where needed
   - [ ] Authentication/authorization checked
   - [ ] No SQL injection vulnerabilities
   - [ ] No XSS vulnerabilities
   - [ ] Sensitive data properly handled
   - [ ] Logging doesn't expose sensitive data

9. **Performance Review** (if applicable)
   - [ ] No N+1 query issues
   - [ ] Appropriate caching
   - [ ] Large data sets handled efficiently
   - [ ] No unnecessary loops
   - [ ] No blocking operations in async code

10. **SOLID Principles Review** 🔴 MANDATORY
    - [ ] **S - Single Responsibility**: Each class/module has ONE job only
    - [ ] **S**: No "god classes" doing everything
    - [ ] **S**: Functions < 30 lines, classes < 300 lines, files < 400 lines
    - [ ] **O - Open/Closed**: New features via extension, not modification
    - [ ] **O**: Uses strategy/factory patterns instead of long if/else chains
    - [ ] **L - Liskov Substitution**: Subclasses honor parent contracts
    - [ ] **L**: No unexpected exceptions in overridden methods
    - [ ] **I - Interface Segregation**: No fat interfaces forcing unused methods
    - [ ] **I**: Small, focused interfaces preferred
    - [ ] **D - Dependency Inversion**: Dependencies injected, not instantiated
    - [ ] **D**: High-level modules don't import low-level modules directly

11. **Anti-Monolith Review** 🔴 MANDATORY
    - [ ] No tight coupling between unrelated modules
    - [ ] Clear module boundaries (feature-based, not layer-based)
    - [ ] No global state or singletons (without good reason)
    - [ ] No circular dependencies
    - [ ] Changes to one feature don't require changes to others
    - [ ] Code is testable in isolation

12. **Maintainability Review**
    - [ ] Code is readable
    - [ ] DRY principle followed
    - [ ] Dependencies minimized
    - [ ] Easy to test
    - [ ] Easy to modify

#### Phase 3: Document Findings

13. **Categorize Issues**
    - [ ] Assign severity to each issue (Blocker/Warning/Suggestion)
    - [ ] Assign category (Correctness/Pattern/Testing/Security/etc.)
    - [ ] Document line numbers
    - [ ] Provide fix suggestions

14. **Generate Review Report**
    - [ ] Create review document
    - [ ] List all issues with details
    - [ ] Summarize approval status
    - [ ] Note required changes
    - [ ] Create `docs/reviews/story-[N.M]-code-review-v[X].md` (increment version if re-review)

### Phase 3.5: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `REVIEWER`
  - **Progress Summary** → Set "Review" row to `🟡 In Progress` (or `✅ Done` when all stories reviewed)
  - **Current Step Details** → Document which story was reviewed, result (APPROVED/CHANGES_REQUESTED)
  - **Completed Steps** → Add review entry with evidence: `docs/reviews/story-[N.M]-code-review-v[X].md`
  - **Quality Metrics** → Increment **Code Review** `[done]/[total]` count; set Status to `✅` when all stories reviewed or `🟡` while in progress
  - **Agent Activity** → Update REVIEWER: last action = "Reviewed story [N.M]", status = Active/Idle

Report to user:
```
✅ docs/status.md updated
   Step: Review → [status]
   Code Review: [done]/[total] stories reviewed
```

### Phase 4: Tracker Update (Optional - ALWAYS ASK)

Read `docs/status.md` → `## Project Tracking` block to determine the active tracker, then ask:

```
✅ Code review complete!
📄 Review saved to: docs/reviews/story-[N.M]-code-review.md

Result: [APPROVED / CHANGES_NEEDED]

❓ Would you like me to update the tracker? (yes/no/skip)
   [Detected tracker: Jira | GitHub Projects | Azure DevOps | Local]
```

**Only if user says YES**:

#### Jira

> **Comment FORMAT CONTRACT**: post the comment body as **Markdown** with REAL line breaks — NOT wiki-markup, and NEVER literal `\n` escape sequences (the Rovo MCP converts Markdown → Jira ADF; literal `\n` renders as plain text).

When review APPROVED:
```
@atlassian-rovo Update story [STORY_ID]:
- Add comment:
  * Code review APPROVED ✅
  * No major issues found
  * Minor fixes: [list if any]
  * Ready for unit testing
- Move to "Done" or "Ready for Testing" (based on workflow)
```

When review has BLOCKERS:
```
@atlassian-rovo Update story [STORY_ID]:
- Add comment:
  * Code review REQUIRES CHANGES 🔴
  * Blocker issues found: [count]
  * See review doc: docs/reviews/story-[N.M]-code-review.md
- Move back to "In Progress"
```

#### GitHub Projects

> Run all `gh` commands yourself via the Bash tool.

```bash
# Post review result comment
gh issue comment N --repo "ORG/REPO" \
  --body "Code review [APPROVED ✅ | REQUIRES CHANGES 🔴]. See docs/reviews/story-[N.M]-code-review-v[X].md"

# Move status: APPROVED → "In Review"; CHANGES_NEEDED → "In Development"
# Use GraphQL STATUS_OPTION_ID mutation (same pattern as aire-dev-implement)
```

#### Azure DevOps

> Run all `az boards` commands yourself via the Bash tool.

```bash
# Post review result comment
az boards work-item update \
  --id {WI_ID} \
  --discussion "Code review [APPROVED ✅ | REQUIRES CHANGES 🔴]. See docs/reviews/story-[N.M]-code-review-v[X].md" \
  --project "{PROJECT}"

# APPROVED → move to "Resolved"; CHANGES_NEEDED → move back to "Active"
az boards work-item update --id {WI_ID} --state "[Resolved|Active]" --project "{PROJECT}"
```

**If user says NO or SKIP**:
```
✅ Review complete. Tracker not updated.
   You can update manually if needed.
```

---

## Issue Severity

| Level | Icon | Action |
|-------|------|--------|
| Blocker | 🔴 | MUST fix before merge |
| High | 🟠 | SHOULD fix |
| Medium | 🟡 | CAN fix later |
| Low | 🟢 | Optional |

---

## Output

**Location**: `docs/reviews/story-[N.M]-code-review-v[X].md`
- First review: `story-1.2-code-review-v1.md`
- Second review: `story-1.2-code-review-v2.md`
- etc.

**Contents**:
- Review metadata (mode, previous review, severity threshold)
- Checklist results
- Issues found with severity (filtered by threshold)
- Previous issues status (for re-reviews)
- Suggested fixes
- Approval status

### Code Review Report Template

```markdown
# Code Review - Story [N.M]: [Story Name]

**Date**: [YYYY-MM-DD]  
**Reviewed By**: REVIEWER Agent  
**Review Number**: [1, 2, 3, etc.]  
**Review Mode**: [INITIAL_REVIEW / FIX_VERIFICATION / NEW_CHANGES]  
**Status**: ✅ APPROVED / ⚠️ APPROVED WITH COMMENTS / ❌ CHANGES REQUESTED

---

## Review Metadata

**Previous Review**: [None / docs/reviews/story-[N.M]-code-review-v1.md]  
**Previous Status**: [N/A / APPROVED / CHANGES_REQUESTED]  
**Files Changed Since Last Review**: [All / specific files / None]  
**Severity Threshold Applied**: [All / Blocker+High only]

---

## Review Summary

**Components Reviewed**: [List of files/components]  
**Lines of Code**: [Approximate count]  
**Tests Reviewed**: [Yes/No]  
**Coverage**: [X]%

**Overall Assessment**: [Brief 2-3 sentence summary]

---

## Checklist Results

### Correctness
- [x] ✅ Code does what it's supposed to
- [x] ✅ Edge cases handled
- [x] ✅ Error conditions handled
- [x] ✅ No obvious bugs

### Pattern Adherence
- [x] ✅ Error handling follows pattern
- [x] ✅ Logging follows pattern
- [x] ⚠️ Naming conventions - Minor issues (see ISS-002)
- [x] ✅ File organization correct

### Testing
- [x] ✅ Unit tests exist
- [x] ✅ Tests are meaningful
- [x] ⚠️ Missing edge case test (see ISS-003)
- [x] ✅ Coverage ≥85%

### Documentation
- [x] ✅ Code comments where needed
- [x] ✅ No TODO comments
- [x] ✅ Self-review exists

### Security
- [x] ✅ No hardcoded secrets
- [x] ✅ Input validation present
- [x] ✅ Auth/authz checked

---

## Issues Found

### ISS-001: [Title] 🔴 Blocker

**Category**: [Correctness/Security/Pattern/etc.]  
**File**: `path/to/file.js:45-52`  
**Pattern Reference**: [Link to pattern doc section if applicable]

**Issue**: 
[Detailed description of what's wrong]

**Current Code**:
```javascript
// code that has the issue
```

**Suggested Fix**:
```javascript
// code showing the fix
```

**Why This Matters**: [Explanation of impact]

---

### ISS-002: [Title] 🟡 Medium

**Category**: Style  
**File**: `path/to/file.js:23`  
**Pattern Reference**: `docs/architecture/design/01-patterns-and-standards-greenfield.md` (greenfield) or `docs/architecture/design/03-patterns-and-standards-brownfield.md` (brownfield) — section `#naming`

**Issue**: 
Variable name `x` doesn't follow naming convention.

**Suggested Fix**:
Rename to `userCount` or similar descriptive name.

---

### ISS-003: [Title] 🟢 Low

**Category**: Testing  
**File**: `path/to/file.test.js`

**Issue**: 
Missing test for empty array edge case.

**Suggested Test**:
```javascript
it('should return empty array when no users exist', () => {
  expect(getUsers([])).toEqual([]);
});
```

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|-----|----------|----------|------|--------|
| 1 | ISS-001 | 🔴 Blocker | Security | auth.js:45 | Must Fix |
| 2 | ISS-002 | 🟡 Medium | Style | user.js:23 | Should Fix |
| 3 | ISS-003 | 🟢 Low | Testing | user.test.js | Optional |

**Summary**:
- Blockers: 1 (must fix before merge)
- High: 0
- Medium: 1
- Low: 1

---

## What Was Done Well

1. ✅ Clean separation of concerns
2. ✅ Comprehensive error handling
3. ✅ Good test coverage (87%)
4. ✅ Clear function names

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: 1 blocker (ISS-001) must be resolved before merge.

**Next Steps**:
1. Fix ISS-001 (security issue)
2. Consider fixing ISS-002 (naming)
3. Re-request review

---

## Sign-Off

**Reviewer**: REVIEWER Agent  
**Date**: [Date]  
**Signature**: [Approved / Changes Requested]
```

---


---

## Anti-Loop Protection

**Key Rules**:
1. ✅ ALWAYS check for previous reviews first
2. ✅ SKIP if already approved and code unchanged
3. ✅ Only report Blocker+High on re-reviews
4. ❌ DON'T find new Medium/Low issues on every review
5. ❌ DON'T re-review approved unchanged code
6. ❌ **DON'T edit code, tests, or any non-docs file** — this workflow is strictly read + report. Fixes are owned by DEV via `aire-dev-remediate`.

**This prevents endless suggestion loops!**

---

**Tell me what story to review (e.g., "aire-review-code story 1.2"), then type "proceed".**

---

## After Review — Mandatory Next-Step Output (DO NOT IMPROVISE)

After writing `docs/reviews/story-[N.M]-code-review-v[X].md`, the ONLY message you present is the block below. Do NOT propose code edits, do NOT invent "fix infra first vs. continue" alternates, do NOT skip the remediate handoff when blockers/high issues exist.

```
📋 Code review complete — docs/reviews/story-[N.M]-code-review-v[X].md
   Status: <✅ APPROVED | ⚠️ APPROVED WITH COMMENTS | ❌ CHANGES REQUESTED>
   Issues: [a] 🔴 | [b] 🟠 | [c] 🟡 | [d] 🟢

▶️ Next step:

1️⃣  **aire-dev-remediate**   ← required if status is ❌ CHANGES REQUESTED
                                 recommended if ⚠️ APPROVED WITH COMMENTS
                                 N/A if ✅ APPROVED
     DEV picks this review report and fixes each 🔴/🟠 issue TDD-style,
     marking each ✅ Resolved in the report.

2️⃣  **aire-dev-implement next story**     ← only if status is ✅ APPROVED (or after remediation)

Type your choice (1 / 2).
```


