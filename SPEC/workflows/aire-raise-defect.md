---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-07-06"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Raise Defect - Turn one or many QA/demo findings into well-formed, individually trackable defects. Consumes an existing bugs document or interviews the tester for missing fields, validates steps for contradictions, then creates Bug issues in Jira (Atlassian MCP), Azure DevOps (az CLI), or GitHub (gh CLI) — confirm-first.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---


# 🐞 Raise Defect — QA Bug Reporting to Jira / Azure DevOps / GitHub

Turn findings from a demo, QA pass, or exploratory session into crisp, reproducible, **individually
trackable** defects. A good bug report is actionable by a developer without a follow-up conversation.
This workflow handles **one bug or a whole batch**: it consumes an existing bugs document when there
is one, interviews the tester only for what's missing, and creates one tracker issue per bug —
nothing is written to the tracker until the tester approves.

---

## Phase 0: Intake & Tracker Detection

1. **Ask first**: "Do you have the bugs written down somewhere or will you describe them now?"
   - **Document given** → read it, split it into individual bugs (one defect per distinct failure —
     never merge two failures into one ticket, never split one failure into two), and extract every
     field from Phase 1 that the document already answers. Only ask about what's missing.
   - **No document** → ask how many bugs they found, then interview the tester with the **Phase 1
     questions** for each bug — there is no other source; every field comes from the tester's answers.
2. Detect the **tracker** from `docs/status.md` → `## Project Tracking` block:
   - `**Tracking**: Jira` → Jira path (Atlassian MCP). Confirm the MCP is available; if not, STOP
     and tell the tester to connect the Atlassian integration — no workarounds.
   - `**Tracking**: Azure DevOps` → ADO path. Capture `ORG_URL`, `PROJECT`; run
     `az devops configure --defaults organization="{ORG_URL}" project="{PROJECT}"` once. Verify auth.
   - `**Tracking**: GitHub Projects` → GitHub path. Capture `ORG`, `REPO`, `PROJECT_NUMBER`,
     `PROJECT_ID`. Verify `gh auth status`.
   - **No block / no status.md** → ask which tracker to use (Jira / Azure DevOps / GitHub) and
     collect the project key / org+project / owner+repo.
3. Determine the target container: Jira **project key**, ADO **project**, or GitHub **repo** — from
   `docs/status.md`, existing story keys in the Story Tracker, or by asking.

---

## Phase 1: Collect the Defect Fields (per bug)

For each bug, fill these industry-standard fields. **Pre-fill everything already known** from the
bugs document, the conversation, and `docs/` artifacts — then ask for ALL missing fields of ALL bugs
in **one consolidated message** (numbered per bug), so the tester answers once, not in a ping-pong.
Never invent details; if the tester doesn't know a field, record "Unknown".

1. **Summary** — `[Area] concise problem statement` (specific, searchable).
   e.g. `[Patient Search] No results returned when searching by MRN`
2. **Environment** — build/version, env (dev/QA/staging/prod), OS, browser/device, URL.
3. **Preconditions** — state that must exist before reproducing (logged-in role, existing data).
   Omit if none.
4. **Steps to Reproduce** — numbered, from a known starting state, with test data/accounts.
5. **Expected Result** — the intended behavior (cite the story/AC it comes from when known).
6. **Actual Result** — what happened, with exact error text/codes.
7. **Severity** — Blocker / Critical / Major / Minor / Trivial (impact if shipped).
8. **Priority** *(optional)* — P0/P1/P2; often set by the PO — leave blank if unknown.
9. **Reproducibility** — Always / Intermittent (state frequency) / Once.
10. **Affected story/component** — match against `docs/status.md` Story Tracker and
    `docs/plans/`; capture the related story's tracker ID (Jira key / ADO work item / GH issue) if one exists.

**Core fields** (never skip): steps to reproduce, expected, actual, severity. Push gently for these.

### Consistency check (before drafting)

For each bug, verify the report makes sense — catch problems now, not after a developer bounces it:

- Steps are ordered and complete: no step references something never set up (e.g. "click Save" with
  no editing step; a precondition used in step 4 but missing from Preconditions).
- Expected vs Actual actually differ and relate to the final step.
- Severity is plausible for the described impact (a typo isn't a Blocker; data loss isn't Trivial).
- Across the batch: flag bugs that look like **duplicates of each other** — ask the tester before
  drafting both.

Report anything contradictory back to the tester as a question — never silently "fix" their facts.

---

## Phase 2: Draft the Defects

Draft every bug, then show the batch as a compact review table
(`# | Summary | Severity | Priority | Affected story | Labels`) followed by the full body of each
draft. Body template (real Markdown — see tracker notes below):

```markdown
### Environment
**Build:** [..] | **Env:** [..] | **OS/Browser:** [..] | **URL:** [..]

### Preconditions
- [..]  (omit section if none)

### Steps to Reproduce
1. [..]
2. [..]

### Expected Result
[..]

### Actual Result
[.. exact error text ..]

### Severity / Priority / Reproducibility
**Severity:** [..] | **Priority:** [.. or —] | **Reproducibility:** [..]

### Affected Story / Component
[Story N.M — title + tracker ID if any]

---
Raised via AIRE `aire-raise-defect` by QA. Drafted with AI ([MODEL NAME]).
```

Per-tracker settings:

- **Jira**: issue type `Bug` — if the project has no `Bug` type, check
  `getJiraProjectIssueTypesMetadata` and confirm the nearest defect type with the tester.
  Labels `bug`, `defect`. Description must be **real Markdown** (`###`, `-`, `**bold**`) — the
  Atlassian MCP converts Markdown → ADF; old Jira wiki markup (`h3.`, `*`, `#`) lands as raw text.
- **Azure DevOps**: work item type `Bug`. Steps/description go as **HTML** (`<ol><li>…`) in
  `Microsoft.VSTS.TCM.ReproSteps` (or Description), matching this framework's other `az boards`
  usage. Tags: `bug; defect`. Map Severity to `Microsoft.VSTS.Common.Severity`.
- **GitHub**: issue with labels `bug`, `defect` (create labels only if missing). Body is Markdown
  as-is. If tracking is GitHub Projects, add the issue to project `PROJECT_NUMBER`.

Resolve `[MODEL NAME]` from the current session — never leave the placeholder.

---

## Phase 3: Confirm Before Creating (REQUIRED — never skip)

Show the final batch and ask exactly two options:

- **one-by-one** — confirm and create each defect individually
- **in one go** — approve the whole batch now and create all of them

Do not create anything without an explicit yes. If the tester edits a draft, revise and re-confirm
that draft. Excluding a bug from the batch is fine — record it as "not raised" in the summary.

---

## Phase 4: Create the Defects (only after confirmation)

For each approved bug, in order:

1. **Create** —
   - Jira: `createJiraIssue` (projectKey, issueType, summary, Markdown description, labels, priority).
   - ADO: `az boards work-item create --type Bug --title "<summary>" --fields ...` — run every `az`
     command yourself via the terminal; pass all content inline (here-string/heredoc), never via
     scratch files.
   - GitHub: `gh issue create --repo <ORG/REPO> --title "<summary>" --label bug --label defect
     --body ...` (inline body); then `gh project item-add` when GitHub Projects tracking is active.
2. **Verify & capture the real ID** — re-fetch the created issue (`getJiraIssue` /
   `az boards work-item show` / `gh issue view`) and capture key/ID + URL. Never report a guessed ID.
3. **Link** to the affected story's tracker item when one was identified
   (Jira `createIssueLink` relates-to; ADO `az boards work-item relation add` Related;
   GitHub: reference the story issue number in the body/comment).
4. If one creation fails, report it, fix or skip **that bug**, and continue the rest — never abandon
   a half-created batch silently.

---

## Execution Rules

- 🔴 **Never create a tracker issue without the Phase 3 confirmation** — non-negotiable gate.
- 🔴 **One defect per distinct failure** — trackable individually; never bundle a demo's findings
  into a single "demo bugs" ticket.
- 🔴 **Never fabricate steps, errors, environments, or severity** — ask, or record "Unknown".
- 🔴 **Run the consistency check** before drafting; surface contradictions as questions to the
  tester, never silently rewrite their facts.
- 🔴 **Be token-lean**: pre-fill from the bugs document and `docs/` first; batch all missing-field
  questions into one message; one batch confirmation (unless the tester picked one-by-one).
- 🔴 **Verify every creation** and report only real IDs/URLs.
- 🔴 **Never touch `docs/bugs.md`** — reading or writing. Raised defects live in the tracker only;
  the sole local write is the one Agent Activity row in `docs/status.md`.
- 🔴 **All issue bodies passed inline** to the MCP/CLI — never through scratch files.
- 🔴 Jira descriptions are **Markdown, never wiki markup**; ADO repro steps are **HTML** — match
  the conventions the framework's other workflows already use.
