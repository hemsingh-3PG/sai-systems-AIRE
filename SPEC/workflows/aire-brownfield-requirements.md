---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Brownfield - Requirements Definition. Define requirements from Jira active sprint, user input, or existing docs. Checks story completeness and generates docs/requirements.md.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---
# Brownfield - Requirements Definition

## Agent

**ANALYST_PM_BROWNFIELD** 

## Before Starting

1. Read `SPEC/agents/AIRE_ANALYST_PM_BROWNFIELD.md`
2. Read `SPEC/rulebooks/aire-brownfield-rulebook.md`
3. **MANDATORY**: Verify brownfield analysis outputs exist (see Prerequisites below)
---

## Prerequisites (MUST be completed before this workflow)

1. **System Overview must exist**: Check if `docs/architecture/current/00-system-overview.md` exist
   - If not found → tell user to run `aire-brownfield-inspect` first
2. **Deep-Dive analysis must exist**: Check if `docs/architecture/current/01-*-deep-dive.md` exist
   - If not found → tell user to run `aire-brownfield-deep-dive` first

**Check both before proceeding**:

```
Checking prerequisites...

[If both exist]
✅ Prerequisites found:
   ✓ System overview: docs/architecture/current/00-system-overview.md
   ✓ Deep-dive: docs/architecture/current/[files found]

Proceeding to requirements definition...

[If either is missing]
⚠️ Missing Required Analysis

[If system overview missing]
❌ docs/architecture/current/00-system-overview.md not found
   → Please run: aire-brownfield-inspect

[If deep-dive missing]
❌ No deep-dive analysis found in docs/architecture/current/
   → Please run: aire-brownfield-deep-dive

Run the missing workflows first, then return here.
```
---
## Reference Document Adherence (CRITICAL)

**ALWAYS check `SPEC/references/` first before any workflow. Reference documents represent approved decisions and are the absolute source of truth. Treat them as requirements, not suggestions.**

| Rule | Description |
|------|-------------|
| 🔴 **STRICTLY FOLLOW** | Execute the vision exactly as specified. |
| 🔴 **NO CHANGES** | Do not suggest modifications to existing feature definitions. |
| 🔴 **NO ALTERNATIVES** | Do not propose alternative approaches unless explicitly asked. |
| 🔴 **CLARIFY ONLY** | Only ask about genuinely ambiguous points. |
| 🔴 **IMPLEMENT, DON'T REDESIGN**| Your job is execution, not re-architecture. |
| 🔴 **NEVER SKIP FILES** | Never skip `.docx`/`.pdf` files — use `aire read` or ask the user to run it. |
| 🔴 **READ ALL FIRST** | NEVER proceed without reading ALL references. |

---

## STEP 0: Reference Check (MANDATORY FIRST)

**Execute these steps sequentially before gathering new requirements:**

- [ ] **List Directory:** List all files in `SPEC/references/`.
- [ ] **Process Documents:** - For `.docx`/`.pdf`: Run `aire read SPEC/references/<file>` (if it fails, ask the user to run it in CMD and paste the output).
  - For `.md`/`.txt`: Read directly.
- [ ] **Process Designs:** View images/designs and document them in `docs/requirements.md` under the "Design References" section, noting key UI/UX elements.
- [ ] **Process Builds (`SPEC/references/builds/`):**
  - Run `aire read` for `.docx`/`.pdf`; read others directly.
  - **If builds are found**, infer the sequence from filenames (e.g., numeric/alpha prefixes).
  - Present to the user: `📦 Found [N] builds: [list with 1-line summaries]. Suggested order: Build 1→2→N. Confirm or reorder?`
  - Record the confirmed sequence in `docs/requirements.md` under "Build Sequence". *(Note: This sequence will drive epic/story grouping in implementation planning).*
- [ ] **Check Synced Helix Context (`docs/helix/`):** If `docs/helix/INDEX.md` exists (synced by `aire-helix-sync`), read it and pull the relevant `docs/helix/documents/` files as prior solution context. Treat as read-only — never edit synced files; if `synced_at` looks stale, suggest re-running `aire-helix-sync`.
- [ ] **Confirm Status:** Confirm to the user exactly what was found and successfully read before moving to Phase 1.
---

## STEP 1: Requirements Source

**Ask the user**:

```
📋 How would you like to define requirements?

[J] I have stories in Jira — pull from active sprint to generate requirements
[G] I have issues in GitHub — pull from a repo / project board to generate requirements
[A] I have stories in Azure DevOps — pull from active sprint to generate requirements
[L] I want to describe what we're building from scratch

Choose J, G, A, or L:
```

---

## PATH J: Import from Jira Active Sprint → Generate Requirements

### J.1 — Fetch Stories from Active Sprint

Ask user:
```
❓ Jira project key? (e.g., PROJ)
```

**Step 1 — Fetch stories from the active sprint that are NOT done:**
```
@atlassian-rovo Search issues using JQL:
  project = [PROJECT_KEY] AND sprint in openSprints() AND status in ("To Do", "Backlog", "In Progress", "Open", "Selected for Development", "Ready for Development", "Idea")
  ORDER BY priority DESC, created ASC
```

If no active sprint is found, fall back to fetching from the backlog:
```
@atlassian-rovo Search issues using JQL:
  project = [PROJECT_KEY] AND sprint is EMPTY AND status in ("To Do", "Backlog", "Open", "Idea")
  ORDER BY priority DESC, created ASC
```

**Step 2 — Filter out non-technical stories:**

Discard stories that are purely discovery, research, or non-implementation work (e.g., "Conduct user interviews", "Market research", "Define KPIs"). Only keep stories that result in code changes — features, enhancements, bug fixes, integrations, migrations, refactors.

Report:
```
📊 Active Sprint: [Sprint Name]
   Found [N] technical stories (excluding Done/Closed and non-technical):

| # | ID | Title | Priority | Status | Epic |
|---|-----|-------|----------|--------|------|
| 1 | PROJ-101 | [title] | High | To Do | [epic] |
| 2 | PROJ-102 | [title] | Medium | In Progress | [epic] |
| 3 | PROJ-103 | [title] | Medium | Backlog | [epic] |
...

[If any were discarded]
⏭️ Skipped [M] non-technical stories:
   - PROJ-104: "Conduct stakeholder interviews" (discovery)
   - PROJ-105: "Define success metrics" (planning)

Would you like to:
  A) Use all [N] technical stories
  B) Select specific stories (provide IDs)
  C) Also include backlog stories not in any sprint
```

### J.2 — Fetch Full Details & Check Completeness

For each selected story:
1. Use `@atlassian-rovo get issue [STORY-ID]` to fetch full content
2. Extract: Story ID, Title, Description, Acceptance Criteria, Priority, Labels, Epic, Out of Scope

**Check Story Completeness:**

A Jira story in the real world typically only has a title, description, acceptance criteria, and out-of-scope notes. That is all that is required from Jira. The agent derives everything else from the codebase.

**A story is COMPLETE if it has ALL THREE of**:
- [ ] **Description** — clear objective (what and why, even if brief)
- [ ] **Acceptance Criteria** — at least 1-2 items (even if vague or partial)
- [ ] **Out of Scope** — at least one explicit exclusion

**A story is INCOMPLETE if ANY of the three above is missing or too vague to act on** (e.g., only a title with no description, or AC says "it should work" with no specifics, or no out of scope at all).

Report to user:

```
📊 Story Completeness Analysis:

[For each story]
Story [JIRA-ID]: [Title]
Status: ✅ COMPLETE / ⚠️ INCOMPLETE
Missing: [Description / Acceptance Criteria / Out of Scope — whichever apply]
```

### J.3 — Complete Incomplete Stories

For each **INCOMPLETE** story:

1. Read `docs/architecture/current/00-system-overview.md`
2. Read all `docs/architecture/current/01-*-deep-dive.md` files
3. Ask clarifying questions **only about the missing Description / AC / Out of Scope** — ground each question in what you learned from the architecture:

```
❓ Clarifying Questions for [JIRA-ID]: [Title]

This story is missing: [Description / Acceptance Criteria / Out of Scope].
Based on my analysis of your codebase, I need to understand:

[If Description missing or vague:]
1. What is the goal of this story? What should it do and why?
   (e.g., based on the [module] I found in the codebase, is this about [X]?)

[If AC missing or too vague:]
2. What does "done" look like? Give me 2-3 specific, testable outcomes.
   (e.g., "The [LeadsPage] exports a CSV when the button is clicked" — that kind of specificity)

[If Out of Scope missing:]
3. What should this story NOT include?
   (e.g., I see [related feature] exists — should that be excluded here?)

Please answer these so I can complete the story.
```

4. After user answers, all three fields are now known for that story
5. Repeat for ALL incomplete stories before proceeding
6. **Roles & Permissions**: across ALL stories (complete and just-completed), infer which user roles/permissions they reference. Cross-check against roles already enforced in `docs/architecture/current/01-*-deep-dive.md`. For any role implied but not confirmed, ask the user one grounded question. Mark each role `Existing` (already in the codebase) or `New` (introduced by this work) — this seeds the Roles & Permissions Matrix written in J.5.

### J.4 — Check References Folder

Before generating requirements, scan `SPEC/references/` for relevant assets:

1. List all files in `SPEC/references/` (images, PDFs, docx, etc.)
2. If files found, ask the user:

```
📎 Reference files found in SPEC/references/:
   - SPEC/references/[file1] ([type])
   - SPEC/references/[file2] ([type])
   ...

Are any of these relevant to the stories being planned?

[Y] Yes — tell me which ones map to which stories
[N] No — skip references
```

3. If user says Yes: note file-to-story mappings for inclusion in requirements doc
4. If `SPEC/references/` is empty or does not exist: skip silently

### J.5 — Synthesize into Requirements

1. Read `docs/architecture/current/00-system-overview.md` and all deep-dive files for system context
2. Using ALL stories (now complete after J.3), synthesize into `docs/requirements.md`:

```markdown
# Requirements — [Project Name]

**Type**: Brownfield Enhancement
**Date**: [YYYY-MM-DD]
**Source**: Jira project [PROJECT_KEY] — Active Sprint: [Sprint Name] — [N] stories
**Author**: ANALYST_PM_BROWNFIELD

---

## Project Overview

[Synthesized from all story descriptions — what is the overall goal of this body of work]

## Current System Context

**Architecture**: [from 00-system-overview.md]
**Affected Modules**: [list of modules these stories touch]
**Existing Patterns**: [from deep-dive — patterns to follow]

## Roles & Permissions Matrix

> Canonical role registry. Every story's User Flow by Persona and RBAC Enforcement block
> references these role names + permission keys verbatim. Need a role not listed? Add it here first.
> `Origin` = `Existing` (already enforced in the codebase, per deep-dive) or `New` (introduced by this work).

| Role (canonical) | Description | Key Permissions (allow) | Explicitly Denied | Auth Source | Origin |
|------------------|-------------|-------------------------|-------------------|-------------|--------|
| Admin  | [who] | users:manage, reports:view-all | delete audit logs | [auth source] | Existing |
| Editor | [who] | records:create, records:edit-own | approve, manage users | [auth source] | Existing |
| Viewer | [who] | read-only permitted records | any write | [auth source] | New |

**Permission keys** (stable IDs referenced by every story's RBAC Enforcement block):
`users:manage`, `reports:view-all`, `records:create`, ...

**Notes**: reuse roles already enforced in the codebase rather than inventing parallel ones; the Auth Source must match the architecture authorization model. _Single-actor change?_ Record one row + the note "No role variation — single actor."

## Jira Stories Imported

| # | Jira ID | Title | Priority | Status | Epic |
|---|---------|-------|----------|--------|------|
| 1 | PROJ-101 | [title] | High | To Do | [epic] |
| 2 | PROJ-102 | [title] | Medium | In Progress | [epic] |
...

## Functional Requirements

[Grouped by theme/epic — extracted from story descriptions and ACs]

### [Theme 1 — e.g., User Management]
- [Requirement from PROJ-101] (PROJ-101)
- [Requirement from PROJ-102] (PROJ-102)

### [Theme 2 — e.g., Reporting]
- [Requirement from PROJ-103] (PROJ-103)

## Success Criteria (Measurable)

[Extracted from acceptance criteria across all stories]

## Failure Criteria (Explicit)

[What constitutes failure — regression risks to existing functionality]

## Technical Constraints

[From architecture docs + story descriptions]

## Quality Gates

[Aligned with existing test infrastructure from deep-dive]

## Scope

### IN Scope
[All features covered by the imported stories]

### OUT of Scope
[Anything explicitly excluded in story out-of-scope fields]

### IMPACT Scope (indirect)
[Modules that may be affected by changes but are not directly modified]

## Affected Modules

[From architecture analysis — which modules these stories touch]

## Existing Patterns to Follow

[Extracted from deep-dive — patterns the implementation must adhere to]

## Reference Files

[If any reference files were mapped in J.4]
- `SPEC/references/[file]` — relevant to [JIRA-ID]: [description]
```

3. Present to user for approval:
```
✅ docs/requirements.md generated from [N] Jira stories (Active Sprint: [Sprint Name]).

📄 Review the requirements document and confirm:
  A) Approved
  B) Edit needed — I'll update specific sections
```

### J.6 — Update docs/status.md

- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "Requirements" row to `✅ Done`, evidence: `docs/requirements.md`

---

## PATH G: Import from GitHub Issues → Generate Requirements

> **Prerequisite**: the user must have the GitHub CLI installed and authenticated. If `gh --version` or `gh auth status` fails, stop and tell the user: "Install the GitHub CLI from https://cli.github.com/ and run `gh auth login -s repo,project,read:org` before retrying."

### G.1 — Fetch Issues from the Repo / Project

Ask user:
```
❓ GitHub repo URL (e.g., https://github.com/ORG/REPO)?
   Optional: also paste the Project URL if you want to scope to a specific board
   (e.g., https://github.com/orgs/ORG/projects/N or https://github.com/users/USER/projects/N).
```

Parse the URL → `ORG`, `REPO`. If a project URL was given, also capture `PROJECT_OWNER` and `PROJECT_NUMBER`.

**Step 1 — Fetch open, non-done issues:**

If a Project was provided, prefer items where `Status` is **not** `Done` and is **not** `Blocked`:

```bash
gh project item-list PROJECT_NUMBER --owner "PROJECT_OWNER" --format json \
  --jq '.items[] | select(.content.type=="Issue") | select((.status // "") | test("Done|Blocked")|not) | {number: .content.number, title: .content.title, url: .content.url, labels: .content.labels, status: .status, milestone: .content.milestone}'
```

Otherwise (repo-only, no project):

```bash
gh issue list --repo "ORG/REPO" --state open --limit 200 \
  --json number,title,url,labels,milestone,assignees,body
```

**Step 2 — Filter out non-technical issues:**

Discard issues that are purely discovery, research, planning, or meta — same rule as Jira (only keep things that result in code changes). Bugs, features, enhancements, integrations, migrations, refactors → keep. "Conduct user interviews", "Define KPIs", "Write RFC" → drop.

Report:
```
📊 Source: GitHub repo ORG/REPO[ — Project #N "<title>"]
   Found [N] technical issues (excluding Done/Closed and non-technical):

| # | Issue | Title | Labels | Status | Milestone |
|---|-------|-------|--------|--------|-----------|
| 1 | #101  | [title] | story, P1-high | Sprint Ready | Epic 1: ... |
| 2 | #102  | [title] | bug, P2-medium | In Development | Epic 1: ... |
...

[If any were discarded]
⏭️ Skipped [M] non-technical issues:
   - #104: "Conduct stakeholder interviews" (discovery)
   - #105: "Define success metrics" (planning)

Would you like to:
  A) Use all [N] technical issues
  B) Select specific issues (provide #numbers)
  C) Also include closed issues from the last 30 days
```

### G.2 — Fetch Full Details & Check Completeness

For each selected issue, fetch the body:

```bash
gh issue view ISSUE_NUMBER --repo "ORG/REPO" \
  --json number,title,body,labels,milestone,assignees,state,url
```

Extract: Issue number, Title, Description (from body), Acceptance Criteria (from body — usually under an `## Acceptance Criteria` heading or checkbox list), Labels, Milestone, Out of Scope (from body — usually under `## Out of Scope`).

**Check Issue Completeness:**

A GitHub issue typically only has a title, description, acceptance criteria, and out-of-scope notes. That is all that is required from GitHub. The agent derives everything else from the codebase.

**An issue is COMPLETE if it has ALL THREE of**:
- [ ] **Description** — clear objective (what and why, even if brief)
- [ ] **Acceptance Criteria** — at least 1-2 items (checkboxes or bullets)
- [ ] **Out of Scope** — at least one explicit exclusion

**An issue is INCOMPLETE if ANY of the three above is missing or too vague to act on**.

Report to user using the same `📊 Story Completeness Analysis` format as J.2, substituting `Issue #N` for `Story [JIRA-ID]`.

### G.3 — Complete Incomplete Issues

Same procedure as J.3 — read architecture docs, ask the user clarifying questions grounded in the codebase, only about the missing Description / AC / Out of Scope. After the user answers, all three fields are known. Repeat for every incomplete issue before proceeding.

### G.4 — Check References Folder

Same as J.4 — scan `SPEC/references/` and ask the user which files map to which issues. Skip silently if the folder is empty.

### G.5 — Synthesize into Requirements

Generate `docs/requirements.md` using the same template as J.5, with these substitutions:

- `**Source**`: `GitHub repo ORG/REPO[ — Project #N "<title>"] — [N] issues`
- `## Jira Stories Imported` → `## GitHub Issues Imported`
- Columns: `# | Issue | Title | Labels | Status | Milestone`
- Per-requirement citations use `(#101)` instead of `(PROJ-101)`

Present to user for approval (same A/B prompt as J.5).

### G.6 — Update docs/status.md

- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "Requirements" row to `✅ Done`, evidence: `docs/requirements.md`

---

## PATH A: Import from Azure DevOps Active Sprint → Generate Requirements

> **Prerequisite**: the user must have the Azure CLI installed and authenticated. If `az --version` or `az devops configure --list` fails, stop and tell the user: "Install the Azure CLI from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli and run `az login` before retrying."

### A.1 — Connect and Fetch Stories from Active Sprint

Ask user:
```
❓ Azure DevOps organization URL (e.g., https://dev.azure.com/my-org)?
❓ Azure DevOps project name (e.g., MyProject)?
❓ Iteration path (Sprint) to import from (e.g., MyProject\Sprint 1)?
   Or type 'active' to query the current team's active sprint.
```

Set CLI defaults and query work items:

```bash
az devops configure --defaults organization="{ORG_URL}" project="{PROJECT}"

az boards query \
  --wiql "SELECT [System.Id],[System.Title],[System.Description],[System.State],[Microsoft.VSTS.Common.Priority],[System.Tags],[System.IterationPath],[Microsoft.VSTS.Common.AcceptanceCriteria] FROM WorkItems WHERE [System.TeamProject] = '{PROJECT}' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] = '{ITERATION_PATH}' AND [System.State] NOT IN ('Closed','Resolved','Done') ORDER BY [Microsoft.VSTS.Common.Priority] ASC" \
  --project "{PROJECT}"
```

**Filter out non-technical work items**: Discard purely discovery, research, or planning items (no code output). Only keep stories that result in code changes.

Report:
```
📊 Sprint: {ITERATION_PATH}
   Found [N] technical User Stories (excluding Closed/Resolved and non-technical):

| # | ID | Title | Priority | State | Tags |
|---|-----|-------|----------|-------|------|
| 1 | #101 | [title] | 2 | Active | [tags] |
| 2 | #102 | [title] | 2 | New | [tags] |
...

Would you like to:
  A) Use all [N] stories
  B) Select specific work items (provide #IDs)
```

### A.2 — Fetch Full Details & Check Completeness

For each selected work item:

```bash
az boards work-item show --id {WI_ID} --project "{PROJECT}"
```

Extract: Work Item ID, Title, Description (`System.Description`), Acceptance Criteria (`Microsoft.VSTS.Common.AcceptanceCriteria`), Priority, Tags, State.

**Check Story Completeness** — same rule as PATH J:

**A story is COMPLETE if it has ALL THREE of**:
- [ ] **Description** — clear objective (what and why)
- [ ] **Acceptance Criteria** — at least 1-2 items
- [ ] **Out of Scope** — at least one explicit exclusion

Report completeness analysis to user.

### A.3 — Complete Incomplete Stories

For each INCOMPLETE story, ask clarifying questions grounded in the codebase (same procedure as J.3). After user answers, all three fields are known. Repeat for every incomplete story before proceeding.

### A.4 — Check References Folder

Same as J.4 — scan `SPEC/references/` and ask the user which files map to which work items. Skip silently if folder is empty.

### A.5 — Synthesize into Requirements

Using ALL stories (now complete after A.3), generate `docs/requirements.md`:

```markdown
# Requirements — [Project Name]

**Type**: Brownfield Enhancement
**Date**: [YYYY-MM-DD]
**Source**: Azure DevOps project {PROJECT} — Sprint: {ITERATION_PATH} — [N] work items
**Author**: ANALYST_PM_BROWNFIELD

---

## Project Overview

[Synthesized from all story descriptions]

## Current System Context

**Architecture**: [from 00-system-overview.md]
**Affected Modules**: [list of modules these stories touch]
**Existing Patterns**: [from deep-dive]

## Roles & Permissions Matrix

> Canonical role registry. Every story's User Flow by Persona and RBAC Enforcement block
> references these role names + permission keys verbatim. Need a role not listed? Add it here first.
> `Origin` = `Existing` (already enforced in the codebase, per deep-dive) or `New` (introduced by this work).

| Role (canonical) | Description | Key Permissions (allow) | Explicitly Denied | Auth Source | Origin |
|------------------|-------------|-------------------------|-------------------|-------------|--------|
| Admin  | [who] | users:manage, reports:view-all | delete audit logs | [auth source] | Existing |
| Editor | [who] | records:create, records:edit-own | approve, manage users | [auth source] | Existing |
| Viewer | [who] | read-only permitted records | any write | [auth source] | New |

**Permission keys** (stable IDs referenced by every story's RBAC Enforcement block):
`users:manage`, `reports:view-all`, `records:create`, ...

**Notes**: reuse roles already enforced in the codebase rather than inventing parallel ones; the Auth Source must match the architecture authorization model. _Single-actor change?_ Record one row + the note "No role variation — single actor."

## Azure DevOps Work Items Imported

| # | Work Item ID | Title | Priority | State | Tags |
|---|-------------|-------|----------|-------|------|
| 1 | #101 | [title] | 2 | Active | [tags] |
| 2 | #102 | [title] | 2 | New | [tags] |
...

## Functional Requirements

[Grouped by theme — extracted from story descriptions and ACs]

### [Theme 1]
- [Requirement from #101] (#101)

## Success Criteria (Measurable)

[Extracted from acceptance criteria across all stories]

## Failure Criteria (Explicit)

[Regression risks to existing functionality]

## Technical Constraints

[From architecture docs + story descriptions]

## Quality Gates

[Aligned with existing test infrastructure]

## Scope

### IN Scope
[All features covered by the imported stories]

### OUT of Scope
[Anything explicitly excluded in story out-of-scope fields]

### IMPACT Scope (indirect)
[Modules that may be affected but are not directly modified]

## Affected Modules

[From architecture analysis]

## Existing Patterns to Follow

[Extracted from deep-dive]
```

Present to user for approval (same A/B prompt as J.5).

### A.6 — Update docs/status.md

- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "Requirements" row to `✅ Done`, evidence: `docs/requirements.md`

---

## PATH L: Local Requirements Definition

### L.1 — Load Existing Analysis

- [ ] Read `docs/architecture/current/00-system-overview.md`
- [ ] Read ALL `docs/architecture/current/01-*-deep-dive.md` files
- [ ] Read `SPEC/references/` files if any exist
- [ ] Check `SPEC/references/builds/` for build documents

**Present Architecture Summary**:

```
Current System Understanding:

Architecture: [style]
Tech Stack: [languages, frameworks, databases]
Key Modules: [list from system overview]
Patterns Found: [from deep-dive]
Data Layer: [database type, ORM, key models]
Integration Points: [external APIs, services]
Test Infrastructure: [testing frameworks, coverage]

Based on this analysis, tell me what changes/features you want to build.
```

### L.2 — Gather Requirements

Ask the user:

```
What changes/features are we building?

1. What feature/change is needed?
2. Who is it for?
3. What problem does it solve?
4. What does success look like?
5. Any constraints? (Timeline, tech, budget, compatibility)
6. What user roles exist, and what can each do / not do?
```

### L.3 — Clarifying Questions

Ask clarifying questions **grounded in the existing system**:
- Which modules will be affected?
- Do we need to extend existing patterns or introduce new ones?
- Are there database schema changes needed?
- Any breaking changes to existing APIs?
- Does this affect existing integrations?
- Which roles already exist in the codebase (already enforced) vs are new for this change?

### L.4 — Generate Requirements Document

- [ ] Create `docs/requirements.md` with:
  - Project overview
  - Current system context (from architecture docs)
  - Roles & Permissions Matrix (mark each role Existing vs New)
  - Success criteria (measurable)
  - Failure criteria (explicit — including regression risks)
  - Technical constraints
  - Quality gates
  - Scope (IN / OUT / IMPACT)
  - Affected modules
  - Existing patterns to follow

  ### Requirements Template

```markdown
# Requirements - [Feature Name]

**Date**: [YYYY-MM-DD]  
**Author**: ANALYST_PM_BROWNFIELD  
**Status**: [Draft / Approved]

---

## Project Type

- [x] Brownfield (modifying existing system)
- [ ] MVP (Proof of Concept acceptable)
- [x] Production-Ready (NO TODO comments allowed)

## Timeline

**Target Completion**: [Date]  
**Hard Deadline**: [Date or "None"]

---

## Success Criteria (MUST HAVE)

1. [Specific, measurable outcome]
2. [Specific, measurable outcome]
3. [Specific, measurable outcome]

## Failure Criteria (UNACCEPTABLE)

1. [What would make this implementation fail]
2. [What we absolutely cannot compromise on]

---

## Technical Constraints

- **Patterns to Follow**:
- **Database**: [existing DB + migration strategy]
- **Test Coverage**: Minimum 85%
- **Tests Location**: [existing test location]

## Quality Gates

- All tests pass (100%)
- Coverage ≥85%
- Follows existing patterns
- Code review approved
- No TODO comments

---

## Explicit Scope

### IN Scope
- [What WILL be implemented]

### OUT of Scope
- [What will NOT be implemented]
- [Intentional exclusions]

---

## Roles & Permissions Matrix

> Canonical role registry. Every story's User Flow by Persona and RBAC Enforcement block
> references these role names + permission keys verbatim. Need a role not listed? Add it here first.
> `Origin` = `Existing` (already enforced in the codebase) or `New` (introduced by this work).

| Role (canonical) | Description | Key Permissions (allow) | Explicitly Denied | Auth Source | Origin |
|------------------|-------------|-------------------------|-------------------|-------------|--------|
| Admin  | [who] | users:manage, reports:view-all | delete audit logs | [auth source] | Existing |
| Editor | [who] | records:create, records:edit-own | approve, manage users | [auth source] | Existing |
| Viewer | [who] | read-only permitted records | any write | [auth source] | New |

**Permission keys** (stable IDs referenced by every story's RBAC Enforcement block):
`users:manage`, `reports:view-all`, `records:create`, ...

**Notes**: reuse roles already enforced in the codebase rather than inventing parallel ones; the Auth Source must match the architecture authorization model. _Single-actor change?_ Record one row + the note "No role variation — single actor."

---

## Design References

**Location**: `SPEC/references/`

| File | Type | Description | Used In |
|------|------|-------------|---------|
| [filename.png] | UI Design | [Existing UI to match] | Story X.X - Frontend |
| [filename.pdf] | Spec | [Legacy feature spec] | All stories |
| [filename.docx] | Architecture | [System design doc] | Architecture context |

**Note**: All design files must be referenced in implementation stories. Frontend stories MUST include "Design References" section pointing to specific files.

---

## Patterns to Follow

| Pattern | Reference |
|---------|-----------|
| Error handling | docs/architecture/current/01-deep-dive.md#error-handling |
| Logging | docs/architecture/current/01-deep-dive.md#logging |
| Testing | docs/architecture/current/01-deep-dive.md#testing |
```

- [ ] Present to user for approval

### L.5 — Update docs/status.md

- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "Requirements" row to `✅ Done`, evidence: `docs/requirements.md`

---

## Rules

- NO vague requirements ("fast" → "< 200ms")
- Measurable success criteria
- Explicit scope boundaries — including IMPACT scope for brownfield
- Ask before assuming
- Ground all requirements in the existing system analysis
- Include regression risk assessment for existing functionality
- Discard non-technical stories (discovery, research, planning) from Jira import
- Capture a Roles & Permissions Matrix (mark each role Existing vs New); reuse roles already enforced rather than inventing parallel ones

---

## Mandatory Next Steps to suggest user

| # | Next Command | Purpose |
|---|-------------|---------|
|▶️| `aire-brownfield-architecture`| to design the target state architecture for the changes|

---

**Choose J, G, or L, then type "proceed".**
