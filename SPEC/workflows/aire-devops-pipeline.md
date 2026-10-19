---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: DevOps - CI/CD Pipeline. Create GitHub Actions workflows for lint, test, security, build, and deploy. Also refactors/upgrades existing pipelines and IaC when an infra evolution plan exists.
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
3. Read `docs/deployment/discovery-report.md` (REQUIRED in Greenfield Mode — run `aire-devops-discover` first if missing. NOT required in Evolution Mode, i.e. when `docs/deployment/infra-evolution-plan.md` exists — the evolution plan is the config source instead)
4. Read existing `Dockerfile` and `docker-compose*.yml` (if any)
5. Read `docs/deployment/infra-evolution-plan.md` (if exists — triggers **Evolution Mode**)
6. Read `docs/deployment/infra-current-state.md` (if exists — provides baseline for evolution)
7. Read "Jira Stories", "GitHub Issues", and "Azure DevOps Work Items" sections from `docs/deployment/discovery-report.md` and/or `docs/deployment/infra-evolution-plan.md` (if exists — extract linked tracker IDs for status update after pipeline creation)
8. Read `docs/status.md` → `## Project Tracking` block to determine active tracker: `**Tracking**: Jira` | `**Tracking**: GitHub Projects` | `**Tracking**: Azure DevOps` | neither

---

## Prerequisites Check

### Mode Detection (run FIRST)

- [ ] Check if `docs/deployment/infra-evolution-plan.md` exists:
  - **If YES** → enter **Evolution Mode** — execute Phase 7 (Evolve Existing Infrastructure) AFTER or INSTEAD OF greenfield phases, based on what the plan specifies
  - **If NO** → enter **Greenfield Mode** — execute Phases 1-6 as normal (create from scratch)

### Greenfield Mode prerequisites

- [ ] `docs/deployment/discovery-report.md` exists and is approved
- [ ] If missing: **STOP** — tell user to run `aire-devops-discover` first

### Evolution Mode prerequisites

- [ ] `docs/deployment/infra-evolution-plan.md` exists and is approved — the discovery report is OPTIONAL; wherever a phase below says "read the discovery report", use the evolution plan (esp. §4b-2 Per-Module Configuration) as the source when no discovery report exists

---

## Execution Steps:

### Phase 1: Dockerfile & Compose (server-based deployments only)

**Skip this phase entirely if discovery report says serverless deployment (Lambda, Fargate, Cloud Run, Azure Functions, etc.) — serverless does not use Dockerfile/Compose.**

- [ ] Read discovery report — extract user-provided names, selected modules, dependency graph, deployment model (serverless vs server)
- [ ] **If serverless**: Skip to Phase 1.5 (or Phase 2 if no IaC)
- [ ] Create `Dockerfile` (if not exists) — non-root user, healthcheck, minimal image
- [ ] Create `.dockerignore` excluding `.git/`, `.github/`, `terraform/`, `.env`, `*.pem`, `__pycache__/`
- [ ] Create `docker-compose.prod.yml` — app (expose only, NOT ports), db, redis (if needed), nginx
- [ ] **Service ordering**: Set `depends_on` based on interdependency graph from discovery report
- [ ] Create `docker-compose.staging.yml` (if staging environment defined) — OR document that staging uses same compose file
- [ ] **RULE D1**: Pick ONE reverse proxy method (host Nginx OR container Nginx) — never both
- [ ] **RULE D2**: App uses `expose: ["PORT"]` not `ports: "PORT:PORT"` when behind proxy
- [ ] **RULE D3**: Resource limits use `mem_limit`/`cpus`, NOT `deploy.resources`
- [ ] Create `nginx/app.conf` (if using container Nginx)
- [ ] **RULE N1**: `limit_req_zone` in separate `http {}` context file, NOT inside `server {}`
- [ ] Create `Makefile` with targets: build, up, down, logs, deploy, rollback, health, migrate, test, lint

### Phase 1.5: Per-Module Configuration Extraction (CRITICAL)

**Before generating ANY Terraform code, extract ALL per-module configuration details from the discovery report. This phase creates a configuration checklist that Phase 4 (Terraform) MUST follow exactly. Missing a documented config is a validation failure.**

For EACH module in the discovery report, read its per-module configuration section and extract:

- [ ] **Authentication & access model** per service:
  - Database (SQL Server): SQL auth / Entra ID (AAD) / both — if Entra ID, extract AAD admin object ID → configure `azuread_administrator` block, set `azuread_authentication_only` accordingly
  - Database (PostgreSQL): password / Entra ID / both — if Entra ID, configure `authentication` block with `active_directory_auth_enabled`
  - Database (CosmosDB): primary key / RBAC — if RBAC, set `access_key_metadata_writes_enabled = false`
  - Key Vault: RBAC / Access Policy — set `enable_rbac_authorization` accordingly
  - Storage: access keys / Managed Identity / SAS — determines auth pattern for consumers
  - Container Registry: admin user / service principal / Managed Identity — set `admin_enabled` accordingly
  - Other services: auth method as documented

- [ ] **SKU, tier, and compute settings** per service:
  - Database (SQL Server): Serverless (`GP_S_Gen5_*`) / Provisioned (`GP_Gen5_*`) / DTU (`S0`, `S1`, etc.) — set `sku_name`; if serverless, extract `auto_pause_delay_in_minutes` and `min_capacity`
  - Database (PostgreSQL): SKU tier (Burstable/GP/MemoryOptimized) + SKU name (e.g., `B_Standard_B1ms`) — set `sku_name`; extract `storage_mb`, `version`, `high_availability` mode
  - Database (CosmosDB): Provisioned (extract max RU/s, autoscale) / Serverless — set `offer_type` and throughput settings; extract consistency level
  - App Service Plan: SKU name (`B1`, `S1`, `P1v3`, `EP1`, etc.) — set `sku_name`; extract OS type
  - Function App hosting: Consumption (`Y1`) / Premium (`EP1-EP3`) / Dedicated — set plan SKU
  - Static Web App: Free / Standard — set `sku_tier` and `sku_size`
  - Front Door: Standard / Premium — set `sku_name`
  - Key Vault: Standard / Premium — set `sku_name`
  - Storage Account: Standard / Premium + LRS / GRS / ZRS / GZRS — set `account_tier` and `account_replication_type`
  - Cache (Redis): SKU family + capacity (e.g., `C0`, `C1`, `P1`) — set `family`, `sku_name`, `capacity`
  - Container Registry: Basic / Standard / Premium — set `sku`
  - Message Queue (Service Bus): Basic / Standard / Premium — set `sku`
  - OpenAI: model deployment types (Standard/Provisioned) + PTU counts

- [ ] **Runtime stack and version** per compute service:
  - Function Apps: language + version (e.g., `python_version = "3.11"`, `node_version = "20"`) → set in `site_config` `application_stack` block; extract OS type (Linux/Windows)
  - App Service: stack + version (e.g., `dotnet_version = "8.0"`, `python_version = "3.11"`) → set in `site_config` `application_stack` block; extract OS type
  - Extract `always_on`, `minimum_tls_version`, `health_check_path` if specified

- [ ] **Networking config** per service:
  - Public network access: enabled or disabled — set `public_network_access_enabled` on EVERY resource that has this attribute
  - VNet integration subnet: for compute services (App Service, Function Apps) — set `virtual_network_subnet_id`
  - Key Vault network ACLs: default action (Allow/Deny), bypass (AzureServices), IP rules — set `network_acls` block
  - Storage network rules: default action, bypass, IP rules, VNet rules — set `network_rules` block
  - Database firewall rules: specific IPs, Azure services, VNet rules
  - Cache firewall rules: allowed IPs, private endpoint
  - Private endpoints: for any service where public access is disabled
  - **Operator/admin IP whitelist (RULE ACL1)**: Extract operator IPs from discovery report "Operator Network Access" section → add to `ip_rules` on EVERY resource that has `default_action = Deny` or equivalent firewall rules. This includes Key Vault `network_acls.ip_rules`, Storage `network_rules.ip_rules`, SQL Server firewall rules, etc. If operator IPs are missing from the discovery report, **STOP** and ask user.

- [ ] **Identity and RBAC** per compute service:
  - Identity type: System-Assigned MI, User-Assigned MI, or none — set `identity` block with correct `type`
  - For EACH compute service with MI, extract ALL resources it needs access to and the required role:
    - Key Vault → `Key Vault Secrets User` (read secrets) or `Key Vault Crypto User` (use keys)
    - Storage → `Storage Blob Data Contributor` or `Storage Blob Data Reader`
    - SQL Server → `Directory Readers` on AAD or connection string via Key Vault
    - CosmosDB → `Cosmos DB Account Reader Role` or `Cosmos DB Built-in Data Contributor`
    - Service Bus → `Azure Service Bus Data Sender` / `Azure Service Bus Data Receiver`
    - Container Registry → `AcrPull`
    - Other services as documented
  - **Create `azurerm_role_assignment` for EVERY MI → resource pair** — do NOT skip any

- [ ] **App settings and connection strings** per compute service:
  - Extract EXACT key names from discovery (e.g., `DB_CONNECTION_STRING`, `KEY_VAULT_URI`, `REDIS_URL`, `STORAGE_ACCOUNT_NAME`)
  - Map each key to its value source:
    - Key Vault reference: `@Microsoft.KeyVault(SecretUri=...)` or `@Microsoft.KeyVault(VaultName=...;SecretName=...)`
    - Terraform output: direct reference to another resource's output attribute
    - Static value: literal string from discovery
  - Set in `app_settings` block of the corresponding `azurerm_linux_web_app`, `azurerm_linux_function_app`, etc.
  - **Do NOT substitute different key names** — if discovery says `DB_CONNECTION_STRING`, use exactly that, not `KEY_VAULT_URI` or `SQL_CONNECTION`

- [ ] **Linked services and connections** (Data Factory, etc.):
  - For each linked service listed in discovery, create the corresponding Terraform resource:
    - Key Vault linked service → `azurerm_data_factory_linked_service_key_vault`
    - ADLS Gen2 linked service → `azurerm_data_factory_linked_service_data_lake_storage_gen2`
    - SQL linked service → `azurerm_data_factory_linked_service_sql_server`
    - REST linked service (Function App endpoints) → `azurerm_data_factory_linked_service_web` or custom
    - Other types as documented
  - **Do NOT skip any linked service from the discovery list**
  - Set authentication method per linked service (Managed Identity, connection string, Key Vault-backed)

- [ ] **Data policies** per storage/database:
  - Blob versioning: `is_versioning_enabled` on storage account
  - Lifecycle management rules: `azurerm_storage_management_policy` with rules for tier-to-Cool, tier-to-Archive, delete — exact day counts from discovery
  - Soft delete retention: `blob_properties.delete_retention_policy.days` and `container_delete_retention_policy.days`
  - Database backup: retention days, geo-redundant backup
  - CosmosDB: backup policy (periodic/continuous), retention hours, storage redundancy

- [ ] **Secret references**:
  - List ALL Key Vault secret names from discovery with their exact names
  - For each secret: who produces the value? (Terraform via `azurerm_key_vault_secret`, user manual entry, external service rotation)
  - For each secret: who consumes it? (which compute service, via what app setting key, using Key Vault reference or data source)
  - Create `azurerm_key_vault_secret` resources for secrets that Terraform can populate (e.g., SQL connection strings, storage keys)
  - Document secrets that require manual population in `pipeline-secrets.md`

- [ ] **Create configuration checklist**: Compile all extracted configs into an internal checklist that Phase 4 MUST cross-reference during Terraform generation. Every item in this checklist MUST have a corresponding Terraform resource attribute.

### Phase 2: CI Pipeline

**Skip Phases 2-3 entirely if discovery report says CI/CD not requested. Proceed directly to Phase 4 (Terraform) or Phase 5 (Secrets).**

- [ ] Read discovery report — check if CI/CD was requested. If not → skip to Phase 4.
- [ ] Read discovery report — extract CI/VCS platform (GitHub, GitLab, or Bitbucket)
- [ ] Create CI pipeline file in correct format for the platform:
  - **GitHub**: `.github/workflows/ci.yml`
  - **GitLab**: `.gitlab-ci.yml`
  - **Bitbucket**: `bitbucket-pipelines.yml`
- [ ] **RULE W1** (GitHub only): `on:` block MUST include `workflow_call` trigger (for reusable workflow)
- [ ] Add pull request and push triggers (syntax varies by platform)
- [ ] **Lint job** — use tools detected in codebase, branched by language:

  | Language | Linters / Formatters |
  |----------|---------------------|
  | Python | ruff, flake8, black, isort, mypy |
  | Node.js/TS | eslint, prettier, tsc --noEmit |
  | Java/Kotlin | checkstyle, spotless, ktlint |
  | .NET/C# | dotnet format --verify-no-changes |
  | Go | golangci-lint, gofmt -l |
  | Rust | cargo clippy, cargo fmt --check |
  | Ruby | rubocop |
  | PHP | phpstan, php-cs-fixer |

- [ ] **Test job** — branched by language:

  | Language | Test Runner | Coverage |
  |----------|------------|----------|
  | Python | pytest | pytest-cov |
  | Node.js/TS | jest / vitest / mocha | --coverage / c8 |
  | Java/Kotlin | mvn test / gradle test | jacoco |
  | .NET/C# | dotnet test | coverlet |
  | Go | go test ./... | -coverprofile |
  | Rust | cargo test | cargo-tarpaulin |
  | Ruby | rspec / minitest | simplecov |
  | PHP | phpunit | --coverage-clover |

  Add service containers for DB/Redis if detected in dependencies.

- [ ] **Security job** — branched by language:

  | Language | SAST | Dependency Audit |
  |----------|------|-----------------|
  | Python | bandit | pip-audit / safety |
  | Node.js/TS | — | npm audit / yarn audit |
  | Java/Kotlin | — | mvn dependency-check / gradle dependencyCheckAnalyze |
  | .NET/C# | — | dotnet list package --vulnerable |
  | Go | gosec | govulncheck |
  | Rust | cargo-audit | cargo-audit |
  | Ruby | brakeman (Rails) | bundler-audit |
  | PHP | — | composer audit |

  Install ONLY what you run **(RULE W3)**. If multiple languages detected, create a job per language.
- [ ] Upload coverage report as artifact

#### DevSecOps Jobs (from discovery report — DevSecOps tooling selections)

**Auto-included (always add):**
- [ ] **Secret scanning job**: gitleaks — scan for leaked secrets in code. No config needed, always add.
- [ ] **Container scanning job** (if Dockerfile exists): Trivy — scan Docker image for CVEs. No config needed.

**Conditional (only if selected in discovery):**
- [ ] **SAST job** (if SonarQube/SonarCloud selected): Run sonar-scanner, consume coverage report. Requires `SONAR_TOKEN` + `SONAR_HOST_URL` secrets. Create `sonar-project.properties` in repo root with project key, org, exclusions from discovery.
- [ ] **SAST job** (if Semgrep selected): Run `semgrep ci`. Requires `SEMGREP_APP_TOKEN` secret for paid rules, free rules need no token.
- [ ] **SAST job** (if CodeQL selected): Add CodeQL analysis workflow using `github/codeql-action`. GitHub-only, no external config.
- [ ] **SCA job** (if Snyk selected): Run `snyk test`. Requires `SNYK_TOKEN` secret.
- [ ] **SCA job** (if pip-audit/safety selected): Run pip-audit or safety in CI. No external config.
- [ ] **Dependabot config** (if Dependabot selected): Create `.github/dependabot.yml`. GitHub-only.
- [ ] **DAST job** (if OWASP ZAP selected): Run ZAP baseline scan against deployed staging URL. Add after deploy-staging job.
- [ ] **RULE W3 applies**: Every tool installed MUST be run, every tool run MUST be installed

### Phase 3: Deploy Pipelines

- [ ] Create deploy pipelines in correct format for the CI platform:
  - **GitHub**: `.github/workflows/deploy-staging.yml` + `.github/workflows/deploy-production.yml`
  - **GitLab**: Deploy stages within `.gitlab-ci.yml` (staging + production)
  - **Bitbucket**: Deploy steps within `bitbucket-pipelines.yml` (staging + production)
- [ ] (GitHub) Both MUST call CI as reusable workflow: `uses: ./.github/workflows/ci.yml`
- [ ] **RULE W2**: Every compose file referenced in deploy scripts MUST exist
- [ ] **RULE D4**: Verify all compose file references match actual filenames
- [ ] Deploy step: SSH into server → pull image → migrate → restart → health check
- [ ] **RULE R1/R2**: Rollback MUST save current image tag BEFORE deploy, then actually restore it on failure
- [ ] Health check with retry loop (30 attempts, 2s apart)
- [ ] Failure notification

### Phase 4: Terraform Pipeline (if IaC requested)

#### 4a: Backend Bootstrap (CRITICAL — runs BEFORE `terraform init`)

- [ ] Create `terraform/bootstrap/main.tf` — a self-contained Terraform config (local backend) that provisions ALL prerequisites for the main Terraform to run:
  - Resource Group for tfstate storage (e.g., `rg-<project>-tfstate`)
  - Storage Account for tfstate (e.g., `st<project>tfstate`) with secure defaults (HTTPS-only, TLS 1.2, blob versioning enabled)
  - Storage Container for tfstate blob (e.g., `tfstate`)
  - Lock table / lease mechanism (Azure uses blob lease by default)
  - Service Principal / Managed Identity permissions (if needed for CI runner)
  - Any other foundational resources that must exist before `terraform init` can succeed
- [ ] Create `terraform/bootstrap/variables.tf` — project_prefix, location, environment (derived from discovery report, NOT hardcoded)
- [ ] Create `terraform/bootstrap/outputs.tf` — output all values needed by main backend config (resource_group_name, storage_account_name, container_name, etc.)
- [ ] Create `terraform/bootstrap/README.md` — explains this must run once before main `terraform init`
- [ ] **RULE B1**: Bootstrap MUST use local backend (no chicken-and-egg problem)
- [ ] **RULE B2**: Bootstrap resource names derived from discovery report (project prefix, environment) — NEVER hardcoded names like `rg-mip-tfstate` or `stmiptfstate`
- [ ] **RULE B3**: Bootstrap MUST be idempotent — safe to re-run without destroying existing state
- [ ] Add bootstrap step to Makefile: `make tf-bootstrap` that runs `cd terraform/bootstrap && terraform init && terraform apply -auto-approve`

#### 4b: Production-Grade Terraform Self-Sufficiency (CRITICAL)

**The Terraform codebase MUST be fully self-contained — it must create EVERY Azure/cloud resource it depends on. Nothing should be assumed to pre-exist except the Azure subscription itself and the bootstrapped backend.**

- [ ] **RULE RG1**: ALL resource groups MUST be created as Terraform resources — NEVER assume any resource group pre-exists
- [ ] **RULE RG2**: Every module that references a resource group MUST receive it via variable + `depends_on` from where it's created
- [ ] **RULE RG3**: Resource group names derived from discovery report — NEVER hardcoded
- [ ] **RULE SS1 (Self-Sufficiency)**: The Terraform config MUST create ALL of the following that are needed (not just resource groups):
  - Resource Groups (for each environment and service tier)
  - VNet, Subnets, NSGs, and all networking prerequisites
  - Key Vault (with access policies for the service principal and app services)
  - Container Registry (ACR) if Docker images are used
  - App Service Plans before App Services
  - SQL Server before SQL Databases
  - Storage Accounts before any blob/queue/table references
  - Log Analytics Workspace before any diagnostic settings
  - Application Insights before any app that references it
  - Private DNS Zones before private endpoints (if requested)
  - Managed Identities before any role assignments
  - Any provider registrations needed (e.g., `Microsoft.Web`, `Microsoft.Sql`)
- [ ] **RULE SS2**: Module dependency order MUST be explicit — use `depends_on` or output-to-input chaining so `terraform apply` never fails due to ordering
- [ ] **RULE SS3**: Every `data` source that looks up an existing resource MUST have a corresponding `resource` block that creates it — do NOT use `data` to reference resources that Terraform itself should manage
- [ ] **RULE SS4**: `terraform plan` on a clean subscription (with only bootstrap resources) MUST succeed with zero errors — this is the litmus test
- [ ] **RULE ACL1 (Control-Plane Network Access)**: When ANY resource has `network_acls.default_action = "Deny"`, `public_network_access_enabled = false` with firewall rules, or equivalent network restrictions, the `ip_rules` (or firewall rules) MUST include:
  - Operator/admin public IPs from the discovery report "Operator Network Access" section (developer laptops, CI/CD runners, VPN egress)
  - If discovery report has no operator IPs and any module uses Deny → **STOP** and ask user before generating Terraform
  - Applies to: Key Vault `network_acls.ip_rules`, Storage `network_rules.ip_rules`, SQL Server `azurerm_mssql_firewall_rule`, Container Registry `network_rule_set`, Cache firewall rules, and any other resource with network restrictions
  - Failure: `terraform apply` succeeds but Terraform itself (or operators) are locked out of the resource on subsequent runs — cannot write secrets, update configs, or manage the resource
  - **Pass operator IPs as a Terraform variable** (e.g., `variable "operator_ip_addresses" { type = list(string) }`) defined once in root `variables.tf`, used by all network-restricted modules
- [ ] **RULE SQL1 (SQL Authentication Consistency)**: When configuring `azuread_administrator` on an Azure SQL Server, `azuread_authentication_only` MUST match the authentication strategy:
  - If `azuread_authentication_only = true` → Azure AD-only auth; `administrator_login` and `administrator_login_password` are NOT required
  - If `azuread_authentication_only = false` → Mixed auth; `administrator_login` and `administrator_login_password` are REQUIRED on the `azurerm_mssql_server` resource
  - **Default to `azuread_authentication_only = true`** unless discovery explicitly requests SQL authentication (username/password login). AD-only is the secure default.
  - Failure: `terraform plan` fails with missing required attributes, or worse — deploys an SQL Server with no valid login method
- [ ] **RULE SS5 (Configuration Fidelity)**: Every per-module configuration detail from the discovery report (extracted in Phase 1.5) MUST be reflected in the generated Terraform. Specifically:
  - Auth modes: if discovery says "Entra ID", Terraform MUST have `azuread_administrator` block — not SQL-only auth
  - SKUs/tiers: if discovery says "Serverless", Terraform MUST use `GP_S_*` SKU — not Provisioned
  - Runtime versions: if discovery says "Python 3.11", Terraform MUST set `python_version = "3.11"` — not omit it
  - Network rules: if discovery says "public access disabled", Terraform MUST set `public_network_access_enabled = false`
  - App settings: if discovery says `DB_CONNECTION_STRING`, Terraform MUST use that exact key — not substitute a different name
  - Linked services: if discovery lists 3 Data Factory linked services, Terraform MUST create all 3 — not just 1
  - RBAC roles: if discovery says "Function App MI needs access to Key Vault, SQL, and Storage", Terraform MUST create 3 `azurerm_role_assignment` resources — not just Key Vault
  - Lifecycle policies: if discovery says "tier to Cool after 30 days", Terraform MUST have `azurerm_storage_management_policy` with that rule
  - Key Vault secrets: if discovery lists secret names, Terraform MUST create `azurerm_key_vault_secret` for Terraform-producible ones and document manual ones
  - **Missing a documented config is a Phase 6 validation failure — fix before presenting deliverables**
- [ ] Verify: Run `terraform validate` as part of generation to catch syntax/reference errors

#### 4d: Globally Unique Name Collision Handling (CRITICAL)

**Many Azure resources require globally unique names (Storage Accounts, Key Vaults, SQL Servers, etc.). Terraform MUST handle the case where a name is already taken — either by another subscription or by a soft-deleted resource.**

- [ ] **RULE NC1 (Name Collision Prevention)**: For ALL globally unique resources, append a short random suffix (e.g., 4-6 char hex from `random_string`) to the base name to avoid collisions. The base name still comes from discovery report, but the suffix ensures uniqueness.
  - Storage Accounts (globally unique, 3-24 chars, lowercase alphanumeric only)
  - Key Vaults (globally unique, soft-delete means deleted names stay reserved for 90 days)
  - SQL Servers (globally unique DNS name)
  - Azure Container Registries (globally unique)
  - App Service / Function App names (globally unique `*.azurewebsites.net`)
  - Cognitive Services / OpenAI accounts (globally unique)
  - Front Door / CDN endpoints (globally unique)
  - Data Factory instances (globally unique)
- [ ] **RULE NC2 (Random Suffix Strategy)**: Use a Terraform `random_string` resource (stored in state, so stable across runs) to generate the suffix:
  ```
  resource "random_string" "suffix" {
    length  = 4
    special = false
    upper   = false
  }
  locals {
    name_suffix = random_string.suffix.result
  }
  ```
  Then use `"${var.base_name}${local.name_suffix}"` for globally unique resources.
- [ ] **RULE NC3 (Soft-Delete Recovery)**: For Key Vault specifically, enable `purge_protection_enabled = false` in non-production environments (so deleted vaults don't block re-creation), OR include a `recover` mechanism. For production, keep purge protection ON and document that deleted vault names are reserved for 90 days.
- [ ] **RULE NC4 (Name Length Limits)**: Validate that base name + suffix does not exceed Azure name length limits:
  - Storage Account: max 24 chars (alphanumeric, lowercase only)
  - Key Vault: max 24 chars
  - SQL Server: max 63 chars
  - Resource Group: max 90 chars
  If base name from discovery is too long, truncate the base (not the suffix) and warn the user.
- [ ] **RULE NC5 (Output Actual Names)**: Always output the final resolved resource names (with suffix) in Terraform outputs and in deployment docs, so the user knows the exact names that were created.
- [ ] **RULE NC6 (Import Existing)**: If `terraform apply` fails because a resource already exists AND it belongs to the same subscription, prompt the user to either:
  1. Import the existing resource into Terraform state (`terraform import`)
  2. Choose a different name prefix
  3. Purge the soft-deleted resource (for Key Vault, SQL, etc.) and retry
  Include instructions for each option in the troubleshooting runbook.

#### 4e: Resource Tagging Strategy (CRITICAL)

**All Terraform-managed resources MUST have consistent tags. Tagging is handled entirely through Terraform variables — users provide additional tags at `terraform apply` time (via `-var`, `.tfvars`, or interactive prompt), NOT during workflow conversation.**

- [ ] **Default tags** — Root module defines `locals.default_tags` with `Name`, `Environment`, `Project`, `ManagedBy = "Terraform"` from root variables (discovery report values).

- [ ] **ASK USER (before generating Terraform)**: _"Do you want an `additional_tags` input variable so teams can pass extra tags (e.g. `cost_center`, `team`) at `terraform apply` time?"_
  - If **yes** → include `additional_tags` variable in root AND all modules
  - If **no** → only default tags; `additional_tags` variable is NOT generated

- [ ] **RULE TAG1 (Additional Tags Variable)**: Root module defines `variable "additional_tags" { type = map(string); default = {} }`. Users supply via tfvars or CLI at `apply` time.

- [ ] **RULE TAG2 (Tag Merging)**: Root module computes `local.tags = merge(local.default_tags, var.additional_tags)` and passes `local.tags` to every child module as `common_tags`.

- [ ] **RULE TAG3 (Per-Module Tags)**: Every child module accepts `variable "common_tags" (map(string))` + `variable "additional_tags" (map(string), default = {})`, computes `local.tags = merge(var.common_tags, var.additional_tags)`, applies `local.tags` to all resources. Callers can override per-module: `module "database" { common_tags = local.tags, additional_tags = { data_classification = "confidential" } }`.

- [ ] **RULE TAG4 (No Untagged Resources)**: Every taggable resource MUST have `tags = local.tags` — no exceptions.
- [ ] **RULE TAG5 (Tag Propagation via Provider)**: If the provider supports `default_tags` in provider block, use as baseline. Module `additional_tags` extend or override.

#### 4c: CI/CD Workflow

- [ ] Create `.github/workflows/terraform.yml`
- [ ] **Add bootstrap check job**: Before plan/apply, verify backend resources exist — if not, run bootstrap automatically or fail with clear instructions
- [ ] Plan on PR, Apply on merge
- [ ] **RULE T6**: Include jobs for ALL environments (staging + production)
- [ ] **RULE T1**: Remote backend MUST be enabled (not commented out) — backend config values MUST match bootstrap outputs
- [ ] **RULE T7**: All resource names in tfvars MUST match user-provided names from discovery
- [ ] **RULE T9**: Verify App Service module contains BOTH frontend and backend — no separate FE/BE modules
- [ ] **RULE T11**: Core infra params passed from root `variables.tf` to all modules consistently

### Phase 5: Document Secrets

- [ ] Create `docs/deployment/pipeline-secrets.md`
- [ ] List ALL secrets/variables needed with descriptions (deployment + DevSecOps tokens)
- [ ] Include DevSecOps secrets based on discovery selections:
  - `SONAR_TOKEN` + `SONAR_HOST_URL` (if SonarQube/SonarCloud)
  - `SEMGREP_APP_TOKEN` (if Semgrep with paid rules)
  - `SNYK_TOKEN` (if Snyk)
- [ ] **NEVER include actual secret values**
- [ ] Provide **platform-specific** step-by-step instructions based on CI platform from discovery:
  - **GitHub**: Settings → Secrets and variables → Actions → New repository secret
  - **GitLab**: Settings → CI/CD → Variables → Add variable
  - **Bitbucket**: Repository settings → Pipelines → Repository variables

### Phase 6: Post-Generation Validation

**MANDATORY — Validate ALL generated deployment code before presenting deliverables. Fix errors first — NEVER ship broken code.**

#### 6a: Full Codebase Validation (ALL generated artifacts)

**Terraform:**
- [ ] `terraform validate` passes on all generated code
- [ ] `terraform fmt -check` passes
- [ ] All module cross-references resolve (no missing variables/outputs)
- [ ] All resource dependencies explicit — no implicit ordering failures
- [ ] No circular dependencies between modules
- [ ] No hardcoded subscription IDs, tenant IDs, or resource names
- [ ] `terraform plan` succeeds on clean subscription (walkthrough)

**Shell Scripts:**
- [ ] `bash -n` syntax check passes on every `.sh` file
- [ ] All scripts have correct shebang
- [ ] All referenced paths/binaries/commands exist or are installed in the script
- [ ] No assumed pre-existing state — scripts create what they need
- [ ] No hardcoded IPs, passwords, tokens, or secrets

**Docker & Compose:**
- [ ] Dockerfile has valid syntax, correct base image, valid COPY/RUN
- [ ] `docker compose config` validates all compose files
- [ ] All images/services referenced are built or available
- [ ] Volume mounts and env vars are valid and documented

**GitHub Actions Workflows:**
- [ ] Valid YAML syntax on all workflow files
- [ ] All referenced actions use pinned versions
- [ ] All `${{ secrets.X }}` documented in `pipeline-secrets.md`
- [ ] All file paths in workflow steps exist in repo

**Nginx:**
- [ ] Config syntax valid (`nginx -t` would pass)
- [ ] Upstream names match Docker Compose service names
- [ ] SSL cert paths match `setup-ssl.sh` output

**Makefile:**
- [ ] All targets reference valid commands and file paths

**Cross-File Consistency:**
- [ ] Every file path referenced anywhere exists in the repo
- [ ] Every env var referenced anywhere is documented
- [ ] Every secret referenced anywhere is in `pipeline-secrets.md`
- [ ] Service names consistent across Terraform, Compose, Nginx, workflows
- [ ] Port numbers consistent across Dockerfile, Compose, Nginx, health checks

#### 6b: AIRE_DEVOPS.md Rule Checks

- [ ] **W1**: ci.yml has `workflow_call` in `on:` block
- [ ] **W2**: Every file path in workflows exists in repo
- [ ] **W3**: Every tool installed in CI is run, every tool run is installed
- [ ] **W4**: Deploy workflows cover all environments
- [ ] **D1**: Only ONE reverse proxy (host OR container)
- [ ] **D2**: App port uses `expose` not `ports`
- [ ] **D3**: Resource limits use container-level config
- [ ] **D4**: All referenced compose files exist
- [ ] **D5**: `.dockerignore` exists
- [ ] **N1/N2**: Nginx rate limit directives in correct context
- [ ] **R1/R2**: Rollback actually restores previous image
- [ ] **B1-B3**: Bootstrap config exists with local backend, names from discovery report, is idempotent
- [ ] **SS1-SS4**: Terraform fully self-sufficient — creates ALL resources, no `data` lookups for self-managed resources
- [ ] **SS5**: Every per-module config from discovery report is implemented in Terraform (cross-reference Phase 1.5 checklist):
  - [ ] Auth modes match: SQL auth / Entra ID / RBAC configured as discovery specified — not defaulted differently
  - [ ] SKUs and tiers match: Serverless/Provisioned/DTU, plan SKUs, storage tiers all match discovery values
  - [ ] Runtime versions match: language + version set in `application_stack` for every compute service
  - [ ] Network access rules match: `public_network_access_enabled`, network ACLs, firewall rules as specified
  - [ ] App settings keys match: every key name from discovery appears in `app_settings` with correct value source
  - [ ] Linked services all created: every Data Factory linked service from discovery has a Terraform resource
  - [ ] RBAC role assignments complete: `azurerm_role_assignment` exists for EVERY MI → resource pair from discovery
  - [ ] Lifecycle policies implemented: storage lifecycle rules, soft delete retention, backup policies match discovery
  - [ ] All Key Vault secret names created: Terraform-producible secrets have `azurerm_key_vault_secret` resources; manual secrets documented
- [ ] **ACL1**: If ANY resource has `network_acls.default_action = Deny` or firewall rules, verify `ip_rules` includes operator IPs from discovery report — empty `ip_rules` with Deny locks out Terraform and operators on subsequent runs
- [ ] **SQL1**: If `azuread_administrator` configured, verify `azuread_authentication_only` matches auth strategy — if `true`, no SQL login/password needed; if `false`, `administrator_login` + `administrator_login_password` MUST be present
- [ ] **T7**: All resource names from discovery report — no auto-generated names
- [ ] **T8**: If existing `variables.tf` was found, unclear names were clarified with user
- [ ] **T9**: Frontend and backend in SINGLE App Service module — no separate FE/BE modules
- [ ] **TAG1**: If user opted in, root module has `variable "additional_tags"` (`map(string)`, default `{}`) — users supply at `apply` time
- [ ] **TAG2**: Root module computes `local.tags = merge(local.default_tags, var.additional_tags)` and passes to all child modules as `common_tags`
- [ ] **TAG3**: Every child module accepts `common_tags` + optional `additional_tags`, merges them into `local.tags`
- [ ] **TAG4**: Every taggable resource has `tags = local.tags` — no untagged resources
- [ ] **TAG5**: User was prompted about additional tags option before Terraform generation
- [ ] **T10**: WAF module exists ONLY if user explicitly requested it
- [ ] **T11**: Core infra params defined once in root `variables.tf`, passed to all modules
- [ ] **G1-G4**: No out-of-scope resources (Storage Queues, Private Endpoint: Queue, ADF Diagnostic Settings, Logic Apps)
- [ ] **G5**: Private DNS Zones only if user explicitly requested
- [ ] **F1/F2**: Cross-reference all file paths — all exist or documented as "USER MUST CREATE"

#### 6c: Evolution Mode Checks (only when `infra-evolution-plan.md` exists)

- [ ] **EV1/EV2**: Existing file sections unrelated to the change manifest are preserved — no collateral modifications
- [ ] **EV5**: `terraform plan` shows no unexpected destroys — only changes from the evolution plan
- [ ] **EV6**: Renamed Terraform resources use `moved` blocks — no destroy+recreate
- [ ] **EV9**: Final `terraform plan` shows "No changes" or only expected differences
- [ ] **EV10**: If parallel run was recommended, both old and new pipelines exist and run correctly
- [ ] **EV11**: All existing triggers, jobs, and environment deployments still function (no regression)
- [ ] **EV12**: Updated action/image versions are pinned and documented
- [ ] Every change in the evolution plan's change manifest was either applied or explicitly skipped by user
- [ ] Every high-risk change was presented with approval gate — user responded before execution
- [ ] `docs/deployment/evolution-changelog.md` generated with full change log and validation results

---

### Phase 7: Evolve Existing Infrastructure (Evolution Mode Only)

**This phase runs ONLY when `docs/deployment/infra-evolution-plan.md` exists. It refactors, upgrades, or extends existing pipeline and IaC code based on the evolution plan generated by `devops-infra-evolve`.**

#### 7a: Read & Validate Evolution Plan

- [ ] Read `docs/deployment/infra-evolution-plan.md` — extract:
  - Change manifest (list of files to CREATE, MODIFY, DELETE with risk levels)
  - Execution order (step sequence with dependencies)
  - Current state vs target state comparison
  - Safety guardrails (pre-conditions, validation steps, rollback procedures)
  - New secrets/configuration requirements
- [ ] Read `docs/deployment/infra-current-state.md` — extract:
  - Infrastructure inventory (existing files and tools)
  - Current pipeline flow (triggers, stages, environments)
  - Environment matrix
  - Dependency graph
  - Identified gaps and risks
- [ ] **Validate plan is still current**: For each file listed in the change manifest, verify it still exists at the expected path and has not changed since the plan was generated. If discrepancies found → **STOP** and ask user to re-run `devops-infra-evolve` or confirm changes are still valid.

#### 7b: Execute Changes — Ordered by Risk Level

**Follow the execution order from the evolution plan EXACTLY. Low-risk additive changes first, high-risk modifications last.**

##### Low-Risk Changes (Additive — no existing behavior changed):

- [ ] **CREATE** new files listed in the change manifest:
  - New workflow files (e.g., `deploy-staging.yml` for new environments)
  - New Terraform modules (e.g., `modules/monitoring/` if adding observability)
  - New Terraform variable files (e.g., `environments/staging.tfvars`)
  - New security scanning configs (e.g., `sonar-project.properties`, `.semgrep.yml`)
  - New Docker Compose files for new environments
- [ ] **ADD** new variables to `terraform/variables.tf` — append only, do NOT rename or remove existing variables
- [ ] **ADD** new outputs to `terraform/outputs.tf`
- [ ] **ADD** new secret documentation to `docs/deployment/pipeline-secrets.md`

##### Medium-Risk Changes (Modifies existing behavior — easy rollback):

- [ ] **MODIFY** existing CI/CD pipeline files:
  - Add new stages/jobs (SAST, DAST, container scanning) as specified in plan
  - Add new environment deployment jobs
  - Update action versions (pin to specific SHA or version)
  - Add caching, matrix builds, or parallel jobs as specified
  - **RULE EV1**: Before modifying, read the ENTIRE existing file — understand current structure, do NOT overwrite sections unrelated to the change
  - **RULE EV2**: Preserve all existing triggers, jobs, and steps that are NOT in the change manifest — only touch what the plan says to touch
- [ ] **MODIFY** existing Terraform files:
  - Wire new modules into `main.tf` — add `module` blocks, do NOT restructure existing ones unless plan says to
  - Update provider versions if plan specifies
  - Update module references if plan specifies
  - **RULE EV3**: If plan says "refactor module X", read the current module FIRST, understand its variables/outputs/resources, then restructure while preserving all existing resource addresses (to avoid Terraform wanting to destroy+recreate)
- [ ] **MODIFY** existing Docker/Compose files:
  - Add new services as specified
  - Update base images if plan specifies
  - Add health checks if missing
  - **RULE EV4**: Do NOT change existing service names, port mappings, or volume mounts unless the plan explicitly says to — these are breaking changes
- [ ] **MODIFY** existing Nginx configs:
  - Add new upstreams for new services
  - Update SSL configuration if plan specifies
  - **Preserve existing routing rules**

##### High-Risk Changes (Requires USER APPROVAL GATE):

- [ ] **Before each high-risk change**: Present the change to the user with:
  1. What will change (diff preview or description)
  2. Why (from evolution plan)
  3. Risk (blast radius from plan)
  4. Rollback procedure (from plan)
  5. **Ask: "Proceed with this change? (yes / skip / abort)"**
  6. **Wait for reply — NEVER proceed without confirmation**
- [ ] **MODIFY** IaC backend configuration — only if plan specifies state migration:
  - Back up current state FIRST
  - Migrate state to new backend
  - Verify state integrity after migration
- [ ] **MODIFY** existing Terraform resource configurations that could trigger destroy+recreate:
  - Renaming resources → use `moved` blocks to preserve state
  - Changing resource types → use `import` blocks where possible
  - Modifying immutable attributes → document the destroy+recreate and get user approval
- [ ] **DELETE** files only if plan explicitly marks them for deletion:
  - Verify the file is truly unused (grep for references across all configs)
  - **NEVER delete without user confirmation**

#### 7c: Terraform Evolution Safety

**When modifying existing Terraform code, extra safeguards apply:**

- [ ] **RULE EV5 (State Preservation)**: Before any Terraform change, run `terraform plan` and verify:
  - No unexpected destroys (only changes/additions from the plan)
  - If `terraform plan` shows resources being destroyed that the plan did NOT intend → **STOP**, show the plan output to user, ask how to proceed
- [ ] **RULE EV6 (Moved Blocks)**: When renaming modules or resources, use `moved` blocks:
  ```hcl
  moved {
    from = module.old_name
    to   = module.new_name
  }
  ```
  This prevents Terraform from destroying the old resource and creating a new one.
- [ ] **RULE EV7 (Import Existing)**: When bringing unmanaged resources under Terraform control, use `import` blocks:
  ```hcl
  import {
    to = azurerm_resource_group.example
    id = "/subscriptions/.../resourceGroups/existing-rg"
  }
  ```
  Run `terraform plan` after import to verify no unexpected changes.
- [ ] **RULE EV8 (Incremental Apply)**: Apply Terraform changes incrementally using `-target`:
  ```bash
  # Step 1: Apply new module only
  terraform apply -target=module.monitoring
  # Step 2: Verify, then apply remaining changes
  terraform apply
  ```
  This limits blast radius if something goes wrong.
- [ ] **RULE EV9 (No Silent Drift)**: After all changes, run `terraform plan` one final time — output MUST show "No changes" or only expected differences. Any unexpected drift → investigate before proceeding.

#### 7d: Pipeline Evolution Safety

**When modifying existing CI/CD pipelines, extra safeguards apply:**

- [ ] **RULE EV10 (Parallel Run)**: If the evolution plan recommends a parallel run period:
  - Keep existing pipeline file unchanged
  - Create the new/modified pipeline as a SEPARATE file (e.g., `ci-v2.yml`)
  - Run both in parallel until user confirms the new pipeline is stable
  - Then swap: rename new to replace old, delete the old
- [ ] **RULE EV11 (No Regression)**: After modifying any pipeline file, verify:
  - All existing triggers still work (PR, push, manual, schedule)
  - All existing jobs still run (lint, test, security, deploy)
  - All existing environment deployments still function
  - No new secrets are required that haven't been documented
- [ ] **RULE EV12 (Pinned Versions)**: When updating action/image versions:
  - Pin to specific SHA for third-party actions (e.g., `actions/checkout@<sha>`)
  - Document the version upgrade in `pipeline-secrets.md` or a changelog
  - If upgrading a major version (e.g., v3 → v4), check for breaking changes

#### 7e: Post-Evolution Validation

**After ALL changes from the evolution plan are applied, run the FULL validation suite:**

- [ ] Run Phase 6 validation (6a + 6b) on ALL files — both existing and newly modified
- [ ] **Regression check**: Verify every file that existed BEFORE evolution still functions:
  - Existing pipeline triggers still fire
  - Existing Terraform `plan` shows no unintended changes
  - Existing Docker Compose files pass `docker compose config`
  - Existing health checks still pass
- [ ] **Evolution-specific checks**:
  - [ ] Every change in the evolution plan's change manifest has been executed
  - [ ] Every "USER APPROVAL GATE" was presented and user responded
  - [ ] Every new secret is documented in `pipeline-secrets.md`
  - [ ] Cross-file consistency maintained — new changes are consistent with existing configs (ports, service names, env vars, resource names)
  - [ ] No orphaned references — files deleted in evolution are not referenced anywhere
- [ ] **Generate evolution summary**: Update or create `docs/deployment/evolution-changelog.md`:
  ```markdown
  # Infrastructure Evolution Changelog

  ## [Date] — Evolution from infra-evolution-plan.md

  ### Changes Applied
  | # | Action | File | Description | Status |
  |---|--------|------|-------------|--------|
  | 1 | MODIFY | `.github/workflows/ci.yml` | Added SAST scanning stage | ✅ Done |
  | 2 | CREATE | `.github/workflows/deploy-staging.yml` | New staging deploy pipeline | ✅ Done |
  | 3 | SKIP | `terraform/main.tf` | User skipped monitoring module | ⏭️ Skipped |
  | ... | ... | ... | ... | ... |

  ### Validation Results
  - Terraform plan: ✅ No unexpected changes
  - Pipeline syntax: ✅ All valid
  - Cross-file consistency: ✅ Verified
  - Regression: ✅ No existing behavior broken
  ```

---

### Phase 8: Jira Story Update & Status

**After ALL pipeline artifacts are generated and validated, update Jira stories and project status.**

#### Jira Story Update

- [ ] Check `docs/deployment/discovery-report.md` for a "Jira Stories" section
- [ ] Check `docs/deployment/infra-evolution-plan.md` for a "Jira Stories" section (if exists)
- [ ] If Jira stories found in either document:

```
📋 Jira Story Update

Pipeline creation is complete. The following Jira stories are linked:

| Jira ID | Title | Current Status |
|---------|-------|----------------|
| PROJ-123 | [title] | In Progress |

Would you like to update their status?
  [N] Move to next status (e.g., In Review, Ready for Deploy)
  [S] Skip — don't update Jira status (deploy workflow will handle completion)

Choose N or S:
```

- [ ] If N: Use `@atlassian-rovo` to transition each issue:
  1. `@atlassian-rovo get transitions for issue [JIRA-ID]` — get available transitions
  2. `@atlassian-rovo transition issue [JIRA-ID]` to the selected status
  3. Optionally add a comment: `@atlassian-rovo add comment to issue [JIRA-ID]` — "CI/CD pipeline created. See docs/deployment/pipeline-secrets.md for required secrets."
  4. Confirm transition to user

- [ ] If no Jira stories found: skip silently

#### GitHub Issues Update (if `**Tracking**: GitHub Projects` or GitHub Issues section found)

> **Rule for the agent: run every `gh` / `gh api` command yourself via the Bash tool. Do NOT ask the user.**

If GitHub issues found in either document:

```
📋 GitHub Issue Update

Pipeline creation is complete. The following GitHub issues are linked:

| Issue | Title | Current Status |
|-------|-------|----------------|
| #123  | [title] | In Development |

Would you like to update their status?
  [N] Move to next status (e.g., In Review, Ready for Deploy)
  [S] Skip — don't update GitHub (deploy workflow will handle completion)

Choose N or S:
```

If N, for each issue:

```bash
# Post pipeline-complete comment
gh issue comment N --repo "ORG/REPO" \
  --body "CI/CD pipeline created. See docs/deployment/pipeline-secrets.md for required secrets."

# Move Status → "In Review" using GraphQL STATUS_OPTION_ID mutation (same pattern as aire-dev-implement)
```

- [ ] If no GitHub issues found: skip silently

#### Azure DevOps Work Items Update (if `**Tracking**: Azure DevOps` or Azure DevOps Work Items section found)

> **Rule for the agent: run every `az boards` command yourself via the Bash tool. Do NOT ask the user.**

If Azure DevOps work items found in either document:

```
📋 Azure DevOps Work Item Update

Pipeline creation is complete. The following work items are linked:

| Work Item ID | Title | Current State |
|-------------|-------|---------------|
| #123 | [title] | Active |

Would you like to update their status?
  [N] Move to next state (e.g., Resolved — pipeline ready, awaiting deploy)
  [S] Skip — don't update Azure DevOps (deploy workflow will handle completion)

Choose N or S:
```

If N, for each work item:

```bash
# Post pipeline-complete comment
az boards work-item update \
  --id N \
  --discussion "CI/CD pipeline created. See docs/deployment/pipeline-secrets.md for required secrets." \
  --project "{PROJECT}"

# Move to Resolved (pipeline done, awaiting full deployment)
az boards work-item update --id N --state "Resolved" --project "{PROJECT}"
```

- [ ] If no Azure DevOps work items found: skip silently

#### Update docs/status.md

- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: Set "DevOps Pipeline" row to `✅ Done`, evidence: pipeline files created

---

## Output

**Files Created/Modified** (CI file format depends on platform from discovery):

### Greenfield Mode (no evolution plan):
- **GitHub**: `.github/workflows/ci.yml`, `.github/workflows/deploy-staging.yml`, `.github/workflows/deploy-production.yml`, `.github/workflows/terraform.yml` (if IaC)
- **GitLab**: `.gitlab-ci.yml`
- **Bitbucket**: `bitbucket-pipelines.yml`
- `Dockerfile`
- `.dockerignore`
- `docker-compose.prod.yml`
- `docker-compose.staging.yml` (if applicable)
- `nginx/app.conf` (if container Nginx)
- `Makefile`
- `sonar-project.properties` (if SonarQube/SonarCloud selected)
- `.github/dependabot.yml` (if Dependabot selected, GitHub only)
- `docs/deployment/pipeline-secrets.md`

### Evolution Mode (infra-evolution-plan.md exists):
- Files CREATED, MODIFIED, or DELETED as specified in the evolution plan's change manifest
- `docs/deployment/evolution-changelog.md` — log of all changes applied, skipped, and validation results
- `docs/deployment/pipeline-secrets.md` — updated with any new secrets required by evolution

---

## Rules

- 🔴 Discovery report MUST exist before pipeline creation
- 🔴 CI workflow MUST have `workflow_call` trigger
- 🔴 Every file referenced MUST exist or be flagged
- 🔴 Rollback MUST actually restore previous version
- 🔴 ONE reverse proxy only — never host AND container
- 🔴 App port NOT exposed to host when behind proxy
- 🔴 Every tool installed in CI MUST be run
- 🔴 ALL resource names derived from discovery report — never auto-generate or hardcode
- 🔴 Per-module configuration details from discovery report MUST be extracted (Phase 1.5) before Terraform generation — auth modes, SKUs, runtimes, network rules, app settings, linked services, RBAC roles, lifecycle policies
- 🔴 Every config detail in discovery report MUST appear in generated Terraform — missing a documented config is a validation failure (RULE SS5)
- 🔴 RBAC role assignments MUST be created for EVERY managed identity → resource access pair documented in discovery — do NOT skip any
- 🔴 App setting key names MUST match discovery report EXACTLY — do NOT substitute different key names
- 🔴 Bootstrap script MUST create ALL tfstate backend prerequisites (resource group, storage account, container) BEFORE `terraform init`
- 🔴 Bootstrap uses local backend only — no circular dependency on remote state
- 🔴 Terraform MUST be fully self-sufficient — create EVERY resource it depends on (resource groups, networking, Key Vault, ACR, Log Analytics, identities, etc.)
- 🔴 NEVER use `data` sources to look up resources that Terraform itself should manage
- 🔴 NEVER assume ANY resource pre-exists except the Azure subscription and bootstrapped backend
- 🔴 `terraform plan` on a clean subscription MUST succeed with zero errors
- 🔴 Module dependency order MUST be explicit via `depends_on` or output chaining
- 🔴 `terraform validate` MUST pass before presenting deliverables
- 🔴 SQL Server `azuread_authentication_only` MUST match auth strategy — default to `true` (AD-only); if `false`, `administrator_login` + password are REQUIRED
- 🔴 When ANY resource has `network_acls default_action = Deny`, `ip_rules` MUST include operator IPs (developer laptops, CI/CD runners) — empty `ip_rules` with Deny locks out Terraform and operators (RULE ACL1)
- 🔴 Frontend + backend in ONE App Service module — never separate
- 🔴 WAF only if user requested — never add by default
- 🔴 Service `depends_on` based on interdependency graph from discovery
- 🔴 Core infra params from root `variables.tf` — consistent across all modules
- 🚫 NEVER create Storage Queues, Private Endpoint: Queue, ADF Diagnostic Settings, or Logic Apps — out of scope
- 🚫 Private DNS Zones only if user explicitly requested in discovery
- 🔴 ASK user if they want `additional_tags` input variable enabled — never skip this prompt
- 🔴 Additional tags are a Terraform input variable (`map(string)`) — users provide at `apply` time via tfvars or CLI, NOT hardcoded
- 🔴 Every module MUST accept `common_tags` + optional `additional_tags` for per-module overrides
- 🔴 Tags merged via `merge(local.default_tags, var.additional_tags)` — additional tags override defaults
- 🔴 All taggable resources MUST have `tags = local.tags` — no untagged resources
- 🔴 Run post-generation validation (including out-of-scope exclusion check) before presenting deliverables
- 🔴 **EVOLUTION MODE**: If `infra-evolution-plan.md` exists, execute Phase 7 — refactor/upgrade existing code per the plan
- 🔴 **EVOLUTION MODE**: Follow the plan's execution order EXACTLY — low-risk first, high-risk last
- 🔴 **EVOLUTION MODE**: Read ENTIRE existing file before modifying — preserve all unrelated sections (RULE EV1/EV2)
- 🔴 **EVOLUTION MODE**: HIGH-RISK changes require USER APPROVAL GATE — present diff, risk, rollback, ask "yes/skip/abort", WAIT
- 🔴 **EVOLUTION MODE**: Use `moved` blocks when renaming Terraform resources — NEVER destroy+recreate (RULE EV6)
- 🔴 **EVOLUTION MODE**: Run `terraform plan` after changes — no unexpected destroys (RULE EV5/EV9)
- 🔴 **EVOLUTION MODE**: No regression — all existing triggers, jobs, environments must still work after modification (RULE EV11)
- 🔴 **EVOLUTION MODE**: Generate `evolution-changelog.md` documenting every change applied, skipped, or failed
- 🚫 **EVOLUTION MODE**: NEVER delete existing working files without explicit user confirmation
- 🚫 **EVOLUTION MODE**: NEVER change IaC backend without a state migration plan
- 🚫 **EVOLUTION MODE**: NEVER remove existing security scanning — only add or improve
- 🚫 **EVOLUTION MODE**: NEVER rename existing service names, ports, or volumes unless plan explicitly says to
- 🔴 Auto-include gitleaks and Trivy (if Docker) — no user choice needed
- 🔴 SAST/SCA/DAST tools only if selected in discovery — never add by default
- 🔴 DevSecOps tool secrets documented in `pipeline-secrets.md` with platform-specific instructions
- 🔴 CI pipeline format matches platform from discovery (GitHub/GitLab/Bitbucket)
- 🔴 No secrets in code — ever
- 🔴 READ TRACKER STORIES from discovery report and/or evolution plan — extract Jira Story IDs ("Jira Stories"), GitHub Issue numbers ("GitHub Issues"), and Azure DevOps Work Item IDs ("Azure DevOps Work Items")
- 🔴 OFFER TRACKER UPDATE — after pipeline creation, route to Jira (@atlassian-rovo), GitHub (`gh`), or Azure DevOps (`az boards`) based on `docs/status.md` Project Tracking block; offer to move items to next status
- 🔴 UPDATE STATUS.MD — update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md` after pipeline creation

---

## Completion

### Greenfield Mode

```
✅ CI/CD Pipeline Complete!

📄 Files Created:
├─ CI/CD pipeline (GitHub/GitLab/Bitbucket — per discovery)
├─ Dockerfile + .dockerignore
├─ docker-compose.prod.yml
├─ nginx/app.conf
├─ Makefile
├─ DevSecOps: gitleaks + Trivy (auto) + selected SAST/SCA/DAST tools
└─ docs/deployment/pipeline-secrets.md

📋 Tracker: [N] items updated (Jira / GitHub / Azure DevOps, or "No tracker items linked")
🔍 Validation: All checks passed

What would you like to do next?

1️⃣  aire-devops-deploy   → Full infra setup (Terraform + server + SSL + monitoring)

Type your choice
```

### Evolution Mode

```
✅ Infrastructure Evolution Complete!

📋 Source Plan: docs/deployment/infra-evolution-plan.md

📄 Changes Applied:
├─ Created: [N] new files
├─ Modified: [N] existing files
├─ Deleted: [N] files (with user approval)
├─ Skipped: [N] changes (user chose to skip)
└─ Changelog: docs/deployment/evolution-changelog.md

📋 Tracker: [N] items updated (Jira / GitHub / Azure DevOps, or "No tracker items linked")

🔍 Validation:
├─ Regression: ✅ All existing pipelines/IaC still work
├─ Terraform plan: ✅ No unexpected changes
├─ Cross-file consistency: ✅ Verified
└─ Evolution plan: ✅ All approved changes applied

What would you like to do next?

1️⃣  aire-devops-deploy      

Type your choice
```

---

**Type "proceed" to start building the CI/CD pipeline (greenfield) or evolving existing infrastructure (if evolution plan exists).**