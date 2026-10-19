---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-05-08"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Data Engineering & Data Architecture - Design and build production-grade data platforms (architecture, modeling, ingestion, transformation, quality, governance, DataOps). Supports both greenfield (new platforms) and brownfield (legacy DW/lake migration via Strangler Fig + dual-write + shadow read).
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

## Agent

**AIRE_DATA_ENGINEER**

## Before Starting

1. Read `SPEC/agents/AIRE_DATA_ENGINEER.md`
2. Read `SPEC/rulebooks/aire-data-engineering-rulebook.md`
3. Read `SPEC/rulebooks/aire-clean-architecture.md` (layering principles apply to data products)
4. Read `SPEC/rulebooks/aire-design-patterns.md` (Strangler Fig, ACL, Event Sourcing, CQRS)
5. Read `SPEC/rulebooks/aire-implementation-rulebook.md` (code/SQL standards, OWASP for data APIs)
6. Read `SPEC/rulebooks/aire-qa-rulebook.md` (test rigor, coverage, data quality acceptance)
7. Read `SPEC/rulebooks/aire-devops-rulebook.md` (orchestrator CI/CD, observability, 12-Factor)
8. Read `docs/architecture/` (application architecture context)
9. Read `docs/requirements.md` (if exists — extract data-relevant requirements)
10. Read `docs/data/current-state.md` (if exists — triggers Brownfield Mode)

---

## Prerequisites Check

- [ ] User has stated the data initiative goal (new platform / new pipeline / migration / new dataset)
- [ ] Regulatory scope is known or asked (GDPR / HIPAA / PCI / SOX / FERPA / sovereign data)
- [ ] At least one consumer + their SLA is identified

If any unmet → **STOP** and ask the user before proceeding.

---

## Phase 0 — Mode Detection & Anti-Loop

- [ ] Check whether `docs/data/current-state.md` exists
  - **If YES** → enter **Brownfield Mode** (Phases 1-9 + 10 migration)
  - **If NO** → enter **Greenfield Mode** (Phases 1-9; Phase 10 skipped)
- [ ] If `docs/data/architecture-decision-record.md` already exists for this initiative AND no rulebook / requirement has changed → ask user whether to re-run or stop
- [ ] If user says "stop" → exit cleanly; if "re-run" → continue with full audit

---

## Phase 1 — Discovery

**Goal**: Capture every input needed to design the right platform / pipeline / dataset. NO DDL written before this phase ends.

### 1a: Auto-detect existing assets

- [ ] Scan repo for existing data artifacts:
  - `dbt_project.yml`, `models/`, `macros/`, `seeds/` → existing dbt project
  - `dags/`, `airflow.cfg`, `dagster_*.yaml`, `prefect_*.py`, `pipelines/` → existing orchestration
  - `*.sql`, `migrations/`, `flyway/`, `liquibase/` → existing schema migrations
  - `streams/`, `kafka/`, `kinesis/`, `pubsub/`, `*.avsc`, `*.proto` → existing streaming
  - `schemas/`, `data_contracts/`, `contracts/` → existing contract files
  - `notebooks/`, `*.ipynb` → ad-hoc analytics (red flag if production-relied-upon)
- [ ] Detect cloud / vendor footprint from existing IaC (`terraform/`, `bicep/`, `cloudformation/`):
  - Warehouses: Snowflake / BigQuery / Redshift / Synapse / Databricks SQL / Fabric
  - Lakes: S3 / ADLS / GCS / OneLake
  - Streaming: Kafka / MSK / Confluent / Kinesis / Pub/Sub / Event Hubs
  - Orchestration: Airflow / MWAA / Composer / ADF / Step Functions / Databricks Jobs / Dagster Cloud / Prefect Cloud
  - Catalog: DataHub / Atlan / Collibra / Purview / Unity Catalog / Glue Data Catalog
  - Quality: dbt tests / Great Expectations / Soda / Monte Carlo / Datafold

### 1b: Discovery questions (only ask what cannot be detected)

Ask in this order. Stop at the first BLOCK if the user cannot answer.

| Q | Topic | Asked Of User |
|---|-------|---------------|
| Q1 | **Initiative type** | New platform / new pipeline / new dataset / migration of existing platform |
| Q2 | **Regulatory scope** | GDPR / HIPAA / PCI-DSS / SOX / FERPA / sovereign data / none — list ALL that apply |
| Q3 | **Data domains** | Which business domains will this serve? (orders, customers, payments, …) |
| Q4 | **Sources** | What systems publish data? (OLTP DBs, SaaS APIs, event streams, files, IoT) |
| Q5 | **Consumers** | Who reads this? (BI tools, ML features, downstream services, partners, regulators) |
| Q6 | **Latency SLA** | Per consumer: real-time (<1s) / near-real-time (<1m) / micro-batch (<15m) / hourly / daily / weekly |
| Q7 | **Volume / scale** | Rows/day, GB/day, peak QPS at the consumer |
| Q8 | **Retention** | Per regulatory class — 7y SOX, 6y HIPAA, etc. — and per business need |
| Q9 | **PII / sensitive columns** | What categories exist? (email, SSN, PAN, MRN, location, biometric) |
| Q10 | **Existing tooling** | Confirm detected stack OR specify preferred stack |
| Q11 | **Cost ceiling** | Monthly budget envelope (storage + compute) |
| Q12 | **Data residency** | Region pinning required? (EU-only, US-only, etc.) |
| Q13 | **Cutover tolerance (brownfield only)** | Per-dataset cutover or domain-by-domain — never bulk |
| Q14 | **On-call ownership** | Who owns operational data quality alerts after launch |

### 1c: Write `docs/data/discovery-report.md`

Output a structured report covering:
- Initiative type, regulatory scope
- Inventory of existing assets (auto-detected + user-confirmed)
- Sources, consumers, SLAs, volumes
- PII / sensitive column inventory (initial — refined in Phase 4)
- Tooling stack (warehouse, lake, orchestrator, transformation, catalog, quality)
- Cost envelope, residency, retention class
- Open questions (BLOCK list — must be resolved before Phase 2)

**STOP** here, present the discovery report, get user approval before Phase 2.

---

## Phase 2 — Architecture Decisions (ADR)

**Goal**: Record every architectural choice with alternatives + rationale. No DDL until ADR is approved.

### 2a: Architecture style

- [ ] Choose architecture style from rulebook ARCH1–ARCH6:
  - **Medallion (Bronze/Silver/Gold)** — DEFAULT for analytical platforms
  - **Lambda Architecture** — only when speed/batch must diverge
  - **Kappa Architecture** — stream-first with replayable log
  - **Data Mesh** — only when ≥3 domains + ≥3 producing teams + federated governance feasible
  - **Data Vault 2.0** — auditable EDW + source-system change tolerance
  - **Kimball Star Schema** — BI-first, predictable queries
  - **Inmon 3NF** — enterprise hub-and-spoke
  - **Lakehouse** — unified analytics + ML on open formats
  - **Event Sourcing + CQRS** — audit-critical, temporal queries
- [ ] Document **alternatives considered** and **rejection rationale**
- [ ] **RULE ARCH1**: choice MUST have alternatives + rationale documented

### 2b: Storage decisions

- [ ] Versioned table format selected: Delta / Iceberg / Hudi (RULE L4 — mandatory)
- [ ] File format: Parquet / ORC for analytical tiers (RULE STR1)
- [ ] Storage tiers: hot / warm / cold / archive — mapped to Bronze/Silver/Gold + retention
- [ ] Region / residency confirmed against Q12

### 2c: Processing decisions

- [ ] Batch vs streaming chosen per pipeline based on Q6 SLAs
- [ ] If streaming: schema registry chosen (RULE ST4); replayability strategy declared
- [ ] If CDC: log-based vs trigger-based decision recorded
- [ ] Orchestrator chosen ONCE for the platform (RULE ORK1)
- [ ] Transformation engine chosen: dbt (default for ELT) / Spark (heavy compute) / native warehouse SQL / streaming engine

### 2d: Modeling decisions

- [ ] Modeling style per layer:
  - Bronze: source-preserving (1:1 with sources)
  - Silver: conformed dimensions + facts (3NF or pre-dimensional)
  - Gold: dimensional (Star) or Vault — chosen with rationale (RULE MOD1)
- [ ] SCD policy declared per dimension (RULE MOD3 — SCD2 default)
- [ ] Surrogate key strategy (RULE MOD2)
- [ ] Naming convention captured (RULE MOD5)

### 2e: Privacy & security decisions

- [ ] Classification scheme declared (`public` / `internal` / `confidential` / `restricted`)
- [ ] Encryption: at rest (storage default) + in transit (TLS 1.2+) (RULE PRV3)
- [ ] Column-level encryption / tokenization for high-sensitivity (RULE PRV4) — list columns
- [ ] RLS / CLS requirements mapped per dataset (RULE PRV5/PRV6)
- [ ] Right-to-be-forgotten approach (RULE PRV7) — Bronze-through-Gold + backups
- [ ] Synthetic / masked data plan for non-prod (RULE PRV11)

### 2f: Cost / FinOps decisions

- [ ] Cost-tagging strategy per data product (RULE FIN1)
- [ ] Auto-suspend / scale-to-zero policies (RULE FIN3 / FIN7)
- [ ] Spot / preemptible usage for retryable batch (RULE FIN4)
- [ ] Materialized aggregates plan (RULE FIN5) — which top-cost queries justify materialization

### 2g: Write `docs/data/architecture-decision-record.md` (ADR)

ADR per decision: Context → Decision → Alternatives → Consequences → Status.

**STOP** here, present the ADR, get user approval before Phase 3.

---

## Phase 3 — Logical & Physical Data Model

### 3a: Conceptual & logical model

- [ ] Entity-relationship diagram for each domain (saved to `docs/data/diagrams/<domain>-erd.md` — Mermaid or PlantUML)
- [ ] Logical attributes + types + constraints per entity (RULE MOD1)
- [ ] Cardinalities + identifying vs non-identifying relationships
- [ ] Glossary of terms used in the model (feeds catalog business glossary, RULE GOV3)

### 3b: Physical model

- [ ] DDL drafts per layer:
  - Bronze: `bronze/<source>/<entity>.sql` — append-only, schema-preserving
  - Silver: `silver/<domain>/<entity>.sql` — typed, masked, conformed
  - Gold: `gold/<consumer>/<mart>.sql` — dimensional / aggregate
- [ ] Partition key per fact table (RULE STR2)
- [ ] Clustering / Z-order columns (RULE STR4)
- [ ] Time columns in UTC, timezone-aware (RULE MOD8)
- [ ] No reserved words / vendor keywords (RULE MOD7)

### 3c: Semantic layer (if 2+ BI tools or 2+ teams consume)

- [ ] Semantic layer chosen (LookML / dbt metrics / Cube / DAX / Power BI semantic model)
- [ ] Single metric definitions documented (RULE MOD6) — single source of metric truth

---

## Phase 4 — Data Contracts

**Goal**: Every published dataset has a complete contract before pipeline code is written.

- [ ] For each Silver + Gold dataset, write `data_contracts/<domain>/<dataset>.yml`:
  - name, version (SemVer 1.0.0 for first publish)
  - owner: team + steward
  - description, classification, contains_pii, pii_columns
  - sla: freshness, completeness_pct, uniqueness_pct
  - schema: columns + types + required + constraints + descriptions
  - quality_checks: not_null, unique, relationship, accepted_values, custom
  - compatibility: backward (default per RULE SE1) / forward / full
  - retention: hot / warm / archive durations
  - lineage.sources: upstream dataset references
- [ ] Each contract reviewed by named consumers (RULE DC5)
- [ ] PII / sensitive columns refined against Q9 list — every column classified (RULE PRV1)
- [ ] Contract files committed to version control with PR review

---

## Phase 5 — Pipeline / Transformation Implementation Plan

**Goal**: Detailed implementation stories that DEV / DATA_ENGINEER can execute without ambiguity. NO code written here — only the plan.

### 5a: Ingestion plan per source

For each source:
- [ ] Pattern chosen (full-load / incremental / CDC log / CDC trigger / streaming / outbox / API pull)
- [ ] Idempotency strategy (RULE ING1) — dedup key, MERGE vs UPSERT
- [ ] Late / out-of-order handling (RULE ING2) — watermark or windowed merge
- [ ] Schema-change handling (RULE ING3) — fail-fast vs auto-evolve per declared policy
- [ ] DLQ destination (RULE ING4 — streaming only)
- [ ] Backfill story (RULE ING5) — same code, parameterized date range
- [ ] Secrets sourcing (RULE ING6) — secrets manager reference

### 5b: Transformation plan per dataset

For each Silver / Gold dataset:
- [ ] dbt model file path: `dbt/models/staging|intermediate|marts/...sql` (RULE T3)
- [ ] Inter-model deps via `{{ ref(...) }}` only (RULE T4)
- [ ] Source declared in `sources.yml` with freshness check (RULE T5)
- [ ] Materialization: `view` / `table` / `incremental` — incremental uses `unique_key` + merge strategy (RULE T6)
- [ ] Tests in `schema.yml`: not_null, unique, relationships, accepted_values (RULE T7)
- [ ] Macros documented if used (RULE T8)
- [ ] Stored procs / UDFs justified if chosen over dbt (RULE T9 / T10)

### 5c: Streaming plan (if applicable)

- [ ] Topic naming + schema registration (RULE ST4 / ST5)
- [ ] Checkpoint strategy (RULE ST1) — never "start from now" in prod
- [ ] Watermarks for joins / windows (RULE ST2)
- [ ] Exactly-once vs at-least-once (RULE ST3) — choice justified per SLA
- [ ] Lag monitoring + alert thresholds (RULE ST6)
- [ ] Replay strategy tested (RULE ST7)

### 5d: Write `docs/data/implementation-plan.md`

Story-driven, each story self-contained, each with: scope IN/OUT, acceptance criteria, test requirements, owner.

---

## Phase 6 — Data Quality & Test Plan

Aligned with **DAMA DMBOK six dimensions** + `aire-qa-rulebook.md`.

### 6a: Quality test design

For each dataset, design tests covering:

| Dimension | Test |
|-----------|------|
| Accuracy | Reconciliation vs source / golden record (per ingest run) |
| Completeness | not_null on declared NOT NULL; row-count tolerance vs source |
| Consistency | Cross-system checks (e.g., orders.customer_id ↔ customers.customer_id) |
| Timeliness | Freshness SLA per `sources.yml` |
| Uniqueness | unique on PK + business keys |
| Validity | accepted_values, regex, range checks |

- [ ] Test severity classification: blocker / warning (RULE DQ3)
- [ ] Test results emitted as observability events (RULE DQ4)
- [ ] Reconciliation report scheduled per ingest (RULE DQ5)
- [ ] Anomaly detection optional but recommended for high-impact datasets (RULE DQ7)

### 6b: Pipeline-code test plan (inherits from QA rulebook)

- [ ] Unit tests for transformations (Python / Scala / SQL) — coverage line ≥85%, branch ≥80%, new-code 100%
- [ ] Integration tests against an isolated dev/staging dataset (RULE CIDC2)
- [ ] Idempotency verification — replay test on the same input window
- [ ] Backfill test — parameterized historical window

### 6c: Write `docs/testing/data-test-plan-[YYYY-MM-DD].md`

Per QA rulebook handoff format.

---

## Phase 7 — DataOps Setup (Orchestration, CI/CD, Observability)

### 7a: Orchestration

- [ ] DAGs / workflows in version control (RULE ORK2)
- [ ] Idempotent + retryable tasks with exponential backoff (RULE ORK3)
- [ ] SLA / max runtime per DAG with alerts (RULE ORK4)
- [ ] Inter-DAG deps via sensors / data-aware scheduling (RULE ORK5)
- [ ] Secrets via secrets manager (RULE ORK6)

### 7b: CI/CD for data pipelines

- [ ] PR pipeline: lint, type-check, dbt parse, dbt compile, unit tests, schema-registry compatibility (RULE CIDC1)
- [ ] Integration tests against isolated dev dataset (RULE CIDC2)
- [ ] Auto-deploy to staging on merge; reconciliation vs prod within tolerance (RULE CIDC3)
- [ ] Production deploy gated on staging-pass + reviewer approval (RULE CIDC4)
- [ ] Rollback path: previous DAG + previous dbt manifest + table time-travel (RULE CIDC5)
- [ ] Data product Git SHA tagged on every published dataset (RULE CIDC6)

> Cross-reference: invoke `aire-devops-pipeline` to wire CI/CD if not already in place. Hand off to DEVOPS for IaC / runtime infra changes.

### 7c: Data observability — five pillars (RULE OBS1)

- [ ] Freshness monitor per dataset (vs SLA in contract)
- [ ] Volume monitor (row count, GB) with anomaly bands (RULE OBS2)
- [ ] Schema drift monitor (registry-driven for streams; comparison-driven for batch)
- [ ] Quality test results emitted (pass/fail/% per dimension)
- [ ] Lineage events via OpenLineage (RULE OBS4)
- [ ] Pipeline metrics (duration, rows in/out, retries) to OTel (RULE OBS3)
- [ ] On-call runbook per data product (RULE OBS5) — references contract, lineage, dashboards
- [ ] Cost dashboard per data product with month-over-month alerts (RULE OBS6)

### 7d: Catalog integration

- [ ] Catalog connector chosen (DataHub / Atlan / Collibra / Purview / Unity / Glue) (RULE GOV1)
- [ ] Auto-publish on deploy: owner, steward, classification, contract link, lineage, sample query, freshness, quality status (RULE GOV2)
- [ ] Business glossary populated (RULE GOV3)
- [ ] Lineage emission verified (RULE GOV5)

---

## Phase 8 — Privacy, Security & Compliance Validation

- [ ] Every column tagged with classification (RULE PRV1) — verify 100% coverage
- [ ] PII / PHI / PCI columns masked / tokenized / encrypted per regulatory scope (RULE PRV2 / PRV4)
- [ ] RLS / CLS implemented where required (RULE PRV5 / PRV6)
- [ ] Right-to-be-forgotten workflow tested through Bronze / Silver / Gold + backups (RULE PRV7)
- [ ] Data residency enforced (RULE PRV8)
- [ ] Access reviewed (RULE PRV9) — least-privilege via RBAC/ABAC
- [ ] Audit log retention configured per regulation (RULE PRV10)
- [ ] Synthetic / masked data plan for non-prod (RULE PRV11)
- [ ] DPIA completed for personal data processing (RULE PRV12)

---

## Phase 9 — Greenfield Validation (Mode-Specific)

**Run only when in Greenfield Mode.**

- [ ] First dataset ships with: contract, tests, lineage, classification, catalog entry (RULE GFD1)
- [ ] Architecture style ADR exists BEFORE first DDL (RULE GFD2)
- [ ] Schema-first review completed (RULE GFD3)
- [ ] Catalog tooling integrated BEFORE second dataset lands (RULE GFD4)
- [ ] Versioned table format active from day one (RULE GFD5)
- [ ] PII classification applied to first column (RULE GFD6)

---

## Phase 10 — Brownfield Migration Execution (Mode-Specific)

**Run only when in Brownfield Mode (`docs/data/current-state.md` exists).**

### 10a: Validate current state

- [ ] Inventory in `docs/data/current-state.md` is current (re-verify against repo + cloud)
- [ ] Characterization snapshots captured for legacy pipeline outputs (RULE BFD3)
- [ ] Implicit contracts extracted to `data_contracts/legacy/...` as explicit baselines (no behavior change)

### 10b: Build new platform alongside legacy

- [ ] New datasets follow Greenfield bar (RULE BFD2)
- [ ] Dual-write or shadow-read configured per migrated dataset
- [ ] Reconciliation report scheduled: row count + key checksum + sum-of-amounts (RULE DQ5 + BFD4)

### 10c: Per-dataset cutover

For each dataset to migrate:

- [ ] Reconciliation green for ≥1 full SLA cycle BEFORE cutover (RULE BFD4)
- [ ] Consumer cutover one-by-one (never bulk) (RULE BFD7 timebox respected)
- [ ] Legacy stays writeable until ALL consumers cut over + reconciliation green
- [ ] Mark legacy dataset deprecated in catalog; retire after grace period
- [ ] **USER APPROVAL GATE**: present cutover plan (impact, blast radius, rollback path) — wait for explicit `yes / skip / abort`

### 10d: Migration safety rules

- [ ] No flag-day cutover (RULE BFD1 / 🚫 NO BIG-BANG)
- [ ] No legacy rewrite from scratch (RULE BFD1)
- [ ] Legacy infra FROZEN — only critical fixes (RULE BFD6)
- [ ] Migration timebox documented per dataset (RULE BFD7) — drift triggers escalation

### 10e: Write `docs/data/migration-changelog.md`

Per dataset: action (CREATE / DUAL-WRITE / SHADOW-READ / CUTOVER / DEPRECATE / RETIRE), date, reconciliation status, approver.

---

## Phase 11 — Post-Build Validation (Mandatory Before Hand-off)

### 11a: Rulebook gate checks

Validate against `aire-data-engineering-rulebook.md` Quality Gates table:

- [ ] Schema tests: 100% pass
- [ ] Freshness SLA: 100% on monitored datasets
- [ ] Completeness: ≥99.9%
- [ ] Uniqueness: 100% on PKs
- [ ] Referential integrity: 0 orphans
- [ ] Idempotency: replay test green
- [ ] Lineage coverage: 100% published datasets
- [ ] PII classification: 100% columns
- [ ] Catalog registration: 100% published datasets
- [ ] Access policy: enforced (verified)
- [ ] Schema compatibility: 100% PRs pass registry check
- [ ] Cost budget: under approved
- [ ] Backup / DR: tested per regulatory class
- [ ] Reconciliation (brownfield): green ≥1 SLA cycle

### 11b: Cross-rulebook gate checks

- [ ] File / function size per `aire-implementation-rulebook.md`
- [ ] Coverage thresholds per `aire-qa-rulebook.md` (line ≥85%, branch ≥80%, new-code 100%)
- [ ] No PR-ready TODOs (Blocker per implementation rulebook)
- [ ] OWASP Top 10 mapping for any data API (per implementation rulebook)
- [ ] OTel emission per `aire-devops-rulebook.md`
- [ ] 12-Factor for pipeline services per devops rulebook

### 11c: Forbidden actions audit

- [ ] No production DML (verified)
- [ ] No PII in logs (verified by sample inspection)
- [ ] No hardcoded credentials (secrets scanner clean)
- [ ] No uncataloged published datasets
- [ ] No schema-on-read for regulated data
- [ ] No silent transformation (every step lineage-emitted)

### 11d: Document validation outcomes

Write `docs/data/validation-report-[YYYY-MM-DD].md` with results table.

---

## Phase 12 — Handoff & Status Update

### 12a: Handoff package

For each downstream agent:

| Hand off to | When | Deliverable |
|-------------|------|-------------|
| **DEVOPS** | CI/CD or IaC changes needed | Reference to `docs/data/architecture-decision-record.md` + list of pipeline files |
| **DEV** | Producer instrumentation needed (e.g., outbox pattern in source service) | Story IDs + acceptance criteria |
| **QA** | Business-level acceptance testing required | `docs/testing/data-test-plan-*.md` |
| **REVIEWER** | PR-ready code | Branch + ADR + contract files + test results |
| **ARCHITECT** | App architecture must integrate with new data products | ADR + contract registry link |

### 12b: Update tracking

- [ ] Update `docs/status.md` per `SPEC/templates/STATUS_FORMAT.md`: set "Data Platform" / "Data Migration" / "Data Pipeline" row to `✅ Done` with evidence
- [ ] If Jira stories linked in discovery report → offer status transition via `@atlassian-rovo` (same pattern as `aire-devops-pipeline` Phase 8)

---

## Output

### Greenfield Mode

**Files Created**:
- `docs/data/discovery-report.md`
- `docs/data/architecture-decision-record.md`
- `docs/data/diagrams/<domain>-erd.md` (one per domain)
- `docs/data/implementation-plan.md`
- `data_contracts/<domain>/<dataset>.yml` (one per published dataset)
- `dbt/models/staging|intermediate|marts/...sql` (or chosen transformation engine equivalents)
- `dbt/models/sources.yml`, `dbt/models/schema.yml`
- `dags/` or `pipelines/` (orchestration code, if owned by this agent)
- `docs/testing/data-test-plan-[YYYY-MM-DD].md`
- `docs/data/validation-report-[YYYY-MM-DD].md`
- `docs/data/runbook-<data-product>.md` (one per data product)

### Brownfield Mode

**All of Greenfield Mode PLUS**:
- `docs/data/current-state.md` (read; updated if discoveries refine it)
- `docs/data/migration-plan.md` (per-dataset cutover plan with rollback)
- `docs/data/migration-changelog.md`
- Reconciliation report jobs (in `dags/` or chosen orchestrator)
- Characterization snapshots checked into `tests/data/characterization/`

---

## Rules

- 🔴 Discovery report MUST exist and be approved before any DDL is written
- 🔴 ADR MUST document architecture style with alternatives + rationale (RULE ARCH1)
- 🔴 Every published dataset MUST have a contract before pipeline code (RULE DC1 / DC2)
- 🔴 Bronze MUST be append-only and schema-preserving (RULE L1)
- 🔴 Silver MUST classify PII and conform types (RULE L2)
- 🔴 Storage layer MUST be a versioned table format (Delta / Iceberg / Hudi) (RULE L4)
- 🔴 Production writes MUST be idempotent (MERGE / upsert / dedupe) (RULE ING1)
- 🔴 Schema changes MUST pass schema-registry compatibility in CI (RULE SE2)
- 🔴 Every column MUST be classified at ingest (RULE PRV1)
- 🔴 PII / PHI / PCI MUST be masked / tokenized / encrypted per regulatory scope (RULE PRV2 / PRV4)
- 🔴 Right-to-be-forgotten workflow MUST be tested (RULE PRV7)
- 🔴 Every published dataset MUST be cataloged with owner + lineage (RULE GOV1 / GOV2 / GOV5)
- 🔴 Lineage MUST be emitted from every transformation job (RULE OBS4 / GOV5)
- 🔴 Quality tests MUST cover all DAMA dimensions where applicable (RULE DQ1)
- 🔴 Test failures BLOCK pipeline propagation (RULE DQ2)
- 🔴 Brownfield: Strangler Fig + dual-write + shadow read — NO flag-day cutover (RULE BFD1 / 🚫 NO BIG-BANG)
- 🔴 Brownfield: reconciliation green for ≥1 full SLA cycle BEFORE consumer cutover (RULE BFD4)
- 🔴 Brownfield: legacy stays writeable until ALL consumers cut over (RULE BFD5)
- 🔴 Greenfield: first dataset ships with full bar — contract + tests + lineage + classification + catalog (RULE GFD1)
- 🔴 Greenfield: schema-first / catalog-first / versioned-storage from day one (RULE GFD3 / GFD4 / GFD5)
- 🔴 USER APPROVAL GATE before each per-dataset cutover (Phase 10c)
- 🔴 USER APPROVAL GATE before ADR is committed (Phase 2g)
- 🔴 USER APPROVAL GATE before discovery report is committed (Phase 1c)
- 🔴 No production DML — every change is a tracked, reversible migration
- 🔴 No PII in logs / non-prod environments unless masked / synthetic (RULE PRV11)
- 🔴 No hardcoded credentials (RULE ING6 / ORK6)
- 🔴 No schema-on-read for regulated data (🚫 NO SCHEMA-ON-READ FOR CRITICAL DATA)
- 🔴 No uncataloged published datasets (🚫 NO UNCATALOGED DATASETS)
- 🔴 No silent transformations — every step lineage-emitted
- 🔴 Cross-domain sharing goes through contracts, not direct grants (RULE GOV6 / 🚫 NO SHARED MUTABLE STATE)
- 🚫 NEVER rewrite legacy from scratch (RULE BFD1)
- 🚫 NEVER decommission legacy before consumers cut over (RULE BFD5)
- 🚫 NEVER edit production data via ad-hoc DML (Forbidden Actions)
- 🚫 NEVER copy production data to non-prod without masking + DPO approval (RULE PRV11)
- 🔴 UPDATE STATUS.MD — `docs/status.md` row updated after build
- 🔴 OFFER JIRA UPDATE if stories linked in discovery report

---

## Completion

### Greenfield Mode

```
✅ Data Platform / Pipeline Build Complete!

📄 Architecture & Plan:
├─ docs/data/discovery-report.md
├─ docs/data/architecture-decision-record.md
├─ docs/data/diagrams/*.md
└─ docs/data/implementation-plan.md

📑 Contracts:
└─ data_contracts/<domain>/*.yml ([N] published datasets)

🛠 Transformations:
└─ dbt/ (or chosen engine) — staging / intermediate / marts

🧪 Quality:
├─ docs/testing/data-test-plan-[YYYY-MM-DD].md
└─ Quality gates: ✅ all green

🔍 Validation:
└─ docs/data/validation-report-[YYYY-MM-DD].md

📋 Jira: [N] stories updated (or "No Jira stories linked")

What would you like to do next?

1️⃣  aire-devops-pipeline       → Wire CI/CD + IaC for the new pipelines
2️⃣  aire-qa-test-plan          → Business-level acceptance testing
3️⃣  aire-review-code           → PR review of generated transformation code

Type your choice
```

### Brownfield Mode

```
✅ Data Platform Migration Plan Complete!

📋 Source: docs/data/current-state.md (legacy baseline)

📄 Architecture & Migration:
├─ docs/data/architecture-decision-record.md
├─ docs/data/migration-plan.md
└─ docs/data/migration-changelog.md

📑 Contracts (legacy + new):
└─ data_contracts/legacy/*.yml + data_contracts/<domain>/*.yml

🛠 New Pipelines (alongside legacy):
└─ dbt/, dags/ — dual-write + shadow-read configured

🔁 Reconciliation:
└─ Scheduled per migrated dataset

🧪 Quality:
├─ Characterization snapshots — tests/data/characterization/
└─ docs/testing/data-test-plan-[YYYY-MM-DD].md

🔍 Validation:
└─ docs/data/validation-report-[YYYY-MM-DD].md

📋 Jira: [N] stories updated (or "No Jira stories linked")

⏭ Next Cutover Gate:
   Per dataset, reconciliation green ≥1 SLA cycle, consumer cutover one-by-one
   (USER APPROVAL required at each cutover)

What would you like to do next?

1️⃣  aire-devops-pipeline       → Wire CI/CD for new pipelines
2️⃣  Continue cutover           → Resume Phase 10c per-dataset cutover
3️⃣  aire-review-code           → PR review of generated code

Type your choice
```

---

**Type "proceed" to start data platform / pipeline design (greenfield) or to plan migration (brownfield, if `docs/data/current-state.md` exists).**
