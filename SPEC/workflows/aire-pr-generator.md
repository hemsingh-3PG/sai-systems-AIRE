---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-07-03"
component: "3Pillar AIRE SDLC Agentic Framework"
description: PR Generator - Repair docs/status.md (dedupe union-merge duplication, reconcile against source artifacts), then raise a Pull Request from the current branch with an evidence-grounded description.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---


# PR Generator — Status Repair + Pull Request Creation


## Before Starting

1. Read `SPEC/templates/STATUS_FORMAT.md` — the canonical structure `docs/status.md` MUST match
2. Read `docs/status.md` (if present)
3. Note the target branch: default `main` (or the repo's default branch), unless the user specified another

---

## Why this workflow repairs status.md first

`docs/status.md` is marked `merge=union` in `.gitattributes`. That driver
concatenates both sides of any conflicting hunk instead of producing conflict markers. Because markdown
tables re-flow when padded, parallel branches that each edit the same tables can leave **duplicated
rows/sections** behind — multiple copies of the same table stacked on top of each other — with no
conflict ever surfaced. Real conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) can also leak in.

**Every PR raised through this workflow first verifies and, if needed, repairs `docs/status.md` so the
duplication never reaches the target branch.**

---

## Phase 1: Preconditions & Safety Checks

1. Run `git status` and `git branch --show-current`.
   - If the current branch **is** the target branch (e.g. `main`), **STOP** — tell the user they must
     be on a feature branch to raise a PR.
   - If there are uncommitted changes, show them and ask whether to commit them first, stash them, or
     proceed anyway (uncommitted changes will NOT be included in the PR).
2. Run `git fetch origin <target-branch>` so the diff is computed against the **latest** remote target,
   not a stale local copy.
3. Confirm the current branch has a remote tracking branch. If not, note that push will need `-u`.
4. Check `gh auth status` (GitHub CLI installed and authenticated). If not, **STOP** and tell the user
   to authenticate first — do not attempt workarounds (no manual API calls with tokens).

---

## Phase 2: Repair docs/status.md

Skip this phase only if `docs/status.md` does not exist. Otherwise:

### 2a. Detect

1. Grep `docs/status.md` for `<<<<<<<`, `=======`, `>>>>>>>` — leftover conflict markers.
2. For each `##` section, check for:
   - **Repeated section headers** — the same `## Section Name` appearing more than once
     (union merge duplicates whole blocks, header included).
   - **Repeated table rows by key column** — the same key value appearing 2+ times:
     - Progress Summary: key = `Step` (including Epic rows)
     - Story Tracker: key = `Story`
     - Build Cycles: key = `Cycle` / `BUILDID`
     - Blockers: key = `ID`
     - Quality Metrics: key = `Metric`
     - Agent Activity: consecutive identical `(Agent, Last Action)` pairs (append-only log — only
       exact repeats count as duplicates, not different actions by the same agent)
   - **Repeated table header rows** mid-table (`| Step | Status | ...` appearing again below data rows)
     — a stacked duplicate copy of the table.
   - **Mixed table padding** within one logical table (padded vs unpadded `|---|`) — a signal of a
     merge-caused split, not two separate tables.
3. Report the duplicate count found per section **before** fixing anything. If nothing is found,
   report `docs/status.md is clean` and continue to Phase 3.

### 2b. Reconcile against source-of-truth artifacts

Do NOT just keep "the first copy" of a duplicated row — cross-check the actual artifacts so the
surviving row is correct:

| Table | Ground truth | Reconciliation rule |
|---|---|---|
| Story Tracker | `docs/plans/stories/`, `docs/stories-implemented/story-*-review.md` | One row per Story ID. `Start` = earliest non-`—` date across duplicates; `End` = latest; `Recorded` = latest. Merge only the columns the table actually has — the Story Tracker has NO Status column; never add one. |
| Progress Summary (Epic rows) | Count of `docs/stories-implemented/story-*-review.md` files per epic vs total stories for that epic in `docs/plans/implementation-plan.md` | Recompute `[done]/[total] stories done` from actual file counts — never trust either duplicate's cached count. |
| Build Cycles | Story Tracker (after its own reconciliation above) | `Stories` = done/total of Story Tracker rows whose `BUILDID` matches the cycle — a story counts as done when its `End` date is filled (non-`—`) or a matching `docs/stories-implemented/story-*-review.md` exists. `✅ Done` only if every story in the cycle is done. |
| Quality Metrics | Latest `Recorded` timestamp per `Metric` | Latest wins; discard older duplicates. |
| Blockers | Latest `Recorded` timestamp per `ID` | Latest wins — **unless** one duplicate says open and another says resolved: that is a genuine semantic conflict, ask the user. |
| Agent Activity | N/A — append-only log | Collapse only exact consecutive duplicates; never reorder or dedupe distinct actions. |
| Header / Project Overview / Current Step Details | N/A | Keep the block with the latest `**Last Updated**` timestamp; discard older duplicate blocks. |

**Genuine conflicts HALT the workflow.** If two duplicate rows disagree in a way that isn't just
"more/less progress" — e.g. one says `✅ Done` and the other says `🔴 Blocked`, different owners, or a
higher status whose cited evidence file does not exist on disk — surface it, ask the user which is
correct, and do NOT continue to Phase 3 until resolved. Never silently pick one, and never let a later
timestamp alone override a real status contradiction.

### 2c. Rewrite and validate

- Fold information from discarded duplicates into the surviving row (earliest start, latest end,
  evidence links) — dedup means merge-and-keep-best, never first-wins-delete-rest.
- Preserve the exact section names, column order, and status indicators defined in
  `SPEC/templates/STATUS_FORMAT.md`. Every required section present exactly once; `Recorded` remains
  the last column of every table.
- **Preserve the columns actually present in the file — NEVER insert, remove, or rename a column**,
  even if a reconciliation rule mentions a field the table doesn't have. If a table's columns differ
  from STATUS_FORMAT.md, keep the file's existing columns as-is and flag the discrepancy to the user
  instead of restructuring (dashboards parse these tables by column position).
- Write tables **unpadded** (`|---|---|`, cells not space-aligned) as STATUS_FORMAT.md shows them —
  padded tables re-flow every line when any cell changes length, which is what turns single-row edits
  into whole-table diffs and feeds the union-merge duplication. Formatting only — no content changes
  beyond the dedup itself.
- Print a summary: duplicates removed per section, anything flagged for manual review, and
  before/after line counts.
- If the file changed, commit it on the current branch with message
  `chore: repair docs/status.md (dedupe union-merge duplication)` — after showing the diff to the user.

---

## Phase 3: Diff Analysis

1. Changed files and full diff against the fetched remote target:
   ```
   git diff --stat origin/<target-branch>...HEAD
   git diff origin/<target-branch>...HEAD
   ```
2. Commit log for the branch: `git log origin/<target-branch>..HEAD --oneline`
3. Categorize the changes: features, bug fixes, refactors, docs, config, tests, infra.
4. Note files risky to auto-summarize: migrations, CI/CD config, secrets/config files, deleted files.

---

## Phase 4: AIRE Context — ground the summary in recorded work

Use the framework's own artifacts so the PR describes **what was actually planned and recorded**, not
just the raw diff:

1. `docs/status.md` (now repaired): identify Story Tracker / Progress Summary rows whose stories fall
   within this branch's scope — match story IDs against commit messages, the branch name, and changed
   file paths.
2. `docs/stories-implemented/story-*-review.md` for those stories: implementation evidence (tests,
   coverage, linter output) recorded at completion time.
3. `docs/reviews/` for those stories: code-review verdicts and any remediation notes.
4. If these artifacts don't exist or contain nothing relevant to this branch,Do not add content **Never fabricate story status or review results.**

---

## Phase 5: Draft the PR

Show the full draft to the user before doing anything else — do not push or create yet.

### Title
Short (< 70 chars), imperative, describing the net effect. Prefix with the primary story ID when one
is clearly identifiable (e.g. `[Story 4.2] Add domain API modules`).

### Body

```markdown
> 🤖 **AI Generated** — This pull request was generated by an AI agent using **[MODEL NAME]**.

## Summary
- [1-3 bullets on what changed and why, grounded in status.md / story artifacts]

## Stories
- [Story ID — title — status per docs/status.md, with evidence links, or the "no artifacts" note]

## Changes
- [Main code changes, grouped by area]

## Status.md Repair
- [Summary from Phase 2 (duplicates collapsed / already clean / not present)]

---
🤖 Generated with AI — Model: **[MODEL NAME]**
```

Determine `[MODEL NAME]` from the current session — never leave it as a placeholder in the final PR.

---

## Phase 6: User Confirmation (REQUIRED — never skip)

Present: target and current branch, whether push needs `-u`, the full title/body draft, and the label
to apply (`AI Generated`). Ask explicitly:

**"Push this branch and open this PR with these contents — yes/no?"**

Do not proceed without an explicit yes. If the user asks for edits, revise and re-confirm.

---

## Phase 7: Execute (only after confirmation)

1. Push: `git push -u origin <current-branch>` (or plain `git push` if upstream exists).
2. Ensure the `AI Generated` label exists (`gh label list --search "AI Generated"`); create it only if
   missing: `gh label create "AI Generated" --description "Pull request generated by an AI agent" --color "8A2BE2"`.
3. Create the PR, passing the body **inline** — a heredoc on POSIX shells, a here-string
   (`@'...'@`) on PowerShell. Never route the body through a scratch file.
   ```
   gh pr create --base <target-branch> --head <current-branch> \
     --title "<title>" --label "AI Generated" --body "$(cat <<'EOF'
   <body from Phase 5>
   EOF
   )"
   ```
4. Report the PR URL back to the user, then verify the created PR body renders the status-repair
   summary and stories section (`gh pr view <url>`).

---

## Execution Rules

- 🔴 **Never push or create the PR without the explicit Phase 6 confirmation** — non-negotiable,
  regardless of how confident the draft looks.
- 🔴 **Never let a duplicated `docs/status.md` reach the PR** — Phase 2 runs on every invocation the
  file exists; a HALT on a semantic conflict blocks the PR until the user resolves it.
- 🔴 **Never fabricate story status, review verdicts, or evidence** — cite only artifacts that exist
  on disk; otherwise state plainly that none were found.
- 🔴 **Always name the actual model** generating the PR in the body.
- 🔴 **Diff against the fetched remote target branch**, never a possibly-stale local copy.
- 🔴 **Do not rewrite history** (no rebase/amend). If the branch conflicts with the target, tell the
  user and stop — do not resolve conflicts automatically.
- 🔴 **One PR per branch** — if `gh pr list --head <branch>` shows an existing PR, show it and ask
  whether to update it instead of creating a duplicate.
- 🔴 **This workflow does not modify `.gitattributes`** — removing `merge=union` is a separate,
  explicit decision.
