---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Build Cycle Planning — break requirements into Build Cycles, output cycle-plan.md per cycle
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---
# AIRE Build Cycles — Planning

## Agent

**BUILD_CYCLE_PLANNER** 

## Before Starting

Read ALL of the following — nothing else:

1. Read `SPEC/agents/AIRE_BUILD_CYCLE_PLANNER.md`
2. Read `docs/requirements.md` — features, success criteria, NFRs, scope, timeline
3. Read all files in `docs/architecture/design/` (greenfield + brownfield target/patterns) AND `docs/architecture/current/` (brownfield as-is overview + deep-dives) — system architecture, tech stack, constraints, patterns
4. If `docs/plans/builds/` has existing cycle plans, read them all (carry-forward items)

**Prerequisites** (must be completed before this workflow):

- **For Greenfield projects**:
  - `docs/requirements.md` must exist. If not ask user to run `aire-greenfield-requirements` first.
  - `docs/architecture/design/` must have files. If not ask user to run `aire-greenfield-architecture` then `aire-greenfield-patterns`.

- **For Brownfield projects**:
  - `docs/requirements.md` must exist. If not ask user to run `aire-brownfield-requirements` first.
  - `docs/architecture/current/` must have files. if not ask user to run `aire-brownfield-inspect` → `aire-brownfield-deep-dive` → `aire-brownfield-architecture` → `aire-brownfield-patterns`.

---

## Execution Steps:

**Do NOT ask the user questions before starting.** Read the requirements and architecture docs, analyze them, then go straight to proposing cycles. The user will review and adjust the proposal.

### Phase 1: Load Inputs

**Step 1a — Requirements**

- [ ] Read `docs/requirements.md` completely
- [ ] Extract all features, user personas, success criteria, NFRs, technical constraints, timeline signals
- [ ] Note explicit scope boundaries (IN vs OUT)

**Step 1b — Architecture**

- [ ] Check if `docs/architecture/design/` exists → read all files (greenfield: `00-system-architecture-greenfield.md`, `01-patterns-and-standards-greenfield.md`; brownfield: `02-target-architecture-brownfield.md`, `03-patterns-and-standards-brownfield.md`)
- [ ] Check if `docs/architecture/current/` exists → read all files (brownfield as-is: `00-system-overview.md`, `01-*-deep-dive.md`)
- [ ] Note constraints that affect sequencing: what must be built before what can be built
- [ ] Note integration points that span multiple cycles

**Step 1c — Previous Cycles (only if `docs/plans/builds/` has existing cycle folders)**

- [ ] For each previous `docs/plans/builds/cycle-[N]/cycle-plan.md`:
  - Read the **Open Items** table
  - Read the **Deferred to Next Cycle** section
- [ ] Compile a consolidated carry-forward list

**Step 1d — Tier categorization**

```
TIER 1 — Foundation
  - Architecture scaffold + project bootstrap
  - Authentication, authorization
  - Shared infrastructure (database, APIs, CI/CD)

TIER 2 — Core Features (from requirements.md)
  [list]

TIER 3 — Supporting Features (depends on Tier 2)
  [list]

TIER 4 — Integrations (third-party / system interfaces)
  [list]

TIER 5 — Non-functional / Polish
  [list]
```

- [ ] Map hard dependencies between features

### Phase 2: Propose Cycle Structure

Present proposal directly — no questions first:

```
## Proposed Build Cycle Plan

Total Cycles: [N]
Cycle Plans: docs/plans/builds/cycle-[N]/cycle-plan.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Cycle 1 — Foundation
BUILDID: CYCLE-1
Expected Outcome: Deployable walking skeleton
Scope:
  - Architecture scaffold + project bootstrap
  - [Auth feature]
  - [Shared infrastructure]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Cycle 2 — [Feature Area]
BUILDID: CYCLE-2
Expected Outcome: [What stakeholders can see and sign off]
Scope:
  - [Feature — vertical slice: backend API + frontend UI]
  - [Feature]
Dependencies: Cycle 1 complete

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Continue for each cycle]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Does this reflect your delivery priorities?
  A) Confirm as proposed
  B) Move [feature] to an earlier cycle
  C) Split cycle [N] into two cycles
  D) Merge cycles [N] and [N+1]
  E) Other: ___
```

- [ ] Wait for user response
- [ ] Revise if needed
- [ ] Final confirmation: "Cycle structure confirmed. Generating artifacts."

### Phase 3: Generate Cycle Plan Documents

For each approved cycle, create `docs/plans/builds/cycle-[N]/cycle-plan.md`:

```markdown
# Cycle Plan — [Cycle Name]

**Cycle ID**: cycle-[N]
**BUILDID**: CYCLE-[N]
**Expected Outcome**: [demonstrable to stakeholders]

---

## Scope

### In Scope (this cycle)

- [Feature] — Epic N, Stories N.M-N.P
- [Feature] — Epic N, Stories N.M-N.P

### Deferred to Next Cycle

- [Feature — reason]

---

## Workshop Plan (4 half-days)

**Day 1**: [Focus area — e.g., information architecture, core feature]
→ Goal: production-ready code for [specific deliverable]

**Day 2**: [Focus area]
→ Goal: production-ready code for [specific deliverable]

**Day 3**: [Focus area]
→ Goal: production-ready code for [specific deliverable]

**Day 4**: Integration, testing, stakeholder review and scope sign-off
→ Goal: all features integrated, tested, demo-ready

Each day ends with **production-ready, deployable code** — no partial or broken states overnight.

---

## Acceptance Criteria

[High-level criteria for sign-off]

## Open Items

| Item | Owner |
| ---- | ----- |

## Prerequisites

[What must exist before workshops begin]
```

### Phase 4: Generate Master Overview

Create `docs/plans/build-cycles.md`:

```
# Build Cycles Overview — [Project Name]

## Summary
Total Cycles: [N]
Cycle Plans: docs/plans/builds/cycle-[N]/cycle-plan.md
Story Files: docs/plans/stories/

## Cycle Map
| Cycle | BUILDID | Scope Summary | Expected Outcome |
|---|---|---|---|
| Cycle 1 | CYCLE-1 | Foundation + auth | Walking skeleton deployed |
| Cycle 2 | CYCLE-2 | [summary] | [outcome] |

## Dependency Map
[Which cycles depend on which]

## Risk Log
[Scoping risks flagged during planning]
```

### Phase 4.5: GitHub Release Plan (if GitHub tracking active)

> **Rule for the agent: execute every `gh` command yourself via the Bash tool. Skip this phase entirely if `docs/status.md` does NOT contain `**Tracking**: GitHub Projects`.**

**Step A — Detect GitHub tracking**

Read `docs/status.md`. If the Project Tracking block shows `**Tracking**: GitHub Projects`, capture:
- `ORG`, `REPO` (from `**Repo**:` URL)
- `PROJECT_NUMBER`, `PROJECT_ID` (node id starting `PVT_`)
- `RELEASE_FIELD_ID` (single-select, created empty in kickoff)

If any are missing → tell user: "GitHub tracking is configured but field IDs are missing — re-run `aire-project-kickoff` Step G". Stop this phase.

**Step B — Conceptual model**

A **Build Cycle = Release Plan**. It is strategic and spans multiple Epics (= Milestones) created later by `aire-*-plan`. Each cycle becomes one option on the project's **Release** custom field, so every future Story/Bug issue can be tagged with its cycle.

**Step C — Create one Release field option per cycle** (GraphQL — one mutation setting all options at once, since `singleSelectOptions` replaces the full list):

```bash
gh api graphql -f query='
mutation($projectId:ID!,$fieldId:ID!){
  updateProjectV2Field(input:{projectId:$projectId,fieldId:$fieldId,singleSelectOptions:[
    {name:"CYCLE-1 — <Cycle 1 Name>",color:BLUE,  description:"<Expected Outcome>"}
    {name:"CYCLE-2 — <Cycle 2 Name>",color:PURPLE,description:"<Expected Outcome>"}
    {name:"CYCLE-3 — <Cycle 3 Name>",color:GREEN, description:"<Expected Outcome>"}
  ]}){ projectV2Field{ ... on ProjectV2SingleSelectField { id name options{ id name } } } }
}' -f projectId="PROJECT_ID" -f fieldId="RELEASE_FIELD_ID"
```

Capture each option's returned `id` — these are `RELEASE_OPTION_ID_CYCLE_N`.

**Step D — Create a draft GitHub Release per cycle** (optional roadmap visibility; ask user first):

```
❓ Create a draft GitHub Release per cycle for roadmap visibility? (yes/no)
```

If yes, for each cycle:

```bash
gh release create "v<cycle-tag>" --repo "ORG/REPO" --draft \
  --title "CYCLE-<N> — <Cycle Name>" \
  --notes "Release Plan scope:
- <feature 1>
- <feature 2>

Expected Outcome: <stakeholder demo description>"
```

(Skip a cycle if its tag already exists — `gh release view <tag>` returns 0.)

**Step E — Write back into each `cycle-plan.md`**

Append to each `docs/plans/builds/cycle-[N]/cycle-plan.md`:

```
## GitHub Release Plan

**Release Option**: CYCLE-N — <name>
**Release Option ID**: <RELEASE_OPTION_ID_CYCLE_N>
**Draft Release**: https://github.com/ORG/REPO/releases/tag/v<cycle-tag>  (if created)
```

Downstream (`aire-*-plan`, `aire-qa-triage`) uses the Release Option ID to set the Release field on every issue it creates for this cycle.

---

### Phase 4.6: Azure DevOps Iteration Plan (if Azure DevOps tracking active)

> **Rule for the agent: execute every `az boards` command yourself via the Bash tool. Skip this phase entirely if `docs/status.md` does NOT contain `**Tracking**: Azure DevOps`.**

**Step A — Detect Azure DevOps tracking**

Read `docs/status.md`. If the Project Tracking block shows `**Tracking**: Azure DevOps`, capture:
- `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH` (Sprint 1 baseline from kickoff)

**Step B — Create one Iteration per Build Cycle**

Each Build Cycle maps to one Azure DevOps iteration (sprint):

```bash
# For each cycle N (2, 3, ... — Sprint 1 already created in kickoff for Cycle 1):
az boards iteration project create \
  --name "Sprint N" \
  --project "{PROJECT}" \
  --start-date "<YYYY-MM-DD>" \
  --finish-date "<YYYY-MM-DD>"

# Assign iteration to team
az boards iteration team add \
  --team "{TEAM_NAME}" \
  --id "{PROJECT}\\Sprint N" \
  --project "{PROJECT}"
```

Capture each iteration path as `ITERATION_PATH_CYCLE_N` (e.g., `{PROJECT}\Sprint N`).

**Step C — Write back into each `cycle-plan.md`**

Append to each `docs/plans/builds/cycle-[N]/cycle-plan.md`:

```
## Azure DevOps Iteration Plan

**Iteration Path**: {ITERATION_PATH_CYCLE_N}
**Board URL**: {ORG_URL}/{PROJECT}/_boards/board/t/{TEAM_NAME}/Stories?iteration={ITERATION_PATH_CYCLE_N}
```

Downstream (`aire-*-plan`, `aire-qa-triage`) uses `ITERATION_PATH_CYCLE_N` to assign all work items created for this cycle to the correct sprint.

---

### Phase 4.7: Jira Fix Version Plan (if Jira tracking active)

> **Rule for the agent: use `@atlassian-rovo` for all Jira operations. Skip this phase entirely if `docs/status.md` does NOT contain `**Tracking**: Jira`.**

**Step A — Detect Jira tracking**

Read `docs/status.md`. If the Project Tracking block shows `**Tracking**: Jira`, capture:
- `JIRA_BASE_URL` (e.g., `https://your-org.atlassian.net`)
- `PROJECT_KEY` (from the Project Tracking block)

If any are missing → tell user: "Jira tracking is configured but project key is missing — re-run `aire-project-kickoff` Step J". Stop this phase.

**Step B — Conceptual model**

A **Build Cycle = Fix Version**. Each cycle becomes one Jira fixVersion so that every future Story/Bug issue can be tagged with its target release cycle. Downstream workflows (`aire-*-plan`, `aire-qa-triage`) use the fixVersion ID to stamp every Jira issue they create for that cycle.

**Step C — Create one fixVersion per cycle**

For each cycle N:

```
@atlassian-rovo create version in project [PROJECT_KEY]:
  name: "CYCLE-N — <Cycle Name>"
  description: "<Expected Outcome>"
  released: false
```

Capture each returned version ID as `JIRA_VERSION_ID_CYCLE_N`.

**Step D — Write back into each `cycle-plan.md`**

Append to each `docs/plans/builds/cycle-[N]/cycle-plan.md`:

```
## Jira Fix Version Plan

**Fix Version Name**: CYCLE-N — <name>
**Fix Version ID**: <JIRA_VERSION_ID_CYCLE_N>
**Jira URL**: <JIRA_BASE_URL>/projects/<PROJECT_KEY>/versions/<JIRA_VERSION_ID_CYCLE_N>
```

Downstream (`aire-*-plan`, `aire-qa-triage`) uses `JIRA_VERSION_ID_CYCLE_N` to set the `fixVersion` on every Jira issue it creates for this cycle.

---

### Phase 5: Update `docs/status.md`

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` if it exists; create using `SPEC/templates/STATUS_FORMAT.md` format if not
- [ ] Updates to make:
  - **Updated By** → `BUILD_CYCLE_PLANNER`
  - **Overall Status** → `🟢 ON TRACK`
  - **Progress Summary** → Set "Build Cycles" row to `✅ Done` with evidence: `docs/plans/builds/`
  - **Build Cycles table** → Add/update all cycle rows with BUILDID, scope, status
  - **Completed Steps** → Add cycle plan files as evidence
  - **Upcoming** → `aire-greenfield-plan` or `aire-brownfield-plan` for Cycle 1 stories
  - **Agent Activity** → Update BUILD_CYCLE_PLANNER to Idle

### Phase 6: Execution Brief

```
Build Cycle Planning Complete — [N] cycles.

Cycle plans:
  docs/plans/builds/cycle-[N]/cycle-plan.md  (one per cycle)

Master overview:
  docs/plans/build-cycles.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next Steps:

Per-cycle execution:
  → aire-ui-ux-design  ⭐ RECOMMENDED
  → aire-greenfield-plan or aire-brownfield-plan (BUILDID: CYCLE-[N])
  → Stories saved to: docs/plans/stories/
  → aire-dev-implement → aire-review-code → aire-qa-validate → deploy
  → Wrap Up → next cycle
```

---

## Output Summary

| Artifact                 | Location                               |
| ------------------------ | -------------------------------------- |
| Cycle Plan (per cycle)   | `docs/plans/builds/cycle-[N]/cycle-plan.md` |
| Build Cycles Overview    | `docs/plans/build-cycles.md`           |

---

## Rules

- MUST: `docs/requirements.md` and `docs/architecture/` must exist before running this workflow
- MUST: Do NOT ask the user questions before proposing — read docs, analyze, propose
- MUST: Cycle plans are `.md` files at `docs/plans/builds/cycle-[N]/cycle-plan.md`
- MUST: Every cycle must end with shippable, demonstrable functionality
- MUST: Cycle 1 always bootstraps the architecture scaffold
- MUST: Stories within a cycle must use vertical slices (not layer-based horizontals)
- MUST: Every cycle plan includes a BUILDID (CYCLE-1, CYCLE-2, etc.)
- MUST: Stories created by `aire-greenfield-plan` or `aire-brownfield-plan` must carry the BUILDID from the active cycle

---

**Type "proceed" to begin analyzing requirements and architecture docs.**


