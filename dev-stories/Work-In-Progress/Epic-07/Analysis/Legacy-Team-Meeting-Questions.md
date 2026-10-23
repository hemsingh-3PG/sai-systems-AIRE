# Meeting: ICD/CPT Flow with the PacEHR UI and API Team

**Length:** 30 minutes · **Date:** ____________ · **Attendees:** ____________________________________________
**Run by:** Hem Singh · **Revised:** 2026-10-21, after the [pre-meeting validation](Pre-Meeting-Validation.md)
**Goal:** get only what the code can't tell us: data sources, licence, the production prompt, manual steps, product
decisions and plans for the new screen.

**How to use this sheet:**
- Each question starts with **what we already know** (so we don't spend their time on it) and **our assumption** to confirm or correct.
- Tick a box and write notes under each question.
- §6 lists what to update afterwards.

---

## 0. Opening (1 min)

> "We're replacing the AI step that suggests ICD and CPT codes with a server-side agent. We've been through the Angular
> and API code and its history, so we know the save path, the suppression switches and the HL7 queue. We'd like the
> parts that aren't in the code: where the code tables come from, the licence, the production prompt, and what you
> want from us for the new screen."

**If time runs short, ask only:** Q1, Q2, Q7, Q10.

---

## 1. Block 1: The code tables and the licence (9 min)

### Q1. Where do `DATA.icdCodes` and `DATA.cptCodes` come from, who loads them, how often, and when was the last load?

- **Already known:**
  - No script, procedure, job or pipeline in any repo writes either table.
  - Leftovers suggest a manual ICD load around January 2026: `dbo.2026ICD10`, `icdCodes_BAK_01032026`, and `icdCodesMaster_01132026` (IMO-shaped).
  - There's nothing at all for CPT.
- **Our assumption:**
  - ICD comes from a CMS/NCHS file plus IMO, loaded by hand once a year.
  - CPT comes from an AMA file through a vendor, loaded by hand.
  - Neither picks up the April interim updates.
- **Also ask:**
  - **CPT (found on DEV 2026-10-22):**
    - every `DATA.cptCodes` row runs 2020-01-01 to 2027-01-01, and deleted codes (`99311`–`99313`, `99327`) and
      non-CPT codes (`658`, `90300`) are present with those dates;
    - descriptions are custom (`99309` "[30 min] Moderate MDM").

    Is that the same in production, and is there a real effective-date source?
  - Was `icdCodesMaster_01132026` promoted into `icdCodes`?
  - How do retired ICD codes leave the table? Nothing ever sets `isActive = 0` or `endDate`.
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer:**
  - ICD source / who / how often / last load: ____________________________________________
  - CPT source / who / how often / last load: ____________________________________________
  - Retired ICD codes: ____________________________________________

### Q2. Who holds the AMA CPT licence, and has it been updated for the AMA's AI Addendum (14 July 2026)?

- **Already known:**
  - The AMA requires a CPT licence per product.
  - Its AI terms **allow** retrieval-style use, where the AI references licensed CPT at the point of use.
  - They **forbid** training or fine-tuning on the CPT data file, and uploading it into public or open-market AI.
  - AI outputs "should be marked as AI-generated".
- **Our assumption:**
  - The product's licence covers internal use.
  - Our use (sending CPT codes and descriptions to Azure OpenAI under a BAA, with no training) fits "retrieval".
  - Nobody has checked this against the addendum yet.
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer / licence owner / next step:** ____________________________________________

---

## 2. Block 2: How the current flow is meant to work (11 min)

### Q7. Both suppression switches now default to "not suppressed". Is that the intended product decision, and how many production accounts have each one on?

- **Already known:**
  - PB-AIDOC-19 (July 2026) set "default suppressed (safe)" for compliance.
  - PAC-1049 split CPT into its own switch.
  - PR 11665's review then flipped the ICD default to 0, and the write default is 0 too. The procedure comment still says "default suppressed".
  - The design doc left "True for Telos only" undecided.
  - Switch changes have no audit trail.
- **Our assumption:** the flip was accepted in review without a product decision. Most production accounts have both switches off.
- **Also ask:**
  - Was the R7 "affected accounts" query run before the deploy?
  - Can we have the missing plan, `pacehr-orchestration/docs/plans/AI-CODE-002-granular-code-suppression-plan.md`?
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer:**
  - Intended default: ____________________________________________
  - Production counts: ICD suppressed ______ / CPT suppressed ______ / total accounts ______
  - R7 run? ☐ Yes ☐ No · Plan doc: ☐ will send

### Q6. Once a signed encounter is queued for HL7 (DFT), who reads the queue, and does anyone check the codes before the claim?

- **Already known:**
  - Signing inserts an `Hl7outboundprocessing` DFT row when `isHL7Enable = 1`.
  - Nothing in our repos reads that queue.
  - PacEHR has no review queue.
  - `claimTransmitDelayHours` is stored but not used in our repos.
- **Our assumption:**
  - An external HL7 engine sends the charges to the billing company.
  - Their claim scrubber is the only check after the clinician clicks Continue.
  - The claim delay gives clinicians time to correct codes.
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer:**
  - Engine: ____________________________________________
  - Review / scrubber: ____________________________________________
  - Claim delay: ____________________________________________

### Q5. Can you send the production ICD/CPT prompt text, and who maintains it?

- **Already known:**
  - Prompts live only in data, with no history table.
  - The DEV prompt (id 20) tells the model to extract ICD codes "only from the provider note", avoid "unbillable/outdated" and "IMO-custom" codes, and keep CPT to codes valid for the place of service.
- **Our assumption:** production uses one universal prompt close to the DEV one, edited by a few people through the admin page.
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer / who sends it:** ____________________________________________

### Q8 + Q9. Why did review by removing (Continue saves whatever is left), problem-list auto-add and "no AI modifiers" come about? Have wrong AI codes reached a claim or the problem list?

- **Already known:**
  - All three date from the 2024 work (TASK-13919/13920/16109), with no rationale recorded.
  - Removals aren't logged anywhere.
  - Fix 34385 ("Telos - AI ICD codes, unable to remove") shows AI descriptions differ from the catalogue.
- **Our assumption:** all three were chosen for speed. Accuracy has never been measured, and incidents come from support tickets.
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer / known incidents:** ____________________________________________

---

## 3. Block 3: The new screen (7 min)

### Q10. Who owns the new screen in screenshot 4, when is it due, and what do you want from our service for each code?

- **Already known:**
  - The screen doesn't exist on any branch.
  - The new guided workflow (AITP-116, merged 2026-10-21) bypasses the old AI screen and **deliberately saves no ICD/CPT**. Reviewing AI output is left to a later **"Review AI Output"** story, probably this screen.
  - A per-ICD MIPS badge existed briefly and was reverted in April 2026 (`getQMBadgeClass` is still in the code).
  - The DSM-5 flag is set only by an IMO pick.
  - "Sync QM" exists nowhere.
- **Our assumption:**
  - We send the **code only**, plus "existing on problem list / new" for ICD.
  - The UI fetches descriptions with the existing exact lookups (`usp_getICDDescription`, `proc_getMultipleCPTCodes`).
  - The UI saves through the existing endpoints.
  - The MIPS badges come from the eCQM procedures after saving.
- **Also ask:** is screenshot 4 the "Review AI Output" screen? Does your team know that, while the guided flags are on, accounts get no AI codes at all?
- **Confirmed?** ☐ Yes ☐ No ☐ Partly
- **Answer:**
  - Owner / due date: ____________________________________________
  - Fields per ICD code: ____________________________________________
  - Fields per CPT code: ____________________________________________
  - Who saves: ____________________________________________

### Quick confirmations (1 line each)

| # | Statement | Our evidence | ✔ / ✘ / note |
|---|---|---|---|
| Q4 | `billable = 1` in the ICD insert procedures is an old shortcut and should become a lookup | Comment: "Assuming billable is always 1" (October 2024) | |
| Q11a | Single-select modifier in the mock-up is a mistake; keep multi-select | Today's form is multi-select | |
| Q11b | Modifier `25` on every CPT row and a DSM-5 badge on `I10` are mock data | DSM-5 needs an IMO pick; 25 is normally E/M only (to confirm with billing) | |
| Q11c | No rank number is needed; drag-and-drop order is enough | The form shows no rank today | |
| Q12 | You'll add a marker for AI-suggested codes (e.g. a source column in `encounterCodeHistory`), owned by your team | None exists on any branch; the AMA asks for AI outputs to be marked | |

---

## 4. Close (2 min): ask them to send

| # | Item | Who | By when | Received |
|---|---|---|---|---|
| 1 | The current **production prompt text** for ICD and CPT | | | ☐ |
| 2 | The **load source and process** for both code tables, with the last load date | | | ☐ |
| 3 | **Production counts** for each suppression switch, and the **R7 query output** | | | ☐ |
| 4 | The **AI-CODE-002 plan** document | | | ☐ |
| 5 | The **AMA licence owner**, and whether the AI Addendum has been reviewed | | | ☐ |
| 6 | Whether the **DEV code tables are a copy of production**, and whether our service's login can **read** `DATA.icdCodes`, `DATA.cptCodes`, `DATA.restrictedCPTByPOS` | | | ☐ |

## 5. Anything new they raised

- ____________________________________________
- ____________________________________________

## 6. After the call: what to update

| Answer | Update |
|---|---|
| Q1, Q2 + close items 2, 5, 6 | README **P1** and Additions **A2** |
| Q7 + close items 3, 4 | README **Q4** and Additions **A5** |
| Q6, Q8 | PEA-704 tech spec §2 (how much the agent's check carries) and Epic 6's `afterModel` scope |
| Q5 | Epic 8: file the production prompt with the pack |
| Q9, Q10, Q11 | README **Q1–Q3**, Additions **A3**, **A4** (output contract, Epic 3) |
| Q4, Q12 | Additions **A6**; the current-system notes for the lead |
