# Epic 12 — Memory Layer (Phase 2)

**Epic id:** E12 · **Phase:** 2 · **Stories:** PEA-1201..PEA-1205 · **Points:** 23

## Goal

Today the ten-thousandth note for a clinician is processed exactly like the first, and
every correction they make is thrown away. When this epic is done, every field a
clinician corrects is captured durably, condensed into a short per-scope instruction,
and folded back into that clinician's next prompt — without that instruction ever being
able to relax a validator or raise a confidence band, and without its benefit ever being
assumed rather than measured.

Both new tables are additive and every read this epic performs degrades to an empty
result on any failure — a missing row, a slow store, or the feature switched off all
produce the same outcome Phase 1 already produces with no memory layer at all. That is
deliberate: this epic is the one most likely to be cut, and every story in it is written
so that cutting it — or measuring it dead and switching it off — is a clean subtraction,
never a partial unravelling of Phase 1.

## Scope

**In:** Capturing every clinician correction as a durable, purgeable event
(`AI.memoryEvent`); condensing corrections into one capped, rewritten-in-place
instruction per scope (`AI.memory`); reading and injecting that instruction into
`before_agent` across the clinician, clinician–patient, and template-field scopes, safe
on cold start and on the memory store's own failure; the structural guarantee that a
learned instruction can never relax a validator or raise a confidence band; and the
falsifiable edit-rate measurement — with a real configuration switch — that decides
whether the layer keeps running.

**Out:** The four Phase 1 `AI` tables (`promptFragment`, `fieldConstraint`, `agentRun`,
`fieldOutcome`) — Epic 2. The validators and the confidence/status computation this
epic's tests hold immune to memory — Epic 6 (validation engine) and Epic 3 (dynamic
schema, confidence, status). The `POST /ai/encounter/resolve` workflow that produces the
finalized field decisions this epic reads — Epic 9. Prompt composition and fragment
precedence, which consumes the memory block this epic produces — Epic 8. The
operational dashboard and general observability instrumentation, including wherever
memory-hit rate and edit rate are actually displayed — Epic 10; this epic owns the
decision rule and the switch, not the tile. Injection scanning and PHI masking — Epic 5,
unaffected by and unaffecting this epic's read path.

## Dependencies

Epic 4 must land first: `before_agent` and the middleware spine (`AgentMiddleware`,
`AgentState`, the six-hook pipeline) are what this epic's read side hooks into. Epic 2's
`AI.fieldOutcome` must exist and be populated: it is the side-by-side proposed/accepted
record this epic diffs to produce a correction event. Epic 9's resolve endpoint must
exist and must call this epic's capture entry point after applying a clinician's
decision — it is the one place a final decision on a flagged field becomes known. Epic
6's validators and Epic 3's confidence/status computation must already exist before this
epic's authority-boundary tests can hold them immune to memory. Epic 10 depends on this
epic in the other direction: it reads the responsive/non-responsive flag PEA-1205
produces, this epic does not read anything of Epic 10's.

---

### PEA-1201 — Capture every clinician correction as an append-only memory event

**Type:** Story · **Epic:** E12 · **Phase:** 2 · **Points:** 3
**Depends on:** none within this epic (Epic 2 `AI.fieldOutcome`; Epic 9 resolve endpoint) · **Satisfies:** REQ-12-01, REQ-02-05, REQ-12-08

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want every field where a clinician's final decision differs
from the AI's proposal captured as an append-only event the moment a review is resolved,
so that the memory layer has verifiable raw material to condense and the clinical values
it contains carry one well-defined retention and purge path from the day the table
exists.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today, when a clinician corrects an AI proposal, the correction is applied to the
encounter and then discarded — nothing durable records that the AI was wrong or what the
clinician actually wanted instead. The tenth time the same clinician fixes the same field
the same way, the system has learned nothing: it asks the identical question and gets
corrected again. `AI.memoryEvent` is the durable record that makes learning possible at
all — an append-only log of every place the AI's proposal and the clinician's final
decision diverged, keyed to the exact field, encounter and clinician involved, written
once and never touched again except by a purge.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A clinician's override is captured as a correction event
  Given an AI run proposed Weight "160 lb" for encounter "ENC-771"
    And the clinician's resolve decision sets the final value to "185 lb"
   When POST /ai/encounter/resolve completes for that field
   Then exactly one AI.memoryEvent row is written
    And it records proposed "160 lb", accepted "185 lb", the field's (templetID,
        sectionID, fieldID), the clinicianID, the patientID, and the run's id
    And the row is never updated or deleted by this or any later request

Scenario: Acceptance without correction writes nothing
  Given an AI run proposed Temperature "98.6 F" for encounter "ENC-772"
    And the clinician's resolve decision accepts "98.6 F" unchanged
   When POST /ai/encounter/resolve completes for that field
   Then no AI.memoryEvent row is written for that field

Scenario: One event per corrected field, not one per encounter
  Given an AI run for encounter "ENC-900" proposed values for 5 fields
    And the clinician's resolve decision changes 2 of those 5 fields
   When POST /ai/encounter/resolve completes
   Then exactly 2 AI.memoryEvent rows are written
    And the 3 unchanged fields produce no rows

Scenario: A patient-data purge removes memory events with everything else
  Given patient "PT-4410" has 12 AI.memoryEvent rows accumulated across several encounters
   When a patient-data purge runs for "PT-4410"
   Then all 12 AI.memoryEvent rows for that patient are deleted
    And no AI.memoryEvent row for "PT-4410" survives under any retention exemption
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Capture lives in `pacehr/memory/events.py`, called from the resolve path (Epic 9) after
  a clinician's decision is applied to a field; it diffs `AI.fieldOutcome`'s proposed
  value against the final value already sitting beside it (REQ-02-04) and writes one row
  per divergent field. This story does not build the resolve endpoint, only the capture
  entry point it must call.
- `AI.memoryEvent` is append-only: no code path outside the purge job issues an `UPDATE`
  or `DELETE` against it. This is enforced by test, not by convention.
- Column-level DDL beyond the columns named in the scenarios above is left to wherever
  source index Table B item B1 resolves ("full DDL is held separately"); this story
  requires only the columns the scenarios exercise. Clinician and patient identifier
  columns follow the same ID-suffix spelling convention already confirmed for
  `templetID`/`fieldID`/`sectionID` (REQ-02-09) — confirm exact live spelling against
  `information_schema.columns` before migration, per `CLAUDE.md` § Code standard.
- Retention: the period is a `Settings` field (`core/settings.py`), never a bare literal.
  The exact value is an open compliance question (source index Table B, item B7) and is
  deliberately not asserted here — only that the mechanism is configurable.
- This story does not build a new purge mechanism. It ensures `AI.memoryEvent`
  participates in the existing patient-data purge path on the same patient identifier
  every other purged clinical table uses.
- PHI: proposed/accepted values are clinical values. Per `CLAUDE.md` § Clinical and PHI
  rules, no such value reaches a log line — log the field identity and the run id, never
  the value.

#### 5. Definition of Done (DoD) Checklist
- [ ] `AI.memoryEvent` created: append-only, one row per corrected field, carrying
      clinicianID, patientID, (templetID, sectionID, fieldID), proposed value/unit,
      accepted value/unit, `found_in`, run id, timestamp
- [ ] `pacehr/memory/events.py` implements the capture entry point, invoked from the
      resolve path
- [ ] `tests/unit/` covers: a correction produces exactly one row, acceptance-as-is
      produces none, one encounter with N corrected fields produces N rows
- [ ] `tests/integration/` proves a patient-data purge deletes every `AI.memoryEvent` row
      for that patient and none for any other patient
- [ ] Retention period is a `Settings` field, not a bare literal; exact value left open
      per source index Table B item B7
- [ ] Test proves no `UPDATE`/`DELETE` path exists on this table outside the purge job
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules — no clinical value in a log
      line

---

### PEA-1202 — Condense corrections into a capped, rewritten-in-place memory summary

**Type:** Story · **Epic:** E12 · **Phase:** 2 · **Points:** 5
**Depends on:** PEA-1201 (Epic 2 `AI.fieldOutcome` retention precedent) · **Satisfies:** REQ-12-02, REQ-12-03, REQ-12-06, REQ-12-09, REQ-02-06

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want every scope's corrections condensed into one capped,
rewritten-in-place summary, so that a clinician's history costs the same prompt budget
however large it grows, and so that I can clear or flag a scope directly when its
learned content goes wrong.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`AI.memoryEvent` grows without bound — that is the point of capturing every correction.
But a prompt cannot be handed that log directly: the clinician with 5,000 corrections
would cost roughly a hundred times the prompt tokens of the clinician with 50, for no
proportional gain, and most of that history restates the same handful of patterns.
`AI.memory` turns the unbounded log into one bounded, current instruction per scope —
rewritten each time new evidence arrives, never appended — so token cost stays flat
regardless of history size, and a human has exactly one row per scope to inspect, clear
or flag rather than a log to search.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The condensed summary is capped regardless of history size
  Given clinician "C-1029" has 5,000 recorded AI.memoryEvent rows
    And clinician "C-2050" has 50 recorded AI.memoryEvent rows
   When the memory condenser rewrites each clinician's AI.memory row
   Then both rewritten summary_text values are at most 500 characters
        (module constant MEMORY_SUMMARY_MAX_CHARS)

Scenario: Rewriting replaces the row rather than appending
  Given clinician "C-1029" has an existing AI.memory row with a 480-character summary_text
    And one new correction event is recorded for that clinician
   When the condenser runs
   Then the row is updated in place with a freshly computed summary_text
    And no historical summary_text is concatenated onto the new one
    And exactly one active AI.memory row still exists for the CLINICIAN scope of "C-1029"

Scenario: An admin clears a scope back to empty without losing history
  Given clinician "C-1029" has a non-empty AI.memory row for the CLINICIAN scope
   When an AI/clinical admin clears that scope
   Then summary_text for that row is set to empty
    And the next request for that clinician reads an empty memory block, identical to
        cold start
    And the underlying AI.memoryEvent history for that clinician is not deleted

Scenario: An admin flags a scope without deleting its history
  Given clinician "C-1029" has a non-empty AI.memory row for the CLINICIAN scope
   When an AI/clinical admin flags that scope
   Then the row is marked is_flagged
    And the next request for that clinician excludes this scope's summary_text from the
        injected memory block
    And the row's summary_text and event history remain intact for audit
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- `AI.memory` holds one row per `(scope_type, scope_key)` — `scope_type` one of
  `CLINICIAN`, `CLINICIAN_PATIENT`, `TEMPLATE_FIELD` (three scopes tracked
  independently, REQ-12-03); `scope_key` is clinicianID alone, clinicianID+patientID, or
  (templetID, sectionID, fieldID) depending on `scope_type`. A unique index on
  `(scope_type, scope_key)` is what makes "exactly one active row per scope" (REQ-12-09)
  a database guarantee rather than an application promise — verified by a test that
  attempts a duplicate insert and expects it rejected.
- Condensation lives in `pacehr/memory/condense.py`, invoked after PEA-1201 records new
  events for a scope. It is deterministic Python, not a model call: a bounded, rule-based
  formatter (dedup by field, most-recent-and-most-frequent pattern wins, truncate to the
  cap) — keeping condensation inside the same "ordinary Python the model cannot skip"
  philosophy the rest of this system is built on, and avoiding a second, uncontrolled LLM
  call this file's API allow-list does not need to cover.
- `MEMORY_SUMMARY_MAX_CHARS = 500` is a module constant per `CLAUDE.md` § Numbers,
  commented as an initial value pending a real token-cost measurement at implementation
  time — the ticket asserts a concrete, testable cap; it does not claim the character
  count is itself a calibrated token budget.
- Column-level DDL beyond `scope_type`, `scope_key` columns, `summary_text`,
  `is_flagged`, `updated_at` is left to wherever source index Table B item B1 resolves,
  same as PEA-1201.
- Admin clear/flag are the only two writes to this table outside the condenser itself —
  both audited (who, when) per the same PHI-safe logging rule as PEA-1201: the action is
  logged, the summary content is not.

#### 5. Definition of Done (DoD) Checklist
- [ ] `AI.memory` created with a unique index on `(scope_type, scope_key)`, plus
      `summary_text`, `is_flagged`, `updated_at`
- [ ] `pacehr/memory/condense.py` implements the deterministic condenser, invoked per
      affected scope after new events are recorded
- [ ] `MEMORY_SUMMARY_MAX_CHARS` module constant enforced; test proves 5,000-event and
      50-event clinicians both produce summaries at or under the cap
- [ ] Test proves rewrite replaces rather than appends
- [ ] Admin clear and flag actions implemented and unit-tested, including that clearing
      preserves `AI.memoryEvent` history
- [ ] Duplicate-insert test proves the unique-per-scope constraint is enforced by the
      database, not application logic alone
- [ ] Reviewed against `CLAUDE.md` § Numbers — the cap is a named constant, not a bare
      literal

---

### PEA-1203 — Inject the per-scope memory block into before_agent, empty on cold start

**Type:** Story · **Epic:** E12 · **Phase:** 2 · **Points:** 5
**Depends on:** PEA-1202 (Epic 4 `before_agent` contract) · **Satisfies:** REQ-12-03, REQ-12-04, REQ-12-05

#### 1. User Story (As a... I want... So that...)

As a clinician, I want my accumulated corrections and the patterns already known for this
patient and this field folded automatically into my next note's context, so that I never
repeat a correction I have already made, and so that the very first time I use the system
— or the first time it runs for anyone — it behaves exactly as it does today.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The memory layer must never make the system worse for a clinician with no history yet.
That is not an edge case to tolerate — it is the design's central safety property, since
a brand-new clinician, or a system with the feature freshly enabled for everyone, cannot
be allowed to regress relative to Phase 1. Reading the three scopes' bounded summaries
and folding them into request state before any model call is the single integration
point every other story in this epic depends on: it is where the write side (PEA-1201,
PEA-1202) becomes something the model actually sees, and where "no memory yet" is proven
to mean "no different," not "broken."

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Cold start yields an empty block and unchanged behavior
  Given clinician "C-9901" has no AI.memory rows in any scope
   When before_agent runs for a new request from "C-9901"
   Then the memory_block state field is an empty string
    And the composed prompt is byte-for-byte identical to the same request with the
        memory middleware uninstalled entirely

Scenario: All three scopes are read and combined
  Given clinician "C-1029" has a non-empty CLINICIAN-scope AI.memory row
    And the pair "C-1029"/"PT-500" has a non-empty CLINICIAN_PATIENT-scope row
    And template field (templetID=12, sectionID=3, fieldID=44) has a non-empty
        TEMPLATE_FIELD-scope row, and that field is in this encounter's template
   When before_agent runs for this request
   Then memory_block contains content drawn from all three rows
    And each read is satisfied by an index seek on (scope_type, scope_key), not a scan

Scenario: A field-scope row for a field outside this template is never included
  Given a TEMPLATE_FIELD-scope row exists for (templetID=99, sectionID=1, fieldID=7)
    And the current request's template is templetID=12
   When before_agent composes memory_block
   Then that row's content is not included

Scenario: The combined block is capped even when many field-scope rows apply
  Given 40 fields in this encounter's template each have a non-empty TEMPLATE_FIELD-scope
        row at the per-row cap
   When before_agent composes the combined memory_block
   Then the combined block does not exceed 2,500 characters (MEMORY_BLOCK_MAX_CHARS)
    And rows are dropped oldest-updated-first until it fits
    And no row's content is truncated mid-line

Scenario: A memory-store failure degrades to cold start rather than failing the run
  Given the AI.memory read raises a connection error
   When before_agent runs
   Then memory_block is set to an empty string
    And the run continues exactly as it would on cold start
    And the error is logged without any clinical value attached
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/memory/middleware.py` as a class-form middleware
  (`MemoryReadMiddleware(AgentMiddleware)`), `state_schema = MemoryState` where
  `class MemoryState(AgentState): memory_block: NotRequired[str]` — the documented
  state-extension pattern (`AgentState`, `NotRequired`) per
  `00-langchain-api-truth.md` §3.
- Implements `before_agent(self, state, runtime) -> dict[str, Any] | None`, returning
  `{"memory_block": <text or "">}`. It declares no `can_jump_to` and never returns
  `jump_to` — it has no path to end or redirect a run; a missing or unreadable memory row
  is not a failure condition, only an empty one. This is itself part of the authority
  boundary PEA-1204 proves: the memory hook cannot even abort a run, let alone bias one.
- `memory_block` is never a required prompt slot under REQ-04-05 — an empty value is
  valid input to prompt composition (Epic 8), unlike a slot whose absence must abort the
  run.
- Runs after injection scanning (REQ-05-01 requires injection scanning first). It has no
  ordering dependency on PHI masking: scope keys (clinicianID, patientID, templetID,
  sectionID, fieldID) come from the encounter record, never from the masked note text.
- Reads: one indexed lookup on the CLINICIAN-scope row, one on the CLINICIAN_PATIENT-scope
  row, one batch indexed lookup across the TEMPLATE_FIELD-scope rows for the fields in
  the current template's manifest — three index seeks against the `(scope_type,
  scope_key)` index PEA-1202 defines, never a scan.
- `MEMORY_BLOCK_MAX_CHARS = 2,500` is a module constant (per `CLAUDE.md` § Numbers)
  bounding the combined text even when many template-field rows apply.
- Uses the existing `database` singleton (`core/database.py`) per `CLAUDE.md` §
  Singletons; no new client or singleton is introduced.
- PHI: `memory_block` is built from clinical values (REQ-12-08). Any log statement
  touching it logs that a block was composed and its length, never its content, per
  `CLAUDE.md` § Clinical and PHI rules.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/memory/middleware.py` implements `MemoryReadMiddleware` with
      `state_schema = MemoryState`, no `can_jump_to` declared
- [ ] `tests/unit/test_memory_middleware.py` covers: cold start equals
      middleware-absent baseline, all-three-scopes composition, field-outside-template
      exclusion, combined-cap drop rule, store-failure degrades to empty
- [ ] `MEMORY_BLOCK_MAX_CHARS` is a module constant with a comment naming the value
- [ ] Index-seek (not scan) verified for each of the three reads
- [ ] No clinical value in `memory_block` reaches a log line
- [ ] Reviewed against `CLAUDE.md` § The agent — hook signature matches the documented
      `before_agent(self, state, runtime)` form exactly

---

### PEA-1204 — Prove memory can never relax a validator or a confidence band

**Type:** Story · **Epic:** E12 · **Phase:** 2 · **Points:** 5
**Depends on:** PEA-1203 (Epic 6 validators; Epic 3 confidence/status) · **Satisfies:** REQ-12-07

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want the memory-derived instruction block structurally
barred from ever touching a validator's bounds, a field's status, or its confidence
band, so that a clinician who repeatedly overrides a correct block cannot silently
retrain the system to stop flagging it.

#### 2. Business Context & Problem Statement (Why are we doing this?)

This is the most important story in the epic by a wide margin. Memory is context and
never authority: a learned instruction can bias what the model tries, but it must never
be able to change what a validator allows, what status a field receives, or how much
confidence its verdict carries. A memory layer able to weaken a guard is a clinical
safety defect, not a feature — a clinician who is simply wrong about a value, repeated
often enough, must not be able to teach the guard to stop catching it. The rest of this
epic makes memory real; this story is what keeps that real thing from becoming
dangerous, and it is proven by making the adversarial case and watching it fail, not by
asserting the principle in a comment.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Repeated overrides do not relax the range validator's BLOCK verdict
  Given clinician "C-1029" has overridden the BLOCK verdict on field "Weight" on each of
        1, 12, and 200 prior encounters, every time keeping a value above the field's
        plausible upper bound
    And the CLINICIAN-scope AI.memory row for "C-1029" reads "Weight: this clinician
        frequently keeps values the validator flags as implausible"
    And AI.fieldConstraint declares a plausible upper bound of 500 lb for "Weight"
   When the next encounter is processed and the model proposes Weight "890 lb"
   Then after_model's range validator evaluates "890 lb" against the 500 lb bound from
        AI.fieldConstraint only
    And the verdict is BLOCK, identical at repetition count 1, 12, and 200
    And the field is not committed

Scenario: A learned instruction cannot upgrade ABSTAINED to FOUND
  Given the CLINICIAN-scope AI.memory row for "C-1029" reads "Always resolve ambiguous
        weight units as kg for this clinician"
    And the note contains "weight 187" with no unit
    And the template field "Weight" declares unit "kg|lb"
   When the extraction agent processes the note with memory injected
   Then the field status is still ABSTAINED
    And confidence is still LOW
    And the response still carries reason code UNIT_AMBIGUOUS
    And no value is written to the encounter form

Scenario: A learned instruction cannot raise confidence from LOW
  Given the CLINICIAN-scope AI.memory row for "C-1029" reads "This clinician's evidence
        is reliable even when the quote is loose"
    And the evidence-check validator would ordinarily hold confidence at LOW because the
        quoted found_in substring does not appear verbatim in the note
   When after_model computes confidence for this field
   Then confidence is LOW, exactly as it would be with no memory present
    And the memory-derived text is not among the inputs the confidence computation
        received

Scenario: The boundary is structural, not just behavioral
  Given the signatures of every validator function and the confidence computation
        function used by after_model
   When tests/unit/test_memory_authority.py inspects each callable's parameters
   Then none accepts a parameter named memory, memory_block, or an equivalent
    And adding such a parameter fails this test, not merely a code review

Scenario: Memory may shape what the model tries, never what the guard allows
  Given the CLINICIAN-scope AI.memory row for "C-1029" reads "This clinician documents
        Temperature in Fahrenheit"
    And the note states "Temp 99.1" with no unit stated
   When the extraction agent processes the note with memory injected
   Then the model's proposed unit reflects the learned instruction
    But after_model still runs the same unit and range validators against
        AI.fieldConstraint
    And a value that fails those validators is still flagged or blocked regardless of
        the memory instruction
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- The enforcement is two-layered, deliberately redundant: a behavioral test suite
  (`tests/unit/test_memory_authority.py`) proving verdicts, status and confidence are
  unchanged in the presence of adversarial memory content; and a structural test
  inspecting validator and confidence-function signatures, so a future change that
  quietly wires memory into either one fails a test immediately rather than surfacing
  as a subtle accuracy drift months later.
- `memory_block` (PEA-1203) is consumed only by prompt composition (Epic 8) as
  context text. No validator, confidence computation, or status assignment in Epic 6 or
  Epic 3 takes it as an input — this story does not modify those functions, it adds the
  external harness that keeps them provably immune.
- A small helper, `pacehr/memory/authority.py::assert_no_memory_parameter`, wraps the
  signature check so it is reusable when new validators are added; it is the one piece
  of production code this story contributes, everything else is test.
- This is the one test suite in the epic that should block a merge or a deploy on
  failure, not merely warn — a regression here is the clinical safety defect this story
  exists to prevent.
- Security/PHI: none beyond what PEA-1203 already established for `memory_block` — this
  story reads no new clinical value, it proves an absence.

#### 5. Definition of Done (DoD) Checklist
- [ ] `tests/unit/test_memory_authority.py` implements all five scenarios above
- [ ] The repeated-override scenario is parametrized over repetition counts 1, 12 and
      200 — proving there is no count at which memory begins to win
- [ ] `pacehr/memory/authority.py::assert_no_memory_parameter` implemented and used by
      the structural test
- [ ] Structural test fails when a memory-shaped parameter is added to any validator or
      confidence function used by after_model (verified by deliberately adding one in a
      throwaway branch during review, then reverting)
- [ ] This suite is wired into CI as a blocking check, not an advisory one
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules — confidence remains the
      band HIGH/MEDIUM/LOW, never a float, under every scenario above

---

### PEA-1205 — Measure edit rate against a memory-off control arm and wire a real kill switch

**Type:** Story · **Epic:** E12 · **Phase:** 2 · **Points:** 5
**Depends on:** PEA-1201, PEA-1203 (Epic 2 `AI.fieldOutcome`; Epic 10 dashboard consumption) · **Satisfies:** REQ-12-10, REQ-12-11

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want the memory layer's benefit measured against a
memory-off control arm using edit rate per clinician, with a real switch to disable it
the moment that measurement goes flat, so that the layer earns its place with evidence
and can be turned off cleanly the moment it stops paying for itself.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The memory layer adds real cost — two tables, a condensation step, prompt tokens on
every request, and a new class of risk PEA-1204 exists to close off. REQ-12-10 and
REQ-12-11 require that cost be justified by a measurement, not an assumption: if edit
rate per clinician is flat after fifty encounters, the layer is not earning its cost and
must be switched off. A feature with no stated falsification condition can only be
un-shipped by argument; this one is designed to be switched off by a number instead, and
the switch has to actually work, not just exist as a recommendation nobody wires up.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Clinicians are split into a stable measurement cohort
  Given clinician "C-4471" hashes into the control (memory-off) arm under the configured
        control-arm split
   When any encounter for "C-4471" is processed at any point before the measurement
        window closes
   Then before_agent's memory read step is skipped for "C-4471"
    And the run is identical to the cold-start case

Scenario: Edit rate is compared once both arms reach fifty encounters
  Given a treatment-arm clinician has completed 50 encounters with memory enabled
    And a control-arm clinician has completed 50 encounters with memory disabled
   When the fifty-encounter comparison runs (MEMORY_MEASUREMENT_WINDOW_ENCOUNTERS = 50)
   Then each arm's edit rate is computed as corrected fields divided by total fields
        presented, over those 50 encounters, from AI.fieldOutcome
    And the two rates are compared directly

Scenario: A flat result trips the non-responsive flag
  Given the treatment arm's edit rate at 50 encounters is not lower than the control
        arm's edit rate
   When the fifty-encounter comparison completes
   Then that clinician's memory scope is marked NON_RESPONSIVE
    And an AI/clinical admin receives a recommendation to disable memory for that scope

Scenario: An improving result leaves the layer on
  Given the treatment arm's edit rate at 50 encounters is measurably lower than the
        control arm's edit rate
   When the fifty-encounter comparison completes
   Then the scope is marked RESPONSIVE
    And no disable recommendation is produced

Scenario: The kill switch is a real deliverable, not a recommendation alone
  Given an AI/clinical admin sets memory_layer_enabled to False for a NON_RESPONSIVE scope
   When before_agent runs for any request in that scope afterward
   Then no AI.memory read occurs
    And memory_block is an empty string
    And the composed prompt is byte-for-byte identical to a clinician who has never had
        a memory row
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Cohort assignment lives in `pacehr/memory/measurement.py`: a deterministic hash of
  clinicianID against a `Settings`-configured control-arm percentage
  (`memory_control_arm_percentage`), stable for a clinician across the whole measurement
  window. No new assignment table is introduced.
- Edit rate is computed from `AI.fieldOutcome` (Epic 2), which already holds the AI's
  proposal beside the clinician's accepted value (REQ-10-07); this story does not
  recompute or own that capture, only the comparison and the decision rule over it.
- "Flat" is defined operationally as: the treatment arm's edit rate at the
  fifty-encounter mark is not lower than the control arm's over the same encounter
  count. This is a deliberately conservative, non-improving reading — Table B item B6
  leaves the precise statistical threshold open, and this ticket resolves it this way
  because the fallback (treat as flat, recommend disabling) is safe and reversible: cold
  start and switched-off are both already proven harmless by PEA-1203.
- `MEMORY_MEASUREMENT_WINDOW_ENCOUNTERS = 50` is a module constant taken directly from
  REQ-12-11 — not re-derived, not restated as a different number elsewhere.
- The kill switch is `memory_layer_enabled` (global) and an optional per-scope override,
  both `Settings` fields (`core/settings.py`) per `CLAUDE.md` § Configuration. It is
  checked at the top of `MemoryReadMiddleware.before_agent` (PEA-1203); when off,
  behavior collapses to the already-tested cold-start path. No new module is needed for
  the switch itself — its realness is proven by the byte-for-byte prompt-equality test,
  not by a comment claiming it works.
- UI/dashboard: the NON_RESPONSIVE/RESPONSIVE flag is exposed as queryable state for
  Epic 10's dashboard to render; this story does not build the dashboard tile, only the
  flag and the switch it recommends.

#### 5. Definition of Done (DoD) Checklist
- [ ] `memory_layer_enabled` and `memory_control_arm_percentage` added as `Settings`
      fields, no bare literals
- [ ] Deterministic cohort assignment implemented and unit-tested for stability (same
      clinician, same arm, across repeated calls)
- [ ] Edit-rate comparison implemented over `AI.fieldOutcome`, gated on
      `MEMORY_MEASUREMENT_WINDOW_ENCOUNTERS = 50`
- [ ] `tests/unit/` covers both branches: flat result → NON_RESPONSIVE, improving result
      → RESPONSIVE
- [ ] `tests/unit/test_memory_kill_switch.py` proves byte-for-byte prompt equality with
      a stubbed store when the switch is off; `tests/integration/` repeats the assertion
      against a real `AI.memory` table
- [ ] The NON_RESPONSIVE/RESPONSIVE flag is exposed as state Epic 10 can query, without
      this story building a dashboard
- [ ] Reviewed against `CLAUDE.md` § Numbers — window and percentage are named
      constants/`Settings` fields, not bare literals
