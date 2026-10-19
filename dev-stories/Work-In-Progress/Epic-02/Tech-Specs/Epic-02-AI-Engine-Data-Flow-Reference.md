# Epic 02 — AI Engine Data Flow Reference

**Scope:** the AI engine (`pacEHR_AI`) and the `AI.*` tables it owns, plus the existing PacEHR
tables it reads. Nothing about the legacy C# "AI Command" path, which coexists and writes none of
these tables.
**Date:** 2026-10-06, amended 2026-10-07
**Tables as of:** branch `3p-dev/PEA-201-ai-schema-data-layer`, migrations `0001`–`0006`
(uncommitted, not yet applied to a SQL Server).

> **Amended 2026-10-07 — no session table, and no schema-creation script.**
> `0001_create_ai_schema.sql` is withdrawn: the AI schema already exists in every target database
> (it carries the pre-existing `AI.prompt` table), so the guarded `CREATE SCHEMA` was always a
> no-op where it would run. The set now starts at `0001_create_transcript.sql`. Nothing about the
> guard or the runner changed — `migrations/verification/post-apply-checks.sql` check 1 still
> confirms the schema is present before anything else runs.
>
> **No session table either.** `AI.extractionSession` is withdrawn: a conversation is
> grouped by the encounter itself (`Encounter.encounter`). What the session table did is now done by:
>
> | The session table gave | Now given by |
> |---|---|
> | grouping of turns, transcripts and field state | `encounterID` on `AI.transcript`, `AI.agentRun`, `AI.fieldState` |
> | the template snapshot | `templetID` on `AI.agentRun` and `AI.fieldState` |
> | where a conversation starts again (template change, start over) | the `parentRunID` chain: a turn with `parentRunID` NULL starts a new conversation |
> | one turn at a time per encounter | an application lock, `sp_getapplock` on `AI.encounter.<encounterID>`, held by step 6's transaction |
> | turn numbering | `UQ_agentRun_encounterTurn (encounterID, turnNumber)` |
> | `patientID`, `accountId` copies | read from `Encounter.encounter` when needed; not stored in `AI.*` |
>
> **Two columns dropped from `AI.transcript`.** `textHash` and `submittedByUserID` are withdrawn
> (owner decision, 2026-10-07). Who posted the transcript is `AI.agentRun.requestedByUserID` on the
> turn it became -- recorded once there rather than twice. The duplicate-post check in S14 compares
> `transcriptText` directly instead of a hash of it; `IX_transcript_encounter` still finds the row to
> compare against.

**Companion:** [Epic-02-Multi-Turn-Extraction-Design.md](Epic-02-Multi-Turn-Extraction-Design.md)
explains *why* the tables look the way they do; this document says *which table is touched, when,
and with what*.

---

## 0. How to use this document when the flow changes

Every scenario in §4 has an id (`S1`, `S2`, …) and ends with an **"If this changes"** line. Each
behaviour has a single place in the database that enforces it, and §6 indexes those places.

1. **Find the scenario** the change affects (§4, or the matrix in §5).
2. **Read its "Tables" block.** It lists every table and column the scenario reads or writes.
3. **Look the change up in §6.** That gives the columns, CHECK constraints and indexes that encode
   today's behaviour, so you know exactly what has to move.
4. **Change the migration.**
   - **Before the branch is merged** (today): edit the numbered script in place.
   - **After it is merged:** never edit a merged script. Write the next numbered script
     (`0009_…`), with `IF NOT EXISTS` / `IF EXISTS` guards like the others.
5. **Update this document and the data dictionary** (§11 of the design doc) in the same change, so
   the next person can point at it.

Each step in this document is marked with its build state:
**✅ built** = code exists and has unit tests · **📐 designed** = the table supports it but no
code writes it yet · **⛔ blocked** = waits on another epic or a decision.

---

## 1. The tables at a glance

### 1.1 Tables the AI engine owns (`AI` schema, migrations `0001`–`0006`)

| # | Table | One row is… | Written in steps | Holds PHI | Lifetime |
|---|---|---|---|---|---|
| 0001 | `AI.transcript` | one text the clinician posted for an encounter | 2 | **yes** | text redacted at retention; row kept |
| 0002 | `AI.agentRun` | one turn: one attempt to extract, including blocked and failed ones; carries the turn's template | 6 | no | kept, append-only |
| 0003 | `AI.fieldOutcome` | one field in one turn: proposal, prior state, merge decision, clinician decision | 6, review | **yes** | retention purge |
| 0004 | `AI.fieldEvidence` | one transcript passage supporting one proposal | 6 | **yes** | deleted with its outcome (cascade) |
| 0005 | `AI.fieldState` | the current value and protection of one field of an encounter | 3, 6, review | **yes** | deleted when the conversation ends (template change, start over, signed) |
| 0006 | `AI.fieldConstraint` | numeric bounds for one field on one template | admin only | no | kept |

### 1.2 Existing PacEHR tables the engine reads (never writes)

| Table | What the engine takes from it | Used in |
|---|---|---|
| `Encounter.encounter` | the encounter's current `templeteId`, `accountID` and `encounterSignedDate`; `patientID` for reporting joins | step 1, prompt tier 1 |
| `AI.prompt` | the master prompt text and its `promptId`, read through `dbo.usp_getPrompt` | step 4 |
| `Template.encounterTempletes` | the template, and its `promptId` (prompt tier 1) | step 4 |
| `Template.templateSection` | which sections a template has, and their order | step 4 |
| `Template.section` | `sectionName`, and `prompt` (the section's instruction) | step 4 |
| `Template.fieldSection` | which fields a section has, and their order | step 4 |
| `Template.fields` | `fieldName`, and `prompt` (the field's instruction) | step 4 |

**The engine never writes outside the `AI` schema.** The migration guard
(`src/core/databaseMigrations.ts`) refuses any script that does. The value the clinician sees on
the chart is written by the .NET API and Angular form into `Encounter.encounterData`, never by
the engine.

### 1.3 How they relate

```
 Encounter.encounter ─ read ─┐        AI.prompt ─ read via usp_getPrompt ─┐
   (encounterID: the logical  ▼                                            │
    key of every AI table. No FK by policy, not by SQL Server limitation:  │
    Encounter is modelled by pacEHR_API's separate SSDT project)           │
   │                                                                      │
   ├──< AI.transcript           every text posted, immutable              │
   │        ▲   ▲                                                         │
   ├──< AI.agentRun ── transcriptID ┘   │  promptId / promptTemplateHash ◀─┘
   │        │  └─ parentRunID → AI.agentRun (last COMPLETED turn, same template;
   │        │                     NULL = a new conversation starts here)
   │        └──< AI.fieldOutcome      one per field per COMPLETED turn
   │                  └──< AI.fieldEvidence ── transcriptID ──> AI.transcript
   │
   └──< AI.fieldState           current value + protection, per field (+ templetID)
             └─ setByOutcomeID ──> AI.fieldOutcome   (SET NULL if purged)

 Template.* ── read ──> sections, fields and their prompts (the field list of every turn)
 AI.fieldConstraint ── read ──> bounds the validators check proposals against
```

---

## 2. Vocabulary

Every column below is backed by a CHECK constraint, so these lists are the complete set.

| Column | Values | Meaning |
|---|---|---|
| `agentRun.outcome` | `COMPLETED` · `BLOCKED` · `FAILED` | model returned an extraction · a guard stopped it before the model · the model call or the extraction failed |
| `agentRun.failureMode` | `FORMAT` · `ROUTING` · `AMBIGUITY` · `COMPREHENSION` | only on `FAILED` runs whose extraction failed |
| `fieldOutcome.proposedStatus` | `FOUND` · `ABSENT` · `ABSTAINED` | a value was extracted · the transcript has none · the model would not commit |
| `fieldOutcome.proposedConfidence` | `HIGH` · `MEDIUM` · `LOW` | the model's own band, never a number |
| `fieldOutcome.verdict` | `ACCEPT` · `REVIEW` · `BLOCK` | the validators' judgement of the *value* (Epic 6) |
| `fieldOutcome.mergeAction` | `FILLED` · `CONFIRMED` · `UPDATED` · `CONFLICT` · `KEPT` · `EMPTY` · `REJECTED` | what the engine did with the *change* (§3.6) |
| `fieldState.source`, `fieldOutcome.priorSource` | `AI` · `CLINICIAN` | who set the value |
| `fieldState.protection`, `fieldOutcome.priorProtection` | `LOCKED` · `HIGH` · `LOW` | the "weightage" (§3.5) |
| `fieldEvidence.matchStatus` | `EXACT` · `NORMALIZED` · `NOT_FOUND` | how the engine located the model's quote in the transcript |

`agentRun.reasonCode` has **no** CHECK. Its values come from `REASON_CODES` in
`src/pacehr/agents/failure-modes.ts`, so a new reason code needs no migration.

---

## 3. The flow of one turn

A **turn** is one transcript posted into one encounter. Every turn walks steps 1–7. Blocked and
failed turns leave the path where marked.

```
 Clinician posts a transcript (via the .NET API)
   │
 1 ▸ Place the turn in its conversation  Encounter.encounter, AI.agentRun (read)  📐
 2 ▸ Store the transcript ............. AI.transcript                 📐
 3 ▸ Reconcile with the form .......... AI.fieldState                 📐
 4 ▸ Guards, template, prompt ......... Template.*, AI.prompt (read)  ✅ guards+prompt · ⛔ template (PEA-303)
       └─ a guard stops it ─────────────────────────────────────┐
 5 ▸ Model call ....................... (no table)              ✅  │
       └─ the call or the parse fails ─────────────────────────┐ │
 6 ▸ Merge and record (one transaction)                         ▼ ▼
       AI.agentRun ................................................. ✅ writer · 📐 not yet called
       AI.fieldOutcome, AI.fieldEvidence, AI.fieldState ........... ✅ outcome writer · 📐 merge, evidence, state
 7 ▸ Return to the form ............... (no table)                   📐
```

### 3.1 Step 1 — place the turn in its conversation

| | |
|---|---|
| **Reads** | `Encounter.encounter`: the current `templeteId`, and `encounterSignedDate` (a signed encounter is refused, S17). `AI.agentRun`: the encounter's latest `COMPLETED` run |
| **Decides** | the would-be parent. It is that latest COMPLETED run, **unless** its `templetID` differs from the encounter's template (S9), the request asks to start over (S16), or there is none (S1) — then there is no parent and a new conversation starts |
| **Context** | the conversation's transcripts: walk `parentRunID` back from the parent, taking each run's `transcriptID`, oldest first |
| **Writes** | nothing. The parent is decided again under the lock in step 6, in case another tab finished a turn meanwhile |

### 3.2 Step 2 — store the transcript

| | |
|---|---|
| **Writes** | `AI.transcript`: `transcriptText` exactly as posted. Who posted it lives on the turn's `AI.agentRun.requestedByUserID`, not here |
| **Why first** | evidence offsets point into this text, so it has to exist and never move. It is stored even if a guard later blocks the turn, because the audit row must say what was refused |
| **Enforced by** | `CK_transcript_redaction`: text present ⇔ not redacted |

### 3.3 Step 3 — reconcile with the form

| | |
|---|---|
| **Reads** | the field values currently on the form (the request carries them — design doc §10, decision 2), and `AI.fieldState` |
| **Writes** | `AI.fieldState`: a form value that differs from state becomes `source = 'CLINICIAN'`, `protection = 'LOCKED'`, `setByUserID` = the clinician, `setByOutcomeID = NULL` |
| **Why** | a value the clinician typed must be protected *before* the model runs, or a follow-up could overwrite it |
| **Enforced by** | `CK_fieldState_protection` (a clinician value is always LOCKED), `CK_fieldState_setBy` |

### 3.4 Step 4 — guards, template and prompt

| | |
|---|---|
| **Reads** | the template: `Template.encounterTempletes` → `templateSection` → `section` (`prompt`) → `fieldSection` → `fields` (`prompt`). The prompt: `EXEC dbo.usp_getPrompt @userId, @accountId, @encounterId` → `AI.prompt` |
| **Also reads (follow-ups)** | `AI.fieldState` (what is filled and how strongly), and the `AI.transcript` rows of the conversation's COMPLETED turns (the `parentRunID` chain), oldest first |
| **Writes** | nothing. The resolved `promptId`, `promptTemplateHash` (the hash of the `AI.prompt` text) and `promptHash` (the hash of the whole composed prompt) are carried to step 6 |
| **Prompt tiers** (`usp_getPrompt`) | 1. the template's `promptId` → 2. the account's `isUniversal = 1` row → 3. the `accountId = 0`, `isUniversal = 1` row |
| **Stops here** | injection found, payload too large, template unavailable, no prompt, more than one prompt, placeholder unfilled → **S10** |

### 3.5 Protection — the "weightage"

| Protection | Assigned when | May a later turn replace it? |
|---|---|---|
| `LOCKED` | the clinician typed it (step 3), or accepted, corrected or emptied it on review (S7) | **never** |
| `HIGH` | the model found it with `HIGH` confidence **and** at least one passage located `EXACT` or `NORMALIZED` | **never** |
| `LOW` | anything else the model found: `MEDIUM`/`LOW` confidence, or no locatable passage | yes |
| *(no row)* | nothing found yet | yes |

A `LOW` value that a later turn repeats with `HIGH` confidence and located evidence is
**promoted** to `HIGH`.

### 3.6 Step 6 — merge and record

The merge is deterministic code that runs on every field. The model only proposes.

| Prior state (`AI.fieldState`) | Proposal | `mergeAction` | `AI.fieldState` afterwards |
|---|---|---|---|
| none | `FOUND`, not blocked | `FILLED` | new row, `AI`, `HIGH` or `LOW` per §3.5 |
| none | `ABSENT` / `ABSTAINED` | `EMPTY` | still none |
| any | `FOUND`, verdict `BLOCK` | `REJECTED` | unchanged |
| any value | `ABSENT` / `ABSTAINED` | `KEPT` | unchanged |
| `AI · LOW` | `FOUND`, same value | `CONFIRMED` | promoted to `HIGH` if §3.5 is met |
| `AI · LOW` | `FOUND`, different | `UPDATED` | replaced, protection per §3.5 |
| `AI · HIGH` or `LOCKED` | `FOUND`, same value | `CONFIRMED` | unchanged |
| `AI · HIGH` or `LOCKED` | `FOUND`, different | `CONFLICT` | **unchanged**; the proposal waits for the clinician |

One transaction, in this order:

1. Take the encounter's lock: `EXEC sp_getapplock @Resource = N'AI.encounter.<encounterID>',
   @LockMode = 'Exclusive', @LockOwner = 'Transaction'`. Then re-read the latest COMPLETED run and
   `AI.fieldState`. Another tab may have finished a turn while this one was at the model.
2. If this turn starts a new conversation (S9, S16), delete the encounter's `AI.fieldState` rows.
   This happens only in a turn that COMPLETED, so a blocked or failed start-over resets nothing.
3. Insert `AI.agentRun`. `turnNumber` = the encounter's highest + 1; `templetID` = the encounter's
   template; `parentRunID` = the parent from step 1 (NULL for a new conversation);
   `priorTurnsIncluded` = the number of earlier transcripts actually sent.
4. Insert one `AI.fieldOutcome` per template field. The `prior*` columns are copied from
   `AI.fieldState` *as re-read*.
5. Insert `AI.fieldEvidence` rows: one per quote, located by the engine.
6. Apply `FILLED` / `UPDATED` / promotions to `AI.fieldState`. The update of an existing row runs
   `WHERE protection = 'LOW'`, so a stale read cannot overwrite a protected value.
7. Commit, which releases the lock.

A BLOCKED or FAILED turn writes only its `AI.agentRun` row, in its own short transaction under the
same lock (it needs the next `turnNumber` too).

### 3.7 Step 7 — return to the form

The response carries `FILLED`, `UPDATED` and promoted values for the form, plus `CONFLICT` and
`REJECTED` items for review. No table is written. The .NET API and Angular put the values on the
chart.

---

## 4. Scenarios

### The running example

All scenarios use one encounter, so the ids line up from scenario to scenario.

| Thing | Value |
|---|---|
| Encounter | `encounterID` 5414457, `patientID` 88123, account 1 |
| Template | `templetID` 7, "Follow-up Visit" |
| Clinician | `userId` 965, Entra OID `0b6c…e91` |
| Section | `sectionID` 2, "Vitals" |
| Fields | 88 **BP** · 89 **Heart rate** · 90 **Temperature** · 91 **Weight** |
| `AI.fieldConstraint` | Weight (7, 2, 91): `plausibleMin` 1, `plausibleMax` 300, unit `kg` |

---

### S1 — First transcript on an encounter

**When:** the clinician posts the first transcript for encounter 5414457.
**Transcript 9001:** `Follow-up visit. BP 120/80. Heart rate 72. Temp maybe 99.`

**What happens:** the encounter has no COMPLETED run, so this turn starts the conversation
(`parentRunID` NULL). The model sees only this transcript and no field state. Every field is
`FILLED` or `EMPTY`.

**Tables**

| Table | Op | Key columns written |
|---|---|---|
| `Encounter.encounter` | read | `templeteId` 7, `accountID` 1, not signed |
| `AI.agentRun` | read | no COMPLETED run for 5414457 → new conversation |
| `AI.transcript` | **insert** | `transcriptID` 9001, `encounterID` 5414457, `transcriptText` |
| `Template.*`, `AI.prompt` | read | 4 fields of section 2; `promptId` 12 |
| `AI.agentRun` | **insert** | `runID` 7001, `encounterID` 5414457, `templetID` 7, `turnNumber` 1, `parentRunID` NULL, `transcriptID` 9001, `priorTurnsIncluded` 0, `outcome` COMPLETED, `promptId` 12, `promptTemplateHash`, `promptHash`, `modelDeployment`, tokens, `latencyMs` |
| `AI.fieldOutcome` | **insert ×4** | below |
| `AI.fieldEvidence` | **insert ×3** | below |
| `AI.fieldState` | **insert ×3** | below |

**`AI.fieldOutcome`** (all `prior*` NULL, all `verdict` ACCEPT)

| outcomeID | field | proposed | status · confidence | mergeAction |
|---|---|---|---|---|
| 30001 | BP | 120/80 mmHg | FOUND · HIGH | FILLED |
| 30002 | Heart rate | 72 | FOUND · MEDIUM | FILLED |
| 30003 | Temperature | 99 | FOUND · LOW | FILLED |
| 30004 | Weight | — | ABSENT · HIGH | EMPTY |

**`AI.fieldEvidence`**

| evidenceID | outcomeID | transcriptID | quote | start–end | matchStatus |
|---|---|---|---|---|---|
| 40001 | 30001 | 9001 | `BP 120/80` | 17–26 | EXACT |
| 40002 | 30002 | 9001 | `Heart rate 72` | 28–41 | EXACT |
| 40003 | 30003 | 9001 | `Temp maybe 99` | 43–56 | EXACT |

**`AI.fieldState`** after the turn

| field | currentValue | source | protection | setByOutcomeID | why |
|---|---|---|---|---|---|
| BP | 120/80 mmHg | AI | **HIGH** | 30001 | HIGH confidence + EXACT evidence |
| Heart rate | 72 | AI | LOW | 30002 | MEDIUM confidence |
| Temperature | 99 | AI | LOW | 30003 | LOW confidence |
| Weight | *(no row)* | | | | EMPTY creates no row |

**Constraints relied on:** `CK_agentRun_turn` (turn 1 has no parent, `priorTurnsIncluded` 0) ·
`CK_agentRun_reachedModel` (a COMPLETED run has `promptHash` and `modelDeployment`) ·
`CK_fieldOutcome_protectedNeverOverwritten` (FILLED only with no prior) ·
`CK_fieldEvidence_offsets`.

**If this changes:**
- Needing the patient inside `AI.*` (for example, reporting without access to `Encounter`) → add
  `patientID` to `AI.agentRun`.
- Letting `EMPTY` create a state row → `CK_fieldState_setBy` (an AI row must have a value).

---

### S2 — Follow-up transcript

**When:** the clinician posts a second transcript into the same encounter.
**Before it:** the clinician changed Heart rate on the form from 72 to **74** (step 3 handles that,
see S6).
**Transcript 9002:** `Weight 82 kg. Repeat BP 140/90. Temp 98.6 F.`

**What happens:** the latest COMPLETED run is 7001, on the same template, so it is the parent.
The model is told this is turn 2. It is given
the filled fields with their protection, and transcript 9001 as earlier context. Each field is
merged against the state per §3.6.

**Tables**

| Table | Op | Key columns written |
|---|---|---|
| `Encounter.encounter` | read | `templeteId` 7, same as run 7001's |
| `AI.transcript` | **insert**, then read | insert 9002; read 9001 as context |
| `AI.fieldState` | read, **update** (step 3), read again in the transaction, **insert/update** | see S6 and below |
| `AI.agentRun` | **insert**, then read | read 7001 (the parent); insert `runID` 7002, `templetID` 7, `turnNumber` 2, `parentRunID` 7001, `transcriptID` 9002, `priorTurnsIncluded` 1, COMPLETED |
| `AI.fieldOutcome` | **insert ×4** | below |
| `AI.fieldEvidence` | **insert ×3** | 40004 `Repeat BP 140/90` 14–30 · 40005 `Temp 98.6 F` 32–43 · 40006 `Weight 82 kg` 0–12, all transcript 9002, EXACT |

**`AI.fieldOutcome`**

| outcomeID | field | proposed | prior (value · source · protection · outcome) | mergeAction |
|---|---|---|---|---|
| 30005 | BP | 140/90 mmHg · FOUND · HIGH | 120/80 · AI · HIGH · 30001 | **CONFLICT** |
| 30006 | Heart rate | — · ABSENT | 74 · CLINICIAN · LOCKED · NULL | **KEPT** |
| 30007 | Temperature | 98.6 F · FOUND · HIGH | 99 · AI · LOW · 30003 | **UPDATED** |
| 30008 | Weight | 82 kg · FOUND · HIGH | — | **FILLED** |

**`AI.fieldState`** after the turn

| field | currentValue | source · protection | setByOutcomeID | changed? |
|---|---|---|---|---|
| BP | **120/80 mmHg** | AI · HIGH | 30001 | no. The protected value stays; 140/90 waits for review |
| Heart rate | 74 | CLINICIAN · LOCKED | NULL | no |
| Temperature | 98.6 F | AI · **HIGH** | 30007 | yes: LOW replaced; HIGH because HIGH confidence + EXACT |
| Weight | 82 kg | AI · HIGH | 30008 | yes: new row |

**What the clinician sees:** Temperature and Weight filled, and one item to rule on: *"BP: you
have 120/80; the latest transcript says 140/90."*

**Constraints relied on:** `CK_agentRun_turn` (`priorTurnsIncluded` 1 < `turnNumber` 2) ·
`UQ_agentRun_encounterTurn` · `CK_fieldOutcome_mergeMatchesState` (a CONFLICT needs a HIGH/LOCKED
prior; a KEPT row cannot carry a FOUND proposal) · `CK_fieldOutcome_protectedNeverOverwritten`
(UPDATED only over LOW).

**If this changes:**
- How many earlier transcripts are sent → engine setting only; it is recorded in
  `priorTurnsIncluded`.
- Asking the model only about empty and LOW fields → KEPT and CONFIRMED rows mostly disappear.
  No DDL change, but the review queue loses corrections (they never become CONFLICT).
- Building on the *previous* turn rather than the last *completed* one → the meaning of
  `parentRunID` changes, and S9, S10, S11 and S16 have to be rewritten — the chain is what defines
  the conversation now that there is no session table.

---

### S3 — The follow-up contradicts a protected value (CONFLICT)

This is the "do not alter what is already filled" rule. It appears in S2 as outcome 30005; this
section isolates it.

| | |
|---|---|
| **When** | a field is `HIGH` or `LOCKED`, and the new proposal is `FOUND` with a different value |
| **`AI.fieldOutcome`** | `mergeAction` CONFLICT; `prior*` holds the protected value; `proposed*` holds the new one; `decidedAtUtc` NULL |
| **`AI.fieldState`** | **not touched**. The engine's update runs `WHERE protection = 'LOW'` and matches 0 rows |
| **Review queue** | the row appears (`IX_fieldOutcome_pending` includes CONFLICT) |
| **Resolved by** | S7, the clinician's decision |
| **Enforced by** | code (§3.6) **and** the database: `CK_fieldOutcome_protectedNeverOverwritten` refuses an `UPDATED` or `FILLED` row over a HIGH/LOCKED prior, so the overwrite cannot even be recorded |

**If this changes:**
- "Discard contradicting proposals instead of queuing them" → write `KEPT` instead of `CONFLICT`.
  `CK_fieldOutcome_mergeMatchesState` forbids a `KEPT` row with a `FOUND` proposal, so that
  constraint changes too.
- "Let HIGH (not LOCKED) values be overwritten" → `CK_fieldOutcome_protectedNeverOverwritten`
  (`UPDATED` would allow `priorProtection IN ('LOW','HIGH')`) and `CK_fieldOutcome_mergeMatchesState`
  (CONFLICT would be LOCKED-only).

---

### S4 — A LOW value is confirmed and promoted

**Variant of turn 2:** `Patient resting. BP unchanged from earlier. Pulse 72, steady.`
Heart rate is still `AI · LOW · 72` (no clinician edit in this variant).

| field | proposal | evidence | prior | mergeAction | state after |
|---|---|---|---|---|---|
| Heart rate | 72 · FOUND · HIGH | `Pulse 72`, transcript 9002, 44–52, EXACT | 72 · AI · LOW | **CONFIRMED** | 72 · AI · **HIGH**, `setByOutcomeID` → the new outcome |
| BP | 120/80 · FOUND · HIGH | `BP 120/80`, **transcript 9001**, 17–26, EXACT (see S12) | 120/80 · AI · HIGH | CONFIRMED | unchanged |

**Tables:** as in S2. `AI.fieldState` gets an update for Heart rate only: protection LOW → HIGH.

**If this changes:**
- "Two mentions are not stronger than one" → drop the promotion rule; code only.
- Adding a middle band (`MEDIUM`) → `CK_fieldState_protection`, `CK_fieldOutcome_priorState`,
  `CK_fieldOutcome_protectedNeverOverwritten`, `CK_fieldOutcome_mergeMatchesState`, and the width
  of `protection` / `priorProtection` (`VARCHAR(8)`).

---

### S5 — The follow-up does not mention a filled field (KEPT)

| | |
|---|---|
| **When** | prior value exists; the proposal is `ABSENT` or `ABSTAINED` (Heart rate in S2, outcome 30006) |
| **`AI.fieldOutcome`** | `mergeAction` KEPT, `proposedValue` NULL, `prior*` copied |
| **`AI.fieldState`** | unchanged. A follow-up never erases a value |
| **Review queue** | not included: nothing changed |
| **Retention** | never decided, so today's purge never deletes it (see §8, D4) |

**If this changes:** "a follow-up saying 'no fever' should clear Temperature" → that is a
`FOUND` proposal of a negative value, not `ABSENT`. If clearing is ever wanted, it needs a new
`mergeAction` (`CLEARED`) in `CK_fieldOutcome_mergeAction` and `CK_fieldOutcome_mergeMatchesState`,
and an AI row with no value, which `CK_fieldState_setBy` forbids today.

---

### S6 — The clinician edits the form between turns

**When:** after turn 1, the clinician types Heart rate **74** over the AI's 72. Then turn 2 arrives.

| Step | Table | Op | Values |
|---|---|---|---|
| 3 | `AI.fieldState` (5414457, 2, 89) | **update** | `currentValue` 72 → 74, `source` AI → CLINICIAN, `protection` LOW → LOCKED, `setByUserID` 965, `setByOutcomeID` 30002 → NULL |
| 6 | `AI.fieldOutcome` 30006 | insert | `priorValue` 74, `priorSource` CLINICIAN, `priorProtection` LOCKED |

A field the AI had not filled but the clinician typed gets a new `AI.fieldState` row with source
CLINICIAN, protection LOCKED, and the encounter's current `templetID`.

**Depends on:** the request carrying the current form values (design doc §10, decision 2).
`ExtractionContext` (`src/pacehr/agents/state.ts`) has no field for them today.

**If this changes:**
- Reading values from `Encounter.encounterData` instead of the request → no DDL change, but up to
  10 s of autosave lag, inside which an edit is missed.
- A clinician *deleting* an AI value → undecided (design doc §10, decision 3). If it becomes "lock
  the field empty", the row is CLINICIAN · LOCKED with `currentValue` NULL, which is already
  allowed.

---

### S7 — The clinician reviews a proposal

**When:** the clinician acts on an item in the review queue. The engine writes the decision once.
The model is not involved.

| Decision | `AI.fieldOutcome` (the reviewed row) | `AI.fieldState` |
|---|---|---|
| **Accept** the proposal (BP CONFLICT 30005 → take 140/90) | `acceptedValue` 140/90, `acceptedUnit` mmHg, `acceptedStatus` FOUND, `decidedByProviderID` 965, `decidedAtUtc` now | BP → 140/90 · CLINICIAN · **LOCKED**, `setByOutcomeID` 30005, `setByUserID` 965 |
| **Keep** the existing value (reject the CONFLICT) | `acceptedValue` = `priorValue` (120/80), decided | BP → 120/80 · CLINICIAN · LOCKED |
| **Correct** it (Weight 30008 → 81.5 kg) | `acceptedValue` 81.5 | Weight → 81.5 · CLINICIAN · LOCKED |
| **No value** (Temperature 30007 → "not taken") | `acceptedStatus` ABSENT, `acceptedValue` NULL | Temperature → NULL · CLINICIAN · LOCKED. Locked empty, so no later turn refills it |
| **Auto-accept** (PEA-902, ⛔ not built) | decided with `decidedByProviderID` NULL | unchanged (already applied) |

**Statement:** `SET_FIELD_OUTCOME_DECISION_SQL` in `src/repositories/fieldOutcomeRepository.ts`
✅. It runs `… WHERE outcomeID = @outcomeID AND decidedAtUtc IS NULL`, so a decision is written
once and a second click changes nothing. The `AI.fieldState` update is 📐: the review path is a
clinician write, so it may overwrite any protection, unlike the engine's `WHERE protection = 'LOW'`.

**If this changes:**
- Letting a decision be revised → drop `AND decidedAtUtc IS NULL` and add a decision-history table.
  `fieldOutcome` keeps only one decision.
- "Accepting an AI value should keep it HIGH, not LOCKED" → `CK_fieldState_protection` ties
  CLINICIAN to LOCKED; the source would have to stay AI.

---

### S8 — A validator blocks a value (REJECTED) ⛔ Epic 6

**Turn 2 variant:** the model reads `Weight 820 kg` (a dictation slip).

| Table | Op | Values |
|---|---|---|
| `AI.fieldConstraint` | read | (7, 2, 91): plausible 1–300 kg |
| `AI.fieldOutcome` | insert | `proposedValue` 820, `verdict` **BLOCK**, `reasonCode` e.g. `OUT_OF_PLAUSIBLE_RANGE` (illustrative; Epic 6 names the codes), `mergeAction` **REJECTED** |
| `AI.fieldEvidence` | insert | `Weight 820 kg`, EXACT |
| `AI.fieldState` | — | unchanged (Weight stays absent) |

**`verdict` REVIEW** (inside the plausible range but outside the abnormal range) does not block.
The value is applied as FILLED or UPDATED, and the row is in the review queue with its reason.

**Enforced by:** `CK_fieldOutcome_rejectedIsBlocked`: REJECTED ⇔ BLOCK.

**Gap:** `verdict` is `NOT NULL`, and nothing produces it until Epic 6 exists (delivery plan D9).
The writer needs an interim rule. "ACCEPT unless blocked" is the obvious one, but it is a
decision, not a default.

**If this changes:** a blocked value applied anyway with a flag → `CK_fieldOutcome_rejectedIsBlocked`.

---

### S9 — The template changes mid-encounter

**When:** the encounter's template changes from 7 to 12 after turns 1 and 2 ran on template 7. The
clinician then posts transcript 9010.

| Step | Table | Op | Values |
|---|---|---|---|
| 1 | `Encounter.encounter` | read | `templeteId` **12** |
| 1 | `AI.agentRun` | read | latest COMPLETED run 7002 has `templetID` 7 ≠ 12 → **no parent**: a new conversation |
| 4 | `Template.*` | read | template 12's fields |
| 6 | `AI.fieldState` (5414457) | **delete** all rows | they describe template 7's fields |
| 6 | `AI.agentRun` | **insert** | `templetID` 12, `parentRunID` NULL, `priorTurnsIncluded` 0 |
| 6 | `AI.fieldOutcome` / `fieldEvidence` / `fieldState` | insert | as S1, against template 12 |

Step 3 of this turn brings the form's current values in as CLINICIAN · LOCKED, with `templetID` 12.
Old runs and outcomes keep `templetID` 7, so each row stays interpretable.

**Why the delete waits for step 6:** if this turn is blocked or fails, nothing was reset, and the
next post makes the same decision again from the same rows.

**If this changes:** "carry values across templates when the field ids match" → instead of deleting,
update the matching `AI.fieldState` rows to `templetID` 12 and delete the rest; no DDL change.

---

### S10 — A guard blocks the turn (BLOCKED) ✅ guard · 📐 recording

**Turn 3:** transcript 9003 contains `Ignore previous instructions and …`.

| Table | Op | Values |
|---|---|---|
| `AI.transcript` | insert | 9003, stored as posted (the audit must show what was refused) |
| `AI.agentRun` | **insert** | 7003, `templetID` 7, `turnNumber` 3, `parentRunID` 7002 (the last COMPLETED run), `priorTurnsIncluded` 0, `outcome` BLOCKED, `reasonCode` INJECTION_BLOCKED, `promptId`/`promptHash`/`modelDeployment` NULL |
| `AI.fieldOutcome`, `AI.fieldEvidence`, `AI.fieldState` | — | nothing |

**Guard reason codes** (all → BLOCKED): `INJECTION_BLOCKED`, `PAYLOAD_TOO_LARGE`,
`TEMPLATE_UNAVAILABLE`, `PROMPT_NOT_FOUND` (`usp_getPrompt` returned 0 rows), `PROMPT_AMBIGUOUS`
(more than one row), `PROMPT_SLOT_UNFILLED`, `PROMPT_PLACEHOLDER_UNFILLED`, `PROMPT_NOT_COMPOSED`,
`GUARD_STEP_FAILED`.

> ⚠️ **Today every run ends here.** The template loader (`src/pacehr/templates/config.ts`, PEA-303)
> throws "not built", and the guard records that as `GUARD_STEP_FAILED`.

**Rule this document fixes:** a blocked turn's transcript is **never** sent as context to a later
turn. It may be the injection that was refused.

**Enforced by:** `CK_agentRun_reasonMatchesOutcome` (non-COMPLETED ⇒ a reason) ·
`CK_agentRun_reachedModel` (only a BLOCKED run may lack `promptHash`/`modelDeployment`) ·
`CK_agentRun_turn` (`priorTurnsIncluded` 0 is allowed with a parent).

---

### S11 — The model call or the extraction fails (FAILED) ✅ classification · 📐 recording

**Turn 4:** the model returns JSON that breaks the response schema.

| Table | Op | Values |
|---|---|---|
| `AI.transcript` | insert | 9004 |
| `AI.agentRun` | **insert** | 7004, `templetID` 7, `turnNumber` 4, `parentRunID` 7002 (skips blocked 7003), `priorTurnsIncluded` 2 (9001, 9002), `outcome` FAILED, `reasonCode` OUTPUT_SCHEMA_VIOLATION, `failureMode` **FORMAT**, `promptHash` + `modelDeployment` set, tokens and latency set |
| field tables | — | nothing |

**Model-call codes** (FAILED, no `failureMode`): `MODEL_CONTENT_FILTERED`,
`PROMPT_CONTENT_FILTERED`, `MODEL_CALL_FAILED`. **Extraction codes** (FAILED, `failureMode`
FORMAT): `OUTPUT_SCHEMA_VIOLATION`, `OUTPUT_MISSING`.

**Retry:** the clinician posts again → turn 5, new `requestID`, new transcript 9005 with the same
text as 9004, `parentRunID` 7002. A failed turn's transcript is not sent as context, because its
content was never extracted and the retry carries it again.

**Enforced by:** `CK_agentRun_failureMode` (only FAILED, only the four modes) ·
`CK_agentRun_reachedModel`.

**If this changes:** a new failure mode → `CK_agentRun_failureMode` and `FAILURE_MODES` in
`failure-modes.ts`. A new outcome → `CK_agentRun_outcome`, `CK_agentRun_reachedModel`,
`CK_agentRun_reasonMatchesOutcome`, and the `outcome` width (`VARCHAR(10)`).

---

### S12 — Evidence points at an earlier transcript

In S4, BP is supported by a passage from turn 1 ("BP unchanged from earlier"). The model returns
`{"quote": "BP 120/80", "turn": 1}`. The engine maps turn 1 → transcript 9001 and locates the quote
there.

| `AI.fieldEvidence` | `outcomeID` = the turn-2 BP outcome · `transcriptID` **9001** · `quote` `BP 120/80` · 17–26 · EXACT |
|---|---|

**Why each evidence row names its own transcript:** a follow-up's proposal can rest on any earlier
text in the conversation. `FK_fieldEvidence_transcript` keeps that pointer valid.

**If this changes:** limiting evidence to the current transcript → no DDL change, but the
`transcriptID` column becomes redundant with `agentRun.transcriptID`.

---

### S13 — The model's quote is not in the transcript

The model returns `FOUND 72 · HIGH` with the quote `HR 72 bpm`, which appears nowhere.

| Table | Values |
|---|---|
| `AI.fieldEvidence` | `quote` `HR 72 bpm`, `startOffset`/`endOffset` NULL, `matchStatus` **NOT_FOUND** |
| `AI.fieldState` | protection **LOW** despite HIGH confidence. An unlocatable quote is the strongest sign of an invented value |

**Enforced by:** `CK_fieldEvidence_offsets` (NOT_FOUND ⇔ no offsets).

**If this changes:** fuzzy matching → a new `matchStatus` (`FUZZY`) in
`CK_fieldEvidence_matchStatus` (width `VARCHAR(10)`), plus a decision whether it counts towards
HIGH.

---

### S14 — The same request arrives twice

**When:** a double-click or a network retry sends the same `runId` (`requestID`) twice.

| | |
|---|---|
| **Caught by** | `UQ_agentRun_requestID`. The second `AI.agentRun` insert fails, and the engine returns the first run's result |
| **Gap** | the duplicate is only detected at step 6. By then the second request has stored its own `AI.transcript` row (step 2), which no run points to, and has paid for a model call. Fix before building: check for an existing `requestID` (and an in-flight one) at step 1, or skip the transcript insert when the encounter's latest transcript has identical `transcriptText` within a few seconds -- found through `IX_transcript_encounter`; the comparison is now a full-text match, there being no hash to compare instead (owner decision, 2026-10-07) |
| **Gap** | `requestID` is `VARCHAR(64)`, but `ExtractionContext.runId` has no maximum length. Add `.max(64)` |

---

### S15 — Two tabs post at the same time

| Race | Caught by | Loser does |
|---|---|---|
| Both claim the next turn | `sp_getapplock` on `AI.encounter.<encounterID>` in step 6, with `UQ_agentRun_encounterTurn` as the backstop | waits for the lock, takes the next number, re-reads the parent, and merges against the state the winner left |
| Both change one field | step 6 re-reads `AI.fieldState` under the lock | merges against the winner's value. If the winner made it HIGH, the loser's differing value becomes a CONFLICT |

No lock is held during the model call (step 5). The lock is an application lock: it locks a name,
not a row, so it needs no table and blocks nothing outside the AI engine.

---

### S16 — The clinician starts the extraction over

**When:** the clinician asks to re-extract from scratch. The request carries a start-over flag
(📐 not yet in `ExtractionContext`, §8 D8).

| Step | Table | Op |
|---|---|---|
| 1 | — | no parent, whatever the latest COMPLETED run is |
| 6 | `AI.fieldState` (5414457) | delete all rows — only if this turn COMPLETES |
| 6 | `AI.agentRun` | insert with `parentRunID` NULL, `priorTurnsIncluded` 0 |

Because later turns take the latest COMPLETED run as their parent, the conversation continues from
this turn. If the start-over turn is blocked or fails, nothing was reset, and the next post (with
the flag again) starts over.

⚠️ **Consequence:** step 3 of the start-over turn treats every value still on the form as
a clinician value (LOCKED), *including values the AI put there earlier*. If "start over" means
re-extracting those fields, the form must clear the AI's values first.

---

### S17 — The encounter is signed

| Table | Op |
|---|---|
| `AI.fieldState` (5414457) | delete all rows. `AI.fieldOutcome` already holds everything they said |
| later posts | refused at step 1: `Encounter.encounter.encounterSignedDate` is set |

**Gap:** what triggers the delete? A call from the .NET sign path, or a sweep for signed encounters
that still have `AI.fieldState` rows. Undecided (§8 D12).

---

### S18 — Retention purge ✅ fieldOutcome · 📐 transcript

| Table | What happens | Mechanism |
|---|---|---|
| `AI.fieldOutcome` | rows with `createdUtc` older than the window **and** `decidedAtUtc IS NOT NULL` are deleted, 4,000 per batch | `fieldOutcomeRetention.ts` → `DELETE_FIELD_OUTCOME_BEFORE_SQL` ✅. No window set ⇒ deletes nothing |
| `AI.fieldEvidence` | goes with its outcome | `ON DELETE CASCADE` ✅ |
| `AI.fieldState.setByOutcomeID` | set to NULL if its outcome is deleted | `ON DELETE SET NULL` ✅ |
| `AI.fieldOutcome.priorOutcomeID` | may dangle | deliberately no foreign key |
| `AI.transcript` | `transcriptText` → NULL, `redactedUtc` stamped; row kept | 📐 not built |
| `AI.agentRun` | kept | no PHI |

**Gap:** `KEPT`, `CONFIRMED` and `EMPTY` rows are never decided, and neither is a proposal later
overtaken by another turn. Under the 2026-10-06 rule ("purge decided rows only"), none of them is
ever purged (§8, D4).

**If this changes:** a new predicate → `DELETE_FIELD_OUTCOME_BEFORE_SQL`. Deleting transcripts
instead of redacting them → `FK_agentRun_transcript` and `FK_fieldEvidence_transcript` would block
it, so both foreign keys change, along with `CK_transcript_redaction`.

---

### S19 — Prompt and template resolution ✅ prompt · ⛔ template

| Tier | Source | Chosen when |
|---|---|---|
| 1 | `Template.encounterTempletes.promptId` → `AI.prompt` | the encounter's template has a `promptId` > 0 |
| 2 | `AI.prompt` with `accountId` = the account, `isUniversal = 1` | no template prompt |
| 3 | `AI.prompt` with `accountId = 0`, `isUniversal = 1` | neither of the above |

The field list and instructions come from `Template.templateSection` / `Template.section.prompt` /
`Template.fieldSection` / `Template.fields.prompt`. They are filled into the `AI.prompt` text's
`<<placeholders>>` by `src/pacehr/agents/prompt.ts` ✅.

**Written:** `agentRun.promptId`, `promptTemplateHash` (SHA-256 of the `AI.prompt` text) and
`promptHash` (SHA-256 of the full composed prompt). `AI.prompt` rows are edited in place, so the
hash is the only proof of which wording a run used.

**Known defects in `usp_getPrompt`** (pacEHR_API, not changed here): it does not filter
`isDeleted = 0`; it has no `TOP 1` (so two universal rows → `PROMPT_AMBIGUOUS`); its "Priority 2"
comment says non-universal but the query filters `isUniversal = 1`.

**If this changes:** prompt versioning in `AI.prompt` → `agentRun.promptId` could point at a
version; the hashes stay.

---

## 5. Scenario × table matrix

`I` insert · `U` update · `D` delete · `R` read · `—` not touched. 📐 = designed, not built.

| Scenario | transcript | agentRun | fieldOutcome | fieldEvidence | fieldState | fieldConstraint | Template.* / AI.prompt | Encounter |
|---|---|---|---|---|---|---|---|---|
| S1 first transcript | **I** | **I** R | **I** | **I** | **I** | R | R | R |
| S2 follow-up | **I** R | **I** R | **I** | **I** | R **U I** | R | R | R |
| S3 conflict | — | — | **I** | **I** | R (no write) | — | — | — |
| S4 confirm/promote | — | — | **I** | **I** | **U** | — | — | — |
| S5 kept | — | — | **I** | — | R | — | — | — |
| S6 form edit | — | — | (prior) | — | **U I** | — | — | — |
| S7 review | — | — | **U** | — | **U I** | — | — | — |
| S8 rejected | — | — | **I** | **I** | — | R | — | — |
| S9 template change | **I** | **I** R | **I** | **I** | **D I** | R | R | R |
| S10 blocked | **I** | **I** R | — | — | — | — | R | R |
| S11 failed | **I** | **I** R | — | — | — | — | R | R |
| S12 earlier evidence | R | — | — | **I** | — | — | — | — |
| S13 quote not found | R | — | — | **I** | **I/U** (LOW) | — | — | — |
| S14 duplicate | **I** (orphan) | ✗ refused | — | — | — | — | — | — |
| S15 two tabs | **I** | **I** R | **I** | **I** | R **U** | — | — | — |
| S16 start over | **I** | **I** R | **I** | **I** | **D I** | — | R | R |
| S17 signed | — | — | — | — | **D** | — | — | R |
| S18 purge | **U** 📐 | — | **D** | **D** (cascade) | **U** (SET NULL) | — | — | — |

---

## 6. Change-impact index

Look up the behaviour you want to change. The right-hand column is everything that encodes it today.

| If you change… | Columns | Constraints / indexes | Code |
|---|---|---|---|
| What one conversation is (the grouping) | `agentRun.encounterID`, `parentRunID`, `templetID` | `FK_agentRun_parentRun`, `UQ_agentRun_encounterTurn` | step 1 (parent rule), S9, S16 |
| Needing a lifecycle state again (closed, abandoned) | today none: derived from the chain and `Encounter.encounter` | — | a new table, or a status column on a new table — the withdrawn `extractionSession` design is in git history |
| Template fixed per turn | `agentRun.templetID`, `fieldState.templetID`, `fieldOutcome.templetID` | — | S9 |
| One turn at a time per encounter | — | `UQ_agentRun_encounterTurn` (backstop) | `sp_getapplock` in step 6 |
| Transcript immutability / retention | `transcript.transcriptText`, `redactedUtc` | `CK_transcript_redaction`, `FK_agentRun_transcript`, `FK_fieldEvidence_transcript` | S18 |
| Turn numbering, parent, context size | `agentRun.turnNumber`, `parentRunID`, `priorTurnsIncluded` | `CK_agentRun_turn`, `UQ_agentRun_encounterTurn`, `FK_agentRun_parentRun` | `agentRunWriter.ts` |
| Idempotency | `agentRun.requestID` (`VARCHAR(64)`) | `UQ_agentRun_requestID` | `ExtractionContext.runId` |
| Run outcomes, reasons, failure modes | `agentRun.outcome`, `reasonCode`, `failureMode` | `CK_agentRun_outcome`, `CK_agentRun_reasonMatchesOutcome`, `CK_agentRun_reachedModel`, `CK_agentRun_failureMode` | `failure-modes.ts` |
| Which prompt was used | `agentRun.promptId`, `promptTemplateHash`, `promptHash` | none (no FK: `AI.prompt` has no PK) | `guard.ts`, `prompt.ts` |
| One outcome per field per turn | `fieldOutcome.runID`, `sectionID`, `fieldID` | `UQ_fieldOutcome_runField` | — |
| A field can hold several values (a list) | `proposedValue` etc. | `UQ_fieldOutcome_runField`, `PK_fieldState` (`encounterID`, `sectionID`, `fieldID`) | merge |
| Value length (today 400) | `proposedValue`, `priorValue`, `acceptedValue`, `fieldState.currentValue` — all `NVARCHAR(400)` | — | — |
| Protection bands / the "weightage" | `fieldState.protection`, `fieldOutcome.priorProtection` (`VARCHAR(8)`) | `CK_fieldState_protection`, `CK_fieldOutcome_priorState`, `CK_fieldOutcome_protectedNeverOverwritten`, `CK_fieldOutcome_mergeMatchesState` | merge §3.5 |
| What may overwrite what | `fieldOutcome.mergeAction`, `priorProtection` | `CK_fieldOutcome_protectedNeverOverwritten`, `CK_fieldOutcome_mergeMatchesState`; the engine's `WHERE protection = 'LOW'` | merge §3.6 |
| A new merge action | `fieldOutcome.mergeAction` (`VARCHAR(10)`) | `CK_fieldOutcome_mergeAction`, `CK_fieldOutcome_mergeMatchesState`, **`IX_fieldOutcome_pending` filter** (drop and recreate) | `SELECT_PENDING_BY_ENCOUNTER_SQL` |
| Who counts as a clinician value | `fieldState.source`, `setByUserID` | `CK_fieldState_source`, `CK_fieldState_setBy`, `CK_fieldState_protection` | step 3, S7 |
| Validator verdicts | `fieldOutcome.verdict`, `reasonCode` | `CK_fieldOutcome_verdict`, `CK_fieldOutcome_rejectedIsBlocked` | Epic 6 |
| Numeric bounds | `fieldConstraint.*` | `UQ_fieldConstraint_mapping`, the two range CHECKs | `fieldConstraintRepository.ts` |
| Evidence matching | `fieldEvidence.matchStatus`, offsets | `CK_fieldEvidence_matchStatus`, `CK_fieldEvidence_offsets` | S13 |
| Clinician decision | `accepted*`, `decidedByProviderID`, `decidedAtUtc` | `CK_fieldOutcome_acceptedStatus` | `SET_FIELD_OUTCOME_DECISION_SQL` |
| The review queue | `decidedAtUtc`, `mergeAction` | `IX_fieldOutcome_pending` | `SELECT_PENDING_BY_ENCOUNTER_SQL` |
| Retention | `fieldOutcome.createdUtc`, `decidedAtUtc` | `FK_fieldEvidence_fieldOutcome` (CASCADE), `FK_fieldState_fieldOutcome` (SET NULL) | `DELETE_FIELD_OUTCOME_BEFORE_SQL`, `fieldOutcomeRetention.ts` |

---

## 7. Build status by step

| Step / piece | State | Where |
|---|---|---|
| Tables `0001`–`0006` | ✅ written, unit-tested · ⚠️ never applied to a SQL Server | `migrations/sql/` |
| 1 parent/chain decision, S9/S16/S17 resets | 📐 | no code yet |
| 2 transcript store | 📐 | no repository yet |
| 3 form reconcile | 📐 · needs the form values in the request | — |
| 4 guards (injection, size, PHI mask) | ✅ | `src/pacehr/guards/`, `middleware/guard.ts` |
| 4 template load | ⛔ PEA-303 | `src/pacehr/templates/config.ts` throws |
| 4 prompt resolve + compose + hashes | ✅ | `guard.ts`, `prompt.ts` |
| 4 follow-up context (turn header, field state, earlier transcripts) | 📐 | — |
| 5 model call, token/latency capture | ✅ | `middleware/model-call.ts` |
| 5 per-field evidence in the response schema | ⛔ PEA-304 | `src/pacehr/schema/builder.ts` |
| Outcome classification | ✅ | `middleware/outcome.ts` |
| 6 `AI.agentRun` insert | ✅ writer · 📐 not yet called by the agent (PEA-902 wires it) | `agentRunWriter.ts` |
| 6 `AI.fieldOutcome` insert | ✅ writer | `fieldOutcomeRepository.ts` |
| 6 merge logic, evidence location, state apply | 📐 | — |
| Validators | ⛔ Epic 6 | — |
| S7 decision write | ✅ outcome row · 📐 state update | `fieldOutcomeRepository.ts` |
| S18 purge of `fieldOutcome` | ✅ (fails closed without a window) | `jobs/fieldOutcomeRetention.ts` |
| S18 transcript redaction | 📐 | — |

---

## 8. Open decisions this flow depends on

D1–D7 are the design doc's §10. D8–D12 came out of writing this document.

| # | Decision | Scenarios | Recommendation |
|---|---|---|---|
| D1 | Ask about every field each turn, or only empty/LOW ones | S2, S3, S5 | every field |
| D2 | Form values: in the request, or read from `Encounter.encounterData` | S6 | in the request |
| D3 | Signal for "clinician deleted an AI value" | S6 | explicit signal from the form |
| D4 🔴 | Purge undecided `KEPT`/`CONFIRMED`/`EMPTY` rows (and overtaken proposals, D9) | S18 | purge past the window regardless of `decidedAtUtc`. **Changes the owner decision of 2026-10-06** |
| D5 | Transcript redaction in the purge | S18 | same window |
| D6 | `runId` `.max(64)` | S14 | add it |
| D7 | Volume (turns per encounter) | all | measure in shadow mode |
| D8 | `ExtractionContext` has no form values and no start-over flag | S6, S16 | add both to the request |
| D9 | **Overtaken proposals stay in the review queue.** In S2, turn 1's Temperature (30003) was replaced by 30007 but is still undecided, so `SELECT_PENDING_BY_ENCOUNTER_SQL` returns both | S2, S7 | show only the latest action-bearing row per field (§9, Q5). No DDL change |
| D10 | Interim `verdict` before Epic 6 | S8 | ACCEPT, recorded as a decision |
| D11 | Duplicate requests are caught only at step 6 | S14 | check `requestID` / `transcriptText` at step 1 |
| D12 | How the engine learns an encounter is signed | S17 | a close call from the .NET sign path |

---

## 9. Queries to trace an encounter

All are read-only. Set the variables at the top before running.

```sql
DECLARE @encounterID INT = 5414457;

-- Q1. Every turn of the encounter: template, what it built on, how it ended, which prompt it used.
--     A row with parentRunID NULL starts a new conversation.
SELECT r.[turnNumber], r.[runID], r.[templetID], r.[parentRunID], r.[priorTurnsIncluded],
       r.[outcome], r.[reasonCode], r.[failureMode], r.[promptId], r.[promptTemplateHash],
       r.[inputTokens], r.[outputTokens], r.[latencyMs], t.[transcriptID],
       t.[redactedUtc], r.[createdUtc]
  FROM [AI].[agentRun] r
  JOIN [AI].[transcript] t ON t.[transcriptID] = r.[transcriptID]
 WHERE r.[encounterID] = @encounterID
 ORDER BY r.[turnNumber];

-- Q2. The current conversation: walk parentRunID back from the latest COMPLETED run.
WITH latest AS (
    SELECT TOP (1) [runID] FROM [AI].[agentRun]
     WHERE [encounterID] = @encounterID AND [outcome] = 'COMPLETED'
     ORDER BY [turnNumber] DESC
), chain AS (
    SELECT r.[runID], r.[parentRunID], r.[turnNumber], r.[transcriptID], r.[templetID]
      FROM [AI].[agentRun] r JOIN latest l ON l.[runID] = r.[runID]
    UNION ALL
    SELECT p.[runID], p.[parentRunID], p.[turnNumber], p.[transcriptID], p.[templetID]
      FROM [AI].[agentRun] p JOIN chain c ON c.[parentRunID] = p.[runID]
)
SELECT [turnNumber], [runID], [parentRunID], [templetID], [transcriptID]
  FROM chain
 ORDER BY [turnNumber];

-- Q3. Where every field stands now, with its name and patient.
SELECT s.[templetID], s.[sectionID], s.[fieldID], f.[fieldName], s.[currentValue], s.[currentUnit],
       s.[source], s.[protection], s.[setByOutcomeID], s.[setByUserID], s.[updatedUtc], e.[patientID]
  FROM [AI].[fieldState] s
  JOIN [Template].[fields] f ON f.[fieldID] = s.[fieldID]
  JOIN [Encounter].[encounter] e ON e.[encounterID] = s.[encounterID]
 WHERE s.[encounterID] = @encounterID
 ORDER BY s.[sectionID], s.[fieldID];

-- Q4. One field's history across the turns: proposal, prior state, action, decision.
DECLARE @sectionID INT = 2, @fieldID INT = 88;
SELECT r.[turnNumber], o.[outcomeID], o.[templetID], o.[proposedValue], o.[proposedStatus],
       o.[proposedConfidence], o.[priorValue], o.[priorSource], o.[priorProtection],
       o.[mergeAction], o.[verdict], o.[acceptedValue], o.[decidedByProviderID], o.[decidedAtUtc]
  FROM [AI].[fieldOutcome] o
  JOIN [AI].[agentRun] r ON r.[runID] = o.[runID]
 WHERE o.[encounterID] = @encounterID AND o.[sectionID] = @sectionID AND o.[fieldID] = @fieldID
 ORDER BY r.[turnNumber];

-- Q5. The review queue as D9 recommends: per field, only the latest row that changed something.
WITH ranked AS (
    SELECT o.*, r.[turnNumber],
           ROW_NUMBER() OVER (PARTITION BY o.[sectionID], o.[fieldID] ORDER BY r.[turnNumber] DESC) AS rn
      FROM [AI].[fieldOutcome] o
      JOIN [AI].[agentRun] r ON r.[runID] = o.[runID]
     WHERE o.[encounterID] = @encounterID
       AND o.[mergeAction] IN ('FILLED', 'UPDATED', 'CONFLICT', 'REJECTED')
)
SELECT [turnNumber], [outcomeID], [sectionID], [fieldID], [mergeAction], [proposedValue],
       [priorValue], [priorProtection], [verdict], [reasonCode]
  FROM ranked
 WHERE rn = 1 AND [decidedAtUtc] IS NULL
 ORDER BY [sectionID], [fieldID];

-- Q6. The evidence behind one proposal, and the passage it points at.
DECLARE @outcomeID BIGINT = 30005;
SELECT e.[evidenceID], e.[transcriptID], e.[matchStatus], e.[quote],
       CASE WHEN e.[startOffset] IS NOT NULL AND t.[transcriptText] IS NOT NULL
            THEN SUBSTRING(t.[transcriptText], e.[startOffset] + 1, e.[endOffset] - e.[startOffset]) END AS [locatedPassage]
  FROM [AI].[fieldEvidence] e
  JOIN [AI].[transcript] t ON t.[transcriptID] = e.[transcriptID]
 WHERE e.[outcomeID] = @outcomeID;
```
