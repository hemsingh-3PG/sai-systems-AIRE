# Epic 6 — Deterministic validation engine

**Epic id:** E6 · **Phase:** 1 · **Stories:** PEA-601..PEA-608 · **Points:** 32

## Goal

Every value the model returns is checked by ordinary Python before it can reach the chart,
and every field of every run leaves `after_model` carrying exactly one verdict — accept,
review or block — a reason code, and a confidence band derived from facts that can be
re-checked. Nothing in this epic calls a model. When it is done, "a range check ran on this
vital" is something the audit row proves rather than something the model's behaviour implies.

## Scope

**In:** the `after_model` validation chain and the single verdict it emits per field; two-band
range checking; unit resolution and ambiguity detection; cross-field consistency; date
sanity; evidence binding against the note; the derived `HIGH`/`MEDIUM`/`LOW` confidence band;
and the compiler that turns a clinical author's prose into the executable per-field guards
the range, unit and date validators run on.

**Out:**

- Registering the hook in the middleware list and declaring request-scoped state — Epic 4
  (PEA-402). This epic writes the hook body, not the spine it hangs on.
- What is done with a verdict — commit, review queue, clinician override — Epic 9 (PEA-902,
  PEA-903, PEA-904).
- `ExtractedValue` and the three-state `status` field (`FOUND` / `ABSENT` / `ABSTAINED`) —
  Epic 3 (PEA-305). This epic reads that field and may lower it; it does not define it.
- The `AI.fieldConstraint` table, its DDL and who may write it — Epic 2 (PEA-206).
- The reason-code taxonomy and the module that holds the constants — Epic 10 (PEA-1004).
  This epic raises codes and registers the ones it raises; it does not own the taxonomy.
- `resolve_date` and `compute_bmi` — Epic 7 (PEA-702, PEA-703). A tool computes a value; a
  validator checks one. They are not the same job and they are not in the same place.
- PHI masking and de-masking — Epic 5 (PEA-503). Evidence binding reads the masked note; it
  does not produce or reverse it.

## Dependencies

- **Epic 3** must land first: PEA-304 builds the response model whose slots this chain walks,
  and PEA-305 defines `ExtractedValue`, including the `status` field every verdict rule reads.
- **Epic 4** must land first: PEA-402 registers middleware and owns the request-scoped state
  schema this chain reads and writes.
- **Epic 2** (PEA-206) must land before PEA-602: the compiler writes its output to
  `AI.fieldConstraint` and the runtime reads it from there.
- **Epic 5** (PEA-503) must land before PEA-607: evidence binding compares against the note as
  it was sent to the model, which is the masked note.
- **Epic 10** (PEA-1004) owns the reason-code constants. Until it lands, the codes this epic
  raises live in one module of this package and move there when it does. Either way they are
  module constants, never literals at a raise site.
- **Epic 9** consumes this epic's output. Nothing here writes to the chart.

---

### PEA-601 — Run every field of every response through one validation chain in `after_model`

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-305, PEA-402 · **Satisfies:** REQ-06-01, REQ-06-08

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want every extracted field to pass through the same deterministic
check sequence inside the agent's `after_model` hook and to leave it with exactly one recorded
verdict, so that I can show an auditor which checks ran on a given vital without relying on
what the model chose to do.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today whatever the model returns is written to the encounter form unchecked, so a value that
is impossible and a value that is correct arrive on the chart the same way. Validators are
plain Python inside a hook, never tools: a tool the model may decline to call cannot prove a
range check ran on every vital of every encounter, and that is an audit obligation rather than
a preference. The chain is also where the three output states become actionable — `ABSENT`
needs nobody, `ABSTAINED` always needs somebody, and `FOUND` needs the checks — which is
exactly the distinction the current system loses when it writes `NA` for both silence and
uncertainty.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Every slot in the manifest receives exactly one verdict
  Given a template whose compiled schema declares 40 slots
    And a model response parsed into the structured response on agent state
   When after_model completes
   Then the run carries exactly 40 field verdicts
    And each verdict is one of ACCEPT, REVIEW or BLOCK
    And each verdict carries a reason code unless it is ACCEPT

Scenario: The most severe finding decides the field's single verdict
  Given the field "Blood Pressure" collects a RANGE_ABNORMAL finding and an
        EVIDENCE_NOT_FOUND finding
   When the verdicts are resolved
   Then the field's verdict is BLOCK
    And both reason codes are carried on the field for review and for the trace

Scenario: An abstention is reviewed even when every validator passes
  Given a field whose status is ABSTAINED
    And the value passes the range, unit, cross-field, date and evidence validators
   When after_model completes
   Then the field verdict is REVIEW
    And the status remains ABSTAINED
    And no value is written to the encounter form

Scenario: A silent note is accepted and writes nothing
  Given a field whose status is ABSENT and whose value and unit are empty
   When after_model completes
   Then the field verdict is ACCEPT
    And no validator finding is recorded against the field
    And nothing is written to the encounter form for that field

Scenario: A value on a field the model declared ABSENT is a contract breach
  Given a field whose status is ABSENT and whose value is "120/80"
   When after_model completes
   Then the field verdict is BLOCK
    And the reason code is STATUS_VALUE_CONFLICT

Scenario: A validator that raises blocks its field and never ends the run
  Given the unit validator raises on a malformed compiled guard
   When after_model completes
   Then that field's verdict is BLOCK with reason code VALIDATOR_ERROR
    And the remaining 39 fields still receive their verdicts
    And after_agent runs and writes the audit row

Scenario: A slot the model returned that is not in the manifest is discarded
  Given a template whose compiled schema declares 40 slots
    And the parsed response carries a slot key absent from that schema
   When after_model completes
   Then the run records SLOT_UNKNOWN against that key
    And the slot is not written to the encounter form
    And the run still carries exactly 40 field verdicts

Scenario: A tool-call-only response produces no verdicts
  Given the model returns a response containing only tool calls and no structured output
   When after_model runs
   Then no field verdict is emitted
    And no reason code is raised
    And the run continues to the tools node
    And the verdicts from a later response are the run's only verdicts
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/middleware.py` — `ValidationMiddleware`, a class-form
  `AgentMiddleware` subclass whose one public method is the `after_model` hook — and
  `pacehr/validation/verdicts.py` (the verdict ladder and the per-field record). One class per
  surface, one public method, per `CLAUDE.md` § Code standard. The hook is node-style: it
  receives `state`, returns a `dict`, and declares no jump, because the run must continue to
  `after_agent` whatever the verdicts are.
- The chain reads `state["structured_response"]` and the compiled guards loaded once per
  request, and writes one `field_verdicts` entry per slot onto request-scoped state. The state
  schema subclasses `AgentState` with `NotRequired` keys; those declarations belong to PEA-402.
- **The middleware instance is constructed once, where the agent is compiled (PEA-401), and
  holds no per-request data.** Every clinical value it touches comes from `state` and dies with
  the request; a middleware attribute holding a note or a verdict leaks across concurrent
  requests exactly as a shared PHI map would.
- Verdict order is fixed and total: `BLOCK` > `REVIEW` > `ACCEPT`. No finding means `ACCEPT`.
  Status maps first — `ABSENT` accepts, `ABSTAINED` floors at `REVIEW`, `FOUND` runs the chain
  — and the validators can only move a field down the ladder, never up.
- **Status transitions are one-way and downward.** The chain may lower `FOUND` to `ABSTAINED`
  (PEA-604 does). It never raises `ABSTAINED` to `FOUND` and never touches `ABSENT`.
- **`after_model` is entered on every model response, including one that carries only tool
  calls**, because the loop runs `before_model` → `wrap_model_call` → `after_model` → tools node
  → `before_model` rather than branching around the hook. The chain must therefore distinguish
  "nothing to validate yet" from "everything failed validation": with no structured output on the
  response it emits no verdicts and raises no reason codes, and the run proceeds to the tools
  node. Validating an empty response would fabricate a blocked or review field for every slot on
  every tool-using run, and no clinician can action those.
- **Completeness is counted against the manifest, not against the response.** A manifest slot
  absent from the parsed object is recorded as `BLOCK` with `SLOT_MISSING`. Provider-enforced
  structured output (PEA-401) makes that case unreachable; counting it is what proves so on
  every run rather than assuming it.
- Every non-accept verdict carries a reason code from the taxonomy PEA-1004 owns, so a clinician
  reads `UNIT_AMBIGUOUS` rather than a bare rejected number. The codes this epic raises, for that
  ticket to register, are: `STATUS_VALUE_CONFLICT`, `SLOT_UNKNOWN`, `SLOT_MISSING`,
  `VALIDATOR_ERROR`, `NO_GUARD_DEFINED`, `RANGE_IMPLAUSIBLE`, `RANGE_ABNORMAL`,
  `VALUE_NOT_NUMERIC`, `UNIT_AMBIGUOUS`, `UNIT_UNRECOGNISED`, `CROSS_FIELD_BP_ORDER`,
  `CROSS_FIELD_BMI_MISMATCH`, `CROSS_FIELD_INPUT_MISSING`, `DATE_AFTER_ENCOUNTER`,
  `DATE_BEFORE_BIRTH`, `DATE_BEYOND_HORIZON`, `DATE_UNPARSEABLE` and `EVIDENCE_NOT_FOUND`.
- Scenario 1 exists because upstream documentation does not state that the parsed structured
  response is present on state inside `after_model`; it is asserted by an integration test
  before anything is built on it, not assumed.
- **A validator never raises to end a run**, per `CLAUDE.md` § Clinical and PHI rules. The
  chain catches, converts to `BLOCK`, and lets the run reach `after_agent`, because an
  exception skips `after_agent` and destroys the audit row for the run most worth auditing.
- Security: verdict records carry the field key, the verdict and the reason code. No clinical
  value reaches a log line or a trace attribute — PHI-safe logging per `CLAUDE.md`.
- Performance: the chain performs no I/O. Guards and the note arrive on state; a per-field
  query would be ~30 database round trips per encounter inside the hot path. Per-hook p50/p95
  is reported by PEA-1005, and the latency budget is set from that measurement rather than
  guessed now.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/middleware.py` implements `after_model` over every slot in the schema
- [ ] `pacehr/validation/verdicts.py` holds the ladder, the finding record and the status map
- [ ] Reason codes are module constants, never literals at a raise site, per `CLAUDE.md` § Naming
- [ ] `tests/unit/test_validation_spine.py` covers: 40 slots → 40 verdicts, severity resolution,
      `ABSTAINED` floored to REVIEW with all validators passing, `ABSENT` accepted writing
      nothing, `ABSENT` carrying a value blocked, a raising validator blocking one field only,
      and an unknown slot key
- [ ] `tests/unit/test_validation_spine.py` asserts a response carrying only tool calls emits no
      verdict and no reason code, and that the verdicts from the following response are the run's only ones
- [ ] `tests/integration/test_after_model.py` asserts the parsed structured response is readable
      inside `after_model` and that `after_agent` still runs when a validator raises
- [ ] Test asserts the middleware instance holds no request data after a run completes
- [ ] Test asserts no clinical value appears in any log line or trace attribute emitted by the hook
- [ ] Reviewed against `CLAUDE.md` § Singletons and § Clinical and PHI rules

---

### PEA-602 — Compile the clinical author's prose into executable per-field guards

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-206, PEA-301, PEA-302 · **Satisfies:** REQ-06-09

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want the bounds and units I write in prose on a
template field to be compiled into an executable guard and shown back to me before I save, so
that the check that runs in production is the one I approved and not an approximation of it.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Range and unit validation is only as good as the bounds it runs on, and bounds written into
Python are bounds no clinician ever approved. `AI.fieldConstraint` exists so the clinical
author owns them, but a row nobody can read back is a row nobody can trust: prose like "normal
60 to 100, impossible under 20 or over 300" has to become two numeric bands, a unit and a risk
class, and the author has to see that translation before it becomes the guard that blocks a
value on a live chart. Compiling on save also means an unparseable rule is rejected while the
author is still looking at it, instead of silently producing a field with no guard.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Prose compiles into two bands and a unit, and is confirmed before save
  Given a clinical template administrator writes for "Heart Rate":
        "normal 60 to 100 bpm; under 20 or over 300 is impossible"
   When the constraint is compiled
   Then the compiled guard declares unit "bpm"
    And abnormal bounds 60 to 100
    And plausible bounds 20 to 300
    And the compiled bounds are displayed for confirmation before the row is written

Scenario: A field with alternative units compiles both
  Given the administrator writes for "Weight": "kg or lb; 0.5 to 400 kg plausible"
   When the constraint is compiled
   Then the compiled guard declares units "kg|lb"
    And the plausible band is stored against the unit it was written in

Scenario: A composite field compiles one guard per component
  Given the administrator writes for "Blood Pressure":
        "systolic 90-140 normal, 40-300 plausible; diastolic 60-90 normal, 20-200 plausible"
   When the constraint is compiled
   Then the guard declares two components, systolic and diastolic
    And each component carries its own two bands
    And each component carries the role systolic or diastolic for cross-field binding

Scenario: Prose that cannot be compiled is rejected at save, not ignored
  Given the administrator writes for "Serum Ferritin": "use clinical judgement"
   When the constraint is compiled
   Then the save is rejected
    And the rejection names the clause that could not be compiled
    And no row is written to AI.fieldConstraint

Scenario: A field with no compiled guard is never accepted silently
  Given the field "Serum Ferritin" has no row in AI.fieldConstraint
    And the model returns a FOUND value for it
   When after_model completes
   Then the field verdict is REVIEW
    And the reason code is NO_GUARD_DEFINED

Scenario: Guards are read once per request and reach the next request immediately
  Given a constraint row is edited and saved
   When the next extraction request runs
   Then the run uses the edited bounds
    And the guards for the whole template are read in a single query before the model call
    And no query is issued from inside after_model
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/constraints.py`: one public compile entry point taking the
  author's prose and the field's declared type and returning either a compiled guard or a
  rejection naming the clause, plus the loader that reads the template's guards into
  request-scoped state.
- The compiled guard carries: unit or unit alternatives, plausible band, abnormal band, risk
  class, optional components with roles, and for date fields a temporal direction (`past` or
  `future`) and horizon. Every validator in this epic reads it; none carries its own numbers.
- **No clinical bound appears in Python source.** A bound in code is a bound no clinician
  approved and one nobody can change without a deployment. The only numbers in these modules
  are structural, and each is a module constant per `CLAUDE.md` § Numbers.
- Risk class is compiled from the field's declared type: `code` is held strictest, then
  `vital`, then `narrative`. It is what PEA-603 and PEA-607 read when deciding whether a
  finding reviews or blocks.
- **Security: the compiler parses a closed grammar and never evaluates author text.** No
  `eval`, no `exec`, no `compile`, no regular expression assembled from the prose. Constraint
  prose is admin-authored input, and executing it would make the template editor a remote code
  execution surface on the extraction service.
- Compilation happens on the template editor's save path and never at extraction time; the
  agent reads `AI.fieldConstraint` and never writes to it.
- SQL is a `SCREAMING_SNAKE_SQL` module constant with server-side parameter binding, per
  `CLAUDE.md` § Naming. Reads go through `database.aexecute`.
- Performance: one query per request for the whole template, held on state. Constraints are
  small and change rarely, and the design carries no cache — an edit must be live on the very
  next request.
- UI/UX: the confirmation step shows the compiled bands in the guard's own units. An author who
  cannot recognise their intent in the echo has found a compiler bug before it reaches a chart.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/constraints.py` implements compile, rejection and the per-request loader
- [ ] Compiled guard structure covers unit alternatives, both bands, risk class, components with
      roles, and temporal direction for date fields
- [ ] `tests/unit/test_constraints.py` covers: the "Heart Rate" prose above compiling to
      20-300 / 60-100 bpm, the "kg or lb" alternatives, the two-component blood pressure, and
      "use clinical judgement" rejected with the clause named
- [ ] `tests/unit/test_constraints.py` asserts the grammar rejects `__import__('os')` in a prose
      field and that no `eval`, `exec` or `compile` call exists in the module
- [ ] Test asserts a field with no constraint row produces REVIEW with NO_GUARD_DEFINED, never ACCEPT
- [ ] `tests/integration/` asserts an edited constraint row takes effect on the next request with
      no deployment, and that no query is issued from inside `after_model`
- [ ] Every statement is a `SCREAMING_SNAKE_SQL` constant with bound parameters
- [ ] Reviewed against `CLAUDE.md` § Numbers and § Naming

---

### PEA-603 — Range-check every value against two bands, not one threshold

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-601, PEA-602 · **Satisfies:** REQ-06-03

#### 1. User Story (As a... I want... So that...)

As a clinician, I want a physiologically impossible value blocked outright and an abnormal but
genuinely possible value flagged and kept, so that the system stops nonsense reaching the chart
without also stopping me from recording an emergency.

#### 2. Business Context & Problem Statement (Why are we doing this?)

A single cut-off cannot do this job. Set it tight enough to block 700 over 400 and it also
blocks 210 over 115 — a real hypertensive crisis, exactly the reading a clinician most needs
recorded. Set it loose enough to let 210 over 115 through and 700 over 400 goes through with
it. Two bands separate the two questions that were being conflated: *can this value exist at
all* is a blocking question, and *is this value normal* is a review question. The bands come
from the guard the clinical author approved (PEA-602), so tightening one is an edit, not a
release.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A physiologically impossible blood pressure is blocked
  Given a note containing "BP 700/400"
    And the compiled guard for "Blood Pressure" declares plausible bounds
        40 to 300 systolic and 20 to 200 diastolic
   When the range validator runs
   Then the field verdict is BLOCK
    And the response carries reason code RANGE_IMPLAUSIBLE
    And no value is written to the encounter form

Scenario: A hypertensive crisis is flagged and kept
  Given a note containing "BP 210/115"
    And the compiled guard declares abnormal bounds
        90 to 140 systolic and 60 to 90 diastolic
    And plausible bounds 40 to 300 systolic and 20 to 200 diastolic
   When the range validator runs
   Then the field verdict is REVIEW
    And the reason code is RANGE_ABNORMAL
    And the value 210/115 is carried into the review item
    And the review item shows the words "BP 210/115" from the note

Scenario: A value inside both bands is accepted
  Given a note containing "BP 120/80"
   When the range validator runs
   Then the field verdict is ACCEPT
    And no reason code is recorded for the field

Scenario: One implausible component blocks the whole field
  Given a note containing "BP 118/400"
   When the range validator runs
   Then the field verdict is BLOCK
    And the reason code is RANGE_IMPLAUSIBLE
    And the diastolic component is named in the finding

Scenario: A value that is not a number is not parsed into one
  Given the model returns "unobtainable" for a numeric field
   When the range validator runs
   Then the field verdict is REVIEW
    And the reason code is VALUE_NOT_NUMERIC
    And no numeric coercion is attempted

Scenario: Strictness follows the field's risk class
  Given a narrative field whose value is outside its abnormal band
   When the range validator runs
   Then the field verdict is REVIEW
    And the same finding on a field of risk class vital or code is BLOCK
        when the value is outside the plausible band
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/ranges.py`. One function per band comparison, one entry point per
  field, returning findings — no class, because there is no construction to own.
- Band semantics are fixed: outside the **plausible** band is `RANGE_IMPLAUSIBLE` and blocks;
  inside plausible but outside **abnormal** is `RANGE_ABNORMAL` and reviews; inside both is
  clean. A guard that declares only one band declares the plausible one, and the field can then
  only be blocked or accepted — never silently half-checked.
- Numbers are parsed with `decimal.Decimal`, not `float`: a dose or a weight compared with
  binary floating point produces boundary results that differ from what the author wrote.
- Composite fields are checked component by component against the component's own bands, and
  the worst component decides the field, so "BP 118/400" cannot pass on its systolic value.
- **No clinical bound is written in this module.** Every number it compares against arrives on
  the compiled guard; the only constants here are structural.
- Security: findings record the field key, the band that was violated and the reason code. The
  value itself goes to the review payload, not to the log or the trace.
- UI/UX: the review card for `RANGE_ABNORMAL` shows the value, the band it fell outside and the
  quoted words, so the clinician is confirming a reading rather than re-reading their own note.
  The card itself is PEA-903.
- Performance: pure comparison, no I/O, negligible against one model call.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/ranges.py` implements the two-band comparison over scalar and composite guards
- [ ] `tests/unit/test_ranges.py` covers 700/400 blocked, 210/115 reviewed and kept, 120/80
      accepted, 118/400 blocked on the diastolic component, and "unobtainable" reviewed
- [ ] Test asserts a guard with only a plausible band never produces RANGE_ABNORMAL
- [ ] Test asserts `Decimal` parsing, including a boundary value equal to a bound
- [ ] Test asserts risk class changes the verdict for the same finding
- [ ] No numeric clinical bound appears anywhere in the module — asserted by review and by a test
      that runs the validator with an empty guard and gets NO_GUARD_DEFINED, not a default band
- [ ] Reviewed against `CLAUDE.md` § Numbers

---

### PEA-604 — Resolve units from the guard, and abstain rather than guess one

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-601, PEA-602 · **Satisfies:** REQ-06-04

#### 1. User Story (As a... I want... So that...)

As a clinician, I want a number whose unit the note does not state to be handed back to me
rather than assigned a unit by the system, so that a weight used for dosing is never off by a
factor of two because something inferred pounds from a plausible-looking number.

#### 2. Business Context & Problem Statement (Why are we doing this?)

"weight 187" is 187 pounds or 187 kilograms, a two-fold difference on a number that drives
dosing. The inference that looks reasonable — pick the unit that makes the value normal — fails
on its own terms: "temp 99.1" is not a normal reading in either Fahrenheit or Celsius, so
plausibility would have to choose between "abnormal but real" and "impossible" and would pick
one silently. Neither number is hard for a clinician to resolve; both are impossible for the
system to resolve honestly. So it does not try, and the ambiguity becomes one tap in the review
queue instead of a wrong value on a chart.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Ambiguous weight unit is surfaced rather than guessed
  Given a note containing "weight 187" with no unit
    And the compiled guard for "Weight" declares units "kg|lb"
   When the unit validator runs
   Then the field status is ABSTAINED
    And the field verdict is REVIEW
    And confidence is LOW
    And the response carries reason code UNIT_AMBIGUOUS
    And no value is written to the encounter form

Scenario: The value's plausibility is never used to infer a unit
  Given a note containing "temp 99.1" with no unit
    And the compiled guard for "Temperature" declares units "F|C"
   When the unit validator runs
   Then the field verdict is REVIEW
    And the reason code is UNIT_AMBIGUOUS
    And the range validator records no finding for the field
    And neither the Fahrenheit nor the Celsius band is applied

Scenario: A unit stated in the note is carried, never converted
  Given a note containing "weight 84.8 kg"
    And the compiled guard declares units "kg|lb"
   When the unit validator runs
   Then the field verdict is ACCEPT
    And the committed unit is "kg"
    And no conversion to lb is performed or recorded

Scenario: A single declared unit is configuration, not a guess
  Given a note containing "height 178" with no unit
    And the compiled guard for "Height" declares unit "cm" only
   When the unit validator runs
   Then the field verdict is ACCEPT
    And the committed unit is "cm"

Scenario: A unit the guard does not declare is not silently accepted
  Given a note containing "weight 187 stone"
    And the compiled guard declares units "kg|lb"
   When the unit validator runs
   Then the field verdict is REVIEW
    And the reason code is UNIT_UNRECOGNISED
    And no value is written to the encounter form
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/units.py`. The alias table — `lbs`/`pounds` → `lb`, `kgs` → `kg`,
  `°F`/`F`/`fahrenheit` → `F` — is a module constant, and it maps spellings to declared units
  only. **It never maps one unit to another.**
- The rule is about ambiguity, not about absence: one declared unit resolves a unitless value by
  configuration; two or more declared units and no unit in the note is `UNIT_AMBIGUOUS`.
- **This validator lowers `FOUND` to `ABSTAINED`**, which is the one status transition the chain
  makes and the reason the transition is defined as downward-only in PEA-601. The value is
  retained on the review item — it is the unit that is unknown, not the number.
- An unresolved unit suppresses the range validator for that field. Applying a band chosen
  without a unit is the same guess the ticket exists to prevent, one layer down.
- **No conversion, ever.** The note's unit is recorded as written. Conversion changes a clinical
  record into a derived value with no evidence behind it, and the prompt already forbids the
  model from converting (Epic 8 owns that fragment).
- Security: the value and its candidate units go to the review payload; the log line carries the
  field key and the reason code only.
- UI/UX: the review card offers the declared units as choices with **nothing pre-selected**. A
  default selection is the same guess with an extra tap in front of it.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/units.py` implements resolution, the alias table and ambiguity detection
- [ ] `tests/unit/test_units.py` covers "weight 187" with units kg|lb → ABSTAINED / LOW /
      UNIT_AMBIGUOUS with nothing written, and "temp 99.1" with units F|C → REVIEW with no band applied
- [ ] Test asserts "weight 84.8 kg" is accepted and is not converted to lb anywhere in the payload
- [ ] Test asserts a single declared unit accepts a unitless value
- [ ] Test asserts "stone" produces UNIT_UNRECOGNISED rather than a nearest-match
- [ ] Test asserts the status transition is downward only: an ABSTAINED field is never raised to FOUND
- [ ] Alias table is a module constant mapping spellings to declared units only, never unit to unit
- [ ] Reviewed against `CLAUDE.md` § Naming and § Clinical and PHI rules

---

### PEA-605 — Check the fields of one encounter against each other

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-601, PEA-602, PEA-603, PEA-604 · **Satisfies:** REQ-06-05

#### 1. User Story (As a... I want... So that...)

As a clinician, I want values that are each individually plausible but cannot all be true at
once — a systolic under its diastolic, a BMI that does not follow from the height and weight on
the same encounter — caught before they are committed, so that an internally contradictory
chart is never produced silently.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Per-field checks cannot see a transposition. 88 over 122 passes every band a clinician would
write, and is still impossible, because diastolic pressure cannot exceed systolic. A BMI of
22.4 is an unremarkable number that happens to disagree with the 178 cm and 84.8 kg recorded
beside it. These are the errors that survive range checking, and they are caught by comparing
fields rather than by inspecting one. The comparison is also the only honest way to handle
disagreement: when a computed BMI and its inputs conflict, there is no way to know which of the
three is wrong, so all three go to the clinician rather than one being picked.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A transposed blood pressure is blocked
  Given a note containing "BP 88/122"
    And both components are inside their plausible bands
   When the cross-field validator runs
   Then the field verdict is BLOCK
    And the reason code is CROSS_FIELD_BP_ORDER
    And no value is written to the encounter form

Scenario: A BMI that does not follow from the height and weight recorded is reviewed
  Given the encounter records "Height 178 cm" and "Weight 84.8 kg"
    And the model returns 22.4 for "BMI"
   When the cross-field validator runs
   Then the recomputed BMI is 26.8
    And the verdict for BMI, Height and Weight is REVIEW
    And all three carry reason code CROSS_FIELD_BMI_MISMATCH
    And the review item shows the recorded height and weight beside the proposed BMI

Scenario: A BMI inside the rounding tolerance is accepted
  Given the encounter records "Height 178 cm" and "Weight 84.8 kg"
    And the model returns 26.8 for "BMI"
   When the cross-field validator runs
   Then the field verdict is ACCEPT
    And no finding is recorded against Height or Weight

Scenario: A missing unit stops the comparison rather than assuming one
  Given a note containing "weight 187" with no unit
    And the encounter records "Height 178 cm"
    And the model returns a value for "BMI"
   When the cross-field validator runs
   Then no BMI comparison is performed
    And the BMI field verdict is REVIEW
    And the reason code is CROSS_FIELD_INPUT_MISSING

Scenario: A blocked input is never used as a comparison basis
  Given "Weight" was blocked with RANGE_IMPLAUSIBLE
    And the model returns a value for "BMI"
   When the cross-field validator runs
   Then the BMI field verdict is REVIEW with CROSS_FIELD_INPUT_MISSING
    And the blocked weight is not read

Scenario: Rules bind to roles, not to field ids
  Given a template where the same fieldID appears in Review of Systems and in Exam
    And only the Exam mapping carries the systolic and diastolic roles
   When the cross-field validator runs
   Then the blood-pressure ordering rule is applied to the Exam slots only
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/cross_field.py`. It runs once per encounter after every per-field
  verdict is resolved, over the fields that were not blocked.
- **Rules bind to the semantic roles the compiled guard carries** — `systolic`, `diastolic`,
  `height`, `weight`, `bmi` — never to a `fieldID` literal. The same `fieldID` legitimately
  recurs in two sections of a template with different meanings, so a rule keyed on `fieldID`
  would fire on the wrong slot; roles are compiled per mapping by PEA-602.
- **A failed rule marks every participant, not the field that looks most wrong.** There is no
  basis for choosing between a mistyped BMI and a mistyped weight, and choosing anyway is the
  false-confidence behaviour this project exists to remove.
- The BMI comparison recomputes in Python from the validated height and weight. This is not the
  model doing arithmetic — the model is forbidden from that and delegates to `compute_bmi`
  (PEA-703) — it is the check on the result. Where a unit is unresolved the validator refuses to
  compute, exactly as `compute_bmi` refuses.
- The tolerance is a module constant carrying its derivation: a height recorded to the whole
  inch moves BMI by up to ±0.38 kg/m² at adult heights and a weight to the whole pound by a
  further ±0.07, so 0.5 kg/m² is the smallest tolerance that does not flag rounding as
  disagreement. Per `CLAUDE.md` § Numbers, the comment carries that arithmetic.
- Arithmetic uses `decimal.Decimal`; a tolerance comparison in binary floating point fails at
  the boundary it exists to define.
- Security: the review payload carries the participating values because the clinician cannot
  adjudicate without them; the log line and trace attribute carry roles and the reason code only.
- Performance: one pass over the declared rules, not over every pair of fields.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/cross_field.py` implements role binding, the ordering rule and the BMI rule
- [ ] `tests/unit/test_cross_field.py` covers 88/122 blocked, 178 cm + 84.8 kg vs a proposed 22.4
      reviewing all three fields, a proposed 26.8 accepted, "weight 187" with no unit producing
      CROSS_FIELD_INPUT_MISSING, and a blocked weight never being read
- [ ] Test asserts a rule binds by role and not by `fieldID`, using the same `fieldID` in two sections
- [ ] Tolerance constant carries its derivation in the comment and is covered by a boundary test
- [ ] Test asserts the validator never computes a BMI when a unit is unresolved
- [ ] Test asserts no clinical value reaches a log line or trace attribute
- [ ] Reviewed against `CLAUDE.md` § Numbers

---

### PEA-606 — Sanity-check every date against the encounter, not against today

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-601, PEA-602 · **Satisfies:** REQ-06-06

#### 1. User Story (As a... I want... So that...)

As a clinician, I want every extracted date checked against this encounter's date of service
and the patient's date of birth, so that an onset recorded after the visit or before the
patient was born never reaches the chart.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Dates are where relative language becomes a number, and the reference point is the thing that
goes wrong: "two weeks" is two weeks from the date of service, which is frequently not today —
notes are dictated and processed late. `resolve_date` computes from the date of service
(PEA-702), and this validator is the check that the answer is consistent with the encounter
regardless of who computed it. The two impossible cases are cheap to state and unambiguous: a
past event cannot be dated after the visit, and nothing clinical can be dated before the patient
was born.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A past event dated after the encounter is impossible
  Given the encounter's date of service is 2026-09-22
    And the guard for "Symptom onset" declares direction past
    And the extracted value is 2027-01-04
   When the date validator runs
   Then the field verdict is BLOCK
    And the reason code is DATE_AFTER_ENCOUNTER
    And no value is written to the encounter form

Scenario: The reference point is the date of service, never the system clock
  Given the encounter's date of service is 2026-09-22
    And the system clock reads 2026-11-30
    And the guard for "Symptom onset" declares direction past
    And the extracted value is 2026-10-15
   When the date validator runs
   Then the field verdict is BLOCK
    And the reason code is DATE_AFTER_ENCOUNTER

Scenario: A follow-up date after the encounter is correct
  Given the encounter's date of service is 2026-09-22
    And the guard for "Follow-up" declares direction future with a horizon of one year
    And the extracted value is 2026-10-06 quoting "follow up in two weeks"
   When the date validator runs
   Then the field verdict is ACCEPT

Scenario: A date before the patient was born is blocked
  Given the patient's date of birth on the encounter record is 1948-03-14
    And the extracted value for "Symptom onset" is 1946-07-02
   When the date validator runs
   Then the field verdict is BLOCK
    And the reason code is DATE_BEFORE_BIRTH

Scenario: A partial date is not completed by the system
  Given the extracted value for a date field is "3/4"
   When the date validator runs
   Then the field verdict is REVIEW
    And the reason code is DATE_UNPARSEABLE
    And no year is inferred
    And no day-month order is chosen from a locale

Scenario: A future date beyond the declared horizon is reviewed
  Given the encounter's date of service is 2026-09-22
    And the guard for "Follow-up" declares direction future with a horizon of one year
    And the extracted value is 2031-04-02
   When the date validator runs
   Then the field verdict is REVIEW
    And the reason code is DATE_BEYOND_HORIZON
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/dates.py`. Direction (`past` / `future`) and horizon come from the
  compiled guard (PEA-602); this module holds no clinical policy.
- **The date of service and the patient's date of birth are read from the encounter record on
  request-scoped state, never re-derived from the note text and never from the system clock.**
  Scenario 2 exists specifically to fail if anyone reaches for the clock.
- Parsing accepts complete calendar dates only. A partial or order-ambiguous string is a finding,
  not an input to a heuristic: choosing between 3 April and 4 March by locale would silently
  encode a guess into a clinical record.
- Security and PHI: a date of birth is an identifier. It is read in memory for the comparison,
  never written to a log line, a trace attribute or an exception message — PHI-safe logging per
  `CLAUDE.md`. The comparison happens server-side after the model call, so it does not weaken the
  masking that kept the date of birth off the wire (PEA-503).
- The validator checks the result, not the method. It cannot see whether the model delegated to
  `resolve_date` or computed a date itself, and it does not need to — an unattributed date that
  is consistent with the encounter is acceptable, and one that is not is caught either way.
- Performance: pure comparison, no I/O.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/dates.py` implements direction, horizon, birth-date and parse checks
- [ ] `tests/unit/test_dates.py` covers: onset 2027-01-04 against a date of service of 2026-09-22
      blocked; the same check passing the system clock at 2026-11-30 and still blocking 2026-10-15;
      follow-up 2026-10-06 accepted; onset 1946-07-02 against a date of birth of 1948-03-14 blocked;
      "3/4" reviewed with no inference; 2031-04-02 beyond horizon reviewed
- [ ] Test asserts the module never reads the system clock — patched clock, unchanged verdicts
- [ ] Test asserts no date of birth appears in any log line, trace attribute or exception message
- [ ] Horizon and direction are read from the compiled guard, with no default band in the module
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules

---

### PEA-607 — Bind every value to the exact words it came from

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-601, PEA-503 · **Satisfies:** REQ-06-07

#### 1. User Story (As a... I want... So that...)

As a clinician, I want any value whose quoted evidence does not appear in my note word for word
to be stopped, so that nothing reaches the chart that I did not say, however reasonable it looks.

#### 2. Business Context & Problem Statement (Why are we doing this?)

This is the hallucination check, and it is the one check that does not need to understand
medicine. If the quoted substring does not appear in the note, the value is not an extraction —
no matter how plausible it is, and no matter how confident the model claims to be. Making that
assertion mechanical rather than a matter of judgement is what turns "the model seems reliable"
into a number: the evidence-bound rate becomes a measurable hallucination proxy (PEA-1004), and
a fragment edit that quietly drops the requirement to quote source text shows up as a metric
moving rather than as a bad chart six weeks later.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A value whose quote is not in the note is not an extraction
  Given a note reading "BP 120/80, afebrile, lungs clear"
    And the model returns value "128/82" with found_in "BP 128/82"
    And the model reports confidence HIGH
   When the evidence validator runs
   Then the field verdict is BLOCK
    And the reason code is EVIDENCE_NOT_FOUND
    And no value is written to the encounter form
    And the model's reported confidence does not change the verdict

Scenario: The comparison is made against the note the model was given
  Given the note as dictated reads "Mrs. Eleanor Whitfield weighs 84.8 kg"
    And the note sent to the model reads "Mrs. [NAME] weighs 84.8 kg"
    And found_in is "[NAME] weighs 84.8 kg"
   When the evidence validator runs
   Then the quote is found
    And the field verdict is ACCEPT

Scenario: Whitespace from transcription does not fail a real quote
  Given the note contains "BP\n  120/80"
    And found_in is "BP 120/80"
   When the evidence validator runs
   Then the quote is found
    And the field verdict is ACCEPT

Scenario: A paraphrase is not evidence, but the value it produced may still be right
  Given a note reading "blood pressure was one twenty over eighty"
    And the model returns value "120/80" with found_in "BP 120/80"
   When the evidence validator runs
   Then the field verdict is BLOCK with reason code EVIDENCE_NOT_FOUND
    And when the same value is returned with found_in "one twenty over eighty"
    Then the quote is found and the field verdict is ACCEPT

Scenario: A FOUND value with no quote at all is never committed
  Given a field whose status is FOUND and whose found_in is empty
   When the evidence validator runs
   Then a finding is recorded with reason code EVIDENCE_NOT_FOUND
    And the verdict is BLOCK for a field of risk class vital or code
    And the verdict is REVIEW for a field of risk class narrative
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/evidence.py`. The check is `found_in in note` after normalisation —
  a substring test, never a similarity score, a fuzzy match or an edit distance. A threshold
  would make the hallucination check a matter of degree, which is the property being removed.
- **The comparison runs against the note as sent to the model**, which is the masked note held on
  request-scoped state by PEA-503. Comparing against the raw note fails every legitimate quote
  that spans a masked identifier, and the clinician then sees a correct value blocked as a
  fabrication. De-masking happens later, in `after_agent`.
- **Normalisation is exactly two operations, applied identically to both sides:** Unicode NFKC,
  then runs of whitespace collapsed to a single space. Case and punctuation are preserved.
  Whitespace and encoding differences come from how the note was transcribed; every further
  normalisation is one more class of fabrication the check stops catching, so the list is closed
  and lives in one module constant.
- Verdict severity follows risk class (PEA-602): an unbound quote blocks a `vital` or a `code`
  and reviews a `narrative`. A section-summary slot that cannot quote the note is therefore
  reviewed rather than committed — never committed silently.
- Evidence binding constrains the quote, not the value: a value normalised from spoken numbers is
  acceptable as long as the spoken words are quoted, which is why scenario 4 has both halves.
- Security: the quoted span is clinical text. It reaches the review payload, never a log line or a
  trace attribute; the trace records only whether the quote bound, which is what the metric needs.
- Performance: one substring scan per field against a note of a few thousand characters. The note
  is normalised once per request and reused across all fields, not re-normalised per field.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/evidence.py` implements the normalised substring check against the note
      as sent to the model
- [ ] Normalisation is limited to NFKC plus whitespace collapsing, declared as one module constant,
      with a test asserting a case change or a punctuation change fails the match
- [ ] `tests/unit/test_evidence.py` covers: "BP 128/82" absent from a note reading "BP 120/80,
      afebrile, lungs clear" → BLOCK / EVIDENCE_NOT_FOUND even with a self-reported HIGH; a quote
      spanning `[NAME]` bound against the masked note; a newline-and-spaces quote bound; both
      halves of the "one twenty over eighty" pair; an empty `found_in` on a FOUND value
- [ ] Test asserts risk class decides BLOCK versus REVIEW for the same unbound quote
- [ ] Test asserts no fuzzy match, similarity score or threshold exists in the module
- [ ] Test asserts the quoted span never appears in a log line or trace attribute
- [ ] Test asserts the note is normalised once per request, not once per field
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules

---

### PEA-608 — Derive the confidence band from checkable facts, not from the model's opinion

**Type:** Story · **Epic:** E6 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-601, PEA-603, PEA-604, PEA-607 · **Satisfies:** REQ-06-02

#### 1. User Story (As a... I want... So that...)

As a clinician, I want the confidence shown beside a suggested value to be computed from whether
it quoted my note and whether it passed the checks, so that the band I am reading is a
measurement of the extraction rather than the model's opinion of itself.

#### 2. Business Context & Problem Statement (Why are we doing this?)

A model's self-reported confidence is not a calibrated measurement, and the failure is in the
worst direction: a value the model invented arrives marked `HIGH` exactly as often as one it
copied correctly. Deriving the band from facts that can be re-checked — was the quote in the
note, did the validators pass, was the unit resolved — makes the number in front of the
clinician reproducible from the audit row by anyone, months later. It stays a band rather than a
percentage because a percentage invites a question that has no honest answer, and the gap
between what the model claimed and what was derived becomes a calibration metric instead of a
belief.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A clean extraction derives HIGH
  Given a field whose status is FOUND
    And the quote was found in the note
    And the unit was resolved
    And no validator recorded a finding
   When the confidence band is derived
   Then the band is HIGH
    And the field verdict is ACCEPT

Scenario: An abnormal but real value derives MEDIUM and is reviewed
  Given a note containing "BP 210/115"
    And the quote was found in the note
    And the only finding is RANGE_ABNORMAL
   When the confidence band is derived
   Then the band is MEDIUM
    And the field verdict is REVIEW

Scenario: The model's self-reported confidence is never an input
  Given the model returns confidence HIGH for a value whose quote is not in the note
   When the confidence band is derived
   Then the band is LOW
    And the band written to the encounter form and the audit row is LOW
    And the model's self-reported band is recorded beside the derived band for calibration
    And no decision in the run reads the self-reported band

Scenario: An abstention is LOW even when every check passes
  Given a field whose status is ABSTAINED
    And the quote was found in the note
    And no validator recorded a finding
   When the confidence band is derived
   Then the band is LOW
    And the field verdict is REVIEW

Scenario: The band is never a number
  Given any completed run
   When the response, the audit row and the trace are inspected
   Then every confidence value is one of HIGH, MEDIUM or LOW
    And no numeric score, percentage or probability appears beside any field
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Lives in `pacehr/validation/confidence.py`. It runs once per field after the chain completes and
  is a pure function of the findings — same inputs, same band, no I/O, no state.
- The derivation is total, and these three rows are the whole of it:

  | Band | Conditions |
  |---|---|
  | `HIGH` | status `FOUND` · quote bound verbatim · unit resolved · no finding from any validator |
  | `MEDIUM` | status `FOUND` · quote bound · at least one REVIEW-level finding · no BLOCK-level finding |
  | `LOW` | everything else — status `ABSTAINED`, quote unbound, any BLOCK-level finding, or an unresolved unit |

- **The model's self-reported `confidence` is not an input.** It is recorded beside the derived
  band so the distance between the two can be measured (PEA-1004, PEA-1005); no branch anywhere
  in the run reads it. Treating it as even a minor input would reintroduce the self-report the
  rest of this epic exists to replace.
- The derived band overwrites the `confidence` field on the value that leaves the service, so the
  clinician and the audit row see the same band, per `CLAUDE.md` § Clinical and PHI rules.
- Band and verdict are related but not the same thing and neither is computed from the other:
  `MEDIUM` always accompanies `REVIEW`, and `LOW` accompanies `REVIEW` or `BLOCK`, but an
  abstention is `LOW` with every check passed, because abstention is about certainty and the
  validators measure plausibility.
- UI/UX: the band is what the review card shows beside the value and the quote (PEA-903). It is
  three words because three words is what the underlying evidence supports.
- API impact: `HIGH`/`MEDIUM`/`LOW` is the contract, and a numeric confidence is not
  representable in the response at all — the field's type forbids it (PEA-305).

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/validation/confidence.py` derives the band as a pure function of status, evidence,
      unit resolution and validator findings
- [ ] `tests/unit/test_confidence.py` is table-driven over every combination of status, evidence
      bound, unit resolved and highest finding severity, asserting the mapping is total
- [ ] Test asserts a self-reported HIGH on an unbound quote derives LOW, and that the self-reported
      band is recorded but read by no decision
- [ ] Test asserts an ABSTAINED field with every check passing derives LOW and verdict REVIEW
- [ ] Test asserts "BP 210/115" with only RANGE_ABNORMAL derives MEDIUM
- [ ] `tests/integration/` asserts no numeric confidence appears in the response, the audit row or
      the trace for any field of any run
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules
