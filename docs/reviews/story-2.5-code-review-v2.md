# Code Review — Story 2.5 (PEA-205): Store versioned prompt fragments in `AI.promptFragment`, admin-write only

**Date**: 2026-10-06
**Reviewed By**: REVIEWER Agent
**Review Number**: 2
**Review Mode**: FIX_VERIFICATION
**Status**: ✅ APPROVED — with one deployment gate outstanding

---

## Review Metadata

**Previous Review**: `docs/reviews/story-2.5-code-review-v1.md`
**Previous Status**: ❌ CHANGES REQUESTED (1 🟠, 3 🟡, 1 🟢)
**Severity Threshold Applied**: Verification of previous issues + **new 🔴/🟠 only**
**Standard applied**: `PacEHR_AI/CLAUDE.md` per ADR-03

> ⚠️ **Disclosure**: both the code and its remediation were written by the DEV agent in this session.
> Every claim below was checked by running something.

---

## Verification method

```
$ npm test
ℹ tests 132 | pass 132 | fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 42 | pass 9 | fail 0 | skipped 33
```

The ISS-501 guard was probed across every failure shape it claims to cover, not just the one its
test asserts:

```
✅ refused     | missing fragmentText
✅ refused     | missing version
✅ refused     | missing fragmentID
✅ preserved   | empty fragmentText
✅ refused     | bad row in second position
```

The last line matters more than it looks: the guard runs inside `rows.map`, so a malformed row in
any position fails the whole read rather than only the first. A guard that checked only `rows[0]`
would have passed the written test and let a corrupted fragment through in a multi-row result —
which is the normal case, since the reader returns every applicable fragment.

---

## Verification of Previous Issues

| ID | Severity | v2 Verdict |
|---|---|---|
| ISS-501 | 🟠 High | ✅ **Verified Resolved** |
| ISS-505 | 🟢 Low | ✅ Verified Resolved |
| ISS-502 | 🟡 Medium | ⏸️ **Deferred — and it gates deployment.** See below |
| ISS-503 | 🟡 Medium | ⏸️ Deferred — unverifiable until B11 |
| ISS-504 | 🟡 Medium | ⏸️ Deferred — spans three tables |

### ISS-501 — ✅ Verified Resolved

All three columns are checked, the guard fires per row, and `''` survives as a value. All three
typed-row repositories (`fieldConstraint`, `fieldDescription`, `promptFragment`) now agree on how a
malformed row is handled.

The `typeof fragmentText !== 'string'` choice over a truthiness check is correct and was made
deliberately — an empty fragment means *"this layer contributes nothing"*, which is not a malformed
row. That distinction was discovered the hard way in story 2.7 (ISS-703) and carried over this time
rather than rediscovered, which is the point of writing it down.

### ISS-505 — ✅ Verified Resolved

The comment now states that `'contract'` leads alphabetically by coincidence and that precedence is
Epic 8's (D32). Cheap, and it removes a trap: the accidental ordering is exactly what a
precedence-ordered list would look like.

---

## New Issues

**None.** No new 🔴 or 🟠 found in the changed files.

---

## 🔴 Outstanding deployment gate — not a code defect

**ISS-502 / blocker B14.** `CK_promptFragment_templateOverride` forbids any non-`template_override`
fragment from naming a template:

```sql
CHECK (([kind]='template_override' AND [templetID]<>0) OR ([kind]<>'template_override' AND [templetID]=0))
```

The implementer added it on inference; the spec does not require it. It would make a `specialty`
fragment scoped to one template unrepresentable — a plausible Epic 8 case.

**This is forward-only DDL.** Relaxing it later means another numbered script and a permanently spent
number.

**The approval below does not cover applying this migration.** The code is correct and the constraint
is defensible; what is unresolved is whether it is *right*, and that belongs to Epic 8's author.
**Do not apply the migration set anywhere until they confirm.**

---

## What Was Done Well

1. ✅ **The guard fires per row, not just on the first.** The written test only covers a single-row
   result; the implementation is correct for the multi-row case that is actually normal here.
2. ✅ **The empty-string distinction was carried forward, not rediscovered.** Third story in a row
   where "a legal value that looks like absence" came up, and the first where it was handled right
   on the first attempt.
3. ✅ **The remediation recorded what it did not fix, and why** — three deferrals each naming the
   person or resource needed, rather than a silent partial close.
4. ✅ **It proposed a lint rule instead of claiming the problem was solved.** The same unchecked
   assertion appeared three times across stories 2.6, 2.7 and 2.5; the remediation says plainly that
   a review catching one defect three times is doing a job that belongs upstream, and suggests
   `as <Type>` on a `database.execute` result become a guard error. Suggested, not implemented,
   because a guard rule ships with its planted violation and is its own work.

---

## Approval Status

**Decision**: ✅ APPROVED

**Reason**: The 🟠 is verified resolved across every failure shape, including one the test did not
cover. No new High or Blocker issues. The three deferrals each need a person or a database, not
engineering.

**This approval covers the code. It does not authorise applying the migration** — see B14.

**Carried forward**
- 🔴 **B14 / ISS-502** — Epic 8's author must confirm the template-override constraint **before the
  migration set is applied anywhere**.
- 🟡 **ISS-503** — the filtered index's plan is unverifiable until **B11** clears.
- 🟡 **ISS-504** — `updatedUtc` is never updated, across three tables. One script should cover all.
- 📌 The suggested lint rule, which would have caught ISS-501 before review.
- 📝 Two spec defects to amend in `Other-Docs/Epic-02/epic-02-data-layer.md`: PEA-205 §4's missing
  `templetID` column, and the stale `0004_create_prompt_fragment.sql` filename.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-06
**Signature**: Approved — migration application gated on B14
