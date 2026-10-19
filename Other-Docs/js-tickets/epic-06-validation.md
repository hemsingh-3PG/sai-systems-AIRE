# Epic 6 — Deterministic validation engine (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic
**Title:** Check every extracted value in code, and give every field one verdict

**Description:** Every value the model returns is checked by ordinary TypeScript before it can reach the chart. The checks run inside the agent's `afterModel` hook, which the model cannot skip. Each field of each run leaves that hook with exactly one verdict (ACCEPT, REVIEW or BLOCK), its reason codes, and a HIGH, MEDIUM or LOW confidence band derived from facts anyone can re-check. The checks cover two-band ranges, units, cross-field consistency, dates and evidence binding against the note. A compiler turns the clinical author's prose into the per-field guards that the range, unit and date checks run on. Nothing in this epic calls a model. Evidence binding and the derived band already run on every request; the verdicts and the other validators are still to build.

### PEA-601
**Title:** Run every field through one validation chain in afterModel, one verdict each

**Description:**
As a compliance officer, I want every extracted field to pass through the same deterministic checks inside the agent's `afterModel` hook and leave with exactly one recorded verdict, so that I can show an auditor which checks ran on a given vital without relying on what the model chose to do.

Today the evidence check (PEA-607) flags slots for review, but no field gets a verdict or a reason code, so an impossible value and a correct one leave the agent the same way. Validators are plain TypeScript in a middleware hook, never tools: a tool the model may decline to call cannot prove a check ran. The chain is also where the output states become actionable. A null slot needs nobody, ABSTAINED always needs somebody, and FOUND needs the checks.

**Scope**
- in: the chain inside the one `afterModel` hook, the ACCEPT/REVIEW/BLOCK ladder, one verdict with its reason codes per slot on run state, per-validator error handling, and the per-field reason-code constants
- out: registering the hook and the spine order (Epic 4, PEA-402); what happens to a verdict: commit, review queue, override (Epic 9); the value contract (Epic 3, PEA-305); the reason-code taxonomy (Epic 10, PEA-1004); the constraint table (Epic 2, PEA-206); the date and BMI tools (Epic 7)

**Acceptance criteria**
- A template whose schema declares 40 slots gets exactly 40 verdicts, each ACCEPT, REVIEW or BLOCK. Every verdict other than ACCEPT carries at least one reason code.
- The most severe finding decides the verdict (BLOCK over REVIEW over ACCEPT), and the code of every finding stays on the field.
- A null slot is ACCEPT with no finding, and nothing is written for it.
- An ABSTAINED slot is REVIEW even when every validator passes, and its status stays ABSTAINED.
- A slot whose status and value disagree (FOUND with an empty value, or ABSTAINED carrying a value) is BLOCK with STATUS_VALUE_CONFLICT.
- A validator that throws makes its own field BLOCK with VALIDATOR_ERROR. The other 39 fields still get verdicts, `invoke` resolves and `afterAgent` runs.
- A slot key that is not in the schema is recorded as SLOT_UNKNOWN and dropped. A schema slot missing from the reply is BLOCK with SLOT_MISSING.
- A model response that carries only tool calls produces no verdicts and no codes. The next response's verdicts are the run's only verdicts.

**Technical notes**
- The spine allows one middleware per hook, and a unit test checks it. So the chain extends the existing `afterModel` in `src/agents/middleware/evidence.ts`; it is not a second middleware. The validators are plain functions in a new `src/validation/` folder (alias `#validation/*`). The ladder and the finding record live in `src/validation/verdicts.ts`.
- The hook reads `structuredResponse`, `noteText` and the request's guards from state. It returns a partial state update (`fieldVerdicts`, declared in `ExtractionState` in `src/agents/state.ts`) and declares no `canJumpTo`, because the run must reach `afterAgent` whatever the verdicts are. No I/O inside the hook.
- The middleware object holds no request data. Every clinical value comes from state and dies with the request. Status only moves down: FOUND may become ABSTAINED (PEA-604); ABSTAINED never becomes FOUND, and a null slot is never filled.
- Reason codes are exported constants, never literals at the raise site: STATUS_VALUE_CONFLICT, SLOT_UNKNOWN, SLOT_MISSING, VALIDATOR_ERROR, NO_GUARD_DEFINED, RANGE_IMPLAUSIBLE, RANGE_ABNORMAL, VALUE_NOT_NUMERIC, UNIT_AMBIGUOUS, UNIT_UNRECOGNISED, CROSS_FIELD_BP_ORDER, CROSS_FIELD_BMI_MISMATCH, CROSS_FIELD_INPUT_MISSING, DATE_AFTER_ENCOUNTER, DATE_BEFORE_BIRTH, DATE_BEYOND_HORIZON, DATE_UNPARSEABLE and EVIDENCE_NOT_FOUND.
- Each validator call sits in its own try/catch. `langchain` 1.5.14 runs a hook with no try/catch around it, and a throw from `wrapModelCall` was measured rejecting `invoke` and skipping `afterAgent`, which loses the audit row. The pino log line carries slot keys and codes only.
- Tests: `tests/unit/validation/verdicts.test.ts`, plus spine cases in `tests/unit/agents/middleware/evidence.test.ts` built on `tests/unit/agents/harness.ts`.

**Before you build (due diligence)**
- Decide where the per-field codes live. `src/agents/failure-modes.ts` is the run-level table (kind GUARD, MODEL_CALL or EXTRACTION), and `outcome.ts` sets the run's outcome from it. A field code must never end a run. Choose a separate field table or a new kind, and the failure mode (ROUTING, AMBIGUITY or COMPREHENSION) each code counts as.
- Measure the abstain rate before every ABSTAINED goes to review. Today the evidence check never reviews ABSTAINED, and some runs returned about 80 abstained placeholders for fields the note never mentions. That is 80 review items for one note.
- Confirm with the client whether the chain may read null slots to raise non-blocking recall hints, for example a null field whose label or a matching pattern appears in the note, without changing their status. As written, a null slot is accepted unseen, and the client now weighs recall over precision.
- Check that SLOT_UNKNOWN and SLOT_MISSING can happen at all. Strict mode sends `additionalProperties: false` with every key required, and the zod parse may strip or reject the reply before the hook sees it. Read what `providerStrategy` hands `afterModel` in the installed `langchain`.
- Decide how a verdict reaches the user and the accuracy gate. `encounterAgent.stream` yields each field before `afterModel` runs, so a streamed field has no verdict yet. Decide whether `npm run eval` scores the model's answer or the answer after verdicts; a BLOCK that removes a correct value costs recall.

---

### PEA-602
**Title:** Compile the clinical author's prose into executable per-field guards

**Description:**
As a clinical template administrator, I want the bounds and units I write in prose on a template field compiled into an executable guard and shown back to me before I save, so that the check that runs in production is the one I approved and not an approximation of it.

Range, unit and date checks are only as good as the bounds they run on, and bounds written into code are bounds no clinician approved. Prose like "normal 60 to 100, impossible under 20 or over 300" has to become two numeric bands, a unit and a risk class. The author has to see that translation before it can block a value on a live chart. Compiling on save also rejects a rule that cannot be parsed while the author is still looking at it, instead of silently leaving the field with no guard.

**Scope**
- in: the compiler (prose and field type in; a compiled guard, or a rejection naming the clause, out), the compiled-guard shape, and the per-request read of a template's guards into run state
- out: the `AI.fieldConstraint` table, its DDL and who may write it (Epic 2, PEA-206); the editor screen and its route; the validators that read the guard (PEA-603, PEA-604, PEA-606)

**Acceptance criteria**
- "normal 60 to 100 bpm; under 20 or over 300 is impossible" for Heart Rate compiles to unit bpm, abnormal 60 to 100 and plausible 20 to 300. The compiled bounds are shown for confirmation before the row is written.
- "kg or lb; 0.5 to 400 kg plausible" for Weight compiles to units kg|lb, with the plausible band stored against kg, the unit it was written in.
- The blood-pressure prose compiles to two components, systolic and diastolic, each with its own two bands and its role for cross-field rules.
- "use clinical judgement" for Serum Ferritin is rejected at save. The rejection names the clause, and no row is written.
- Prose that contains code, such as `process.exit()` or `${...}`, is rejected by the grammar and never run.
- A field with no guard row that comes back FOUND gets REVIEW with NO_GUARD_DEFINED, never ACCEPT.
- An edited row is used on the next request with no deployment. The template's guards are read in one query before the model call, and no query runs inside `afterModel`.

**Technical notes**
- `src/validation/constraints.ts`: one exported compile function and the zod schema `CompiledGuard` (unit or unit choices, plausible band, abnormal band, risk class, optional components with roles, and for date fields a direction, past or future, and a horizon). Types come from `z.infer`. Every validator reads this guard, and none carries its own numbers.
- The read is one `*_SQL` constant run through `database.execute(SQL, { templetID })` in `src/repositories/fieldConstraintRepository.ts`, keyed on templetID, sectionID and fieldID. The guards land in a private state key (for example `_fieldGuards`) before the model call. No cache: an edit must be live on the next request.
- No clinical bound appears in TypeScript source. The only numbers in these modules are structural, each a named constant.
- The compiler parses a closed grammar and never evaluates author text: no `eval`, no `new Function`, no `RegExp` built from the prose. ESLint's `no-eval`, `no-implied-eval` and `no-new-func` join the guard rules, with a planted violation that proves they fire.
- Risk class comes from the field's type: code is strictest, then vital, then narrative. PEA-603 and PEA-607 read it to choose between BLOCK and REVIEW. Tests: `tests/unit/validation/constraints.test.ts`; the "edited row is live on the next request" check in `tests/integration/`.

**Before you build (due diligence)**
- Confirm the table exists and can hold the guard. Neither the `AI.fieldConstraint` migration nor its repository is in the service today, and the designed columns (unit, two bands, source prose) have no place for risk class, components, roles, direction or horizon. Agree the extra columns with the Epic 2 owner first, or every date field stays NO_GUARD_DEFINED.
- Decide where the save path runs. This service has no admin route, and the template editor lives in the PacEHR UI and API. The compiler may have to run behind a new route, or be called from there.
- Check how `mssql` returns a `DECIMAL(6,2)` column (a JavaScript number) and decide how bounds stay exact: compare in SQL, cast to text in the statement, or scale to integers.
- Decide where the read runs. A new step in the guard's `beforeAgent` changes Epic 4's step list (PEA-403); folding it into the template read keeps one step and one round trip.
- Pull the distinct `fieldType` and `variant` values from DEV to map each one to a risk class, and to see which fields are numeric, dates or narrative.

---

### PEA-603
**Title:** Range-check every value against two bands, not one threshold

**Description:**
As a clinician, I want a physiologically impossible value blocked outright and an abnormal but possible value flagged and kept, so that nonsense never reaches the chart and I can still record an emergency.

A single cut-off cannot do this. Set tight enough to block 700/400, it also blocks 210/115, a real hypertensive crisis and the reading a clinician most needs recorded. Two bands separate two questions: can this value exist at all (a blocking question), and is it normal (a review question). The bands come from the guard the clinical author approved (PEA-602), so tightening one is an edit, not a release.

**Scope**
- in: the two-band comparison over single values and composite values such as blood pressure, and the numeric parse of the value
- out: the bounds and risk class (PEA-602); unit resolution (PEA-604); the review card (Epic 9, PEA-903)

**Acceptance criteria**
- "BP 700/400", with plausible bounds 40 to 300 systolic and 20 to 200 diastolic, is BLOCK with RANGE_IMPLAUSIBLE, and nothing is written.
- "BP 210/115", with abnormal bounds 90 to 140 and 60 to 90, is REVIEW with RANGE_ABNORMAL. The value and the words "BP 210/115" from the note go to the review item.
- "BP 120/80" is ACCEPT with no reason code.
- "BP 118/400" is BLOCK with RANGE_IMPLAUSIBLE, and the finding names the diastolic component.
- "unobtainable" in a numeric field is REVIEW with VALUE_NOT_NUMERIC, and no number is coerced from it.
- A value equal to a bound compares exactly, with no floating-point error at the boundary.
- A guard with only a plausible band never produces RANGE_ABNORMAL. An empty guard gives NO_GUARD_DEFINED, never a default band.
- Risk class changes the verdict: outside the abnormal band is REVIEW for a narrative field, and outside the plausible band is BLOCK for a vital or code field.

**Technical notes**
- `src/validation/ranges.ts`: plain functions that return findings. No class, because there is nothing to construct.
- Values arrive as strings (the contract's `value` is a string). Parse them with one strict pattern. Never use `parseFloat` or `Number()` on free text: `parseFloat('120abc')` is 120 and `Number('')` is 0. Compare without binary floating point.
- A composite value is checked component by component against that component's bands, and the worst component decides the field.
- No clinical bound appears in the module. A finding logs the slot key, the band and the code; the value goes only to the review payload.
- Pure comparison, no I/O. Tests: `tests/unit/validation/ranges.test.ts`.

**Before you build (due diligence)**
- The model sometimes puts several readings in one value ("156/94, 148/90 mmHg", "2/10 (nursing), 7/10 (patient)"). Decide whether that is VALUE_NOT_NUMERIC, a check of each reading, or a conflict to review.
- Values also arrive with units or words inside them ("92 %", "156 pounds", "37.6 °C"). Decide what the parser strips, and agree it with PEA-604 so both validators read the same number.
- Pick the exact-comparison method. Scaled integers after a strict pattern are enough for bounds stored to two decimals. Confirm no new dependency is needed.
- Get plausible and abnormal bands for template 457's vitals from the clinical owner. No bands exist in the database today.

---

### PEA-604
**Title:** Resolve units from the guard, and abstain rather than guess one

**Description:**
As a clinician, I want a number whose unit the note does not state handed back to me rather than given a unit by the system, so that a weight used for dosing is never off by a factor of two.

"weight 187" is 187 pounds or 187 kilograms. Picking the unit that makes the value normal fails on its own terms: "temp 99.1" is not a normal reading in either Fahrenheit or Celsius. A clinician resolves either in a second; the system cannot resolve them honestly. So it does not try, and the ambiguity becomes one tap in review instead of a wrong value on the chart.

**Scope**
- in: unit resolution, the alias table, ambiguity detection, and lowering FOUND to ABSTAINED
- out: any unit conversion; the prompt rule that forbids conversion (Epic 8); the review card (Epic 9)

**Acceptance criteria**
- A note with "weight 187" and no unit, where the guard declares kg|lb, gives ABSTAINED, REVIEW, LOW and UNIT_AMBIGUOUS, even when the model's `unit` key says kg. Nothing is written, and the number stays on the review item.
- "temp 99.1" with units F|C gives REVIEW with UNIT_AMBIGUOUS. The range validator records no finding, and neither band is applied.
- "weight 84.8 kg" with units kg|lb gives ACCEPT with unit kg. No conversion to lb appears anywhere in the payload.
- "height 178" with only cm declared gives ACCEPT with unit cm.
- "weight 187 stone" with units kg|lb gives REVIEW with UNIT_UNRECOGNISED, never a nearest match, and nothing is written.
- An ABSTAINED field is never raised to FOUND.

**Technical notes**
- `src/validation/units.ts`. `UNIT_ALIASES` is an exported, frozen constant that maps spellings to declared units (`lbs` and `pounds` to `lb`, `kgs` to `kg`, `°F`, `F` and `fahrenheit` to `F`). It never maps one unit to another.
- One declared unit resolves a value with no unit by configuration. Two or more declared units and no unit in the note is UNIT_AMBIGUOUS.
- This is the one validator that lowers FOUND to ABSTAINED. An unresolved unit stops the range check for that field: a band chosen without a unit is the same guess one layer down.
- No conversion, ever. The note's unit is recorded as written.
- The log carries the slot key and the code. The value and its candidate units go to the review payload, where the declared units are offered with none pre-selected. Tests: `tests/unit/validation/units.test.ts`.

**Before you build (due diligence)**
- Measured on a terse note: the model filled `unit` when the note had none ("Weight 61" came back "61 kg", "Temp 37.6" came back "37.6 °C"), despite the rule against guessing. Read the unit from the quoted words, as the evidence check's unit-in-quote test already does, and measure how often the two disagree.
- Some field prompts ask for a conversion: the model turned "Height 165 cm" into "5 feet, 5 inches". That conflicts with "no conversion, ever". Agree with the template owner which rule wins.
- Decide where the lowered status lives: rewrite the slot in `structuredResponse`, or keep the model's answer and record ABSTAINED on the field's verdict. A streamed field has already gone out as FOUND by then.
- Count the abstains this rule causes per field. That is a recall cost, and a clinician later entering the same value shows the abstain was not needed.

---

### PEA-605
**Title:** Check the fields of one encounter against each other

**Description:**
As a clinician, I want values that are each plausible but cannot all be true at once caught before they are committed, so that an internally contradictory chart is never produced silently.

Per-field checks cannot see a transposition: 88/122 passes every band a clinician would write and is still impossible, because diastolic cannot exceed systolic. A BMI of 22.4 is an ordinary number that disagrees with the 178 cm and 84.8 kg beside it. When a BMI and its inputs disagree, there is no way to know which of the three is wrong, so all three go to the clinician instead of one being picked.

**Scope**
- in: role binding, the blood-pressure ordering rule and the BMI rule, run once over the whole response
- out: computing a BMI for the chart (Epic 7, PEA-703); storing roles (PEA-602)

**Acceptance criteria**
- "BP 88/122", with both components inside their plausible bands, is BLOCK with CROSS_FIELD_BP_ORDER, and nothing is written.
- Height 178 cm, Weight 84.8 kg and a proposed BMI of 22.4 give a recomputed 26.8. BMI, Height and Weight are all REVIEW with CROSS_FIELD_BMI_MISMATCH, and the review item shows the height and weight beside the proposed BMI.
- The same inputs with a proposed BMI of 26.8 give ACCEPT, with no finding on Height or Weight.
- "weight 187" with no unit, Height 178 cm and a BMI value give no comparison. BMI is REVIEW with CROSS_FIELD_INPUT_MISSING.
- A weight blocked with RANGE_IMPLAUSIBLE is never read. BMI is REVIEW with CROSS_FIELD_INPUT_MISSING.
- When one fieldID appears in Review of Systems and in Exam, and only the Exam mapping carries the systolic and diastolic roles, the ordering rule applies to the Exam slots only.
- A boundary test fixes the tolerance: a BMI just inside it is accepted, and one just outside it is reviewed.

**Technical notes**
- `src/validation/cross-field.ts` runs once per response, after every per-field verdict, over the fields that were not blocked.
- Rules bind to the roles on the compiled guard (systolic, diastolic, height, weight, bmi), never to a fieldID literal. The same fieldID recurs in two sections of a template with different meanings.
- A failed rule marks every participant, not the field that looks most wrong.
- `BMI_TOLERANCE_KG_M2 = 0.5`, with its derivation in the comment: a height to the whole inch moves BMI by up to ±0.38 at adult heights, and a weight to the whole pound by a further ±0.07. The comparison must not wobble at that boundary. The check recomputes BMI only to check the value; it never writes one.
- The log carries roles and codes only; the review payload carries the values. One pass over the declared rules, not over every pair of fields. Tests: `tests/unit/validation/cross-field.test.ts`.

**Before you build (due diligence)**
- Roles need somewhere to live. The designed constraint table has no role column (see PEA-602).
- Height and weight can arrive in different units (cm and lb). Confirm with the clinical owner that the check may convert inside the comparison only, while the committed values stay as written.
- The stream shows each field as the model writes it, but cross-field results exist only once the whole reply is parsed. Decide how a streamed field that a later rule sends to review is shown, for example "pending" until the run ends.
- The same rules can raise non-blocking recall hints when a related field is empty: BMI filled but Weight null while the note has a weight, or an assessment that lists diagnoses while Active Problems is null. Decide with the client whether those hints belong in this ticket.
- Choose the arithmetic. A double's error here is far below 0.001, so only an exact-boundary case can differ from integer arithmetic. If doubles are kept, mark that ceiling with a `ponytail:` comment.

---

### PEA-606
**Title:** Sanity-check every date against the encounter, not against today

**Description:**
As a clinician, I want every extracted date checked against this encounter's date of service and the patient's date of birth, so that an onset recorded after the visit or before the patient was born never reaches the chart.

Dates are where relative words become a number, and the reference point is what goes wrong. "Two weeks" means two weeks from the date of service, which is often not today, because notes are dictated and processed late. The date tool (Epic 7, PEA-702) computes from the date of service; this validator checks the answer, whoever computed it. A past event cannot be dated after the visit, and nothing clinical can be dated before birth.

**Scope**
- in: direction, horizon, birth-date and parse checks, against the date of service and the date of birth held for the run
- out: computing dates (Epic 7, PEA-702); keeping the date of birth off the wire (Epic 5, PEA-503)

**Acceptance criteria**
- Date of service 2026-09-22, a "Symptom onset" guard with direction past, and the value 2027-01-04 give BLOCK with DATE_AFTER_ENCOUNTER. Nothing is written.
- With the clock mocked to 2026-11-30, the value 2026-10-15 for the same field still gives BLOCK with DATE_AFTER_ENCOUNTER.
- A "Follow-up" guard with direction future and a one-year horizon accepts 2026-10-06 quoting "follow up in two weeks".
- Date of birth 1948-03-14 and an onset of 1946-07-02 give BLOCK with DATE_BEFORE_BIRTH.
- "3/4" in a date field gives REVIEW with DATE_UNPARSEABLE. No year is inferred, and no day-month order is chosen from a locale.
- 2031-04-02 against a one-year horizon gives REVIEW with DATE_BEYOND_HORIZON.
- No date of birth appears in any log line, trace attribute or error message.

**Technical notes**
- `src/validation/dates.ts`. Direction and horizon come from the compiled guard (PEA-602); the module holds no clinical policy.
- The date of service is `runtime.context.dateOfService` (an ISO date on `ExtractionContext`). The module never calls `Date.now()` or `new Date()` without an argument. The clock test mocks `Date` with `t.mock.timers`.
- Only complete `YYYY-MM-DD` dates are accepted, and each is checked as a real calendar date. Dates compare as ISO strings, which sort in date order, so time zones never enter.
- The check judges the result, not the method: it cannot see whether the model used the date tool, and it does not need to.
- Pure comparison, no I/O. Tests: `tests/unit/validation/dates.test.ts`.

**Before you build (due diligence)**
- The date of birth is in neither `ExtractionContext` nor state today. Decide its source (the caller, in Epic 9, or a read in the guard), and agree with Epic 5 that it stays in memory and is never sent to the model.
- Check the format the template's date fields expect and what the model returns for them (ISO, "10/26/2026", "in 2 weeks"). If the fields want US format, accepting ISO only would send every date to review.
- Confirm that `t.mock.timers` mocks `Date` on the Node 22.13 floor, not only on the newer Node used locally.
- Direction and horizon have no column in the designed constraint table (PEA-602). Without them every date field is NO_GUARD_DEFINED.

---

### PEA-607
**Title:** Bind every value to the exact words it came from

**Description:**
As a clinician, I want any value whose quote does not appear in my note kept from reaching the chart unchecked, so that nothing I did not say is committed, however reasonable it looks.

This is the hallucination check, and it needs no medicine: if the quote is not in the note, the value is not an extraction. Code, not the model, decides whether the quote is there, so the share of bound quotes becomes a measurable hallucination signal. The check is built and runs after every model call. It finds each quote in the note, checks that the value and unit are inside it, and lists rewritten or unbound values for review. Turning that list into field verdicts with a reason code waits for PEA-601 and PEA-602.

**Scope**
- in: finding each quote in the masked note, the value-in-quote and unit-in-quote checks, the review list, and EVIDENCE_NOT_FOUND on the field verdict with BLOCK or REVIEW by risk class
- out: masking (Epic 5, PEA-503); the verdict ladder (PEA-601); the confidence band (PEA-608)

**Acceptance criteria**
- Each slot gets a match: EXACT (the quote is in the note as written), NORMALIZED (found after normalisation), NOT_FOUND, or NONE (no quote).
- Normalisation is NFKC, lower case and whitespace runs collapsed to one space, applied to both sides. Punctuation is kept, so "Code status - full code." does not match "Code status: full code.".
- The quote is matched against the note the model was sent (the masked note), so a quote that spans a masked token still binds.
- The check records whether the value is inside the quote, and whether the unit sits beside the value in it. In "Pain 6/10", a unit of "10" does not count.
- A FOUND slot that is NOT_FOUND or NONE, or whose value or unit is not in the quote, is listed in `reviewSlots`. The model's own confidence never changes the result.
- The check is a substring test, never a similarity score or edit distance.
- The log line carries slot keys and counts only, never a quote or a value.
- A FOUND value whose quote is NOT_FOUND or NONE gets EVIDENCE_NOT_FOUND on its verdict: BLOCK for a vital or code field, REVIEW for a narrative field.

**Technical notes**
- `src/agents/middleware/evidence.ts`: `checkEvidence(note, structuredResponse)` returns `{ evidence, reviewSlots }`, and `evidenceMiddleware` runs it in `afterModel` and writes both to state (`src/agents/state.ts`). It is the third entry of `MIDDLEWARE`, after the model call and before the outcome hook.
- A tool round, a refused call and a failed call have no parsed output, so the hook returns nothing for them.
- `encounterAgent.stream` runs the same `checkEvidence` on each field as it arrives, so every streamed field carries its match and band.
- Tests: `tests/unit/agents/middleware/evidence.test.ts`. The cases are the model's own outputs from template-457 runs, plus a spine run with a stubbed deployment and a seeded masker, and a guard-blocked run that still reaches `afterAgent`.

**Before you build (due diligence)**
- Decide whether NOT_FOUND blocks or reviews. Measured over three runs of five queries, the flags caught 29 of 36 errors, but they also flag about 4 in 10 correct values. Blocking would drop those correct values, and the client weighs recall over precision now.
- Decide the normalisation list. Case folding is in, although the original rule kept case. Rich-text notes with `<br>` come back NOT_FOUND because the model quotes them with new lines. Each extra rule catches more real quotes and also lets one more kind of fabrication through.
- Risk class (vital, code, narrative) does not exist yet (PEA-602), so the BLOCK or REVIEW split has no input until it does.
- The check binds the quote, not the field. A real number placed in the wrong field (total visit time given as counseling time) still derives HIGH. Decide whether PEA-605's rules or the prompt should catch that.
- Re-measure the flag rates when the model changes. The figures come from gpt-4.1, which is closed to new customers, and how a model quotes drives this check. Return each quote's offset too (one `indexOf`), which the recall work needs for note coverage.

---

### PEA-608
**Title:** Derive the confidence band from checkable facts, not the model's opinion

**Description:**
As a clinician, I want the confidence shown beside a suggested value computed from whether it quoted my note and passed the checks, so that the band I read measures the extraction rather than the model's opinion of itself.

A model's self-reported confidence is not calibrated, and it fails in the worst direction: an invented value arrives HIGH as often as a copied one. A band derived from facts anyone can re-check (was the quote in the note, is the value in the quote, did the validators pass) can be reproduced from the run record months later. Today the band is derived from the evidence check alone; validator findings join it once PEA-601 to PEA-606 exist. It stays a band, never a number.

**Scope**
- in: the band rules, keeping the model's own band beside the derived one, and feeding validator findings into the band
- out: the review card (Epic 9, PEA-903); calibration dashboards (Epic 10)

**Acceptance criteria**
- FOUND, a located quote (EXACT or NORMALIZED), and the value and unit inside it give HIGH.
- FOUND and a located quote, with the value or unit not written that way in it, give MEDIUM, and the slot is reviewed.
- Any other slot (not FOUND, or a quote that is NOT_FOUND or NONE) is LOW. A FOUND slot at LOW is reviewed.
- The model's `confidence` is never read: a self-reported HIGH on a quote not in the note derives LOW. The model's band stays on the slot, beside the derived band.
- Every band in state, in the result and in the stream is HIGH, MEDIUM or LOW. No number, percentage or probability appears beside any field.
- A REVIEW-level finding only, such as "BP 210/115" with RANGE_ABNORMAL, derives MEDIUM. Any BLOCK-level finding, or an unresolved unit, derives LOW.
- An ABSTAINED field is LOW and its verdict is REVIEW, even when every check passes.
- The clinician and the run record see the derived band, never the model's.

**Technical notes**
- The band is set in `checkEvidence` (`src/agents/middleware/evidence.ts`) and stored as `evidence[slotKey].confidence`, a zod enum in `src/agents/state.ts`. It is a pure function of status, match, value-in-quote and unit-in-quote: same inputs, same band.
- `structuredResponse` keeps the model's own band on each slot. The derived band sits beside it, not over it.
- Band and verdict are related but separate. An abstention is LOW with every check passed, because abstention is about certainty and the validators measure plausibility.
- Tests: `tests/unit/agents/middleware/evidence.test.ts`, one case per band rule.

**Before you build (due diligence)**
- HIGH is not correctness. Measured: the model picked one of two conflicting weights, and took the total visit time as the counseling time. Both derived HIGH, because the value is written in the quote. Say what HIGH means before clinicians rely on it.
- Decide whether to drop `confidence` from the model's output. It came back HIGH on 198 of 198 slots in two runs, it costs output tokens on every slot, and a consumer could show it by mistake. Its only use is as a calibration metric.
- Decide which band leaves the service. A streamed field carries both `answer.confidence` (the model's) and `evidence.confidence` (derived), and Epic 9 must read the derived one.
- Today ABSTAINED is LOW and never reviewed; this ticket reviews it. Measure the abstain rate first (see PEA-601).

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-601 | Not started (later sprint) | 5 | PEA-305 (Epic 3), PEA-402 (Epic 4) | Nothing for verdicts. The hook it extends exists: `evidenceMiddleware` (`afterModel`) is in `MIDDLEWARE`, already returns nothing on a reply with no parsed output, and logs no clinical text (`evidence.test.ts`). | `pacehr/validation/middleware.py` (`ValidationMiddleware` class) and `verdicts.py` become plain functions in `src/validation/` called from the one existing `afterModel`; `encounter.test.ts` "no hook is defined twice" forbids a second. There is no ABSENT status: absence is a null slot (`src/schema/contract.ts`), so STATUS_VALUE_CONFLICT now means FOUND with an empty value or ABSTAINED with a value. The planned integration test "structured response readable in after_model" already exists as a unit spine test with a stubbed deployment. Codes sit beside `src/agents/failure-modes.ts`, not in a Python module. | Field-code home and failure-mode mapping. Abstain flood: Q2 runs returned 79 and 82 abstained placeholders (`docs/2026-10-12-five-query-comparison.md`). Null-slot recall hints (`docs/2026-10-13-recall-observability-brainstorm.md` §6). SLOT_UNKNOWN unreachable as specified (`docs/tickets/GAPS.md` #19). Stream yields fields before verdicts. Eval scores model answers, not verdicts. |
| PEA-602 | Not started (later sprint) | 5 | PEA-206 (Epic 2), PEA-301, PEA-302 (Epic 3) | Nothing. | `constraints.py` becomes `src/validation/constraints.ts` plus `src/repositories/fieldConstraintRepository.ts`; `database.aexecute` becomes `database.execute`. The "no eval/exec/compile in the module" source test becomes ESLint guard rules with a planted violation (the repo's `CLAUDE.md`: tests assert behaviour, not shape). The guards load in `beforeAgent` into a private state key. | `AI.fieldConstraint` is designed only (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` §C8, `docs/sql/0004_create_field_constraint.sql`). No `PacEHR_AI` branch has its migration (merged migrations are 0001–0006) or `fieldConstraintRepository.ts`, which that doc lists as ✅. The DDL cannot hold risk class, roles, direction or horizon (`GAPS.md` #7). No admin route for the compiler (`GAPS.md` #22). |
| PEA-603 | Not started (later sprint) | 3 | PEA-601, PEA-602 | Nothing. | `ranges.py` becomes `src/validation/ranges.ts`. `decimal.Decimal` has no stdlib twin in Node: exact comparison by strict parse and scaled integers, no new dependency. | Several readings in one value (Q7 pain, Q9 BP in `docs/2026-10-13-confidence-queries.md`). Units inside values. Bands for template 457's vitals from the clinical owner. |
| PEA-604 | Not started (later sprint) | 3 | PEA-601, PEA-602 | Nothing. The evidence check already records `unitInQuote`. | `units.py` becomes `src/validation/units.ts`; the alias table is a frozen exported constant. The first criterion now says the model's `unit` key is not trusted, because the model was measured adding units (Q8, `docs/2026-10-13-confidence-queries.md`). | Field prompts that ask for a conversion (Q10 height) against "never convert". Where the lowered status lives. Recall cost per abstain (`RECALL_LOST_TO_UNIT`, recall brainstorm §6). |
| PEA-605 | Not started (later sprint) | 5 | PEA-601, PEA-602, PEA-603, PEA-604 | Nothing. | `cross_field.py` becomes `src/validation/cross-field.ts`. `compute_bmi` is Epic 7's BMI tool, not built. Decimal arithmetic becomes integer or documented double arithmetic. | Role column. Unit conversion inside the check. Stream shows fields before cross-field results (`docs/2026-10-09-pacehr-ai-gaps-and-improvements.md` T8). Expected-field recall hints (recall brainstorm §6). Placement check proposed in `docs/2026-10-13-single-vs-multi-agent.md` §6. |
| PEA-606 | Not started (later sprint) | 3 | PEA-601, PEA-602 | Nothing. | `dates.py` becomes `src/validation/dates.ts`. Date of service comes from `ExtractionContext.dateOfService` (already a validated ISO date). Clock patching becomes `t.mock.timers`. Dates compare as ISO strings. | No source for the date of birth: it is not in `ExtractionContext`. Date-field formats in DEV. Direction and horizon columns. |
| PEA-607 | Partly done | 5 | PEA-601, PEA-503 (Epic 5) | `src/agents/middleware/evidence.ts` (`checkEvidence`, `evidenceMiddleware`); `evidence` and `reviewSlots` in `src/agents/state.ts`; third entry of `MIDDLEWARE` and the per-field check in `encounterAgent.stream` (`src/agents/encounter.ts`); `tests/unit/agents/middleware/evidence.test.ts` (12 tests, 12 passed, run 2026-10-14). Also read by `tests/manual/review-csv.ts` and the demo stream server. Commit 89099ab (2026-10-14) on `3p-dev/epic-4-agent-core`, pushed; not merged to `PacEHR-AI-Develop-Main`; PR not checked. | Flags for review (`reviewSlots`), does not block. No EVIDENCE_NOT_FOUND, no verdict, no risk class. Normalisation adds lower case (Python kept case). Adds EXACT versus NORMALIZED, `valueInQuote` and `unitInQuote` (gaps doc S1: caught 6 of 6 rewritten values). "One twenty over eighty" with value 120/80 is MEDIUM and reviewed, not ACCEPT. The stream path re-runs `checkEvidence` per field, normalising the note once per field (about 99 times a run) instead of once per request. | Block or review on NOT_FOUND: 29 of 36 errors flagged, and 90 of 207 correct values flagged (119 of 243 filled values in all; `docs/2026-10-12-five-query-comparison.md`). `<br>` quotes NOT_FOUND (Q9). Misplaced values pass; under section fan-out the check caught 16 of 31 errors (`docs/2026-10-13-single-vs-multi-agent.md`). Narrative values unchecked except by `valueInQuote` (`GAPS.md` #15). Quote offset for coverage. Re-measure on the next model. |
| PEA-608 | Partly done | 3 | PEA-601, PEA-603, PEA-604, PEA-607 | The band in `checkEvidence` (`evidence[slot].confidence`, a zod enum); the same 12 tests; the same commit. | Derived from evidence only; no validator findings yet. HIGH also needs the value and unit in the quote. The derived band sits beside the model's band instead of overwriting it, so `structuredResponse` still carries the model's claim. ABSTAINED is LOW and never reviewed (Python: REVIEW). | HIGH is not correctness (Q7 weight, Q10 counseling, `docs/2026-10-13-confidence-queries.md`). Drop the model's `confidence` (HIGH on 198 of 198, gaps doc T4)? Which band Epic 9 shows. No audit row yet to prove "no number" end to end (Epic 9). |

Total: 32 points (8 tickets; 2 partly done, 6 not started).

### Notes

**What changed from the Python edition, epic-wide**

| Python edition | TypeScript edition |
|---|---|
| `pacehr/validation/*.py`, a `ValidationMiddleware` class | Plain functions in `src/validation/` (alias `#validation/*`), called from the one `afterModel` in `src/agents/middleware/evidence.ts`, built with `createMiddleware` |
| `after_model`, node-style dict return | `afterModel` returning a partial state update; new keys declared in `ExtractionState` (zod) |
| FOUND / ABSENT / ABSTAINED | FOUND / ABSTAINED, and a null slot for absence (`src/schema/contract.ts`, rules in `OUTPUT_RULES`) |
| `decimal.Decimal` | No stdlib decimal; exact comparison by strict parse and scaled integers, no new dependency |
| pytest, `tests/unit/test_*.py`, integration test for state in the hook | `node:test` with `node:assert/strict`, `tests/unit/validation/*.test.ts` mirroring the source; the state-in-hook check is a unit spine test with a stubbed deployment |
| `database.aexecute` | `database.execute(SQL_CONSTANT, params)` with `@name` parameters |
| Source test for "no eval" | ESLint guard rules with a planted violation |
| Evidence binding blocks; case kept | Built: flags for review; case folded; value and unit checked inside the quote |
| Derived band overwrites the model's | Built: derived band beside the model's |

**Decisions and conflicts the team must resolve**

- **Block or review on unbound evidence.** The Python design blocks a value whose quote is NOT_FOUND. The built check only flags it. Measured over 3 runs of 5 queries, flags caught 29 of 36 errors, and also flagged 90 of the 207 correct values (`docs/2026-10-12-five-query-comparison.md`). Blocking would raise precision and lower recall, which the client weighs more since 2026-10-12. Proposed gate: no recall gain counts if precision falls under 84.6% (decision D5, `docs/2026-10-13-recall-observability-brainstorm.md` §7).
- **Reviewing every ABSTAINED field.** The Python rule reviews every abstention. The built check never does. Runs have returned about 80 abstained placeholders for one note, against the prompt's rule (`docs/2026-10-12-five-query-comparison.md`). Measure the abstain rate first.
- **Recall signals from the validators.** As specified, the chain never looks at a null slot. The recall brainstorm (`docs/2026-10-13-recall-observability-brainstorm.md` §6) proposes non-blocking codes such as `RECALL_CANDIDATE` (an empty field while related evidence exists) and `RECALL_LOST_TO_UNIT`. Those rows need the chain to read null slots without changing them. The Python stories are kept unchanged here; the decision is open.
- **HIGH is not correctness.** A conflicting weight and a counseling time taken from the total visit both derived HIGH (`docs/2026-10-13-confidence-queries.md`, Q7 and Q10). No story in this epic covers conflict or placement rules. The single-vs-multi-agent study recommends a placement check (`docs/2026-10-13-single-vs-multi-agent.md`).
- **The constraint table.** `AI.fieldConstraint` is designed but not migrated, and it cannot store risk class, roles, direction or horizon (`docs/tickets/GAPS.md` #7; `docs/sql/0004_create_field_constraint.sql`). The Epic 2 data design lists `fieldConstraintRepository.ts` as built, but it is in no branch of `PacEHR_AI`. PEA-602 to PEA-606 all wait on this.
- **Where the compiler runs.** No route exists for a template-editor save path (`GAPS.md` #22).
- **Reason-code taxonomy.** Epic 10's closed list does not match the codes raised here (`GAPS.md` #2: EVIDENCE_NOT_FOUND against EVIDENCE_MISSING, four date codes against one). The per-field codes also need a home that never ends a run (`src/agents/failure-modes.ts`).
- **Field-type dispatch.** No story says which validators run for a boolean, coded or narrative field (`GAPS.md` #18). The SOP rule that billing and safety-critical fields are always manual is not stated (`docs/tickets/SOP-COVERAGE.md` 2.4; gaps doc S8 on code status and allergies).
- **The model's own confidence.** It came back HIGH on 198 of 198 slots (`docs/2026-10-09-pacehr-ai-gaps-and-improvements.md` T4). Keep it only for calibration, or drop it from the contract.
- **Streaming and verdicts.** `encounterAgent.stream` sends each field before `afterModel` runs, so unit lowering and cross-field results arrive after the field is shown (gaps doc T8).
- **Model.** All measurements are on gpt-4.1, which is deprecated for new customers and retires on 2027-04-14. The validators in PEA-601 to PEA-606 do not depend on the model, but the evidence flag rates in PEA-607 and PEA-608 do. Re-measure them on the successor model, which is likely a reasoning model where temperature is mostly unsupported.
- **Code state.** Evidence binding and the band are in commit 89099ab on `3p-dev/epic-4-agent-core` (pushed 2026-10-14), labelled Epic 4 in its message, and not yet merged to `PacEHR-AI-Develop-Main`.
