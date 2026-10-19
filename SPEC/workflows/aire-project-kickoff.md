---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: AIRE INITIALIZER - Greenfield Project Kickoff. Initialize project tracking for a new (greenfield) project.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# AIRE INITIALIZER - Greenfield Project Kickoff

> **This workflow is the entry point for GREENFIELD projects only.** 

## Agent

**AIRE_INITIALIZER** 

## Before Starting

1. Read `SPEC/agents/AIRE_INITIALIZER.md`
2. If `docs/helix/INDEX.md` exists (synced by `aire-helix-sync`), read it and skim the listed `docs/helix/documents/` — prior Helix solution context (discovery notes, existing product docs) that should inform kickoff. Read-only; never edit synced files.

---

## Execution Steps:

### Phase 1: Initialize Tracking

- [ ] **CRITICAL**: Read `SPEC/templates/STATUS_FORMAT.md` — this is the mandatory format for `docs/status.md`
- [ ] Create `docs/status.md` following the exact format in `SPEC/templates/STATUS_FORMAT.md`
- [ ] Set **Updated By** to the agent running kickoff
- [ ] Set **Overall Status** to `🟡 IN PROGRESS`
- [ ] Add applicable Step rows to Progress Summary (only rows relevant to this project type)
- [ ] All Step rows start as `⏸️ Not Started` except the first active step

### Phase 2: Project Tracking Setup (Optional - ALWAYS ASK)

**Present options to user**:

> **RULE — MANDATORY**: Always display the full block below exactly as written, including the Prerequisites section. Never show only the options list without the prerequisites. Do not paraphrase, summarize, or omit any part of this block.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Project Tracking Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You can track this project using:

📁 OPTION 1: Local         — docs/status.md only
🔗 OPTION 2: Jira          — via @atlassian-rovo
🐙 OPTION 3: GitHub        — via `gh` CLI (Projects V2 + Issues + Milestones)
🔷 OPTION 4: Azure DevOps  — via `az boards` CLI (Boards + Work Items + Iterations)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  Prerequisites (always check before selecting):
   🐙 GitHub Projects  → requires the `gh` CLI to be installed and authenticated. See the README for setup instructions.
   🔷 Azure DevOps     → requires the `az` CLI to be installed with the `azure-devops` extension. See the README for setup instruction 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❓ Which tracking?  Type: 'local' | 'jira' | 'github' | 'azure-devops' | 'skip'
```


#### Jira Setup Path (if user chose 'jira')

##### Step A — Existing or new?

```
❓ Use an existing Jira project/board, or create a new one? (existing/new/cancel)
```

##### Step B (existing) — Capture keys, skip creation

```
❓ Enter Jira project key (e.g., PROJ):
❓ Enter Jira board ID/key (or 'auto' to use the project's default board):
❓ Enter Jira site URL (e.g., https://acme.atlassian.net):
```

Verify via `@atlassian-rovo` that the project + board exist. If not, fall back to "new" path. Skip directly to **Step D**.

##### Step C (new) — Confirm and create

```
📋 Create Jira project:
   Name: [from docs/requirements.md]
   Key: [USER_PROVIDED]
   Type: Software / Scrum
   Board: Sprint board (Backlog, To Do, In Progress, In Review, Done)
❓ Proceed? (yes/no)
```

If yes, via `@atlassian-rovo`: create project, board with the columns above, Sprint 1 (2-week duration starting today). Capture project key, board ID, site URL.

##### Step D — Save tracking block to `docs/status.md`

Append (or update if already present):

```
## Project Tracking

**Tracking**: Jira
**Site**: https://YOURSITE.atlassian.net
**Project Key**: PROJ
**Project URL**: https://YOURSITE.atlassian.net/jira/software/projects/PROJ
**Board ID**: 123
**Board URL**: https://YOURSITE.atlassian.net/jira/software/projects/PROJ/boards/123
**Active Sprint**: Sprint 1 (or N/A if existing project)
```

Downstream workflows read this block to decide Jira vs GitHub vs local.

---

#### GitHub Projects Setup Path (if user chose 'github')

> **Rule for the agent running this workflow: execute every `gh` command yourself via the Bash tool. Do not ask the user to run them. If any command fails with "already exists" / 422, skip and continue. If `gh auth status` fails, stop and tell the user to run `gh auth login -s repo,project,read:org`.**

##### Step A — Pre-flight

Run both in the CLI yourself:

```bash
gh --version
gh auth status
```

If auth is missing scopes:

```bash
gh auth refresh -s repo,project,read:org
```

##### Step B — Ask user for repo URL

```
❓ Enter the GitHub repo URL (e.g., https://github.com/ORG/REPO):
   Or type 'cancel' to skip.
```

Parse the URL. Store `ORG=<owner>` and `REPO=<owner>/<name>`. Verify the repo:

```bash
gh repo view "ORG/REPO" --json name -q ".name"
```

##### Step C — Check for an existing Project, or create one

```bash
gh project list --owner "ORG" --format json
```

- If a project already fits → ask user: `Reuse project #N "<title>"? (yes/no)`
- Otherwise ask for a new title, then:

```bash
gh project create --owner "ORG" --title "PROJECT_NAME"
gh project list --owner "ORG" --format json
```

Capture the new **project number** (`number`) and **project node id** (`id`, starts with `PVT_`).

##### Step C.5 — Link project to repo

> **Without this step the project and repo stay disconnected: issues from `ORG/REPO` won't show in the project's Auto-add picker, the repo's Projects tab won't list this project, and `gh issue create --project` from repo context won't find it.**

```bash
gh project link PROJECT_NUMBER --owner "ORG" --repo "ORG/REPO"
```

Verify:

```bash
gh project view PROJECT_NUMBER --owner "ORG" --format json --jq '.url'
```

If `gh project link` is unavailable (older `gh`), fall back to GraphQL:

```bash
REPO_NODE_ID=$(gh repo view "ORG/REPO" --json id -q .id)
gh api graphql -f query='
mutation($projectId:ID!,$repoId:ID!){
  linkProjectV2ToRepository(input:{projectId:$projectId,repositoryId:$repoId}){
    repository { nameWithOwner }
  }
}' -f projectId="PROJECT_ID" -f repoId="$REPO_NODE_ID"
```

If the command fails with "already linked" / 422, skip and continue.

##### Step D — Clean default labels (non-fatal)

```bash
gh label delete "good first issue" --repo "ORG/REPO" --yes || true
gh label delete "help wanted" --repo "ORG/REPO" --yes || true
gh label delete "invalid" --repo "ORG/REPO" --yes || true
gh label delete "question" --repo "ORG/REPO" --yes || true
gh label delete "wontfix" --repo "ORG/REPO" --yes || true
```

##### Step E — Create labels (type, priority, size, status)

```bash
# Type
gh label create "story"         --color "1D76DB" --repo "ORG/REPO" --force --description "User story"
gh label create "bug"           --color "D73A4A" --repo "ORG/REPO" --force --description "Defect"
gh label create "task"          --color "E4E669" --repo "ORG/REPO" --force --description "Task/chore"
gh label create "enhancement"   --color "A2EEEF" --repo "ORG/REPO" --force --description "Improvement"
gh label create "tech-debt"     --color "F9D0C4" --repo "ORG/REPO" --force --description "Refactor"
gh label create "documentation" --color "0075CA" --repo "ORG/REPO" --force --description "Docs"
gh label create "test"          --color "C5DEF5" --repo "ORG/REPO" --force --description "Test-only change"
gh label create "infra"         --color "BFD4F2" --repo "ORG/REPO" --force --description "Infra/DevOps"

# Priority
gh label create "P0-critical" --color "B60205" --repo "ORG/REPO" --force --description "Blocks release"
gh label create "P1-high"     --color "D93F0B" --repo "ORG/REPO" --force --description "Must fix this sprint"
gh label create "P2-medium"   --color "FBCA04" --repo "ORG/REPO" --force --description "Plan next sprint"
gh label create "P3-low"      --color "0E8A16" --repo "ORG/REPO" --force --description "Backlog"

# Size
gh label create "XS" --color "C2E0C6" --repo "ORG/REPO" --force --description "1 point"
gh label create "S"  --color "C2E0C6" --repo "ORG/REPO" --force --description "2 points"
gh label create "M"  --color "FEF2C0" --repo "ORG/REPO" --force --description "3-5 points"
gh label create "L"  --color "F9D0C4" --repo "ORG/REPO" --force --description "8 points"
gh label create "XL" --color "E99695" --repo "ORG/REPO" --force --description "13 points — split"

# Severity (for bugs)
gh label create "severity:critical" --color "B60205" --repo "ORG/REPO" --force
gh label create "severity:high"     --color "D93F0B" --repo "ORG/REPO" --force
gh label create "severity:medium"   --color "FBCA04" --repo "ORG/REPO" --force
gh label create "severity:low"      --color "0E8A16" --repo "ORG/REPO" --force

# Status/process
gh label create "blocked"     --color "B60205" --repo "ORG/REPO" --force
gh label create "needs-review" --color "FBCA04" --repo "ORG/REPO" --force
gh label create "duplicate"   --color "CFD3D7" --repo "ORG/REPO" --force
```

`epic:N` and `cycle:N` labels are created later by `aire-build-cycles` and `aire-*-plan`.

##### Step F — Issue templates, PR template, CODEOWNERS

> **Path rule: write these files to the actual repo root — NOT to `.scratch/`, NOT to any sandbox path.** The paths below are relative to the repo root (the same directory where `git status` runs). If the sandbox blocks the write, ask the user to approve writing to `.github/**`; do not silently stage under `.scratch/`.

Write these files only if they do not already exist (skip-if-present):

- `.github/ISSUE_TEMPLATE/story.yml` — story form (labels: `[story]`; fields: Epic, Story ID, Story Points, User Story, Acceptance Criteria, E2E Coverage, DoD)
- `.github/ISSUE_TEMPLATE/bug.yml` — bug form (labels: `[bug]`; fields: Parent Story, Severity, Browser, Description, Steps, Evidence, Environment)
- `.github/ISSUE_TEMPLATE/task.yml` — task form (labels: `[task]`; fields: Category, Description, Done When)
- `.github/ISSUE_TEMPLATE/config.yml` — `blank_issues_enabled: false`, contact link to project board
- `.github/PULL_REQUEST_TEMPLATE.md` — Summary, Changes, Testing, Accessibility, Screenshots, Related Issues
- `.github/CODEOWNERS` — ask user for lead/frontend/infra/qa GitHub usernames, write ownership rules

Then commit + push:

```bash
git add .github/ISSUE_TEMPLATE/ .github/PULL_REQUEST_TEMPLATE.md .github/CODEOWNERS
git commit -m "chore: bootstrap GitHub Projects templates + CODEOWNERS"
git push
```

##### Step G — Custom project fields

Use `PROJECT_NUMBER` from Step C. Retrieve `PROJECT_ID` (node id starting `PVT_`) from `gh project list --owner "ORG" --format json`.

```bash
# Priority (single select)
gh project field-create PROJECT_NUMBER --owner "ORG" --name "Priority" --data-type "SINGLE_SELECT"

# Story Points (number)
gh project field-create PROJECT_NUMBER --owner "ORG" --name "Story Points" --data-type "NUMBER"

# Release (single select — options added by aire-build-cycles, one per build cycle)
gh project field-create PROJECT_NUMBER --owner "ORG" --name "Release" --data-type "SINGLE_SELECT"
```

> **⚠️ Do NOT try to create the Sprint field with `gh project field-create --data-type ITERATION`.** `gh` does not support creating ITERATION fields — the call silently does nothing or errors in a way the agent may miss. Use GraphQL:

```bash
gh api graphql -f query='
mutation($projectId:ID!){
  createProjectV2Field(input:{
    projectId:$projectId,
    dataType:ITERATION,
    name:"Sprint",
    iterationConfiguration:{duration:14, startDate:"'"$(date +%Y-%m-%d)"'"}
  }){ projectV2Field{ ... on ProjectV2IterationField { id name } } }
}' -f projectId="PROJECT_ID"
```

Retrieve all field IDs (needed by downstream workflows) — **use `--jq` (built into `gh`) so you do not depend on a separate `jq` binary**:

```bash
gh project field-list PROJECT_NUMBER --owner "ORG" --format json \
  --jq '.fields[] | {name, id}'
```

Capture these IDs into `docs/status.md` — **you MUST read them back from the `field-list` output above; do not reuse IDs from earlier `field-create` responses, which are easy to mix up**:
- `PRIORITY_FIELD_ID`
- `STORY_POINTS_FIELD_ID`
- `SPRINT_FIELD_ID`
- `RELEASE_FIELD_ID` (empty options — populated by `aire-build-cycles`)
- `STATUS_FIELD_ID` (auto-created by GitHub — look for `name == "Status"` in the output)

> **⚠️ ID-mix-up trap:** Priority, Release, and Status are all `PVTSSF_*` single-select IDs and look identical. Agents have mis-targeted Priority when they meant Status and silently overwritten the wrong field's options. Before each of the two mutations below, re-read the field list and confirm the id by name.

Then set the Priority field options via GraphQL:

```bash
gh api graphql -f query='
mutation($projectId:ID!,$fieldId:ID!){
  updateProjectV2Field(input:{projectId:$projectId,fieldId:$fieldId,singleSelectOptions:[
    {name:"P0-Critical",color:RED,description:"Drop everything"}
    {name:"P1-High",color:ORANGE,description:"This sprint"}
    {name:"P2-Medium",color:YELLOW,description:"Next sprint"}
    {name:"P3-Low",color:GREEN,description:"Backlog"}
  ]}){ projectV2Field{ ... on ProjectV2SingleSelectField { id name } } }
}' -f projectId="PROJECT_ID" -f fieldId="PRIORITY_FIELD_ID"
```

Set Status field options (overwrite the default):

```bash
gh api graphql -f query='
mutation($projectId:ID!,$fieldId:ID!){
  updateProjectV2Field(input:{projectId:$projectId,fieldId:$fieldId,singleSelectOptions:[
    {name:"Backlog",color:GRAY}
    {name:"Sprint Ready",color:BLUE}
    {name:"In Development",color:YELLOW}
    {name:"In Review",color:ORANGE}
    {name:"In QA",color:PURPLE}
    {name:"Done",color:GREEN}
    {name:"Blocked",color:RED}
  ]}){ projectV2Field{ ... on ProjectV2SingleSelectField { id name } } }
}' -f projectId="PROJECT_ID" -f fieldId="STATUS_FIELD_ID"
```

**Verify both mutations landed on the intended fields** (if either shows the wrong options, re-read `field-list` — you used the wrong id):

```bash
gh project field-list PROJECT_NUMBER --owner "ORG" --format json \
  --jq '.fields[] | select(.name=="Status" or .name=="Priority") | {name, id, options: [.options[]?.name]}'
```

Expected: Status → `["Backlog","Sprint Ready","In Development","In Review","In QA","Done","Blocked"]` and Priority → `["P0-Critical","P1-High","P2-Medium","P3-Low"]`. If these are swapped, you overwrote the wrong field — re-run both mutations with the correct ids.

##### Step H — Save tracking block to `docs/status.md`

Append (or update if already present) this exact block to `docs/status.md`:

```
## Project Tracking

**Tracking**: GitHub Projects
**Repo**: https://github.com/ORG/REPO
**Project**: https://github.com/orgs/ORG/projects/PROJECT_NUMBER
**Project Number**: PROJECT_NUMBER
**Project Node ID**: PVT_xxx
**Priority Field ID**: PVTSSF_xxx
**Story Points Field ID**: PVTF_xxx
**Sprint Field ID**: PVTIF_xxx
**Release Field ID**: PVTSSF_xxx
**Status Field ID**: PVTSSF_xxx
```

Downstream workflows (`aire-build-cycles`, `aire-greenfield-plan`, `aire-brownfield-plan`, `aire-qa-triage`) read this block to decide GitHub vs Jira vs local.

##### Step I — Print manual UI steps (GitHub has no API for these)

> **⚠️ Rule: do NOT tell the user to manually update Status field options or create the Sprint iteration field — both are automated above. If you find yourself listing either as "manual", the automation in Step G failed silently and you must re-run it, not hand it off to the user.**

```
⚠️  Manual UI steps required (GitHub has no public API for these):
   1. Create custom views: Current Sprint (Board), Backlog (Table),
      My Work (Board), By Epic (Table), Bug Triage (Table),
      Release Roadmap (Roadmap), Done This Sprint (Board)
   2. Workflows → enable: Auto-add, Item closed→Done, PR merged→Done,
      Review approved→In QA, Changes requested→In Development
   3. Insights charts: Burn-Up, Velocity, Bug Trend, Epic Progress
```

Branch protection on `main` is automatable — do not list it as manual. Run:

```bash
gh api -X PUT "repos/ORG/REPO/branches/main/protection" \
  -F required_pull_request_reviews.required_approving_review_count=1 \
  -F required_status_checks.strict=true \
  -F required_status_checks.contexts='[]' \
  -F enforce_admins=true \
  -F restrictions= \
  -F required_linear_history=false \
  -F allow_force_pushes=false \
  -F allow_deletions=false
```

---

#### Azure DevOps Boards Setup Path (if user chose 'azure-devops')

> **Rule for the agent running this workflow: execute every `az` command yourself via the Bash tool. Do not ask the user to run them. If any command fails with "already exists", skip and continue.**

##### Step AA — Pre-flight

Run in the CLI yourself:

```bash
az --version
az devops configure --list
az extension add --name azure-devops --only-show-errors || true
az login --allow-no-subscriptions
```

If `az` is not installed, stop and tell the user: "Install the Azure CLI from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli and re-run `az login` before retrying."

##### Step AB — Ask org URL and project name

```
❓ Enter your Azure DevOps organization URL (e.g., https://dev.azure.com/my-org):
❓ Enter the Azure DevOps project name (e.g., MyProject):
```

Set CLI defaults and verify the project exists:

```bash
az devops configure --defaults organization={ORG_URL} project={PROJECT_NAME}
az devops project show --project "{PROJECT_NAME}" --query "name" -o tsv
```

If the project does not exist, ask:
```
❓ Project "{PROJECT_NAME}" not found. Create it? (yes/no)
```
If yes: `az devops project create --name "{PROJECT_NAME}" --process Agile --source-control git`

##### Step AC — Create or reuse Team

```bash
az devops team list --project "{PROJECT_NAME}" --query "[].name" -o tsv
```

Ask user:
```
❓ Which team to use? (paste existing team name, or type 'new' to create one)
   If 'new': what name?
```

If new:
```bash
az devops team create --name "{TEAM_NAME}" --project "{PROJECT_NAME}"
```

Capture `TEAM_NAME`.

##### Step AD — Create Sprint 1 Iteration

```bash
az boards iteration project create \
  --name "Sprint 1" \
  --project "{PROJECT_NAME}" \
  --start-date "$(date +%Y-%m-%d)" \
  --finish-date "$(date -v +14d +%Y-%m-%d 2>/dev/null || date -d '+14 days' +%Y-%m-%d)"
```

Capture the iteration path returned (e.g., `{PROJECT_NAME}\Sprint 1`). Store as `ITERATION_PATH`.

```bash
az boards iteration team add \
  --team "{TEAM_NAME}" \
  --id "{ITERATION_PATH}" \
  --project "{PROJECT_NAME}"
```

##### Step AE — Set Area Path for Team

```bash
az boards area team add \
  --team "{TEAM_NAME}" \
  --path "{PROJECT_NAME}" \
  --project "{PROJECT_NAME}"
```

##### Step AF — Verify board is reachable

```bash
az boards query \
  --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '{PROJECT_NAME}' AND [System.WorkItemType] = 'User Story' ORDER BY [System.CreatedDate] DESC" \
  --project "{PROJECT_NAME}" --top 1
```

If this fails, report the error to the user — do not continue silently.

##### Step AG — Save tracking block to `docs/status.md`

Append (or update if already present):

```
## Project Tracking

**Tracking**: Azure DevOps
**Org URL**: {ORG_URL}
**Project**: {PROJECT_NAME}
**Team**: {TEAM_NAME}
**Sprint 1 Iteration Path**: {ITERATION_PATH}
**Board URL**: {ORG_URL}/{PROJECT_NAME}/_boards/board/t/{TEAM_NAME}/Stories
**Backlog URL**: {ORG_URL}/{PROJECT_NAME}/_backlogs/backlog/{TEAM_NAME}/Stories
```

Downstream workflows read this block to decide Azure DevOps vs Jira vs GitHub vs local.

##### Step AH — Print manual UI steps (Azure DevOps has no public API for board view customization)

```
⚠️  Manual UI steps required (no public API for these):
   1. Open Board URL and configure columns: Backlog, Active, Resolved, Closed
   2. Add fields to cards: Story Points, Priority, Iteration Path
   3. Create custom queries / dashboards as needed
   4. Configure team notifications (optional)
```

---

### Phase 3: Plan Kickoff
- [ ] Identify first epic
- [ ] Identify first story
- [ ] Assign to DEV agent
- [ ] ✅ Jira: First sprint configured (if applicable)
- [ ] ✅ GitHub: Project + labels + fields bootstrapped (if applicable)
- [ ] ✅ Azure DevOps: Sprint 1 iteration created and team configured (if applicable)

### Phase 4: Communication
- [ ] Create project overview
- [ ] Brief team on objectives
- [ ] Schedule first check-in

---

## Output

**Locations**:
- `docs/status.md` - Project status tracker


---

**Type "proceed" to initialize project tracking.**

---

## 🔄 Next Steps in AIRE Workflow

**You are here → `aire-project-kickoff`**

| # | Next Command | Purpose |
|---|-------------|---------|
| ▶️ | `aire-greenfield-requirements` | Gather and define project requirements |

