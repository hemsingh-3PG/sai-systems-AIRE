---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-05-15"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Dev - Remediate Issues. Fix defects identified in a code-review or QA bug-triage report against the relevant story/epic context.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---
## Agent

**DEV**

## Before Starting 

1. Read `SPEC/agents/AIRE_DEV.md`
2. Read `SPEC/rulebooks/aire-implementation-rulebook.md`
3. **Check for reports** (do NOT read them yet):
   - `docs/reviews/story-*-code-review-v*.md` (code review reports)
   - `docs/testing/bug-triage-*.md` (QA triage reports)
   - If **none** exist, **STOP**: Tell user to "Run `aire-review-code` or `aire-qa-triage` first to produce a report to remediate from."

---

## STEP 1 — Tell Me Which Report to Remediate (ask FIRST)

**IMPORTANT**: Always ask the user which report drives this remediation. Never guess.

1. **Enumerate available reports**:
   - List every `docs/reviews/story-*-code-review-v*.md` (newest version per story).
   - List every `docs/testing/bug-triage-*.md` (sorted newest first by date in filename).

2. **Present options to user**:

```
Which report should I remediate from?

📝 CODE REVIEW REPORTS (docs/reviews/):
  1. story-1.2-code-review-v2.md   — Status: ❌ CHANGES REQUESTED   (2 🔴, 1 🟠)
  2. story-2.1-code-review-v1.md   — Status: ⚠️ APPROVED WITH COMMENTS (0 🔴, 3 🟡)
  3. ...

🐛 QA TRIAGE REPORTS (docs/testing/):
  A. bug-triage-2026-05-12.md      — 7 bugs (2 P0, 3 P1, 2 P2)
  B. bug-triage-2026-05-08.md      — 4 bugs (0 P0, 1 P1, 3 P2)
  C. ...

🔀 COMBINED:
  M. "multiple" — pick more than one report (I will ask which)

Type your choice (e.g., "1", "A", or "multiple"):
```

3. **After selection**, read the chosen report(s) end-to-end. Do NOT proceed until the user has named a specific report.

4. **If multiple stories appear in the same report (triage spanning epics)**, list the distinct stories/epics referenced and confirm scope:
   ```
   This triage references stories: 1.2, 2.1, 3.4 (Epic 3).
   ❓ Remediate ALL referenced stories, or a subset? (all / list specific, e.g. "1.2, 2.1")
   ```

---

## STEP 2 — Load Plan, Architecture, and Story Context (only AFTER user picked a report)

Now that the scope is known, read **only** the context relevant to the chosen report:

1. Read `docs/plans/implementation-plan.md` — if missing, **STOP**: Tell user to "Run `aire-greenfield-plan` or `aire-brownfield-plan` first."
2. Read pattern docs from `docs/architecture/` — the ones cited in the report or in the affected story file(s).

---

## STEP 3 — Load Story & Epic Context

For EVERY story referenced by the chosen report(s):

1. **Find the story file**: `docs/plans/stories/epic-N-story-N.M-*.md`
   - If filename isn't obvious, glob `docs/plans/stories/*story-N.M*.md`.
   - If the story file is missing, ASK the user to confirm the correct story before continuing — do NOT invent context.

2. **Read the full story file** — Acceptance Criteria, IN/OUT of scope, Must-Read references, architecture patterns.

3. **Read sibling stories in the same epic** ONLY if a report issue explicitly crosses story boundaries (e.g., "BUG-005 spans story 3.2 and 3.3"). Otherwise stay scoped to the referenced story.

4. **Read the existing self-review** at `docs/stories-implemented/story-[N.M]-review.md` (if present) to understand what was already implemented and what patterns were applied.

5. **Read related implemented code** — the files listed in the report's "File" column and any neighbors needed to understand the change.

> **No separate remediation log file is ever created.** All remediation evidence (resolution blocks, files changed, test summary, patterns applied, deviations, lessons) is appended *inside the source report itself*. See the "Remediation Section Template" under **Output**.

---

## Tracker Detection (Jira / GitHub / Azure DevOps / Local)

Read `docs/status.md` → `## Project Tracking` block, same as `aire-dev-implement`:
- `**Tracking**: Jira` → enable Jira sync prompts.
- `**Tracking**: GitHub Projects` → capture `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `STATUS_FIELD_ID`, and the `STATUS_OPTION_ID_*` values (via `gh project field-list PROJECT_NUMBER --owner ORG --format json` once per session).
- `**Tracking**: Azure DevOps` → capture `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH`; run `az devops configure --defaults organization="{ORG_URL}" project="{PROJECT}"` once per session.
- Neither → local only.

**Identifying the tracker artifact for this remediation**:
- **Code review report** → use the parent story's `**Jira**: PROJ-N`, `**GitHub**: #N`, or `**AzureDevOps**: #N` header.
- **QA triage report** → each bug row already has `**GitHub**: <url>` (if pushed), a Jira bug key, or an Azure DevOps work item ID. If a bug has no tracker link, remediate it against the parent story instead.

---

## Execution Steps

### Phase 1: Preparation & Scope Confirmation

- [ ] Build a unified **Remediation Backlog** from the chosen report(s). Each entry: `{id, severity/priority, file:line, summary, story, tracker-link}`.
   - Code review issues → use `ISS-NNN` IDs from the review doc.
   - Triage bugs → use `BUG-NNN` IDs from the triage doc.
- [ ] **Skip already-resolved items** — any issue in the source report that already carries a `**Resolution** ([date], DEV): ... Status: ✅ Resolved` marker block (the marker this workflow itself writes) MUST be excluded from the backlog. Surface the count to the user:
   ```
   ℹ️  Skipped [K] item(s) already marked ✅ Resolved in <report filename>:
       ISS-001, BUG-005, ...
   ```
   This makes the workflow re-entrant — running it twice on the same report does NOT redo finished work.
- [ ] **Filter by severity (default)**:
   - Code review: 🔴 Blocker + 🟠 High are MANDATORY. 🟡 Medium / 🟢 Low: ask user.
   - Triage: P0 + P1 are MANDATORY. P2 / P3: ask user.
- [ ] **Read all reference files** cited by affected stories.
- [ ] **MANDATORY: Summarize the remediation plan**:
   ```
   Remediation plan from <report filename>:

   Stories touched: 1.2, 2.1
   Files to change: src/auth/login.js, src/auth/login.test.js, ...

   Will fix:
     🔴 ISS-001 — Missing input validation (login.js:45)
     🔴 BUG-005 — Data loss on save (saveHandler.js:88)
     🟠 ISS-002 — Logging exposes PII (login.js:120)

   Will SKIP unless you say otherwise:
     🟡 ISS-003 — Naming nit (user.js:23)

   Approach per item: [1-line summary]

   ❓ Proceed? (yes / adjust scope / cancel)
   ```
   **HALT until the user explicitly confirms.** Do NOT touch code before this.
- [ ] ✅ Jira: If user confirms, ask before moving each affected story back to "In Progress".
- [ ] ✅ GitHub: If user confirms, ask before moving each affected issue back to "In Development". For triage-bug issues, move them to "In Development" individually.
- [ ] ✅ Azure DevOps: If user confirms, ask before moving each affected work item back to "Active" (`az boards work-item update --id {WI_ID} --state "Active"`).
- [ ] Update **## Story Tracker** in `docs/status.md` — note **Remediation Started** today (`[YYYY-MM-DD]`) on each affected story row.

### Phase 2: Remediation (Strict Execution Order, Per Issue)

Iterate the Remediation Backlog in severity order (🔴 → 🟠 → 🟡 → 🟢 / P0 → P3). For EACH issue:

- [ ] **Write/Update the failing test FIRST (TDD)**: Add a test that reproduces the defect. Run it — it MUST fail before the fix. If the defect can't be expressed as a test (pure refactor / doc).
- [ ] **Apply the fix**: Follow the "Suggested Fix" in the report when sound; deviate only with explicit justification logged in the remediation report.
- [ ] **Re-run the targeted test**: Must now pass.
- [ ] **Run the full unit + integration test suite**: 100% pass required. No "we'll fix the other test next iteration" — fix regressions you cause immediately.
- [ ] **Quality gates**: lint clean (zero warnings/errors), coverage still ≥85%.
- [ ] **Mark the issue resolved in the source report** (append a "Resolution" block under the issue — see template below). Do NOT delete original text.

### Phase 3: Status & Documentation

- [ ] 🔴 **MANDATORY in BOTH scenarios (code-review AND QA-triage)**: Append the **Remediation Section** (template below) to the *source report itself*. Do NOT create a separate remediation log file under `docs/stories-implemented/` — all evidence lives inside the source report.
- [ ] 🔴 **Stamp the top-of-report status banner** (template below) at the very top of the source report — `✅ Resolved` if every in-scope issue is fixed, `🟡 Partially Remediated (X/Y)` if some were deferred with user consent. Required in BOTH scenarios.
- [ ] If a triage report touches multiple stories, append ONE consolidated Remediation Section to that single triage report (grouped by story) — still no separate per-story log files.
- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`:
   - **Updated By** → `DEV`
   - **Current Step Details** → "Remediation from <report> — N issues fixed"
   - **Completed Steps** → add remediation entry per story with test evidence
   - **Quality Metrics** → refresh coverage %, lint status, increment `Documentation` `[done]/[total]`
   - **Blockers** → remove any entries resolved by this remediation
   - **Agent Activity** → DEV active, last action "Remediated story [N.M] (<report>)"

---

## Output

**Locations**:
- Updated code + tests
- Source report (code-review OR triage) annotated in place: top status banner + per-issue Resolution blocks + appended Remediation Section
- **No separate remediation log file is produced** — everything lives inside the source report

### Top-of-Report Status Banner (insert at the very top of the source report, BOTH scenarios)

Place this directly after the report's existing H1 title, replacing any prior remediation banner from a previous pass:

```markdown
> ## 🛠️ Remediation Status: ✅ Resolved
> - **Remediated**: [YYYY-MM-DD] by DEV Agent
> - **Fixed**: [N] issue(s) — 🔴 [a] / 🟠 [b] / 🟡 [c] / 🟢 [d]   (or P0:[a] / P1:[b] / P2:[c] / P3:[d])
> - **Deferred (with user consent)**: [M] — see Remediation Section
> - **Tests**: [P/P] passing | **Coverage**: [Z]% | **Linter**: clean
> - **Scenario**: [Code Review | QA Triage]
```

If anything was deferred, change the heading to `🟡 Partially Remediated (X/Y)` instead of `✅ Resolved`.

### Per-Issue Resolution Block (append under each fixed issue inside the source report)

```markdown
**Resolution** ([YYYY-MM-DD], DEV):
- Fix: [1-line description]
- Commit / change ref: `src/auth/login.js:45-58`
- Test evidence: `src/auth/login.test.js` (all green)
- Status: ✅ Resolved
```

### Remediation Section (append to the END of the source report, BOTH scenarios)

```markdown
---

# 🛠️ Remediation — [YYYY-MM-DD]

**Developer**: DEV Agent
**Severity Scope**: 🔴 Blocker + 🟠 High  (or P0+P1)
**Scenario**: [Code Review | QA Triage]
**Stories Affected**: [1.2, 2.1, ...]

## Issues Remediated

| ID | Severity | Story | File:Line | Summary | Resolution | Test Added |
|------|----------|-------|-----------|---------|------------|------------|
| ISS-001 | 🔴 Blocker | 1.2 | login.js:45 | Missing input validation | Added validateLoginInput() | login.test.js:120 ✅ |
| BUG-005 | P0 Critical | 2.1 | saveHandler.js:88 | Data loss on save | Wrapped write in tx with rollback | saveHandler.test.js:60 ✅ |

## Issues Deferred (with user consent)

| ID | Severity | Story | Reason |
|----|----------|-------|--------|
| ISS-003 | 🟡 Medium | 1.2 | Cosmetic, deferred to next cycle per user |

## Files Changed

| File | Change Type | Description |
|------|-------------|-------------|
| `src/auth/login.js` | Modified | Input validation + PII-safe logging |
| `src/auth/login.test.js` | Modified | New cases for invalid input + PII redaction |

## Patterns Applied

| Pattern | Where Applied | Notes |
|---------|---------------|-------|
| Input validation | `login.js` | Per `docs/architecture/design/*-patterns-*.md` |

## Testing Summary

- **Targeted tests added**: [X]
- **Full suite**: [Y/Y] passing
- **Coverage**: [Z]% (target ≥85%)

**Test Output**:
```
[paste here]
```

## Deviations from Report Suggestions

- None / [issue id]: [why the suggested fix wasn't used]

## Lessons Learned

1. [Lesson]

## Next Steps

- [ ] Re-request code review (`aire-review-code`) — required if any 🔴 fixed
- [ ] Re-run validation/regression (`aire-qa-validate` / `aire-qa-regression`) — required if any P0/P1 fixed
```

> **Re-runs**: if a Remediation Section dated today already exists in the source report, replace it (same date = same pass). If it's an older date, append a NEW `# 🛠️ Remediation — [YYYY-MM-DD]` section below the old one — keep the history. Always update the top banner to reflect the latest state.

---

## Tracker Sync (Always Ask)

### Jira

For each affected story / bug with a Jira key, after all its issues are remediated:

```
✅ Remediation for [STORY/BUG] complete.
❓ Update Jira [JIRA-ID]? (yes/no)
   - Story → move back to "Ready for Review" / "In QA"
   - Bug    → move to "Resolved" with fix comment
```

If YES:
```
@atlassian-rovo Update [JIRA-ID]:
- Add comment: "Remediated <ISS/BUG ids>. Tests: X/X. Coverage: XX%."
- Transition to <Ready for Review | Resolved>
```
> Comment body: Markdown with REAL line breaks — never literal `\n` escapes (the Rovo MCP converts Markdown → Jira ADF; literal `\n` renders as plain text).

### GitHub Projects

> Run all `gh` commands yourself via the Bash tool. On 422 "already exists" or "no changes", skip and continue.

For each affected story issue:
```
❓ Move issue #N back to "In Review" on the board? (yes/no)
```

For each remediated bug issue:
```
❓ Close bug issue #M as completed? (yes/no)
```

On YES, use the same GraphQL mutation pattern as `aire-dev-implement` (Phase: Story Completion → GitHub) with the appropriate `STATUS_OPTION_ID_*`. Close bug issues with `gh issue close M --repo "ORG/REPO" --reason completed` when the bug is fully resolved.

**NEVER change tracker state without explicit user confirmation.**

---

### Azure DevOps

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user to run them — but ALWAYS ask for confirmation before any work item state update (per the confirmation prompt below). If a command fails, STOP and report the error to the user before continuing.**

For each affected story / bug with an Azure DevOps work item ID (`**AzureDevOps**: #N`), after all its issues are remediated:

```
✅ Remediation for [STORY/BUG] complete.
❓ Update Azure DevOps Work Item #N? (yes/no)
   - Story → move back to "Active" (ready for re-review)
   - Bug    → move to "Resolved" with fix comment
```

If YES:
```bash
# Update state
az boards work-item update \
  --id N \
  --state "Active" \
  --project "{PROJECT}"

# Add completion comment
az boards work-item update \
  --id N \
  --discussion "Remediated <ISS/BUG ids>. Tests: X/X. Coverage: XX%." \
  --project "{PROJECT}"
```

**NEVER change tracker state without explicit user confirmation.**

---

## Rules

- 🔴 ALWAYS read the source report end-to-end before touching code — never remediate from memory or partial recall
- 🔴 ONE report per invocation by default — "multiple" is opt-in and still must list which
- 🔴 Always confirm scope (which issues, which stories) BEFORE writing code. HALT until user says proceed
- 🔴 TDD: failing test → fix → green test. No fix lands without a test (unless the issue is non-testable: doc/lint/rename — note this explicitly)
- 🔴 Run the FULL test suite after EVERY issue, not just at the end
- 🔴 Zero lint errors, coverage ≥85% — same bar as `aire-dev-implement`
- 🔴 Never silently downgrade severity — if you cannot fix a 🔴/P0, STOP and surface it; do not move on
- 🔴 Never modify the report's original issue text — only **append** (top banner above the original H1's content, per-issue Resolution blocks under each issue, and a Remediation Section at the end). The `Status: ✅ Resolved` line in the per-issue block is the **idempotency marker**: on re-runs, items carrying it MUST be skipped. Never alter or remove markers from prior runs.
- 🔴 **Never create a separate remediation log file — all remediation evidence is appended INSIDE the source report (code-review report or triage report). One file, one source of truth per cycle.
- 🔴 The top-of-report `🛠️ Remediation Status` banner is MANDATORY in both scenarios — code-review and QA-triage. Re-runs update the banner to reflect the latest pass.
- 🔴 Never skip stories on agent judgment ("looks fine") — every referenced issue must be either fixed, explicitly deferred with user consent, or escalated
- 🔴 No tracker writes without explicit user confirmation

---

## Anti-Loop Protection

- If the source report already contains a `# 🛠️ Remediation — [today]` section, STOP and ask the user whether this is a second pass (overwrite today's section) or a duplicate invocation (abort).
- After remediation, recommend `aire-review-code` (for review-driven remediation) or `aire-qa-regression` (for triage-driven remediation) — do NOT self-approve.

---

## After Remediation — Mandatory Next-Step Output (DO NOT IMPROVISE)

After all fixes land and the source report carries `✅ Resolved` markers, the ONLY message you present is the block below.

```
✅ Remediation complete — <report filename>
   Fixed: [X] (🔴[a] 🟠[b] 🟡[c] 🟢[d])  |  Deferred: [Y]
   Tests: [P/P] | Coverage: [Z]% | Linter: clean

▶️ Type the next step to proceed:

1️⃣  **aire-review-code**     ← required if any 🔴 was fixed in a code-review report
2️⃣  **aire-qa-regression**   ← required if any P0/P1 was fixed in a triage report
3️⃣  **aire-dev-remediate**   ← only if another report is still outstanding
4️⃣  **aire-dev-implement**   ← move to the next planned story (review/regression first if applicable)

```

**Tell me which report to remediate, then type "proceed".**
