# 2026-10-22: Coding answer key and coding report added to the eval

**Repo:** `pacEHR_AI`, branch `feature/AITP-88-tool-outcomes-followup`. Paths below are relative to that repo.

**What changed**
- `tests/eval/cases.json`: each case has a `coding` key: the ICD-10-CM and CPT/HCPCS codes a coder would expect, with
  S (required) and O (acceptable) items, written from the notes alone before any coding output was seen. Every case
  is `"status": "DRAFT"`.
- `tests/eval/score.ts`: `scoreCoding` and `codingRates`.
- `tests/eval/encounter.eval.ts`: reports coding precision, recall and verified share per system, tool use per run
  and cached prompt tokens, in the diagnostics, `summary.json` and `history.jsonl`.

**What did not change**
- The field gate: same answer key, benchmark, `RUNS_PER_CASE` and `TOLERANCE_POINTS`. `scoreRun` skips the `coding`
  key, so field precision and recall are measured as before.
- Coding is not gated. A coding gate needs a confirmed key and a measured spread, and comes in its own change.

**Why**
Epic 7 (story S6) adds code suggestions to the encounter agent; this measures them from the first run.

**Before / after**
No coding run exists yet, so there is no "before". The field benchmark is unchanged.

**Decision recorded**
A note that says not to add ICD or billing codes gets no codes of that kind (decided 2026-10-22). Q2's and Q3's keys
expect empty lists for that reason; Q2 still expects 99309, which the note states.

**Open**
A coder must confirm or correct each case's key: see the [review sheet](../Analysis/S6-Coding-Answer-Key-Review.md).
