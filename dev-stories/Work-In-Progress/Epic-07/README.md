# Epic 07 — Agent Tools: Clarification Pack (PEA-704 first)

**For:** the engineers building Epic 7 in `pacEHR_AI`, and whoever answers the open questions (lead, client, compliance)
**From:** Hem Singh · **Updated:** 2026-10-22
**Benchmark (source of truth):** [`Tickets-Original-JS/epic-07-tools.md`](../../Tickets-Original-JS/epic-07-tools.md), the Node.js
edition. Where this pack and the JS ticket differ, the JS ticket wins until a change is approved. Every difference is listed
in §3 or in [Epic-07-Additions.md](Tech-Specs/Epic-07-Additions.md).
**Code baseline:**

| Repo | Branch | Commit | Date | Used for |
|---|---|---|---|---|
| `pacEHR_AI` | `PacEHR-AI-Develop-Main` | `9cbfe57` | 2026-10-21 | The tool contract and BMI tool this story builds on |
| `pacEHR_AI` (work) | `feature/AITP-88-tool-outcomes-followup` | uncommitted, on `9cbfe57` | 2026-10-22 | Stories S0–S6 below; the developer commits |
| `PacEHR` (Angular) | `PacEHR-DevelopUI-Main` | `02f338919` (re-checked 2026-10-21; first read at `401caa134`) | 2026-10-21 | How the current AI suggests and saves codes, and the new guided workflow (read only) |
| `pacEHR_API` (C# + SQL) | `PacEHR-DevelopAPI-Main` | `dc7316ec3` | 2026-10-21 | Code tables, save procedures, downstream readers (read only) |

> **Scope reminder.** The build work stays inside the Node `pacEHR_AI` service. The Angular and C# findings are
> **context**, so we know what the new agent replaces. They are not work items for those repos.

---

## 1. Where Epic 7 stands

| Story | JS ticket | Status (2026-10-22) | Jira |
|---|---|---|---|
| PEA-701 Shared tool contract | "Not started" | **Merged** (PR 13031). Both gaps are fixed on the work branch (S0): the reducer now keeps repeated outcomes (A1), and the `TOOLS` contract test exists (A7) | AITP-88 |
| PEA-702 `resolve_date` | Not started | Not started | — |
| PEA-703 `compute_bmi` | "Not started" | **Merged** (PR 13032). 13 unit tests, eval 2026-10-18 | AITP-95 |
| **PEA-704 `lookup_icd_cpt`** | Not started | **Built** (S1 + S2): batched and backed by the database, with a format-only fallback. Beyond the JS ticket, which asked for format only (P1) | Not in Jira |
| PEA-705 Context loads | Partly done | Prompt and template loads built; history and note not started | — |

**The ICD/CPT coding stories** ([implementation plan](Tech-Specs/ICD-CPT-Coding-Implementation-Plan.md) §4). All
are on `feature/AITP-88-tool-outcomes-followup`, uncommitted. Unit tests: 286 pass.

| # | Story | Status | What's left |
|---|---|---|---|
| S0 | A1 reducer fix + A7 `TOOLS` contract test | **Built** | — |
| S1 | Code-set access: `CodeSet`, `codeSetRepository`, `checkCodeFormat` | **Built, live-tested on DEV.** Lookups pass. Search moved to an in-memory index (C5, decided 2026-10-22) | — |
| S2 | `lookup_icd_cpt` | **Built** | — |
| S3 | `search_codes` | **Replaced** (decision 2026-10-22): no search tool in the run. The in-memory index (`src/services/codeIndex.ts`) gives alternatives for rejected codes | — |
| S4 | Account switches, `coding` block, tool filtering, `CODING_RULES` | **Built. Eval `20261022-175058` passed:** fields 90.5% / 77.5%, 94% of input tokens from cache, first field 4.5 s | The model calls `search_codes` in only about one run in three |
| S5 | `checkCoding` after the model (statuses, quote, problem list, caps) | **Built. Runs in the eval:** 78% of ICD and 8% of CPT suggestions verified (E/M always needs review) | — |
| S6 | Coding eval: DRAFT key, coding report | **Built, report only. First run:** ICD precision 58% / recall 71%; CPT precision 58% / recall 100%. The note's own instructions were followed (Q2, Q3) | A coder confirms the key ([review sheet](Analysis/S6-Coding-Answer-Key-Review.md)); then a coding gate |
| — | In-memory code index, alternatives, ICD guideline rules, `UNCERTAIN_DX`, SNF eval setting | **Built** ([change log](Change-Logs/2026-10-22-code-index-and-coding-rules.md)). The index: 63k ICD codes, 10 searches in 27 ms | Eval running |
| — | `ABSTAINED` settling (an eval-gate finding) | **Built.** At most 3 `ABSTAINED` per result, against up to 79 ([change log](Change-Logs/2026-10-22-abstained-settling.md)) | — |
| — | Code-set SQL moved into `[AI]` stored procedures (migrations 0013–0016) | **Built, applied and live-tested on DEV.** Place-of-service rule matches `usp_restrictedCPTByPOS` on all 18 listed codes ([change log](Change-Logs/2026-10-23-code-set-stored-procedures.md)) | One eval before push |
| — | Code-review fixes 4–10; invented answers (eval Q5) nulled | **Built, unit-tested.** `codeSetMode` is now per system ([change log](Change-Logs/2026-10-23-review-fixes-and-invented-answers.md)) | One eval before push |

The JS ticket's status table is out of date for PEA-701 and PEA-703.

## 2. Documents in this pack

| Document | What it answers |
|---|---|
| [Tech-Specs/PEA-704-Tech-Spec-ICD-CPT-Format-Check.md](Tech-Specs/PEA-704-Tech-Spec-ICD-CPT-Format-Check.md) | What to build for PEA-704, with the proposed changes to its acceptance criteria |
| [Tech-Specs/ICD-CPT-Coding-Implementation-Plan.md](Tech-Specs/ICD-CPT-Coding-Implementation-Plan.md) | **The build plan:** coding inside the encounter agent, codes chosen from our tables through `search_codes` and `lookup_icd_cpt`, account switches, the output contract, stories S0–S6. Includes the flow and performance review (§8) |
| [Tech-Specs/Epic-07-Additions.md](Tech-Specs/Epic-07-Additions.md) | Work the JS ticket doesn't contain, proposed for approval (A1–A6) |
| [Tech-Specs/2026-10-22-coding-output-format.md](Tech-Specs/2026-10-22-coding-output-format.md) | **The `coding` result format** for the Review AI Output screen and its save: fields, statuses, reasons, existing/new, what the screen still owns |
| [Change-Logs/](Change-Logs/) | Dated change logs for this epic's work in `pacEHR_AI`: [eval coding key](Change-Logs/2026-10-22-eval-coding-key.md), [ABSTAINED settling](Change-Logs/2026-10-22-abstained-settling.md), [code index and coding rules](Change-Logs/2026-10-22-code-index-and-coding-rules.md), [code-set stored procedures](Change-Logs/2026-10-23-code-set-stored-procedures.md), [review fixes and invented answers](Change-Logs/2026-10-23-review-fixes-and-invented-answers.md) |
| [Analysis/ICD-CPT-Current-System-Flow.md](Analysis/ICD-CPT-Current-System-Flow.md) | How today's system has the AI suggest ICD and CPT codes, where they're saved and what reads them |
| [Analysis/ICD-CPT-DEV-Data-Checks.md](Analysis/ICD-CPT-DEV-Data-Checks.md) | Read-only DEV queries that close the remaining data questions |
| [Analysis/Pre-Meeting-Validation.md](Analysis/Pre-Meeting-Validation.md) | What the code, git history and primary sources (CMS, NCHS, AMA, X12) already answer, and the corrections made to this pack |
| [Analysis/S6-Coding-Answer-Key-Review.md](Analysis/S6-Coding-Answer-Key-Review.md) | Sheet for a coder to confirm the expected ICD/CPT codes for the five eval notes (DRAFT key in `tests/eval/cases.json`) |
| [Analysis/Legacy-Team-Meeting-Questions.md](Analysis/Legacy-Team-Meeting-Questions.md) | 30-minute meeting sheet for the PacEHR UI/API team: 12 questions, our assumption for each, space for answers, and what to update afterwards |

## 3. Decisions this pack rests on

**Status key:**
- **Proposed** means the code evidence supports it and it needs sign-off.
- **Open** means it needs an answer from a person.
- **Decided** means it's signed off.

| # | Question | Recommendation | Evidence | Status |
|---|---|---|---|---|
| **D1** | Tool parameters | `{ code, codeSystem: 'ICD10CM' \| 'CPT' }`. `CPT` also accepts HCPCS Level II shapes. Run facts come from `runtime.context` | ICD and CPT are separate everywhere: tables, UI sections, `encounterCodeHistory.codeType`. HCPCS rows (`G2211`, `G0438`) sit in `encounterCPT` and `DATA.cptCodes`, which have no code-system column | Proposed |
| **D2** | Dot-less ICD (`E1119`) | Normalise first: trim, upper-case, strip surrounding brackets and spaces, then insert the dot after the 3rd character when the code is longer than 3 and has no dot. `E1119 → E11.19`, and `I10` stays `I10` | ICD is stored dotted. The only existing normaliser (`usp_ApplyCCLImportDiagnoses`, PAC-1326) does exactly this so "patientDiagnosis.code never receives an undotted code" | Proposed. **Changes an AC** |
| **D3** | Which code shapes are in Phase 1 | ICD-10-CM including the X placeholder and 7th character; CPT Cat I (`#####`), Cat II (`####F`), Cat III (`####T`); HCPCS Level II. **Out:** PLA (`####U`) and modifiers (`99213-25`): base code only | `S83.241A` and `T84.54XA` appear in real use. HCPCS is in `encounterCPT`. No PLA anywhere. Modifiers are always a separate field. The legacy AI parser drops anything that isn't 5 digits | Proposed. PLA to be confirmed by [DEV check 5](Analysis/ICD-CPT-DEV-Data-Checks.md) |
| **D4** | How a result is recorded in `state.toolOutcomes` | Change `tool-call.ts` to write only `reasonCode` to state, not the whole parsed object. Then `FORMAT_INVALID` is a refusal that still carries `status` and `mode` | The middleware spreads the whole result, but a test showed the state schema strips extra keys, so nothing leaks today. Narrowing the write to `reasonCode` is optional hardening. The real A1 defect is the reducer dropping repeated outcomes | Proposed (Additions **A1**) |
| **D5** | Where the format rule lives | A pure exported `checkCodeFormat()` in `src/tools/coding.ts`. The tool wraps it, and Epic 6's `afterModel` imports it | CLAUDE.md:432 says validators are never tools; GAPS #18 | Proposed |
| **P1** | Is PEA-704's premise ("no code set exists") right? | **No, partly.** `DATA.icdCodes` (billable, isActive, dates) and `DATA.cptCodes` (dates) exist in the database pacEHR_AI already reads. Build format-only as specified now, and raise the database lookup as a separate story (Additions **A2**) | Schema checked against the repo DDL and the client's screenshots. **No loader exists in any repo**: the ICD data looks like a manual load around January 2026, and there's no CPT trace at all. The AMA's **AI Addendum (14 July 2026)** allows retrieval-style CPT use and forbids training on CPT. Whether our use fits it, and whether the data is current, are unknown | **Open**: needs a lead + compliance answer (meeting Q1, Q2) |
| **Q1** | Does the new agent fill the ICD and CPT sections? | It should. The live system already has the AI suggest both, and the planned UI keeps both sections | Today's code-slot handling, and screenshot 4. **New on `02f338919`:** the guided workflow (AITP-116, behind account and user flags) deliberately **saves no ICD/CPT** and calls no AI endpoint yet. Reviewing AI output is left to a later "Review AI Output" story, which is probably the screen in screenshot 4 | **Chosen 2026-10-22**: yes, inside the encounter agent ([plan](Tech-Specs/ICD-CPT-Coding-Implementation-Plan.md) C1). Lead sign-off pending |
| **Q2** | What does the agent return per code? | The code only. Never a description: that comes from the code tables. Assessment text and rank are separate questions | The ICD description is saved exactly as the AI wrote it, so `S83.241A` was shown with another code's description | **Chosen 2026-10-22**: code + quote + status, with the description from the table ([plan](Tech-Specs/ICD-CPT-Coding-Implementation-Plan.md) C4) |
| **Q3** | Does the agent propose modifiers or units in Phase 1? | No. The legacy AI never saved them either (unit 1, modifier NULL) | `getCPTArray()` in the UI | Proposed |
| **Q4** | Does the new flow respect the two per-account suppression switches? | Yes, per code type. `isAICodingSuppressed` (ICD) and `isCptAICodingSuppressed` (CPT) | PAC-1049 / AI-CODE-002 in the UI. **Both now default to NOT suppressed**: PR 11665's review reversed PB-AIDOC-19's "default suppressed", with no product decision recorded | **Chosen 2026-10-22**: the service reads both switches from `Account.accounts` on every run ([plan](Tech-Specs/ICD-CPT-Coding-Implementation-Plan.md) C3). Whether the default is intended is still meeting Q7 |

## 4. Recommended order

Updated 2026-10-22. Steps 1, 3 and 4 of the earlier order are done, and the build went further than PEA-704 asked
(S0–S6).

1. **Raise the CPT data problem with the legacy team** (meeting Q1):
   - every CPT row on DEV runs 2020–2027;
   - deleted codes (`99311`–`99313`, `99327`) and non-CPT codes (`658`, `90300`) look valid;
   - the descriptions are custom.

   Until it's fixed, every CPT suggestion should be reviewed.
2. **Get a coder to confirm the eval coding key** ([review sheet](Analysis/S6-Coding-Answer-Key-Review.md)). The
   setting question comes first.
3. **Lead sign-off:** C1–C7, the assumptions in plan §7, and the "respect the note" decision. **Compliance:** P1, the
   CPT licence.
4. **Share the [coding output format](Tech-Specs/2026-10-22-coding-output-format.md)** with the Review AI Output owner.
5. **Commit S0–S6** in separate commits, with a passing eval line.
6. **Fields that miss in every run** (`s1_f5`, `s1_f917`, `s33_f1958`, Q3 `s4_f40/41`): a template and prompt fix
   outside Epic 7, which lifts field precision.

Any push that changes `src/` needs a passing `npm run eval` line in `tests/eval/history.jsonl`. That needs the VPN and the DEV database, and takes about 11 minutes.
