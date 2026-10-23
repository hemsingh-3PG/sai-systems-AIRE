# Coding Output Format: ICD-10-CM and CPT/HCPCS Suggestions

**For:** the owner of the "Review AI Output" screen (AITP) and whoever builds its API route and save
**From:** Hem Singh · **Date:** 2026-10-22 · **Status:** Implemented in `pacEHR_AI` (branch
`feature/AITP-88-tool-outcomes-followup`, not merged); format open for review
**Source of truth:** `src/agents/state.ts` (`coding` in `ExtractionState`) and `src/agents/coding.ts` (`checkCoding`).
Background: [implementation plan](ICD-CPT-Coding-Implementation-Plan.md).

## 1. Where the codes appear

| Call | Where |
|---|---|
| `encounterAgent.invoke(...)` | `result.coding` |
| `encounterAgent.stream(...)` | The final `{ type: 'done', result }` event, as `result.coding`. Codes are **never** sent as `field` events, because they're checked only after the whole answer is in |

- **No HTTP route returns this yet.** The route that exposes the agent result should pass `coding` through unchanged.
- **`coding` is absent** when the account allows no code system, or when the run failed or was blocked.

## 2. Shape

```ts
coding?: {
  icd: CodedResult[];          // [] when ICD is suppressed or nothing was suggested
  cpt: CodedResult[];          // [] when CPT is suppressed or nothing was suggested
  switches: { icd: boolean; cpt: boolean };   // what this run allowed: true = suggestions on
  codeSetMode: { icd: Mode; cpt: Mode };      // per system (changed 2026-10-23)
}

Mode = 'DATABASE' | 'FORMAT_ONLY';           // FORMAT_ONLY: that system's table could not be read

CodedResult = {
  code: string;                // normalised as stored: ICD dotted (E11.9), CPT as is (99213, G2211)
  codeSystem: 'ICD10CM' | 'CPT';             // CPT includes HCPCS Level II
  description: string | null;  // from DATA.icdCodes / DATA.cptCodes, never from the model; null if no row or unread
  found_in: string;            // the span of the note the model quoted as support
  quoteMatch: 'EXACT' | 'NORMALIZED' | 'NOT_FOUND' | 'NONE';   // whether that quote is really in the note
  status: 'VERIFIED' | 'NEEDS_REVIEW' | 'NOT_IN_CODE_SET';
  reasons: string[];           // why it is not VERIFIED (section 3); [] when VERIFIED
  isExisting: boolean | null;  // ICD: already on the patient's active problem list; CPT: always null
  confidence: 'HIGH' | 'MEDIUM' | 'LOW';     // the model's own band
  source: 'AI';                // for the AI-suggested marker (A6; the AMA asks for AI output to be marked)
  alternatives: { code: string; description: string }[];   // NOT_IN_CODE_SET only: up to 3 usable codes; else []
}
```

**Order and limits:**
- The array order is the model's priority, so the **first ICD code is the proposed primary diagnosis**.
- At most **12 ICD and 6 CPT** codes. Duplicates are merged: `e119` and `E11.9` become one entry, and the first is
  kept.

## 3. Status and reasons

| Status | Meaning | Suggested UI |
|---|---|---|
| `VERIFIED` | In our tables and usable for this encounter, quoted from the note, confidence not LOW | Normal row, pre-selected |
| `NEEDS_REVIEW` | Usable, but something needs a human look (reasons below) | Row with a review flag, not pre-selected |
| `NOT_IN_CODE_SET` | Our tables reject it for this encounter. **It isn't dropped**, so the clinician sees what the AI thought | Separate "not usable" group; can't be saved as is |

| Reason | Gives status | Meaning |
|---|---|---|
| `FORMAT_INVALID` | NOT_IN_CODE_SET | Not a valid ICD-10-CM / CPT / HCPCS shape (e.g. `E1`, `99213-25`) |
| `NOT_FOUND` | NOT_IN_CODE_SET | No row in the code table |
| `NOT_BILLABLE` | NOT_IN_CODE_SET | ICD row with `billable = 0` (e.g. a category header like `E11`) |
| `INACTIVE` | NOT_IN_CODE_SET | ICD row with `isActive = 0` |
| `EXPIRED_ON_DOS` | NOT_IN_CODE_SET | CPT not valid on the date of service (`startDate`/`endDate`). **It never fires on DEV today:** every CPT row there runs 2020–2027, deleted codes included (section 9) |
| `POS_RESTRICTED` | NOT_IN_CODE_SET | CPT the encounter's place of service doesn't allow: the same rule as `usp_restrictedCPTByPOS`, so the CPT screen would refuse it too |
| `EM_LEVEL` | NEEDS_REVIEW | E/M visit code (99202–99499): the level rests on decision-making or time, which the model is weakest at |
| `QUOTE_NOT_FOUND` | NEEDS_REVIEW | The quote isn't in the note, or there's no quote |
| `LOW_CONFIDENCE` | NEEDS_REVIEW | The model rated it LOW |
| `CODE_SET_UNAVAILABLE` | NEEDS_REVIEW | The code's table couldn't be read (that system's `codeSetMode` is `FORMAT_ONLY`); only the format was checked |
| `UNCERTAIN_DX` | NEEDS_REVIEW | ICD only: the quote calls the diagnosis uncertain ("probable", "suspected", "rule out"…). The guidelines say not to code it |

**How the status is decided:**
- A code can carry several reasons.
- `NOT_IN_CODE_SET` always wins over `NEEDS_REVIEW`.
- Quote and confidence reasons are added on top of table reasons. For example, a code can be
  `['EXPIRED_ON_DOS', 'LOW_CONFIDENCE']`.

## 3a. Alternatives

A `NOT_IN_CODE_SET` code carries up to 3 `alternatives`: codes from our tables that the clinician may have meant.
- **Where they come from:**
  - a header code our tables mark not billable gets its billable children first (`N18.3` → `N18.30`, `N18.31`,
    `N18.32`);
  - then the in-memory index's best matches for the code's quote.
- **Each alternative is looked up for this encounter**, so only a usable code is offered. Its description comes from
  the tables.
- **Suggested UI:** offer them as one-click replacements on the rejected row.
- **When there are none:** on a service's first run the index is still loading, so the run doesn't wait. The list is
  also empty when nothing matches.

## 4. Existing or new (ICD)

`isExisting` tells the screen which of today's two ICD groups a code belongs to:
- `true` means **Existing ICD Code(s)**;
- `false` means **New ICD Code Recommendation(s)**.

It uses the same problem list the UI uses, `usp_GetPatientDiagnosis(@isActive = 1)`: active, not deleted, not a
refine code. It's `null` when the problem list couldn't be read, and the screen should then treat the code as new.

## 5. When there are no codes

| Situation | `coding` |
|---|---|
| The account suppresses both ("Suppress AI Coding - ICD-10" and "Suppress AI Coding - CPT") | Absent |
| The account suppresses one | Present; that list is always `[]`, and `switches` shows which |
| The account row is missing, or the switches can't be read | Absent: suppressed is the safe default |
| The note says "Do not add ICD-10 codes" / "no billing or procedure codes" | Present; that list is `[]`. A code the note states itself (e.g. "CPT code: 99309") is still listed |
| The only diagnosis is uncertain ("probable", "suspected", "rule out") | Not coded; documented symptoms may be |

## 6. What the screen and save still own

- **Nothing is saved by the AI service.** The clinician accepts or removes codes, and the screen saves through the
  existing endpoints:
  - ICD: `usp_InsertMultipleEncounterDiagnosis` / `usp_InsertPatientMultipleDiagnosis`;
  - CPT: the `saveCPTCodes` path, which runs the POS and billing-rule checks.
- **No modifiers and no units:** CPT units default to 1, with no modifier, as the legacy AI did.
- **Billable flag on save:** the ICD insert procedures hard-code `billable = 1` (meeting Q4). A code marked
  `NOT_BILLABLE` here must not be saved as billable.
- **AI marker:** keep `source: 'AI'` through the save, e.g. as a source column in `encounterCodeHistory` (A6,
  meeting Q12), so audits and the AMA marking requirement can be met.
- **Descriptions:** show `description`, never text from the model. When it's `null`, show the code with "not in code
  set" (or "description unavailable" in `FORMAT_ONLY` mode).

## 7. Example

```json
{
  "icd": [
    { "code": "I50.33", "codeSystem": "ICD10CM", "description": "Acute on chronic diastolic (congestive) heart failure",
      "found_in": "acute on chronic diastolic heart failure", "quoteMatch": "EXACT",
      "status": "VERIFIED", "reasons": [], "isExisting": false, "confidence": "HIGH", "source": "AI" },
    { "code": "E11.22", "codeSystem": "ICD10CM", "description": "Type 2 diabetes mellitus with diabetic chronic kidney disease",
      "found_in": "type 2 diabetes", "quoteMatch": "EXACT",
      "status": "NEEDS_REVIEW", "reasons": ["LOW_CONFIDENCE"], "isExisting": true, "confidence": "LOW", "source": "AI" }
  ],
  "cpt": [
    { "code": "99306", "codeSystem": "CPT", "description": "1st nf care high mdm 50", "found_in": "total time spent 55 minutes",
      "quoteMatch": "EXACT", "status": "NEEDS_REVIEW", "reasons": ["EM_LEVEL"], "isExisting": null, "confidence": "MEDIUM", "source": "AI" }
  ],
  "switches": { "icd": true, "cpt": true },
  "codeSetMode": { "icd": "DATABASE", "cpt": "DATABASE" }
}
```

The descriptions above are illustrative; real ones come from the tables.

## 8. How the codes are produced

- **No search or lookup tool in the run.** The model writes codes in its answer, and every code is checked after the
  answer, so no tool round delays the first field.
- **The rules the model follows** are in `CODING_RULES` (`src/schema/contract.ts`): no uncertain diagnoses, no
  symptom that's part of a coded diagnosis, the most specific code, organisms only when named, and respect for the
  note's own "no codes" instructions.

## 9. Known data problem: CPT on DEV

`DATA.cptCodes` on DEV isn't reliable (measured 2026-10-22):
- **Placeholder dates:** every row runs 2020-01-01 to 2027-01-01.
- **Deleted and non-CPT codes look valid,** e.g. `99311`–`99313`, `99327`, `658`, `90300`.
- **Descriptions are custom,** not AMA (`99309` is "[30 min] Moderate MDM").

Until the table is fixed, a CPT `VERIFIED` means only that the code has a row, so the screen should treat every CPT
suggestion as needing review. This is raised with the legacy team (meeting Q1).

## 10. Open points for the screen owner

1. **Is the per-code format enough?** In particular: do you need the model's reasoning text? It's left out on purpose,
   because the quote is the evidence.
2. **Should `NOT_IN_CODE_SET` codes be shown at all,** or only counted?
3. **Do you need per-code events in the stream,** or is `done` enough?
4. **Who owns the AI-source column** on save (A6)?
