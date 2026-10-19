# Code Review — Story 2.7 (PEA-207): Store the per-mapping field description in `AI.fieldDescription`, admin-write only

> ## 🛠️ Remediation Status: 🟡 Partially Remediated (3/5)
> - **Remediated**: 2026-10-05 by DEV Agent
> - **Fixed**: 3 issue(s) — 🔴 1 / 🟠 2 / 🟡 0 / 🟢 0
> - **Deferred (with user consent)**: 2 — ISS-704 (one Epic 3 decision for both tables), ISS-705
> - **Tests**: 108/108 unit passing, 28 integration (7 pass / 21 skipped, no credentials) | **Linter**: clean
> - **Scenario**: Code Review
> - **The 🔴 Blocker is resolved**, and ISS-702 was fixed across *both* repositories rather than only here.

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
- `migrations/sql/0005_create_field_description.sql`
- `src/repositories/fieldDescriptionRepository.ts` (30 lines)
- **Tests: none exist**

**Overall Assessment**: Thirty lines, and the DDL reasoning is the tightest in the epic — the
composite key *is* the whole key, `name`/`type`/`unit` are deliberately absent because they already
live on `Template.fields`, and the cache warning names two Node-specific ways to break the rule
without writing anything that looks like a cache. Three problems: **no tests at all**; the Map key
is built inline here while story 2.6 now exports one for the identical identity; and a renamed
column would hand the model `undefined` as a field's meaning, silently.

This story carries **REQ-03-01**, described in the source index as *"the highest-value requirement
in the corpus."* The gap between that and its test coverage is the finding.

---

## Evidence Verified

```
$ npm test
ℹ tests 103
ℹ pass 103
ℹ fail 0        ← none of them touch this story

$ grep -rln "fieldDescription" tests/
(no matches)
```

As with story 2.6, the only thing exercising this file is `tests/unit/repo.test.ts`'s import proof,
which asserts the module loads with no environment. It asserts nothing about behaviour.

---

## Checklist Results

### Correctness
- [x] ✅ Bulk read by template, not per field — stated, and correct for the request path
- [x] ✅ The composite PK serves the seek directly; no secondary index earns its place
- [x] ⚠️ The Map key is built inline, duplicating an exported contract (ISS-702)
- [x] ⚠️ `row.description as string` is unchecked (ISS-703)

### Pattern Adherence
- [x] ✅ Singleton on the last line; one `_SQL` constant above the class; `@name` binding
- [x] ✅ Live spelling preserved (`templetID`, `sectionID`, `fieldID`)
- [x] ✅ **No cache**, with the best-argued reason in the epic — see *What Was Done Well*
- [x] ✅ No write path, which is the correct expression of "admin-write only" after ADR-01
- [x] ✅ No foreign key to `Template.*` — correct; an FK would be a write dependency on a table this
      service may only read

### Testing
- [x] ❌ **No unit test** (ISS-701)
- [x] ❌ **No integration test** (ISS-701)
- [x] ❌ Coverage: 0%

### Security
- [x] ✅ No secrets, no interpolation, no PHI — a description is authored clinical *instruction*,
      not patient data
- [x] ✅ Read-only; the agent cannot write its own instructions, which is the boundary that matters

---

## Issues Found

### ISS-701: The story has no tests 🔴 Blocker

**Category**: Testing
**File**: `tests/unit/repositories/` — no `fieldDescriptionRepository.test.ts`

**Issue**

`grep -rln "fieldDescription" tests/` returns nothing. Identical to story 2.6's ISS-601, which was
resolved earlier today — this is the remaining half of blocker **B12**.

`SPEC/rulebooks/aire-review-rulebook.md`: *"No tests → 🔴 Blocker → Cannot approve."*

**What is unverified**
- that the Map is keyed as the doc comment claims
- that a template with no descriptions returns an empty Map rather than throwing
- that `@templetID` binds to a real column, and that `description` is spelled as the statement says
- that a description long enough to hit `NVARCHAR(1000)` round-trips intact
- that the composite primary key refuses a duplicate mapping

**Suggested fix**: mirror `tests/unit/repositories/fieldConstraintRepository.test.ts` and
`tests/integration/repositories/fieldConstraintRepository.test.ts`, written today for the
same-shaped story. The seeded-pool helper and the fixture/cleanup pattern transfer directly.

**Resolution** (2026-10-05, DEV):
- Fix: `tests/unit/repositories/fieldDescriptionRepository.test.ts` — five cases: the keyed bulk
  read with one `fieldID` in two sections; an empty result yielding an empty Map; a row with a
  missing description refused; a row with a missing mapping column refused; and **an empty-string
  description surviving as a value**, since `''` means "no extra instruction for this mapping" and
  is not the same as the mapping being unconfigured.
- Plus `tests/integration/repositories/fieldDescriptionRepository.test.ts` — four cases, including a
  description at the `NVARCHAR(1000)` ceiling round-tripping without truncation, which no stubbed
  pool can check.
- Change ref: both files new
- Test evidence: unit 108/108 (103 before — five added). First run failed at import, the intended red.
- Status: ✅ Resolved

---

### ISS-702: Two independent key builders now exist for one identity 🟠 High

**Category**: Correctness / Maintainability
**File**: `src/repositories/fieldDescriptionRepository.ts:26`

**Issue**

```typescript
// fieldDescriptionRepository.ts — inline
return new Map(rows.map((row) => [`${row.sectionID}:${row.fieldID}`, row.description as string]));

// fieldConstraintRepository.ts — exported, as of today
export const constraintKey = (sectionID: number, fieldID: number): string => `${sectionID}:${fieldID}`;
```

Both key on the **same identity** — the `(sectionID, fieldID)` half of the mapping triple — and both
tables are keyed on that triple for the same measured reason (`PEA-301`: one `displayName` edit
reached 179 of 458 templates). After story 2.6's remediation the two are asymmetric: one format is
exported and pinned by a test, the other is a template literal with nothing holding it.

Two failure modes, and the second is worse:

1. **They drift.** Someone changes one separator; the other is unaffected; Epic 3's schema builder
   and Epic 6's validator now disagree about what identifies a mapping.
2. **Someone imports `constraintKey` to key descriptions.** It would work — the formats are
   identical today — and it would create a dependency from the description path onto a function
   named for constraints, in another module, which the next person to change `constraintKey` will
   not know about.

**Suggested fix**: the identity belongs to neither table. Promote it, and have both repositories use
it:

```typescript
/** The identity of one field's use within a template. Both AI.fieldConstraint and
 *  AI.fieldDescription are keyed on it, for the reason PEA-301 argues: the same fieldID recurs
 *  across sections with a different meaning each time. */
export const mappingKey = (sectionID: number, fieldID: number): string => `${sectionID}:${fieldID}`;
```

`constraintKey` can remain as a re-export if anything already depends on it. Note this is a slightly
awkward placement question — there is no shared module under `src/repositories/`, and `CLAUDE.md`
warns against creating one for a single function. Putting it in whichever repository is read first
by the schema builder, and importing it in the other, is acceptable; two copies is not.

**Resolution** (2026-10-05, DEV):
- Fix: `src/repositories/mapping.ts` exports `mappingKey(sectionID, fieldID)`. **Both** repositories
  import it; `constraintKey` is gone, and its two test files were rewired.
- **Placement decided against the review's own suggestion.** The review proposed putting the key in
  whichever repository the schema builder reads first. A separate module was chosen instead because
  `AI.fieldConstraint` and `AI.fieldDescription` are peers: whichever owned the key would leave the
  other importing a name that belongs to the wrong table, and the next person to change it would not
  know who else depends on it.
- This is a four-line module, which `CLAUDE.md` would normally question. It earns its place by
  owning a **contract between two modules**, not by forwarding a call — and the alternative was an
  arbitrary dependency direction between peers.
- Change ref: `src/repositories/mapping.ts` (new), `fieldConstraintRepository.ts`,
  `fieldDescriptionRepository.ts`
- Status: ✅ Resolved

---

### ISS-703: A renamed column would give the model `undefined` as a field's meaning 🟠 High

**Category**: Correctness
**File**: `src/repositories/fieldDescriptionRepository.ts:26`

```typescript
row.description as string
```

`rows` is `Record<string, unknown>[]`. If `description` is ever renamed, `row.description` is
`undefined`, the assertion suppresses the type error, and the Map holds `undefined` under a valid
key. The schema builder then receives a Map that *has* the key — so no "missing description" branch
fires — and puts `undefined` where the field's meaning should be.

**This lands in the model's instructions.** The `.describe()` text is, per `CLAUDE.md`,
*"the only per-field instruction the model receives… specification, not documentation."* A field
whose specification is the string `undefined` will not raise anything; it will quietly extract
worse.

That makes this a sharper version of story 2.6's ISS-604, where a bad bound at least failed in a
direction that merely stopped guarding. Here the corrupted value is sent to the model.

**Suggested fix** — check, as `fieldConstraintRepository` now does:

```typescript
const { sectionID, fieldID, description } = row;
if (typeof sectionID !== 'number' || typeof fieldID !== 'number' || typeof description !== 'string') {
  throw new Error('fieldDescription: row is missing sectionID, fieldID or description');
}
return [mappingKey(sectionID, fieldID), description];
```

`description` is `NOT NULL` in the DDL, so this can only fire on a schema change — which is exactly
when it should.

**Resolution** (2026-10-05, DEV):
- Fix: applied as suggested — all three columns checked, `fieldDescription: row is missing
  sectionID, fieldID or description`. The `as string` assertion is gone.
- **One correction to the suggested fix**: `typeof description !== 'string'` is used rather than a
  truthiness check, so an **empty-string description survives**. `''` is a legal value meaning "no
  extra instruction for this mapping"; rejecting it would have turned a valid row into an error and
  a configured mapping into an unconfigured one. A test pins it.
- Change ref: `src/repositories/fieldDescriptionRepository.ts:24-38`
- Test evidence: `a row whose description is missing is refused, not handed to the model as
  undefined` — **verified failing before the fix** — plus `an empty description is a value, not a
  missing row`.
- Status: ✅ Resolved

---

### ISS-704: A missing description is indistinguishable from an unconfigured template 🟡 Medium

**File**: `src/repositories/fieldDescriptionRepository.ts:24`

`forTemplate` returns an empty Map both when a template has no descriptions authored and when it has
some but not for the field being looked up. The schema builder cannot tell *"nobody has configured
this template"* from *"this field deliberately has no extra instruction"*.

The consequence differs from story 2.6's equivalent: there, a missing bound drops a guard; here, a
field reaches the model with no semantics, which `REQ-03-01` exists to prevent. It is the quieter
failure of the two and the one with no error path at all.

This is the same open question left deliberately unresolved in story 2.6's remediation, and it
should be settled once for both tables rather than twice — **it is Epic 3's call**, since the schema
builder is what has to act on the distinction.

---

### ISS-705: `sourceProse`'s counterpart is absent, so no description records its own provenance 🟢 Low

**File**: `migrations/sql/0005_create_field_description.sql`

`AI.fieldConstraint` stores `sourceProse` — the author's original words, beside the compiled bounds.
`AI.fieldDescription` stores only the final text, with `createdUtc`/`updatedUtc`.

That is defensible: a description *is* the prose, so there is nothing to compile from. Noted only
because D6 (description versus the existing `aiSummaryPrompt`) is still open, and if descriptions
turn out to be derived from an existing field, provenance will matter then. **No action now** — a
column added speculatively is the `yagni:` this codebase rejects.

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-701 | 🔴 Blocker | Testing | `tests/unit/repositories/` | Must Fix |
| 2 | ISS-702 | 🟠 High | Correctness | `fieldDescriptionRepository.ts:26` | Should Fix |
| 3 | ISS-703 | 🟠 High | Correctness | `fieldDescriptionRepository.ts:26` | Should Fix |
| 4 | ISS-704 | 🟡 Medium | Correctness | `fieldDescriptionRepository.ts:24` | Can Fix Later |
| 5 | ISS-705 | 🟢 Low | Documentation | `0005_create_field_description.sql` | Optional |

**Summary** — Blockers: **1** · High: **2** · Medium: 1 · Low: 1

---

## Carried Decisions — not defects

- **D6** — description versus the existing `aiSummaryPrompt`. `PEA-207 §5.4`'s sizing query should
  be run first; it may make the decision trivial. Gates Epic 3 as well.
- **D7** — UI scope, which gates the template-editor authoring surface. **Nothing writes to this
  table today**, so every description is absent until that lands, and `REQ-03-01` is unsatisfied in
  practice no matter how correct this repository is.

---

## What Was Done Well

1. ✅ **The cache warning is the best comment in the epic.** It does not say "no cache" — it names
   the two ways Node lets you build one by accident: *"a module-scope Map and an Azure Functions
   warm instance both persist across invocations."* Then it gives the consequence that is not
   obvious: *"A cached description also makes the per-call prompt hash stop matching what was
   actually sent, which is the record an audit reads."* That connects this file to `AI.agentRun`'s
   purpose, two stories away.
2. ✅ **`name`, `type` and `unit` are deliberately absent**, with the reason: they are live columns
   on `Template.fields`, and copying them would create a second source of truth that drifts
   silently. This is the discipline that `REQ-02-07` requires and the easiest one to violate.
3. ✅ **The composite key is the whole key** — no surrogate id, because nothing references a
   description by id and the mapping grain *is* the identity. The DDL comment says exactly that, and
   draws the right conclusion: one description per mapping enforced by the PK, so no secondary index
   earns its place.
4. ✅ **No foreign key to `Template.*`**, which would have been the obvious thing to add and would
   have made this service a writer-of-record against a read-only clinical table.
5. ✅ **Bulk by template, never per field**, with the round-trip cost stated rather than implied.
6. ✅ Thirty lines. Nothing here exists that does not need to.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: ISS-701 is a Blocker under the review rulebook. ISS-703 is the sharpest correctness issue
found in this epic so far, because its failure mode ends inside the model's instructions rather than
inside a log.

**Next Steps**
1. **ISS-701** — unit and integration tests, mirroring the files written for story 2.6 today.
2. **ISS-703** — check the row rather than asserting it.
3. **ISS-702** — one key builder for the mapping identity, used by both repositories.
4. Settle ISS-704 together with story 2.6's equivalent, as one Epic 3 decision.
5. Re-request review.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-05
**Signature**: Changes Requested

---

# 🛠️ Remediation — 2026-10-05

**Agent**: DEV · **Source report**: this document · **Story**: 2.7 (PEA-207)

## Scope

| ID | Severity | Outcome |
|---|---|---|
| ISS-701 | 🔴 Blocker | ✅ Resolved — five unit cases, four integration cases |
| ISS-702 | 🟠 High | ✅ Resolved — `mappingKey` shared by both repositories |
| ISS-703 | 🟠 High | ✅ Resolved |
| ISS-704 | 🟡 Medium | ⏸️ Deferred — one Epic 3 decision, to be settled for 2.6 and 2.7 together |
| ISS-705 | 🟢 Low | ⏸️ Deferred — a speculative column is the `yagni:` this codebase rejects |

## Files changed

| File | Change |
|---|---|
| `src/repositories/mapping.ts` | **New** — `mappingKey`, the identity shared by both keyed tables |
| `src/repositories/fieldDescriptionRepository.ts` | Uses `mappingKey`; all three columns checked |
| `src/repositories/fieldConstraintRepository.ts` | `constraintKey` removed in favour of `mappingKey` |
| `tests/unit/repositories/fieldDescriptionRepository.test.ts` | **New** — five cases |
| `tests/integration/repositories/fieldDescriptionRepository.test.ts` | **New** — four cases |
| `tests/unit/repositories/fieldConstraintRepository.test.ts` | Rewired to `mappingKey` |
| `tests/integration/repositories/fieldConstraintRepository.test.ts` | Rewired to `mappingKey` |

## Test evidence

```
$ npm test
ℹ tests 108     (103 before -- five added)
ℹ pass 108
ℹ fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 28      (23 before -- five added)
ℹ pass 7
ℹ fail 0
ℹ skipped 21    ← no .env.local; all four new cases are among the skipped
```

## A fix that reached beyond this story

ISS-702 was raised against story 2.7, but the defect was created by story 2.6's remediation earlier
the same day — exporting `constraintKey` made the asymmetry. Fixing it only here would have left two
builders; fixing it in both leaves one. **Story 2.6's code and both its test files were therefore
changed under this story's remediation**, which is recorded here because the change is outside the
report it is filed against.

`constraintKey` was deleted rather than kept as a re-export: nothing outside its own tests depended
on it, and `CLAUDE.md` is explicit that deleted code is deleted.

## Patterns applied

- **Fail closed** — a row that does not match the expected shape raises, naming the table
- **A guard change ships with the planted violation that proves it fires** — both refusal cases were
  verified failing first
- **The empty-string case was found by writing the test, not by reading the code** — the obvious
  truthiness check would have silently converted a configured mapping into an unconfigured one
- No bare numbers (`DESCRIPTION_MAX_LENGTH` names the column's declared ceiling), no interpolation,
  no second connection

## Deviations

1. **ISS-702 placed in a new module, against the review's suggestion.** Reasoned in the resolution
   block: peers should not depend on each other's names for a shared identity.
2. **ISS-703 implemented with `typeof`, not truthiness**, so `''` survives as a value.

## Lessons

- **A remediation can create the next review's finding.** ISS-702 did not exist this morning; story
  2.6's fix introduced it, and story 2.7's review caught it hours later. That is the process working,
  but it argues for asking "does this fix make a sibling inconsistent?" before closing one out.
- The empty-description case is the second time in this epic that **writing the test surfaced a
  distinction the code had not considered** — the first being `ABSENT` versus `ABSTAINED` in story
  2.3. Both are "a legal value that looks like absence."

## Still open on this story

ISS-704 (empty Map ambiguous between unconfigured and configured-with-a-gap — Epic 3's call, shared
with 2.6), ISS-705, and decisions **D6** and **D7**. Nothing writes to this table until D7 lands, so
`REQ-03-01` remains unsatisfied in practice however correct this repository now is.
