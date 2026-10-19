---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# DevOps Rulebook

## Purpose

Mandatory standards for CI/CD pipeline creation, containerization, infrastructure as code, and deployment automation. Every rule exists because violating it caused a real deployment failure.

---


## Strict Constraints

| Rule | Description |
|------|-------------|
| ✅ DISCOVER FIRST | Always run discovery phase before generating any pipeline |
| ✅ AUTO-DETECT | Detect app type, dependencies, commands from codebase before asking user |
| ✅ ASK BEFORE BUILDING | Gather all deployment context via discovery questions |
| ✅ PLAN BEFORE EXECUTE | Generate deployment plan, get user approval, then build |
| ✅ SECRETS MANAGEMENT | Never hardcode secrets; use GitHub Secrets / environment variables |
| ✅ HEALTH CHECKS | Every deployment includes health check verification |
| ✅ ROLLBACK STRATEGY | Every deployment has a documented rollback path |
| ✅ ASK SERVERLESS VS SERVER | Always ask if deployment is serverless or server-based before proceeding |
| ✅ USER-PROVIDED NAMES ONLY | NEVER auto-generate resource names; always ask user for exact names |
| ✅ COLLECT INFRA PARAMS ONCE | Resource group, region, VNet, subnet, location — ask once, use everywhere |
| ✅ ASK MODULE SELECTION | Ask user which service modules they want and their names before generating Terraform |
| ✅ MAP INTERDEPENDENCIES | Build service dependency graph before generating configs |
| ✅ READ VARIABLES.TF | If `variables.tf` exists, read it and ask user to clarify any unclear variable names |
| ✅ SINGLE APP MODULE | Frontend and backend are part of ONE App Service module — never separate modules |
| 🚫 NO AUTO DNS | DNS is ALWAYS configured manually by user; agent only documents required records |
| 🚫 NO AUTO-GENERATED NAMES | Never invent resource names — every name comes from user input |
| 🚫 NO SEPARATE FE/BE MODULES | Frontend and backend MUST be in a single App Service module |
| 🚫 NO STORAGE QUEUES | NEVER create Storage Queues in any module — out of scope |
| 🚫 NO PRIVATE ENDPOINT: QUEUE | NEVER create Private Endpoints for Queues — out of scope |
| 🚫 NO ADF DIAGNOSTIC SETTINGS | NEVER create ADF Diagnostic Settings — out of scope |
| 🚫 NO LOGIC APPS | NEVER create Logic Apps — out of scope |
| 🚫 NO PRIVATE DNS ZONES (UNLESS ASKED) | Private DNS Zones only if user explicitly requests |
| 🚫 NO SOURCE CODE CHANGES | Never modify application source code; flag bugs for DEV |
| 🚫 NO CREDENTIALS IN CODE | Never commit secrets, keys, passwords, or tokens |
| 🚫 NO MANUAL STEPS | If it can be automated, it must be automated |
| 🚫 NO SKIPPING TESTS | CI pipeline must run tests before any deployment |
| 🚫 NO DIRECT PUSH TO MAIN | Enforce branch protection in pipeline design |

---

## GitHub Actions Workflow Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| W1 | CI workflow MUST have `workflow_call` trigger when used as reusable workflow | Deploy pipelines fail with "workflow is not reusable" |
| W2 | Every file referenced in a workflow MUST exist in the repo | Deploy step fails with "file not found" |
| W3 | Every tool installed in CI MUST be run, every tool run MUST be installed | Wasted CI time or job failure |
| W4 | Deploy workflows MUST cover ALL environments defined in the plan | Missing environment has no infra |

## Git Workflow Enforcement

The CI/CD pipeline MUST enforce:

| Rule | Implementation |
|------|---------------|
| Feature branches from `develop` | Pipeline triggers on PR to `develop`/`main` |
| Conventional commits | Lint commit messages (`feat:`, `fix:`, `chore:`) |
| Never push directly to `main` | Branch protection rules documented |
| Tests before merge | CI must pass before PR merge allowed |
| Security scan before merge | Bandit + Safety checks in CI |

### W1 Example — Reusable Workflow

```yaml
# ✅ CORRECT
on:
  workflow_call:        # Required for deploy pipelines to call this
  pull_request:
    branches: [develop, main]

# ❌ WRONG — deploy workflows using `uses: ./.github/workflows/ci.yml` will fail
on:
  pull_request:
    branches: [develop, main]
```

---

## Docker & Compose Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| D1 | ONE reverse proxy only — host Nginx OR container Nginx, NEVER both | Port conflict: `bind: address already in use` |
| D2 | App port: `expose` not `ports` when behind reverse proxy | Security bypass — app accessible without SSL/headers |
| D3 | Resource limits: `mem_limit`/`cpus`, NOT `deploy.resources` (needs Swarm) | Limits silently ignored |
| D4 | Every compose file referenced in workflows MUST exist | Deploy fails on missing file |
| D5 | `.dockerignore` MUST exist excluding `.git/`, `terraform/`, `.env`, `*.pem` | Secrets leaked into image, bloated builds |

### D2 Example — Port Exposure

```yaml
# ✅ CORRECT — behind reverse proxy
services:
  app:
    expose: ["8000"]       # Internal only

# ❌ WRONG — bypasses all proxy security
services:
  app:
    ports: ["8000:8000"]   # Exposed to world
```

---

## Nginx Configuration Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| N1 | `limit_req_zone` in `http {}` context (separate conf.d file), NEVER in `server {}` | Nginx refuses to start |
| N2 | If `limit_req_zone` defined, `limit_req` MUST be used in a `location` block | Rate limiting silently not working |
| N3 | Always run `nginx -t` after writing config, fail script if invalid | Broken config persists |

### N1 Example — Rate Limiting

```nginx
# ✅ CORRECT — zone in http context
# /etc/nginx/conf.d/rate-limit.conf
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

# /etc/nginx/sites-available/app (server context)
server {
    location / {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:8000;
    }
}

# ❌ WRONG — zone inside server block
server {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
}
```

---

## Rollback Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| R1 | Rollback MUST restore the previous working image, not restart the broken one | App stays on broken version |
| R2 | Full sequence: read saved tag → pull that image → restart with it | Partial rollback — still broken |

### Rollback Pattern

```bash
# ✅ CORRECT — full rollback
ROLLBACK_IMAGE=$(cat /opt/app/.rollback-tag)
export APP_IMAGE="$ROLLBACK_IMAGE"
docker compose -f docker-compose.prod.yml pull app
docker compose -f docker-compose.prod.yml up -d --no-deps app

# ❌ WRONG — just restarts the broken image
docker compose -f docker-compose.prod.yml up -d
```

---

## Terraform / IaC Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| T1 | Remote backend MUST be enabled for CI | State lost after each CI run |
| T2 | No `timestamp()` or non-deterministic functions in tags | Perpetual drift on every plan |
| T3 | Every declared module variable MUST be used | Dead code, confusion |
| T4 | `prevent_deletion_if_contains_resources = true` for production | Accidental infra destruction |
| T5 | SSH NSG rules MUST allow CI runner IPs when deploy uses SSH | Deploy hangs/times out |
| T6 | Terraform CI workflow covers ALL environments | Prod infra unmanaged |
| T7 | ALL resource names MUST come from user input — NEVER auto-generated | Naming chaos, resources impossible to identify |
| T8 | If `variables.tf` exists, READ it and ask user to clarify unclear variable names | Wrong values bound to wrong variables |
| T9 | Frontend + backend in SINGLE App Service module — NEVER separate FE/BE modules | Over-engineered modules, duplicated configs |
| T10 | WAF module OPTIONAL — only create if user explicitly requests | Unnecessary cost or missing security |
| T11 | Core infra params (project prefix, region, networking — Resource Group for Azure, VPC for AWS/GCP, subnets) defined ONCE in root `variables.tf`, passed to ALL modules. Branch by cloud provider — Resource Group is Azure-only, GCP uses Project ID. | Cross-module drift, inconsistent regions/networks |
| ACL1 | When `network_acls.default_action = "Deny"`, `ip_rules` MUST include operator IPs (developer laptops, CI/CD runners, Terraform runner). Pass as `variable "operator_ip_addresses"` in root, used by all network-restricted modules. | Terraform and operators locked out of the resource — cannot write secrets, update configs, or manage it on subsequent runs |
| SQL1 | When `azuread_administrator` is configured, `azuread_authentication_only` MUST match auth strategy. Default to `true` (AD-only). If `false`, `administrator_login` + `administrator_login_password` are REQUIRED. | `terraform plan` fails with missing required attributes, or SQL Server deployed with no valid login method |

### T7 Example — User-Provided Naming

```hcl
# ✅ CORRECT — all names from user input
variable "resource_group_name" {
  default = "rg-myapp-prod"  # User provided this exact name
}

# ❌ WRONG — auto-generated name
variable "resource_group_name" {
  default = "rg-default-001"  # Agent invented this
}
```

### T9 Example — Single App Service Module

```hcl
# ✅ CORRECT — frontend and backend in one module
module "app_service" {
  source = "./modules/app-service"
  # Handles both frontend and backend
}

# ❌ WRONG — separate modules
module "frontend" { source = "./modules/frontend" }
module "backend"  { source = "./modules/backend" }
```

### T11 Example — Core Infra Params Defined Once

```hcl
# ✅ CORRECT — root variables.tf, passed to all modules
# terraform/variables.tf
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "vnet_name"           { type = string }

# terraform/main.tf
module "network" {
  source              = "./modules/network"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.vnet_name
}
module "app_service" {
  source              = "./modules/app-service"
  resource_group_name = var.resource_group_name
  location            = var.location
}

# ❌ WRONG — hardcoded in individual modules
module "network"     { location = "eastus" }
module "app_service" { location = "westus2" }  # Mismatch!
```

### T2 Example — Tags

```hcl
# ✅ CORRECT — deterministic
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ❌ WRONG — changes every plan
locals {
  common_tags = {
    CreatedAt = timestamp()
  }
}
```

---

## Out-of-Scope Resource Exclusions

**These resources MUST NEVER be created in any module, regardless of context.**

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| EX1 | NEVER create **Storage Queues** in any module | Out of scope — unnecessary resource, wasted cost |
| EX2 | NEVER create **Private Endpoint: Queue** in any module | Out of scope — queue endpoints not managed by this agent |
| EX3 | NEVER create **ADF Diagnostic Settings** in any module | Out of scope — Azure Data Factory diagnostics not managed |
| EX4 | NEVER create **Logic Apps** in any module | Out of scope — orchestration/integration not managed |
| EX5 | **Private DNS Zones** are OPTIONAL — only create if user explicitly requests during discovery | Created without consent — unexpected DNS management burden |

> If user requests any EX1-EX4 resource, inform them it is out of scope. For EX5, ask explicitly during discovery.

---

## Discovery & Naming Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| DN1 | Ask **serverless vs server-based** FIRST — before any other infra questions | Wrong architecture, wasted work |
| DN2 | Collect core infra params ONCE from user — Project Prefix + Region always; Resource Group (Azure), VPC (AWS/GCP), Subnets, GCP Project ID as applicable. Do NOT ask Azure-specific params for AWS/GCP or vice versa. | Inconsistent naming across files |
| DN3 | NEVER auto-generate resource names — every name from user input | Naming chaos, impossible to audit |
| DN4 | Ask which service modules user wants WITH exact names | Unwanted modules created, missing needed ones |
| DN5 | Frontend + backend = ONE App Service module | Over-engineered, duplicated configs |
| DN6 | WAF is optional — only create when user explicitly asks | Unnecessary cost |

## DNS Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| DNS1 | DNS is ALWAYS configured manually by the user | Agent creates DNS records user didn't authorize, potential domain hijack |
| DNS2 | Agent MUST document required DNS records in runbook (A, CNAME, etc.) | User doesn't know what records to create |
| DNS3 | Never include DNS provider credentials or API calls in any generated file | Security risk — DNS provider access leaked |

## Service Interdependency Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| SI1 | Map ALL service dependencies before generating any config | Missing `depends_on`, services start out of order, crashes |
| SI2 | Validate no circular dependencies in the dependency graph | Deadlock — services wait for each other forever |
| SI3 | Reflect dependencies in Docker Compose `depends_on`, Terraform `depends_on`, and pipeline deploy order | Partial dependency enforcement — works in one layer, breaks in another |
| SI4 | Document deployment order in runbook (which service starts first, second, etc.) | Manual deploys done out of order, cascading failures |

---

## File Consistency Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| F1 | Every file path referenced in configs MUST exist or be documented as "USER MUST CREATE" | Builds fail at various stages |
| F2 | After generating ALL files, run cross-reference check | Broken refs found only at deploy time |

---

## Security Rules

| ID | Rule |
|----|------|
| S1 | NEVER commit secrets, keys, passwords, or tokens |
| S2 | Use GitHub Secrets / environment variables for all sensitive values |
| S3 | Run `bandit` (Python code) + `pip-audit` (dependencies) in CI |
| S4 | Scan Docker images with `trivy` (if containerized) |
| S5 | Fail pipeline on critical/high vulnerabilities |
| S6 | Non-root user in Dockerfile |
| S7 | Fail2ban on all servers |

---

## Quality Gates

| Gate | Target | Description |
|------|--------|-------------|
| Lint Pass | 0 errors | All linting rules satisfied |
| Tests Pass | 100% | All tests pass in CI |
| Coverage | ≥85% | Minimum code coverage |
| Security Scan | 0 critical/high | No critical vulnerabilities |
| Health Check | 200 OK | Post-deploy health check passes |
| Rollback Tested | Yes | Rollback procedure verified |
| Secrets Secure | Yes | No secrets in code or logs |
| Documentation | Complete | Runbooks created and accurate |
| Naming Consistency | All user-provided | Every resource name matches user input |
| Interdependency | Mapped | Dependency graph validated, no circular deps |
| Module Selection | User-approved | Only user-selected modules created |
| DNS | Manual | Required records documented, no auto-config |
| Validation | All passed | Post-generation checklist complete (T1-T11) |

---

## Red Flags

| Red Flag | Action |
|----------|--------|
| Secrets in source code | Remove, rotate credentials, add to `.gitignore` |
| No tests in pipeline | Add test stage — forbidden without tests |
| Manual deployment steps | Automate — manual steps will break |
| No health check | Add one — blind deployments cause outages |
| No rollback plan | Define before deploying |
| Direct push to main | Configure branch protection rules |
| Hardcoded IPs/ports | Use environment variables |
| No `.env.example` | Create one for onboarding |
| Skipping security scan | Never — vulnerabilities ship silently |
| CI workflow missing `workflow_call` | Deploy pipelines calling CI will fail |
| Nginx on host AND in container | Pick ONE — port conflict |
| `limit_req_zone` inside `server {}` | Move to `http {}` — nginx won't start |
| App port exposed directly (`ports:`) | Change to `expose:` — bypasses proxy security |
| `timestamp()` in Terraform tags | Causes perpetual drift every plan |
| Terraform local backend in CI | State lost after each CI run |
| Tool installed but never run in CI | Remove unused or add missing run steps |
| Missing `.dockerignore` | Secrets leak into image |
| Compose file referenced but missing | Deploy will fail |
| Rollback doesn't switch image | Must read saved tag, pull, restart |
| `prevent_deletion = false` in prod | Set `true` — prevents accidental deletion |
| SSH blocked but deploy uses SSH | Add CI runner IPs to NSG |
| Auto-generated resource names | All names from user — ask in discovery |
| Separate FE/BE Terraform modules | Merge into single App Service module |
| WAF created without user request | Optional — only when explicitly asked |
| Core params hardcoded per module | Define once in root `variables.tf` |
| Existing `variables.tf` not read | Read and clarify unclear names |
| Agent auto-configuring DNS | DNS is ALWAYS manual |
| No interdependency mapping | Build dependency graph first |
| Out-of-scope resources created | Remove immediately (Queue, ADF Diag, Logic App) |
| Private DNS Zone without user request | Only if explicitly requested |