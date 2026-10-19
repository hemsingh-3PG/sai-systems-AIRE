# Requirements — PacEHR Encounter Agent, Epic 02 (Data Layer — AI Schema)

**Date**: 2026-10-05
**Author**: ANALYST_PM_BROWNFIELD
**Status**: Approved — 2026-10-05 · **Revised 2026-10-05** (authority model + PEA-205 corrected against as-built code)
**Source**: `dev-stories/Work-In-Progress/Epic-02/epic-02-data-layer.md` (Revision 8, 2026-10-05) synthesised
against `dev-stories/Tickets-Original-Python/00-source-index.md` (REQ ids) and `GAPS.md` (risk register)
**Scope of this document**: **Epic 02 only** — stories PEA-201…PEA-207. Epics 01 and 03–12 are
deliberately excluded; see *Scope* below.

---

## Project Type

- [x] Brownfield (new AI schema inside an existing production database)
- [ ] MVP (Proof of Concept acceptable)
- [x] Production-Ready (NO TODO comments allowed)

## Timeline

**Target Completion**: TBD
**Hard Deadline**: None stated
**Points**: 24 across 7 stories

---

## Project Overview

Epic 02 creates five tables in a new `AI` schema inside the **existing production Azure SQL
database** — `agentRun`, `fieldOutcome`, `promptFragment`, `fieldConstraint`,
`fieldDescription` — plus three database roles and a forward-only, idempotent migration
mechanism that touches nothing outside that schema.

These tables are the foundation the rest of the encounter-extraction programme is built on.
`AI.fieldOutcome` in particular is the asset with the highest downstream leverage: it is what
`afterAgent` writes, what the review queue reads, and — with no hand-labelling — what Epic 10's
evaluation harness treats as ground truth.

The governing constraint is that this runs against a database holding **real encounters for real
patients**. No existing clinical table is altered, dropped, or written to. Every guarantee in
this document is subordinate to that one.

---

## Current System Context

**Architecture**: Layered modular monolith — Angular 18 SPA → ASP.NET Core 8 API (~1,012
RPC-style endpoints) → SQL Server (1,120 tables / 1,553 stored procedures), per
`docs/architecture/current/00-system-overview.md`.

**This epic's build target**: `PacEHR_AI` — a **standalone Node.js / TypeScript service**
(ES modules, zod 4, `mssql` ^12.7.2, pino, jose, `node --test` + tsx, Node >=22.13), which owns
both the new AI code *and* the `AI.*` DDL. Migrations apply through
`MigrationRunner.applyPending()`, **not** through `pacEHR_API`'s SSDT project.

**Affected modules**:

| Module | Deep-dive reference | How this epic touches it |
|---|---|---|
| Data & SQL tier | `current/03-data-sql-tier-deep-dive.md` | Adds the `AI` schema to the same database. Reads existing clinical tables only. |
| AI assistance | `current/12-ai-assistance-deep-dive.md` | Coexists with it. Does **not** migrate `AIController`, `AIPromptServices`, `AI.prompt`, `usp_getPrompt` or the Angular admin feature. |
| Auth, identity & tenancy | `current/01-auth-identity-tenancy-deep-dive.md` | Introduces three database principals authenticated by Entra managed identity. |

**Existing patterns this epic must follow** — from `PacEHR_AI/CLAUDE.md`, which is the
engineering standard for the build target:

| Pattern | Rule |
|---|---|
| Singletons | One object per process per job; the instance exported on the module's last line; construction reads nothing and touches no network; expensive members are self-overwriting lazy getters. The migration runner opens **no second connection** — it uses the `database` singleton's `execute()`. |
| SQL naming | One statement per constant, `SCREAMING_SNAKE`, suffixed `_SQL`, declared above the class that runs it. Parameters are `@name` placeholders bound via `request.input()`. **No value ever reaches SQL by interpolation.** The tagged-template `query` form is banned. |
| Live spelling preserved | `templetID`, `fieldID`, `sectionID` keep the production database's own spelling, misspellings included. Retro-fitting conventions onto existing SQL is forbidden. |
| Configuration | Every setting is one entry in the zod schema in `src/core/settings.ts`. `process.env` appears nowhere else. No hardcoded environment values. |
| Logging | Fields first, literal message second. Log the token, never the value. No clinical value reaches a log line. |
| Numbers | A bare number in an expression is a bug. Every tunable is a named module constant traceable to a measurement, or a `settings()` field. |
| Tests | `node:test` + `node:assert/strict`. Unit tier runs with the network blocked. A test is classified by the directory it lives in. |

---

## Functional Requirements

Grouped by theme. Each line cites its `REQ-*` id from `00-source-index.md` and the story that
delivers it.

### Theme 1 — Migration mechanism and schema ownership

- The `AI` schema and three database roles are created by a forward-only, idempotent migration
  mechanism runnable against the live production database (REQ-02-07, REQ-02-10) — *PEA-201*
- Idempotency is by existence check against `sys.schemas` / `sys.database_principals`, **not** by
  a migration-history ledger table (REQ-02-10) — *PEA-201*
- Every migration file is static, fully literal SQL — never string-built, never taking a runtime
  parameter — *PEA-201*
- No down-migration exists. Undoing a bad migration is a new forward script, never an edit to a
  merged one — *PEA-201*
- The identity that runs migrations (deploy-time) is distinct from `aiServiceRuntime` (runtime) —
  *PEA-201*
- CI rejects, before merge, any script touching an object outside the `AI` schema — *PEA-201*

### Theme 2 — Immutable audit of every AI invocation

- `AI.agentRun` stores exactly one append-only row per invocation — prompt hash, model, tokens,
  latency, outcome — written only by the agent; no human writes to it (REQ-02-03) — *PEA-202*
- A run blocked by a guard **before any model call** still writes its row, with the model columns
  null and the reason recorded (REQ-02-03, REQ-02-09) — *PEA-202*
- The service's database principal holds `SELECT, INSERT` only; no `UPDATE`, no `DELETE`
  (REQ-02-07) — *PEA-202*
- The repository exposes exactly one SQL constant, `INSERT_AGENT_RUN_SQL`; no constant exists that
  could update or delete a row — *PEA-202*

### Theme 3 — Proposal beside decision, as the measurement asset

- `AI.fieldOutcome` stores what the AI proposed and what the clinician accepted, side by side, per
  field; the agent writes the proposal, the reviewer updates the decision and final value
  (REQ-02-04) — *PEA-203*
- The AI's three-state verdict — **FOUND, ABSENT, ABSTAINED** — is stored distinctly and must never
  collapse into a single "no value" encoding (REQ-02-04) — *PEA-203*
  > This is the defect the table exists to stop reproducing: the current production system writes
  > `NA` whether the note said nothing or the model was guessing. Edit rate, the review queue and
  > Epic 10's metrics are all computed by querying `proposedStatus`; a collapsed value makes every
  > one of those queries lie.
- The service's update authority is a **column-level** `GRANT UPDATE` naming exactly
  `acceptedValue, acceptedUnit, acceptedStatus, decidedByProviderId, decidedAtUtc` — the proposal
  columns are not updatable (REQ-02-04, REQ-02-09) — *PEA-203*
- The table carries an index and a defined retention policy, being the only table expected to grow
  meaningfully — ~30 rows per encounter, ~10.95M rows/year at 1,000 AI-assisted encounters/day
  (REQ-02-08) — *PEA-203, PEA-204*

### Theme 4 — Retention

- Rows older than a configured window are purged (REQ-02-08) — *PEA-204*
- **The purge fails closed when the window is unset**: no row is deleted, and the job logs a
  refusal naming the missing setting, never any row's content (REQ-02-08) — *PEA-204*
  > The retention period is a genuinely open compliance question (open question B7). Inventing a
  > day-count would be exactly the unsupported number `CLAUDE.md`'s numbers rule forbids. The
  > mechanism is in scope; the value is not.

### Theme 5 — Admin-authored configuration the agent may read and never write

- `AI.promptFragment` stores versioned, composable prompt fragments; only the AI/clinical admin,
  through Prompt Studio, may write to it, and **the agent never writes to it** (REQ-02-01) —
  *PEA-205* — 🔴 **NOT DELIVERED.** Blocked on decision **D11** (see Q9). The table does not exist;
  migrations ship 0001–0005 and four tables, not five.
- `AI.fieldConstraint` stores executable per-field guards — units, plausible bounds, abnormal
  bounds — compiled from prose a clinical author writes in the template editor; the agent never
  writes to it (REQ-02-02) — *PEA-206*
- `AI.fieldDescription` stores the per-mapping AI-facing field description (REQ-02-10,
  REQ-03-01) — *PEA-207*
- `AI.fieldConstraint` and `AI.fieldDescription` are keyed on the triple
  **`(templetID, sectionID, fieldID)`**, never on `fieldID` alone (REQ-03-01) — *PEA-206, PEA-207*
  > Measured justification, inherited from `PEA-301` and not re-argued here: the same `fieldID`
  > legitimately recurs in multiple sections of one template with a different meaning each time
  > (Blood Pressure in Review of Systems vs. Exam). `Template.fields.displayName` is global today,
  > and **one displayName edit was measured reaching 179 of 458 templates**. A coarser grain cannot
  > express the difference and cannot be fixed later without a migration.
- `AI.fieldDescription` stores exactly one new fact per mapping — the description text. `name`,
  `type` and `unit` are **not** duplicated; they already exist on `Template.fields`, are read-only,
  and are joined in at request time by Epic 3's schema-builder — *PEA-207*

### Theme 6 — Authority boundary enforced in the application

> **🔴 Revised 2026-10-05 against the as-built code.** The original text of this theme specified
> three database roles and a table-by-table `GRANT` matrix. **That is not what was built.**
> `0002_create_ai_roles.sql` was withdrawn and the remaining scripts renumbered; `DELIVERY-PLAN.md`
> records the owner decision: *"no database roles, and no `GRANT`s, in this epic. Authority over
> `AI.*` is enforced in the application — the service connects as one principal, and which caller
> may read or write what is decided above the data layer."* This closes blockers D2 and M1. The
> affected DoD items are **withdrawn, not passed**.

- The service connects as **one database principal**. No `AI`-schema role is created, and nothing
  is granted on any `AI.*` object (REQ-02-07) — *PEA-201*
- Read/write authority per caller is decided **above the data layer**, by the repository surface:
  one class per table, and a table's write path exists only where a caller is entitled to it —
  *PEA-202, 203, 206, 207*
- `AI.agentRun` has exactly one SQL constant, `INSERT_AGENT_RUN_SQL`; no constant exists that could
  update or delete a row — the append-only property is enforced by the **absence of code**, not by
  permission — *PEA-202*
- `AI.fieldOutcome`'s decision update is scoped by `AND [decidedAtUtc] IS NULL` and touches only
  the accepted-value columns; the proposal columns are never in an `UPDATE` statement — *PEA-203*
- `migrations/verification/post-apply-checks.sql` asserts the inverse of the original design:
  **0 rows** for `AI`-schema roles and **0 rows** for `AI`-object grants. A row means someone
  reintroduced a role out of band.

🔴 **The cost, recorded as a decision rather than left as drift.** `AI.agentRun` is specified as a
record *"no application code can have edited after the fact."* With no permissions, nothing at the
server refuses an `UPDATE` or `DELETE` against the audit table. The guarantee becomes *no
application code **does** edit it* — a convention, not a control. **If the compliance claim is
load-bearing, the substitute is an `INSTEAD OF UPDATE, DELETE` trigger on `AI.agentRun`**, which
needs no principal, no grant and no provisioning. This is open question Q10.

### Theme 7 — Naming fidelity

- Every new column referencing an existing key reuses the live database's own spelling and
  inconsistencies — `templetID`, `fieldID`, `sectionID` — rather than a retro-fitted convention
  (REQ-02-09) — *all stories*

---

## Success Criteria (MUST HAVE — measurable)

1. Applying the full migration set against a copy of the production database creates the `AI`
   schema, the three roles and the five tables, **and no row in any existing clinical table is
   added, changed or removed.**
2. Re-running the full migration set is a verified no-op: no error raised, nothing recreated or
   altered, every existence check short-circuits its `CREATE`.
3. A draft script containing `ALTER TABLE Encounter.encounter ADD aiFlag BIT` **fails CI and
   cannot be merged.**
4. No file under `migrations/sql/` drops or reverses another.
5. A committed run inserts exactly one `AI.agentRun` row with `outcome` committed and
   `promptHash`, `modelDeployment`, `inputTokens`, `outputTokens`, `latencyMs` all populated.
6. A guard-blocked run inserts exactly one row with the blocked outcome, a non-null reason, and
   the token/latency columns null.
7. `post-apply-checks.sql` returns **0 rows** for `AI`-schema database roles and **0 rows** for
   grants on any `AI.*` object — the application-enforced authority model, verified.
8. `src/repositories/agentRunWriter.ts` exposes exactly one SQL constant, `INSERT_AGENT_RUN_SQL`;
   a mutation test confirms no update or delete path exists. `fieldOutcomeRepository`'s decision
   update is scoped by `AND [decidedAtUtc] IS NULL` and names only the accepted-value columns,
   both mutation-tested.
9. `proposedStatus` distinguishes FOUND, ABSENT and ABSTAINED in storage and in every read path.
10. With the retention setting unset, the purge job deletes **zero** rows and logs a refusal
    naming the setting.
11. Every `AI` column referencing an existing key matches the live spelling exactly, verified
    against `information_schema.columns` on the real database.
12. Unit tier passes with the network blocked; integration tier applies the script set twice
    against a scratch database with the second run a no-op.
13. Test coverage ≥85%.

## Failure Criteria (UNACCEPTABLE)

1. **Any write, alter or drop against an existing clinical table** — by migration, by repository,
   or by a bad re-run. This is the single non-negotiable.
2. A migration that is not idempotent, or that can be reversed in place.
3. ABSENT and ABSTAINED becoming indistinguishable in storage or in any read path.
4. An `UPDATE` or `DELETE` path existing on `AI.agentRun` in code — which, absent grants, is the
   only thing preventing one.
5. A guard-blocked run that writes no audit row — the run most worth auditing going unrecorded.
6. The retention purge deleting rows on an unset or defaulted window.
7. A clinical value, patient identifier or proposed/accepted value appearing in a log line, trace
   attribute or error message.
8. SQL assembled by interpolation anywhere in the epic, DDL included.
9. A second database connection opened outside the `database` singleton.
10. A retro-fitted column name that silently breaks the join to an existing key.

---

## Technical Constraints

- **Patterns to follow**: `PacEHR_AI/CLAUDE.md` — Singletons, Naming, Numbers, Logging, Errors,
  Tests, Clinical and PHI rules. Tickets cite it; they do not restate it.
- **Runtime**: Node >=22.13, ES modules, TypeScript (NodeNext; `.js` specifiers).
- **Driver**: `mssql` (node-mssql over tedious) — **natively async**, so there is one `execute()`
  and no sync/async twin. The reference design's thread-pool bridge does not apply.
- **Database**: the existing production Azure SQL database. New `AI` schema only. No new data
  store is introduced (REQ-02-10).
- **Migrations**: `migrations/sql/NNNN_*.sql`, applied in filename order by
  `MigrationRunner.applyPending()` in `src/core/databaseMigrations.ts`, invocable standalone
  (`npm run migrate`) so it does not block on Epic 11's pipeline.
- **Authentication**: deployed code uses managed identity. `aiServiceRuntime` maps to the
  extraction service's own managed identity. SQL login is a local-development fallback only.
- **Repository surface**: `src/repositories/` — one class per `AI.*` table, the only readers and
  writers of it, module-scope `_SQL` constants.
- **Test coverage**: ≥85%. **Tests location**: `tests/unit`, `tests/integration`, `tests/manual` —
  the directory is the marker.
- **No new dependency** for the CI schema-scope check; built-in `RegExp` only.

## Quality Gates

- All tests pass (100%)
- Coverage ≥85%
- `npm run typecheck` (`tsc --noEmit`) clean
- ESLint guard rules pass — `process.env` confinement, log-call shape, banned tagged-template
  `query`, `no-explicit-any`
- Unit tier passes with network blocked; unit import proof passes with `env: {}`
- Follows `PacEHR_AI/CLAUDE.md`
- Code review approved
- No TODO comments
- **Migration reviewed by a second engineer and dry-run against a staging copy of the production
  database before production application** — a gate specific to this epic

---

## Explicit Scope

### IN Scope

- The `AI` schema; roles `aiServiceRuntime`, `aiPromptAdmin`, `aiTemplateAdmin`; the forward-only
  idempotent migration mechanism.
- Five tables and their DDL: `AI.agentRun`, `AI.fieldOutcome` (with index and retention/purge),
  `AI.promptFragment`, `AI.fieldConstraint`, `AI.fieldDescription`.
- The read/write authority boundary for every table, as database `GRANT`s.
- The minimal repository-level TypeScript surface under `src/repositories/` that other epics call
  — **not** the callers themselves.

### OUT of Scope

- `AI.memoryEvent`, `AI.memory` — Epic 12, Phase 2.
- The clinical justification for the `(templetID, sectionID, fieldID)` grain — Epic 3, `PEA-301`.
  This epic ships the DDL and treats the grain as settled.
- Prompt fragment composition, precedence, activation gating, rollback, A/B comparison — Epic 8.
- The validators reading `AI.fieldConstraint` at request time — Epic 6.
- The schema-builder reading `AI.fieldDescription` at request time — Epic 3.
- The `/ai/encounter/resolve` endpoint — Epic 9.
- The evaluation harness reading `AI.fieldOutcome` — Epic 10.
- The pipeline step invoking the runner, and the purge job's schedule trigger — Epic 11.
- Prompt Studio UI/API and the template editor UI — outside this epic's numbered scope.
- Migrating existing AI code (`AIController`, `AIPromptServices`, `AI.prompt`, `usp_getPrompt`,
  the Angular admin feature). **Owner decision: coexist, do not migrate.**

### IMPACT Scope (indirect)

- **Existing clinical tables** — read-only, and must be *proven* unchanged, not assumed.
- **The production Azure SQL database** — shared with the live EHR; migration runs against it.
- **`pacEHR_API`'s SSDT project** — now no longer the sole authority for database objects in this
  database. Two deployment mechanisms write to one database; divergence is a standing risk.
- **Epics 3, 6, 8, 9, 10, 12** — all consume these tables. A grain or vocabulary change here
  propagates to all of them.

---

## Roles & Permissions Matrix

> Canonical role registry. `Origin` = `Existing` (already enforced in the codebase, per deep-dive)
> or `New` (introduced by this work).

### Database principals — **revised 2026-10-05**

> The three roles below were specified by the epic text and **are not built**. Owner decision,
> 2026-10-05: no `AI`-schema roles, no `GRANT`s. They are retained here as *withdrawn*, because a
> later reader finding `aiServiceRuntime` named in Epics 3, 6, 8 and 9 needs to know why it does
> not exist.

| Role (canonical) | Status | Description | Origin |
|---|---|---|---|
| Service principal | ✅ **Built** | The one login the service connects as. Holds whatever rights that login already carries; nothing is granted on `AI.*` specifically. Which caller may read or write what is decided **above the data layer**, by the repository surface. | Existing login, **new** use |
| Migration identity | ✅ **Built** | Deploy-time only; creates the schema and tables. Distinct from the runtime principal. | Entra managed identity (deploy principal) |
| `aiServiceRuntime` | 🔴 **Withdrawn** | Was to hold `SELECT, INSERT` on `agentRun` and column-scoped `UPDATE` on `fieldOutcome` | — |
| `aiPromptAdmin` | 🔴 **Withdrawn** | Was to hold `INSERT, UPDATE` on `promptFragment` | — |
| `aiTemplateAdmin` | 🔴 **Withdrawn** | Was to hold `INSERT, UPDATE` on `fieldConstraint` and `fieldDescription` | — |

**Where authority now lives.** One class per `AI.*` table under `src/repositories/`, and that
class is the only reader and writer of its table. A table has a write path only where a caller is
entitled to one — so `agentRunWriter` has an insert and nothing else, and `fieldOutcomeRepository`
separates the proposal insert from the decision update. **The enforcement is the absence of code,
and it is mutation-tested**: removing `AND [decidedAtUtc] IS NULL` from the decision update, or
making the proposal insert touch `acceptedValue`, each fails the suite.

**Permission keys** (now application-level concepts, not database grants): `agentRun:insert`,
`fieldOutcome:propose`, `fieldOutcome:decide`, `fieldConstraint:read`, `fieldDescription:read`,
`promptFragment:read` *(pending PEA-205)*.

### Human actors referenced by this epic's user stories

| Actor | Appears in | Acts through | Origin |
|---|---|---|---|
| Platform engineer | PEA-201 | The migration identity, at deploy time | Existing |
| Compliance officer | PEA-202, PEA-204 | Reads `AI.agentRun`; sets the retention window | Existing |
| AI/clinical admin | PEA-203, PEA-205 | Prompt Studio — surface not built (D7, and PEA-205 blocked on D11) | Existing role, **new** privilege |
| Clinical template administrator | PEA-206, PEA-207 | The template editor — authoring surface not built (M6/D7) | Existing role, **new** privilege |
| Clinician / reviewing provider | PEA-203 | Recorded as `decidedByProviderId` on `AI.fieldOutcome` | Existing |

**Notes**: The existing application role model is `Account.roles` (`roleID`, `roleName`), with
role-based response-field stripping done inline against magic numbers
(`UserController.cs:320-339`, per `01-auth-identity-tenancy-deep-dive.md`). This epic does **not**
extend that model — its authority boundary is enforced in the database, independent of it.
Mapping the four human actors above onto concrete `roleID` values is **unresolved** and is
recorded as open question Q3 below. With database roles withdrawn, that mapping is now the *only*
authority mechanism for the admin-authored tables, which raises its priority.

---

## Design References

**Location**: `SPEC/references/`

| File | Type | Description | Used In |
|---|---|---|---|
| — | — | Directory holds only two empty folders (`builds/`, `devops/`) | — |

No PRDs, designs or legacy specs are available to honour. `docs/helix/INDEX.md` is absent, so no
prior Helix solution context was available either. The substantive source documents for this epic
live outside `SPEC/references/`, in `dev-stories/` — see *Source Traceability*.

---

## Patterns to Follow

| Pattern | Reference |
|---|---|
| Singletons, lazy getters, no second connection | `PacEHR_AI/CLAUDE.md` § Singletons |
| SQL constants, `@name` binding, live spelling | `PacEHR_AI/CLAUDE.md` § Naming |
| Configuration via one zod schema entry | `PacEHR_AI/CLAUDE.md` § Configuration |
| Logging — fields first, token not value | `PacEHR_AI/CLAUDE.md` § Logging |
| Errors — `PacEHRError` is a refusal, 4xx | `PacEHR_AI/CLAUDE.md` § Errors |
| Tests — tier by directory, network blocked | `PacEHR_AI/CLAUDE.md` § Tests |
| PHI — mask before egress, fail closed, guards never throw | `PacEHR_AI/CLAUDE.md` § Clinical and PHI rules |
| Existing data tier conventions | `docs/architecture/current/03-data-sql-tier-deep-dive.md` |
| Existing AI surface (coexists, not migrated) | `docs/architecture/current/12-ai-assistance-deep-dive.md` |

---

## Source Traceability

| Source | What it supplied |
|---|---|
| `dev-stories/Work-In-Progress/Epic-02/epic-02-data-layer.md` (Rev 8, 2026-10-05) | Authoritative story text, DDL, Gherkin AC, DoD for PEA-201…207 |
| `dev-stories/Tickets-Original-Python/00-source-index.md` | REQ-02-01…10, REQ-03-01 — 128 requirements with line citations |
| `dev-stories/Tickets-Original-Python/GAPS.md` | Risk register — eight independent reviews |
| `dev-stories/Work-In-Progress/Epic-02/DELIVERY-PLAN.md` | Delivery sequencing |
| `PacEHR_AI/CLAUDE.md` | The engineering standard for the build target |
| `docs/architecture/current/*` | System context, affected modules, existing patterns |

### Requirement coverage

| REQ | Covered by |
|---|---|
| REQ-02-01 | PEA-205 — 🔴 **not delivered**, blocked on D11 |
| REQ-02-02 | PEA-206 |
| REQ-02-03 | PEA-202 |
| REQ-02-04 | PEA-203 |
| REQ-02-05, REQ-02-06 | **Out of scope** — Epic 12, Phase 2 |
| REQ-02-07 | PEA-201, 202, 206, 207 |
| REQ-02-08 | PEA-203, PEA-204 |
| REQ-02-09 | PEA-202, 203, 206, 207 |
| REQ-02-10 | PEA-201, PEA-207 |
| REQ-03-01 | PEA-207 (storage only; the argument is Epic 3's) |

**Deviation on table count, carried forward deliberately.** `REQ-02-10` names *four* Phase 1
tables, matching the 4Pager's enumeration. This epic ships *five*. `REQ-03-01` requires a
per-mapping field description, and `REQ-02-07` forbids adding anything to an existing clinical
table — so the description cannot live on `Template.fields` or
`Encounter.encounterTempletMapping`. It must be an `AI`-schema sidecar. `REQ-02-10`'s substantive
clause — *"no new data store is introduced"* — still holds: one more table in the same existing
database is not a new store.

---

## Open Questions & Risks

Carried from `GAPS.md` and from this synthesis. These are **not** resolved by this document; they
are recorded so the architecture step can close them.

| # | Question / Risk | Severity | Source |
|---|---|---|---|
| Q1 | **What is the `AI.fieldOutcome` retention window?** Neither source document states one; the mechanism fails closed until compliance sets it. Must also exceed what Epic 10's harness needs (REQ-10-08). | 🔴 Blocking go-live, not build | Open question B7; PEA-204 |
| Q2 | **Nothing owns writing to the encounter form.** Epic 9 says it writes validated fields to the chart; `REQ-02-07` says no existing clinical table is ever written by this service. No repository, no `_SQL` constant, no `GRANT`, no upsert exists. *"Written to the encounter form"* appears 26 times across 6 epics. **The product's only output has no implementation.** | 🔴 Blocking | GAPS #1 (3 confirmations) |
| Q3 | **Clinician identity is never defined.** Three incompatible shapes — Entra `oid` (warned to be the proxy's own identity), an unexplained "clinician object id" context field, and `decidedByProviderId INT` on this epic's own table. The audit cannot answer *"who decided this."* | 🔴 Blocking | GAPS #6 (3 confirmations); PEA-203 |
| Q4 | **`AI.fieldConstraint` may not be able to store four of the six things the compiled guard carries** — risk class, components, roles, temporal direction and horizon. Would kill role binding, leave the BLOCK-vs-REVIEW branch with no input, and send every date field to `NO_GUARD_DEFINED` permanently. **Verify against the shipped DDL before closing.** | 🟠 High | GAPS #7 (2 confirmations); PEA-206 |
| Q5 | **An auto-committed field never acquires a final value.** The only two writers on `AI.fieldOutcome` are propose-at-extract and accept-at-resolve — so edit rate, the memory kill switch and Epic 12's capture all depend on a value nothing writes, narrowing *"every field a clinician corrected"* to *"every reviewed field."* | 🟠 High | GAPS #25; PEA-203 |
| Q6 | **Two deployment mechanisms now write to one database** — this service's `MigrationRunner` and `pacEHR_API`'s SSDT project. No story defines how they stay from colliding. | 🟠 High | This synthesis |
| Q7 | **Patient-request deletion has no erasure path.** `proposedValue`, `acceptedValue` and `foundIn` are PHI. Retention purge is time-based only. | 🟠 High | GAPS §3 #10 |
| Q8 | **Backup, restore and credential rotation for the `AI` schema** are named by nobody. | 🟡 Medium | GAPS §3 "Worth naming" |
| Q9 | **D11 — `AI.promptFragment` uniqueness.** §3.1's filtered unique index (`WHERE accountId IS NOT NULL AND templetID IS NOT NULL`) enforces uniqueness only on account-scoped rows; a global `contract` fragment has both columns NULL, falls outside the filter, and can be inserted **twice at the same version with no error** — the exact near-duplicate defect already found in live `AI.prompt` data. Recommended fix: §3.3's option A — `NOT NULL DEFAULT 0` sentinels with a plain `UNIQUE (kind, scope, accountId, templetID, version)`, matching `usp_getPrompt`'s existing `accountId = 0` precedent. **Blocks PEA-205 / REQ-02-01.** ~30 minutes to decide. | 🔴 Blocking | DELIVERY-PLAN §3 |
| Q10 | **`AI.agentRun` immutability is now a convention, not a control.** With no grants, nothing at the server refuses an `UPDATE`/`DELETE` on the audit table. Substitute: an `INSTEAD OF UPDATE, DELETE` trigger — no principal, no grant, no provisioning. **Decide whether the compliance claim is load-bearing.** | 🔴 Blocking the compliance claim | DELIVERY-PLAN decision note; HANDOFF §3 |
| Q11 | **M11 — no deployment path exists.** Every story's exit criterion ends in *"against staging"*. Code can be written, reviewed and merged; it cannot be proven. 5–8 points, unowned. | 🔴 Blocking epic closure | DELIVERY-PLAN §4.2 |
| Q12 | **D7 — UI scope undecided.** Decides ~31 vs ~75 points, and gates the review surface (M4). Without it `AI.fieldOutcome` stays half-NULL forever: the accepted-value columns have no writer. | 🟠 High | DELIVERY-PLAN §4.2 |
| Q13 | **D29 — `DECIMAL(6,2)` arrives in Node as a binary double**, so a bound comparison at the boundary can flip. Push the comparison into SQL, or adopt an explicit documented tolerance — decided before the first bound check is written. | 🟠 High | `0004_create_field_constraint.sql` ponytail note |
| Q14 | **D18** (`agentRun` vs `runAudit` naming, 5 min), **D6** (description vs `aiSummaryPrompt`), **D32** (prompt precedence, replaces the cutover D5 removed). | 🟡 Medium | DELIVERY-PLAN §4.2 |

### As-built delivery state (verified 2026-10-05 against `PacEHR_AI` working tree)

| Story | Table | DDL | Repository | State |
|---|---|---|---|---|
| PEA-201 | `AI` schema + runner | ✅ `0001` | `src/core/databaseMigrations.ts` | Built |
| PEA-202 | `AI.agentRun` | ✅ `0002` | `agentRunWriter.ts` | Built |
| PEA-203 | `AI.fieldOutcome` | ✅ `0003` | `fieldOutcomeRepository.ts` | Built; no decision writer (D7/M4) |
| PEA-204 | retention purge | ⏳ | ⏳ | Mechanism next; **blocked on D4 for the number** |
| PEA-205 | `AI.promptFragment` | 🔴 **not built** | — | **Blocked on D11** (Q9) |
| PEA-206 | `AI.fieldConstraint` | ✅ `0004` | `fieldConstraintRepository.ts` | Built |
| PEA-207 | `AI.fieldDescription` | ✅ `0005` | `fieldDescriptionRepository.ts` | Built |

**Four of five tables shipped.** `migrations/verification/post-apply-checks.sql` check #4 still
reads *"The five tables exist — expect: 5 rows"*; against the current script set it returns 4.

A design decision was also reversed during the build and is recorded here so it is not re-derived:
**PEA-201 originally banned `GO` in migration scripts.** That was wrong — `CREATE INDEX` cannot
reference a table the same batch is still creating, so every spec's DDL uses `GO`. The runner now
splits on `GO` and sends each part as its own batch, `batches()` is exported and tested directly,
and the `README.md`/`HANDOFF.md` claims about `GO` are superseded.

### Risks assessed as already addressed by the as-built DDL

Recorded for transparency — these were open in `GAPS.md` and appear closed in
`migrations/sql/0002_create_agent_run.sql`. **Verification belongs to `aire-review-code`, not to
this document.**

| GAPS # | Finding | As-built evidence |
|---|---|---|
| #3 | A guard-blocked run cannot write its audit row — `promptHash`/`modelDeployment` declared NOT NULL, no `reasonCode` column | `promptHash` and `modelDeployment` are nullable, gated by `CK_agentRun_reachedModel`; `reasonCode` exists and is forced non-null for blocked runs by `CK_agentRun_blockedHasReason` |
| #9 | Run outcome has two vocabularies and an orphan `error` value | `CK_agentRun_outcome` admits exactly `COMMITTED`, `AWAITING_REVIEW`, `BLOCKED` — one vocabulary, no orphan |
| §3 #12 | `AI.agentRun` records no `templetID` and no config version | Both columns present (`templetID`, `configVersion`) |

### Language drift — resolved for this epic

The `dev-stories/Tickets-Original-Python/` backlog states *Python · Pydantic · `create_agent`*, and its
symbol-truth document is `00-langchain-api-truth.md`. The `Epic-02` private copy used here is
**Revision 8 and already retargeted to Node/TypeScript**, with zod, `mssql` and `node --test`
settled by shipped code. **No translation was required for Epic 02.** Two consequences worth
carrying forward:

- `PacEHR_AI/CLAUDE.md` cites **`00-langchainjs-api-truth.md` §16 #1**; no file of that name exists
  on disk. The JS symbol-truth document is either unwritten or not in this workspace.
- `GAPS.md` findings that are Pydantic-specific (notably #12 and #19) do not transfer to zod and
  must be re-derived before Epics 3 and 6 are planned.

### Architecture drift — flagged, not resolved

`docs/architecture/design/12-ai-phase1-implementation-architecture.md` (2026-09-09) recommends
**Option B** — `PacEHR.AI.*` .NET projects inside the existing solution behind a legacy contract
adapter — and explicitly defers **Option C** (separate deployable) to Phase 2/3. What is being
built is Option C: a standalone Node service in its own repository. The owner decisions recorded
in Epic 02 Revision 8 state this plainly (*"Node only, greenfield"*), so it is a deliberate
choice — but **no document under `docs/architecture/design/` records it**, and the target
architecture still says otherwise. `aire-brownfield-architecture` should reconcile the two.

Related: `docs/architecture/current/00-system-overview.md` (2026-09-30) describes `PacEHR_AI` as
*"Stub only — template README, no source."* That is now five days stale.

---

## Mandatory Next Step

| # | Next Command | Purpose |
|---|---|---|
| ▶️ | `aire-brownfield-architecture` | Design the target-state architecture for these changes, and reconcile the Option B / Option C drift above |
