# 2026-10-22: ABSTAINED answers for fields the note doesn't hold become null

**Repo:** `pacEHR_AI`, branch `feature/AITP-88-tool-outcomes-followup`. Paths are relative to that repo.

## What changed

**A new rule in `src/agents/middleware/evidence.ts`:**
- `settleSlot()` turns an `ABSTAINED` slot whose remark says the note doesn't hold the field into `null`. Typical
  remarks: "not documented in the note", "No … provided in the note", "not mentioned".
- `settleAnswer()` applies that to every template slot. It leaves the `coding` key alone.

**Where it runs:**
- **Evidence middleware (`afterModel`):** settles the answer before evidence and coding are checked, and writes the
  settled answer back as `structuredResponse`. It logs `settled`, the number of slots it made null.
- **Stream (`src/agents/encounter.ts`):** each `field` event, and each backfilled field, is settled the same way, so
  a streamed field still equals the final result.

## Why

`OUTPUT_RULES` says a field the note doesn't mention is `null`, "never ABSTAINED". In the 63 eval runs from 15 to 22
October, about one run in three broke this for most unmentioned fields:
- up to 81 `ABSTAINED` slots in a run;
- 4,500 to 6,000 output tokens, against about 1,600;
- 20 to 28 s, against 8 to 12 s;
- quotes that are often not in the note: 77 of 79 in one run.

**What this does not fix:** these runs don't lower field precision. `ABSTAINED` isn't counted as a fill, and the
wrong answers are spread across all runs: 59 in these runs, 65 in the others. They cost time and tokens, and they
would fill a review screen with dozens of false "AI abstained" flags.

## How the pattern was chosen

**Tested on all 1,411 `ABSTAINED` answers in those runs:**
- It matches 1,382.
- It matches none that is about a missing unit, a conflict, or a last-recorded value. Those are the real reasons to
  abstain, and they stay `ABSTAINED`.

**Kept on purpose:**
- "Pain level not quantified, patient denies pain";
- "No GI symptoms reported", which is a review-of-systems negative;
- "does not explicitly state …".

## What this does not do

- **Output still takes the same time.** The model still writes those slots, so this run still costs the extra
  tokens and seconds. Reducing the generation itself needs a prompt or model change, which is a separate step.
- **The eval gate is unchanged.** `ABSTAINED` was never a fill, so field precision and recall are scored as before.

## Before / after

| | Before (20261022-161231) | After (this change) |
|---|---|---|
| Field precision / recall | 89.5% / 80% (gate failed) | 90.5% / 77.5% (gate passed, run `20261022-175058`; this run also has S4–S6 coding on) |
| Most `ABSTAINED` in one run's result | 79 | 3 (the genuine ones) |
| Average output tokens / run time per run | 2,534 / 13.5 s | 2,239 / 13.2 s: the model still writes the slots, as expected |

## What the field-precision gap actually comes from

These fields are wrong in calm runs too, so they need their own fixes in the template or the prompt:
- `s1_f5` "Nature of Presenting Illness": the model adds "group home", the place of service, which the key forbids.
- `s1_f917` "Resident care plan reviewed?".
- `s33_f1958` "Total Time Spent in Counseling".
- `s69_f1212` "screened for cognitive impairment".
- Q3's `s4_f40` and `s4_f41`, the empty GI and GU exam headers: wrong in every run.
