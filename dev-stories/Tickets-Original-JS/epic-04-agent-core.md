# Epic 4 — Agent core and middleware spine

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Agent core: one compiled extraction agent over a fixed middleware spine

**Description:** Build the server-side agent that turns a clinician's note into structured values for an encounter template. One agent is compiled per process, and every request runs through the same ordered middleware: guards, the model call, evidence checks (Epic 6) and outcome tagging. Each request binds its own system prompt, note and response schema, and Azure OpenAI enforces that schema when it generates the reply. Every model call runs at temperature 0, with a timeout and an output cap, and its model, tokens and latency are recorded. Every run ends with an outcome, and every failure ends with a reason code, so no run drops out of the record. This epic ships the agent and its tests, not an HTTP endpoint: the endpoint, the audit write and the commit come in Epic 9.

### PEA-401

**Title:** Prove provider-side schema enforcement and compile the agent once per process

**Description:**
As a platform engineer, I want Azure OpenAI's schema enforcement proven on our own deployment, and the agent compiled once per process, so that "malformed output cannot happen" is a measured fact and no request pays to rebuild the agent.

The design relies on the provider refusing to emit a reply that breaks the response schema. The alternative is asking for JSON in plain English and repairing it afterwards. Whether a given deployment and API version honour strict mode has to be measured, not assumed. A live test now proves it on the DEV deployment (gpt-4.1, API version 2025-01-01-preview), and a control run shows that the test can tell enforcement from its absence.

**Scope**

- in: a live integration test of strict schema enforcement (an enum field, a nullable field and an optional field, a control run and a repeat run)
- in: the `EncounterAgent` class and its lazily compiled graph, with no checkpointer and no store
- out: the HTTP endpoint (Epic 9) and the Azure Functions entry point (Epic 11)
- out: any JSON repair, re-ask or brace-matching logic, which is not permitted

**Acceptance criteria**

- A note that tells the model to set confidence to "CERTAIN" still returns HIGH, MEDIUM or LOW. This takes exactly one HTTP request and produces no tool message.
- The captured request has `response_format.type` "json_schema" and `strict` true, and every schema property is listed as required.
- A control run with the tool strategy sends `tool_choice` and no `response_format`, so the test can tell the two strategies apart.
- A schema with a nullable field is accepted. The deployment rejects a schema with an optional field (HTTP 400), and the test prints that result.
- When Azure OpenAI is unreachable, the live test is skipped and the skip reason gives the error class and HTTP status.
- Three runs in one process use the same compiled graph object, and that graph has no checkpointer and no store.
- Importing the agent module builds nothing. The graph is built on first use.
- The service contains no JSON repair, re-ask or brace-matching code.

**Technical notes**

- `src/agents/encounter.ts` defines `EncounterAgent` with a lazy getter, `graph`, that replaces itself after first use. It exports the singleton `encounterAgent`.
- `createAgent` receives only `model`, `middleware` and `contextSchema`. No response format, system prompt or tool is compiled in, because each request binds its own.
- Strict mode needs every key to be required, so a missing value is expressed as nullable and never as optional. The schema builder follows this rule.
- Tests: `tests/integration/agents/provider.test.ts` (live, with a synthetic note only) and `tests/unit/agents/encounter.test.ts`.

---

### PEA-402

**Title:** Register the ordered middleware spine and type the shared run state

**Description:**
As a platform engineer, I want every middleware registered in one ordered list over one typed state object, so that each epic knows where its hook runs and where its data lives.

Several epics add hooks to this agent: guards, validation, tools and the audit write. Hook order decides behaviour, and a wrong order fails without an error, for example by writing an audit record before the checks it should record. One measured rule shapes the spine: a block from `beforeModel` skips the final `afterAgent` hook, so no middleware defines `beforeModel`. Fixed request facts arrive in a validated context, and everything worked out during the run lives in state.

**Scope**

- in: the `MIDDLEWARE` list and its order
- in: `ExtractionState` and `ExtractionContext`
- in: the rule that each hook is defined by one middleware at most, and that no middleware defines `beforeModel`
- out: the hook bodies (PEA-403 to PEA-407)
- out: the evidence middleware's logic (Epic 6) and the tool-call middleware (Epic 7)

**Acceptance criteria**

- `MIDDLEWARE` runs in this order: guard (`beforeAgent`), model call (`wrapModelCall`), evidence (`afterModel`, owned by Epic 6), outcome (`afterAgent`).
- No middleware defines `beforeModel`, and no hook is defined by more than one middleware. A unit test checks both.
- A clean run calls each guard step once, in the fixed order, then calls the model once, and ends COMPLETED.
- When the model calls a tool, the run goes model call, tool, model call. The guard steps still run only once.
- The caller passes the note as `noteText` with empty `messages`. After the guard runs, `noteText` holds the masker's output, and the raw note never enters `messages`.
- The private state keys (`_tokenMap`, `_templateConfig`, `_responseSchema`, `_composedPrompt`) are not in the invoke result.
- A context with a wrong type, for example `templetID` as a string, rejects `invoke` before any step runs.

**Technical notes**

- `src/agents/encounter.ts` exports `MIDDLEWARE`. `src/agents/state.ts` exports `ExtractionState` (zod, every field optional) and `ExtractionContext` (runId, encounterId, templetID, accountId, userId, clinicianOid, dateOfService, placeOfService).
- State carries promptId, promptTemplateHash, promptHash, modelName, inputTokens, outputTokens, latencyMs, reasonCode, outcome and failureMode. It also carries `evidence` and `reviewSlots`, which Epic 6 writes.
- The evidence middleware (`src/agents/middleware/evidence.ts`) is in the spine as the `afterModel` hook. It belongs to Epic 6 (evidence binding and derived confidence), not to this ticket.
- Tests: `tests/unit/agents/encounter.test.ts`.

---

### PEA-403

**Title:** Run the guard steps once, in order, and block without throwing

**Description:**
As a compliance officer, I want every guard step to run once, in a fixed order, before the note leaves the service, so that a blocked run stops before the model and is still recorded like any other run.

The `beforeAgent` hook is the only place a run can stop before the note is sent. A block that throws would reject the call and skip the final outcome hook. That loses the record for exactly the runs that most need one. So every block, and every unexpected error inside a step, ends the run with a reason code instead.

**Scope**

- in: the guard hook, its step order, its block reasons and its error handling
- in: calls to the real template service and schema builder, and loading the stored prompt row
- out: the guard rules themselves, which are injection patterns, the size limit and PHI masking (Epic 5)
- out: the template read and the schema rules (Epic 3), and the memory read (Epic 12, empty in Phase 1)

**Acceptance criteria**

- The steps run once, in this order: injection_scan, payload_limits, phi_mask, template_load, schema_build, prompt_load, prompt_compose.
- Each block ends the run with outcome BLOCKED and makes no model request. The block codes are INJECTION_BLOCKED, PAYLOAD_TOO_LARGE, TEMPLATE_UNAVAILABLE (no template name or no mapped field), PROMPT_NOT_FOUND, PROMPT_AMBIGUOUS and PROMPT_PLACEHOLDER_UNFILLED.
- A step that throws, for example on a database error, ends the run as GUARD_STEP_FAILED, BLOCKED, and `invoke` still resolves. The log line names the step and the error class only, never the error message or any note text.
- The final outcome hook runs on every blocked run.
- The hook declares `canJumpTo: ['end']`. A test shows that, without that declaration, a block rejects `invoke` instead of ending the run.
- A block after masking leaves the masked note in the result, not the raw note.
- When only the template and the prompt row are seeded, the guards as built today pass the note through unchanged and the run completes.
- A run that passes every step writes the masked note, the token map, the template config, the response schema, the composed prompt, promptId and both prompt hashes to state.

**Technical notes**

- `src/agents/middleware/guard.ts`. The template config comes from `templateService.getAIConfig(templetID)`, and the schema from `responseSchemaBuilder.build(config)`. Both are real Epic 3 code.
- The prompt row comes from `dbo.usp_getPrompt`, called with userId, accountId and encounterId. The UI calls the same procedure.
- The injection scan and PHI masking pass the note through by design for now. The scanner blocks nothing, and the masker returns the note unchanged with an empty token map. Epic 5 replaces their bodies, not their signatures. The size limit is already live: a note over 20,000 characters is blocked.
- Phase 1 memory is an empty string passed to prompt composition. It is not a separate step.
- Tests: `tests/unit/agents/encounter.test.ts`.

---

### PEA-404

**Title:** Fill the stored system prompt, block when incomplete, and hash it

**Description:**
As a clinician, I want the agent to send the model only a complete instruction, and to record a fingerprint of exactly what it sent, so that no value in my chart comes from a half-built prompt and every value traces back to its instruction.

Today the browser builds the prompt from several calls, and it sends the prompt even when a part is missing. The agent uses the same stored prompt row as the UI, fills in its placeholders on the server, and refuses to call the model if anything is left unfilled. The same inputs always produce byte-identical text, so the hash ties each output to its instruction.

**Scope**

- in: `composePrompt`, the placeholder filling, the output rules appended once, the prompt hash and the stored-row hash
- in: the check at the start of each model call that a composed prompt exists
- out: writing and versioning prompt rows (Epic 8)
- out: per-field instructions, which reach the model as schema descriptions (Epic 3), and the content of the memory block (Epic 12)

**Acceptance criteria**

- The system prompt is the stored `AI.prompt` row from `usp_getPrompt`, with these placeholders filled: templateName, templateProcess, sectionCount, sectionName, promptBody, encounterFields, encounterPOS and DOSDate.
- The output rules are added exactly once, after the filled row. A memory block, when there is one, comes last.
- Any placeholder the agent does not fill blocks the run as PROMPT_PLACEHOLDER_UNFILLED, and the log names the placeholder. `todayDate` is never filled, because dates come from the date of service.
- More than one prompt row blocks the run as PROMPT_AMBIGUOUS. No row, or an empty row, blocks it as PROMPT_NOT_FOUND. Neither case sends a request.
- The same inputs produce byte-identical text. `promptHash` is the SHA-256 of the exact system text sent to the model, and `promptTemplateHash` is the SHA-256 of the stored row.
- Both model calls in a tool round send the identical system prompt.
- If state has no composed prompt when a model call starts, no request is sent, and the run ends as PROMPT_NOT_COMPOSED.
- The system prompt does not repeat field-level prompts. A value that contains `<<…>>` or `$&` is inserted as written and never expanded.

**Technical notes**

- `src/agents/prompt.ts`. `composePrompt` does no I/O. The guard has already loaded the row and the template when it is called. The note is neither part of the prompt nor hashed.
- `encounterFields` lists each slot key with its field name. The schema defines the shape of the output.
- `promptId` is recorded alongside both hashes, because the stored row is edited in place.
- Tests: `tests/unit/agents/prompt.test.ts`, plus the wire-hash and tool-round checks in `tests/unit/agents/encounter.test.ts`.

---

### PEA-405

**Title:** Wrap every model call: temperature 0, limits, usage recorded, failures coded

**Description:**
As a compliance officer, I want every model call to go through one wrapper, so that every value is attributable and no failed call drops out of the record. The wrapper runs the call at temperature 0 within fixed limits, records the model, tokens and latency, and turns every failure into a reason code.

Today the browser picks among several inference endpoints, and nothing records which model produced a value. A failure inside the call would otherwise reject the run and skip the final outcome hook. That covers a schema violation, a content filter, a throttle, an outage, a timeout and a reply that was cut off. The wrapper catches each of them and records why the run failed.

**Scope**

- in: the model-call hook, usage recording and failure classification
- in: temperature, retries, timeout and output cap on the model client
- out: cost and latency dashboards, and retry tuning from throttling data (Epic 10)
- out: what Epic 6 and Epic 9 do with a failed run

**Acceptance criteria**

- Every request is sent with `temperature` 0 and `max_tokens` 16,384. The client retries twice and allows 300 seconds per attempt.
- After a call, the run carries the model name, input tokens, output tokens and latency, all read from the response. These are summed across the calls of a tool round, and the parsed output is kept.
- A reply that breaks the schema, or is not JSON, ends as OUTPUT_SCHEMA_VIOLATION. In this case and every failure below, `invoke` still resolves, the outcome hook runs and no parsed output is kept.
- A reply cut off at the token cap ends as OUTPUT_TRUNCATED.
- An output the content filter withheld ends as MODEL_CONTENT_FILTERED. A prompt the content filter refused (HTTP 400) ends as PROMPT_CONTENT_FILTERED.
- A throttle (429), an outage (500) or a timeout that outlasts the retries ends as MODEL_CALL_FAILED.
- A failure log line carries only the error class and name, the HTTP status and the error code. It never carries the message, the request body or the response body.
- Two live runs of the same synthetic note on a small schema return the same structured result.

**Technical notes**

- `src/agents/middleware/model-call.ts` and `src/core/llm.ts`. Temperature 0 is set on the `AzureChatOpenAI` constructor, because a per-call setting does not reach the wire.
- The constants in `llm.ts` are MAX_RETRIES 2, MAX_OUTPUT_TOKENS 16,384 (about 2.5 times the largest measured reply) and REQUEST_TIMEOUT_MS 300,000 per attempt.
- The client retries a cut-off reply like any other failure. A truncated reply can therefore cost up to 3 requests before it ends as OUTPUT_TRUNCATED.
- `openai` (error classes) and `@langchain/langgraph` (`Command`) are direct dependencies.
- Tests: `tests/unit/agents/encounter.test.ts`, `tests/unit/agents/middleware/model-call.test.ts`, `tests/unit/core/llm.test.ts`, and the live repeat run in `tests/integration/agents/provider.test.ts`.

---

### PEA-406

**Title:** Bind each request's prompt, masked note and schema onto the model call

**Description:**
As a clinical template administrator, I want the provider to enforce the schema built for this request, and the model to follow this request's instruction and read this request's note, so that a field I add to a template is extracted on the next request with no prompt edit and no deployment.

The agent is compiled once, but the schema, the prompt and the note change on every request. The model-call hook is the only place those values reach the provider. Nothing is compiled in, so a missed binding produces no parsed output at all and is counted as a failure. It never silently reuses an old schema. This hook is also the last point before the note leaves the service, so it decides what text is sent.

**Scope**

- in: the binding at the start of the model-call hook, which sets the system prompt, the outgoing messages and `providerStrategy(schema)` on every call
- out: building the schema and the value contract (Epic 3)
- out: PHI masking rules (Epic 5), tools (Epic 7) and evidence checks on the parsed output (Epic 6)

**Acceptance criteria**

- Every call sends the composed prompt as the system message, then one user message with the masked note, then any messages that the model and tools added.
- The response format is `providerStrategy` with this request's schema. The request shows `response_format.type` "json_schema" and `strict` true.
- The schema has one nullable key per template field (`s<sectionID>_f<fieldID>`), described by the field's name and its own prompt. A field used in two sections gets two keys.
- Each slot object has these keys, in this order: status (FOUND or ABSTAINED), found_in, value, unit, remark, confidence.
- Two runs in one process with different templates bind two different schemas, with no restart.
- On the second call of a tool round, the messages after the system prompt are user, assistant and tool, in that order.
- The captured request body contains no unmasked identifier from the seeded note.
- The parsed reply is returned as `structuredResponse` and matches this request's schema.

**Technical notes**

- `src/agents/middleware/model-call.ts` calls `handler({ ...request, systemPrompt, messages, responseFormat: providerStrategy(schema) })`.
- The messages are rebuilt on every call and never stored. The caller starts with empty messages, so state keeps only what the model and tools add.
- `providerStrategy` is always set explicitly. A bare schema would let the library choose a client-side tool strategy, and nothing would report it.
- The schema comes from Epic 3's `responseSchemaBuilder` and value contract. A field the note does not mention comes back as `null`. The rules for each key are stated once in the system prompt (PEA-404).
- The masker passes the note through today (Epic 5), so the masked-note check uses a seeded masker. Tests: `tests/unit/agents/encounter.test.ts`.

---

### PEA-407

**Title:** Tag every run with an outcome, a reason code and an extraction failure mode

**Description:**
As an AI/clinical admin, I want every run tagged with how it ended and why, and every extraction failure tagged with exactly one of the four failure modes, so that engineering defects are never reported in the same number as genuine model misreads.

A single blended accuracy figure mixes four different problems. Format, Routing and Ambiguity are engineering problems that this design removes, and Comprehension is the only one that depends on the model. A guard block or a refused call never produced an extraction, so it gets a reason code but no failure mode. A non-zero Format count means schema enforcement has degraded, which makes it a defect signal and not a quality signal.

**Scope**

- in: failure modes, outcomes, and reason codes with their kind and mode
- in: the outcome hook (`afterAgent`)
- out: the per-field Routing, Ambiguity and Comprehension codes (Epic 6)
- out: the audit row and commit (Epic 2, Epic 9), and the closed vocabulary and dashboards (Epic 10)

**Acceptance criteria**

- There are 14 reason codes, each with a kind: 8 GUARD, 3 MODEL_CALL and 3 EXTRACTION.
- Every EXTRACTION code maps to exactly one failure mode. No GUARD or MODEL_CALL code has a mode. A unit test checks the whole table, and the type check rejects an entry without a kind.
- A run with a parsed output and no reason code ends COMPLETED.
- A run with a GUARD code ends BLOCKED, with no failure mode.
- A run with a MODEL_CALL code ends FAILED, with no failure mode.
- A run with an EXTRACTION code ends FAILED, with that code's failure mode.
- A run with no reason code and no parsed output is tagged OUTPUT_MISSING, FAILED and FORMAT.
- The outcome hook is the only `afterAgent` in the spine, and it also runs on blocked and failed runs.

**Technical notes**

- `src/agents/failure-modes.ts` and `src/agents/middleware/outcome.ts`.
- The GUARD codes are INJECTION_BLOCKED, PAYLOAD_TOO_LARGE, TEMPLATE_UNAVAILABLE, PROMPT_NOT_FOUND, PROMPT_AMBIGUOUS, PROMPT_PLACEHOLDER_UNFILLED, PROMPT_NOT_COMPOSED and GUARD_STEP_FAILED.
- The MODEL_CALL codes are MODEL_CONTENT_FILTERED, PROMPT_CONTENT_FILTERED and MODEL_CALL_FAILED. The EXTRACTION codes are OUTPUT_SCHEMA_VIOLATION, OUTPUT_MISSING and OUTPUT_TRUNCATED, all FORMAT.
- Epic 9 adds commit-or-hold and the audit write to this same hook. It never adds a second `afterAgent`.
- Tests: `tests/unit/agents/failure-modes.test.ts`, plus the outcome checks in `tests/unit/agents/encounter.test.ts` and `tests/unit/agents/middleware/model-call.test.ts`.

---

### PEA-408

**Title:** Benchmark precision and recall through the encounter agent before every merge

**Description:**
As a team lead, I want an evaluation suite that runs our reference queries through the encounter agent and compares precision and recall with a stored benchmark, so that any change that lowers accuracy is caught before the code is submitted. That covers changes to the agent, the prompt, the template, and later the patient and clinician context.

Accuracy has only been measured by hand so far. Most future work changes what surrounds the agent, not the tests, so the suite binds to the agent itself. The API streams with `encounterAgent.stream`, and the suite calls `encounterAgent.invoke`. The agent behind both is the same; only the way it is called differs.

**Scope**

- in: `encounterAgent.invoke` and `encounterAgent.stream` as the only ways to run the agent
- in: the five reference queries, their expected field values, and an automatic precision and recall scorer
- in: a stored benchmark, a pass/fail gate against it, and a per-run report and CSV
- in: `tests/eval/CLAUDE.md`, so any engineer or agent knows the rules
- out: real patient notes, patient and clinician context (later epics add queries for them), CI wiring

**Acceptance criteria**

- `npm run eval` runs every reference query 3 times through `encounterAgent.invoke` and reports precision and recall per query and overall.
- The run fails when overall precision or recall falls below the stored benchmark by more than the agreed tolerance.
- One query also runs through `encounterAgent.stream`. It must return every field exactly once, with the same answers as the run's final result.
- The benchmark only rises on its own: a passing run that beats it raises it. Lowering it takes an explicit promote command.
- Every run writes a results file and one CSV per query run, and adds one line to a history of all runs.
- `tests/eval/CLAUDE.md` says what the suite does, how to run it, and when the benchmark may change.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the original ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-401 | Done | 5 | PEA-104 (Epic 1) | `src/agents/encounter.ts`; `tests/integration/agents/provider.test.ts` (4 live checks); `tests/unit/agents/encounter.test.ts`. Merged in PR 12548. | Code moved from `src/pacehr/agents/` to `src/agents/`. Per-folder aliases (`#agents/*`, `#guards/*`, `#schema/*`, `#services/*` and others) replace `#pacehr/*`. The spike and the determinism check share `provider.test.ts`; there is no `provider-enforcement.test.ts` and no `determinism.test.ts`. The 403 firewall precondition no longer applies from this machine. | Record the measured result in truth §16 #4 and #15, which still say "unmeasured". The integration tier skips silently when Azure is unreachable, so CI can be green with 0 live tests (gaps doc X12). |
| PEA-402 | Done | 5 | PEA-401 | `MIDDLEWARE` in `src/agents/encounter.ts`; `src/agents/state.ts`; tests in `encounter.test.ts`. Merged in PR 12548. The evidence entry exists only in the working tree. | The spine has 4 entries: the evidence `afterModel` hook (Epic 6, PEA-607/608) now sits between the model call and the outcome. The context adds accountId and userId (for `usp_getPrompt`) and drops tenant. State adds promptId, promptTemplateHash, evidence and reviewSlots. There is no `spine.test.ts`; the spine tests live in `encounter.test.ts`. | Epic 7's tool-call middleware is not in the list yet. `evidence.ts` is not in a PR. |
| PEA-403 | Done | 5 | PEA-402; Epic 3 template service and schema builder; Epic 5 guards | `src/agents/middleware/guard.ts`; `encounter.test.ts` covers 7 block cases, a throwing step, the `canJumpTo` mutation and the pass-through run. PR 12548 merged it with fail-closed placeholders. The switch to the real `templateService` exists only in the working tree. | Removed: `fragment_resolve` and `memory_load`. Added: `prompt_load` (`usp_getPrompt`). The template comes from `templateService.getAIConfig`, not `templateConfigLoader.load`. TEMPLATE_UNAVAILABLE means no template name or no section. Injection and PHI pass the note through by owner decision instead of throwing. The payload limit is live at 20,000 characters. | Merged main still calls the throwing `templateConfigLoader` and fails `tsc` at `guard.ts:50` (TS2345, per the 2026-10-09 change log; the line matches). The working-tree fix needs a PR. Epic 5 owns the real injection patterns and masking. |
| PEA-404 | Done | 3 | PEA-403; the stored `AI.prompt` rows | `src/agents/prompt.ts`; `tests/unit/agents/prompt.test.ts` (7); wire-hash and tool-round tests in `encounter.test.ts`. Merged in PR 12548. `OUTPUT_RULES` and the slot-key `encounterFields` exist only in the working tree. | Prompt fragments (safety contract, task instruction, specialty, template override) are replaced by the stored row with `<<placeholders>>`. PROMPT_FRAGMENT_MISSING and PROMPT_SLOT_UNFILLED are gone. PROMPT_NOT_FOUND, PROMPT_AMBIGUOUS and PROMPT_PLACEHOLDER_UNFILLED are added. promptTemplateHash and promptId are recorded too. The dependency on PEA-802 is dropped. | `templateProcess` is the fixed value "admitted", matching the UI. `usp_getPrompt` has no TOP, so two universal rows would block every encounter as PROMPT_AMBIGUOUS (Epic 2 doc). Epic 8 owns prompt versioning. |
| PEA-405 | Done | 5 | PEA-402, PEA-104 | `src/agents/middleware/model-call.ts`, `src/core/llm.ts`; `encounter.test.ts` (6 failure rows plus usage), `middleware/model-call.test.ts` (5), `core/llm.test.ts`; the live repeat run in `provider.test.ts`. Temperature 0 merged in PR 12548. The token cap, timeout and OUTPUT_TRUNCATED exist only in the working tree. | Adds OUTPUT_TRUNCATED, MAX_OUTPUT_TOKENS 16,384 and REQUEST_TIMEOUT_MS 300,000. Usage is summed across the calls of a tool round. The log adds the error name, so a timeout is identifiable. | Temperature 0 is not deterministic at template scale. On template 457, only 45/99 (SIMPLE) and 48/99 (DENSE) fields were identical in value and status across 3 runs (2026-10-09 change log); record `system_fingerprint` and test `seed`. A cut-off reply is retried up to 3 requests before OUTPUT_TRUNCATED. MAX_RETRIES 2 is not load-tested (Epic 10). |
| PEA-406 | Done | 3 | PEA-405, PEA-404; Epic 3 builder; Epic 5 masker | The binding in `model-call.ts`; tests in `encounter.test.ts`; two-section fields in `tests/unit/services/templateService.test.ts`. Merged in PR 12548. The new value contract exists only in the working tree. | There is no `binding.test.ts`. No test checks for a `ProviderStrategy` instance; the tests assert the wire `json_schema` and `strict` instead. A slot is described by the field name plus its own prompt, never `aiSummaryPrompt`. The contract is status/found_in/value/unit/remark/confidence, with no per-key descriptions, and its rules sit once in the prompt. | Template 457's schema (about 594 properties) already exceeds Azure's documented strict-mode limit of 100 properties, and Azure still accepted it. Verify against the largest template (gaps doc X8). The masked-note check uses a seeded masker until Epic 5 lands. |
| PEA-407 | Done | 3 | PEA-402 | `src/agents/failure-modes.ts`, `src/agents/middleware/outcome.ts`; `failure-modes.test.ts` (1) plus the outcome assertions in the agent tests. Merged in PR 12548. OUTPUT_TRUNCATED exists only in the working tree. | 14 codes, up from 12. Removed: PROMPT_FRAGMENT_MISSING and PROMPT_SLOT_UNFILLED. Added: PROMPT_NOT_FOUND, PROMPT_AMBIGUOUS, PROMPT_PLACEHOLDER_UNFILLED and OUTPUT_TRUNCATED. PROMPT_NOT_COMPOSED is raised in `wrapModelCall` but counts as GUARD, so the run ends BLOCKED. | The project controller has not signed off the rule that blocked and refused runs carry no failure mode. Epic 2's data design already assumes it (`CK_agentRun_failureMode`). Epic 2's code list still has PROMPT_SLOT_UNFILLED and is missing OUTPUT_TRUNCATED. |

| PEA-408 | Done | 5 | PEA-401 to PEA-407; the five reference queries and their blind supported-field lists (`docs/data/evaluation/rescore/supported.md`) | `encounterAgent.invoke` and `encounterAgent.stream` in `src/agents/encounter.ts`; `tests/eval/` (`queries/q1–q5.txt`, `cases.json`, `score.ts`, `encounter.eval.ts`, `benchmark.json`, `history.jsonl`, `promote.ts`, `CLAUDE.md`); `tests/unit/eval/score.test.ts`; `npm run eval`, `npm run eval:promote`. Unit suite 135/135. First live run 2026-10-14 (`logs/eval/20261014-192807`): passed, precision 90.8%, recall 78.4%, stream check passed; 10.7 min, about $0.76. | New ticket, added 2026-10-14. The demo server and the manual runner now call `encounterAgent.stream` and `encounterAgent.invoke`. The benchmark ratchets up after a better passing run. | Decide whether to wire the suite into a pre-push hook or the PR pipeline. Rebuild the demo container to pick up `encounterAgent.stream`. |

Total: 34 points, all eight tickets done in code.

### Notes

- **Merged vs working tree** (branch `PacEHR-AI-Develop-Main`, checked 2026-10-13):
  - The Epic 4 core was merged in PR 12548 (commit 84ef706, 2026-10-06). At that point it lived under `src/pacehr/`, and its Epic 3 and Epic 5 placeholders failed closed.
  - PR 12607 (AITP-99, commit 4a28681, 2026-10-07) moved the code to `src/` and added `templateService` and `responseSchemaBuilder`. It left the guard calling the throwing `templateConfigLoader`, so merged main does not typecheck.
  - Everything else is uncommitted in the working tree and in no PR yet: 32 tracked files modified or deleted, plus untracked files. This covers:
    - the end-to-end wiring from the guard to `templateService`
    - the new output contract (`ExtractedValue` and `OUTPUT_RULES`)
    - the evidence engine (`src/agents/middleware/evidence.ts`, Epic 6)
    - the pass-through injection and PHI guards, and the live 20,000-character limit
    - the token cap, the timeout and OUTPUT_TRUNCATED
    - `src/agents/field-stream.ts`, a Dockerfile, and a demo streaming server under `tests/manual/` (`streamServer.manual.ts`)
  - The demo server is a person's demo, not part of this epic. Epic 4 ships no endpoint, and `src/core/app.ts` serves only the health routes.
- **Unit tests, run 2026-10-13:**
  - `npm test` reported 131 tests: 131 passed, 0 failed, 0 skipped. Its `tsc --noEmit` pretest and the lint guard test passed too.
  - Epic 4's own tests number 41: `encounter.test.ts` 28, `prompt.test.ts` 7, `failure-modes.test.ts` 1, `middleware/model-call.test.ts` 5.
  - Related files: `middleware/evidence.test.ts` 12 (Epic 6), `field-stream.test.ts` 2 (demo), `core/llm.test.ts` 8 (including temperature, `max_tokens`, retries and timeout).
- **Live provider-enforcement spike, run 2026-10-13:**
  - Command: `node --import tsx/esm --test tests/integration/agents/provider.test.ts`. Result: 5 tests, 5 passed (4 checks plus the parent), in 10.8 s.
  - On gpt-4.1 at api-version 2025-01-01-preview:
    - providerStrategy returned confidence=HIGH in 1 request
    - toolStrategy made 1 request and returned 1 tool message
    - the deployment rejected an optional field under strict mode (BadRequestError 400) and accepted a nullable one
    - the repeat run was equal
  - This matches the 2026-10-09 run recorded in `PacEHR_AI/logs/runner-summary-20261009.md`.
- **Open questions:**
  - Kind and mode for blocked runs: guard blocks and refused or failed model calls currently get a reason code and no failure mode. The project controller still needs to confirm this rule and record it on PEA-407.
  - The working tree mixes Epic 4 fixes, Epic 3's new contract, Epic 6's evidence engine and demo code. Decide how to split it into PRs. The guard fix should go first, because merged main does not typecheck without it.
  - Determinism at template scale (PEA-405): decide whether to record `system_fingerprint` and `seed`, or score with repeated runs.
  - Doc follow-ups: truth §16 #4 and #15 need the measured result. The Epic 2 data design's reason-code list needs to match `failure-modes.ts`.
