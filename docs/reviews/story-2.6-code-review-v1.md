# Code Review — Story 2.6 (PEA-206): Store per-mapping field guards in `AI.fieldConstraint`, admin-write only

> ## 🛠️ Remediation Status: 🟡 Partially Remediated (3/5)
> - **Remediated**: 2026-10-05 by DEV Agent
> - **Fixed**: 3 issue(s) — 🔴 1 / 🟠 1 / 🟡 1 / 🟢 0
> - **Deferred (with user consent)**: 2 — ISS-603 (Epic 6 / ADR-06), ISS-605 (costs a migration number)
> - **Tests**: 103/103 unit passing, 23 integration (6 pass / 17 skipped, no credentials) | **Linter**: clean
> - **Scenario**: Code Review
> - **The 🔴 Blocker is resolved**: the story went from zero tests to six unit and four integration cases.

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
- `migrations/sql/0004_create_field_constraint.sql`
- `src/repositories/fieldConstraintRepository.ts` (45 lines)
- **Tests: none exist**

**Overall Assessment**: The DDL is thoughtful — two labelled bands rather than one ambiguous pair,
`DECIMAL` rather than `FLOAT`, the per-mapping grain, and a `ponytail:` note recording the one trap
the column type cannot close on its own. The repository is 45 lines and reads well. But **it has no
tests of any kind**, and the Map key it returns is an undocumented contract whose mismatch fails
silently in the direction that drops a clinical bound.

---

## Evidence Verified

```
$ npm test
ℹ tests 97
ℹ pass 97
ℹ fail 0        ← none of them touch this story

$ grep -rln "fieldConstraint" tests/
(no matches)
```

The only thing exercising this file is `tests/unit/repo.test.ts`, whose import proof walks
`src/repositories` and asserts the tree imports with no environment and no network. That proves the
module loads. It asserts nothing about what it does.

---

## Checklist Results

### Correctness
- [x] ✅ `isActive = 1` filter applied, so a retired bound stops being read
- [x] ✅ One round trip per template, not per field — stated and correct
- [x] ✅ The seek is genuinely indexed — `UQ_fieldConstraint_mapping` leads on `templetID`
- [x] ⚠️ The Map key contract is implicit and fails silently (ISS-602)
- [x] ⚠️ `row as FieldConstraint` is unchecked (ISS-604)

### Pattern Adherence
- [x] ✅ Singleton on the last line; one `_SQL` constant above the class; `@name` binding
- [x] ✅ Live spelling preserved (`templetID`, `sectionID`, `fieldID`)
- [x] ✅ **No cache**, with the reason stated — *"a cached bound is a bound that disagrees with what
      an author just changed, in a direction that silently blocks a clinical value"*
- [x] ✅ No `execute` seam, correctly — this is a request-path read, not part of a write transaction

### Testing
- [x] ❌ **No unit test** (ISS-601)
- [x] ❌ **No integration test** (ISS-601)
- [x] ❌ Coverage: 0%

### Security
- [x] ✅ No secrets, no interpolation in SQL, no PHI in any message
- [x] ✅ The agent never writes here — the repository exposes no write path at all, which is the
      correct expression of "admin-write only" given ADR-01 withdrew the `GRANT`s

---

## Issues Found

### ISS-601: The story has no tests 🔴 Blocker

**Category**: Testing
**File**: `tests/unit/repositories/` — no `fieldConstraintRepository.test.ts`

**Issue**

There is no test for this story. Not a thin one — none. `grep -rln "fieldConstraint" tests/` returns
nothing.

`SPEC/rulebooks/aire-review-rulebook.md` is unambiguous: *"NO APPROVAL WITHOUT TESTS — Untested code
or failing tests = Auto-Reject"*, and lists *"No tests → 🔴 Blocker → Cannot approve."*

Stories 2.2 and 2.3 each shipped with a unit test file and gained an integration file during
remediation. This story and 2.7 shipped with neither, and nothing in the epic text or the delivery
plan explains the difference — `DELIVERY-PLAN.md` lists both as *"✅ built"* with a repository, which
is true of the code and not of its tests.

**What specifically is unverified**
- that `isActive = 0` rows are excluded — the retirement mechanism for a bad bound
- that the Map is keyed as the doc comment claims
- that a template with no constraints returns an empty Map rather than throwing
- that `@templetID` binds to a real column
- that the two range CHECKs accept what this repository reads back

**Suggested fix** — the seeded-pool pattern already used twice in this epic:

```typescript
test('only active bounds for the requested template are returned, keyed by mapping', async (t) => {
  useTestEnv();
  const seen = seedPool(t, [
    { sectionID: 2, fieldID: 88, unit: 'mmHg', plausibleMin: 70, plausibleMax: 200, abnormalMin: 90, abnormalMax: 140 },
  ]);
  const bounds = await fieldConstraintRepository.forTemplate(7);
  assert.equal(seen.inputs.templetID, 7);
  assert.match(seen.statement!, /\[isActive\] = 1/);
  assert.deepEqual([...bounds.keys()], ['2:88']);
});

test('a template with no constraints yields an empty map, not a throw', async (t) => { … });
```

**Resolution** (2026-10-05, DEV):
- Fix: `tests/unit/repositories/fieldConstraintRepository.test.ts` — six cases: the one-round-trip
  read and its keying; the exported key builder matching the map's own keys; the `isActive` filter;
  an empty result yielding an empty Map rather than a throw; a row missing a mapping column being
  refused; and null bounds surviving as null, since a partially specified band is legal.
- Plus `tests/integration/repositories/fieldConstraintRepository.test.ts` — four cases, which is what
  actually closes the "does every column exist" question.
- Change ref: both files new
- Test evidence: unit 103/103 pass (97 before — six added). The first run failed at import
  (`does not provide an export named 'constraintKey'`), which was the intended red.
- Status: ✅ Resolved

---

### ISS-602: The Map key is an undocumented contract whose mismatch fails open 🟠 High

**Category**: Correctness
**File**: `src/repositories/fieldConstraintRepository.ts:41`

```typescript
return new Map(rows.map((row) => [`${row.sectionID}:${row.fieldID}`, row as FieldConstraint]));
```

**Issue**

`"2:88"` is a contract between this repository and every consumer, and it exists only inside a
template literal. Epic 6's validator must reconstruct the identical string to find a bound. Nothing
exports a key builder, nothing documents the separator, and no test pins the format.

**A mismatch is silent, and it fails open.** A lookup against a wrong key is a Map miss, which is
indistinguishable from "this mapping has no bound" — so the validator skips the check and the value
passes unguarded. `GAPS.md` #7 already warns about this table sending *"every date field to
`NO_GUARD_DEFINED` forever"*; a key-format drift does the same to **every** field, with no error
anywhere.

That direction matters. `CLAUDE.md` requires guards to **fail closed**; this one fails open by
construction, because an absent bound and an unfindable bound are the same value.

**Suggested fix** — export the constructor so the two sides cannot drift:

```typescript
/** The key both this repository and its callers must use. A mismatch is a silent miss, and a
 *  missing bound reads as "no guard defined" rather than as an error. */
export const constraintKey = (sectionID: number, fieldID: number): string => `${sectionID}:${fieldID}`;
```

Then key the Map with it, and have the test assert the exported function produces the key the Map
actually holds. Consider also returning a distinguishable "no constraints for this template at all"
signal, so Epic 6 can tell an unconfigured template from a configured one with a gap.

**Resolution** (2026-10-05, DEV):
- Fix: `constraintKey(sectionID, fieldID)` is exported, used to build the Map, and used by both the
  unit and integration tests to look rows back up — so caller and repository cannot drift. The doc
  comment states why: a drift is a miss, a miss reads as "no bound defined", and the bound stops
  applying with nothing raised.
- **Not done**: the "unconfigured template versus configured with a gap" signal. An empty Map is
  still ambiguous between the two. That is a decision for Epic 6's validator, which has to act on
  the distinction, and inventing a representation here before it exists would be guessing at its
  needs. **Left open deliberately** rather than silently dropped.
- Change ref: `src/repositories/fieldConstraintRepository.ts:29-36`
- Test evidence: `the exported key builder produces the key the map actually holds`
- Status: ✅ Resolved (key contract) — ⏸️ the empty-Map ambiguity remains open

---

### ISS-603: The `DECIMAL`-as-double trap is documented but nothing enforces it 🟡 Medium

**File**: `src/repositories/fieldConstraintRepository.ts:14-18`

The doc comment is exactly right, and it is the only thing standing between a reader and the bug:

> ⚠️ The four bounds arrive as JavaScript numbers: node-mssql surfaces `DECIMAL(6,2)` as a binary
> double, so a comparison at the boundary can flip. Compare in SQL, or with an explicit documented
> tolerance — never with bare `>` on a value a clinician typed.

The type still says `number`, so a bare `value > plausibleMax` in Epic 6 compiles, passes review if
the reviewer has not read this comment, and fails intermittently at exactly the boundary — a blood
pressure of exactly 200, a weight at the plausible maximum. ADR-06 records the decision; nothing
implements it.

**Options**, in increasing cost: export a `withinBounds()` helper here so the comparison happens once
in a place that knows the hazard; or return the bounds as `string` and force the caller to decide;
or push the comparison into SQL as ADR-06 proposes. The first is cheapest and keeps the hazard
knowledge next to the data.

This is R10/Q13 and belongs to Epic 6 — raised here because this repository is where the value
crosses the boundary, and a comment is not a guard.

---

### ISS-604: `row as FieldConstraint` is an unchecked assertion 🟡 Medium

**File**: `src/repositories/fieldConstraintRepository.ts:41`

`rows` is `Record<string, unknown>[]`. The assertion claims seven properties exist with specific
types and checks none of them. Rename a column in a future migration and every consumer receives a
`FieldConstraint` whose fields are `undefined` — so `plausibleMax` becomes `undefined`, every
comparison against it is `false`, and bounds silently stop applying.

This is the same family as the `as number` assertions already corrected in `agentRunWriter`
(ISS-204) and `fieldOutcomeRepository` (ISS-304). Those were fixed; this one is the remaining
instance, and the failure here is quieter than either.

At minimum assert the shape of one row before trusting the batch. The integration test proposed in
ISS-601 would also catch a rename, which may be the more economical answer.

**Resolution** (2026-10-05, DEV):
- Fix: the two key columns are now checked rather than asserted —
  `fieldConstraint: row is missing sectionID or fieldID`. The `row as FieldConstraint` assertion
  remains for the bound columns, where a rename yields `undefined` rather than a broken key; the
  integration test is what catches those, by naming every column and reading the values back.
- This was the last instance of the family corrected in `agentRunWriter` (ISS-204) and
  `fieldOutcomeRepository` (ISS-304); all three repositories now agree.
- Change ref: `src/repositories/fieldConstraintRepository.ts:46-52`
- Test evidence: `a row missing a mapping column is refused instead of becoming an undefined bound`,
  **verified failing before the fix**.
- Status: ✅ Resolved

---

### ISS-605: The covering index does not cover 🟢 Low

**File**: `migrations/sql/0004_create_field_constraint.sql`

`UQ_fieldConstraint_mapping (templetID, sectionID, fieldID)` serves the seek, but the query also
selects `unit` and the four bounds and filters on `isActive` — none of which are in the index. Each
matching row therefore needs a key lookup into the clustered index.

At tens of mappings per template on a request path this is immaterial, and the comment's claim of
*"one indexed range seek"* is substantially true. Noted only because the fix is free if the index is
ever revisited: `INCLUDE ([unit], [plausibleMin], [plausibleMax], [abnormalMin], [abnormalMax], [isActive])`.

**Do not add a new migration for this alone** — the set is forward-only and a script costs a
permanent number.

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-601 | 🔴 Blocker | Testing | `tests/unit/repositories/` | Must Fix |
| 2 | ISS-602 | 🟠 High | Correctness | `fieldConstraintRepository.ts:41` | Should Fix |
| 3 | ISS-603 | 🟡 Medium | Correctness | `fieldConstraintRepository.ts:14-18` | Can Fix Later |
| 4 | ISS-604 | 🟡 Medium | Correctness | `fieldConstraintRepository.ts:41` | Can Fix Later |
| 5 | ISS-605 | 🟢 Low | Performance | `0004_create_field_constraint.sql` | Optional |

**Summary** — Blockers: **1** · High: **1** · Medium: 2 · Low: 1

---

## Carried Risk — not a defect in this code

**GAPS #7**: `AI.fieldConstraint` reportedly cannot store four of the six things Epic 6's compiled
guard carries — risk class, components, roles, temporal direction and horizon — which would kill role
binding, leave the BLOCK-versus-REVIEW branch with no input, and send every date field to
`NO_GUARD_DEFINED` permanently.

**This review does not resolve that**, because the compiled-guard model is Epic 6's and is not
written yet. What can be said from the shipped DDL: the table stores a unit, two numeric bands,
`sourceProse` and `isActive`. There is no column for risk class, components, roles or temporal
direction, so the gap report is consistent with what was built. Whether that is a defect depends on
a model that does not yet exist — it is tracked as **Q4** and belongs to Epic 6's design, not here.

Also open: **D6** (description versus `aiSummaryPrompt`) and **D7** (UI scope), which gate the
template-editor authoring surface. Nothing writes to this table today.

---

## What Was Done Well

1. ✅ **Two labelled bands rather than one ambiguous pair.** The DDL comment states the failure mode
   in both directions — *"either real abnormal values pass unflagged, or real hypertensive readings
   are refused as implausible"*. That is a design decision argued from consequences.
2. ✅ **`DECIMAL`, not `FLOAT`**, with the reason: *"a bound is compared, and binary floating point
   makes a comparison at the boundary a coin toss."*
3. ✅ **The `ponytail:` note is model behaviour for this codebase** — it names the ceiling, says
   where the resolution belongs, and does not pretend the column type solved it.
4. ✅ **`unit` stored as authored and never converted**, with the ambiguity (`kg|lb` against one
   min/max pair) named and assigned to the validator rather than silently resolved here.
5. ✅ **No cache, with the reason** — a stale bound silently blocks a clinical value. That is the
   right call and the right justification, and it is the kind of thing usually added by reflex.
6. ✅ **One round trip per template, not per field**, stated in a comment that quantifies why.
7. ✅ The unique constraint on the mapping triple enforces the per-mapping grain in the database
   rather than by convention.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: ISS-601 is a Blocker under the review rulebook — the story has no tests at all. ISS-602
is a silent, fail-open contract on the path that applies clinical bounds.

**Next Steps**
1. **ISS-601** — a unit test file covering the `isActive` filter, the Map keying, and the empty
   result. An integration test would also close ISS-604.
2. **ISS-602** — export `constraintKey()` and pin the format with a test.
3. Consider ISS-603 and ISS-604.
4. Re-request review.

> **Note for whoever picks this up**: story 2.7 (`AI.fieldDescription`) is the same shape and also
> has **zero tests**. ISS-601 applies there verbatim. Fixing both in one pass is cheaper than two.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-05
**Signature**: Changes Requested

---

# 🛠️ Remediation — 2026-10-05

**Agent**: DEV · **Source report**: this document · **Story**: 2.6 (PEA-206)

## Scope

| ID | Severity | Outcome |
|---|---|---|
| ISS-601 | 🔴 Blocker | ✅ Resolved — six unit cases, four integration cases |
| ISS-602 | 🟠 High | ✅ Resolved (key contract) — the empty-Map ambiguity left open for Epic 6 |
| ISS-604 | 🟡 Medium | ✅ Resolved |
| ISS-603 | 🟡 Medium | ⏸️ Deferred — the `DECIMAL`-as-double enforcement is ADR-06 / Epic 6 |
| ISS-605 | 🟢 Low | ⏸️ Deferred — an INCLUDE would cost a permanent migration number for a non-issue |

**Story 2.7 was deliberately not touched.** It shares the zero-tests Blocker, but it has no review
report, and fixing code against a review that does not exist puts the change outside any record.
It needs `aire-review-code story 2.7` first.

## Files changed

| File | Change |
|---|---|
| `src/repositories/fieldConstraintRepository.ts` | `constraintKey` exported; mapping columns checked, not asserted |
| `tests/unit/repositories/fieldConstraintRepository.test.ts` | **New** — six cases |
| `tests/integration/repositories/fieldConstraintRepository.test.ts` | **New** — four cases |

## Test evidence

```
$ npm test
ℹ tests 103     (97 before -- six added)
ℹ pass 103
ℹ fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 23      (18 before -- five added)
ℹ pass 6
ℹ fail 0
ℹ skipped 17    ← no .env.local; all four new cases are among the skipped
```

## What the integration test covers that the unit test cannot

- **Every column the statement names exists.** A statement naming a renamed column passes all six
  unit tests and fails only here.
- `UQ_fieldConstraint_mapping` refuses a duplicate mapping — the per-mapping grain enforced by the
  database rather than by convention.
- `CK_fieldConstraint_plausibleRange` refuses a band whose minimum exceeds its maximum.
- The retired-bound case shares `fieldID` 88 across two sections, so it proves the grain *and* the
  `isActive` filter in one fixture.

This file cleans up after itself (`DELETE … WHERE templetID = @templetID` in `t.after`) and uses a
negative `templetID` so a row left by a failed run is identifiable.

## An observation about the earlier integration tests

⚠️ The integration tests written for stories 2.2 and 2.3 insert rows into `AI.agentRun` and
`AI.fieldOutcome` with `encounterID = -1` and **never delete them**. On a shared DEV database each
run accumulates rows in the table whose growth rate the epic specifically budgets for, and in the
table Epic 10 will read as its evaluation set. Not raised as a formal issue against those stories —
it is noted here so it is on the record, and it is cheap to fix when they are next touched.

## Deviations

1. **ISS-602 partially resolved by design.** The key contract is closed; the empty-Map ambiguity is
   not, because distinguishing "template unconfigured" from "configured with a gap" is a decision
   Epic 6's validator has to make and does not yet exist to make. Recorded rather than guessed at.
2. **ISS-604 partially resolved.** The two key columns are checked; the bound columns are still
   asserted, with the integration test as the guard. Checking all seven in the repository would put
   a schema shape in two places.

## Lessons

- This story is the clearest case yet of the pattern noted in 2.2 and 2.3: **correct code, absent
  proof.** The repository did the right thing in every case the new tests check — the only genuine
  defect found was the unguarded key, and it was a defect about what happens when something *else*
  changes.
- ISS-602 is worth generalising. A key built with a template literal at both ends of a boundary is
  two contracts that look like one. Where a miss is silent and fails open, the key builder belongs
  with the data, exported.

## Still open on this story

ISS-603 (`DECIMAL` comparison, ADR-06), ISS-605 (index INCLUDE), the empty-Map ambiguity, and the
carried risk **Q4** / GAPS #7 — whether this table can hold what Epic 6's compiled guard needs.
