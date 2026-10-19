# Epic 02 — AI Engine Data Design: Handover

**For:** the engineer continuing the AI engine's data layer in `pacEHR_AI`
**From:** Hem Singh · **Date:** 2026-10-06, amended 2026-10-07
**Scope:** the AI engine's own tables (`AI.*` schema) and the flow that reads and writes them. It
does not cover the legacy C# "AI Command" path, which stays as it is and writes none of these tables.

This document stands on its own. **Part A** says where the work is and what to do next. **Part B**
describes the flow: which table is touched in which scenario, with worked example rows. **Part C**
holds every table's column dictionary and its full migration script, copied word for word from
`pacEHR_AI/migrations/sql`.

---

## Part A — Where things stand

### A1. In one paragraph

A clinician creates an encounter for a patient using a template, and posts a transcript. The AI
returns, for every field of the template, a value plus the passage of the transcript it came from.
The clinician can then post follow-up transcripts, and each follow-up is treated as a continuation
of the earlier ones, like a chat thread. **A value already filled with high weight is never changed
by the AI.** If a follow-up contradicts such a value, the contradiction is kept as a `CONFLICT` for
the clinician to rule on, and is not discarded. Six tables carry this design, keyed on the encounter itself (there is no session table). They are written
and unit-tested, but **have not yet been applied to a SQL Server database**.

### A2. Where the code is

| | |
|---|---|
| Repository | `pacEHR_AI` (Node 22 / TypeScript ESM) |
| Branch | `3p-dev/PEA-201-ai-schema-data-layer`, based on `PacEHR-AI-Develop-Main` |
| State on 2026-10-06 | ⚠️ **Not pushed.** The changes are in Hem's working tree. Ask Hem for the pushed branch before you start |
| Migrations | `migrations/sql/0001`–`0007` (Part C) |
| Post-apply checks | `migrations/verification/post-apply-checks.sql` |
| Unit tests | `npm test`: 160 pass, 0 fail on 2026-10-06. `npm run typecheck`: clean |
| Integration tests | `npm run test:integration`. Skipped unless `.env.local` sets `AZURE_SQL_SERVER` and `AZURE_SQL_DATABASE` (and `AZURE_SQL_USER` / `AZURE_SQL_PASSWORD` locally) |

**Files that matter**

| File | What it is | State |
|---|---|---|
| `src/core/databaseMigrations.ts` | Applies `migrations/sql` in order (splits batches on `GO`), and refuses any script that touches anything outside the `AI` schema | ✅ |
| `src/repositories/agentRunWriter.ts` | Inserts one `AI.agentRun` row | ✅ built · not yet called by the agent |
| `src/repositories/fieldOutcomeRepository.ts` | Inserts proposals, records the clinician's decision, reads the review queue, runs the purge batch | ✅ |
| `src/repositories/fieldConstraintRepository.ts` | Reads a template's numeric bounds | ✅ |
| `src/repositories/mapping.ts` | `mappingKey(sectionID, fieldID)`, the shared key for per-field maps | ✅ |
| `src/jobs/fieldOutcomeRetention.ts` | Retention purge; deletes nothing until `AI_FIELD_OUTCOME_RETENTION_DAYS` is set | ✅ |
| `src/pacehr/agents/middleware/guard.ts` | Guards, template load, prompt from `usp_getPrompt`, prompt compose | ✅ (template load ⛔ PEA-303) |
| `src/pacehr/agents/middleware/model-call.ts` | The one model call; tokens, latency, failure → reason code | ✅ |
| `src/pacehr/agents/middleware/outcome.ts` | Classifies the run COMPLETED / BLOCKED / FAILED | ✅ |
| `src/pacehr/agents/failure-modes.ts` | Every reason code and failure mode | ✅ |
| `src/pacehr/agents/state.ts` | `ExtractionContext` (the request) and `ExtractionState` | ✅ needs additions (§B8 D6, D8) |
| `src/pacehr/templates/config.ts` | Template loader | ⛔ PEA-303, throws today |
| `src/pacehr/schema/builder.ts` | Per-request response schema | ⛔ needs per-field evidence (PEA-304) |
| `tests/integration/aiFixtures.ts` | Creates a transcript for integration tests; removes test rows in foreign-key order | ✅ |

### A3. Decisions already made — do not reopen without the owner

| Date | Decision | Effect on the tables |
|---|---|---|
| by 2026-10-05 | `pacEHR_AI` is **Node/TypeScript only** and owns all new AI code **and** the `AI.*` DDL. No Python | Migrations live in `pacEHR_AI`, not in the `pacEHR_API` SSDT project |
| by 2026-10-05 | Legacy C# AI code (`AIController`, `AI.prompt` admin UI, `usp_getPrompt`) **coexists**, unchanged | The engine *reads* `AI.prompt` through `usp_getPrompt` |
| 2026-10-05 | **No database roles and no `GRANT`s.** Access is controlled in the application | No role or permission script. `agentRun`'s "append-only" is a code convention, not a server control |
| 2026-10-06 | **`AI.promptFragment` and `AI.fieldDescription` are withdrawn** | Prompts come from the existing `AI.prompt`; field and section instructions come from `Template.fields.prompt` / `Template.section.prompt` |
| 2026-10-06 | `AI.fieldConstraint` **kept** | No existing table holds numeric bounds |
| 2026-10-06 | Retention purge deletes **decided** `fieldOutcome` rows only | See §B8 D4: this leaves undecided rows forever |
| 2026-10-06 | Multi-turn design: transcript, turn, evidence, field state, protection bands, `CONFLICT` instead of overwrite | Tables `0002`–`0006` |
| 2026-10-07 | **`AI.extractionSession` withdrawn.** `Encounter.encounter` already identifies the conversation | `encounterID` keys `transcript`, `agentRun`, `fieldState`; `templetID` on `agentRun` and `fieldState`; the `parentRunID` chain marks where a conversation restarts; `sp_getapplock` serialises turns (§B3.1, §B3.6) |
| 2026-10-07 | **`0001_create_ai_schema.sql` withdrawn.** The AI schema already exists in production (it carries `AI.prompt`), so the guarded `CREATE SCHEMA` was always a no-op | No script creates a schema. The set starts at `0001_create_transcript.sql`. `post-apply-checks.sql` check 1 still asserts the schema is present |

**What replaced the session table (2026-10-07):**

| The session table gave | Now given by |
|---|---|
| grouping of turns, transcripts and field state | `encounterID` on `AI.transcript`, `AI.agentRun`, `AI.fieldState` |
| the template snapshot | `templetID` on `AI.agentRun` and `AI.fieldState` |
| where a conversation starts again (template change, start over) | the `parentRunID` chain: a turn with `parentRunID` NULL starts a new conversation |
| one turn at a time per encounter | `sp_getapplock` on `AI.encounter.<encounterID>`, held by step 6's transaction |
| turn numbering | `UQ_agentRun_encounterTurn (encounterID, turnNumber)` |
| `patientID`, `accountId` copies | read from `Encounter.encounter` when needed |

### A4. House rules in `pacEHR_AI`

- **Migrations are forward-only.** A merged script is never edited; a correction is the next
  numbered script. Until this branch merges, the scripts may still be edited in place.
- Every `CREATE` is wrapped in `IF NOT EXISTS`, so running `npm run migrate` twice is safe.
- **Every column carries a `--` comment** saying what it means. Keep that up.
- A script may only touch the `AI` schema. The runner rejects anything else, and a unit test proves
  it does.
- A filtered index cannot use `OR` in its `WHERE`. Use `IN (…)`.
- ESLint enforces three rules:
  - `process.env` is read only in `src/core/settings.ts`;
  - every log call is `(fields, 'literal message')`, so no PHI ends up in log text;
  - no SQL is built with template literals or concatenation at the call site. Statements are
    exported constants.
- Tests run with `node --test` and `tsx`; there is no vitest. Unit tests never touch the network.

### A5. What to do next, in order

| # | Work | Depends on | Notes |
|---|---|---|---|
| 1 | **Apply the migrations to a dev database.** Run `npm run migrate` twice (the second run must do nothing), then `post-apply-checks.sql`, then `npm run test:integration` | the branch from Hem; a dev DB | Target must already have the `AI` schema (true of every PacEHR database) — nothing creates it. None of the DDL has run on a server yet. The IDE's SQL checker already caught one syntax error, so expect to find more |
| 2 | Get decisions **D2, D4, D8, D9, D10** (§B8) answered | owner | D4 changes an owner decision; D8 and D9 change code you are about to write |
| 3 | `ExtractionContext`: add `.max(64)` to `runId`, the current form values, and a start-over flag | D2, D8 | `src/pacehr/agents/state.ts` |
| 4 | Repositories: `transcript` (insert, read a chain's transcripts), `agentRun` reads (latest COMPLETED run, the `parentRunID` chain — §B9 Q2), `fieldState` (read, reconcile, apply `WHERE protection = 'LOW'`, delete on reset or sign), `fieldEvidence` (insert) | 1 | Same style as `fieldOutcomeRepository.ts`: exported SQL constants, a class, one exported instance |
| 5 | **Quote locator**: a pure function from (transcript text, quote) to `EXACT` / `NORMALIZED` / `NOT_FOUND` plus offsets | — | Unit-test it with the offsets in §B4 S1/S2 |
| 6 | **Merge engine**: a pure function from (prior state, proposal, verdict, evidence) to `mergeAction` plus the new state | 5 | Build its tests straight from the matrix in §B3.6 and the rows in §B4 |
| 7 | **Turn transaction** (step 6): `sp_getapplock` on the encounter, re-decide the parent, re-read state, insert run, outcomes and evidence, apply state | 4, 6 | Then wire `agentRunWriter` into the agent's `afterAgent` (PEA-902) |
| 8 | Follow-up context builder (§B3.8) | PEA-303, PEA-304 | — |
| 9 | Purge: transcript redaction; the predicate per D4 | D4, D5 | — |
| 10 | Review queue query per D9 (§B9 Q5) | D9 | `SELECT_PENDING_BY_ENCOUNTER_SQL` |

**Outside this work, but blocking it:** PEA-303 (template loader), PEA-304 (response schema with
evidence), Epic 6 (validators, which produce `verdict`), PEA-902 (commit-or-hold, and calling the
audit writer).

### A6. Questions worth investigating further

- **Volume.** A turn writes one `fieldOutcome` row per template field. At an *assumed* 2.5 turns
  per encounter that is about 27M rows a year. Measure the real number of turns in shadow mode.
- **Template size.** The number of fields per template drives row volume and prompt size. Get the
  distribution from `Template.templateSection` / `Template.fieldSection`.
- **Normalisation of values for `CONFIRMED`.** Is "120/80" equal to "120 / 80 mmHg"? Define value
  equality per field type before writing the merge engine.
- **Signed encounters.** Is `Encounter.encounter.encounterSignedDate` reliable enough for the
  engine to refuse posts on its own (S17, D12)?
- **`usp_getPrompt` defects** (S19): find out whether production data already has accounts with
  two universal prompts. Those encounters would all be blocked with `PROMPT_AMBIGUOUS`.

---

## Part B — The data flow

### B0. How to use this document when the flow changes

Every scenario in §B4 has an id (`S1`, `S2`, …) and ends with an **"If this changes"** line. Each
behaviour has a single place in the database that enforces it, and §B6 indexes those places.

1. **Find the scenario** the change affects (§B4, or the matrix in §B5).
2. **Read its "Tables" block.** It lists every table and column the scenario reads or writes.
3. **Look the change up in §B6.** That gives the columns, CHECK constraints and indexes that encode
   today's behaviour, so you know exactly what has to move.
4. **Change the migration.**
   - **Before the branch is merged** (today): edit the numbered script in place.
   - **After it is merged:** never edit a merged script. Write the next numbered script
     (`0009_…`), with `IF NOT EXISTS` / `IF EXISTS` guards like the others.
5. **Update this document and the column dictionary in Part C** in the same change, so
   the next person can point at it.

Each step in this document is marked with its build state:
**✅ built** = code exists and has unit tests · **📐 designed** = the table supports it but no
code writes it yet · **⛔ blocked** = waits on another epic or a decision.

---

### B1. The tables at a glance

#### B1.1 Tables the AI engine owns (`AI` schema, migrations `0001`–`0006`)

| # | Table | One row is… | Written in steps | Holds PHI | Lifetime |
|---|---|---|---|---|---|
| 0001 | `AI.transcript` | one text the clinician posted for an encounter | 2 | **yes** | text redacted at retention; row kept |
| 0002 | `AI.agentRun` | one turn: one attempt to extract, including blocked and failed ones; carries the turn's template | 6 | no | kept, append-only |
| 0003 | `AI.fieldOutcome` | one field in one turn: proposal, prior state, merge decision, clinician decision | 6, review | **yes** | retention purge |
| 0004 | `AI.fieldEvidence` | one transcript passage supporting one proposal | 6 | **yes** | deleted with its outcome (cascade) |
| 0005 | `AI.fieldState` | the current value and protection of one field of an encounter | 3, 6, review | **yes** | deleted when the conversation ends (template change, start over, signed) |
| 0006 | `AI.fieldConstraint` | numeric bounds for one field on one template | admin only | no | kept |

Full column dictionaries and scripts: **Part C**.

#### B1.2 Existing PacEHR tables the engine reads (never writes)

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

#### B1.3 How they relate

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

### B2. Vocabulary

Every column below is backed by a CHECK constraint, so these lists are the complete set.

| Column | Values | Meaning |
|---|---|---|
| `agentRun.outcome` | `COMPLETED` · `BLOCKED` · `FAILED` | model returned an extraction · a guard stopped it before the model · the model call or the extraction failed |
| `agentRun.failureMode` | `FORMAT` · `ROUTING` · `AMBIGUITY` · `COMPREHENSION` | only on `FAILED` runs whose extraction failed |
| `fieldOutcome.proposedStatus` | `FOUND` · `ABSENT` · `ABSTAINED` | a value was extracted · the transcript has none · the model would not commit |
| `fieldOutcome.proposedConfidence` | `HIGH` · `MEDIUM` · `LOW` | the model's own band, never a number |
| `fieldOutcome.verdict` | `ACCEPT` · `REVIEW` · `BLOCK` | the validators' judgement of the *value* (Epic 6) |
| `fieldOutcome.mergeAction` | `FILLED` · `CONFIRMED` · `UPDATED` · `CONFLICT` · `KEPT` · `EMPTY` · `REJECTED` | what the engine did with the *change* (§B3.6) |
| `fieldState.source`, `fieldOutcome.priorSource` | `AI` · `CLINICIAN` | who set the value |
| `fieldState.protection`, `fieldOutcome.priorProtection` | `LOCKED` · `HIGH` · `LOW` | the "weightage" (§B3.5) |
| `fieldEvidence.matchStatus` | `EXACT` · `NORMALIZED` · `NOT_FOUND` | how the engine located the model's quote in the transcript |

`agentRun.reasonCode` has **no** CHECK. Its values come from `REASON_CODES` in
`src/pacehr/agents/failure-modes.ts`, so a new reason code needs no migration.

---

### B3. The flow of one turn

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

#### B3.1 Step 1 — place the turn in its conversation

| | |
|---|---|
| **Reads** | `Encounter.encounter`: the current `templeteId`, and `encounterSignedDate` (a signed encounter is refused, S17). `AI.agentRun`: the encounter's latest `COMPLETED` run |
| **Decides** | the would-be parent. It is that latest COMPLETED run, **unless** its `templetID` differs from the encounter's template (S9), the request asks to start over (S16), or there is none (S1) — then there is no parent and a new conversation starts |
| **Context** | the conversation's transcripts: walk `parentRunID` back from the parent, taking each run's `transcriptID`, oldest first |
| **Writes** | nothing. The parent is decided again under the lock in step 6, in case another tab finished a turn meanwhile |

#### B3.2 Step 2 — store the transcript

| | |
|---|---|
| **Writes** | `AI.transcript`: `transcriptText` exactly as posted. Who posted it lives on the turn's `AI.agentRun.requestedByUserID`, not here |
| **Why first** | evidence offsets point into this text, so it has to exist and never move. It is stored even if a guard later blocks the turn, because the audit row must say what was refused |
| **Enforced by** | `CK_transcript_redaction`: text present ⇔ not redacted |

#### B3.3 Step 3 — reconcile with the form

| | |
|---|---|
| **Reads** | the field values currently on the form (the request carries them — §B8, D2), and `AI.fieldState` |
| **Writes** | `AI.fieldState`: a form value that differs from state becomes `source = 'CLINICIAN'`, `protection = 'LOCKED'`, `setByUserID` = the clinician, `setByOutcomeID = NULL` |
| **Why** | a value the clinician typed must be protected *before* the model runs, or a follow-up could overwrite it |
| **Enforced by** | `CK_fieldState_protection` (a clinician value is always LOCKED), `CK_fieldState_setBy` |

#### B3.4 Step 4 — guards, template and prompt

| | |
|---|---|
| **Reads** | the template: `Template.encounterTempletes` → `templateSection` → `section` (`prompt`) → `fieldSection` → `fields` (`prompt`). The prompt: `EXEC dbo.usp_getPrompt @userId, @accountId, @encounterId` → `AI.prompt` |
| **Also reads (follow-ups)** | `AI.fieldState` (what is filled and how strongly), and the `AI.transcript` rows of the conversation's COMPLETED turns (the `parentRunID` chain), oldest first |
| **Writes** | nothing. The resolved `promptId`, `promptTemplateHash` (the hash of the `AI.prompt` text) and `promptHash` (the hash of the whole composed prompt) are carried to step 6 |
| **Prompt tiers** (`usp_getPrompt`) | 1. the template's `promptId` → 2. the account's `isUniversal = 1` row → 3. the `accountId = 0`, `isUniversal = 1` row |
| **Stops here** | injection found, payload too large, template unavailable, no prompt, more than one prompt, placeholder unfilled → **S10** |

#### B3.5 Protection — the "weightage"

| Protection | Assigned when | May a later turn replace it? |
|---|---|---|
| `LOCKED` | the clinician typed it (step 3), or accepted, corrected or emptied it on review (S7) | **never** |
| `HIGH` | the model found it with `HIGH` confidence **and** at least one passage located `EXACT` or `NORMALIZED` | **never** |
| `LOW` | anything else the model found: `MEDIUM`/`LOW` confidence, or no locatable passage | yes |
| *(no row)* | nothing found yet | yes |

A `LOW` value that a later turn repeats with `HIGH` confidence and located evidence is
**promoted** to `HIGH`.

#### B3.6 Step 6 — merge and record

The merge is deterministic code that runs on every field. The model only proposes.

| Prior state (`AI.fieldState`) | Proposal | `mergeAction` | `AI.fieldState` afterwards |
|---|---|---|---|
| none | `FOUND`, not blocked | `FILLED` | new row, `AI`, `HIGH` or `LOW` per §B3.5 |
| none | `ABSENT` / `ABSTAINED` | `EMPTY` | still none |
| any | `FOUND`, verdict `BLOCK` | `REJECTED` | unchanged |
| any value | `ABSENT` / `ABSTAINED` | `KEPT` | unchanged |
| `AI · LOW` | `FOUND`, same value | `CONFIRMED` | promoted to `HIGH` if §B3.5 is met |
| `AI · LOW` | `FOUND`, different | `UPDATED` | replaced, protection per §B3.5 |
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

#### B3.7 Step 7 — return to the form

The response carries `FILLED`, `UPDATED` and promoted values for the form, plus `CONFLICT` and
`REJECTED` items for review. No table is written. The .NET API and Angular put the values on the
chart.

#### B3.8 What the model is told on a follow-up

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

### B4. Scenarios

#### The running example

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

#### S1 — First transcript on an encounter

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

#### S2 — Follow-up transcript

**When:** the clinician posts a second transcript into the same encounter.
**Before it:** the clinician changed Heart rate on the form from 72 to **74** (step 3 handles that,
see S6).
**Transcript 9002:** `Weight 82 kg. Repeat BP 140/90. Temp 98.6 F.`

**What happens:** the latest COMPLETED run is 7001, on the same template, so it is the parent.
The model is told this is turn 2. It is given
the filled fields with their protection, and transcript 9001 as earlier context. Each field is
merged against the state per §B3.6.

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

#### S3 — The follow-up contradicts a protected value (CONFLICT)

This is the "do not alter what is already filled" rule. It appears in S2 as outcome 30005; this
section isolates it.

| | |
|---|---|
| **When** | a field is `HIGH` or `LOCKED`, and the new proposal is `FOUND` with a different value |
| **`AI.fieldOutcome`** | `mergeAction` CONFLICT; `prior*` holds the protected value; `proposed*` holds the new one; `decidedAtUtc` NULL |
| **`AI.fieldState`** | **not touched**. The engine's update runs `WHERE protection = 'LOW'` and matches 0 rows |
| **Review queue** | the row appears (`IX_fieldOutcome_pending` includes CONFLICT) |
| **Resolved by** | S7, the clinician's decision |
| **Enforced by** | code (§B3.6) **and** the database: `CK_fieldOutcome_protectedNeverOverwritten` refuses an `UPDATED` or `FILLED` row over a HIGH/LOCKED prior, so the overwrite cannot even be recorded |

**If this changes:**
- "Discard contradicting proposals instead of queuing them" → write `KEPT` instead of `CONFLICT`.
  `CK_fieldOutcome_mergeMatchesState` forbids a `KEPT` row with a `FOUND` proposal, so that
  constraint changes too.
- "Let HIGH (not LOCKED) values be overwritten" → `CK_fieldOutcome_protectedNeverOverwritten`
  (`UPDATED` would allow `priorProtection IN ('LOW','HIGH')`) and `CK_fieldOutcome_mergeMatchesState`
  (CONFLICT would be LOCKED-only).

---

#### S4 — A LOW value is confirmed and promoted

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

#### S5 — The follow-up does not mention a filled field (KEPT)

| | |
|---|---|
| **When** | prior value exists; the proposal is `ABSENT` or `ABSTAINED` (Heart rate in S2, outcome 30006) |
| **`AI.fieldOutcome`** | `mergeAction` KEPT, `proposedValue` NULL, `prior*` copied |
| **`AI.fieldState`** | unchanged. A follow-up never erases a value |
| **Review queue** | not included: nothing changed |
| **Retention** | never decided, so today's purge never deletes it (see §B8, D4) |

**If this changes:** "a follow-up saying 'no fever' should clear Temperature" → that is a
`FOUND` proposal of a negative value, not `ABSENT`. If clearing is ever wanted, it needs a new
`mergeAction` (`CLEARED`) in `CK_fieldOutcome_mergeAction` and `CK_fieldOutcome_mergeMatchesState`,
and an AI row with no value, which `CK_fieldState_setBy` forbids today.

---

#### S6 — The clinician edits the form between turns

**When:** after turn 1, the clinician types Heart rate **74** over the AI's 72. Then turn 2 arrives.

| Step | Table | Op | Values |
|---|---|---|---|
| 3 | `AI.fieldState` (5414457, 2, 89) | **update** | `currentValue` 72 → 74, `source` AI → CLINICIAN, `protection` LOW → LOCKED, `setByUserID` 965, `setByOutcomeID` 30002 → NULL |
| 6 | `AI.fieldOutcome` 30006 | insert | `priorValue` 74, `priorSource` CLINICIAN, `priorProtection` LOCKED |

A field the AI had not filled but the clinician typed gets a new `AI.fieldState` row with source
CLINICIAN, protection LOCKED, and the encounter's current `templetID`.

**Depends on:** the request carrying the current form values (§B8, D2).
`ExtractionContext` (`src/pacehr/agents/state.ts`) has no field for them today.

**If this changes:**
- Reading values from `Encounter.encounterData` instead of the request → no DDL change, but up to
  10 s of autosave lag, inside which an edit is missed.
- A clinician *deleting* an AI value → undecided (§B8, D3). If it becomes "lock
  the field empty", the row is CLINICIAN · LOCKED with `currentValue` NULL, which is already
  allowed.

---

#### S7 — The clinician reviews a proposal

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

#### S8 — A validator blocks a value (REJECTED) ⛔ Epic 6

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

#### S9 — The template changes mid-encounter

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

#### S10 — A guard blocks the turn (BLOCKED) ✅ guard · 📐 recording

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

#### S11 — The model call or the extraction fails (FAILED) ✅ classification · 📐 recording

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

#### S12 — Evidence points at an earlier transcript

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

#### S13 — The model's quote is not in the transcript

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

#### S14 — The same request arrives twice

**When:** a double-click or a network retry sends the same `runId` (`requestID`) twice.

| | |
|---|---|
| **Caught by** | `UQ_agentRun_requestID`. The second `AI.agentRun` insert fails, and the engine returns the first run's result |
| **Gap** | the duplicate is only detected at step 6. By then the second request has stored its own `AI.transcript` row (step 2), which no run points to, and has paid for a model call. Fix before building: check for an existing `requestID` (and an in-flight one) at step 1, or skip the transcript insert when the encounter's latest transcript has identical `transcriptText` within a few seconds -- found through `IX_transcript_encounter`; the comparison is now a full-text match, there being no hash to compare instead (owner decision, 2026-10-07) |
| **Gap** | `requestID` is `VARCHAR(64)`, but `ExtractionContext.runId` has no maximum length. Add `.max(64)` |

---

#### S15 — Two tabs post at the same time

| Race | Caught by | Loser does |
|---|---|---|
| Both claim the next turn | `sp_getapplock` on `AI.encounter.<encounterID>` in step 6, with `UQ_agentRun_encounterTurn` as the backstop | waits for the lock, takes the next number, re-reads the parent, and merges against the state the winner left |
| Both change one field | step 6 re-reads `AI.fieldState` under the lock | merges against the winner's value. If the winner made it HIGH, the loser's differing value becomes a CONFLICT |

No lock is held during the model call (step 5). The lock is an application lock: it locks a name,
not a row, so it needs no table and blocks nothing outside the AI engine.

---

#### S16 — The clinician starts the extraction over

**When:** the clinician asks to re-extract from scratch. The request carries a start-over flag
(📐 not yet in `ExtractionContext`, §B8 D8).

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

#### S17 — The encounter is signed

| Table | Op |
|---|---|
| `AI.fieldState` (5414457) | delete all rows. `AI.fieldOutcome` already holds everything they said |
| later posts | refused at step 1: `Encounter.encounter.encounterSignedDate` is set |

**Gap:** what triggers the delete? A call from the .NET sign path, or a sweep for signed encounters
that still have `AI.fieldState` rows. Undecided (§B8 D12).

---

#### S18 — Retention purge ✅ fieldOutcome · 📐 transcript

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
ever purged (§B8, D4).

**If this changes:** a new predicate → `DELETE_FIELD_OUTCOME_BEFORE_SQL`. Deleting transcripts
instead of redacting them → `FK_agentRun_transcript` and `FK_fieldEvidence_transcript` would block
it, so both foreign keys change, along with `CK_transcript_redaction`.

---

#### S19 — Prompt and template resolution ✅ prompt · ⛔ template

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

### B5. Scenario × table matrix

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

### B6. Change-impact index

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
| Protection bands / the "weightage" | `fieldState.protection`, `fieldOutcome.priorProtection` (`VARCHAR(8)`) | `CK_fieldState_protection`, `CK_fieldOutcome_priorState`, `CK_fieldOutcome_protectedNeverOverwritten`, `CK_fieldOutcome_mergeMatchesState` | merge §B3.5 |
| What may overwrite what | `fieldOutcome.mergeAction`, `priorProtection` | `CK_fieldOutcome_protectedNeverOverwritten`, `CK_fieldOutcome_mergeMatchesState`; the engine's `WHERE protection = 'LOW'` | merge §B3.6 |
| A new merge action | `fieldOutcome.mergeAction` (`VARCHAR(10)`) | `CK_fieldOutcome_mergeAction`, `CK_fieldOutcome_mergeMatchesState`, **`IX_fieldOutcome_pending` filter** (drop and recreate) | `SELECT_PENDING_BY_ENCOUNTER_SQL` |
| Who counts as a clinician value | `fieldState.source`, `setByUserID` | `CK_fieldState_source`, `CK_fieldState_setBy`, `CK_fieldState_protection` | step 3, S7 |
| Validator verdicts | `fieldOutcome.verdict`, `reasonCode` | `CK_fieldOutcome_verdict`, `CK_fieldOutcome_rejectedIsBlocked` | Epic 6 |
| Numeric bounds | `fieldConstraint.*` | `UQ_fieldConstraint_mapping`, the two range CHECKs | `fieldConstraintRepository.ts` |
| Evidence matching | `fieldEvidence.matchStatus`, offsets | `CK_fieldEvidence_matchStatus`, `CK_fieldEvidence_offsets` | S13 |
| Clinician decision | `accepted*`, `decidedByProviderID`, `decidedAtUtc` | `CK_fieldOutcome_acceptedStatus` | `SET_FIELD_OUTCOME_DECISION_SQL` |
| The review queue | `decidedAtUtc`, `mergeAction` | `IX_fieldOutcome_pending` | `SELECT_PENDING_BY_ENCOUNTER_SQL` |
| Retention | `fieldOutcome.createdUtc`, `decidedAtUtc` | `FK_fieldEvidence_fieldOutcome` (CASCADE), `FK_fieldState_fieldOutcome` (SET NULL) | `DELETE_FIELD_OUTCOME_BEFORE_SQL`, `fieldOutcomeRetention.ts` |

---

### B7. Build status by step

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

### B8. Open decisions this flow depends on

D1–D7 came out of the multi-turn design; D8–D12 out of tracing every scenario through the tables.

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
| D9 | **Overtaken proposals stay in the review queue.** In S2, turn 1's Temperature (30003) was replaced by 30007 but is still undecided, so `SELECT_PENDING_BY_ENCOUNTER_SQL` returns both | S2, S7 | show only the latest action-bearing row per field (§B9, Q5). No DDL change |
| D10 | Interim `verdict` before Epic 6 | S8 | ACCEPT, recorded as a decision |
| D11 | Duplicate requests are caught only at step 6 | S14 | check `requestID` / `transcriptText` at step 1 |
| D12 | How the engine learns an encounter is signed | S17 | a close call from the .NET sign path |

---

### B9. Queries to trace an encounter

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

---

## Part C — Table definitions

Copied word for word from `pacEHR_AI/migrations/sql` and `migrations/verification` on 2026-10-07. **If this part and the scripts ever disagree, the scripts win.** Each column dictionary is generated from the `--` comment above each column.

Run order is the file number. Each script is safe to re-run: every object is created under `IF NOT EXISTS`. The set creates no schema: the `AI` schema already exists in every target database (it carries the pre-existing `AI.prompt` table), so `0001_create_ai_schema.sql` was withdrawn on 2026-10-07 as a no-op script.

| # | Script | Creates |
|---|---|---|
| 0001 | `0001_create_transcript.sql` | `AI.transcript` |
| 0002 | `0002_create_agent_run.sql` | `AI.agentRun` |
| 0003 | `0003_create_field_outcome.sql` | `AI.fieldOutcome` |
| 0004 | `0004_create_field_evidence.sql` | `AI.fieldEvidence` |
| 0005 | `0005_create_field_state.sql` | `AI.fieldState` |
| 0006 | `0006_create_field_constraint.sql` | `AI.fieldConstraint` |

---

### C1. `AI.transcript` — `0001_create_transcript.sql`

The exact text a clinician posted for one turn, keyed by encounter. Immutable; redacted, not deleted, at retention.

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `transcriptID` | BIGINT IDENTITY | no |  | The transcript's identity. AI.agentRun and AI.fieldEvidence refer to it. |
| `encounterID` | INT | no |  | The encounter this transcript was posted for (Encounter.encounter.encounterID). No foreign key: not a SQL Server limitation -- a cross-schema FK in one database works fine -- but a deliberate choice. Encounter is owned and deployed by pacEHR_API's separate SSDT project, which does not model the AI schema at all; a hard FK here would be invisible to that project's tooling and could block a future rebuild of Encounter.encounter it has no way to know about. The migration guard enforces this as policy: no script here may name a schema outside AI. |
| `transcriptText` | NVARCHAR(MAX) | yes |  | The text exactly as posted. NULL only after the retention purge has redacted it. No hash of it is kept: a duplicate post is instead recognised by comparing this column directly against the encounter's latest transcript (owner decision, 2026-10-07). |
| `createdUtc` | DATETIME2(7) | no | `getutcdate()` | Who posted it is not stored here: AI.agentRun.requestedByUserID carries the clinician for the turn this transcript became (owner decision, 2026-10-07). Unrecoverable only if a transcript is ever written with no agentRun row pointing at it -- see S14 in the flow reference. When it was posted, UTC. |
| `redactedUtc` | DATETIME2(7) | yes |  | When the retention purge removed the text, UTC. NULL while the text is present. |

**Keys, checks and indexes:** `PK_transcript` (primary key) · `CK_transcript_redaction` (check) · `IX_transcript_encounter` (index)

**Full script — `migrations/sql/0001_create_transcript.sql`**

```sql
-- AI.transcript: the exact text a clinician posted for one turn. Forward-only: once merged this file
-- is never edited.
--
-- Stored because evidence has to point at something that cannot move. AI.fieldEvidence records
-- character offsets into this text; if the text lived only in Patient.roundingNotes, an edit there
-- would silently shift every offset that points into it. So a transcript is written once and never
-- changed -- with one exception, below.
--
-- ⚠️ This is clinical text (PHI). It is the raw text as the clinician typed or dictated it. The model
-- never saw it raw: it saw a masked copy, and the token map that links the two is request-scoped and
-- never stored. Evidence quotes returned by the model are unmasked before they are located in this text.
--
-- Retention does not delete a transcript, it redacts it: transcriptText is set to NULL and
-- redactedUtc is stamped. Deleting would break AI.agentRun's reference to it, and agentRun is the
-- audit record that has to survive. Nothing here proves a redacted transcript's original content;
-- AI.agentRun.promptHash still proves two runs saw the same composed input, not what one said.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[transcript]') AND type = N'U')
CREATE TABLE [AI].[transcript] (
    -- The transcript's identity. AI.agentRun and AI.fieldEvidence refer to it.
    [transcriptID]      BIGINT         IDENTITY (1, 1) NOT NULL,
    -- The encounter this transcript was posted for (Encounter.encounter.encounterID). No foreign
    -- key: not a SQL Server limitation -- a cross-schema FK in one database works fine -- but a
    -- deliberate choice. Encounter is owned and deployed by pacEHR_API's separate SSDT project,
    -- which does not model the AI schema at all; a hard FK here would be invisible to that
    -- project's tooling and could block a future rebuild of Encounter.encounter it has no way to
    -- know about. The migration guard enforces this as policy: no script here may name a schema
    -- outside AI.
    [encounterID]       INT            NOT NULL,
    -- The text exactly as posted. NULL only after the retention purge has redacted it. No hash of
    -- it is kept: a duplicate post is instead recognised by comparing this column directly against
    -- the encounter's latest transcript (owner decision, 2026-10-07).
    [transcriptText]    NVARCHAR (MAX) NULL,
    -- Who posted it is not stored here: AI.agentRun.requestedByUserID carries the clinician for the
    -- turn this transcript became (owner decision, 2026-10-07). Unrecoverable only if a transcript
    -- is ever written with no agentRun row pointing at it -- see S14 in the flow reference.
    -- When it was posted, UTC.
    [createdUtc]        DATETIME2 (7)  CONSTRAINT [DF_transcript_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    -- When the retention purge removed the text, UTC. NULL while the text is present.
    [redactedUtc]       DATETIME2 (7)  NULL,
    CONSTRAINT [PK_transcript] PRIMARY KEY CLUSTERED ([transcriptID] ASC),
    -- Text present and not redacted, or redacted and absent. Never neither, never both.
    CONSTRAINT [CK_transcript_redaction] CHECK (
        ([transcriptText] IS NOT NULL AND [redactedUtc] IS NULL)
        OR ([transcriptText] IS NULL AND [redactedUtc] IS NOT NULL)
    )
);
GO

-- An encounter's transcripts, oldest first: the duplicate-post check, and the audit's "what was posted
-- on this chart". A turn's context is read by transcriptID from its run chain, not through this index.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_transcript_encounter' AND object_id = OBJECT_ID(N'[AI].[transcript]'))
CREATE NONCLUSTERED INDEX [IX_transcript_encounter]
    ON [AI].[transcript]([encounterID] ASC, [createdUtc] ASC);
```

---

### C2. `AI.agentRun` — `0002_create_agent_run.sql`

One append-only audit row per turn, including blocked and failed ones. Carries the turn template; parentRunID chains turns into a conversation.

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `runID` | BIGINT IDENTITY | no |  | The run's identity. AI.fieldOutcome rows hang off it. |
| `requestID` | VARCHAR(64) | no |  | The caller's id for this request (ExtractionContext.runId). Unique, so a retried or double-clicked request cannot produce a second audit row. |
| `turnNumber` | INT | no |  | This turn's position among the encounter's turns, from 1. Every attempt gets a number -- blocked and failed turns included -- so the numbering is the order the clinician posted in. It does not restart when a new chain starts. |
| `parentRunID` | BIGINT | yes |  | The most recent COMPLETED turn of the same encounter and template that this one built on. NULL starts a new chain: nothing earlier completed, the template changed, or the clinician started over -- an initial request from the model's point of view even if turnNumber is above 1. Walking parentRunID back from the latest COMPLETED run gives the conversation. |
| `transcriptID` | BIGINT | no |  | The transcript this turn processed. |
| `priorTurnsIncluded` | INT | no | `0` | How many earlier transcripts were sent to the model as context, oldest first. 0 when the model saw only the new transcript and the current field state. |
| `encounterID` | INT | no |  | The encounter this turn documents (Encounter.encounter.encounterID). No foreign key, by policy rather than capability -- see AI.transcript.encounterID for why -- and the same reasoning covers templetID below: Template.* is a third project's schema, not modelled here. |
| `templetID` | INT | no |  | The encounter's template when this turn ran (Encounter.encounter.templeteId), in the AI tables' spelling. It fixes the field set the turn extracted against: a turn whose template differs from the latest COMPLETED turn's starts a new chain instead of building on it. |
| `requestedByUserID` | INT | no |  | The PacEHR user id of the clinician who posted the transcript (ExtractionContext.userId). |
| `requestedByOid` | VARCHAR(36) | no |  | That clinician's Microsoft Entra object id (ExtractionContext.clinicianOid) -- the verified identity, as opposed to the PacEHR user id the caller asserted. |
| `promptId` | INT | yes |  | The AI.prompt row the system prompt came from: the existing account-level master prompt, chosen by usp_getPrompt (template prompt, else the account's, else the universal one). NULL when the run was blocked before a prompt was resolved. No foreign key: AI.prompt predates these migrations and has no primary key to reference. |
| `promptTemplateHash` | VARCHAR(64) | yes |  | SHA-256 of that prompt row's text at the moment it was used. AI.prompt rows are edited in place, so promptId alone does not say which text was sent. |
| `promptHash` | VARCHAR(64) | yes |  | SHA-256 of the fully composed prompt sent to the model: system prompt with placeholders filled, field state, earlier transcripts and the new one. Proves two runs saw the same input. |
| `modelDeployment` | NVARCHAR(100) | yes |  | The Azure OpenAI deployment that served the call. |
| `configVersion` | VARCHAR(64) | yes |  | The version of the template configuration the response schema was built from. |
| `inputTokens` | INT | yes |  | Prompt tokens reported by the model's response. Never a client-supplied figure. |
| `outputTokens` | INT | yes |  | Completion tokens reported by the model's response. |
| `latencyMs` | INT | yes |  | Wall-clock duration of the run in milliseconds, measured by the service. |
| `outcome` | VARCHAR(10) | no |  | How the run ended:<br>`COMPLETED` — the model returned an extraction<br>`BLOCKED` — a guard stopped it before any model call<br>`FAILED` — the model call or the extraction itself failed |
| `reasonCode` | VARCHAR(64) | yes |  | Why a run did not complete (failure-modes.ts REASON_CODES). NULL exactly when COMPLETED. |
| `failureMode` | VARCHAR(14) | yes |  | For an extraction failure only, which of the four ways it failed. Feeds Epic 10's evaluation. |
| `createdUtc` | DATETIME2(7) | no | `getutcdate()` | When the row was written, UTC. |

**Keys, checks and indexes:** `PK_agentRun` (primary key) · `UQ_agentRun_requestID` (unique) · `UQ_agentRun_encounterTurn` (unique) · `FK_agentRun_transcript` (foreign key) · `FK_agentRun_parentRun` (foreign key) · `CK_agentRun_outcome` (check) · `CK_agentRun_reachedModel` (check) · `CK_agentRun_reasonMatchesOutcome` (check) · `CK_agentRun_failureMode` (check) · `CK_agentRun_turn` (check)

**Full script — `migrations/sql/0002_create_agent_run.sql`**

```sql
-- PEA-202. AI.agentRun: one append-only audit row per turn -- every attempt to extract, including
-- the ones a guard stopped before the model was reached. Forward-only: once merged this file is
-- never edited.
--
-- A turn is one transcript posted for one encounter. Turns are grouped by Encounter.encounter itself,
-- with no session table of their own: each turn builds on the most recent COMPLETED turn of the same
-- encounter and template (parentRunID), so the model is told what is already filled and the engine
-- never overwrites a protected value. The parentRunID chain *is* the conversation. A chain starts
-- again (parentRunID NULL) on an encounter's first turn, on the first turn after its template
-- changed, and when the clinician starts the extraction over.
--
-- The outcome vocabulary is the agent's own (src/pacehr/agents/failure-modes.ts): COMPLETED,
-- BLOCKED, FAILED. It says how the run ended. Whether a field's value was applied or held for a
-- clinician is a per-field question, answered by AI.fieldOutcome.mergeAction -- not by this row.
--
-- No clinical value is stored here: the transcript is a reference, prompts are hashes. This row is
-- kept indefinitely and is not part of the retention purge. Nothing in this repository issues an
-- UPDATE or DELETE against it; that absence is the whole of its append-only guarantee (ADR-01).

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[agentRun]') AND type = N'U')
CREATE TABLE [AI].[agentRun] (
    -- The run's identity. AI.fieldOutcome rows hang off it.
    [runID]              BIGINT         IDENTITY (1, 1) NOT NULL,
    -- The caller's id for this request (ExtractionContext.runId). Unique, so a retried or
    -- double-clicked request cannot produce a second audit row.
    [requestID]          VARCHAR (64)   NOT NULL,
    -- This turn's position among the encounter's turns, from 1. Every attempt gets a number --
    -- blocked and failed turns included -- so the numbering is the order the clinician posted in. It
    -- does not restart when a new chain starts.
    [turnNumber]         INT            NOT NULL,
    -- The most recent COMPLETED turn of the same encounter and template that this one built on.
    -- NULL starts a new chain: nothing earlier completed, the template changed, or the clinician
    -- started over -- an initial request from the model's point of view even if turnNumber is
    -- above 1. Walking parentRunID back from the latest COMPLETED run gives the conversation.
    [parentRunID]        BIGINT         NULL,
    -- The transcript this turn processed.
    [transcriptID]       BIGINT         NOT NULL,
    -- How many earlier transcripts were sent to the model as context, oldest first. 0 when the
    -- model saw only the new transcript and the current field state.
    [priorTurnsIncluded] INT            CONSTRAINT [DF_agentRun_priorTurnsIncluded] DEFAULT ((0)) NOT NULL,
    -- The encounter this turn documents (Encounter.encounter.encounterID). No foreign key, by
    -- policy rather than capability -- see AI.transcript.encounterID for why -- and the same
    -- reasoning covers templetID below: Template.* is a third project's schema, not modelled here.
    [encounterID]        INT            NOT NULL,
    -- The encounter's template when this turn ran (Encounter.encounter.templeteId), in the AI
    -- tables' spelling. It fixes the field set the turn extracted against: a turn whose template
    -- differs from the latest COMPLETED turn's starts a new chain instead of building on it.
    [templetID]          INT            NOT NULL,
    -- The PacEHR user id of the clinician who posted the transcript (ExtractionContext.userId).
    [requestedByUserID]  INT            NOT NULL,
    -- That clinician's Microsoft Entra object id (ExtractionContext.clinicianOid) -- the verified
    -- identity, as opposed to the PacEHR user id the caller asserted.
    [requestedByOid]     VARCHAR (36)   NOT NULL,
    -- The AI.prompt row the system prompt came from: the existing account-level master prompt,
    -- chosen by usp_getPrompt (template prompt, else the account's, else the universal one). NULL
    -- when the run was blocked before a prompt was resolved. No foreign key: AI.prompt predates
    -- these migrations and has no primary key to reference.
    [promptId]           INT            NULL,
    -- SHA-256 of that prompt row's text at the moment it was used. AI.prompt rows are edited in
    -- place, so promptId alone does not say which text was sent.
    [promptTemplateHash] VARCHAR (64)   NULL,
    -- SHA-256 of the fully composed prompt sent to the model: system prompt with placeholders
    -- filled, field state, earlier transcripts and the new one. Proves two runs saw the same input.
    [promptHash]         VARCHAR (64)   NULL,
    -- The Azure OpenAI deployment that served the call.
    [modelDeployment]    NVARCHAR (100) NULL,
    -- The version of the template configuration the response schema was built from.
    [configVersion]      VARCHAR (64)   NULL,
    -- Prompt tokens reported by the model's response. Never a client-supplied figure.
    [inputTokens]        INT            NULL,
    -- Completion tokens reported by the model's response.
    [outputTokens]       INT            NULL,
    -- Wall-clock duration of the run in milliseconds, measured by the service.
    [latencyMs]          INT            NULL,
    -- How the run ended:
    --   COMPLETED  the model returned an extraction
    --   BLOCKED    a guard stopped it before any model call
    --   FAILED     the model call or the extraction itself failed
    [outcome]            VARCHAR (10)   NOT NULL,
    -- Why a run did not complete (failure-modes.ts REASON_CODES). NULL exactly when COMPLETED.
    [reasonCode]         VARCHAR (64)   NULL,
    -- For an extraction failure only, which of the four ways it failed. Feeds Epic 10's evaluation.
    [failureMode]        VARCHAR (14)   NULL,
    -- When the row was written, UTC.
    [createdUtc]         DATETIME2 (7)  CONSTRAINT [DF_agentRun_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_agentRun] PRIMARY KEY CLUSTERED ([runID] ASC),
    CONSTRAINT [UQ_agentRun_requestID] UNIQUE NONCLUSTERED ([requestID] ASC),
    -- Two concurrent posts on one encounter cannot both claim the same turn: one insert fails. Also
    -- the access path for "every AI call on this chart, in order", which is the turn order.
    CONSTRAINT [UQ_agentRun_encounterTurn] UNIQUE NONCLUSTERED ([encounterID] ASC, [turnNumber] ASC),
    CONSTRAINT [FK_agentRun_transcript] FOREIGN KEY ([transcriptID]) REFERENCES [AI].[transcript] ([transcriptID]),
    CONSTRAINT [FK_agentRun_parentRun] FOREIGN KEY ([parentRunID]) REFERENCES [AI].[agentRun] ([runID]),
    CONSTRAINT [CK_agentRun_outcome] CHECK ([outcome]='COMPLETED' OR [outcome]='BLOCKED' OR [outcome]='FAILED'),
    -- Any run that got past the guards composed a prompt and called a deployment. A completed run
    -- without a prompt hash would be unreproducible, which is the reason this table exists.
    CONSTRAINT [CK_agentRun_reachedModel] CHECK (
        ([outcome]='BLOCKED')
        OR ([promptHash] IS NOT NULL AND [modelDeployment] IS NOT NULL)
    ),
    -- Every row says either "it completed" or "here is why it did not". There is no third state.
    CONSTRAINT [CK_agentRun_reasonMatchesOutcome] CHECK (
        ([outcome]='COMPLETED' AND [reasonCode] IS NULL)
        OR ([outcome]<>'COMPLETED' AND [reasonCode] IS NOT NULL)
    ),
    CONSTRAINT [CK_agentRun_failureMode] CHECK (
        [failureMode] IS NULL
        OR ([outcome]='FAILED' AND ([failureMode]='FORMAT' OR [failureMode]='ROUTING' OR [failureMode]='AMBIGUITY' OR [failureMode]='COMPREHENSION'))
    ),
    -- Turn arithmetic: the first turn has no parent; context can only come from turns before this one.
    CONSTRAINT [CK_agentRun_turn] CHECK (
        [turnNumber] >= 1
        AND [priorTurnsIncluded] >= 0
        AND [priorTurnsIncluded] < [turnNumber]
        AND ([parentRunID] IS NULL OR [turnNumber] > 1)
        AND ([parentRunID] IS NOT NULL OR [priorTurnsIncluded] = 0)
    )
);
```

---

### C3. `AI.fieldOutcome` — `0003_create_field_outcome.sql`

One row per field per completed turn: proposal, prior state, merge decision, clinician decision.

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `outcomeID` | BIGINT IDENTITY | no |  | The outcome's identity. AI.fieldEvidence and AI.fieldState refer to it. |
| `runID` | BIGINT | no |  | The turn this proposal came from. |
| `encounterID` | INT | no |  | The encounter, copied from the run for the review queue's index. Cannot drift. |
| `templetID` | INT | no |  | The field's identity within the template: template, section, field -- the mapping grain, in the live database's own spelling. The same fieldID in two templates is two different fields here. |
| `sectionID` | INT | no |  | The field's section. With `templetID` and `fieldID`, the field's identity. |
| `fieldID` | INT | no |  | The field (`Template.fields.fieldID`). With `templetID` and `sectionID`, the field's identity. |
| `proposedValue` | NVARCHAR(400) | yes |  | The value the model extracted. NULL unless proposedStatus is FOUND. |
| `proposedUnit` | NVARCHAR(50) | yes |  | The unit the model attached to that value, as written (e.g. mmHg). Never converted here. |
| `proposedStatus` | VARCHAR(10) | no |  | FOUND: a value was extracted. ABSENT: the transcript has no value for this field. ABSTAINED: the model would not commit to an answer. |
| `proposedConfidence` | VARCHAR(6) | no |  | The model's own confidence as a band -- HIGH, MEDIUM, LOW. Never a number: nothing in the runtime produces a calibrated probability, and a number invites arithmetic that means nothing. |
| `priorValue` | NVARCHAR(400) | yes |  | The field's value before this turn, copied from AI.fieldState. All prior* columns are NULL together when the field had no value yet. |
| `priorUnit` | NVARCHAR(50) | yes |  | That value's unit. |
| `priorSource` | VARCHAR(10) | yes |  | Who set that value: AI (an earlier turn) or CLINICIAN (typed it, or accepted it on review). |
| `priorProtection` | VARCHAR(8) | yes |  | That value's protection -- the "weightage" that decides whether it may be replaced:<br>`LOCKED` — set or accepted by a clinician; the model never changes it<br>`HIGH` — an earlier turn found it with HIGH confidence and located evidence; never changed<br>`LOW` — an earlier turn found it with less certainty; a later turn may replace it |
| `priorOutcomeID` | BIGINT | yes |  | The earlier outcome that produced the prior value, when its source was AI. A logical reference with no foreign key: the retention purge may remove that older row while this one remains. |
| `mergeAction` | VARCHAR(10) | no |  | The merge decision, made by code from the proposal and the prior state:<br>`FILLED` — the field was empty; the proposal was applied<br>`CONFIRMED` — the proposal equals the existing value; nothing changed<br>`UPDATED` — the existing value had LOW protection; the proposal replaced it<br>`CONFLICT` — the existing value is HIGH or LOCKED and the proposal differs; the existing value was kept and the proposal held for a clinician to rule on<br>`KEPT` — the model found nothing this turn; the existing value was kept. A follow-up that does not mention a field never erases it<br>`EMPTY` — the model found nothing, and there was nothing to keep<br>`REJECTED` — a validator blocked the proposed value; nothing was applied |
| `verdict` | VARCHAR(10) | no |  | The deterministic validators' verdict on the proposed value (Epic 6): ACCEPT, REVIEW or BLOCK. A different question from mergeAction: this judges the value, mergeAction judges the change. |
| `reasonCode` | NVARCHAR(50) | yes |  | Why a validator returned REVIEW or BLOCK. |
| `acceptedValue` | NVARCHAR(400) | yes |  | The value the clinician accepted, which may differ from the proposal. |
| `acceptedUnit` | NVARCHAR(50) | yes |  | The unit of the accepted value. |
| `acceptedStatus` | VARCHAR(10) | yes |  | The status the clinician confirmed for the field. ABSENT here means "this field has no value" and locks the field empty, so a later turn cannot refill it. |
| `decidedByProviderID` | INT | yes |  | The PacEHR user id who decided. NULL for a system commit of an auto-accepted value -- a decision with no human in it. |
| `decidedAtUtc` | DATETIME2(7) | yes |  | When the decision was recorded, UTC. NULL while the row still awaits one. |
| `createdUtc` | DATETIME2(7) | no | `getutcdate()` | When the row was written, UTC. |

**Keys, checks and indexes:** `PK_fieldOutcome` (primary key) · `UQ_fieldOutcome_runField` (unique) · `FK_fieldOutcome_agentRun` (foreign key) · `CK_fieldOutcome_proposedStatus` (check) · `CK_fieldOutcome_proposedConfidence` (check) · `CK_fieldOutcome_verdict` (check) · `CK_fieldOutcome_acceptedStatus` (check) · `CK_fieldOutcome_mergeAction` (check) · `CK_fieldOutcome_priorState` (check) · `CK_fieldOutcome_protectedNeverOverwritten` (check) · `CK_fieldOutcome_mergeMatchesState` (check) · `CK_fieldOutcome_rejectedIsBlocked` (check) · `IX_fieldOutcome_pending` (index) · `IX_fieldOutcome_field_history` (index)

**Full script — `migrations/sql/0003_create_field_outcome.sql`**

```sql
-- PEA-203. AI.fieldOutcome: for every field of every turn, what the model proposed, what was already
-- there, what the engine did about it, and -- later -- what the clinician decided. Forward-only: once
-- merged this file is never edited.
--
-- One row per field per turn. A follow-up turn asks the model about every field again, so a
-- clinician's correction to an already-filled value ("actually the BP was 140/90") surfaces as a
-- CONFLICT instead of being lost. The cost is rows that record nothing changed (KEPT); that is the
-- price of never silently dropping a correction.
--
-- THE RULE THIS TABLE ENFORCES: a value with HIGH or LOCKED protection is never overwritten by the
-- model. The engine compares each proposal with the field's prior state (copied into the prior*
-- columns, so the decision can be audited) and records a mergeAction. CK_fieldOutcome_protected-
-- NeverOverwritten makes "overwrote a protected value" a row the database refuses to store, whatever
-- the engine's code does.
--
-- ABSENT and ABSTAINED stay distinct and never collapse into one value: the first is a successful
-- extraction that found nothing, the second is the model declining to answer. Production writes NA
-- for both today, which is the defect this table exists to fix.
--
-- ⚠️ PHI: proposed*, prior* and accepted* hold clinical values. Covered by the retention purge
-- (src/jobs/fieldOutcomeRetention.ts); AI.fieldEvidence rows go with their outcome.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldOutcome]') AND type = N'U')
CREATE TABLE [AI].[fieldOutcome] (
    -- The outcome's identity. AI.fieldEvidence and AI.fieldState refer to it.
    [outcomeID]             BIGINT          IDENTITY (1, 1) NOT NULL,
    -- The turn this proposal came from.
    [runID]                 BIGINT          NOT NULL,
    -- The encounter, copied from the run for the review queue's index. Cannot drift.
    [encounterID]           INT             NOT NULL,
    -- The field's identity within the template: template, section, field -- the mapping grain, in the
    -- live database's own spelling. The same fieldID in two templates is two different fields here.
    [templetID]             INT             NOT NULL,
    [sectionID]             INT             NOT NULL,
    [fieldID]               INT             NOT NULL,

    -- ── What the model proposed this turn ───────────────────────────────────────────────────────
    -- The value the model extracted. NULL unless proposedStatus is FOUND.
    [proposedValue]         NVARCHAR (400)  NULL,
    -- The unit the model attached to that value, as written (e.g. mmHg). Never converted here.
    [proposedUnit]          NVARCHAR (50)   NULL,
    -- FOUND: a value was extracted. ABSENT: the transcript has no value for this field.
    -- ABSTAINED: the model would not commit to an answer.
    [proposedStatus]        VARCHAR (10)    NOT NULL,
    -- The model's own confidence as a band -- HIGH, MEDIUM, LOW. Never a number: nothing in the
    -- runtime produces a calibrated probability, and a number invites arithmetic that means nothing.
    [proposedConfidence]    VARCHAR (6)     NOT NULL,

    -- ── What was already there when this turn ran ───────────────────────────────────────────────
    -- The field's value before this turn, copied from AI.fieldState. All prior* columns are NULL
    -- together when the field had no value yet.
    [priorValue]            NVARCHAR (400)  NULL,
    -- That value's unit.
    [priorUnit]             NVARCHAR (50)   NULL,
    -- Who set that value: AI (an earlier turn) or CLINICIAN (typed it, or accepted it on review).
    [priorSource]           VARCHAR (10)    NULL,
    -- That value's protection -- the "weightage" that decides whether it may be replaced:
    --   LOCKED  set or accepted by a clinician; the model never changes it
    --   HIGH    an earlier turn found it with HIGH confidence and located evidence; never changed
    --   LOW     an earlier turn found it with less certainty; a later turn may replace it
    [priorProtection]       VARCHAR (8)     NULL,
    -- The earlier outcome that produced the prior value, when its source was AI. A logical reference
    -- with no foreign key: the retention purge may remove that older row while this one remains.
    [priorOutcomeID]        BIGINT          NULL,

    -- ── What the engine did ─────────────────────────────────────────────────────────────────────
    -- The merge decision, made by code from the proposal and the prior state:
    --   FILLED     the field was empty; the proposal was applied
    --   CONFIRMED  the proposal equals the existing value; nothing changed
    --   UPDATED    the existing value had LOW protection; the proposal replaced it
    --   CONFLICT   the existing value is HIGH or LOCKED and the proposal differs; the existing value
    --              was kept and the proposal held for a clinician to rule on
    --   KEPT       the model found nothing this turn; the existing value was kept. A follow-up that
    --              does not mention a field never erases it
    --   EMPTY      the model found nothing, and there was nothing to keep
    --   REJECTED   a validator blocked the proposed value; nothing was applied
    [mergeAction]           VARCHAR (10)    NOT NULL,
    -- The deterministic validators' verdict on the proposed value (Epic 6): ACCEPT, REVIEW or BLOCK.
    -- A different question from mergeAction: this judges the value, mergeAction judges the change.
    [verdict]               VARCHAR (10)    NOT NULL,
    -- Why a validator returned REVIEW or BLOCK.
    [reasonCode]            NVARCHAR (50)   NULL,

    -- ── What the clinician decided (written once, by the review path, never by the model) ──────
    -- The value the clinician accepted, which may differ from the proposal.
    [acceptedValue]         NVARCHAR (400)  NULL,
    -- The unit of the accepted value.
    [acceptedUnit]          NVARCHAR (50)   NULL,
    -- The status the clinician confirmed for the field. ABSENT here means "this field has no value"
    -- and locks the field empty, so a later turn cannot refill it.
    [acceptedStatus]        VARCHAR (10)    NULL,
    -- The PacEHR user id who decided. NULL for a system commit of an auto-accepted value -- a
    -- decision with no human in it.
    [decidedByProviderID]   INT             NULL,
    -- When the decision was recorded, UTC. NULL while the row still awaits one.
    [decidedAtUtc]          DATETIME2 (7)   NULL,

    -- When the row was written, UTC.
    [createdUtc]            DATETIME2 (7)   CONSTRAINT [DF_fieldOutcome_createdUtc] DEFAULT (getutcdate()) NOT NULL,

    CONSTRAINT [PK_fieldOutcome] PRIMARY KEY CLUSTERED ([outcomeID] ASC),
    -- One outcome per field per turn. Also serves every lookup by runID.
    CONSTRAINT [UQ_fieldOutcome_runField] UNIQUE NONCLUSTERED ([runID] ASC, [sectionID] ASC, [fieldID] ASC),
    CONSTRAINT [FK_fieldOutcome_agentRun] FOREIGN KEY ([runID]) REFERENCES [AI].[agentRun] ([runID]),
    CONSTRAINT [CK_fieldOutcome_proposedStatus] CHECK ([proposedStatus]='FOUND' OR [proposedStatus]='ABSENT' OR [proposedStatus]='ABSTAINED'),
    CONSTRAINT [CK_fieldOutcome_proposedConfidence] CHECK ([proposedConfidence]='HIGH' OR [proposedConfidence]='MEDIUM' OR [proposedConfidence]='LOW'),
    CONSTRAINT [CK_fieldOutcome_verdict] CHECK ([verdict]='ACCEPT' OR [verdict]='REVIEW' OR [verdict]='BLOCK'),
    CONSTRAINT [CK_fieldOutcome_acceptedStatus] CHECK ([acceptedStatus] IS NULL OR [acceptedStatus]='FOUND' OR [acceptedStatus]='ABSENT' OR [acceptedStatus]='ABSTAINED'),
    CONSTRAINT [CK_fieldOutcome_mergeAction] CHECK (
        [mergeAction]='FILLED' OR [mergeAction]='CONFIRMED' OR [mergeAction]='UPDATED' OR [mergeAction]='CONFLICT'
        OR [mergeAction]='KEPT' OR [mergeAction]='EMPTY' OR [mergeAction]='REJECTED'
    ),
    -- Prior state is all there or all absent; and a clinician's value is always LOCKED, an AI one never is.
    CONSTRAINT [CK_fieldOutcome_priorState] CHECK (
        ([priorSource] IS NULL AND [priorProtection] IS NULL AND [priorValue] IS NULL AND [priorUnit] IS NULL AND [priorOutcomeID] IS NULL)
        OR ([priorSource]='CLINICIAN' AND [priorProtection]='LOCKED')
        OR ([priorSource]='AI' AND ([priorProtection]='HIGH' OR [priorProtection]='LOW'))
    ),
    -- The guarantee: FILLED only into an empty field, UPDATED only over a LOW value. A HIGH or
    -- LOCKED value can be CONFIRMED, KEPT or held as a CONFLICT -- never replaced.
    CONSTRAINT [CK_fieldOutcome_protectedNeverOverwritten] CHECK (
        ([mergeAction]<>'FILLED' OR [priorProtection] IS NULL)
        AND ([mergeAction]<>'UPDATED' OR [priorProtection]='LOW')
    ),
    -- Each action means one thing about the prior state and the proposal.
    CONSTRAINT [CK_fieldOutcome_mergeMatchesState] CHECK (
        ([mergeAction]<>'CONFLICT'  OR ([priorProtection]='HIGH' OR [priorProtection]='LOCKED'))
        AND ([mergeAction]<>'CONFIRMED' OR [priorProtection] IS NOT NULL)
        AND ([mergeAction]<>'KEPT'      OR [priorProtection] IS NOT NULL)
        AND ([mergeAction]<>'EMPTY'     OR [priorProtection] IS NULL)
        AND (([mergeAction]<>'KEPT' AND [mergeAction]<>'EMPTY') OR [proposedStatus]<>'FOUND')
        AND (([mergeAction]<>'FILLED' AND [mergeAction]<>'UPDATED' AND [mergeAction]<>'CONFLICT' AND [mergeAction]<>'CONFIRMED' AND [mergeAction]<>'REJECTED')
             OR [proposedStatus]='FOUND')
    ),
    -- A blocked value is never applied, and nothing is rejected except by a validator.
    CONSTRAINT [CK_fieldOutcome_rejectedIsBlocked] CHECK (
        ([mergeAction]='REJECTED' AND [verdict]='BLOCK')
        OR ([mergeAction]<>'REJECTED' AND [verdict]<>'BLOCK')
    )
);
GO

-- The review queue: an encounter's undecided rows that a clinician actually has to look at -- new
-- values, replacements, conflicts and rejections. CONFIRMED, KEPT and EMPTY rows changed nothing,
-- so they are left out of the queue. IN rather than OR: a filtered-index predicate accepts no OR.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fieldOutcome_pending' AND object_id = OBJECT_ID(N'[AI].[fieldOutcome]'))
CREATE NONCLUSTERED INDEX [IX_fieldOutcome_pending]
    ON [AI].[fieldOutcome]([encounterID] ASC, [createdUtc] ASC)
    WHERE ([decidedAtUtc] IS NULL AND [mergeAction] IN ('FILLED', 'UPDATED', 'CONFLICT', 'REJECTED'));
GO

-- A field's history across encounters on the same template: the evaluation set's access path.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fieldOutcome_field_history' AND object_id = OBJECT_ID(N'[AI].[fieldOutcome]'))
CREATE NONCLUSTERED INDEX [IX_fieldOutcome_field_history]
    ON [AI].[fieldOutcome]([templetID] ASC, [sectionID] ASC, [fieldID] ASC, [createdUtc] ASC);
```

---

### C4. `AI.fieldEvidence` — `0004_create_field_evidence.sql`

The transcript passages a proposal was taken from, located by the engine.

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `evidenceID` | BIGINT IDENTITY | no |  | The evidence row's identity. |
| `outcomeID` | BIGINT | no |  | The proposal this passage supports. |
| `transcriptID` | BIGINT | no |  | The transcript the passage is in -- this turn's, or an earlier turn's on the same encounter. |
| `quote` | NVARCHAR(1000) | no |  | The passage exactly as the model quoted it, after unmasking. |
| `startOffset` | INT | yes |  | Where the passage starts in transcriptText, as located by the engine. NULL when NOT_FOUND. |
| `endOffset` | INT | yes |  | Where it ends, exclusive. NULL when NOT_FOUND. |
| `matchStatus` | VARCHAR(10) | no |  | How the engine located the quote:<br>`EXACT` — found character for character<br>`NORMALIZED` — found after collapsing whitespace and case -- the usual result for dictated text<br>`NOT_FOUND` — not in the transcript at all; treat the value as unsupported |
| `createdUtc` | DATETIME2(7) | no | `getutcdate()` | When the row was written, UTC. |

**Keys, checks and indexes:** `PK_fieldEvidence` (primary key) · `FK_fieldEvidence_fieldOutcome` (foreign key) · `FK_fieldEvidence_transcript` (foreign key) · `CK_fieldEvidence_matchStatus` (check) · `CK_fieldEvidence_offsets` (check) · `IX_fieldEvidence_outcome` (index)

**Full script — `migrations/sql/0004_create_field_evidence.sql`**

```sql
-- AI.fieldEvidence: the transcript passages a proposed value was taken from. Forward-only: once merged
-- this file is never edited.
--
-- Zero or more rows per AI.fieldOutcome -- a blood pressure mentioned twice has two. In a follow-up
-- turn the passage may sit in an earlier transcript ("BP as noted above"), which is why each row
-- names its own transcript rather than inheriting the turn's.
--
-- The model returns the quote; the engine works out where it is. Model-reported character offsets are
-- unreliable, so they are never stored. The engine searches the transcript for the quote and records
-- what it found: EXACT, NORMALIZED (found after collapsing whitespace and case), or NOT_FOUND. A quote
-- that cannot be found is the strongest available sign that the model invented it, and it keeps the
-- value's protection at LOW.
--
-- Offsets are 0-based UTF-16 code units, end-exclusive: the same as a JavaScript string index. T-SQL's
-- SUBSTRING is 1-based, so the passage is SUBSTRING(transcriptText, startOffset + 1, endOffset - startOffset).
--
-- ⚠️ PHI: quote is clinical text. Rows are removed with their outcome -- ON DELETE CASCADE, so the
-- existing retention purge needs no change to cover this table.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldEvidence]') AND type = N'U')
CREATE TABLE [AI].[fieldEvidence] (
    -- The evidence row's identity.
    [evidenceID]   BIGINT          IDENTITY (1, 1) NOT NULL,
    -- The proposal this passage supports.
    [outcomeID]    BIGINT          NOT NULL,
    -- The transcript the passage is in -- this turn's, or an earlier turn's on the same encounter.
    [transcriptID] BIGINT          NOT NULL,
    -- The passage exactly as the model quoted it, after unmasking.
    [quote]        NVARCHAR (1000) NOT NULL,
    -- Where the passage starts in transcriptText, as located by the engine. NULL when NOT_FOUND.
    [startOffset]  INT             NULL,
    -- Where it ends, exclusive. NULL when NOT_FOUND.
    [endOffset]    INT             NULL,
    -- How the engine located the quote:
    --   EXACT       found character for character
    --   NORMALIZED  found after collapsing whitespace and case -- the usual result for dictated text
    --   NOT_FOUND   not in the transcript at all; treat the value as unsupported
    [matchStatus]  VARCHAR (10)    NOT NULL,
    -- When the row was written, UTC.
    [createdUtc]   DATETIME2 (7)   CONSTRAINT [DF_fieldEvidence_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldEvidence] PRIMARY KEY CLUSTERED ([evidenceID] ASC),
    CONSTRAINT [FK_fieldEvidence_fieldOutcome] FOREIGN KEY ([outcomeID]) REFERENCES [AI].[fieldOutcome] ([outcomeID]) ON DELETE CASCADE,
    CONSTRAINT [FK_fieldEvidence_transcript] FOREIGN KEY ([transcriptID]) REFERENCES [AI].[transcript] ([transcriptID]),
    CONSTRAINT [CK_fieldEvidence_matchStatus] CHECK ([matchStatus]='EXACT' OR [matchStatus]='NORMALIZED' OR [matchStatus]='NOT_FOUND'),
    -- A located quote has a real, non-empty span; an unlocated one has none.
    CONSTRAINT [CK_fieldEvidence_offsets] CHECK (
        ([matchStatus]='NOT_FOUND' AND [startOffset] IS NULL AND [endOffset] IS NULL)
        OR ([matchStatus]<>'NOT_FOUND' AND [startOffset] >= 0 AND [endOffset] > [startOffset])
    )
);
GO

-- A proposal's evidence, read together with the proposal.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fieldEvidence_outcome' AND object_id = OBJECT_ID(N'[AI].[fieldEvidence]'))
CREATE NONCLUSTERED INDEX [IX_fieldEvidence_outcome]
    ON [AI].[fieldEvidence]([outcomeID] ASC);
```

---

### C5. `AI.fieldState` — `0005_create_field_state.sql`

Current value and protection of each field of an encounter. The only mutable table.

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `encounterID` | INT | no |  | The encounter this state belongs to (Encounter.encounter.encounterID). No foreign key, by policy rather than capability -- see AI.transcript.encounterID for why. |
| `templetID` | INT | no |  | The template the value was extracted against. A row whose template is not the encounter's current one is stale: the template changed, and the row is deleted before the next turn. |
| `sectionID` | INT | no |  | The field, within that template. |
| `fieldID` | INT | no |  | The field (`Template.fields.fieldID`). |
| `currentValue` | NVARCHAR(400) | yes |  | The field's current value. NULL only when a clinician has said the field has no value -- a LOCKED empty field, which no later turn may refill. |
| `currentUnit` | NVARCHAR(50) | yes |  | That value's unit, as written. |
| `source` | VARCHAR(10) | no |  | Who set the current value: AI (a turn's proposal) or CLINICIAN (typed, accepted or corrected). |
| `protection` | VARCHAR(8) | no |  | The current value's protection: LOCKED, HIGH or LOW. See the header for how it is assigned. |
| `setByOutcomeID` | BIGINT | yes |  | The AI.fieldOutcome that set the current value, when it came from a turn -- or that a clinician accepted. Set to NULL if the retention purge removes that outcome. |
| `setByUserID` | INT | yes |  | The PacEHR user id of the clinician who set the value. NULL when the source is AI. |
| `updatedUtc` | DATETIME2(7) | no | `getutcdate()` | When the value or its protection last changed, UTC. |

**Keys, checks and indexes:** `PK_fieldState` (primary key) · `FK_fieldState_fieldOutcome` (foreign key) · `CK_fieldState_source` (check) · `CK_fieldState_protection` (check) · `CK_fieldState_setBy` (check)

**Full script — `migrations/sql/0005_create_field_state.sql`**

```sql
-- AI.fieldState: the current value of each field of an encounter's extraction, and how strongly it
-- is protected. Forward-only: once merged this file is never edited.
--
-- This is what a follow-up turn is told is "already filled", and what the engine checks before
-- applying a proposal. It is the one mutable table in the extraction flow -- every other table is a
-- record of what happened, and this is a projection of where things stand now. It can be rebuilt from
-- AI.fieldOutcome and the encounter form, so it is not itself the audit.
--
-- How a field's protection is set (the "weightage"):
--   CLINICIAN  any value a clinician typed on the form, or accepted or corrected on review -> LOCKED
--   AI, HIGH   found with HIGH confidence AND at least one EXACT or NORMALIZED evidence passage
--   AI, LOW    anything else the model found: lower confidence, or evidence it could not locate
-- A LOW value confirmed by a later turn with HIGH confidence and located evidence is promoted to HIGH.
-- A field with no value has no row -- ABSENT and ABSTAINED never create one.
--
-- The engine applies a proposal with an UPDATE conditioned on protection = 'LOW', so a HIGH or LOCKED
-- row cannot be overwritten even by a stale read; AI.fieldOutcome's constraints refuse to record it.
-- Turns on one encounter are serialised by an application lock (sp_getapplock on
-- 'AI.encounter.<encounterID>', owned by the turn's transaction), so two tabs cannot merge at once.
--
-- Rows live only while the encounter's conversation does. They are deleted when it ends -- the
-- encounter's template changes, the clinician starts over, or the encounter is signed -- because
-- AI.fieldOutcome already holds everything they said.
--
-- ⚠️ PHI: currentValue is clinical. Short-lived by design.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldState]') AND type = N'U')
CREATE TABLE [AI].[fieldState] (
    -- The encounter this state belongs to (Encounter.encounter.encounterID). No foreign key, by
    -- policy rather than capability -- see AI.transcript.encounterID for why.
    [encounterID]     INT             NOT NULL,
    -- The template the value was extracted against. A row whose template is not the encounter's
    -- current one is stale: the template changed, and the row is deleted before the next turn.
    [templetID]       INT             NOT NULL,
    -- The field, within that template.
    [sectionID]       INT             NOT NULL,
    [fieldID]         INT             NOT NULL,
    -- The field's current value. NULL only when a clinician has said the field has no value -- a
    -- LOCKED empty field, which no later turn may refill.
    [currentValue]    NVARCHAR (400)  NULL,
    -- That value's unit, as written.
    [currentUnit]     NVARCHAR (50)   NULL,
    -- Who set the current value: AI (a turn's proposal) or CLINICIAN (typed, accepted or corrected).
    [source]          VARCHAR (10)    NOT NULL,
    -- The current value's protection: LOCKED, HIGH or LOW. See the header for how it is assigned.
    [protection]      VARCHAR (8)     NOT NULL,
    -- The AI.fieldOutcome that set the current value, when it came from a turn -- or that a clinician
    -- accepted. Set to NULL if the retention purge removes that outcome.
    [setByOutcomeID]  BIGINT          NULL,
    -- The PacEHR user id of the clinician who set the value. NULL when the source is AI.
    [setByUserID]     INT             NULL,
    -- When the value or its protection last changed, UTC.
    [updatedUtc]      DATETIME2 (7)   CONSTRAINT [DF_fieldState_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldState] PRIMARY KEY CLUSTERED ([encounterID] ASC, [sectionID] ASC, [fieldID] ASC),
    CONSTRAINT [FK_fieldState_fieldOutcome] FOREIGN KEY ([setByOutcomeID]) REFERENCES [AI].[fieldOutcome] ([outcomeID]) ON DELETE SET NULL,
    CONSTRAINT [CK_fieldState_source] CHECK ([source]='AI' OR [source]='CLINICIAN'),
    -- A clinician's value is always LOCKED; a model's value is never LOCKED.
    CONSTRAINT [CK_fieldState_protection] CHECK (
        ([source]='CLINICIAN' AND [protection]='LOCKED')
        OR ([source]='AI' AND ([protection]='HIGH' OR [protection]='LOW'))
    ),
    -- A clinician's value names the clinician; a model's value names nobody and is never empty.
    CONSTRAINT [CK_fieldState_setBy] CHECK (
        ([source]='CLINICIAN' AND [setByUserID] IS NOT NULL)
        OR ([source]='AI' AND [setByUserID] IS NULL AND [currentValue] IS NOT NULL)
    )
);
```

---

### C6. `AI.fieldConstraint` — `0006_create_field_constraint.sql`

Numeric bounds per template mapping, read by the validators (Epic 6).

| Column | Type | Null | Default | Meaning |
|---|---|---|---|---|
| `constraintID` | INT IDENTITY | no |  | The row's identity. |
| `templetID` | INT | no |  | The template the bounds apply to. With `sectionID` and `fieldID`, one row per mapping (`UQ_fieldConstraint_mapping`). |
| `sectionID` | INT | no |  | The section of the mapping. |
| `fieldID` | INT | no |  | The field of the mapping. |
| `unit` | NVARCHAR(20) | yes |  | The unit the bounds are written in, as authored. Never converted here. |
| `plausibleMin` | DECIMAL(6, 2) | yes |  | Below this the value is implausible: the validator returns BLOCK, and the proposal is `REJECTED`. |
| `plausibleMax` | DECIMAL(6, 2) | yes |  | Above this the value is implausible: BLOCK → `REJECTED`. |
| `abnormalMin` | DECIMAL(6, 2) | yes |  | Below this the value is clinically abnormal: the validator returns REVIEW. The value is kept and flagged. |
| `abnormalMax` | DECIMAL(6, 2) | yes |  | Above this the value is clinically abnormal: REVIEW, kept and flagged. |
| `sourceProse` | NVARCHAR(MAX) | yes |  | The free text the bounds were authored from, kept so the numbers can be checked against it. |
| `isActive` | BIT | no | `1` | Whether validators use this row. On by default. |
| `createdUtc` | DATETIME2(7) | no | `getutcdate()` | When the row was created, UTC. |
| `updatedUtc` | DATETIME2(7) | no | `getutcdate()` | When the row was last changed, UTC. |

**Keys, checks and indexes:** `PK_fieldConstraint` (primary key) · `UQ_fieldConstraint_mapping` (unique) · `CK_fieldConstraint_plausibleRange` (check) · `CK_fieldConstraint_abnormalRange` (check)

**Full script — `migrations/sql/0006_create_field_constraint.sql`**

```sql
-- PEA-206. Per-mapping numeric bounds, keyed on (templetID, sectionID, fieldID).
-- Forward-only: once merged this file is never edited.
--
-- The grain is per mapping, not per field: one displayName edit was measured reaching 179 of 458
-- templates, so a global grain would leak a bound across every template using that field.
--
-- Two bands, with different behaviours: plausible* blocks a value, abnormal* flags it and keeps
-- it. One unlabelled pair cannot express that difference, and getting it wrong is silent in both
-- directions -- either real abnormal values pass unflagged, or real hypertensive readings are
-- refused as implausible.
--
-- DECIMAL, not FLOAT: a bound is compared, and binary floating point makes a comparison at the
-- boundary a coin toss. ponytail: node-mssql surfaces DECIMAL as a JS double, so the comparison
-- must happen in SQL or carry an explicit tolerance -- see the read path, not this file.
--
-- unit is stored as authored and never converted here. A multi-unit value such as "kg|lb" against
-- one min/max pair is ambiguous by construction; the resolution belongs to the validator.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldConstraint]') AND type = N'U')
CREATE TABLE [AI].[fieldConstraint] (
    [constraintID] INT            IDENTITY (1, 1) NOT NULL,
    [templetID]    INT            NOT NULL,
    [sectionID]    INT            NOT NULL,
    [fieldID]      INT            NOT NULL,
    [unit]         NVARCHAR (20)  NULL,
    [plausibleMin] DECIMAL (6, 2) NULL,
    [plausibleMax] DECIMAL (6, 2) NULL,
    [abnormalMin]  DECIMAL (6, 2) NULL,
    [abnormalMax]  DECIMAL (6, 2) NULL,
    [sourceProse]  NVARCHAR (MAX) NULL,
    [isActive]     BIT            CONSTRAINT [DF_fieldConstraint_isActive] DEFAULT ((1)) NOT NULL,
    [createdUtc]   DATETIME2 (7)  CONSTRAINT [DF_fieldConstraint_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    [updatedUtc]   DATETIME2 (7)  CONSTRAINT [DF_fieldConstraint_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldConstraint] PRIMARY KEY CLUSTERED ([constraintID] ASC),
    CONSTRAINT [UQ_fieldConstraint_mapping] UNIQUE NONCLUSTERED ([templetID] ASC, [sectionID] ASC, [fieldID] ASC),
    CONSTRAINT [CK_fieldConstraint_plausibleRange] CHECK ([plausibleMin] IS NULL OR [plausibleMax] IS NULL OR [plausibleMin]<=[plausibleMax]),
    CONSTRAINT [CK_fieldConstraint_abnormalRange] CHECK ([abnormalMin] IS NULL OR [abnormalMax] IS NULL OR [abnormalMin]<=[abnormalMax])
);
```

---

### C7. Post-apply checks — `migrations/verification/post-apply-checks.sql`

Run after `npm run migrate` against the target database. Each check states the expected result.

```sql
-- PEA-201 post-apply verification. Read-only: every statement here is a SELECT.
-- Run after each apply, against each target, and keep the output as deployment evidence.
--
-- No script here creates the AI schema: it already exists in production, carrying the pre-existing
-- AI.prompt table (defect X9 -- no CREATE SCHEMA statement was ever in source control, and none is
-- added here, because adding one would imply this epic owns a schema that predates it). Check 1
-- below only confirms that precondition holds on the target; a 0-row result means this whole set
-- cannot apply, because every script here creates its table inside [AI].
--
-- These are operator checks, not application statements, so they live here rather than as _SQL
-- constants in a module. Nothing in the service ever runs this file.

-- 1. The schema already exists (it must; nothing here creates it).         expect: 1 row
SELECT name FROM sys.schemas WHERE name = 'AI';

-- 2. No database role was created by this epic.                          expect: 0 rows
--    Authority lives in the application (owner decision, 2026-10-05). A row here means someone
--    reintroduced a role out of band -- find out who, and whether the application still agrees.
SELECT name, type_desc FROM sys.database_principals
WHERE type = 'R' AND name IN ('aiServiceRuntime', 'aiPromptAdmin', 'aiTemplateAdmin');

-- 3. Nothing has been granted on any AI.* object.                         expect: 0 rows
--    The service connects as one principal with whatever rights that login already holds.
--    ⚠️ Read this one knowing what it means: AI.agentRun is append-only by application
--    convention, not by permission. Nothing at the server refuses an UPDATE or DELETE against
--    the audit table. If that guarantee is needed, it is a trigger, not a grant -- see HANDOFF.
SELECT pr.name AS grantee, dp.permission_name, dp.state_desc, o.name AS object_name
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'AI';

-- 4. The six tables this epic creates exist.                            expect: 6 rows
--    transcript, agentRun, fieldOutcome, fieldEvidence, fieldState, fieldConstraint. Turns are
--    grouped by Encounter.encounter, so there is no session table. AI.prompt is the pre-existing master-prompt table and is excluded. Field and
--    section descriptions are read from Template.fields.prompt and Template.section.prompt, so the
--    epic creates no table for them.
SELECT o.name, o.type_desc FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'AI' AND o.type = 'U'
  AND o.name IN ('transcript', 'agentRun', 'fieldOutcome', 'fieldEvidence', 'fieldState',
                 'fieldConstraint')
ORDER BY o.name;

-- 4a. The constraint that carries the follow-up design exists.            expect: 1 row
--    CK_fieldOutcome_protectedNeverOverwritten is what makes "the model replaced a HIGH or LOCKED
--    value" a row the server refuses. If it is missing, that guarantee is application code only.
SELECT name FROM sys.check_constraints
WHERE name = 'CK_fieldOutcome_protectedNeverOverwritten';

-- 5. THE CHECK THAT MATTERS: not one object outside the AI schema was touched today.
--                                                                        expect: 0 rows
--    Any row is a failed deployment. Stop, keep the output, and do not proceed.
SELECT s.name AS schema_name, o.name AS object_name, o.type_desc, o.modify_date
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name <> 'AI'
  AND o.modify_date >= CAST(GETDATE() AS DATE);

-- 6. What the AI schema now holds. Informational -- AI.prompt, which predates this epic, plus
--    the six tables of check 4. Anything else is a table this epic does not know about.
SELECT o.name, o.type_desc, o.create_date
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'AI'
ORDER BY o.name;
```

---

### C8. Existing PacEHR objects the engine reads (never writes)

From `pacEHR_API/PacEHR.Database`, the SSDT project that owns them. Audit triggers are omitted. The engine must not change any of these.

**`AI.prompt`** — The master prompt, per account. No primary key, so `AI.agentRun.promptId` has no foreign key.

```sql
CREATE TABLE [AI].[prompt] (
    [promptId]     INT            IDENTITY (1, 1) NOT NULL,
    [prompt]       NVARCHAR (MAX) NULL,
    [isActive]     INT            NULL,
    [description]  NVARCHAR (100) NULL,
    [templateId]   INT            NULL,
    [promptName]   NVARCHAR (255) DEFAULT ('') NOT NULL,
    [createdBy]    INT            NULL,
    [modifiedBy]   INT            NULL,
    [isDeleted]    BIT            DEFAULT ((0)) NOT NULL,
    [createdDate]  DATETIME2 (7)  DEFAULT (sysdatetime()) NOT NULL,
    [modifiedDate] DATETIME2 (7)  NULL,
    [accountId]    INT            NULL,
    [type]         NVARCHAR (255) NULL,
    [isUniversal]  INT            NULL
);
```

**`Template.encounterTempletes`** — The template. `promptId` is prompt tier 1.

```sql
CREATE TABLE [Template].[encounterTempletes] (
    [encounterTempleteID]          INT            IDENTITY (1, 1) NOT NULL,
    [encounterTempleteName]        VARCHAR (150)  NULL,
    [encounterTempleteDescription] VARCHAR (550)  NULL,
    [createdDate]                  DATETIME       NULL,
    [createdBy]                    INT            NULL,
    [lastModifiedDate]             DATETIME       NULL,
    [lastModifiedBy]               INT            NULL,
    [isActive]                     BIT            NULL,
    [DXFlag]                       BIT            NULL,
    [promptId]                     INT            NULL,
    [ambientFlag]                  BIT            NULL,
    [ambientPrompt]                VARCHAR (255)  NULL,
    [cptBillingRuleId]             INT            NULL,
    [speciality]                   VARCHAR (255)  NULL,
    [associatedCarePrograms]       NVARCHAR (200) NULL,
    CONSTRAINT [PK_encounterTempleteID] PRIMARY KEY CLUSTERED ([encounterTempleteID] ASC)
);
```

**`Template.templateSection`** — Which sections a template has, in order.

```sql
CREATE TABLE [Template].[templateSection] (
    [templateID] INT NOT NULL,
    [sectionID]  INT NOT NULL,
    [orderby]    INT NULL
);
```

**`Template.section`** — `prompt` is the section instruction sent to the model.

```sql
CREATE TABLE [Template].[section] (
    [sectionID]   INT            IDENTITY (1, 1) NOT NULL,
    [sectionName] VARCHAR (1000) NULL,
    [description] VARCHAR (1000) NULL,
    [isActive]    INT            NULL,
    [createdBy]   INT            NULL,
    [CreatedDate] DATETIME       NULL,
    [prompt]      VARCHAR (MAX)  NULL,
    CONSTRAINT [PK_sectionID] PRIMARY KEY CLUSTERED ([sectionID] ASC)
);
```

**`Template.fieldSection`** — Which fields a section has, in order. No template column, so field placement is shared across templates.

```sql
CREATE TABLE [Template].[fieldSection] (
    [fieldID]   INT NOT NULL,
    [sectionID] INT NOT NULL,
    [orderby]   INT NULL
);
```

**`Template.fields`** — `prompt` is the field instruction sent to the model. Per field, shared by every template that uses it.

```sql
CREATE TABLE [Template].[fields] (
    [fieldID]            INT            IDENTITY (1, 1) NOT NULL,
    [fieldName]          VARCHAR (255)  NOT NULL,
    [fieldType]          VARCHAR (255)  NOT NULL,
    [displayName]        VARCHAR (255)  NOT NULL,
    [createdBy]          INT            NULL,
    [CreatedDate]        DATETIME       NULL,
    [isActive]           INT            NULL,
    [defaultValue]       VARCHAR (MAX)  NULL,
    [importData]         VARCHAR (55)   NULL,
    [chargeCategoryName] VARCHAR (55)   NULL,
    [variant]            VARCHAR (20)   NULL,
    [isShowinPDF]        INT            NULL,
    [prompt]             VARCHAR (MAX)  NULL,
    [allowAISummary]     BIT            NULL,
    [aiSummaryPrompt]    NVARCHAR (MAX) NULL,
    [abbreviation]       VARCHAR (20)   NULL,
    CONSTRAINT [PK_fieldID] PRIMARY KEY CLUSTERED ([fieldID] ASC)
);
```

**`Encounter.encounter`** — excerpt: only the columns the engine uses (the table has 48). `templeteId` is spelled that way in the live schema.

```sql
CREATE TABLE [Encounter].[encounter] (
    [encounterID]                   INT            IDENTITY (1, 1) NOT NULL,
    [patientID]                     INT            NULL,
    [isDeleted]                     BIT            NULL,
    [templeteId]                    INT            NULL,
    [accountID]                     INT            NULL,
    [encounterSignedDate]           DATETIME       NULL,
    CONSTRAINT [PK_encounterID] PRIMARY KEY CLUSTERED ([encounterID] ASC)
    -- … 42 further columns not used by the AI engine …
    CONSTRAINT [PK_encounterID] PRIMARY KEY CLUSTERED ([encounterID] ASC)
);
```

**`dbo.usp_getPrompt`** — how the prompt is chosen (S19). Three known defects are listed in §B4 S19.

```sql
--==============================================================================
-- Author          : Akash Irlapalle
-- Created Date    : 9 July 2024
-- Description     : Get Active AI prompt.
-- Modification    : Changes done to get priority based prompts (mapped prompt, organization-universal, system-universal) by Sai Bindu Raavi on Feb 03 2026
-- Modification    : getPrmopt issue changes by SaiR on 17-02-2026
--=============================================================================
--exec usp_getPrompt 965,1,5414457
CREATE PROCEDURE [dbo].[usp_getPrompt]
    @userId     INT,
    @accountId  INT,
    @encounterId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @templatePromptId INT = NULL;

    /* 1) Get promptId from Encounter -> Template.encounterTempletes */
    SELECT
        @templatePromptId = et.promptId
    FROM Encounter.encounter e
    INNER JOIN [Template].[encounterTempletes] et
        ON et.encounterTempleteID = e.templeteId   -- adjust column if different
    WHERE e.encounterId = @encounterId;

    /* Priority 1: template prompt */
    IF (@templatePromptId IS NOT NULL AND @templatePromptId > 0)
        BEGIN
            SELECT p.promptId, p.prompt
            FROM AI.prompt p
            WHERE p.isActive = 1
              AND p.promptId = @templatePromptId;

            RETURN;
        END;
    ELSE
        BEGIN
            /* Priority 2: account-specific non-universal prompts */
            IF EXISTS (
                SELECT 1
                FROM AI.prompt p
                WHERE p.isActive = 1
                  AND p.accountId = @accountId
                  AND p.isUniversal = 1
            )
                BEGIN
                    SELECT p.promptId, p.prompt
                    FROM AI.prompt p
                    WHERE p.isActive = 1
                      AND p.accountId = @accountId
                      AND p.isActive=1
                      AND p.isUniversal = 1;

                    RETURN;
                END;
            ELSE
                BEGIN
                    /* Priority 3: universal prompts (accountId = 0, isUniversal = 1) */
                    SELECT p.promptId, p.prompt
                    FROM AI.prompt p
                    WHERE p.isActive=1 and p.accountId=0 and p.isUniversal=1
                END
        END
END
```
