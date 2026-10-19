---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: DevOps - Full Deployment. Server setup, Terraform IaC, SSL, monitoring, and runbook documentation.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

## Agent

**DEVOPS** 

## Before Starting

1. Read `SPEC/agents/AIRE_DEVOPS.md`
2. Read `SPEC/rulebooks/aire-devops-rulebook.md`
3. Read `docs/deployment/discovery-report.md` (REQUIRED)
4. Read existing `.github/workflows/` (if CI/CD already created via `aire-devops-pipeline`)
5. Read "Jira Stories", "GitHub Issues", and/or "Azure DevOps Work Items" section from `docs/deployment/discovery-report.md` and/or `docs/deployment/infra-evolution-plan.md` (if exists — extract linked tracker IDs for status update after deployment)
6. Read `docs/status.md` → `## Project Tracking` block to determine active tracker: `**Tracking**: Jira` | `**Tracking**: GitHub Projects` | `**Tracking**: Azure DevOps` | neither. Capture `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `STATUS_FIELD_ID` if GitHub; capture `ORG_URL`, `PROJECT` if Azure DevOps.

---

## Prerequisites Check

- [ ] `docs/deployment/discovery-report.md` exists and is approved
- [ ] If missing: **STOP** — tell user to run `aire-devops-discover` first
- [ ] If CI/CD not created yet: recommend `aire-devops-pipeline` first, or include it in this workflow

---

## Execution Steps:

### Phase 1: Deployment Plan

- [ ] Define target architecture from discovery report (serverless or server-based)
- [ ] Define environment strategy (dev, staging, production)
- [ ] Define secret management approach
- [ ] Define rollback strategy
- [ ] Define health check strategy
- [ ] Include **infrastructure naming table** — every resource name as provided by user in discovery
- [ ] Include **service dependency graph** with startup/deploy order
- [ ] Include **selected Terraform modules** with user-provided names
- [ ] If WAF requested, include WAF module config with OWASP rule set
- [ ] Note: "DNS: Manual configuration — required records listed in runbook"
- [ ] Create `docs/deployment/deployment-plan.md`
- [ ] **Present plan (including naming table and dependency graph) to user and get approval before proceeding**

### Phase 2: Server Setup Scripts

- [ ] Create `deploy/server-setup.sh` — OS packages, Docker install, firewall (UFW)
- [ ] Create `deploy/app-setup.sh` — App directory structure, permissions, log dirs
- [ ] **RULE D1**: If using host-level Nginx, configure it here. If container Nginx, do NOT install Nginx on host.
- [ ] **RULE N1**: `limit_req_zone` in `/etc/nginx/conf.d/rate-limit.conf` (http context), NOT inside `server {}`
- [ ] **RULE N2**: Apply `limit_req zone=... burst=... nodelay;` inside `location` blocks
- [ ] **RULE N3**: Always validate with `nginx -t` before restart

### Phase 3: Infrastructure as Code (Terraform)

**Only if user requested IaC in discovery:**

#### 3a: Backend Bootstrap (CRITICAL — must exist before `terraform init`)

- [ ] Create `terraform/bootstrap/main.tf` — self-contained config (local backend) that creates ALL prerequisites:
  - Resource Group for tfstate storage
  - Storage Account (HTTPS-only, TLS 1.2, blob versioning) for tfstate
  - Storage Container for tfstate blob
  - Service Principal permissions (if needed for CI runner)
  - Any other foundational resources required before main Terraform can initialize
- [ ] Create `terraform/bootstrap/variables.tf` — project_prefix, location, environment (from discovery report)
- [ ] Create `terraform/bootstrap/outputs.tf` — outputs all values needed by main backend config
- [ ] **RULE B1**: Bootstrap MUST use local backend — no circular dependency
- [ ] **RULE B2**: All names derived from discovery report — NEVER hardcoded (e.g., no `rg-mip-tfstate`)
- [ ] **RULE B3**: Bootstrap MUST be idempotent — safe to re-run

#### 3b: Self-Sufficient Terraform (CRITICAL — create EVERYTHING, assume NOTHING)

**The Terraform config MUST create EVERY cloud resource it depends on. The only assumptions allowed are: (1) Azure subscription exists, (2) bootstrap backend resources exist.**

- [ ] **RULE T8**: If `variables.tf` already exists, READ it first — ask user to clarify any unclear variable names
- [ ] **RULE T11**: Create root `variables.tf` with core infra params from discovery (resource_group, location, VNet, subnet, project_prefix, environment) — ALL values from discovery, defined ONCE, used everywhere
- [ ] **RULE T7**: ALL resource names derived from discovery report — NEVER auto-generate or hardcode
- [ ] Create modular Terraform structure: `terraform/main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`
- [ ] **RULE SS1 (Self-Sufficiency)**: Terraform MUST create ALL of the following that are needed:
  - Resource Groups for every environment and service tier — NEVER assume pre-existing
  - VNet, Subnets, NSGs — complete networking stack from scratch
  - Key Vault with access policies for service principal and app services
  - Container Registry (ACR) if Docker images are used
  - App Service Plans BEFORE App Services
  - SQL Server BEFORE SQL Databases
  - Storage Accounts BEFORE any blob/queue/table usage
  - Log Analytics Workspace BEFORE any diagnostic settings
  - Application Insights BEFORE any app that references its instrumentation key
  - Private DNS Zones BEFORE private endpoints (if requested)
  - Managed Identities BEFORE any role assignments
  - Provider registrations (e.g., `Microsoft.Web`, `Microsoft.Sql`, `Microsoft.KeyVault`)
- [ ] **RULE SS2**: Module dependency order MUST be explicit — use `depends_on` or output-to-input variable chaining
- [ ] **RULE SS3**: NEVER use `data` sources to look up resources that Terraform itself should manage — use `resource` blocks instead
- [ ] **RULE SS4**: `terraform plan` on a clean subscription (with only bootstrap resources) MUST succeed with zero errors
- [ ] Create ONLY the modules the user selected in discovery:
  - [ ] `modules/resource-groups/` — creates ALL resource groups needed by other modules
  - [ ] `modules/network/` — VNet, subnets (names from discovery)
  - [ ] `modules/security/` — NSG, firewall rules
  - [ ] `modules/app-service/` — **Frontend + Backend together in ONE module (RULE T9)** — NEVER create separate FE/BE modules
  - [ ] `modules/database/` — only if selected, with discovery-provided name and type
  - [ ] `modules/cache/` — only if selected (Redis, etc.), with discovery-provided name
  - [ ] `modules/storage/` — only if selected, with discovery-provided name
  - [ ] `modules/container-registry/` — only if selected, with discovery-provided name
  - [ ] `modules/waf/` — **ONLY if user explicitly requested WAF (RULE T10)**, with OWASP rule set
  - [ ] `modules/monitoring/` — only if selected (Log Analytics + App Insights), with discovery-provided name
  - [ ] `modules/key-vault/` — only if selected, with discovery-provided name
- [ ] **Service Interdependency**: Set `depends_on` in Terraform based on dependency graph from discovery
- [ ] Create environment tfvars: `terraform/environments/staging.tfvars`, `production.tfvars` — using discovery-provided names
- [ ] Create `terraform/.gitignore` (exclude `.tfstate`, `.terraform/`, `*.pem`)
- [ ] Create cloud-init bootstrap script for VM provisioning (server-based only)
- [ ] **RULE T1**: Remote backend MUST be enabled — backend config values MUST match bootstrap outputs
- [ ] **RULE T2**: No `timestamp()` or non-deterministic functions in tags
- [ ] **RULE T3**: Every declared module variable MUST be used
- [ ] **RULE T4**: `prevent_deletion_if_contains_resources = true` for production
- [ ] **RULE T5**: SSH NSG rules MUST allow CI runner IPs when deploy uses SSH
- [ ] **RULE T6**: Terraform CI workflow covers ALL environments
- [ ] **DNS**: Document required DNS records in runbook — user configures DNS manually

#### 3c: Generated Codebase Validation (CRITICAL — validate ALL generated deployment code, not just Terraform)

**After generating ALL deployment artifacts (Terraform, shell scripts, Docker, workflows, Nginx, Makefile, etc.), validate the ENTIRE codebase end-to-end. Do NOT present deliverables with errors — fix them first.**

**Terraform Validation:**
- [ ] Run `terraform validate` on all generated Terraform code
- [ ] Run `terraform fmt -check` to verify formatting
- [ ] Verify all module cross-references resolve (no missing variables, no undefined outputs)
- [ ] Verify all resource dependencies are explicit — no implicit ordering that could fail
- [ ] Check for circular dependencies between modules
- [ ] Verify no hardcoded subscription IDs, tenant IDs, or resource names — all from variables/discovery
- [ ] Verify `terraform plan` would succeed on a clean subscription (walkthrough resource creation order)
- [ ] Verify backend config values match what bootstrap creates

**Shell Script Validation:**
- [ ] Run `bash -n <script>` (syntax check) on every `.sh` file generated (`server-setup.sh`, `app-setup.sh`, `setup-ssl.sh`, `healthcheck.sh`, etc.)
- [ ] Verify all scripts use correct shebang (`#!/bin/bash` or `#!/usr/bin/env bash`)
- [ ] Verify all referenced paths, binaries, and commands exist or are installed earlier in the script
- [ ] Verify scripts don't assume pre-existing state (directories, packages, users) without creating/installing them first
- [ ] Verify environment variables referenced in scripts are documented in secrets/env docs
- [ ] Verify no hardcoded IPs, passwords, tokens, or secrets in any script

**Docker & Compose Validation:**
- [ ] Verify `Dockerfile` builds successfully (correct base image, valid COPY paths, valid RUN commands)
- [ ] Verify all `docker-compose*.yml` files pass `docker compose config` syntax validation
- [ ] Verify all images/services referenced in compose files are either built or available
- [ ] Verify volume mounts reference paths that exist or are created
- [ ] Verify environment variables in compose files are documented and sourced from `.env` or secrets

**CI/CD Pipeline Validation (platform from discovery):**
- [ ] Verify all pipeline files have valid YAML syntax
- [ ] (GitHub) Verify all referenced actions exist and use pinned versions (e.g., `actions/checkout@v4`, not `@main`)
- [ ] (GitLab) Verify all stages, jobs, and includes are valid
- [ ] (Bitbucket) Verify all steps and pipes are valid
- [ ] Verify all secrets/variables referenced in pipelines are documented in `pipeline-secrets.md`
- [ ] Verify all file paths referenced in pipeline steps exist in the repo
- [ ] (GitHub) Verify job dependency chains (`needs:`) are correct and complete

**Nginx Validation:**
- [ ] Verify `nginx -t` would pass on generated config (correct directive syntax, matching braces)
- [ ] Verify upstream names match actual service names in Docker Compose
- [ ] Verify SSL cert paths match what `setup-ssl.sh` creates

**Makefile Validation:**
- [ ] Verify all Makefile targets reference valid commands and file paths
- [ ] Verify targets for bootstrap, plan, apply, destroy, deploy, rollback all work end-to-end

**Cross-File Consistency:**
- [ ] Every file path referenced anywhere (workflows, scripts, Makefile, runbooks) MUST exist in the repo
- [ ] Every environment variable referenced anywhere MUST be documented in one place
- [ ] Every secret referenced anywhere MUST be listed in `pipeline-secrets.md`
- [ ] Service names MUST be consistent across Terraform, Docker Compose, Nginx, and workflows
- [ ] Port numbers MUST be consistent across Dockerfile, Compose, Nginx, and health checks

**If ANY errors found: fix them immediately — NEVER present broken deliverables to the user**

### Phase 4: SSL & Domain

**Only if domain provided in discovery:**

- [ ] Create `deploy/setup-ssl.sh` — Certbot installation + certificate request
- [ ] Create Nginx HTTPS configuration with redirect
- [ ] Configure auto-renewal cron
- [ ] Configure HSTS headers

### Phase 5: Monitoring & Health

- [ ] Create `deploy/healthcheck.sh` — Curl-based health check with auto-restart
- [ ] Configure health check cron (every 5 minutes)
- [ ] Create `deploy/logrotate.conf` — 14-day retention, compressed
- [ ] Configure centralized logging (if requested in discovery)
- [ ] Configure alerting (if requested)

### Phase 6: Documentation & Runbooks

- [ ] Create `docs/deployment/runbook-deploy.md` — Step-by-step deploy instructions
- [ ] Create `docs/deployment/runbook-rollback.md` — Rollback procedures
- [ ] Create `docs/deployment/runbook-troubleshoot.md` — Common issues and fixes
- [ ] Create `docs/deployment/architecture.md` — Deployment architecture diagram
- [ ] Create `docs/deployment/quick-reference.md` — Commands cheat sheet
- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "DevOps Deploy" row to `✅ Done`, evidence: `docs/deployment/runbook-deploy.md`

### Phase 7: Post-Generation Validation

**MANDATORY — Run ALL checks from DEVOPS.md Post-Generation Validation section AND the full codebase validation from Phase 3c:**

- [ ] **Run Phase 3c validation** (Terraform, shell scripts, Docker, workflows, Nginx, Makefile, cross-file consistency)
- [ ] All GitHub Actions workflow checks (W1-W4)
- [ ] All Docker & Compose checks (D1-D5)
- [ ] All Nginx checks (N1-N3)
- [ ] All Rollback checks (R1-R2)
- [ ] All Bootstrap checks (B1-B3) — if applicable
- [ ] All Self-Sufficiency checks (SS1-SS4) — if applicable
- [ ] All Terraform checks (T1-T11) — if applicable:
  - [ ] T1-T6: Standard Terraform integrity
  - [ ] T7: All resource names from discovery report — no auto-generated names
  - [ ] T8: Existing `variables.tf` read and unclear names clarified
  - [ ] T9: Frontend + backend in SINGLE App Service module
  - [ ] T10: WAF only if user requested
  - [ ] T11: Core infra params defined once, passed to all modules
- [ ] File cross-reference check (F1-F2)
- [ ] Out-of-scope exclusion check:
  - [ ] G1: No Storage Queues in any module
  - [ ] G2: No Private Endpoint: Queue in any module
  - [ ] G3: No ADF Diagnostic Settings in any module
  - [ ] G4: No Logic Apps in any module
  - [ ] G5: Private DNS Zones only if user explicitly requested
- [ ] Present cross-reference table to user
- [ ] **If any validation fails: fix before presenting deliverables — NEVER ship broken code**

### Phase 8: Tracker Story Completion

**After ALL deployment artifacts are generated and validated, update linked tracker items if any.**

- [ ] Check `docs/deployment/discovery-report.md` for a "Jira Stories" section, a "GitHub Issues" section, and an "Azure DevOps Work Items" section
- [ ] Check `docs/deployment/infra-evolution-plan.md` for the same (if exists)
- [ ] Route by active tracker (from `docs/status.md` Project Tracking block):

#### Jira path (if `**Tracking**: Jira` or Jira Stories section found)

If Jira stories found in either document:

```
📋 Jira Story Completion

Deployment setup is complete. The following Jira stories are linked:

| Jira ID | Title | Current Status |
|---------|-------|----------------|
| PROJ-123 | [title] | In Progress |
| PROJ-124 | [title] | In Progress |

Would you like to mark them as done?
  [D] Yes — mark all as Done/Closed
  [N] Move to next status (e.g., In Review, Ready for QA)
  [S] Skip — don't update Jira status

Choose D, N, or S:
```

- [ ] If D or N: Use `@atlassian-rovo` to transition each issue:
  1. `@atlassian-rovo get transitions for issue [JIRA-ID]` — get available transitions
  2. `@atlassian-rovo transition issue [JIRA-ID]` to the selected status (Done, Closed, or next status)
  3. Optionally add a comment: `@atlassian-rovo add comment to issue [JIRA-ID]` — "DevOps deployment setup complete. See docs/deployment/runbook-deploy.md for details."
  4. Confirm transition to user

#### GitHub path (if `**Tracking**: GitHub Projects` or GitHub Issues section found)

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user. If 422 "already exists", skip and continue.**

If GitHub issues found (issue numbers listed as `#N` in the discovery/evolution docs):

```
📋 GitHub Issue Completion

Deployment setup is complete. The following GitHub issues are linked:

| Issue | Title | Current Status |
|-------|-------|----------------|
| #123 | [title] | In Development |
| #124 | [title] | In Review |

Would you like to update them?
  [D] Mark all as Done (Status → Done, close issue)
  [R] Move to "In Review" (deployment ready, awaiting stakeholder sign-off)
  [S] Skip — don't update GitHub

Choose D, R, or S:
```

If D or R, for each issue:

```bash
# Resolve item id in the project
ISSUE_ID=$(gh api "repos/ORG/REPO/issues/N" --jq '.node_id')
ITEM_ID=$(gh project item-list PROJECT_NUMBER --owner "ORG" --format json --limit 500 \
  | python -c "import sys,json; d=json.load(sys.stdin); print(next(i['id'] for i in d['items'] if i.get('content',{}).get('number')==N))")

# Set Status → chosen option
gh api graphql -f query='
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){ projectV2Item{ id } }
}' -f projectId="PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="STATUS_FIELD_ID" -f optionId="STATUS_OPTION_ID_<Done|In Review>"

# Post deployment comment
gh issue comment N --repo "ORG/REPO" --body "DevOps deployment setup complete. See docs/deployment/runbook-deploy.md."

# Close if D
gh issue close N --repo "ORG/REPO" --reason completed
```

#### Azure DevOps path (if `**Tracking**: Azure DevOps` or Azure DevOps Work Items section found)

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user.**

If Azure DevOps work items found (IDs listed as `#N` in the discovery/evolution docs):

```
📋 Azure DevOps Work Item Completion

Deployment setup is complete. The following work items are linked:

| Work Item ID | Title | Current State |
|-------------|-------|---------------|
| #123 | [title] | Active |
| #124 | [title] | Active |

Would you like to update them?
  [D] Closed   — fully accepted and deployed
  [R] Resolved — deployment done, awaiting sign-off
  [S] Skip     — don't update

Choose D, R, or S:
```

If D or R, for each work item:

```bash
# Update state
az boards work-item update \
  --id N \
  --state "Resolved" \
  --project "{PROJECT}"

# Post deployment comment
az boards work-item update \
  --id N \
  --discussion "DevOps deployment setup complete. See docs/deployment/runbook-deploy.md for details." \
  --project "{PROJECT}"
```

If D (Closed), additionally:

```bash
az boards work-item update --id N --state "Closed" --project "{PROJECT}"
```

- [ ] If no tracker items found in any path: skip silently
- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`

---

## Output

**Files Created**:
- `docs/deployment/deployment-plan.md`
- `deploy/server-setup.sh`
- `deploy/app-setup.sh`
- `deploy/healthcheck.sh`
- `deploy/logrotate.conf`
- `deploy/setup-ssl.sh` (if domain provided)
- `terraform/` directory (if IaC requested)
- `docs/deployment/runbook-deploy.md`
- `docs/deployment/runbook-rollback.md`
- `docs/deployment/runbook-troubleshoot.md`
- `docs/deployment/architecture.md`
- `docs/deployment/quick-reference.md`
- `docs/deployment/pipeline-secrets.md`

---

## Rules

- 🔴 Discovery report MUST exist before starting
- 🔴 User MUST approve deployment plan before execution
- 🔴 ONE reverse proxy — host OR container, never both
- 🔴 Nginx syntax validated with `nginx -t` before any restart
- 🔴 Terraform remote backend enabled for CI
- 🔴 No `timestamp()` in Terraform tags
- 🔴 Production resource groups protected from accidental deletion
- 🔴 SSH access allowed for CI runners when deploy uses SSH
- 🔴 ALL resource names from discovery report — never auto-generate or hardcode (RULE T7)
- 🔴 Read existing `variables.tf` and clarify unclear names (RULE T8)
- 🔴 Frontend + backend in ONE App Service module (RULE T9)
- 🔴 WAF only if user explicitly requested (RULE T10)
- 🔴 Core infra params defined once, used everywhere (RULE T11)
- 🔴 Bootstrap MUST create ALL tfstate prerequisites before `terraform init` — local backend, no circular deps (B1-B3)
- 🔴 Terraform MUST be fully self-sufficient — create EVERY resource (resource groups, networking, Key Vault, ACR, identities, etc.) — NEVER assume pre-existing (SS1-SS4)
- 🔴 NEVER use `data` sources to look up resources Terraform should manage
- 🔴 `terraform plan` on clean subscription MUST succeed with zero errors
- 🔴 ALL generated code validated before presenting — Terraform, shell scripts, Docker, workflows, Nginx, Makefile
- 🔴 Shell scripts syntax-checked (`bash -n`), no assumed pre-existing state, no hardcoded values
- 🔴 Cross-file consistency enforced — paths, env vars, secrets, service names, ports consistent everywhere
- 🔴 DNS is manual — document required records only, never auto-configure
- 🔴 Service interdependencies mapped and reflected in `depends_on`
- 🔴 Only create modules user selected in discovery — no extras
- 🚫 NEVER create Storage Queues, Private Endpoint: Queue, ADF Diagnostic Settings, or Logic Apps — out of scope
- 🚫 Private DNS Zones only if user explicitly requested in discovery
- 🔴 NEVER present broken deliverables — fix ALL errors before showing to user
- 🔴 No secrets in any file — ever
- 🔴 READ TRACKER STORIES from discovery report and/or evolution plan — extract Jira Story IDs ("Jira Stories" section), GitHub Issue numbers ("GitHub Issues" section), and Azure DevOps Work Item IDs ("Azure DevOps Work Items" section)
- 🔴 OFFER TRACKER COMPLETION — after deployment is complete, route to Jira (@atlassian-rovo), GitHub (`gh`), or Azure DevOps (`az boards`) based on `docs/status.md` Project Tracking block; offer to move items to Done/Resolved/Closed or next status
- 🔴 UPDATE STATUS.MD — update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md` after deployment

---

## Completion

```
╔══════════════════════════════════════════════════════════════════╗
║                    ✅ DEVOPS SETUP COMPLETE                      ║
╠══════════════════════════════════════════════════════════════════╣
║  📊 Deliverables Summary                                         ║
║  ├─ Discovery Report: docs/deployment/discovery-report.md        ║
║  ├─ Deployment Plan: docs/deployment/deployment-plan.md          ║
║  ├─ CI Pipeline: .github/workflows/ci.yml                        ║
║  ├─ Deploy Pipeline: .github/workflows/deploy-*.yml              ║
║  ├─ Docker Config: Dockerfile + docker-compose.*.yml             ║
║  ├─ Server Setup: deploy/server-setup.sh                         ║
║  ├─ Monitoring: deploy/healthcheck.sh                            ║
║  └─ Runbooks: docs/deployment/runbook-*.md                     ║
╠══════════════════════════════════════════════════════════════════╣
║  📋 Tracker                                                      ║
║  └─ [N] tracker items updated (Jira, GitHub, Azure DevOps, or "none linked") ║
╚══════════════════════════════════════════════════════════════════╝

```
**Type "proceed" to start the full deployment setup.**

---

## Next Steps — Interactive Command Execution (PRIORITY)

**After generating all files, determine the required post-generation commands from the created docs (runbook, deployment plan, pipeline-secrets.md, etc.).**

**MANDATORY protocol — for EVERY command identified:**

1. Display the command in a code block
2. One sentence: what it does and why
3. Ask the user: `"Run this command? (yes / skip / abort)"`
4. **Wait for reply before proceeding**
   - `yes` → execute on terminal, show output, then move to next command
   - `skip` → move to next command without running
   - `abort` → stop all remaining commands immediately
5. If a command fails → show error, ask user how to proceed before continuing

**Rules:**
- 🔴 NEVER run a command without explicit user confirmation
- 🔴 Commands that depend on a prior step must wait for that step's success before being presented
- 🔴 Non-command steps (e.g. "set this secret in portal") — describe the action, ask "Done? (yes/skip/abort)", wait for reply
- 🔴 Commands are derived from generated docs — do NOT hardcode; read what was created