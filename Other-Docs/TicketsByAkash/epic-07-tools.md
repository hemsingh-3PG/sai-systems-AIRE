# Epic 7 — Agent Tools

**Epic id:** E7 · **Phase:** 1 · **Stories:** PEA-701..PEA-705 · **Points:** 18

## Goal
The model reads clinical language and nothing else: it never does date arithmetic, never
computes a BMI, and never decides whether a code is valid. When this epic is done,
`resolve_date`, `compute_bmi` and `lookup_icd_cpt` make those three computations impossible
for the model to perform or guess its way through, and `resolve_prompt`,
`load_encounter_template`, `load_patient_history` and `load_note_text` mean the agent
assembles its own context on the server instead of trusting nine browser calls to have done
it in advance. Every one of the seven is built to one shared construction contract, so the
eighth tool this repository ever needs costs a morning, not a rediscovery.

## Scope
**In:** the seven tools (`resolve_date`, `compute_bmi`, `lookup_icd_cpt`, `resolve_prompt`,
`load_encounter_template`, `load_patient_history`, `load_note_text`); the shared
`@tool`/`ToolRuntime`/`@staticmethod` construction contract; the `wrap_tool_call` hook's
tool-specific logging and failure handling; the empirical check that settles the
`@tool`/`@staticmethod` decorator stacking order for this codebase; the registration list
`create_agent` consumes.

**Out:**
- The six-stage middleware pipeline itself, hook wiring and execution order → **Epic 4**.
  This epic supplies `wrap_tool_call`'s tool-specific behaviour; Epic 4 wires it into
  `middleware=[...]` alongside the other five hooks.
- Field-level validation (range, unit, cross-field, evidence, date-sanity) that consumes
  what these tools return → **Epic 6**. A tool computes or fetches; it never judges
  plausibility.
- Prompt fragment composition, precedence and versioning → **Epic 8**. `resolve_prompt` is
  an entrypoint onto that logic, not a second implementation of it.
- Dynamic Pydantic schema construction from template configuration → **Epic 3**.
  `load_encounter_template` returns the configured data; Epic 3 turns it into the response
  schema.
- PHI masking, de-masking and injection scanning → **Epic 5**.
- REQ-07-09 (the four legacy inference endpoints collapsing into one agent invocation) is
  a consequence of the single-endpoint architecture, not a tool → **Epic 1** (one Python
  service, one endpoint) and **Epic 9** (the two-endpoint API surface) own delivering it.
- REQ-07-10 (`addEditAILogs` replaced by an unconditional server-side write) is the audit
  row, not a tool → **Epic 4** (`after_agent` writes it) and **Epic 10**
  (observability's `AI.agentRun` row) own delivering it.
- The licensed ICD/CPT reference data set itself is a procurement and licensing matter, not
  an engineering task any story in this backlog can close.

## Dependencies
- **Epic 1** — every tool reads through a `core/` singleton (database, document store); none
  opens its own connection. `create_agent` and the tool registry it consumes both live on
  Epic 1's scaffolding.
- **Epic 4** — `wrap_tool_call` is one of the six middleware hooks Epic 4's pipeline wires
  together; this epic supplies that hook's tool-logging and failure-handling body.
- **Epic 3** — `load_encounter_template` returns the same underlying template configuration
  Epic 3 turns into the dynamic response schema; it does not re-read or reinterpret it
  independently.
- **Epic 8** — `resolve_prompt` is the entrypoint onto Epic 8's fragment resolution
  (precedence, version, active/passed-eval); this epic does not reimplement that logic.
- **Epic 5** — text that `load_patient_history` and `load_note_text` pull in mid-run carries
  the same identifiers the original note does, and must pass through Epic 5's masking guard
  before any model call exactly as the original note does.

---

### PEA-701 — Build the shared tool contract: registration, wrap_tool_call, logging, failures

**Type:** Story · **Epic:** E7 · **Phase:** 1 · **Points:** 5
**Depends on:** none · **Satisfies:** REQ-07-05

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want every tool in this repository built against one decorator
contract and one `wrap_tool_call` implementation, so that adding the eighth tool never means
rediscovering the docstring rule, inventing a new logging shape, or leaving a raised
exception to crash a run silently.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`@tool(parse_docstring=True)` is how a tool's docstring becomes the specification the model
reads — the summary and every `Args:` entry are sent to the provider, and the composed
prompt does not repeat them. But `parse_docstring` defaults to `False` and
`error_on_invalid_docstring` defaults to `True`, so the moment someone sets the former
without matching Google-style `Args:` blocks, the whole module raises `ValueError` at import
— not at the call site of the broken tool, but for every tool that shares its module. Left
implicit, this surfaces as a confusing first-import crash. Stated here as a repository rule
and enforced in CI, it is instead a fast, understood failure. The same reasoning applies to
logging and failure handling: seven tools each inventing their own error shape means seven
places a clinical value could leak into a log line, and seven different ideas of what
"the tool failed" means to the rest of the pipeline. One shared `wrap_tool_call`
implementation makes it one place to get right.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A tool is declared with the mandated decorator arguments
  Given a new tool module under pacehr/tools/ defines a callable decorated with @tool
  When the module is imported
  Then the decorator call includes parse_docstring=True
  And the callable's docstring is Google-style with an Args: entry for every parameter
  And the module imports without raising

Scenario: A malformed docstring fails the build, not a production run
  Given a tool function decorated with @tool(parse_docstring=True)
    And its docstring omits the Args: entry for a declared parameter
  When the module is imported
  Then ValueError is raised at import time
  And the failure is caught by tests/unit, before any deployment

Scenario: A tool call is logged without exposing values
  Given the agent invokes any registered tool during a run
  When wrap_tool_call executes
  Then a log entry records the tool name, the run id, and the outcome
  And no argument value or return value is written to that log entry

Scenario: An unexpected tool failure does not crash the run
  Given a tool implementation raises an exception the tool itself did not construct as a refusal
  When wrap_tool_call executes
  Then the exception is caught
  And a ToolMessage carrying a structured error reaches the model
  And the run continues rather than terminating

Scenario: wrap_tool_call runs only when a tool is actually requested
  Given a model response contains no tool call
  When after_model processes that response
  Then wrap_tool_call does not execute
  And no tool-call log entry is written for that turn

Scenario: A tool's declared refusal reaches validation independent of the model's own retelling
  Given compute_bmi returns a structured refusal for a missing unit
  When wrap_tool_call processes that result
  Then a Command updates agent state with the tool name and the refusal's reason code
  And after_model's validation engine can read that reason code without depending on the
    model having restated it correctly
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Registration lives in `pacehr/tools/__init__.py`, exporting one list every tool in this
  epic is added to; Epic 1's `create_agent(tools=...)` call consumes that list directly, so
  a tool left off the list is a diff to that one file, not a hunt.
- `wrap_tool_call`'s tool-logging and failure-handling body lives under `pacehr/tools/`
  (this epic's ownership); Epic 4 wires the hook itself into the six-stage
  `middleware=[...]` pipeline. This story does not define hook order — only this hook's
  content.
- **Decorator stacking order is not decided here.** Before any tool in PEA-702–PEA-705 is
  written, build one throwaway tool with `@tool` above `@staticmethod` and one with the
  reverse order, call `.args_schema.model_json_schema()` on each, and confirm the declared
  parameters appear in `properties` and neither `self` nor `cls` does. Adopt whichever order
  passes for every tool in this epic and record the schema evidence as a code comment on the
  first tool module — per `CLAUDE.md`'s rule that a date only ever marks a measurement
  against a live system. Neither ordering is documented upstream; guessing produces a
  malformed argument schema that presents as a model problem, not a code problem.
- A tool's own body returns a structured result (success or a named refusal) for an
  *expected* outcome — a missing unit, an unresolvable date phrase — and raises only for a
  genuinely unexpected failure (a downstream I/O error). `wrap_tool_call` only catches the
  latter; the former is a normal return value the model and, via `Command`, the validation
  engine both see.
- `ToolMessage` (`from langchain.messages import ToolMessage`) carries the failure back to
  the model; a `Command(update={...})` mirroring a tool's structured refusal into state must
  still include a `ToolMessage` whose `tool_call_id` matches `runtime.tool_call_id`, or
  `ToolNode` raises.
- PHI-safe logging per `CLAUDE.md` § Clinical and PHI rules: log the token, never the value.
  No tool argument or return value is assumed safe to log by default — the logging helper
  logs identity (tool name, run id, outcome), never payload.
- Performance: the failure-handling path adds no I/O of its own — it wraps whatever the
  underlying tool call already did.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/tools/__init__.py` exports the tool registration list consumed by `create_agent`
- [ ] Shared logging and failure-handling helpers implemented under `pacehr/tools/`, imported
      by the `wrap_tool_call` hook Epic 4 registers
- [ ] `tests/unit/test_tool_contract.py` imports every module in `pacehr/tools/` and asserts
      each `@tool` call passes `parse_docstring=True`
- [ ] Same test exercises a deliberately-broken fixture tool and asserts `ValueError` at
      import — the `error_on_invalid_docstring=True` path is proven, not assumed
- [ ] Empirical check performed for the `@tool`/`@staticmethod` order; result and the
      `model_json_schema()` evidence recorded as a code comment before any other tool ships
- [ ] Test asserts a tool call is logged with tool name, run id and outcome only — no
      argument or return value present in the log line
- [ ] Test asserts an unhandled tool exception is caught and returns a `ToolMessage`, and the
      run does not terminate
- [ ] Test asserts wrap_tool_call does not execute on a turn with no tool call
- [ ] Test asserts a tool's structured refusal reaches agent state via `Command`, readable
      without depending on the model's structured output
- [ ] Reviewed against `CLAUDE.md` § Docstrings and comments, § Singletons and § Clinical and
      PHI rules

---

### PEA-702 — Resolve dates from the date of service, never from today

**Type:** Story · **Epic:** E7 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-701 · **Satisfies:** REQ-07-01, REQ-07-04

#### 1. User Story (As a... I want... So that...)

As a clinician, I want a relative date in my dictated note resolved from the encounter's
date of service, so that a note I dictate about "symptoms three days ago" is never dated
from whatever the model believes "today" to be.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The current production prompt literally instructs the model to "calculate the date from
today." A model has no reliable idea what today is — it has no system clock, and nothing in
its context binds it to the wall-clock date the server is running on. The only date this
system can trust is the one already on the encounter: the date of service. `resolve_date`
takes that date and the exact relative phrase from the note, and does the calendar
arithmetic in deterministic Python, so "today" per the model's guess never enters a
computed value that reaches the chart.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A relative day count resolves from the date of service
  Given an encounter with date of service "2026-09-21"
    And the note reads "started three days ago"
  When the agent calls resolve_date with reference_date "2026-09-21" and relative_expression "three days ago"
  Then the tool returns "2026-09-18"
  And the computation reads no clock or calendar value from the runtime environment

Scenario: A named weekday resolves relative to the date of service
  Given an encounter with date of service "2026-09-21"
    And the note reads "seen last Tuesday"
  When the agent calls resolve_date with reference_date "2026-09-21" and relative_expression "last Tuesday"
  Then the tool returns "2026-09-15"

Scenario: An unparseable expression is refused, not guessed
  Given an encounter with date of service "2026-09-21"
    And the note reads "a while back"
  When the agent calls resolve_date with reference_date "2026-09-21" and relative_expression "a while back"
  Then the tool returns a structured refusal with reason code DATE_EXPRESSION_UNRESOLVABLE
  And no date value is returned

Scenario: A missing reference date is refused rather than substituted with the server clock
  Given resolve_date is called with relative_expression "yesterday" and no reference_date
  When the tool executes
  Then the tool returns a structured refusal with reason code REFERENCE_DATE_MISSING
  And the tool does not fall back to the server's current date under any circumstance

Scenario: The resolved date is independent of when the code actually runs
  Given the same reference_date and relative_expression are resolved on two different real days
  When resolve_date executes both times
  Then both calls return the identical resolved date
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module `pacehr/tools/dates.py`. `@staticmethod`, decorated `@tool(parse_docstring=True)` in
  the stacking order PEA-701's empirical check selects — this story does not re-derive it.
- Arguments: `reference_date` (the encounter's date of service, ISO 8601) and
  `relative_expression` (the verbatim phrase from the note, preserved for the evidence trail).
  The model's job is recognising that a relative expression exists and what its text is —
  language understanding. Turning that text plus an anchor date into an absolute date is
  calendar arithmetic, done entirely in this function.
- **The one invariant this tool exists to hold: no call path reads `datetime.now()` or any
  other wall-clock source as a fallback.** A fallback to server time is the exact defect
  this tool replaces, so it is treated as a bug, not a graceful degradation.
- Pure function — no network, no database, no `core/` singleton needed. Fully covered by
  `tests/unit` with no environment.
- Feeds Epic 6's date-sanity validator (REQ-06-06) downstream: this tool computes the value;
  Epic 6 judges whether the resolved date is itself plausible (e.g., not in the future
  relative to the date of service). This story does not perform that judgment.
- Dates of service are not in Epic 5's masking scope (REQ-05-04 names patient name, DOB and
  MRN specifically) — no masking interaction applies to this tool's arguments or return
  value.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/tools/dates.py` implements `resolve_date` per the contract in PEA-701
- [ ] Reason codes `DATE_EXPRESSION_UNRESOLVABLE` and `REFERENCE_DATE_MISSING` are module
      constants, not literals at the return site, per `CLAUDE.md` § Naming
- [ ] `tests/unit/test_dates_tool.py` covers: day-count offset, named weekday, unresolvable
      phrase, missing reference date
- [ ] Test freezes the system clock to two real, far-apart instants and asserts the resolved
      date is identical both times — proving no wall-clock read occurs
- [ ] No `datetime.now()` (or equivalent) call anywhere in `pacehr/tools/dates.py` — enforced
      by test, not by code review alone
- [ ] Reviewed against `CLAUDE.md` § Docstrings and comments and § Numbers

---

### PEA-703 — Refuse BMI computation on a missing unit

**Type:** Story · **Epic:** E7 · **Phase:** 1 · **Points:** 2
**Depends on:** PEA-701 · **Satisfies:** REQ-07-02, REQ-07-04

#### 1. User Story (As a... I want... So that...)

As a clinician, I want the system to refuse to calculate a BMI when the note doesn't state a
unit for height or weight, rather than silently assuming one, so that a wrong unit guess
never turns into a fabricated vital sign on my patient's chart.

#### 2. Business Context & Problem Statement (Why are we doing this?)

A number computed from a guessed unit is worse than no number: it looks exactly as
authoritative as a correct one. This is the same failure this project's own worked example
guards against for a bare weight value with no unit — the answer there is to abstain, not
to assume kilograms because most of the world uses metric, or pounds because the account is
US-based. `compute_bmi` applies that same discipline to its own inputs. The refusal path is
the reason this tool exists; the arithmetic itself is the easy part.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: BMI computes correctly when both units are explicit
  Given height "68 in" and weight "180 lb"
  When the agent calls compute_bmi with value_height=68, unit_height="in", value_weight=180, unit_weight="lb"
  Then the tool returns bmi 27.4

Scenario: A missing weight unit is refused, not guessed
  Given the note states weight as "187" with no unit
  When the agent calls compute_bmi with value_weight=187, unit_weight=None, value_height=68, unit_height="in"
  Then the tool returns a structured refusal with reason code UNIT_MISSING_WEIGHT
  And no numeric BMI is returned

Scenario: A missing height unit is refused, not guessed
  Given the note states height as "170" with no unit
  When the agent calls compute_bmi with value_height=170, unit_height=None, value_weight=80, unit_weight="kg"
  Then the tool returns a structured refusal with reason code UNIT_MISSING_HEIGHT
  And no numeric BMI is returned

Scenario: An unrecognized unit is refused rather than assumed to be the nearest known one
  Given the note states weight using the token "stone-ish"
  When the agent calls compute_bmi with unit_weight="stone-ish"
  Then the tool returns a structured refusal with reason code UNIT_UNRECOGNIZED
  And no conversion is attempted from an assumed nearest unit

Scenario: The refusal becomes a review item, never a silently written value
  Given compute_bmi returns a refusal for a missing unit
  When after_model assigns a verdict to the corresponding field
  Then the field's verdict is "review"
  And the field's status is "ABSTAINED"
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module `pacehr/tools/bmi.py`. `@staticmethod`, decorated `@tool(parse_docstring=True)` in
  the stacking order PEA-701's empirical check selects.
- Arguments: `value_height`, `unit_height`, `value_weight`, `unit_weight`. The set of
  recognized units (height: `in`, `cm`, `m`; weight: `lb`, `kg`) is a named, tested module
  constant per `CLAUDE.md` § Numbers — anything outside it is a refusal, never a coerced
  guess. There is no default unit; a `None` or unrecognized unit is always a refusal.
- Reason codes `UNIT_MISSING_WEIGHT`, `UNIT_MISSING_HEIGHT`, `UNIT_UNRECOGNIZED` are module
  constants, not literals at the raise/return site.
- **This tool computes; it does not judge plausibility.** A successfully computed BMI of 8
  or 200 is returned as computed — Epic 6's range and cross-field validators, not this tool,
  decide whether that value is clinically implausible and block or flag it. Conflating the
  two failure modes (refusing because an input is unusable vs. flagging because an output
  is implausible) would duplicate work Epic 6 already owns.
- Pure function — no network, no database. Fully covered by `tests/unit`.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/tools/bmi.py` implements `compute_bmi` per the contract in PEA-701
- [ ] Recognized unit sets for height and weight are module constants, not inline literals
- [ ] Reason codes are module constants per `CLAUDE.md` § Naming
- [ ] `tests/unit/test_bmi_tool.py` covers: correct computation, missing weight unit, missing
      height unit, unrecognized unit
- [ ] Test asserts a successfully computed implausible value (e.g., BMI 8) is still returned
      by this tool — proving plausibility is deliberately out of scope here
- [ ] Test asserts a refusal maps to verdict "review" and status "ABSTAINED" at the
      after_model boundary
- [ ] Reviewed against `CLAUDE.md` § Docstrings and comments and § Numbers

---

### PEA-704 — Check ICD/CPT format and require sign-off without a licensed code set

**Type:** Story · **Epic:** E7 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-701 · **Satisfies:** REQ-07-03, REQ-07-11

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want `lookup_icd_cpt` to state plainly that it can only check a
code's format when no licensed ICD/CPT code set is configured, so that a clinician's sign-off
on a diagnosis or procedure code is never skipped under the false impression the system
already verified it.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Checking that a code exists, is billable, and is valid for the encounter's Place of Service
requires a licensed ICD/CPT reference data set. This project does not have one today. A tool
that silently claimed full validation it cannot perform would be worse than no tool at all —
it would give a false sense of coverage exactly where billing and compliance risk is
highest. Absent that license, this tool degrades to structural format checking and forces
mandatory human sign-off on every code it sees. That degradation is written into this story
as the actual Phase 1 behaviour, not hidden behind a name that implies more.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Format checking passes for a well-formed code, without asserting real-world validity
  Given the model proposes ICD-10-CM code "E11.9"
    And no licensed ICD/CPT code set is configured
  When the agent calls lookup_icd_cpt
  Then the tool returns status "FORMAT_OK_UNVERIFIED" and mode "DEGRADED"
  And the response states that existence, billability and Place-of-Service validity were not checked

Scenario: A malformed code fails format checking outright
  Given the model proposes code "E1119"
  When the agent calls lookup_icd_cpt
  Then the tool returns status "FORMAT_INVALID"

Scenario: Degraded mode never returns a verdict better than "review"
  Given lookup_icd_cpt returns status "FORMAT_OK_UNVERIFIED"
  When after_model assigns a verdict to the corresponding field
  Then the verdict is "review", never "accept"

Scenario: The tool never claims a validation it cannot perform
  Given no licensed ICD/CPT code set is configured anywhere in the deployment
  When lookup_icd_cpt is called with any well-formed code
  Then the returned status is never "VALID"
  And the response's mode field reads "DEGRADED"
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module `pacehr/tools/coding.py`. `@staticmethod`, decorated `@tool(parse_docstring=True)`
  in the stacking order PEA-701's empirical check selects.
- **Explicit external dependency, not an engineering task:** a licensed ICD-10-CM/CPT
  reference data set. This story delivers format checking only; the integration point for a
  future licensed lookup is a named, empty seam (a settings flag / injection point), not an
  implementation. No story in this backlog closes the licensing dependency itself.
- Format checking covers both ICD-10-CM and CPT structural shapes. It is never elevated to
  imply existence, billability, or Place-of-Service validity — those three checks require
  the licensed set named above.
- Every response carries an explicit `mode` field (`DEGRADED` for the whole of Phase 1),
  so downstream consumers never have to infer which level of checking ran.
- UI/UX: the review item this drives (Epic 9's surface) must say *why* — "code format only,
  not verified against a licensed set" — rather than a generic "needs review." Supplying that
  reason is this tool's responsibility even though rendering it is Epic 9's.
- Whatever format-pattern data this tool reads goes through `core/` per `CLAUDE.md` §
  Singletons — no ad hoc file handle inside the tool.
- Security/compliance: a code accepted here without the licensed set is billing-relevant,
  unverified data; treating `FORMAT_OK_UNVERIFIED` as anything but mandatory-review is the
  exact failure Non-goal A3 in the source index calls out.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/tools/coding.py` implements format checking for ICD-10-CM and CPT shapes
- [ ] Every response includes an explicit `mode` field; Phase 1 always reports `DEGRADED`
- [ ] Status and mode values are module constants, not inline literals
- [ ] `tests/unit/test_coding_tool.py` covers: well-formed unverified, malformed, and the
      invariant that status is never "VALID" while mode is "DEGRADED"
- [ ] Test asserts `FORMAT_OK_UNVERIFIED` never maps to an "accept" verdict
- [ ] The licensed-code-set integration seam exists (named, unimplemented) so wiring a real
      lookup later requires no rewrite of this tool's call signature
- [ ] Dependency on a licensed ICD/CPT code set recorded explicitly as external to this
      backlog, not silently assumed
- [ ] Reviewed against `CLAUDE.md` § Singletons and § Docstrings and comments

---

### PEA-705 — Load prompt, template, history and note context on demand

**Type:** Story · **Epic:** E7 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-701 · **Satisfies:** REQ-07-06, REQ-07-07, REQ-07-08

#### 1. User Story (As a... I want... So that...)

As a clinician, I want the extraction agent to load the current prompt, template, my
patient's prior history and the saved note text directly on the server for each request, so
that what the AI sees always matches the live record instead of a snapshot nine separate
browser calls assembled earlier.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today the browser calls `getPrompt`, `getPreviousEncounterDetails`,
`getImportPatientDetailsToEncounterForm` and `getRoundingNotesByEncounter` to pre-assemble
everything the model might need before it ever runs. That means the browser is guessing in
advance what the agent will require, and whatever it fetched can already be stale by the
time the model actually reasons over it. Moving these four reads onto the server, as tools
the agent invokes directly during its own context assembly, means the agent requests exactly
what the current request needs, when it needs it, against the live record — not a browser's
earlier guess.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: resolve_prompt replaces the browser's getPrompt call
  Given a request for task type "New Encounter" on template "Adult Primary Care Visit"
  When the agent calls resolve_prompt
  Then the tool returns the composed system prompt text for that task type and template
  And no equivalent call to getPrompt occurs anywhere in the request path

Scenario: load_encounter_template returns the current field configuration
  Given template "Adult Primary Care Visit" has 42 configured fields across 6 sections
  When the agent calls load_encounter_template for that templetID
  Then the tool returns all 6 sections and all 42 fields with fieldID, type, unit and description
  And a field edited in the admin page one minute earlier is present in the returned fields

Scenario: load_patient_history replaces both legacy history endpoints
  Given patient "12345" has 3 prior encounters and previously imported detail fields
  When the agent calls load_patient_history for patient "12345"
  Then the tool returns both the prior encounter summaries and the imported detail fields in one response
  And no call to getPreviousEncounterDetails or getImportPatientDetailsToEncounterForm occurs

Scenario: load_note_text replaces getRoundingNotesByEncounter
  Given encounter "98765" has a saved rounding note
  When the agent calls load_note_text for encounter "98765"
  Then the tool returns the exact note text stored for that encounter

Scenario: A context tool fails closed when its record is missing
  Given load_note_text is called for encounter "00000" which has no saved note
  When the tool executes
  Then the tool returns a structured "not found" result, never an empty string treated as a valid note
  And the run does not proceed as though a blank note had been dictated

Scenario: Context tools run deterministically once per request, not by model request
  Given a new extraction request begins
  When before_agent performs context assembly
  Then resolve_prompt, load_encounter_template, load_patient_history and load_note_text each execute exactly once
  And none of their execution depends on the model requesting them as a tool call

Scenario: Text a context tool loads is masked before any model call, same as the original note
  Given load_patient_history returns a prior encounter mentioning a patient's full name
  When that returned text re-enters agent state
  Then the identifier is masked before the next model call
  And Epic 5's masking guard applies to tool-loaded text exactly as it applies to the original note
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module `pacehr/tools/context.py`: `resolve_prompt`, `load_encounter_template`,
  `load_patient_history`, `load_note_text`, each `@staticmethod`, each decorated
  `@tool(parse_docstring=True)` in the stacking order PEA-701's empirical check selects.
- Each tool reads through the matching `core/` singleton — `core/database`'s async accessor
  (`aexecute`, per `CLAUDE.md` § Naming) for SQL reads, the document store singleton for
  anything blob-backed. **No tool opens its own connection** — per this epic's constraint,
  a tool that does pays for a second handshake and no test catches it.
- `resolve_prompt` is an entrypoint onto Epic 8's fragment resolution; it does not
  reimplement precedence, versioning or the active/passed-eval gate.
- `load_encounter_template` returns the template configuration Epic 3 also reads to build
  the response schema; both consume the same underlying data, not two independent reads.
- `load_patient_history` collapses two legacy endpoints (`getPreviousEncounterDetails`,
  `getImportPatientDetailsToEncounterForm`) into one tool and one response shape.
- Existing clinical tables backing these reads remain read-only, per REQ-02-07 — these
  tools never write.
- **Security:** patient history and note text these tools return are not yet masked at the
  moment they load. The pipeline must route this output through Epic 5's masking guard
  before any subsequent model call — this story's obligation is to ensure nothing here
  bypasses that guard, not to reimplement masking itself. Per `CLAUDE.md` § Clinical and PHI
  rules, none of these tools' own logging includes the returned clinical text.
- **API impact:** ships alongside the removal of four legacy browser calls
  (`getPrompt`, `getPreviousEncounterDetails`, `getImportPatientDetailsToEncounterForm`,
  `getRoundingNotesByEncounter`) from the request path — a coordination point with whoever
  retires those calls on the client side, outside this epic's scope.
- **Performance:** these four reads happen once per request in context assembly, not once
  per model turn — repeating them on every tool-loop iteration would multiply DB round trips
  for no benefit, since none of them are expected to change mid-request.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/tools/context.py` implements all four tools, each `@staticmethod` with a
      Google-style docstring per PEA-701's contract
- [ ] Each tool reads through its matching `core/` singleton; no tool constructs its own
      client or connection
- [ ] `load_patient_history` returns prior-encounter summaries and imported detail fields
      together, replacing both legacy endpoints in one call
- [ ] Each tool has a distinct, structured "not found" result — never an empty success
- [ ] `tests/unit/test_context_tools.py` covers all four tools' happy path and not-found path
      against a stubbed `core/` singleton
- [ ] `tests/integration/` covers at least one real round trip per tool against Azure SQL
- [ ] Test asserts these four tools execute exactly once per request from context assembly,
      independent of any model tool-call decision
- [ ] Test asserts none of these tools' log lines contain patient history or note text content
- [ ] Test or integration check confirms tool-loaded text passes through Epic 5's masking
      guard before reaching a model call
- [ ] Reviewed against `CLAUDE.md` § Singletons, § Naming and § Clinical and PHI rules
