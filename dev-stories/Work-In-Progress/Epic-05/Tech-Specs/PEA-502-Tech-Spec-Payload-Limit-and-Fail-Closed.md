# PEA-502 — Tech Spec: End Every Guard Block the Same Fail-Closed Way and Cap the Note Size

**Type:** Story · **Epic:** E5 · **Points:** 3 (JS ticket) · **Status:** Code done, committed locally (`0d7e5f9`, plus the size tests in `5cee0a6`); the limit kept at 20,000
(D9, decided 2026-10-15); the blocked-run wording stays a placeholder for Phase 1; D8 (FAILED runs) is open
**Benchmark:** [`js-tickets/epic-05-guardrails.md`](../../js-tickets/epic-05-guardrails.md) PEA-502
**Depends on:** PEA-501; Epic 4 PEA-403 and PEA-407 (done); Epic 9 (message, HTTP status, audit write)
**Code baseline:** `pacEHR_AI` branch `PacEHR-AI-Develop-Main` at `b93f989` (Epic 4 merged in PR 12886, 2026-10-15)
**Files still to change:** `src/agents/failure-modes.ts` · `tests/unit/agents/failure-modes.test.ts`

---

## 1. User story

As a platform engineer, I want every guard to block a run through one fail-closed path, and an oversized note rejected
before masking, so that a blocked run is always recorded and an oversized request cannot inflate cost or latency.

A block that throws rejects `invoke` and skips the outcome hook, so the runs most worth reviewing would drop out of the
record. Every guard step therefore ends the run by jumping to the end with a reason code. A size limit applies the same
rule to cost: a note far larger than real dictation is refused by one length check.

## 2. Scope (from the JS ticket)

| In | Out |
|---|---|
| The one guard `beforeAgent` hook and its step order: injection scan, size limit, PHI mask | Rate limiting, authentication and tenancy (the .NET proxy, Epic 9) |
| The size limit `MAX_NOTE_CHARS` and its PAYLOAD_TOO_LARGE block | The audit row and the HTTP response (Epics 2 and 9). This ticket guarantees the outcome hook runs |
| One exported generic message for every blocked run | |

## 3. Already built on `b93f989`, so this story doesn't rebuild it

| Requirement | Where | Test |
|---|---|---|
| One `beforeAgent` hook, steps in code order, one try/catch | `src/agents/middleware/guard.ts` | `encounter.test.ts`, `GUARD_STEPS` asserted in every block case |
| `block()` logs run id, step and reason code, returns `jumpTo: 'end'` | `guard.ts:33-36` | `BLOCKS` table: 7 cases |
| `canJumpTo: ['end']` declared | `guard.ts:28` | *"without canJumpTo the block rejects invoke instead of ending the run"* |
| A throwing step ends the run as `GUARD_STEP_FAILED`, BLOCKED; the log names the step and error class only | `guard.ts` `catch` | *"a step that throws is a block, logged by step and class only"* |
| `MAX_NOTE_CHARS = 20_000`, a constant with its measurement comment and a `ponytail:` note | `src/guards/limits.ts` | `tests/unit/guards/limits.test.ts`: at the cap passes, cap + 1 blocks |
| `reasonCode` in state; `outcome.ts`, the only `afterAgent`, turns any GUARD code into BLOCKED | `state.ts`, `outcome.ts` | Every `BLOCKS` case asserts `outcome === 'BLOCKED'` |

Measured on `b93f989` (2026-10-15): `tsc --noEmit` is clean and `npm test` passes **196 of 196**.

## 4. What's left to build: the generic message

`src/agents/failure-modes.ts`, after `REASON_CODES`:

```ts
/**
 * What the clinician is told for every BLOCKED run, whatever the reason (PEA-502). It names no phrase, pattern class or
 * reason code: telling the sender what tripped a guard is a map of the guard. Epic 9's endpoint returns it.
 */
// ponytail: placeholder wording until product and the Epic 9 owner agree it.
export const BLOCKED_RUN_MESSAGE = 'This note could not be processed automatically. Please complete the fields manually.';
```

`tests/unit/agents/failure-modes.test.ts`, new test:

```ts
test('the blocked-run message names no reason code and no pattern class', () => {
  assert.ok(BLOCKED_RUN_MESSAGE.trim().length > 0);
  for (const name of [...Object.keys(REASON_CODES), ...PATTERN_CLASSES]) assert.doesNotMatch(BLOCKED_RUN_MESSAGE, new RegExp(name, 'i'));
  assert.doesNotMatch(BLOCKED_RUN_MESSAGE, /inject|jailbreak|prompt|pattern|block/i);
});
```

`PATTERN_CLASSES` comes from PEA-501's `#guards/injection.js`. Until PEA-501 lands, check `REASON_CODES` only.

**Contract for Epic 9's endpoint:** a run whose `outcome` is `BLOCKED` returns `BLOCKED_RUN_MESSAGE` and the `runId`,
never the `reasonCode` or the `patternClass`. Record this as an acceptance criterion on the Epic 9 endpoint story.

## 5. Acceptance criteria (JS ticket, with the test that proves each)

| # | Criterion | Test | State |
|---|---|---|---|
| 1 | A note longer than `MAX_NOTE_CHARS` (20,000) with no injection pattern ends BLOCKED with PAYLOAD_TOO_LARGE. The steps run are `injection_scan` then `payload_limits`; PHI masking never starts; no model request | `BLOCKS` "an oversized note" (seeded); `guard-corpus.test.ts` with the real limit: `MAX_NOTE_CHARS` reaches the model, one over ends `PAYLOAD_TOO_LARGE` (`5cee0a6`) | Done |
| 2 | A note of exactly `MAX_NOTE_CHARS` passes the limit | `limits.test.ts` | Done |
| 3 | An ordinary note passes both checks and reaches PHI masking | `encounter.test.ts` clean run (steps include `phi_mask`); PEA-504 benign set end to end | Done |
| 4 | Every block returns `jumpTo: 'end'` from a hook declared `canJumpTo: ['end']`. `invoke` resolves, and the outcome hook tags the run BLOCKED with its reason code | `BLOCKS` table | Done |
| 5 | Without the `canJumpTo` declaration, a block rejects `invoke` | `encounter.test.ts` | Done |
| 6 | A step that throws ends the run as GUARD_STEP_FAILED, BLOCKED. The log names the step and the error class only | `encounter.test.ts` | Done |
| 7 | Every BLOCKED run maps to one exported generic message that names no matched phrase, pattern class or reason code | §4; `failure-modes.test.ts` (`0d7e5f9`) | Done. Wording is a placeholder (D8) |

## 6. Before you build (due diligence, from the JS ticket)

- [x] **Decide the limit.** *Decided 2026-10-15 (Hem Singh): keep 20,000 for Phase 1 (D9).* 9 of the 1,000 production notes (0.9%) are over 20,000 characters, the longest 54,738.
  Each is refused whole, which costs recall. At 3.43 characters per token, the longest is about 16K tokens.
  Options:
  - raise the cap;
  - count tokens instead;
  - accept the refusal rate.

  Owner: us. Whichever is chosen, change the constant and its measurement comment together.
- [ ] **Confirm the request-body cap that Epic 9 sets.** The scanner runs before the limit, so it sees notes of any size.
  PEA-501 times it at 60,000 characters, about 1 ms. Time it at Epic 9's cap if that's larger.
- [x] **Confirm the Epic 2 audit table accepts a blocked run.** Checked in
  `dev-stories/Work-In-Progress/Epic-02/Epic-02-AI-Engine-Handover-and-Data-Design.md`:
  - `agentRun.reasonCode` has no CHECK (line 230; the JS ticket cites line 217);
  - `CK_agentRun_reachedModel` lets only a BLOCKED run have a null `promptHash` or `modelDeployment` (line 694);
  - the worked example (line 679) is a BLOCKED row with `INJECTION_BLOCKED`.
- [x] **Decide whether the audit row also needs the injection class.** Decided 2026-10-15: no, the log is enough (PEA-501 §8, D2).
- [ ] **Agree the generic message's wording, and the HTTP status for a blocked run,** with product and the Epic 9 owner.
  *2026-10-15 (Hem Singh): the placeholder ships for Phase 1; the final wording is still to agree.*

## 7. Decisions and open items

| # | Item | Status |
|---|---|---|
| D5 | The limit is a module constant, `MAX_NOTE_CHARS`, not a setting. Under `pacEHR_AI/CLAUDE.md` § Numbers, only environment-varying limits are settings | **Adopted** from the JS ticket. Replaces our earlier `MAX_NOTE_LENGTH_CHARS` setting. If one environment ever needs a different cap, it becomes a setting then |
| D6 | "No guard throws" is shown by behaviour tests (criteria 5 and 6), not by a lint rule | **Adopted** from the JS ticket. Our earlier ESLint `ThrowStatement` rule is dropped |
| D7 | One constant for BLOCKED runs, not a per-reason lookup | **Adopted** from the JS ticket. Our earlier `clinician-message.ts` is dropped |
| D8 | **What the clinician sees for a FAILED run.** The JS ticket covers BLOCKED only. FAILED runs include `PROMPT_CONTENT_FILTERED`, `MODEL_CONTENT_FILTERED` and `MODEL_CALL_FAILED` | **Open (gap in the JS ticket).** Proposal: the same message, never the code. Decide with the Epic 9 owner. (On 2026-10-15 the BLOCKED wording was settled as "placeholder for Phase 1"; the FAILED case wasn't asked) |
| D9 | The limit refuses 0.9% of real notes | **Decided 2026-10-15 (Hem Singh): keep 20,000 for Phase 1.** The 0.9% is an accepted trade-off, to review with production data later. No code change |

## 8. Definition of Done

- [x] `BLOCKED_RUN_MESSAGE` and its test, as in §4 (`0d7e5f9`). The test file's header comment also covers the message
- [ ] The Epic 9 contract (§4) is recorded on the Epic 9 endpoint story
- [x] The limit decision (§6) is recorded, with `MAX_NOTE_CHARS` and its comment updated if the value changes (kept
      at 20,000, so no change)
- [ ] D8 is answered, or tracked with an owner
- [x] `npm run typecheck`, `npx eslint src tests`, `npm test` and `npm run build` are clean (2026-10-15: 217 / 217
      after `0d7e5f9`; 390 tests, 379 passing, 0 failing, 11 todo after the additions; the PR pipeline, `pipelines/pr-validation.yml`, runs `npm test` and the build)
- [ ] `npm run eval` passed on exactly the code being pushed, and `tests/eval/history.jsonl` is committed with it. The
      pre-push hook (`npm run hooks:install`) refuses a push that changes `src/` without it
