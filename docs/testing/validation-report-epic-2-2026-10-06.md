# Validation Report — Epic 2: Data Layer, AI Schema

**Date**: 2026-10-06
**Validated By**: QA
**Scope**: `epic-2`
**Test Plan**: `docs/testing/test-plan-epic-2.md`
**Verdict**: ⚠️ **CONDITIONAL PASS** — every runnable gate is met; the gates that matter most could not be run
**Revised**: 2026-10-06 — coverage gate corrected from ✅ to ❌ (QA-004); QA-001/002/003 remediated

---

## Executive Summary

The unit tier is genuinely strong: **121 of 121 passing**, typecheck clean, lint guards firing
against planted violations, and every Epic 2 module at or near 100% line coverage. Nothing in the
runnable set failed.

That is also the limit of what this validation establishes. **25 of 33 integration tests did not
execute**, so no constraint, key or statement in this epic has been verified against a database. Two
new defects were found during execution that six code reviews did not surface — one of them a method
serving the clinician review queue that **has no test and no caller**.

**This epic cannot be signed off as validated.** It can be signed off as *correct in every respect a
machine without database credentials is able to check*, which is a materially weaker claim and is the
one made here.

---

## Phase 1 — Pre-Validation Checks

| Check | Result |
|---|---|
| Test plan exists | ✅ `docs/testing/test-plan-epic-2.md` |
| Requirements readable | ✅ `docs/requirements.md` (rev. 2026-10-05) |
| Implementation complete for scope | ⚠️ **6 of 7 stories.** 2.5 unbuilt — blocked on D11 |
| Test commands identified | ✅ `npm test`, `npm run test:integration`, `npm run typecheck` |
| **Code is committed** | ❌ **FAIL — 34 uncommitted paths.** HEAD is `e86c54e`, which predates every story in this epic |

🔴 **The commit gate fails.** Everything validated below exists only in a working tree. A validation
report against uncommitted code describes a state no one else can reproduce and that a stray
`git checkout` erases. This does not invalidate the results, but it bounds them.

---

## Phase 2 — Test Execution

### Unit suite — ✅ PASS

```
$ npm test
ℹ tests 121
ℹ suites 0
ℹ pass 121
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 2837.205416
```

Run with the network blocked (`tests/unit/no-network.ts`). No process exited 99, so nothing attempted
a socket, DNS lookup or fetch. **TC-X-003 ✅**

### Typecheck — ✅ PASS

```
$ npm run typecheck
> tsc --noEmit
(no output)
```

### Integration suite — ❌ BLOCKED

```
$ npm run test:integration
ℹ tests 33
ℹ pass 8
ℹ fail 0
ℹ skipped 25
ℹ duration_ms 425.752584
```

**0 failures, and that number means nothing.** The 8 "passes" are the parent `test()` wrappers that
compute the skip reason; the 25 subtests carrying every assertion were skipped.

### Coverage — ❌ **CORRECTED 2026-10-06: the gate cannot be evidenced**

> 🔴 **This section originally read "✅ gate met" at 85.23%. That was wrong, and the correction is
> the most important finding in this report.** The figure below was one sample from a measurement
> that is not reproducible. See **QA-004**.

```
ℹ   databaseMigrations.ts         |  94.94 |    85.00 |   72.41
ℹ   fieldOutcomeRetention.ts      | 100.00 |   100.00 |   80.00
ℹ   agentRunWriter.ts             | 100.00 |    94.74 |   80.00
ℹ   fieldConstraintRepository.ts  | 100.00 |   100.00 |   83.33
ℹ   fieldDescriptionRepository.ts | 100.00 |   100.00 |   83.33
ℹ   fieldOutcomeRepository.ts     |  97.99 |   100.00 |   54.55
ℹ   mapping.ts                    | 100.00 |   100.00 |   75.00
ℹ   all files                     |  85.23 |    93.78 |   72.85
```

**Re-measured four times, same command, same tree:**

```
all files   85.23%   (first run, originally reported)
all files   71.38%
all files   68.05%
all files   73.59%
```

Per-module figures are stable run to run; **the aggregate is not**. Node's
`--experimental-test-coverage` merges across one process per test file, and the merge is evidently
incomplete under concurrency.

Worse, the per-file figures are systematically understated. `fieldOutcomeRepository.ts` reports lines
`63-78, 101-104, 114-119, 123` as uncovered. Those lines are:

```typescript
export type Proposal = { … }          // erased at runtime
/** False is not an error and not a retry: … */   // a doc comment
async recordProposal(proposal: Proposal, …)       // demonstrably covered — tests call it
```

**Type declarations and comments, which tsx erases before execution.** The same file dropped from
97.99% to 81.88% *after* three passing tests were added to it, which is the tell.

⚠️ **The coverage run itself also fails a test** — `REQUIRED and OPTIONAL are derived from the schema, in
schema order` (`tests/unit/core/settings.test.ts`). This is **ISS-010**, pre-existing, confirmed
earlier against a stashed-clean tree. So the gate is neither met nor missed — **it is unmeasured**, by a tool that cannot complete a run
and whose numbers do not reproduce. ISS-005 (add a `test:coverage` script) is blocked twice over.

---

## Phase 3 — Requirements Verification

| Requirement | Evidence | Verdict |
|---|---|---|
| REQ-02-07 — no clinical table written or altered | TC-MIG-003/004 ✅ unit; **TC-ENV-002 not run** | 🟡 Partial — proven in CI, never against a database |
| REQ-02-10 — tables inside the existing database | TC-MIG-001/002 **not run** | ❌ Unverified |
| REQ-02-03 — one append-only `agentRun` row | TC-RUN-001/002/003 ✅ unit; TC-RUN-004 not run | 🟡 Partial |
| REQ-02-04 — proposal beside decision | TC-OUT-001/002/003/004 ✅ unit; 005/006 not run | 🟡 Partial |
| REQ-02-08 — index + retention policy | TC-RET-001/002/003/005 ✅ unit; 004/006 not run | 🟡 Partial |
| REQ-02-09 — live spelling preserved | Statements assert their own text; **TC-ENV-002 not run** | 🟡 Partial — nothing has compared a statement to a real column |
| REQ-02-02 — per-field guards | TC-CON-001/002 ✅ unit; 003/004 not run | 🟡 Partial |
| REQ-03-01 — per-mapping description | TC-DES-001/002/003 ✅ unit; 004 not run | 🟡 Partial |
| REQ-02-01 — versioned prompt fragments | **No code** — story 2.5 unbuilt (D11) | ❌ Not delivered |

**No requirement is fully verified. Eight are partially verified by unit tests; one has no
implementation.** The common missing half is identical in every row: the database.

---

## Phase 4 — Quality Gate Verification

| Gate | Target | Actual | Verdict |
|---|---|---|---|
| Unit tests passing | 100% | 121/121 | ✅ |
| Unit coverage (lines) | ≥85% | **non-deterministic** — 65.19–88.18% across five identical runs | ❌ **QA-004** |
| Unit coverage (branch) | ≥85% | **93.81%, exact and reproducible** | ✅ |
| Integration tests passing | 100% | **8 of 33 executed** | ❌ |
| Typecheck | clean | clean | ✅ |
| Lint guards + planted violations | fire | fire | ✅ |
| Critical/high defects open | 0 | 0 in epic code; **1 🟠 open in Epic 01 (ISS-010)** | 🟡 |
| Code committed | yes | **34 uncommitted paths** | ❌ |
| Migration dry-run vs staging | required | impossible — M11 | ❌ |
| `post-apply-checks.sql` check #5 | 0 rows | never run | ❌ |

**5 of 10 gates met.** The line-coverage gate is not failed on merit — it is unanswerable as stated. Branch coverage, which is exact, passes comfortably.

---

## Phase 5 — Defects Found During Validation

### QA-001: `pendingForEncounter` has no test and no caller 🟠 High

**Component**: `src/repositories/fieldOutcomeRepository.ts:144`

```
$ grep -rn "pendingForEncounter" tests/ src/
  src/repositories/fieldOutcomeRepository.ts:144:  async pendingForEncounter(...)
```

One hit — the declaration. **No test calls it. No production code calls it.** It is the method that
serves the clinician review queue, and `IX_fieldOutcome_pending` — a filtered index created
specifically for it — exists to make it fast.

This is why `fieldOutcomeRepository.ts` shows **54.55% function coverage** against 97.99% line
coverage: the lines inside the method are few, but the method itself is never entered.

**Six code reviews did not catch this.** Story 2.3's v1 listed `SELECT_PENDING_BY_ENCOUNTER_SQL`
among the components reviewed and raised ISS-306 about its *return type* — without noticing that
nothing exercised it. Reviewing a method's signature is not the same as checking that anything runs
it, and line coverage hid it because the method is three lines long.

**Severity**: High, not Blocker — no caller means no user-visible failure today. But this is the read
path the entire review surface (M4/D7) will be built on, and it will be built against an untested
method.

**Suggested fix**: a unit test asserting the `encounterID` binding and the `decidedAtUtc IS NULL`
filter, plus an integration case asserting that a decided row does **not** appear in the queue.

---

### QA-002: The integration skip reason misattributes a configuration failure to the database 🟡 Medium

**Component**: every `tests/integration/**` file

Observed skip reason:

```
# Azure SQL did not answer from this machine (Error: settings: missing or invalid:
  AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_VERSION, AZURE_OPENAI_GPT_4_1_DEPLOYMENT,
  AZURE_SQL_SERVER, AZURE_SQL_DATABASE, ENTRA_TENANT_ID, ENTRA_AUDIENCE)
```

**Azure SQL was never contacted.** `settings()` threw first, because required variables are absent.
The message asserts something that did not happen, and the real cause is only visible in the
parenthetical.

Why it matters beyond tidiness: once an `.env.local` exists, a genuine connectivity failure, an
expired credential and a typo'd database name will all produce this same sentence. The message that
is supposed to tell an operator *why* the suite skipped flattens three different causes into one
wrong claim.

**Suggested fix**: distinguish the two — catch the configuration error separately and say
`configuration incomplete: <names>`, reserving *"Azure SQL did not answer"* for a failure that
actually reached the driver.

---

### QA-003: Fixture hygiene — two integration files never clean up 🟡 Medium

`tests/integration/repositories/agentRunWriter.test.ts` and `fieldOutcomeRepository.test.ts` insert
`encounterID = -1` rows and never delete them. The 2.4, 2.6 and 2.7 files clean up in `t.after`.

Against a shared DEV database every run accumulates rows in `AI.agentRun` and `AI.fieldOutcome` —
the two tables whose growth this epic explicitly budgets for, and the one Epic 10 will read as its
evaluation set. **Fix before TC-ENV-001 is run repeatedly**, not after.

---

### QA-004: Line coverage is non-deterministic, so the gate's verdict is a coin flip 🟠 High

**Discovered**: while re-verifying this report's own coverage claim. **Twice corrected** — the first
two diagnoses were each partly wrong, and the measured result below supersedes them.

**Method**: five runs of the identical command on an unchanged tree.

| Metric | Run 1 | Run 2 | Run 3 | Run 4 | Run 5 | Stable? |
|---|---|---|---|---|---|---|
| `fieldOutcomeRepository.ts` lines | 100.00 | 81.88 | 81.88 | 100.00 | 81.88 | ❌ |
| `fieldDescriptionRepository.ts` lines | 100.00 | 60.00 | 100.00 | 100.00 | 60.00 | ❌ |
| **`all files` lines** | 74.61 | 82.36 | 66.48 | **88.18** | 65.19 | ❌ |
| `all files` **branch** | 93.81 | 93.81 | 93.81 | 93.81 | 93.81 | ✅ |
| `all files` **functions** | 73.51 | 73.51 | 73.51 | 73.51 | 73.51 | ✅ |

**Line coverage is non-deterministic. Branch and function coverage are exact.**

The aggregate crosses the ≥85% threshold in both directions — 88.18% passes, 65.19% fails — on a
tree that did not change. **A gate stated in line coverage therefore returns a different verdict
depending on when it is run.**

Per-module values flip between two discrete figures rather than drifting, and the lines reported
uncovered in the low variant are consistently the same ranges — `63-78` (`export type Proposal`),
`101-104` and `114-119` (doc comments). Those constructs are erased by `tsx` before execution, so
whether source-map attribution credits them appears to be racy rather than wrong-but-consistent.
Neither `--test-concurrency=1` nor repeated runs removed it.

**Impact on this report**: the coverage gate was originally recorded as ✅ met at 85.23%. **That
claim is withdrawn** — not because the code is poorly covered, but because the number quoted was one
sample from a distribution spanning 23 percentage points.

**What is usable today, at no cost**: branch coverage is exact and reads **93.81%**, comfortably
above the gate. Function coverage is exact at 73.51% and is the figure that exposed QA-001.

**Suggested fix**, in order of cost:
1. **State the gate in branch coverage** — exact today, needs no tooling change.
2. Keep function coverage as a second signal; it found a defect six reviews missed.
3. If a line-coverage figure is genuinely required, measure it with a tool that does not inherit this
   behaviour — `c8` over compiled `dist/` output is the usual answer for a `tsx` project. **That adds
   a devDependency and is a decision for the owner**, not something to adopt unilaterally under
   `CLAUDE.md`'s dependency discipline.

**Until one of those lands, no line-coverage figure should appear in a release record.**

---

## Remediation — 2026-10-06

QA-001, QA-002 and QA-003 were fixed in the same session. QA-004 is new and open.

| ID | Severity | Outcome |
|---|---|---|
| QA-001 | 🟠 High | ✅ Resolved — three unit cases, one integration case |
| QA-002 | 🟡 Medium | ✅ Resolved — seven integration files |
| QA-003 | 🟡 Medium | ✅ Resolved — both offending files clean up |
| QA-004 | 🟠 High | 🔴 **Open** — raised by this remediation's own verification |

**QA-001** — `pendingForEncounter` now has three unit tests (the binding and returned rows; the
statement scoped to `decidedAtUtc IS NULL`, ordered oldest-first, and exposing no decision column;
an empty queue returning `[]`) and an integration case asserting **a decided row leaves the queue
while an undecided one stays**. All three unit tests **passed on first run** — the method was
correct, it simply had no test. Recorded as a coverage gap, not a repair.

**QA-002** — the skip reason now distinguishes the two causes. Observed after the fix:

```
# configuration incomplete, so no connection was attempted (settings: missing or invalid: …)
```

Applied to seven files. `tests/integration/core/llm.test.ts` was **deliberately left alone**: it
says *"Azure OpenAI is not configured from this machine"*, which makes no false claim, and it belongs
to Epic 01.

**QA-003** — `agentRunWriter` and `fieldOutcomeRepository` integration files now delete their
`encounterID = -1` rows in `t.after`, matching the 2.4, 2.6 and 2.7 files.

**Suites after remediation**: `npm test` **124 pass / 0 fail** (121 before — three added);
integration **34 tests, 8 pass / 26 skipped / 0 fail**; typecheck clean.

---

## Scenario Results

| Status | Count | |
|---|---|---|
| ✅ Passed | 13 | All unit scenarios |
| ❌ Blocked (B11) | 25 | Every integration scenario |
| 🆕 Specified, not implemented | 7 | TC-MIG-006, TC-RUN-005, TC-OUT-007, TC-RET-007, TC-CON-005, TC-X-004, TC-PERF-001 |
| ⛔ Not applicable | 1 | REQ-02-01 — story 2.5 unbuilt |

### Passed

TC-MIG-003, TC-MIG-004, TC-MIG-005, TC-RUN-001, TC-RUN-002, TC-RUN-003, TC-OUT-001 *(unit half)*,
TC-OUT-002 *(unit half)*, TC-OUT-003, TC-RET-001, TC-RET-002, TC-RET-003, TC-RET-005, TC-X-001,
TC-X-002, TC-X-003.

### Blocked

TC-ENV-001/002/003, TC-MIG-001/002, TC-RUN-004, TC-OUT-004 *(integration half)*, TC-OUT-005/006,
TC-RET-004/006, TC-CON-001/002/003/004 *(integration halves)*, TC-DES-001/004 *(integration halves)*.

---

## Verdict

### ⚠️ CONDITIONAL PASS

**What is established**: the unit tier is complete, passing and genuinely strict — network-blocked,
guard-rule-enforced, with planted violations proving each guard fires. No defect was found in the production
code of any of the six built stories. **Line coverage, however, returns a different answer on every
run** — 65.19% to 88.18% on an unchanged tree — so the gate as written is unanswerable. Branch
coverage is exact at 93.81% and passes. See QA-004.

**What is not established**: that any of it works against a database. No CHECK constraint, foreign
key, primary key, unique constraint, column name or `@@ROWCOUNT` behaviour in this epic has been
exercised once.

**Conditions for an unconditional pass**

1. 🔴 **TC-ENV-001** — run the integration suite once against DEV. Converts 25 blocked scenarios.
2. 🔴 **Commit the work.** 34 uncommitted paths; HEAD predates the entire epic.
3. ✅ ~~**QA-001**~~ — resolved 2026-10-06.
4. ✅ ~~**QA-003**~~ — resolved 2026-10-06.
5. 🟠 **QA-004** — restate the gate in **branch** coverage (exact, 93.81%), or adopt a tool whose
   line figure reproduces. **Until then no line-coverage figure should appear in a release record.**
6. 🟡 **ISS-010** — the suite must complete under instrumentation before any gate can be automated.

None of the five is a defect in the epic's logic. Four are access, hygiene or process.

---

## Recommendation

**Do not treat this report as validation.** Treat it as evidence that the code is ready *to be*
validated, and that one session with database credentials would produce the real thing.

The most useful next action is not another QA workflow. It is `.env.local`.

---

## Sign-Off

**Validated By**: QA Agent
**Date**: 2026-10-06 (revised same day)
**Signature**: Conditional Pass — 13 of 38 scenarios executed; **5 of 10 quality gates met**
