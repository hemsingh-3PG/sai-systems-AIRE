# Epic 07 — Proposed Additions (need approval)

**From:** Hem Singh · **Updated:** 2026-10-21
**Why this file exists:** the JS ticket is the benchmark. Work it doesn't contain goes here, and stays out of the story
specs until it's approved (the same rule as Epic 5's `Azure-Layer-Additions.md`).

| # | Addition | Where it fits | Size | Status |
|---|---|---|---|---|
| **A1** | Fix the `toolOutcomes` reducer (defect confirmed by a test) | PEA-701 follow-up (AITP-88) | ~1 pt | Proposed. **Blocks PEA-704 AC 7** |
| **A7** | Add the `TOOLS` contract test PEA-701 promised but didn't deliver | PEA-701 follow-up (AITP-88) | ~1 pt | Proposed. **PEA-704 relies on it** |
| **A2** | Check codes against `DATA.icdCodes` / `DATA.cptCodes` (and place of service) | New story after PEA-704 | ~5 pts | Proposed. **Needs P1** |
| **A3** | The agent returns codes only; descriptions come from the code tables | Epic 3 output contract + A2 | ~2 pts | Proposed |
| **A4** | Code slots in the agent's output | Epic 3 | Depends on Q1 | **Open** |
| **A5** | Respect the per-account suppression switches | Epic 4 guard / Epic 9 request | ~1 pt | **Open** (Q4) |
| **A6** | Record which saved codes came from the AI | Epic 10 audit (current-system observation) | — | For the lead to decide |

---

## A1 — Fix the `toolOutcomes` reducer, and write only `reasonCode`

### Defect 1: a repeated outcome is dropped (**confirmed by a test run, 2026-10-21**)

A temporary probe test on `9cbfe57` (since deleted) showed:
- Two identical `SUCCESS` calls **in two turns** produced **1** entry, not 2.
- Two identical calls **in parallel in one turn** also produced **1** entry.

The cause is in `src/agents/state.ts:19-28`:

```ts
if (JSON.stringify(current) === JSON.stringify(incoming)) return current;
return [...current, ...incoming];
```

The check exists because middleware hooks spread the full state back into their result. It also drops a genuine write:

| Step | `current` | `incoming` | Result |
|---|---|---|---|
| 1st call: `lookup_icd_cpt` E11.9 → SUCCESS | `[]` | `[{lookup_icd_cpt, SUCCESS}]` | `[{…SUCCESS}]` ✔ |
| 2nd call: `lookup_icd_cpt` I10 → SUCCESS | `[{…SUCCESS}]` | `[{lookup_icd_cpt, SUCCESS}]` | **equal → skipped** ✘. State shows one call, not two |

This happens whenever the first two tool outcomes in a run are identical, in parallel or in sequence. No test covers it (`tests/unit/agents/middleware/tool-call.test.ts` has single calls only).

### Defect 2: the whole result is spread into state (**not reproduced**)

In `src/agents/middleware/tool-call.ts`, the write is `toolOutcomes: [{ toolName, outcome, ...refusal }]`, and `refusal` is the entire parsed tool result.
- **What the probe showed:** a refusal returning `{ reasonCode, status, code: 'E11.9' }` was stored as `{ toolName, outcome: 'REFUSED', reasonCode }` only. The state schema strips unknown keys.
- **So there's no leak today.** Narrowing the write to `reasonCode` is optional hardening, not a fix.

### Fix

1. **Test first.** Add a test to `tool-call.test.ts`: two identical outcomes, both in sequence and in parallel, must give two entries.
2. **Optionally narrow the write** to `...(refusal && { reasonCode: refusal.reasonCode })`, so it doesn't depend on the schema stripping keys.
3. **Change the reducer** so it tells a genuine write apart from a hook's re-spread. Two options; choose whichever the test shows works in `langchain` 1.5.14:
   - Hooks stop returning `toolOutcomes` at all.
   - Each tool-call write carries a unique id (`runtime.toolCallId`), and the reducer appends only ids it hasn't seen.

## A2 — Check codes against the code tables (proposed story, after PEA-704)

**Precondition (P1):**
- **Licence:** the lead and compliance confirm that the existing tables may be used by the AI service.
  - CPT content is AMA-licensed.
  - The AMA's **AI Addendum (14 July 2026)** allows retrieval-style use at the point of use.
  - It forbids training or fine-tuning on the CPT data file, and uploading it to public or open-market AI.
  - So the licence holder must confirm our Azure OpenAI use fits the addendum.
- **Data:** the [DEV data checks](../Analysis/ICD-CPT-DEV-Data-Checks.md) show the tables are current. **No loader exists in any repo**, and the ICD data appears to have been loaded by hand around January 2026 ([validation](../Analysis/Pre-Meeting-Validation.md) Q1).

| Check | ICD-10-CM (`DATA.icdCodes`) | CPT/HCPCS (`DATA.cptCodes`) |
|---|---|---|
| Exists | Exact match on `code` | Exact match on `code` |
| Billable | `billable = 1` | **Can't be checked**: the table has no billable column (`isChargeCheckerCPT` is something else) |
| Active / not deleted | `isActive = 1`, `isDelete` not set. **Nothing in any repo ever sets these**, so they're only as good as the last manual load | — |
| Valid on the date of service | `startDate`/`endDate` are **NVARCHAR(20)** and **nothing reads or writes them**. Don't rely on them until DEV check 3 shows real values | `startDate ≤ dateOfService ≤ endDate` (DATE), **inclusive**. The existing procedures use strict `<`/`>`, which wrongly hides a code on its first and last day. This would have caught 99327, deleted in 2023 |
| Valid for the place of service | — | `DATA.restrictedCPTByPOS` / `usp_restrictedCPTByPOS`. That takes an **int `posId`**, but `ExtractionContext.placeOfService` is a string, so a mapping is needed first |

**New statuses** (mode becomes `VERIFIED` for codes that pass):

| Status | Meaning |
|---|---|
| `VALID` | Passed every check above |
| `NOT_FOUND` | No row for the code |
| `NOT_BILLABLE` | ICD only |
| `INACTIVE_ON_DOS` | Not valid on the date of service |
| `POS_RESTRICTED` | Not allowed for the place of service |

**Build notes:**
- Fill in PEA-704's empty `lookupLicensedCode` and keep the same tool parameters.
- Each read is one `*_SQL` constant run through `database.execute`, read-only.
- **Existing procedures:** none fits as-is, so write our own `*_SQL` constants.

  | Procedure | Match | Problem for us |
  |---|---|---|
  | `proc_getMultipleICDCodes` | `LIKE '%term%'` on `code : description` | Not exact |
  | `usp_getICDDescription` | Exact, **one** code, `billable = 1` only | A non-billable code looks "not found" |
  | `proc_getIMOICDCodes` | Exact list | No billable filter |
  | `proc_getMultipleCPTCodes` | Exact list | **No date filter** |
  | `proc_getCPTCodes`, `usp_getCPTCodeByPOS` | Search | Strict `<`/`>` on dates |

- **Several rows per code.** `DATA.icdCodes` has **no key at all**, and `DATA.cptCodes.code` **isn't unique**. Pick one row per code (the one valid on the date of service), and show duplicates in DEV check 6.
- **Billable, not just existing.** IMO-custom ICD codes exist and are non-billable (the DEV prompt says so), so "exists" isn't enough for ICD.
- **The NCHS order file** (a valid-for-HIPAA flag per code; FY2026 has 74,719 valid codes) is a public reference to compare `DATA.icdCodes` against. ICD-10-CM also has **April 1** interim updates, not only October.
- Epic 6's `afterModel` calls the same lookup for every coded slot.

## A3 — Codes only; descriptions from the code tables

- **What happens today:**
  - The ICD description saved to the encounter and the problem list is **the AI's own text**.
  - In the client's screenshot, `S83.241A` ("Other tear of medial meniscus") was shown with the description of `S83.211A` ("Bucket-handle tear"). **Confirmed against the CMS/NCHS titles.**
  - Fix 34385 ("Telos - AI ICD codes, unable to remove") shows the same mismatch broke deletes.
  - CPT descriptions are replaced from `DATA.cptCodes.codeShortDesc`. That text is **outdated for 99234**: it uses pre-2023 history/exam wording, confirmed against the AMA 2023 descriptors.
- **Proposal:**
  - The agent's output carries only the code.
  - Once A2 exists, the agent adds the table description it read (`Description` for ICD; the CPT column to be agreed: `codeShortDesc`, `codeLongDesc` or `userFriendlyDescription`).
  - Until then, the UI looks the description up.
- **Coordination:** the UI can use the existing exact lookups, `usp_getICDDescription` (one code) and `proc_getMultipleCPTCodes`, but `usp_getICDDescription` returns billable codes only. Agree the approach with the UI and API teams (meeting Q10).

## A4 — Code slots in the agent's output (Q1)

- **Today:** the legacy request adds `ICD Code` and `CPT Codes` keys outside the template. The model returns free text (`CODE (desc) <<justification>>`), which the UI parses with regexes.
- **Problems with that parsing:**
  - HCPCS and CPT Categories II/III are dropped without warning (the regex accepts 5 digits only).
  - Lower-case ICD codes are dropped.
- **Planned UI (screenshot 4):** keeps an ICD section and a CPT section.
- **Questions for the client and lead:**
  1. Does the new agent fill these sections?
  2. If so, what does each item carry: the code only, or the code plus an **assessment** (narrative, unchecked, GAPS #15) and a **rank** (the diagnosis order, which screenshot 4 drops)?
  3. Does the agent still split ICD codes into "existing" (already on the problem list) and "new"? That needs the problem list in context (PEA-705 history load).

## A5 — Respect the suppression switches (Q4)

- **The switches:** each account has `isAICodingSuppressed` (ICD) and `isCptAICodingSuppressed` (CPT). The UI enforces them on display and on save (PAC-1049 / AI-CODE-002).
- **Defaults today: both NOT suppressed.**
  - Read default: `usp_AccountList.sql:103-104`, `ISNULL(…, 0)`.
  - Write default: `usp_addEditAccount.sql:163-164`, `= 0`. Its comment still says "default suppressed (safe)".
  - This reverses PB-AIDOC-19's "default suppressed" design. It was changed in PR 11665's review, with no product decision recorded.
  - Switch changes have no audit trail.
  - Meeting Q7 asks whether this is intended.
- **Option a (recommended):** the UI keeps enforcing them as it does now. The agent also leaves out a suppressed code type, which saves tokens and stops the model suggesting codes the account has turned off. This needs both switches in the request context (Epic 9).
- **Option b:** the UI enforces them alone. Simpler, but the model still spends tokens on suppressed sections.

## A6 — Record which saved codes came from the AI (current-system observation)

- **Today:** once saved, AI codes can't be told apart from manual ones.
  - `Encounter.encounterCodeHistory` has no source column, and `byUser` is the clinician.
  - `Patient.patientDiagnosis.source` is `'PacEHR'`.
  - The only record is the raw response in `Log.AILogs`.
- **Confirmed for every branch:** no AI-source marker exists anywhere in git history. Removals on the review screen aren't logged either (`removeField` makes no API call).
- **Why it matters:**
  - Nobody can measure how accurate the AI's codes are, or how often clinicians remove them.
  - The AMA's AI Addendum (14 July 2026) says AI outputs "should be marked as AI-generated where appropriate".
- **Where it belongs:** this is outside `pacEHR_AI`'s build scope. It's recorded here so the lead can decide whether Epic 10 (audit) or the UI/API team owns it (meeting Q12).

## A7 — Add the `TOOLS` contract test (PEA-701 gap)

- **What PEA-701 promised (AC 1):** "Every tool in `TOOLS` reaches the model with a non-empty description and a description on every parameter. A unit test checks the captured request, and a planted tool with a missing description makes that test fail."
- **What's on `9cbfe57`:** **no such test.**
  - `TOOLS` is referenced only in `src/agents/encounter.ts:26,62`.
  - `tests/unit/tools/bmi.test.ts` checks behaviour only.
  - `git log -S TOOLS -- tests` is empty.
- **Fix:** add the test to `tests/unit/agents/encounter.test.ts`.
  1. Capture the request through `stubDeployment`.
  2. For every tool in `TOOLS`, assert that the description is non-empty, every parameter has a description, and `additionalProperties` is `false`.
  3. Add a planted tool with a missing description, which must fail the test.
- **Why now:** PEA-704 adds the second tool, and its spec counts on this test to cover its descriptions.
