# ICD/CPT Coding in the Encounter Agent: Implementation Plan

**For:** the engineers building Epic 7 in `pacEHR_AI`, and the lead who signs it off
**From:** Hem Singh · **Date:** 2026-10-22 · **Status:** Draft, revised after the flow and performance review (§8)
**Baseline:** `pacEHR_AI` `9cbfe57`, `pacEHR_API` `dc7316ec3`. File and line references are to these commits.
**Builds on:** [PEA-704 tech spec](PEA-704-Tech-Spec-ICD-CPT-Format-Check.md) (normalisation, format patterns, D1–D5) and
[Epic-07-Additions](Epic-07-Additions.md) (A1–A7).

---

## 1. The behaviour

1. The clinician submits the transcript.
2. The encounter agent fills the template fields, as today.
3. In the same run, it suggests **ICD-10-CM** and **CPT/HCPCS** codes, **chosen from our own code tables**
   (`DATA.icdCodes`, `DATA.cptCodes`) through tools.
4. Every suggested code is checked again by plain code after the model answers. Each code comes back with:
   - its description, taken from the table;
   - the quote from the transcript that supports it;
   - a status.

   A code the tables don't support is **flagged, not dropped**.
5. The account's existing switches, **"Suppress AI Coding - ICD-10"** and **"Suppress AI Coding - CPT"**, decide on
   every run which code types are suggested.
6. The service **saves nothing**. The clinician reviews the codes in the UI, which saves them through the existing
   endpoints.

## 2. Decisions

| # | Decision | Chosen (2026-10-22) | Why |
|---|---|---|---|
| C1 | Where coding runs | **Inside the encounter agent.** The tools join `TOOLS`, and the codes are part of the same structured answer | One run, one note, one prompt; the tools stay reusable |
| C2 | A code the tables don't support | **Flag it** (`NOT_IN_CODE_SET` with reasons); never drop it silently | A stale table must not hide a real diagnosis; the clinician decides |
| C3 | Configuration | **The two existing per-account switches**, read from `Account.accounts` on every run. No new table or settings | They already exist and are managed in the account screen (`usp_addEditAccount`) |
| C4 | What each code returns | **Code, quote, status**, plus the table description, `isExisting` (ICD) and `source: 'AI'` | The clinician sees why each code was suggested; descriptions never come from the model |
| C5 | Where the tools read the tables at run time | **Revised 2026-10-22:** exact lookups use SQL on every run. **Search uses an in-memory index** (`src/services/codeIndex.ts`) refreshed every 6 hours | Per-run SQL search measured 2–10 s on DEV with poor ranking; the index answers 10 searches in 27 ms |
| C6 | The extra model round for search | **Revised 2026-10-22: no search tool in the run.** The model writes codes; `checkCoding` verifies every one and attaches up to 3 alternatives from the index to a rejected code. "Only our codes" is enforced by status | The model used the search tool in only about one run in three, and its mistakes were clinical |
| C7 | A coding failure | **Never fails the run.** The template fields are returned regardless (§3.6, §3.5) | Coding is an addition to extraction, not a precondition |

Unchanged from the [PEA-704 spec](PEA-704-Tech-Spec-ICD-CPT-Format-Check.md):
- D2: normalise first (`E1119 → E11.19`).
- D3: the code shapes in scope.
- D5: `checkCodeFormat()` is a pure function shared by the tools and the middleware.

**D1 changes:** the lookup takes a list of codes, not one, to save model round trips (§3.3).

## 3. Design

### 3.1 Flow

```
POST transcript ─► guard (beforeAgent)
                     • load template ║ NEW: read the account's coding switches     (in parallel)
                       a failed switch read = both suppressed, logged; the run continues (C7)
                       ──► _codingSwitches { icd, cpt }
                     • load prompt (as today)
                     • NEW: schema gets a `coding` block for the enabled systems only
                   model-call (wrapModelCall)
                     • NEW: bind search_codes / lookup_icd_cpt only if a system is enabled
                     • NEW: append CODING_RULES to the system prompt
                   ┌─ model turn 1 ─► search_codes({ICD10CM, terms[]}) ║ search_codes({CPT, terms[]})   (one turn, parallel)
                   │                   └─► CodeSet.search: one OPENJSON query per system ─► DATA tables (read-only)
                   └─ model turn 2 ─► structured answer: template slots … then coding { icd[], cpt[] }
                      (same system prompt + note prefix as turn 1, so Azure prompt caching applies)
                   evidence (afterModel)  • slots as today; skips `coding`
                   NEW coding (afterModel)        independent of evidence: neither reads the other's output
                     • normalise + checkCodeFormat
                     • in parallel: ICD lookup ║ CPT lookup ║ problem list (one query each)
                       a failed code-set query = codeSetMode 'FORMAT_ONLY'; the run continues (C7)
                     • quote check, isExisting, status rules, list caps
                     ──► state.coding (public)
                   outcome (afterAgent) ─► result: fields + evidence + coding
```

### 3.2 Components

| File | New or changed | What it does |
|---|---|---|
| `src/types/coding.types.ts` (built in S1; the repo has no `#coding` import alias, and domain types live in `src/types/`) | New | The **`CodeSet` interface**: `search(system, terms, at)` and `lookup(system, codes, at)`. Tools and middleware depend only on this, so the data source can be swapped (a vendor API, IMO, a cache) without touching them |
| `src/repositories/codeSetRepository.ts` | New | The SQL implementation of `CodeSet`. Parameterised, read-only queries on `DATA.icdCodes`, `DATA.cptCodes`, `DATA.restrictedCPTByPOS`. Exported as the singleton `codeSet`, like the other repositories |
| `src/repositories/accountRepository.ts` | New | `getCodingSwitches(accountId)` |
| `src/repositories/patientRepository.ts` | Changed | `getActiveProblemCodes(encounterId)`: one query joining `Encounter.encounter` to `Patient.patientDiagnosis`, because `ExtractionContext` has no `patientID`. The index `(patientID, isActive, isDeleted)` covers it |
| `src/tools/coding.ts` | New | `normaliseCode()`, `checkCodeFormat()` (PEA-704), and the tools `search_codes` and `lookup_icd_cpt`. The tools read `_codingSwitches` from the tool runtime's state: filtering `request.tools` only hides a tool from the model, while the compiled graph's tool node can still run every tool in `TOOLS` |
| `src/agents/coding.ts` (built in S5 as `checkCoding()`, called by the evidence middleware's `afterModel`: the spine allows one `afterModel`, which the test "no hook is defined twice" enforces) | New | `afterModel`: re-verifies every code and builds `state.coding`. Always runs; the model can't skip it. It doesn't depend on running before or after `evidence`: LangChain runs `after*` hooks in reverse array order |
| `src/schema/contract.ts` | Changed | `CodeSuggestion` (what the model writes) and `CODING_RULES` (prompt text, stated once) |
| `src/schema/builder.ts` | Changed | `build(config, switches)` appends `coding` **last**, so template fields still stream first |
| `src/agents/state.ts` | Changed | `_codingSwitches` (private), `coding` (public result) |
| `src/agents/middleware/guard.ts` | Changed | Reads the switches **in parallel with** the template load, in its own `try` so a failure suppresses coding instead of returning `GUARD_STEP_FAILED`; passes them to the schema builder |
| `src/agents/middleware/model-call.ts` | Changed | Filters `request.tools` by the switches; appends `CODING_RULES` when coding is on; logs `usage_metadata.input_token_details.cache_read` next to the token counts |
| `src/agents/middleware/evidence.ts` | Changed | `checkEvidence` skips the `coding` key |
| `src/agents/encounter.ts` | Changed | Adds the tools to `TOOLS` and the coding middleware to `MIDDLEWARE`. `stream` skips `coding` in **both** places that loop over top-level keys: the `FieldScanner` loop and the backfill (`missed`) |
| `tests/eval/score.ts` | Changed | `scoreRun` skips `coding`. Otherwise it's scored as a template slot, precision drops and the push gate fails |

`checkEvidence`, the stream and `scoreRun` use one shared exported name for the key (`CODING_KEY`), so no loop
can miss it.

### 3.3 The tools

**`search_codes`** gives the model candidates from our tables, so it can only choose codes we have.

- **Input:**
  - `codeSystem`: `'ICD10CM' | 'CPT'`
  - `terms`: 1–10 clinical phrases, each 3–80 characters, for example `"type 2 diabetes with neuropathy"`.

  The rules tell the model to search **once per system with all its terms**, and to search again only for a term
  that found nothing.
- **Output:** up to **5 candidates per term**, at most **40 per system per call**. They come back as compact text
  lines (`E11.40 — Type 2 diabetes mellitus with diabetic neuropathy, unspecified`), not JSON, because they're read
  by the model on its next turn.
- **One query per system, not one per term.** The terms go in as one JSON parameter, are expanded with `OPENJSON`,
  and `CROSS APPLY (SELECT TOP 5 …)` picks the candidates for each term. That makes one round trip to the database
  per system, and the ICD and CPT calls run at the same time.
- **ICD query:**
  - filters on `billable = 1 AND isActive = 1 AND ISNULL(isDelete, 0) = 0`, with every word of the term in
    `code + Description`, matching how `proc_getICDCodes` finds codes. `proc_getICDCodes` doesn't filter
    `isDelete`;
  - **groups by `code`**: `DATA.icdCodes` is a heap with no primary key, so one code can have several rows (DEV
    check 6);
  - orders by exact-code match, then `UsageCount` descending, then code. `proc_getICDCodes` orders by code only and
    cuts at 50, so good matches get lost.
- **CPT query:**
  - every word must be in `codeShortDesc` or `userFriendlyDescription`. **Never search `codeLongDesc`**
    (`VARCHAR(4000)`): it makes each scan slower, and it would flood the model with tokens. `proc_getCPTCodes` only
    matches the *start* of the code or description, so "knee injection" never finds 20610;
  - returns `codeShortDesc` as the description;
  - the code must be active on the date of service: `startDate <= DOS <= endDate`. CPT dates are `DATE` columns, so
    they're compared directly, without `TRY_CONVERT`. The comparisons are inclusive; `proc_getCPTCodes` uses strict
    `<`/`>`, which loses codes on their first and last day;
  - the code must not be refused for the encounter's place of service. **Corrected in S1:** `restrictedCPTByPOS` is
    an **allow-list**, not a block-list. `usp_restrictedCPTByPOS` refuses a code that is listed under a `posName`
    the encounter's POS doesn't have; an unlisted code is allowed anywhere. The CPT screen runs this check before
    adding a code ("This encounter has a Place of Service that does not allow the selected CPT to be billed").
    The repository copies the rule exactly, using the POS id from `Encounter.encounter.POS` rather than the
    context's POS name, and, like the procedure, ignores `isActive`. The agent therefore never suggests a code the
    screen would refuse.
- **Typed parameters:** `database.execute` passes JS strings untyped, so mssql sends them as `NVARCHAR`.
  `cptCodes.code` is `VARCHAR(100)`, so comparing against an `NVARCHAR` value converts the column and can't seek
  `idx_CPTCodes_code`. The `OPENJSON … WITH` clause declares `VARCHAR(100)` for CPT and `NVARCHAR(50)` for ICD, so
  every join matches the table type. `database.ts` needs no change.
- **Durations:** every query logs how long it took. The DEV integration test sets a time budget (§4, S1).
- **Refusals** (PEA-701 contract):
  - `TERMS_EMPTY`;
  - `CODE_SYSTEM_SUPPRESSED`: a second line of defence; the tool isn't bound in that case anyway.

  A database error is `FAILED`.

**`lookup_icd_cpt`** (PEA-704, now backed by the database) checks codes the model already has in mind.

- **When:** only for codes that **didn't** come from `search_codes`. Calling it on search results adds a third model
  round (about 14.5k input tokens and 2–4 s) and tells us nothing: the middleware checks every code anyway.
- **Input:** `{ codeSystem, codes: string[] }`, 1–20 codes. One `OPENJSON` query per call, with the same typed
  columns as the search.
- **Output, per code:** `{ code (normalised), status, description | null, reasons[] }`. This uses the same rules as
  the middleware (§3.5), so the model sees the verdict the clinician will see.
- **PEA-704's format-only behaviour stays inside it as step 1.** If the code set is unavailable, the tool returns
  `mode: 'FORMAT_ONLY'` with `status: 'NEEDS_REVIEW'`, as the PEA-704 spec describes.

**Fixed values** are constants in `coding.ts`, like `BMI_DECIMAL_PLACES`, not settings:
- 10 terms per search, 80 characters per term;
- 5 candidates per term, 40 per system per call;
- 20 codes per lookup;
- 12 ICD and 6 CPT codes in the answer (§3.4).

### 3.4 The output contract

**What the model writes:** the last key of the response schema. Strict mode: every key is required, and absence is
`null`.

```ts
coding: {
  icd: CodeSuggestion[],   // key present only when ICD is enabled; [] means nothing to code
  cpt: CodeSuggestion[],   // key present only when CPT is enabled; [] means nothing to code
}
CodeSuggestion = { code: string, found_in: string, confidence: 'HIGH' | 'MEDIUM' | 'LOW' }
```

- **Both systems suppressed:** there is no `coding` key, no coding tools, no `CODING_RULES`, and no extra tokens.
- **Order:** the order of the array is the model's priority; the primary diagnosis comes first.
- **Size:**
  - at most **12 ICD and 6 CPT** codes. The rules state the caps, and the middleware cuts anything beyond them and
    logs the count;
  - `found_in` is the **shortest span** that supports the code.

  The `coding` block is written last, so it doesn't delay the first field, but every token adds to the total run
  time.

**What the run returns** (`state.coding`, built by the middleware):

```ts
{
  icd: CodedResult[], cpt: CodedResult[],
  switches: { icd: boolean, cpt: boolean },   // what this run used
  codeSetMode: 'DATABASE' | 'FORMAT_ONLY',
}
CodedResult = {
  code, codeSystem, description: string | null,  // description from the table, never from the model
  found_in, quoteMatch: 'EXACT' | 'NORMALIZED' | 'NOT_FOUND',
  status: 'VERIFIED' | 'NEEDS_REVIEW' | 'NOT_IN_CODE_SET',
  reasons: string[],                               // e.g. ['EXPIRED_ON_DOS'], ['POS_RESTRICTED'], ['EM_LEVEL']
  isExisting: boolean | null,                      // ICD: on the patient's active problem list; CPT: null
  confidence, source: 'AI',
}
```

### 3.5 Status rules

**Duplicates** (the same normalised code) are merged first, keeping the first one.

| Status | When | Example `reasons` |
|---|---|---|
| `NOT_IN_CODE_SET` | The code fails the format check, isn't in the table, isn't valid on the date of service, isn't billable (ICD), or is restricted for the place of service (CPT) | `FORMAT_INVALID`, `NOT_FOUND`, `EXPIRED_ON_DOS`, `NOT_BILLABLE`, `POS_RESTRICTED` |
| `NEEDS_REVIEW` | The code is in the table, but the quote isn't in the transcript, or confidence is LOW, or it's an **E/M code (99202–99499)**: the level depends on MDM or time, which the model is weakest at | `QUOTE_NOT_FOUND`, `LOW_CONFIDENCE`, `EM_LEVEL` |
| `VERIFIED` | Everything above passes | — |

### 3.6 The account switches

- **Read:**
  ```sql
  SELECT ISNULL(isAICodingSuppressed,0) AS icdSuppressed,
         ISNULL(isCptAICodingSuppressed,0) AS cptSuppressed
  FROM Account.accounts WHERE accountID = @accountId
  ```
  This uses the same unset-means-not-suppressed default as `usp_AccountList:103-104`.
- **When:** read on every run, in the guard, with no cache, so a change in the account screen applies to the next
  run.
- **No account row, or the read fails:** treat both switches as **suppressed**, log it, and **carry on with the
  template fields**. It's the safe choice for billing data. The read runs in its own `try`; inside the guard's
  shared `try`, a failure would return `GUARD_STEP_FAILED` and block the whole extraction (C7).
- **Timing:** the read runs in parallel with the template load, so it adds no time to the run.

| ICD switch | CPT switch | Schema | Tools bound | Prompt |
|---|---|---|---|---|
| off | off | `coding.icd`, `coding.cpt` | both, both systems | `CODING_RULES` |
| on | off | `coding.cpt` only | both, CPT only | rules for CPT |
| off | on | `coding.icd` only | both, ICD only | rules for ICD |
| on | on | no `coding` | none | none |

The UI also checks these switches. A second check in the service is deliberate.

### 3.7 The prompt

**`CODING_RULES`** lives in code, next to `OUTPUT_RULES`, so it is versioned and tested, and is appended by
`model-call`. It says:
- Call `search_codes` once per enabled system, with every condition and procedure as a term, before writing any code.
- Write only codes returned by `search_codes` or confirmed by `lookup_icd_cpt`. Write the **code only**, never a
  description.
- `found_in` is the exact span of the transcript that supports the code.
- Put the primary diagnosis first.
- Don't code uncertain diagnoses ("probable", "suspected", "rule out"); code the documented symptoms instead. This
  follows the ICD-10-CM outpatient guideline (Section IV).
- No modifiers and no units (Q3).
- Suggest an E/M level only if the transcript documents medical decision-making or time.

**DB prompt conflict:** the DEV prompt (id 20) still contains the legacy free-text ICD/CPT instructions ("CODE (desc)
<<justification>>"). These conflict with `CODING_RULES`. The prompt owner must remove them before go-live; this is
also meeting Q5. Until then, the rule "Where an instruction above conflicts with these rules, these rules apply" covers
it, as it does for `OUTPUT_RULES`.

### 3.8 Streaming and latency

- **Template fields:** still stream one by one. `coding` is the last member and is only returned in `done`, after the
  middleware has verified it. Per-code events aren't needed until the Review AI Output screen asks for them.
- **Cost:** one more model turn, the search round, **before the first field**.
  - **Baseline** (eval 2026-10-21, template 457, gpt-4.1, 16 runs): each run makes one model call of
    14,234–14,697 input tokens, writes 845–4,724 output tokens and takes 4.7–22.7 s.
  - **The search round** resends the same prompt, so about **+14.5k input tokens** (roughly double) and an estimated
    **+2–4 s before the first field**.
  - **Turn 2** grows by the search results. With the §3.3 caps that's at most 80 short lines, a few thousand tokens.
- **Mitigations:**
  - one batched search per system, both in the same turn (C6);
  - no lookup on codes that came from a search (§3.3);
  - short results.
- **Prompt caching:**
  - turn 2 starts with the same system prompt and note as turn 1 (`model-call.ts` already puts them first), so Azure
    OpenAI's automatic prompt caching can serve most of it at lower cost and latency;
  - `model-call` logs `cache_read` to prove it. If the log shows no caching, the eval shows the full cost.
- **Schema variants:** the four switch combinations give up to four strict schemas per template. The first request
  for each one pays the provider's schema-compile delay once.
- **Eval gate** (S6):
  - the `firstFieldMs` delta against the latest run in `tests/eval/history.jsonl`;
  - tool rounds per run (fails above an average of 1);
  - `cache_read`;
  - output tokens of the `coding` block.

  The lead sets the budgets.

### 3.9 Security and compliance

- **SQL:**
  - parameterised queries only, with no dynamic SQL (unlike `proc_getICDCodes`);
  - `%`, `_` and `[` in terms are escaped before `LIKE`;
  - term counts and lengths are capped in the zod schema.
- **Database login:** read-only on the `DATA` tables and `Account.accounts`. Close item 6 of the meeting sheet
  confirms access.
- **Logs:** counts per status and system only, never codes, quotes or terms. Codes tied to an encounter are clinical
  data.
- **CPT licence (P1):**
  - `search_codes` sends CPT descriptions to Azure OpenAI. That is within the BAA and is retrieval-style use under the
    AMA AI Addendum, but compliance must sign it off.
  - Until it does, the **existing CPT switch** keeps CPT off for production accounts, so no new configuration is
    needed.
  - ICD-10-CM is public domain.

## 4. Stories and build order

| # | Story | Size | Depends on | Acceptance in short |
|---|---|---|---|---|
| S0 | **A1 + A7**: reducer keeps repeated outcomes; `TOOLS` contract test. **A hard prerequisite of S3**: two parallel `search_codes` calls produce identical outcomes, which the current reducer merges | S | — | Two calls of the same tool, sequential **and parallel**, give two `toolOutcomes` entries; the test fails if a tool in `TOOLS` breaks the contract |
| S1 | **Code-set access**: `CodeSet` interface, `codeSetRepository`, `normaliseCode`, `checkCodeFormat` | M | S0, DEV checks 2, 3, 5, 6 | Unit tests on the patterns (D3); repository tests with a mocked `database.execute`; the DEV integration test returns `E11.9` and `99213`, no duplicate codes and no `isDelete` rows, and each query stays inside the **time budget** (for example p95 under 300 ms for a 10-term search) |
| S2 | **PEA-704 `lookup_icd_cpt`**: batched, database-backed, format-only fallback | S | S1 | Statuses and reasons as in §3.5; `FORMAT_ONLY` when the code set is unavailable; typed `OPENJSON` columns |
| S3 | **`search_codes`** (new story, number to assign) | M | S0, S1 | Ranked candidates; DOS and POS filters; `LIKE` escaping; one query per system; the 5-per-term and 40-per-call caps; compact text output; refuses a suppressed system using the runtime state |
| S4 | **Switches and the output contract**: `accountRepository`, guard, schema builder, state, tool filtering, `CODING_RULES`, `CODING_KEY` | M | S2, S3 | The four rows of the §3.6 matrix pass in `encounter.test.ts`; a missing account or failed read suppresses both **and still returns the fields**; `coding` never appears as a `field` event, a backfilled field, an evidence slot or a scored slot |
| S5 | **Coding middleware**: verification, quote check, `isExisting`, status rules, list caps | M | S4 | Every code in the answer is in `state.coding` with a status; nothing is dropped except duplicates and codes over the caps; the three queries run in parallel; a code-set failure gives `FORMAT_ONLY`, not a failed run |
| S6 | **Eval**: coding cases in `tests/eval/cases.json` (expected ICD/CPT per note) | M | S5 | Recall and precision per system; share `VERIFIED`; `firstFieldMs` delta; tool rounds per run; `cache_read`; `coding` output tokens; a line in `history.jsonl` |
| — | Outside this service: the Review AI Output screen, the save, and the AI-source marker (A6) | — | S5 | Owner in AITP (meeting Q10, Q12) |

**Order:** S0 → S1 → S2 and S3 in parallel → S4 → S5 → S6.

**Progress** (branch `feature/AITP-88-tool-outcomes-followup`, not yet committed):
- **S0 is built.** The reducer keys on `toolCallId`. The cause was that LangChain merges a hook's return as
  `{ ...state, ...result }`. The `TOOLS` contract test is in.
- **S1 is built, apart from its live run.** It adds `src/types/coding.types.ts`, `normaliseCode` and
  `checkCodeFormat` in `src/tools/coding.ts`, and `src/repositories/codeSetRepository.ts`. Unit tests pass. The
  live test in `tests/integration/repositories/` skips without the VPN, and needs one run on DEV to close S1.
- **S2 and S3 are built** in `src/tools/coding.ts`:
  - `judgeCode()` holds the §3.5 status rules, minus the quote and confidence checks, which belong to S5.
    `lookupIcdCptTool` and `searchCodesTool` are the tools.
  - The state key `_codingSwitches` was added early. When it's absent, both systems count as suppressed, so the
    tools refuse until S4's guard sets it.
  - The tools are **not in `TOOLS` yet**: S4 binds them, together with `CODING_RULES`.
- **Choices made while building S2 and S3:**
  - **Lookup:** a malformed code gets a per-code `FORMAT_INVALID` status instead of refusing the whole call, because
    the lookup is batched (D1 change). A failed database read falls back to `FORMAT_ONLY`.
  - **Search:** a failed read throws, so the tool-call middleware records `FAILED`.
  - **Reasons:** the not-usable reason is `INACTIVE` for ICD and `EXPIRED_ON_DOS` for CPT.
  - **Candidates per term:** `min(5, 40 ÷ number of terms)`, so 10 terms get 4 each.
  - **No length or count limits in the tool schemas.** OpenAI strict mode may reject `minLength`/`maxItems`, so terms
    and codes are tidied and capped in code instead.
- **S4 is built** (unit tests only; its eval run is pending):
  - **Guard:** `accountRepository.getCodingSwitches` is read beside the template load, and a failure suppresses
    coding without blocking the run.
  - **Answer schema:** the `coding` block is last, with one list per allowed code system.
  - **Model-call:** shows the coding tools only when a code system is allowed, and logs `cacheReadTokens`.
  - **Skipping `coding`:** one shared `CODING_KEY`, skipped by evidence, the stream (field events and backfill) and
    `scoreRun`.
  - **Tests:** the four-row switch matrix is tested end to end.
- **Choices made in S4:**
  - **`CODING_RULES` is appended in `composePrompt`, after `OUTPUT_RULES`,** not in model-call, so `promptHash`
    covers the rules. They end with "Where an instruction above about ICD or CPT codes conflicts with these rules,
    these rules apply", because prompt id 20 still has the legacy free-text instructions.
  - **The account read is strict:** only a definite "not suppressed" (`false` or `0`) allows a code system; no row
    or any other value suppresses it.
  - **The unit-test harness defaults to coding off,** so every earlier test sends exactly what it did before.
- **S5 is built** (unit tests only; its eval run is pending). `checkCoding()` in `src/agents/coding.ts` turns the
  model's `coding` answer into `state.coding`:
  - **What it does:** normalises, removes duplicates (the first one is kept) and caps the codes (12 ICD, 6 CPT,
    with the number cut logged). It then runs `judgeCode` against one batched lookup per system and binds each
    quote with the same rule as template fields.
  - **Statuses:** a missing quote or LOW confidence turns `VERIFIED` into `NEEDS_REVIEW`; `NOT_IN_CODE_SET` stands.
    Each code gets `isExisting` from the problem list, and `source: 'AI'`.
  - **Reads:** the two lookups and the problem list run at the same time, and each can fail on its own.
    Unreadable tables set `codeSetMode: 'FORMAT_ONLY'`; an unreadable problem list leaves `isExisting` null.
  - **Logs:** counts per status only.
- **Choices made in S5:**
  - **The check runs inside the evidence middleware's `afterModel`,** not as a second middleware. The spine allows
    one hook of each kind, so hook order can't matter (F6).
  - **The quote rule moved to `src/agents/quote.ts`** (`normalize`, `locateQuote`), so fields and codes share it
    without an import cycle.
  - **`isExisting` uses the UI's own filters:** `usp_GetPatientDiagnosis(@isActive = 1)`, meaning active, not
    deleted and not a refine code, read through the encounter.
  - **A list the account suppresses is ignored,** even if the model filled it.
- **S6 is built; it is report-only until the key is confirmed:**
  - **Answer key:** `tests/eval/cases.json` has a DRAFT `coding` key per case, written from the notes alone before
    any coding output was seen.
  - **Scoring:** `scoreCoding` and `codingRates` in `score.ts`.
  - **Reporting:** the eval reports coding precision, recall and verified share per system, tool rounds and calls
    per run, and cached prompt tokens. All of it goes to the diagnostics, `summary.json` and `history.jsonl`.
  - **Gate:** coding doesn't pass or fail a run until a coder confirms the key
    ([review sheet](../Analysis/S6-Coding-Answer-Key-Review.md)). A later change will add a coding gate with a
    measured tolerance.
  - **Docs:** the change log is [Change-Logs/2026-10-22-eval-coding-key.md](../Change-Logs/2026-10-22-eval-coding-key.md),
    and the eval's `CLAUDE.md` has a Coding section.
- **Decided 2026-10-22: the note's own instruction wins.** "Do not add ICD-10 codes" empties `coding.icd`; "no
  billing or procedure codes" empties `coding.cpt`. A code the note states, such as Q2's 99309, is still listed.
  This is now in `CODING_RULES`.
- **Choice made in S6:** `cacheReadTokens` is now summed in state with the other token counts, not only logged, so
  the eval can report it.
- **Live test on DEV, 2026-10-22 (VPN):**
  - **Fixed on the real data:**
    - the ICD/CPT search SQL was invalid on SQL Server (an aggregate over an outer reference);
    - words matched code text, so "type 2" found `E10.21`;
    - the internal `00000` / `99999` "Non-Billable" rows were reachable; they're now excluded.
  - **Lookups pass.**
  - **Search still fails its budget:** about 2 s per term, 10 terms over 10 s, with poor ranking. The DEV data checks
    have the numbers.
- **C5 is reopened:** per-run SQL search isn't viable. The API project caches no code tables: Redis holds only PCC
  tokens and scopes, and `IMemoryCache` only IMO tokens and 5-minute IMO search results. Its clinician ICD search is
  IMO's API, which returns ranked `ICD10CM_CODE`s. **The options:**
  - an in-process index in `pacEHR_AI`, refreshed every few hours;
  - IMO's search API for ICD;
  - a full-text index from the API team.

  Lookups stay in SQL either way.
- **First eval with coding on (`20261022-175058`, 2026-10-22): passed.**
  - **Fields:** precision 90.5%, recall 77.5%.
  - **Cost:** input tokens up 35%, but 94% of them were served from cache. Output down 12%. First field 4.5 s,
    against 7.2 s.
  - **Search:** the model called `search_codes` in only about one run in three, and never `lookup_icd_cpt`. The
    check after the model verified every code anyway.
  - **Coding against the DRAFT key:** ICD precision 58% / recall 71%; CPT precision 58% / recall 100%. The note's
    instructions were followed (Q2 no ICD, Q3 nothing).
  - **Wrong codes worth noting:**
    - `E11.00`, which our bad search ranking put first for "type 2 diabetes";
    - `A09` for Q5's "probable" gastroenteritis, breaking the uncertain-diagnosis rule;
    - `R60.0` edema, a symptom that's part of CHF;
    - `I50.32` instead of `I50.33`;
    - `J13`, an organism the note doesn't name.
  - **The eval's stream check** now compares template fields only, because `coding` is never a field event.
- **Decided and built 2026-10-22** ([change log](../Change-Logs/2026-10-22-code-index-and-coding-rules.md)):
  - the in-memory index replaces SQL search;
  - `search_codes` is removed from the run, and alternatives are added for rejected codes;
  - four ICD guideline rules plus the `UNCERTAIN_DX` check;
  - the eval runs on SNF encounter 5112492.
- **Found:** DEV's CPT table has placeholder dates (2020–2027 on every row), deleted codes that look valid, and
  custom descriptions.
- **ABSTAINED settling is built**
  ([change log](../Change-Logs/2026-10-22-abstained-settling.md)): a no-mention `ABSTAINED` slot becomes `null` in
  the evidence hook and in the stream.
- **Eval baseline, 2026-10-22, before any agent change:** precision 89.5%, recall 80%. The gate failed, needing 89.9%.
  - **Not caused by this branch:** the 21 October run on `9cbfe57` scored 90.1%.
  - **The +209 input tokens per case are `compute_bmi`'s definition** (PR 13032).
  - **Corrected:** the runs that flood `ABSTAINED` (about one in three) **don't** lower precision. `ABSTAINED` isn't a
    fill, and the wrong answers split 59 in those runs to 65 in the others. They cost 2–3 times the tokens and
    time.
  - **The precision gap comes from fields that miss in every run:** `s1_f5` (adds "group home"), `s1_f917`,
    `s33_f1958`, `s69_f1212`, and Q3's `s4_f40` and `s4_f41`.

## 5. Tests

- **Unit:**
  - normalisation and format patterns (table-driven);
  - status rules, one test per row of §3.5;
  - the switch matrix;
  - `LIKE` escaping;
  - `checkEvidence` skipping `coding`;
  - tool refusals that follow the PEA-701 contract.
- **Integration (DEV, VPN):**
  - the repository against real tables: one known code per family, one expired CPT, one POS-restricted CPT;
  - the switch read for a test account.
- **Eval:** 10–20 DEV transcripts with expected codes chosen by a coder or clinician, not copied from what was saved.
  Saved codes started as AI suggestions, so they would grade the old model.

## 6. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| The tables are stale (no loader exists; ICD loaded by hand about January 2026, CPT unknown) | Correct new codes show as `NOT_IN_CODE_SET` | Flag, don't drop (C2); DEV check 7; meeting Q1 for the load process |
| ICD `startDate`/`endDate` are `NVARCHAR(20)` in an unknown format (CPT dates are proper `DATE` columns) | ICD date check can't run | Phase 1 uses `isActive` and `billable` for ICD; add the date check once DEV check 3 shows the format |
| Searches scan code tables on the **shared clinical database** (`LIKE '%word%'` can't use an index; `icdCodes` is a heap); each run makes about 6 queries instead of 2, through a pool of 10 connections per process | More database CPU, and pool waits under concurrent load | One query per system; short columns only; typed parameters; queries in parallel; per-query durations logged; S1 time budget. If the load test still shows pressure, add a cached `CodeSet` behind the same interface (C5 can be revisited) |
| Up to four strict schemas per template (switch combinations) | A one-off schema-compile delay on the first request for each | Accepted; visible in the eval's first run |
| Word search misses synonyms ("heart attack" against "myocardial infarction") | Weak candidates | Rules tell the model to search in clinical terminology and retry broader terms; the eval measures recall |
| Extra model turn before the first field | Slower first field | One batched, parallel search; measured in the eval |
| The legacy DB prompt conflicts with `CODING_RULES` | Free-text codes or descriptions | Remove the legacy text from the prompt (Q5); rules take precedence |
| CPT licence not cleared | CPT can't be used in production | The account's CPT switch stays on until P1 is signed off |

## 7. Assumptions to confirm

| # | Assumption | Who |
|---|---|---|
| 1 | A missing account row suppresses both systems | Lead |
| 2 | A format-invalid code is flagged (`NOT_IN_CODE_SET` / `FORMAT_INVALID`), not dropped | Lead (follows C2) |
| 3 | E/M codes are always `NEEDS_REVIEW` in Phase 1 | Lead, clinical reviewer |
| 4 | `coding` arrives in `done` only, with no streamed per-code events | Owner of Review AI Output |
| 5 | The lookup takes a list of codes (changes D1) | Team |
| 6 | Uncertain diagnoses aren't coded; symptoms are | Clinical reviewer |
| 7 | `search_codes` gets a new PEA number in Epic 7 | Lead |
| 8 | Budgets for the eval gate: extra `firstFieldMs`, average tool rounds, query p95 | Lead |
| 9 | The caps: 12 ICD and 6 CPT codes per answer, 5 candidates per term | Lead, clinical reviewer |
| 10 | A CPT row with no `startDate` or `endDate` is open at that end (S1). `proc_getCPTCodes` drops such rows instead; DEV check 7 shows whether any exist | Lead |
| 11 | The POS check matches `usp_restrictedCPTByPOS` exactly, including ignoring `isActive` (S1) | Owner of the legacy CPT screen |

## 8. Review findings (2026-10-22)

The plan was checked against `pacEHR_AI` `9cbfe57`, the `pacEHR_API` `dc7316ec3` DDL and the eval of 2026-10-21.
Each finding is folded into the section shown.

**Flow**

| # | Severity | Finding | Where it's fixed |
|---|---|---|---|
| F1 | High | Parallel ICD and CPT searches write identical tool outcomes, which the current reducer merges (A1) | §4 S0 is a hard prerequisite of S3 |
| F2 | High | A switch-read failure inside the guard's shared `try` would return `GUARD_STEP_FAILED` and block the fields too | C7, §3.6, §3.1 |
| F3 | High | Filtering `request.tools` hides tools from the model only; the compiled tool node can still run them | §3.2: tools read the switches from runtime state |
| F4 | Medium | `coding` would leak into the `FieldScanner` loop, the stream backfill, `checkEvidence` and `scoreRun`, and fail the eval gate | §3.2: `CODING_KEY`, S4 |
| F5 | Medium | `icdCodes` is a heap with an `isDelete` column: duplicate and deleted rows | §3.3 |
| F6 | Medium | `afterModel` hooks run in reverse array order; the plan assumed coding ran after evidence | §3.2: the two are independent |
| F7 | Low | `isExisting` needs `patientID`, which the context doesn't carry | §3.2: query on `encounterId` |
| F8 | Low | `CodeSuggestion[] \| null` gave two ways to say "nothing" | §3.4: arrays only |
| F9 | Low | CPT dates are `DATE`, not strings | §3.3, §6 |

**Performance**

| # | Bottleneck | Where it's fixed |
|---|---|---|
| P1 | The search round: about +14.5k input tokens and an estimated +2–4 s before the first field | C6, §3.8 (batching, prompt caching, `cache_read` log) |
| P2 | A third round if the model looks up codes it just searched | §3.3: lookup only for codes not from search; S6 counts rounds |
| P3 | Search results inflating turn 2 (up to 200 rows; `codeLongDesc` up to 4,000 characters) | §3.3: 5 per term, 40 per call, short descriptions, text lines |
| P4 | The `coding` block adding about 400–700 output tokens | §3.4: caps and the shortest `found_in` |
| P5 | `LIKE` scans on the shared clinical database | §3.3: one `OPENJSON` query per system; S1 time budget; §6 |
| P6 | `NVARCHAR` parameters against `VARCHAR` `cptCodes.code`, so no index seek | §3.3: typed `OPENJSON … WITH` columns |
| P7 | About 6 queries per run through a pool of 10 connections | §3.1: switch read in parallel with the template load; middleware queries in parallel |
| P8 | One schema compile per switch variant | §3.8, §6 |
