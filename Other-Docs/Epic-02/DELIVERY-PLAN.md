# Epic 02 — Delivery Plan, All Stories

**Date:** 2026-10-05, amended 2026-10-06, 2026-10-07 · **Target:** `pacEHR_AI` @ `e86c54e` · **Artefacts:** `Reference-Implementation/`

What is built, what is buildable, and what is blocked — per story, with the specific blocker
rather than a status colour. Written after building PEA-201 and the four unblocked table scripts,
so the blockers below are ones that were hit, not ones that were predicted.


> ✅ **Decision, 2026-10-06 — `AI.promptFragment` and `AI.fieldDescription` are withdrawn.
> PEA-205 and PEA-207 deliver no table.** The engine reuses what PacEHR already stores:
>
> | Need | Comes from (existing) | Read by |
> |---|---|---|
> | Master prompt, per account | `AI.prompt` — template prompt via `Template.encounterTempletes.promptId`, else the account's universal row, else `accountId = 0` | `dbo.usp_getPrompt` → `src/pacehr/agents/middleware/guard.ts` |
> | Section instructions | `Template.section.prompt` | template loader (PEA-303) → `TemplateSection.prompt` |
> | Field instructions | `Template.fields.prompt`, placed by `Template.templateSection` + `Template.fieldSection` | template loader (PEA-303) → `TemplateField.prompt` |
>
> `0009_create_field_description.sql`, `0010_create_prompt_fragment.sql`, both repositories and
> their tests are deleted from the branch — never pushed, never applied. **D6, D11 and D32 are
> closed** with them. Which prompt text a run used is still provable: `AI.agentRun` keeps
> `promptId` plus `promptTemplateHash`, because `AI.prompt` rows are edited in place.
>
> 🟠 **What it costs, recorded once.** `Template.fields.prompt` is per **field**, not per
> template mapping: one edit reaches every template that uses the field (PEA-301 measured one
> `displayName` edit reaching 179 of 458 templates). And `AI.prompt` has no version or
> evaluation gate, so a prompt edit goes live on the next request. Both are accepted by this
> decision. `AI.fieldConstraint` stays — no existing table holds numeric bounds
> (`Template.normals` is normal-finding phrases, not ranges).

> ✅ **Decision, 2026-10-05 — no database roles, and no `GRANT`s, in this epic.**
> `0002_create_ai_roles.sql` is withdrawn and the remaining scripts renumbered `0002`–`0005`
> (free: nothing was committed). Authority over `AI.*` is enforced **in the application** — the
> service connects as one principal, and which caller may read or write what is decided above the
> data layer.
>
> **This closes D2 and M1**, which were the hard blocker on four stories' security DoDs and on
> PEA-201's `0001`. Those DoD items are not "passed" — they are **withdrawn**, which is the
> honest reading.
>
> 🔴 **What it costs, recorded once so it is a decision and not a drift.** `AI.agentRun` is
> specified as an audit record *"no application code can have edited after the fact"*, and the
> epic's sharpest verification check was that the runtime principal held `SELECT + INSERT` only.
> Without permissions, nothing at the server refuses an `UPDATE` or `DELETE` against the audit
> table: the guarantee becomes *no application code **does** edit it*, which is a convention, not
> a control. **If the compliance claim matters, the cheap substitute is a trigger, not a role** —
> an `INSTEAD OF UPDATE, DELETE` on `AI.agentRun` that throws needs no principal, no grant and no
> provisioning. Six lines. See `HANDOFF.md` §3.

---

## 1. Status

| Story | Table | DDL | Runtime | Surface | Blocker |
|---|---|---|---|---|---|
| **PEA-201** | — (schema + roles) | ⛔ **schema script withdrawn 2026-10-07** — see below | ✅ **built** (runner, guard) | — | D2/M1 · M11 |
| **PEA-202** | `AI.agentRun` | ✅ **built** `0002` (+ `0001` transcript — multi-turn) | ✅ **built** `agentRunWriter` | — | D18 name · instrumentation has no call path yet |
| **PEA-203** | `AI.fieldOutcome` | ✅ **built** `0003` (+ `0004` evidence, `0005` field state — multi-turn) | ✅ **built** `fieldOutcomeRepository` | 🔴 M4 | D9 verdict writer · D7 UI scope |
| **PEA-204** | purge | ⏳ procedure | ⏳ job | — | 🔴 **D4 retention number** · D30 host · M3 |
| **PEA-205** | ~~`AI.promptFragment`~~ | ⛔ **withdrawn 2026-10-06** | reuses `AI.prompt` via `usp_getPrompt` (already built, Epic 4) | — | — |
| **PEA-206** | `AI.fieldConstraint` | ✅ **built** `0006` | ✅ **built** `fieldConstraintRepository` | 🔴 M6 | D29 decimal comparison · D7 |
| **PEA-207** | ~~`AI.fieldDescription`~~ | ⛔ **withdrawn 2026-10-06** | reuses `Template.fields.prompt` / `Template.section.prompt` (PEA-303) | — | — |

**Six tables are written** (`0001`–`0006`) and unit-tested; none is yet applied to a SQL Server. Two stories are withdrawn — see the 2026-10-06 decision above. `AI.extractionSession` was withdrawn on 2026-10-07: turns are grouped by `Encounter.encounter` (see `Epic-02-AI-Engine-Handover-and-Data-Design.md`).

> ✅ **Decision, 2026-10-07 — `0001_create_ai_schema.sql` is withdrawn. PEA-201 creates no schema
> script.** The AI schema already exists in every target database, carrying the pre-existing
> `AI.prompt` table, so the guarded `CREATE SCHEMA` was always a no-op where it would ever run.
> `migrations/verification/post-apply-checks.sql` check 1 still confirms the schema is present
> before anything else runs, so a target missing it fails loudly rather than failing on the first
> table script with a less legible error. PEA-201's remaining deliverable is the runner and the
> guard (`src/core/databaseMigrations.ts`), not a script. The set now starts at `0001` with
> `create_transcript`.


### Verified, in a scratch clone of `pacEHR_AI@e86c54e`

```
npm run typecheck   clean
npm test            88 pass, 0 fail      (60 before — 28 added)
npm run build       dist/migrate.js + dist/core/databaseMigrations.js emitted
```

Scope check mutation-tested against the full six-script set — each planted violation caught and
named, each removal returning the suite to green:

| Planted | Caught |
|---|---|
| `ALTER TABLE Encounter.encounter ADD aiFlag BIT` | ✅ 2 cases |
| `UPDATE Template.fields SET prompt = NULL` | ✅ 2 cases |
| `DROP TABLE [AI].[agentRun]` | ✅ 2 cases |
| unguarded `CREATE TABLE [AI].[widget]` | ✅ 1 case |

Repository behaviour mutation-tested the same way:

| Planted | Caught |
|---|---|
| `AND [decidedAtUtc] IS NULL` removed from the decision UPDATE | ✅ |
| proposal INSERT made to touch `acceptedValue` | ✅ |
| transaction rollback removed / `commit()` on the failure path | ✅ 2 each |

---

## 2. A design decision reversed while building

**PEA-201 originally banned `GO` in migration scripts. That was wrong, and it is now fixed.**

`GO` is a client-side separator the driver never sees, so the runner could not send a script
containing one — and I made that a validation rule. Building PEA-202 showed the cost: **every
spec's DDL uses `GO` between its `CREATE TABLE` and its `CREATE INDEX`**, because `CREATE INDEX`
cannot reference a table the same batch is still creating. The rule would have forced every
future script author to restructure DDL that was already reviewed.

The runner now **splits on `GO` and sends each part as its own batch**, which is what every
migration tool does. The spec DDL is used verbatim, with guards added. `batches()` is exported
and tested directly, because the batch is the unit the server actually receives — a test
asserting on whole-file text asserts on something no server ever sees.

**Cost of the reversal:** the `README.md` and `HANDOFF.md` claims about `GO` are superseded; the
unit test changed from *reject `GO`* to *`GO` splits batches* plus *a script with no statements is
rejected*. Caught before merge, which is the only time it is cheap.

---

## 3. 🔴 PEA-205 is not built, and the reason is a defect in its own spec

> ⛔ **Moot since 2026-10-06** — `AI.promptFragment` is withdrawn, so D11 never needs deciding.
> Kept because the same trap (a filtered unique index that skips all-NULL rows) applies to any
> future table keyed on optional account or template columns.

**Do not write `0007_create_prompt_fragment.sql` until D11 is settled.** The spec contradicts
itself across two sections:

- **§3.1's DDL** ships a filtered unique index:
  `WHERE ([accountId] IS NOT NULL AND [templetID] IS NOT NULL)`
- **§3.1's own inline comment** says *"use computed sentinels in a unique index"* — which is not
  what the DDL does.
- **§3.3** analyses the problem properly and **recommends sentinel `0`** (option A), noting
  `usp_getPrompt.sql` tier 3 already uses `accountId = 0` for universal prompts, and warns: *"do
  not ship a plain `UNIQUE` over nullable columns and assume it means what it reads like."*

**The filtered index is worse than either option it was meant to replace.** It enforces
uniqueness only on rows where **both** columns are non-null — that is, account-scoped
`template_override` fragments alone. A global `contract` fragment has both columns NULL, falls
outside the filter, and can be inserted **twice at the same version with no error**. Two active
v1 contract fragments is precisely the "near-duplicate forks, two simultaneously active" defect
the audit already found in the live `AI.prompt` data.

**Recommendation: adopt §3.3's option A** — `accountId` and `templetID` `NOT NULL DEFAULT 0`,
with the two conditional CHECKs testing `= 0` rather than `IS NULL`, and a plain
`UNIQUE (kind, scope, accountId, templetID, version)`. It matches existing precedent in this
exact domain and needs no filter or computed column.

This is a thirty-minute decision and a schema change afterwards. **It is the one place in this
epic where building to the written spec would have shipped a hole.**

---

## 4. What to build next, in order

### 4.1 Built in this pass

| # | Work | Story | State |
|---|---|---|---|
| 1 | `agentRunWriter.ts` — `record()` | 202 | ✅ built, 4 tests |
| 2 | `fieldOutcomeRepository.ts` — proposal, decision, pending queue | 203 | ✅ built, 7 tests |
| 3 | `fieldConstraintRepository.ts` — read by template | 206 | ✅ built |
| 4 | ~~`fieldDescriptionRepository.ts`~~ | 207 | ⛔ deleted 2026-10-06 — descriptions come from `Template.*` |
| 5 | `fieldOutcomeRetention.ts` — purge **mechanism** | 204 | ⏳ **next** — the refusal path is testable without the retention number |

**5 carries a trap, and so does 3 — both fail silently:**

- 🔴 **The retention setting must be `z.coerce.number().int().positive().optional()` — never
  `.default(0)`.** `settings.ts` throws on a missing required field, which is the fail-closed
  behaviour the purge depends on; the idiomatic zod default would turn an unmade compliance
  decision into a full-table DELETE. **Port the behaviour, not the field list.**
- 🟠 **`DECIMAL(6,2)` arrives in Node as a binary double** (D29), so a bound check at the
  boundary can flip. Push the comparison into SQL, or use an explicit documented tolerance —
  decided before the first bound check is written, not after a boundary bug is reported.

### 4.2 Blocked on a decision, not on engineering

| Decision | Blocks | Owner | Lead time |
|---|---|---|---|
| 🔴 **D4** retention period | 204's enablement | Clinical + Compliance | **longest in the epic** — two documents have already stalled on it |
| ~~D11~~ uniqueness (§3) | — | — | ⛔ closed: PEA-205 withdrawn |
| 🔴 **D2/M1** three principals | every grant | Architecture + DBA | unknown — no precedent in 2,857 SQL files |
| 🔴 **M11** deployment path | every exit criterion | DevOps | 5–8 pts, unowned |
| **D7** UI scope | 203, 205, 206, 207 surfaces | Product | decides ~31 vs ~75 points |
| ~~D6~~ description vs `aiSummaryPrompt` | — | — | ⛔ closed: `Template.fields.prompt` is the one source |
| **D18** `agentRun` vs `runAudit` | 202 | Architecture | five minutes, prevents two tables |
| ~~D32~~ prompt precedence | — | — | ⛔ closed: `usp_getPrompt`'s order is the precedence |

### 4.3 Not in the epic, on the critical path

**M11** (deployment), **M1** (principals), **M4** (review UI, or `fieldOutcome` is half-NULL
forever), **M6** (template-editor authoring — merge PEA-206b and PEA-207b, they touch the same
Angular components), **M8** (authoring validation for free text).

---

## 5. The sequence

```
NOW ───────────────────────────────────────────────────────────────────
  ✅ PEA-201 schema + roles + runner          built, verified
  ✅ 0001 transcript · 0002 agentRun · 0003 fieldOutcome   written, unit-tested
  ✅ 0004 evidence · 0005 fieldState · 0006 fieldConstraint written, unit-tested
  ⛔ extractionSession, create_ai_schema                   withdrawn 2026-10-07
  ⛔ fieldDescription · promptFragment                    withdrawn 2026-10-06
  ⏳ repositories (§4.1 items 1-5)            buildable today

IN PARALLEL, NO ENGINEERING ──────────────────────────────────────────
  D4 retention ····· start now, longest lead
  D2/M1 principals · unblocks every grant
  M11 deployment ··· unblocks every exit criterion

THEN ──────────────────────────────────────────────────────────────────
  purge enablement (after D4)
  M4 / M6 / M8 surfaces (after D7)
```

**Nothing in this epic can be *closed* until M11 exists**, because every story's exit criterion
ends in "against staging". The code can be written, reviewed and merged; it cannot be proven.
Say which half a ticket is claiming.

---

## 6. How to tell this is working

Not "stories closed" — every table here can ship correct and empty, and four will if nobody
looks:

| Signal | Reading |
|---|---|
| `AI.agentRun` rows/day vs `Log.AILogs` rows/day | the instrumented path is complete, or it is not |
| Proportion of `AI.fieldOutcome` with non-NULL `decidedAtUtc` | M4 shipped, or half the table is permanently NULL |
| Mappings with a `fieldConstraint` row ÷ total mappings | M6 shipped and is used, or the validators pass vacuously |
| `AI.agentRun` rows per distinct `promptTemplateHash` per `promptId` | more than one hash per id means an `AI.prompt` row was edited while live — expected, but it should be a decision someone remembers making |
| Purge dry-run count vs actual | the predicate means what you think |

The fourth is the cheapest fraud detector in the epic: one query, once a week.
