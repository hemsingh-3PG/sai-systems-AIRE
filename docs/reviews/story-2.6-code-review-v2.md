# Code Review — Story 2.6 (PEA-206): Store per-mapping field guards in `AI.fieldConstraint`, admin-write only

**Date**: 2026-10-06
**Reviewed By**: REVIEWER Agent
**Review Number**: 2
**Review Mode**: FIX_VERIFICATION
**Status**: ✅ APPROVED

---

## Review Metadata

**Previous Review**: `docs/reviews/story-2.6-code-review-v1.md`
**Previous Status**: ❌ CHANGES REQUESTED
**Severity Threshold Applied**: Verification of previous 🔴/🟠 + **new 🔴/🟠 only**
**Standard applied**: `PacEHR_AI/CLAUDE.md` per ADR-03

## Verification method

Each fix was **executed**, not read. A probe imported the live modules against a seeded pool and
printed the observed behaviour; the output is quoted per issue below. Suites at review time:

```
$ npm test
ℹ tests 108 | pass 108 | fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 28 | pass 7 | fail 0 | skipped 21
```

🔴 **The integration figure is not evidence of anything.** 21 of 28 skip for want of an `.env.local`.
Every integration case written during the four remediations has **never executed**. That is blocker
**B11**, and it bounds what any of these approvals can mean: the unit behaviour is verified, the
database behaviour is asserted in code that has not run.

---

## Verification of Previous Issues

| ID | Severity | v2 Verdict |
|---|---|---|
| ISS-601 | 🔴 Blocker | ✅ **Verified Resolved** |
| ISS-602 | 🟠 High | ✅ **Verified Resolved** — and superseded, see below |
| ISS-604 | 🟡 Medium | ✅ Verified Resolved |
| ISS-603, ISS-605 | 🟡 / 🟢 | ⏸️ Deferred with consent — still open |

### ISS-601 — ✅ Verified Resolved

Zero tests became six unit cases and four integration cases. The unit file covers the `isActive`
filter, the keying, an empty result, a row missing a mapping column, and null bounds surviving as
null. Blocker **B12** is closed for this story.

### ISS-602 — ✅ Verified Resolved, by a change made under story 2.7

```
2.6/2.7 ISS-702 constraintKey removed    : true
2.6/2.7 ISS-702 mappingKey shared        : true
```

🔴 **Read this carefully, because the fix is not the one this report proposed.** The remediation
filed against *this* report exported `constraintKey` from `fieldConstraintRepository`. Story 2.7's
review then found that this created **two independent key builders for one identity**, and story
2.7's remediation replaced it with `src/repositories/mapping.ts` exporting `mappingKey`.

So this story's code and **both its test files** were modified after its own remediation closed,
under a different story's report. That is recorded in story 2.7's remediation section, and it is
re-verified here rather than assumed:

- `constraintKey` no longer exists on `fieldConstraintRepository` — confirmed by export inspection
- `fieldConstraintRepository.forTemplate` keys via the shared `mappingKey`
- both of this story's test files were rewired and pass

**The outcome is better than the fix this report asked for.** One builder, owned by neither table.

⏸️ Still open, as the remediation stated plainly: an empty Map remains ambiguous between
"template unconfigured" and "configured with a gap". Deliberately left to Epic 3, and shared with
story 2.7's ISS-704 — it should be settled once for both tables.

### ISS-604 — ✅ Verified Resolved

```
Error: fieldConstraint: row is missing sectionID or fieldID
```

Observed firing against a row lacking the mapping columns. The bound columns remain asserted, with
the integration test as their guard — a partial fix, stated as such in the remediation rather than
claimed as complete.

---

## New Issues (🔴/🟠 only)

**None.** The `mappingKey` rewire was re-verified above rather than taken on trust, and it
introduced no new issue. No new 🔴 or 🟠 found.

---

## Process note

This story was modified **after its remediation closed**, by work filed under story 2.7. That is
unusual enough to name: a reader comparing this report's resolution blocks against the current code
would otherwise find `constraintKey` missing and conclude the record was wrong.

The sequence was: 2.6 remediation exports `constraintKey` → 2.7 review finds the resulting asymmetry
→ 2.7 remediation replaces it with `mappingKey` in both repositories. **A remediation created the
next review's finding**, which is the process working, but it argues for asking *"does this fix make
a sibling inconsistent?"* before closing one out.

---

## Approval Status

**Decision**: ✅ APPROVED

**Reason**: The Blocker is resolved — zero tests became ten cases. ISS-602 is resolved by a better fix than this report proposed, re-verified here because it landed under a different story. ISS-604 is resolved as far as it was scoped to be.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.
🟡/🟢 issues were not re-hunted, per the workflow's anti-loop protection.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-06
**Signature**: Approved
