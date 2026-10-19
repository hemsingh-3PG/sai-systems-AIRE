# Epic 3 — Template configuration to dynamic schema (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic
**Title:** Turn each template's configuration into the schema the model must fill

**Description:** An administrator's template configuration is the response schema that Azure OpenAI forces the model to fill. Each request reads the template's sections and fields from the database, builds a zod schema with one slot per section-and-field mapping, and binds it to that request's model call. A field added, removed or reworded in the template changes the very next request, with no prompt edit, no code change and no deployment. Every slot returns the same value contract: a status, the quoted evidence, the value, its unit, a remark and a confidence band. The remaining work gives each mapping its own AI description, so that a field used in two sections carries two different instructions, and lets administrators write and check those descriptions.

### PEA-301
**Title:** Key each field's AI description on (templetID, sectionID, fieldID)

**Description:**
As a clinical template administrator, I want a field's AI description stored against the template, section and field mapping rather than against the field, so that Blood Pressure in Review of Systems and Blood Pressure in Exam can carry different instructions and the model can tell which slot it is filling.

Today a slot's description comes from `Template.fields.prompt`, which is one value per `fieldID`, shared by every template and section that uses the field. The slots `s11_f412` and `s12_f412` already exist, but they get the same sentence, so the model cannot tell them apart: on template 457, 9 fields sit in two sections each, and each pair is described identically. An instruction such as "only when re-measured during the physical exam; if Review of Systems already has it, leave this empty" cannot be written for one section. Values in `Encounter.encounterData` are already keyed by section and field, and the description should follow the same key.

**Scope**
- in: a description store keyed `(templetID, sectionID, fieldID)` in the `AI` schema, with no change to any clinical table
- in: reading it in the same per-request template load, falling back to today's `fieldName: prompt` when a mapping has no stored description
- in: tests proving that two sections get two descriptions and that one edit changes one slot
- out: writing and validating descriptions (PEA-302), bounds and units (`AI.fieldConstraint`, Epic 2), the system prompt (Epic 8)

**Acceptance criteria**
- With field 412 mapped into sections 11 and 12 of template 3, each with its own stored description, the loaded config returns two fields for 412, each with its own sectionID and its own text.
- The JSON schema sent to Azure OpenAI has `s11_f412` and `s12_f412`, each with its own `description`, and the section-12 text ("re-measured") appears under no other key.
- Editing the description for (3, 12, 412) changes exactly one stored row, and every other template's slot text stays byte-identical.
- Field 412 in sections 11 and 12 of templates 3 and 7 returns four independent descriptions.
- A mapping with no stored description still produces a slot, described as today (`fieldName: prompt`, or `fieldName` alone).
- Removing the (3, 12, 412) mapping leaves one slot for field 412, in section 11, with its description unchanged.
- No column is added to `Template.fields` or `Encounter.encounterTempletMapping`, checked against `information_schema.columns` on DEV.

**Technical notes**
- The read stays one round trip per template: a `*_SQL` constant in `src/repositories/templateRepository.ts` that left-joins the description on the triple, with `@templateId` bound and never interpolated.
- `src/services/templateService.ts` uses the stored description when there is one. `src/schema/builder.ts` does not change, because it already uses `field.description`.
- The table ships in the `AI` migration set (`migrations/sql`, `npm run migrate`): forward-only, every column commented, the live spelling `templetID` kept.
- A description is instruction text sent to the model. It never holds patient data, and log lines carry the triple only, never the text.
- Tests: `tests/unit/services/templateService.test.ts`, `tests/unit/schema/builder.test.ts`, and a wire check in `tests/unit/agents/encounter.test.ts`.

**Before you build (due diligence)**
- The Epic 2 owner withdrew `AI.fieldDescription` on 2026-10-06 and chose the existing field and section prompts instead. Before writing any DDL, get a decision from the owner and the client: reopen the table, or keep global descriptions and accept the collision.
- In DEV, count how many templates map one fieldID into more than one section, and how many templates each shared prompt reaches. Section 4, "Vital Signs - Updated", with its prompt "Summarize the vital signs", is used by 175 of 458 templates, so editing that prompt today changes all of them.
- `usp_getTemplateMapping` belongs to the pacEHR API and the UI uses it too. Confirm whether this service may own a new read-only procedure, or must add its own SQL constant beside it.
- The client values recall most right now. Run `npm run eval` before and after writing per-section descriptions for template 457's 9 shared fields and its 14 Physical Exam fields, and record the change in recall.
- gpt-4.1 retires on 2027-04-14. Confirm that its successor follows per-slot `description` text inside a strict schema in the same way, and rerun the eval on it.

---

### PEA-302
**Title:** Author one description per mapping in the admin page, and validate it

**Description:**
As a clinical template administrator, I want to write one line of description against each field of each section when I configure a template, so that the instruction the model reads is written once, by the person who knows the field, and is never copied into code.

The description is the main lever for accuracy. When corrections show that a description is unclear, it is sharpened in the admin page, with no code change and no release. Two rules protect the design. The admin page asks for the description per section-and-field mapping, never once per field, because one box per field brings back the collision PEA-301 removes. Text seeded from the global `Template.fields.prompt` is marked as not authored, so it cannot pass for a written description.

**Scope**
- in: the validation rules and their reason codes, the backfill from `Template.fields.prompt`, a readiness report of unauthored slots per template, and the authoring contract handed to the admin-page team
- in: `updatedBy` (the author's Entra object id) and `updatedAt` on every edit
- out: the admin page itself (the Saisystems team's pacEHR UI and API), any review of clinical wording, and the injection scan of the note (Epic 5)

**Acceptance criteria**
- Saving the description for field 412 in section 12 of template 3 writes exactly one row, keyed (3, 12, 412), and leaves (3, 11, 412) untouched.
- A description containing a newline is refused with `DESCRIPTION_NOT_ONE_LINE`, and nothing is written.
- A description longer than `DESCRIPTION_MAX_CHARS` is refused with `DESCRIPTION_TOO_LONG`, and the message gives the limit and the submitted length.
- A description containing control characters or model special tokens is refused with its own reason code.
- After the backfill, every seeded slot reports `authored: false`, and the readiness report lists those slots for each template.
- The extraction agent has no write path to the description table: no statement in this repository writes to it, checked in review.
- An edit stores the author's Entra object id in `updatedBy` and the edit time in `updatedAt`.

**Technical notes**
- Validation is one function beside the loader, with every reason code and every message an exported constant.
- `DESCRIPTION_MAX_CHARS` is a constant whose comment records the measurement behind it: the largest active template's slot count times the limit, against the deployment's input budget.
- Descriptions end up inside the schema sent to Azure OpenAI. Validation rejects control characters and model special tokens. It does not judge clinical wording.
- A description never contains patient data. Validation cannot prove that, so the admin page states the rule, and an edit is audited like any other template edit.
- Tests: `tests/unit/services/` covers the newline, over-length, control-character and seeded-row cases.

**Before you build (due diligence)**
- Find out which service performs the write. The admin page is part of the pacEHR UI and API (C#). If the write goes through that code, the rules must be built there too, and this repository can only check them when it reads. Agree the split with the Saisystems team.
- PEA-301's original design denied the agent write access by a database grant. The Epic 2 owner decided on 2026-10-05: no database roles and no GRANTs. Confirm that "no write statement in this repository" is enough.
- Measure before you choose `DESCRIPTION_MAX_CHARS`. Today template 457's 99 slot descriptions total 9,181 characters (the longest field prompt is 420), and its schema is about 22,400 tokens. Measure input tokens and the provider's acceptance with longer descriptions on the largest template, on gpt-4.1 and on its successor.
- On template 457, 33 of 99 fields have a prompt and 66 have none. Agree with the client who writes the missing ones, and in what order. Start with the Physical Exam fields: their section's only instruction is "Summarize the vital signs", and that has been linked to missed exam findings on the reference queries.
- The template tables have audit triggers. Confirm that the new table gets the same audit trail, and that `updatedBy` comes from the validated Entra token, never from the request body.

---

### PEA-303
**Title:** Load the template's sections, fields, types, units and descriptions per request

**Description:**
As a platform engineer, I want the current template's configuration read exactly once per request, before any model call, so that every later step reads one consistent configuration and a failed read ends the run before a model is billed.

Today the UI flattens templates, sections and field mappings into comma-joined strings, with no ids, no field types and no per-field instruction. The loader reads the structure that the database holds instead. `templateService.getAIConfig` reads `usp_getTemplateMapping` and the template's name in parallel, and returns the sections in the procedure's order, each with its fields. Field types are loaded but not yet used, and units are not loaded, because no template table has a unit column.

**Scope**
- in: the repository (two SQL constants), the row mapper, `templateService.getAIConfig` and the DTO it returns
- in: loading per request in the guard's `template_load` step, with no cache
- in (remaining): units, and using the field type in the slot (a dropdown's options as an enum)
- out: per-mapping descriptions (PEA-301), the schema (PEA-304), the hooks that call the loader (Epic 4)

**Acceptance criteria**
- Each `(sectionID, fieldID)` mapping returns one field with `slotKey` `s{sectionID}_f{fieldID}`, `fieldId`, `fieldName`, `fieldType`, `variant` and `description`, grouped by section in the procedure's order.
- A field that the procedure returns twice in one section (one row per dropdown option) appears once. The same field in another section keeps its own entry.
- A section is named by the template's `customSectionName` when it is set, otherwise by its `sectionName`, trimmed. Its prompt is trimmed, or `''`.
- A field is described as `fieldName: prompt`, or `fieldName` alone when it has no prompt. `aiSummaryPrompt` never appears, whatever `allowAISummary` says.
- The mapping and the name are each read once per request with the same `@templateId`, including in a run with a tool call and a second model call.
- A template with no rows or no name blocks the run as TEMPLATE_UNAVAILABLE. A database error blocks it as GUARD_STEP_FAILED at step `template_load`. Neither sends a model request.
- Remaining: each slot carries its unit when one is configured, and a dropdown's value is limited to its options or `''`.

**Technical notes**
- `src/repositories/templateRepository.ts` holds `GET_TEMPLATE_FIELDS_SQL` (`EXEC usp_getTemplateMapping @templateId = @templateId`) and `GET_TEMPLATE_NAME_SQL` (`Template.encounterTempletes`), both run through `database.execute`.
- `src/mappers/templateMapper.ts` keeps 9 columns of the row. `src/types/template.types.ts` types the row, and `src/dtos/templateConfig.dto.ts` is what the agent receives.
- `templateService` is a singleton that holds no data. The config is request-scoped and lives in run state as `_templateConfig`.
- The loader throws on a database error, and the guard turns that into a reason code, so `invoke` still resolves and `afterAgent` still runs.
- Tests: `tests/unit/services/templateService.test.ts`, `tests/unit/mappers/templateMapper.test.ts`, the block and tool-round cases in `tests/unit/agents/encounter.test.ts`. `tests/manual/templateConfig.manual.ts` prints a live template's config and schema.

**Before you build (due diligence)**
- `usp_getTemplateMapping` does not filter `isActive` on the mapping, the field or the template, and the UI's section procedure does not filter the mapping's `isActive` either. Count the inactive rows in DEV and find out how the admin page removes a mapping (delete or `isActive = 0`) before adding a filter. The agent must offer the same fields as the form the clinician sees.
- No template table has a unit column. In the Epic 2 design, units live in `AI.fieldConstraint`, which is not in the merged migration set. Agree the unit source with the Epic 2 owner first.
- Dropdown options as an enum exist only on an unmerged branch, built against the old contract (an ABSENT status and an `options` list on the DTO). Rebase it onto today's contract. On template 457 only 2 of 99 slots are dropdowns and 2 are multi-selects, so measure the gain on the eval before merging. De-duplicate option values (DEV repeats "Option 3"), and check the extra enum strings against the provider's strict-mode limits.
- A unit or an enum narrows what the model may return. The client values recall most right now, so check on the eval that ABSTAINED and null do not rise.
- Measure the p95 of the template read on the largest live template, and record it in the repository's comment.

---

### PEA-304
**Title:** Build the response schema per request with zod, one slot per mapping

**Description:**
As a clinical template administrator, I want the response schema generated from my template configuration at request time, so that every slot I configure is a slot the provider forces the model to fill, and no part of the schema is hand-written in code.

The UI's current request sends no response schema: it asks for JSON in prose and writes back whatever arrives. `responseSchemaBuilder.build` turns the loaded config into a zod object with one key per section-and-field mapping. Each key holds the value contract, described by the field's description and nullable, so a field the note does not mention comes back as `null`. The key is built from the section and the field together, so a field used in two sections becomes two slots, and each key maps back to the encounter's own `(sectionID, fieldID)` key with no name lookup.

**Scope**
- in: `src/schema/builder.ts` and the slot key `s{sectionID}_f{fieldID}`
- in: proof that each description reaches the request and that the provider enforces the schema strictly
- out: the keys and rules of the value contract (PEA-305), binding the schema to the call (Epic 4), per-mapping descriptions (PEA-301), type-aware slots (PEA-303)

**Acceptance criteria**
- A config with 2 sections and 3 fields builds a schema with exactly 3 keys, in config order, all required. No slot key is written as a literal in `src/`.
- Each slot's JSON schema is `anyOf` [the value contract, `null`], and its `description` equals the field's description exactly.
- Field 412 in sections 11 and 12 gives two keys, `s11_f412` and `s12_f412`. No slot is lost to a key clash.
- The request sent to Azure OpenAI has `response_format.type` "json_schema" and `strict` true, with these keys and descriptions.
- A reply that misses a slot, drops `status`, or uses a status outside the enum fails to parse.
- A reply with a key the schema does not declare fails validation (`additionalProperties: false`) and ends as OUTPUT_SCHEMA_VIOLATION. Nothing from it is kept.
- A template with no mapped field never reaches the builder: the guard blocks it as TEMPLATE_UNAVAILABLE.
- Two runs in one process, for two different templates, send two different schemas.

**Technical notes**
- `responseSchemaBuilder.build(config)` returns `z.object(shape)`, where `shape[slotKey] = ExtractedValue.describe(description).nullable()`. Strict mode needs every key to be required, so absence is `.nullable()`, never `.optional()`.
- The slot key is built in `templateService` from two integer ids, so no administrator-written text ever becomes a schema key.
- Epic 4 binds the schema on each call with `responseFormat: providerStrategy(schema)`, where `strict` defaults to true. A bare schema could fall back to a client-side tool strategy with no error.
- Slots are flat, not nested by section. Administrators edit section names, and `customSectionName` overrides them per template.
- Tests: `tests/unit/schema/builder.test.ts`, plus the wire check and the two-template check in `tests/unit/agents/encounter.test.ts`.

---

### PEA-305
**Title:** Define the value contract: status, quote, value, unit, remark and confidence

**Description:**
As a clinician, I want every value the AI returns to come with the words it came from, a clear statement of whether it was found or the AI held back, and a confidence band rather than a number, so that I can see at a glance what the note said and what the AI would not claim.

Today a value arrives as a bare string, and the production system writes `NA` both when the note said nothing and when the model was unsure. Those are different clinical facts, and the contract keeps them apart. A field the note does not mention is the slot `null`. A field the note mentions but that cannot be filled reliably is ABSTAINED, with its quote and a reason. A filled field is FOUND, with the exact span of the note it came from, which is what the review screen shows.

**Scope**
- in: `ExtractedValue` in `src/schema/contract.ts`, and `OUTPUT_RULES`, the rules for each key stated once in the system prompt
- out: the evidence check and the derived band (Epic 6), PHI masking of `found_in` (Epic 5), the review screen (Epic 9)

**Acceptance criteria**
- Each slot is `null` or an object with exactly these keys, in this order: `status`, `found_in`, `value`, `unit`, `remark`, `confidence`. All six are required.
- `status` is FOUND or ABSTAINED. ABSENT, or any other string, fails to parse. A field the note never mentions is `null`.
- `confidence` is HIGH, MEDIUM or LOW. A number or any other string fails to parse.
- `remark` is required, and is `""` when there is nothing to say.
- No key of the contract carries a description, so nothing is repeated in every slot. The rules for each key are added once to the system prompt as `OUTPUT_RULES`.
- `OUTPUT_RULES` says: `null` when the field is not mentioned; `found_in` copied as one continuous span; the unit only when the note states it, never guessed; ABSTAINED with a quote and a remark when the value cannot be filled reliably.
- `found_in` and `value` never appear in a log line: the evidence log carries slot keys and counts only.

**Technical notes**
- `ExtractedValue` is `z.object` with `status` and `confidence` as `z.enum` and the other four keys as `z.string()`.
- Key order is generation order. Strict mode emits keys in schema order, so the model writes the status and the quote before the value that must agree with them.
- There is no per-key `.describe()`: on template 457 the five per-key descriptions were measured at 48% of the schema's tokens (10,890 of 22,447, 99 slots).
- Rules that span keys, such as "a FOUND value needs a quote that is in the note", are checked in code after the model call (Epic 6), never in the schema. A model mistake then becomes a flagged field, not a parse failure.
- The model's own `confidence` is required but never read: Epic 6 derives HIGH, MEDIUM or LOW from the evidence.
- Tests: `tests/unit/schema/contract.test.ts`, and the wire key-order check in `tests/unit/agents/encounter.test.ts`.

---

### PEA-306
**Title:** Make a template edit take effect on the next request, with no deployment

**Description:**
As a clinical template administrator, I want a field I add, remove or reword to change the very next extraction request, so that improving the system is an edit I make myself rather than a release someone schedules.

The improvement loop is: a clinician corrects a field, the correction shows that the instruction is unclear, the instruction is sharpened, and the next note extracts better. Two ordinary habits would break it: a process-wide cache of template config keyed on the template id, which serves the old text until a restart, and a schema compiled into the agent at startup. Neither exists. The config is read and the schema is built on every request, and the agent is compiled once, with no schema in it.

**Scope**
- in: no cache of the config or the schema, a per-request load and build, and one compiled agent per process
- out: any cache (added only against a measured cost), and the admin page

**Acceptance criteria**
- In one process, a run for a template followed by a run after a field (`s13_f900`) is added sends the new key in the second request, with no restart.
- A reworded field prompt or section prompt reaches the next request's schema or system prompt.
- A mapping removed from the template is gone from the next request's schema.
- Three runs in one process use the same compiled graph, and `createAgent` is not called per request.
- `templateService`, `templateRepository` and `responseSchemaBuilder` hold no template data between requests.
- A template change needs no prompt row, code or deployment change: the slot list in the system prompt (`encounterFields`) and the schema come from the same loaded config.

**Technical notes**
- The guard's `template_load` and `schema_build` steps run on every request (`src/agents/middleware/guard.ts`). The schema is kept in run state as `_responseSchema` and bound in `wrapModelCall` (Epic 4).
- `encounterAgent.graph` is a lazy getter that compiles once, with no response format and no system prompt (`src/agents/encounter.ts`).
- If a cache is ever added, its key is a fingerprint of the ordered slot list and every description, never the template id alone.
- Tests: "two runs in one process bind two schemas" and "one compiled graph across three runs" in `tests/unit/agents/encounter.test.ts`.

---

### PEA-307
**Title:** Give a newly added field the full contract and every check from day one

**Description:**
As an AI/clinical admin, I want a field added yesterday to produce values that are flagged and reviewable rather than silently written, so that a first-draft description costs a clinician a review, not a wrong value in a chart.

A new field arrives with a first-draft description and no history of corrections, so it will extract less well than a mature field. That is expected, not a defect. What is guaranteed from day one is safety: a new slot has exactly the same contract and checks as a mature one. There is no maturity gate in the build, because a gate is how a weak field quietly becomes an exempt one, and improvement is measured as that field's edit rate falling over time.

**Scope**
- in: the same contract for every slot, and a FOUND value without located evidence flagged for review (Epic 6's check)
- in (remaining): an `authored` flag per slot (after PEA-301 and PEA-302), the count of unauthored slots per template for Epic 10, and the day-one note for clinical leadership
- out: holding a run for review (Epic 9) and the edit-rate dashboard (Epic 10)

**Acceptance criteria**
- A slot added a minute ago and a slot in use for two years have structurally identical sub-schemas, and both require all six keys.
- The builder reads only the slot key and the description: no maturity, age or `authored` flag.
- A FOUND value with an empty or unlocated `found_in` gets band LOW and is listed in `reviewSlots`.
- Remaining: a slot with `authored: false` is present and complete in the schema.
- Remaining: the template load logs the count of unauthored slots for Epic 10, with ids and counts only, and the schema does not change with that count.
- Remaining: the rollout note for clinical leadership says that new fields start with more review items, and names edit rate as the measure.

**Technical notes**
- Every slot is `ExtractedValue.describe(description).nullable()`. Nothing else varies between slots.
- The flag comes from `src/agents/middleware/evidence.ts` (Epic 6): a FOUND value without a located quote is LOW and is reviewed.
- The unauthored count is a log field on the template load, not a gate.
- Tests: `tests/unit/schema/builder.test.ts`, and "a FOUND value with no quote is NONE, LOW and reviewed" in `tests/unit/agents/middleware/evidence.test.ts`.

**Before you build (due diligence)**
- `authored` needs PEA-301's store and PEA-302's backfill. Until then, decide whether to ship the count now as "slots with no field prompt" (66 of 99 on template 457).
- Confirm with Epic 10 which log field and message the dashboard reads, so the count is built once.
- A first-draft field is more often missed (`null`) than wrong, and no review flag catches a miss. The client values recall most right now, so agree the rollout note's wording with them and measure a new field's recall on the eval suite.
- The day-one expectation depends on the model. gpt-4.1 retires on 2027-04-14, so re-measure on its successor before the note goes out.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-301 | Not started (later sprint) | 5 | Epic 1 database; Epic 2 migration set; an owner decision | Nothing yet. The per-section slot key it relies on is built (PEA-304), but every description is still global: `Template.fields.prompt` via `usp_getTemplateMapping`. | Storage ships in `PacEHR_AI/migrations/sql` (`npm run migrate`). The fallback is `fieldName: prompt`, not `displayName` plus the section name. The grep-level source check is dropped: the repository's standard is that tests assert behaviour, not shape. | The Epic 2 owner withdrew `AI.fieldDescription` on 2026-10-06 (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` §A3). A draft DDL exists at `docs/sql/0005_create_field_description.sql`: NVARCHAR(1000), no `updatedBy`, no `isActive`, and its comment wrongly says `unit` is a column of `Template.fields`. Template 457 has 9 fieldIDs in two sections, with identical descriptions (`docs/data/template/template457_202610091356.json`). Section 4 is in 175 of 458 templates (`templateSection_202610071342.json`). |
| PEA-302 | Not started (later sprint) | 3 | PEA-301 | Nothing yet. | The validation module moves from a Python file to TypeScript beside the loader. Denying the agent's write by grant conflicts with the Epic 2 decision. | "No roles and no GRANTs" (2026-10-05, Epic 2 doc §A3). The admin write path is in pacEHR UI/API (C#), outside this repository. `DESCRIPTION_MAX_CHARS` is not measured. |
| PEA-303 | Partly done | 3 | Epic 1 (`database.execute`) | `src/repositories/templateRepository.ts`, `src/mappers/templateMapper.ts`, `src/types/template.types.ts`, `src/dtos/templateConfig.dto.ts`, `src/services/templateService.ts`; `tests/unit/services/templateService.test.ts` (6), `tests/unit/mappers/templateMapper.test.ts` (1), the block, throw and tool-round cases in `tests/unit/agents/encounter.test.ts`; `tests/manual/templateConfig.manual.ts`. First merged in PR 12607 (AITP-99, `4a28681`). The current form is in `89099ab`. | Reads the shared `usp_getTemplateMapping` plus a name query, not `TemplateConfiguration` or a new procedure. Returns every mapped field. PR 12607 kept only `allowAISummary` fields described by `aiSummaryPrompt`, and the comment in `templateService.ts` records that text embellishing BP, Labs and Medication List on template 457. The loader throws and the guard turns the error into GUARD_STEP_FAILED, instead of the loader returning a failure value. Order is the procedure's `ORDER BY etm.orderby`, with no tie-breaker (template 457 has no ties). There is no `authored` flag and no unit, and `fieldType`/`variant` are carried but unused. No success log carries the template id and slot count; the evidence log carries the slot count. | `isActive` is not filtered on the mapping, the field or the template (`pacEHR_API/PacEHR.Database/Stored Procedures/Procs2/usp_getTemplateMapping.sql`). No unit source exists. The dropdown enum is on unmerged `origin/feature/AITP-99-dynamic-template` (`eb0b098`, `44d9395`, 2026-10-13), against the old contract (`docs/2026-10-09-pacehr-ai-gaps-and-improvements.md` P4). The p95 read time is not measured. `templetID` comes from the caller's context; Epic 9's endpoint must resolve it from the encounter. |
| PEA-304 | Done | 5 | PEA-303, PEA-305 | `src/schema/builder.ts`; `tests/unit/schema/builder.test.ts` (2); the wire-schema and "two runs bind two schemas" tests in `tests/unit/agents/encounter.test.ts`. First merged in PR 12607 (`4a28681`); the current form is in `89099ab`. | A zod `z.object` built per request, not `create_model`. `.describe()` and `z.toJSONSchema` replace `Field(description=...)` and `model_json_schema()`. The slot key is built in `templateService`, not in `contract.ts`, and there is no parse function. Strict is on (the `providerStrategy` default, proven live in PEA-401); the Python ticket said not to set `strict`. A template with no fields is blocked by the guard (TEMPLATE_UNAVAILABLE), not by the builder. An undeclared key fails the whole reply, because langchain 1.5.14's `ProviderStrategy.parse` validates against the JSON schema with `additionalProperties: false` and then throws `StructuredOutputParsingError`, which becomes OUTPUT_SCHEMA_VIOLATION. Checked by a probe on 2026-10-14; there is no dedicated test. | Schema size: about 594 properties on template 457 with the five-key contract (2026-10-09), and 693 with today's six keys (99 × 6 + 99). Azure documents a strict-mode limit of 100 properties, yet accepted both (the 2026-10-14 eval passed on template 457). Verify on the largest template, and keep per-section calls as the fallback (`docs/2026-10-09-pacehr-ai-gaps-and-improvements.md` X8, T7; `docs/2026-10-13-single-vs-multi-agent.md`). There is no round-trip key test and no parse function; Epic 9's write-back adds the parse when it needs one. Build time is not measured. |
| PEA-305 | Done | 3 | none | `src/schema/contract.ts` (`ExtractedValue`, `OUTPUT_RULES`); `tests/unit/schema/contract.test.ts` (3); the key-order and status-enum check on the wire in `tests/unit/agents/encounter.test.ts`. In `89099ab`. | ABSENT is gone: a field that is not mentioned is a `null` slot. `remark` is added. Keys are reordered for generation. No per-key descriptions (they were 48% of the schema's tokens), with the rules stated once in `OUTPUT_RULES`. The model's `confidence` is never read: Epic 6 derives the band (`src/agents/middleware/evidence.ts`, PEA-607/608). | Epic 6 and Epic 9 owners have not recorded sign-off on the changed contract. `docs/tickets/SOP-COVERAGE.md` 4.2 and the Epic 2 data design still cite ABSENT. No unit test asserts that a numeric confidence is refused (the enum makes it impossible). `found_in` de-masking waits for Epic 5. |
| PEA-306 | Done | 3 | PEA-303, PEA-304 | Per-request `template_load` and `schema_build` in `src/agents/middleware/guard.ts`; the once-compiled `encounterAgent.graph` in `src/agents/encounter.ts`; "two runs in one process bind two schemas" and "one compiled graph across three runs" in `tests/unit/agents/encounter.test.ts`. | No cache of any kind; reading per request is the mechanism. There is no admin-path integration test, because the admin page is not in this repository. | Only the added-field case is tested; a reworded and a removed mapping are not. A mapping set to `isActive = 0` still loads (see PEA-303). The read and build latency is not measured. |
| PEA-307 | Partly done | 2 | PEA-304, PEA-305; Epic 6 evidence; PEA-301/302 for `authored` | The identical per-slot contract in `src/schema/builder.ts`; FOUND-without-quote is LOW and reviewed (`src/agents/middleware/evidence.ts`, Epic 6); `tests/unit/agents/middleware/evidence.test.ts`. | The flag is Epic 6's derived band and `reviewSlots`, not a required-key check. | No `authored` flag, no unauthored count for Epic 10, no rollout note. A missed field (`null`) raises no flag. That matters because recall is the client's priority (`docs/2026-10-13-recall-observability-brainstorm.md` §1.3). |

Total: 24 points. Done: PEA-304, PEA-305, PEA-306 (11 points). Partly done: PEA-303, PEA-307 (5 points). Not started: PEA-301, PEA-302 (8 points). Jira: AITP-99 (dynamic template schema).

### Notes

**Verified 2026-10-14** (`PacEHR_AI`, branch `3p-dev/epic-4-agent-core`, HEAD `89099ab`, clean working tree, pushed)
- `npm test`: the `tsc --noEmit` pretest passed, then 151 of 151 tests passed. Epic 3's own unit files: 12 of 12 (`templateService` 6, `templateMapper` 1, `builder` 2, `contract` 3).
- Probe against zod 4.6.5 and langchain 1.5.14: `z.toJSONSchema` emits `additionalProperties: false` at the top and inside each slot, and `ProviderStrategy.fromSchema(...).parse` returns `undefined` for a reply with an undeclared key. `AgentNode` then throws `StructuredOutputParsingError`.
- `npm run eval` on 2026-10-14 (template 457, gpt-4.1): passed, precision 90.8%, recall 78.4% (`tests/eval/history.jsonl`).
- Merge state: PR 12607 (AITP-99, `4a28681`, 2026-10-07) merged the first loader, builder and contract into `PacEHR-AI-Develop-Main`. The current form (every mapped field, `fieldName: prompt`, the six-key contract, `OUTPUT_RULES`, the name query, the tests) is `89099ab`, which is not yet merged.

**What changed from the Python edition**

| Python edition | TypeScript edition |
|---|---|
| `pacehr/templates/config.py` (`TemplateConfiguration`, `TemplateField`, loader) | `src/repositories/templateRepository.ts`, `src/mappers/templateMapper.ts`, `src/types/template.types.ts`, `src/dtos/templateConfig.dto.ts`, `src/services/templateService.ts` |
| `create_model` + `Field(description=...)`, `model_json_schema()` | `z.object` built per request, `.describe()`, `z.toJSONSchema` |
| `ProviderStrategy(ExtractionResult)`, `strict` unset | `providerStrategy(schema)`; `strict` true by default and proven live |
| `asyncio.to_thread` around `mssql_python` | `database.execute(SQL, params)` on the mssql pool |
| `before_agent`, `wrap_model_call`, `after_model` | `beforeAgent` (guard), `wrapModelCall` (binding), `afterModel` (evidence, Epic 6) |
| FOUND / ABSENT / ABSTAINED, five described keys | `null` or FOUND / ABSTAINED, six undescribed keys, `OUTPUT_RULES` once |
| pytest files `test_template_config.py`, `test_schema_builder.py`, `test_contract.py` | `node:test` files mirroring the source paths under `tests/unit/` |
| `AI.fieldDescription` planned in Epic 2's set | withdrawn by the Epic 2 owner; descriptions come from `Template.fields.prompt` |

**Decisions the team must resolve**
- **Per-mapping descriptions (PEA-301/302):** the withdrawal of `AI.fieldDescription` (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` §A3) leaves the collision this epic was written to remove. The owner and the client choose: reopen the table, or accept global descriptions.
- **The Physical Exam instruction:** the 14 Physical Exam fields on template 457 sit in section 4, "Vital Signs - Updated", whose only instruction is "Summarize the vital signs". This causes recall misses (prose exam findings were caught in 1 run of 3; `docs/2026-10-12-five-query-comparison.md`; `docs/2026-10-13-single-vs-multi-agent.md` §6, step 0). The prompt is global, and section 4 is in 175 of 458 templates. Decide whether to edit it now, for every template, or wait for per-mapping descriptions.
- **Inactive mappings:** neither the agent's procedure nor the UI's filters `isActive`. Count the inactive rows in DEV and choose one rule for both.
- **Units:** there is no source. `AI.fieldConstraint` is in the Epic 2 design but not in the merged migrations (`PacEHR_AI/migrations/sql` 0001–0006).
- **Large templates:** template 457's schema is well above Azure's documented 100-property strict-mode limit and was still accepted. Verify on the largest live template and on gpt-4.1's successor (gpt-4.1 retires 2027-04-14; newer models are reasoning models). Per-section calls are the fallback (`docs/2026-10-13-single-vs-multi-agent.md`).
- **Contract sign-off:** ABSENT was replaced by `null`. `docs/tickets/SOP-COVERAGE.md` 4.2 and the Epic 2 data design still cite ABSENT, and Epics 6, 9 and 10 read the contract.
- **Tenancy:** `templetID` comes from the run context. Epic 9's endpoint must resolve it from the encounter on the server, never take it from the client.
