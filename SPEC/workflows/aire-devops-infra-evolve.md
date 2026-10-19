---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: DevOps - Brownfield Infrastructure Evolution. Analyze existing IaC, CI/CD pipelines, and deployment configs, generate architecture design, gather user requirements for changes, and produce a secure evolution plan.
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
3. Read `docs/deployment/discovery-report.md` (if exists — not required for this workflow)
4. Read existing infrastructure files (Terraform, CI/CD pipelines, Docker configs — see Phase 1)

---

## Execution Steps:

### Phase 0: DevOps Reference Check (MANDATORY FIRST)

**Check `SPEC/references/devops/` for existing infrastructure documentation before scanning.**

1. **List Reference Directory**
   - [ ] List `SPEC/references/devops/`
   - [ ] Identify .docx, .pdf, .md, .txt, images, diagrams

2. **Process Documents**
   - [ ] For EACH .docx: `aire read SPEC/references/devops/<file>.docx`
   - [ ] For EACH .pdf: `aire read SPEC/references/devops/<file>.pdf`
   - [ ] If `aire read` fails: Ask user to run in CMD and paste output. **NEVER skip.**
   - [ ] Read .md/.txt files directly

3. **Process Images & Diagrams**
   - [ ] For EACH image in `SPEC/references/devops/` (.png, .jpg, .jpeg, .gif, .svg, .webp): **View the image directly**
   - [ ] Note architecture diagrams, network topology, cloud resource layouts, deployment flow diagrams
   - [ ] Note current vs target state diagrams, migration paths, environment structures
   - [ ] Note any resource names, IP ranges, port numbers, or configurations visible in diagrams
   - [ ] If a diagram shows infrastructure that contradicts the code scan (Phase 1), flag the conflict to the user

4. **Extract Pre-Existing Context**
   - [ ] Current infrastructure architecture (from docs, not code — code scan is Phase 1)
   - [ ] Planned changes or migration requirements documented by the team
   - [ ] Compliance or security requirements for infrastructure changes
   - [ ] Deployment target state or desired architecture
   - [ ] Operator/team preferences for tools, providers, naming conventions
   - [ ] Budget, timeline, or approval constraints

5. **Confirm**
   - [ ] Tell user: "Found [N] documents and [M] images in SPEC/references/devops/"
   - [ ] List what was found and key details extracted
   - [ ] Note: reference doc context will inform Phase 2 (architecture design) and Phase 3 (requirements gathering)

> **Rules**:
> - 🔴 NEVER skip .docx/.pdf — use `aire read` or ask user to run in CMD
> - 🔴 NEVER skip images — view ALL .png/.jpg/.jpeg/.gif/.svg/.webp files directly
> - 🔴 NEVER proceed without reading ALL reference documents and viewing ALL images
> - 🔴 Reference docs provide context, NOT override — the code scan (Phase 1) is the source of truth for current state
> - 🔴 Reference doc requirements inform Phase 3 questions — pre-fill where applicable, user confirms

---

### Phase 0.5: Tracker Story Integration

**Ask the user if they have an existing DevOps task/story on their tracker board.**

First check `docs/status.md` → `## Project Tracking` block to pre-filter options.

```
📋 How would you like to start?

[J] I have a DevOps task/story in Jira I want to work on
[G] I have a DevOps issue in GitHub I want to work on
[A] I have a DevOps task/story in Azure DevOps I want to work on
[S] I want to work from scratch — no tracker story

Choose J, G, A, or S:
```

---

#### PATH J: Work from Jira Story

##### J.1 — Fetch Story Details

Ask user:
```
❓ Paste the Jira story URL(s) — one per line:
   Example: https://your-org.atlassian.net/browse/PROJ-123
```

For each URL provided:
1. Extract the issue key from the URL (e.g., `PROJ-123`)
2. Use `@atlassian-rovo get issue [ISSUE-KEY]` to fetch full details
3. Extract: Story ID, Title, Description, Acceptance Criteria, Priority, Status

##### J.2 — Check Story Completeness

**A DevOps story is COMPLETE if it has ALL of**:
- [ ] **Description** — clear objective (what infrastructure evolution is needed and why)
- [ ] **Acceptance Criteria** — at least 1-2 items (e.g., "Add monitoring with Prometheus + Grafana to existing infra")

**A story is INCOMPLETE if ANY of the above is missing or too vague to act on.**

Report:
```
📊 Story Completeness Analysis:

[For each story]
Story [JIRA-ID]: [Title]
Status: ✅ COMPLETE / ⚠️ INCOMPLETE
Missing: [Description / Acceptance Criteria — whichever apply]
```

##### J.3 — Complete Incomplete Stories

For each **INCOMPLETE** story, ask clarifying questions:

```
❓ Clarifying Questions for [JIRA-ID]: [Title]

This story is missing: [Description / Acceptance Criteria].

[If Description missing or vague:]
1. What is the goal of this infrastructure evolution? What changes need to happen and why?

[If AC missing or too vague:]
2. What does "done" look like? Give me 2-3 specific outcomes.
   (e.g., "Staging environment added with separate Terraform workspace and deploy pipeline")

Please answer so I can proceed.
```

After user answers, all fields are now known. Repeat for ALL incomplete stories before proceeding.

##### J.4 — Record Jira Context

- [ ] Note the Jira story ID(s) for inclusion in the evolution plan
- [ ] Use the story description and AC to inform Phase 3 (requirements gathering) — pre-fill answers where the story provides enough detail
- [ ] Proceed to Prerequisites Check with Jira context loaded

---

#### PATH G: Work from GitHub Issue

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user. If 422 "already exists", skip and continue.**

##### G.1 — Fetch Issue Details

Ask user:
```
❓ Paste the GitHub issue URL(s) or `#N` number(s) — one per line:
   Example: https://github.com/ORG/REPO/issues/42   or   #42
```

From `docs/status.md` Project Tracking block, capture `ORG`, `REPO`, `PROJECT_NUMBER`, `PROJECT_ID`, `STATUS_FIELD_ID`.

For each issue:

```bash
gh issue view N --repo "ORG/REPO" --json number,title,body,state,labels,milestone,assignees,url
```

Extract: Issue number, Title, Body (User Story + Acceptance Criteria), Labels, Milestone, Current board Status (from `gh project item-list PROJECT_NUMBER --owner ORG --format json` matched by issue number).

##### G.2 — Check Issue Completeness

**A DevOps issue is COMPLETE if it has ALL of**:
- [ ] **Description / User Story** — clear objective (what infrastructure evolution is needed and why)
- [ ] **Acceptance Criteria** — at least 1-2 items (e.g., "Add monitoring with Prometheus + Grafana to existing infra")

**INCOMPLETE if missing or too vague.**

Report:
```
📊 Issue Completeness Analysis:

[For each issue]
Issue #N: [Title]
Status: ✅ COMPLETE / ⚠️ INCOMPLETE
Missing: [Description / AC — whichever apply]
```

##### G.3 — Complete Incomplete Issues

For each **INCOMPLETE** issue, ask the same clarifying questions used in J.3. After the user answers, **append the clarification to the issue body** so future readers see it:

```bash
gh issue comment N --repo "ORG/REPO" --body "$(cat <<'EOF'
### Clarification (captured during aire-devops-infra-evolve)

**Goal**: <user answer>

**Acceptance Criteria**:
- <AC 1>
- <AC 2>
EOF
)"
```

##### G.4 — Record GitHub Context

- [ ] Note the issue numbers for inclusion in the evolution plan
- [ ] Use body + AC to pre-inform Phase 3 requirements gathering
- [ ] Proceed to Prerequisites Check with GitHub context loaded

---

#### PATH A: Work from Azure DevOps Story

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user. Skip this path if `docs/status.md` does NOT contain `**Tracking**: Azure DevOps`.**

##### A.1 — Fetch Story Details

Ask user:
```
❓ Paste the Azure DevOps work item URL or ID:
   Example: https://dev.azure.com/my-org/MyProject/_workitems/edit/123
```

Extract work item ID and fetch:

```bash
az boards work-item show --id {WI_ID} --project "{PROJECT}"
```

##### A.2 — Check Completeness

Extract: Title, Description, Acceptance Criteria, State, Tags, Iteration Path. Apply the same three-field completeness check as other paths. Ask clarifying questions if incomplete.

##### A.3 — Pre-load Context

- [ ] Note work item ID for inclusion in `docs/deployment/infra-evolution-plan.md`
- [ ] Use Description + AC to pre-inform Phase 3 requirements questions
- [ ] Offer to mark work item as "Active" after user approves the evolution plan:
  ```
  ❓ Should I mark Work Item #{WI_ID} as "Active"? (yes/no)
  ```
  If YES:
  ```bash
  az boards work-item update --id {WI_ID} --state "Active" --project "{PROJECT}"
  ```

---

#### PATH S: Work from Scratch

- [ ] Proceed directly to Prerequisites Check — no tracker context
- [ ] At the end of this workflow (Phase 5), user will be offered to create/link a tracker story (Jira, GitHub, or Azure DevOps, depending on active tracker)

---

## Prerequisites Check

- [ ] Project has **existing infrastructure code** (at least ONE of the following):
  - Terraform / OpenTofu / Pulumi / CloudFormation / Bicep files
  - CI/CD pipeline files (`.github/workflows/`, `.gitlab-ci.yml`, `bitbucket-pipelines.yml`, `Jenkinsfile`, `azure-pipelines.yml`)
  - Docker / Docker Compose files
  - Ansible / Chef / Puppet / Salt configuration
  - Kubernetes manifests / Helm charts
  - Serverless framework config (`serverless.yml`, SAM templates)
- [ ] If **no existing infrastructure code found**: **STOP** — tell user this workflow is for brownfield projects with existing infra. Recommend `aire-devops-discover` + `aire-devops-pipeline` for greenfield setup.

---

## Process

### Phase 1: Infrastructure Discovery Scan

**Automatically scan the entire codebase to map ALL existing infrastructure artifacts. Do NOT ask the user — find everything first.**

#### 1a: IaC Discovery

- [ ] Scan for Terraform files: `**/*.tf`, `**/*.tfvars`, `**/*.tfbackend`, `terraform/`, `infra/`, `infrastructure/`
- [ ] If Terraform found:
  - [ ] Read `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `providers.tf`, `backend.tf`
  - [ ] List all modules (local and remote)
  - [ ] List all resources and data sources
  - [ ] List all variables — flag unclear or ambiguous names (RULE T8)
  - [ ] Identify backend configuration (local, S3, Azure Blob, GCS, Terraform Cloud)
  - [ ] Identify provider versions and constraints
  - [ ] Identify environment separation strategy (workspaces, directories, tfvars)
  - [ ] Check for state locking configuration
- [ ] Scan for other IaC: CloudFormation (`**/*.yaml`, `**/*.json` with `AWSTemplateFormatVersion`), Bicep (`**/*.bicep`), Pulumi (`Pulumi.yaml`), OpenTofu
- [ ] Scan for configuration management: Ansible (`playbook*.yml`, `inventory/`, `roles/`), Chef, Puppet, Salt

#### 1b: CI/CD Pipeline Discovery

- [ ] Scan for GitHub Actions: `.github/workflows/*.yml`
  - [ ] List all workflow files, triggers, jobs, steps
  - [ ] Identify reusable workflows and composite actions
  - [ ] List all secrets and variables referenced (`${{ secrets.* }}`, `${{ vars.* }}`)
  - [ ] Identify deployment targets and environments
- [ ] Scan for GitLab CI: `.gitlab-ci.yml`, `ci/` includes
  - [ ] List stages, jobs, includes, extends
  - [ ] Identify environment deployments and variables
- [ ] Scan for Bitbucket Pipelines: `bitbucket-pipelines.yml`
  - [ ] List pipelines, steps, pipes
  - [ ] Identify deployment targets
- [ ] Scan for other CI/CD: `Jenkinsfile`, `azure-pipelines.yml`, `circleci/config.yml`, `.travis.yml`
- [ ] Identify CI/CD tool versions and pinned action/image versions

#### 1c: Container & Orchestration Discovery

- [ ] Scan for Docker: `Dockerfile*`, `docker-compose*.yml`, `.dockerignore`
  - [ ] Base images used and their versions
  - [ ] Multi-stage build patterns
  - [ ] Port mappings and exposed ports
  - [ ] Volume mounts and network configurations
  - [ ] Environment variable injection patterns
- [ ] Scan for Kubernetes: `k8s/`, `kubernetes/`, `manifests/`, `**/*.yaml` with `apiVersion`
  - [ ] Deployments, Services, Ingress, ConfigMaps, Secrets
  - [ ] Namespace strategy
  - [ ] Resource requests/limits
- [ ] Scan for Helm charts: `charts/`, `Chart.yaml`, `values.yaml`
- [ ] Scan for serverless: `serverless.yml`, `template.yaml` (SAM), `app.yaml` (App Engine)

#### 1d: Security & Compliance Discovery

- [ ] Check for secret scanning config (`.gitleaks.toml`, `.trivyignore`, `.snyk`)
- [ ] Check for SAST/DAST tool configs (`sonar-project.properties`, `.semgrep.yml`, `codeql/`)
- [ ] Check for dependency scanning (`.github/dependabot.yml`, `.snyk`, `renovate.json`)
- [ ] Check for policy-as-code (OPA/Rego, Sentinel, Checkov, tfsec)
- [ ] Identify existing security gates in pipelines
- [ ] Check for SSL/TLS configurations
- [ ] Check for secrets management (Vault, AWS Secrets Manager, Azure Key Vault references)

#### 1e: Monitoring & Observability Discovery

- [ ] Check for monitoring configs (Prometheus, Grafana, Datadog, New Relic, CloudWatch)
- [ ] Check for health check endpoints and scripts
- [ ] Check for alerting configurations
- [ ] Check for log aggregation setup (ELK, Loki, CloudWatch Logs)
- [ ] Check for tracing setup (Jaeger, Zipkin, OpenTelemetry)

---

### Phase 2: Architecture Design Document

**Generate a comprehensive architecture design of the existing infrastructure. This becomes the baseline for all changes.**

- [ ] Create `docs/deployment/infra-current-state.md` with the following sections:

#### 2a: Infrastructure Architecture Diagram

- [ ] Create a Mermaid diagram showing:
  - All cloud resources and their relationships
  - Network topology (VNets/VPCs, subnets, security groups)
  - Data flow between services
  - CI/CD pipeline flow (trigger → build → test → deploy)
  - External integrations and dependencies

#### 2b: Infrastructure Inventory Table

- [ ] Create a table listing EVERY discovered resource:

  | Category | Tool/Service | File(s) | Version | Status |
  |----------|-------------|---------|---------|--------|
  | IaC | Terraform | `terraform/*.tf` | 1.x | Active |
  | CI/CD | GitHub Actions | `.github/workflows/*.yml` | - | Active |
  | Container | Docker | `Dockerfile`, `docker-compose.prod.yml` | - | Active |
  | ... | ... | ... | ... | ... |

#### 2c: Current Pipeline Flow

- [ ] Document the existing CI/CD pipeline end-to-end:
  - Trigger conditions (push, PR, manual, schedule)
  - Build steps and artifact creation
  - Test stages (unit, integration, e2e)
  - Security scanning stages (if any)
  - Deployment stages and target environments
  - Rollback mechanisms (if any)
  - Approval gates (if any)

#### 2d: Environment Matrix

- [ ] Document all environments discovered:

  | Environment | Deploy Method | Branch/Trigger | Infra Source | Secrets Source |
  |-------------|--------------|----------------|-------------|----------------|
  | dev | auto on push | `develop` | terraform/dev.tfvars | GitHub Secrets |
  | staging | auto on merge | `main` | terraform/staging.tfvars | GitHub Secrets |
  | production | manual approval | tag `v*` | terraform/prod.tfvars | Azure Key Vault |

#### 2e: Identified Gaps & Risks

- [ ] Flag issues found during scan:
  - Missing security scanning in pipelines
  - Unpinned action/image versions
  - Hardcoded secrets or credentials
  - Missing health checks or rollback mechanisms
  - Missing state locking for IaC
  - Outdated provider/tool versions
  - Missing `.dockerignore` or overly permissive COPY
  - No environment separation in IaC
  - Missing monitoring or alerting
  - Terraform state not backed by remote backend
  - Resources created outside of IaC (drift risk)
  - No branch protection or approval gates

#### 2f: Dependency Graph

- [ ] Create a Mermaid dependency graph of all services:
  - Which services depend on which
  - Startup/deploy order
  - Shared resources between services
  - External service dependencies

- [ ] **Present the full architecture design to the user and confirm accuracy before proceeding**

---

### Phase 3: User Requirements Gathering

**Ask the user what changes, additions, or improvements they want to make to the existing infrastructure. Present findings from Phase 2 to inform their decisions.**

- [ ] Present the gaps and risks identified in Phase 2e
- [ ] Ask the user the following questions in order:

#### 3a: Change Scope

1. **What is the primary goal of this infrastructure evolution?** (select all that apply):
   - Add new environments (e.g., staging, QA, performance)
   - Improve CI/CD pipeline (faster builds, more stages, better testing)
   - Add or improve security scanning (SAST, DAST, SCA, secret scanning)
   - Migrate or upgrade IaC (e.g., Terraform version upgrade, module refactor)
   - Add monitoring, alerting, or observability
   - Add or improve deployment strategy (blue-green, canary, rolling)
   - Add rollback capabilities
   - Containerize services or improve Docker setup
   - Add Kubernetes / Helm support
   - Fix identified gaps and risks
   - Other — describe

#### 3b: Specific Changes

2. **For each goal selected, ask specific follow-up questions:**

   - **New environments**: Which environments? What naming convention? Same infra as existing or different?
   - **CI/CD improvements**: Which platform are you staying on? What stages to add/change? Parallel jobs? Caching? Matrix builds?
   - **Security scanning**: Which tools? (Present options same as `aire-devops-discover` Step 9 — SonarQube, Semgrep, CodeQL, Snyk, ZAP, etc.)
   - **IaC migration/upgrade**: Target version? Module restructuring needed? State migration plan?
   - **Monitoring**: What tool? What metrics? Alerting thresholds? Who gets paged?
   - **Deployment strategy**: Blue-green, canary, or rolling? Traffic shifting percentages? Approval gates?
   - **Rollback**: Automated or manual? How far back? Database rollback included?
   - **Containerization**: Which services? Base images? Registry?
   - **Kubernetes**: Managed (EKS/AKS/GKE) or self-managed? Namespace strategy? Resource limits?
   - **Gap fixes**: Review each gap from Phase 2e — fix, skip, or defer?

3. **For any NEW modules being added or EXISTING modules being reconfigured, ask per-module configuration details** using the same question sets from `aire-devops-discover` Step 3.5. This includes:
   - Database (branched by type: SQL Server, PostgreSQL, MySQL, CosmosDB, MongoDB)
   - Storage (branched by platform: Azure Blob/ADLS, AWS S3, GCP Cloud Storage)
   - Serverless Functions (branched: Azure Functions, AWS Lambda, GCP Cloud Functions)
   - App Service / Web App (branched: Azure App Service, AWS EB/ECS, GCP App Engine/Cloud Run)
   - Static Web App (branched: Azure SWA, AWS Amplify/S3+CloudFront, GCP Firebase)
   - Key Vault / Secrets Manager (branched: Azure KV, AWS Secrets Manager/SSM, GCP Secret Manager)
   - Container Registry (branched: ACR, ECR, Artifact Registry, Docker Hub)
   - Monitoring (branched: Azure Monitor, CloudWatch, GCP Cloud Monitoring, third-party)
   - Front Door / CDN (branched: Azure Front Door, CloudFront, GCP Cloud CDN)
   - AI / ML (branched: Azure OpenAI, Cognitive Services, AWS Bedrock, GCP Vertex AI)
   - Data Factory / Orchestration (branched: ADF, AWS Glue/Step Functions, GCP Composer/Dataflow)
   - Cache (branched: Azure Redis, ElastiCache, Memorystore, self-hosted)
   - Message Queue (branched: Service Bus, SQS/SNS, RabbitMQ, Pub/Sub, Kafka/Event Hubs)

   > **Rule**: For each module, ask auth mode, SKU/tier, runtime version, network access, identity type, app settings, and linked service connections. Branch by platform and service variant. Never assume defaults. If reconfiguring an existing module, present current config and ask what should change.

#### 3c: Constraints & Preferences

3. **Are there any constraints or preferences?**
   - Budget limitations for new services/tools
   - Compliance requirements (SOC2, HIPAA, PCI-DSS, etc.)
   - Team familiarity — tools the team already knows vs. new ones
   - Timeline — is this a gradual rollout or big-bang migration?
   - Existing contracts with cloud/tool vendors
   - Approval process — who signs off on infra changes?

#### 3d: Risk Tolerance

4. **How should we handle the migration safely?**
   - Should changes be applied incrementally (one at a time) or all at once?
   - Do you want a parallel run period (old + new pipelines running simultaneously)?
   - Do you want a rollback plan for the infrastructure changes themselves?
   - Are there maintenance windows or freeze periods to respect?

- [ ] Wait for ALL user responses before proceeding
- [ ] Clarify any ambiguous answers

---

### Phase 4: Evolution Plan Document

**Generate a detailed, actionable plan document that `aire-devops-pipeline` can execute to make the changes safely in existing infrastructure.**

- [ ] Create `docs/deployment/infra-evolution-plan.md` with the following sections:

#### 4a: Executive Summary

- [ ] One-paragraph summary of what will change and why
- [ ] List of goals from user input
- [ ] Estimated scope (files to create, modify, delete)

#### 4b: Current State vs Target State

- [ ] Side-by-side comparison table:

  | Aspect | Current State | Target State | Change Type |
  |--------|--------------|-------------|-------------|
  | CI Pipeline | Basic lint + test | Lint + test + SAST + container scan | Modify |
  | IaC Backend | Local state | Remote S3 backend with locking | Modify |
  | Environments | prod only | dev, staging, prod | Add |
  | Rollback | None | Automated image rollback | Add |
  | Monitoring | None | Prometheus + Grafana | Add |
  | ... | ... | ... | ... |

#### 4b-2: Per-Module Configuration (for new or reconfigured modules)

- [ ] For each new or reconfigured module, include a configuration detail table:

  | Module | Setting | Current Value | Target Value | Source |
  |--------|---------|--------------|-------------|--------|
  | Database (PostgreSQL) | SKU/Instance | Azure: `GP_Standard_D2s_v3` / AWS: `db.r6g.large` / GCP: `db-custom-2-8192` | Upgrade to next tier | User request |
  | Database (PostgreSQL) | HA | disabled | zone-redundant / Multi-AZ / Regional | User request |
  | Secrets Manager | Access model | Access Policies / IAM / IAM Binding | RBAC / IAM Role / Workload Identity | Gap fix |
  | Compute | Auto-scale | manual (2 instances) | auto (2-6, CPU > 70%) | User request |
  | ... | ... | ... | ... | ... |

- [ ] If a reference document (PDF, PRD) provided configs, note "validated by user" next to each value

#### 4c: Change Manifest

- [ ] For EVERY file that will be created, modified, or deleted, list:

  | # | Action | File Path | Description | Risk Level | Rollback |
  |---|--------|-----------|-------------|------------|----------|
  | 1 | MODIFY | `.github/workflows/ci.yml` | Add SAST scanning stage | Low | Revert commit |
  | 2 | CREATE | `.github/workflows/deploy-staging.yml` | New staging deploy pipeline | Low | Delete file |
  | 3 | MODIFY | `terraform/main.tf` | Add monitoring module | Medium | `terraform destroy -target` |
  | 4 | MODIFY | `terraform/variables.tf` | Add new variables for monitoring | Low | Revert commit |
  | ... | ... | ... | ... | ... | ... |

- [ ] **Risk levels**: Low (additive, no existing behavior changed), Medium (modifies existing behavior, easy rollback), High (changes state, backend, or destructive — requires careful execution)

#### 4d: Execution Order

- [ ] Define the exact order of changes with dependencies:

  ```
  Step 1: [Low Risk] Add new variables to terraform/variables.tf
    ↓ (no dependency)
  Step 2: [Low Risk] Create new Terraform modules
    ↓ (depends on Step 1)
  Step 3: [Medium Risk] Modify main.tf to wire new modules
    ↓ (depends on Step 2)
  Step 4: [Medium Risk] Run terraform plan — review changes
    ↓ (depends on Step 3 — USER APPROVAL GATE)
  Step 5: [High Risk] Run terraform apply
    ↓ (depends on Step 4)
  Step 6: [Low Risk] Update CI/CD pipeline files
    ↓ (no dependency on Terraform)
  Step 7: [Low Risk] Add security scanning configs
  ```

- [ ] Mark USER APPROVAL GATES for high-risk steps
- [ ] Mark steps that can run in parallel vs. those that must be sequential

#### 4e: Safety Guardrails

- [ ] For each high/medium risk change, document:
  - **Pre-condition check**: What must be true before executing
  - **Validation step**: How to verify the change worked
  - **Rollback procedure**: Exact steps to undo if something breaks
  - **Blast radius**: What other systems/services could be affected

- [ ] Document the overall rollback strategy:
  - Git-level rollback (revert commits for file changes)
  - IaC-level rollback (`terraform plan` with previous tfvars, targeted destroy)
  - Pipeline-level rollback (re-run previous working pipeline version)
  - Data-level rollback (if applicable — database migrations, state files)

#### 4f: Secrets & Configuration Requirements

- [ ] List ALL new secrets/variables that need to be configured:

  | Secret/Variable | Where to Set | Purpose | Who Provides |
  |----------------|-------------|---------|-------------|
  | `SONAR_TOKEN` | GitHub Secrets | SonarQube authentication | DevOps team |
  | `STAGING_SSH_KEY` | GitHub Secrets | SSH deploy to staging server | Ops team |
  | ... | ... | ... | ... |

- [ ] **NEVER include actual secret values**
- [ ] Provide platform-specific instructions for setting each secret

#### 4g: Validation Checklist

- [ ] After ALL changes are applied, verify:
  - [ ] All existing pipelines still work (no regression)
  - [ ] New pipelines trigger correctly on expected events
  - [ ] Terraform plan shows only expected changes (no drift introduced)
  - [ ] All security scanning tools run and produce reports
  - [ ] Health checks pass for all environments
  - [ ] Rollback procedures tested (at least dry-run)
  - [ ] All secrets configured and accessible
  - [ ] No hardcoded secrets in any modified file
  - [ ] Cross-file consistency maintained (ports, service names, env vars)

#### 4h: Post-Evolution Monitoring

- [ ] Define what to monitor after changes are live:
  - Pipeline success/failure rate (before vs. after)
  - Deployment frequency and lead time
  - Mean time to recovery (MTTR)
  - Security scan findings trend
  - Infrastructure cost impact (if new resources added)

- [ ] **Present the full evolution plan to user and get approval before any execution**

---

### Phase 5: Tracker Story Management

**After the evolution plan is approved, manage tracker story tracking.**

#### If user started with Jira stories (PATH J):

- [ ] Ask user:

```
📋 Jira Story Update

Your evolution plan references these Jira stories:
  [List JIRA-IDs and titles]

Would you like to transition them?
  [P] Mark as In Progress
  [N] Move to next status (e.g., In Review, Ready for Dev)
  [S] Skip — don't update Jira status

Choose P, N, or S:
```

- [ ] If P or N: Use `@atlassian-rovo` to transition the issue:
  1. `@atlassian-rovo get transitions for issue [JIRA-ID]` — get available transitions
  2. `@atlassian-rovo transition issue [JIRA-ID]` to the selected status
  3. Confirm transition to user

#### If user started with GitHub issues (PATH G):

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user.**

- [ ] Ask user:

```
📋 GitHub Issue Update

Your evolution plan references these GitHub issues:
  [List #N and titles]

Would you like to transition them?
  [N] Move to next status (e.g., In Review)
  [S] Skip — don't update GitHub status

Choose N or S:
```

- [ ] If N, for each issue:

```bash
# Post evolution-plan-complete comment
gh issue comment N --repo "ORG/REPO" \
  --body "Infrastructure evolution plan approved. See docs/deployment/infra-evolution-plan.md for details."

# Move Status → "In Review"
ISSUE_ID=$(gh api "repos/ORG/REPO/issues/N" --jq '.node_id')
ITEM_ID=$(gh project item-list PROJECT_NUMBER --owner "ORG" --format json --limit 500 \
  | python -c "import sys,json; d=json.load(sys.stdin); print(next(i['id'] for i in d['items'] if i.get('content',{}).get('number')==N))")

gh api graphql -f query='
mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){ projectV2Item{ id } }
}' -f projectId="PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="STATUS_FIELD_ID" -f optionId="STATUS_OPTION_ID_<In Review>"
```

#### If user started with Azure DevOps stories (PATH A):

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user.**

- [ ] Ask user:

```
📋 Azure DevOps Work Item Update

Your evolution plan references these work items:
  [List #WI_ID and titles]

Would you like to transition them?
  [N] Move to next state (e.g., Active → In Review / Resolved)
  [S] Skip — don't update Azure DevOps status

Choose N or S:
```

- [ ] If N, for each work item:

```bash
# Post evolution-plan-approved comment
az boards work-item update \
  --id N \
  --discussion "Infrastructure evolution plan approved. See docs/deployment/infra-evolution-plan.md for details." \
  --project "{PROJECT}"

# Move to next state (Active → Resolved, or project-specific next state)
az boards work-item update --id N --state "Resolved" --project "{PROJECT}"
```

---

#### If user started from scratch (PATH S):

- [ ] Ask user:

```
📋 Tracker Story

Would you like to create a story for this infrastructure evolution work on your tracker board?
  [J] Yes — create a Jira story
  [G] Yes — create a GitHub issue
  [A] Yes — create an Azure DevOps work item
  [L] I'll link an existing story — paste the URL(s) or ID(s)
  [S] Skip — no tracker needed

Choose J, G, A, L, or S:
```

> **Rule**: Show ALL options regardless of what `docs/status.md` contains. Do NOT silently pre-filter to one tracker. Let the user choose.

**If J:**

- [ ] Ask for Jira project key, then create using `@atlassian-rovo create issue in project [PROJECT_KEY]` with a **detailed, structured story body** derived from the evolution plan — NOT a generic placeholder:
  - **FORMAT CONTRACT**: pass the `description` as **Markdown** with REAL line breaks (the Rovo MCP converts Markdown → Jira ADF). Use `##`/`**...**`, NOT wiki-markup `h2.`/`*...*`, and NEVER emit literal `\n` escape sequences, or Jira renders the body as plain text.
  - **Title**: `DevOps: Infrastructure evolution for [project name from plan]`
  - **Description / Objective**: State what is being evolved — which existing infra components are changing and why — drawn from Phase 4a Executive Summary
  - **Acceptance Criteria**: Derive specific, testable items directly from the Change Manifest (Phase 4c), for example:
    - Each planned file change (MODIFY/CREATE/DELETE) that represents a user-visible outcome becomes an AC item
    - All existing pipelines continue to work — no regression
    - New secrets/variables are configured and accessible
    - Evolution plan approved and available at `docs/deployment/infra-evolution-plan.md`
  - **Out of Scope**: List explicitly what is NOT in this story — gaps deferred from Phase 2e, DNS (manual), and that execution is handled by `aire-devops-pipeline`, not this issue
  - Record the created story ID in the evolution plan
  - Ask if they want to mark as In Progress (same flow as PATH J above)

> **Rule**: NEVER write a generic description. Build the story from actual evolution plan content — objective, AC, and out-of-scope must reflect the real Change Manifest and Executive Summary.

**If G:**

> **Rule for the agent: run every `gh` command yourself via the Bash tool. Do NOT ask the user.**

- [ ] Build a **detailed, structured issue body** from the evolution plan — NOT a generic one-liner. The body must contain:

  ```
  ## Objective
  [State what is being evolved: which existing infra components are changing and why — from Phase 4a Executive Summary]

  ## Acceptance Criteria
  - [ ] [Each planned change from the Change Manifest (Phase 4c) becomes a testable AC item, e.g.:]
  - [ ] [SAST scanning stage added to CI pipeline — all PRs must pass before merge]
  - [ ] [Staging Terraform workspace created with separate .tfvars and deploy pipeline]
  - [ ] [Remote IaC backend configured with state locking]
  - [ ] [New secrets/variables listed in Phase 4f are configured and accessible]
  - [ ] [All existing pipelines continue to work — no regression]
  - [ ] Evolution plan approved and available at docs/deployment/infra-evolution-plan.md
  [Tailor AC to the actual changes in the evolution plan — do not copy examples verbatim]

  ## Out of Scope
  - Changes not included in the evolution plan (list any explicitly deferred items from Phase 2e gaps)
  - DNS configuration — manual
  - Execution of the plan — this issue covers planning only; aire-devops-pipeline handles implementation
  [Add any tools or modules the user explicitly excluded]
  ```

  ```bash
  gh issue create --repo "ORG/REPO" \
    --title "DevOps: Infrastructure evolution for [project name]" \
    --body "$(cat <<'EOF'
  [Structured body as built above]
  EOF
  )"
  ```
  Record the created issue number in the evolution plan.
- [ ] Ask if they want to move to In Review (same flow as PATH G above).

> **Rule**: NEVER use a generic placeholder body. AC must map directly to the Change Manifest in the evolution plan. Out of Scope must list what was explicitly excluded or deferred.

**If A:**

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user.**

- [ ] Ask for project name, then create using `az boards work-item create` with a **detailed, structured description** from the evolution plan — NOT a generic placeholder:
  - **Title**: `DevOps: Infrastructure evolution for [project name from plan]`
  - **Description / Objective**: State what is being evolved — which existing infra components are changing and why — drawn from Phase 4a Executive Summary
  - **Acceptance Criteria**: Derive specific, testable items directly from the Change Manifest (Phase 4c) — each planned MODIFY/CREATE/DELETE that represents a user-visible outcome, plus "All existing pipelines continue to work — no regression"
  - **Out of Scope**: Gaps deferred from Phase 2e, DNS (manual), execution by `aire-devops-pipeline`

  ```bash
  az boards work-item create \
    --title "DevOps: Infrastructure evolution for [project name]" \
    --type "User Story" \
    --description "[Structured body: Objective + AC + Out of Scope derived from evolution plan]" \
    --project "{PROJECT}"
  ```
  Record the created work item ID in the evolution plan.
- [ ] Offer to mark as Active:
  ```
  ❓ Should I mark Work Item #{WI_ID} as "Active"? (yes/no)
  ```
  If YES:
  ```bash
  az boards work-item update --id {WI_ID} --state "Active" --project "{PROJECT}"
  ```

> **Rule**: NEVER use a generic placeholder description. Build from actual evolution plan content — objective, AC, and out-of-scope must reflect the real Change Manifest.

**If L:**

- [ ] Ask:
  ```
  ❓ Paste the URL(s) or ID(s) of the existing story/issue — one per line:
     Jira:         https://your-org.atlassian.net/browse/PROJ-123
     GitHub:       https://github.com/ORG/REPO/issues/42   or   #42
     Azure DevOps: https://dev.azure.com/org/project/_workitems/edit/123
  ```
- [ ] Detect tracker type from URL format, extract IDs, record in evolution plan.
- [ ] Ask if they want to transition (In Progress for Jira, In Review for GitHub, Active/Resolved for ADO) using the same flow as PATH J/G/A above.

**If S:** Skip — no tracker needed.

#### Update Evolution Plan with Tracker Story Numbers

- [ ] If Jira stories are linked, add a **"Jira Stories"** section to `docs/deployment/infra-evolution-plan.md`:

```markdown
## Jira Stories

| Jira ID | Title | Status | URL |
|---------|-------|--------|-----|
| PROJ-123 | Upgrade CI/CD pipeline | In Progress | https://your-org.atlassian.net/browse/PROJ-123 |
| PROJ-124 | Add monitoring to staging | In Progress | https://your-org.atlassian.net/browse/PROJ-124 |
```

- [ ] If GitHub issues are linked, add a **"GitHub Issues"** section to `docs/deployment/infra-evolution-plan.md`:

```markdown
## GitHub Issues

| Issue | Title | Status | URL |
|-------|-------|--------|-----|
| #42 | Upgrade CI/CD pipeline | In Review | https://github.com/ORG/REPO/issues/42 |
| #43 | Add monitoring to staging | In Review | https://github.com/ORG/REPO/issues/43 |
```

- [ ] If Azure DevOps work items are linked, add an **"Azure DevOps Work Items"** section to `docs/deployment/infra-evolution-plan.md`:

```markdown
## Azure DevOps Work Items

| Work Item ID | Title | Status | URL |
|-------------|-------|--------|-----|
| #123 | Upgrade CI/CD pipeline | Active | https://dev.azure.com/org/project/_workitems/edit/123 |
| #124 | Add monitoring to staging | Active | https://dev.azure.com/org/project/_workitems/edit/124 |
```

- [ ] These sections will be read by downstream workflows (`aire-devops-pipeline`, `aire-devops-deploy`) to update tracker story status upon completion.
- [ ] Also add the relevant section (Jira Stories, GitHub Issues, or Azure DevOps Work Items) to `docs/deployment/discovery-report.md` if it exists.

#### Update docs/status.md

- [ ] If `docs/status.md` does **not** exist: read `SPEC/templates/STATUS_FORMAT.md` and create `docs/status.md` from it (use the template as-is, filling in the project name and date). Do NOT skip this step — downstream workflows depend on `docs/status.md` being present.
- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "DevOps Infra Evolve" row to `✅ Done`, evidence: `docs/deployment/infra-evolution-plan.md`

---

## Output

**Files Created**:
- `docs/deployment/infra-current-state.md` — Architecture design of existing infrastructure
- `docs/deployment/infra-evolution-plan.md` — Detailed plan for making changes safely (includes Jira Stories, GitHub Issues, and/or Azure DevOps Work Items section if linked)

---

## Rules

- 🔴 CHECK `SPEC/references/devops/` FIRST — read ALL reference docs before scanning. Use `aire read` for .docx/.pdf. NEVER skip.
- 🔴 SCAN FIRST — discover ALL existing infrastructure before asking any questions
- 🔴 NEVER modify existing infrastructure code during this workflow — this is PLAN ONLY
- 🔴 Present architecture design to user and confirm accuracy before gathering requirements
- 🔴 User MUST approve the evolution plan before any execution
- 🔴 Every change in the plan MUST have a rollback procedure
- 🔴 High-risk changes MUST have USER APPROVAL GATES in the execution order
- 🔴 Changes MUST be ordered to minimize blast radius — additive/low-risk first, destructive/high-risk last
- 🔴 No secrets in any generated document — reference names only, never values
- 🔴 Respect existing naming conventions — do NOT rename existing resources unless user explicitly requests
- 🔴 Respect existing tool choices — do NOT swap tools (e.g., GitLab to GitHub) unless user explicitly requests
- 🔴 All new resource names MUST come from user input — NEVER auto-generate (RULE T7)
- 🔴 ASK PER-MODULE CONFIG for any new or reconfigured module — auth mode, SKU/tier, runtime, network access, identity, app settings, linked services. Branch by platform and service variant. Never assume defaults.
- 🔴 If existing `variables.tf` found, read it and clarify unclear names with user (RULE T8)
- 🔴 Cross-file consistency enforced — new changes must be consistent with existing configs
- 🔴 Identified gaps/risks MUST be presented to user — do NOT silently fix or ignore them
- 🔴 Execution order MUST respect dependencies — no step runs before its prerequisites
- 🔴 Parallel run period recommended for high-risk pipeline migrations
- 🔴 ASK TRACKER FIRST — ask user if they have a Jira story, GitHub issue, Azure DevOps story, or want to work from scratch before starting
- 🔴 CHECK STORY COMPLETENESS — if a tracker story is provided, verify Description and Acceptance Criteria exist; ask clarifying questions for missing fields
- 🔴 JIRA STORIES IN PLAN — if Jira stories linked, include "Jira Stories" section in evolution plan with story IDs, titles, status, and URLs
- 🔴 GITHUB ISSUES IN PLAN — if GitHub issues linked, include "GitHub Issues" section in evolution plan with issue numbers, titles, status, and URLs
- 🔴 AZURE DEVOPS WORK ITEMS IN PLAN — if Azure DevOps work items linked, include "Azure DevOps Work Items" section in evolution plan with IDs, titles, status, and URLs
- 🔴 OFFER JIRA TRANSITION — after evolution plan approval, offer to mark Jira stories as In Progress or next status
- 🔴 OFFER GITHUB TRANSITION — after evolution plan approval, offer to move GitHub issues to In Review; use `gh` commands directly, do NOT ask user to run them
- 🔴 OFFER ADO TRANSITION — after evolution plan approval, offer to move Azure DevOps work items to next state; use `az boards` commands directly, do NOT ask user to run them
- 🔴 OFFER TRACKER CREATION — if user started from scratch, offer to create a tracker story (GitHub issue if GitHub Projects active, Jira story if Jira active, Azure DevOps work item if Azure DevOps active) after plan is approved
- 🚫 NEVER delete existing working infrastructure without explicit user approval
- 🚫 NEVER change IaC backend configuration without a state migration plan
- 🚫 NEVER remove existing security scanning — only add or improve
- 🚫 NEVER create out-of-scope resources — Azure: Storage Queues, Private Endpoint: Queue, ADF Diagnostic Settings, Logic Apps; AWS: SWF, Data Pipeline (legacy); GCP: Workflows (unless explicitly requested). These are integration/orchestration services outside the DevOps agent's scope.

---

## Completion

```
+==================================================================+
|              INFRA EVOLUTION PLAN COMPLETE                       |
+==================================================================+
|  Deliverables                                                    |
|  +- Current State: docs/deployment/infra-current-state.md        |
|  +- Evolution Plan: docs/deployment/infra-evolution-plan.md      |
+==================================================================+
|  Summary                                                         |
|  +- Existing infra artifacts scanned: [N] files                  |
|  +- Gaps/risks identified: [N]                                   |
|  +- Changes planned: [N] (create: X, modify: Y, delete: Z)       |
|  +- High-risk changes requiring approval: [N]                    |
|  +- Tracker: [N] items linked — [status] (or "No tracker items") |
+==================================================================+

Next Steps

1  aire-devops-pipeline  -> Execute pipeline changes from the evolution plan

Type your choice
```

---

**Tell me about your project's existing infrastructure, then type "proceed" to start the infrastructure evolution assessment.**
