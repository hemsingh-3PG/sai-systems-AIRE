# Code Review — Story 2.7 (PEA-207): Store the per-mapping field description in `AI.fieldDescription`, admin-write only

**Date**: 2026-10-06
**Reviewed By**: REVIEWER Agent
**Review Number**: 2
**Review Mode**: FIX_VERIFICATION
**Status**: ✅ APPROVED

---

## Review Metadata

**Previous Review**: `docs/reviews/story-2.7-code-review-v1.md`
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
| ISS-701 | 🔴 Blocker | ✅ **Verified Resolved** |
| ISS-702 | 🟠 High | ✅ **Verified Resolved** |
| ISS-703 | 🟠 High | ✅ **Verified Resolved**, in both directions |
| ISS-704, ISS-705 | 🟡 / 🟢 | ⏸️ Deferred with consent — still open |

### ISS-701 — ✅ Verified Resolved

Zero tests became five unit cases and four integration cases. Blocker **B12** is now closed
entirely, across both stories that carried it.

### ISS-702 — ✅ Verified Resolved

```
2.6/2.7 ISS-702 constraintKey removed    : true
2.6/2.7 ISS-702 mappingKey shared        : true
```

`src/repositories/mapping.ts` owns the identity; both repositories import it; `constraintKey` is
deleted rather than kept as a re-export.

**The placement deviates from this report's own suggestion**, and the reasoning given is better than
the suggestion: the two tables are peers, so whichever owned the key would leave the other importing
a name belonging to the wrong table. A four-line module is the kind of thing `CLAUDE.md` normally
rejects, and it earns its place here by owning a contract between two modules rather than by
forwarding a call. Accepted.

### ISS-703 — ✅ Verified Resolved, in both directions

```
ISS-703 undefined description : refused -> fieldDescription: row is missing sectionID, fieldID or description
ISS-703 empty-string description: "" (must be "" not refused)
```

Both halves matter, and the second is the one that would have been easy to get wrong. The obvious
implementation — a truthiness check — would have rejected `''`, which is a **legal value** meaning
"no extra instruction for this mapping". Rejecting it would have converted a configured mapping into
an unconfigured one, which is precisely the failure ISS-704 describes. The remediation used `typeof`
and pinned the distinction with a test.

That distinction was found by writing the test, not by reading the code — the second time in this
epic, after `ABSENT` versus `ABSTAINED` in story 2.3. Both are the same shape: **a legal value that
looks like absence.**

---

## New Issues (🔴/🟠 only)

**None.** No new 🔴 or 🟠 found in the changed files.

---

## Still open — not defects in this code

- **ISS-704**: an empty Map cannot distinguish an unconfigured template from one configured with a
  gap. Shared with story 2.6; **Epic 3's decision**, since the schema builder is what must act on it.
- **D6** (description versus `aiSummaryPrompt`) and **D7** (UI scope).
- 🔴 **Nothing writes to this table.** Until D7 lands there are no descriptions, so `REQ-03-01` —
  *"the highest-value requirement in the corpus"* — is unsatisfied in practice however correct this
  repository now is. No review can close that.

---

## Approval Status

**Decision**: ✅ APPROVED

**Reason**: The Blocker and both High issues are verified resolved by execution, ISS-703 in both directions. The deviation on ISS-702 placement is better reasoned than the suggestion it replaced.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.
🟡/🟢 issues were not re-hunted, per the workflow's anti-loop protection.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-06
**Signature**: Approved
