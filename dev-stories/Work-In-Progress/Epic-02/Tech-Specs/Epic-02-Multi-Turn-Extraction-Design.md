# Epic 02 — Multi-Turn Extraction: Data Design and Flow

**Scope:** the AI engine's data layer only (`pacEHR_AI`, `AI.*` schema).

> ⛔ **Amended 2026-10-07 — `AI.extractionSession` is withdrawn.** Turns are grouped by
> `Encounter.encounter`: `encounterID` keys `AI.transcript`, `AI.agentRun` and `AI.fieldState`;
> `templetID` moves onto `AI.agentRun` and `AI.fieldState`; a turn with `parentRunID` NULL starts a
> new conversation (template change, start over); `sp_getapplock` replaces the session-row lock.
> Migrations are now `0001`–`0006`: `0001_create_ai_schema.sql` is also withdrawn (2026-10-07) --
> the AI schema already exists in production, so no script creates it. **Where this document
> mentions the session, its ER diagram, turn
> flow or data dictionary, the current version is
> [Epic-02-AI-Engine-Data-Flow-Reference.md](Epic-02-AI-Engine-Data-Flow-Reference.md).** The
> rationale below (protection, merge rules, evidence) is unchanged.
**Date:** 2026-10-06
**Status:** Design implemented in `migrations/sql/0001`–`0006` on branch
`3p-dev/PEA-201-ai-schema-data-layer`. **Not yet applied to a SQL Server instance** — see §12.
**Supersedes:** §3.1 (the DDL) of the PEA-202 and PEA-203 tech specs.
**Scenario reference:** [Epic-02-AI-Engine-Data-Flow-Reference.md](Epic-02-AI-Engine-Data-Flow-Reference.md) — which table each scenario touches, with worked rows and a change-impact index.

---

## 1. The scenario

1. A clinician creates an encounter for a patient and picks a template. The encounter form is now
   tied to one patient and one template.
2. The clinician posts a transcript. The AI reads it and returns, for every field in the template,
   a value and the passage of the transcript it came from.
3. The clinician posts another transcript. This is a **follow-up**: the AI must know it continues
   the earlier one, the way a chat thread continues its earlier messages.
4. **Values already filled are not altered.** A value that carries high weight is kept, whatever
   the follow-up says.

Point 4 is the hard one. "Do not change it" in a prompt is a request the model can ignore. Here it
is enforced **twice, by code and by the database**. The engine refuses to overwrite a protected
value. Separately, a CHECK constraint refuses to *record* an overwrite, so even a bug in the engine
cannot store one.

**One deliberate refinement.** Ignoring a follow-up silently would lose real corrections, e.g.
*"correction — BP was 140/90"*. So a differing proposal for a protected field is **kept out of the
chart but not thrown away**. It is stored as a `CONFLICT` and shown to the clinician. The protected
value stays exactly as it was. The model's proposal just isn't discarded unseen.

---

## 2. The model in one picture

```
 Encounter.encounter ──(read only)──┐
                                    ▼
 AI.extractionSession   one conversation per encounter + template
   │ 1
   ├──< AI.transcript          each text the clinician posted (immutable)
   │       ▲    ▲
   │ 1     │    └─────────────────────────────┐
   ├──< AI.agentRun            one per turn ──┘ (which transcript it processed)
   │       │ ▲
   │       │ └── parentRunID: the turn it built on
   │       │ 1
   │       └──< AI.fieldOutcome   one per field per turn: proposal · prior state · merge · decision
   │                 │ 1
   │                 └──< AI.fieldEvidence   passages supporting the proposal ──> AI.transcript
   │
   └──< AI.fieldState          current value + protection per field (ACTIVE sessions only)
                 └── setByOutcomeID ──> AI.fieldOutcome
```

| Table | Kind | Holds PHI | Lifetime |
|---|---|---|---|
| `extractionSession` | record | no | kept |
| `transcript` | record | **yes** | text redacted at retention; row kept |
| `agentRun` | audit, append-only | no | kept |
| `fieldOutcome` | record | **yes** | retention purge |
| `fieldEvidence` | record | **yes** | goes with its `fieldOutcome` (cascade) |
| `fieldState` | **mutable projection** | **yes** | deleted when the session closes |

---

## 3. What changed from the previous design

| | Before | Now | Why |
|---|---|---|---|
| Conversation | none — every run stood alone | `AI.extractionSession` | A follow-up needs something to follow |
| Transcript | not stored | `AI.transcript`, immutable | Evidence offsets need text that cannot move |
| `agentRun.outcome` | `COMMITTED` / `AWAITING_REVIEW` / `BLOCKED` | **`COMPLETED` / `BLOCKED` / `FAILED`** | 🔴 **Fixes a live defect:** the merged agent core (`failure-modes.ts`) writes these three. The old CHECK would have rejected every completed and every failed run |
| `agentRun.failureMode` | absent | added | The agent produces it; Epic 10 counts it |
| `agentRun.promptId`, `promptTemplateHash` | absent | added | `AI.prompt` rows are edited in place; the id alone does not say which text was sent |
| `agentRun.requestID` | absent | added, unique | A retried or double-clicked request cannot write a second audit row |
| `agentRun.requestedByUserID`, `requestedByOid` | absent | added | The audit row did not say *who* asked |
| `agentRun.templetID` | on the run | moved to the session | The session fixes the template |
| `fieldOutcome.foundIn` | one free-text column | **`AI.fieldEvidence`**, many per outcome | A value can have several passages, in several transcripts |
| `fieldOutcome` prior state, `mergeAction` | absent | added | The engine's decision, and what it was decided against, have to be auditable |
| One outcome per field per turn | not enforced | `UQ_fieldOutcome_runField` | A duplicate would make "what did this turn propose" ambiguous |
| Review queue | every undecided row | only rows that changed something | `KEPT` / `CONFIRMED` / `EMPTY` rows need no clinician |

---

## 4. Protection — the "weightage"

Every filled field has a protection level. It is a **band, not a number**, for the same reason
confidence is: a number invites arithmetic that means nothing.

| Protection | Set when | The model may replace it? |
|---|---|---|
| **LOCKED** | A clinician typed the value, or accepted or corrected it on review. Also a clinician saying "no value" (locked empty) | **Never** |
| **HIGH** | An earlier turn found it with HIGH confidence **and** at least one passage the engine located (`EXACT` or `NORMALIZED`) | **Never** |
| **LOW** | An earlier turn found it with MEDIUM or LOW confidence, or with evidence the engine could not locate | Yes — a later turn's value replaces it |
| *(no row)* | Nothing found yet | Yes — a later turn fills it |

**Promotion:** a LOW value that a later turn confirms with HIGH confidence and located evidence
becomes HIGH. Two independent mentions are stronger than one.

**Why evidence decides it:** a quote the engine cannot find in the transcript is the strongest
available sign the model invented the value. So such a value is never trusted enough to be protected.

---

## 5. The merge rules

The engine compares each proposal with the field's prior state and records exactly one
`mergeAction`. **This is code, not prompt** — it runs on every proposal whatever the model said.

| Prior state | Proposal | `mergeAction` | Field state afterwards |
|---|---|---|---|
| none | FOUND, validators pass | **FILLED** | AI value; HIGH or LOW per §4 |
| none | ABSENT / ABSTAINED | **EMPTY** | still none |
| any | FOUND, a validator **blocks** it | **REJECTED** | unchanged |
| any value | ABSENT / ABSTAINED | **KEPT** | unchanged — a follow-up that doesn't mention a field never erases it |
| AI · LOW | FOUND, same value | **CONFIRMED** | may promote to HIGH |
| AI · LOW | FOUND, different | **UPDATED** | the new AI value replaces it |
| AI · HIGH | FOUND, same | **CONFIRMED** | unchanged |
| AI · HIGH | FOUND, different | **CONFLICT** | **unchanged**; proposal queued for the clinician |
| CLINICIAN · LOCKED | FOUND, same | **CONFIRMED** | unchanged |
| CLINICIAN · LOCKED | FOUND, different (or field locked empty) | **CONFLICT** | **unchanged**; proposal queued for the clinician |

**What the database enforces**, independently of the code:

| Constraint | Refuses |
|---|---|
| `CK_fieldOutcome_protectedNeverOverwritten` | `FILLED` into a field that had a value; `UPDATED` over anything but LOW |
| `CK_fieldOutcome_mergeMatchesState` | `CONFLICT` without a protected prior; `KEPT` or `CONFIRMED` without a prior; `EMPTY` with one; a FOUND-only action on an ABSENT proposal, and the reverse |
| `CK_fieldOutcome_rejectedIsBlocked` | `REJECTED` without a `BLOCK` verdict, and a `BLOCK` verdict recorded as anything but `REJECTED` |
| `CK_fieldOutcome_priorState` | prior state half-filled; a clinician value that isn't LOCKED; an AI value that is |
| `CK_fieldState_protection` | the same two rules on the live state |

The engine applies a proposal to `AI.fieldState` with an `UPDATE … WHERE protection = 'LOW'`. So
even a stale read cannot overwrite a HIGH or LOCKED row: the statement matches zero rows.

---

## 6. The flow of one turn

```
Clinician posts a transcript
  │
  1 ▸ find the ACTIVE session for the encounter, or create one
  │     reads    Encounter.encounter (patient, template)          read-only
  │     writes   AI.extractionSession                             if none ACTIVE
  │     ▸ the encounter's template differs from the session's → mark it SUPERSEDED, start a new one
  │
  2 ▸ store the transcript as posted                              before anything else
  │     writes   AI.transcript (text + SHA-256)
  │
  3 ▸ reconcile with the form — what is on the chart right now?
  │     reads    the current form values (see §10, decision 2)
  │     writes   AI.fieldState   a value that differs from the AI's → source CLINICIAN, LOCKED
  │
  4 ▸ build the context  (§7)
  │     reads    AI.fieldState, earlier AI.transcript rows, AI.prompt via usp_getPrompt
  │
  5 ▸ guards → model call → structured response      ── no lock held across this step
  │
  6 ▸ one short transaction:
  │     lock     AI.extractionSession row (UPDLOCK)  — serialises turns in one session
  │     re-read  AI.fieldState  — if another turn landed meanwhile, merge against *that*
  │     merge    each field per §5  — deterministic code, so no second model call
  │     writes   AI.agentRun          (turnNumber = next; parentRunID = latest COMPLETED run)
  │              AI.fieldOutcome      one row per field
  │              AI.fieldEvidence     one row per located or unlocated passage
  │              AI.fieldState        FILLED / UPDATED / promotions only, WHERE protection='LOW'
  │     commit
  │
  7 ▸ return to the form: FILLED and UPDATED values, plus CONFLICT and REJECTED rows for review
```

**A blocked or failed turn** still writes its `AI.agentRun` row, with its turn number, transcript
and reason code. It writes no field rows and leaves `AI.fieldState` untouched. The next turn builds
on the last **COMPLETED** turn, which is why `parentRunID` points there rather than at
`turnNumber − 1`.

**Concurrency:** step 6 is the only step that writes the merge, and it is short. The model call in
step 5 holds no lock. `UQ_agentRun_sessionTurn` stops two tabs claiming one turn number, and
`UX_extractionSession_activeEncounter` stops them creating two sessions.

---

## 7. What the model is told on a follow-up

This is what makes the AI "know" it is continuing a conversation.

| Part | Content |
|---|---|
| System prompt | From `AI.prompt` via `usp_getPrompt`, placeholders filled — unchanged |
| Turn header | "This is turn *N* of an ongoing extraction for this encounter." |
| Field state | Every filled field: value, unit and protection. LOCKED and HIGH are marked "confirmed — report only an explicit contradiction" |
| Earlier transcripts | The last *K* transcripts, oldest first. *K* is recorded in `agentRun.priorTurnsIncluded` |
| New transcript | The text just posted |

**The response contract this design expects** from the schema builder (PEA-304, not yet built).
For every field:

```json
{ "value": "140/90", "unit": "mmHg",
  "status": "FOUND", "confidence": "HIGH",
  "evidence": [ { "quote": "Repeat BP 140/90", "turn": "current" },
                { "quote": "BP 120/80",        "turn": 1 } ] }
```

`turn` lets a quote point into an earlier transcript, and the engine maps it to a `transcriptID`.
**The model returns quotes, never offsets** — the engine locates them (`AI.fieldEvidence`).

The whole composed prompt is hashed into `agentRun.promptHash`. So two runs can be proven to have
seen the same input without storing it.

---

## 8. Worked example — two turns

Template fields: **BP**, **Heart rate**, **Temperature**, **Weight**.

**Turn 1** — *"Follow-up visit. BP 120/80. Heart rate 72. Temp maybe 99."*

| Field | Proposal | Evidence | Prior | `mergeAction` | State after |
|---|---|---|---|---|---|
| BP | FOUND 120/80 · HIGH | "BP 120/80" · EXACT | — | FILLED | AI · **HIGH** |
| Heart rate | FOUND 72 · MEDIUM | "Heart rate 72" · EXACT | — | FILLED | AI · LOW |
| Temperature | FOUND 99 · LOW | "Temp maybe 99" · EXACT | — | FILLED | AI · LOW |
| Weight | ABSENT · HIGH | — | — | EMPTY | — |

*Between turns, the clinician edits heart rate on the form to 74.* Step 3 of turn 2 sees the
difference and makes heart rate **CLINICIAN · LOCKED · 74**.

**Turn 2** — *"Weight 82 kg. Repeat BP 140/90. Temp 98.6 F."* — `parentRunID` = turn 1,
`priorTurnsIncluded` = 1.

| Field | Proposal | Prior | `mergeAction` | State after |
|---|---|---|---|---|
| BP | FOUND 140/90 · HIGH | AI · HIGH · 120/80 | **CONFLICT** | **120/80 kept**; 140/90 queued for the clinician |
| Heart rate | ABSENT | CLINICIAN · LOCKED · 74 | KEPT | 74 |
| Temperature | FOUND 98.6 F · HIGH | AI · LOW · 99 | **UPDATED** | AI · HIGH · 98.6 F |
| Weight | FOUND 82 kg · HIGH | — | FILLED | AI · HIGH · 82 kg |

**What the clinician sees:** weight and temperature filled, and one item to rule on — *"BP: you
have 120/80; the latest transcript says 140/90."* Heart rate is untouched. The rule "do not alter
what is filled" held for BP and heart rate, and no correction was lost.

---

## 9. Retention and PHI

| Table | What the purge does | State today |
|---|---|---|
| `fieldOutcome` | deletes decided rows past the window (owner decision, 2026-10-06) | ✅ built (`fieldOutcomeRetention.ts`) |
| `fieldEvidence` | goes with its outcome by `ON DELETE CASCADE` | ✅ no purge change needed |
| `fieldState` | its outcome reference is set to NULL by `ON DELETE SET NULL` | ✅ cannot block the purge |
| `transcript` | redact `transcriptText`, stamp `redactedUtc`, keep the row and its hash | ⚠️ **not built** — §10, decision 5 |
| `fieldState` rows | deleted when the session closes | ⚠️ engine logic, not built |
| `agentRun`, `extractionSession` | kept | no PHI |

---

## 10. Decisions this design needs

| # | Decision | Recommendation |
|---|---|---|
| 1 | **Ask the model about every field each turn, or only empty and LOW ones?** | **Every field.** Corrections to protected values then surface as CONFLICT. The cost is more rows — mostly KEPT |
| 2 | **Where do "current form values" come from?** | **The request**, sent by the .NET API from the open form. Reading `Encounter.encounterData` lags up to 10 s behind autosave, and an edit made in those 10 s would be missed and overwritten |
| 3 | **A clinician deletes an AI value on the form** — indistinguishable from "not transferred yet" | Needs an explicit signal from the form or the review path. Until then the engine keeps the AI value in state |
| 4 | 🔴 **Purge predicate.** `KEPT`, `CONFIRMED` and `EMPTY` rows are never decided, so under the 2026-10-06 rule they are never purged | Purge them past the window regardless of `decidedAtUtc`. They were never in the review queue. **This changes an owner decision**, so it is yours to make |
| 5 | **Transcript redaction** in the purge job | Add it with the same window. Until then transcripts accumulate |
| 6 | `requestID` is `VARCHAR(64)`, but `ExtractionContext.runId` has no maximum length | Add `.max(64)` to the zod schema |
| 7 | **Volume.** The earlier estimate was 10.95M `fieldOutcome` rows a year, at one run per encounter | Unmeasured multiplier. At an *assumed* 2.5 turns per encounter, about 27M a year. Measure after shadow mode |

---

## 11. Data dictionary

### `AI.extractionSession`

| Column | Type | Null | Meaning |
|---|---|---|---|
| `sessionID` | BIGINT identity | no | The conversation's identity |
| `encounterID` | INT | no | The encounter being documented. Fixed for the session's life |
| `patientID` | INT | no | The encounter's patient, copied at start |
| `templetID` | INT | no | The template when the session began (live spelling). A change means a new session |
| `accountId` | INT | no | The organisation; selects the prompt tier and scopes reporting |
| `status` | VARCHAR(12) | no | `ACTIVE` · `CLOSED` (encounter signed) · `SUPERSEDED` (template changed) · `ABANDONED` (started over) |
| `startedByUserID` | INT | no | PacEHR user who posted the first transcript |
| `createdUtc` | DATETIME2 | no | When the first transcript arrived |
| `closedUtc` | DATETIME2 | yes | When it stopped accepting turns; NULL exactly while ACTIVE |

### `AI.transcript`

| Column | Type | Null | Meaning |
|---|---|---|---|
| `transcriptID` | BIGINT identity | no | The transcript's identity |
| `sessionID` | BIGINT | no | The conversation it was posted into |
| `transcriptText` | NVARCHAR(MAX) | yes | The text exactly as posted. **PHI.** NULL only after redaction |
| `textHash` | VARCHAR(64) | no | SHA-256 of the original; survives redaction |
| `submittedByUserID` | INT | no | PacEHR user who posted it |
| `createdUtc` | DATETIME2 | no | When it was posted |
| `redactedUtc` | DATETIME2 | yes | When retention removed the text |

### `AI.agentRun`

| Column | Type | Null | Meaning |
|---|---|---|---|
| `runID` | BIGINT identity | no | The turn's identity |
| `requestID` | VARCHAR(64) | no | Caller's request id (`ExtractionContext.runId`); unique |
| `sessionID` | BIGINT | no | The conversation |
| `turnNumber` | INT | no | Position in the session from 1; every attempt numbered |
| `parentRunID` | BIGINT | yes | The latest COMPLETED turn this one built on; NULL = no earlier context |
| `transcriptID` | BIGINT | no | The transcript this turn processed |
| `priorTurnsIncluded` | INT | no | Earlier transcripts sent as context |
| `encounterID` | INT | no | Copied from the session, for "every AI call on this chart" |
| `requestedByUserID` | INT | no | PacEHR user who posted |
| `requestedByOid` | VARCHAR(36) | no | That user's verified Entra object id |
| `promptId` | INT | yes | The `AI.prompt` row used |
| `promptTemplateHash` | VARCHAR(64) | yes | Hash of that row's text when used |
| `promptHash` | VARCHAR(64) | yes | Hash of the fully composed prompt |
| `modelDeployment` | NVARCHAR(100) | yes | The Azure OpenAI deployment |
| `configVersion` | VARCHAR(64) | yes | Template configuration version the schema was built from |
| `inputTokens` / `outputTokens` | INT | yes | From the model's response — never client-supplied |
| `latencyMs` | INT | yes | Measured by the service |
| `outcome` | VARCHAR(10) | no | `COMPLETED` · `BLOCKED` (guard) · `FAILED` (model call or extraction) |
| `reasonCode` | VARCHAR(64) | yes | Why it didn't complete; NULL exactly when COMPLETED |
| `failureMode` | VARCHAR(14) | yes | For an extraction failure: `FORMAT` · `ROUTING` · `AMBIGUITY` · `COMPREHENSION` |
| `createdUtc` | DATETIME2 | no | When written |

### `AI.fieldOutcome`

| Column | Type | Null | Meaning |
|---|---|---|---|
| `outcomeID` | BIGINT identity | no | The outcome's identity |
| `runID` | BIGINT | no | The turn |
| `encounterID` | INT | no | Copied from the run, for the review queue |
| `templetID` · `sectionID` · `fieldID` | INT | no | The field, at mapping grain (live spelling) |
| `proposedValue` | NVARCHAR(400) | yes | What the model extracted; set only when FOUND. **PHI** |
| `proposedUnit` | NVARCHAR(50) | yes | Its unit, as written — never converted |
| `proposedStatus` | VARCHAR(10) | no | `FOUND` · `ABSENT` (nothing there) · `ABSTAINED` (model wouldn't commit) |
| `proposedConfidence` | VARCHAR(6) | no | The model's band: `HIGH` · `MEDIUM` · `LOW` |
| `priorValue` | NVARCHAR(400) | yes | The field's value before this turn. **PHI** |
| `priorUnit` | NVARCHAR(50) | yes | Its unit |
| `priorSource` | VARCHAR(10) | yes | `AI` or `CLINICIAN` |
| `priorProtection` | VARCHAR(8) | yes | `LOCKED` · `HIGH` · `LOW` — the weightage |
| `priorOutcomeID` | BIGINT | yes | The earlier outcome that set it. Logical reference, no FK, because retention may remove it |
| `mergeAction` | VARCHAR(10) | no | The engine's decision, §5 |
| `verdict` | VARCHAR(10) | no | Validators' verdict on the value: `ACCEPT` · `REVIEW` · `BLOCK` |
| `reasonCode` | NVARCHAR(50) | yes | Why a validator returned REVIEW or BLOCK |
| `acceptedValue` / `acceptedUnit` | NVARCHAR | yes | What the clinician accepted. **PHI** |
| `acceptedStatus` | VARCHAR(10) | yes | The status confirmed; ABSENT locks the field empty |
| `decidedByProviderID` | INT | yes | Who decided; NULL for a system auto-commit |
| `decidedAtUtc` | DATETIME2 | yes | When; NULL while awaiting a decision |
| `createdUtc` | DATETIME2 | no | When written |

### `AI.fieldEvidence`

| Column | Type | Null | Meaning |
|---|---|---|---|
| `evidenceID` | BIGINT identity | no | The passage's identity |
| `outcomeID` | BIGINT | no | The proposal it supports; deleted with it |
| `transcriptID` | BIGINT | no | Which transcript — this turn's or an earlier one |
| `quote` | NVARCHAR(1000) | no | The passage as the model quoted it, unmasked. **PHI** |
| `startOffset` / `endOffset` | INT | yes | Where the engine found it: 0-based UTF-16 code units, end-exclusive. NULL when not found |
| `matchStatus` | VARCHAR(10) | no | `EXACT` · `NORMALIZED` (after whitespace/case folding) · `NOT_FOUND` (likely invented) |
| `createdUtc` | DATETIME2 | no | When written |

To read a passage in T-SQL: `SUBSTRING(transcriptText, startOffset + 1, endOffset - startOffset)`.

### `AI.fieldState`

| Column | Type | Null | Meaning |
|---|---|---|---|
| `sessionID` · `sectionID` · `fieldID` | BIGINT · INT · INT | no | The field, within the session's template. Primary key |
| `currentValue` | NVARCHAR(400) | yes | The current value. NULL only when a clinician locked it empty. **PHI** |
| `currentUnit` | NVARCHAR(50) | yes | Its unit |
| `source` | VARCHAR(10) | no | `AI` or `CLINICIAN` |
| `protection` | VARCHAR(8) | no | `LOCKED` · `HIGH` · `LOW`, §4 |
| `setByOutcomeID` | BIGINT | yes | The outcome that set or was accepted into it; NULL after retention |
| `setByUserID` | INT | yes | The clinician who set it; NULL when the source is AI |
| `updatedUtc` | DATETIME2 | no | When the value or protection last changed |

All timestamps default to `getutcdate()`. Its DATETIME precision (~3 ms) is harmless here, because
ordering within a session always uses `turnNumber`, never a timestamp.

---

## 12. Verifying on a real database

**Done:**

- `npm test` → **173 pass** (167 before; 6 added)
- typecheck clean
- the migration scope check passes against all ten scripts

**Not done:** none of this has been applied to SQL Server. `.env.local` here sets no
`AZURE_SQL_SERVER`, so the 43 integration tests skip. Those include the new ones asserting
`CK_fieldOutcome_protectedNeverOverwritten`, `CK_fieldOutcome_priorState`, `UQ_agentRun_sessionTurn`
and `UQ_agentRun_requestID`. Against a development database:

```bash
# .env.local: AZURE_SQL_SERVER, AZURE_SQL_DATABASE (+ AZURE_SQL_USER / PASSWORD locally)
npm run migrate            # first apply
npm run migrate            # second run must be a no-op
npm run test:integration   # 53 tests, none skipped
```

Then run `migrations/verification/post-apply-checks.sql`.
