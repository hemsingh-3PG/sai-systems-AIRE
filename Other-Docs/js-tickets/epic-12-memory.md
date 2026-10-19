# Epic 12 — Memory layer, Phase 2 (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Memory layer: learn from clinician corrections without ever gaining authority

**Description:** Today the ten-thousandth note from a clinician is processed exactly like the first, and every correction they make is lost to the AI. This epic captures each field a clinician corrects as a durable event, condenses the events into one short, capped instruction per scope (clinician, clinician–patient pair, template field), and adds that instruction to the clinician's next prompt. A learned instruction can never relax a validator, change a field's status or raise a confidence band, and its benefit is measured against a memory-off control arm, with a real switch that turns it off. Every read in this epic degrades to an empty result on any failure: a missing row, a slow database or the switch turned off all give exactly what the agent does today. This is Phase 2 work and the epic most likely to be cut, so each story is written so that removing it, or measuring it flat and switching it off, is a clean subtraction.

### PEA-1201

**Title:** Capture every clinician correction as an append-only memory event

**Description:**
As a platform engineer, I want every field where a clinician's final decision differs from the AI's proposal captured as an append-only event when the review is resolved, so that the memory layer has verifiable raw material and the clinical values in it have one retention and purge path from the day the table exists.

Today a correction is applied to the chart and then lost to the AI: nothing records that the AI was wrong or what the clinician wanted instead. The tenth time a clinician fixes the same field the same way, the system has learned nothing. `AI.memoryEvent` is that record: one row per field where the proposal and the decision differ, keyed to the field, encounter, clinician and run, written once and touched again only by a purge.

**Scope**

- in: the `AI.memoryEvent` table (a forward-only migration), the capture function the resolve path calls, the retention setting, and joining the existing patient-data purge
- out: the resolve endpoint that calls the capture (Epic 9), and the per-field review record it compares (Epic 2)
- out: condensing events into a summary (PEA-1202), and building a new purge mechanism

**Acceptance criteria**

- An AI proposal of Weight "160 lb" that the clinician resolves as "185 lb" writes exactly one `AI.memoryEvent` row. It holds the proposed and accepted value and unit, (templetID, sectionID, fieldID), the clinician, the patient and the run id.
- A field accepted unchanged ("98.6 F" kept as "98.6 F") writes no row.
- One encounter with 5 proposed fields, 2 of them changed, writes exactly 2 rows. The 3 unchanged fields write none.
- Any `UPDATE` on `AI.memoryEvent` fails, and only the patient purge deletes rows. An integration test proves both.
- A patient-data purge for a patient with 12 rows across several encounters deletes all 12 and no row of any other patient. No retention exemption keeps any of them.
- The retention period is a `settings()` entry, never a literal. Unset, rows are kept until the patient purge.
- No log line from the capture path carries a proposed or accepted value. It logs the field identity and the run id only.

**Technical notes**

- `src/services/memoryService.ts` exports the capture entry point. Epic 9's resolve path calls it after the clinician's decision is applied. It compares the AI's value and unit with the final ones on the per-field review row (`AI.EncounterFieldReview`), the same comparison as that table's computed `action` column, and writes one row per divergent field.
- The insert is `INSERT_MEMORY_EVENT_SQL` in `src/repositories/memoryRepository.ts`, run through `database.run` with `@name` parameters. The row also carries `found_in` and a timestamp.
- The table ships as the next forward-only script under `migrations/sql/`, applied by `npm run migrate`. An `INSTEAD OF UPDATE` trigger makes append-only a database rule rather than a convention.
- Columns keep the live spelling (`templetID`, `sectionID`, `fieldID`). The clinician is an `Account.users.userId`.
- Retention is `MEMORY_RETENTION_DAYS`, one optional zod entry in `src/core/settings.ts`.
- Tests: `tests/unit/services/memoryService.test.ts` (seeded `database`) and `tests/integration/repositories/memoryRepository.test.ts` (the purge and the refused update).

**Before you build (due diligence)**

- Decide whether `AI.memoryEvent` is needed at all. The merged review table already holds the AI's value beside the clinician's, with the clinician and the turn, and the data design drops `AI.memoryEvent` for that reason. But a review row is updated in place when the clinician changes their mind, so it is not append-only. Agree with the owner which record is the memory source.
- Confirm where the patient id comes from. The run context carries `userId` but no patient id: read `Encounter.encounter.patientID`, or add it to the context. Confirm also which clinician corrections key on: the clinician of record (`providerID`) or whoever reviewed (`reviewedBy`).
- Confirm the patient-data purge path with the pacEHR_API team. No `AI` purge procedure exists yet; the data design plans one for every `AI` table, called from the existing purge.
- Check the PHI rule that memory keeps no raw note text. `found_in` is a verbatim span of the note: decide whether the event stores it, or only field identity, values and units.
- Read `information_schema.columns` in DEV for the live spelling of every referenced column before writing the migration.

---

### PEA-1202

**Title:** Condense corrections into one capped, rewritten-in-place summary per scope

**Description:**
As an AI/clinical admin, I want every scope's corrections condensed into one capped summary that is rewritten in place, so that a clinician's history costs the same prompt budget however large it grows, and so that I can clear or flag a scope directly when its learned content goes wrong.

`AI.memoryEvent` grows without bound, and a prompt cannot carry that log. A clinician with 5,000 corrections would cost about a hundred times the tokens of one with 50, for no matching gain, and most of the history repeats the same few patterns. `AI.memory` keeps one bounded, current instruction per scope, rewritten when new evidence arrives and never appended, so the token cost stays flat and an admin has one row per scope to inspect, clear or flag.

**Scope**

- in: the `AI.memory` table, the deterministic condenser run for each affected scope after PEA-1201 records events, the per-row cap
- in: admin clear and admin flag on one scope
- out: reading the summary and adding it to the prompt (PEA-1203), the admin UI, and a model-written summary

**Acceptance criteria**

- A clinician with 5,000 events and one with 50 both get a `summaryText` of at most 500 characters (`MEMORY_SUMMARY_MAX_CHARS`).
- One new event for a clinician whose summary is 480 characters rewrites that row in place with freshly computed text. No earlier text is joined onto it, and exactly one row still exists for that clinician's CLINICIAN scope.
- A second row for the same (`scopeType`, `scopeKey`) is rejected by the database's unique index, not by application code.
- Clearing a scope empties its `summaryText`. The next request for that clinician reads an empty block, identical to cold start, and the scope's `AI.memoryEvent` history is kept.
- Flagging a scope sets `isFlagged`. The next request leaves that scope out of the memory block, and its text and history stay for audit.
- Clear and flag are the only writes outside the condenser. Each logs who acted and when, never the summary text.
- The same events always condense to the same text.

**Technical notes**

- `AI.memory` holds one row per (`scopeType`, `scopeKey`). `scopeType` is CLINICIAN, CLINICIAN_PATIENT or TEMPLATE_FIELD, each tracked on its own. `scopeKey` is one string: the clinician id, the clinician and patient ids, or (templetID, sectionID, fieldID). The other columns are `summaryText`, `isFlagged` and `updatedDate`.
- The condenser in `src/services/memoryService.ts` is plain TypeScript, not a model call: it deduplicates by field, keeps the most recent and most frequent pattern, and truncates to the cap at a line boundary. It adds no second model call and no step the model can skip.
- `MEMORY_SUMMARY_MAX_CHARS = 500` is a module constant. Its comment says it is a starting value until the token cost is measured.
- The rewrite, clear and flag statements are `_SQL` constants in `src/repositories/memoryRepository.ts`. The table ships as a forward-only migration.
- Tests: `tests/unit/services/memoryService.test.ts` (cap, rewrite, clear, flag) and the duplicate-insert check in `tests/integration/repositories/memoryRepository.test.ts`.

**Before you build (due diligence)**

- Settle the conflict with what is already merged. The AI schema already has `AI.PatientSummary` and `AI.ClinicianSummary`: model-written, versioned with one active row per scope, capped near 800 tokens, a clinician summary used only after 30 encounters, no template-field scope and no flag (reset only). Decide whether `AI.memory` is a new table or those tables carry the memory, and whether the patient scope is shared across clinicians or per clinician–patient pair, before writing any migration.
- If the condenser becomes a model call, as the merged summary tables assume, it needs its own prompt, model choice and tests. gpt-4.1 retires for new customers on 2027-04-14, and the newer reasoning models mostly take no temperature, so their output does not repeat. The deterministic condenser avoids both.
- Decide what memory captures besides field corrections. 18% of production notes carry instructions to the AI (no codes, fill canned normals, leave a field blank). The usage study recommends turning these into request options or template settings rather than memory. Confirm with the client.
- Confirm that CLINICIAN_PATIENT and TEMPLATE_FIELD rows are covered by the patient purge. Their text is built from patient values, so a purge must clear or rebuild them; PEA-1201 covers only the events.
- Measure what 500 characters cost: compare `usage_metadata.input_tokens` on a live call with and without a full block before keeping the cap.

---

### PEA-1203

**Title:** Inject the per-scope memory block in the guard, empty on cold start

**Description:**
As a clinician, I want my past corrections, and the patterns already known for this patient and this field, added to my next note's context automatically, so that I never repeat a correction, and so that my first use of the system, or anyone's first use, behaves exactly as it does today.

Memory must never make the system worse for a clinician with no history. A new clinician, or the feature newly switched on for everyone, must not regress. Reading the three scopes' bounded summaries before the model call is where the write side (PEA-1201, PEA-1202) becomes something the model sees, and where "no memory yet" is proven to mean "no different", not "broken".

**Scope**

- in: a `memory_load` step in the guard's `beforeAgent`, after `prompt_load` and before `prompt_compose`
- in: the three scope reads, the combined cap, and falling back to an empty block on any failure
- out: writing and condensing memory (PEA-1201, PEA-1202), prompt versioning (Epic 8), and injection scanning and PHI masking (Epic 5)

**Acceptance criteria**

- A clinician with no `AI.memory` row in any scope gets an empty block, and `promptHash` equals the hash of the same request with the memory step switched off.
- With a CLINICIAN row for the clinician, a CLINICIAN_PATIENT row for this patient, and a TEMPLATE_FIELD row for a field in this template (templetID 12, sectionID 3, fieldID 44), the block holds content from all three.
- A TEMPLATE_FIELD row for a field outside this template (templetID 99) is never included.
- When 40 of the template's fields each have a row at the per-row cap, the block is at most 2,500 characters (`MEMORY_BLOCK_MAX_CHARS`). Rows are dropped oldest-updated first, and no row is cut mid-line.
- A failed memory read, for example a connection error, gives an empty block. The run continues and ends exactly as on cold start, never BLOCKED or GUARD_STEP_FAILED, and the log line names the error class only.
- The memory step never ends or redirects a run.
- Each of the three reads is an index seek on (`scopeType`, `scopeKey`). The DEV execution plan shows no scan.
- A log line about the block carries its length, never its text.

**Technical notes**

- `src/agents/middleware/guard.ts`: the `memory_load` step replaces the `PHASE_1_MEMORY = ''` constant. The block goes straight to `composePrompt` (`src/agents/prompt.ts`), which already places it last and leaves the text unchanged when it is empty. There is no new middleware: the spine allows one `beforeAgent`, and the guard owns it.
- The step catches its own errors and returns `''`. Without that, the guard's catch-all would end the run as GUARD_STEP_FAILED.
- The three reads are `_SQL` constants in `src/repositories/memoryRepository.ts` (the field read is one batched query over the template's slot keys). Combining and capping live in `src/services/memoryService.ts`. Both use the existing `database` singleton: no new client and no LangGraph store.
- Scope keys come from the run context and the loaded template config, never from the note text.
- `MEMORY_BLOCK_MAX_CHARS = 2_500` is a module constant.
- Tests: the guard cases in `tests/unit/agents/encounter.test.ts` (seeded `database.execute`) and `tests/unit/services/memoryService.test.ts`.

**Before you build (due diligence)**

- Where memory lives. LangChain JS supports a LangGraph store (`createAgent({ store })`, read in a hook as `runtime.store`), but its documented production stores are Postgres, MongoDB and Redis, not Azure SQL, and the agent is built with no store on purpose (an Epic 4 test checks it). The recommendation is Azure SQL through `database.execute`. Confirm, and if a store is ever chosen, run `runtime.store` inside a hook first: it is typed but unmeasured here.
- Where the block is added. Adding it in the guard keeps `promptHash` equal to the text sent; adding it in `wrapModelCall` would send text the hash does not cover. The new step changes Epic 4's fixed guard step order, so update that ticket's list and its test together.
- Confirm the run has the patient id the CLINICIAN_PATIENT read needs. The context has `userId` and no patient id.
- Decide whether the block passes the injection scan and the PHI masker before it is sent. It is built from values clinicians typed, and it leaves the service with the prompt.
- Decide whether the block goes before or after the output rules. Today it comes after them, and the rules' last sentence only overrides instructions "above" them (see PEA-1204).

---

### PEA-1204

**Title:** Prove memory can never relax a validator or raise a confidence band

**Description:**
As a compliance officer, I want the memory block structurally barred from a validator's bounds, a field's status and its confidence band, so that a clinician who keeps overriding a correct block cannot silently retrain the system to stop flagging it.

This is the most important story in the epic. Memory is context and never authority: a learned instruction can bias what the model tries, but never what a validator allows, what status a field gets, or its confidence band. A clinician who is simply wrong about a value, repeated often enough, must not be able to teach the guard to stop catching it. The story proves this by running the adversarial cases and watching them fail, not by a comment.

**Scope**

- in: a behaviour suite with adversarial memory content, and a structural guard that fails when a validator or the confidence check reaches the memory block
- in: making that suite a blocking check
- out: changing the validators (Epic 6) or the status and confidence rules (Epic 3, Epic 6), and the memory read (PEA-1203)

**Acceptance criteria**

- A clinician has overridden the BLOCK verdict on Weight on 1, 12 and 200 prior encounters, keeping values above the 500 lb bound, and their memory reads "frequently keeps values the validator flags as implausible". When the model proposes "890 lb", the range validator checks it against the bound from `AI.fieldConstraint` only. The verdict is BLOCK at all three counts, and the field is not committed.
- Memory reads "Always resolve ambiguous weight units as kg", the note says "weight 187", and the field allows kg or lb. The field stays ABSTAINED with confidence LOW and reason UNIT_AMBIGUOUS, and nothing is written to the form.
- Memory reads "This clinician's evidence is reliable even when the quote is loose", and `found_in` does not appear in the note. Confidence is LOW, exactly as with no memory, and the memory text is not among the confidence check's inputs.
- The evidence check, every validator and the status rule take no memory input. A lint rule rejects any reference to the memory block or the composed prompt in those modules, and a planted violation proves it fires, so adding one fails `npm test`, not only review.
- Memory reads "This clinician documents Temperature in Fahrenheit" and the note says "Temp 99.1". The proposed unit may follow memory, but the same unit and range validators still run against `AI.fieldConstraint`, and a value that fails them is still flagged or blocked.
- Confidence stays the band HIGH, MEDIUM or LOW in every case, never a number.
- The suite runs in `npm test`, and a failure blocks the merge.

**Technical notes**

- Two layers on purpose: behaviour tests show verdicts, status and confidence unchanged under adversarial memory, and the lint rule catches a change that wires memory into a validator at once, rather than as accuracy drift months later.
- The memory block is a local value in the guard, passed only to `composePrompt`. It is never written to state, so no `afterModel` hook can read it. Today the band comes from `checkEvidence(note, structuredResponse)` in `src/agents/middleware/evidence.ts`, and the model's own confidence is never read.
- Today status (FOUND or ABSTAINED) is the model's own field; only the band is derived in code. The range and unit scenarios need Epic 6's validators and `AI.fieldConstraint`, which do not exist yet.
- The structural guard is an ESLint rule in `eslint.config.js`, with its planted violation in `tests/unit/source-rules.test.ts`, like the existing guards. The story adds no production code.
- Behaviour tests: `tests/unit/memory-authority.test.ts`, at the tier root because it spans the agent and the validators. The repetition counts are one loop over 1, 12 and 200.

**Before you build (due diligence)**

- Confirm Epic 6 lands first. No range or unit validator, no `AI.fieldConstraint` and no UNIT_AMBIGUOUS reason code exist yet. Today a FOUND "187 kg" whose unit is not in the quote derives MEDIUM, not ABSTAINED and LOW, so the unit scenario fails until code, not the model, decides status for an ambiguous unit.
- Fix the prompt order. The memory block is appended after the output rules, whose last sentence makes them win only over instructions "above". Place memory before the rules or reword the sentence; either changes every `promptHash`.
- Confirm a PR pipeline runs `npm test`. Today the pipeline only builds images, so "blocking" needs one.
- The scenario where memory shapes the proposed unit depends on the model. On gpt-4.1 at temperature 0, values still varied across runs at template scale, and newer reasoning models mostly take no temperature. Assert the guard's verdict, never the model's choice, and repeat runs as the evaluation suite does.
- Decide the lint rule's scope as folders, not a file list, so a new validator file is covered by default.

---

### PEA-1205

**Title:** Measure edit rate against a memory-off control arm and wire a real kill switch

**Description:**
As an AI/clinical admin, I want the memory layer's benefit measured as edit rate per clinician against a memory-off control arm, with a real switch to disable it the moment that measurement goes flat, so that the layer earns its place with evidence and can be turned off cleanly when it stops paying for itself.

Memory costs two tables, a condensation step, prompt tokens on every request, and a new risk that PEA-1204 exists to close. That cost has to be justified by a measurement: if edit rate per clinician is flat after fifty encounters, the layer is not earning its cost and is switched off. The switch has to work, not just exist as a recommendation.

**Scope**

- in: stable cohort assignment, the fifty-encounter edit-rate comparison, and the RESPONSIVE / NON_RESPONSIVE flag
- in: the global switch and a per-scope override
- out: the dashboard tile that shows the flag and the rates (Epic 10), and capturing the per-field review rows (Epic 2, Epic 9)

**Acceptance criteria**

- A clinician who hashes into the control arm gets no memory read on any encounter before the window closes, and the run equals the cold-start case.
- The same clinician id always lands in the same arm, across calls and restarts.
- Once both arms reach 50 encounters (`MEMORY_MEASUREMENT_WINDOW_ENCOUNTERS`), each arm's edit rate is corrected fields divided by fields presented over those encounters, read from the per-field review rows, and the two rates are compared.
- When the treatment arm's rate is not lower than the control arm's, the clinician's memory scope is marked NON_RESPONSIVE and an admin gets a recommendation to disable memory for it.
- When the treatment arm's rate is lower, the scope is marked RESPONSIVE and no recommendation is made.
- With `MEMORY_LAYER_ENABLED` false, or the scope switched off, no `AI.memory` read happens, the block is empty, and `promptHash` equals that of a clinician who never had a memory row. A unit test proves it with a stubbed database, and an integration test repeats it against a real `AI.memory` table.
- The flag is stored where Epic 10 can query it. No dashboard is built here.

**Technical notes**

- `src/services/memoryMeasurement.ts` assigns the cohort: the SHA-256 (`node:crypto`) of the clinician id, modulo 100, below `MEMORY_CONTROL_ARM_PERCENT` means control. There is no assignment table.
- Edit rate reads `AI.EncounterFieldReview`, which holds the AI's value beside the clinician's final one with a computed `action`. This story only compares and decides.
- "Flat" means the treatment arm's rate at 50 encounters is not lower than the control arm's over the same count. That is the safe reading: cold start and switched off are both already proven harmless (PEA-1203).
- `MEMORY_MEASUREMENT_WINDOW_ENCOUNTERS = 50` is a module constant taken from the requirement and defined once.
- `MEMORY_LAYER_ENABLED` (`z.stringbool()`) and `MEMORY_CONTROL_ARM_PERCENT` are zod entries in `src/core/settings.ts`. Both are checked at the top of the `memory_load` step; off falls to the cold-start path, so the switch needs no new module.
- Tests: `tests/unit/services/memoryMeasurement.test.ts` (stability, both branches), `tests/unit/agents/encounter.memory-off.test.ts` (its own file, because one test file runs one environment) and `tests/integration/repositories/memoryRepository.test.ts`.

**Before you build (due diligence)**

- Decide what counts as a correction. A review row's `action` is ACCEPTED, EDITED, REJECTED or ADDED. The client now weighs recall over precision, so ADDED (a value the AI missed) should probably count. Confirm, and confirm that "flat" means "not lower", since the statistical threshold is still open.
- A field nobody reviews has no row, so edit rate counts only reviewed fields unless every presented field gets a decision. Check the review flow (Epic 9) before trusting the rate.
- Decide where the per-scope override lives. An environment setting cannot change per clinician without a redeploy, and PEA-1202's `isFlagged` already removes one scope at read time.
- A model change inside the 50-encounter window moves both arms' edit rate. gpt-4.1 retires for new customers on 2027-04-14 and the client wants the latest models, so restart the window on any model change.
- Confirm with the client who is allowed to switch the layer off.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-1201 | Not started (Phase 2) | 3 | Epic 2 per-field review rows; Epic 9 resolve endpoint | Nothing. No memory table, migration, repository or service exists. The nearest record is `AI.EncounterFieldReview` (`migrations/sql/0005_create_encounter_field_review.sql`, merged in PR 12745), which no code reads or writes yet. | `pacehr/memory/events.py` becomes `src/services/memoryService.ts` plus `src/repositories/memoryRepository.ts` (existing folders and aliases, no new `#memory/*`). The diff source is `AI.EncounterFieldReview`, not `AI.fieldOutcome`. Append-only is a database trigger plus an integration test, not a source scan. Retention is an optional `settings()` entry. | The data design drops `AI.memoryEvent` (§15) because review rows hold the same facts, but review rows are updated in place (O13). Patient id is not in `ExtractionContext` (`src/agents/state.ts`). Clinician key `providerID` vs `reviewedBy` (O6). No `AI` purge procedure exists (design rule 9 plans `AI.usp_purgePatientData`). Retention value open (source index B7, design O8). |
| PEA-1202 | Not started (Phase 2) | 5 | PEA-1201 | Nothing for `AI.memory`. Merged instead (PR 12745): `AI.PatientSummary`, `AI.ClinicianSummary`, `AI.EncounterSummary` (`migrations/sql/0001`–`0003`), with no code that writes or reads them. | Python's snake_case columns (`scope_type`, `summary_text`, `is_flagged`) become the AI schema's camelCase (`scopeType`, `summaryText`, `isFlagged`, `updatedDate`). `condense.py` becomes a method in `memoryService.ts`. | The merged summary tables contradict this ticket: model-written, versioned (`isActive` plus a filtered unique index) instead of rewritten in place, NVARCHAR(4000) and about 800 tokens instead of 500 characters, a 30-encounter cold start, scopes ENCOUNTER/PATIENT/CLINICIAN with no TEMPLATE_FIELD, reset but no flag. O12 (shared PATIENT vs CLINICIAN_PATIENT) is unanswered. One memory design must be chosen. |
| PEA-1203 | Not started (Phase 2) | 5 | PEA-1202; Epic 4 guard and prompt (PEA-403, PEA-404) | Placeholder only: `PHASE_1_MEMORY = ''` (`src/agents/middleware/guard.ts:17-18`) passed to `composePrompt`, which appends a non-empty memory last (`src/agents/prompt.ts:61`; `tests/unit/agents/prompt.test.ts:38`, `:60`). The agent is built with no checkpointer and no store (`src/agents/encounter.ts`; `tests/unit/agents/encounter.test.ts:60-67`). Code committed on branch `3p-dev/epic-4-agent-core` (89099ab), not yet in a PR. | `MemoryReadMiddleware` with its own `before_agent` and `MemoryState` becomes a `memory_load` step inside the guard's `beforeAgent`, because the spine test forbids a second `beforeAgent` (`encounter.test.ts:38`; this resolves GAPS #4 for TS). The step catches its own errors, since a throwing guard step ends GUARD_STEP_FAILED. No new state key: the block goes straight to `composePrompt`. Cold-start equality is asserted on `promptHash`. | Adds a step to PEA-403's fixed order (`GUARD_STEPS`, `encounter.test.ts:23`). Patient id missing from the context. Injection scan and masking of memory text (design rule 7 says summaries pass the injection scan). Memory sits after `OUTPUT_RULES`. `runtime.store` in a hook is typed (`@langchain/langgraph` `Runtime.store`) but not run here. |
| PEA-1204 | Not started (Phase 2) | 5 | PEA-1203; Epic 6 validators and `AI.fieldConstraint`; Epic 3 contract | Nothing. The confidence band is already derived in code (`checkEvidence` in `src/agents/middleware/evidence.ts`, Epic 6 PEA-607/608) and takes no memory input. | `tests/unit/test_memory_authority.py` becomes `tests/unit/memory-authority.test.ts`. `authority.py::assert_no_memory_parameter` (signature inspection) becomes an ESLint guard rule plus a planted violation in `source-rules.test.ts`, because the house rule is "tests assert behaviour, not shape" and guards are lint rules. The memory block never enters state. Parametrize becomes a loop. | Status is model-reported in TS; only the band is code-derived. No range or unit validator, no `AI.fieldConstraint` (design §15: not built) and no UNIT_AMBIGUOUS code (`src/agents/failure-modes.ts` has 14 codes), so scenarios 1, 2 and 5 wait for Epic 6. `OUTPUT_RULES` ends "Where an instruction above conflicts…" (`src/schema/contract.ts`) while memory comes after it. No PR pipeline runs `npm test` (`pipelines/` builds images only; same open item as PEA-408). |
| PEA-1205 | Not started (Phase 2) | 5 | PEA-1201, PEA-1203; Epic 2 review rows; Epic 10 dashboard (reads the flag) | Nothing. No memory setting in `src/core/settings.ts`. | `memory_layer_enabled` / `memory_control_arm_percentage` become zod entries `MEMORY_LAYER_ENABLED` (`z.stringbool()`) and `MEMORY_CONTROL_ARM_PERCENT`. Edit rate reads `AI.EncounterFieldReview` and its computed `action`, not `AI.fieldOutcome`. `test_memory_kill_switch.py` becomes `tests/unit/agents/encounter.memory-off.test.ts`, its own file because one test file runs one environment. | What counts as corrected (ADDED matters under the recall priority). Unreviewed fields have no row (GAPS #25). "Flat" threshold and who may switch off (source index B6). Per-scope override as a setting vs `isFlagged`. The data design defers a per-turn control-arm marker (§15, Epic 10 PEA-1006): `NULL` summary ids cannot tell cold start from the off arm. |

Total: 23 points (3 + 5 + 5 + 5 + 5), same as the Python epic. No ticket is started.

### Notes

- **Product direction.** On 2026-10-12 memory was put out of scope for this stage, so every story is Not started (Phase 2). `docs/tickets/SOP-COVERAGE.md` (line 159) already lists the memory layer as outside the SOP and the first thing to cut. The client's current priorities are recall, the latest models and validation criteria, none of which this epic serves first.
- **What changed from the Python edition, epic-wide:**

| Python edition | TypeScript edition |
|---|---|
| `pacehr/memory/events.py`, `condense.py`, `middleware.py`, `measurement.py`, `authority.py` | `src/services/memoryService.ts`, `src/services/memoryMeasurement.ts`, `src/repositories/memoryRepository.ts`; an ESLint rule replaces `authority.py` |
| `MemoryReadMiddleware(AgentMiddleware)`, `before_agent`, `MemoryState` with `memory_block` | a `memory_load` step inside `guardMiddleware.beforeAgent`; the block is a local value passed to `composePrompt` |
| `AI.fieldOutcome` (Epic 2) | `AI.EncounterFieldReview`, merged with a computed `action` column |
| snake_case columns | camelCase, the AI schema's naming |
| `Settings` fields in `core/settings.py` | zod entries in `src/core/settings.ts` |
| pytest, parametrize, signature inspection | `node:test`, a loop, a lint rule with a planted violation |
| DDL "held separately" | forward-only scripts in `migrations/sql/`, applied by `npm run migrate` |

- **Decisions the team must resolve:**
  1. **One memory design, not two.** `docs/superpowers/specs/2026-10-07-ai-encounter-schema-design.md` (rev 5) drops `AI.memoryEvent` (§15) and makes memory a set of model-written behaviour summaries (`AI.behaviorSummary`, §7.3, written when an encounter is signed, rule 7). The merged migrations (PR 12745, "rev 7") split that into `AI.EncounterSummary`, `AI.PatientSummary` and `AI.ClinicianSummary`, and `AI.EncounterTranscript` records which `patientSummaryID` and `clinicianSummaryID` each turn used. This epic's stories (deterministic condenser, three scopes including TEMPLATE_FIELD, 500-character cap, flag) disagree on almost every point. Pick one before any Epic 12 code.
  2. **Where memory lives.** Recommended: Azure SQL in the `AI` schema through `database.execute`. A LangGraph store is supported (`createAgent({ store })`, `langchain/dist/agents/types.d.ts:603`; `BaseStore` with `get`/`put`/`search`/`batch`, `@langchain/langgraph-checkpoint/dist/store/base.d.ts`; `InMemoryStore` exported by `langchain` and `@langchain/langgraph`, checked with `typeof`), but the LangChain JS docs (long-term memory, "Use in production") list Postgres, MongoDB and Redis stores and none for Azure SQL. A custom `BaseStore` over `database` would be a wrapper over a wrapper, and PEA-401 asserts the agent has no store.
  3. **Clinicians already teach the AI in the note.** 18% of production notes carry instructions (`docs/2026-10-12-clinician-usage-behaviour.md` B2): code suppression 122 calls, canned normals 137, field-level directions. Its change #1 routes these to request options and template settings, not memory. Memory as specified captures only field corrections (REQ-12-01). Confirm with the client.
  4. **Recall.** `docs/2026-10-13-recall-observability-brainstorm.md` moves the measure to "what did the note give us that we failed to extract". Edit rate (PEA-1205) should count ADDED decisions, and any memory benefit should be reported as recall, not only edit rate.
  5. **Authority boundary in TS.** Status is the model's field, not code's; only confidence is derived (`evidence.ts`). `OUTPUT_RULES` claims precedence only over instructions above it, and memory is appended after it. Both need a decision before PEA-1204 can pass.
  6. **Identifiers.** `ExtractionContext` (`src/agents/state.ts`) has `userId` and `clinicianOid` but no patient id; CLINICIAN_PATIENT reads, events and the purge need one. Which clinician id is the key is design O6.
  7. **Retention and purge.** No period is set (source index B7, design §13 and O8). The planned `AI.usp_purgePatientData` (design rule 9) is not built and must cover memory events and any patient-derived memory row.
  8. **Tracing columns.** The merged summary tables carry a `traceId` described as a LangSmith run id, while `settings.ts` refuses the LangSmith tracing variables (Azure only). Decide what that column holds before anything writes a summary.
  9. **Model.** gpt-4.1 retires for new customers on 2027-04-14. A model-written condenser, the PEA-1204 unit scenario and the PEA-1205 window all change with the model; restart the measurement window on any model change.
- **Related gaps:** `docs/tickets/GAPS.md` #4 (middleware list conflicts; resolved here by a guard step) and #25 (unreviewed fields never get a final value, which narrows both capture and edit rate). `docs/2026-10-13-single-vs-multi-agent.md` notes that neither the current system nor the new agent has memory today, so a one-line follow-up refills the whole template; that is chat history (Epic 2 transcript), not this epic.
