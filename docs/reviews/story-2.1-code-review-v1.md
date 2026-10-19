# Code Review — Story 2.1 (PEA-201): Create the AI schema via a forward-only migration mechanism

> ## 🛠️ Remediation Status: 🟡 Partially Remediated (3/8)
> - **Remediated**: 2026-10-05 by DEV Agent
> - **Fixed**: 3 issue(s) — 🔴 1 / 🟠 2 / 🟡 0 / 🟢 0
> - **Deferred (with user consent)**: 5 — ISS-004…ISS-008, all 🟡/🟢. See Remediation Section.
> - **Tests**: 89/89 passing | **Coverage**: `databaseMigrations.ts` 96.02% lines, 85.00% branch | **Linter**: clean
> - **Scenario**: Code Review
> - **Every mandatory 🔴/🟠 issue is resolved.** The banner reads *Partially* only because the
>   optional 🟡/🟢 items were deferred by agreement, not because a blocker remains.

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
**Branch**: `3p-dev/PEA-201-ai-schema-data-layer`

### 🔴 Which standard was applied

**`PacEHR_AI/CLAUDE.md` and `docs/architecture/design/03-patterns-and-standards-brownfield.md`, per
ADR-03 — not `SPEC/rulebooks/aire-clean-architecture.md`.**

`SPEC/rulebooks/aire-review-rulebook.md` lists *"ARCHITECTURE MATCH: Must follow Clean Architecture"*
as a 🔴 CRITICAL rule and *"SOLID violation — Tight coupling → must use dependency injection"* as a
Blocker. **Those rules were deliberately not applied.** ADR-03 records the user's explicit decision
that `CLAUDE.md` governs this service, and the module-singleton pattern is load-bearing there: a
caller constructing its own pool pays for a second TLS handshake that no test catches.

Applying the rulebook literally would have produced three Blockers against `migrationRunner`,
`database` and `logger` that are wrong for this codebase. They are not raised.

---

## Review Summary

**Components Reviewed**:
- `migrations/sql/0001_create_ai_schema.sql`
- `migrations/verification/post-apply-checks.sql`
- `src/core/databaseMigrations.ts` (102 lines)
- `src/migrate.ts` (28 lines)
- `tests/unit/core/databaseMigrations.test.ts` (104 lines)
- `tests/integration/core/databaseMigrations.test.ts`
- `package.json` (migrate scripts)

**Lines of Code**: ~250 (excluding tests)
**Tests Reviewed**: Yes
**Coverage**: `databaseMigrations.ts` — **89.22% lines, 94.74% branch, 93.75% functions** ✅
`src/migrate.ts` — **0%** ❌

**Overall Assessment**: Careful, well-reasoned work. The comments state measurements rather than
restating the code, the `GO`-handling reversal was caught and fixed before merge, and the validator
is deliberately shaped so tests can assert rejections with no filesystem and no database. One real
hole exists in the schema-scope check — the single control protecting this epic's non-negotiable
rule — and it is reachable by a plausible future script. That, plus a deviation from the story's own
acceptance criteria and an entrypoint failure path, means changes are requested.

---

## Evidence Verified

Run against the working tree at review time, not taken from the ticket:

```
$ npm test
ℹ tests 88
ℹ pass 88
ℹ fail 0
ℹ duration_ms 2994.394833

$ npm run typecheck
> tsc --noEmit
(clean, no output)

$ node --import tsx/esm --import ./tests/unit/no-network.ts --test \
    --experimental-test-coverage "tests/unit/core/databaseMigrations.test.ts"
ℹ   databaseMigrations.ts |  89.22 |    94.74 |   93.75 | 25-26 30-38
```

---

## Checklist Results

### Correctness
- [x] ✅ Code does what it's supposed to — scripts apply in numeric order, batch by batch
- [x] ✅ Idempotency is by existence check, not a ledger table, as specified
- [x] ✅ Forward-only — no script reverses another, asserted by its own test
- [x] ⚠️ Edge cases — **unqualified object names escape the scope check** (ISS-001)
- [x] ⚠️ Error conditions — **a successful migration can report failure** (ISS-003)
- [x] ✅ No race conditions — scripts are sequential by construction
- [x] ✅ No memory leaks — pool closed on the entrypoint's exit path

### Pattern Adherence
- [x] ✅ Singleton exported on the module's last line, named after its class
- [x] ✅ Construction reads nothing and opens nothing
- [x] ✅ No second connection — uses the `database` singleton's `run()`
- [x] ✅ Logging is fields-first with a literal message
- [x] ✅ Naming — `SCRIPT_DIRECTORY`, `SCRIPT_NAME`, `BATCH_SEPARATOR` all module constants
- [x] ✅ No bare numbers; `/^\d{4}_/` carries its reason in a comment
- [x] ⚠️ **Promise float in `src/migrate.ts`** (ISS-003)
- [x] ✅ One public method on the class — `applyPending()`

### Testing
- [x] ✅ Unit tests exist and are meaningful — 13 cases, each asserting a distinct rule
- [x] ✅ Tests assert behaviour, not shape
- [x] ✅ Integration test applies the set twice and asserts the second run is a no-op
- [x] ✅ Coverage ≥85% on the module under review (89.22%)
- [x] ❌ **`src/migrate.ts` has no test at all** (ISS-006)
- [x] ⚠️ **No coverage script exists, so the gate is unenforced** (ISS-005)

### Documentation
- [x] ✅ Every module header says what the module is and why it is not the one beside it
- [x] ✅ Comments state facts and measurements, never activity
- [x] ✅ No commented-out code
- [x] ✅ No TODO comments
- [x] ✅ `ponytail:` notes carry their ceiling and upgrade path

### Security
- [x] ✅ No hardcoded secrets, keys or environment values
- [x] ✅ No value reaches SQL by interpolation — scripts are fully literal
- [x] ✅ Migration identity is distinct from the runtime principal
- [x] ✅ Failures name the script and the batch ordinal, **never the script text**
- [x] ⚠️ **The scope check has a reachable bypass** (ISS-001)
- [x] ✅ No PHI or clinical value in any log line

---

## Issues Found

### ISS-001: An unqualified `CREATE TABLE` escapes the schema-scope check 🔴 Blocker

**Category**: Security / Correctness
**File**: `tests/unit/core/databaseMigrations.test.ts:30-52`
**Pattern Reference**: `docs/requirements.md` → Failure Criteria #1; story AC *"A script touching an
object outside the AI schema is rejected before merge"*

**Issue**

The scope check matches **schema-qualified** names only. `QUALIFIED_NAME` requires a `schema.object`
pattern, so an unqualified `CREATE TABLE` — which SQL Server resolves to the connection's default
schema, normally `dbo` — is invisible to it. `FORBIDDEN` does not list `CREATE`, and the guard-count
test is satisfied by the `IF NOT EXISTS` wrapper.

The file's own header calls this *"the only thing standing between a merged script and production,
since there is no down-migration."*

**Verified, not theorised.** Running the test's actual regexes against a synthetic script:

```
foreign schemas: []
forbidden hit:   null
creates: 1  guards: 1
```

All five scope tests pass on this script:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'widget')
CREATE TABLE widget ([id] INT NOT NULL);     -- lands in dbo, outside AI
```

**Suggested fix** — assert the target of every `CREATE`, rather than only scanning for foreign
schema prefixes:

```typescript
const AI_QUALIFIED_CREATE = /\bCREATE\s+(?:TABLE|INDEX|VIEW|PROCEDURE|FUNCTION)\b[\s\S]{0,200}?\[?AI\]?\s*\./i;

test('every CREATE names an AI-qualified target', () => {
  for (const { name, text } of scripts) {
    for (const batch of batches(statements(text))) {
      if (!/\bCREATE\s+(TABLE|INDEX|VIEW|PROCEDURE|FUNCTION)\b/i.test(batch)) continue;
      assert.match(batch, AI_QUALIFIED_CREATE, `${name}: CREATE with no AI-qualified target`);
    }
  }
});
```

**Why this matters**

The one rule this epic cannot break is *no existing clinical table is altered, dropped or written
to*, against a production database holding real patient data, with no down-migration to undo a
mistake. **Every shipped script is clean** — this is a gap in the guard, not a live defect — but the
guard is the whole control, and the next script is written by someone who trusts it.

**Resolution** (2026-10-05, DEV):
- Fix: the scope rules moved **into `validate()`** as `scopeProblems()`, so the runner itself refuses
  an out-of-scope script — not only the merge gate. `CREATE TABLE/VIEW/PROCEDURE/FUNCTION` must carry
  an `AI.` prefix; `CREATE INDEX/TRIGGER` must name an `AI.`-qualified target in its `ON` clause;
  `CREATE SCHEMA` must name `AI`.
- **Deviation from the suggested fix, justified**: the report proposed a test-only assertion. That
  would have left `applyPending()` applying whatever is on disk, because `readScripts()` calls
  `validate()` and `validate()` did not check scope. Putting the rule in `validate()` makes it a
  runtime gate *and* a merge gate, and matches the function's own stated design — *"takes the
  scripts rather than reading them so tests/unit can assert each rejection against a synthetic set."*
- Change ref: `src/core/databaseMigrations.ts:21-100` (new constants + `bare`, `statements`,
  `scopeProblems`), `src/core/databaseMigrations.ts:validate()`
- Test evidence: `tests/unit/core/databaseMigrations.test.ts` — planted violation
  `an unqualified CREATE lands outside the AI schema and is rejected`. **Verified failing before the
  fix** (`ℹ fail 2`) and passing after.
- Status: ✅ Resolved

> Severity note, so it can be argued down: nothing is broken today, which is an argument for 🟠 High.
> It is raised as 🔴 Blocker because of the asymmetry — the cost of the check being wrong is
> unrecoverable damage to production clinical data, and the fix is about six lines.

---

### ISS-002: The write-ban is stricter than the acceptance criteria and will block Epic 8 🟠 High

**Category**: Correctness / Pattern
**File**: `tests/unit/core/databaseMigrations.test.ts:19-20, 38-43`

**Issue**

The story's acceptance criterion reads:

> asserts no `ALTER`, `DROP`, `INSERT`, `UPDATE` or `DELETE` keyword appears **against any object
> outside the `AI` schema**

The implementation bans those keywords **unconditionally, anywhere in any script**:

```typescript
const FORBIDDEN = /\b(DROP|TRUNCATE|DELETE|UPDATE|INSERT|MERGE|ALTER\s+TABLE)\b/i;

test('no script drops, truncates or writes rows anywhere', () => { … });
```

The test name says `anywhere` and means it. This is stricter than specified, and the extra strictness
is not free: **Epic 8 requires a bootstrap prompt fragment**, which `GAPS.md` §4 lists among the
things it checked and found sound. A migration seeding a row into `AI.promptFragment` is legitimate
under the AC and rejected by this test.

**Suggested fix** — scope the ban to non-`AI` targets, keeping `DROP` and `TRUNCATE` unconditional
since neither is ever legitimate here:

```typescript
const NEVER = /\b(DROP|TRUNCATE|ALTER\s+TABLE)\b/i;          // never legitimate, any schema
const WRITES = /\b(INSERT|UPDATE|DELETE|MERGE)\s+(?:INTO\s+)?(?!\[?AI\]?\s*\.)/i;  // only outside AI
```

**Why this matters**

A guard that is stricter than its specification is still a defect: the next author hits it, cannot
tell whether the rule or the script is wrong, and the cheapest way out is to weaken the whole check.

**Resolution** (2026-10-05, DEV):
- Fix: the single `FORBIDDEN` regex is split in two. `NEVER` (`DROP`, `TRUNCATE`, `ALTER TABLE`)
  stays unconditional in any schema — none is ever legitimate in a forward-only set. Row writes
  (`INSERT`, `UPDATE`, `DELETE`, `MERGE`) are now rejected only when their target is **not**
  `AI.`-qualified, so **Epic 8's bootstrap prompt fragment is no longer blocked**. A write with no
  schema at all is rejected, since it would resolve to `dbo`.
- The stale `FORBIDDEN` constant and the `no script drops, truncates or writes rows anywhere` test
  were **deleted** from the test file rather than left beside the new rule — two checks disagreeing
  about the same thing is how the next author learns to distrust both.
- Change ref: `src/core/databaseMigrations.ts` (`NEVER`, `WRITE`),
  `tests/unit/core/databaseMigrations.test.ts`
- Test evidence: planted violations `a row write inside the AI schema is allowed` (passes — proves
  the relaxation is real) and `a row write outside the AI schema is rejected` (**verified failing
  before the fix**), plus `a script that drops, truncates or alters a table is rejected` covering all
  three `NEVER` keywords.
- Status: ✅ Resolved

---

### ISS-003: A successful migration can report failure to the pipeline 🟠 High

**Category**: Correctness
**File**: `src/migrate.ts:14-28`
**Pattern Reference**: `CLAUDE.md` § Code standard — *"No promise floats. Every promise is awaited or
returned."*

**Issue**

The promise chain is neither awaited nor returned, and the final `.then` has no rejection handler:

```typescript
migrationRunner
  .applyPending()
  .then(() => 0, (error: unknown) => { log.error({ err: error }, 'migrations failed'); return 1; })
  .then(async (code: number) => {
    if (Object.hasOwn(database, 'pool')) await database.pool.close();
    process.exit(code);          // ← never reached if close() rejects
  });
```

If `database.pool.close()` rejects — a connection reset during teardown is enough —
`process.exit(code)` never runs. The rejection is unhandled, and Node exits **1**.

For a failed migration that is harmless; the code was 1 anyway. **For a successful migration it
reports failure**, and the deploy step's own comment says *"A pipeline step reads the code, not the
log."* The pipeline would then re-run or roll back a migration that in fact applied cleanly — against
a forward-only set with no down-migration.

**Suggested fix**

```typescript
void migrationRunner
  .applyPending()
  .then(() => 0, (error: unknown) => { log.error({ err: error }, 'migrations failed'); return 1; })
  .then(async (code: number) => {
    // A teardown failure must not turn a clean apply into a reported failure.
    if (Object.hasOwn(database, 'pool')) {
      await database.pool.close().catch((err: unknown) => log.warn({ err }, 'pool close failed'));
    }
    process.exit(code);
  });
```

`void` marks the float as deliberate at the one place CLAUDE.md permits it — the entrypoint, which
cannot use top-level `await`.

**Resolution** (2026-10-05, DEV):
- Fix: `database.pool.close()` now carries `.catch()`, logging the teardown failure at `warn` and
  letting `process.exit(code)` run regardless. A clean apply can no longer be reported as a failure
  because teardown stumbled. The chain is prefixed `void` to mark the float deliberate, with the
  reason in a comment — an entrypoint cannot use top-level `await`.
- Change ref: `src/migrate.ts:13-34`
- Note: an interim edit also consumed `applyPending()`'s return value to log the count (ISS-008).
  **Reverted** — `applyPending()` already logs `migrations applied`, so it produced a duplicate line,
  and ISS-008 was out of the agreed scope.
- Test evidence: no new test. The failure requires a rejecting `pool.close()` on a real pool, and
  `src/migrate.ts` executes on import so `tests/unit` cannot import it — the same constraint ISS-006
  records. **This fix is reasoned, not test-proven**, which is itself an argument for ISS-006.
- Status: ✅ Resolved


---

### ISS-004: `post-apply-checks.sql` expects five tables; four ship 🟡 Medium

**Category**: Correctness / Documentation
**File**: `migrations/verification/post-apply-checks.sql` — check #4

```sql
-- 4. The five tables exist.                    expect: 5 rows
```

`AI.promptFragment` is deliberately not built (ADR-05 / D11), so the current script set creates
four. The first real deployment reports a false failure on a check whose whole purpose is to be
trusted as deployment evidence.

**Suggested fix**: amend to `expect: 4 rows` with a one-line note that the fifth arrives with
PEA-205, or make the expectation derive from the shipped script count.

---

### ISS-005: The ≥85% coverage gate is unenforced — no coverage script exists 🟡 Medium

**Category**: Testing
**File**: `package.json` — `scripts`

`package.json` defines `test`, `test:integration`, `typecheck`, `build`, `start`, `migrate` — and no
coverage target. The gate in `03-patterns-and-standards-brownfield.md` and in `docs/requirements.md`
says ≥85%, but nothing computes it; this review measured it by hand.

Compounding it, `11-test-infrastructure-cicd-deep-dive.md` records that
`test-validation-pipeline.yml`'s `pr:` trigger **is ignored by Azure DevOps for Azure Repos Git**, so
unit tests are not gated on pull requests either.

**Suggested fix**

```json
"test:coverage": "node --import tsx/esm --import ./tests/unit/no-network.ts --test --experimental-test-coverage \"tests/unit/**/*.test.ts\""
```

The CI trigger itself is R2/M11 and outside this story.

---

### ISS-006: `src/migrate.ts` has no test 🟡 Medium

**Category**: Testing
**File**: `src/migrate.ts`

Coverage is 0% — the file is absent from the report because no unit test imports it. It is the
deploy-time entrypoint: the one piece of this story that runs against the production database.

The reason it is untested is sound and documented — it executes on import, so `tests/unit/repo.test.ts`
(which proves the tree imports with no environment and no network) must not import it. That argues
for restructuring, not for no test:

**Suggested fix**: extract the exit-code decision into a testable pure function and keep only the
invocation at module scope.

```typescript
export function exitCodeFor(result: 'applied' | 'failed'): 0 | 1 { … }
```

A child-process smoke test asserting the exit code on a failed apply would also close it.

---

### ISS-007: `readScripts()` runs at test-module scope 🟢 Low

**Category**: Testing
**File**: `tests/unit/core/databaseMigrations.test.ts:22`

```typescript
const scripts = readScripts();      // module scope, outside any test
```

If it throws — a malformed filename, an unreadable file — the failure surfaces as a module-load
error rather than a named assertion, and all 13 cases in the file disappear rather than one failing.

**Suggested fix**: move it inside a first test, or wrap it so the throw becomes an assertion.

---

### ISS-008: `applyPending()`'s return value has no consumer 🟢 Low

**Category**: Maintainability
**File**: `src/core/databaseMigrations.ts:81`, `src/migrate.ts:15`

`applyPending(): Promise<number>` returns the script count, and the only caller discards it. The
count is already logged inside the method, so nothing is lost — but the return type advertises a
contract nobody uses. Either consume it in the entrypoint's log line or return `Promise<void>`.

---

## Issue Summary

| # | ID | Severity | Category | File | Status |
|---|---|---|---|---|---|
| 1 | ISS-001 | 🔴 Blocker | Security / Correctness | `tests/unit/core/databaseMigrations.test.ts:30-52` | Must Fix |
| 2 | ISS-002 | 🟠 High | Correctness / Pattern | `tests/unit/core/databaseMigrations.test.ts:19-43` | Should Fix |
| 3 | ISS-003 | 🟠 High | Correctness | `src/migrate.ts:14-28` | Should Fix |
| 4 | ISS-004 | 🟡 Medium | Correctness | `migrations/verification/post-apply-checks.sql` | Can Fix Later |
| 5 | ISS-005 | 🟡 Medium | Testing | `package.json` | Can Fix Later |
| 6 | ISS-006 | 🟡 Medium | Testing | `src/migrate.ts` | Can Fix Later |
| 7 | ISS-007 | 🟢 Low | Testing | `tests/unit/core/databaseMigrations.test.ts:22` | Optional |
| 8 | ISS-008 | 🟢 Low | Maintainability | `src/core/databaseMigrations.ts:81` | Optional |

**Summary**
- Blockers: **1** (must fix before merge)
- High: **2**
- Medium: **3**
- Low: **2**

---

## What Was Done Well

1. ✅ **The `GO` reversal was caught before merge and documented as a reversal.** The original rule
   banned `GO`; building PEA-202 showed every spec's DDL needs it, because `CREATE INDEX` cannot
   reference a table the same batch is creating. The runner now splits on it, `batches()` is
   exported and tested directly — *"the batch is the unit the database actually receives: a test
   that asserts on whole-file text is asserting on something no server ever sees."* That is the
   right instinct about what a test should bind to.
2. ✅ **`validate()` takes scripts rather than reading them**, so every rejection is assertable with
   no filesystem and no database. Six of the thirteen tests depend on that one design choice.
3. ✅ **Failures name the script and the batch ordinal, never the script text.** Applied
   consistently, including in the error `cause` chain.
4. ✅ **`EXEC('CREATE SCHEMA [AI]')` with the reason in a comment** — `CREATE SCHEMA` must be first
   in its batch and mssql sends the file as one batch. The comment states the constraint, not the
   code.
5. ✅ **The `0001` header records a real defect found on the way** — the schema already exists in
   production carrying `AI.prompt`, with no `CREATE SCHEMA` anywhere in source control (defect X9) —
   and explains why the guard makes the script correct against both a production and an empty
   database.
6. ✅ **`no script is a down-migration` is a separate test with its reason attached**: *"the rule a
   reviewer is most likely to relax under pressure."* Correct, and unusually self-aware.
7. ✅ **Zero-padding is explained by its failure mode**, not asserted: *"an unpadded 10_ sorts before
   2_."*
8. ✅ **`run`, not `execute`**, with the reason — a migration yields no rows and `execute`'s type
   would promise an array the driver never builds.
9. ✅ Coverage on the module under review is **89.22% / 94.74% / 93.75%**, above the gate without
   padding.

---

## Approval Status

**Decision**: ❌ CHANGES REQUESTED

**Reason**: ISS-001 is a reachable bypass in the only control enforcing this epic's non-negotiable
rule, against a production database with no down-migration. ISS-002 and ISS-003 are both cases where
the code and its own specification disagree in ways that will surface later as someone else's bug.

**Next Steps**
1. Fix **ISS-001** — assert every `CREATE` names an `AI`-qualified target, and add the planted
   violation that proves it fires (per the patterns doc: *a guard change ships with the planted
   violation that proves it fires*).
2. Fix **ISS-002** — scope the write-ban to non-`AI` targets so Epic 8's bootstrap is not blocked.
3. Fix **ISS-003** — catch the teardown rejection so a clean apply cannot report failure.
4. Consider ISS-004 through ISS-006.
5. Re-request review.

**Not raised, deliberately**: dependency injection, repository interfaces, a domain layer, and the
absence of a DI container. See *Which standard was applied* above.

---

## Sign-Off

**Reviewer**: REVIEWER Agent
**Date**: 2026-10-05
**Signature**: Changes Requested

---

# 🛠️ Remediation — 2026-10-05

**Agent**: DEV · **Source report**: this document · **Scenario**: Code Review
**Story**: 2.1 (PEA-201) · **Branch**: `3p-dev/PEA-201-ai-schema-data-layer`

## Scope

Mandatory 🔴 + 🟠 only, confirmed with the user before any code was touched. 🟡/🟢 deferred with
explicit consent.

| ID | Severity | Outcome |
|---|---|---|
| ISS-001 | 🔴 Blocker | ✅ Resolved |
| ISS-002 | 🟠 High | ✅ Resolved |
| ISS-003 | 🟠 High | ✅ Resolved |
| ISS-004 | 🟡 Medium | ⏸️ Deferred — `post-apply-checks.sql` still expects 5 tables |
| ISS-005 | 🟡 Medium | ⏸️ Deferred — no `test:coverage` script |
| ISS-006 | 🟡 Medium | ⏸️ Deferred — `src/migrate.ts` untested |
| ISS-007 | 🟢 Low | ⏸️ Deferred |
| ISS-008 | 🟢 Low | ⏸️ Deferred |

## Files changed

| File | Change |
|---|---|
| `src/core/databaseMigrations.ts` | Added `bare()`, `statements()`, `scopeProblems()` and six rule constants; `validate()` now applies them |
| `src/migrate.ts` | Teardown rejection caught; chain marked `void` with its reason |
| `tests/unit/core/databaseMigrations.test.ts` | Three planted violations added; stale `FORBIDDEN` constant, `ALLOWED_SCHEMAS`, `QUALIFIED_NAME`, local `statements()` and two superseded tests removed |

## Test evidence

```
$ npm test
ℹ tests 89
ℹ pass 89
ℹ fail 0

$ npm run typecheck
> tsc --noEmit
(clean)

$ node --import tsx/esm --import ./tests/unit/no-network.ts --test \
    --experimental-test-coverage "tests/unit/**/*.test.ts"
ℹ   databaseMigrations.ts  |  96.02 |    85.00 |   72.41 | 32 72-77
```

**Before**: 88 tests, `databaseMigrations.ts` at 89.22% lines / 94.74% branch.
**After**: 89 tests, 96.02% lines / 85.00% branch — above the ≥85% gate on both.

Branch coverage fell 94.74 → 85.00 because `scopeProblems()` adds many branches, several reachable
only by SQL forms no shipped script uses (`MERGE`, `CREATE TRIGGER`, `CREATE PROC`). It remains above
the gate. Line coverage rose.

Net test count is +1, not +3: three planted violations were added and two superseded tests deleted.

The lint guards ran inside `npm test` — `tests/unit/source-rules.test.ts` passes, including the
`process.env`, log-call and tagged-template `query` rules.

## Patterns applied

- **Fail closed** — a script that leaves the `AI` schema is now refused by the runner, not only by CI
- **A guard change ships with the planted violation that proves it fires** — three added
- **Deleted code is deleted** — the superseded `FORBIDDEN` check was removed, not left beside the new one
- **One statement per constant, comment carries the reason** — each new regex states the failure it prevents
- **No bare numbers**; no interpolation; no second connection

## Deviations from the suggested fixes

1. **ISS-001 — fixed in `validate()`, not only in the test.** The report proposed a test-only
   assertion, which would have left `applyPending()` applying whatever is on disk. Moving the rule
   into `validate()` makes it both a runtime and a merge gate. Strictly more than asked; recorded
   here rather than done quietly.
2. **ISS-003 — no test.** The failure needs a rejecting `pool.close()` on a real pool, and
   `src/migrate.ts` runs on import so `tests/unit` cannot import it. The fix is reasoned, not
   test-proven. **This is the strongest argument for closing ISS-006.**

## Lessons

- The hole in ISS-001 existed because the check scanned for *foreign schema prefixes* rather than
  asserting the *target of each CREATE*. A guard phrased as "nothing bad appears" misses everything
  unnamed; one phrased as "every create names an allowed target" does not. Worth applying to the
  remaining scripts' checks.
- ISS-002 shows a guard stricter than its specification is still a defect: it would have failed Epic
  8's bootstrap, and the cheapest escape would have been to weaken the whole check.

## Still open on this story

Deferred items ISS-004…ISS-008 remain. **ISS-004 is worth doing before the first deployment** —
`post-apply-checks.sql` check #4 expects five tables and four ship, so the check that exists to be
trusted as deployment evidence will report a false failure.
