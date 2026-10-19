# Code Review — Story 2.4 (PEA-204): Purge `AI.fieldOutcome` rows past the configured retention window

**Date**: 2026-10-06
**Reviewed By**: REVIEWER Agent
**Review Number**: 2
**Review Mode**: FIX_VERIFICATION
**Status**: ✅ APPROVED

---

## Review Metadata

**Previous Review**: `docs/reviews/story-2.4-code-review-v1.md`
**Previous Status**: ❌ CHANGES REQUESTED (2 🟠, 2 🟡, 2 🟢)
**Severity Threshold Applied**: Verification of previous issues + **new 🔴/🟠 only**
**Standard applied**: `PacEHR_AI/CLAUDE.md` per ADR-03

> ⚠️ **Disclosure**: both the code and its remediation were written by the DEV agent in this session.
> Every claim below was checked by running something.

---

## Verification method

```
$ npm test
ℹ tests 121 | pass 121 | fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 33 | pass 8 | fail 0 | skipped 25
```

Statement-level verification, by importing the live modules:

```
ISS-401 TOP(@batchSize) : true
ISS-401 batch size      : 4000
ISS-402 decided-only    : true
ISS-402 age bound kept  : true
ISS-405 ms/day exported : true
```

---

## Verification of Previous Issues

| ID | Severity | v2 Verdict |
|---|---|---|
| ISS-401 | 🟠 High | ✅ **Verified Resolved** |
| ISS-402 | 🟠 High | ✅ **Verified Resolved** (owner decision) |
| ISS-403 | 🟡 Medium | ✅ Resolved in code — ⚠️ its test is weaker than it looks (ISS-407) |
| ISS-404 | 🟡 Medium | ✅ Verified Resolved |
| ISS-405 | 🟢 Low | ✅ Verified Resolved |
| ISS-406 | 🟢 Low | ✅ Verified Resolved |

### ISS-401 — ✅ Verified Resolved

`DELETE TOP (@batchSize)` confirmed in the statement, `PURGE_BATCH_SIZE = 4000` exported, and
`purge()` loops until a batch returns short. Two unit cases pin the loop: three round trips for two
full batches plus a short one with the total asserted, and a zero-row batch ending the loop after a
single round trip.

**The constant carries its reasoning** — under SQL Server's ~5,000-lock escalation threshold on one
object — which is the number that actually decides whether the review queue blocks. That is the
difference between a tunable and a guess with a name.

**Termination checked**: the loop is `for(;;)` with no iteration cap, which would normally draw a
comment. It terminates because each iteration deletes the rows it counted, so the eligible set
strictly shrinks; a statement that threw would propagate rather than spin. Correct as written — see
ISS-408 for the defence-in-depth note.

### ISS-402 — ✅ Verified Resolved, by owner decision

`AND [decidedAtUtc] IS NOT NULL` confirmed present, and the age bound confirmed still present — both
matter, since dropping either would be a different and much worse statement.

The right thing happened procedurally: this was **escalated to the owner rather than decided by the
implementer**, because it is a clinical-workflow question. The accepted consequence — undecided rows
now accumulate with no policy — is written into the resolution block rather than left implicit.

The integration test was **rewritten rather than patched**, and the remediation record is explicit
about why: the old fixture was entirely undecided, so under the new rule it would have passed while
proving nothing. That is the correct instinct and the thing most likely to have been missed.

### ISS-404 — ✅ Verified Resolved

`src/purge.ts` mirrors `src/migrate.ts`: `void` chain, teardown `.catch()` so a pool-close failure
cannot turn a clean purge into a reported one, `process.exit(code)`. `npm run purge` and
`purge:prod` added.

**The deliberate asymmetry is right.** A refusal exits **0**, where `migrate.ts` exits 1 on failure.
Until compliance sets a window, deleting nothing is the system working as designed, and a scheduler
reading a non-zero code would alert on correct behaviour. Stated in the file's comment.

### ISS-405, ISS-406 — ✅ Verified Resolved

`MILLISECONDS_PER_DAY` is exported and imported by the integration test. The `createdUtc` comment now
says plainly that a test may age a row because there is no other way, no repository does, and a
reader grepping for writers of that column should find only this.

---

## New Issues

### ISS-407: The `useUTC` test reads a memoised pool, so it proves less than it appears to 🟡 Medium

**Category**: Testing
**File**: `tests/unit/core/database.sql-login.test.ts`

**Issue**

The ISS-403 fix is correct — `options: { encrypt: true, useUTC: true }` is in the pool config. The
test added to prove it is in the wrong file.

`database.sql-login.test.ts` already had a test that calls `useTestEnv({...with a SQL login})` and
reads `database.pool`. Both `settings()` and `database.pool` are self-overwriting memos, so by the
time the new test calls `useTestEnv({...without a login})` and reads `database.pool` again, **it gets
the object the first test built.**

Verified rather than reasoned:

```
pool auth after first read : default
pool auth after second read: default
→ SAME pool object: the second test reads a MEMOISED pool, not a fresh one
```

The assertion still passes, and it still passes for a valid reason — `useUTC` is a literal in the
source, not environment-dependent, so any built pool carries it. But the test's placement implies it
exercises a fresh configuration, and it does not. A reader would reasonably believe a second
environment was being tested here.

This is the same **one environment per test file** rule the remediation correctly applied when it
split the retention tests into three files, and then did not apply to this one.

**Suggested fix**: move it to its own file, as `database.system-identity.test.ts` and
`database.sql-login.test.ts` already demonstrate, or keep it here with a comment saying it asserts a
source-level constant on whatever pool exists and does not depend on the environment.

**Not blocking**: the production behaviour is correct and verified; this is about what the test
proves, not about what the code does.

### ISS-408: The batch loop has no iteration cap 🟢 Low

**File**: `src/jobs/fieldOutcomeRetention.ts`

`for(;;)` terminates correctly — each pass deletes the rows it counts, so the set shrinks — and a
failing statement throws rather than spinning. No defect.

Worth a cap anyway as defence in depth, because this is the one loop in the service that issues
destructive statements against production: a trigger, a rolled-back transaction, or a future `WHERE`
change that stops the set shrinking would turn a correct loop into an unbounded one, and the failure
mode is "deleting in a tight loop against the live database". A named maximum, logged if reached,
costs two lines.

---

## Issue Summary

| # | ID | Severity | Category | Status |
|---|---|---|---|---|
| 1 | ISS-407 | 🟡 Medium | Testing | Open — not blocking |
| 2 | ISS-408 | 🟢 Low | Correctness | Open — not blocking |

**Summary** — Blockers: **0** · High: **0** · Medium: 1 · Low: 1

---

## What Was Done Well

1. ✅ **Every issue was fixed, including both Lows.** No deferrals.
2. ✅ **The 🟠 that was a decision got escalated, not decided.** ISS-402 went to the owner, and the
   trade-off being accepted is recorded rather than buried.
3. ✅ **The integration test was rewritten, not patched** — and the remediation record names the
   reason: a behaviour change can leave a test green and meaningless. The three-row fixture with an
   explicit undecided control is the right shape.
4. ✅ **`PURGE_BATCH_SIZE` is traceable to a mechanism**, not to a round number that felt safe.
5. ✅ **The cutoff is computed once, before the loop** — so a long purge cannot drift its own window
   forward while running. Easy to get wrong, and not flagged in the review that prompted the change.
6. ✅ **`purge.ts`'s exit-code asymmetry is reasoned and stated.**

---

## Approval Status

**Decision**: ✅ APPROVED

**Reason**: Both High issues are verified resolved by execution, as are all four lesser ones. The two
new findings concern a test's placement and a defensive cap; neither affects the behaviour of the
shipped code.

**Carried forward, not blocking**
- **ISS-407 / ISS-408** — worth a few minutes when this area is next touched.
- 🔴 **B11** — 25 of 33 integration tests have never executed, including **every proof that the purge
  deletes the right rows**. The batching and decided-only behaviour are, at this moment, asserted in
  code that has never reached a database. This bounds what this approval means.
- **D4** — the retention window. The engineering precondition recorded in blocker **B1** is now
  cleared: D4 can land without the first unattended run being dangerous.
- **R1 / M4** — while the accepted columns have no writer, every row is undecided, so the purge will
  correctly delete nothing whatever D4 sets.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-06
**Signature**: Approved
