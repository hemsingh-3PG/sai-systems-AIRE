---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: QA - Bug Triage. Classify, prioritize, and assess release impact of bugs found in validation or regression reports.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

## Agent

**QA** 

## Before Starting

1. Read `SPEC/agents/AIRE_QA.md`
2. Read `SPEC/rulebooks/aire-qa-rulebook.md`
3. **Check**: `docs/testing/` for any `validation-report-*.md` or `regression-report-*.md` — if none found, **STOP**: Tell user to "Run `aire-qa-validate` or `aire-qa-regression` first."

---

## Tell Me the Source Report

**IMPORTANT**: Always ask the user which report to triage bugs from.

If the user has just run `aire-qa-validate` or `aire-qa-regression` in this session, confirm:

```
Would you like to triage bugs from:

1. "current" - Use the report just generated in this session
              (aire-qa-validate or aire-qa-regression output)

2. "validation [filename]" - Use a specific validation report
   e.g., "validation validation-report-full-2026-03-11.md"

3. "regression [filename]" - Use a specific regression report
   e.g., "regression regression-report-2026-03-11.md"

4. "both" - Combine bugs from both a validation and regression report
   (I will ask for each filename)

Type your choice:
```

After selection:
- Read the chosen report(s) from `docs/testing/`
- Extract all bugs/failures listed
- **Output file**: `docs/testing/bug-triage-[YYYY-MM-DD].md`

---

## Execution Steps:

### Phase 1: Bug Collection
- [ ] Read the chosen validation/regression report(s)
- [ ] Extract all issues, failures, and regressions listed
- [ ] Compile into a unified bug list with IDs (BUG-001, BUG-002, ...)

### Phase 2: Bug Classification
For each bug:
- [ ] Assign severity: Critical / High / Medium / Low
- [ ] Assign priority: P0 / P1 / P2 / P3
- [ ] Categorize by type: Functional / Performance / Security / UI

### Phase 3: Impact Analysis
For each bug:
- [ ] Identify affected features
- [ ] Determine user impact
- [ ] Check for available workarounds

### Phase 4: Release Blocking Assessment
For each bug:
- [ ] Determine if it blocks release (Critical = always blocks)
- [ ] Identify dependencies between bugs
- [ ] Recommend action: Fix now / Fix later / Won't fix

### Phase 5: Generate Triage Report

**Output**: `docs/testing/bug-triage-[YYYY-MM-DD].md`

### Phase 5.5: Push Bugs to Tracker (Always ask)

After the bug triage report is written to `docs/testing/bug-triage-[YYYY-MM-DD].md`, check `docs/status.md` for the **Project Tracking** block:

- If `**Tracking**: GitHub Projects` → ask: `Push bugs to GitHub as Issues? (yes/no)` — if yes, follow the **GitHub path** below.
- If `**Tracking**: Jira` → ask: `Push bugs to Jira as Issues? (yes/no)` — if yes, follow the **Jira path** below.
- If `**Tracking**: Azure DevOps` → ask: `Push bugs to Azure DevOps as Work Items? (yes/no)` — if yes, follow the **Azure DevOps path** below.
- Otherwise → skip.

#### Jira Path

> **Rule for the agent: use `@atlassian-rovo` for all Jira operations. ALWAYS ASK FOR CONFIRMATION before creating issues. If an issue already exists, skip and continue.**

**Step 1 — Read tracking context**

From `docs/status.md` Project Tracking block: `PROJECT_KEY`, and the active cycle number `CYCLE_NUMBER` (if BUILDID set).
For each bug, check whether its parent story file has a `**Jira**: PROJ-N` reference — use that as the "Relates to" link.

**Step 2 — For each bug (BUG-NNN) in the triage report, create a Jira Bug issue**

Map severity → Jira priority:

| Triage Severity | Jira Priority |
| --------------- | ------------- |
| 🔴 Critical      | Highest       |
| 🟠 High          | High          |
| 🟡 Medium        | Medium        |
| 🟢 Low           | Low           |

```
@atlassian-rovo Create in [PROJECT_KEY]:
- Issue type: Bug
- Summary: BUG-NNN: <summary from triage report>
- Description (FORMAT CONTRACT — pass as **Markdown** with REAL line breaks; the Rovo MCP
  converts Markdown → Jira ADF. Use `##`/`**...**`, NOT wiki-markup `h2.`/`*...*`, and NEVER
  emit literal `\n` escape sequences, or Jira renders the body as plain text):
    ## Description
    <description from triage>

    ## Steps to Reproduce
    <steps>

    ## Evidence
    <logs/screenshots/test output>

    ## Environment
    <Local / Dev / Staging / Prod>

    ## Parent Story
    <PROJ-N or "N/A">

    ## Release Impact
    <Blocks / Should fix / Can defer>

    ## Recommendation
    <Fix now / Fix later / Won't fix>

    ---
    Source: docs/testing/bug-triage-YYYY-MM-DD.md
    BUILDID: CYCLE-N
- Priority: <mapped from severity above>
- Labels: bug, cycle-N (if BUILDID set), P<priority>, severity:<severity>
- fixVersion: cycle-N (only if BUILDID set — must match exactly, e.g. "cycle-1")
- If parent story Jira key known: link as "Relates to" → PROJ-N
```

**Step 3 — Write Jira keys back into the triage report**

For every BUG-NNN row in `docs/testing/bug-triage-[YYYY-MM-DD].md`, append the Jira link:

```
### BUG-001: Login failure 🔴
**Jira**: https://[your-domain].atlassian.net/browse/PROJ-NNN
```

**Step 4 — Print summary**

```
✅ Pushed N bugs to Jira
   M P0 blockers: PROJ-123, PROJ-124
   Project: https://[your-domain].atlassian.net/jira/software/projects/[PROJECT_KEY]/boards
   Release: cycle-N (if BUILDID set)
```

---

#### GitHub Path

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user. If 422 "already exists", skip and continue.**

**Step 1 — Read tracking context**

From `docs/status.md`: `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `RELEASE_FIELD_ID`, `PRIORITY_FIELD_ID`.
From the currently active cycle (ask user or read from `docs/status.md` Story Tracker): `RELEASE_OPTION_ID_CYCLE_N`, `CYCLE_NUMBER`.

**Step 2 — For each bug (BUG-NNN) in the triage report, create an Issue**

Map severity → GitHub label and priority → GitHub label:

| Triage Severity | Label              |
| --------------- | ------------------ |
| 🔴 Critical      | `severity:critical`|
| 🟠 High          | `severity:high`    |
| 🟡 Medium        | `severity:medium`  |
| 🟢 Low           | `severity:low`     |

| Triage Priority | Label         |
| --------------- | ------------- |
| P0              | `P0-critical` |
| P1              | `P1-high`     |
| P2              | `P2-medium`   |
| P3              | `P3-low`      |

If the bug references a parent story with a GitHub issue number (from the story file `**GitHub**: #N`), include `Parent: #N` in the body and use its milestone.

> **⚠️ CRITICAL — two failure modes that have silently burned past runs:**
>
> 1. **`--milestone` takes the milestone TITLE STRING, not the integer number.** `gh issue create --milestone 1` fails with "could not resolve to a Milestone" and the issue is NOT created. Always pass the full title (e.g. `--milestone "Epic 3: Search & Filtering"`). If the parent epic title isn't known, omit `--milestone` entirely — do not pass an integer.
> 2. **Never swallow the output of `gh issue create` into a variable without verifying both the exit code and that the captured value is a URL matching `https://github.com/<owner>/<repo>/issues/<number>`.** Some shell wrappers route `gh`'s error text to the same capture stream as the URL, and a surrounding print/log statement can exit 0 even when the issue was never created. After every call, assert: (a) exit status is 0, and (b) captured output matches the issue-URL pattern. On mismatch, STOP and report — do not keep filing bugs on top of a silent failure.

```bash
gh issue create --repo "ORG/REPO" \
  --title "BUG-NNN: <summary>" \
  --body "$(cat <<'EOF'
## Description
<description from triage>

## Steps to Reproduce
<steps>

## Evidence
<logs/screenshots/test output>

## Environment
<Local / Dev / Staging / Prod>

## Parent Story
<#parent-issue-number or "N/A">

## Release Impact
<Blocks / Should fix / Can defer>

## Recommendation
<Fix now / Fix later / Won't fix>

---
**Source**: docs/testing/bug-triage-YYYY-MM-DD.md
**BUILDID**: CYCLE-N
EOF
)" \
  --label "bug" --label "cycle:N" --label "<priority-label>" --label "<severity-label>" \
  --milestone "Epic <N>: <parent epic name if known, else omit --milestone>"
```

Capture `ISSUE_NUMBER` from the returned URL.

**Step 3 — Add bug issue to the Project + set Release field**

```bash
ISSUE_ID=$(gh api "repos/ORG/REPO/issues/ISSUE_NUMBER" --jq '.node_id')

ITEM_ID=$(gh api graphql -f query='
mutation($projectId:ID!,$contentId:ID!){
  addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){ item{ id } }
}' -f projectId="PROJECT_ID" -f contentId="$ISSUE_ID" --jq '.data.addProjectV2ItemById.item.id')

gh api graphql -f query='
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){ projectV2Item{ id } }
}' -f projectId="PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="RELEASE_FIELD_ID" -f optionId="RELEASE_OPTION_ID_CYCLE_N"
```

**Step 4 — Write issue numbers back into the triage report**

For every BUG-NNN row in `docs/testing/bug-triage-[YYYY-MM-DD].md`, append the GitHub link:

```
### BUG-001: Login failure 🔴
**GitHub**: https://github.com/ORG/REPO/issues/123
```

**Step 5 — Print summary**

```
✅ Pushed N bugs to GitHub
   M P0 blockers: #123, #124
   Project: https://github.com/orgs/ORG/projects/PROJECT_NUMBER
   Release: CYCLE-N — <name>
```

---

#### Azure DevOps Path

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user. If a command fails with "already exists", skip and continue.**

**Step 1 — Read tracking context**

From `docs/status.md`: `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH`.
From the currently active cycle (ask user or read from Story Tracker): `ITERATION_PATH_CYCLE_N`, `CYCLE_NUMBER`.

**Step 2 — For each bug (BUG-NNN) in the triage report, create a Bug work item**

Map severity → ADO priority field:

| Triage Severity | ADO Priority |
| --------------- | ------------ |
| 🔴 Critical      | 1            |
| 🟠 High          | 2            |
| 🟡 Medium        | 3            |
| 🟢 Low           | 4            |

Map triage priority → tag:

| Triage Priority | Tag          |
| --------------- | ------------ |
| P0              | `P0-critical`|
| P1              | `P1-high`    |
| P2              | `P2-medium`  |
| P3              | `P3-low`     |

If the bug references a parent story with an Azure DevOps work item ID (from the story file `**AzureDevOps**: #N`), include that in the tags and link the new work item.

```bash
BUG_WI_ID=$(az boards work-item create \
  --type "Bug" \
  --title "BUG-NNN: <summary>" \
  --description "<description from triage>" \
  --project "{PROJECT}" \
  --fields "Microsoft.VSTS.Common.Priority=<priority>" \
           "System.Tags=bug;cycle-<N>;P<priority>;severity:<severity>" \
           "Microsoft.VSTS.Scheduling.Effort=<story-points-if-known>" \
  --query "id" -o tsv)

# Assign to iteration
az boards work-item update \
  --id "$BUG_WI_ID" \
  --iteration "{ITERATION_PATH_CYCLE_N}" \
  --project "{PROJECT}"

# Link to parent story work item (if known)
az boards work-item relation add \
  --id "$BUG_WI_ID" \
  --relation-type "System.LinkTypes.Hierarchy-Reverse" \
  --target-id {PARENT_WI_ID}
```

**Step 3 — Write work item IDs back into the triage report**

For every BUG-NNN row in `docs/testing/bug-triage-[YYYY-MM-DD].md`, append the Azure DevOps link:

```
### BUG-001: Login failure 🔴
**AzureDevOps**: https://{ORG_URL}/{PROJECT}/_workitems/edit/{BUG_WI_ID}
```

**Step 4 — Print summary**

```
✅ Pushed N bugs to Azure DevOps
   M P0 blockers: #{WI_ID_1}, #{WI_ID_2}
   Board: {ORG_URL}/{PROJECT}/_boards/board/t/{TEAM_NAME}/Stories
   Iteration: {ITERATION_PATH_CYCLE_N}
```

---

### Phase 6: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `QA`
  - **Progress Summary** → Set "QA" row to `🟡 In Progress` (if blockers found) or keep current status
  - **Current Step Details** → Document triage results: total bugs, release blockers count, recommendation
  - **Blockers** → Add any release-blocking bugs (P0/Critical/high) to the Blockers table
  - **Agent Activity** → Update QA: last action = "Bug triage complete — [N] bugs, [M] blockers", status = Active

Report to user:
```
✅ docs/status.md updated
   QA: Bug triage complete — [N] bugs found, [M] release blockers
```

---

## Priority Classification Guide

| Priority | Severity | Condition |
|----------|----------|-----------|
| P0 | Critical | Blocks release — must fix immediately |
| P1 | High | Blocks release — must fix before release |
| P2 | Medium | Can fix after release |
| P3 | Low | Nice to have — cosmetic or minor |

---

## Bug Triage Report Template

```
# Bug Triage Report

**Date**: [YYYY-MM-DD]
**Triaged By**: QA Agent
**Source Report(s)**: [validation/regression report filenames used]

---

## Summary

**Total Bugs**: [X]
**Critical**: [A] 🔴
**High**: [B] 🟠
**Medium**: [C] 🟡
**Low**: [D] 🟢

**Release Blockers**: [N]

---

## Release Blocking Bugs

| ID | Severity | Summary | Impact | Recommendation |
|----|----------|---------|--------|----------------|
| BUG-001 | 🔴 Critical | Login failure | All users affected | MUST FIX |
| BUG-005 | 🔴 Critical | Data loss on save | Data integrity risk | MUST FIX |

---

## Priority Classification

### P0 - Must Fix Now (Release Blockers)
- BUG-001: Login failure
- BUG-005: Data loss

### P1 - Should Fix Before Release
- BUG-002: Performance degradation
- BUG-003: Error message unclear

### P2 - Can Fix After Release
- BUG-006: Minor UI glitch
- BUG-007: Tooltip text wrong

### P3 - Nice to Have
- BUG-010: Cosmetic issue

---

## Bug Details

### BUG-001: Login failure 🔴
**Severity**: Critical
**Priority**: P0
**Category**: Functional
**Affected Users**: All
**Workaround**: None
**Recommendation**: BLOCK RELEASE - Must fix immediately
**Assigned To**: DEV
**Target**: Today

[Repeat for each bug]

---

## Release Decision

**Recommendation**:
- [ ] ✅ APPROVE RELEASE (no blockers)
- [ ] ❌ BLOCK RELEASE (P0 bugs exist)
- [ ] ⚠️ CONDITIONAL RELEASE (with documented issues)

**Rationale**: [e.g., 2 critical bugs (BUG-001, BUG-005) must be fixed before release]

---

## Next Steps
1. Assign P0/P1 bugs to DEV
2. Set target fix date
3. Plan re-validation after fixes
```

---

## After Triage — Mandatory Next-Step Output (DO NOT IMPROVISE)

After writing `docs/testing/bug-triage-[YYYY-MM-DD].md`, the ONLY message you present to the user is the block below. Do NOT invent alternate paths ("fix infra first vs. continue story X"), do NOT recommend creating ad-hoc "Story 0.0" stories, do NOT skip the remediate handoff. The user — not the agent — decides whether to defer fixes.

```
📋 Bug triage complete — docs/testing/bug-triage-[YYYY-MM-DD].md
   [N] bugs total | [a] P0 | [b] P1 | [c] P2 | [d] P3

▶️ Next step:

1️⃣  **aire-dev-remediate**   ← recommended if any  bugs found
     DEV will fix the bugs in this report in priority order (P0 → P3),
     TDD per bug, then mark each ✅ Resolved in the triage report.

2️⃣  **aire-dev-implement** next story    

```

If there are zero P0/P1 bugs, still present the block and mark option 1 as "optional (only P2/P3 bugs)" instead of "recommended".

---

## Output

**Location**: `docs/testing/bug-triage-[YYYY-MM-DD].md`

---

## Rules

- 🔴 Always read the source report before triaging — never classify from memory
- 🔴 Critical bugs ALWAYS = P0 and BLOCK RELEASE, no exceptions
- 🔴 Every bug must have severity, priority, category, and recommendation
- 🔴 Write ONLY to `docs/testing/`
- 🔴 Output file name MUST include the date

---

**Recommended flow**: Run after `aire-qa-validate` or `aire-qa-regression`. Tell me which report to triage, then type "proceed".**


