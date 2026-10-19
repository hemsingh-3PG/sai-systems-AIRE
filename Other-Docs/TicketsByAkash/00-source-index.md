# Source Index — PacEHR Encounter Extraction Agent

**This file is the single source of requirements for the 55-story backlog.** If a
requirement is not in this file, it does not get built. If a requirement is not
supported by a real line citation below, it should not have been invented.

Indexes the **proposed** system only:
- `pacEHR-AI-Approach-2-Proposed.md` (primary)
- `pacEHR-Encounter-Agent-4Pager.md` (primary)
- `pacEHR-Azure-Deployment-Architecture.md` (supporting — cited directly for Epic 11,
  which the two primary documents do not cover)

`pacEHR-AI-Approach-1-Current.md`, `pacEHR-AI-API-Reference.md`, and
`pacEHR-Encounter-Template-Data-Model.md` were read in full to understand what
problem each requirement solves, but describe the **current** system and are never
cited as a Source below. `ai-agent-observability.md` and
`deliverables-scope-and-roadmap.md` were also read; see the note at the end of this
file for why they are excluded as sources.

Stack: Python · LangChain `create_agent` · Azure OpenAI · Azure SQL.

**Note on spelling:** `templetID`, `fieldID`, `sectionID` are reproduced exactly as
the live database spells them (including the misspelling of "template") throughout
this file. This is not a typo — do not "fix" it in any story.

---

## Epic 01 — Repository foundation & core singletons

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-01-01 | The extraction service is implemented as a Python service built with LangChain's `create_agent` and a middleware pipeline, calling Azure OpenAI as the model provider | `pacEHR-AI-Approach-2-Proposed.md` | 6 | 1 |
| REQ-01-02 | Context assembly — prompt composition, template loading, patient history and note retrieval, tool orchestration — happens entirely server-side inside the agent; the browser no longer assembles the prompt or chooses among inference endpoints | `pacEHR-Encounter-Agent-4Pager.md` | 18, 24 | 1 |
| REQ-01-03 | The model provider and model identity used for inference are read from configuration at call time and are never hardcoded in source | `pacEHR-AI-Approach-2-Proposed.md` | 198 | 1 |

---

## Epic 02 — Data layer — AI schema tables

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-02-01 | `AI.promptFragment` stores versioned, composable prompt fragments; only AI/clinical admin, through the Prompt Studio, may write to it, and the agent never writes to it | `pacEHR-Encounter-Agent-4Pager.md` | 104 | 1 |
| REQ-02-02 | `AI.fieldConstraint` stores executable per-field guards (units, plausible bounds, abnormal bounds) compiled from prose the clinical author writes in the template editor; the agent never writes to it | `pacEHR-Encounter-Agent-4Pager.md` | 105 | 1 |
| REQ-02-03 | `AI.agentRun` stores exactly one append-only row per AI invocation (prompt hash, model, tokens, latency, outcome), written only by the agent; no human writes to it | `pacEHR-Encounter-Agent-4Pager.md` | 106 | 1 |
| REQ-02-04 | `AI.fieldOutcome` stores what the AI proposed and what the clinician accepted, side by side, per field; the agent writes the proposal and the reviewer updates the decision and final value | `pacEHR-Encounter-Agent-4Pager.md` | 107 | 1 |
| REQ-02-05 | `AI.memoryEvent` is an append-only record of every field a clinician corrected, written by the agent only when the AI was wrong, and deleted only by a patient-data purge | `pacEHR-Encounter-Agent-4Pager.md` | 108 | 2 |
| REQ-02-06 | `AI.memory` holds the condensed instruction block actually injected into prompts, one active row per scope, rewritten in place by the agent; an admin may clear or flag a scope | `pacEHR-Encounter-Agent-4Pager.md` | 109 | 2 |
| REQ-02-07 | None of the six new `AI` schema tables replaces an existing clinical table, none is written by the browser, and existing clinical tables remain read-only and unchanged | `pacEHR-Encounter-Agent-4Pager.md` | 100 | 1 |
| REQ-02-08 | `AI.fieldOutcome` is the only one of the six tables expected to grow meaningfully (roughly 30 rows per encounter, on the order of 11 million rows a year at 1,000 AI-assisted encounters a day) and requires an index and a defined retention policy | `pacEHR-Encounter-Agent-4Pager.md` | 111 | 1 |
| REQ-02-09 | Every new column that references an existing key reuses the live database's own spelling and inconsistencies (`templetID`, `fieldID`, `sectionID`) rather than a retro-fitted naming convention | `pacEHR-Encounter-Agent-4Pager.md` | 113 | 1 |
| REQ-02-10 | Phase 1 creates exactly four of the six `AI` tables (`promptFragment`, `fieldConstraint`, `agentRun`, `fieldOutcome`) inside the existing SQL database; no new data store is introduced | `pacEHR-Azure-Deployment-Architecture.md` | 16, 76-87 | 1 |

---

## Epic 03 — Template config → dynamic Pydantic schema

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-03-01 | **[Highest-value requirement in the corpus]** A field's AI-facing description is stored keyed on the triple `(templetID, sectionID, fieldID)` — never globally per `fieldID` — because the same `fieldID` legitimately recurs in multiple sections of one template with a different meaning each time (e.g., Blood Pressure in Review of Systems vs. Exam), and a global description would collide exactly as `Template.fields.displayName` already does today (one displayName edit was measured reaching 179 of 458 templates); only a per-mapping description can carry a section-specific instruction such as "only when re-measured … leave empty if already captured elsewhere" | `pacEHR-AI-Approach-2-Proposed.md` | 124-141 | 1 |
| REQ-03-02 | Each template field's AI configuration includes at minimum a `fieldID`, name, type, unit, and a per-mapping natural-language description of what the field is for | `pacEHR-AI-Approach-2-Proposed.md` | 76-120 | 1 |
| REQ-03-03 | Field descriptions are authored once, in the admin page, by whoever configures the template — one line of description per field | `pacEHR-AI-Approach-2-Proposed.md` | 122 | 1 |
| REQ-03-04 | Once per request, before any model call, the agent loads the current template's sections, fields, types and descriptions from the admin configuration | `pacEHR-AI-Approach-2-Proposed.md` | 194 | 1 |
| REQ-03-05 | At request time the agent builds the response schema directly from template configuration (one schema field per configured section+field slot); no part of the schema is hand-written | `pacEHR-AI-Approach-2-Proposed.md` | 74, 145-160 | 1 |
| REQ-03-06 | Adding, removing or editing a field in the admin page takes effect on the very next request, with no prompt edit, no code change and no deployment | `pacEHR-AI-Approach-2-Proposed.md` | 164-166 | 1 |
| REQ-03-07 | The same `fieldID` used in two different sections of a template produces two independent schema slots, each keeping its own section-specific description | `pacEHR-AI-Approach-2-Proposed.md` | 36-53, 106-120 | 1 |
| REQ-03-08 | Every extracted value is returned as a structured object carrying `value`, `unit`, `found_in` (the evidence substring) and `confidence` — never as a bare string | `pacEHR-AI-Approach-2-Proposed.md` | 58-64 | 1 |
| REQ-03-09 | **[Critical — do not let a supporting document override this]** `confidence` on every extracted value is restricted to the literal band `HIGH` / `MEDIUM` / `LOW`; it is never a numeric score or percentage | `pacEHR-AI-Approach-2-Proposed.md` | 63-66 | 1 |
| REQ-03-10 | `value` and `unit` are left empty — never guessed — when the note does not state them | `pacEHR-AI-Approach-2-Proposed.md` | 60-61 | 1 |
| REQ-03-11 | A newly added field is expected to extract less accurately at first (first-draft description, no correction history) than a field that has been in use for months, and this is expected behavior, not a defect | `pacEHR-AI-Approach-2-Proposed.md` | 172-180 | 1 |
| REQ-03-12 | Guards apply to every field from day one regardless of maturity: a field with a weak description must produce flagged, reviewable values rather than silently wrong ones committed with false confidence | `pacEHR-AI-Approach-2-Proposed.md` | 182 | 1 |

---

## Epic 04 — Agent core — `create_agent` + middleware spine

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-04-01 | Every extraction failure is attributable to exactly one of four modes — Format, Routing and Ambiguity (deterministic, engineered out) or Comprehension (probabilistic, no ceiling claimed) — and the three deterministic modes must not be reported or treated as if they shared the model's probabilistic ceiling | `pacEHR-AI-Approach-2-Proposed.md` | 14-21 | 1 |
| REQ-04-02 | The agent runs as a single pipeline with exactly six ordered middleware stages — `before_agent`, `before_model`, `wrap_model_call`, `wrap_tool_call` (conditional), `after_model`, `after_agent` — executed in that fixed order for every request | `pacEHR-AI-Approach-2-Proposed.md` | 208-211 | 1 |
| REQ-04-03 | When `wrap_tool_call` executes because the model requested a tool, control returns to `before_model` rather than proceeding directly to `after_model` | `pacEHR-AI-Approach-2-Proposed.md` | 209-210 | 1 |
| REQ-04-04 | `before_agent` runs exactly once per request, before any model call, and if any of its steps fails the run ends immediately with nothing written and no model called | `pacEHR-AI-Approach-2-Proposed.md` | 194 | 1 |
| REQ-04-05 | `before_model` runs before every model call, including the second pass after a tool call, and aborts the run if any slot required to compose the prompt is unfilled rather than sending a half-built prompt | `pacEHR-AI-Approach-2-Proposed.md` | 196 | 1 |
| REQ-04-06 | `wrap_model_call` enforces the response schema at the provider level such that a malformed-JSON response becomes impossible from that call | `pacEHR-AI-Approach-2-Proposed.md` | 198 | 1 |
| REQ-04-07 | Every model call runs at temperature 0, so that the same note produces the same result every time | `pacEHR-AI-Approach-2-Proposed.md` | 198 | 1 |
| REQ-04-08 | `after_agent` runs exactly once per request, after `after_model` has produced a verdict for every field | `pacEHR-AI-Approach-2-Proposed.md` | 204 | 1 |

---

## Epic 05 — Guardrails — injection scanning + PHI masking

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-05-01 | Injection scanning is a deterministic pattern match with no model call, and runs before any other `before_agent` step | `pacEHR-AI-Approach-2-Proposed.md` | 194 | 1 |
| REQ-05-02 | The injection scanner recognizes at minimum five pattern classes: instruction override, role hijacking, prompt exfiltration, special tokens, and known jailbreaks | `pacEHR-AI-Approach-2-Proposed.md` | 225-231 | 1 |
| REQ-05-03 | A matched injection pattern ends the run entirely; the clinician's text is never silently stripped or altered | `pacEHR-AI-Approach-2-Proposed.md` | 233 | 1 |
| REQ-05-04 | Patient name, DOB and MRN are replaced with tokens server-side before the note leaves the service, so the model never receives a raw patient identifier | `pacEHR-AI-Approach-2-Proposed.md` | 194, 238-246 | 1 |
| REQ-05-05 | Masked tokens are replaced with real values (de-masked) in `after_agent`, before anything — committed fields or review items — leaves the service | `pacEHR-AI-Approach-2-Proposed.md` | 204 | 1 |
| REQ-05-06 | The model never sees a patient identifier, and the clinician never sees a masked one | `pacEHR-AI-Approach-2-Proposed.md` | 250 | 1 |
| REQ-05-07 | The masking token map exists only in memory for the life of the request and is discarded with it — never logged, never persisted to any store, never transmitted anywhere | `pacEHR-AI-Approach-2-Proposed.md` | 250 | 1 |
| REQ-05-08 | A skiplist prevents ordinary clinical words that coincide with a patient's name (e.g., a patient surnamed Brown) from being masked out of clinical prose | `pacEHR-AI-Approach-2-Proposed.md` | 252 | 1 |
| REQ-05-09 | Ages are not masked as identifiers, since a bare number (e.g., `82`) is far more often a dose than an age | `pacEHR-AI-Approach-2-Proposed.md` | 252 | 1 |

---

## Epic 06 — Deterministic validation engine

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-06-01 | All field validation runs as plain Python inside the `after_model` hook, never as a tool the model can be asked to call, because a tool the model may decline cannot prove a check ran on every field of every encounter — an audit obligation, not a preference | `pacEHR-Encounter-Agent-4Pager.md` | 69, 82 | 1 |
| REQ-06-02 | Confidence for a field's verdict is computed from evidence and validator outcomes, never from the model's self-reported probability | `pacEHR-Encounter-Agent-4Pager.md` | 69 | 1 |
| REQ-06-03 | Range validation uses two bands: implausible values block, abnormal-but-real values flag for review | `pacEHR-AI-Approach-2-Proposed.md` | 202 | 1 |
| REQ-06-04 | A missing or ambiguous unit sends the field to review rather than the system guessing a unit | `pacEHR-AI-Approach-2-Proposed.md` | 202 | 1 |
| REQ-06-05 | Cross-field validation checks internal consistency — e.g., systolic recorded over diastolic, and BMI agreeing with the height and weight recorded on the same encounter | `pacEHR-AI-Approach-2-Proposed.md` | 202 | 1 |
| REQ-06-06 | After_model includes a date-sanity validator alongside range, unit and cross-field checks | `pacEHR-Encounter-Agent-4Pager.md` | 69 | 1 |
| REQ-06-07 | Evidence-check validation requires the quoted `found_in` substring to appear verbatim in the source note | `pacEHR-AI-Approach-2-Proposed.md` | 202 | 1 |
| REQ-06-08 | Every field receives exactly one verdict from `after_model`: accept, review, or block | `pacEHR-AI-Approach-2-Proposed.md` | 202 | 1 |
| REQ-06-09 | Range and unit validators are driven by executable per-field guard definitions (unit, plausible bounds, abnormal bounds) compiled from prose the clinical author writes in the template editor, confirmed on save | `pacEHR-Encounter-Agent-4Pager.md` | 105 | 1 |

---

## Epic 07 — Agent tools

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-07-01 | The agent exposes a `resolve_date` tool that computes a relative or implied date from the encounter's date of service, never from today's date | `pacEHR-AI-Approach-2-Proposed.md` | 200 | 1 |
| REQ-07-02 | The agent exposes a `compute_bmi` tool that refuses to compute a BMI when a required unit is missing, rather than assuming one | `pacEHR-AI-Approach-2-Proposed.md` | 200 | 1 |
| REQ-07-03 | The agent exposes a `lookup_icd_cpt` tool that checks a code exists, is billable, and is valid for the encounter's Place of Service | `pacEHR-AI-Approach-2-Proposed.md` | 200 | 1 |
| REQ-07-04 | The model never performs date or BMI arithmetic itself; both are always delegated to the `resolve_date` and `compute_bmi` tools | `pacEHR-AI-Approach-2-Proposed.md` | 267 | 1 |
| REQ-07-05 | `wrap_tool_call` executes only when the model explicitly requests a tool; it is not invoked on every request | `pacEHR-AI-Approach-2-Proposed.md` | 200 | 1 |
| REQ-07-06 | The agent exposes a `resolve_prompt` tool that replaces the current `getPrompt` endpoint | `pacEHR-Encounter-Agent-4Pager.md` | 48 | 1 |
| REQ-07-07 | The agent exposes a `load_patient_history` tool that replaces the current `getPreviousEncounterDetails` and `getImportPatientDetailsToEncounterForm` endpoints | `pacEHR-Encounter-Agent-4Pager.md` | 49 | 1 |
| REQ-07-08 | The agent exposes a `load_note_text` tool that replaces the current `getRoundingNotesByEncounter` endpoint | `pacEHR-Encounter-Agent-4Pager.md` | 50 | 1 |
| REQ-07-09 | The four current inference-call endpoints (`streamTemplateCompletion`, `streamCompletion`, `streamCompletionWithData`, `getCompletion`) collapse into a single agent invocation | `pacEHR-Encounter-Agent-4Pager.md` | 51 | 1 |
| REQ-07-10 | The current client-driven `addEditAILogs` call is replaced by a server-side write that happens unconditionally on every run, not contingent on the browser calling it | `pacEHR-Encounter-Agent-4Pager.md` | 52 | 1 |
| REQ-07-11 | Absent a licensed ICD/CPT code set, `lookup_icd_cpt` degrades to format checking only and forces human sign-off rather than asserting a validated code | `pacEHR-AI-Approach-2-Proposed.md` | 283 | 1 |

---

## Epic 08 — Prompt ownership — versioned fragments

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-08-01 | The composed prompt instructs the model to fill only the slots listed in the current SLOT MANIFEST and never invent a slot | `pacEHR-AI-Approach-2-Proposed.md` | 261 | 1 |
| REQ-08-02 | The composed prompt instructs the model that every FOUND value must quote the exact substring of the note it came from | `pacEHR-AI-Approach-2-Proposed.md` | 262 | 1 |
| REQ-08-03 | **[incl. critical status distinction]** The composed prompt defines two distinct non-answer statuses — `ABSENT` (the note is silent on a slot) vs. `ABSTAINED` (text exists but the model is unsure) — and states explicitly that abstaining is correct and a guess is worse than an abstention | `pacEHR-AI-Approach-2-Proposed.md` | 263-265 | 1 |
| REQ-08-04 | The composed prompt instructs the model to report units exactly as written and never to convert them | `pacEHR-AI-Approach-2-Proposed.md` | 266 | 1 |
| REQ-08-05 | The composed prompt instructs the model never to calculate a value itself, and to use `resolve_date` and `compute_bmi` instead | `pacEHR-AI-Approach-2-Proposed.md` | 267 | 1 |
| REQ-08-06 | The composed prompt instructs the model that a section-level slot summarizes its child slots and must not duplicate a child slot's value into the section slot | `pacEHR-AI-Approach-2-Proposed.md` | 268 | 1 |
| REQ-08-07 | The composed system prompt contains no instructions about JSON validity, key names, or brace matching, since schema enforcement covers those instead | `pacEHR-AI-Approach-2-Proposed.md` | 275 | 1 |
| REQ-08-08 | The composed prompt includes the task type, template name, place of service and date of service, plus the full slot manifest built per the template configuration | `pacEHR-AI-Approach-2-Proposed.md` | 270-272 | 1 |
| REQ-08-09 | The legacy `AI.prompt` table is taken off the runtime path entirely and read only once, at migration | `pacEHR-Encounter-Agent-4Pager.md` | 90 | 1 |
| REQ-08-10 | Prompts are composed at request time from versioned, composable fragments of at least these kinds: a contract, a task, an optional specialty, and an optional template override | `pacEHR-Encounter-Agent-4Pager.md` | 90 | 1 |
| REQ-08-11 | Fragment resolution precedence is explicitly defined and tested: an account-specific fragment beats a global one, and the highest version wins | `pacEHR-Encounter-Agent-4Pager.md` | 90 | 1 |
| REQ-08-12 | A prompt fragment resolves at runtime only when it is both marked active and has passed evaluation | `pacEHR-Encounter-Agent-4Pager.md` | 90 | 1 |
| REQ-08-13 | `AI.promptFragment` is the only table prompt fragments are written to, and only AI/clinical admin, through the Prompt Studio, may write it — the agent never writes to it | `pacEHR-Encounter-Agent-4Pager.md` | 104 | 1 |
| REQ-08-14 | A prompt fragment version can be rolled back, and two fragment versions can be compared A/B | `pacEHR-Encounter-Agent-4Pager.md` | 104 | 1 |
| REQ-08-15 | Promotion of a prompt fragment that fails evaluation is blocked | `pacEHR-Encounter-Agent-4Pager.md` | 104, 123 | 1 |
| REQ-08-16 | Any model output can be traced back to the exact prompt fragment versions and text that produced it | `pacEHR-Encounter-Agent-4Pager.md` | 104 | 1 |

---

## Epic 09 — HITL review + API surface

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-09-01 | The encounter path exposes exactly two API endpoints: `POST /ai/encounter/extract` and `POST /ai/encounter/resolve` | `pacEHR-Encounter-Agent-4Pager.md` | 30, 53 | 1 |
| REQ-09-02 | The existing .NET API layer remains a thin proxy in front of the agent, retaining authentication, tenancy scoping and rate limiting | `pacEHR-Encounter-Agent-4Pager.md` | 30 | 1 |
| REQ-09-03 | When `after_model` flags zero fields, `after_agent` commits every validated field directly and nothing is held for review | `pacEHR-AI-Approach-2-Proposed.md` | 204 | 1 |
| REQ-09-04 | When `after_model` flags one or more fields, `after_agent` persists the run in an `awaiting_review` state and commits nothing | `pacEHR-Encounter-Agent-4Pager.md` | 84 | 1 |
| REQ-09-05 | `POST /ai/encounter/resolve` applies the clinician's decision on each flagged field individually and completes the run | `pacEHR-Encounter-Agent-4Pager.md` | 84 | 1 |
| REQ-09-06 | Resolving a flagged run does not re-invoke the model or replay any step that already completed before the pause | `pacEHR-Encounter-Agent-4Pager.md` | 84 | 1 |
| REQ-09-07 | Flagged fields are returned to the clinician together with the exact words they came from, so nothing is committed sight-unseen | `pacEHR-AI-Approach-2-Proposed.md` | 204 | 1 |

---

## Epic 10 — Observability & evaluation

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-10-01 | Level 1 observability produces exactly one trace per agent invocation, with one span per middleware hook | `pacEHR-Encounter-Agent-4Pager.md` | 121 | 1 |
| REQ-10-02 | Each trace records guard outcomes, which prompt fragments resolved, model identity and token counts, per-field decisions, and what was ultimately committed | `pacEHR-Encounter-Agent-4Pager.md` | 121 | 1 |
| REQ-10-03 | The final composed prompt text is hashed before the model call, so any output can be traced back to the exact prompt that produced it | `pacEHR-AI-Approach-2-Proposed.md` | 196 | 1 |
| REQ-10-04 | Every model call records the model used, token counts, and latency | `pacEHR-AI-Approach-2-Proposed.md` | 198 | 1 |
| REQ-10-05 | An audit record is written server-side on every run unconditionally, including runs that failed closed before reaching a model | `pacEHR-AI-Approach-2-Proposed.md` | 204 | 1 |
| REQ-10-06 | Level 2 evaluation lets a prompt-fragment edit save as a new version that cannot resolve at runtime until it has passed evaluation | `pacEHR-Encounter-Agent-4Pager.md` | 123 | 1 |
| REQ-10-07 | The Level 2 evaluation set requires no hand-labelling: `AI.fieldOutcome` already holds the AI's proposal beside the clinician's accepted value, so production traffic supplies labelled ground truth directly | `pacEHR-Encounter-Agent-4Pager.md` | 123 | 1 |
| REQ-10-08 | Level 2 evaluation replays the current and candidate prompt versions over the same set of recent real notes at temperature 0, so the prompt version is the only variable that differs | `pacEHR-Encounter-Agent-4Pager.md` | 123 | 1 |
| REQ-10-09 | Level 2 promotion is decided only by deterministic metrics: schema validity, validator pass rate, evidence-bound rate, exact match against the accepted value, and token/latency deltas | `pacEHR-Encounter-Agent-4Pager.md` | 125 | 1 |
| REQ-10-10 | **[deterministic-vs-judge split]** An LLM judge may advise on a Level 2 comparison with a semantic diff explaining why a metric moved, but can never itself gate promotion, since a model scoring its own prompt family is not an impartial gate | `pacEHR-Encounter-Agent-4Pager.md` | 125 | 1 |
| REQ-10-11 | **[falsifiable memory test]** Level 3 observability is decided by exactly one metric — edit rate per clinician over time — measured against a memory-off control arm | `pacEHR-Encounter-Agent-4Pager.md` | 129 | 2 |
| REQ-10-12 | The operational dashboard reports run count, edit rate with trend, blocked rate, p95 latency and cost per encounter over a rolling window | `pacEHR-Encounter-Agent-4Pager.md` | 134, 137-139 | 1 |
| REQ-10-13 | The dashboard reports per-hook latency (p50/p95) for every middleware stage and the distribution of field-level verdicts (accept/review/block) as a share of all fields decided | `pacEHR-Encounter-Agent-4Pager.md` | 141-145 | 1 |
| REQ-10-14 | The dashboard reports the leading reason codes behind non-accept verdicts, ranked by volume, and each active prompt fragment's version, active/blocked state and pass rate | `pacEHR-Encounter-Agent-4Pager.md` | 147-151 | 1 |
| REQ-10-15 | The dashboard reports memory-layer health (active scopes, memory-hit rate, median summary token size) and review-queue health (open count, median age, oldest age) | `pacEHR-Encounter-Agent-4Pager.md` | 153-156 | 2 |
| REQ-10-16 | Tracked metrics include at minimum: edit rate per field and per clinician, block rate by risk class, abstention rate, evidence-bound rate as a hallucination proxy, review queue depth and age, memory hit rate, cost per encounter, and hook latency | `pacEHR-Encounter-Agent-4Pager.md` | 162 | 1 |
| REQ-10-17 | Observability instrumentation follows OpenTelemetry semantics so the tracing backend remains replaceable | `pacEHR-Encounter-Agent-4Pager.md` | 164 | 1 |
| REQ-10-18 | Tracing is self-hosted inside the tenant without exception, because traces carry prompts and clinical values | `pacEHR-Encounter-Agent-4Pager.md` | 164 | 1 |

---

## Epic 11 — Azure deployment & operations

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-11-01 | The extraction agent is deployed as exactly one dockerized Azure Function (Python container image); no other new compute component is introduced | `pacEHR-Azure-Deployment-Architecture.md` | 11, 15 | 1 |
| REQ-11-02 | Because the Function ships as a container image rather than a code deployment, the hosting plan must support custom containers (Premium/Elastic Premium, Dedicated, or Flex Consumption); plain Consumption is not an option | `pacEHR-Azure-Deployment-Architecture.md` | 64-66 | 1 |
| REQ-11-03 | At least one always-ready instance is configured for the Function, to remove cold start and keep clinician-facing response times consistent | `pacEHR-Azure-Deployment-Architecture.md` | 67-70 | 1 |
| REQ-11-04 | The container image pins the Python runtime and dependency versions, so what passes test in CI is byte-for-byte what runs in production | `pacEHR-Azure-Deployment-Architecture.md` | 68 | 1 |
| REQ-11-05 | The Function authenticates to Azure OpenAI and to SQL using Managed Identity; no credentials are stored in configuration | `pacEHR-Azure-Deployment-Architecture.md` | 93 | 1 |
| REQ-11-06 | Any remaining secret material is stored in Key Vault | `pacEHR-Azure-Deployment-Architecture.md` | 94 | 1 |
| REQ-11-07 | Azure OpenAI is reached only via a Private Endpoint, so clinical prompts never traverse the public internet | `pacEHR-Azure-Deployment-Architecture.md` | 95 | 1 |
| REQ-11-08 | Tracing stays inside the tenant, in the existing Application Insights instance, recording run id, prompt hash, model and provider, token counts, latency, and per-field decisions | `pacEHR-Azure-Deployment-Architecture.md` | 97 | 1 |
| REQ-11-09 | The existing Angular SPA is out of scope for this work and is not redeployed | `pacEHR-Azure-Deployment-Architecture.md` | 4 | 1 |
| REQ-11-10 | The existing API gateway and .NET 8 App Service continue to handle TLS, routing and rate limiting in front of the agent, and are not replaced | `pacEHR-Azure-Deployment-Architecture.md` | 29-30 | 1 |
| REQ-11-11 | The four Phase 1 AI tables are created inside the existing SQL database; no new data store is introduced | `pacEHR-Azure-Deployment-Architecture.md` | 16, 76-78 | 1 |
| REQ-11-12 | The container image is published to a container registry as a normal CI step, using the existing Azure DevOps pipelines, without a new deployment pattern | `pacEHR-Azure-Deployment-Architecture.md` | 72 | 1 |
| REQ-11-13 | Redis cache / prompt caching is deferred out of Phase 1; the design must work correctly without a cache, since fragments and constraints are small and change rarely | `pacEHR-Azure-Deployment-Architecture.md` | 107, 18 | 2 |
| REQ-11-14 | Phase 1 does not enable the memory/learning layer, since it needs accumulated `AI.fieldOutcome` rows to learn from and would add an untested variable to a release that is already consolidating the AI path | `pacEHR-Azure-Deployment-Architecture.md` | 109, 18 | 2 |

---

## Epic 12 — Memory layer (Phase 2)

| REQ id | Requirement — one line, testable | Source | Lines | Phase |
|---|---|---|---|---|
| REQ-12-01 | After a clinician finalizes a field, the agent compares what the AI proposed against what was accepted, and records any difference as a correction event | `pacEHR-Encounter-Agent-4Pager.md` | 92 | 2 |
| REQ-12-02 | Accumulated correction events are condensed into a short instruction block injected into that clinician's next prompt | `pacEHR-Encounter-Agent-4Pager.md` | 92 | 2 |
| REQ-12-03 | Three scopes of memory are tracked independently: the clinician, the clinician–patient pair, and the template field | `pacEHR-Encounter-Agent-4Pager.md` | 92 | 2 |
| REQ-12-04 | Before every request, `before_agent` performs one indexed read of the clinician's accumulated memory summary, empty on first use | `pacEHR-AI-Approach-2-Proposed.md` | 194 | 2 |
| REQ-12-05 | An empty (cold-start) memory yields an empty instruction block, and the run behaves exactly as it would without memory — a new clinician is never worse off | `pacEHR-Encounter-Agent-4Pager.md` | 94 | 2 |
| REQ-12-06 | The memory summary is capped and rewritten in place rather than appended, so a clinician with 5,000 recorded corrections costs the same prompt tokens as one with 50 | `pacEHR-Encounter-Agent-4Pager.md` | 94, 109 | 2 |
| REQ-12-07 | Memory is context and never authority: a learned instruction can never relax a validator or raise a confidence score, so a clinician who repeatedly overrides a correct block cannot silently train the guard away | `pacEHR-Encounter-Agent-4Pager.md` | 94 | 2 |
| REQ-12-08 | `AI.memoryEvent` contains clinical values and therefore requires a defined retention policy | `pacEHR-Encounter-Agent-4Pager.md` | 108 | 2 |
| REQ-12-09 | `AI.memory` holds exactly one active row per scope, and an admin may clear or flag a scope | `pacEHR-Encounter-Agent-4Pager.md` | 109 | 2 |
| REQ-12-10 | The memory layer's benefit is measured, not assumed: its value is unproven until a decline in edit rate per clinician is demonstrated against a memory-off control arm | `pacEHR-AI-Approach-2-Proposed.md` | 284 | 2 |
| REQ-12-11 | If edit rate per clinician is flat after fifty encounters, the memory layer is judged not to be earning its cost and must be switched off | `pacEHR-AI-Approach-2-Proposed.md` | 284 | 2 |

---

## Table A — Non-goals

Explicit out-of-scope items. No story should be written against any row in this table.

| # | Non-goal | Source | Lines |
|---|---|---|---|
| A1 | Comprehension errors are not fixed by this design — ambiguous dictation can still be misread by the model; evidence binding makes the error visible but does not prevent it | `pacEHR-AI-Approach-2-Proposed.md` | 281 |
| A2 | A newly added field is not immediately as accurate as an established one — it starts weaker and improves only with use | `pacEHR-AI-Approach-2-Proposed.md` | 282 |
| A3 | ICD/CPT coding is not a finished, authoritative capability — absent a licensed ICD/CPT code set, `lookup_icd_cpt` degrades to format checking plus mandatory human sign-off | `pacEHR-AI-Approach-2-Proposed.md` | 283 |
| A4 | The memory layer's value is not assumed — it remains unproven until measured, and a flat edit-rate result after fifty encounters means it should be switched off, not kept anyway | `pacEHR-AI-Approach-2-Proposed.md` | 284 |
| A5 | Ambient speech, telephony, the patient roster, and developer tooling are out of scope — only the encounter documentation path is addressed | `pacEHR-Encounter-Agent-4Pager.md` | 3 |

---

## Table B — Open questions

Genuinely undecided items an engineer would need to ask about before building. No
answer is invented below — each is left open exactly as the source documents leave it.

| # | Open question | Nearest source |
|---|---|---|
| B1 | Full column-level DDL for the six `AI` tables is not in either primary document ("Full DDL is held separately from this document") — where does it live, and who owns keeping it consistent with this index? | `pacEHR-Encounter-Agent-4Pager.md` L113 |
| B2 | Is `ABSENT` / `ABSTAINED` a distinct `status` field on `ExtractedValue`, or is it encoded through an empty `value` plus a `confidence` band? The illustrative schema in Approach-2 §2 has no `status` field, but §5's system prompt instructs the model to set "status ABSENT" / "status ABSTAINED." | `pacEHR-AI-Approach-2-Proposed.md` L58-64 vs L263-265 |
| B3 | What is the exhaustive list of PHI elements the masking step must cover? Only name, DOB and MRN are named explicitly — does it also need phone, address, email, SSN, insurance ID, etc.? | `pacEHR-AI-Approach-2-Proposed.md` §4.2 |
| B4 | What specific rule maps evidence and validator outcomes to a HIGH/MEDIUM/LOW confidence band, and which band(s) map to which verdict (accept/review/block)? Both documents state that confidence and verdict derive from validators, but neither gives the mapping. | `pacEHR-Encounter-Agent-4Pager.md` L69; `pacEHR-AI-Approach-2-Proposed.md` L202 |
| B5 | What are the concrete numeric thresholds that gate Level 2 prompt-fragment promotion (minimum evidence-bound rate, exact-match rate, acceptable token/latency delta)? The mechanism is defined; the pass/fail numbers are not. | `pacEHR-Encounter-Agent-4Pager.md` L125 |
| B6 | What edit-rate value or trend precisely counts as "flat" for the memory-layer kill test, and who is authorized to switch the layer off? | `pacEHR-Encounter-Agent-4Pager.md` L129 |
| B7 | What is the retention period for `AI.fieldOutcome` and `AI.memoryEvent`? Both are flagged as needing a retention policy; neither document gives a period. | `pacEHR-Encounter-Agent-4Pager.md` L108, L111 |
| B8 | Is there a defined numeric or time-based gate for when a field graduates from "day one" to "maturity" in the progressive-accuracy model, or is it judged qualitatively? | `pacEHR-AI-Approach-2-Proposed.md` L175-180 |
| B9 | Who approves changes to `AI.fieldConstraint` bounds and `AI.promptFragment` activation, beyond the named roles ("clinical author," "AI/clinical admin")? No approval workflow or RBAC model is specified. | `pacEHR-Encounter-Agent-4Pager.md` L104-105 |
| B10 | Is the injection-pattern list in §4.1 configurable at runtime, or fixed in code? | `pacEHR-AI-Approach-2-Proposed.md` L225-231 |
| B11 | What is the target latency/availability SLO for the extraction call? The 4Pager dashboard shows illustrative example readings (e.g., p95 4.8s), not committed targets. | `pacEHR-Encounter-Agent-4Pager.md` L138 |

---

## Note on excluded supporting documents

`ai-agent-observability.md` and `deliverables-scope-and-roadmap.md` were read in full.
Both describe a broader, differently-scoped "AI Agent Fleet" initiative — self-hosted
LangSmith, eight named agents (A1-A8), risk classes R0-R4 with specific numeric
promotion thresholds, clinician style profiles, and a deliverables-contract framing
(D1-D3). None of this vocabulary appears anywhere in `pacEHR-AI-Approach-2-Proposed.md`
or `pacEHR-Encounter-Agent-4Pager.md`, and the brief for this index instructs indexing
only the proposed system those two documents describe. Requirements were therefore
**not** drawn from either file, to avoid inventing scope the two primary documents do
not themselves ask for. Epic 10 (Observability & evaluation) is instead built entirely
from 4Pager §6, which covers the same ground (traces, evaluation, an edit-rate-based
metric) with a simpler, self-contained design.
