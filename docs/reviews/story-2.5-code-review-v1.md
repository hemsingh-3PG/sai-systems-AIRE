# Code Review — Story 2.5 (PEA-205): Store versioned prompt fragments in `AI.promptFragment`, admin-write only

> ## 🛠️ Remediation Status: 🟡 Partially Remediated (2/5)
> - **Remediated**: 2026-10-06 by DEV Agent
> - **Fixed**: 2 issue(s) — 🔴 0 / 🟠 1 / 🟡 0 / 🟢 1
> - **Deferred**: 3 — ISS-502 (needs Epic 8's author), ISS-503 (needs B11), ISS-504 (spans three tables)
> - **Tests**: 132/132 unit passing, 42 integration (9 pass / 33 skipped) | **Linter**: clean
> - **The 🟠 is resolved.** The three deferrals each need a person or a database, not engineering.


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

> ⚠️ **Disclosure**: this code was written by the DEV agent earlier in this session, immediately
> after the owner settled D11. Every finding below was checked by running something.

---

## Review Summary

**Components Reviewed**:
- `migrations/sql/0006_create_prompt_fragment.sql`
- `src/repositories/promptFragmentRepository.ts` (48 lines)
- `tests/unit/repositories/promptFragmentRepository.test.ts` (6 cases)
- `tests/integration/repositories/promptFragmentRepository.test.ts` (7 cases)

**Overall Assessment**: The D11 decision is implemented correctly and the two CHECK constraints added
beyond the spec are genuinely good — they stop `scope` and `accountId` contradicting each other,
which is the class of defect this table exists to replace. The fail-closed read on
`passedEvaluation` is right, and the no-write-statement test is the correct expression of "the agent
cannot author its own instructions."

**But the implementer repeated a defect he had fixed three stories earlier.** `rows as
PromptFragment[]` is the unchecked assertion corrected as ISS-604 in story 2.6 and ISS-703 in story
2.7 — and here the corrupted value is `fragmentText`, which goes straight into the model's
instructions. That is ISS-703's exact failure mode, in the one table where the payload *is* the
prompt.

---

## Evidence Verified

```
$ npm test
ℹ tests 130 | pass 130 | fail 0

$ npm run typecheck   → clean

$ validate() over the six scripts   → []   (0006 accepted by the scope check)

$ npm run test:integration
ℹ tests 42 | pass 9 | fail 0 | skipped 33
```

---

## Checklist Results

### Correctness
- [x] ✅ Sentinel `0` + plain `UNIQUE` over all five columns — every row covered, globals included
- [x] ✅ `isActive = 1 AND passedEvaluation = 'PASSED'` — the three other states fail closed
- [x] ✅ Both versions of one fragment returned; nothing collapsed, so rollback stays possible
- [x] ❌ **`rows as PromptFragment[]` is unchecked** (ISS-501)
- [x] ⚠️ `CK_promptFragment_templateOverride` is stricter than the spec (ISS-502)

### Pattern Adherence
- [x] ✅ One `_SQL` constant above its class; `@name` binding; no interpolation
- [x] ✅ Singleton on the last line; **no write statement anywhere in the module**
- [x] ✅ Live spelling preserved (`accountId`, `templetID`)
- [x] ✅ No cache, with the reason — a cached fragment breaks the prompt hash an audit reads
- [x] ⚠️ The row guard applied in 2.6 and 2.7 was not applied here (ISS-501)

### Testing
- [x] ✅ Six unit cases, seven integration cases
- [x] ✅ The module's `_SQL` exports are enumerated and asserted write-free
- [x] ✅ All four CHECK constraints have an integration case
- [x] ⚠️ 33 integration tests still never executed — **B11**

### Security
- [x] ✅ **No PHI** — fragment text is authored prompt-engineering content, noted explicitly rather
      than skipped, as the DoD requires
- [x] ✅ The agent cannot write its own instructions — structurally, not by convention

---

## Issues Found

### ISS-501: A renamed column puts `undefined` into the model's instructions 🟠 High

**Category**: Correctness
**File**: `src/repositories/promptFragmentRepository.ts:46`

```typescript
const rows = await database.execute(SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL, { accountId, templetID });
return rows as PromptFragment[];
```

**Issue**

`rows` is `Record<string, unknown>[]`. The assertion claims seven properties exist and checks none.
**Verified by execution** against a recordset missing `fragmentText`:

```
fragmentText when the column is renamed: undefined
→ undefined reaches the caller, and from there the model. Same failure as ISS-703.
```

This is the third appearance of one defect, and the second time the fix was known before the code was
written:

| Story | Issue | Outcome |
|---|---|---|
| 2.6 | ISS-604 — `row as FieldConstraint` | ✅ Fixed — mapping columns checked |
| 2.7 | ISS-703 — `row.description as string` | ✅ Fixed — all three columns checked |
| **2.5** | **ISS-501 — `rows as PromptFragment[]`** | ❌ **Not applied** |

**It matters more here than in either.** In 2.6 a corrupted bound stopped guarding. In 2.7 an
`undefined` description became a field's specification. Here `fragmentText` **is** the instruction —
a fragment of kind `contract` carries the safety rules, so an `undefined` one silently removes
*"capture, do not infer"* from the prompt and nothing raises.

**Suggested fix** — the same shape already used twice:

```typescript
return rows.map((row) => {
  const { fragmentID, kind, scope, accountId: rowAccountId, templetID: rowTempletID, version, fragmentText } = row;
  if (typeof fragmentID !== 'number' || typeof fragmentText !== 'string' || typeof version !== 'number') {
    throw new Error('promptFragment: row is missing fragmentID, version or fragmentText');
  }
  return { … } as PromptFragment;
});
```

`fragmentText` is `NOT NULL` in the DDL, so this can only fire on a schema change — which is exactly
when it should.

**Resolution** (2026-10-06, DEV):
- Fix: `activeFragments` now checks `fragmentID`, `version` and `fragmentText` on every row and
  throws `promptFragment: row is missing fragmentID, version or fragmentText`. All three repositories
  that return typed rows now agree.
- Implemented with `typeof fragmentText !== 'string'`, **not truthiness**, so an empty fragment
  survives: `''` means "this layer contributes nothing", which is not the same as a malformed row.
  That distinction is the one ISS-703 turned up in `fieldDescription`, carried over deliberately this
  time rather than rediscovered.
- Change ref: `src/repositories/promptFragmentRepository.ts:46-57`
- Test evidence: `a row missing its fragment text is refused, not handed to the model as undefined`
  — **verified failing before the fix** — plus `an empty fragment text is a value, not a missing row`.
- Status: ✅ Resolved

---

### ISS-502: The template-override CHECK is stricter than the spec, and may block Epic 8 🟡 Medium

**File**: `migrations/sql/0006_create_prompt_fragment.sql`

```sql
CONSTRAINT [CK_promptFragment_templateOverride] CHECK (
  ([kind]='template_override' AND [templetID]<>0) OR ([kind]<>'template_override' AND [templetID]=0))
```

**Issue**

This forbids **any** non-`template_override` fragment from naming a template. The spec does not say
that; it was an inference drawn while writing the DDL, and the inference may be wrong.

A plausible Epic 8 case it blocks: a `specialty` fragment that applies only to the behavioural-health
template. Under this constraint that is unrepresentable — the author would have to mislabel it
`template_override`, losing the kind distinction the vocabulary exists for.

**This is forward-only DDL.** Relaxing it later means another numbered script altering the
constraint, and a permanently spent number.

The constraint is defensible and the reasoning is sound; the problem is that it decides something
Epic 8 owns, on a table Epic 8 is the only writer of. **Confirm with Epic 8's author before this is
applied anywhere**, or split it: keep the half that requires a `template_override` to name a
template, drop the half that forbids everything else from doing so.

---

### ISS-503: The filtered index probably cannot serve the query's `OR` predicates 🟡 Medium

**File**: `migrations/sql/0006_create_prompt_fragment.sql`, `promptFragmentRepository.ts`

```sql
CREATE NONCLUSTERED INDEX [IX_promptFragment_active] ON [AI].[promptFragment]([accountId], [templetID])
    WHERE ([isActive] = 1 AND [passedEvaluation] = 'PASSED');
```

against

```sql
WHERE … AND ([accountId] = 0 OR [accountId] = @accountId)
          AND ([templetID] = 0 OR [templetID] = @templetID)
```

The index's filter matches the query's exactly — good. But SQL Server generally cannot seek on a
disjunction over an index key; it will likely scan the filtered index rather than seek it.

On a table of tens-to-hundreds of fragments that is immaterial, and the filtered index still prunes
most rows. Raised because the index was added on the assumption it would be *sought*, and that
assumption is untested — **and cannot be tested until B11 clears**, since only a real server produces
a plan. Confirm with an actual execution plan before trusting it at scale; `UNION ALL` of two seeks
is the usual rewrite if it matters.

---

### ISS-504: `updatedUtc` is never updated 🟡 Medium

**File**: `migrations/sql/0006_create_prompt_fragment.sql`

`updatedUtc DATETIME2 NOT NULL DEFAULT getutcdate()` is set on insert and **nothing ever changes it**
— this module ships no `UPDATE`, by design, and no trigger exists.

So a fragment edited by Epic 8 will carry a creation timestamp in a column named `updatedUtc` unless
Epic 8 remembers to set it explicitly. A timestamp that silently means something other than its name
is worse than no timestamp: an operator reading it to answer *"when did this prompt last change"*
gets a confidently wrong answer.

`AI.fieldConstraint` and `AI.fieldDescription` carry the identical pattern, so this is a three-table
observation, not a 2.5 defect. Either document that the writer owns it, or add an `AFTER UPDATE`
trigger — the latter in one script covering all three.

---

### ISS-505: `ORDER BY [kind]` is alphabetical, and reads as if it were precedence 🟢 Low

**File**: `promptFragmentRepository.ts`

`ORDER BY [kind] ASC` sorts `contract, specialty, task, template_override` alphabetically. The
comment correctly says the ordering "carries no precedence" and that composition is Epic 8's (D32).

But the alphabetical result happens to put `contract` — the safety layer — first, which is what a
precedence-ordered list would also do. The next reader may well take the coincidence for intent and
rely on it. A one-line comment noting that the leading position of `contract` is accidental would
cost nothing.

**Resolution** (2026-10-06, DEV): a comment above the statement now records that `'contract'` leads
alphabetically by coincidence, and that precedence is Epic 8's (D32). Status: ✅ Resolved

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-501 | 🟠 High | Correctness | `promptFragmentRepository.ts:46` | Should Fix |
| 2 | ISS-502 | 🟡 Medium | Correctness | `0006_*.sql` | Confirm with Epic 8 |
| 3 | ISS-503 | 🟡 Medium | Performance | `0006_*.sql` | Verify after B11 |
| 4 | ISS-504 | 🟡 Medium | Correctness | three tables | Can Fix Later |
| 5 | ISS-505 | 🟢 Low | Documentation | `promptFragmentRepository.ts` | Optional |

**Summary** — Blockers: **0** · High: **1** · Medium: 3 · Low: 1

---

## Spec Defects Recorded by the Implementation

Both were surfaced rather than silently resolved, which is the right handling. Recording them here so
they reach whoever owns the epic text:

1. **PEA-205 §4's column list has no `templetID`**, yet `kind` admits `'template_override'`. Such a
   fragment could not name its template. Built with `templetID INT NOT NULL DEFAULT 0`.
2. **The spec names `0004_create_prompt_fragment.sql`** — stale since the ADR-01 renumbering. Built as
   `0006`.

Both need an amendment to `Other-Docs/Epic-02/epic-02-data-layer.md`, or the next reader of Rev 8
will hit the same two walls.

---

## What Was Done Well

1. ✅ **The two added CHECKs are the best part of this story.** `CK_promptFragment_scopeAccount`
   stops `scope` and `accountId` contradicting each other row by row — which is precisely the
   near-duplicate-fork class already found in live `AI.prompt` data. Neither constraint was asked
   for.
2. ✅ **The D11 decision is implemented exactly**, with the rejected alternative and its failure mode
   written into the migration's header, so the next reader cannot re-propose the filtered index
   without meeting the argument against it.
3. ✅ **Fail-closed on `passedEvaluation`.** `PENDING_EVAL`, `BLOCKED` and `INCOMPLETE` are three
   different operational situations and none is safe; the reader resolves `PASSED` only.
4. ✅ **The no-write test is the right expression of the requirement.** Enumerating `_SQL` exports and
   asserting none can write proves the agent is *structurally* incapable of authoring its own
   instructions — a convention could not.
5. ✅ **Every CHECK has an integration case**, including the uniqueness collision that the spec's own
   DDL would have allowed.
6. ✅ **The PHI position is stated explicitly** rather than skipped, as the DoD requires: fragment
   text is authored content, never patient data.
7. ✅ **Closes ISS-004 as a side effect** — `post-apply-checks.sql` has expected five tables since
   story 2.1, and five now ship.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: ISS-501 — the same unchecked-assertion defect fixed in stories 2.6 and 2.7, repeated in
the one table where the corrupted value is the model's instruction itself. The fix is known, applied
twice, and takes minutes.

**Next Steps**
1. **ISS-501** — check the row, as 2.6 and 2.7 now do.
2. **ISS-502** — confirm the template-override constraint with Epic 8's author **before this DDL is
   applied anywhere**; it is forward-only.
3. **ISS-503** — verify the execution plan once B11 clears.
4. Consider ISS-504 (three tables) and ISS-505.
5. Amend the epic text for the two spec defects.
6. Re-request review.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer — ADR-03.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-06
**Signature**: Changes Requested

---

# 🛠️ Remediation — 2026-10-06

**Agent**: DEV · **Source report**: this document · **Story**: 2.5 (PEA-205)

| ID | Severity | Outcome |
|---|---|---|
| ISS-501 | 🟠 High | ✅ Resolved |
| ISS-505 | 🟢 Low | ✅ Resolved |
| ISS-502 | 🟡 Medium | ⏸️ **Deferred — needs Epic 8's author.** Forward-only DDL; do not apply anywhere until confirmed |
| ISS-503 | 🟡 Medium | ⏸️ Deferred — needs a real execution plan, so blocked on **B11** |
| ISS-504 | 🟡 Medium | ⏸️ Deferred — spans `promptFragment`, `fieldConstraint` and `fieldDescription`; "trigger vs writer-owns" is a design call, and one script should cover all three |

## Files changed

| File | Change |
|---|---|
| `src/repositories/promptFragmentRepository.ts` | Row columns checked, not asserted; ordering comment |
| `tests/unit/repositories/promptFragmentRepository.test.ts` | Two cases added |

## Test evidence

```
$ npm test
ℹ tests 132     (130 before -- two added)
ℹ pass 132
ℹ fail 0

$ npm run typecheck   → clean

$ npm run test:integration
ℹ tests 42 | pass 9 | fail 0 | skipped 33
```

## The lesson, since this was the third occurrence

The same unchecked-assertion defect appeared in stories 2.6, 2.7 and 2.5. It was found and fixed
twice before being written a third time, an hour after the second fix.

Reviews caught it every time, which is the system working — but a review catching the same defect
three times is a review doing a job that belongs upstream. The three repositories now agree, and the
honest preventative is a lint rule: **`as <Type>` on a value derived from `database.execute` should
be a guard error**, in the same `eslint.config.js` that already bans interpolated SQL and malformed
log calls. That rule would have failed this module before it was ever reviewed.

Recorded as a suggestion rather than implemented, because adding a guard rule means adding its
planted violation and is its own small piece of work.

## Still open on this story

ISS-502, ISS-503, ISS-504 above — plus the two **spec defects** that need amending in
`Other-Docs/Epic-02/epic-02-data-layer.md`: PEA-205 §4's missing `templetID` column, and the stale
`0004_create_prompt_fragment.sql` filename.
