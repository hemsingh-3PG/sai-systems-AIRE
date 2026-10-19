# Epic 3 — Template configuration to dynamic schema

**Epic id:** E3 · **Phase:** 1 · **Stories:** PEA-301..PEA-307 · **Points:** 24

## Goal

When this epic is done, an administrator's template configuration *is* the response
schema the provider forces the model to fill. A field added, removed or reworded in the
admin page changes the very next request with no prompt edit, no code change and no
deployment. Two sections that legitimately use the same `fieldID` become two independent
slots carrying two different instructions — which is not true today, and is the single
change that makes the accuracy argument for this project hold.

## Scope

**In:** the per-mapping AI description and the key it is stored under; the authoring and
validation contract for that description; the request-time loader that reads the
template's sections, fields, types, units and descriptions; the generated response model
and its slot keys; the `ExtractedValue` output contract including the three-state
`status` field; the guarantee that a template edit takes effect on the next request.

**Out:** the six middleware hooks that call the loader and attach the schema to the model
call — Epic 04. The system prompt and slot-manifest wording — Epic 08. Validation
verdicts, reason codes and computed confidence — Epic 06. The `AI` schema migration set,
its conventions, and `AI.fieldConstraint` — Epic 02. Injection scanning and PHI
masking/de-masking of `found_in` — Epic 05. Review UX and persistence of proposals —
Epic 09. Metrics over slot maturity and abstention rate — Epic 10.

## Dependencies

**Epic 01** must land first: `core/settings.py`, the `core/database.py` singleton and its
async execution path are what every story here reads through. **Epic 02** must land first
for the migration set and its column-spelling conventions — `AI.fieldDescription` ships
inside that set, though its grain is this epic's requirement, not Epic 02's. **Epic 04**
consumes this epic and cannot start its `before_agent` and `wrap_model_call` work without
PEA-303 and PEA-304. **Epics 04, 06, 07, 08, 09, 10 and 12 all consume `ExtractedValue`
(PEA-305)**; a change to it after this epic closes is a cross-epic change.

---

### PEA-301 — Key the AI field description on `(templetID, sectionID, fieldID)`, never on `fieldID`

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 5
**Depends on:** E1 (core database singleton), E2 (AI schema migration set) · **Satisfies:** REQ-03-01, REQ-03-07

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want a field's AI-facing description stored
against the template/section/field mapping rather than against the field, so that Blood
Pressure in *Review of Systems* and Blood Pressure in *Exam* can carry different
instructions and the model can tell which slot it is filling.

#### 2. Business Context & Problem Statement (Why are we doing this?)

This is the decision the rest of the design rests on, and it was proved from the client's
own stored procedures rather than argued from principle.

`Template.fields.displayName` is a **global** value — one row per `fieldID`, shared by
every template and every section that uses it. One edit to it was measured reaching **179
of 458 templates**. And `fieldID` alone is not unique inside a single template: 35+
templates map the same field into more than one section, which is why the real key is the
triple.

If the AI description is stored the same way — `Template.fields.aiDescription` — it is
global too, and **field 412 in Review of Systems and field 412 in Exam receive an
identical sentence.** That is the collision this project exists to remove, reproduced one
layer up. The consequence is not cosmetic: a `Field(description=...)` is the only
per-field instruction the model ever receives (`CLAUDE.md` § The agent), so two slots
sharing one description are two slots the model cannot distinguish. The instruction that
makes the whole approach work — *"only when re-measured during the physical examination;
if the value was already captured in Review of Systems, leave this empty"* — becomes
unwritable, because a global description cannot name one section. At that point the
accuracy argument collapses and there is no reason to build this service.

**The fix is not a new idea, which is what makes it cheap to accept.** `Encounter.encounterData`
is already keyed `(encounterID, sectionID, fieldID)`, and `usp_getEncounterData` already
joins on `fieldID AND sectionId`. PacEHR has always known that a value belongs to a
section-and-field pair, not to a field. The description simply follows the key the system
already uses for values: `(templetID, sectionID, fieldID)` — the grain of
`Encounter.encounterTempletMapping`. We are extending an existing convention, not
introducing one.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: One template, one fieldID, two sections, two descriptions
  Given template 3 "H&P Initial" maps field 412 "Blood Pressure" into section 11
        "Review of Systems" and into section 12 "Exam"
    And the description for (3, 11, 412) reads "Vital sign as measured and stated at the
        bedside. Systolic over diastolic."
    And the description for (3, 12, 412) reads "Blood pressure only when re-measured
        during the physical examination. If the value was already captured in Review of
        Systems, leave this empty."
   When the template configuration for template 3 is read
   Then two field entries are returned for fieldID 412
    And each carries its own sectionID and its own description text
    And neither description has overwritten the other

Scenario: Both descriptions reach the model attached to the correct slot
  Given the two mappings above
   When an extraction request for template 3 builds its response model
   Then the JSON schema sent to Azure OpenAI carries the properties "s11_f412" and "s12_f412"
    And properties.s11_f412.description equals the section 11 description exactly
    And properties.s12_f412.description equals the section 12 description exactly
    And the substring "re-measured" appears under s12_f412 and under no other property

Scenario: Editing one mapping's description changes nothing else — the displayName counter-test
  Given field 412 is mapped into 40 templates
    And the description for (3, 12, 412) is edited
   When the template configuration for every other template mapping field 412 is read
   Then every one of their descriptions is byte-identical to its value before the edit
    And exactly one stored row changed

Scenario: A description cannot be stored at the global field grain
  Given the deployed database schema
   When the columns of Template.fields are inspected
   Then no column holds an AI description
    And no read path in pacehr/ selects a description keyed on fieldID alone

Scenario: The same fieldID in two sections of two templates keeps four descriptions
  Given field 412 is mapped into sections 11 and 12 of template 3 and of template 7
   When all four mappings are read
   Then four independent descriptions are returned, one per triple

Scenario: Removing a mapping removes only that mapping's description
  Given field 412 is mapped into sections 11 and 12 of template 3
   When the (3, 12, 412) mapping is deactivated
   Then the configuration for template 3 returns one slot for field 412, in section 11
    And that slot's description is unchanged
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Storage is `AI.fieldDescription`, primary key `(templetID, sectionID, fieldID)`, plus
  `description`, `isActive`, `updatedAt`, `updatedBy`. Column spellings reproduce the live
  database's own, including `templetID` — per `CLAUDE.md` § Clinical and PHI rules and
  REQ-02-09. Retro-fitting a spelling convention is forbidden.
- **No existing clinical table is altered.** REQ-02-07 holds the clinical tables read-only
  and unchanged, so the description is a sidecar in the `AI` schema and
  `Encounter.encounterTempletMapping` supplies the triple by join. The DDL ships in the
  migration set Epic 02 establishes and follows its conventions; the *grain* is this
  ticket's requirement and is not Epic 02's to revisit.
- A reviewer verifies this ticket by the **absence** of `Template.fields.aiDescription` as
  much as by the presence of the new table. Both checks are in the DoD.
- The same key discipline binds `AI.fieldConstraint` (REQ-02-02, Epic 02): a unit or a
  plausible bound keyed on `fieldID` alone reproduces exactly this collision for guards —
  field 412's mmHg bounds are not field 412's bounds in every section that reuses it.
  Raised to Epic 02; not resolved here.
- Reads join the field spine `Encounter.encounterTempletMapping → Template.fields` and
  left-join `AI.fieldDescription` on the triple. One statement, one module-level `_SQL`
  constant declared above the class that runs it, parameters bound server-side and never
  interpolated, per `CLAUDE.md` § Naming.
- **Two-spine hazard:** sections are declared in `Template.templateSection` and fields are
  mapped in `Encounter.encounterTempletMapping`, and nothing forces the two to agree — the
  client's own query flags the disagreement because sections were silently disappearing. A
  mapping row whose `sectionID` is missing from `Template.templateSection` still produces a
  slot; it is never dropped silently.
- Security: a description is template configuration and must never contain PHI, and it is
  model-facing instruction text, so it is an admin-authored injection surface. Authoring
  validation is PEA-302; the runtime injection scan covers the note, not configuration
  (Epic 05).
- Tenancy: the configuration read is scoped by the template the encounter resolves to
  server-side. No client-supplied field list is honoured.
- PHI-safe logging per `CLAUDE.md`: log the mapping triple, never description text beside
  note content.
- Performance: the triple is the primary key, so the per-request read is one indexed seek
  range per template, not one read per field.

#### 5. Definition of Done (DoD) Checklist
- [ ] `AI.fieldDescription` created with primary key `(templetID, sectionID, fieldID)`, live
      spelling preserved, in Epic 02's migration set
- [ ] No column added to `Template.fields` or `Encounter.encounterTempletMapping`; asserted
      against `information_schema.columns` on the live database, not against a migration
      document, per `CLAUDE.md` § Code standard ("verify, do not recall")
- [ ] Read statement is one module-level `_SQL` constant with bound parameters, no interpolation
- [ ] `tests/unit/test_template_config.py` covers field 412 in sections 11 and 12 of template 3
      with two distinct descriptions returned intact
- [ ] `tests/integration/test_template_schema.py` asserts `s11_f412` and `s12_f412` carry
      their own `description` in `model_json_schema()` and that neither text appears under
      the other key
- [ ] Test asserts editing one mapping's description leaves every other template's slot text
      byte-identical — the 179-of-458 counter-test
- [ ] Test covers a mapping whose `sectionID` is absent from `Template.templateSection` and
      asserts the slot still appears
- [ ] Grep-level check in CI that no module selects a description keyed on `fieldID` alone
- [ ] `AI.fieldConstraint` key grain raised with Epic 02 in writing

---

### PEA-302 — Author one description per mapping in the admin page, and validate it

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-301 · **Satisfies:** REQ-03-03, REQ-03-01

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want to write one line of description against each
field of each section when I configure a template, so that the instruction the model reads
is authored once by the person who knows what the field means and is never copied into code.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The description is the accuracy lever. It is the single sentence that tells the model what
distinguishes this slot from a similarly-named one, and it is authored by whoever
configures the template — not by an engineer, and not in a prompt file. That is what makes
the refinement loop cheap: when corrections show a description is ambiguous, it is
sharpened in the admin page with no code change and no release.

Two authoring rules protect the design. First, the description is written against the
mapping, so the admin page must present it per section, not once per field — a single
field-level input box on the admin screen silently reintroduces the global collision
PEA-301 removes, whatever the storage does underneath. Second, existing per-field prompt
text in `Template.fields.prompt` is a global value: seeding it into many mappings is a
useful starting point but it is not an authored per-mapping description, and it must not
be able to pass for one.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A description is authored against one mapping only
  Given the administrator is editing section 12 "Exam" of template 3
   When they save the description for field 412
   Then exactly one row of AI.fieldDescription is written, keyed (3, 12, 412)
    And the description for (3, 11, 412) is untouched

Scenario: A multi-line description is rejected at authoring time
  Given a description containing a newline character
   When it is submitted
   Then it is rejected with reason code DESCRIPTION_NOT_ONE_LINE
    And no row is written

Scenario: An over-long description is rejected at authoring time
  Given a description longer than DESCRIPTION_MAX_CHARS
   When it is submitted
   Then it is rejected with reason code DESCRIPTION_TOO_LONG
    And the message states the limit and the submitted length

Scenario: Seeded text from the global per-field prompt is marked unauthored
  Given Template.fields.prompt carries text for field 412
    And the backfill seeds it into all 40 mappings that use field 412
   When the configuration for template 3 is read
   Then each seeded slot reports authored = false
    And a template readiness check lists those slots as awaiting an authored description

Scenario: The extraction agent cannot write a description
  Given the agent's managed identity
   When it attempts INSERT, UPDATE or DELETE against AI.fieldDescription
   Then the statement is refused by the database
    And no _SQL constant under pacehr/ contains a write against that table

Scenario: An edit is attributable
  Given a description is edited
   When the row is read
   Then updatedBy carries the authoring administrator's Entra object id
    And updatedAt carries the edit time
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Validation lives in `pacehr/templates/config.py` beside the model it validates, as one
  method, per `CLAUDE.md` § Code standard. The admin page is the Saisystems team's surface
  and is not code in this repository — this ticket delivers the storage contract, the
  validation rules, the backfill and the readiness check that the admin surface writes
  against.
- UI/UX contract for the admin page, stated so it cannot be misread: **the description
  input is rendered per section-and-field mapping, not once per field.** One box per field
  on the template screen is the bug PEA-301 exists to prevent.
- `DESCRIPTION_MAX_CHARS` is a module constant whose comment carries the measurement that
  produced it — the largest active template's slot count multiplied by the limit, measured
  against the deployment's prompt budget. A literal chosen by taste is forbidden per
  `CLAUDE.md` § Numbers; the measurement is a DoD item, not an estimate.
- Security: writes are a privileged admin path. The agent holds `SELECT` only on
  `AI.fieldDescription` — enforced by grant, not by convention — mirroring the write
  ownership discipline the `AI` tables already follow (REQ-02-01, REQ-08-13).
- Security: descriptions are free text that ends up inside the schema sent to the provider.
  Validation rejects control characters and provider special tokens; it does not attempt
  semantic review of an administrator's clinical wording.
- Compliance: a description must never contain patient data. Validation cannot prove that,
  so the rule is stated in the admin surface and the field is covered by the same audit
  trail as any other template edit.
- Anything the administrator reads — every rejection message and reason code — is a module
  constant, not a literal at the raise site, per `CLAUDE.md` § Naming.

#### 5. Definition of Done (DoD) Checklist
- [ ] Validation rejects newlines, over-length text and control characters, with named
      reason-code constants
- [ ] `DESCRIPTION_MAX_CHARS` set from a recorded measurement against the largest live
      template, with the measurement in the constant's comment
- [ ] Backfill seeds `Template.fields.prompt` per mapping and marks every seeded row
      `authored = false`
- [ ] Readiness check reports, per template, the slots with no authored description
- [ ] `tests/unit/test_template_config.py` covers the newline, over-length and seeded-row cases
- [ ] `tests/integration/` asserts the agent identity is refused a write to `AI.fieldDescription`
- [ ] `updatedBy` / `updatedAt` populated and asserted on an edit
- [ ] The per-mapping authoring requirement is written into the admin-surface contract handed
      to the Saisystems team, with the 179-of-458 measurement cited

---

### PEA-303 — Load the template's sections, fields, types, units and descriptions once per request

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-301 · **Satisfies:** REQ-03-02, REQ-03-04

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want the current template's full configuration read exactly once
per request before any model call, so that every later stage reads one consistent
configuration and a configuration failure ends the run before a model is billed.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today the browser flattens a hierarchy of 458 templates, their sections and ~13,700 field
mappings into three comma-joined strings before the request leaves the client. What reaches
the model has no field ids, no field types, no section-to-field nesting and no per-field
instruction — so nothing can be mapped back deterministically and the model cannot know
that Blood Pressure is numeric and HPI is prose.

The loader is where that stops. It reads the structure the database actually holds:
per slot, a `fieldID`, a name, a type, a unit and the per-mapping description. Everything
downstream — the slot manifest in the prompt, the generated schema, the validators, the
write-back — is a function of what this one read returns. It runs as step 4 of
`before_agent`, once, before any model call.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The configuration carries the minimum set for every slot
  Given template 3 has 2 sections and 7 active field mappings
   When the configuration is loaded
   Then 7 slots are returned
    And every slot carries sectionID, sectionName, fieldID, name, type, unit and description

Scenario: The read happens once per request
  Given an extraction request for template 3
   When the run completes, including a tool call and a second model pass
   Then exactly one template configuration read was issued to the database

Scenario: Slot order is deterministic
  Given template 3 is loaded twice in two separate requests
   When the two slot lists are compared
   Then they are identical in order, ordered by section order then mapping order

Scenario: Inactive mappings are excluded
  Given the (3, 12, 412) mapping has isActive = 0
   When the configuration is loaded
   Then no slot s12_f412 is returned

Scenario: A mapping with no authored description still produces a slot
  Given the (3, 12, 431) mapping has no row in AI.fieldDescription
   When the configuration is loaded
   Then a slot is returned for (3, 12, 431)
    And its description falls back to the field's displayName with its section name
    And the slot reports authored = false

Scenario: A configuration read failure ends the run before any model call
  Given the database read fails
   When before_agent runs
   Then the loader returns a failure result rather than raising
    And no model call is made
    And nothing is written to the encounter

Scenario: Configuration is request-scoped, not cached across requests
  Given two concurrent requests for two different templates
   When both complete
   Then neither run read the other's configuration
    And no template configuration is held on a module-level object between requests
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/templates/config.py`: `TemplateConfiguration` and `TemplateField` (the
  REQ-03-02 minimum set), the `_SQL` constants, and one loader class with one public async
  method. The loader is the module-level singleton per `CLAUDE.md` § Singletons; **the
  configuration it returns is request-scoped state.** Caching template rows on the singleton
  would serve a stale schema after an admin edit and would carry one tenant's configuration
  into another request — the one thing this loader must never do.
- Azure SQL has no native async driver: `mssql_python` is a synchronous PEP 249 driver, so
  the async path is `asyncio.to_thread` around the blocking call, exposed as the `a`-prefixed
  method and with the blocking call not exported (`CLAUDE.md` § Naming).
- Deterministic slot order is not cosmetic: the order feeds the slot manifest and therefore
  the prompt hash (REQ-10-03), and temperature-0 reproducibility (REQ-04-07) is only
  meaningful if the same template produces the same prompt bytes.
- The loader surfaces failure as a value, never an exception. `before_agent` fails closed by
  returning `{"jump_to": "end"}` with `can_jump_to=["end"]` declared, so `after_agent` still
  writes the audit row; Epic 04 owns that hook, and a raise there would destroy the audit row
  for exactly the runs most worth auditing (`CLAUDE.md` § Clinical and PHI rules).
- Performance: one round trip for the whole template, joining both spines — never one read
  per field. The p95 of that read against the largest live template is measured and recorded,
  not estimated (`CLAUDE.md` § Code standard).
- Security: the template is resolved server-side from the encounter, as `getPrompt` already
  does; a client-supplied template id is not trusted to select configuration for another
  tenant's template.
- Logging: log the template id and the slot count. Description text and any note content stay
  out of log lines.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/templates/config.py` defines `TemplateConfiguration` and `TemplateField` with
      `fieldID`, name, type, unit, sectionID, sectionName and description
- [ ] One `_SQL` constant per statement, above the class, parameters bound server-side
- [ ] Async read is `asyncio.to_thread` around the synchronous driver; no blocking twin exported
- [ ] `tests/unit/test_template_config.py` covers: minimum field set, deterministic order,
      inactive mapping excluded, missing-description fallback marked `authored = false`
- [ ] Test asserts exactly one configuration read per request, including a run with a tool call
- [ ] Test asserts a read failure returns a failure value and raises nothing
- [ ] Test asserts no template configuration survives on a module-level object between requests
- [ ] p95 load time for the largest live template measured and recorded in the module comment
- [ ] Reviewed against `CLAUDE.md` § Singletons and § Naming

---

### PEA-304 — Build the response model at request time with `create_model`, one slot per mapping

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-303, PEA-305 · **Satisfies:** REQ-03-05, REQ-03-07

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want the response schema generated from my template
configuration at request time, so that every slot I configure is a slot the provider forces
the model to fill and no part of that schema is hand-written in code.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The current request sends no `response_format` at all: JSON is requested in prose and
whatever comes back is written onto the form unchecked. Replacing that with a hand-written
schema would fix the format problem and keep the real one — a template change would again
need an engineer, a code review and a release.

So the schema is data. One `create_model` call per request turns the loaded configuration
into a Pydantic model with one field per configured `(sectionID, fieldID)` slot, each typed
`ExtractedValue` and each carrying its per-mapping description as `Field(description=...)`.
That description is verified to reach the provider: `model_json_schema()` emits it at
`properties.<slot>.description`, and LangChain hands that JSON Schema to the provider as the
structured-output schema. It is specification, not documentation, and the prompt does not
repeat it.

**The slot key is where the collision is either fixed or reintroduced.** A key derived from
`fieldID` alone — `f412` — collides the moment a template maps a field into two sections, and
it collides silently: the second definition simply replaces the first and one slot disappears
from the schema. The key is derived from the section and the field together, `s{sectionID}_f{fieldID}`,
and it is reversible, so a returned slot routes back to `Encounter.encounterData`'s own
`(encounterID, sectionID, fieldID)` key without a name lookup.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: One slot per configured mapping, no slot hand-written
  Given a configuration with 2 sections and 7 active mappings
   When the response model is built
   Then the model has exactly 7 fields
    And every field is typed ExtractedValue
    And no slot name appears as a literal anywhere under pacehr/

Scenario: The description reaches the schema the provider receives
  Given the slot (3, 11, 412) carries the description "Vital sign as measured and stated at
        the bedside. Systolic over diastolic."
   When model_json_schema() is produced
   Then properties.s11_f412.description equals that sentence exactly

Scenario: The same fieldID in two sections produces two independent slots
  Given field 412 is mapped into section 11 and section 12 of template 3
   When the response model is built
   Then properties s11_f412 and s12_f412 both exist
    And they carry different description text
    And the model has not lost a slot to a key collision

Scenario: A slot key is reversible to its mapping
  Given the slot key "s12_f412"
   When it is parsed
   Then it yields sectionID 12 and fieldID 412
    And the round trip holds for every mapping of every active template

Scenario: The provider enforces the schema, not a client-side retry loop
  Given the built model
   When the model call is composed
   Then response_format is ProviderStrategy(ExtractionResult), passed explicitly
    And the strategy in force at call time is asserted to be the provider strategy

Scenario: A template with no active mappings fails closed
  Given template 9 has zero active field mappings
   When the response model would be built
   Then the run ends before any model call
    And nothing is written to the encounter

Scenario: A slot the manifest does not declare is rejected
  Given the model returns a key "s99_f999" that is not in the configuration
   When the response is parsed
   Then the extra key is rejected rather than written
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/schema/builder.py`; the slot-key format and its parse live in
  `pacehr/schema/contract.py` beside `ExtractedValue`, because Epic 09's write-back needs the
  same parse and a second copy would drift.
- Built with `create_model("ExtractionResult", __base__=BaseModel, __doc__=..., **slot_fields)`,
  where each entry is the two-tuple `(ExtractedValue, Field(description=...))`. The
  `field_definitions` two-tuple form is the verified shape.
- `Field(description=...)` → `model_json_schema()` → `properties.<slot>.description` → the JSON
  Schema LangChain passes to the provider. **This chain is verified, and the whole approach
  depends on it**, so it is asserted by a test rather than assumed.
- Unknown slot keys are rejected by the generated model via `__config__=ConfigDict(...)` on
  `create_model`; the exact config option is confirmed against the Pydantic reference at
  implementation rather than recalled.
- `ProviderStrategy(ExtractionResult)` is passed **explicitly**, never a bare schema type: a
  bare type leaves strategy selection to the model's profile data, and when that data is
  missing or stale LangChain silently selects the tool strategy — the schema is then enforced
  by a client-side retry loop instead of by the provider, and nothing raises
  (`CLAUDE.md` § The agent). Epic 04 owns the runtime assertion that the provider strategy is
  the one in force (REQ-04-06).
- `strict=` is **not** set. Provider acceptance of it is unconfirmed for this deployment and
  API version; it is a spike, not a ticket.
- One compiled agent per process (`CLAUDE.md` § The agent), so the per-request schema cannot be
  baked into the compiled graph. It reaches the call by overriding `response_format` on the
  `ModelRequest` inside `wrap_model_call`. Epic 04 owns that hook; this ticket delivers the
  model and the strategy wrapper it attaches.
- Slots are flat, not nested by section. Flat keys are reversible to `(sectionID, fieldID)`;
  nesting by section name would route on a name that administrators edit and that
  `customSectionName` already overrides per mapping.
- `ExtractedValue` is the one hand-written piece, and REQ-03-05 is satisfied: the **slot set**
  is generated. The per-slot value type is fixed by contract (PEA-305).
- Performance: a model is constructed per request. The cost is measured against the largest
  live template and recorded; if it becomes material it is cached on a fingerprint of the
  configuration, never on `templetID` alone (PEA-306).
- Security: slot keys are derived from integer ids, so no administrator-authored text becomes
  a schema key. Description text is data inside the schema, never an identifier.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/schema/builder.py` builds the model with `create_model` from
      `TemplateConfiguration`; no slot name is a literal in the tree
- [ ] Slot key format and parse are module constants/functions in `pacehr/schema/contract.py`
- [ ] `tests/unit/test_schema_builder.py` asserts `properties.s11_f412.description` and
      `properties.s12_f412.description` are the two distinct authored sentences
- [ ] Property-style test asserts `parse(build(sectionID, fieldID)) == (sectionID, fieldID)`
      across every active mapping of every active template
- [ ] Test asserts slot count equals active mapping count, and no slot is lost to a key collision
- [ ] Test asserts an unknown slot key in a response is rejected
- [ ] Test asserts a zero-slot template ends the run before a model call
- [ ] `response_format=ProviderStrategy(...)` passed explicitly; no bare schema type and no
      `strict=` anywhere
- [ ] Model build time measured against the largest live template and recorded
- [ ] Reviewed against `CLAUDE.md` § The agent and § Numbers

---

### PEA-305 — Define `ExtractedValue`: value, unit, evidence, three-state status and a confidence band

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 3
**Depends on:** none · **Satisfies:** REQ-03-08, REQ-03-09, REQ-03-10

#### 1. User Story (As a... I want... So that...)

As a clinician, I want every value the AI returns to arrive with the words it came from, an
explicit statement of whether it was found, absent or abstained on, and a confidence band
rather than a number, so that I can tell at a glance what the note actually said and what the
AI was unwilling to claim.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today a value arrives as a bare string with no evidence and no status, and the production
system writes `NA` in two entirely different situations: when the note said nothing about the
field, and when the model was unsure about text that was there. **In the chart those two facts
are indistinguishable** — "not documented" and "the AI was guessing" look the same to the next
clinician who reads it. They are clinically different facts and they must be different values.

So `ExtractedValue` carries an explicit `status` with three states: `FOUND`, `ABSENT`,
`ABSTAINED`. Encoding them implicitly — an empty value plus a LOW confidence band — is
rejected, because that reintroduces precisely the defect this design exists to remove.

`confidence` is the band `HIGH`, `MEDIUM` or `LOW` and never a float. A self-reported
probability is not a calibrated measurement, and a number invites arithmetic that means
nothing — an average of model-reported confidences is a number with no referent.

`found_in` carries the exact substring of the note the value came from. It is what makes an
extraction checkable by a human in two seconds, and it is what the review screen shows.

This contract is the seam of the system: nine other epics read it. It is defined here, once.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A found value carries its evidence and a band
  Given a note reading "BP 138/86 at the bedside"
    And the slot s11_f412 "Blood Pressure"
   When extraction completes
   Then s11_f412.status is FOUND
    And s11_f412.value is "138/86"
    And s11_f412.unit is "mmHg"
    And s11_f412.found_in is "BP 138/86 at the bedside"
    And s11_f412.confidence is one of HIGH, MEDIUM, LOW

Scenario: Silence is ABSENT, not an empty FOUND
  Given a note that never mentions oxygen saturation
    And the slot s11_f430 "O2 Saturation"
   When extraction completes
   Then s11_f430.status is ABSENT
    And s11_f430.value is ""
    And s11_f430.unit is ""
    And s11_f430.found_in is ""

Scenario: Uncertainty is ABSTAINED, and it is not the same as ABSENT
  Given a note containing "weight 187" with no unit
    And the slot s11_f425 "Weight" declares unit "kg|lb"
   When extraction completes
   Then s11_f425.status is ABSTAINED
    And s11_f425.found_in is "weight 187"
    And s11_f425.value is ""
    And the status is not ABSENT

Scenario: A unit is never guessed
  Given the note states a weight with no unit
   When the value is returned
   Then unit is ""
    And no unit is inferred from the field's declared unit list

Scenario: Confidence is a band and cannot be a number
  Given a response carrying confidence 0.87 for any slot
   When it is parsed against the contract
   Then parsing fails
    And no numeric confidence can be expressed by the schema

Scenario: The status field cannot be omitted
  Given a response omitting status for slot s11_f412
   When it is parsed against the contract
   Then parsing fails

Scenario: Every field of the contract instructs the model
  Given the generated JSON schema for any slot
   When the ExtractedValue sub-schema is inspected
   Then value, unit, found_in, status and confidence each carry a description
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/schema/contract.py`. Fields: `value: str`, `unit: str`, `found_in: str`,
  `status` restricted to the literal set `FOUND` / `ABSENT` / `ABSTAINED`, and `confidence`
  restricted to `HIGH` / `MEDIUM` / `LOW`. The literal-type construct is standard-library
  typing, not a vendor API.
- Every field carries `Field(description=...)`, because that description is the only per-field
  instruction the model receives and the prompt does not repeat it (`CLAUDE.md` § The agent).
  The system prompt therefore says nothing about JSON validity or key names (REQ-08-07).
- **Cross-field rules are not enforced inside the contract.** "A FOUND value must carry
  non-empty `found_in`" is a deterministic check in `after_model`, owned by Epic 06 — a
  validator embedded in the schema would turn a model mistake into a parse failure and destroy
  the reviewable verdict, when what the clinician needs is the field flagged with its evidence.
- `confidence` here is the model's own band, not the system's verdict. Epic 06 computes the
  verdict from evidence and validator outcomes and never from this value (REQ-06-02). The two
  must not be conflated in any consumer.
- Security / PHI: `found_in` is a verbatim substring of the clinician's note and is PHI. It is
  never written to a log line, a trace attribute or an exception message (`CLAUDE.md` § Clinical
  and PHI rules) and, because masking runs before egress, any identifier inside it comes back
  tokenised and is de-masked in `after_agent` before it reaches the clinician or the chart
  (Epic 05).
- UI/UX: `found_in` is the text the review screen shows beside a flagged field, so nothing is
  committed sight-unseen (REQ-09-07). `ABSENT` and `ABSTAINED` must render differently; a review
  surface that collapses them is a defect against this ticket.
- API impact: this contract is consumed by Epics 04, 06, 07, 08, 09, 10 and 12. Adding,
  renaming or re-typing a field is a cross-epic change and is versioned as one.
- Every status and band value the product emits is a module constant, not a literal at a use
  site, per `CLAUDE.md` § Naming.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/schema/contract.py` defines `ExtractedValue` with the five fields, each with a
      `Field(description=...)`
- [ ] `status` and `confidence` are closed literal sets; no numeric confidence is expressible
- [ ] `tests/unit/test_contract.py` covers: FOUND with evidence, ABSENT on silence,
      ABSTAINED on "weight 187" with no unit, a rejected numeric confidence, a rejected
      missing status
- [ ] Test asserts ABSENT and ABSTAINED are distinct values and neither is derived from
      confidence
- [ ] Test asserts all five descriptions appear in the sub-schema emitted by `model_json_schema()`
- [ ] Test asserts `found_in` never appears in a log record or trace attribute
- [ ] Status and band values are module constants, referenced by every consumer epic
- [ ] Contract signed off by Epic 06 and Epic 09 owners before those epics start

---

### PEA-306 — Make a template edit take effect on the next request, with no deployment

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-303, PEA-304 · **Satisfies:** REQ-03-06

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want a field I add, remove or reword to change the
very next extraction request, so that improving the system is an edit I make myself rather
than a release someone schedules.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The refinement loop this design depends on is: a clinician corrects a field, the correction
shows the description is ambiguous, the description is sharpened, the next note extracts
better. If that loop passes through an engineer and a deployment, it runs quarterly instead of
daily and the accuracy story never materialises.

Two mechanisms can silently break it, and both are ordinary engineering habits. A process-level
cache of template configuration keyed on `templetID` looks correct — the id is stable, after
all — and serves the old description until the next restart. And a schema baked into the
compiled agent at startup is a schema that needs a restart to change, which is exactly the
deployment this requirement forbids. This story exists to make both impossible and to prove it.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A field added in the admin page appears in the next request
  Given a running process that has already served a request for template 3
   When field 431 is mapped into section 12 of template 3 with a description
    And a new extraction request for template 3 arrives
   Then the generated schema contains the property s12_f431 with that description
    And the process was not restarted
    And no prompt fragment was edited

Scenario: A reworded description takes effect on the next request
  Given the description for (3, 12, 412) is edited
   When the next extraction request for template 3 arrives
   Then properties.s12_f412.description carries the new text
    And no cached schema served the old text

Scenario: A removed field disappears from the next request
  Given the (3, 12, 412) mapping is deactivated
   When the next extraction request for template 3 arrives
   Then the generated schema has no property s12_f412

Scenario: A cache keyed on the template id alone is rejected
  Given any cache of built response models
   When its key is inspected
   Then the key is a fingerprint over the ordered slot list and every description
    And a configuration change produces a different key

Scenario: The compiled agent is not rebuilt per request
  Given 100 sequential requests across 12 different templates
   When the run is inspected
   Then create_agent was called once for the process
    And each request carried its own response model
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Default behaviour is no cache at all: the loader reads per request, which REQ-03-04 requires
  anyway. A cache is added only against a measurement, per `CLAUDE.md` § Numbers.
- If a cache is added, the key is a fingerprint over the ordered slot list, types, units and
  description text — never `templetID`, and never `templetID` plus a timestamp the admin page
  does not update. The fingerprint is the same ordering the prompt hash uses (REQ-10-03).
- One compiled agent per process (`CLAUDE.md` § The agent). The per-request schema is attached
  by overriding `response_format` on the `ModelRequest` in `wrap_model_call` (Epic 04). A second
  `create_agent` call per request pays for a second compiled graph and no test catches it.
- No prompt file, fragment or code change accompanies a template edit. Epic 08 composes the slot
  manifest from the same loaded configuration, so both the schema and the manifest move together
  or the request is inconsistent.
- Performance: this is the story that decides whether the per-request read and build are on the
  critical path. Their contribution to end-to-end latency is measured and recorded against the
  largest live template before any cache is considered.
- Security: no configuration crosses a request boundary, so no tenant's template can be served
  from another tenant's warm process.

#### 5. Definition of Done (DoD) Checklist
- [ ] `tests/integration/` adds a mapping through the admin path and asserts the next request's
      schema contains it, with no process restart
- [ ] Test asserts an edited description reaches the next request's schema
- [ ] Test asserts a deactivated mapping disappears from the next request's schema
- [ ] Test asserts `create_agent` is called once per process across many requests and templates
- [ ] If a cache exists, a test asserts its key changes when any description changes
- [ ] Read + build latency contribution measured against the largest live template and recorded
- [ ] Reviewed against `CLAUDE.md` § Singletons and § The agent

---

### PEA-307 — Give a newly added field the full contract and every guard from its first request

**Type:** Story · **Epic:** E3 · **Phase:** 1 · **Points:** 2
**Depends on:** PEA-304, PEA-305 · **Satisfies:** REQ-03-11, REQ-03-12

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want a field added yesterday to produce values that are flagged and
reviewable rather than silently written, so that a first-draft description costs a clinician a
review rather than a wrong value in a chart.

#### 2. Business Context & Problem Statement (Why are we doing this?)

A newly added field arrives with a first-draft description and no correction history. It will
not extract as well as a field that has been in use for months. **That is expected behaviour,
not a defect**, and saying so here prevents it being raised as a bug in week two and prevents a
premature accuracy claim in week one.

What is guaranteed from day one is not accuracy — it is safety. The system starts cautious and
becomes confident as evidence accumulates; it never starts confident and hopes. Concretely, the
generated schema gives a one-day-old slot exactly the same obligations as a mature one: a
required `status`, a required `found_in`, and the same validator registration. There is no
maturity gate anywhere in the build, because a maturity gate is the mechanism by which a weak
field would quietly become an exempt field.

The measure of improvement is edit rate for that field declining over time, not a claimed
percentage.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A new slot's contract is identical to a mature slot's
  Given mapping (3, 12, 431) was created one minute ago
    And mapping (3, 11, 412) has been in use for two years
   When the response model is built
   Then the sub-schema for s12_f431 is structurally identical to the sub-schema for s11_f412
    And both require status, value, unit, found_in and confidence

Scenario: An unauthored description does not exempt a slot from anything
  Given the slot (3, 12, 431) has no authored description and reports authored = false
   When the response model is built
   Then the slot is present in the schema
    And it is not excluded, and no validator is skipped for it

Scenario: A weak description produces a flagged value, not a silent one
  Given a slot whose description is a first draft
    And the note contains text the model reads as a possible match
   When the model returns status FOUND with an empty found_in
   Then the field is flagged for review rather than committed
    And the clinician sees the field with no evidence attached

Scenario: Slot maturity is reported, never acted on inside the schema build
  Given a template with 12 unauthored slots out of 40
   When the configuration is loaded
   Then the 12 unauthored slots are reported for observability
    And the built schema is unchanged by that count
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- No branch anywhere in `pacehr/schema/builder.py` reads a maturity, age or `authored` flag.
  The flag is carried on the loaded configuration for reporting only; the builder never sees a
  reason to treat one slot differently from another.
- The mechanism that makes a weak field safe is the contract itself: `status` and `found_in` are
  required on every slot, so an unevidenced claim cannot be expressed as a confident FOUND
  without the absence of evidence being visible. Epic 06 renders the verdict in `after_model`
  and Epic 09 holds the run for review (REQ-09-04).
- The unauthored-slot count per template is emitted for Epic 10's dashboard alongside edit rate
  per field (REQ-10-16). It is a configuration-quality signal, not a runtime gate.
- UI/UX: a first-draft field will produce more review items in its first weeks. That is the
  intended experience and belongs in the rollout note to clinical leadership, not in a bug queue.
- Security: none specific beyond the epic's rules — no clinical value is logged when the
  unauthored-slot count is reported; the report carries ids and counts only.

#### 5. Definition of Done (DoD) Checklist
- [ ] `tests/unit/test_schema_builder.py` asserts a one-minute-old mapping and a two-year-old
      mapping produce structurally identical sub-schemas
- [ ] Test asserts a slot with `authored = false` is present, complete and not exempted
- [ ] Grep-level check that no maturity, age or `authored` flag is branched on in the builder
- [ ] Unauthored-slot count per template emitted for Epic 10, with ids and counts only
- [ ] Day-one accuracy expectation written into the rollout note for clinical leadership, with
      edit rate named as the measure
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules
