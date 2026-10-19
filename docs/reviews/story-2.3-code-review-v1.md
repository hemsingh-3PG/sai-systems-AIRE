# Code Review — Story 2.3 (PEA-203): Store the AI's proposal beside the clinician's decision in `AI.fieldOutcome`

> ## 🛠️ Remediation Status: 🟡 Partially Remediated (4/7)
> - **Remediated**: 2026-10-05 by DEV Agent
> - **Fixed**: 4 issue(s) — 🔴 0 / 🟠 3 / 🟡 1 / 🟢 0
> - **Deferred (with user consent)**: 3 — ISS-305, ISS-306, ISS-307. See Remediation Section.
> - **Tests**: 97/97 unit passing, 18 integration (5 pass / 13 skipped, no credentials) | **Linter**: clean
> - **Scenario**: Code Review
> - **Every mandatory 🟠 issue is resolved.** ISS-304 was fixed alongside, to stop the two
>   repositories disagreeing about how a missing result is handled.

**Date**: 2026-10-05
**Reviewed By**: REVIEWER Agent
**Review Number**: 1
**Review Mode**: INITIAL_REVIEW
**Status**: ❌ CHANGES REQUESTED

---

## Review Metadata

**Previous Review**: None
**Severity Threshold Applied**: All (🔴 🟠 🟡 🟢)
**Standard applied**: `PacEHR_AI/CLAUDE.md` per ADR-03

---

## Review Summary

**Components Reviewed**:
- `migrations/sql/0003_create_field_outcome.sql`
- `src/repositories/fieldOutcomeRepository.ts` (106 lines)
- `tests/unit/repositories/fieldOutcomeRepository.test.ts` (91 lines)

**Lines of Code**: ~145 **Tests Reviewed**: Yes

**Overall Assessment**: The DDL is excellent and the decision guard is the best-tested behaviour in
the epic — `AND [decidedAtUtc] IS NULL` with `SELECT @@ROWCOUNT`, and a test asserting a second
decision changes nothing and *says so*. Three problems, all about what is **not** there: the
invariant the whole table exists to protect — `ABSENT` ≠ `ABSTAINED` — has no test; `recordDecision`
cannot join a transaction, which Epic 9 requires; and nothing in this story has reached a database.

---

## Evidence Verified

```
$ npm test
ℹ tests 92
ℹ pass 92
ℹ fail 0

$ npm run typecheck   → clean
$ npm run test:integration
ℹ tests 13 | pass 4 | fail 0 | skipped 9      ← nothing here touches AI.fieldOutcome
```

---

## Checklist Results

### Correctness
- [x] ✅ Proposal and decision never touch each other's columns — asserted both directions
- [x] ✅ The decision guard prevents a stale screen overwriting a first decision
- [x] ✅ A system commit with a null provider is permitted, and the test says why a pairing
      constraint must never be added
- [x] ❌ **`recordDecision` cannot join a transaction** (ISS-301)
- [x] ⚠️ Unguarded `rows[0]` in both write methods (ISS-304)

### Pattern Adherence
- [x] ✅ Singleton on the last line; one `_SQL` constant per statement above the class
- [x] ✅ `@name` binding; no interpolation; computed column aliased (`AS [changed]`)
- [x] ✅ Live spelling preserved (`templetID`, `sectionID`, `fieldID`)
- [x] ✅ Confidence is a band, never a float — in the type **and** the CHECK
- [x] ⚠️ `recordProposal` has the transaction seam, `recordDecision` does not, unexplained (ISS-301)

### Testing
- [x] ✅ Seven tests; the decision-guard behaviour is thoroughly pinned
- [x] ❌ **No test writes `ABSENT` or `ABSTAINED`** (ISS-302)
- [x] ❌ **No integration test** (ISS-303)
- [x] ⚠️ No binding-completeness test, unlike `agentRunWriter` (ISS-305)

### Security
- [x] ✅ No secrets, no interpolation
- [x] ✅ `proposedValue`, `acceptedValue` and `foundIn` are PHI and never reach a log line
- [x] ⚠️ `pendingForEncounter` returns raw untyped rows carrying PHI (ISS-306)

---

## Issues Found

### ISS-301: `recordDecision` cannot join a transaction, and Epic 9 needs it to 🟠 High

**Category**: Correctness / Pattern
**File**: `src/repositories/fieldOutcomeRepository.ts:95`

**Issue**

Three write methods exist across this epic. Two take an `execute` seam; one does not:

```
agentRunWriter.record(run, execute = database.execute.bind(database))      ✅ seam
fieldOutcomeRepository.recordProposal(proposal, execute = …)               ✅ seam
fieldOutcomeRepository.recordDecision(decision)                            ❌ no seam
```

`recordProposal`'s seam is justified in its own comment — *"so a run's outcomes land with the
`AI.agentRun` row that produced them."* `recordDecision` has no such note, and no stated reason for
the asymmetry.

**Why it will bite.** Epic 9's `/ai/encounter/resolve` commits a clinician's decisions. `GAPS.md`
#17 records the requirement directly: *"Epics 9 and 10 require atomic multi-statement writes with
rollback across the form commit, the `fieldOutcome` rows and the `agentRun` row."* A resolve call
decides several fields at once and writes the encounter form — all or nothing. As written,
`recordDecision` always takes its own connection from the pool, so **it cannot be inside that
transaction**. A partial resolve would leave some fields decided and the form unwritten, with no
rollback.

The repository is specified as the only reader and writer of this table, so Epic 9 cannot work
around it without breaking that rule.

**Suggested fix** — make it symmetric with the other two:

```typescript
async recordDecision(decision: Decision, execute = database.execute.bind(database)): Promise<boolean> {
  const rows = await execute(SET_FIELD_OUTCOME_DECISION_SQL, { ...decision });
  return (rows[0]?.changed as number) === 1;
}
```

Three characters of risk, and it removes a blocker from a downstream epic. If the asymmetry **is**
deliberate — a decision genuinely must stand alone — then that belongs in a comment, because the
next reader will otherwise assume it was an oversight and add the seam anyway.

**Resolution** (2026-10-05, DEV):
- Fix: `recordDecision(decision, execute = database.execute.bind(database))` — symmetric with
  `recordProposal` and `agentRunWriter.record`. The doc comment now states the reason rather than
  leaving the symmetry to be inferred.
- Change ref: `src/repositories/fieldOutcomeRepository.ts:95-110`
- Test evidence: unit — `a decision can join the caller transaction that commits the encounter form`,
  **verified failing before the fix**. Integration — `a decision rolls back with the transaction that
  carried it` asserts the decision does **not** survive a forced rollback, which is the property Epic
  9 actually needs; the unit test alone only proves the seam is wired.
- Status: ✅ Resolved

---

### ISS-302: The invariant this table exists to protect has no test 🟠 High

**Category**: Testing
**File**: `tests/unit/repositories/fieldOutcomeRepository.test.ts:29-34`

**Issue**

The story's business context is unambiguous about what this table is for:

> this design fails the moment a row makes ABSENT and ABSTAINED indistinguishable, because
> everything downstream — edit rate, the review queue, Epic 10's metrics — is computed by querying
> `proposedStatus`, and a collapsed value makes that query lie.

**Every test uses `proposedStatus: 'FOUND'`.** The single `PROPOSAL` fixture hardcodes it, and no
test varies it. `ABSENT` and `ABSTAINED` are never written by any test in the suite.

What *is* protected: the TypeScript union (compile-time only, and not for a value crossing a
boundary) and `CK_fieldOutcome_proposedStatus` (never exercised — see ISS-303). So the distinction
the entire design rests on is currently guarded by a type annotation and an untested constraint.

The same applies to `proposedConfidence`: only `HIGH` is ever written. `MEDIUM` and `LOW` are
untested, and the band is the thing that replaced a float.

**Suggested fix**

```typescript
test('ABSENT and ABSTAINED are written distinctly and never collapse', async (t) => {
  // Production writes NA for both today: a successful extraction finding nothing, and the model
  // declining to answer. Everything downstream queries proposedStatus, so a collapsed value lies.
  for (const proposedStatus of ['FOUND', 'ABSENT', 'ABSTAINED'] as const) {
    useTestEnv();
    const seen = seedPool(t, [{ outcomeID: 1 }]);
    await fieldOutcomeRepository.recordProposal({ ...PROPOSAL, proposedStatus });
    assert.equal(seen.inputs.proposedStatus, proposedStatus);
  }
});
```

Pair it with the equivalent over the three confidence bands.

**Resolution** (2026-10-05, DEV):
- Fix: two unit tests added — `ABSENT and ABSTAINED are written distinctly and never collapse` (all
  three statuses) and `every confidence band reaches the statement as itself` (all three bands).
- **These passed on first run.** This was a coverage gap, not a defect: the repository always
  forwarded the value correctly, and nothing had ever asked it to forward anything but `FOUND`/`HIGH`.
  Recorded plainly so the fix is not read as having repaired broken behaviour.
- The real proof is the integration case, where the CHECK constraints are exercised rather than
  assumed — see ISS-303.
- Change ref: `tests/unit/repositories/fieldOutcomeRepository.test.ts`
- Status: ✅ Resolved

---

### ISS-303: Nothing in this story has reached a database 🟠 High

**Category**: Testing
**File**: `tests/integration/repositories/` — holds only `agentRunWriter.test.ts`

**Issue**

Every unit test stubs `database.pool`, so no statement here has executed against SQL Server. Four
things are therefore unverified, and all four fail only at the server:

| Unverified | Why it matters |
|---|---|
| `FK_fieldOutcome_agentRun` | A proposal written with a `runID` that has no `AI.agentRun` row is refused. Nothing proves the repository's ordering satisfies this |
| The four CHECK constraints | `proposedStatus`, `proposedConfidence`, `verdict`, `acceptedStatus` — including the one in ISS-302 |
| Every `@name` binds to a real column | A statement naming a column that does not exist passes all seven unit tests |
| `SELECT @@ROWCOUNT AS [changed]` returns what the code reads | The multi-statement batch's recordset shape is assumed, not observed |

The last one carries the decision guard — the behaviour this file's own header calls the one worth
pinning. It is pinned against a stub that returns whatever the test handed it.

A template now exists: `tests/integration/repositories/agentRunWriter.test.ts`, written during story
2.2's remediation, with the skip-reason pattern.

> ⚠️ Note carried from story 2.2: that file has **never been executed** either — there is no
> `.env.local` on this machine, so the integration suite skips. Blocker **B11**. Writing this test
> adds coverage on paper only until someone runs it.

**Resolution** (2026-10-05, DEV):
- Fix: `tests/integration/repositories/fieldOutcomeRepository.test.ts` — four cases:
  **(1)** all nine `proposedStatus` × `proposedConfidence` combinations round-trip distinctly,
  exercising `CK_fieldOutcome_proposedStatus` and `CK_fieldOutcome_proposedConfidence`;
  **(2)** a proposal naming no `AI.agentRun` row is refused by `FK_fieldOutcome_agentRun`;
  **(3)** the first decision lands, a second changes nothing, and the proposal column is untouched —
  the only place `SELECT @@ROWCOUNT AS [changed]` is read from a real recordset;
  **(4)** a decision rolls back with the transaction that carried it.
- The run row each case depends on is created through `agentRunWriter`, so the FK ordering the
  repository relies on is exercised rather than assumed.
- Change ref: `tests/integration/repositories/fieldOutcomeRepository.test.ts` (new)
- ⚠️ **Test evidence: WRITTEN BUT NEVER EXECUTED.** No `.env.local` on this machine:
  `ℹ tests 18 | pass 5 | fail 0 | skipped 13`. It compiles and skips with its reason. **It has not
  been proven to pass against a database** — blocker **B11**.
- Status: ✅ Resolved (written) — ⚠️ unverified

---

### ISS-304: Unguarded `rows[0]` in both write methods 🟡 Medium

**File**: `src/repositories/fieldOutcomeRepository.ts:86, 97`

```typescript
return rows[0].outcomeID as number;
return (rows[0].changed as number) === 1;
```

An empty recordset throws `Cannot read properties of undefined` with nothing naming the table or the
row. **This is the same defect as ISS-204 in `agentRunWriter`, which was fixed on 2026-10-05** — the
two repositories now disagree about how a missing result is handled.

```typescript
const outcomeID = rows[0]?.outcomeID;
if (typeof outcomeID !== 'number') throw new Error('fieldOutcome: insert returned no outcomeID');
return outcomeID;
```

`recordDecision` is the sharper of the two: a missing recordset would surface as a `TypeError`
during a clinician's decision commit, where the honest answer is that the decision did not land.

**Resolution** (2026-10-05, DEV):
- Fix: both methods guard the result — `fieldOutcome: insert returned no outcomeID` and
  `fieldOutcome: decision returned no rowcount`. The two `as number` assertions are gone, and the two
  repositories now agree with the ISS-204 fix applied to `agentRunWriter`.
- Change ref: `src/repositories/fieldOutcomeRepository.ts:85-90, 106-110`
- Test evidence: two unit tests seeding an empty recordset, both **verified failing before the fix**.
- Status: ✅ Resolved

---

### ISS-305: No binding-completeness test, and a trap for whoever adds one 🟡 Medium

**File**: `tests/unit/repositories/fieldOutcomeRepository.test.ts`

`agentRunWriter` has `every column the statement names is bound, so none is silently dropped`, which
derives its expectation from the statement rather than a hand-written list. `fieldOutcomeRepository`
has no equivalent, though it binds twelve columns via `{ ...proposal }` — so a column added to
`INSERT_FIELD_OUTCOME_SQL` without a matching `Proposal` field fails only at the server.

**The trap**: that test extracts placeholders with `/@(\w+)/g`. Run against
`SET_FIELD_OUTCOME_DECISION_SQL`, it captures **`ROWCOUNT`** out of `@@ROWCOUNT`:

```
DECISION placeholders: ROWCOUNT, acceptedStatus, acceptedUnit, acceptedValue, decidedByProviderID, outcomeID
```

A copied test would demand a binding for a built-in variable. Use `/(?<!@)@(\w+)/g`, and say why.

---

### ISS-306: The review queue returns raw untyped rows 🟡 Medium

**File**: `src/repositories/fieldOutcomeRepository.ts:101`

```typescript
async pendingForEncounter(encounterID: number): Promise<Record<string, unknown>[]>
```

Every other member of this epic returns a typed result. This one hands back untyped rows, so every
caller casts — and each cast is a place where `proposedStatus` can be narrowed to the wrong thing,
which is precisely ISS-302's risk one layer up.

It is also the PHI-carrying read path (`proposedValue`, `foundIn`), so the callers are the ones most
worth constraining. A `PendingOutcome` type mirroring the thirteen selected columns costs one
declaration.

---

### ISS-307: `acceptedStatus` is required where the schema allows null 🟢 Low

**File**: `src/repositories/fieldOutcomeRepository.ts:69`

`Decision.acceptedStatus: ProposedStatus` is non-optional, while
`CK_fieldOutcome_acceptedStatus` explicitly permits `NULL`. Narrower than the schema is usually
right — but here `acceptedStatus IS NULL` is the state the column was designed to hold before a
decision, and a caller clearing a decision has no representation. Either widen it or note that the
narrowing is deliberate.

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-301 | 🟠 High | Correctness | `fieldOutcomeRepository.ts:95` | Should Fix |
| 2 | ISS-302 | 🟠 High | Testing | `fieldOutcomeRepository.test.ts:29` | Should Fix |
| 3 | ISS-303 | 🟠 High | Testing | `tests/integration/repositories/` | Should Fix |
| 4 | ISS-304 | 🟡 Medium | Correctness | `fieldOutcomeRepository.ts:86,97` | Can Fix Later |
| 5 | ISS-305 | 🟡 Medium | Testing | `fieldOutcomeRepository.test.ts` | Can Fix Later |
| 6 | ISS-306 | 🟡 Medium | Maintainability | `fieldOutcomeRepository.ts:101` | Can Fix Later |
| 7 | ISS-307 | 🟢 Low | Correctness | `fieldOutcomeRepository.ts:69` | Optional |

**Summary** — Blockers: **0** · High: **3** · Medium: 3 · Low: 1

---

## Standing Risk — not a code defect, recorded because this story carries it

**`AI.fieldOutcome`'s accepted-value columns have no writer** (risk R1, GAPS #25). `recordDecision`
exists and is correct; nothing calls it, because the review surface (M4) is out of scope in Epics 9,
10 and 11 and decision D7 is open.

Until that lands, every row is proposal-only and `acceptedValue` is NULL forever — so **edit rate,
the review queue and Epic 10's evaluation set all read from a half-populated table.** That is the
one thing this story's business case promises, and it is blocked on a product decision, not on this
code. Nothing here can fix it; it should not be lost because the code looks complete.

Related and still open: **clinician identity is undefined** (Q3 / GAPS #6). `decidedByProviderID`
has no agreed source, so even once a writer exists, *"who decided this"* has no answer.

---

## What Was Done Well

1. ✅ **The decision guard is the best-reasoned behaviour in the epic.** `AND [decidedAtUtc] IS NULL`
   plus `SELECT @@ROWCOUNT AS [changed]`, with `recordDecision` returning a boolean whose doc
   comment states the semantics exactly: *"False is not an error and not a retry: it means another
   decision arrived first, and the caller should re-read rather than overwrite."*
2. ✅ **Both column-separation tests exist, in both directions** — the proposal write names no
   decision column and the decision write names no proposal column. That is the invariant stated as
   two assertions rather than one comment.
3. ✅ **The system-commit test carries a warning to the future**: *"A constraint pairing
   `decidedAtUtc` with `decidedByProviderID` would forbid exactly this row — do not add one."* That
   is a test preventing a plausible future mistake, which is rare and valuable.
4. ✅ **Three distinct indexes, each earning its place** — `IX_fieldOutcome_pending` is filtered on
   `decidedAtUtc IS NULL` and *is* the review queue.
5. ✅ **Confidence as a band in both the type and the CHECK**, with the reason stated: nothing in the
   runtime produces a calibrated probability.
6. ✅ The DDL comment explains `ABSENT` vs `ABSTAINED` in one sentence that a reader will understand
   a year from now.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: ISS-301 blocks Epic 9's atomic resolve. ISS-302 leaves the table's defining invariant
untested. ISS-303 means no statement here has executed anywhere.

**Next Steps**
1. **ISS-301** — add the `execute` seam, or document why it is absent.
2. **ISS-302** — write `ABSENT` and `ABSTAINED`; cover all three confidence bands.
3. **ISS-303** — integration test covering the FK, the four CHECKs and the `@@ROWCOUNT` shape.
4. Consider ISS-304 (align with the `agentRunWriter` fix), ISS-305, ISS-306.
5. Re-request review.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-05
**Signature**: Changes Requested

---

# 🛠️ Remediation — 2026-10-05

**Agent**: DEV · **Source report**: this document · **Story**: 2.3 (PEA-203)

## Scope

| ID | Severity | Outcome |
|---|---|---|
| ISS-301 | 🟠 High | ✅ Resolved |
| ISS-302 | 🟠 High | ✅ Resolved — was a coverage gap, not a defect |
| ISS-303 | 🟠 High | ✅ Resolved (written) — ⚠️ never executed |
| ISS-304 | 🟡 Medium | ✅ Resolved — consistency with `agentRunWriter` |
| ISS-305 | 🟡 Medium | ⏸️ Deferred — no binding-completeness test; the `@@ROWCOUNT` trap stays documented |
| ISS-306 | 🟡 Medium | ⏸️ Deferred — `pendingForEncounter` still returns untyped rows |
| ISS-307 | 🟢 Low | ⏸️ Deferred |

## Files changed

| File | Change |
|---|---|
| `src/repositories/fieldOutcomeRepository.ts` | `execute` seam on `recordDecision`; result guards on both write methods |
| `tests/unit/repositories/fieldOutcomeRepository.test.ts` | Five tests added — status coverage, band coverage, transaction seam, two empty-recordset guards |
| `tests/integration/repositories/fieldOutcomeRepository.test.ts` | **New** — four cases against a live database |

## Test evidence

```
$ npm test
ℹ tests 97      (92 before -- 5 added)
ℹ pass 97
ℹ fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 18      (13 before -- 5 added)
ℹ pass 5
ℹ fail 0
ℹ skipped 13    ← no .env.local; all four new cases are among the skipped
```

## Patterns applied

- **Fail closed** — a missing result names the table instead of throwing a bare `TypeError`
- **Tests assert behaviour, not shape** — the rollback case asserts the row is unchanged after a
  forced rollback, rather than asserting a transaction object was passed
- **Symmetry stated, not inferred** — `recordDecision`'s seam carries its reason in the doc comment
- No bare numbers, no interpolation, no second connection, no PHI in any message

## Deviations

1. **ISS-304 fixed though 🟡** — `agentRunWriter` already had this exact fix. Two repositories
   disagreeing about a missing recordset is worse than either convention alone.
2. **ISS-303 written but unverified**, as with story 2.2. Its evidence is "it compiles and skips."

## Lessons

- **ISS-302 is the useful one.** No code was wrong; the suite had simply never asked the repository
  to carry anything but the happy value. A single hardcoded fixture reused by every test quietly
  decides what the suite can discover. Where a column's *whole point* is that it distinguishes
  several values, the fixture must vary over them.
- Both this story and 2.2 ended with a correct implementation whose guarantee was untested. The
  pattern is consistent enough to act on: in this epic, **look first for the invariant the story
  describes in prose, then for the test that pins it.** Twice now, the prose existed and the test
  did not.

## Still open on this story

ISS-305, ISS-306, ISS-307. And the standing risk that is not a code defect: **`recordDecision` still
has no caller** — the review surface (M4) is out of scope and D7 is open, so `acceptedValue` stays
NULL and the table remains half-populated. The seam added here is what lets Epic 9 use it once it
exists.
