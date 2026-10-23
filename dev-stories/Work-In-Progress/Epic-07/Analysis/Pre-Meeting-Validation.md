# Pre-Meeting Validation — What the Code and Public Sources Already Answer

**From:** Hem Singh · **Updated:** 2026-10-21
**Purpose:** before meeting the PacEHR UI/API team, answer as many of the
[meeting questions](Legacy-Team-Meeting-Questions.md) as possible from evidence, and correct this pack where it was wrong.

**How:**
- Read-only sweeps of all three repos, including git history on every branch and deleted design docs:
  - `PacEHR` `401caa134`
  - `pacEHR_API` `dc7316ec3`
  - `pacEHR_AI` `9cbfe57`
- One probe test run in `pacEHR_AI` (written temporarily, then deleted).
- Web research that checked 8 external claims against primary sources (CMS, CDC/NCHS, AMA, X12), each verified by three independent reviewers.

**Limit:** the database project was imported from production in May 2026 (`e3d89ac56`, `3e1de463e`). SQL objects have no git history before that.

---

## 1. Meeting questions: what's already answered

| Q | Status | What the evidence shows | Still ask |
|---|---|---|---|
| **Q1** How the code tables are loaded | **Partly** | **No loader exists in any repo**: no script, procedure, job or pipeline writes `DATA.icdCodes` or `DATA.cptCodes`. Leftovers point to a manual load around January 2026: `dbo.2026ICD10` (a raw import layout with `DottedCode` and "Valid for Submission on a UB04"), `icdCodes_BAK_01032026`, and `icdCodesMaster_01132026`, which is filled by `usp_addEditNewIcdCodes_type` (IMO-shaped, called by no C#). **There's nothing at all for CPT.** IMO is used live for search (`ImoService.cs:206`), not to refresh the tables | The source files, who loads them, how often, and whether `icdCodesMaster_01132026` was promoted to `icdCodes` |
| **Q2** CPT licence for AI use | **Partly** | AMA: CPT needs a licence **per product**. Its **AI Addendum (14 July 2026)** **allows** retrieval-style AI that references licensed CPT content at the point of use, and **prohibits** training or fine-tuning on the CPT data file and uploading it into public or open-market AI systems. AI outputs "should be marked as AI-generated where appropriate". ICD-10-CM: the NCHS order file flags each code valid or not for HIPAA transactions (FY2026: 74,719 valid). Whether the files are "public domain" wasn't confirmed | Who holds the AMA licence; whether it has been updated for the AI Addendum; whether sending CPT codes through Azure OpenAI under our BAA counts as permitted retrieval use |
| **Q3** Retired codes and description columns | **Mostly** | **ICD:** nothing ever sets `isActive = 0`, `endDate` or `isDelete`, and nothing reads `startDate`/`endDate`. The ICD dates are unused. **CPT:** dates are used, but with **strict `<` / `>`** (`proc_getCPTCodes.sql:30`, `usp_getCPTCodeByPOS.sql:26`), so a code is hidden on its first and last valid day. `proc_getMultipleCPTCodes` and `usp_getHL7FT1` don't filter by date. **Descriptions:** `codeShortDesc` goes to the UI and to billing (FT1); `userFriendlyDescription` is used only in the POS lookup and QRDA; `codeLongDesc` only in QRDA and Pinecone | How retired ICD codes leave the table on a reload, if they do |
| **Q4** `billable = 1` hard-coded | **Answered** | Created by Akash Kumar in October 2024 with the comment "Assuming billable is always 1 for this insert". No ticket is linked. Fix `3593769e0` ("Telos - AI ICD codes, unable to remove") removed the description match from the delete procedures, which shows AI descriptions differ from the catalogue | Confirm in 30 seconds only |
| **Q5** Production prompt | **Partly** | The production text isn't in any repo: prompts live only in data (`usp_addEditAiPrompt`), with no history table. The DEV prompt (id 20) has the code instructions: ICD "Extract… only from the following provider note… Do not select any unbillable/outdated ICD codes… Do not select any IMO-custom created ICD codes as these are non-billable"; CPT "only CPT codes valid for this Place of Service… Suggested by… 'Recommended by AI'". `usp_getPrompt` picks the template prompt, then the account's, then universal. Its comment says "non-universal" but the code filters `isUniversal = 1` | The production text |
| **Q6** What happens before billing | **Mostly** | Signing (`usp_verifyEncounter.sql:155-158`, called from `EncounterService.cs:102`) queues an `Hl7outboundprocessing` DFT row when `isHL7Enable = 1`. Addendums queue as well. **Nothing in our repos reads that queue**, so an external HL7 engine does. **There is no review queue in PacEHR.** `claimTransmitDelayHours` is stored but not used in these repos | Which engine reads the queue; whether the billing company scrubs claims; what the claim delay does |
| **Q7** Suppression defaults | **Answered, and it corrects this pack** | PB-AIDOC-19 (July 2026) made "Default = suppressed (safe)" to remove the "wrong-code billing/compliance exposure". PAC-1049 split CPT into its own switch. PR 11665's review then **flipped the ICD read default to 0**, and the write default is now `= 0` as well (`usp_addEditAccount.sql:163`; its comment still says "default suppressed"). **Today both switches default to NOT suppressed.** PB-AIDOC-19 left a product decision open ("True for Telos only"). Switch changes have no audit trail | Production counts per switch; whether the R7 "affected accounts" query was run before the deploy; whether "not suppressed by default" is the intended product decision |
| **Q8** Review by removing | **Partly** | It's been that way since AI v1 (`deb3a9077`, June 2024), with no rationale recorded. **Removals aren't recorded anywhere**: `removeField` makes no API call and has no Pendo id. The only wording is the dialog text "AI-generated codes will be added… human review" | Why; any known incidents |
| **Q9** Problem-list auto-add; modifiers | **Partly** | Behaviour confirmed (`f4a6b2b20` TASK-16109; `f43f22d49` TASK-13919). Since PAC-958, AI CPT codes take the manual add path, which also saves unit 1 and no modifier, and the clinician edits afterwards. No rationale recorded | Why (2024 work items TASK-13919/13920/16109) |
| **Q10** The new screen | **Partly** | **Update for `02f338919`:** the new guided workflow (AITP-116) deliberately saves no ICD/CPT and calls no AI endpoint yet. Reviewing AI output is left to a later **"Review AI Output"** story, probably screenshot 4, owned inside AITP ([current-flow §9](ICD-CPT-Current-System-Flow.md)). **The new screen doesn't exist on any branch.** Parts existed before: a per-ICD MIPS badge (`a848754cd` March 2026, reverted April 2026; `getQMBadgeClass` is still at `encounter-mips.facade.ts:132`) and the DSM-5 flag (shipped in PAC-1358; set only when a code is picked through IMO search with `isIMODSM5Enabled`; **AI-saved codes never set it**). "Sync QM" exists nowhere | Who owns the screen, the timeline, and what fields they want from us per code |
| **Q11** Mock-up details | **Mostly** | Today's modifiers are **multi-select** (`encounter-form.component.html:783` on `02f338919`). Single-select exists nowhere, so the mock-up is a deviation. The form shows no rank number; rows are reordered by drag and drop. A DSM-5 badge on `I10` needs an IMO pick with DSM-5 enabled, so it's probably mock data. The modifier-25 rule wasn't confirmed by the research | Confirm the mock-up is illustrative. Ask billing about modifier 25 |
| **Q12** AI-source marker; exact lookup | **Answered** | **No AI-source marker on any branch** (searched all git history). `patientDiagnosis.source` holds the feed name, not AI. **Exact-match lookups do exist:** `usp_getICDDescription` (one code, billable only), `proc_getIMOICDCodes` (a list, no billable filter), `proc_getMultipleCPTCodes` (a list, no date filter). The AMA AI Addendum's "mark AI-generated outputs" supports adding a marker | Will they add a marker, and who owns it |
| Close 5 | DEV a copy of production? | Partly: the schema was imported from production in May 2026. The data is unknown | Ask |
| Close 6 | Can our login read the code tables? | Partly: `pacEHR_AI` already reads `DATA.specilityMaster` (`clinicianRepository.ts:7-12`), so it can read at least one `DATA` table. There are no GRANT scripts in any repo | Confirm, or test with DEV check 1 under the service login |

## 2. Corrections applied to this pack

| What we said | What's true | Fixed in |
|---|---|---|
| A1: the reducer defect was read but not run | **Confirmed by a test**: two identical outcomes give one entry, in sequence and in parallel. The "whole result spread into state" defect **didn't reproduce**, because the state schema strips extra keys | Additions A1 |
| A `TOOLS` contract test exists (PEA-701) | **No such test exists.** PEA-701's first criterion (a test over every registered tool's description) wasn't delivered | New **A7**; PEA-704 spec §6 |
| ICD suppression write default is 1 | **Both switches default to not suppressed** | README Q4, Additions A5, current-flow §5 |
| There's no exact-match ICD lookup | `usp_getICDDescription` and `proc_getIMOICDCodes` exist | Additions A2, A3 |
| "122 calls", "26% / 36%", "Q5's CPT 99327" (from the JS ticket) | **No source found in any repo.** The cited docs (`five-query-comparison`, `clinician-usage-behaviour`, `SOP-COVERAGE`, `single-vs-multi-agent`) don't exist on disk. "Do not add any ICD-10 codes" appears only in the synthetic eval query `tests/eval/queries/q2.txt` | Meeting sheet Q7; treat these as unverified |
| ICD-10-CM changes every 1 October | Also **1 April** interim updates (FY23–FY26 all had one) | DEV checks §7 |
| `S83.241A` description mismatch (screenshot 1) | **Confirmed**: `S83.241A` is "Other tear…", and `S83.211A` is "Bucket-handle tear…" | Current-flow §8 |
| The 99234 text is outdated (medium confidence) | **Confirmed**: since 2023 the level is set by MDM or time. The text shown is the pre-2023 history/exam wording | Current-flow §8 |
| ICD codes sent without the dot in claims | **Confirmed** (X12 RFI 1882) | PEA-704 spec §2 |
| PLA format (four digits plus U) | **Confirmed**. Still excluded from Phase 1 unless DEV check 5 finds PLA codes | — |
| JS ticket: `MIDDLEWARE` has 4 entries | It now has 5, including `toolCallMiddleware` | README §1 |

## 3. New findings worth knowing

1. **`placeOfService` in `pacEHR_AI` is a POS name** ("Group Home", "Skilled Nursing Facility"), not the CMS number. A POS check (A2) needs a name-to-`posId` mapping.
2. **The DEV prompt computes the follow-up date "from today".** That conflicts with PEA-702 ("never from today") and is worth raising in Epic 8.
3. **IMO-custom ICD codes exist** and are non-billable, per the prompt. So any lookup must check the billable flag, not just that the code exists.
4. **`DATA.icdCodes` has no key at all, and `DATA.cptCodes.code` isn't unique.** Joins can return duplicate rows, for example in the billing export.
5. **CPT date filters exclude a code's first and last valid day** (strict `<`/`>`). That's a current-system defect, recorded here for the lead.
6. **No audit trail of suppression-switch changes**, and **no record of which codes the AI suggested or the clinician removed**. Nobody can measure how accurate the AI's codes are today.
7. **A deleted design doc names a plan we don't have:** `pacehr-orchestration/docs/plans/AI-CODE-002-granular-code-suppression-plan.md`. Ask for it.

## 4. Frontend re-check (`PacEHR-DevelopUI-Main` `02f338919`, 2026-10-21)

- **83 new commits. Nothing changes the code-handling path.** The AI, ICD and CPT facades, `ai-code-sections.ts`, the code models and the services are unchanged.
- **The guided workflow (AITP-116/117) is new.** With its flags on, the legacy AI screen is bypassed, and **no AI codes are suggested or saved**, by design.
- **Codes come back with a later "Review AI Output" story.** That makes Q10 partly an internal AITP question ([current-flow §9](ICD-CPT-Current-System-Flow.md)).

## 5. What this means for the meeting

Q4 and Q12 are answered, and Q3, Q6, Q7 and Q11 are mostly answered. The [meeting sheet](Legacy-Team-Meeting-Questions.md) now starts each question with what we already know, so the 30 minutes go on the open parts:
- **where the code tables come from** (Q1);
- **the licence and the AI Addendum** (Q2);
- **the production prompt** (Q5);
- **who reviews before billing** (Q6);
- **the suppression decision** (Q7);
- **the new screen's contract** (Q10).
