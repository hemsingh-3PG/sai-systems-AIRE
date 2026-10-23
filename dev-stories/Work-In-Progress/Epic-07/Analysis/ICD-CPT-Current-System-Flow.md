# ICD and CPT Codes in the Current System — How the AI Suggests Them, Where They're Saved, What Reads Them

**From:** Hem Singh · **Updated:** 2026-10-21
**Purpose:** context for PEA-704 and the Epic 7 decisions. This describes what the new agent replaces. It is **not** a list
of work for the Angular or C# repos.
**Evidence:** code was read, nothing was run.
- `PacEHR` at `401caa134` (detached HEAD, 2026-10-15)
- `pacEHR_API` at `dc7316ec3` (`PacEHR-DevelopAPI-Main`, 2026-10-21)
- Table schemas confirmed against the client's DB-tool screenshots

The stored prompt text (`AI.prompt`) lives in database data and wasn't read.

---

## 1. Summary

- **The AI suggests both ICD-10 and CPT codes today.** The Angular app parses them from free text and saves them when the clinician clicks **Continue**.
- **Nothing checks an ICD code against `DATA.icdCodes` before it's saved.** It goes to the encounter and to the patient's problem list with `billable = 1` hard-coded, and with the AI's own description.
- **CPT codes go through the manual-entry checks** (billing rule, place of service, primary, duplicate). They're not rejected if missing from `DATA.cptCodes`, and they're saved with unit 1 and no modifier.
- **Saved codes feed downstream systems:** billing (HL7 FT1), risk adjustment (HCC/RAF), quality measures (eCQM/QRDA/MIPS), data exchange (CCDA/HL7) and reports.

## 2. How the AI is asked for codes

| Step | Where (`PacEHR`) | What happens |
|---|---|---|
| Build the output shape | `facades/encounter-ai.facade.ts:915-929` (`getNestedFieldDetails`) | The template's sections, plus extra keys **outside the template**: `ICD Code`, `CPT Codes`, `Follow-up {Date, Description}`, `Date of Service {DOS}`, `Place of Service {POS}` |
| System prompt | `open-ai.service.ts` `getPrompt` → API `usp_getPrompt` → `AI.prompt` | The ICD/CPT instructions live in the stored prompt (database data) |
| CPT re-prompt on a POS change | `encounter-ai.facade.ts:755-756` (`updateCPTOnUpdatePOS`) | A **hard-coded** prompt: "comma-separated CPT code(s) with its description", each marked "Recommended by AI" or "CPT Added by User", with justification in `<<…>>`. It asks for modifiers only inside the justification, and for "only CPT codes valid for this Place of Service" |
| Place of service in the prompt | `encounter-ai.facade.ts:845` | The POS **name** (`POSname`), not the CMS number. The answer is mapped back to an id with `getPOSIdFromPOSName` |
| API role | `pacEHR_API` `AIPromptServices.cs` | Forwards to OpenAI and streams the raw text back. **No code parsing in the API** |
| Logging | `addEditAILogs` → `Log.AILogs` | System, user and response content, plus token counts |

## 3. How the reply is parsed

The model returns free text per section: `CODE (description) <<justification>>`.

| Code type | Parser | Regex | Lost |
|---|---|---|---|
| ICD | `parseICDCodes` (`:1326-1356`) | `/([A-Z0-9.]+)\s+\((.+?)\)(?=\s*<<)/g` | Lower-case codes; any code without a `<<…>>` after it |
| CPT | `parseFieldCodes` / `parseCPTCodes` (`:1286`, `:1113`) | `/(\d{5})\s*\((.*?)\)/g` | **HCPCS (`G2211`), Category II (`####F`), III (`####T`)**: dropped without warning |

- **ICD codes are split** into **"Existing ICD Code(s)"**, codes already in `icdFacade.problemListForTreatment`, and **"New ICD Code Recommendation(s)"** (`:1346-1356`).
- **The CPT description** is replaced by `DATA.cptCodes.codeShortDesc` when the code is found (`getMultipleCPTCodes` → `proc_getMultipleCPTCodes`, matched on code with **no date filter**). Otherwise the AI's text stays.
- **The ICD description is always the AI's text.**
- **The section-name to code-type mapping** is one constant map (`ai-code-sections.ts`, PAC-1049).

## 4. Clinician review

The clinician reviews by **removing, not accepting**. Every suggested code has a remove button (`removeField`). Clicking **Continue** (`toggleScreen()`, `:404`) saves every code that remains.

## 5. Where the codes are saved

```
Continue (toggleScreen, encounter-ai.facade.ts:469-484)
│
├─ ICD "New ICD Code Recommendation(s)"     skipped if account.isAICodingSuppressed
│   ├─ POST saveMultipleEncounterDiagnosis   DiagnosisController.cs:820
│   │    dedupe on (code, description) → usp_InsertMultipleEncounterDiagnosis
│   │    ├─ Encounter.encounterDiagnosis     code, Description = AI text, assessment = AI justification,
│   │    │                                   billable = 1 (hard-coded), hcc = NULL, orderNo appended
│   │    ├─ Encounter.encounterCodeHistory   codeType 'ICD', action 'Added', byUser = clinician,
│   │    │                                   isAddendum = 1 if the encounter is signed
│   │    └─ Encounter.encounter.ICD          comma-separated list, appended to (no dedupe)
│   └─ POST savePatientMultipleDiagnosis     DiagnosisController.cs:346 → usp_InsertPatientMultipleDiagnosis
│        └─ Patient.patientDiagnosis         problem list: billable = 1, hcc = NULL, source 'PacEHR',
│                                            dedupe on (patient, code, description, active)
│
├─ ICD "Existing ICD Code(s)"                encounter path only (no problem-list write)
│
└─ CPT, one code at a time                   skipped if account.isCptAICodingSuppressed
    encounter-cpt.facade.ts:349 saveCPTCodes
      1. checkEncounterCptBillingRule (:361)   non-billable code already billed for this DOS?
      2. getCptByPOS (:379)                    place-of-service restriction
      3. primary-CPT and duplicate checks
    └─ POST saveEncounterCPT                 CPTCodeController.cs:91 → usp_InsertEncounterCPT
         ├─ Encounter.encounterCPT           code, unit = 1, modifier = NULL, isPrimary
         ├─ Encounter.encounterCodeHistory   codeType 'CPT', 'Added'
         └─ Encounter.encounter.cpt          comma-separated list

Later, manual edits only:
  updateEncounterCPT (:201)          modifier / unit → history 'Updated'
  updateEncounterCPTOrder (:537), updateEncounterDiagnosisOrder
  deleteEncounterCPT (:237), deleteEncounterDiagnosis
```

### Checks on save

| | ICD | CPT |
|---|---|---|
| Suppression switch | `isAICodingSuppressed`: default **not suppressed** (read and write default 0 since PR 11665; the procedure comment still says "suppressed") | `isCptAICodingSuppressed`: default **not suppressed** |
| Format check | None | None (the regex only finds codes) |
| Exists in the code table | **No** | **No.** Used for the description only |
| Billable | **Hard-coded `1`** in both procedures | Billing-rule check (a different thing) |
| Place of service | — | Yes (`usp_restrictedCPTByPOS`) |
| Duplicate | (code, description): the **same code with different AI wording is saved twice** | Yes |
| Description source | AI text | `codeShortDesc` if found, else AI text |
| Marked as AI-suggested | **No** | **No** |

## 6. The code tables

The schemas below were confirmed against the repo DDL and the client's screenshots on 2026-10-21.

| Table | Columns that matter | What it can check | Caveat |
|---|---|---|---|
| `DATA.icdCodes` | `code` NVARCHAR(50), `Description` NVARCHAR(255), `isActive`, `billable`, `hcc` (bit), `startDate`/`endDate` **NVARCHAR(20)**, `isDelete`, `billableDate`, `isActiveDate`, `lexical_code` (IMO), `snomed` | Exists, billable, active | Dates are strings in an unknown format. Row count shown as "220…" (cut off) |
| `DATA.cptCodes` | `code` VARCHAR(100), `codeShortDesc`, `codeLongDesc`, `userFriendlyDescription`, `isPrimary`, `isChargeCheckerCPT`, `snomed`, `startDate`/`endDate` **DATE** | Exists, valid on the date of service | **No billable or active column. No code-system column** (HCPCS mixed in). Row count shown as "7.4…" (cut off) |
| `DATA.restrictedCPTByPOS`, `DATA.POSCPTMapping` | `posId`, `cptCode` | CPT allowed for a place of service | `posId` is the CMS number as an INT |
| `DATA.Modifier`, `DATA.CPTModifier`, `DATA.AcountModifier` | Modifier master and allowed modifiers per CPT/account | Modifier allowed for a CPT | Out of Phase 1 |
| `HCC.vw_hccScoring` | ICD **without** the dot | HCC category and score | Joined with `REPLACE(code, '.', '')` |

**Vendors:** the product licenses **IMO Health** for ICD search (`ImoService.cs`, `api.imohealth.com`). No AMA, FDB, Optum or NCCI references were found.

## 7. What reads the saved codes

These are procedures that read `encounterCPT` / `encounterDiagnosis`, grouped by name. Most are read-only reports or exports.

| Downstream use | Examples | Count |
|---|---|---|
| **Billing out** | `usp_getHL7FT1`: CPT, `codeShortDesc`, units, modifier, ICD list per charge line. Also the CPT calculator and billing reports | 9 |
| **Risk adjustment (HCC/RAF)** | `GetRAF_V24`, `GetRAF_V28` (signed and closed encounters) | part of 37 "other" |
| **Quality (eCQM/QRDA/MIPS)** | `usp_verifyAndUpdateECQMMeasures*`, `usp_getQrdaEncounter`, `USP_getMIPSEncounterColor` | 12 |
| **Data exchange** | `usp_getEncDaignosisForCCDA`, `usp_getHl7outboundprocessing` | 5 |
| **Reports** | ACO reports, GDR, day sheet | 19 |

**Why this matters:** an unchecked AI code that survives Continue flows into **claims, RAF scores and MIPS**. That's where a wrong code costs the most.

## 8. Screenshots from the client

### Existing system (screenshots 1–3)

- **ICD row:** `S83.241A (1)`. It's dotted with a 7th character, has a rank, a description, and an assessment box holding the AI's Treatment/Plan text.
- **The description doesn't match the code.** The description shown is "Bucket-handle tear of medial meniscus, current injury, right knee, initial encounter", which is `S83.211A`. `S83.241A` is "Other tear of medial meniscus…". §3 explains why: the ICD description is the AI's text, never checked. **Confirmed against the CMS/NCHS titles** (2026-10-21).
- **CPT rows:** `99234`, `73562`, `20610`, each with units, a **multi-select** modifier list and a rank.
- **Allowed modifiers differ per code:** 99234 offers `57, SA`; 20610 offers `50, 59, FS, LT, RT`.
- **Outdated 99234 description.** The text shown, "detailed or comprehensive history and examination… moderate complexity", is the pre-2023 history/exam wording. **Confirmed against the AMA 2023 descriptors**: 99234 is now set by straightforward/low MDM or 45 minutes. So `codeShortDesc`, which the UI and the billing export (HL7 FT1) both use, is out of date for at least this code. DEV check 4 shows how widespread it is.
- **A modifier that contradicts the diagnosis.** 20610 has modifier `50` (bilateral) for a right-knee diagnosis, where `RT` would be expected.

### Planned build (screenshot 4)

- **ICD rows:** `I10`, `E11.9`, `Z79.4`. Each has a description, a DSM-5 badge, a **QM · MIPS** status (236 Met, 001 Exception, 317 Not Met), an empty assessment box, and a "Sync QM" button.
- **CPT rows:** `99213`, `36415`, `80053`, `83036`, each with a units dropdown and a **single-select** modifier.
- **Points to raise with the UI team or client (not PEA-704 work):**
  - Modifier `25` appears on every CPT row, but it applies to the E/M code (`99213`) only.
  - Modifiers are single-select, where the existing system allows several.
  - The rank `(1)(2)(3)` is gone.
  - A DSM-5 badge appears on `I10` (hypertension). It's either mock data or the flag means something else.
- **What it confirms:** ICD and CPT stay as separate sections (D1). A 3-character ICD code has no dot (D2). Codes drive MIPS status, which raises the stakes of a wrong code.

## 9. The new guided workflow (re-checked on `PacEHR-DevelopUI-Main` `02f338919`, 2026-10-21)

83 commits since `401caa134`. **The code-handling path is unchanged.** These files have no diff:
- `encounter-ai.facade.ts`, `encounter-icd.facade.ts`, `encounter-cpt.facade.ts`
- `ai-code-sections.ts`
- the code models, `encounter.service.ts`, `open-ai.service.ts`

The form's ICD/CPT markup changed only in layout and styling. Modifiers are still multi-select (now line 783).

**What's new is the guided workflow** (AITP-32, -35, -116, -117; `src/app/features/guided-workflow/`):

| Point | Evidence |
|---|---|
| **When it's on** | Account `isGuidedWorkflowEnabled` **and** user `userGuidedWorkflowEnabled`, plus Open AI and New Dashboard. Not in the native mobile or tablet apps (`guided-workflow-feature.service.ts`). A missing flag reads as off |
| **The old AI screen never opens** | With the flag on, an "AI box" sits under the form instead (`encounter-form.component.ts` around 4450-4510) |
| **No codes are saved, deliberately** | "Exit is an event, not a call into EncounterAiFacade.toggleScreen(): that method copies AI values into the form, **saves ICD/CPT** and sets the one-run lock, **none of which the guided workflow may do**" (`guided-workflow-container.component.ts:20-23`) |
| **No AI call yet** | The box captures the note (typing, Dragon dictation, a "/" field picker). The only HTTP read is the template mapping for "What to Cover". "The automatic Execute… comes with the Review AI Output story", and "What to Cover moves to the Review AI Output screen (a later story)" |

**What it means for us:**
- **For accounts with the guided flag on, no AI codes are suggested or saved at all today.** The legacy path that does it is bypassed.
- **The "Review AI Output" story is where the new agent's codes will be reviewed and saved.** It's probably the screen in screenshot 4. It exists only in code comments, with no spec in any repo.
- **Its owner is inside AITP** (the guided-workflow commits are by the 3Pillar team), so Q10 can be settled internally, not only with the legacy team.
- **When that story is written, it has to cover:**
  - both suppression switches (A5);
  - the existing/new ICD split and the problem-list write;
  - the CPT place-of-service checks;
  - descriptions from the code tables (A3);
  - an AI-source marker (A6).

## 10. What this means for the new agent

| Finding | Consequence |
|---|---|
| The AI already suggests codes, and the planned UI keeps both sections | "Nowhere to write" is answered for the product. Q1 asks whether the new agent fills them |
| pacEHR_AI never writes clinical tables, and the save path doesn't check ICD codes | **The agent's checks (PEA-704 + Epic 6 `afterModel`) are the only checks ICD codes get** |
| The AI-written description is saved | Return codes only. Descriptions come from the code tables (A3) |
| Code tables exist | A database lookup is possible (A2), subject to P1 and the DEV checks |
| HCPCS, Cat II/III and 7th-character codes are in use | D1 and D3 |
| ICD is stored dotted, with one existing normaliser | D2 |
| Modifiers are a separate field; the AI never saved them | Q3: no modifiers from the agent in Phase 1 |
| There are two per-account suppression switches | A5 / Q4 |
| AI codes can't be traced after saving | A6 (Epic 10 / lead) |
