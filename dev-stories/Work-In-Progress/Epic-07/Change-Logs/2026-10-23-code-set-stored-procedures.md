# 2026-10-23: code-set reads moved into `[AI]` stored procedures

**Repo:** `pacEHR_AI`, branch `feature/AITP-88-tool-outcomes-followup`. Paths are relative to that repo.

## What changed

**`src/repositories/codeSetRepository.ts` no longer holds SQL.** It calls four procedures, the way `summaryRepository`
calls its own:

| Migration | Procedure | Used for |
|---|---|---|
| `0013_create_usp_get_icd_code_facts.sql` | `[AI].[usp_getICDCodeFacts] @codes` | Checking the ICD codes the model suggested |
| `0014_create_usp_get_cpt_code_facts.sql` | `[AI].[usp_getCPTCodeFacts] @codes, @encounterId, @dateOfService` | Checking the CPT codes, including the place-of-service rule |
| `0015_create_usp_get_icd_index_rows.sql` | `[AI].[usp_getICDIndexRows]` | Loading the in-memory ICD index |
| `0016_create_usp_get_cpt_index_rows.sql` | `[AI].[usp_getCPTIndexRows]` | Loading the in-memory CPT index |

- `@codes` is a JSON array; each procedure casts it to the column's own type, so the code index is still used.
- The rules each statement applies, and why, are in the script's header, not in the repository.

**The migration rules allow reads of two shared schemas.** `src/core/databaseMigrations.ts` now has `READ_SCHEMAS`
(`DATA`, `Encounter`):
- an `[AI]` procedure may **read** them;
- creating anything outside `AI`, and writing anywhere outside `AI`, are still refused;
- every other schema (`Account`, `Patient`, …) is still refused, even for reads.

**`migrations/verification/post-apply-checks.sql`** has a new check 9: the four procedures exist (expect 4 rows).

## Why

To follow the API project's style: SQL lives in stored procedures, and the service only calls them.

## Numbering

Main's clinician-summary migrations (AITP-137, merged 2026-10-23) took 0011 and 0012, so these are 0013–0016. The
validator refuses two scripts with the same number.

## Verified on DEV (2026-10-23)

- **Applied:** only 0013–0016, not the whole set, so main's clinician-summary procedures were left as they were.
  Check 9 returns 4 rows.
- **Permissions:** `AI`, `DATA` and `Encounter` are all owned by `dbo`, so the procedures read the shared tables
  through ownership chaining. No grants were needed.
- **Live test:** `tests/integration/repositories/codeSetRepository.test.ts` passes 4 of 4: known codes found, an
  unknown one absent, the index loads and ranks the general code first, and 10 searches take 30 ms.
- **Place-of-service rule:** compared code by code with `dbo.usp_restrictedCPTByPOS` for all 18 codes in
  `DATA.restrictedCPTByPOS`:

  | Encounter | POS | Legacy restricts | Ours restricts | Differences |
  |---|---|---|---|---|
  | 5112465 | 11 (office) | 18 | 18 | none |
  | 5112492 | 31 (SNF) | 10 | 10 | none |

  `993X0` is listed in `DATA.restrictedCPTByPOS` but isn't a code in `DATA.cptCodes`, so a lookup reports it as not
  found.
- **Excluded rows:** `00000` and `99999` ("Non-Billable") are not returned.

## What this does not change

- The results are the same as the inline SQL's. `CodeFacts`, `checkCoding` and the index are unchanged.
- No eval was run for this change. The pre-push gate still needs one passing eval line for the branch's code.
