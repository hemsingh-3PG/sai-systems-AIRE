---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Brownfield - Implementation Planning. Create detailed execution plan with stories from requirements.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Brownfield - Implementation Plan

## Agent

**PRODUCT_OWNER** 

## Before Starting

1. Read `SPEC/agents/AIRE_PRODUCT_OWNER.md`
2. Read `SPEC/rulebooks/aire-brownfield-rulebook.md`
3. **CRITICAL**: Read `SPEC/templates/IMPLEMENTATION_PLAN_FORMAT.md` for mandatory format
4. Read `docs/requirements.md`
4a. Read the **Roles & Permissions Matrix** in `docs/requirements.md` — the canonical role registry every story's persona flow and RBAC Enforcement block must reference. Note each role's `Origin` (`Existing` = already enforced in the codebase, reuse it; `New` = introduced by this work). If absent, tell the user to add it via `aire-brownfield-requirements`.
5. Read `docs/architecture/current/00-system-overview.md`
6. Read all `docs/architecture/current/01-*-deep-dive.md` files
7. **Read**: `docs/architecture/design/02-target-architecture-brownfield.md`.
8. **Read**: `docs/architecture/design/03-patterns-and-standards-brownfield.md`.
9. **OPTIONAL UI/UX**: Ask user if UI/UX design needed
10. **IF UI/UX DONE**: Read `docs/ui-ux/ui-ux-spec.md` for design tokens
11. **SEQUENTIAL NUMBERING**: Check for existing epics/stories and ask user for starting numbers
12. **BUILD CYCLE CHECK** *(optional)*: Check if `docs/plans/builds/` exists. If it does, follow build-cycle integration below. If it does not, ask the user: "No build cycles found. Run `aire-build-cycles` first, or proceed without cycles? (cycles are optional)". If user proceeds without, skip BUILDID assignment entirely.

---

## STEP 0: Prerequisites Check (ALWAYS DO THIS FIRST)

Before anything else, verify ALL required inputs exist:

1. **Check for requirements**: `docs/requirements.md`
2. **Check for system overview**: `docs/architecture/current/00-system-overview.md`
3. **Check for deep-dive analysis**: `docs/architecture/current/01-*-deep-dive.md`
4. **Check for target architecture**: `docs/architecture/design/02-target-architecture-brownfield.md`
5. **Check for patterns & standards**: `docs/architecture/design/03-patterns-and-standards-brownfield.md`

**If requirements are missing**:
```
❌ docs/requirements.md not found
   → Please run: aire-brownfield-requirements
```

**If system overview or deep-dive are missing**:
```
❌ docs/architecture/current/ not found or empty
   → Please run: aire-brownfield-inspect then aire-brownfield-deep-dive
```

**If target architecture is missing**:
```
❌ docs/architecture/design/02-target-architecture-brownfield.md not found
   → Please run: aire-brownfield-architecture
```

**If patterns & standards are missing**:
```
❌ docs/architecture/design/03-patterns-and-standards-brownfield.md not found
   → Please run: aire-brownfield-patterns
```

**If ALL exist**, confirm and continue:
```
✅ Prerequisites found:
   ✓ Requirements: docs/requirements.md
   ✓ System overview: docs/architecture/current/00-system-overview.md
   ✓ Deep-dive: docs/architecture/current/[files found]
   ✓ Target architecture: docs/architecture/design/02-target-architecture-brownfield.md
   ✓ Patterns & standards: docs/architecture/design/03-patterns-and-standards-brownfield.md

Proceeding to implementation planning...
```

---

## STEP 1: Epic/Story Numbering (ALWAYS DO THIS FIRST)

**CRITICAL**: Before creating the implementation plan, determine the starting epic/story numbers.

### Check Existing Implementation Plan

1. **Read the existing plan** (if it exists):
   - Check if `docs/plans/implementation-plan.md` exists
   - If it exists, read the entire file
   - Find all Epic headers: `## EPIC N:` or `# Epic N:`
   - Find all Story headers: `### Story N.M:` or `## Story N.M:`
   - Also scan `docs/plans/stories/` for existing story files
   - Identify the **highest Epic number** and **highest Story number**

2. **Determine next numbers**:
   - If **no implementation plan exists**: Start from Epic 1, Story 1.1
   - If **plan exists with Epic X, Story X.Y as last**:
     - For adding stories to same epic: Epic X, Story X.(Y+1)
     - For new major feature: Epic (X+1), Story (X+1).1

3. **Ask User to Confirm**:
   ```
   📊 Current Implementation Plan Status:

   [If plan exists]
   ✓ Found existing implementation-plan.md
   ✓ Last Epic: Epic X
   ✓ Last Story: Story X.Y

   [If no plan exists]
   ℹ️  No existing implementation-plan.md found
   ℹ️  This will be the first implementation plan

   💡 Recommended Starting Point:

   For brownfield projects (adding features to existing code):
   - ALWAYS continue sequentially: Epic (X+1), Story (X+1).1

   Options:
   1. Start new epic (Epic [X+1], Story [X+1].1) - recommended for new feature
   2. Continue in current epic (Epic [X], Story [X.Y+1]) - only if extending same feature
   3. Specify custom epic/story numbers

   Which option? (1-3):
   ```

4. **Confirm Final Numbers**:
   ```
   ✅ Confirmed: Starting from:
   - First Epic: [N]
   - First Story: [N.1]

   Ready to proceed? (yes/no)
   ```

### CRITICAL Rules for Sequential Numbering

- ✅ **ALWAYS continue sequentially** - never reset to Epic 1, Story 1.1 unless truly the first plan
- ✅ **Read the file first** - don't guess, actually read `docs/plans/implementation-plan.md`
- ✅ **Ask user to confirm** - show what you found and what you'll use
- ❌ **NEVER reset numbering** - brownfield projects build on existing work
- ❌ **NEVER overwrite** existing epics - always increment

---

## BUILD CYCLE INTEGRATION (BUILDID)

**CRITICAL**: If build cycles have been planned (via `aire-build-cycles`), every story MUST carry a BUILDID.

### Detect Active Cycle

1. Check if `docs/plans/builds/` directory exists
2. If it exists, list all `docs/plans/builds/cycle-[N]/cycle-plan.md` files
3. Ask user:

```
Build cycles detected:
  - Cycle 1 (CYCLE-1): [scope from cycle-plan.md]
  - Cycle 2 (CYCLE-2): [scope from cycle-plan.md]
  ...

Which cycle are you planning stories for?
Enter cycle number (e.g., 1 for CYCLE-1):
```

4. Set `BUILDID = CYCLE-[N]` for all stories in this planning session
5. Read the corresponding `docs/plans/builds/cycle-[N]/cycle-plan.md` to scope the stories

### BUILDID in Story Files

Every story file MUST include the BUILDID and Jira traceability in the header:

```
### Story N.M: [Title]

**BUILDID**: CYCLE-[N] | **Epic**: N - [NAME] | **ID**: N.M | **Date**: [YYYY-MM-DD] | **Jira**: [JIRA-ID]
```

### Jira Traceability (MANDATORY)

**CRITICAL**: Check `docs/requirements.md` for the "Jira Stories Imported" table. If requirements were sourced from Jira (Path J in `aire-brownfield-requirements`), every story that maps to an imported Jira issue MUST carry the original Jira ID.

- **Jira-sourced story**: `**Jira**: PROJ-101` (exact Jira issue key from requirements.md)
- **Locally-created story** (no Jira origin): `**Jira**: LOCAL`
- **Story covering multiple Jira issues**: `**Jira**: PROJ-101, PROJ-102`

This traceability is used in Phase 4 to determine export behavior.

### If No Build Cycles Exist

If `docs/plans/builds/` does not exist or is empty, skip BUILDID assignment. Stories are created without BUILDID (backwards compatible).

---

## MANDATORY FORMAT

**You MUST follow the exact format specified in `SPEC/templates/IMPLEMENTATION_PLAN_FORMAT.md`**

This ensures:
- ✅ Each story contains complete implementation details
- ✅ Code examples are included in every story
- ✅ Test requirements are comprehensive
- ✅ Each story file is self-contained — AI agents have full context without loading the entire plan

---

## Execution Steps:

### Phase 1: Plan Structure

- [ ] Read `docs/requirements.md` — all features, success criteria, scope
- [ ] Read `docs/architecture/current/` — system overview + deep-dive patterns
- [ ] If BUILDID set: scope stories to the active cycle's plan only

#### 1a — Check for Jira Stories Table in Requirements

- [ ] Check if `docs/requirements.md` contains a **"Jira Stories Imported"** table
- [ ] If YES (Jira-sourced requirements): use **1:1 Jira Story Mapping** (see below)
- [ ] If NO (local requirements): use **Vertical Slice Planning** (see below)

#### 1b — Jira-Sourced: 1:1 Story Mapping (when requirements have Jira table)

When `docs/requirements.md` has a "Jira Stories Imported" table, create **one implementation story file per Jira story**:

- [ ] Read the Jira Stories table — each row = one implementation story
- [ ] Group stories by Epic (use the Jira Epic column, or group by theme from Functional Requirements)
- [ ] For each Jira story, create a matching implementation story that:
  - Preserves the original Jira ID in the header (`**Jira**: PROJ-101`)
  - Uses the original Jira title as the story title
  - Keeps original Description, AC, Out of Scope from requirements.md
  - Derives implementation steps, prerequisites, patterns, tests from architecture docs
- [ ] Assign sequential epic/story numbers (from STEP 1 numbering)
- [ ] Each story carries the BUILDID if cycles are active

**Story file header format for Jira-sourced stories:**

```
### Story N.M: [ORIGINAL JIRA TITLE — unchanged]

**BUILDID**: CYCLE-[N] | **Jira**: [JIRA-ID] | **Epic**: N - [NAME] | **ID**: N.M | **Date**: [YYYY-MM-DD]
```

**Example mapping:**

```
Jira Stories from requirements.md:
  PROJ-101: "Export leads to CSV"        → Epic 1, Story 1.1 (CYCLE-1, Jira: PROJ-101)
  PROJ-102: "PDF report for leads"       → Epic 1, Story 1.2 (CYCLE-1, Jira: PROJ-102)
  PROJ-103: "Email notification system"  → Epic 2, Story 2.1 (CYCLE-1, Jira: PROJ-103)
  PROJ-104: "Dashboard analytics"        → Epic 3, Story 3.1 (CYCLE-2, Jira: PROJ-104)
```

#### 1c — Local Requirements: Vertical Slice Planning (when no Jira table)

When `docs/requirements.md` was created locally (PATH L), define epics using **VERTICAL FEATURE SLICES**:

- [ ] Each epic = ONE complete feature across ALL layers
- [ ] Within each epic, order stories: Backend API → Frontend UI → Integration/Wiring
- [ ] Break into stories (1-4 hours each)
- [ ] Each story gets `**Jira**: LOCAL` in the header

**❌ FORBIDDEN (Horizontal/Layer-Based)**:

```
Epic 1: Add All Backend Features
  Story 1.1: Webhook receiver
  Story 1.2: All API endpoints

Epic 2: Add All Frontend Features
  Story 2.1: Dashboard scaffolding
  Story 2.2: All components

Problem: Nothing testable until everything is connected
```

**✅ REQUIRED (Vertical/Feature-Based)**:

```
Epic 1: Repository Management (Complete Feature)
  Story 1.1: Repository API (Backend - CRUD endpoints)
  Story 1.2: PAT Storage (Backend - secure token storage)
  Story 1.3: Repository Form (Frontend - add repo UI)
  Story 1.4: Repository List (Frontend - display repos)
  Story 1.5: Integration Test (End-to-end repo management)
  ✅ TESTABLE: User can add/view/delete repositories
```

### Phase 1.5: Story-Dependency Graph (MANDATORY when plan has 2+ stories)

Before writing any story files, produce `docs/plans/dependency-graph.yml` per `SPEC/templates/IMPLEMENTATION_PLAN_FORMAT.md`. The graph groups stories into **waves of independent work**. Each story carries a `wave: N` field that gets pushed to Jira / GitHub as a `wave-N` label in Phase 4 so the board can be filtered by wave.

**Scope of this phase**: produce the YAML, validate it manually against the rules below, and confirm with the user. **Story-file authoring stays one-at-a-time in Phase 3.**

The graph does NOT route work to specific developers. It declares which stories are independent. Anyone on the team can pick any story from the current ready wave on the Jira / GitHub board.

---

**Step 1 — Ask `team_size` (justify it explicitly):**

```
❓ How many developers will be working on this project?

   Used SOLELY as a story-granularity hint. The planner aims to split
   stories so each wave contains at least `team_size` independent stories
   where the architecture allows, so no developer is blocked waiting on
   another's work-in-progress.

   - Solo dev (team_size: 1): normal granularity; waves still group
     independent stories so you can pick the next safe story without
     manual dependency analysis.
   - 2+ devs: planner pushes harder to make wave members independent,
     and surfaces shared-file conflicts before they cause merge pain.


```

Record the answer in the YAML's `team_size:` field.

---

**Step 2 — For each story, populate the graph entry:**

- `id`, `title`, `epic`: from the plan structure.
- `jira`: copy the Jira ID for Jira-sourced stories; else `LOCAL` (Phase 4 updates this).
- `github: null`: placeholder; Phase 4 updates it.
- `requires`: from architecture-natural ordering, informed by module dependencies discovered in the deep-dive. Apply the **TRUE-PARALLELISM RULES** below before finalizing.
- `enables`: reverse edges (informational).
- `files_touched`: from AIRE_ARCHITECT's File/Module Boundary Map in the brownfield patterns doc, intersected with the existing module each story touches.
- `wave`: filled in by Step 5.

---

**Step 3 — TRUE-PARALLELISM RULES (apply when computing `requires`):**

These rules prevent the two real failure modes: (a) artificial blocking that idles developers, and (b) cross-branch merge conflicts on shared files.

**R1. Seed-wave rule (BLOCKING — prevents unmergeable conflicts).** Any file in `shared_files` that does NOT yet exist in the repo must be **created** in a single "seed" story in wave 1, with every other wave-1 story `requires`-ing it. *Brownfield note*: in most brownfield projects the shared root files already exist, so R1 is a no-op for them. It applies when introducing a NEW shared file (a new central registry, a new shared types barrel, a new migrations dir).

**R2. Contract-not-implementation rule.** A story `requires` another only when it needs the other's **code to exist at compile/run time**, not just its API shape. If story B only needs A's request/response shape, B does NOT need `requires: [A]` — implement against the contract.

**R3. Frontend-may-mock rule.** A frontend story that calls a backend endpoint MAY drop `requires: [<backend story>]` when ALL of:
- The endpoint's contract is fixed, AND
- The frontend story's tests use MSW (or equivalent) handlers, AND
- A separate integration-test story verifies real-API wiring.

**R4. No-artificial-chains rule.** If two stories don't actually need each other's code, they get separate root nodes. Let real code dependencies decide ordering, not epic narrative.

**R5. Wave-width target.** Aim for each wave to contain at least `team_size` independent stories where architecture allows. Split chunky stories into 2 parallel ones over one big sequential one — but stop splitting when sub-stories drop below 1–2 hours.

---

**Step 4 — Identify `shared_files` (BLOCKING — do NOT skip):**

**4.1 Auto-detect overlap candidates.** Walk every story's `files_touched` and build a frequency map: any file path appearing in **2 or more** stories is a candidate.

**4.2 Add the always-shared baseline + brownfield-specific files.** The following must be in `shared_files` if they exist in this project:
- Every `package.json` (root + per-workspace)
- Every `tsconfig*.json`, lockfiles, lint/format configs
- Central route registries (discovered during deep-dive — use ACTUAL paths)
- Root app bootstrap files (discovered during deep-dive)
- Migrations index directory
- Shared type/interface barrel files
- Root config (`.env.example`, `.gitignore`, base tsconfig)
- CI/DevOps shared files
- **Brownfield-specific**: DI container / IoC registry, plugin registration file, feature-flag registry — typically already exist in the codebase and ARE shared.

**4.3 Present `shared_files` to the user for explicit confirmation.** Block on response.

**4.4 BLOCKING self-check.** For each pair of stories in the same candidate wave, check whether they overlap on any file NOT in `shared_files`. Resolve each overlap by adding to `shared_files` (if genuinely shared) or splitting/merging stories (if not). Re-run until zero illegal overlaps.

**4.5 Empty `shared_files` is forbidden for any plan with 2+ stories.**

---

**Step 5 — Compute waves and assign `wave: N` to each story:**

- Wave 1 = stories with `requires: []`.
- Wave N+1 = stories whose `requires` are entirely satisfied by waves ≤ N.
- Write the per-story `wave: N` field AND populate the top-level `waves:` block.

---

**Step 6 — Write `docs/plans/dependency-graph.yml`.**

> **GUARDRAIL (BLOCKING) — single graph file.** The dependency graph is ALWAYS
> `docs/plans/dependency-graph.yml`. NEVER invent a per-epic or variant filename
> (e.g. `dependency-graph-epic-38.yml`) — any other file is silently ignored and its stories never get implemented.
> If the file already holds a prior plan that is **planned-but-unshipped**, APPEND the
> new epic's stories and waves into the same file (do not overwrite the existing
> entries, do not create a second file). Group/delimit entries by epic so mixed-epic
> waves stay readable.

---

**Step 7 — Final validation pass (BLOCKING — do all four checks manually):**

1. **Seed-wave check**: no two wave-1 stories list the same `shared_files` entry in their `files_touched`.
2. **Disjoint-files check**: for every pair of stories in the same wave, `files_touched` are disjoint modulo `shared_files`.
3. **Wave consistency check**: every story's `wave: N` field matches the wave it appears in inside the `waves:` block.
4. **Requires resolution check**: every story ID in any `requires` list exists in `stories:`.

---

**Step 8 — Add `## Dependency Graph` section to the TOP of `docs/plans/implementation-plan.md`** with a Mermaid `graph TD` mirror (color-coded by wave) + wave summary table.

---

**Step 9 — Show the graph + wave analysis to the user and confirm:**

```
📊 Dependency Graph
   - Total stories: K
   - Waves: W (largest wave = M independent stories)
   - Root-independent stories: R
   - Longest dependency chain: L stories deep
   - team_size: N → average wave width: K/W (target ≥ N)

⚠️ Flag any wave with fewer than `team_size` stories. Acceptable only if
   architecture genuinely forces it. Otherwise return to Step 3 and split.

Proceed to story file authoring? (yes / revise graph)
```

Block until the user confirms `yes`.

---

**Step 10 — Compute Wave Workload Distribution:**

First, ensure `docs/plans/.parallel/` is listed in `.gitignore` — add it if missing (one-line append only, no other edits).

Using `team_size` (from Step 1) and the wave assignments from Step 5, distribute stories across developers so no dev idles within a wave.

**Distribution algorithm:**
1. Sort stories within each wave by dependency depth (deepest chains first — they take the longest)
2. Round-robin assign: Dev 1 → story 1, Dev 2 → story 2, … Dev N → story N, Dev 1 → story N+1, …
3. Flag ⚠️ any wave with fewer stories than `team_size` — at least one dev idles; accept only if architecture genuinely forces it

Present to the user:

```
📊 Wave Workload Distribution (team_size: N)

| Wave | Stories | Per Dev | Dev Assignments                                             | Notes                             |
|------|---------|---------|-------------------------------------------------------------|-----------------------------------|
| 1    | 6       | 2 each  | Dev-1: [1.1, 1.2] / Dev-2: [1.3, 1.4] / Dev-3: [1.5, 1.6] | ✅ All devs active               |
| 2    | 4       | 1–2     | Dev-1: [2.1, 2.2] / Dev-2: [2.3] / Dev-3: [2.4]           | ✅ All devs active               |
| 3    | 2       | 1 or 0  | Dev-1: [3.1] / Dev-2: [3.2] / Dev-3: —                     | ⚠️ 1 dev idles (arch constraint) |

⚠️ Any wave with fewer stories than team_size means at least one dev idles.
   Accept only when architecture genuinely forces it. Otherwise return to Step 3 and split.
```

Write `assignments:` into `docs/plans/dependency-graph.yml` under each wave entry:

```yaml
waves:
  - wave: 1
    stories: [1.1, 1.2, 1.3, 1.4, 1.5, 1.6]
    assignments:         # advisory — devs may swap stories; prevents accidental file overlap
      - dev: 1
        stories: [1.1, 1.2]
      - dev: 2
        stories: [1.3, 1.4]
      - dev: 3
        stories: [1.5, 1.6]
```

Confirm with user:

```
❓ Accept this wave distribution, or reassign?
1) Accept — proceed to story file authoring
2) Reassign — tell me which stories to swap between devs
```

Block until user responds.

> **No execution-mode flag is stored.** Whether stories are implemented one-by-one or in-one-go is decided at implementation time: `aire-dev-implement` auto-detects a parallelizable wave (≥2 ready stories or an `assignments:` block) and *suggests* the in-one-go path. The planner's only job here is to produce the `assignments:` blocks so that suggestion has the dev slices to work from.

---

### Phase 2: Detail Each Story

Every story body has **two sections in this order** (per IMPLEMENTATION_PLAN_FORMAT.md): **👤 User Reference** first (plain-English description + acceptance criteria for PMs/stakeholders — no technical jargon, covers all details), then **🤖 AI Agent Reference** (the full technical implementation contract — every checklist item below except the first lives inside it).

> **Depth standard (MANDATORY)** — author every section to `IMPLEMENTATION_PLAN_FORMAT.md` → **✍️ Authoring Depth Standard**. Write **expansively**: do NOT collapse QA Candidate, persona narratives, System responses + error cases, or QA-observable behaviour to one-liners. Persona narratives are a paragraph (prior state + trigger + system response + an edge case); steps name the system mechanics; QA Candidate=Yes names the mechanism + authz/state preconditions + idempotency/edge + the regression scope; System responses cover happy + idempotent-repeat + unauthorized + wrong-state + empty. A thin story forces the DEV to guess — match the worked examples, don't abbreviate them.

For each story (whether Jira/ADO/Github sourced or local), follow `SPEC/templates/IMPLEMENTATION_PLAN_FORMAT.md` and include:

- [ ] **👤 User Reference section** (FIRST): plain-English Description (what it delivers, problem solved, edge cases — no file paths/framework names/code jargon) + plain-English Acceptance Criteria bullets (every technical AC mirrored; for Jira-sourced: a plain-English rendering of the original Jira description + AC)
- [ ] **User Flow** (in 👤 User Reference): pick ONE mode, consistent with RBAC — **(A) role-differentiated** → per-persona `### [Persona]` subsections (scenario narrative + steps, canonical role names); **(B) role-agnostic but user-facing** (single-actor RBAC; everyone sees the same UI) → ONE deep **User Journey** with ≥4 interaction states (entry → load → render → interact → empty/error → responsive), NOT repeated personas; **(C) non-user-facing** infra/seed → the sentinel `Actor: system — no role variation.` Never list personas when RBAC = single-actor; never omit.
- [ ] **Flow Diagram** (in 👤 User Reference): one fenced ```mermaid diagram per story, type chosen to fit — `flowchart TD` for user-decision flows (decision diamonds for role/permission gates + error/denied branches) or `sequenceDiagram` for backend round-trips; a pure read-only/display story may substitute a state/display matrix table; single-actor/setup stories may use a short linear flow. Never omit (diagram OR matrix).
- [ ] **RBAC Enforcement** (in 🤖 AI Agent Reference): table of persona / permission key / guarded route / allowed / denied behavior / UI-when-denied, referencing the canonical matrix verbatim (prefer roles marked `Existing` — reuse their existing enforcement); plus enforcement point(s), the denied-access contract, and — for any scoped/`*-own` permission — the server-side scope derivation (identity from token/session, never client-supplied params — IDOR guard). If no role-differentiated access, write `No role-differentiated access — single actor.`
- [ ] **System responses + error cases** (in 🤖 AI Agent Reference): a Trigger/Response/Side-effect table covering the happy path, idempotent repeats, and unauthorized/wrong-state cases — the technical counterpart to the User Flow steps.
- [ ] **QA-observable behaviour** (in 🤖 AI Agent Reference, required when QA Candidate = Yes): verifiable post-conditions QA turns into assertions.
- [ ] **Roles Ref** header line listing the personas this story differentiates, and **QA Candidate** header (`Yes/No — reason`) — both mirror `IMPLEMENTATION_PLAN_FORMAT.md`
- [ ] **Must Read Reference Files** (top of 🤖 AI Agent Reference — images, specs, designs from `SPEC/references/`)
- [ ] **Design Tokens and Icons to Use** (for frontend stories — from `docs/ui-ux/ui-ux-spec.md` if exists)
- [ ] Epic context (Epic number, Story ID, Date, BUILDID if set, **Jira ID** if Jira-sourced)
- [ ] **Wave / Requires / Enables / Files Touched** in the story header — MUST mirror `docs/plans/dependency-graph.yml` exactly
- [ ] **Story Description** (detailed explanation of what the story does, what it achieves, and why it matters — placed at the top of the story; for Jira-sourced: use original Jira description and expand with additional context)
- [ ] Acceptance Criteria (comprehensive — cover every functional, edge-case, and validation scenario; include as many as needed to fully define "done"; for Jira-sourced: preserve original ACs from Jira, then add derived ones)
- [ ] Prerequisites (inferred from deep-dive module dependencies)
- [ ] Context files to read (exact paths from the codebase)
- [ ] Patterns to follow (from `docs/architecture/design/03-patterns-and-standards-brownfield.md` if it exists, otherwise from deep-dive pattern catalog — include migration notes for [New adoption] patterns where relevant)
- [ ] **Implementation Steps** (derived from target architecture + story description + AC, WITH code examples aligned to chosen patterns)
- [ ] **Test Requirements** (derived from existing test patterns, WITH code examples)
- [ ] Quality Checks (ESLint, coverage, etc.)
- [ ] Explicitly OUT of Scope (for Jira-sourced: preserve original out-of-scope from Jira, then add derived ones)
- [ ] Completion Evidence (what to provide when done)

**For or Jira, Github projects or Azure Devops Board sourced  stories**: Keep original title, description, AC, and out-of-scope unchanged. Add all derived fields (steps, tests, patterns, prerequisites) around them. The originals live in the 🤖 AI Agent Reference section; the 👤 User Reference section renders them in plain English. The **User Flow by Persona** and **RBAC Enforcement** blocks are also derived and **added** (never an edit to the imported content). If an imported story names a role absent from the Roles & Permissions Matrix, STOP and reconcile the matrix first (add the role there), then author the blocks.

### Phase 3: Documentation

**NEVER write all stories into one file — generates too many tokens and will exceed output limits.**

- [ ] Create `docs/plans/implementation-plan.md` as **lean index only** (epic titles + story titles + one-line objectives — NO full story content)
- [ ] Add **QA Manual Testing Groups** section at the end of `implementation-plan.md` (see Output below)
- [ ] Create each story as an individual file **one at a time**: `docs/plans/stories/epic-N-story-N.M-Story-Title.md`
  - **Always this naming** — no build number in filename (build tracked inside story content)
  - Write one story → confirm and ask to continue with next story → write next story (never batch all stories in one response)
  - Story files MUST follow `SPEC/templates/IMPLEMENTATION_PLAN_FORMAT.md`
- [ ] Present index to user for approval before writing story files
- [ ] **🚦 DEPTH GATE (BLOCKING — run before presenting each story)**: re-read the story you just wrote and verify each required section against `SPEC/templates/IMPLEMENTATION_PLAN_FORMAT.md` → **✍️ Authoring Depth Standard**, scaled to the story's classification:
  - **QA Candidate = Yes** → the rationale carries all five labels: Observable / Mechanism / Authz & preconditions / Edge & idempotency / Regression. A single clause or a missing label FAILS.
  - **User Flow** → role-differentiated: per-persona narratives (a paragraph each + an edge/error case); role-agnostic but user-facing: ONE deep User Journey with ≥4 interaction states (entry/load/render/interact/empty-error/responsive); infra/seed: the sentinel. A list of repeated personas on a single-actor story FAILS; a one-line journey or one-sentence persona narrative FAILS.
  - **System responses + error cases** → rows for happy + idempotent-repeat + unauthorized + wrong-state + empty/edge.
  - **Steps** → name the system mechanics at each step, not just UI clicks.
  - **Exempt (do NOT pad)**: single-actor sentinels and `QA Candidate = No` keep their lean forms.
  If any section FAILS, **rewrite it to depth and re-run the gate**. A story that fails the gate is NOT "written" — do not present it or advance to the next story until it passes. (The `aire lint` command applies these same checks deterministically.)
- [ ] **After writing each story** (and only after it passes the DEPTH GATE), prompt:
  ```
  ✅ Story N.M written: docs/plans/stories/epic-N-story-N.M-<slug>.md
  Next? 1) Continue to next story  2) Edit this story  3) Stop
  ```
  - (1) Continue → write the next story.
  - (2) Edit → apply edits to the just-written story, then re-prompt the same 3 options.
  - (3) Stop → halt; do not write further stories.
- [ ] 🔴 **NEVER batch multiple stories in a single response** — exceeds token limits. This forbids batching *multiple* stories; it does NOT license a thin story — every single story must still pass the 🚦 DEPTH GATE above.

### Phase 4: Tracker Sync (MANDATORY — Always ask, even if MCP not configured)

After user approves plan, check `docs/status.md` for the **Project Tracking** block:

- If `**Tracking**: Jira` → follow the **Jira path** below.
- If `**Tracking**: GitHub Projects` → follow the **GitHub path** (at the end of Phase 4).
- If `**Tracking`: Azure DevOps` → follow the **Azure DevOps path** (at the end of Phase 4).
- Otherwise → ask:
  ```
  ❓ Push stories to: 1) Jira   2) GitHub   3) Azure DevOps   4) Skip
  ```

#### Jira Path

#### 4.1 — Classify Stories by Origin

Scan all story files and split into two groups:
- **Jira-sourced stories**: Stories where `**Jira**:` is a real Jira ID (e.g., `PROJ-101`) — already exist in Jira
- **Local stories**: Stories where `**Jira**: LOCAL` — new, don't exist in Jira yet

```
📊 Story Origin Summary:

  🔗 Jira-sourced: [N] stories (already in Jira)
     [List: Story N.M → PROJ-101, Story N.M → PROJ-102, ...]

  🆕 Local: [M] stories (new — will be pushed to Jira)
     [List: Story N.M — [Title], Story N.M — [Title], ...]

Syncing to Jira...
```

#### 4.2 — Get Project Key

```
❓ Jira project key? (e.g., PROJ)
```

#### 4.3 — Sync Jira-Sourced Stories (Labels + fixVersion + wave-N Only)

For stories that already exist in Jira — **do NOT create duplicates**. Add labels, fixVersion, wave tag, and (when the wave is split across 2+ devs) dev-slot tag, then add a planning comment:

```
@atlassian-rovo For each existing Jira issue:
- Add labels:
    epic-N, story-N.M, wave-N (read `wave:` from dependency-graph.yml), cycle-N (if BUILDID set)
    dev:N (ONLY when the `assignments:` block splits this wave across 2+ devs — read it from
           dependency-graph.yml to find which dev slot owns this story; e.g. dev:1, dev:2, dev:3)
- Set `fixVersion` to `cycle-N` (if BUILDID set — e.g., cycle-1)
- Add comment:
    "Planned as Story N.M in AIRE implementation plan.
     BUILDID: CYCLE-N | Wave: N | Dev slot: N | Cycle: cycle-N
     Local file: docs/plans/stories/epic-N-story-N.M-slug.md"

Issues to update:
- PROJ-101 → labels: epic-1, story-1.1, wave-1, dev:1, cycle-1 | fixVersion: cycle-1
- PROJ-102 → labels: epic-1, story-1.2, wave-1, dev:2, cycle-1 | fixVersion: cycle-1
...
```

> **`dev:N` label is advisory** — devs may swap stories freely before starting. Its sole purpose is board visibility so the team can see at a glance which dev is picking up which wave stories.

#### 4.4 — Push Local Stories to Jira (Full Export)

For new stories that don't exist in Jira — create them:

1. **If BUILDID is set**: Ensure `fixVersion` `cycle-N` exists; create it if not:
   ```
   @atlassian-rovo Create version "cycle-[N]" in project [PROJECT_KEY]
   ```
2. Get assignees: `@atlassian-rovo list assignable users [PROJECT_KEY]`
3. Ask: `Assign to: 1) Auto-distribute 2) One person 3) Unassigned 4) Manual`
4. **Create ALL Epics first — capture and record each key before creating any story.**

   For each Epic N, check if the Epic already exists in Jira via search, then create or retrieve:
   ```
   @atlassian-rovo Search Jira [PROJECT_KEY] for issue with summary "Epic N: <Epic Name>" and type Epic
   ```
   - If found: record the existing key (e.g., `PROJ-200`) — do NOT create a duplicate.
   - If not found: create it:
     ```
     @atlassian-rovo Create Epic in [PROJECT_KEY]:
     - Summary: "Epic N: <Epic Name>"
     - Description: <epic objective from implementation-plan.md>
     - Labels: epic-N (if BUILDID set: also cycle-N)
     - fixVersion: cycle-N (only if BUILDID set)
     ```
     Record the returned issue key.

   After processing all epics, store the complete map:
   ```
   EPIC_KEY_MAP:
     Epic 1 → [key, e.g. PROJ-200]  (created / already existed)
     Epic 2 → [key, e.g. PROJ-201]
     ...
   ```
   **STOP after all epics are confirmed. Do NOT create any story until every epic key is recorded.**

   Verify before continuing:
   ```
   ✅ All epics confirmed in Jira:
      Epic 1 → PROJ-200
      Epic 2 → PROJ-201
      ...
   Proceeding to story creation...
   ```

   **BLOCKING — Epic Key Completeness Gate**:
   Before entering the story creation loop, assert EPIC_KEY_MAP contains a key for EVERY epic number
   referenced across all story files in `docs/plans/stories/`. If any Epic N is absent, STOP — do
   not create any story. Resolve the missing epic first (re-run the epic creation/retrieval step for
   Epic N), then re-run this gate.

   **GUARDRAIL — BLOCKING (per-story pre-push check)**:
   Before building the Jira payload for each story, assert ALL of the following. If any check fails, STOP and fix before proceeding to the next story:
   1. `wave:` is populated in `docs/plans/dependency-graph.yml` for this story (not null, not empty)
   2. BUILDID is set (`CYCLE-N` or `NO-CYCLE`) — never blank or absent from the story header
   3. The local story file `docs/plans/stories/epic-N-story-N.M-<slug>.md` exists on disk
   4. The description body Story Metadata section contains ALL THREE fields and none may be blank:
      - `**Wave**: W` — wave number from dependency-graph.yml
      - `**Cycle**: cycle-N` (or `NO-CYCLE` when no cycles configured) — build cycle ID
      - `**Local file**: docs/plans/stories/epic-N-story-N.M-slug.md` — path to local story
   5. Labels list includes `wave-N` AND (if BUILDID is set and ≠ NO-CYCLE) `cycle-N` — both in body AND as Jira labels; neither is optional
   6. `Epic Link / Parent` key is taken from EPIC_KEY_MAP — never guessed or assumed

5. For each new Story N.M, read the **full** story file `docs/plans/stories/epic-N-story-N.M-*.md` and create:
   ```
   @atlassian-rovo Create Story in [PROJECT_KEY]:
   - Summary: "Story N.M: <Story Title>"
   - Description (full body — read verbatim from story file).
     FORMAT CONTRACT — the `description` argument to `createJiraIssue` must be **Markdown**
     (the Rovo MCP converts Markdown → Jira ADF). Use Markdown headings (`##`) and bold
     (`**...**`) — NOT legacy Jira wiki-markup (`h2.`, `*...*`). Put REAL line breaks between
     sections; NEVER emit literal `\n` escape sequences, or Jira renders the body as plain text.

       ## Story Metadata
       **BUILDID**: CYCLE-N | **Epic**: N - <Name> | **ID**: N.M | **Wave**: W | **Cycle**: cycle-N
       **Local file**: docs/plans/stories/epic-N-story-N.M-slug.md

       ## User Reference
       <👤 User Reference section — plain-English description + AC bullets, verbatim from story file>

       ## Description
       <Story Description section — full text>

       h2. RBAC Enforcement
       <RBAC Enforcement block from 🤖 AI Agent Reference — the persona/permission/route table verbatim, OR "No role-differentiated access — single actor.">

       h2. System responses + error cases
       <Trigger/Response/Side-effect table from 🤖 AI Agent Reference — verbatim>

       h2. QA-observable behaviour
       <QA-observable behaviour bullets from 🤖 AI Agent Reference — omit only if QA Candidate = No>

       h2. Prerequisites
       ## Prerequisites
       <Prerequisites section — full list>

       ## Implementation Steps
       <Steps section — ALL numbered steps with code blocks, no truncation>

       ## Test Requirements
       <Tests section — ALL unit + manual test cases, no truncation>

       ## Out of Scope
       <OUT section — full list>

       ## Completion Evidence
       <Evidence section>
   - Acceptance Criteria field: <full AC list — every criterion as a checklist item>
   - Story Points: <points from story file or blank>
   - Labels: epic-N, story-N.M, wave-N (from dependency-graph.yml), cycle-N (if BUILDID set)
   - fixVersion: cycle-N (only if BUILDID set)
   - Epic Link / Parent: <key from EPIC_KEY_MAP for Epic N — NEVER use a guessed or assumed key>
     CRITICAL: Jira Cloud next-gen projects use "Parent" instead of "Epic Link". Try "Epic Link" first;
     if the field is rejected or unavailable, retry using "Parent". NEVER omit the Epic association.
   - Assignee: per user config
   ```

   After creating each story, immediately verify the Epic association was set:
   ```
   @atlassian-rovo Get Jira issue [STORY-KEY]: confirm "Epic Link" or "Parent" = EPIC_KEY_MAP[N]
   ```
   If the association is missing, update it before proceeding to the next story:
   ```
   @atlassian-rovo Edit Jira issue [STORY-KEY]: set "Epic Link" (or "Parent") = [EPIC_KEY_MAP[N]]
   ```

**CRITICAL Jira Fix Version Rule**: When stories have a BUILDID (e.g., CYCLE-1), the corresponding Jira `fixVersion` MUST be `cycle-1` (lowercase, hyphenated). If the version does not exist in the Jira project, create it first.

6. Show summary: updated issues, new issues created, fixVersion applied, wave labels applied per story

   **Post-Creation Audit (MANDATORY)**:
   After all stories are created, run JQL to find any in this batch missing Epic association:
   ```
   @atlassian-rovo Search Jira using JQL:
     project = [PROJECT_KEY] AND issueType = Story AND "Epic Link" is EMPTY AND created >= "-15m"
   ```
   For Jira Cloud next-gen projects, also try:
   ```
     project = [PROJECT_KEY] AND issueType = Story AND parent is EMPTY AND created >= "-15m"
   ```
   For any stories returned, immediately set their Epic Link / Parent to the correct EPIC_KEY_MAP key.
   Report: "N stories verified with Epic association; M stories corrected."

7. **MANDATORY — Update local story files with Jira IDs**:
   After Jira issues are created, go back and update the `**Jira**:` field in each local story file (`docs/plans/stories/epic-N-story-N.M-*.md`) with the actual Jira issue key returned from creation:
   - Before: `**Jira**: LOCAL`
   - After: `**Jira**: PROJ-NNN`

   This ensures full traceability between local story files and Jira issues. Do NOT skip this step.

---

#### GitHub Path

> **Rule for the agent: execute every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user. If 422 "already exists", skip and continue.**

**Step 1 — Read tracking context**

From `docs/status.md`: `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `RELEASE_FIELD_ID`, `PRIORITY_FIELD_ID`, `STORY_POINTS_FIELD_ID`.
From active cycle plan: `RELEASE_OPTION_ID_CYCLE_N`.

**Step 2 — Classify stories by origin**

Scan each `docs/plans/stories/epic-N-story-N.M-*.md`:
- **Already-linked**: header has `**GitHub**: #<number>` → **update** path
- **New**: header has `**GitHub**: LOCAL` or no GitHub field → **create** path

Print counts:

```
🔗 Already-linked: N stories (will update labels/milestone/project)
🆕 New:            M stories (will create fresh GitHub issues)
```

**Step 3 — Ensure `epic:N`, `cycle:N`, `wave:N`, and (if multi-dev) `dev:N` labels + Epic Milestones exist**

```bash
gh label create "epic:N" --color "6F42C1" --repo "ORG/REPO" --force --description "Epic N"
gh label create "cycle:N" --color "5319E7" --repo "ORG/REPO" --force

# Ensure wave labels — one per distinct wave in docs/plans/dependency-graph.yml:
gh label create "wave:N" --color "0E8A16" --repo "ORG/REPO" --force --description "Wave N — independent ready set"

# If the assignments block splits the wave across 2+ devs — one dev-slot label per dev:
# For each dev N in docs/plans/dependency-graph.yml assignments blocks:
gh label create "dev:N" --color "BFD4F2" --repo "ORG/REPO" --force --description "Dev slot N (parallel wave assignment — advisory)"

gh api repos/ORG/REPO/milestones --method POST \
  -f title="Epic N: <Epic Name>" \
  -f description="<objective>" \
  -f due_on="<YYYY-MM-DD>T23:59:59Z"
# If 422, fetch existing milestone number:
gh api "repos/ORG/REPO/milestones?state=all" --jq '.[] | select(.title=="Epic N: <Epic Name>") | .number'
```

**Step 4a — CREATE path (new local stories)**

> **⚠️ CRITICAL — two failure modes that have silently burned past runs:**
>
> 1. **`--milestone` takes the milestone TITLE STRING, not the integer number.** `gh issue create --milestone 1` fails with "could not resolve to a Milestone" and the issue is NOT created. Always pass the full title (e.g. `--milestone "Epic 1: Project Foundation"`). The integer number captured from Step 3 is only for the REST API, not for `gh issue create` / `gh issue edit`.
> 2. **Never swallow the output of `gh issue create` into a variable without verifying both the exit code and that the captured value is a URL matching `https://github.com/<owner>/<repo>/issues/<number>`.** Whatever shell the agent is running in, some wrappers route `gh`'s error text to the same capture stream as the URL, and a surrounding print/log statement can exit 0 even when the issue was never created. After every call, assert: (a) exit status is 0, and (b) captured output matches the issue-URL pattern. On mismatch, STOP the loop — do not keep creating stories on top of a silent failure.

For each new story, read the **full** story file `docs/plans/stories/epic-N-story-N.M-<slug>.md` and build the body from ALL its sections.

**GUARDRAIL — BLOCKING (per-story pre-push check)**:
Before calling `gh issue create`, assert ALL of the following. If any check fails, STOP and report — do not proceed to the next story:
1. `wave:` is populated in `docs/plans/dependency-graph.yml` for this story (not null, not empty)
2. BUILDID is set (`CYCLE-N` or `NO-CYCLE`) — never blank
3. The local story file exists on disk
4. The issue body (built above) contains `**Wave**: W`, `**Cycle**: cycle-N` (or `NO-CYCLE`), and `**Local file**: docs/plans/stories/...` in the Story Metadata section
5. The `--label` list includes `wave:<W>` and (if BUILDID is set and ≠ NO-CYCLE) `cycle:<N>`
6. The `--milestone` value is the full milestone title string (e.g. `"Epic N: <Epic Name>"`) — **never an integer**

Then:

```bash
gh issue create --repo "ORG/REPO" \
  --title "Story N.M: <Story Title>" \
  --body "$(cat <<'EOF'
## Story Metadata
**BUILDID**: CYCLE-N | **Epic**: N - <Epic Name> | **ID**: N.M | **Wave**: W | **Cycle**: cycle-N | **QA Candidate**: Yes/No
**Local file**: docs/plans/stories/epic-N-story-N.M-<slug>.md

## User Reference
<👤 User Reference section — plain-English description + AC bullets, verbatim from story file>

## Description
<Story Description — full text from story file>

## Acceptance Criteria
- [ ] <Criterion 1 from story file>
- [ ] <Criterion 2>
- [ ] <Criterion 3 — edge cases>
- [ ] <Criterion N — all criteria, no truncation>

## RBAC Enforcement
<RBAC Enforcement block from 🤖 AI Agent Reference — the persona/permission/route table verbatim, OR "No role-differentiated access — single actor.">

## System responses + error cases
<Trigger/Response/Side-effect table from 🤖 AI Agent Reference — verbatim>

## QA-observable behaviour
<QA-observable behaviour bullets from 🤖 AI Agent Reference — omit only if QA Candidate = No>

## Prerequisites
<Full prerequisites list from story file>

## Implementation Steps
<ALL numbered steps from story file, including code blocks>

1. <Step 1>
   ```lang
   <code>
   ```
2. <Step 2>
   ...

## Test Requirements
<ALL unit test cases and manual test cases from story file>

## Out of Scope
<Full OUT list from story file>

## Completion Evidence
<Evidence section from story file>
EOF
)" \
  --label "story" --label "epic:N" --label "cycle:<N>" --label "wave:<W>" --label "<size>" --label "P<priority>" \
  --milestone "Epic N: <Epic Name>"
```

**Verify before continuing to the next story.** Three checks, in whichever shell the agent is using:

1. The exit status of `gh issue create` is 0.
2. The captured output matches `^https://github\.com/[^/]+/[^/]+/issues/\d+$` — extract the trailing `\d+` → `ISSUE_NUMBER`.
3. **Content-parity check (BLOCKING)** — the FULL body landed (same content the Jira path pushes); shell quoting can silently drop sections even when the issue is created:
   ```bash
   gh issue view ISSUE_NUMBER --repo "ORG/REPO" --json body \
     --jq '.body | contains("## User Reference") and contains("## Acceptance Criteria") and contains("## RBAC Enforcement") and contains("## QA-observable behaviour") and contains("## Implementation Steps") and contains("BUILDID")'
   ```
   Must print `true`. If `false`, re-push the body once with `gh issue edit ISSUE_NUMBER --repo "ORG/REPO" --body "<same full body>"` and re-verify; still `false` → STOP.

If any check fails (beyond the single retry in check 3), STOP the loop and report the captured output verbatim.

Then attach to the Project and set fields (same as greenfield Step 5):

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

**MANDATORY — Write issue number back into the local story file**:
After each GitHub issue is created, update the story file header in `docs/plans/stories/epic-N-story-N.M-<slug>.md`:
- Before: `**BUILDID**: CYCLE-N | **Jira**: LOCAL | **Epic**: N - <NAME> | **ID**: N.M | **Date**: YYYY-MM-DD`
- After:  `**BUILDID**: CYCLE-N | **GitHub**: #ISSUE_NUMBER | **Epic**: N - <NAME> | **ID**: N.M | **Date**: YYYY-MM-DD`

This ensures full traceability between local story files and GitHub issues. Do NOT skip this step.

**Step 4b — UPDATE path (already-linked stories)**

For each story with an existing `**GitHub**: #N`:

```bash
# Add labels + cycle + wave + dev-slot (if multi-dev) + assign milestone
gh issue edit N --repo "ORG/REPO" \
  --add-label "cycle:<N>" --add-label "epic:N" --add-label "wave:<W>" \
  --milestone "Epic N: <Epic Name>"

# If the assignments block splits the wave across 2+ devs — also add dev-slot label:
gh issue edit N --repo "ORG/REPO" --add-label "dev:<slot>"

# Add comment
gh issue comment N --repo "ORG/REPO" \
  --body "Planned as Story N.M in AIRE implementation plan (BUILDID: CYCLE-N | Wave: W | Dev slot: N)"
```

If the issue is not yet on the project, add it + set Release field (same GraphQL as Step 4a).

**Step 5 — Summary**

Print: updated issues, new issues created, project URL, Release Plan option tagged.

---

#### Azure DevOps Path

> **Rule for the agent: execute every `az boards` command yourself via the Bash tool. Do NOT ask the user. If a command fails with "already exists", skip and continue.**

**Step 1 — Read tracking context**

From `docs/status.md`: `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH`.
From active cycle plan: `ITERATION_PATH_CYCLE_N` (if cycles exist).

**Step 2 — Classify stories by origin**

Scan each `docs/plans/stories/epic-N-story-N.M-*.md`:
- **Already-linked**: header has `**AzureDevOps**: #<number>` → **update** path (add tags + iteration only)
- **New**: header has `**AzureDevOps**: LOCAL` or no AzureDevOps field → **create** path

Print counts:
```
🔗 Already-linked: N stories (will update tags/iteration)
🆕 New:            M stories (will create fresh work items)
```

**Step 3 — CREATE path (new stories)**

**Step 3a — Create ALL Epics first, then gate before creating any story.**

For each Epic N referenced by a new story, search for an existing Epic work item to avoid duplicates, then create or retrieve:

```bash
# Search for existing epic first — skip creation if found
az boards work-item query --wiql \
  "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject]='{PROJECT}' AND [System.WorkItemType]='Epic' AND [System.Title]='Epic N: <Epic Name>'" \
  --project "{PROJECT}" --query "[0].id" -o tsv
```

- If found: record the existing numeric ID — do NOT create a duplicate.
- If not found: create it:

```bash
EPIC_WI_ID_N=$(az boards work-item create \
  --type "Epic" \
  --title "Epic N: <Epic Name>" \
  --description "<epic objective from implementation-plan.md>" \
  --project "{PROJECT}" \
  --fields "System.Tags=ai-generated;epic-N$([ -n "$BUILDID" ] && echo ";cycle-<N>")" \
  --query "id" -o tsv)
```

After processing all epics, store the complete map and assert every entry is a valid numeric ID:

```
EPIC_WI_ID_MAP:
  Epic 1 → [EPIC_WI_ID_1]
  Epic 2 → [EPIC_WI_ID_2]
  ...
```

**BLOCKING — Epic WI ID Completeness Gate**:
Before entering the story creation loop, assert every Epic N referenced across `docs/plans/stories/` has a valid numeric ID in EPIC_WI_ID_MAP. If any entry is missing, zero, or empty, STOP — do not create any story. Re-run Step 3a for the failed epic, then re-run this gate.

```
✅ All epics confirmed in Azure DevOps:
   Epic 1 → 101
   Epic 2 → 102
   ...
Proceeding to story creation...
```

**Step 3b — Create User Story work items.**

For each new story, read the **full** story file `docs/plans/stories/epic-N-story-N.M-<slug>.md` and build the description HTML from ALL its sections.

**GUARDRAIL — BLOCKING (per-story pre-push check)**:
Before calling `az boards work-item create` for each story, assert ALL of the following. If any check fails, STOP and fix before proceeding to the next story:
1. `wave:` is populated in `docs/plans/dependency-graph.yml` for this story (not null, not empty)
2. BUILDID is set (`CYCLE-N` or `NO-CYCLE`) — never blank (or absent when cycles were not configured)
3. The local story file exists on disk
4. The HTML description (built above) contains `Wave: W`, `Cycle: cycle-N` (or `NO-CYCLE`), and `Local file: docs/plans/stories/...` in the Story Metadata section
5. The `System.Tags` string includes `wave-<W>` and (if BUILDID is set and ≠ NO-CYCLE) `cycle-<N>`
6. `EPIC_WI_ID_N` for this story's epic is a valid numeric ID from EPIC_WI_ID_MAP — never zero, null, or empty string

Then:

```bash
# Create User Story
STORY_WI_ID=$(az boards work-item create \
  --type "User Story" \
  --title "Story N.M: <Story Title>" \
  --description "<HTML body — see template below>" \
  --project "{PROJECT}" \
  --fields "Microsoft.VSTS.Common.AcceptanceCriteria=<AC as HTML checklist — see template below>" \
           "Microsoft.VSTS.Scheduling.StoryPoints=<points from story file or blank>" \
           "Microsoft.VSTS.Common.Priority=2" \
           "System.Tags=ai-generated;epic-N;story-N.M;cycle-<N>;wave-<W>" \
  --query "id" -o tsv)

# Link to Epic (parent-child)
az boards work-item relation add \
  --id "$STORY_WI_ID" \
  --relation-type "System.LinkTypes.Hierarchy-Reverse" \
  --target-id "$EPIC_WI_ID_N"

# Assign to iteration
az boards work-item update \
  --id "$STORY_WI_ID" \
  --iteration "{ITERATION_PATH_CYCLE_N}" \
  --project "{PROJECT}"
```

**VERIFY CONTENT LANDED (BLOCKING — per story, before creating the next one)**: the work item must carry the SAME full content as the Jira path (Description incl. User Reference + BUILDID metadata, AC checklist). Inline `az` quoting can silently truncate these even when creation and epic-linking succeed:

```bash
az boards work-item show --id "$STORY_WI_ID" --project "{PROJECT}" -o json --query \
  "{descLen: length(fields.\"System.Description\"), acLen: length(fields.\"Microsoft.VSTS.Common.AcceptanceCriteria\"), userRef: contains(fields.\"System.Description\", 'User Reference'), rbac: contains(fields.\"System.Description\", 'RBAC Enforcement'), qaObs: contains(fields.\"System.Description\", 'QA-observable behaviour'), buildId: contains(fields.\"System.Description\", 'BUILDID')}"
```

Assert: `userRef` = `true`, `rbac` = `true`, `qaObs` = `true`, `buildId` = `true`, `acLen` > 0, and `descLen` roughly matches the HTML you built (a tiny `descLen` = truncation). A query error (null field) counts as FAIL. On failure, re-push once — `az boards work-item update --id "$STORY_WI_ID" --project "{PROJECT}" --description "<same full HTML body>" --fields "Microsoft.VSTS.Common.AcceptanceCriteria=<same AC HTML>"` — and re-verify; still failing → STOP and report the output verbatim. Do NOT proceed to the next story on top of a content-less work item.

**⚠️ Command-line-too-long fallback**: if any `az boards` call fails because the full HTML Description/AC exceeds the command-line length limit, push those two fields via the Azure DevOps REST API instead — file-based JSON payload bypasses all CLI length limits:

```bash
# patch.json (temp — delete after the loop, never commit):
# [{"op":"add","path":"/fields/System.Description","value":"<full HTML body>"},
#  {"op":"add","path":"/fields/Microsoft.VSTS.Common.AcceptanceCriteria","value":"<AC HTML checklist>"}]
az rest --method patch \
  --uri "{ORG_URL}/{PROJECT}/_apis/wit/workitems/${STORY_WI_ID}?api-version=7.1" \
  --resource "499b84ac-1321-37b0-8456-7c123481e4b9" \
  --headers "Content-Type=application/json-patch+json" \
  --body "@patch.json"
```

Then re-run the VERIFY query above — the same asserts apply.

**Description HTML template** (build from story file — include ALL sections, no truncation):

```html
<h2>Story Metadata</h2>
<p><strong>BUILDID</strong>: CYCLE-N | <strong>Epic</strong>: N - Epic Name | <strong>ID</strong>: N.M | <strong>Wave</strong>: W | <strong>Cycle</strong>: cycle-N | <strong>QA Candidate</strong>: Yes/No</p>
<p>Local file: docs/plans/stories/epic-N-story-N.M-slug.md</p>

<h2>User Reference</h2>
<p>[👤 User Reference section — plain-English description + AC bullets, verbatim from story file]</p>

<h2>Description</h2>
<p>[Full Story Description — verbatim from story file]</p>

<h2>RBAC Enforcement</h2>
<p>[RBAC Enforcement block from 🤖 AI Agent Reference — the persona/permission/route table as HTML, OR "No role-differentiated access — single actor."]</p>

<h2>System responses + error cases</h2>
<p>[Trigger/Response/Side-effect table from 🤖 AI Agent Reference as HTML]</p>

<h2>QA-observable behaviour</h2>
<p>[QA-observable behaviour bullets from 🤖 AI Agent Reference — omit only if QA Candidate = No]</p>

<h2>Prerequisites</h2>
<ul>
  <li>[Prerequisite 1]</li>
  <li>[Prerequisite N]</li>
</ul>

<h2>Implementation Steps</h2>
<ol>
  <li>[Step 1 — full text including code]</li>
  <li>[Step 2]</li>
  ... (ALL steps, no truncation)
</ol>

<h2>Test Requirements</h2>
<p>[All unit test cases and manual test cases from story file]</p>

<h2>Out of Scope</h2>
<ul>
  <li>[OUT item 1]</li>
</ul>

<h2>Completion Evidence</h2>
<p>[Evidence section from story file]</p>
```

**Acceptance Criteria HTML template** (field `Microsoft.VSTS.Common.AcceptanceCriteria`):

```html
<ul>
  <li><input type="checkbox" disabled> [Criterion 1 from story file]</li>
  <li><input type="checkbox" disabled> [Criterion 2]</li>
  <li><input type="checkbox" disabled> [Criterion 3 — edge cases]</li>
  ... (ALL criteria, no truncation)
</ul>
```

**Tag rules**:
- `ai-generated` — all AI-generated items
- `epic-N` — epic identifier
- `story-N.M` — story identifier
- `cycle-<N>` — build cycle (if BUILDID set, e.g., `cycle-1`)
- `wave-<W>` — wave number from `docs/plans/dependency-graph.yml`
- `dev-N` — dev slot from `assignments:` block (ONLY when the wave is split across 2+ devs; advisory — devs may swap)

**MANDATORY — Write work item ID back into the local story file**:
After each Azure DevOps work item is created, update the story file header in `docs/plans/stories/epic-N-story-N.M-<slug>.md`:
- Before: `**BUILDID**: CYCLE-N | **Jira**: LOCAL | **Epic**: N - <NAME> | **ID**: N.M | **Date**: YYYY-MM-DD`
- After:  `**BUILDID**: CYCLE-N | **AzureDevOps**: #{STORY_WI_ID} | **Epic**: N - <NAME> | **ID**: N.M | **Date**: YYYY-MM-DD`

This ensures full traceability between local story files and Azure DevOps work items. Do NOT skip this step.

**Step 4 — UPDATE path (already-linked stories)**

For each story with an existing `**AzureDevOps**: #N`:

```bash
# Update tags and iteration only — do NOT create duplicate work items
# If the assignments block splits the wave across 2+ devs, append dev-N tag (read dev slot from dependency-graph.yml assignments)
az boards work-item update \
  --id N \
  --fields "System.Tags=ai-generated;epic-N;story-N.M;cycle-<N>;wave-<W>;dev-<slot>" \
  --iteration "{ITERATION_PATH_CYCLE_N}" \
  --project "{PROJECT}"

# Add planning comment with full traceability
az boards work-item update \
  --id N \
  --discussion "Planned as Story N.M in AIRE implementation plan.
BUILDID: CYCLE-N | Wave: W | Dev slot: N (parallel, advisory) | Cycle: cycle-N
Local file: docs/plans/stories/epic-N-story-N.M-slug.md" \
  --project "{PROJECT}"
```

> Omit `dev-<slot>` tag for solo (single-dev) plans.

**Step 5 — Summary**

Print: updated work items, new work items created, board URL, iteration path tagged.

---

### Phase 5: Update docs/status.md (MANDATORY)

- [ ] **Follow `SPEC/templates/STATUS_FORMAT.md`** — all fields/sections below must match that format
- [ ] Update `docs/status.md`:
  - **Updated By** → `PRODUCT_OWNER`
  - **Progress Summary** → Set "Implementation Plan" row to `✅ Done`, evidence: `docs/plans/implementation-plan.md`
  - **Current Step Details** → List all epics and story counts
  - **Completed Steps** → Add implementation plan with story count
  - **Upcoming** → First story to implement: `aire-dev-implement [N.M]`
  - **Build Cycles** table → Set **Stories** column to `0/[total]` for each cycle (count stories per BUILDID)
  - **Story Tracker** → Create and update table with one row per story (BUILDID, Story number, Title, Start: `—`, End: `—`)
  - **Agent Activity** → Update PRODUCT_OWNER to Idle

---

## Output

**Index** (`docs/plans/implementation-plan.md`): epic titles + story titles + one-line objectives


**QA Manual Testing Groups** — append as the last section in `implementation-plan.md`. Groups are ordered by **first testable milestone**, by epic. Every story appears in exactly one group — backend/API stories are listed as prerequisites (marked `[backend]`) inside the group that makes them manually testable, so QA can see the full picture and knows no stories were dropped.

Format:
```
## QA Manual Testing Groups

### Epic N: [Name]

**Group 1** — Stories: N.1 `[backend]`, N.2 `[backend]`, N.3
[Paragraph: once all stories in this group are done, QA can test X end-to-end. Mention what the backend stories provide (API, DB layer) and what the UI stories unlock. Describe the full user flow, what to verify, and any edge cases.]

**Group 2** — Stories: N.4, N.5
[Paragraph describing the combined test scenario.]
```

Rules:
- **Every story must appear in exactly one group** — no story is silently omitted
- **Groups never cross epic boundaries** — all stories in a group belong to the same epic
- Within an epic that has UI stories, backend/API stories are listed with `[backend]` alongside the UI stories they enable
- Keep descriptions concise — one paragraph per group; explain what the backend stories enable and what QA can verify end-to-end

**Story files** (`docs/plans/stories/epic-N-story-N.M-Story-Title.md`):
- Naming always `epic-N-story-N.M-Story-Title.md` — no build prefix in filename
- BUILDID tracked inside story header
- Written **one at a time** — never all in one response

---

## Mandatory Rules

Every story MUST include:
- Tests WITH code (never postponed)
- Run tests after EVERY story
- Update status with evidence
- Self-review document
- Epic review at epic end

---

## Rules

- 🔴 Measurable success criteria
- 🔴 Explicit scope boundaries
- 🔴 Reference existing patterns from deep-dive
- 🔴 NEVER write all stories in one response — exceeds token limits (one story per response, always)
- 🔴 After each story, ask: 1) Continue 2) Edit this story 3) Stop
- 🔴 Vertical slices only — no horizontal/layer-based epics

---

**Type "proceed" to generate implementation plan.**

---

## Mandatory Next Steps to suggest user

**You are here → `aire-brownfield-plan`**

| # | Next Command | Purpose |
|---|-------------|---------|
| ▶️ | `aire-dev-implement` | Implement each story from the plan |


