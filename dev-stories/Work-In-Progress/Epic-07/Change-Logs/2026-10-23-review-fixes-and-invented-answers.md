# 2026-10-23: code-review fixes 4–10, and invented answers (eval Q5)

**Repo:** `pacEHR_AI`, branch `feature/AITP-88-tool-outcomes-followup`. Paths are relative to that repo.

## Code-review fixes

| # | What was wrong | Change |
|---|---|---|
| 4 | The rule that makes a "not in the note" `ABSTAINED` null also nulled genuine abstentions: "Unit not specified", "No unit provided", "Not documented today, only last recorded" | `src/agents/middleware/evidence.ts`: a remark that names a unit, a last-recorded value or a conflict stays `ABSTAINED`. Measured on all 1,878 saved abstentions: the 1,829 nulled before are still nulled; none of them names one of these reasons |
| 5 | The model's unchecked `coding` block stayed in `structuredResponse`, beside the checked `result.coding` | The evidence middleware removes it. `structuredResponse` now holds template slots only |
| 6 | Problem-list codes were compared as stored, so `E119` or `e11.9 ` didn't match `E11.9` and a known diagnosis showed as new | `src/agents/coding.ts` normalises them as it normalises suggestions. The SQL filter (`isDeleted = 0`) stays: the UI's own problem-list procedure uses it |
| 7 | `codeSetMode` said `FORMAT_ONLY` for both systems when only one table failed | Now one mode per system: `codeSetMode: { icd, cpt }`. **This changes the output format** ([coding output format](../Tech-Specs/2026-10-22-coding-output-format.md) updated) |
| 8 | The code index loaded only on the first rejected code, and after a failed load every run retried a full table read | `src/services/codeIndex.ts`: `warm()` loads both systems at service start (`src/server.ts`). After a failed load, runs go without alternatives for 60 s (`RETRY_MS`) before the next try |
| 9 | The note was re-normalised once for every suggested code | Normalised once per check |
| 10 | CLAUDE.md said Epic 7 was "not built", and the eval doc and eval code still counted `search_codes`, which was removed | CLAUDE.md status updated; the `search_codes` count removed from `tests/eval` |

## Invented answers (eval Q5)

**What happens:** Q5 is a one-line edit command ("Please remove the review of systems section and in the assessment
and plan add probable viral gastroenteritis…"). In some runs the model invents a whole patient and fills the template:
room 204, second floor, Full Code, lisinopril, no known allergies. **None of those quotes are in the note.**

**It isn't caused by coding.** It happened on 2026-10-21, before coding existed, and on main's own failed run
`20261023-092449` (Q5 precision 21.4%).

**Measured on the 144 saved runs (2026-10-15 to 22):**

| | Filled fields | Quotes not in the note |
|---|---|---|
| The 4 invented Q5 runs | 10–25 | **100%** |
| Every other run | — | **31% at most** |
| Good Q5 runs | 1 | — |

**Change, in the evidence middleware:** when an answer has at least 5 FOUND fields and at least 75% of their quotes
aren't in the note, those unlocated fields become null. Fields whose quotes are in the note stay. On the saved runs this
rule trips on exactly the 4 invented runs and nothing else. The log line `evidence checked` now has `dropped`.

**Why not drop every unlocated quote?** It would remove 118 correct values to remove 66 wrong ones, and the client's
priority is recall. Below the threshold, an unlocated quote is still kept and flagged LOW for review, as before.

**Known limit:** the stream sends each field as it arrives, before the whole answer can be judged. In an invented
answer the streamed fields carry `NOT_FOUND` / `LOW`, and `done` then has them as null. The eval's stream check runs on
a case that has never tripped the rule.

## Verified

- 316 unit tests pass (5 new); eslint and typecheck clean.
- **No eval was run for this change.**
