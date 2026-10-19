# STATUS FORMAT — Canonical Template

**ALL agents and workflows MUST follow this exact format when creating or updating `docs/status.md`.**

Do NOT invent new sections, rename columns, add "Epic 0", use "Phase" instead of "Step", or change the status indicators. Read this template, then write `docs/status.md` exactly as specified.

---

## Rules for Updating status.md

1. **Always read `docs/status.md` first** before writing — if it exists, update only the changed sections
2. **If it does not exist**, create it using the full format below
3. **Never rename rows** — use the exact Step names listed below
4. **Never add rows like "Epic 0: Kickoff"** or "Epic 0: Documentation & Planning" — planning phases are tracked as individual Step rows, not as epics
5. **Status indicators** — use ONLY these four values (no variations):
   - `✅ Done` or `✅ Complete` — step is complete
   - `🟡 In Progress` — step is actively being worked on
   - `⏸️ Not Started` — step has not begun
   - `🔴 Blocked` — step is blocked by a dependency or issue
6. **Updated By** — always use the agent constant name (e.g., `ANALYST_PM_GREENFIELD`, `ARCHITECT`, `DEV`)
7. **Overall Status** — use ONLY these three values:
   - `🟢 ON TRACK` — no blockers, work proceeding
   - `🟡 IN PROGRESS` — work started but early stages
   - `🔴 BLOCKED` — a blocker is preventing progress
8. **Evidence** — always include the file path to the output artifact
9. **BUILDID** — if build cycles exist, include `**Active Cycle**: CYCLE-[N]` in Project Overview
10. **`Recorded` column** — every table includes a `Recorded` column as the LAST column. Set it to the current ISO timestamp (`YYYY-MM-DD HH:MM`) on every row you write or update.

---

## Concurrency

`docs/status.md` is marked `merge=union` in `.gitattributes` (installed automatically by `aire init` / `aire update`). This is git's built-in merge driver — when two parallel branches both modify `docs/status.md` and produce a hunk-level conflict, git concatenates both sides instead of producing conflict markers. No hooks, no commands, no setup. Works for local `git merge` / `git pull` and for server-side PR merges on GitHub/GitLab.



---

## Full Format

```markdown
# Project Status

**Last Updated**: [YYYY-MM-DD HH:MM]
**Updated By**: [AGENT_NAME]
**Overall Status**: 🟢 ON TRACK / 🟡 IN PROGRESS / 🔴 BLOCKED

---

## Project Overview

**Project**: [Name]
**Type**: Greenfield / Brownfield
**Start Date**: [Date]
**Target Completion**: [Date or TBD]
**Active Cycle**: [CYCLE-N or N/A]

---

## Progress Summary


| Step | Status | Owner | Updated | Evidence | Recorded |
|------|--------|-------|---------|----------|----------|
| Requirements | ✅ Done | AIRE_ANALYST_PM | YYYY-MM-DD | `docs/requirements.md` | YYYY-MM-DD HH:MM |
| System Discovery | ✅ Done | AIRE_ARCHITECT | YYYY-MM-DD | `docs/architecture/current/00-system-overview.md` | YYYY-MM-DD HH:MM |
| Deep-Dive | ✅ Done | AIRE_ARCHITECT | YYYY-MM-DD | `docs/architecture/current/01-*-deep-dive.md` | YYYY-MM-DD HH:MM |
| Target Architecture | ✅ Done | AIRE_ARCHITECT | YYYY-MM-DD | `docs/architecture/design/02-target-architecture-brownfield.md` _(brownfield only)_ | YYYY-MM-DD HH:MM |
| Patterns | ✅ Done | AIRE_ARCHITECT | YYYY-MM-DD | `docs/architecture/design/03-patterns-and-standards-brownfield.md` _(brownfield variant)_ | YYYY-MM-DD HH:MM |
| Architecture | ✅ Done | AIRE_ARCHITECT | YYYY-MM-DD | `docs/architecture/design/00-system-architecture-greenfield.md` _(greenfield only)_ | YYYY-MM-DD HH:MM |
| Patterns | ✅ Done | AIRE_ARCHITECT | YYYY-MM-DD | `docs/architecture/design/01-patterns-and-standards-greenfield.md` _(greenfield variant)_ | YYYY-MM-DD HH:MM |
| UI/UX Design | ✅ Done | AIRE_UI_UX_DESIGNER | YYYY-MM-DD | `docs/ui-ux/ui-ux-spec.md` | YYYY-MM-DD HH:MM |
| Build Cycles | ✅ Done | AIRE_BUILD_CYCLE_PLANNER | YYYY-MM-DD | `docs/plans/builds/` | YYYY-MM-DD HH:MM |
| Implementation Plan | ✅ Done | AIRE_PRODUCT_OWNER | YYYY-MM-DD | `docs/plans/implementation-plan.md` | YYYY-MM-DD HH:MM |
| Epic 1: [Name] | 🟡 In Progress | AIRE_DEV | YYYY-MM-DD | [Y]/[Z] stories done | YYYY-MM-DD HH:MM |
| Epic 2: [Name] | ⏸️ Not Started | — | — | — | YYYY-MM-DD HH:MM |
| Review | ⏸️ Not Started | AIRE_REVIEWER | — | — | YYYY-MM-DD HH:MM |
| QA | ⏸️ Not Started | AIRE_QA | — | — | YYYY-MM-DD HH:MM |
| DevOps Discovery | ⏸️ Not Started | DEVOPS | — | — | YYYY-MM-DD HH:MM |
| DevOps Pipeline | ⏸️ Not Started | DEVOPS | — | — | YYYY-MM-DD HH:MM |
| DevOps Deploy | ⏸️ Not Started | DEVOPS | — | — | YYYY-MM-DD HH:MM |
| DevOps Infra Evolve | ⏸️ Not Started | DEVOPS | — | — | YYYY-MM-DD HH:MM |
| Data Platform | ⏸️ Not Started | AIRE_DATA_ENGINEER | — | — | YYYY-MM-DD HH:MM |

**Row Rules:**
- **Greenfield projects**: Include rows for Requirements, Architecture, Patterns, Data Platform (if applicable), UI/UX Design (if applicable), Build Cycles (if used), Implementation Plan, then Epic rows, then Review, QA
- **Brownfield projects**: Include rows for System Discovery, Deep-Dive, Requirements, Target Architecture, Patterns, Data Platform (if applicable), Build Cycles (if used), UI/UX Design (if applicable), Implementation Plan, then Epic rows, then Review, QA
- **DevOps workflows**: Include rows for DevOps Discovery, DevOps Pipeline, DevOps Deploy, DevOps Infra Evolve — only include rows for workflows actually run
- **Data engineering**: Include a single Data Platform row when `aire-data-design` is run — relabel it `Data Pipeline` or `Data Migration` to match the initiative type
- **Only include rows for steps that apply** — eg: skip UI/UX Design if not used, skip System Discovery for greenfield, skip DevOps/Data rows if those workflows not used
- **Epic rows**: One row per epic from the implementation plan. Format: `Epic N: [Name]`. Progress = `[done]/[total] stories done`

---

## Current Step Details

### [Current Step Name]

**Owner**: [AGENT_NAME]
**Status**: 🟡 In Progress
**Started**: [Date]

**Progress**:
- [x] Sub-step 1 ✅
- [x] Sub-step 2 ✅
- [ ] Sub-step 3 🔄
- [ ] Sub-step 4

---

## Build Cycles

| Cycle | BUILDID | Scope | Stories | Status | Start | End | Recorded |
|-------|---------|-------|---------|--------|-------|-----|----------|
| Cycle 1 | CYCLE-1 | [scope] | 6/6 | ✅ Done | [Date] | [Date] | YYYY-MM-DD HH:MM |
| Cycle 2 | CYCLE-2 | [scope] | 3/5 | 🟡 In Progress | [Date] | — | YYYY-MM-DD HH:MM |
| Cycle 3 | CYCLE-3 | [scope] | 0/4 | ⏸️ Not Started | — | — | YYYY-MM-DD HH:MM |

_Stories `X/N` column is advisory after parallel merges; compute from Story Tracker._

---

## Story Tracker

| BUILDID | Story | Title | Start | End | Recorded |
|---------|-------|-------|-------|-----|----------|
| CYCLE-1 | 1.1 | [Title] | 2026-04-01 | 2026-04-01 | 2026-04-01 17:12 |
| CYCLE-1 | 1.2 | [Title] | 2026-04-02 | 2026-04-03 | 2026-04-03 15:42 |
| CYCLE-1 | 1.3 | [Title] | — | — | 2026-03-30 11:00 |
| CYCLE-2 | 2.1 | [Title] | — | — | 2026-03-30 11:00 |

**Rules:**
- **Plan workflows** (`aire-greenfield-plan`, `aire-brownfield-plan`) create this table with all stories, dates blank (`—`). Set `Recorded` to the planning timestamp.
- **DEV** sets **Start** date when beginning a story and **End** date when story is complete. Update `Recorded` to the current timestamp on every change.
- Sort by BUILDID then Story number.
- **Enhancement sub-stories DO NOT appear here.** Each enhancement run is tracked in the separate **Enhancement Tracker** table below.
- **`aire-drift` may append rows** for newly created foundation stories (no-foundation-match path) and CR-born superseding stories (`CR-N.M`). It MUST NOT modify pre-existing rows whose stories were not in its scope. See the Change Requests table below for CR provenance.


---

## Enhancement Tracker

Rows in this table are written exclusively by the `aire-enhancement` workflow at close-out. One row per completed enhancement run. This table is independent of the Story Tracker — enhancement sub-stories (`1.1a`, `1.1b`, …) and standalone enhancement stories (`ENHANCEMENT-N / N.1`) are tracked here, not in the Story Tracker above.

| Enhancement | Story ID | Title | Related-Story | Tracker | Start | End | Recorded |
|-------------|----------|-------|---------------|---------|-------|-----|----------|
| ENHANCEMENT-1 | 1.1a | [Title] | 1.1 | PROJ-123 / GH-45 / LOCAL | 2026-04-10 | 2026-04-10 | 2026-04-10 16:00 |
| ENHANCEMENT-2 | 2.1 | [Title] | none | LOCAL | 2026-04-15 | 2026-04-16 | 2026-04-16 11:25 |

**Rules:**
- **Only `aire-enhancement` writes rows here** — no other workflow touches this table.
- `Enhancement` column = `ENHANCEMENT-N` where `N` is the enhancement number from `docs/enhancements/enhancement-[N].md`.
- `Story ID` = sub-story letter-suffix ID (e.g., `1.1a`) when a related story is detected, or `N.1` when none is detected.
- `Related-Story` = parent story ID (e.g., `1.1`) or `none`.
- `Tracker` = the Jira key (e.g., `PROJ-123`), the GitHub issue prefix (`GH-<number>`), or `LOCAL`. Mirrors the `Jira:` frontmatter value on the story file.
- Set `Start` on Phase 6 entry and `End` on Phase 8 close-out (typically the same day for small enhancements). Update `Recorded` to the close-out timestamp.
- Sort by Enhancement number ascending; never reorder past rows.


---

## Change Requests

| CR ID | Status | Scheduled Cycle | Summary | Drafted | Applied | Recorded |
|-------|--------|-----------------|---------|---------|---------|----------|
| CR-1 | applied | CYCLE-1 | Void Transfer added (FR-13) | 2026-05-13 | 2026-05-15 | 2026-05-15 14:22 |
| CR-2 | proposed | CYCLE-2 | Bulk import support | 2026-05-14 | — | 2026-05-14 09:00 |

**Status values:**
- `applied` — CR drafted, previewed, confirmed (`yes`), and downstream changes propagated by `aire-drift` Phase 8.8
- `closed` — Implementation of CR-born stories complete
- `rejected` — Drafted in a prior run that the operator canceled at the Phase 8.7 gate; surfaces only if persisted manually
- `superseded` — Replaced by a later CR covering the same scope

Legacy values `proposed` and `approved` are retired (they belonged to the old two-invocation contract). CR status moves directly to `applied` in the single-gate workflow.

**Rules:**
- This section is auto-maintained by the `AIRE_REQUIREMENTS_STEWARD` agent on every drift workflow run. Do NOT edit manually.
- `aire-drift` Phase 8.8 adds a row with status `applied` and Applied = today's date
- Operator setting `status: rejected` in `change-request.md` is reflected here on next steward invocation
- If the section is missing on a legacy `status.md`, the next drift workflow run creates it (inserted between Story Tracker and Quality Metrics)
- CR ID format: `CR-<n>` per-cycle (not zero-padded). Cross-cycle reference: `cycle-<N>.CR-<n>`

---

## Quality Metrics

| Metric | Target | Current | Status | Recorded |
|--------|--------|---------|--------|----------|
| Unit Test Coverage | ≥85% | —% | ⏸️ | YYYY-MM-DD HH:MM |
| Integration Tests | 100% pass | — | ⏸️ | YYYY-MM-DD HH:MM |
| Code Review | All stories | 0/0 | ⏸️ | YYYY-MM-DD HH:MM |
| Documentation | All stories | 0/0 | ⏸️ | YYYY-MM-DD HH:MM |


---

## Completed Steps

- [x] **Requirements**: Done — YYYY-MM-DD
  - Evidence: `docs/requirements.md`
- [x] **Architecture**: Done — YYYY-MM-DD
  - Evidence: `docs/architecture/design/00-system-architecture-greenfield.md`
- [x] **Story 1.1**: [Title] — YYYY-MM-DD
  - Evidence: `docs/plans/stories/epic-1-story-1.1-Title.md`
  - Tests: All passing, coverage 87%

---

## Upcoming

1. **Story [N.M]**: [Title] — next to implement
2. **Story [N.M+1]**: [Title]
3. **[Next workflow step]**

---

## Blockers

| ID | Description | Owner | Opened | Status | Recorded |
|----|-------------|-------|--------|--------|----------|
| — | (none) | — | — | — | YYYY-MM-DD HH:MM |

---

## Agent Activity

| Agent | Last Action | Status | Updated | Recorded |
|-------|------------|--------|---------|----------|
| ANALYST_PM | Requirements complete | Idle | YYYY-MM-DD | YYYY-MM-DD HH:MM |
| ARCHITECT | Architecture complete | Idle | YYYY-MM-DD | YYYY-MM-DD HH:MM |
| PRODUCT_OWNER | Plan complete | Idle | YYYY-MM-DD | YYYY-MM-DD HH:MM |
| BUILD_CYCLE_PLANNER | — | Standby | — | YYYY-MM-DD HH:MM |
| DEV | Story 1.1 in progress | Active | YYYY-MM-DD | YYYY-MM-DD HH:MM |
| REVIEWER | — | Standby | — | YYYY-MM-DD HH:MM |
| QA | — | Standby | — | YYYY-MM-DD HH:MM |
```

---

## What Each Workflow Updates

Every workflow listed below MUST also set the `Recorded` column to the current ISO timestamp (`YYYY-MM-DD HH:MM`) on every row it writes or modifies.

| Workflow | Rows to Update | Sections to Update |
|----------|---------------|-------------------|
| `aire-project-kickoff` | (creates file) | All sections — initial creation |
| `aire-greenfield-requirements` | Requirements | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-brownfield-inspect` | System Discovery | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-brownfield-deep-dive` | Deep-Dive | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-brownfield-requirements` | Requirements | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-brownfield-architecture` | Target Architecture | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-brownfield-patterns` | Patterns | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-greenfield-architecture` | Architecture | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-greenfield-patterns` | Patterns | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-ui-ux-design` | UI/UX Design | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-build-cycles` | Build Cycles | Build Cycles table, Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-greenfield-plan` | Implementation Plan | Current Step Details, Completed Steps, Upcoming, Story Tracker (create rows), Build Cycles (set Stories `0/N`), Agent Activity |
| `aire-brownfield-plan` | Implementation Plan | Current Step Details, Completed Steps, Upcoming, Story Tracker (create rows), Build Cycles (set Stories `0/N`), Agent Activity |
| `aire-dev-implement` | Epic N row (progress) | Current Step Details, Completed Steps, Upcoming, Story Tracker (Start/End dates), Build Cycles (Stories `X/N`, status, End date),  Quality Metrics (Unit Test Coverage, Integration Tests, Documentation), Agent Activity |
| `aire-dev-remediate` | Epic N row (if rework changes progress), Blockers (clear resolved) | Current Step Details (which report + N issues fixed), Completed Steps (per remediation log), Story Tracker (Remediation Started/End notes on affected rows), Quality Metrics (Unit Test Coverage, Integration Tests, Documentation), Blockers (remove items resolved), Agent Activity |
| `aire-enhancement` | Enhancement Tracker (append one row at close-out) | Enhancement Tracker (NEW row — never touch Story Tracker), Quality Metrics (Unit Test Coverage, Integration Tests, Documentation), Agent Activity (ANALYST_PM / PRODUCT_OWNER / ARCHITECT / DEV → Idle) |
| `aire-drift` | Epic K row (if CR introduced stories); new Epic rows for net-new epics created in Phase 8.4c | Agent Activity (log entry for any path). On Phase 8.8 apply: Change Requests (add row, status `applied`, Applied date = today), Story Tracker (append CR-born stories + direct-edited stories + new foundation stories), Build Cycles (increment scheduled count, cycle-using only), Progress Summary (recompute Overall Completion if affected story status changed). On Phase 9 blocker path: Blockers row only. On Phase 8.10 cancel / Phase 10 exit: no writes. |
| `aire-review-code` | Review | Current Step Details, Completed Steps, Quality Metrics (Code Review), Agent Activity |
| `aire-qa-validate` | QA | Current Step Details, Completed Steps, Agent Activity |
| `aire-qa-triage` | QA / Blockers | Current Step Details (triage results), Blockers (add release-blocking bugs), Agent Activity |
| `aire-devops-discover` | DevOps Discovery | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-devops-pipeline` | DevOps Pipeline | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-devops-deploy` | DevOps Deploy | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-devops-infra-evolve` | DevOps Infra Evolve | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-archive` | (if cleaned, reset all step rows to `⏸️ Not Started` for next cycle) | Completed Steps (archive entry + zip path `docs/archive/<label>-<date>.zip`), Upcoming (`aire-brownfield-inspect`), Agent Activity |
| `aire-data-design` | Data Platform (or Data Pipeline / Data Migration) | Current Step Details, Completed Steps, Upcoming, Agent Activity |
| `aire-pr-generator` | (repair only — no new progress rows) | Removes merge=union duplication across ALL sections (one copy of each section/row, reconciled against source artifacts); never adds content, HALTs on genuine status contradictions |
| `aire-pr-reviewer` | (none — read-only) | Reads status.md / story artifacts as review context only; never writes to status.md |
| `aire-raise-defect` | (no progress rows) | Agent Activity only ("Raised N defects"); defects live in the tracker only — never touches `docs/bugs.md`; Blockers rows remain `aire-qa-triage`'s job |

---

## Anti-Patterns (NEVER DO THESE)

- **NEVER** add "Epic 0: Kickoff" or "Epic 0: Documentation & Planning" — planning steps have their own rows
- **NEVER** use "Phase" as the column header — always use "Step"
- **NEVER** use "Phase 1.1: Requirements" — just use "Requirements"
- **NEVER** mix percentage and fraction in the same cell — use `[Y]/[Z] stories done` for Epic rows
- **NEVER** use `.toon` references in status.md — always use `.md`
- **NEVER** invent new status indicators — use only: `✅ Complete` or `✅ Done`, `🟡 In Progress`, `⏸️ Not Started`, `🔴 Blocked`
- **NEVER** omit the `Recorded` column from any table — it's the last column on every row
- **NEVER** insert columns before any existing column — `Recorded` is appended at the end so existing dashboard regex stays valid
- **NEVER** add enhancement sub-stories (`1.1a`, `1.1b`, `ENHANCEMENT-N / N.1`) to the Story Tracker — they belong in the **Enhancement Tracker** table, written exclusively by `aire-enhancement`
- **NEVER** hand-author rows in the **Change Requests** table or hand-create CR folders under `docs/plans/builds/cycle-*/CR/` — `aire-drift` is the only sanctioned producer (R17). If the workflow needs a new CR, run `aire-drift` and let it stage the bundle through the single-gate apply.
