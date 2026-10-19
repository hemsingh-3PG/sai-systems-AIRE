---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: DevOps - Discovery. Auto-detect app profile and gather deployment requirements from user.
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
3. Read `docs/requirements.md` (if exists)
4. Read `docs/architecture/` (if exists)
5. Read `docs/plans/implementation-plan.md` (if exists)

---

## Execution Steps:

### Phase 0: DevOps Reference Check (MANDATORY FIRST)

**Check `SPEC/references/devops/` for existing infrastructure documentation before any discovery.**

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
   - [ ] Note environment structures (dev/staging/prod), service connections, data flows
   - [ ] Note any resource names, IP ranges, port numbers, or configurations visible in diagrams
   - [ ] If a diagram shows infrastructure that contradicts a text document, flag the conflict to the user

4. **Extract Pre-Existing Context**
   - [ ] Infrastructure architecture (cloud provider, regions, resource groups, networking)
   - [ ] Existing resource names, SKUs, configurations
   - [ ] Deployment pipeline designs or requirements
   - [ ] Security/compliance requirements
   - [ ] Module selections or preferences already specified
   - [ ] Operator IP addresses or network access policies

5. **Confirm**
   - [ ] Tell user: "Found [N] documents and [M] images in SPEC/references/devops/"
   - [ ] List what was found and key details extracted
   - [ ] Note: values from reference docs will be **pre-filled** in discovery questions — user confirms or overrides

> **Rules**:
> - 🔴 NEVER skip .docx/.pdf — use `aire read` or ask user to run in CMD
> - 🔴 NEVER skip images — view ALL .png/.jpg/.jpeg/.gif/.svg/.webp files directly
> - 🔴 NEVER proceed without reading ALL reference documents and viewing ALL images
> - 🔴 Reference doc values are pre-filled as defaults in discovery questions — user MUST confirm or override each one
> - 🔴 If reference doc and user answer conflict, user answer wins — note "user-overridden" in report

---

### Phase 0.5: Tracker Story Integration

**Ask the user if they have an existing DevOps task/story on their tracker board.**

First check `docs/status.md` → `## Project Tracking` block. Use `**Tracking**:` value to pre-filter options (offer only paths that match the active tracker; if neither or both, show all).

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
- [ ] **Description** — clear objective (what infrastructure/pipeline work and why)
- [ ] **Acceptance Criteria** — at least 1-2 items (e.g., "Pipeline deploys to staging on merge to main")

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

For each **INCOMPLETE** story, ask clarifying questions grounded in what you know about the project:

```
❓ Clarifying Questions for [JIRA-ID]: [Title]

This story is missing: [Description / Acceptance Criteria].

[If Description missing or vague:]
1. What is the goal of this DevOps story? What infrastructure/pipeline work needs to happen and why?

[If AC missing or too vague:]
2. What does "done" look like? Give me 2-3 specific outcomes.
   (e.g., "CI pipeline runs lint + test + security scan on every PR")

Please answer so I can proceed with discovery.
```

After user answers, all fields are now known. Repeat for ALL incomplete stories before proceeding.

##### J.4 — Record Jira Context

- [ ] Note the Jira story ID(s) for inclusion in the discovery report
- [ ] Use the story description and AC to pre-inform the discovery questions (pre-fill answers where the story provides enough detail)
- [ ] Proceed to Phase 1 with Jira context loaded

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
- [ ] **Description / User Story** — clear objective (what infrastructure/pipeline work and why)
- [ ] **Acceptance Criteria** — at least 1-2 items (e.g., "Pipeline deploys to staging on merge to main")

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
### Clarification (captured during aire-devops-discover)

**Goal**: <user answer>

**Acceptance Criteria**:
- <AC 1>
- <AC 2>
EOF
)"
```

##### G.4 — Record GitHub Context

- [ ] Note the issue numbers for inclusion in the discovery report
- [ ] Use body + AC to pre-inform discovery questions
- [ ] Proceed to Phase 1 with GitHub context loaded

---

#### PATH A: Work from Azure DevOps Story

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user. Skip this path if `docs/status.md` does NOT contain `**Tracking**: Azure DevOps`.**

##### A.1 — Fetch Story Details

Ask user:
```
❓ Paste the Azure DevOps work item URL or ID:
   Example: https://dev.azure.com/my-org/MyProject/_workitems/edit/123
   Or just the work item ID: 123
```

Extract work item ID from URL or direct input.

```bash
az boards work-item show --id {WI_ID} --project "{PROJECT}"
```

##### A.2 — Check Completeness

Extract: Work Item ID, Title, Description (`System.Description`), Acceptance Criteria (`Microsoft.VSTS.Common.AcceptanceCriteria`), State, Priority, Tags, Iteration Path.

**A work item is COMPLETE if it has ALL THREE of**:
- [ ] **Description** — clear objective
- [ ] **Acceptance Criteria** — at least 1-2 items
- [ ] **Out of Scope** — at least one explicit exclusion (may be in Description)

If INCOMPLETE, ask user clarifying questions grounded in codebase before proceeding.

##### A.3 — Pre-load Context

- [ ] Note the work item ID for inclusion in the discovery report
- [ ] Use Description + AC to pre-inform discovery questions
- [ ] Offer to mark work item as "Active" after user approves the discovery plan:
  ```
  ❓ Should I mark Work Item #{WI_ID} as "Active"? (yes/no)
  ```
  If YES:
  ```bash
  az boards work-item update --id {WI_ID} --state "Active" --project "{PROJECT}"
  ```
- [ ] Proceed to Phase 1 with Azure DevOps context loaded

---

#### PATH S: Work from Scratch

- [ ] Proceed directly to Phase 1 — no tracker context
- [ ] At the end of this workflow (Phase 5), user will be offered to create/link a tracker story (Jira, GitHub, or Azure DevOps, depending on active tracker)

---

### Phase 1: Auto-Detect Application Profile

Scan the codebase and extract all available information BEFORE asking any questions:

- [ ] **Auto-detect language and framework** by scanning for manifest files:

  | Language | Manifest Files | Framework Detection |
  |----------|---------------|---------------------|
  | Python | `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` | Django, Flask, FastAPI from imports/deps |
  | Node.js/TypeScript | `package.json`, `yarn.lock`, `pnpm-lock.yaml`, `tsconfig.json` | React, Next.js, Express, NestJS, Angular, Vue from deps |
  | Java/Kotlin | `pom.xml`, `build.gradle`, `build.gradle.kts` | Spring Boot, Quarkus, Micronaut from deps |
  | .NET/C# | `*.csproj`, `*.sln`, `global.json` | ASP.NET Core, Blazor from SDK/packages |
  | Go | `go.mod`, `go.sum` | Gin, Echo, Fiber from imports |
  | Rust | `Cargo.toml` | Actix, Axum, Rocket from deps |
  | Ruby | `Gemfile`, `Gemfile.lock` | Rails, Sinatra from gems |
  | PHP | `composer.json` | Laravel, Symfony from deps |

- [ ] Detect language version (e.g., `.python-version`, `.nvmrc`, `.node-version`, `.tool-versions`, `runtime.txt`, `global.json`, `go.mod`)
- [ ] Detect build, test, lint, start commands from manifest `scripts` section or convention
- [ ] Scan for existing `Dockerfile`, `docker-compose.yml`, `.dockerignore`
- [ ] Scan for existing `.github/workflows/`
- [ ] Detect database dependencies (psycopg2, pymongo, sqlalchemy, etc.)
- [ ] Detect external service dependencies (redis, celery, elasticsearch, etc.)
- [ ] Detect environment variable requirements from `.env.example`, `.env.template`, or settings files
- [ ] Read `docs/architecture/` for system design context
- [ ] Read `docs/requirements.md` for project requirements
- [ ] **Check for existing `variables.tf`** — if found, read it and flag any unclear/ambiguous variable names for user clarification (RULE T8)

### Phase 2: Present Auto-Detection Results

- [ ] **If nothing detected**: Say "No application code detected in this workspace — skipping auto-detection." and proceed directly to Phase 3 discovery questions. Do NOT ask the user to clarify the workspace, project type, or whether code exists — just move on.
- [ ] **If results found**: Show user a summary table of everything detected
- [ ] Highlight any conflicts or uncertainties (e.g., multiple frameworks detected)
- [ ] Note what could NOT be auto-detected
- [ ] If `variables.tf` found, present its variables and ask user to clarify ambiguous names (e.g., `var.name` → "What does this refer to?")

### Phase 3: Ask Discovery Questions

**Ask ONLY questions not answered by auto-detection. Follow this exact order.**

**Step 1 — Deployment Model (MUST ASK FIRST):**
1. **Server-based or Serverless?**
2. If **server-based**: Where? (AWS EC2, Azure VM, DigitalOcean, bare-metal Linux, self-managed K8s on VMs, etc.)
3. If **serverless**: Which platform? (AWS Lambda, ECS Fargate, App Runner, Azure Functions, Azure Container Apps, GCP Cloud Run, Cloud Functions, GKE Autopilot, etc.)

> **RULE DM1**: If the user's chosen category does not match the service they named, **correct them before proceeding** (e.g., "ECS Fargate is serverless, not server-based — you don't manage servers"). Wrong classification changes the entire deployment architecture.
**Step 2 — Infrastructure Naming & Core Parameters (MUST ASK — COLLECT ONCE, USE EVERYWHERE):**

> **CRITICAL**: These values are asked ONCE and used consistently across ALL Terraform files, pipelines, Docker configs. NEVER auto-generate names. Questions are **branched by cloud provider** — only ask what applies to the platform chosen in Step 1.

4. **Project/App name prefix** for all resource naming (e.g., `myapp`) — used to derive ALL resource names consistently across every cloud provider
5. **Region / Location** (e.g., Azure: `eastus`, AWS: `eu-west-1`, GCP: `us-central1`)

6. **Does networking already exist?** (VPC/VNet, subnets, security groups/NSGs) — or should Terraform create them?
   - If **already exists**: provide names/IDs — Terraform will reference them via `data` sources, NOT recreate
   - If **create new**: provide desired names — Terraform will create them as `resource` blocks

**If Azure:**
7. **Resource Group name** (e.g., `rg-myapp-prod`) — already exists or create new?
8. **VNet name** (e.g., `vnet-myapp-prod`)
9. **Subnet name(s)** — how many and what names? (e.g., `snet-app`, `snet-db`)

**If AWS:**
7. **VPC name or ID** (e.g., `vpc-myapp-prod` or `vpc-0abc123`)
8. **Subnet name(s) or IDs** — how many, which AZs, public/private? (e.g., `subnet-app-a`, `subnet-db-b`)
9. **AWS Account ID** (if multi-account strategy) — or confirm single-account

**If GCP:**
7. **GCP Project ID** (e.g., `myapp-prod-123456`) — GCP's organizational container (NOT the same as the app name prefix above)
8. **VPC name** (e.g., `vpc-myapp-prod`)
9. **Subnet name(s)** — how many and what names? (e.g., `subnet-app`, `subnet-db`)

**All providers:**
10. **Environment name(s)** — which environments? (e.g., `dev`, `staging`, `prod`)

**Step 3 — Service Module Selection (MUST ASK):**

> Ask which infrastructure modules the user wants. Present in TWO parts: core modules first, then optional modules separately. For EACH selected module, ask for the **exact resource name**. Do NOT assume defaults.

**Part A — Core Modules** (ask which ones they need):

9. Which core infrastructure modules do you need? (select all that apply):
   - **Compute / App Hosting** (Azure App Service, AWS ECS/EB, GCP Cloud Run/App Engine — frontend + backend together as single module) — name?
   - **Database** (PostgreSQL, MySQL, SQL Server, CosmosDB, DynamoDB, Cloud Spanner, etc.) — type and name?
   - **Cache** (Redis, Memcached — managed or self-hosted) — name?
   - **Message Queue** (Service Bus, SQS/SNS, Pub/Sub, RabbitMQ, Kafka) — name?
   - **Storage** (Azure Blob/ADLS, AWS S3, GCP Cloud Storage) — account/bucket name?
   - **Container Registry** (ACR, ECR, Artifact Registry, Docker Hub) — name?
   - **Monitoring** (Azure Monitor/App Insights, CloudWatch, GCP Cloud Monitoring, Datadog, Grafana) — name?
   - **Secrets Manager** (Azure Key Vault, AWS Secrets Manager/SSM, GCP Secret Manager) — name?
   - **Other** — describe

**Part B — Optional Modules** (ask explicitly, one by one):

10. Do you want a **WAF (Web Application Firewall)**? (Azure WAF, AWS WAF, GCP Cloud Armor) Adds Layer 7 security with OWASP protection, bot mitigation, rate limiting at edge. Adds cost + complexity — recommended only for public-facing apps. (yes/no) — if yes, what name?
11. Do you want **Private DNS Zones**? (Azure Private DNS, AWS Route 53 Private Hosted Zones, GCP Cloud DNS Private Zones) Required for private endpoint name resolution within your VPC/VNet. (yes/no) — if yes, which zone names?

> **Rule**: NEVER include optional modules unless the user explicitly says "yes". Silence or ambiguity = do NOT include.

**Part C — Out-of-Scope Resources (NEVER BUILD):**

Inform the user that the following integration/orchestration services are permanently out of scope. Do NOT create them in ANY module:

| Azure | AWS | GCP | Status |
|-------|-----|-----|--------|
| Storage Queues | SWF | Workflows | 🚫 Out of scope |
| Private Endpoint: Queue | Data Pipeline (legacy) | — | 🚫 Out of scope |
| ADF Diagnostic Settings | — | — | 🚫 Out of scope |
| Logic Apps | — | — | 🚫 Out of scope |

> If the user requests any of these, inform them these are outside the DevOps agent's scope.

**Step 3.5 — Per-Module Configuration Details (MUST ASK — for EACH selected module):**

> For EVERY module the user selected in Step 3, ask the relevant configuration questions below. Do NOT ask questions for modules the user did not select. If a reference document (PDF, PRD) was provided that already specifies these details, still VALIDATE them with the user before including in the report.

**Database (only if Database selected in Step 3):**

> The user already specified the database TYPE in Step 3 (PostgreSQL, MySQL, CosmosDB, SQL Server, MongoDB, etc.). Ask the config questions that match their chosen type. Questions are grouped by database family — only ask the relevant group.

**If Azure SQL / SQL Server:**

- [ ] Authentication mode: SQL auth only, Entra ID (AAD) only, or both?
- [ ] If Entra ID: who is the AAD admin? (object ID or "use Terraform Service Principal")
- [ ] Compute tier: Serverless, Provisioned, or DTU-based?
- [ ] If serverless: auto-pause delay? (e.g., 60 minutes, disabled)
- [ ] Max size in GB?
- [ ] Public network access: enabled or disabled?
- [ ] Key Vault secret names for credentials? (e.g., `sql-admin-login`, `sql-admin-password`)

**If PostgreSQL (Azure Flexible Server / RDS / Cloud SQL):**

- [ ] Authentication mode: PostgreSQL password, Entra ID (AAD), or both?
- [ ] If Entra ID: who is the AAD admin? (object ID or "use Terraform Service Principal")
- [ ] SKU tier: Burstable (B-series), General Purpose (D-series), Memory Optimized (E-series)?
- [ ] SKU name? (e.g., `B_Standard_B1ms`, `GP_Standard_D2s_v3`)
- [ ] PostgreSQL version? (e.g., 14, 15, 16)
- [ ] Storage size in GB?
- [ ] High availability: enabled (zone-redundant) or disabled?
- [ ] Public network access: enabled or disabled?
- [ ] Key Vault secret names for credentials?

**If MySQL (Azure Flexible Server / RDS / Cloud SQL):**

- [ ] Authentication mode: MySQL password, Entra ID (AAD), or both?
- [ ] SKU tier: Burstable, General Purpose, Memory Optimized?
- [ ] MySQL version? (e.g., 8.0, 8.4)
- [ ] Storage size in GB?
- [ ] High availability: enabled or disabled?
- [ ] Public network access: enabled or disabled?
- [ ] Key Vault secret names for credentials?

**If CosmosDB:**

- [ ] API type: NoSQL (Core/SQL), MongoDB, Cassandra, Gremlin, or Table?
- [ ] Consistency level: Strong, Bounded Staleness, Session (default), Consistent Prefix, or Eventual?
- [ ] Capacity mode: Provisioned throughput (RU/s) or Serverless?
- [ ] If provisioned: max RU/s? Autoscale enabled?
- [ ] Database name(s) and container/collection names?
- [ ] Partition key path for each container? (e.g., `/tenantId`, `/userId`)
- [ ] Multi-region writes: enabled or disabled?
- [ ] Public network access: enabled or disabled?
- [ ] Key Vault secret names for connection string and key?

**If MongoDB (Atlas / self-hosted / Azure CosmosDB MongoDB API):**

- [ ] Hosting: MongoDB Atlas, self-hosted, or CosmosDB MongoDB API?
- [ ] If Atlas: cluster tier? (e.g., M10, M20, M30)
- [ ] MongoDB version? (e.g., 6.0, 7.0)
- [ ] Database name(s) and collection names?
- [ ] Public network access or VNet peering?
- [ ] Key Vault secret names for connection string?

**Common to ALL database types:**

- [ ] Backup policy: geo-redundant, locally redundant, or custom retention?
- [ ] Firewall rules: specific IPs, Azure services only, or VNet integration?

**Storage (only if Storage selected in Step 3):**

> The user already specified the cloud provider in Step 1/2. Ask the config questions that match their platform.

**If Azure Storage (Blob / ADLS):**

- [ ] Storage type: ADLS Gen2 (HNS enabled) or standard Blob storage?
- [ ] Account tier: Standard or Premium?
- [ ] Replication: LRS, GRS, ZRS, or GZRS?
- [ ] Default access tier: Hot, Cool, or Cold?
- [ ] Container names and their purpose? (e.g., `uploads` for user files, `data` for ETL output)
- [ ] Blob versioning: enabled or disabled?
- [ ] Soft delete retention: how many days? (or disabled)
- [ ] Lifecycle policy: tier to Cool/Archive after N days? Delete after N days? (or none)
- [ ] Static website hosting: enabled or disabled?
- [ ] CORS rules needed? (if accessed from browser)
- [ ] Encryption: Microsoft-managed keys or customer-managed keys (CMK via Key Vault)?
- [ ] Public network access: enabled or disabled?
- [ ] Key Vault secret names for access keys? (or use Managed Identity — no key needed)

**If AWS S3:**

- [ ] Bucket name(s) and their purpose?
- [ ] Region: same as Step 2 or different?
- [ ] Versioning: enabled or disabled?
- [ ] Encryption: SSE-S3, SSE-KMS, or SSE-C?
- [ ] Bucket policy: public read, private only, or custom?
- [ ] Lifecycle rules: transition to IA/Glacier after N days? Expire after N days?
- [ ] Access logging: enabled or disabled?
- [ ] Static website hosting: enabled or disabled?
- [ ] CORS rules needed?
- [ ] Block all public access: yes or no?
- [ ] Replication: same-region (SRR) or cross-region (CRR)?

**If GCP Cloud Storage:**

- [ ] Bucket name(s) and their purpose?
- [ ] Storage class: Standard, Nearline, Coldline, or Archive?
- [ ] Location type: region, dual-region, or multi-region?
- [ ] Uniform bucket-level access: enabled or disabled?
- [ ] Lifecycle rules: change class or delete after N days?
- [ ] Versioning: enabled or disabled?
- [ ] Public access prevention: enforced or inherited?

**Common to ALL storage types:**

- [ ] Which services need read/write access to this storage? (for IAM/RBAC setup)

**Serverless Functions (only if serverless functions selected in Step 1 or Step 3):**

> The user already specified the serverless platform in Step 1. Ask the config questions that match their platform.

**If Azure Functions:**

- [ ] Runtime and version for each function? (e.g., Python 3.11, Node 20, .NET 8, Java 17)
- [ ] OS: Linux or Windows?
- [ ] Hosting plan: Consumption (Y1), Premium (EP1/EP2/EP3), or Dedicated (App Service Plan)?
- [ ] If Premium: always-on enabled? Pre-warmed instance count?
- [ ] Trigger type per function: HTTP, Timer, Queue, Blob, Event Grid, Service Bus, Cosmos DB?
- [ ] VNet integration subnet? (or reuse the one from Step 2)
- [ ] Identity type: System-Assigned Managed Identity, User-Assigned, or none?
- [ ] What services does each function need access to? (Key Vault, SQL, Storage, etc.)
- [ ] App settings / environment variables needed? (key names only, no values)
- [ ] Separate runtime storage account name?
- [ ] Deployment slots: need a staging slot for swap deployments?
- [ ] CORS: allowed origins? (if called from browser)
- [ ] IP restrictions or access rules?

**If AWS Lambda:**

- [ ] Runtime and version for each function? (e.g., Python 3.12, Node 20, .NET 8, Java 21)
- [ ] Architecture: x86_64 or arm64 (Graviton2)?
- [ ] Memory size per function? (128 MB to 10,240 MB)
- [ ] Timeout per function? (max 900 seconds)
- [ ] Trigger type per function: API Gateway, S3, SQS, SNS, EventBridge, DynamoDB Stream, CloudWatch Schedule?
- [ ] VPC configuration: deploy inside VPC? If yes, which subnets and security groups?
- [ ] IAM role: which AWS services does each function need access to?
- [ ] Environment variables needed? (key names only, no values)
- [ ] Layers: any shared libraries or dependencies?
- [ ] Reserved or provisioned concurrency?
- [ ] Dead-letter queue for failures: SQS or SNS?

**If Google Cloud Functions:**

- [ ] Generation: Gen 1 or Gen 2?
- [ ] Runtime and version? (e.g., Python 3.12, Node 20, Go 1.22, Java 17)
- [ ] Memory allocation per function?
- [ ] Timeout per function?
- [ ] Trigger type: HTTP, Cloud Storage, Pub/Sub, Firestore, Cloud Scheduler?
- [ ] VPC connector: deploy inside VPC? If yes, which connector?
- [ ] Service account: which GCP services does each function need access to?
- [ ] Environment variables needed? (key names only, no values)
- [ ] Ingress settings: Allow all, Allow internal only, or Allow internal + Cloud Load Balancing?
- [ ] Min/max instances?

**Common to ALL serverless platforms:**

- [ ] How many distinct functions will there be? List each with name and purpose
- [ ] Shared dependencies between functions?

**App Service / Web App (only if App Service selected in Step 3):**

> Applies to Azure App Service, AWS Elastic Beanstalk, GCP App Engine, or similar PaaS. Ask the platform-relevant questions.

**If Azure App Service:**

- [ ] Runtime stack and version? (.NET 8.0, Node 20, Python 3.11, Java 17, PHP 8.3, Ruby 3.2, Go, etc.)
- [ ] Reuse an existing App Service Plan or create a new one? If reuse, which plan name?
- [ ] App Service Plan SKU? (e.g., B1, S1, P1v3, P1mv3)
- [ ] OS: Linux or Windows?
- [ ] Always On: enabled or disabled? (required for production — prevents cold starts)
- [ ] VNet integration subnet? (or reuse the one from Step 2)
- [ ] Identity type: System-Assigned Managed Identity, User-Assigned, or none?
- [ ] Deployment slots: need a staging slot for swap deployments? (zero-downtime deploy)
- [ ] App settings / connection strings? (key names only — e.g., `DB_CONNECTION_STRING`, `REDIS_URL`)
- [ ] What services does it need access to? (Key Vault, SQL, Storage, etc. — for RBAC)
- [ ] HTTPS only: enforce HTTPS redirect?
- [ ] Minimum TLS version? (1.2 recommended)
- [ ] Health check path? (e.g., `/health` — used by Azure for instance monitoring)
- [ ] Auto-scaling: manual scale (fixed instance count) or auto-scale rules? If auto: min/max instances, CPU/memory threshold?
- [ ] Custom domain: provide now or configure later?
- [ ] IP restrictions or access rules?
- [ ] CORS: allowed origins? (if API consumed by browser apps)

**If AWS Elastic Beanstalk / ECS:**

- [ ] Platform and version? (e.g., Python 3.11, Node 20, Docker, .NET 8)
- [ ] Instance type? (e.g., t3.micro, t3.small)
- [ ] Auto-scaling: min/max instances?
- [ ] Load balancer type: Application (ALB) or Network (NLB)?
- [ ] VPC and subnet placement?
- [ ] Environment variables needed? (key names only)
- [ ] Health check path?

**If GCP App Engine / Cloud Run:**

- [ ] App Engine Standard or Flexible? Or Cloud Run?
- [ ] Runtime and version?
- [ ] Auto-scaling: min/max instances?
- [ ] VPC connector?
- [ ] Environment variables needed? (key names only)
- [ ] Ingress: Allow all, Internal only, or Internal + Load Balancing?

**Common to ALL app hosting platforms:**

- [ ] Which services does the app depend on at runtime? (DB, cache, storage, queues, external APIs)

**Static Web App / Static Hosting (only if Static Web App selected in Step 3):**

**If Azure Static Web Apps:**

- [ ] SKU tier: Free or Standard?
- [ ] Region? (or same as Step 2)
- [ ] Linked API backend: Azure Functions, App Service, or none?
- [ ] Build config: app location (e.g., `/`), API location (e.g., `/api`), output location (e.g., `build`, `dist`)?
- [ ] Custom domain: provide now or configure later?
- [ ] Authentication providers: GitHub, Azure AD, Twitter, custom, or none?
- [ ] Environment variables? (key names only — set in SWA configuration)

**If AWS Amplify / S3 + CloudFront:**

- [ ] Hosting approach: Amplify Hosting or S3 bucket + CloudFront distribution?
- [ ] Build config: build command, output directory?
- [ ] Custom domain?
- [ ] CloudFront: cache behaviors, price class?

**If GCP Firebase Hosting / Cloud Storage:**

- [ ] Hosting approach: Firebase Hosting or Cloud Storage bucket?
- [ ] Custom domain?
- [ ] Rewrite/redirect rules?

**Secrets Manager / Key Vault (only if Key Vault or Secrets Manager selected in Step 3):**

**If Azure Key Vault:**

- [ ] Access model: RBAC Authorization or Access Policies?
- [ ] Soft delete retention days? (7-90, default 90)
- [ ] Purge protection: enabled or disabled? (enabled recommended for prod — prevents permanent deletion for retention period)
- [ ] Enable for deployment (ARM template deployment access)? yes or no?
- [ ] Enable for disk encryption? yes or no?
- [ ] Network rules: default Deny with Azure Services bypass, or Allow all?
- [ ] List ALL secret names that will be stored (names only, no values)
- [ ] List ALL keys that will be stored (for encryption — names only)?
- [ ] List ALL certificates that will be managed (names only)?
- [ ] Which services need read access? (for Managed Identity RBAC role assignments — e.g., App Service, Function Apps, Data Factory)
- [ ] Diagnostic settings: send logs to Log Analytics workspace?

**If AWS Secrets Manager / Parameter Store:**

- [ ] Which service: Secrets Manager (auto-rotation, higher cost) or SSM Parameter Store (simpler, lower cost)?
- [ ] List ALL secret names that will be stored (names only)
- [ ] Encryption: default AWS KMS key or custom KMS key?
- [ ] Auto-rotation: needed for any secrets? If yes, rotation interval?
- [ ] Which IAM roles/services need read access?

**If GCP Secret Manager:**

- [ ] List ALL secret names that will be stored (names only)
- [ ] Replication policy: automatic or user-managed (specific regions)?
- [ ] Which service accounts need access?

**Common to ALL secrets services:**

- [ ] Are there secrets shared across multiple environments (dev/staging/prod) or separate per environment?
- [ ] If network rules are set to Deny: list ALL **operator/admin IP addresses** that need to manage this Key Vault from outside the cloud network (e.g., developer laptops, Terraform runner, CI/CD agent public IPs). These will be added to `ip_rules` so Terraform and operators are not locked out.

**Container Registry (only if Container Registry selected in Step 3):**

**If Azure Container Registry (ACR):**

- [ ] SKU: Basic, Standard, or Premium?
- [ ] Admin user enabled: yes or no? (disabled recommended — use Managed Identity or service principal)
- [ ] Geo-replication: needed? If yes, which additional regions? (Premium only)
- [ ] Public network access: enabled or disabled?
- [ ] Content trust (image signing): enabled or disabled? (Premium only)
- [ ] Retention policy for untagged manifests: enabled, how many days? (Premium only)
- [ ] Zone redundancy: enabled or disabled? (Premium only)
- [ ] Which services need pull access? (App Service, AKS, Function Apps — for RBAC `AcrPull` role)

**If AWS ECR:**

- [ ] Repository type: private or public?
- [ ] Image tag mutability: mutable or immutable?
- [ ] Image scanning on push: enabled or disabled?
- [ ] Lifecycle policy: expire untagged images after N days?
- [ ] Encryption: AES-256 (default) or KMS?
- [ ] Which IAM roles/services need pull access?

**If GCP Artifact Registry:**

- [ ] Repository format: Docker, Maven, npm, Python, etc.?
- [ ] Region: same as Step 2 or different?
- [ ] Cleanup policies?
- [ ] Which service accounts need reader access?

**If Docker Hub (self-hosted or cloud):**

- [ ] Public or private repository?
- [ ] Organization/namespace name?

**Monitoring & Observability (only if Monitoring selected in Step 3):**

**If Azure Monitor / Application Insights:**

- [ ] Log Analytics workspace: create new or use existing? If existing, name?
- [ ] Log Analytics SKU: PerGB2018 (default) or other?
- [ ] Log retention in days? (30, 60, 90, 120, etc.)
- [ ] Application Insights: which services should it connect to? (App Service, Function Apps, etc.)
- [ ] Diagnostic settings: which resources should send logs/metrics to Log Analytics? (Key Vault, SQL, Storage, NSG flow logs, etc.)
- [ ] Alert rules: what conditions should trigger alerts? (e.g., HTTP 5xx > 10/min, CPU > 80%, response time > 5s)
- [ ] Action groups: who gets notified? (email addresses, SMS, webhook, Azure Function, Logic App — names only)
- [ ] Availability tests (ping tests): URLs to monitor? (e.g., production health endpoint)
- [ ] Dashboard: need an Azure Dashboard or Workbook with key metrics?

**If AWS CloudWatch:**

- [ ] Log groups: which services should send logs? (Lambda, ECS, EC2, API Gateway, etc.)
- [ ] Log retention per group in days?
- [ ] Alarms: what metrics and thresholds? (e.g., Lambda errors > 5/min, ELB 5xx > 1%)
- [ ] SNS topics for alarm notifications: who gets notified?
- [ ] CloudWatch Dashboards: need a custom dashboard?
- [ ] X-Ray tracing: enabled for which services?
- [ ] Container Insights (if ECS/EKS): enabled?

**If GCP Cloud Monitoring / Cloud Logging:**

- [ ] Which services should send logs? (Cloud Run, GKE, Cloud Functions, etc.)
- [ ] Log retention per bucket?
- [ ] Alerting policies: what conditions and notification channels?
- [ ] Uptime checks: URLs to monitor?
- [ ] Cloud Trace: enabled for which services?

**If third-party (Datadog, Grafana, New Relic, Prometheus):**

- [ ] Which tool? Already have an account/instance?
- [ ] Which services to instrument?
- [ ] Key Vault / Secrets Manager name for API keys?

**Common to ALL monitoring:**

- [ ] What is the on-call escalation path? (for action group / SNS / notification config)

**Front Door / CDN / Load Balancer (only if Front Door, CDN, or Load Balancer selected in Step 3):**

**If Azure Front Door:**

- [ ] SKU: Standard or Premium?
- [ ] Endpoint name?
- [ ] Origin groups: list each backend target (e.g., App Service, Storage static site, API Management)
- [ ] Routing rules: path patterns per origin group? (e.g., `/api/*` → backend origin, `/*` → frontend origin)
- [ ] Caching: enable caching? Query string behavior (ignore, include all, include specific)?
- [ ] Compression: enable for which MIME types?
- [ ] Custom domain: provide now or later?
- [ ] HTTPS redirect: enforce HTTPS on all routes?
- [ ] Health probes: path and interval per origin group?
- [ ] WAF policy: already addressed in Step 3 Part B — reference that answer

**If AWS CloudFront:**

- [ ] Origin(s): S3 bucket, ALB, API Gateway, or custom origin?
- [ ] Price class: All edge locations, NA/EU only, or NA/EU/Asia?
- [ ] Cache behaviors: path patterns and TTLs?
- [ ] Custom domain and ACM certificate?
- [ ] Origin Access Control (for S3)?
- [ ] WAF Web ACL: needed?
- [ ] Compression: enabled?
- [ ] Logging: S3 bucket for access logs?

**If GCP Cloud CDN / Load Balancer:**

- [ ] Backend type: Cloud Storage, Cloud Run, GKE, Compute Engine?
- [ ] CDN policy: cache mode and TTL?
- [ ] Custom domain and managed SSL certificate?
- [ ] Cloud Armor (WAF): needed?

**Common to ALL CDN/Front Door:**

- [ ] Geo-restrictions: block or allow specific countries?

**AI / ML Services (only if OpenAI, Cognitive Services, or ML selected in Step 3):**

**If Azure OpenAI:**

- [ ] Model deployments: which models and versions? (e.g., `gpt-4o`, `gpt-4o-mini`, `text-embedding-3-small`)
- [ ] Deployment type per model: Standard (pay-per-token) or Provisioned (reserved TPM)?
- [ ] If provisioned: provisioned throughput units (PTU) per model?
- [ ] Region constraint: must it be a specific region for model availability? (not all models available in all regions)
- [ ] Content filtering policy: default, custom, or disabled? (custom requires application)
- [ ] Rate limits per deployment: requests-per-minute and tokens-per-minute caps?
- [ ] Public network access: enabled or disabled?
- [ ] Private endpoint: needed? (if network-restricted)
- [ ] Key Vault secret names for endpoint URI and API key?
- [ ] Which services will call this? (App Service, Function Apps, Data Factory — for network/RBAC setup)

**If Azure Cognitive Services (non-OpenAI):**

- [ ] Which service(s): Computer Vision, Speech, Language, Translator, Form Recognizer, etc.?
- [ ] SKU: Free (F0) or Standard (S0)?
- [ ] Public network access: enabled or disabled?
- [ ] Key Vault secret names for endpoint and key?

**If AWS Bedrock / SageMaker:**

- [ ] Which foundation models? (Claude, Titan, Llama, etc.)
- [ ] Provisioned throughput or on-demand?
- [ ] VPC endpoint needed?
- [ ] IAM roles for access?

**If GCP Vertex AI:**

- [ ] Which models? (Gemini, PaLM, custom-trained?)
- [ ] Region?
- [ ] VPC Service Controls?
- [ ] Service account for access?

**Data Factory / Orchestration (only if Data Factory or data orchestration selected in Step 3):**

**If Azure Data Factory:**

- [ ] Which linked services are needed? List each: target service + connection method (e.g., ADLS via Managed Identity, SQL via connection string, REST to Function Apps, HTTP to external APIs)
- [ ] Managed Identity: System-Assigned or User-Assigned?
- [ ] Self-hosted Integration Runtime needed? (for on-premises or private network data sources)
- [ ] Git integration: Azure DevOps Repos or GitHub? Repository and branch names?
- [ ] Global parameters: list parameter names and types (for environment-specific configs)
- [ ] Diagnostic settings: send pipeline run logs to Log Analytics?
- [ ] Public network access: enabled or disabled?

**If AWS Glue / Step Functions:**

- [ ] Which service: Glue (ETL) or Step Functions (workflow orchestration)?
- [ ] Data sources and destinations?
- [ ] IAM roles for access?
- [ ] VPC configuration needed?

**If GCP Cloud Composer / Dataflow:**

- [ ] Which service: Cloud Composer (Airflow) or Dataflow (Apache Beam)?
- [ ] Environment size?
- [ ] VPC and service account?

**Cache (only if Cache selected in Step 3):**

**If Azure Cache for Redis:**

- [ ] SKU and tier: Basic (C0-C6), Standard (C0-C6), or Premium (P1-P5)?
- [ ] Redis version? (e.g., 6, 7)
- [ ] If Premium: clustering enabled? How many shards?
- [ ] If Premium: data persistence? RDB snapshots, AOF, or none?
- [ ] If Premium: zone redundancy?
- [ ] Eviction policy? (e.g., `volatile-lru`, `allkeys-lru`, `noeviction`)
- [ ] Public network access: enabled or disabled?
- [ ] Private endpoint needed?
- [ ] Firewall rules: specific IPs or VNet only?
- [ ] Key Vault secret name for connection string?
- [ ] Which services need access? (App Service, Function Apps — for network/firewall rules)

**If AWS ElastiCache:**

- [ ] Engine: Redis or Memcached?
- [ ] Node type? (e.g., `cache.t3.micro`, `cache.r6g.large`)
- [ ] Cluster mode: enabled or disabled? If enabled, number of shards and replicas?
- [ ] If Redis: Redis version? Multi-AZ? Auto-failover?
- [ ] Encryption in transit and at rest: enabled?
- [ ] Subnet group: which VPC subnets?
- [ ] Parameter group customizations?

**If GCP Memorystore:**

- [ ] Engine: Redis or Memcached?
- [ ] Tier: Basic or Standard (HA)?
- [ ] Memory size?
- [ ] Redis version?
- [ ] Authorized VPC network?

**If self-hosted Redis / Memcached (Docker or VM):**

- [ ] Memory limit?
- [ ] Persistence: RDB, AOF, or none?
- [ ] Password protected?

**Message Queue / Event Streaming (only if Message Queue selected in Step 3):**

**If Azure Service Bus:**

- [ ] SKU tier: Basic, Standard, or Premium?
- [ ] Namespace name?
- [ ] Queue names and their purpose? (point-to-point messaging)
- [ ] Topic names and subscription names? (pub/sub messaging)
- [ ] If Premium: messaging units? Zone redundancy?
- [ ] Message sessions: needed? (ordered processing, FIFO)
- [ ] Dead-letter queue: enabled for which queues?
- [ ] Max message size? (Basic/Standard: 256 KB, Premium: up to 100 MB)
- [ ] Duplicate detection: enabled, window duration?
- [ ] Public network access: enabled or disabled?
- [ ] Private endpoint needed?
- [ ] Which services send messages? Which services consume? (for RBAC — Sender/Receiver roles)

**If AWS SQS:**

- [ ] Queue type per queue: Standard (at-least-once, best-effort ordering) or FIFO (exactly-once, strict ordering)?
- [ ] Queue names and their purpose?
- [ ] Message retention period? (1 minute to 14 days, default 4 days)
- [ ] Visibility timeout per queue?
- [ ] Dead-letter queue: enabled? Max receive count before DLQ?
- [ ] Encryption: SSE-SQS or SSE-KMS?
- [ ] Which IAM roles/services send and consume?

**If AWS SNS (pub/sub):**

- [ ] Topic names and their purpose?
- [ ] Subscription types: SQS, Lambda, HTTP/S, email, SMS?
- [ ] FIFO topics needed?
- [ ] Encryption: SSE-KMS?

**If RabbitMQ (self-hosted or managed):**

- [ ] Hosting: self-hosted (Docker/VM), Amazon MQ, CloudAMQP, or other managed?
- [ ] Virtual host name(s)?
- [ ] Exchange names, types (direct, fanout, topic, headers), and purpose?
- [ ] Queue names bound to which exchanges?
- [ ] Clustering: single node or cluster? How many nodes?
- [ ] Persistence: durable queues and messages?
- [ ] Management plugin UI: exposed?
- [ ] Key Vault / Secrets Manager name for credentials?

**If Google Cloud Pub/Sub:**

- [ ] Topic names and their purpose?
- [ ] Subscription names and delivery type: pull or push?
- [ ] Message retention duration?
- [ ] Dead-letter topic: enabled?
- [ ] Schema enforcement: Avro or Protocol Buffer?

**If Apache Kafka / Azure Event Hubs (Kafka-compatible):**

- [ ] Topic names, partition count, and retention?
- [ ] If Event Hubs: SKU tier (Basic, Standard, Premium, Dedicated)? Throughput units?
- [ ] If managed Kafka (Confluent, MSK): cluster size?
- [ ] Consumer groups?
- [ ] Schema registry needed?

**Common to ALL message queue types:**

- [ ] Expected message volume? (messages/second or messages/day — affects SKU and partition sizing)

> **Rule**: For each selected module, collect authentication mode, SKU/tier, runtime version, network access, identity type, app settings, and linked service connections. Never assume defaults without asking. If user says "use defaults" for a specific question, document it as "user-accepted default" in the report.

**Common to ALL network-restricted resources (MUST ASK if ANY module above uses `default_action = Deny`, `public_network_access = disabled`, or firewall rules):**

> **CRITICAL**: When ANY resource restricts network access, the Terraform runner and operators are ALSO blocked unless their IPs are whitelisted. Collect these ONCE and apply to ALL network-restricted resources.

- [ ] **Operator/admin public IP addresses**: List ALL public IPs that need to manage these resources from outside the cloud network:
  - Developer laptop IPs (for running `terraform apply` locally, browsing Key Vault secrets, managing storage, etc.)
  - CI/CD runner IPs (GitHub Actions runner IPs, GitLab runner IPs, self-hosted agent IPs)
  - Any VPN or bastion host egress IPs
  - Example format: `["203.0.113.10/32", "198.51.100.0/24"]`
- [ ] These IPs will be added to `ip_rules` / `firewall_rules` on ALL resources with network restrictions (Key Vault, Storage, SQL Server, Container Registry, Cache, etc.)
- [ ] If CI/CD uses dynamic IPs (e.g., GitHub-hosted runners), recommend alternatives: self-hosted runners with static IPs, private endpoints, or VNet integration for the CI runner
- [ ] **Include these IPs in the discovery report** under a dedicated "Operator Network Access" section

> **Rule**: If any module has network_acls `default_action = Deny` and operator IPs are empty or not asked, **STOP** and ask — empty `ip_rules` with `default_action = Deny` will lock out Terraform itself.

**Step 4 — Service Interdependency Mapping (MUST ASK):**

12. Which services depend on which? (e.g., "App needs DB and Redis before starting")
13. Any services that must be deployed BEFORE others? (e.g., DB migrations before app)
14. Any shared resources between services? (e.g., both FE and BE share same DB)

> Build a dependency graph from answers. Validate no circular dependencies.

**Step 5 — Infrastructure & Access Details (MUST ASK — branched by deployment model from Step 1):**

**If server-based:**
15. Server access: IP/hostname + SSH user + PEM key path OR cloud credentials profile
16. Target OS? (Ubuntu, Amazon Linux, etc.)
17. Single server or multi-server?

**If serverless:**
15. Cloud credentials profile or service principal for deployment?
16. Service/function names if reusing existing? (e.g., existing ECS cluster, Cloud Run service, Lambda function names)

**All deployment models:**
17. Do you have a domain name? (**Note: DNS will be configured manually by the user**)
18. Production secrets or `.env` variables not in codebase?

**Step 6 — Application Profile (ASK IF NOT AUTO-DETECTED):**
20. VCS/CI platform: GitHub, GitLab, or Bitbucket?
21. What port(s) does the backend run on?
22. Any custom build command?
23. Any custom start command?

**Step 7 — Deployment Strategy (MUST ASK — branched by deployment model from Step 1):**

**If server-based:**
24. Deployment method: Docker Compose, PM2, Systemd, self-managed Kubernetes?

**If serverless:**
24. Deployment method: Cloud CLI (`sam deploy`, `az functionapp deploy`, `gcloud run deploy`), Terraform only, or framework deploy (`serverless deploy`, Copilot, etc.)?

**All deployment models:**
25. Git repository URL?
26. Branch strategy? (`main → prod` / `main → staging → prod` / `feature → dev → staging → prod`)
27. Zero-downtime deployments? (blue-green, rolling update, canary, traffic shifting)
28. **Do you want CI/CD pipelines created?** (yes/no) — if no, only IaC and deployment configs will be generated, no pipeline files

**Step 8 — Monitoring & Ops (RECOMMENDED):**
28. Health check endpoint? (e.g., `/health`)
29. Log management preference? (CloudWatch, Grafana, file-based)
30. Monitoring/alerting requirements?

**Step 9 — DevSecOps Tooling (RECOMMENDED):**

> Security scanning tools integrate into your CI pipeline. Some are free/no-config, others need accounts and tokens.

**Part A — Auto-included (free, no config needed — inform user, don't ask):**

Tell the user these will be added automatically:
- **Secret Scanning** (gitleaks) — detects leaked secrets in code. Free, runs in CI, no setup.
- **Container Scanning** (Trivy) — finds vulnerabilities in Docker images. Free, runs in CI, no setup. *(Only if Dockerfile detected)*

**Part B — SAST / Code Quality (ASK):**

31. Do you want **static code analysis** (SAST) for code quality + security vulnerabilities? Options:
   - **SonarQube** (self-hosted) — needs server URL, token, project key
   - **SonarCloud** (hosted) — needs org name, token, project key
   - **Semgrep** (free tier available) — needs token for paid rules, free rules work without
   - **CodeQL** (free for public repos on GitHub) — no external config needed
   - **None** — skip SAST

32. If SonarQube/SonarCloud selected:
   - **Project Key** — unique identifier for this project in SonarQube?
   - **Organization** (SonarCloud only)?
   - Any **file/folder exclusions** from scanning? (e.g., `**/migrations/**`, `**/tests/**`)

**Part C — Dependency Scanning / SCA (ASK):**

33. For **dependency vulnerability scanning** (SCA), which approach?
   - **Dependabot** (GitHub only, free, auto-PRs) — no config needed
   - **pip-audit / safety** (free, runs in CI) — no config needed
   - **Snyk** (needs token, richer reporting)
   - **None** — skip SCA

**Part D — Dynamic Analysis / DAST (ASK — advanced):**

34. Do you want **dynamic application security testing** (DAST)? This tests a running app for vulnerabilities. Adds complexity — needs a running environment in CI.
   - **OWASP ZAP** (free) — needs target URL in CI
   - **None** — skip DAST *(recommended unless you have specific compliance needs)*

> **Rule**: Auto-include Part A tools. For Parts B/C/D, only include what the user explicitly selects. Silence = skip.

- [ ] Wait for ALL user responses before proceeding
- [ ] Clarify any ambiguous answers

### Phase 4: Generate Discovery Report

- [ ] Compile all auto-detected + user-provided information
- [ ] Include **infrastructure naming table** — every resource name as provided by user
- [ ] Include **per-module configuration table** for each selected module — auth mode, SKU/tier, runtime version, network access, identity type, app settings, linked services, and all platform-specific config collected in Step 3.5
- [ ] If reference documents from `SPEC/references/devops/` provided module configs, include them with source attribution — note "from [filename], validated by user" or "from [filename], user-overridden" next to each value
- [ ] Include **service dependency graph** with startup order
- [ ] Include **selected modules** with user-provided names
- [ ] Include note: "DNS configuration: Manual — required records will be documented in runbook"
- [ ] Include **DevSecOps tooling selections** — which tools selected, config values collected (project keys, orgs, exclusions), auto-included tools noted
- [ ] If existing `variables.tf` was found, include clarified variable mappings
- [ ] Create `docs/deployment/discovery-report.md`
- [ ] Get user confirmation on accuracy

---

### Phase 5: Tracker Story Management

**After the discovery report is approved, manage tracker story tracking. Route by the path the user took in Phase 0.5 and by `docs/status.md` Project Tracking.**

#### If user started with Jira stories (PATH J):

- [ ] Ask user:

```
📋 Jira Story Update

Your discovery report references these Jira stories:
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

Your discovery report references these GitHub issues:
  [List #N and titles]

Would you like to transition them?
  [N] Move to next status (e.g., In Review)
  [S] Skip — don't update GitHub status

Choose N or S:
```

- [ ] If N, for each issue:

```bash
# Post discovery-complete comment
gh issue comment N --repo "ORG/REPO" \
  --body "DevOps discovery complete. See docs/deployment/discovery-report.md for details."

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

Your discovery report references these work items:
  [List #WI_ID and titles]

Would you like to transition them?
  [N] Move to next state (e.g., Active → In Review / Resolved)
  [S] Skip — don't update Azure DevOps status

Choose N or S:
```

- [ ] If N, for each work item:

```bash
# Post discovery-complete comment
az boards work-item update \
  --id N \
  --discussion "DevOps discovery complete. See docs/deployment/discovery-report.md for details." \
  --project "{PROJECT}"

# Move to next state (Active → Resolved, or project-specific next state)
az boards work-item update --id N --state "Resolved" --project "{PROJECT}"
```

---

#### If user started from scratch (PATH S):

- [ ] Mandatory Ask user:

```
📋 Tracker Story

Would you like to create a story for this DevOps work on your tracker board?
  [J] Yes — create a Jira story
  [G] Yes — create a GitHub issue
  [A] Yes — create an Azure DevOps work item
  [L] I'll link an existing story — paste the URL(s) or ID(s)
  [S] Skip — no tracker needed

Choose J, G, A, L, or S:
```

**If J:**

- [ ] Ask for Jira project key, then create using `@atlassian-rovo create issue in project [PROJECT_KEY]` with a **detailed, structured story body** derived from the discovery report — NOT a generic placeholder:
  - **FORMAT CONTRACT**: pass the `description` as **Markdown** with REAL line breaks (the Rovo MCP converts Markdown → Jira ADF). Use `##`/`**...**`, NOT wiki-markup `h2.`/`*...*`, and NEVER emit literal `\n` escape sequences, or Jira renders the body as plain text.
  - **Title**: `DevOps: Set up CI/CD and infrastructure for [project name from report]`
  - **Description / Objective**: State the deployment goal — deployment model (serverless/server-based), cloud provider and region, environments, and app name — drawn from the discovery report
  - **Acceptance Criteria**: Derive specific, testable items directly from the report, for example:
    - Pipeline deploys to `[environment]` on merge to `[branch]`
    - Terraform provisions `[list of selected modules]` in `[region]` under resource group `[name]`
    - All secrets stored in `[Key Vault / Secrets Manager name]` and accessed via Managed Identity
    - Container image built and pushed to `[registry name]` on every pipeline run
    - `[Monitoring tool]` configured with alerts for HTTP 5xx and CPU thresholds
    - Discovery report approved and available at `docs/deployment/discovery-report.md`
  - **Out of Scope**: List explicitly what is NOT in this story — modules the user did not select, DNS (manual), any DAST/SAST tools the user skipped, and downstream workflows (`aire-devops-pipeline` handles IaC authoring)
  - Record the created story ID in the discovery report
  - Ask if they want to mark as In Progress (same flow as PATH J above)

> **Rule**: NEVER write "Discovery complete. See docs/..." as the entire story body. Build the story from actual discovery report content — objective, AC, and out-of-scope must reflect what was gathered in Phases 1–4.

**If G:**

> **Rule for the agent: run every `gh` command yourself via the Bash tool. Do NOT ask the user.**

- [ ] Build a **detailed, structured issue body** from the discovery report — NOT a generic one-liner. The body must contain:

  ```
  ## Objective
  [State the deployment goal: deployment model, cloud provider, region, environment(s), app name — from discovery report]

  ## Acceptance Criteria
  - [ ] Pipeline deploys to [environment] on merge to [branch]
  - [ ] Terraform provisions [selected modules list] in [region] under [resource group / VPC name]
  - [ ] All secrets stored in [Key Vault / Secrets Manager name] and accessed via Managed Identity / IAM Role
  - [ ] Container image built and pushed to [registry name] on every pipeline run
  - [ ] [Monitoring tool] configured with alerts for HTTP 5xx and CPU > [threshold]%
  - [ ] Discovery report approved and available at docs/deployment/discovery-report.md
  [Add/remove items to match what was actually gathered in Phases 1–4]

  ## Out of Scope
  - Modules not selected during discovery (e.g., [list any skipped modules])
  - DNS configuration — manual, required records will be documented in the runbook
  - [Any security tools the user skipped, e.g., "DAST — skipped for this phase"]
  - IaC and pipeline file authoring — covered by aire-devops-pipeline
  ```

- [ ] Create the issue with this body:
  ```bash
  gh issue create --repo "ORG/REPO" \
    --title "DevOps: Set up CI/CD and infrastructure for [project name]" \
    --body "$(cat <<'EOF'
  [Structured body as built above]
  EOF
  )"
  ```
  Record the created issue number in the discovery report.
- [ ] Ask if they want to move to In Review (same flow as PATH G above).

> **Rule**: NEVER use a generic placeholder body. AC must be specific and testable, derived from the discovery report selections (modules, region, environments, tools). Out of Scope must list what was explicitly excluded.

**If A:**

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user. Skip if `docs/status.md` does NOT contain `**Tracking**: Azure DevOps`.**

- [ ] Build a **detailed, structured description** from the discovery report (same Objective / Acceptance Criteria / Out of Scope structure as the GitHub and Jira formats above). NEVER use a generic placeholder.
- [ ] Create Azure DevOps work item:
  ```bash
  az boards work-item create \
    --title "DevOps: Set up CI/CD and infrastructure for [project name]" \
    --type "User Story" \
    --description "[Structured body: Objective + AC + Out of Scope derived from discovery report]" \
    --project "{PROJECT}"
  ```
  Record the created work item ID in the discovery report.
- [ ] Offer to mark as Active:
  ```
  ❓ Should I mark Work Item #{WI_ID} as "Active"? (yes/no)
  ```
  If YES:
  ```bash
  az boards work-item update --id {WI_ID} --state "Active" --project "{PROJECT}"
  ```

**If L:**

- [ ] Ask:
  ```
  ❓ Paste the URL(s) or ID(s) of the existing story/issue — one per line:
     Jira:        https://your-org.atlassian.net/browse/PROJ-123
     GitHub:      https://github.com/ORG/REPO/issues/42   or   #42
     Azure DevOps: https://dev.azure.com/org/project/_workitems/edit/123
  ```
- [ ] Detect tracker type from URL format, extract IDs, record in discovery report.
- [ ] Ask if they want to transition (In Progress for Jira/ADO, In Review for GitHub) using the same flow as PATH J/G/A above.

**If S:** Skip — no tracker needed.

#### Update Discovery Report with Tracker Story Numbers

- [ ] If Jira stories are linked (from PATH J or Phase 5), add a **"Jira Stories"** section to `docs/deployment/discovery-report.md`:

```markdown
## Jira Stories

| Jira ID | Title | Status | URL |
|---------|-------|--------|-----|
| PROJ-123 | Set up CI/CD pipeline | In Progress | https://your-org.atlassian.net/browse/PROJ-123 |
| PROJ-124 | Configure staging environment | In Progress | https://your-org.atlassian.net/browse/PROJ-124 |
```

- [ ] If GitHub issues are linked (from PATH G or Phase 5), add a **"GitHub Issues"** section to `docs/deployment/discovery-report.md`:

```markdown
## GitHub Issues

| Issue | Title | Status | URL |
|-------|-------|--------|-----|
| #42 | Set up CI/CD pipeline | In Review | https://github.com/ORG/REPO/issues/42 |
| #43 | Configure staging environment | In Review | https://github.com/ORG/REPO/issues/43 |
```

- [ ] If Azure DevOps work items are linked (from PATH A or Phase 5), add an **"Azure DevOps Work Items"** section to `docs/deployment/discovery-report.md`:

```markdown
## Azure DevOps Work Items

| Work Item ID | Title | Status | URL |
|-------------|-------|--------|-----|
| #123 | Set up CI/CD pipeline | Active | https://dev.azure.com/org/project/_workitems/edit/123 |
| #124 | Configure staging environment | Active | https://dev.azure.com/org/project/_workitems/edit/124 |
```

- [ ] These sections will be read by downstream workflows (`aire-devops-pipeline`, `aire-devops-deploy`) to update tracker story status upon completion.

#### Update docs/status.md

- [ ] If `docs/status.md` does **not** exist: read `SPEC/templates/STATUS_FORMAT.md` and create `docs/status.md` from it (use the template as-is, filling in the project name and date). Do NOT skip this step — downstream workflows depend on `docs/status.md` being present.
- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "DevOps Discovery" row to `✅ Done`, evidence: `docs/deployment/discovery-report.md`

---

## Output

**Location**: `docs/deployment/discovery-report.md`

**Contents**:
- Auto-detected application profile
- User-provided deployment requirements
- Infrastructure target details
- Per-module configuration details (auth mode, SKU/tier, runtime, network access, identity, app settings, linked services — per platform)
- Branch strategy
- Service dependencies
- Secret management requirements
- **Jira Stories** — linked story IDs, titles, status, and URLs (if Jira integration used)
- **GitHub Issues** — linked issue numbers, titles, status, and URLs (if GitHub integration used)
- **Azure DevOps Work Items** — linked work item IDs, titles, status, and URLs (if Azure DevOps integration used)

---

## Rules

- 🔴 CHECK `SPEC/references/devops/` FIRST — read ALL reference docs before discovery. Use `aire read` for .docx/.pdf. NEVER skip.
- 🔴 AUTO-DETECT before asking — never ask what can be found in code
- 🔴 ASK SERVERLESS VS SERVER first — determines entire architecture
- 🔴 COLLECT INFRA NAMING ONCE — resource group, region, VNet, subnet, prefix asked once, used everywhere
- 🔴 NEVER AUTO-GENERATE NAMES — every resource name comes from user input
- 🔴 ASK MODULE SELECTION — user chooses which modules and provides exact names
- 🔴 ASK PER-MODULE CONFIG — for every selected module, ask authentication mode, SKU/tier, runtime version, network access, identity type, app settings, and linked service connections. Branch questions by platform (Azure/AWS/GCP) and by service type variant. Never assume defaults without asking.
- 🔴 VALIDATE REFERENCE DOCS — if `SPEC/references/devops/` docs provided module configs, pre-fill in questions but still confirm each value with user. User answer wins on conflict.
- 🔴 MAP INTERDEPENDENCIES — build service dependency graph, validate no circular deps
- 🔴 READ VARIABLES.TF — if exists, read and ask user to clarify unclear names (RULE T8)
- 🔴 DNS IS MANUAL — never auto-configure DNS; document required records only
- 🔴 SINGLE APP MODULE — frontend + backend are ONE App Service module, never separate
- 🔴 WAF IS OPTIONAL — only include if user explicitly requests
- 🔴 AUTO-INCLUDE gitleaks and Trivy (if Docker) — no user choice needed
- 🔴 SAST/SCA/DAST tools only if user explicitly selects — silence = skip
- 🔴 ASK all must-ask questions — never assume deployment target
- 🔴 WAIT for user responses — never proceed without answers
- 🔴 No secrets in discovery report — reference names only, no values
- 🔴 If ANY module uses network_acls `default_action = Deny` or disables public access, MUST collect operator/admin IPs — empty `ip_rules` with Deny locks out Terraform and operators
- 🔴 Get user CONFIRMATION on discovery report before next phase
- 🔴 ASK TRACKER FIRST — ask user if they have a Jira story, GitHub issue, Azure DevOps story, or want to work from scratch before starting discovery
- 🔴 CHECK STORY COMPLETENESS — if a tracker story is provided, verify Description and Acceptance Criteria exist; ask clarifying questions for missing fields
- 🔴 JIRA STORIES IN REPORT — if Jira stories linked, include "Jira Stories" section in discovery report with story IDs, titles, status, and URLs
- 🔴 GITHUB ISSUES IN REPORT — if GitHub issues linked, include "GitHub Issues" section in discovery report with issue numbers, titles, status, and URLs
- 🔴 OFFER JIRA TRANSITION — after discovery report approval, offer to mark Jira stories as In Progress or next status
- 🔴 OFFER GITHUB TRANSITION — after discovery report approval, offer to move GitHub issues to In Review; use `gh` commands directly, do NOT ask user to run them
- 🔴 OFFER TRACKER CREATION — if user started from scratch (PATH S), present all three tracker options (Jira, GitHub, Azure DevOps) and let the user choose; also offer to link an existing story or skip entirely
- 🔴 AZURE DEVOPS WORK ITEMS IN REPORT — if Azure DevOps work items linked, include "Azure DevOps Work Items" section in discovery report with IDs, titles, status, and URLs

---

## Completion

```
✅ Discovery Complete!

📄 Report: docs/deployment/discovery-report.md
📋 Jira: [N] stories linked — [status] (or "No Jira stories linked")
Next step is:

1️⃣  aire-devops-pipeline -> Create CI/CD pipeline and IAC

```

---

**Tell me about your project, then type "proceed" to start discovery.**
