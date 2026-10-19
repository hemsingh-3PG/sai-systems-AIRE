# Code Review — Story 2.4 (PEA-204): Purge `AI.fieldOutcome` rows past the configured retention window

> ## 🛠️ Remediation Status: ✅ Resolved
> - **Remediated**: 2026-10-06 by DEV Agent
> - **Fixed**: 6 issue(s) — 🔴 0 / 🟠 2 / 🟡 2 / 🟢 2 — **every issue raised**
> - **Deferred**: none
> - **Tests**: 121/121 unit passing, 33 integration (8 pass / 25 skipped, no credentials) | **Linter**: clean
> - **Scenario**: Code Review
> - ISS-402 was settled by an **owner decision**, not by the implementer: undecided rows are preserved.

**Date**: 2026-10-06
**Reviewed By**: REVIEWER Agent
**Review Number**: 1
**Review Mode**: INITIAL_REVIEW
**Status**: ❌ CHANGES REQUESTED

---

## Review Metadata

**Previous Review**: None
**Severity Threshold Applied**: All (🔴 🟠 🟡 🟢)
**Standard applied**: `PacEHR_AI/CLAUDE.md` per ADR-03

> ⚠️ **Disclosure**: the code under review was written by the DEV agent in this same session. The
> review was conducted adversarially — every claim below was checked by reading `node_modules` or
> running something, not by trusting the implementer's account.

---

## 🔴 Mandatory DoD Sign-Off

The story's Definition of Done carries an item that explicitly requires a reviewer, not the author:

> 🔴 **A reviewer has explicitly confirmed the schema is `.optional()` and NOT `.default(0)`**

**Confirmed.** `src/core/settings.ts`:

```typescript
AI_FIELD_OUTCOME_RETENTION_DAYS: z.preprocess(unsetIfBlank, z.coerce.number().int().positive().optional()),
```

| Guard | Stops | Verified by |
|---|---|---|
| `.optional()` | an **unset** window becoming `0` | `settings().aiFieldOutcomeRetentionDays === undefined` |
| `.positive()` | an **explicitly set** `0` | `settings()` throws naming the variable |
| `.int()` | a fractional window | schema |
| `unsetIfBlank` | `''` from `.env.example` reaching coercion as `0` | `z.coerce.number()` would make `''` → `0` without it |

That last row matters and is not in the DoD: `z.coerce.number()` coerces `''` to **0**. Without the
`unsetIfBlank` preprocessor — which this schema applies to every field as a house rule — an empty
`.env.example` line would have become a zero-day window. The guard holds, but it holds because of a
convention rather than because this field asked for it. Worth knowing.

**Signed off.** ✅

---

## Review Summary

**Components Reviewed**:
- `src/core/settings.ts` (schema entry)
- `src/jobs/fieldOutcomeRetention.ts` (41 lines, new)
- `src/repositories/fieldOutcomeRepository.ts` (`DELETE_FIELD_OUTCOME_BEFORE_SQL`, `purgeBefore`)
- `package.json` (`#jobs/*` alias), `.env.example`
- `tests/unit/jobs/fieldOutcomeRetention{,.configured}.test.ts`,
  `tests/unit/core/settings.retention.test.ts`,
  `tests/integration/repositories/fieldOutcomeRetention.test.ts`

**Overall Assessment**: The guard this story exists for is correct, tested from both directions, and
signed off above. The split of policy (job) from statement (repository) is better than the epic's own
layout and is recorded as a deviation. Two real problems remain, and neither is about the guard: the
`DELETE` is **unbounded in row count**, and it makes **no distinction between decided and undecided
rows** — so depending on what D4 lands on, the first run could either stall the production database
or silently empty part of the review queue.

---

## Evidence Verified

```
$ npm test
ℹ tests 116 | pass 116 | fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 31 | pass 8 | fail 0 | skipped 23      ← the purge's row-selection proof is among the skipped
```

---

## Checklist Results

### Correctness
- [x] ✅ Unset window deletes nothing and sends **no statement at all** — the refusal precedes the driver
- [x] ✅ An explicit `0` is rejected by `settings()`
- [x] ✅ The cutoff is `now − days`, asserted to 0.01-day tolerance
- [x] ✅ `purge()` refuses rather than throwing, so a scheduled job does not crash on an unmade decision
- [x] ❌ **The DELETE is unbounded in row count** (ISS-401)
- [x] ❌ **Undecided rows are purged like any other** (ISS-402)
- [x] ⚠️ UTC correctness rests on an unstated driver default (ISS-403)

### Pattern Adherence
- [x] ✅ One `_SQL` constant, `SCREAMING_SNAKE`, above the class that runs it
- [x] ✅ `@name` binding; no interpolation; computed column aliased (`AS [purged]`)
- [x] ✅ Singleton exported on the last line, named after its class
- [x] ✅ `MILLISECONDS_PER_DAY` is a named constant, not a bare number
- [x] ✅ The 10.95M-rows/year figure and its source are recorded in a comment, per the DoD
- [x] ✅ **The repository remains the only writer of its table** — the deviation from the epic's
      layout is the correct call and is documented

### Testing
- [x] ✅ Three unit files, correctly split — `settings()` memoises, so one environment per file
- [x] ✅ The refusal line is asserted to contain no `proposedValue`/`acceptedValue`/`foundIn`
- [x] ✅ Integration test backdates two rows and asserts exactly one is purged
- [x] ⚠️ That integration test **has never executed** — B11

### Security
- [x] ✅ No secrets, no interpolation, no PHI in any log line
- [x] ✅ The refusal names the setting only

---

## Issues Found

### ISS-401: The purge is unbounded in row count 🟠 High

**Category**: Performance / Correctness
**File**: `src/repositories/fieldOutcomeRepository.ts` — `DELETE_FIELD_OUTCOME_BEFORE_SQL`

```sql
DELETE FROM [AI].[fieldOutcome]
 WHERE [createdUtc] < @cutoffUtc;
SELECT @@ROWCOUNT AS [purged]
```

**Issue**

Correct, and unbounded. Verified by inspection: nothing in the statement, the repository or the job
limits how many rows a single call deletes.

The story's own arithmetic makes the consequence concrete — **~30 rows per encounter, ~10.95M rows a
year at 1,000 AI-assisted encounters a day.** The first purge after a window is finally configured
deletes everything outside it in **one statement, one transaction**:

| Risk | Why it bites here specifically |
|---|---|
| Lock escalation | SQL Server escalates to a table lock past ~5,000 locks. This table is on the **live production database**, and the review queue reads it |
| Transaction log growth | A multi-million-row delete logs every row. On Azure SQL the log file is a sized resource |
| Blocking | For the duration, `IX_fieldOutcome_pending` readers — the clinician review queue — queue behind it |

This is the one destructive statement in the epic, pointed at the database that holds real
encounters. "It only runs when scheduled" is not mitigation; it makes the first run unattended.

**Suggested fix** — batch, which is the standard shape for a retention delete:

```sql
DELETE TOP (@batchSize) FROM [AI].[fieldOutcome]
 WHERE [createdUtc] < @cutoffUtc;
SELECT @@ROWCOUNT AS [purged]
```

and loop in `purge()` until a batch returns fewer than `@batchSize`, with `batchSize` a named
constant carrying its reasoning. Each batch is its own short transaction, locks stay row-level, and
the log can truncate between them.

**Why not a Blocker**: nothing can trigger it today — D4 is unmade, so the purge refuses, and Epic 11
has not scheduled it. It must be fixed before D4 lands, not after.

**Resolution** (2026-10-06, DEV):
- Fix: `DELETE TOP (@batchSize)`, with `purge()` looping until a batch returns fewer than it asked
  for. Each batch is its own short transaction, so locks stay row-level and the log can truncate
  between them.
- `PURGE_BATCH_SIZE = 4000`, exported, with the reasoning in its comment: **under SQL Server's
  lock-escalation threshold of roughly 5,000 locks on one object**, which is the number that decides
  whether the review queue blocks behind the purge.
- Change ref: `src/repositories/fieldOutcomeRepository.ts`, `src/jobs/fieldOutcomeRetention.ts`
- Test evidence: `the purge batches, so one call never deletes the table in a single transaction`
  (three round trips for two full batches plus a short one, totals asserted) and `a batch that
  deletes nothing ends the loop without a further round trip`. Integration: `one call deletes no more
  than its batch size`.
- Status: ✅ Resolved

---

### ISS-402: The purge does not distinguish decided from undecided rows 🟠 High

**Category**: Correctness
**File**: `src/repositories/fieldOutcomeRepository.ts`, `src/jobs/fieldOutcomeRetention.ts`

**Issue**

The predicate is `createdUtc < @cutoffUtc` and nothing else. A row with `decidedAtUtc IS NULL` — a
proposal **still waiting for a clinician** — is deleted on the same terms as one decided years ago.

`IX_fieldOutcome_pending` exists precisely to serve that queue (`WHERE [decidedAtUtc] IS NULL`). With
a long window this is harmless; with a short one it means **items silently vanish from the review
queue**, and the clinician who never got to them is never told.

Nothing in the story, the epic text or the DDL comments says this case was considered. It may well be
the intended behaviour — a proposal nobody reviewed in N years is not worth keeping — but that is a
clinical-workflow decision, and right now it is an unstated consequence of a predicate.

**Suggested fix**: raise it with D4, since the right answer depends on the window's size. If
undecided rows should survive, the predicate gains `AND [decidedAtUtc] IS NOT NULL`; if they should
not, a comment should say so, because the next reader will ask.

This also interacts with risk **R1**: the accepted-value columns have **no writer** today, so *every*
row is currently undecided. If a window were configured now, the purge would delete the entire
eligible table and leave nothing for Epic 10's evaluation set.

**Resolution** (2026-10-06, **owner decision**):
- Decision: **undecided rows are preserved.** The predicate gains `AND [decidedAtUtc] IS NOT NULL`.
  A proposal still waiting for a clinician survives the window regardless of age.
- This was put to the owner rather than decided by the implementer, because it is a clinical-workflow
  question: the review's own suggested fix was *"decide, and record the answer either way."*
- The statement's comment now records all three bounds and why each is there, so the next reader does
  not have to rediscover the reasoning.
- ⚠️ **Accepted consequence**: undecided rows now accumulate with no policy covering them. That is a
  deliberate trade — an unbounded backlog is recoverable, a silently emptied review queue is not —
  but it should be revisited when the review surface (M4) exists and the backlog becomes real.
- Change ref: `src/repositories/fieldOutcomeRepository.ts`
- Test evidence: unit `an undecided proposal is not purged, whatever its age`. Integration: a
  three-row fixture — old+decided, old+undecided, recent+decided — asserting **only the first goes**,
  with the old undecided row as the control.
- Status: ✅ Resolved

---

### ISS-403: UTC correctness depends on a driver default nobody states 🟡 Medium

**File**: `src/core/database.ts:36`, `src/jobs/fieldOutcomeRetention.ts`

`createdUtc` is `getutcdate()`. The cutoff is a JS `Date` from `Date.now()`, which the driver
converts. Whether that conversion is UTC depends on `options.useUTC`, and our pool sets only
`options: { encrypt: true }`.

**Verified correct today**: `node_modules/tedious/lib/connection.js:505` has `useUTC: true` as the
default, and nothing overrides it.

But the correctness of the only destructive statement in the epic rests on a library default that no
line in this repository asserts. Set to `false` — by an upgrade, or by someone adding a pool option —
every cutoff shifts by the host's UTC offset. On a developer machine at UTC+5:30 that is **5.5 extra
hours of deletion**, in the wrong direction, silently.

**Suggested fix**: state it, since `CLAUDE.md` requires explicit configuration over inherited defaults
for anything that matters:

```typescript
// useUTC is tedious's default, stated because createdUtc is getutcdate() and the retention cutoff
// is compared against it: a false here shifts every purge by the host's offset.
options: { encrypt: true, useUTC: true },
```

**Resolution** (2026-10-06, DEV):
- Fix: applied as suggested, comment included.
- Change ref: `src/core/database.ts:36-38`
- Test evidence: `useUTC is stated, because the retention cutoff is compared against getutcdate()`,
  asserting the built pool's config rather than the source text.
- Status: ✅ Resolved

---

### ISS-404: Nothing can actually run the purge 🟡 Medium

**File**: `src/jobs/fieldOutcomeRetention.ts`

The DoD requires `purge()` be *"invocable standalone with no dependency on a specific scheduler"*.
The class satisfies the second half — it reads no trigger. It does not satisfy the first: there is no
entrypoint. `src/migrate.ts` exists as exactly this pattern for the migration runner, and there is no
`src/purge.ts` and no `npm run purge`.

As shipped, the only way to invoke it is to import it from code that does not exist yet. That is
defensible — Epic 11 owns scheduling — but it means **the story cannot be exercised end to end by a
person**, which is also why its only real proof is an integration test that has never run.

**Suggested fix**: an entrypoint mirroring `src/migrate.ts`, with the same exit-code discipline, and
a `"purge"` script. Perhaps a dozen lines, and it makes the story demonstrable.

**Resolution** (2026-10-06, DEV):
- Fix: `src/purge.ts`, mirroring `src/migrate.ts` — same `void` chain, same teardown `.catch()` so a
  pool-close failure cannot turn a clean purge into a reported one, same exit-code discipline. Plus
  `npm run purge` and `purge:prod`.
- **One deliberate difference from `migrate.ts`**: a refusal exits **0**, not 1. Until compliance
  sets a window, deleting nothing is the correct outcome, not a failure — a scheduler reading a
  non-zero code would alert on the system working as designed.
- Kept out of `src/jobs/` for the reason `migrate.ts` is kept out of `src/core/`: every file there is
  imported by the `repo.test.ts` import proof, and an entrypoint that runs on import would fail it.
- Change ref: `src/purge.ts` (new), `package.json`
- Status: ✅ Resolved

---

### ISS-405: `MILLISECONDS_PER_DAY` is defined twice 🟢 Low

`src/jobs/fieldOutcomeRetention.ts` and `tests/integration/repositories/fieldOutcomeRetention.test.ts`
each declare it. Two copies of a conversion constant is the kind of duplication `CLAUDE.md` tolerates
across modules — but these two must agree for the test to mean anything, so exporting the one from
the job is marginally better.

**Resolution** (2026-10-06, DEV): `MILLISECONDS_PER_DAY` is exported from the job and imported by the
integration test. Status: ✅ Resolved

---

### ISS-406: The integration test writes a column no repository owns 🟢 Low

`tests/integration/repositories/fieldOutcomeRetention.test.ts` backdates rows with its own
`UPDATE [AI].[fieldOutcome] SET [createdUtc] = …`. `CLAUDE.md` makes the repository the only reader
and writer of its table; a test is not bound by that, and there is no other way to age a row.

Noted because it is the only statement in the tree that writes `createdUtc`, and a reader grepping
for writers of that column will find it in a test and wonder. One comment would settle it.

**Resolution** (2026-10-06, DEV): the comment now says exactly that — a test may age a row because
there is no other way, no repository does, and a reader grepping for writers of `createdUtc` should
find only this. Status: ✅ Resolved

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-401 | 🟠 High | Performance | `fieldOutcomeRepository.ts` | Should Fix |
| 2 | ISS-402 | 🟠 High | Correctness | `fieldOutcomeRepository.ts` | Should Fix |
| 3 | ISS-403 | 🟡 Medium | Correctness | `database.ts:36` | Can Fix Later |
| 4 | ISS-404 | 🟡 Medium | Completeness | `src/jobs/` | Can Fix Later |
| 5 | ISS-405 | 🟢 Low | Maintainability | two files | Optional |
| 6 | ISS-406 | 🟢 Low | Documentation | integration test | Optional |

**Summary** — Blockers: **0** · High: **2** · Medium: 2 · Low: 2

---

## What Was Done Well

1. ✅ **The guard is right, and tested from both sides.** `.optional()` for unset, `.positive()` for
   an explicit zero. Most implementations would have covered one.
2. ✅ **The refusal sends no statement at all.** The unit test asserts `seen.statement === undefined`
   — proving the refusal happens before the driver, not that a harmless statement was issued.
3. ✅ **`purge()` refuses rather than throwing**, with the reasoning stated: a scheduled job that
   crashes on an unmade decision is noise, and refusal is the correct steady state.
4. ✅ **Policy split from statement.** The epic put the `DELETE` in the job; `CLAUDE.md` makes the
   repository the only writer of its table. The deviation is the right call and was recorded rather
   than taken silently.
5. ✅ **The test files are split by environment**, because `settings()` memoises. Getting this wrong
   would have left only the first branch ever running — and the first attempt did get it wrong, was
   caught, and was fixed.
6. ✅ **Two pre-existing tests caught the change** — the schema-order list and `.env.example`'s
   one-line-comment rule — and were updated rather than weakened.
7. ✅ The 10.95M-rows/year figure carries its source, per `CLAUDE.md` § Numbers.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: The guard that this story exists for is correct and is signed off. But two properties of
the `DELETE` itself were never considered: it is unbounded in row count, and it treats an undecided
proposal exactly like a decided one. Both must be settled **before D4 lands**, because the moment a
window is configured, the first run is unattended.

**Next Steps**
1. **ISS-401** — batch the delete.
2. **ISS-402** — decide whether undecided rows survive, and record the answer either way. Carry it to
   the D4 conversation; note that with R1 open, *every* row is currently undecided.
3. **ISS-403** — state `useUTC: true` explicitly.
4. Consider ISS-404 so the story is demonstrable.
5. Re-request review.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-06
**Signature**: Changes Requested — with the 🔴 DoD retention-schema item **confirmed and signed off**

---

# 🛠️ Remediation — 2026-10-06

**Agent**: DEV · **Source report**: this document · **Story**: 2.4 (PEA-204)

## Scope

**Every issue raised was fixed**, including both Lows. ISS-402 was settled by the owner, not by the
implementer.

| ID | Severity | Outcome |
|---|---|---|
| ISS-401 | 🟠 High | ✅ Resolved — batched at 4,000 rows |
| ISS-402 | 🟠 High | ✅ Resolved — **owner decision**: undecided rows preserved |
| ISS-403 | 🟡 Medium | ✅ Resolved |
| ISS-404 | 🟡 Medium | ✅ Resolved — `src/purge.ts` |
| ISS-405 | 🟢 Low | ✅ Resolved |
| ISS-406 | 🟢 Low | ✅ Resolved |

## Files changed

| File | Change |
|---|---|
| `src/repositories/fieldOutcomeRepository.ts` | `DELETE TOP (@batchSize)`; `AND [decidedAtUtc] IS NOT NULL`; `purgeBefore` takes a batch size |
| `src/jobs/fieldOutcomeRetention.ts` | Batch loop; `PURGE_BATCH_SIZE` and `MILLISECONDS_PER_DAY` exported |
| `src/core/database.ts` | `useUTC: true` stated |
| `src/purge.ts` | **New** — standalone entrypoint |
| `package.json` | `purge`, `purge:prod` scripts |
| `tests/unit/jobs/fieldOutcomeRetention.configured.test.ts` | Four cases added |
| `tests/unit/core/database.sql-login.test.ts` | `useUTC` assertion |
| `tests/integration/repositories/fieldOutcomeRetention.test.ts` | Rewritten around a three-row fixture |

## Test evidence

```
$ npm test
ℹ tests 121     (116 before -- five added)
ℹ pass 121
ℹ fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 33      (31 before -- two added)
ℹ pass 8
ℹ fail 0
ℹ skipped 25    ← no .env.local
```

## The behaviour change, stated plainly

**Before**: the purge deleted every row older than the cutoff, in one statement.
**After**: it deletes, in batches of 4,000, only rows older than the cutoff **that a clinician has
decided**.

The integration test was rewritten rather than patched, because the old fixture no longer exercised
anything: both its rows were undecided, so under the new rule neither would purge and the test would
have passed while proving nothing. It now carries three rows — old+decided, old+undecided,
recent+decided — and asserts only the first goes, with the old undecided row as the explicit control.

**That is the shape of this remediation's one real lesson**: a behaviour change can leave a test
green and meaningless. Changing the predicate without rewriting the fixture would have produced a
passing suite that no longer tested the thing it was written for.

## Deviations

1. **ISS-402 was not a DEV decision.** It was escalated and answered by the owner. The accepted
   consequence — undecided rows now accumulate with no policy — is recorded in the resolution block
   rather than left implicit.
2. **`src/purge.ts` exits 0 on a refusal**, unlike `migrate.ts` which exits 1 on failure. A refusal is
   the system working correctly; a scheduler should not alert on it.

## Still open — not this story's to close

- 🔴 **B11**: 25 of 33 integration tests have never executed, including every proof that the purge
  deletes the right rows. The batching and decided-only behaviour are asserted in code that has not
  run against a database.
- **D4** — the retention window itself. Both High issues are now resolved, so the dependency recorded
  in blocker **B1** is cleared: D4 can land without the first run being dangerous.
- **R1 / M4** — while the accepted columns have no writer, every row is undecided and the purge will
  correctly delete nothing, whatever D4 sets.
