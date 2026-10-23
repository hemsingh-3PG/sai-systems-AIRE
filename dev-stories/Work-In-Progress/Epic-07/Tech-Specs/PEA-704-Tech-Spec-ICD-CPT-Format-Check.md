# PEA-704 — Check ICD/CPT Format and Require Sign-off Without a Licensed Code Set

**Type:** Story · **Epic:** E7 · **Points:** 3 (JS ticket, unchanged) · **Depends on:** PEA-701 (merged as AITP-88) and Additions **A1** and **A7**
**Status:** Not started. The acceptance-criteria changes in §4 need approval before the build starts
**Benchmark:** [`Tickets-Original-JS/epic-07-tools.md`](../../../Tickets-Original-JS/epic-07-tools.md), PEA-704 and Part 2
**Code baseline:** `pacEHR_AI` branch `PacEHR-AI-Develop-Main` at `9cbfe57` (PEA-701 and PEA-703 merged 2026-10-21)
**Jira:** no PEA-704 issue exists on the connected site, and no AITP issue mentions ICD, CPT or `lookup_icd_cpt` (searched 2026-10-21)

---

## 1. What the JS ticket asks (copied, not paraphrased)

> As a compliance officer, I want `lookup_icd_cpt` to state plainly that it checked only a code's format when no licensed
> ICD/CPT code set is configured, so that a clinician never skips signing off a diagnosis or procedure code in the belief
> that the system already verified it.

**Acceptance criteria (JS ticket):**
1. "E11.9" with no licensed set returns status FORMAT_OK_UNVERIFIED and mode DEGRADED. The response says that existence, billability and Place-of-Service validity were not checked.
2. "E1119" returns FORMAT_INVALID.
3. CPT shapes are checked as well as ICD-10-CM: five digits for Category I, and four digits plus F or T for Categories II and III.
4. Every response carries `mode`, and in Phase 1 it is always DEGRADED.
5. For any well-formed code, the status is never VALID while the mode is DEGRADED.
6. A FORMAT_OK_UNVERIFIED code is never accepted without review. The review reason reads "code format only, not verified against a licensed set".

**Technical notes (JS ticket), in short:**
- `src/tools/coding.ts`, built to PEA-701's contract.
- The status values, the mode, the review reason and the format patterns are exported constants.
- The licensed lookup is one named function with no implementation. No setting is added.
- It is a pure function, with tests in `tests/unit/tools/coding.test.ts`.

## 2. What the evidence changes

The full evidence is in [ICD-CPT-Current-System-Flow.md](../Analysis/ICD-CPT-Current-System-Flow.md).

| Topic | JS ticket assumption | What the code shows | Effect on this story |
|---|---|---|---|
| Code tables | "This project has none" | `DATA.icdCodes` (billable, isActive, dates) and `DATA.cptCodes` (dates) exist in the database pacEHR_AI already reads | Build format-only now as specified. The database lookup becomes a separate story (Additions **A2**, decision **P1**) |
| Where codes land | "Today no slot would hold a code" | The live system has the AI suggest ICD and CPT codes through extra keys outside the template. The planned UI keeps both sections | Q1: confirm the new agent fills them. Until then the tool only advises the model |
| Dot format | "E1119" is invalid | ICD is stored dotted, and the one existing normaliser inserts the dot after the 3rd character. Claims (X12 837) carry ICD codes **without** the dot (X12 RFI 1882), so dot-less is a legitimate way to write a code | AC 2 changes (D2) |
| Code shapes | ICD + CPT Cat I/II/III | HCPCS Level II sits with CPT. 7th-character codes are in real use. Modifiers are always a separate field | Add HCPCS. Reject modifiers (D3) |
| Recording a result | Not specified | Only a `{ reasonCode }` result counts as REFUSED, and the middleware spreads the whole result into state | Needs **A1** (D4) |

## 3. Design

### 3.1 Parameters (D1)

```ts
const schema = z.object({
  code: z.string().min(1).describe(
    'The base code only, as written in the note or as you propose it, e.g. "E11.9" or "99213". Never include a modifier.',
  ),
  codeSystem: z.enum(CODE_SYSTEMS).describe(
    'ICD10CM for a diagnosis code. CPT for a procedure code, including HCPCS Level II codes such as G2211.',
  ),
});
```

- **Run facts are not parameters.** `placeOfService` and `dateOfService` are already in `ExtractionContext`. A later database lookup reads them from `runtime.context`, so the tool's parameters never change.
- **The model must name the code system.** HCPCS `E0114` and a dot-less ICD code have the same shape, so the tool can't infer the system from the code.

### 3.2 Normalisation (D2)

These steps run in order, the same way as `usp_ApplyCCLImportDiagnoses` (PAC-1326):

1. Trim the code.
2. Strip surrounding `[ ]` and `( )`.
3. Remove inner spaces.
4. Upper-case it.
5. **ICD only:** if there is no dot and the code is longer than 3 characters, insert a dot after the 3rd character.

| As written | Normalised | Result |
|---|---|---|
| `E11.9` | `E11.9` | OK |
| `e1119` | `E11.19` | OK. Format only: whether E11.19 exists is A2's job |
| ` [S83241A] ` | `S83.241A` | OK |
| `I10` | `I10` | OK (no dot added to a 3-character code) |
| `E1.19` | `E1.19` | INVALID (dot in the wrong place) |

### 3.3 Format patterns (D3)

```ts
export const FORMAT_PATTERNS = {
  // Letter, digit, letter-or-digit; then optionally a dot and 1–4 letters-or-digits (X placeholder, 7th character).
  ICD10CM: [/^[A-Z][0-9][0-9A-Z](\.[0-9A-Z]{1,4})?$/],
  // CPT Category I, II, III, and HCPCS Level II. PLA (####U) and modifiers are out of Phase 1.
  CPT: [/^\d{5}$/, /^\d{4}F$/, /^\d{4}T$/, /^[A-V]\d{4}$/],
} satisfies Record<CodeSystem, RegExp[]>;
```

- **HCPCS first letters:** `[A-V]` is a placeholder range. Confirm it against the leading letters actually in `DATA.cptCodes` ([DEV check 5](../Analysis/ICD-CPT-DEV-Data-Checks.md)).
- **PLA codes:** add `/^\d{4}U$/` only if the same check finds PLA codes in the table.

### 3.4 Results and how they are recorded (D4, which needs A1)

**Well-formed code.** The tool call is recorded as SUCCESS, with no `reasonCode`, so nothing about the code reaches state:

```ts
{
  status: 'FORMAT_OK_UNVERIFIED',
  mode: 'DEGRADED',
  code: 'E11.19',                 // normalised
  codeSystem: 'ICD10CM',
  notChecked: ['existence', 'billability', 'placeOfServiceValidity'],
  reviewReason: 'code format only, not verified against a licensed set',
}
```

**Malformed code.** The tool call is recorded as REFUSED, and `toolOutcomes` gets `reasonCode: 'FORMAT_INVALID'` only:

```ts
{ reasonCode: 'FORMAT_INVALID', status: 'FORMAT_INVALID', mode: 'DEGRADED' }
```

- **The malformed result never carries the code**, so even today's full spread into state wouldn't put a clinical value there.
- **A1 is still required.** It makes the state write deterministic (`reasonCode` only), and it fixes the reducer that drops a repeated outcome. A coding tool is the one most likely to be called twice in a run.

### 3.5 The shared rule (D5)

```ts
/** Pure. Used by the tool and by Epic 6's afterModel coded-slot check: the tool alone cannot prove a check ran. */
export function checkCodeFormat(raw: string, codeSystem: CodeSystem): { code: string; wellFormed: boolean } { … }
```

### 3.6 Licensed-lookup seam (P1)

```ts
/**
 * Not implemented: Phase 1 has no approved lookup (decision P1, Additions A2). When built, it reads
 * dateOfService and placeOfService from runtime.context, so the tool's parameters do not change.
 */
export async function lookupLicensedCode(code: string, codeSystem: CodeSystem): Promise<never> { … }
```

Under CLAUDE.md, no setting or flag is added until a lookup exists. The tool never calls this function in Phase 1, so `mode` is always `DEGRADED`.

### 3.7 Tool description (the model reads only this)

> Checks only the format of an ICD-10-CM or CPT/HCPCS code. It cannot confirm that a code exists, is billable or is
> valid for the place of service, so every well-formed code still needs clinician sign-off. Pass the base code only,
> never a modifier, and say which code system it belongs to.

## 4. Acceptance criteria: proposed changes

| # | JS ticket | Proposed | Why |
|---|---|---|---|
| 1 | E11.9 → FORMAT_OK_UNVERIFIED, DEGRADED, states what wasn't checked | **Unchanged**, with `codeSystem: 'ICD10CM'` | — |
| 2 | "E1119" → FORMAT_INVALID | **"E1119" (ICD10CM) is normalised to "E11.19" and returns FORMAT_OK_UNVERIFIED.** "E1", "1E1.9", "E1.19", "E11.12345" and "E11." return FORMAT_INVALID | D2: codes are stored dotted, and dot-less codes are how claims and clinicians write them |
| 3 | CPT Cat I/II/III shapes | **Plus HCPCS Level II** (`G2211`). "99213-25" (modifier) and "0001U" (PLA) return FORMAT_INVALID | D3 |
| 3a | — | **New:** a code that doesn't fit its stated system returns FORMAT_INVALID. Example: "I10" as CPT, or "99213" as ICD10CM | D1 |
| 3b | — | **New:** the ICD X placeholder and 7th character pass: "S83.241A", "T36.0X1A" | D3, real use |
| 4 | Every response carries `mode` = DEGRADED | **Unchanged** (the malformed result carries it too, see §3.4) | — |
| 5 | Never VALID while DEGRADED | **Unchanged.** Tested over every well-formed fixture | — |
| 6 | Never accepted without review; the review reason text | **Split.** PEA-704 exports `REVIEW_REASON` and returns it on every well-formed result. "Never accepted without review" is checked in **Epic 6** (`afterModel`), which owns review and verdicts | `evidence.ts` has no per-slot reason today (`reviewSlots: string[]`) |
| 7 | — | **New:** a `FORMAT_INVALID` call is recorded in `state.toolOutcomes` as `{ toolName: 'lookup_icd_cpt', outcome: 'REFUSED', reasonCode: 'FORMAT_INVALID' }`. Two calls in one run give two entries | D4, A1 |

## 5. Files

| File | Change |
|---|---|
| `src/tools/coding.ts` | **New.** `CODE_SYSTEMS`, `CODE_STATUS`, `CODE_CHECK_MODE`, `REVIEW_REASON`, `NOT_CHECKED`, `FORMAT_PATTERNS`, `normaliseCode`, `checkCodeFormat`, `lookupLicensedCode` (the empty function) and `lookupIcdCptTool`. Laid out like `src/tools/bmi.ts` |
| `src/agents/encounter.ts` | Add `lookupIcdCptTool` to `TOOLS` (line 26) and update the comment on line 25 |
| `tests/unit/tools/coding.test.ts` | **New**, see §6 |
| `tests/eval/history.jsonl` | One passing `npm run eval` line (required by the pre-push hook for `src/` changes) |

## 6. Tests (`node:test`, calling `lookupIcdCptTool.invoke()` and `checkCodeFormat()` directly)

| Group | Cases |
|---|---|
| ICD well-formed | `E11.9`, `I10`, `Z79.4`, `S83.241A`, `T36.0X1A`, `U07.1` → OK, DEGRADED, `notChecked` has all three items |
| ICD normalised | `e1119` → `E11.19`; ` [S83241A] ` → `S83.241A`; `I10` stays `I10` |
| ICD malformed | `E1`, `1E1.9`, `E1.19`, `E11.12345`, `E11.` → `{ reasonCode: 'FORMAT_INVALID' }` |
| CPT well-formed | `99213`, `20610`, `0001F`, `0042T`, `G2211` → OK |
| CPT malformed | `9921`, `99213-25`, `0001U`, `ABCDE`, `992134` → FORMAT_INVALID |
| Wrong system | `I10` as CPT, `99213` as ICD10CM → FORMAT_INVALID |
| Invariant (AC 5) | For every well-formed fixture: `status !== 'VALID'` and `mode === 'DEGRADED'` |
| Review reason (AC 6) | `REVIEW_REASON` is exactly "code format only, not verified against a licensed set" and is returned on every well-formed result |
| Contract (PEA-701) | **No `TOOLS` contract test exists on `9cbfe57`.** Additions **A7** adds it; once it lands, it covers this tool's description and parameter descriptions automatically |
| State (AC 7) | Two `FORMAT_INVALID` calls in one run give two `REFUSED` entries in `toolOutcomes`. **Fails until A1 lands** |

## 7. Out of scope

- **The database lookup:** existence, billable, dates, place of service (Additions **A2**).
- **Code descriptions:** the agent returns codes only (Additions **A3**).
- **Modifiers and units** (Q3).
- **The Epic 6 `afterModel` coded-slot check.** It imports `checkCodeFormat()`.
- **Code slots in the output contract** (Epic 3, Q1).
- **Showing the review reason on screen** (Epic 9).
- **Any write to clinical tables.** pacEHR_AI never writes them.

## 8. Definition of done

- [ ] D1–D5 signed off. The AC changes in §4 approved and copied into Jira
- [ ] A1 and A7 merged, or included as this story's first commits
- [ ] `src/tools/coding.ts` and its tests per §5–§6. No new failures against the base-branch baseline
- [ ] The tool is registered in `TOOLS`, and the contract test passes
- [ ] A passing `npm run eval` line for the exact code pushed
- [ ] P1 (premise) and Q1 (does the agent fill code sections) recorded with an owner and a date, even if still open
