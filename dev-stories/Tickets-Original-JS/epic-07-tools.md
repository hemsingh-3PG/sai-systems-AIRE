# Epic 7 — Agent tools (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Agent tools: computed dates, BMI and code checks, server-side context loading

**Description:** The model reads clinical language and nothing else: it never does date arithmetic, never computes a BMI and never decides whether a code is valid. This epic gives the encounter agent three tools for those jobs, `resolve_date`, `compute_bmi` and `lookup_icd_cpt`. Each is plain TypeScript that the model calls with the words it found in the note. The epic also moves context assembly onto the server: the prompt, the template, the patient's history and the note are read once per request before the model runs, instead of being put together in advance by browser calls. Every tool follows one contract and runs through one tool-call middleware. That middleware logs each call without its values, turns an unexpected failure into a safe message, and records each refusal in run state. Validators stay out of tools, because a tool the model may decline to call cannot prove a check ran.

### PEA-701

**Title:** Build the shared tool contract: registration, tool-call hook, logging, failures

**Description:**
As a platform engineer, I want every tool built to one contract and run through one tool-call middleware, so that adding the next tool never means rediscovering how its description reaches the model, inventing a new log shape, or letting a thrown error end a run.

The model reads only two things about a tool: its `description` and the `.describe()` text on each schema field. The prompt does not repeat them. LangChain raises no error when one is missing, and the model simply has less to go on, so only a unit test catches it. Failures have a trap too. Without a tool-call hook, LangChain turns a thrown tool error into a message that quotes the error text back to the model. With a hook, an error that escapes the hook rejects `invoke` and skips the audit hook. One middleware means logging, failure handling and refusal recording are each done in one place.

**Scope**

- in: the `TOOLS` registration list passed to `createAgent`
- in: the tool-call middleware (`wrapToolCall`) and its place in the spine
- in: a per-call outcome record in run state
- in: a contract test over every registered tool
- out: the tools themselves (PEA-702 to PEA-704) and the context loads (PEA-705)
- out: the field checks that read tool outcomes (Epic 6), and the hook order rules (Epic 4)

**Acceptance criteria**

- Every tool in `TOOLS` reaches the model with a non-empty description and a description on every parameter. A unit test checks the captured request, and a planted tool with a missing description makes that test fail.
- Each tool's parameters on the wire are exactly its declared fields, with `additionalProperties: false`. No run fact, such as the date of service, the account or an id, appears as a parameter.
- Every tool call writes one log line with the run id, the tool name, the outcome and the latency. The line contains no argument, no result and no error message. A test puts a clinical string in all three and checks the line.
- A tool that throws does not end the run. The model gets an error `ToolMessage` with a fixed text and the matching `tool_call_id`. The run continues and the outcome hook still runs. The error text never reaches the model or the log.
- A turn with no tool call does not run the tool-call hook and writes no tool log line.
- A refusal the tool returns on purpose, for example from `compute_bmi` when the weight has no unit, is recorded in state with the tool name and the reason code. A `Command` writes it together with the `ToolMessage`. A later hook can read the refusal without relying on how the model retells it.
- The spine still has one definer per hook and no `beforeModel`. The tool-call middleware comes before the outcome middleware.

**Technical notes**

- `src/agents/middleware/tool-call.ts` defines the middleware. `src/agents/encounter.ts` adds it to `MIDDLEWARE` and exports `TOOLS`, which goes to `createAgent({ ..., tools: TOOLS })`. `ExtractionState` gains `toolOutcomes`: tool name, outcome and reason code per call, and never a value.
- Tool modules live in `src/tools/`, under a new `#tools/*` alias, and the unit import proof adds that folder. A tool is `tool(fn, { name, description, schema: z.object(...) })` from `langchain`. It reads run facts from its second argument, `runtime.context` (the validated `ExtractionContext`), never from arguments the model supplies.
- An expected outcome, such as a missing unit or a phrase the tool cannot parse, is a returned result with a named reason code. A throw means something unexpected, such as an I/O error. The middleware catches only throws.
- The hook never throws. `ToolNode` re-raises any error that escapes `wrapToolCall`, and that rejects `invoke` and skips `afterAgent`.
- `langchain` also ships `toolErrorMiddleware`. It is not used, because it would be a second middleware defining `wrapToolCall`.
- Tests: `tests/unit/agents/middleware/tool-call.test.ts` and the tool-round tests in `tests/unit/agents/encounter.test.ts`. They reuse `stubDeployment`, `completion` and `captureLog` from the test harness.

**Before you build (due diligence)**

- Run one live tool round on the DEV deployment: tools and the strict `json_schema` response format in the same request, with the final reply still parsed. Repeat it on whichever newer model the client picks. Reasoning models may limit tool calls in Chat Completions, for example to one reasoning-effort setting.
- Decide `parallel_tool_calls` and tool `strict`. The tool wire shape today carries no `strict`. Check whether the deployment accepts strict tools together with parallel calls. Check whether `modelSettings` carries `parallel_tool_calls` to the wire, because a per-call temperature was measured not to reach it.
- Check in `langchain` 1.5.14 what happens when two refusals in one turn write the same state key in the same step. Then use a reducer or one call per turn, whichever the run shows works.
- Decide how the middleware reads a refusal: parse the `ToolMessage` JSON, or return the code as an artifact (`responseFormat: 'content_and_artifact'`) so the model never sees it.
- Measure the added tokens and latency of one tool round on template 457, where each extra model call sends the prompt, the note and the schema again. Set a limit on tool rounds per run from that number.

---

### PEA-702

**Title:** Resolve dates from the date of service, never from today

**Description:**
As a clinician, I want a relative date in my note resolved from the encounter's date of service, so that a note about "symptoms three days ago" is never dated from whatever the model believes today is.

A model has no clock, and nothing in its input tells it the server's date. The only date the system can trust is the one on the encounter. Today the stored prompt gets the date of service filled in, and a prompt that asks for today's date blocks the run, but the model still does the arithmetic itself. `resolve_date` takes the exact phrase from the note and does the calendar arithmetic in code, from the date of service in the run context.

**Scope**

- in: `resolve_date`: the phrase forms it accepts, the arithmetic, and two refusal codes
- out: whether the resolved date is plausible (Epic 6 date checks)
- out: where a resolved date lands in the output (Epic 3 contract)

**Acceptance criteria**

- With date of service 2026-09-21 and the phrase "three days ago", the tool returns 2026-09-18.
- With date of service 2026-09-21, a Monday, and the phrase "last Tuesday", the tool returns 2026-09-15.
- "a while back" returns a refusal with reason code DATE_EXPRESSION_UNRESOLVABLE and no date.
- With no date of service in the run context, the tool returns REFERENCE_DATE_MISSING. It never falls back to the server clock.
- The same phrase and date of service give the same answer with the test clock set to two far-apart instants.
- The model passes only the phrase. The anchor date is not a tool parameter, so the model cannot supply a different one.
- The result carries the phrase with the date, so the evidence trail keeps the note's own words.

**Technical notes**

- `src/tools/dates.ts`, built to PEA-701's contract. Its one parameter is `expression`, the phrase exactly as written in the note. The anchor is `runtime.context.dateOfService`, an ISO date the context schema has already validated.
- The arithmetic works on UTC calendar dates built from that ISO string only. The module has no `Date.now()`, no `new Date()` without an argument, and no time-zone read. A clock fallback is the defect this tool replaces, so it counts as a bug, not a graceful fallback.
- The accepted phrase forms and the reason codes are exported constants. A phrase outside those forms is refused, never guessed.
- The tool is a pure function, with no database and no network. Tests: `tests/unit/tools/dates.test.ts`, with the clock set through `t.mock.timers`.
- Dates of service are outside Epic 5's masking scope, so masking does not touch the argument or the result.

**Before you build (due diligence)**

- Collect the relative phrases clinicians actually write, from DEV notes or the production usage data ("x3 days", "POD 2", "in 1 week", "next visit"). Fix the accepted forms from that list, not from memory.
- Confirm with the clinical lead what "last Tuesday" means when the date of service is mid-week: the most recent Tuesday, or the Tuesday of the week before.
- Confirm that `runtime.context` reaches a tool in `langchain` 1.5.14. It is typed in `@langchain/core` but has not been run. Also confirm that `t.mock.timers` mocks `Date` without a flag on Node 22.13.
- Decide where a resolved date goes. The output rules say a value is copied from the note, and the evidence check rates a value that is not in its quote as MEDIUM, so a computed date would always go to review. The agent fills template fields only, and the follow-up date the current system adds sits outside the template.

---

### PEA-703

**Title:** Refuse BMI computation on a missing unit

**Description:**
As a clinician, I want the system to refuse to calculate a BMI when the note doesn't state a unit for height or weight, so that a wrong guess at the unit never becomes a made-up vital sign on my patient's chart.

A number computed from a guessed unit looks exactly as trustworthy as a correct one. The output rules already tell the model to abstain on a bare weight with no unit. `compute_bmi` applies the same rule to its own inputs. The refusal path is the reason the tool exists, and the arithmetic is the easy part.

**Scope**

- in: `compute_bmi`, its known unit sets and its three refusal codes
- out: whether a computed BMI is plausible (Epic 6 range and cross-field checks)

**Acceptance criteria**

- 68 in and 180 lb return a BMI of 27.4.
- A weight of 187 with no unit returns UNIT_MISSING_WEIGHT and no number.
- A height of 170 with no unit returns UNIT_MISSING_HEIGHT and no number.
- A unit outside the known sets, such as "stone-ish", returns UNIT_UNRECOGNIZED. The tool never converts from the nearest known unit.
- A value that computes but is implausible, such as a BMI of 8, is returned as computed. Plausibility is Epic 6's job.
- A refusal is recorded in run state (PEA-701), so the BMI slot is never written as FOUND with a computed value. Epic 6's check keeps the slot ABSTAINED and puts it in front of the clinician.

**Technical notes**

- `src/tools/bmi.ts`, built to PEA-701's contract. Its parameters are `heightValue`, `heightUnit`, `weightValue` and `weightUnit`, and each unit is a nullable string.
- In the schema a unit is any string, not an enum. That way an unknown unit reaches the tool and is refused as UNIT_UNRECOGNIZED instead of failing argument parsing. There is no default unit.
- These are exported constants: the known units (height `in`, `cm`, `m`; weight `lb`, `kg`), the conversion factors, the rounding (one decimal place) and the reason codes.
- The tool is a pure function. Tests: `tests/unit/tools/bmi.test.ts`.

**Before you build (due diligence)**

- List the BMI, height and weight fields in DEV templates (template 457 has BMI as `s7_f53`). Collect how notes write the units: "5 ft 4 in", "5'4\"", "lbs", "kg.". Decide which spellings map to a known unit and which are refused.
- Decide how a refusal is tied to a slot. A tool call carries no slot key today, so Epic 6 cannot yet tell which slot a refusal belongs to.
- The evidence check lists for review only FOUND slots below HIGH, so an ABSTAINED slot is not listed. Confirm with Epic 6 that an ABSTAINED BMI still reaches the clinician.
- A note can quote a BMI from the chart, such as "BMI 31.2 per chart". Decide with the clinical lead whether the quoted value or a computed one wins.

---

### PEA-704

**Title:** Check ICD/CPT format and require sign-off without a licensed code set

**Description:**
As a compliance officer, I want `lookup_icd_cpt` to state plainly that it checked only a code's format when no licensed ICD/CPT code set is configured, so that a clinician never skips signing off a diagnosis or procedure code in the belief that the system already verified it.

To check that a code exists, can be billed and is valid for the Place of Service, the tool needs a licensed ICD/CPT reference set, and this project has none. A tool that claimed more would give false confidence exactly where billing and compliance risk is highest. Without the licence, the tool checks the code's structure only, and every code it sees needs a human sign-off. That limit is the Phase 1 behaviour, and the response itself states it.

**Scope**

- in: format checks for ICD-10-CM and CPT code shapes, and the `mode` field
- in: a named, unimplemented seam for a licensed lookup
- out: the licensed code set itself (procurement and licensing, outside this backlog)
- out: generating codes, and showing the review reason on screen (Epic 9)

**Acceptance criteria**

- "E11.9" with no licensed set returns status FORMAT_OK_UNVERIFIED and mode DEGRADED. The response says that existence, billability and Place-of-Service validity were not checked.
- "E1119" returns FORMAT_INVALID.
- CPT shapes are checked as well as ICD-10-CM: five digits for Category I, and four digits plus F or T for Categories II and III.
- Every response carries `mode`, and in Phase 1 it is always DEGRADED.
- For any well-formed code, the status is never VALID while the mode is DEGRADED.
- A FORMAT_OK_UNVERIFIED code is never accepted without review. The review reason reads "code format only, not verified against a licensed set".

**Technical notes**

- `src/tools/coding.ts`, built to PEA-701's contract. These are exported constants: the status values, the mode, the review reason text and the format patterns.
- The licensed-lookup seam is one named function with no implementation. Wiring in a real lookup later changes none of the tool's parameters. No setting is added until a licensed set exists.
- A format check never implies that the code exists, can be billed or is valid for the Place of Service.
- The tool is a pure function. The patterns are module constants, so it reads no file and no database. Tests: `tests/unit/tools/coding.test.ts`.

**Before you build (due diligence)**

- Confirm with the client where codes appear in the new output. The agent fills template fields only. The current system's ICD and CPT sections sit outside the template, so today no slot would hold a code.
- A tool the model may decline to call cannot prove a format check ran. Agree with Epic 6 that its `afterModel` check runs the same format function on every coded slot, so the tool only helps the model.
- Collect the code spellings clinicians type in DEV notes: with or without the dot, lower case, in brackets. About 26% of notes carry an ICD-10 code and 36% a CPT code. This ticket treats "E1119" (no dot) as FORMAT_INVALID, so decide whether a missing dot is normalised first.
- Confirm with compliance that "format only, sign-off required" is acceptable for Phase 1, and name who owns the licence question.

---

### PEA-705

**Title:** Load prompt, template, history and note context once per request on the server

**Description:**
As a clinician, I want the agent to load the current prompt, the template, my patient's earlier history and the saved note on the server for each request, so that what the AI sees matches the live record and not a snapshot that separate browser calls put together earlier.

Today the browser calls `getPrompt`, `getPreviousEncounterDetails`, `getImportPatientDetailsToEncounterForm` and `getRoundingNotesByEncounter` before the model runs, guessing what it will need. The agent already reads the prompt and the template itself, once per request, in its guard steps. This story adds the patient's history and the note the same way. These loads are plain reads in `beforeAgent`, not tools the model can call, because a load the model may skip cannot prove the context was there.

**Scope**

- in: the prompt and template loads (built)
- in: a history load that replaces both legacy history calls, and a note load that replaces `getRoundingNotesByEncounter`
- in: scanning and masking the loaded text before any model call
- out: prompt versioning (Epic 8), schema rules (Epic 3) and masking rules (Epic 5)
- out: retiring the browser calls (UI team), and any write to clinical tables (never)

**Acceptance criteria**

- The prompt is the row returned by `dbo.usp_getPrompt`, the same procedure the browser's `getPrompt` calls, read once per request (built).
- The template configuration is read live on every request, so a field edited a minute earlier is in that request's schema (built).
- The history load returns the patient's earlier encounter summaries and imported detail fields together, in one result.
- The note load returns the exact text stored for the encounter. A missing note blocks the run as NOTE_NOT_FOUND before any model call. An empty string is never treated as a note.
- A patient with no history is recorded as having none, which is different from a failed read. A failed read ends the run as GUARD_STEP_FAILED.
- Each load runs exactly once per request, in the guard, whatever the model does. A tool round does not repeat it.
- Loaded history goes through the same injection scan, size limit and PHI masking as the note before any model call. The request sent to the model contains no unmasked identifier from it.
- No log line contains history or note text. Logs carry ids and counts only.

**Technical notes**

- `src/agents/middleware/guard.ts` already runs `template_load` (`templateService.getAIConfig`) and `prompt_load` (`GET_PROMPT_SQL`). This story adds `note_load` and `history_load` before `injection_scan`, so the loaded text passes every check the note passes.
- Each read is one `*_SQL` constant run through `database.execute` with `@name` parameters. History rows are mapped in a repository, following `templateRepository`. No read opens its own connection, and none writes.
- NOTE_NOT_FOUND joins the GUARD reason codes in `src/agents/failure-modes.ts`.
- The loads take their keys from the run context, never from the model.
- Tests: step order and blocks in `tests/unit/agents/encounter.test.ts`, repository tests under `tests/unit/repositories/`, and one live read per load under `tests/integration/`.

**Before you build (due diligence)**

- Find the procedures or tables behind `getPreviousEncounterDetails`, `getImportPatientDetailsToEncounterForm` and `getRoundingNotesByEncounter` in DEV, read only. Check their columns with `information_schema.columns`.
- Confirm with the UI team and Epic 9 whether the request carries the note, as it does today (`note`), or the agent reads it by encounter. `getRoundingNotesByEncounter` may return earlier rounding notes, not the note being processed.
- Decide where history goes in the model call: a second user message or a prompt placeholder. Decide what limits its size, because the 20,000-character limit covers the note only. Also note that no hash records history text today.
- The client expects patient history later, not in the demo, so agree the order with them. The run context has no patient id today, so decide how the history load finds the patient.
- With Epic 5: masking passes text through unchanged today, so the history check needs a seeded masker, as the note check does. Note and history must share one token map.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-701 | Not started (later sprint) | 5 | PEA-402 (Epic 4, done) | Nothing yet. `createAgent` in `src/agents/encounter.ts` gets no `tools`. `MIDDLEWARE` has 4 entries and no `wrapToolCall`, and the comment above it keeps a slot for Epic 7. The only tool is a test-only fake `resolve_date` (schema `{ phrase }`) in `tests/unit/agents/encounter.test.ts`. It proves the round model → tool → model, with the same system prompt both times and usage summed. | `@tool(parse_docstring=True)`, Google-style `Args:` and the `ValueError`-at-import check are replaced by `tool(fn, { name, description, schema })` and a unit test over the captured request. In JS a missing description fails nothing at runtime. The `@tool`/`@staticmethod` ordering spike is dropped, because a JS tool is a plain function with no `self`; the wire-parameters check replaces it. Registration is `TOOLS` in `encounter.ts`, not a package `__init__`, because there are no barrel files. The hook lives in `src/agents/middleware/tool-call.ts` beside the other middleware, not under the tools folder. The tool-call id is `request.toolCall.id` in the hook and `runtime.toolCallId` inside a tool. Depends on PEA-402 instead of "none". | PEA-401's note "no tool is compiled in" changes once `TOOLS` is passed. This closes `docs/tickets/GAPS.md` #26 (tools unreachable). Read in `langchain` 1.5.14, `dist/agents/nodes/ToolNode.js`, but not run: without `wrapToolCall`, a thrown tool error becomes a `ToolMessage` holding the error text plus "Please fix your mistakes."; with one, an error escaping the hook is re-raised. Not measured: parallel refusals writing one state key, a live tool round under strict `json_schema`, and the token cost of a round. The fake's `phrase` parameter becomes `expression` when the real tool replaces it. |
| PEA-702 | Not started (later sprint) | 3 | PEA-701 | Nothing. Related, already built: `composePrompt` (`src/agents/prompt.ts`) fills `<<DOSDate>>` from `dateOfService` and never fills `<<todayDate>>`, so a stored row that asks for today blocks as PROMPT_PLACEHOLDER_UNFILLED. | `reference_date` is no longer a tool argument. The anchor is `runtime.context.dateOfService`, already validated by `ExtractionContext` as `z.iso.date()`. REFERENCE_DATE_MISSING stays for a call with no context. The `datetime.now()` ban becomes "no `Date.now()` or argument-less `new Date()`", proven by a mocked clock at two instants. It is not a source scan, because the repo's tests check behaviour. `relative_expression` → `expression`. | Output-contract conflict: `OUTPUT_RULES` (`src/schema/contract.ts`) says a value is copied from the note, and `src/agents/middleware/evidence.ts` rates a value not in its quote as MEDIUM. The current system's follow-up date is outside the template, and the current system invented it in Q4 and Q5 (`docs/2026-10-12-five-query-comparison.md`). The phrase forms have no data behind them yet. `ToolRuntime.context` is typed (`@langchain/core` 1.2.13, `dist/tools/types.d.ts:354`) but not run. |
| PEA-703 | Not started (later sprint) | 2 | PEA-701 | Nothing. Template 457 has a BMI slot, `s7_f53` (section Vitals4), seen in `PacEHR_AI/logs/run-457-20261013-182850.csv`. | A `None` unit becomes `null`. Snake_case arguments become camelCase (`heightValue` and the rest). Units are free strings, not a zod enum, so UNIT_UNRECOGNIZED can be reached. "after_model assigns verdict review": there is no verdict field in TS yet. Epic 6's `evidence.ts` keeps `status` FOUND or ABSTAINED and a `reviewSlots` list. | `reviewSlots` lists only FOUND slots below HIGH, so an ABSTAINED BMI is not listed. Nothing maps a tool call to a slot key. The manual sample note (`tests/manual/agentResponse.manual.ts`) says "BMI 31.2 per chart" with height "last recorded", so stated versus computed BMI is undecided. |
| PEA-704 | Not started (later sprint) | 3 | PEA-701 | Nothing. | The format patterns are module constants, not data read through a `core/` singleton, because there is nothing to read. The seam is a named, unimplemented function, not a settings flag, because CLAUDE.md allows no setting that nobody sets. "Never an accept verdict" becomes "never accepted without review"; Epic 6 owns the verdict words. | The agent's output has no ICD/CPT slot: the template has none, and the current system's code sections sit outside it (`docs/2026-10-12-five-query-comparison.md`; Q5's CPT 99327 was deleted from CPT in 2023). `docs/tickets/GAPS.md` #18: a coded field checked only by a tool cannot prove the check ran. SOP 5.1 code generation is not built (`docs/tickets/SOP-COVERAGE.md`). The licence is outside this backlog. |
| PEA-705 | Partly done | 5 | PEA-403 (Epic 4, done); Epic 5 masker; Epic 9 request body | Prompt and template are built. `src/agents/middleware/guard.ts` steps `template_load` (`templateService.getAIConfig`, `src/services/templateService.ts`) and `prompt_load` (`GET_PROMPT_SQL` = `dbo.usp_getPrompt`) run once per request. They are tested in `tests/unit/agents/encounter.test.ts`: step order, TEMPLATE_UNAVAILABLE, PROMPT_NOT_FOUND, PROMPT_AMBIGUOUS. The history and note loads are not started. The note arrives in the request (`EncounterRequest.note` → `noteText`). | The four `@tool` functions become guard steps, not tools. The Python acceptance criteria already required them to run once during context assembly, whatever the model did, and `docs/tickets/GAPS.md` #8 flagged the contradiction. The mapping: `resolve_prompt` → `prompt_load`, which has no fragments (the stored row with placeholders, Epic 4 PEA-404); `load_encounter_template` → `template_load`; `load_patient_history` → `history_load`; `load_note_text` → `note_load`. Depends on PEA-403 instead of PEA-701. `aexecute` → `database.execute`. NOTE_NOT_FOUND is added. The loads run before `phi_mask` in the same hook, which by design closes `GAPS.md` #13 (unmasked text on the second pass). | Patient history is a later client feature, not in the demo. `ExtractionContext` has no patient id. An empty `note` is not blocked today, because no step checks it. The 20,000-character limit (`src/guards/limits.ts`) covers the note only. Masking passes text through until Epic 5 lands. |

Total: 18 points.

### Notes

- **What changed from the Python edition, epic-wide**
  - Tool declaration: `@tool(parse_docstring=True)` with a docstring becomes `tool(fn, { name, description, schema: z.object(...) })` from `langchain`, with `.describe()` on each field. The description is the tool's API (truth §6; `PacEHR_AI/CLAUDE.md` § The agent).
  - JS has no `@staticmethod` question, so the ordering spike is gone.
  - Run facts come from `runtime.context`. `ToolRuntime` also has `toolCallId`, `state` and `config` (read: `@langchain/core` 1.2.13 `dist/tools/types.d.ts:354`). The hook request has `toolCall`, `tool`, `state` and `runtime` (truth §4).
  - `ToolMessage` comes from `langchain` and `Command` from `@langchain/langgraph` (truth §2, §4.6).
  - Folders: tools in `src/tools/` with a new `#tools/*` alias, and the middleware in `src/agents/middleware/`. Tests mirror source (`tests/unit/tools/*.test.ts`) and run under `node:test`. Frozen clocks use `t.mock.timers`.
  - The four context tools are guard steps (PEA-705). Two of them already exist.
- **Status checked** by reading the code in `PacEHR_AI` on 2026-10-14. No Epic 7 code exists outside the PEA-705 guard steps. No tests were run for this epic, because there is nothing to run.
- **Decisions the team must make**
  1. **Computed values against the output contract.** `OUTPUT_RULES` says a value is copied from the note, and the evidence check (`evidence.ts`, Epic 6 PEA-607/608) rates a value not in its quote as MEDIUM. A resolved date or a computed BMI would therefore always go to review. Decide whether tool results get their own provenance, for example a value matched against a recorded tool outcome, before PEA-702 or PEA-703 changes any output.
  2. **Tool calls and slots.** A tool call names no slot, `reviewSlots` skips ABSTAINED slots, and TS has no verdict field. Epic 6 has to define how a refusal reaches a slot.
  3. **Codes and follow-up are outside the template.** The new agent fills template fields only, while the current system adds ICD, CPT and a follow-up date separately (`docs/2026-10-12-five-query-comparison.md`). Clinicians also suppress codes: "Do not add any ICD-10 codes" appeared in 122 calls (`docs/2026-10-12-clinician-usage-behaviour.md`). Confirm with the client whether the output carries codes and a follow-up date at all. Until then, PEA-704 and part of PEA-702 have nowhere to write.
  4. **Validators stay out of tools.** Epic 6 should run the same BMI and format functions on every relevant slot in `afterModel`, and the tools only help the model (`docs/tickets/GAPS.md` #18). `docs/2026-10-13-single-vs-multi-agent.md` rejected the supervisor option (E), which wraps subagents as tools, for the same reason: a specialist the supervisor may decline to call cannot prove its work ran.
  5. **Model change.** gpt-4.1 retires on 2027-04-14, and newer models are reasoning models. Before PEA-701 merges, verify tool calling and strict `json_schema` together on the chosen deployment. The multi-agent study says "Azure doesn't support parallel function calls with structured outputs" and "gpt-5.6 allows tools in Chat Completions only at `reasoning_effort: none`". Neither is verified here.
  6. **Cost of a tool round.** Each extra model call sends the prompt, the note and the schema again: about 20.6K tokens of prompt and schema on template 457 (`src/guards/limits.ts`). Measure one round before tools go live, and decide a per-run limit.
  7. **Patient history timing.** The client expects patient integration later, not in the demo. It needs a patient id in the run context and a decision on where history sits in the model call. If on-demand history is wanted later (the Python title said "on demand"), that would be a model-callable tool on top of the guard step, and it would carry the "cannot prove it ran" caveat.
- **Recall note.** The client now cares more about recall than precision (2026-10-12 feedback). None of these tools raises recall directly. PEA-702 and PEA-703 move arithmetic out of the model, so their effect on recall depends on decision 1.
