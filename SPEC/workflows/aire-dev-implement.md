---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Dev - Implement Story. Execute implementation plan stories.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---
# Dev - Implement Story

## Agent

**DEV** 

## Before Starting

1. Read `SPEC/agents/AIRE_DEV.md`
2. Read `SPEC/rulebooks/aire-implementation-rulebook.md`
3. Read `docs/plans/implementation-plan.md` — if missing, **STOP**: Tell user to "Run `aire-greenfield-plan` or `aire-brownfield-plan` first." (Read the lean index only — do NOT open story files yet.)

> **Steps 4–5 below apply ONLY to the classic one-story flow.** Do NOT do them yet — first complete **🚦 STEP 0 — Routing Gate** (below), which decides one-by-one vs in-one-go.
> - **In-one-go (orchestrator):** you do NOT read story files, architecture/pattern docs, or existing code at all. Those reads are delegated — the decompose-lead reads the story + Boundary Map, and the workers/integrator read the code. Your context stays limited to the dependency graph + small JSON signals. (Reading them yourself is the "parent reads first" anti-pattern — it burns tokens and defeats the isolation.)
> - **One-by-one (classic):** continue with 4–5, but only for the single story you're implementing.

4. Read the **one** story file you're implementing: `docs/plans/stories/epic-N-story-M-*.md`. It is **self-contained** (full epic context, patterns, steps, tests) and has two sections: **👤 User Reference** (plain-English summary + AC for PMs — use it for user-facing summaries) and **🤖 AI Agent Reference** (the implementation contract: Must Read, technical AC, prerequisites, patterns, steps, tests, out-of-scope). **Implement from the AI Agent Reference section.**
5. Read ONLY the specific files the story names in its **"Context files to read"** section. Do NOT blanket-read all of `docs/architecture/` — the story already cites the patterns it needs.

**Note**: Individual story files contain complete epic context and all details needed — a well-formed story rarely requires reading architecture docs beyond the files it explicitly cites.

---

## 🚦 STEP 0 — Routing Gate (MANDATORY — ask BEFORE anything else)

> This is the **first action** of the workflow — before "Tell Me Which Story", before opening any story file, before any code. It exists because models tend to jump from "pick a story" straight to "write code" and skip the dev-slot + execution-mode questions. The gate is **deterministic** (a file check, not a judgment call) so it cannot be inferred away. Do NOT assume a dev slot. Do NOT assume parallel vs sequential. Do NOT pick a default silently.

**1. Read ONLY `docs/plans/dependency-graph.yml`** (small file — cheap). Two outcomes:

- **No graph, or it has no `assignments:` block** → classic single-story run. Skip to **Tell Me Which Story** below.
- **`assignments:` block exists** → you are in a multi-dev plan. Do steps 2–4. **Do not skip.**

> 🔑 **Story-ID → file resolution (applies everywhere paths are resolved below).** A wave/slice id matching `CR-<n>.<m>` is a CR-born story — read it from the CR bundle, NOT `docs/plans/stories/`:
> `{cr-root}/CR-<n>/Epic <K> (Change Request)/CR-<n>.<m>.md` (`cr-root` = `docs/plans/builds/cycle-<active>/CR/` for cycle projects, else `docs/plans/change-requests/`; glob the `Epic * (Change Request)/` folder to find `<K>`). Plain `N.M` ids resolve to `docs/plans/stories/epic-N-story-N.M-*.md` as usual. Tombstoned ids (`superseded_by:` set) are never in a live slice — skip them.

**2. If `assignments:` exists, ask BOTH questions in ONE message, then STOP and wait.**

Emit the block below **verbatim as your entire reply** (fill the slot lists from the graph). Then **end your turn.** Do NOT narrate it ("let me ask…"), do NOT explain parallel execution, do NOT describe what you're about to do, do NOT read story files or write anything — asking IS the action:

```
Before I start, two things:

1) Which dev slot are you?
   • Dev 1 → [Dev 1's stories from assignments]
   • Dev 2 → [Dev 2's stories from assignments]
   • Dev 3 → [Dev 3's stories from assignments]

2) How should I implement your stories?
   a) One-by-one — one story at a time, then stop (sequential, classic)
   b) In one go  — I spawn parallel subagents to build your assigned
                   stories at the same time (their files are disjoint, so
                   it's safe); large stories also auto-split into parallel
                   component-subagents

Reply like: "Dev 1, in one go"   (or "Dev 1, one-by-one")
```

Asking both at once means one HALT, one reply — no second turn to drift on.

**3. After BOTH answers, branch** — compute your slice = your slot's *incomplete* stories in the lowest unfinished wave (cross-check `docs/status.md`):
- **one-by-one** → go to **Tell Me Which Story** (it detects the active tracker and captures its config) and pick ONE story **from your slot**, then run the classic **Execution Steps** for it.
- **in one go** → **⚡ Execution Mode → In-One-Go Wave Mode** (Phase A onward); reuse the slot you were given (do NOT re-ask). Tracker detection/config is captured in the Pre-flight step there. If your slice happens to be a single story, "in one go" just builds that one (auto-splitting it internally if it's decomposable).

⛔ **GUARD — self-check before you read a story body, spawn anything, or write code:** if `assignments:` exists and you have NOT received BOTH answers, **STOP and emit the question block now**. Never assume the slot, never assume the mode, and never *narrate* the question instead of *asking* it (describing it is not asking it). Asking is one cheap turn; guessing wastes a whole run.

---

## Tell Me Which Story

**IMPORTANT**: Always ask user to choose between local, Jira, and GitHub stories.

**Detect active tracker first** — read `docs/status.md`. Look at the `## Project Tracking` block:
- `**Tracking**: Jira` → enable Jira options
- `**Tracking**: GitHub Projects` → enable GitHub options (capture `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `STATUS_FIELD_ID`, and note the `STATUS_OPTION_ID_*` values by running `gh project field-list PROJECT_NUMBER --owner ORG --format json` once per session)
- `**Tracking**: Azure DevOps` → enable Azure DevOps options (capture `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH`; run `az devops configure --defaults organization="{ORG_URL}" project="{PROJECT}"` once per session)
- neither → only local options apply

Present these options (show only the relevant tracker block):

```
Which story would you like to implement?

📁 LOCAL Stories (from implementation-plan.md):
  1. "story 1.1" - Implement from local plan
  2. "next story" - Next story in local plan
  3. "story [component name]" - Specific component

🔗 JIRA Stories (if MCP configured):
  4. "pick from jira" - Fetch next available Jira story
  5. "jira story PROJ-123" - Specific Jira story

🐙 GITHUB Stories (if GitHub Projects tracking active):
  6. "pick from github" - Fetch next "Sprint Ready" or "Backlog" story issue
  7. "github issue #N" - Specific GitHub issue

🔷 AZURE DEVOPS Stories (if Azure DevOps tracking active):
  8. "pick from azure-devops" - Fetch next Active/New User Story from sprint
  9. "azure work-item #N" - Specific Azure DevOps work item

⏭️  "skip" - I'll tell you later

Type your choice:
```

---

## 🧰 Tracker Operations Reference (OP-1 / OP-2 / OP-3)

> **Single source of truth for every board update in this workflow.** All other sections say "run OP-N with status X" instead of repeating commands — do NOT improvise alternative commands at the call sites. Config values (`PROJECT_KEY`; `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `STATUS_FIELD_ID`, `STATUS_OPTION_ID_*`; `ORG_URL`, `PROJECT`, `ITERATION_PATH`) come from the once-per-session tracker detection in **Tell Me Which Story** / **Pre-flight**.

### Status mapping (canonical — use these exact names)

| Stage          | Jira        | GitHub board     | Azure DevOps state        |
|----------------|-------------|------------------|---------------------------|
| Start work     | In Progress | In Development   | Active                    |
| Code review    | In Review   | In Review        | In Review *(or Resolved)* |
| QA testing     | In QA       | In QA            | In QA *(or Resolved)*     |
| Accepted/done  | Done        | Done + close issue | Closed                  |

*Azure note*: the default Agile workflow only has `New → Active → Resolved → Closed`. If the project has custom `In Review` / `In QA` states, use those exact names; otherwise map both to `Resolved`.

### OP-1 — Jira: transition status + comment (Jira MCP)

Plain intent via the Atlassian MCP is enough — no command syntax needed:

```
@atlassian-rovo Update [JIRA-ID]: transition status to "<target>"; assign to <user / current user>;
add comment "<context — started / completed, with evidence>"
```
> Comment body: Markdown with REAL line breaks — never literal `\n` escapes (the Rovo MCP converts Markdown → Jira ADF; literal `\n` renders as plain text).

**VERIFY (mandatory)**: fetch the issue back and confirm status now equals the target. If the transition was rejected, list the issue's available transitions and retry with the exact transition name. Still failing → STOP and report.

### OP-2 — GitHub: set Project board Status + comment (gh CLI)

Simple operations — use the obvious gh commands directly: assign (`gh issue edit N --add-assignee`), comment (`gh issue comment N --body "..."`), close (`gh issue close N --reason completed`).

⚠️ **Board Status is the exception — there is NO gh shorthand for ProjectV2 fields.** `gh issue edit` CANNOT set the board Status. Use exactly this pipeline (the part that breaks when improvised):

```bash
# 1. Resolve the project item id for issue N
ISSUE_ID=$(gh api "repos/ORG/REPO/issues/N" --jq '.node_id')
ITEM_ID=$(gh project item-list PROJECT_NUMBER --owner "ORG" --format json --limit 500 \
  | python -c "import sys,json; d=json.load(sys.stdin); print(next(i['id'] for i in d['items'] if i.get('content',{}).get('number')==N))")

# 2. Set the Status single-select field to the target option
gh api graphql -f query='
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){ projectV2Item{ id } }
}' -f projectId="PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="STATUS_FIELD_ID" -f optionId="STATUS_OPTION_ID_<target>"
```

Known gotcha (has burned real runs): `--milestone` on `gh issue create` / `gh issue edit` takes the milestone TITLE STRING, never the integer number.

**VERIFY (mandatory)**: re-query the project item and confirm Status equals the target option. Unchanged → STOP and report the output verbatim.

### OP-3 — Azure DevOps: set work item state + comment (az CLI)

Straightforward — use the az CLI directly:

```bash
az boards work-item update --id N --state "<target state>" --project "{PROJECT}"
# optional on the same or a second call: --assigned-to "<user>"  --discussion "<comment>"
```

The only trap: **state names must match the project workflow exactly** — see the mapping table above.

**VERIFY (mandatory)**: `az boards work-item show --id N --query 'fields."System.State"' -o tsv` and confirm it equals the target. Unchanged → STOP and report.

### Universal guardrails (every OP, every call site)

1. **Confirm-first** — NEVER run any OP without explicit user confirmation in that turn.
2. **Verify-after** — every OP ends with its VERIFY step. An update that didn't land is a failure, not a success.
3. **Stop-on-failure** — if an OP errors or VERIFY mismatches, STOP the loop; do not continue to the next story/board on top of a silent failure. Report the output verbatim.
4. **Evidence in comments** — completion updates always carry tests passed/total, coverage %, lint status, and PR URL (if any).

---

## 🔗 Jira Integration (Optional)

**ALWAYS ASK FOR CONFIRMATION** before any Jira operation.

### If User Chooses Local Story 

1. Read story from `docs/plans/implementation-plan.md` and `docs/plans/stories/epic-N-story-M-*.md`
2. Implement using local plan details
3. Only proceed with Jira if user confirms

### If User Chooses Jira Story

1. **First, fetch and show story details**:
   ```
   @atlassian-rovo Find next available story in project [ASK_FOR_PROJECT_KEY from user]:
   - Status: "To Do"
   - Not assigned to others
   - Highest priority
   ```

2. **Show story to user and ASK FOR CONFIRMATION**:
   ```
   Found: PROJ-123 "User Authentication"
   Status: To Do
   Priority: High
   Story Points: 5
   
   Description:
   [show description]
   
   Acceptance Criteria:
   [show criteria]
   
   ❓ Do you want to implement this story? (yes/no/show-next)
   ```

3. **If user says YES, ask about Jira updates**:
   ```
   ❓ Should I update Jira status to "In Progress"? (yes/no)
   ```

4. **Only after user confirms** → run **OP-1** (🧰 Tracker Operations Reference): transition to "In Progress", assign to current user, comment "Development started via AIRE SDLC Agentic Framework". Then OP-1's VERIFY.

**NEVER update Jira without explicit user confirmation**

---

## 🐙 GitHub Projects Integration (Optional)

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user to run them. If a command returns 422 "already exists", skip and continue. Skip this section entirely if `docs/status.md` does NOT contain `**Tracking**: GitHub Projects`.**

**ALWAYS ASK FOR CONFIRMATION** before any board status update.

### If User Chooses "pick from github"

1. **Fetch candidate issues** — open `story`-labeled issues in the current cycle that are in "Sprint Ready" or "Backlog":

   ```bash
   # List open story issues in the active cycle (CYCLE-N from docs/status.md Story Tracker)
   gh issue list --repo "ORG/REPO" --state open --label "story" --label "cycle:N" --json number,title,labels,url,assignees
   ```

   Then query the Project to filter by Status:

   ```bash
   gh project item-list PROJECT_NUMBER --owner "ORG" --format json --limit 200
   ```

   Cross-reference on issue number. Prefer items whose Status is **Sprint Ready**, fall back to **Backlog**. Skip items already assigned to someone else.

2. **Show the story to user and ASK FOR CONFIRMATION**:
   ```
   Found GitHub issue #42 "Product Search API"
   Status: Sprint Ready
   Labels: story, epic:3, cycle:2, M, P1-high
   Milestone: Epic 3: Product Catalog
   URL: https://github.com/ORG/REPO/issues/42

   [Body excerpt — User Story + Acceptance Criteria]

   ❓ Do you want to implement this story? (yes/no/show-next)
   ```

3. **If YES, ask about board updates**:
   ```
   ❓ Should I move this issue to "In Development" on the board and assign it to you? (yes/no)
   ```

4. **Only after user confirms** → run **OP-2** (🧰 Tracker Operations Reference): assign the issue to `@me`, set board Status → "In Development", comment "Development started via AIRE SDLC Agentic Framework. Moving to In Development." Then OP-2's VERIFY.

5. **Map the GitHub issue to a local story file**:
   - Find `docs/plans/stories/epic-N-story-N.M-*.md` where the header `**GitHub**: #ISSUE_NUMBER` matches.
   - If no matching local story file exists, create one from the issue body so the DEV workflow has a reference file to operate on.

**NEVER change board status without explicit user confirmation.**

### If User Chooses "github issue #N"

Skip the fetch step. Run `gh issue view N --repo ORG/REPO --json number,title,body,labels,milestone,assignees,url`, show to user, then follow steps 2–5 above.

---

## 🔷 Azure DevOps Integration (Optional)

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user to run them. Skip this section entirely if `docs/status.md` does NOT contain `**Tracking**: Azure DevOps`.**

**ALWAYS ASK FOR CONFIRMATION** before any work item state update.

### If User Chooses "pick from azure-devops"

1. **Fetch candidate stories** — New/Active User Stories in the current iteration:

   ```bash
   az boards query \
     --wiql "SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo],[System.Tags] FROM WorkItems WHERE [System.TeamProject] = '{PROJECT}' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] = '{ITERATION_PATH}' AND [System.State] IN ('New','Active') ORDER BY [Microsoft.VSTS.Common.Priority] ASC" \
     --project "{PROJECT}"
   ```

2. **Show the story to user and ASK FOR CONFIRMATION**:
   ```
   Found Azure DevOps User Story #42 "Product Search API"
   State: New
   Priority: 2
   Tags: ai-generated;epic-3;story-3.1;cycle-1;wave-2
   Iteration: {ITERATION_PATH}

   [Description + Acceptance Criteria]

   ❓ Do you want to implement this story? (yes/no/show-next)
   ```

3. **If YES, ask about work item updates**:
   ```
   ❓ Should I move this work item to "Active" and assign it to you? (yes/no)
   ```

4. **Only after user confirms** → run **OP-3** (🧰 Tracker Operations Reference): state → "Active", assign to current user, discussion comment "Development started via AIRE SDLC Agentic Framework". Then OP-3's VERIFY.

5. **Map the work item to a local story file**:
   - Find `docs/plans/stories/epic-N-story-N.M-*.md` where the header `**AzureDevOps**: #{WI_ID}` matches.
   - If no matching local story file exists, create one from the work item body so the DEV workflow has a reference file.

**NEVER change work item state without explicit user confirmation.**

### If User Chooses "azure work-item #N"

Skip the query step. Run `az boards work-item show --id N --project "{PROJECT}"`, show to user, then follow steps 2–5 above.

---

## ⚡ Execution Mode (decided in STEP 0 — never a flag)

The dev slot and one-by-one vs in-one-go choice were **already asked and answered in 🚦 STEP 0** (one combined question). Nothing is stored; STEP 0 recomputes it each run from the live graph + `docs/status.md`.

- You only reach **In-One-Go Wave Mode** below because the user chose **"in one go"** in STEP 0.
- If you find yourself here and STEP 0's question was never answered (and the graph has `assignments:`), that is the skip-bug — go back to STEP 0 and emit the question now before doing anything else.

---

### In-One-Go Wave Mode

**ORCHESTRATOR RULE**: Your role is orchestration only. Spawn subagents (or, where your IDE cannot, do the identical work yourself sequentially) — the reading, coding, and testing happens in the worker layer, never in parent context.

**The parent MUST NOT read (this is the #1 mistake — it burns tokens and defeats the isolation):**
- ❌ story files
- ❌ architecture/pattern docs (`docs/architecture/**`)
- ❌ existing source/test code
- ❌ the File/Module Boundary Map

Every one of those reads is **delegated**: the **decompose-lead** reads the story + Boundary Map; **component-workers** and the **single-agent** read the story + only the code their work touches; the **integrator** reads the components it wires. The parent reads ONLY: `docs/plans/dependency-graph.yml`, `docs/status.md`, the lean `implementation-plan.md` index, and the small `*.json` signals under `docs/plans/.parallel/`. If you catch yourself opening a `.md` architecture doc or grepping source, **stop** — spawn the subagent that should be doing it.

---

#### Phase A — Load & LOCK Your Wave Slice

> **DO NOT open story files in this phase — work from file paths and the dependency graph only.**

1. Ensure `docs/plans/.parallel/` is in `.gitignore` — add `docs/plans/.parallel/` if missing (one-line append, no other changes).

2. From `docs/plans/dependency-graph.yml` + the **dev slot already chosen in STEP 0**:
   - Find the lowest wave number with ≥1 incomplete story.
   - **LOCK** to your STEP 0 slot: your slice = exactly the story IDs under your `dev:` entry (e.g., `[1.1, 1.2]`). Do NOT re-ask the slot — reuse the STEP 0 answer. (If there was no `assignments:` block you wouldn't be here.)

3. Read `docs/status.md` — remove already-completed stories from your slice.

4. Resolve story file paths by directory listing (do NOT open files):
   - For each story ID → apply the 🔑 Story-ID → file resolution rule from STEP 1: `CR-<n>.<m>` → CR bundle path; plain `N.M` → `docs/plans/stories/epic-N-story-N.M-*.md`.

5. Confirm with user:

```
Your Wave [N] slice (Dev [slot]):
  📖 Story [N.M]: [slug from filename] → docs/plans/stories/epic-N-story-N.M-*.md
  📖 Story [N.M]: [slug from filename] → docs/plans/stories/epic-N-story-N.M-*.md

Files are disjoint — safe to implement together (verified in dependency graph).
❓ Implement these? (yes / one-by-one instead / stop)
```

Block until user confirms.

---

##### 🔒 Absolute Dev-Slice Lock (hard rule — no in-session override)

Once the dev declares their slot, the slice is **binding for this run**. You may implement **only** the stories under that dev's `assignments:` entry. This holds on every IDE — it is a prose rule, not a tool feature.

If the user asks — in ANY phrasing ("also do 1.3", "add story 1.3", "1.3 is in the same wave, do it too") — to implement a story whose `dev:` owner in `dependency-graph.yml` is a **different** dev, **refuse**:

```
⛔ Story [X.Y] belongs to Dev [other]. I can't add it to your run.

Even though [X.Y] is in the same wave and is technically parallel-safe, working
it here risks duplicate work and a merge conflict with Dev [other]'s branch
(they may be implementing it right now). This is a hard rule with no in-session
override.

To move [X.Y] to you, re-run aire-greenfield-plan / aire-brownfield-plan and
reassign it there.

Your slot (Dev [slot]): [your story IDs].  Continue with these? (yes / stop)
```

Two enforcement layers:
1. **Assignment layer** — story's `dev:` owner ≠ your declared slot → refuse (message above).
2. **Status layer** — story is already `In Progress` / `In Development` on the tracker → hard block ("another dev has already started [X.Y]; I won't touch it").

**Only** genuinely **unassigned** stories (no `dev:` owner anywhere in `assignments:`) may be picked up beyond your slice — they belong to nobody, so there is no collision.

---

#### Pre-flight: Batch Tracker Update → "In Development"

> **Detect the tracker first** (the in-one-go path skips "Tell Me Which Story", so do the same detection here). Read `docs/status.md` → `## Project Tracking` block and capture the config the board update needs:
> - `**Tracking**: Jira` → Jira path (capture `PROJECT_KEY`).
> - `**Tracking**: GitHub Projects` → capture `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `STATUS_FIELD_ID`, and the `STATUS_OPTION_ID_*` values (`gh project field-list PROJECT_NUMBER --owner ORG --format json`, once per session).
> - `**Tracking**: Azure DevOps` → capture `ORG_URL`, `PROJECT`, `TEAM_NAME`, `ITERATION_PATH`; run `az devops configure --defaults organization="{ORG_URL}" project="{PROJECT}"` once per session.
> - neither → all stories are local; skip this whole Pre-flight (nothing to update) and go straight to Phase B.

Before any story work starts, the **parent** (you, not the workers) moves ALL confirmed tracker stories to "In Progress / In Development / Active" in a single batch. This keeps all boards accurate for the whole slice up front, regardless of whether stories then run concurrently or sequentially.

**Collect tracker IDs — read story file headers (authoritative source)**:
For each story in your slice, open its file (CR-born id → CR bundle path per STEP 1's 🔑 rule; else `docs/plans/stories/epic-N-story-N.M-<slug>.md`) and read its header. Collect each field that is **not** `LOCAL` or absent:
- `**Jira**: <KEY>`
- `**GitHub**: #<N>`
- `**AzureDevOps**: #<N>`

> `docs/plans/dependency-graph.yml` also stores `jira` / `github` / `azure_devops` fields — use these only as a fallback when a story file is missing. The story file header is always more up-to-date because it is written back after plan export.

Skip any story whose tracker fields are all `LOCAL` / absent. Build a combined table of every real ID found across all stories in your slice:

```
❓ Move wave-slice stories to In Progress on their tracker boards before we start?

| Story | Board        | ID        | Move to        |
|-------|--------------|-----------|----------------|
| N.M   | Jira         | PROJ-123  | In Progress    |
| N.M   | GitHub       | #42       | In Development |
| N.M   | Azure DevOps | #101      | Active         |
| N.M   | Jira         | PROJ-124  | In Progress    |
...

1) Yes — update all now
2) Partial — tell me which to skip
3) No — I'll update the boards myself
```

**Only after user confirms** — for each confirmed row, run the matching OP from the 🧰 Tracker Operations Reference with the **Start work** column of the status mapping table:

- Jira ID → **OP-1**, status "In Progress"
- GitHub # → **OP-2**, board Status "In Development"
- Azure DevOps # → **OP-3**, state "Active"

Run each OP's VERIFY before moving to the next row; on any failure, stop the batch and report (universal guardrail 3).

Also update `docs/status.md` Story Tracker: set **Start** date to today for each story in your slice.

---

#### Phase B — Decide the path ONCE, then execute mechanically

> Follow B0→B5 in order. Do not start writing code "to get going" — the very first implementing action in this phase is **spawning a subagent**, never a `Write`.

**B0 — Choose the execution path now, state it, and commit for the whole run:**

- Can you spawn concurrent subagents / tasks (Claude Code Task tool, Windsurf Cascade, …)? → **SPAWN MODE** (B1–B5 below).
- No subagent capability at all? → **SEQUENTIAL MODE** (jump to the fallback at the end of this phase).

Decide once. Do NOT begin in one mode and switch — that causes the delete-and-redo waste.

> ### 🚫 SPAWN MODE — HARD RULE (this is the rule that keeps getting violated)
> In SPAWN MODE the parent's **only** allowed actions are: **(1)** call the subagent/Task tool, **(2)** `Read` small coordination files (`dependency-graph.yml`, `status.md`, `docs/plans/.parallel/*.json`), **(3)** run tracker/git commands.
>
> You **MUST NOT** `Write` or `Edit` any source or test file. You **MUST NOT** run the test suite. You **MUST NOT** implement a story or component yourself — not even "just one quick file" or "to save a round-trip."
>
> **If you are about to `Write`/`Edit` a `.js`/`.ts`/source/test file or run tests → STOP. That work belongs to a subagent you have not spawned yet. Spawn it.** Writing code in the parent is a workflow violation; the fix is to never start, not to delete-and-redo.

**Blackboard** (runtime-only, git-ignored): `docs/plans/.parallel/story-[N.M]/tasks.json`, `…/task-<id>-done.json`, `…/integration-done.json`, and the final `…/story-[N.M]-done.json`. The **parent orchestrates both levels** — subagents never spawn subagents.

---

**B1 — Spawn one `DECOMPOSE-LEAD` per story, all in a SINGLE batch.** (Decomposition is automatic — never ask the user.) Then wait for every `tasks.json`. The lead writes a **complete brief** so workers need almost no further reading.

```
DECOMPOSE-LEAD — stateless. Plan only; implement nothing.

READ:  the story file (CR-born id → CR bundle path per STEP 1's 🔑 rule; else docs/plans/stories/epic-[N]-story-[N.M]-<slug>.md)
       EVERY file in the story's **Must Read** + **Context** sections, IN FULL (PRD, design specs, API/UX contracts) — extract the requirements they impose
       the File/Module Boundary Map in docs/architecture/design/0X-patterns-and-standards-*.md

DECIDE decomposable = true ONLY IF 2+ components have DISJOINT file sets and each is
independently unit-testable. Files 2+ components touch (route registry, barrel/index,
shared types) → reserved_for_integrator (workers never touch them). Else decomposable = false.

COVERAGE RULE: every acceptance criterion, every numbered Step, and every requirement
carried by the references MUST be assigned to exactly one component (or to the integrator).
Nothing may be dropped — the union of all components' `acceptance` must equal the story's
full AC set plus reference-derived requirements.

WRITE ONLY docs/plans/.parallel/story-[N.M]/tasks.json — embed enough that a worker
needs NO other reading except its own code files:
{
  "story_id":"[N.M]", "decomposable":true|false,
  "components":[
    { "id":"a", "title":"...",
      "files":["src/..."], "test_files":["test/..."],
      "acceptance":["the AC bullets for THIS component, copied verbatim from the story's 🤖 AI Agent Reference section"],
      "reference_requirements":["each requirement from a Must Read/PRD/spec that THIS component must satisfy, with its source file"],
      "patterns":["1-line cites: error class, repo interface, naming/logging convention"],
      "context_files":["only the existing files this component must read"] }
  ],
  "reserved_for_integrator":["src/.../routes.js","src/.../index.js"],
  "reason_if_atomic": "<one line if false, else null>"
}
Do NOT echo file contents.
```

**B2 — Read the small `tasks.json` files and classify each story** (parent reads JSON only):
- `decomposable:false` → needs ONE `STORY-AGENT`.
- `decomposable:true`  → needs its `COMPONENT-WORKER`s, then ONE `INTEGRATOR`.

**B3 — Spawn the first work wave in a SINGLE batch:** every `COMPONENT-WORKER` (flattened across all decomposable stories) + every `STORY-AGENT` (atomic stories). Concurrency caps at ~6; the tool queues the rest. **Parent writes nothing.**

```
COMPONENT-WORKER — stateless. Implement exactly one component from its brief.
INPUT: your component object from docs/plans/.parallel/story-[N.M]/tasks.json.
READ ONLY: your component's `context_files` + the `files`/`test_files` you will create or edit.
  (Work from the brief's `acceptance`+`reference_requirements`+`patterns` — do NOT re-read the full story or architecture.)
  If a brief item is unclear, open the specific reference it cites in `reference_requirements` and resolve it from there before flagging anything — do NOT stop and ask.
OWN ONLY your `files`/`test_files`. NEVER touch reserved_for_integrator, other components' files, or docs/status.md.
DO: component-level TDD — write its unit tests → implement → those tests pass. Do NOT run the full suite.
COVER EVERYTHING: implement EVERY bullet in your `acceptance` AND every item in `reference_requirements`. Before reporting done, self-check one row per acceptance/reference item with the file:line that proves it. If any is unmet, you are not done — implement it.
WRITE ONLY: your code + test files, and docs/plans/.parallel/story-[N.M]/task-<id>-done.json:
  { "task_id":"<id>","unit_tests_passed":N,"unit_tests_total":N,"acceptance_covered":N,"acceptance_total":N,"files_changed":["..."] }
```

```
STORY-AGENT — stateless. Implement one whole (atomic) story.
READ ONLY: the story file (implement from its 🤖 AI Agent Reference section) + EVERY file in its Must Read + "Context files to read" sections IN FULL (PRD/specs/contracts) + the existing code you extend. Not docs/status.md.
RESOLVE FROM REFERENCES: if anything is unclear or contradictory, resolve it from the story + those references before doing anything else. You are spawned and cannot ask the user mid-run — exhaust the references; only if a genuine unresolved gap remains, write story-[N.M]-done.json omitted and emit a `{"blocked":true,"question":"...","references_checked":["..."]}` note instead of guessing.
DO: full TDD — tests-first → implement → unit pass → integration/E2E → full suite 100% → coverage ≥85%, lint clean → review doc.
COVER THE WHOLE STORY: implement EVERY acceptance criterion, EVERY numbered Step, and EVERY requirement from the Must Read references. Before writing done.json, run the Definition of Done — Compliance Gates (rulebook): build the Gate 1 Spec Echo table (one row per AC + per Step + per reference requirement, each with file:line proof), plus Gate 2 and Gate 3. If any requirement is unproven, you are NOT done — implement the gap and re-run. Paste the gate evidence into the review doc under "## DoD Evidence".
WRITE ONLY: code + test files, docs/stories-implemented/story-[N.M]-review.md, and
  docs/plans/.parallel/story-[N.M]-done.json:
  { "story_id":"[N.M]","tests_passed":N,"tests_total":N,"coverage_pct":N,"lint_clean":true|false,"ac_covered":N,"ac_total":N,"dod_gates_passed":true|false,"files_changed":["..."] }
Do NOT write story-[N.M]-done.json unless dod_gates_passed is true and ac_covered == ac_total.
```

**B4 — As each decomposable story's `COMPONENT-WORKER`s all report `task-<id>-done.json`, spawn that story's `INTEGRATOR`** (do not wait for unrelated stories):

```
INTEGRATOR — stateless. Wire one story's components and run its story-level gates.
READ ONLY: the story file, EVERY Must Read reference it names (IN FULL), this story's tasks.json + task-*-done.json, the component source just written.
OWN the reserved_for_integrator files (wiring, route registration, barrels).
DO: wire components → write integration/E2E tests → run FULL story suite (100%) → coverage ≥85% → lint clean.
REQUIREMENT COVERAGE GATE (runs exactly ONCE, here, across the WHOLE story): run the Definition of Done — Compliance Gates (rulebook). Build the Gate 1 Spec Echo table with one row per acceptance criterion, per numbered Step, and per Must Read/PRD requirement, each citing the file:line that proves it across all components + wiring. Then Gate 2 (negative-space) and Gate 3 (contract consistency). The AC-row count MUST equal the story's AC count and no requirement may be unproven. Paste the evidence into the review doc under "## DoD Evidence".
  If the full suite fails OR any DoD gate fails OR any AC/reference requirement is unproven: write integration-done.json {"passed":false,"note":"..."} and STOP — do NOT write story-[N.M]-done.json. (Tests-green ≠ spec-met.)
WRITE ONLY: reserved/wiring + integration tests, docs/stories-implemented/story-[N.M]-review.md,
  …/integration-done.json, and docs/plans/.parallel/story-[N.M]-done.json (same schema as STORY-AGENT, including ac_covered/ac_total/dod_gates_passed).
```

**B5 — Wait until every story in your slice has a `story-[N.M]-done.json`, then go to Phase C.** A worker/integrator that fails: re-spawn it once; if it still fails, spawn one `STORY-AGENT` to finish that story atomically and note it — never mark a story done without its `story-[N.M]-done.json`.

---

**SEQUENTIAL MODE (only when B0 found no subagent capability).**

```
⚠️ No concurrent subagents in this IDE — running your slice in one go, sequentially.
   Same steps and same output files, just not in parallel.
```

You still don't pre-load anything. Take one story at a time, read lazily: open that one story, decide decomposability from it + the Boundary Map section it cites, write its `tasks.json`; if atomic, do the STORY-AGENT steps reading only its named context files; if decomposable, build each component on its own files in turn then do the integrator steps; write the same `.parallel/*` signals; drop it and move to the next story. This keeps context to one story's worth at a time. Same retry-once-then-atomic fallback as B5.

---

#### Phase C — Aggregate Results

Once every story in your slice has a `docs/plans/.parallel/story-[N.M]-done.json` (written by its integrator or single-agent), run ONE Status Aggregator. Spawn it as a subagent where supported; otherwise do these exact steps yourself.

```
STATUS AGGREGATOR — you are stateless.

READ ONLY:
  docs/plans/.parallel/story-[N.M]-done.json   (one file per completed story in your slice)
  docs/status.md
  SPEC/templates/STATUS_FORMAT.md

UPDATE docs/status.md — mechanical row edits only, NEVER restructure or reorder sections:
  1. Story Tracker: set End date to today for each completed story ID
  2. Progress Summary — Epic N row: update "[done]/[total] stories done" count
  3. Quality Metrics:
       Unit Test Coverage → lowest coverage_pct across your stories (conservative)
       Integration Tests  → update pass count
       Documentation      → increment by number of story-review docs created
  4. Agent Activity: set DEV row to "Story [N.M]+[N.M] complete | Idle"
  5. Set Recorded column to current timestamp on every row you touch

WRITE ONLY: docs/status.md
```

---

#### Phase D — Summary + Tracker Completion

```
✅ Wave [N] slice complete — [X] stories implemented in one go

| Story | Tracker ID   | Tests         | Coverage | Lint     |
|-------|-------------|---------------|----------|----------|
| [N.M] | [TRACKER-ID] | [X/X] passing | [XX]%    | ✅ clean |
| [N.M] | [TRACKER-ID] | [X/X] passing | [XX]%    | ✅ clean |

Wave [N] overall: [done]/[total] stories complete.
Wave [N+1] unlocks when ALL Wave [N] stories across all devs are done.
```

**Batch tracker close-out** — for each completed story, read its story file header and collect every tracker field that is not `LOCAL` / absent (same check as Pre-flight — story file headers are authoritative). Build a combined table across all boards:

```
❓ Update tracker status for completed stories?

| Story | Board        | ID        | Current         |
|-------|--------------|-----------|-----------------|
| [N.M] | Jira         | PROJ-123  | In Progress     |
| [N.M] | GitHub       | #42       | In Development  |
| [N.M] | Azure DevOps | #101      | Active          |
| [N.M] | Jira         | PROJ-124  | In Progress     |
...

Move all to:
1) In Review   — PR opened, awaiting code review
2) In QA       — merged / review approved, ready for QA testing
3) Done        — accepted, all checks passed
4) No          — I'll update the boards myself
```

**Only after user confirms** — for each row in the table, run the matching OP from the 🧰 Tracker Operations Reference, using the chosen stage's column from the status mapping table (In Review / In QA / Done):

- Jira ID → **OP-1**, plus completion comment: "Wave [W] complete. Tests: X/X passing. Coverage: XX%. Lint: clean. PR: <URL if opened>"
- GitHub # → **OP-2**, plus `gh issue comment` with the same evidence (if "Done": also close the issue)
- Azure DevOps # → **OP-3**, plus `--discussion` with the same evidence

Run each OP's VERIFY per row; on any failure, stop the batch and report (universal guardrail 3).

**What next?**
```
1) aire-review-code — request code review for your completed stories
2) aire-dev-implement — start Wave [N+1] (when Wave [N] fully done)
3) Pick up an unassigned story from this wave (if any remain)
```

---

## Execution Steps:

### Phase 1: Preparation & Context
- [ ] Read story requirements (from local plan, Jira, or GitHub), noting action items, acceptance criteria, and what is IN/OUT of scope. In story files the implementation details live in the **🤖 AI Agent Reference** section — the **👤 User Reference** section is the plain-English summary for stakeholders.
- [ ] **FIRST: Read all reference files IN FULL** listed in the "Must Read" section (images, specs, designs, PRD from `SPEC/references/`). These are binding requirements, not background — extract every requirement, constraint, and numeric threshold they impose on this story. Do NOT skim, and do NOT skip a reference because the story body "looks complete."
- [ ] Review context: read ONLY the files the story names in its "Context files to read" / "Patterns" sections, plus the specific existing code you'll extend. The story is self-contained — do NOT blanket-read `docs/architecture/`; open an architecture doc only if the story explicitly cites it.
- [ ] **Build snapshot** (if story has `**BUILDID**: N`): read `docs/plans/implementation-plan.md` → count total stories under `### Build N`. Count existing files in `docs/stories-implemented/` matching that build. Note: `Build N — X of Y stories done`. Use this at end.
- [ ] **Resolve doubts from references BEFORE asking the user (MANDATORY)**: If anything seems unclear, missing, or contradictory, first try to resolve it from the story body + the Must Read / Context references you just read. The answer is almost always there — that is why those files are listed. Only escalate a question to the user when the story **and** all its references together leave a genuine, unresolved gap; when you do, state which references you read and exactly what they failed to answer. ❌ Never HALT with a clarifying question whose answer is in a listed reference.
- [ ] **MANDATORY**: Summarize what will be implemented (lead with the story's 👤 User Reference summary, then the technical scope). Enumerate **every** acceptance criterion and every reference-derived requirement you will satisfy so scope coverage is explicit. State only assumptions that survived the reference check above, ask any genuinely unresolved questions, and **GET USER APPROVAL** to proceed. **HALT until explicitly confirmed.**
- [ ] **TRACKER ID CHECK — MANDATORY (all modes, all spawn types, before any code)**:

  Open the story file. Read its header and collect every tracker field that is **not** `LOCAL` or absent:
  - `**Jira**: <KEY>` — e.g., `PROJ-123`
  - `**GitHub**: #<N>` — e.g., `#42`
  - `**AzureDevOps**: #<N>` — e.g., `#101`

  If **none** are real IDs, skip this block entirely. If **any** are real IDs, emit **one combined prompt** (all found trackers in a single table — never one prompt per board):

  ```
  ❓ This story has tracker links. Move to In Progress before we start?

  | Board        | ID       | Move to        |
  |--------------|----------|----------------|
  | Jira         | PROJ-123 | In Progress    |
  | GitHub       | #42      | In Development |
  | Azure DevOps | #101     | Active         |

  1) Yes — update all now
  2) Partial — tell me which to skip
  3) No — I'll update the boards myself
  ```

  **Only after user confirms** — for each confirmed board, run the matching OP from the 🧰 Tracker Operations Reference with the **Start work** column of the status mapping table, plus assignment and a "Development started via AIRE SDLC Agentic Framework" comment:

  - Jira → **OP-1**, status "In Progress"
  - GitHub → **OP-2**, board Status "In Development"
  - Azure DevOps → **OP-3**, state "Active"

  Run each OP's VERIFY. **NEVER update any board without explicit user confirmation.**

- [ ] Update **## Story Tracker** in `docs/status.md` — set **Start** date to today (`[YYYY-MM-DD]`).

### Phase 2: Implementation (Strict Execution Order)
- [ ] **Reusability Check (MANDATORY before writing any code)**: For every component, utility, hook, or helper you are about to create:
  1. Search the codebase for an existing implementation.
  2. If found in the correct shared location → use it, do not create a new one.
  3. If found in a feature folder but it is generic (no business logic, usable across 2+ features) → use it, flag it as tech debt for migration to the shared library, do not imitate its location.
  4. If it does not exist and is generic → create it in the project's shared component library, not the feature folder.
  5. If it does not exist and is feature-specific → create it in the feature folder.
  Cross-check against the UI Primitive Catalogue in the patterns document before proceeding.
- [ ] **Write Unit Tests First (TDD)**: Create test file covering happy paths, edge cases, and error scenarios. Run tests — they should fail initially.
- [ ] **Implement Code**: Implement in correct location. Apply SOLID principles, documented naming conventions, error handling, and logging patterns. Keep functions small and focused.
- [ ] **Verify Unit Tests**: Run unit tests. All tests must pass. 
- [ ] **Write Integration/E2E Tests**: Test integration points with real dependencies (or test doubles) and error scenarios.
- [ ] **Run Full Test Suite**: All tests must pass (100%). Capture test output as evidence. 
- [ ] **Quality Checks**: Verify test coverage is ≥85%. Verify zero lint warnings/errors.

### Phase 2.5: Requirement Coverage Gate (MANDATORY — blocks completion)
- [ ] **Run the Definition of Done — Compliance Gates** from `SPEC/rulebooks/aire-implementation-rulebook.md` before declaring the story complete. Build the Spec Echo table (Gate 1) with **one row per**: every acceptance criterion, every numbered Step, and every requirement carried by the Must Read / Context references (PRD, design specs, API/UX contracts). Each row cites the `file:line` (or command + output) that proves it.
- [ ] **Coverage assertion**: the number of AC rows MUST equal the number of AC in the story, and every Step + every reference requirement must have a proven row. If any requirement is unproven — or you find a requirement you did NOT implement — the story is **NOT done**: keep it 🟡 In Progress, implement the gap, and re-run the gate. Tests passing is necessary but not sufficient (tests-green ≠ spec-met).
- [ ] Run Gate 2 (Negative-Space — prove each "must NOT" / out-of-scope rule) and Gate 3 (Contract Consistency). Paste all gate evidence into the story review doc under "## DoD Evidence". A failing gate keeps status at In Progress — never flip to ✅ Done.

### Phase 3: Status & Documentation
- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md` (Update Epic row progress, add story to Completed Steps with test evidence).
- [ ] Create `docs/stories-implemented/story-[N.M]-review.md`.
- [ ] Document what was implemented, patterns applied, challenges and solutions, and lessons learned.
---

## Output

**Locations**:
- Implemented code with tests
- `docs/stories-implemented/story-[N.M]-review.md`

### Story Self-Review Template

```markdown
# Story [N.M] Self-Review

**Date**: [YYYY-MM-DD]  
**Story**: [Story Name]  
**Developer**: DEV Agent

---

## What Was Implemented

- [Feature/component 1]
- [Feature/component 2]

## Files Changed

| File | Change Type | Description |
|------|-------------|-------------|
| `path/to/file.js` | New | [What it does] |
| `path/to/test.js` | New | [What it tests] |
| `path/to/existing.js` | Modified | [What changed] |

## Patterns Applied

| Pattern | Where Applied | Notes |
|---------|---------------|-------|
| Error handling | `userService.js` | Used standard pattern from arch docs |
| Logging | All new functions | Structured logging with context |
| Test patterns | `userService.test.js` | AAA pattern, descriptive names |

## Testing Summary

- **Unit Tests**: [X] written, all passing
- **Integration Tests**: [Y] written, all passing  
- **Coverage**: [Z]% (target: 85%)

**Test Output**:
```
[Paste test output here]
```

## DoD Evidence


## Challenges Encountered

| Challenge | Resolution | Time Spent |
|-----------|------------|------------|
| [Challenge 1] | [How resolved] | [X hours] |

## Deviations from Plan

- None / [Description with justification]

## Lessons Learned

1. [Lesson 1]
2. [Lesson 2]

## Next Steps

- [ ] Ready for code review
- [ ] Ready for Unit test validation
```


---

## Rules

- 🔴 Tests WITH code - never postpone (TDD)
- 🔴 Run ALL tests after every change
- 🔴 Execute every step and AC IN ORDER and run the story to completion in one pass — don't stop at "milestones"/"good progress"; only a real HALT condition or genuine completion ends the run
- 🔴 Update status with EVIDENCE (test logs + coverage)
- 🔴 No TODO comments in production
- 🔴 Never skip action items
- 🔴 Zero lint errors allowed
- 🔴 NEVER skip stories on agent judgment (e.g., "no code needed") — present the assessment and let the user decide which story to implement
- 🔴 **RESOLVE FROM REFERENCES BEFORE ASKING** — read every Must Read / Context reference in full first; resolve any doubt or contradiction from the story + those references. Ask the user ONLY for gaps the story and all its references genuinely leave unresolved, and say which references you checked. Never HALT with a question whose answer is in a listed reference.
- 🔴 **COVER THE WHOLE STORY** — implement EVERY acceptance criterion, EVERY numbered step, and EVERY requirement carried by the Must Read references / PRD. A partial / happy-path implementation marked done is a violation. Phase 2.5's Requirement Coverage Gate (DoD Gates 1–3 in the rulebook) MUST pass before any status flips to ✅ Done; tests-green ≠ spec-met.
- 🔴 MUST confirm before coding — after reading the story, summarise scope and ask "proceed?" HALT until the user explicitly confirms. Do NOT write any code, create any files, or run any commands before this confirmation
- 🔴 **UNIVERSAL TRACKER RULE — no exceptions**: For EVERY story, in EVERY mode (sequential one-by-one, in-one-go parallel, any spawn type, any dev slot), at TWO mandatory points:
  - **Before implementation**: read the story file header; if `**Jira**:`, `**GitHub**:`, or `**AzureDevOps**:` is a real ID (not `LOCAL` / absent), ask to move to In Progress / In Development / Active. One combined prompt for all boards found. Never skip this because "the user already picked it from the tracker" or "it's in-one-go mode".
  - **After implementation**: ask to move to In Review / In QA / Done (graduated options — never only "Done"). One combined prompt for all boards found.
  All board updates go through **OP-1 / OP-2 / OP-3** in the 🧰 Tracker Operations Reference — never improvised commands — and every OP ends with its VERIFY. NEVER update any board without explicit user confirmation. NEVER assume the user wants to skip.
---

## Story Completion

> ⛔ **Precondition — the Requirement Coverage Gate (Phase 2.5) MUST have passed.** Do not run any step below until every acceptance criterion, every numbered Step, and every Must Read / PRD requirement has a proven row in the Gate 1 Spec Echo table and Gates 2–3 pass. If anything is unproven, the story stays 🟡 In Progress — go back and implement the gap. Never flip a board or `docs/status.md` to ✅ Done on a partial implementation.

When a story is complete, do the following steps in order:

### 1. Update `docs/status.md`

Per `SPEC/templates/STATUS_FORMAT.md`:
- Update the Epic row progress: `[Y]/[Z] stories done`
- Add the story to **Completed Steps** with test evidence (pass count + coverage %)
- Update **Current Step Details** checklist — mark this story ✅
- Update **Upcoming** — show next story to implement
- Update **Agent Activity** — DEV active with last story completed
- Update **## Story Tracker** — set **End** date to today (`[YYYY-MM-DD]`) for this story
- Update **## Quality Metrics**:
  - **Unit Test Coverage**: set Current to latest coverage %, Status to ✅ if ≥85% or 🟡 if below
  - **Integration Tests**: set Current to pass count (e.g., `100% (15/15)`), Status to ✅ if all pass or 🟡 if failures
  - **Documentation**: increment `[done]/[total]` count (story-review doc created)
- Update **## Build Cycles** table:
  - Set cycle status to `🟡 In Progress` if not already
  - Update **Stories** column: `[done]/[total]` (e.g., `3/6` → `4/6`)

### 2. Update GitHub Issue Status (if GitHub tracking active)

> **Skip if the story header has no `**GitHub**: #N` field.**

If the story file has a `**GitHub**: #N` reference (set by `aire-greenfield-plan` / `aire-brownfield-plan`):

```
✅ Story implementation complete!

Tests: [X/X passing]
Coverage: [XX%]

❓ This story is GitHub issue #N.
   Would you like me to:
   1) Move the board Status to "In Review" (PR opened, awaiting review)
   2) Move the board Status to "In QA" (merged, ready for QA)
   3) Move the board Status to "Done" (accepted)
   4) Skip — I'll update the board myself
```

**Only after user confirms** → run **OP-2** (🧰 Tracker Operations Reference) with the chosen Status (In Review / In QA / Done), plus a completion comment carrying the evidence (tests X/X, coverage XX%, lint clean, PR URL if created). If the user chose **Done**, also close the issue (`gh issue close N --reason completed`). Then OP-2's VERIFY.

**NOTE**: If built-in project workflows (Manual Step 3 of `aire-project-kickoff`) are enabled (PR merged → Done, Review approved → In QA), the board may transition automatically when the PR is merged. In that case, skip the Status update here and only post the completion comment.

**NEVER update the board without explicit user confirmation.**

---

### 3. Update Azure DevOps Work Item Status

> **Skip if the story header has no `**AzureDevOps**: #N` field.**

If the story file has an `**AzureDevOps**: #N` reference:

```
✅ Story implementation complete!

Tests: [X/X passing]
Coverage: [XX%]

❓ This story is Azure DevOps Work Item #N.
   Would you like me to:
   1) Move to "In Review"  — PR opened, awaiting code review
   2) Move to "In QA"      — merged / review approved, ready for QA testing
   3) Move to "Resolved"   — implementation done, awaiting sign-off / acceptance
   4) Move to "Closed"     — fully accepted
   5) Skip                 — I'll update the board myself
```

**Only after user confirms** → run **OP-3** (🧰 Tracker Operations Reference) with the chosen state (see the status mapping table for the Azure default-workflow fallbacks), plus a `--discussion` completion comment carrying the evidence (tests X/X, coverage XX%, lint clean, PR URL if created). Then OP-3's VERIFY.

**NEVER update the work item without explicit user confirmation.**

---

### 4. Update Jira Story Status

If story has a Jira ID (`**Jira**: PROJ-123`, not `LOCAL`):

```
✅ Story implementation complete!

Tests: [X/X passing]
Coverage: [XX%]

❓ This story is Jira [JIRA-ID].
   Would you like me to:
   1) Move to "In Review"  — PR opened, awaiting code review
   2) Move to "In QA"      — merged / review approved, ready for QA testing
   3) Move to "Done"       — accepted, all checks passed
   4) Skip                 — I'll update Jira myself
```

**Only after user confirms** → run **OP-1** (🧰 Tracker Operations Reference) with the chosen status (In Review / In QA / Done), plus a completion comment carrying the evidence (tests X/X, coverage XX%, implementation summary, PR URL if created). Then OP-1's VERIFY.

**If user chose "Done"**, also ask:
```
❓ Set resolution to "Done" and close the issue? (yes/no)
```

**If Skip / No**: Story marked complete locally only.

### 5. Build Cycle Check

If story has `**BUILDID**: CYCLE-[N]`: use the snapshot from Phase 1 — if this was the **last remaining story** in this cycle (X+1 = Y):

**a) Update `docs/status.md` → `## Build Cycles` table:**
- Set the **End Date** for CYCLE-[N] to today's date (`[YYYY-MM-DD]`)
- Set status to `✅ Complete`

**b) Announce completion:**
```
🎉 Cycle [N] Complete! All [Y] stories implemented and tested.
```

**c) Update Jira fixVersion release date (Jira tracker only):**
```
❓ All stories for CYCLE-[N] are done.
   Should I set the release date on fixVersion "cycle-[N]" in Jira? (yes/no)
```

**If YES**:
```
@atlassian-rovo Update version "cycle-[N]" in project [PROJECT_KEY]:
- Set releaseDate to today's date ([YYYY-MM-DD])
- Set released to true
- Add description: "Cycle [N] — [scope summary]. All [Y] stories complete."
```
Report: `✅ Jira fixVersion "cycle-[N]" marked as released ([YYYY-MM-DD])`

**c') Publish GitHub draft Release (GitHub tracker only):**

If `docs/plans/builds/cycle-[N]/cycle-plan.md` has a `## GitHub Release Plan` block referencing a draft release tag `v<cycle-tag>`:

```
❓ All stories for CYCLE-[N] are done.
   Should I publish the draft GitHub Release "v<cycle-tag>"? (yes/no)
```

**If YES**:

```bash
# Flip the draft release to published
gh release edit "v<cycle-tag>" --repo "ORG/REPO" --draft=false --latest

# Post a summary comment on every issue in this cycle (optional)
for n in $(gh issue list --repo "ORG/REPO" --state all --label "cycle:N" --json number --jq '.[].number'); do
  gh issue comment "$n" --repo "ORG/REPO" --body "CYCLE-N released: https://github.com/ORG/REPO/releases/tag/v<cycle-tag>"
done
```

Report: `✅ GitHub Release v<cycle-tag> published ([YYYY-MM-DD])`

**d) Prompt next cycle:**
```
❓ Start Cycle [N+1]? (yes / no)
```
- yes → present first story of Cycle N+1
- no → summarize what Cycle N delivered

### 6. Present Next Options

```
✅ Story [N.M] Complete!

📊 Evidence:
- Tests: [X/X passing]
- Coverage: [XX%]
- Linter: [Clean/Issues]

🔗 Jira: Story marked "Done" [if applicable]
🐙 GitHub: Issue #N moved to [In Review / In QA / Done] [if applicable]
🔷 Azure DevOps: Work Item #N moved to [Resolved / Closed] [if applicable]

What would you like to do next?

⭐ RECOMMENDED but optional:
1️⃣  **aire-review-code** - Request code review for this story
2️⃣  **aire-qa-test-plan** - Create QA test plan against requirements

▶️ CONTINUE:
3️⃣  Type **aire-dev-implement**



💡 Recommended flow: aire-review-code → aire-qa-test-plan → implement next story

Type your choice (e.g., "aire-review-code" or "pick next from github")
```

**Tell me which story to implement, then type "proceed".**


