---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-05-25"
component: "3Pillar AIRE SDLC Agentic Framework"
description: AIRE Enhancement Workflow — to Document and implement a minor enhancement on an ongoing AIRE SDLC Agentic Framework project.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# AIRE Enhancement — Interactive Enhancement Workflow



## Agents

This workflow uses four agents and **the user as the reviewer** at three HALT GATES.

| Phase invocation      | Agent file                                           | Used in                                              |
| --------------------- | ---------------------------------------------------- | ---------------------------------------------------- |
| ANALYST_PM_BROWNFIELD | `SPEC/agents/AIRE_ANALYST_PM_BROWNFIELD.md`          | Phase 1A & 1B (intake, scope gathering)              |
| ARCHITECT             | `SPEC/agents/AIRE_ARCHITECT.md`                      | Phase 2 (codebase impact scan)               |
| PRODUCT_OWNER         | `SPEC/agents/AIRE_PRODUCT_OWNER.md`                  | Phase 3, 4, 5 (author story → approval → tracker)    |
| DEV                   | `SPEC/agents/AIRE_DEV.md`                            | Phase 6 (implementation)                             |


---

## Process

### Phase 0: AIRE Methodology Context (MANDATORY FIRST)

- [ ] Read `SPEC/templates/enhancement.TEMPLATE.md` — the permanent template (never write to this file)
- [ ] **Determine next enhancement number `N`** — glob `docs/enhancements/enhancement-*.md`, parse the integer suffix from each filename (e.g., `enhancement-3.md` → 3), and set `N = max(found) + 1`. If no matching files exist, `N = 1`. Numbers are never reused.
- [ ] Set the working file path for this run: `docs/enhancements/enhancement-[N].md` (e.g., `enhancement-1.md`, `enhancement-2.md`, …). Use this exact path everywhere the workflow refers to "the enhancement file" below.

> **Note on screenshots**: Screenshots in `docs/enhancements/screenshots/` are **optional**. The workflow proceeds regardless of whether any images are present.

---

### Phase 1A: Interactive Intake (Agent: ANALYST_PM_BROWNFIELD)

- [ ] **Load agent** — read `SPEC/agents/AIRE_ANALYST_PM_BROWNFIELD.md`.

The ANALYST_PM_BROWNFIELD agent collects all inputs by asking the user questions.
Present this opening message first:

```
👋 Enhancement workflow started.

I'll ask you a few questions to capture the enhancement, then create the story for you.
Type 'no changes' at any point to cancel.

Let's begin — Question 1 of 7:
```

Ask these questions in one go:

| #   | Question                                                                                                                                                 |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Title** — "Give this enhancement a short title (5–10 words)."                                                                                          |
| 2   | **What needs to change** — "Describe exactly what should change. Be specific (e.g., 'Move the dark-mode toggle from the sidebar to the global header')." |
| 3   | **Current behaviour** — "What happens today? Describe the current state of the thing you want to change."                                                |
| 4   | **Desired behaviour** — "What should happen after the enhancement? Describe the target outcome."                                                         |
| 5   | **Why** — "What is the business or UX reason for this change? (One paragraph max.)"                                                                      |
| 6   | **Acceptance criteria** — "Give 2–4 testable bullets. How will we know it's done? (e.g., 'Toggle is visible in the header without scrolling')"           |
| 7   | **Out of scope** — "Is there anything that looks related but must NOT be touched? (Type 'none' if nothing.)"                                             |

After all 7 answers are collected:

- Ask (optional): "Do you have any screenshots or mockups? If yes, drop them into `docs/enhancements/screenshots/` now and press Enter when ready. If not, just press Enter to continue."
  - Wait briefly for this response, then continue regardless.

**Create the working file `docs/enhancements/enhancement-[N].md`** (using the sequential `N` determined in Phase 0) by copying the structure from `SPEC/templates/enhancement.TEMPLATE.md` and replacing every placeholder with the user's answers. The filename MUST be unique — if `docs/enhancements/enhancement-[N].md` somehow already exists, that means `N` was computed incorrectly in Phase 0; STOP and re-derive `N` rather than overwriting a previous run's record.

🔴 NEVER modify `SPEC/templates/enhancement.TEMPLATE.md` — it is the permanent template.

Show the completed file to the user and ask (this is **HALT GATE #1**):

```
## Enhancement Captured — Awaiting Approval (HALT GATE #1) ✅

Here is what I've recorded in docs/enhancements/enhancement-[N].md:

[paste the completed file content]

Does this look correct? (yes / edit)
```

- If **"edit"**: ask which section to change, update `docs/enhancements/enhancement-[N].md`, and show the revised version again.
- If **"yes"**: proceed to Phase 1B.

🔴 Do NOT continue to Phase 1B / Phase 2 until the user replies **"yes"** explicitly.

If the user types **'no changes'** at any point during intake, output `✅ No changes requested. Workflow closed.` and stop.

---

### Phase 1B: Read Inputs (Agent: ANALYST_PM_BROWNFIELD)

- [ ] Re-read `docs/enhancements/enhancement-[N].md` in full to confirm the file written in Phase 1A matches what was approved
- [ ] View all images in `docs/enhancements/screenshots/` if any are present
- [ ] Read `docs/plans/implementation-plan.md` if present — to discover existing epic/story numbering
- [ ] Read `docs/status.md` if present — to detect the active project tracker (Jira / GitHub Projects / Local)


---

### Phase 2: Codebase Impact Scan (Agent: ARCHITECT)

- [ ] **Load agent** — read `SPEC/agents/AIRE_ARCHITECT.md` now 

The Architect scans the codebase to locate affected code and auto-detects whether the change relates to an existing planned story. Read-only access to codebase.

**Codebase scan:**

- [ ] View every image in `docs/enhancements/screenshots/` if any are present (agent must actually view, not just list) — visual cues often pinpoint the affected component faster than text alone
- [ ] Read top-level codebase directory structure
- [ ] Grep / glob for terms in the enhancement description (component names, button labels, route names, feature flags)
- [ ] Identify the **smallest set of files** that need to change
- [ ] For each file: note the function/component, current behaviour, and what would change
- [ ] Note any tests in the codebase that exercise the affected code
- [ ] Flag risks (shared component, used by many screens, lacks tests, etc.)

**Story linkage auto-detection:**

- [ ] If `docs/plans/implementation-plan.md` exists, scan it for any story whose objective, files-touched, or implementation steps reference the affected paths or components
- [ ] If `docs/plans/stories/` exists, glob `epic-*-story-*.md` files and grep for affected paths inside each story body
- [ ] Pick **closest matching story** (highest specificity).
- [ ] If no plan or no match: record `Related-Story: none` with evidence `"no match found in docs/plans/"`

**Sub-story letter suffix detection** (used by Phase 3 when naming the story file):

- [ ] If a `Related-Story` is found (e.g., `epic-1-story-1.1`), scan `docs/plans/stories/` for any existing files matching `*story-1.1[a-z]*`
- [ ] Determine the **next available letter suffix**: if none exist → `a`; if `1.1a` exists → `b`; if `1.1a` and `1.1b` exist → `c`; and so on
- [ ] Record: `Sub-Story-ID: 1.1a` (or next available)

Append the **Codebase Impact Scan** section directly to the existing enhancement file `docs/enhancements/enhancement-[N].md`:

```markdown
---

## Codebase Impact Scan (Architect)

### Affected Files

| Path         | Component / Function | Change Required |
| ------------ | -------------------- | --------------- |
|          ... | ...                  | ...             |

### Detected Story Linkage

- **Related-Story**: [epic-X-story-Y.Z | none]
- **Sub-Story-ID**: [Y.Za | none]
- **Evidence**: [one sentence — which file or plan section pointed here, or "no match found in docs/plans/"]

### Tests Affected

| Path | Coverage notes |
| ---- | -------------- |
|  ... | ...            |

### Risks

- [risk] — mitigation: [...]

### Suggested Approach

[2–5 sentences on the cleanest implementation path]
```

🔴 Architect MUST cite real file paths. No guessing — if a file can't be located, report that explicitly.

✅ When no `docs/plans/` exists or no match is found, set `Related-Story: none` and `Sub-Story-ID: none` and continue.

---

### Phase 3: Author Story (Agent: PRODUCT_OWNER)

- [ ] **Load agent** — read `SPEC/agents/AIRE_PRODUCT_OWNER.md` now. This same loaded definition also covers Phase 4 and Phase 5 — no need to re-read.

Read the Codebase Impact Scan section in the enhancement file (appended in Phase 2) and determine the story numbering mode:

#### Mode A — Related story detected (Sub-Story-ID is set, e.g. `1.1a`)

- [ ] Create `docs/plans/stories/` if it does not exist
- [ ] Write the story file using the **letter-suffix naming** convention:

```
docs/plans/stories/enhancement-epic-[E]-story-[Y.Za]-[kebab-case-title].md
```

(Where `[E]` is the parent epic number from the Codebase Impact Scan; `[N]` remains the enhancement number from Phase 0.)

Use this frontmatter and structure (mirrors `IMPLEMENTATION_PLAN_FORMAT.md`):

```markdown
---
BUILDID: [copy from parent story if build cycles active, else omit]
Epic: [E — copy parent epic number and name]
ID: [Y.Za]
Parent-Story: [Y.Z]
Date: [YYYY-MM-DD]
Jira: [PENDING — filled in Phase 5]
GitHub: [PENDING — filled in Phase 5]
AzureDevOps: [PENDING — filled in Phase 5]
Enhancement: ENHANCEMENT-[N]
Related-Story: [Y.Z — copy from Codebase Impact Scan]
---

# Epic [E] / Story [Y.Za] — [Title]

> ⚡ Enhancement sub-story of Story [Y.Z]. See parent story for full epic context.

## Objective

[One paragraph: what this enhancement accomplishes]

## Acceptance Criteria

- [ ] [AC 1 from clarifying answers]
- [ ] [AC 2]
- [ ] All affected tests pass
- [ ] No regression in adjacent functionality

## Must Read (References)

- docs/enhancements/enhancement-[N].md (Unified Request & Impact Report)
- docs/enhancements/screenshots/\* (if any images exist)
- docs/plans/stories/epic-[E]-story-[Y.Z]-\*.md (parent story)

## Prerequisites

- Working code checkout
- Parent story [Y.Z] implementation complete
- Existing tests pass on baseline

## Implementation Steps

[Numbered list derived from Codebase Impact Scan's Suggested Approach]

## Test Requirements

- [unit / component / integration tests to add or update]
- Coverage target: ≥85% for changed files

## Out of Scope

[Mirror from Phase 2 scope summary]
```

#### Mode B — No related story (Sub-Story-ID: none)

- [ ] Create directory `docs/plans/enhancements/` if it does not exist
- [ ] Write the story file to:

```
docs/plans/enhancements/enhancement-story-[N].1-[kebab-case-title].md
```

Use the same frontmatter structure but with `ID: [N].1`, `Parent-Story: none`, and `Enhancement: ENHANCEMENT-[N]`.

---

### Phase 4: HALT GATE #2 — Story Approval (Agent: PRODUCT_OWNER)

Present the story to the user for approval BEFORE pushing to the tracker or invoking DEV:

```
## Story Created — Awaiting Approval (HALT GATE #2)

📄 Story file:   [docs/plans/stories/enhancement-epic-[E]-story-[Y.Za]-title.md | docs/plans/enhancements/enhancement-story-[N].1-title.md]
🎫 Tracker:      [PENDING — will ask to push after approval]
🔗 Related to (auto-detected by Architect): [epic-X-story-Y.Z | none]
🔢 Story ID:     [Y.Za | ENHANCEMENT-N / N.1]

### Objective
[paste objective]

### Acceptance Criteria
[paste AC list]

### Affected Files (from Codebase Impact Scan)
[paste table]

### Suggested Approach
[paste from Codebase Impact Scan]

---
Approve story? (yes / refine)
```

🔴 Do NOT continue to Phase 5 until the user replies **"yes"** explicitly. If "refine", loop back to Phase 3 to update the story (and Phase 2 if the Codebase Impact Scan needs revision).

---

### Phase 5: Tracker Push (Agent: PRODUCT_OWNER)

Once approved at Phase 4 (HALT GATE #2):

1. **Detect the active tracker first** — read `docs/status.md` Project Tracking block to determine whether the project is configured for Jira, GitHub Projects, or Local. This determines the default in the next prompt.
2. **Then ask the user** (the detected tracker is the default; the user may override):

```
Story approved! Would you like to push this story to the tracker?
Detected tracker: [Jira | GitHub Projects | Azure DevOps | Local]

(yes-jira / yes-github / yes-ado / local)
```

#### Jira Path (Atlassian MCP) — single story push

**If user chose `yes-jira`**:

1. Ask user and get project key: `❓ Jira project key? (e.g., PROJ)`
2. Get assignable users: `@atlassian-rovo list assignable users [PROJECT_KEY]`
3. Ask: `Assign to: 1) One person 2) Unassigned 3) Manual`
4. Show preview of the single story (title, AC, type = enhancement)
5. Confirm: `Create in Jira? (yes/no)`
6. Execute:

```
@atlassian-rovo Create in [PROJECT_KEY]:
- Issue type: Story (or Task — match project's enhancement convention)
- Summary: <story title>
- Description: full story body (objective, AC, implementation steps, tests, out-of-scope).
  FORMAT CONTRACT — pass `description` as **Markdown** with REAL line breaks (the Rovo MCP
  converts Markdown → Jira ADF). Use `##`/`**...**`, NOT wiki-markup `h2.`/`*...*`, and NEVER
  emit literal `\n` escape sequences, or Jira renders the body as plain text.
- Labels: ai-generated, enhancement, enhancement-N, [story-Y.Za if Related-Story set]
- If BUILDID is set in parent story: set `fixVersion` to `cycle-[N]` (e.g., cycle-1)
- Assignee: per user choice above
- Story points: blank (enhancement scope determined by user)
- If `Related-Story` is set: link as "Relates to" → parent story's Jira key
```

7. Show summary: Jira key, URL, fixVersion applied, link to parent story (if any)
8. **MANDATORY — Update local story file**: Update the story file's frontmatter tracker fields:
   - `Jira: PENDING` → `Jira: PROJ-NNN`
   - `GitHub: PENDING` → `GitHub: LOCAL` (no GitHub issue was created)
   - `AzureDevOps: PENDING` → `AzureDevOps: LOCAL` (no ADO item was created)

---

#### GitHub Path (`gh` CLI) — single story push

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user to run them. If a command returns 422 "already exists", skip and continue.**

**Step 1 — Read tracking context**

From `docs/status.md`: `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `RELEASE_FIELD_ID`, `PRIORITY_FIELD_ID`, `STORY_POINTS_FIELD_ID`, `STATUS_FIELD_ID`, `STATUS_OPTION_ID_TODO`.

From the active cycle plan (`docs/plans/builds/cycle-[N]/cycle-plan.md`), if `BUILDID` is set on the parent story: `RELEASE_OPTION_ID_CYCLE_N`.

**Step 2 — Ensure labels exist**

```bash
# Always create:
gh label create "enhancement" --color "0E8A16" --repo "ORG/REPO" --force --description "Enhancement to existing functionality"
gh label create "story"       --color "1D76DB" --repo "ORG/REPO" --force --description "User story"

# If Related-Story is set, also ensure epic + cycle labels exist (substitute the parent epic number <E> and the active cycle number <N>):
gh label create "epic:<E>"    --color "6F42C1" --repo "ORG/REPO" --force --description "Epic <E> — <Epic Name>"
gh label create "cycle:<N>"   --color "5319E7" --repo "ORG/REPO" --force --description "Cycle <N>"
```

**Step 3 — Locate parent Milestone (only if Related-Story is set)**

```bash
gh api "repos/ORG/REPO/milestones?state=all" --jq '.[] | select(.title=="Epic <E>: <Epic Name>") | .number'
```

Capture the milestone TITLE string (e.g., `"Epic 1: Project Foundation"`) — `gh issue create --milestone` takes the title string, not the integer number. If no parent epic, omit `--milestone`.

**Step 4 — Create the Issue**

> **⚠️ CRITICAL — two failure modes that have silently burned past runs:**
>
> 1. **`--milestone` takes the milestone TITLE STRING, not the integer number.** `gh issue create --milestone 1` fails with "could not resolve to a Milestone" and the issue is NOT created. Always pass the full title, e.g. `--milestone "Epic 1: Project Foundation"`.
> 2. **Never swallow the output of `gh issue create` into a variable without verifying both the exit code AND that the captured value matches `https://github.com/<owner>/<repo>/issues/<number>`.** After every call, assert: (a) exit status 0, and (b) output matches the issue-URL regex. On mismatch, STOP and report — do not silently continue.

Build the body from the story file (Objective, AC, Prerequisites, Implementation Steps summary, Test Requirements summary, Out of Scope), then:

```bash
gh issue create --repo "ORG/REPO" \
  --title "Enhancement Y.Za: <Story Title>" \
  --body "$(cat <<'EOF'
## Enhancement
<story objective>

## Acceptance Criteria
<checkboxes from story file>

## Prerequisites
<list>

## Implementation Steps (summary)
See: docs/plans/stories/enhancement-epic-<E>-story-<Y.Za>-<slug>.md
(or docs/plans/enhancements/enhancement-story-<N>.1-<slug>.md)

## Test Requirements
<summary>

## Out of Scope
<list>

---
**Enhancement**: ENHANCEMENT-<N>
**Related-Story**: <epic-X-story-Y.Z | none>
**BUILDID**: CYCLE-<N>  (only if parent story has BUILDID)
EOF
)" \
  --label "enhancement" --label "story" \
  --label "epic:<E>" --label "cycle:<N>" \
  --milestone "Epic <E>: <Epic Name>" \
  --assignee "<github-username-or-omit>"
```

(Drop `epic:<E>`, `cycle:<N>`, and `--milestone` if no `Related-Story` is set.)

**Verify before continuing.** Two checks:

1. The exit status of `gh issue create` is 0.
2. The captured output matches the regex `^https://github\.com/[^/]+/[^/]+/issues/\d+$`.

If either check fails, STOP — do not write back to the story file or report success. Otherwise extract the trailing `\d+` from the URL → `ISSUE_NUMBER`.

**Step 5 — Add issue to the Project and set custom fields** (GraphQL)

```bash
# a) Resolve the issue's node id
ISSUE_ID=$(gh api "repos/ORG/REPO/issues/ISSUE_NUMBER" --jq '.node_id')

# b) Add the issue to the project → returns the ITEM_ID
ITEM_ID=$(gh api graphql -f query='
mutation($projectId:ID!,$contentId:ID!){
  addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){ item{ id } }
}' -f projectId="PROJECT_ID" -f contentId="$ISSUE_ID" --jq '.data.addProjectV2ItemById.item.id')

# c) Set Release field to this cycle's option (skip if no BUILDID on parent story)
gh api graphql -f query='
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){ projectV2Item{ id } }
}' -f projectId="PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="RELEASE_FIELD_ID" -f optionId="RELEASE_OPTION_ID_CYCLE_N"

# d) Set Status = Todo (or whatever the active board's "ready" column is).
#    Read STATUS_FIELD_ID and STATUS_OPTION_ID_TODO from docs/status.md Project Tracking block.
gh api graphql -f query='
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){ projectV2Item{ id } }
}' -f projectId="PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="STATUS_FIELD_ID" -f optionId="STATUS_OPTION_ID_TODO"
```

**Step 6 — Write issue number back into the local story file**

Update the story frontmatter:
- `GitHub: PENDING` → `GitHub: #<ISSUE_NUMBER>`
- `Jira: PENDING` → `Jira: LOCAL` (no Jira issue was created)
- `AzureDevOps: PENDING` → `AzureDevOps: LOCAL` (no ADO item was created)

**Step 7 — Summary**

Print to user: issue number, URL, project URL, parent-story link (if any), labels applied.

---

#### Azure DevOps Path (`az boards` CLI) — single story push

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user. If a command fails with "already exists", skip and continue.**

**If user chose `yes-ado`**:

**Step 1 — Read tracking context**

From `docs/status.md`: `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH`.
From active cycle plan (if `BUILDID` set on parent story): `ITERATION_PATH_CYCLE_N`.

**Step 2 — Create the work item**

```bash
ENHANCEMENT_WI_ID=$(az boards work-item create \
  --type "User Story" \
  --title "Enhancement Y.Za: <Story Title>" \
  --description "<story objective, AC, steps, out-of-scope>" \
  --project "{PROJECT}" \
  --fields "Microsoft.VSTS.Scheduling.StoryPoints=<blank>" \
           "System.Tags=ai-generated;enhancement;enhancement-N" \
  --query "id" -o tsv)

# Assign to iteration (if BUILDID set)
az boards work-item update \
  --id "$ENHANCEMENT_WI_ID" \
  --iteration "{ITERATION_PATH_CYCLE_N}" \
  --project "{PROJECT}"

# Link to parent story work item (if Related-Story is set and has **AzureDevOps**: #N)
az boards work-item relation add \
  --id "$ENHANCEMENT_WI_ID" \
  --relation-type "System.LinkTypes.Related" \
  --target-id {PARENT_WI_ID}
```

**Step 3 — Write work item ID back into local story file**

Update the story frontmatter:
- `AzureDevOps: PENDING` → `AzureDevOps: #{ENHANCEMENT_WI_ID}`
- `Jira: PENDING` → `Jira: LOCAL` (no Jira issue was created)
- `GitHub: PENDING` → `GitHub: LOCAL` (no GitHub issue was created)

**Step 4 — Summary**

Print to user: work item ID, URL, iteration assigned, parent link (if any).

---

#### Local-only fallback

- [ ] If the user chooses `local` or no tracker is configured, set all three tracker fields to `LOCAL` and continue. No commands run:
  - `Jira: PENDING` → `Jira: LOCAL`
  - `GitHub: PENDING` → `GitHub: LOCAL`
  - `AzureDevOps: PENDING` → `AzureDevOps: LOCAL`

---

### Phase 6: Implementation (Agent: DEV)

- [ ] **Load agent** — read `SPEC/agents/AIRE_DEV.md` now.
- [ ] **Load implementation rulebook** — read `SPEC/rulebooks/aire-implementation-rulebook.md` now.

The DEV agent implements the enhancement story using the **exact same process as any regular story**. No special handling is needed — the sub-story file (`1.1a`) is self-contained.

- [ ] Read the story file + Codebase Impact Scan section in the enhancement file + all images in `docs/enhancements/screenshots/` (if any)
- [ ] Read patterns docs:
  - `docs/architecture/`
- [ ] Write tests first (TDD) for the AC where applicable
- [ ] Implement the change strictly inside the codebase
- [ ] Run tests, capture output, verify coverage ≥85% for changed files
- [ ] Verify no lint errors

🔴 NEVER write production code outside codebase.

After implementation, DEV hands off to Phase 7 (HALT GATE #3) for user review.

---

### Phase 7: HALT GATE #3 — User Review 

Present the completed work to the user. The user is the reviewer.

```
## Implementation Complete — Awaiting User Review (HALT GATE #3)

🎫 Story:        [Y.Za | ENHANCEMENT-N / N.1] — [Title]
📁 Files changed:
  - path/to/file1 (+12 -3)
  - path/to/file2 (+5 -0)
  - path/to/file1.test.ts (+18 -0)

✅ Tests:        [X/X passing]
📊 Coverage:     [XX.X%]  (target ≥85% on changed files)
🧹 Lint:         clean

### How to verify locally
[1–3 short steps]

### Screenshots / recording
[paste link or describe — if frontend, include before/after snippet]

---
✋ MANUAL CHECK REQUIRED
Please verify the implementation is correct:
  1. Open the changed files / run the app locally if needed
  2. Confirm the enhancement matches what you described

Is the implementation correct? (yes / changes-requested)
```

If the user replies **"changes-requested"**, capture their feedback and loop back to Phase 6. Do not update `docs/status.md` or close the tracker until the user explicitly approves with **"yes"**.

---

### Phase 8: Close Out

On explicit user approval at GATE #3:

- [ ] DEV Agent updates `docs/status.md`, to update `docs/status.md` follow `SPEC/templates/STATUS_FORMAT.md` exactly:
  - **Append a row to the `Enhancement Tracker` table** (NOT the Story Tracker). Columns per STATUS_FORMAT.md:
    - `Enhancement` = `ENHANCEMENT-[N]` (from Phase 0)
    - `Story ID` = `[Y.Za]` (Mode A) or `[N].1` (Mode B)
    - `Title` = enhancement title from Phase 1A
    - `Related-Story` = `[Y.Z]` or `none` (from Codebase Impact Scan)
    - `Tracker` = the Jira key (`PROJ-NNN`), GitHub prefix (`GH-<num>`), or `LOCAL` — mirror the `Jira:` frontmatter on the story file
    - `Start` = date DEV began Phase 6
    - `End` = today (YYYY-MM-DD)
    - `Recorded` = current ISO timestamp (YYYY-MM-DD HH:MM)
  - 🔴 **DO NOT add a row to the Story Tracker** — enhancement sub-stories belong in the Enhancement Tracker only (per the STATUS_FORMAT.md anti-pattern list).
  - Update Quality Metrics: increment unit-test coverage, integration tests pass count, documentation-done count as appropriate
  - **Updated By** → `DEV`
  - Then, in the same write, set Agent Activity: PRODUCT_OWNER / ARCHITECT / DEV / ANALYST_PM all back to Idle
- [ ] Close the tracker issue:
  - Jira: transition to Done via Atlassian MCP
  - GitHub: `gh issue close <number> --comment "Completed via aire-enhancement workflow"`
  - Azure DevOps: `az boards work-item update --id <number> --state "Closed" --discussion "Completed via aire-enhancement workflow" --project "{PROJECT}"`
  - Local: no action — just note in status.md
- [ ] **Do NOT delete `docs/enhancements/enhancement-[N].md`** — it is the permanent intake + impact-scan record for this enhancement and stays committed to SCM. The next `aire-enhancement` run will create `enhancement-[N+1].md` instead.
- [ ] Output a final summary:

```
✅ Enhancement complete.

   Story:    [story file path]
   Story ID: [Y.Za | ENHANCEMENT-N / N.1]
   Tracker:  [link or LOCAL]
   Status:   docs/status.md updated

Type 'aire-enhancement' to start another enhancement, or continue with the next story using aire-dev-implement workflow.
```

---

## Rules

- ✅ The workflow is invoked exclusively by the user typing `aire-enhancement`. It always starts in **interactive intake mode** (Phase 1A) and creates a **new, sequentially-numbered file** `docs/enhancements/enhancement-[N].md` from the template — there is no "skip intake" path.
- ✅ **Sequential numbering**: Phase 0 computes `N = max(existing enhancement-*.md numbers) + 1` (or `1` if none). The first run produces `enhancement-1.md`, the second `enhancement-2.md`, and so on. Numbers are never reused.
- 🔴 The workflow MUST NOT overwrite, modify, or delete any prior `enhancement-*.md` file. Each numbered file is a permanent record of one enhancement run and stays committed to SCM.
- ✅ `templates/enhancement.TEMPLATE.md` is the **permanent template** — the workflow MUST NEVER write to or modify this file.
- ✅ Previous runs' story files under `docs/plans/` and `enhancement-*.md` files under `docs/enhancements/` serve as the permanent record of past enhancements.
- ✅ Screenshots in `docs/enhancements/screenshots/` are **optional**. The workflow proceeds regardless of whether any images are present.
- 🔴 ANALYST_PM_BROWNFIELD MUST present the captured enhancement file and wait for explicit user **"yes"** at **HALT GATE #1** (end of Phase 1A) before the Architect runs.
- 🔴 PRODUCT_OWNER MUST present the authored story and wait for explicit user **"yes"** at **HALT GATE #2** before DEV starts implementation.
- 🔴 After implementation, user must explicitly approve at **HALT GATE #3** before `docs/status.md` is updated and the tracker issue is closed.
- 🔴 The workflow MUST NOT update `docs/status.md`, close the tracker issue, or report success until the user has explicitly typed **"yes"** at GATE #3. Silent approval is forbidden.
- 🔴 PRODUCT_OWNER MUST NOT ask the user to nominate an existing story by ID. Story linkage is auto-detected by the Architect in Phase 2 and confirmed at GATE #2.
- ✅ When a `Related-Story` is detected, the new story uses a **letter suffix** (`1.1a`, `1.1b`, …) and is written to `docs/plans/stories/` with the `enhancement-` filename prefix (e.g. `enhancement-epic-1-story-1.1a-title.md`) so DEV can pick it up.
- ✅ Letter suffixes increment alphabetically. Scan `docs/plans/stories/` to find the next available suffix before authoring.
- ✅ When no related story is found, fall back to `ENHANCEMENT-N / N.1` numbering in `docs/plans/enhancements/`
- ✅ Tracker fallback: if no tracker is configured, set `Jira: LOCAL` — do not block the workflow.
- ✅ After Phase 8, `docs/enhancements/enhancement-[N].md` is **retained as-is** — it remains the permanent intake + impact-scan record. The next `aire-enhancement` invocation will create `enhancement-[N+1].md` based on Phase 0's number derivation.

---

## Story Numbering Reference

| Situation                                   | Story ID              | File location                                               |
| ------------------------------------------- | --------------------- | ----------------------------------------------------------- |
| Related story detected (first enhancement)  | `1.1a`                | `docs/plans/stories/enhancement-epic-1-story-1.1a-title.md` |
| Related story detected (second enhancement) | `1.1b`                | `docs/plans/stories/enhancement-epic-1-story-1.1b-title.md` |
| No related story                            | `ENHANCEMENT-1 / 1.1` | `docs/plans/enhancements/enhancement-story-1.1-title.md`    |

---
