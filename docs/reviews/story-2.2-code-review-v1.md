# Code Review — Story 2.2 (PEA-202): Record one append-only `AI.agentRun` row per invocation

> ## 🛠️ Remediation Status: 🟡 Partially Remediated (4/6)
> - **Remediated**: 2026-10-05 by DEV Agent
> - **Fixed**: 4 issue(s) — 🔴 0 / 🟠 3 / 🟡 1 / 🟢 0
> - **Deferred (with user consent)**: 2 — ISS-205, ISS-206. See Remediation Section.
> - **Tests**: 92/92 unit passing, 13 integration (4 pass / 9 skipped, no credentials) | **Linter**: clean
> - **Scenario**: Code Review
> - **Every mandatory 🟠 issue is resolved.** ISS-204 was fixed opportunistically alongside ISS-202.

**Date**: 2026-10-05
**Reviewed By**: REVIEWER Agent
**Review Number**: 1
**Review Mode**: INITIAL_REVIEW
**Status**: ❌ CHANGES REQUESTED

---

## Review Metadata

**Previous Review**: None
**Previous Status**: N/A
**Files Changed Since Last Review**: All
**Severity Threshold Applied**: All (🔴 🟠 🟡 🟢)
**Standard applied**: `PacEHR_AI/CLAUDE.md` per ADR-03, not `aire-clean-architecture.md`

---

## Review Summary

**Components Reviewed**:
- `migrations/sql/0002_create_agent_run.sql`
- `src/repositories/agentRunWriter.ts` (75 lines)
- `tests/unit/repositories/agentRunWriter.test.ts` (70 lines)

**Lines of Code**: ~110 **Tests Reviewed**: Yes **Coverage**: included in the 90-test suite

**Overall Assessment**: The DDL is the strongest artefact in the epic — the two CHECK constraints
encode the fail-closed audit guarantee precisely, and the type union mirrors them so the failure
moves from a deployed INSERT to a compile. Three problems: the writer discriminates on **property
presence** rather than on `outcome`, which lets a blocked run write token counts for a model call
that never happened; the acceptance criterion carrying the entire append-only guarantee has **no
test**; and nothing exercises the CHECK constraints against a real server.

---

## Evidence Verified

```
$ npm test
ℹ tests 90
ℹ pass 90
ℹ fail 0

$ npm run typecheck
> tsc --noEmit
(clean)
```

---

## Checklist Results

### Correctness
- [x] ✅ One row per invocation; `OUTPUT INSERTED.[runID]` returns the id in one round trip
- [x] ✅ A blocked run writes its row — the fail-closed property the middleware design rests on
- [x] ❌ **A blocked run can carry model columns** (ISS-202)
- [x] ⚠️ Empty recordset produces an opaque `TypeError` (ISS-204)

### Pattern Adherence
- [x] ✅ Singleton exported on the last line, named after its class
- [x] ✅ Exactly one `_SQL` constant, `SCREAMING_SNAKE`, above its class
- [x] ✅ `@name` binding throughout; no interpolation
- [x] ✅ Live database spelling preserved (`templetID`)
- [x] ✅ `execute` seam lets the row join a transaction — correct, and well motivated
- [x] ✅ No second connection; no wrapper over a wrapper

### Testing
- [x] ✅ Four tests, each asserting a distinct behaviour
- [x] ✅ Pool seeded via `Object.defineProperty`, restored with `Reflect.deleteProperty`
- [x] ❌ **The "no update path" scenario is untested** (ISS-201)
- [x] ❌ **No integration test — the CHECK constraints are never exercised** (ISS-203)
- [x] ⚠️ No test asserts *exactly one* row is inserted (ISS-206)

### Security
- [x] ✅ No secrets, no interpolation, no PHI in any log line
- [x] ✅ `reasonCode` is a code, not free text carrying clinical detail

---

## Issues Found

### ISS-201: The append-only guarantee has no test 🟠 High

**Category**: Testing
**File**: `tests/unit/repositories/agentRunWriter.test.ts`
**Pattern Reference**: story 2.2 AC scenario 4; ADR-01

**Issue**

The story's fourth Gherkin scenario is:

```gherkin
Scenario: The repository exposes no update path
  Given src/repositories/agentRunWriter.ts
   When its module-level SQL constants are enumerated
   Then exactly one is present, INSERT_AGENT_RUN_SQL
    And no constant exists that could update or delete a row
```

**No test enumerates them.** The four existing tests cover the two row shapes, the binding
completeness and the transaction seam — all good, none this.

The code is correct today; I verified by enumeration that `agentRunWriter.ts` exports exactly
`INSERT_AGENT_RUN_SQL`. The issue is that nothing *keeps* it correct.

This matters more here than it would have when the story was written. **ADR-01 withdrew the database
roles and `GRANT`s**, so the server no longer refuses an `UPDATE` or `DELETE` on the audit table.
The DELIVERY-PLAN records the consequence: the guarantee became *"no application code **does** edit
it"* — a convention, not a control. **This test is now the whole of that convention's enforcement**,
and it does not exist.

**Suggested fix** — enumerate the module's exports, which is behaviour, not source-parsing:

```typescript
test('the module exposes one SQL constant, and it cannot change a written row', async () => {
  const module = await import('#repositories/agentRunWriter.js');
  const sql = Object.entries(module).filter(([name]) => name.endsWith('_SQL'));
  assert.deepEqual(sql.map(([name]) => name), ['INSERT_AGENT_RUN_SQL']);
  for (const [name, text] of sql) {
    assert.doesNotMatch(String(text), /\b(UPDATE|DELETE|MERGE|TRUNCATE|DROP)\b/i, name);
  }
});
```

**Why this matters**

Per the patterns doc: *a guarantee enforced by the absence of code needs the planted violation that
proves it fires.* Without this, the day someone adds `UPDATE_AGENT_RUN_SQL` to fix a wrong row, the
suite stays green and the audit table silently stops being immutable.

**Resolution** (2026-10-05, DEV):
- Fix: `the module exposes one SQL constant, and it cannot change a written row` — imports the module
  and enumerates exports ending `_SQL`, asserting the list is exactly `['INSERT_AGENT_RUN_SQL']` and
  that no constant's text contains `UPDATE`/`DELETE`/`MERGE`/`TRUNCATE`/`DROP`.
- Change ref: `tests/unit/repositories/agentRunWriter.test.ts`
- Test evidence: the guard passed immediately, as expected — the code was already correct — so it was
  **proved to fire by planting `UPDATE_AGENT_RUN_SQL`**, confirming the failure, then removing it:
  `✖ the module exposes one SQL constant … ℹ fail 2`. A guard that has never failed is not yet a guard.
- Status: ✅ Resolved

---

### ISS-202: A blocked run can write token counts for a model call that never happened 🟠 High

**Category**: Correctness
**File**: `src/repositories/agentRunWriter.ts:58-70`
**Pattern Reference**: story 2.2 AC scenario 2 — *"inputTokens, outputTokens and latencyMs are NULL
because the model was never called"*

**Issue**

`record()` decides each column by **property presence** rather than by the discriminant:

```typescript
inputTokens: 'inputTokens' in run ? run.inputTokens : null,
outputTokens: 'outputTokens' in run ? run.outputTokens : null,
```

`BlockedRun` has no `inputTokens` field, so TypeScript rejects a *fresh object literal* carrying one.
**Excess-property checking does not apply to a variable**, and `in` is a runtime check against the
actual object — so a blocked run assembled incrementally writes its tokens.

**Verified by execution** against a seeded pool:

```
blocked run wrote inputTokens = 900 | outputTokens = 120
LEAK - model columns written on a run that never reached the model
```

The caller shape that triggers this is the likely one, not a contrived one: Epic 4's middleware
accumulates telemetry across a run and *then* decides the outcome, so an object that already carries
token fields being stamped `outcome: 'BLOCKED'` on a guard jump is the natural implementation.

`CK_agentRun_reachedModel` does not catch it — that constraint permits nulls on the BLOCKED path, it
does not require them.

**Suggested fix** — switch on the discriminant, which is what the database's own constraints key on:

```typescript
async record(run: AgentRun, execute = database.execute.bind(database)): Promise<number> {
  const reached = run.outcome !== 'BLOCKED';
  const rows = await execute(INSERT_AGENT_RUN_SQL, {
    encounterID: run.encounterID,
    templetID: run.templetID,
    promptHash: reached ? run.promptHash : null,
    modelDeployment: reached ? run.modelDeployment : null,
    configVersion: reached ? run.configVersion : null,
    inputTokens: reached ? run.inputTokens : null,
    outputTokens: reached ? run.outputTokens : null,
    latencyMs: run.latencyMs ?? null,
    outcome: run.outcome,
    reasonCode: reached ? null : run.reasonCode,
  });
  …
}
```

**Why this matters**

`AI.agentRun` exists so *"show me every AI call on this chart"* has an answer no application code
edited after the fact. A blocked run reporting 900 input tokens is that answer being wrong — and
token counts are a cost and attribution signal, so the error is not cosmetic. It also contradicts the
story's own acceptance criterion, which a reader would reasonably trust.

**Resolution** (2026-10-05, DEV):
- Fix: `record()` now derives `const reached = run.outcome !== 'BLOCKED'` and keys every model column
  off it, instead of testing which keys happen to be present. `outcome` is also what the table's CHECK
  constraints key on, so code and schema now agree by construction.
- Change ref: `src/repositories/agentRunWriter.ts:58-80`
- Test evidence: `a blocked run built as a variable still writes no model columns` — **verified
  failing before the fix**, passing after. Re-ran the original probe:
  `blocked run wrote inputTokens = null | outputTokens = null → OK - nulled`.
- Status: ✅ Resolved

---

### ISS-203: No integration test — the CHECK constraints are never exercised 🟠 High

**Category**: Testing
**File**: `tests/integration/` — no `repositories/` directory exists

**Issue**

The unit tests stub `database.pool` entirely, so **no statement in this story has ever reached a SQL
Server.** The DDL's own header says the two CHECKs are *"the point of the design, not decoration"* —
and nothing verifies that the two shapes `record()` produces actually satisfy them.

`tests/integration/` currently holds `core/database`, `core/databaseMigrations` and `core/llm`.
Nothing for repositories.

Specifically unverified:
- that a `BLOCKED` row with null `promptHash`/`modelDeployment` satisfies `CK_agentRun_reachedModel`
- that a `COMMITTED` row without a `reasonCode` satisfies `CK_agentRun_blockedHasReason`
- that `OUTPUT INSERTED.[runID]` returns what the code indexes as `rows[0].runID`
- that every `@name` binds to a real column — a typo'd column name fails only at the server

That last one is the sharp edge: the unit test asserts bindings match the *statement's* placeholders,
not the *table's* columns. A statement naming a column that does not exist passes every unit test.

**Suggested fix**: `tests/integration/repositories/agentRunWriter.test.ts` writing one row of each
shape against the scratch database and reading it back, with the skip-reason pattern the existing
integration tests already use.

**Resolution** (2026-10-05, DEV):
- Fix: `tests/integration/repositories/agentRunWriter.test.ts` — three cases: a completed run
  satisfies `CK_agentRun_reachedModel`; a blocked run satisfies `CK_agentRun_blockedHasReason` with
  null model columns; and a completed run with no `promptHash` is **refused by the database**, so the
  constraint is proven to bind for any caller the type system does not reach. Each row is read back
  through `SELECT_RUN_SQL`, which also proves every `@name` binds to a real column.
- Change ref: `tests/integration/repositories/agentRunWriter.test.ts` (new)
- ⚠️ **Test evidence: WRITTEN BUT NEVER EXECUTED.** There is no `.env.local` on this machine, so the
  integration suite skips: `ℹ tests 13 | pass 4 | fail 0 | skipped 9`. The test compiles and skips
  with its reason; **it has not been proven to pass against a real database.** Agreed with the user
  in advance. It must be run once credentials exist before this issue is treated as closed.
- Status: ✅ Resolved (written) — ⚠️ unverified

---

### ISS-204: An empty recordset produces an opaque `TypeError` 🟡 Medium

**File**: `src/repositories/agentRunWriter.ts:71`

```typescript
return rows[0].runID as number;
```

If the recordset is empty, this throws `Cannot read properties of undefined (reading 'runID')` — at
exactly the moment an audit row failed to be written, with nothing naming the table or the run.

**Suggested fix**

```typescript
const runID = rows[0]?.runID;
if (typeof runID !== 'number') throw new Error('agentRun: insert returned no runID');
return runID;
```

This also removes the `as number` assertion, which currently asserts a type the driver does not
guarantee.

**Resolution** (2026-10-05, DEV):
- Fix: applied as suggested — `rows[0]?.runID` with a `typeof` check throwing
  `agentRun: insert returned no runID`. The `as number` assertion is gone.
- **Scope note**: ISS-204 is 🟡 Medium and was outside the agreed mandatory scope. It was fixed
  because it is three lines in the same method as ISS-202, and splitting them would have meant
  touching `record()` twice. Recorded rather than done silently.
- Change ref: `src/repositories/agentRunWriter.ts:76-79`
- Status: ✅ Resolved

---

### ISS-205: A run awaiting review cannot record why 🟡 Medium

**File**: `src/repositories/agentRunWriter.ts:28`

```typescript
reasonCode?: null;     // on CompletedRun
```

`CK_agentRun_blockedHasReason` is `outcome <> 'BLOCKED' OR reasonCode IS NOT NULL` — it *requires* a
reason when blocked and **permits** one otherwise. The type forbids one on any non-blocked run,
including `AWAITING_REVIEW`.

So a run that completed but needs human review cannot record *why* it needs review, even though the
schema allows it. Either widen the type to `reasonCode?: string | null`, or record in a comment that
the narrowing is deliberate and where the review reason lives instead (`AI.fieldOutcome.reasonCode`
is the plausible answer, per PEA-203).

---

### ISS-206: No test asserts exactly one row is inserted 🟢 Low

**File**: `tests/unit/repositories/agentRunWriter.test.ts`

AC scenario 1 says *"exactly one row is inserted"*. The seeded `request` stub records only the last
statement, so a second insert would be invisible. Counting `query` calls would close it — the
transaction-seam test already collects into an array and could assert length.

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-201 | 🟠 High | Testing | `tests/unit/repositories/agentRunWriter.test.ts` | Should Fix |
| 2 | ISS-202 | 🟠 High | Correctness | `src/repositories/agentRunWriter.ts:58-70` | Should Fix |
| 3 | ISS-203 | 🟠 High | Testing | `tests/integration/` | Should Fix |
| 4 | ISS-204 | 🟡 Medium | Correctness | `src/repositories/agentRunWriter.ts:71` | Can Fix Later |
| 5 | ISS-205 | 🟡 Medium | Correctness | `src/repositories/agentRunWriter.ts:28` | Can Fix Later |
| 6 | ISS-206 | 🟢 Low | Testing | `tests/unit/repositories/agentRunWriter.test.ts` | Optional |

**Summary**
- Blockers: **0**
- High: **3**
- Medium: 2
- Low: 1

> **Why ISS-202 is not a Blocker.** It writes wrong audit data, which is this table's entire purpose.
> It is held at High because `AI.agentRun` has **no call path yet** — the instrumentation arrives
> with Epic 4 — so nothing can trigger it today. It should be fixed before that call path is written,
> not after.

---

## What Was Done Well

1. ✅ **The two CHECK constraints are the best piece of design in the epic.**
   `CK_agentRun_reachedModel` makes nullability legal on exactly one path, and
   `CK_agentRun_blockedHasReason` is its mirror — every row is *"reached the model, here is the
   hash"* or *"did not, here is the reason"*. That is a genuine invariant, not a validation.
2. ✅ **The type union mirrors the constraints**, with the comment stating exactly what it buys:
   *"The database enforces both regardless — this only moves the failure from a deployed INSERT to a
   compile."* Honest about its own limits.
3. ✅ **`OUTPUT INSERTED` rather than `SCOPE_IDENTITY()`**, with the reason: one round trip, and
   unaffected by a trigger adding rows elsewhere. That second clause matters — ADR-01's recommended
   immutability trigger would have broken `SCOPE_IDENTITY()`.
4. ✅ **The `execute` seam is correct and well motivated** — *"PEA-203's rows and this row are one
   fact, and a run row without them reads as a completed run that extracted nothing."*
5. ✅ **`every column the statement names is bound, so none is silently dropped`** derives the
   expectation from the statement rather than restating a hand-written list. That test will keep
   working when a column is added.
6. ✅ Pool seeding via `Object.defineProperty` with `Reflect.deleteProperty` cleanup — exactly the
   pattern `CLAUDE.md` prescribes, and the reason expensive members are not `#private`.
7. ✅ `reasonCode` is a code, never free text — no route for a clinical value to reach the audit row.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: Three High issues. ISS-202 is a verified defect that writes misleading audit data.
ISS-201 leaves the append-only guarantee — which ADR-01 reduced to an application convention —
with no enforcement at all. ISS-203 means no statement in this story has ever reached a database.

**Next Steps**
1. Fix **ISS-202** — discriminate on `run.outcome`, not property presence. Add a test building the
   run as a variable, which is the shape that currently leaks.
2. Fix **ISS-201** — enumerate the module's `_SQL` exports.
3. Fix **ISS-203** — one integration test writing both row shapes and reading them back.
4. Consider ISS-204 and ISS-205.
5. Re-request review.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer. See ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-05
**Signature**: Changes Requested


---

# 🛠️ Remediation — 2026-10-05

**Agent**: DEV · **Source report**: this document · **Scenario**: Code Review
**Story**: 2.2 (PEA-202)

## Scope

Mandatory 🟠 confirmed with the user before any code was touched. ISS-204 (🟡) added opportunistically;
ISS-205 and ISS-206 deferred.

| ID | Severity | Outcome |
|---|---|---|
| ISS-201 | 🟠 High | ✅ Resolved |
| ISS-202 | 🟠 High | ✅ Resolved |
| ISS-203 | 🟠 High | ✅ Resolved (written) — ⚠️ never executed |
| ISS-204 | 🟡 Medium | ✅ Resolved (opportunistic) |
| ISS-205 | 🟡 Medium | ⏸️ Deferred — `AWAITING_REVIEW` still cannot carry a reason |
| ISS-206 | 🟢 Low | ⏸️ Deferred |

## Files changed

| File | Change |
|---|---|
| `src/repositories/agentRunWriter.ts` | Discriminate on `outcome`; guard the returned `runID` |
| `tests/unit/repositories/agentRunWriter.test.ts` | Two tests added — variable-built blocked run, SQL-constant enumeration |
| `tests/integration/repositories/agentRunWriter.test.ts` | **New** — three cases against a live database |
| `tests/integration/core/databaseMigrations.test.ts` | Stale role assertions corrected — see below |

## 🔴 A story 2.1 defect found during this pass

`tests/integration/core/databaseMigrations.test.ts` asserted that the three database roles
**exist** (`roleCount === 3`). **ADR-01 withdrew them**, `0001_create_ai_schema.sql` creates none,
and `post-apply-checks.sql` asserts the opposite — 0 roles, a row meaning someone reintroduced one
out of band.

The test was green only because it **skips without credentials**. It would have failed the first
time anyone ran the integration suite against a real database — exactly when it most needed to be
trustworthy.

**This was missed by story 2.1's v1 and v2 reviews**, both of which ran `npm test` but never the
integration suite. Fixed here with the user's agreement: assertions inverted to `0`, the test
renamed to `applying the set creates the schema and no database role`, and a comment recording why
the three names are still asserted — they are referenced across Epics 3, 6, 8 and 9, so their
*absence* is the thing worth checking.

## Test evidence

```
$ npm test
ℹ tests 92      (90 before -- 2 added)
ℹ pass 92
ℹ fail 0

$ npm run typecheck
> tsc --noEmit
(clean)

$ npm run test:integration
ℹ tests 13
ℹ pass 4
ℹ fail 0
ℹ skipped 9     ← no .env.local; the new tests are among the skipped
```

## Patterns applied

- **A guard change ships with the planted violation that proves it fires** — ISS-201's guard passed
  on arrival, so it was failed deliberately before being trusted
- **Discriminated union over structural probing** — `outcome` is what the database keys on
- **Fail closed** — a missing `runID` now throws with the table named, instead of a bare `TypeError`
- No bare numbers, no interpolation, no second connection, no PHI in any message

## Deviations

1. **ISS-204 fixed though out of scope** — three lines in the same method as ISS-202.
2. **ISS-203 is written but unverified**, by prior agreement. It is the only item in this pass whose
   evidence is "it compiles and skips" rather than "it ran and passed."

## Lessons

- ISS-202 existed because the writer probed *structure* (`'x' in run`) where the database keys on a
  *discriminant* (`outcome`). Wherever a table has a CHECK constraint, the code that writes it should
  branch on the same column the constraint names — then the two cannot drift.
- The stale role assertions show the cost of an architecture decision landing after its tests: ADR-01
  updated the DDL and the verification script, and nothing swept the integration suite. **When a
  decision withdraws a requirement, its tests need the same sweep as its code.**

## Still open on this story

ISS-205 (an `AWAITING_REVIEW` run cannot record why it needs review) and ISS-206 (no assertion that
exactly one row is inserted). Neither blocks.
