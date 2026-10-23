# 2026-10-22: In-memory code index, no search tool, alternatives, uncertain diagnoses, SNF eval setting

**Repo:** `pacEHR_AI`, branch `feature/AITP-88-tool-outcomes-followup`. Paths are relative to that repo.
**Decided by:** Hem Singh, 2026-10-22, choosing the recommended option on four questions.

## Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Where code search comes from | **An in-process index** in `pacEHR_AI`, refreshed every 6 hours. Exact lookups stay in SQL |
| 2 | How the agent uses search | **No search tool in the run.** The model writes codes, the check after the model verifies them, and a code the tables reject gets **alternatives** from the index |
| 3 | How to fix the coding mistakes | **Prompt rules plus a check:** four ICD guideline rules in `CODING_RULES`, and `UNCERTAIN_DX` |
| 4 | The eval's setting | **A nursing-facility encounter:** 5112492, POS 31, `placeOfService: 'SNF'` |

## What changed

**Search (decision 1):**
- **`src/services/codeIndex.ts` (new):** `InMemoryCodeIndex`.
  - **Loading:** it loads the usable ICD rows and the CPT rows once, through `codeSetRepository.loadIndexRows`, and
    refreshes every 6 hours. A stale index is served while the refresh runs, and only one load runs at a time.
  - **Ranking:** more query words matched, then fewer extra words, then the whole phrase in order, then usage. These
    never count as extra: *unspecified*, *without*, and the word after *without*.
  - **Abbreviations** are spelled out (CHF, CKD, AFib…).
  - **Matching:** numbers match exactly, so "2" isn't "21". Words of 3+ letters match the words they begin.
  - **`children(code)`** returns the billable codes a header heads (`N18.3` → `N18.30`/`.31`/`.32`).
- **`src/repositories/codeSetRepository.ts`:** the per-run SQL search is removed. It's replaced by `LOAD_ICD_SQL` /
  `LOAD_CPT_SQL` and `loadIndexRows()`.
- **`src/types/coding.types.ts`:** `CodeSet` is now lookups only, and a new `CodeIndex` covers search and children.

**Search out of the run (decision 2):**
- **`src/tools/coding.ts`:** `search_codes` and its limits are removed. `lookup_icd_cpt` stays, but isn't bound.
- **`src/agents/encounter.ts`:** `TOOLS` is back to `[computeBmiTool]`.
- **`src/agents/middleware/model-call.ts`:** the per-request coding-tool filter is removed.

**Alternatives (decision 2):** `src/agents/coding.ts`, `withAlternatives()`.
- **What's offered:** each `NOT_IN_CODE_SET` code gets up to 3 alternatives. A header code first gets its children,
  then the index's best matches for the code's quote.
- **Every candidate is looked up for the encounter,** and only a usable one is offered. Its description comes from
  the lookup.
- **No waiting:** the run waits at most `ALTERNATIVES_WAIT_MS` (2 s) for the index. On its first load it goes without
  alternatives, and the load continues in the background.
- **Result format:** `alternatives` is now part of `CodedResult` (`state.ts`).

**Coding rules (decision 3):**
- **`src/schema/contract.ts` (`CODING_RULES`):**
  - no tool instructions;
  - a code-system-specific "write codes as … define them" line;
  - ICD rules for uncertain diagnoses, symptoms that are part of a coded diagnosis, the most specific code, and
    organisms only when named.
- **`src/agents/coding.ts`:** an ICD code whose quote calls the diagnosis uncertain ("probable", "suspected",
  "likely", "possible", "questionable", "rule out", "consistent with"…) goes to `NEEDS_REVIEW` with reason
  `UNCERTAIN_DX`.

**Eval setting (decision 4):** in `tests/eval/encounter.eval.ts`, `DEV_ENCOUNTER_ID` changes from 5112465 (POS 11,
office) to 5112492 (POS 31). `PLACE_OF_SERVICE` changes from "Group Home" to "SNF". Both encounters give prompt id
20. Field items are unchanged; the prompt now says "Place of Service is "SNF"".

## Why

The eval run of 2026-10-22 (`20261022-175058`) and the DEV measurements showed:
- **Per-run SQL search:** about 2 s per term on DEV, 10 terms over 10 s, with poor ranking. The model took `E11.00`
  from it.
- **The model called the search tool** in only about one run in three. Its mistakes were clinical (`A09` for a
  "probable" diagnosis, `R60.0` edema with CHF, `I50.32` for `I50.33`, `J13` with no organism), which search doesn't
  fix.
- **The eval's POS (office) belongs to no group** in `restrictedCPTByPOS`. That marked even nursing-facility codes as
  restricted, and the notes describe a nursing facility.

## Measured on DEV (2026-10-22)

**ICD index:**
- 228,853 rows → 63,254 billable codes, 20,475 words.
- Loading took 82–137 s **over the VPN from a laptop**, which read about 30 MB at about 0.3 MB/s. From inside Azure
  it still needs measuring.
- **Once loaded, 10 searches take 27 ms in total.**

**Top ICD result on DEV's real rows:**

| Search | First result |
|---|---|
| "type 2 diabetes" | `E11.9` |
| "heart failure" | `I50.9` |
| "CHF" | `I50.9` |
| "CKD stage 3" | `N18.30` |
| "acute on chronic diastolic heart failure" | `I50.33` |
| "atrial fibrillation" | `I48.91` |
| "pneumonia" | `J18.9` |
| "hypertension" | `I10` |
| "debility" | `R53.81` |

`children('N18.3')` gives `N18.30`, `N18.31`, `N18.32`.

## Found: DEV's CPT data isn't reliable (for the legacy team, meeting Q1)

- **The dates are placeholders.** 24,736 of 24,782 rows start 2020-01-01, and **every row ends 2027-01-01**. So
  `EXPIRED_ON_DOS` can never fire.
- **Deleted and non-CPT codes look valid:** `99311`–`99313` (deleted in 2006), `99327` (deleted in 2023), and `658`
  and `90300`, which aren't CPT codes.
- **The descriptions are custom, not AMA:** `99309` is "[30 min] Moderate MDM", `99327` is "Level 4 Comprehensive",
  and `20610` is "DRAIN/INJECT JOINT/BURSA". A clinical phrase therefore finds few current CPT codes, and CPT
  alternatives will be weak.
- **Until the table is fixed,** a CPT code's `VERIFIED` means only "it has a row". CPT suggestions should go to
  review.

## Before / after

*Filled in after the eval run.*
