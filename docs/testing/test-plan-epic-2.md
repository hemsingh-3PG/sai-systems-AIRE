# Test Plan — Epic 2: Data Layer, AI Schema

**Date**: 2026-10-06
**Author**: QA
**Scope**: `epic-2` · **Status**: Draft — awaiting user approval
**Source**: `docs/plans/implementation-plan.md`, `docs/plans/stories/epic-2-story-2.{1..7}-*.md`,
and the authoritative acceptance criteria in `Other-Docs/Epic-02/epic-02-data-layer.md` (Rev 8)

---

## 🔴 The finding this plan exists to state

Epic 2 has **121 passing unit tests and 33 integration tests, 25 of which have never executed.**
Every claim about database behaviour in this epic — CHECK constraints, foreign keys, primary keys,
unique constraints, column existence, `@@ROWCOUNT`, transaction rollback, and whether the retention
purge deletes the right rows — rests on code that has never reached a database.

**This is not a coverage gap to be filled by writing more tests.** The tests exist. They skip,
because no `.env.local` is present. One execution against a DEV database converts the entire set
from asserted to verified, and no amount of further unit testing substitutes for it.

QA's first action on this epic is therefore **not** to author new scenarios. It is **TC-ENV-001**.

---

## Scope

**Coverage**: Epic 2 — the `AI` schema, its forward-only migration mechanism, and the repository
surface other epics call.

### In Scope

| Story | Component |
|---|---|
| 2.1 (PEA-201) | `AI` schema creation; `MigrationRunner`; migration scope validation |
| 2.2 (PEA-202) | `AI.agentRun` — append-only invocation audit |
| 2.3 (PEA-203) | `AI.fieldOutcome` — proposal beside decision |
| 2.4 (PEA-204) | Retention purge — batching, decided-only, fail-closed |
| 2.6 (PEA-206) | `AI.fieldConstraint` — per-mapping numeric guards |
| 2.7 (PEA-207) | `AI.fieldDescription` — per-mapping AI-facing semantics |

### Out of Scope

- **Story 2.5** (`AI.promptFragment`) — **not built**, blocked on decision D11. No code to test.
- Prompt composition and precedence (Epic 8); validators reading `AI.fieldConstraint` (Epic 6);
  the schema builder reading `AI.fieldDescription` (Epic 3); the `/ai/encounter/*` endpoints
  (Epic 9); the evaluation harness (Epic 10); scheduling (Epic 11).
- The Angular SPA and `pacEHR_API`. This epic adds no HTTP route and no UI.
- **Performance/load testing of the purge at production volume** — see TC-PERF-001, deliberately
  specified but not runnable without a populated environment.

### Cannot Be Tested, and Why

| Thing | Why not |
|---|---|
| End-to-end extraction | No agent exists until Epic 4. `AI.agentRun` has no caller. |
| A clinician's decision | **No writer exists** for the accepted columns (R1 / M4 / D7). Every row is proposal-only. |
| Retention at a real window | **D4 is unmade.** The purge correctly refuses, so its happy path is only reachable by supplying a window in a test. |
| Deployment | **M11 — no deployment path exists.** Every story's exit criterion ends *"against staging"*. |

---

## Requirements Traceability

Every requirement maps to at least one scenario. `REQ-*` ids from
`Other-Docs/TicketsByAkash/00-source-index.md`.

| Requirement | Description | Scenarios |
|---|---|---|
| REQ-02-07 | No existing clinical table is replaced, written, or altered | TC-MIG-003, TC-MIG-004, TC-ENV-002 |
| REQ-02-10 | Phase 1 tables created inside the existing database; no new data store | TC-MIG-001, TC-MIG-002 |
| REQ-02-03 | One append-only `AI.agentRun` row per invocation | TC-RUN-001…004 |
| REQ-02-04 | Proposal beside decision, per field | TC-OUT-001…006 |
| REQ-02-08 | `AI.fieldOutcome` indexed, with a defined retention policy | TC-RET-001…006, TC-PERF-001 |
| REQ-02-09 | Live spelling reused (`templetID`, `fieldID`, `sectionID`) | TC-ENV-002 |
| REQ-02-02 | `AI.fieldConstraint` stores executable per-field guards | TC-CON-001…004 |
| REQ-03-01 | Field description keyed on `(templetID, sectionID, fieldID)` | TC-DES-001…004 |
| REQ-02-01 | `AI.promptFragment` versioned fragments | ❌ **Unmapped — story 2.5 not built (D11)** |

> **REQ-02-01 has no test because it has no code.** Recorded rather than silently omitted.

---

## Test Categories

### Already implemented (121 unit / 33 integration)

| Area | Unit | Integration |
|---|---|---|
| Migration runner & scope rules | `core/databaseMigrations.test.ts` | `core/databaseMigrations.test.ts` |
| `AI.agentRun` | `repositories/agentRunWriter.test.ts` | `repositories/agentRunWriter.test.ts` |
| `AI.fieldOutcome` | `repositories/fieldOutcomeRepository.test.ts` | `repositories/fieldOutcomeRepository.test.ts` |
| Retention | `jobs/fieldOutcomeRetention{,.configured}.test.ts`, `core/settings.retention.test.ts` | `repositories/fieldOutcomeRetention.test.ts` |
| `AI.fieldConstraint` | `repositories/fieldConstraintRepository.test.ts` | `repositories/fieldConstraintRepository.test.ts` |
| `AI.fieldDescription` | `repositories/fieldDescriptionRepository.test.ts` | `repositories/fieldDescriptionRepository.test.ts` |
| Guard rules (lint) | `source-rules.test.ts` | — |
| Import hygiene | `repo.test.ts` | — |

### Gaps this plan adds

Scenarios marked **NEW** below are not yet implemented.

---

## Test Scenarios

### Environment — must run first

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| **TC-ENV-001** | Integration | **Execute the full integration suite once against DEV** with `.env.local` configured | 33/33 run; 0 fail; **25 previously-skipped tests report pass or a real failure** | 🔴 **Blocker** |
| TC-ENV-002 | Integration | After TC-ENV-001, run `migrations/verification/post-apply-checks.sql` and keep the output | Check #5 returns **0 rows** — no object outside `AI` modified. Column spellings match the statements | 🔴 Blocker |
| TC-ENV-003 | Integration | Confirm the target is DEV, not production, before any suite runs | The configured `AZURE_SQL_DATABASE` is the DEV database | 🔴 Blocker |

> TC-ENV-001 is the single highest-value test in this plan. Until it passes, every scenario below
> marked *Integration* is **specified but unproven**, and the epic's quality gates cannot be
> evidenced.

### Migration (story 2.1)

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| TC-MIG-001 | Integration | Apply the full set to a database with no `AI` schema | Schema and four tables exist; **no database role is created** (ADR-01) | High |
| TC-MIG-002 | Integration | Apply the full set a second time | No error; nothing recreated; every existence check short-circuits | High |
| TC-MIG-003 | Unit | A script with an unqualified `CREATE TABLE widget` | Rejected: *"not AI-qualified"* | High |
| TC-MIG-004 | Unit | A script with `ALTER TABLE Encounter.encounter` / `UPDATE Template.fields` / `DROP TABLE` | Each rejected, naming the script | High |
| TC-MIG-005 | Unit | A row write **inside** `AI` (Epic 8's bootstrap) | **Allowed** — the ban is scoped to non-`AI` targets | Medium |
| **TC-MIG-006** | Integration | **NEW** — apply the set against a database where the `AI` schema already exists carrying `AI.prompt` | No error; `AI.prompt` untouched. *This is the production case and is untested today* | 🔴 High |

### `AI.agentRun` (story 2.2)

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| TC-RUN-001 | Unit | A completed run | Hash and deployment written; `reasonCode` null | High |
| TC-RUN-002 | Unit | A guard-blocked run assembled as a variable | Token and model columns **null**; reason written | High |
| TC-RUN-003 | Unit | Enumerate the module's `_SQL` exports | Exactly `INSERT_AGENT_RUN_SQL`; no update/delete form | High |
| TC-RUN-004 | Integration | Both row shapes against the live CHECKs | `CK_agentRun_reachedModel` and `CK_agentRun_blockedHasReason` accept them | High |
| **TC-RUN-005** | Integration | **NEW** — attempt `UPDATE [AI].[agentRun]` directly as the service principal | ⚠️ **Expected to SUCCEED.** ADR-01 withdrew the `GRANT`s, so immutability is convention only. **The test documents the exposure; it does not pass or fail** | 🔴 High |

### `AI.fieldOutcome` (story 2.3)

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| TC-OUT-001 | Unit+Int | `FOUND`, `ABSENT`, `ABSTAINED` each round-trip distinctly | Three distinct stored values; never collapsed | 🔴 High |
| TC-OUT-002 | Unit+Int | All three confidence bands | `HIGH`/`MEDIUM`/`LOW` stored as themselves | High |
| TC-OUT-003 | Unit | Proposal write names no decision column, and vice versa | Both assertions hold | High |
| TC-OUT-004 | Unit+Int | A second decision on a decided row | Changes nothing; returns `false` | 🔴 High |
| TC-OUT-005 | Integration | A proposal naming a non-existent `runID` | Refused by `FK_fieldOutcome_agentRun` | High |
| TC-OUT-006 | Integration | A decision inside a transaction that then rolls back | The decision does **not** survive | High |
| **TC-OUT-007** | Integration | **NEW** — two concurrent `recordDecision` calls on one undecided row | Exactly one returns `true`; the other `false`. *The `decidedAtUtc IS NULL` guard is tested sequentially today, never concurrently* | 🔴 High |

### Retention (story 2.4)

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| TC-RET-001 | Unit | Window unset | 0 rows; **no statement issued**; refusal names the setting | 🔴 Blocker |
| TC-RET-002 | Unit | Window set to `0` | `settings()` throws naming the variable | 🔴 Blocker |
| TC-RET-003 | Unit | Refusal log line | Contains no `proposedValue` / `acceptedValue` / `foundIn` | 🔴 Blocker |
| TC-RET-004 | Integration | Old+decided, old+undecided, recent+decided | Only the old decided row is purged | 🔴 High |
| TC-RET-005 | Unit | Batch loop | Loops until a batch returns short; totals correct | High |
| TC-RET-006 | Integration | One call with batch size 1 | Deletes exactly one row | High |
| **TC-RET-007** | Integration | **NEW** — purge while a concurrent reader queries `IX_fieldOutcome_pending` | The read completes; no lock escalation observed at 4,000-row batches | Medium |
| **TC-PERF-001** | Performance | **NEW** — purge a backlog of ≥100,000 eligible rows | Completes in bounded batches; log does not grow unboundedly; review queue stays responsive. ⚠️ **Needs a populated non-production environment that does not exist** | Medium |

### `AI.fieldConstraint` (story 2.6) and `AI.fieldDescription` (story 2.7)

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| TC-CON-001 | Unit+Int | Bounds read by template, keyed by mapping | Keyed `sectionID:fieldID` via `mappingKey` | High |
| TC-CON-002 | Unit+Int | `isActive = 0` row | Not returned | High |
| TC-CON-003 | Integration | Duplicate mapping insert | Refused by `UQ_fieldConstraint_mapping` | High |
| TC-CON-004 | Integration | A band with min > max | Refused by `CK_fieldConstraint_plausibleRange` | High |
| **TC-CON-005** | Integration | **NEW** — a value exactly on `plausibleMax` (e.g. BP 200.00) | ⚠️ Documents ADR-06: `DECIMAL(6,2)` arrives as a JS double, so a boundary comparison can flip. **Expected to expose the hazard, not to pass** | 🔴 High |
| TC-DES-001 | Unit+Int | Descriptions read by template | One `fieldID` in two sections yields two distinct meanings | 🔴 High |
| TC-DES-002 | Unit | A row with a missing `description` | Refused — never `undefined` into the model's instructions | 🔴 High |
| TC-DES-003 | Unit | An empty-string description | **Preserved as a value**, not refused | High |
| TC-DES-004 | Integration | A description at the `NVARCHAR(1000)` ceiling | Round-trips without truncation | Medium |

### Cross-cutting

| ID | Category | Scenario | Expected Result | Priority |
|---|---|---|---|---|
| TC-X-001 | Unit | Lint guards, with planted violations | `process.env`, log-shape and tagged-template rules each fire | 🔴 High |
| TC-X-002 | Unit | Import proof — every `src/**` file with `env: {}` and no network | Exits 0, empty stderr, no lazy member built | 🔴 High |
| TC-X-003 | Unit | Whole unit suite with the network blocked | No process exits 99 | 🔴 High |
| **TC-X-004** | Integration | **NEW** — an SSDT publish of `pacEHR_API/PacEHR.Database` against a database carrying the `AI` schema | ⚠️ **ADR-04**: the publish must not propose dropping the four `AI` tables. Untested, unowned, and the first production apply is when it matters | 🔴 **Blocker before deployment** |

---

## Test Data Requirements

| Set | Content | Notes |
|---|---|---|
| Negative-id fixtures | `encounterID = -1`, `templetID = -1` | Outside real id ranges so stray rows are identifiable |
| Status × band matrix | 3 statuses × 3 confidence bands | TC-OUT-001/002 |
| Three-row retention fixture | old+decided, old+undecided, recent+decided | TC-RET-004 |
| Boundary numerics | exactly `plausibleMin`, `plausibleMax`, ±0.01 | TC-CON-005 |
| Ceiling string | 1,000-character description | TC-DES-004 |
| Backlog set | ≥100,000 decided rows outside the window | TC-PERF-001 — **does not exist** |

🔴 **No real PHI in any fixture.** Every value is synthetic. `proposedValue`, `acceptedValue` and
`foundIn` are PHI columns; tests populate them with invented clinical strings only.

⚠️ **Fixture hygiene defect, already recorded**: the story 2.2 and 2.3 integration tests insert
`encounterID = -1` rows and **never delete them**. The 2.4, 2.6 and 2.7 tests clean up. Fix before
TC-ENV-001 runs repeatedly, or the two growth-sensitive tables accumulate rows on DEV.

---

## Environment Requirements

| Environment | Configuration | State |
|---|---|---|
| Unit | None — no env, no credentials, network blocked | ✅ Working |
| Integration | `.env.local` with `AZURE_SQL_SERVER`, `AZURE_SQL_DATABASE`, and `AZURE_SQL_USER` + `AZURE_SQL_PASSWORD` (both or neither) | 🔴 **Absent — B11** |
| Staging | A copy of production for migration dry-runs | 🔴 **Does not exist — M11** |
| Performance | Populated with ≥100k eligible rows | 🔴 Does not exist |

⚠️ **Point integration at DEV.** These tests write to the configured database.

---

## Quality Gates

| Gate | Target | Current | Status |
|---|---|---|---|
| Unit tests pass | 100% | 121/121 | ✅ |
| Unit coverage | ≥85% | `databaseMigrations.ts` 94.94% (measured by hand) | 🟡 No coverage script — ISS-005, blocked by ISS-010 |
| Integration tests pass | 100% | **8 of 33 run; 25 never executed** | 🔴 **B11** |
| Typecheck | clean | clean | ✅ |
| Lint guards | pass, with planted violations | pass | ✅ |
| No critical/high open defects | 0 | 0 in code; **ISS-010 🟠 open in Epic 01** | 🟡 |
| Migration dry-run against staging | required before production | impossible | 🔴 **M11** |
| `post-apply-checks.sql` check #5 | 0 rows | never run | 🔴 B11 |

---

## Risks to Test Execution

| # | Risk | Effect on this plan |
|---|---|---|
| 1 | **B11** — no `.env.local` | 25 scenarios unexecutable. Blocks the whole Integration column |
| 2 | **M11** — no deployment path | TC-MIG-* cannot be run against staging; no story can be formally closed |
| 3 | **D7 / R1** — no decision writer | Every decision scenario uses a test-only path; the real workflow is untestable |
| 4 | **D4** — no retention window | The purge's happy path exists only under a test-supplied window |
| 5 | **ISS-010** — suite fails under `--experimental-test-coverage` | The coverage gate cannot be automated |
| 6 | **ADR-04** — SSDT may drop the `AI` tables | TC-X-004 is a blocker before any deployment, and nobody owns it |

---

## Schedule

Deliberately not dated. Four of the six risks above are decisions or access with no owner, and a
date against them would be fiction.

| Phase | Precondition | Sequence |
|---|---|---|
| Test planning | — | ✅ Complete (this document) |
| **Environment enablement** | `.env.local` for DEV | **Next — TC-ENV-001/002/003** |
| Execute existing integration suite | TC-ENV-001 | Immediately after |
| Implement NEW scenarios | the above green | TC-MIG-006, TC-RUN-005, TC-OUT-007, TC-RET-007, TC-CON-005 |
| ADR-04 verification | a staging database | TC-X-004 — before any deployment |
| Performance | a populated environment | TC-PERF-001 — last |

---

## Summary

| | Count |
|---|---|
| Scenarios specified | **38** |
| Already implemented | 31 |
| New in this plan | **7** (TC-ENV-001/002/003, TC-MIG-006, TC-RUN-005, TC-OUT-007, TC-RET-007, TC-CON-005, TC-X-004, TC-PERF-001) |
| Executable today | **13** (unit only) |
| Blocked on B11 | **25** |

**The headline for QA validation**: this epic does not need more tests written. It needs the ones
that exist to be run once.
