---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-05-08"
component: "3Pillar AIRE SDLC Agentic Framework"
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Data Engineering & Data Architecture Rulebook

## Purpose

Mandatory standards for designing, building, and evolving data platforms — covering architecture, modeling, ingestion, transformation, storage, orchestration, quality, governance, security, performance, cost, and DataOps. Every rule exists because violating it caused a real production data incident, a compliance finding, or a costly migration.

This rulebook applies to **both greenfield** (new data platforms) and **brownfield** (legacy DW/lake migration). Greenfield enforces the full bar from day one; brownfield migrates progressively under a documented timebox — never a flag-day cutover.

## Industry Standards Referenced (with version anchors)

| Standard | Version | Use |
|----------|---------|-----|
| DAMA DMBOK | 2 (2017) | Data quality dimensions, governance vocabulary |
| DataOps Manifesto | current | Process / observability principles |
| OpenLineage | 1.x | Lineage event emission |
| ISO/IEC 25010 | 2011 (under revision) | Quality model alignment with QA rulebook |
| Delta Lake | 3.x | Versioned table format |
| Apache Iceberg | v2 spec | Versioned table format |
| Apache Hudi | 0.14+ | Versioned table format |
| Apache Parquet | 2.x | Columnar file format |
| Apache ORC | 1.9+ | Columnar file format |
| OpenTelemetry | OTel 1.x | Observability emission (cross-ref `aire-devops-rulebook.md`) |
| 12-Factor App | current | Pipeline service hygiene (cross-ref `aire-devops-rulebook.md`) |
| GDPR | EU 2016/679 (Art. 17 RTBF, Art. 22 ADM, Art. 35 DPIA) | Privacy obligations |
| HIPAA | Privacy / Security / Breach Rules (45 CFR Parts 160 & 164) | Health data |
| PCI-DSS | v4.0 | Payment card data |
| SOX | 2002 (Section 404 ITGC) | Financial reporting controls |
| FERPA | 20 U.S.C. § 1232g | Education records |
| WCAG | 2.2 AA (cross-ref `aire-qa-rulebook.md`) | Accessibility for data UIs |

> Architectural references: Lakehouse / Medallion (Databricks), Lambda Architecture (Marz), Kappa Architecture (Kreps), Data Mesh (Dehghani 2019), Data Vault 2.0 (Linstedt), Kimball Dimensional Modeling, Inmon Corporate Information Factory, Event Sourcing + CQRS (Fowler / Young).
>
> Cross-references: `aire-implementation-rulebook.md` (code standards), `aire-qa-rulebook.md` (test rigor), `aire-devops-rulebook.md` (CI/CD, IaC, observability), `aire-clean-architecture.md` (layering), `aire-design-patterns.md` (Strangler Fig, ACL, Event Sourcing, CQRS).

---

## Strict Constraints

| Rule | Description |
|------|-------------|
| ✅ DISCOVER FIRST | Always inventory existing data assets (warehouses, lakes, queues, schemas, pipelines) before any change |
| ✅ CONTRACT-FIRST | Every published dataset has a written contract (schema, owner, SLA, quality checks) BEFORE consumers depend on it |
| ✅ MODE DETECTION | Detect greenfield vs brownfield from `docs/data/current-state.md` (if present) before generating any plan |
| ✅ IDEMPOTENT WRITES | Production writes use MERGE / upsert / dedupe — never blind APPEND |
| ✅ VERSIONED STORAGE | Bronze/Silver/Gold (or equivalent) sit on a versioned table format (Delta / Iceberg / Hudi) — time-travel mandatory |
| ✅ LINEAGE EMITTED | Every transformation job emits OpenLineage (or equivalent) — column-level where the engine supports it |
| ✅ CLASSIFY PII AT INGEST | Every column with PII/PHI/PCI is classified, masked, encrypted, and access-controlled at first hop |
| ✅ TEST THE DATA | Every published dataset has schema, not-null, uniqueness, freshness, referential integrity tests |
| ✅ CATALOG REGISTRATION | Every published dataset registered with owner, classification, SLA, contract |
| ✅ SCHEMA EVOLUTION POLICY | Each dataset declares backward/forward/full compatibility — enforced in CI via schema registry |
| ✅ COST AWARENESS | Storage tier, file format, partition layout justified against query/SLA requirements |
| ✅ REGULATORY SCOPE DOCUMENTED | GDPR / CCPA / HIPAA / PCI-DSS / SOX / FERPA scope captured before ingest |
| ✅ DOCUMENT TRADE-OFFS | Every architecture / pattern decision records alternatives considered |
| 🚫 NO PRODUCTION DML | Never run ad-hoc DML on production datasets — every change is a tracked, reversible migration |
| 🚫 NO PII IN LOGS | PII/PHI/PCI MUST NOT appear in logs, metrics, traces, or non-prod environments unless masked / synthetic |
| 🚫 NO BIG-BANG MIGRATION | Brownfield uses Strangler Fig + dual-write + shadow read — never flag-day cutover |
| 🚫 NO HARDCODED CREDENTIALS | All secrets via secrets management (Key Vault, Secrets Manager, GCP Secret Manager) |
| 🚫 NO UNCATALOGED DATASETS | Publishing without catalog registration is forbidden |
| 🚫 NO SCHEMA-ON-READ FOR CRITICAL DATA | Regulated / contracted datasets are validated at ingest |
| 🚫 NO SHARED MUTABLE STATE | Cross-domain data sharing goes through contracts, not direct table access |

---

## Architecture Rules

### Architecture Style Selection

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| ARCH1 | Architecture style (Lakehouse / Lambda / Kappa / Data Mesh / Vault / Kimball / Inmon) MUST be chosen with documented alternatives and rejection rationale | Architecture drift; teams adopt mismatched patterns |
| ARCH2 | Medallion (Bronze / Silver / Gold) is the DEFAULT for greenfield analytical platforms unless rejected with cause | Over-engineered or chaotic lakes; no clear refinement path |
| ARCH3 | Data Mesh is chosen ONLY when ≥3 distinct domains, ≥3 producing teams, and federated governance is feasible | Mesh tax with no mesh benefit |
| ARCH4 | Lambda/Kappa choice is justified by latency SLA (Kappa default if replayable log exists; Lambda only when speed/batch must diverge) | Two pipelines maintained where one would do |
| ARCH5 | Kimball star schema is preferred for BI consumers; Data Vault only when source-system change tolerance + audit traceability are mandatory | Wrong tool for the audience — confused consumers, slow queries |
| ARCH6 | Bounded contexts MUST be explicit — each domain owns its source-of-truth datasets; cross-domain reads go through contracts | Hidden coupling, mass refactors when one team changes a column |

### Layering (Lakehouse / Medallion)

| Layer | Purpose | Allowed Operations | Forbidden Operations |
|-------|---------|--------------------|----------------------|
| **Bronze (Raw)** | Immutable copy of source data, schema preserved | Append-only ingest, deduplication keys | Business logic, joins, aggregations |
| **Silver (Cleansed)** | Conformed dimensions, deduplicated facts, type-cast, PII classified | Cleansing, conforming, masking, surrogate keys | Aggregations for BI consumption |
| **Gold (Curated)** | Business-ready marts, aggregates, semantic layer outputs | Joins, aggregations, business KPIs | Raw cleansing logic (belongs in Silver) |

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| L1 | Bronze MUST be append-only and schema-preserving — no transformations | Cannot replay; source-of-truth lost |
| L2 | Silver MUST classify PII, mask where required, conform types, enforce uniqueness | Privacy / quality leaks into Gold |
| L3 | Gold MUST be derivable solely from Silver (no direct Gold-from-Bronze shortcuts) | Inconsistent metrics across consumers |
| L4 | Each layer's tables live on a versioned format (Delta/Iceberg/Hudi) — time-travel enabled | Cannot rollback; cannot reproduce historical reports |

---

## Data Modeling Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| MOD1 | Conceptual + logical model MUST exist before physical DDL | Physical decisions baked in before access patterns understood |
| MOD2 | Surrogate keys (system-generated) used in dimensional models — never expose source-system natural keys directly | Source key changes break joins everywhere |
| MOD3 | SCD Type 2 is the default for dimensions where history matters; SCD1 only with explicit stakeholder sign-off | Historical reports become inaccurate |
| MOD4 | Fact tables grain documented in the contract — never inferred | Aggregate double-counting |
| MOD5 | Naming conventions consistent across the platform (snake_case for columns; `_dim`, `_fact`, `_bridge`, `_stg` suffixes or chosen equivalent) | Inconsistent naming = onboarding friction, ambiguous joins |
| MOD6 | Semantic layer (LookML / dbt metrics / Cube / DAX models) is REQUIRED when 2+ BI tools or 2+ teams consume — single source of metric truth | Definitions diverge per tool; "what is MAU" debate |
| MOD7 | Reserved words / vendor-specific keywords avoided in column / table names | Portability lost; query rewrites on migration |
| MOD8 | Time columns store timestamps in UTC with timezone-aware type — never naive local time | Cross-region bugs, DST chaos |

---

## Ingestion Patterns

| Pattern | Use When | Avoid When |
|---------|----------|------------|
| **Batch full-load** | Small dimension tables, infrequent change | Large facts (cost / time prohibitive) |
| **Batch incremental** | Append-only facts, changed-since cursor available | No reliable change marker |
| **CDC (log-based)** | Mutable source tables, low-latency need | Source DB doesn't expose log; vendor lock-in concern |
| **CDC (trigger / timestamp)** | Mutable source, no log access | High write volume — triggers add load |
| **Event streaming** | Producer publishes events natively, sub-minute latency | No event source — building one just for ingest is overkill |
| **Outbox pattern** | Transactional consistency between OLTP write + message publish | Single-system writes |
| **API pull** | Third-party SaaS without push integration | Rate-limited APIs at scale |

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| ING1 | Every ingest path is idempotent — replays produce identical Bronze | Double-counted facts on retry |
| ING2 | Late-arriving / out-of-order data handled explicitly via watermarks (streaming) or windowed merge (batch) | Silent data loss or incorrect aggregates |
| ING3 | Source schema changes are detected at ingest (schema diff) and fail-fast OR auto-evolve per declared policy | Silent type coercion bugs |
| ING4 | Dead-Letter Queue (DLQ) MUST exist for any streaming ingest — bad records routed, NEVER silently dropped | Data loss without trace |
| ING5 | Backfill is a first-class pipeline — same code as live ingest, parameterized by date range | "One-off" backfills always recur |
| ING6 | Source connection credentials / secrets MUST come from secrets manager — never hardcoded | Credential leakage |

---

## Transformation Rules (ETL / ELT / dbt)

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| T1 | ELT preferred over ETL when target compute is sufficient (push transforms to the warehouse/lakehouse) | Wasted ETL infra; harder lineage |
| T2 | Transformation code lives in version control with PR review — never edited live in the warehouse | Untracked, irreproducible changes |
| T3 | dbt project structure follows: `staging/` (1:1 with sources), `intermediate/` (reusable joins), `marts/` (consumer-facing) | Spaghetti models; circular refs |
| T4 | Ref macros (`{{ ref('...') }}`) used exclusively for inter-model dependencies — never hard table names | Lineage broken; environments diverge |
| T5 | Sources declared in `sources.yml` with freshness checks — no inline source references | Cannot detect stale upstream |
| T6 | Incremental models use `unique_key` + `merge` strategy for SCD-aware updates — never `append` for mutable data | Duplicates, stale rows |
| T7 | Transformation tests (`schema.yml`) include: `not_null`, `unique`, `relationships`, `accepted_values` for every published model | Quality regressions ship undetected |
| T8 | Macros are documented; magic SQL forbidden | New maintainers cannot read the codebase |
| T9 | Stored procedures avoided when dbt / declarative SQL works — use procs only for what dbt cannot do | Hidden logic outside lineage |
| T10 | UDFs are tested, version-controlled, and documented — never inline opaque expressions | Performance / correctness regressions |

---

## Streaming Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| ST1 | Every streaming consumer MUST be able to recover from a checkpoint — no "start from now" defaults in production | Data loss on restart |
| ST2 | Watermarks defined for every stream-to-stream join or windowed aggregate | Late data silently dropped or skews windows |
| ST3 | Exactly-once or effectively-once semantics required for billable / regulated outputs — at-least-once with downstream dedup is acceptable elsewhere | Double-billing, compliance gaps |
| ST4 | Schema registry (Confluent / Glue / Apicurio) MUST be used — no schema-less Avro/Protobuf in production topics | Producer/consumer schema drift |
| ST5 | Topic naming convention enforced (`<domain>.<entity>.<event>.<version>` or chosen equivalent) | Topic sprawl, ambiguous ownership |
| ST6 | Backpressure / lag monitoring required — alerts when consumer lag exceeds SLA | Silent ingestion lag |
| ST7 | Replay strategy documented — earliest offset or time-bounded — and tested before production | First incident becomes the first replay attempt |

---

## Data Quality Rules

Aligned with **DAMA DMBOK** six dimensions of data quality.

| Dimension | Definition | Required Check |
|-----------|------------|----------------|
| **Accuracy** | Values reflect reality | Reconciliation vs source / golden record |
| **Completeness** | Required values are present | `not_null` on declared NOT NULL columns; row-count tolerance vs source |
| **Consistency** | Same value across systems | Cross-system reconciliation reports |
| **Timeliness** | Data is fresh enough for use | Freshness SLA per dataset, monitored continuously |
| **Uniqueness** | No unintended duplicates | `unique` test on PK + business keys |
| **Validity** | Conforms to format / range / domain | `accepted_values`, regex, range checks |

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| DQ1 | Every published dataset has tests for ALL six DAMA dimensions where applicable — gaps documented with cause | Quality issues caught only by consumers |
| DQ2 | Tests run on every pipeline execution — failure blocks downstream propagation | Bad data poisons Gold |
| DQ3 | Severity classification: blocker / warning — blockers halt the pipeline, warnings page on-call | Single severity = either too noisy or too lax |
| DQ4 | Test results emitted as observability events (metrics + lineage event) — feed dashboards | "Tests passed" with no record |
| DQ5 | Reconciliation: row count + key checksum + sum-of-amounts (where applicable) per ingest run | Silent drift between source and Bronze |
| DQ6 | Data contract violations BLOCK consumer-facing publication — never publish broken contract data with a warning | Contract = nothing if violations are tolerated |
| DQ7 | Anomaly detection (volume / cardinality / null rate) optional but recommended for high-impact datasets | Subtle quality degradation undetected |

---

## Data Contracts

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| DC1 | Every published dataset has a contract file in `data_contracts/<domain>/<dataset>.yml` (or equivalent) | No accountability |
| DC2 | Contract MUST include: schema (typed columns), primary key, owner (team + person), SLA (freshness, completeness), quality checks, classification, retention, lineage source(s) | Partial contract = no contract |
| DC3 | Contracts are versioned (SemVer); breaking changes increment MAJOR | Silent breaking changes for consumers |
| DC4 | Schema compatibility policy declared per dataset: `backward` (default), `forward`, or `full` | Surprise breaks |
| DC5 | Contract changes go through PR review by ALL listed consumers | Producer breaks consumers without warning |
| DC6 | Contract published in catalog (DataHub / Atlan / Collibra / Purview) — discoverable | Contracts hidden = useless |

### Contract Template

```yaml
# data_contracts/orders/orders_fact.yml
name: orders.orders_fact
version: 1.2.0
owner:
  team: orders-platform
  steward: jane.doe@example.com
description: Atomic order facts, one row per (order_id, version)
classification: confidential   # public | internal | confidential | restricted
contains_pii: true
pii_columns: [customer_email_hash, billing_address_id]
sla:
  freshness: 15m            # Silver land time after source write
  completeness_pct: 99.95
  uniqueness_pct: 100
schema:
  - name: order_id
    type: string
    required: true
    description: Source-system order identifier
  - name: order_total_cents
    type: bigint
    required: true
    constraints: [non_negative]
  - name: order_placed_at
    type: timestamp_tz
    required: true
quality_checks:
  - type: not_null
    columns: [order_id, order_total_cents, order_placed_at]
  - type: unique
    columns: [order_id]
  - type: relationship
    column: customer_id
    references: customers.customers_dim.customer_id
compatibility: backward
retention:
  hot: 90d
  warm: 365d
  archive: 7y                # regulatory
lineage:
  sources: [postgres.orders.orders_log]
```

---

## Schema Evolution

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| SE1 | Backward compatibility is the DEFAULT — adding optional columns OK; removing/renaming/retyping requires MAJOR version + migration window | Existing consumers break silently |
| SE2 | Schema changes go through schema registry validation in CI — incompatible changes BLOCK the PR | Bad changes ship via merge |
| SE3 | Deprecated columns marked, kept for ≥2 release cycles before removal | No grace period for consumers |
| SE4 | Renames implemented as add-new + dual-write + drop-old (3 deploys) — never rename in place | All readers break on rename |
| SE5 | Type widening (int → bigint) allowed; type narrowing requires consumer sign-off | Truncation / overflow |

---

## Storage & Performance Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| STR1 | Columnar formats (Parquet / ORC) for analytical storage — never CSV/JSON for Silver+ | 10-100x query cost |
| STR2 | Partition strategy chosen based on query patterns (date for time-series, region for geo, low-cardinality column otherwise) | Full-scan queries |
| STR3 | Partition cardinality kept reasonable (avoid >10k partitions per table without bucketing/clustering) | Metadata-bound queries crawl |
| STR4 | Z-ordering / clustering applied for high-cardinality filter columns | Cold-cache queries hammer storage |
| STR5 | Compaction scheduled (small files → optimal size) — Delta `OPTIMIZE`, Iceberg `rewrite_data_files`, Hudi `clustering` | Small-file problem destroys query perf |
| STR6 | File size target: 128 MB – 1 GB per file (engine-specific) | Either too many small files or too few large ones |
| STR7 | Storage tiers used (hot / warm / cold / archive) with lifecycle rules tied to access pattern | Storage bills balloon |
| STR8 | Query patterns reviewed quarterly — partition / clustering revisited if access patterns shift | Stale optimization for current workload |

---

## Privacy, Security & Classification

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| PRV1 | Every column tagged at ingest with a classification: `public` / `internal` / `confidential` / `restricted` | Cannot enforce policy without classification |
| PRV2 | PII / PHI / PCI columns identified explicitly and masked / tokenized / encrypted as required by regulatory scope | Compliance breach |
| PRV3 | Encryption at rest mandatory (storage-level) + encryption in transit (TLS 1.2+) | Unprotected data |
| PRV4 | Column-level encryption / tokenization for high-sensitivity fields (SSN, PAN, MRN) | Insider risk |
| PRV5 | Row-Level Security (RLS) where users may only see their tenant / region / customer | Data exposure across tenants |
| PRV6 | Column-Level Security (CLS) / dynamic masking where roles see different views of the same column | Over-privileged users |
| PRV7 | Right-to-be-forgotten (GDPR Art. 17) workflow tested — deletion propagates through Bronze / Silver / Gold + backups within regulatory window | Compliance failure |
| PRV8 | Data residency requirements mapped per dataset — pipelines and storage respect region pinning | Sovereign-data violation |
| PRV9 | Access reviewed quarterly — least-privilege enforced via RBAC/ABAC | Permission drift |
| PRV10 | Audit log of data access retained per regulation (SOX 7y, HIPAA 6y, etc.) | No forensic trail |
| PRV11 | Synthetic / masked data only in non-production — production data NEVER copied to dev/staging without DPO approval and masking | Privacy breach via dev environment |
| PRV12 | DPIA (Data Protection Impact Assessment) completed for new processing of personal data | Regulatory non-compliance |

---

## Governance & Catalog

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| GOV1 | Every published dataset registered in the catalog (DataHub / Atlan / Collibra / Purview / Glue) | Discovery impossible |
| GOV2 | Catalog entry includes: owner, steward, classification, contract link, lineage, sample query, freshness, quality status | Catalog without context = useless |
| GOV3 | Business glossary maintained — every metric and key term defined once | "What is active user" debated forever |
| GOV4 | Stewards reviewed annually — orphan datasets flagged for retirement | Zombie data products consume budget |
| GOV5 | Lineage emission via OpenLineage (or vendor equivalent) from every transformation tool | Black-box pipelines |
| GOV6 | Cross-domain data sharing goes through contracts published in the catalog — never direct table grants | Hidden coupling |
| GOV7 | Retention policy enforced per dataset — automated deletion / archival per regulatory class | Manual deletion never happens |

---

## DataOps Rules (Orchestration, CI/CD, Observability)

### Orchestration

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| ORK1 | Orchestrator (Airflow / Dagster / Prefect / ADF / Step Functions / Databricks Jobs) chosen ONCE for the platform — avoid two competing orchestrators | Duplicated DAGs, fragmented monitoring |
| ORK2 | DAGs / workflows live in version control with PR review | Untracked production schedules |
| ORK3 | Tasks idempotent and retryable with exponential backoff | Manual restarts every incident |
| ORK4 | SLA / max runtime declared per DAG — alerts on miss | Silent slowness becomes fast slowness |
| ORK5 | Inter-DAG dependencies explicit (sensors / data-aware scheduling) — never time-coincidence as a dependency | "Usually it finishes by 2am" is not a dependency |
| ORK6 | Secrets accessed via secrets manager integration — never as DAG vars in plaintext | Credential leakage |

### CI/CD for Data Pipelines

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| CIDC1 | Pull requests run: lint, type-check, unit tests on transformations, dbt parse, dbt compile, schema-registry compatibility | Bad code reaches main |
| CIDC2 | Integration tests against an isolated dev/staging dataset on every PR | First production run is the integration test |
| CIDC3 | Deployment to staging on merge — staging dataset reconciled to production within tolerance | Staging diverges and stops catching issues |
| CIDC4 | Production deploys gated on staging-pass + reviewer approval | Untested code reaches prod |
| CIDC5 | Pipeline rollback path defined: previous DAG version + previous dbt manifest + table time-travel restore | First failure becomes first rollback attempt |
| CIDC6 | Data product version (Git SHA) tagged on every published dataset for traceability | Cannot link bad data to the change that caused it |

### Data Observability (DataOps Manifesto-aligned)

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| OBS1 | Five pillars monitored per dataset: Freshness, Volume, Schema, Quality, Lineage | Silent regressions |
| OBS2 | Anomaly detection on volume + null rate + cardinality for high-impact datasets | Slow degradations missed |
| OBS3 | Pipeline metrics (run duration, rows in/out, retries) emitted to OTel-compatible backend | Cannot diagnose perf regressions |
| OBS4 | Lineage events emitted via OpenLineage on every job execution | No incident traceability |
| OBS5 | On-call runbook per data product references the contract + lineage + quality dashboards | "Who do I call" is not a strategy |
| OBS6 | Cost dashboards per data product — alerts on month-over-month deviation > threshold | Bill shock |

---

## Cost / FinOps Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| FIN1 | Cost tagged per data product — billing exportable per domain / team | No accountability |
| FIN2 | Storage tiers respected — Gold hot, Silver warm, Bronze cold-after-N-days, archive per retention class | Hot storage of cold data |
| FIN3 | Compute right-sized — autoscaling preferred over fixed clusters for spiky workloads | Over-provisioned 24/7 clusters |
| FIN4 | Spot / preemptible instances used for retryable batch workloads | Wasted budget on on-demand |
| FIN5 | Materialized aggregates used when query frequency * scan cost > materialization cost | Repeatedly scanning the same fact table |
| FIN6 | Query patterns reviewed quarterly — top-cost queries examined for partition / clustering improvement | Hot queries get hotter |
| FIN7 | Idle resources (paused warehouses, stopped clusters) automated — never manual | Forgotten clusters bill all month |

---

## Brownfield Migration Rules

When evolving a legacy DW / lake / pipeline platform, follow this progressive path. **Do NOT block delivery** while you migrate — work in parallel.

### Migration Patterns

| Pattern | When | Reference |
|---------|------|-----------|
| **Strangler Fig** | Legacy ETL / DW being replaced incrementally | Fowler |
| **Dual-Write** | Producers write to both legacy and new platform during cutover | — |
| **Shadow Read** | New platform serves a copy of consumer queries; results reconciled before cutover | — |
| **Branch by Abstraction** | Internal interface introduced so old + new implementations coexist | Hammant |
| **Anti-Corruption Layer** | New platform consumes legacy via translation layer; legacy semantics quarantined | Evans |
| **Characterization Tests** | Snapshot legacy pipeline output as the regression baseline before refactor | Feathers |
| **Backfill-Forward** | Reprocess history into the new platform incrementally, oldest-first or newest-first | — |

### Migration Phases

#### Phase 1 — Capture Current State (read-only)

| Task | Output |
|------|--------|
| Inventory: warehouses, lakes, pipelines, schedules, owners, SLAs | `docs/data/current-state.md` |
| Inventory: consumers (BI dashboards, ML features, downstream systems) | Same doc |
| Inventory: data contracts (declared or implicit) | Same doc |
| Inventory: PII / regulated columns with current treatment | Same doc |
| Identify rollback path (or "none") | Same doc |

#### Phase 2 — Add Observability & Contracts First

| Task | Why |
|------|-----|
| Emit lineage from legacy (OpenLineage adapter or wrapper) | Cannot migrate what you cannot trace |
| Capture characterization snapshots of legacy pipeline outputs | Regression baseline |
| Publish implicit contracts as explicit contracts (no behavior change) | Surface assumptions before changing them |
| Add freshness / volume / quality monitoring to legacy datasets | Detect drift during migration |

#### Phase 3 — Build New Platform Alongside Legacy

| Task | Why |
|------|-----|
| Greenfield rules apply to net-new datasets in the new platform | Stop accumulating legacy debt |
| Dual-write or shadow-read for migrated datasets | Reconciliation possible |
| Reconciliation report (row count, key sums, hash) per migrated dataset, scheduled | Migration progress measurable |

#### Phase 4 — Cutover Per Dataset

| Task | Why |
|------|-----|
| Switch consumers one-by-one to the new dataset (never bulk) | Blast radius bounded |
| Keep legacy dataset writeable until ALL consumers cut over + reconciliation green for ≥1 SLA cycle | Rollback possible |
| Mark legacy dataset deprecated in catalog, retire after grace period | Zombie datasets pruned |

### Brownfield Rules

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| BFD1 | NEVER rewrite a legacy pipeline from scratch | Loses years of behavior encoded in working code |
| BFD2 | New datasets follow the FULL greenfield bar from day one | Stop adding to the legacy pile |
| BFD3 | Every migrated dataset has a characterization-test baseline before refactor | No regression safety net |
| BFD4 | Reconciliation MUST be green for ≥1 full SLA cycle before consumer cutover | Bad new data ships under "successful migration" banner |
| BFD5 | Legacy and new coexist temporarily — that is the point | Premature decommission breaks rollback |
| BFD6 | Legacy infra is FROZEN — new work goes to the new platform; legacy only receives critical fixes | Dual investment forever |
| BFD7 | Migration timebox documented per dataset/domain (e.g., one quarter) — drift triggers escalation | "Temporary" coexistence becomes permanent |

---

## Greenfield Rules

When designing a new data platform from scratch, the full bar applies from day one. No "we'll add it later".

| ID | Rule | Failure If Violated |
|----|------|---------------------|
| GFD1 | First dataset ships with: contract, tests, lineage, classification, catalog entry — non-negotiable | Standards never get adopted retroactively |
| GFD2 | Architecture style chosen with documented alternatives BEFORE first DDL is written | Architecture by accretion |
| GFD3 | Schema-first / contract-first — schema defined and reviewed before any pipeline code | Schema thrash during build |
| GFD4 | Catalog-first — catalog tooling chosen and integrated before second dataset lands | Backfilling catalog metadata is unloved work |
| GFD5 | Storage layer chosen with versioned table format (Delta / Iceberg / Hudi) from day one | Painful retrofit later |
| GFD6 | Privacy / classification policy applied to first column — never deferred | "PII inventory" project two years later |

---

## Cross-Rulebook Consistency

| Concern | This Rulebook | Cross-Reference |
|---------|---------------|-----------------|
| File / function size | Inherits from `aire-implementation-rulebook.md` (≤300 / >500 lines, ≤30 / >50 lines) | Implementation |
| Coverage thresholds | Pipeline code follows `aire-qa-rulebook.md` (line ≥85%, branch ≥80%, new-code 100%) | QA |
| TODO severity | TODO in PR-ready code is a Blocker | Implementation |
| OWASP mapping | API endpoints fronting datasets follow `aire-implementation-rulebook.md` OWASP Top 10 mapping | Implementation |
| Observability | OTel emission required (per `aire-devops-rulebook.md`) — extended here with five-pillar data observability | DevOps |
| 12-Factor | Pipeline services follow 12-Factor (per `aire-devops-rulebook.md`) | DevOps |
| Layering | Clean Architecture Domain/Application/Infrastructure (per `aire-clean-architecture.md`) — domain layer applies to data products too | Clean Architecture |
| Migration patterns | Strangler Fig / ACL / Branch by Abstraction (per `aire-design-patterns.md`) | Design Patterns |

---

## Quality Gates

| Gate | Target | Description |
|------|--------|-------------|
| **Schema Tests** | 100% pass | dbt / GE / Soda tests green |
| **Freshness SLA** | 100% on monitored datasets | Land within declared SLA |
| **Completeness** | ≥99.9% | Row count vs source within tolerance |
| **Uniqueness** | 100% on PKs | No PK duplicates |
| **Referential Integrity** | 0 orphans | FK joins resolve |
| **Idempotency** | Verified | Replay test green |
| **Lineage Coverage** | 100% published datasets | Source-to-consumer traceable |
| **PII Classification** | 100% columns | Tagged or explicitly non-sensitive |
| **Catalog Registration** | 100% published datasets | Owner, contract, classification present |
| **Access Policy** | Enforced | RBAC/ABAC + RLS/CLS verified |
| **Schema Compatibility** | 100% PRs | Registry compatibility check passes |
| **Cost Budget** | Under approved | Per-product cost tagged + alerted |
| **Backup / DR** | Tested | RPO/RTO verified per regulatory class |
| **Reconciliation (brownfield)** | Green ≥1 SLA cycle | Pre-cutover requirement |

---

## Forbidden Actions

| Forbidden | Why |
|-----------|-----|
| Edit production data via ad-hoc DML | No audit trail; non-reversible |
| Publish dataset without contract | Consumers cannot rely on it |
| Copy production data to non-prod without masking + DPO approval | Privacy breach |
| Drop / rename column without deprecation cycle | Silent consumer breakage |
| Disable a quality test to "make CI pass" | Hides the actual problem |
| Add a column without classification | Cannot enforce policy |
| Backfill manually via console | Not reproducible; not testable |
| Decommission legacy before consumers cut over | Rollback impossible |
| Use schema-on-read for regulated data | Validation deferred = risk deferred |
| Hardcode credentials in DAG / dbt profile | Credential leakage |
| Ignore lineage emission "for one job" | Hole in traceability |

---

## Red Flags

| Red Flag | Action |
|----------|--------|
| Pipeline writes via APPEND to a mutable target | Switch to MERGE / upsert |
| Schema-on-read used for a regulated dataset | Add ingest-time validation |
| Producer publishes without a contract | Stop — write the contract first |
| PII column uncategorized | Classify and apply policy |
| Quality test failures suppressed | Re-enable; fix root cause |
| "We'll add lineage after launch" | Add now — it's cheaper |
| One pipeline serves both batch and stream with diverging logic | Refactor to unified or pick one |
| Stored procedure replaces what dbt could do | Move to dbt for lineage |
| Hot storage holding cold data | Apply lifecycle rule |
| Cluster runs 24/7 for nightly job | Scale to zero / auto-suspend |
| Topic without schema registry | Register schema first |
| Cross-domain direct table grant | Replace with contract-published dataset |
| "Just COPY production to dev to repro" | Refuse — synthetic / masked only |
| Backfill done manually in console | Convert to parameterized pipeline |
| Migration plan says "flag day" | Reject — Strangler / dual-write only |
| Catalog entry missing owner | Block publish |
| Right-to-be-forgotten not tested | Test before regulator does |
| File size <16 MB or >2 GB | Compaction needed |
| Partition cardinality > 100k | Reconsider partition key |
| dbt model outside `staging/intermediate/marts` | Refactor into structure |
| Stream consumer "starts from latest" in prod | Set to checkpoint; prevent data loss |
| Schema change merged without registry compat check | Add gate; revert if breaking |

---

## Decision Checklist (Before Building Anything)

- [ ] Is this greenfield or brownfield? Is `docs/data/current-state.md` present and current?
- [ ] What is the regulatory scope? (GDPR / HIPAA / PCI / SOX / sovereign data)
- [ ] Who are the consumers? What is their SLA?
- [ ] What is the architectural style and why? (Lakehouse / Mesh / Vault / Star / etc.)
- [ ] What is the modeling style? (3NF / Dimensional / Vault / hybrid)
- [ ] Batch / micro-batch / streaming? Justified by latency need?
- [ ] What is the contract? (Schema, owner, SLA, quality, classification, retention)
- [ ] What is the schema evolution policy? (Backward / forward / full)
- [ ] What is the storage layer? (Versioned table format mandatory)
- [ ] What is the partition / clustering strategy?
- [ ] What is the access control model? (RBAC/ABAC + RLS/CLS where applicable)
- [ ] What is the rollback path? (Time-travel + dual-write + reconciliation if brownfield)
- [ ] What is the cost projection? (Storage + compute, per environment)
- [ ] What is the on-call runbook?

If any item is unanswered, **STOP** and answer it before writing code.
