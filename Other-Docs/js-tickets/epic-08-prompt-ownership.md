# Epic 8 — Prompt ownership (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Prompt ownership: versioned, evaluation-gated prompt fragments the agent only reads

**Description:** Today the system prompt is one stored `AI.prompt` row, chosen by `dbo.usp_getPrompt` and edited in place, with no version, no history and no gate. This epic moves every instruction the model receives into versioned prompt fragments of four kinds: `contract` (the fixed safety and output rules), `task`, and the optional `specialty` and `template_override`. An admin saves a change as a new version and never overwrites one, the agent only reads, and a version reaches clinicians only after it passes evaluation and an admin activates it. A bad version is undone by re-activating an earlier one, never by typing the old text back. The `contract` resolves to the same bytes on every encounter for an account, whatever the template. The stored prompt shows why this matters: it asks for ICD and CPT codes, says to return "NA" when unsure and that "no fields are missing", and so contradicts the output rules the agent appends to it.

### PEA-801

**Title:** Save prompt fragments as new versions through an admin-only write path

**Description:**
As an AI/clinical admin, I want to save a new version of a prompt fragment of any of the four kinds, with the agent able only to read what I publish, so that every change to what the model is told is deliberate, attributable to me, and impossible for the agent to alter.

Today a prompt change is an in-place edit of the `AI.prompt` row. The agent records `promptTemplateHash` on each run because `promptId` alone does not say which wording was sent. With this story, saving a change inserts version N+1 beside version N, and N stays readable forever. The module the agent imports to read fragments has no write method, so the agent can never rewrite its own instructions.

**Scope**

- in: the insert-only save, version numbering, kind validation, an admin listing of versions, and the import boundary between the write module and the agent
- out: the `AI.promptFragment` table, its constraints and the agent-facing reader (Epic 2)
- out: the Prompt Studio user interface and any HTTP route for it; activation and the evaluation gate (PEA-804)

**Acceptance criteria**

- Saving an edited `task` fragment at scope global, where version 4 exists, inserts version 5 with the same kind and scope. Version 4's `fragmentText` is unchanged and still readable.
- A new version is saved with `isActive` 0 and `passedEvaluation` PENDING_EVAL. The agent keeps resolving version 4.
- The next version is one more than the highest version for that kind, scope and account, counting inactive and unevaluated rows.
- A kind other than `contract`, `task`, `specialty` or `template_override` is rejected before any SQL is sent. The message names the four kinds. If that check is bypassed, the table's `CHECK` constraint refuses the row.
- Every save records who made it (the admin's Entra object id) and when.
- No SQL constant in the write module updates `fragmentText`, `kind`, `scope`, `accountId` or `version`. A unit test checks every constant.
- A lint rule run inside `npm test` reports any file under `src/agents/` that imports the write module. A planted violation proves it fires.
- The agent-facing reader exports only the active-fragment read.

**Technical notes**

- `src/prompts/studio.ts` is a new folder with its own `#prompts/*` alias. It follows the house shape: one class per surface, one `run()`, and the exported singleton on the last line.
- Statements are `_SQL` constants above the class (insert, next version, list versions), run through `database.execute` with `@name` parameters. `UPDATE` touches only `isActive`, `passedEvaluation` and `updatedUtc`.
- The save input is parsed at the boundary by a zod schema whose `kind` is a `z.enum` over an exported `FRAGMENT_KINDS` constant. The rejection text is an exported constant.
- The import boundary is a `no-restricted-imports` entry in `eslint.config.js`, scoped to `src/agents/**`, with its planted violation in `tests/unit/source-rules.test.ts`.
- Fragment text is prompt text, not PHI. Log lines carry kind, scope, accountId and version, never the text.
- Tests: `tests/unit/prompts/studio.test.ts`; `tests/integration/prompts/studio.test.ts` checks the defaults on a real row.

**Before you build (due diligence)**

- `AI.promptFragment` does not exist. Epic 2 withdrew it on 2026-10-06, and no migration in `migrations/sql/` creates it. Get the owner to reinstate it, and agree who writes the migration, before any code.
- The project decided on no database roles and no `GRANT`s. The agent and this write path share one pool and one identity, so "the agent only reads" rests on the lint rule alone. Decide whether the write path gets its own login, or accept code as the only control.
- The drafted table has no column for who saved a version, for the legacy `promptId` (PEA-803) or for the verdict's failing metric (PEA-804). Add them to the reinstated migration rather than in a later fix.
- Find out who at Saisystems writes prompt text today, and in which screen (the legacy `AI.prompt` admin page). The Prompt Studio has no route to this module. Agree how it will call it.
- Two concurrent saves must not take the same version number. Compute it inside the `INSERT` and let the unique key refuse a duplicate. Decide whether the caller retries or sees a clear error.

---

### PEA-802

**Title:** Resolve prompt fragments by account, then version, failing closed on a tie

**Description:**
As a platform engineer, I want fragment resolution to follow one tested order, and to fail closed on any tie, so that which prompt text reached the model is never an accident and every output traces back to exact fragment versions.

Today `usp_getPrompt` chooses in three tiers: the template's `promptId`, then the account's universal row, then the global universal row. It can return two rows, which the agent blocks as PROMPT_AMBIGUOUS, and it does not filter deleted rows. The resolver replaces this with one documented order: an account fragment beats a global one, the highest version wins, and only active, PASSED rows count. One resolver serves the agent and Epic 7's prompt tool.

**Scope**

- in: pure resolution functions over rows already read by Epic 2's reader, and the structured result
- out: the reader and the table (Epic 2); filling, joining and hashing the prompt (Epic 4's `composePrompt`); any cache

**Acceptance criteria**

- For account 118, an account-scoped `contract` at version 3 beats a global `contract` at version 9.
- Within the winning scope, the highest eligible version wins: of versions 3, 4 and 5, with 3 and 5 eligible, version 5 is returned.
- A version that is active but not PASSED is never a candidate. With version 8 active but unevaluated and version 7 active and PASSED, version 7 is returned.
- Two eligible rows with the same kind, scope, accountId and version return neither row and report PROMPT_AMBIGUOUS. The guard blocks the run before any model call.
- No eligible `specialty` or `template_override` fragment is a silent omission. `contract` and `task` still resolve.
- No eligible `contract` or `task` reports PROMPT_NOT_FOUND, and the run is blocked.
- An account-scoped fragment of account 118 never resolves for account 119.
- The result lists kind, fragmentID, version and fragmentText for each resolved fragment, never joined text. The run records those ids and versions beside the prompt hash.

**Technical notes**

- `src/prompts/resolver.ts` exports pure functions with no database access and no cache. Its input is the rows from Epic 2's reader (`promptFragmentReader.activeFragments(accountId)`, planned).
- It filters again on `isActive` and `passedEvaluation === 'PASSED'`. The comparison is with PASSED, never "not BLOCKED", so a new state fails closed.
- It reuses the GUARD codes PROMPT_AMBIGUOUS and PROMPT_NOT_FOUND from `src/agents/failure-modes.ts`, so no reason code is added. It returns a refusal object, like `composePrompt` does, and the guard turns it into a block. It never throws.
- The table keys a fragment on kind, scope, accountId and version only. So at most one `specialty` and one `template_override` resolve per account, and they apply to every template. The `contract` has no template or task input, which is what makes it identical across templates (PEA-806).
- State carries `promptId` and `promptTemplateHash` for the stored row today. These become the resolved fragment ids and versions.
- Tests: `tests/unit/prompts/resolver.test.ts`, with in-memory rows only.

**Before you build (due diligence)**

- Epic 4's PEA-404 shipped against the stored row and dropped its link to this story. Agree who changes the guard's `prompt_load` step and `composePrompt` to take resolved fragments, and in what order the fragments, `OUTPUT_RULES` and memory are joined.
- The legacy tier 1 is per template (`Template.encounterTempletes.promptId`). Count the templates with a `promptId` above 0 in production. If there are any, a table with no `templetID` loses them. The earlier draft of the table had a `templetID` column. The owner decides.
- `AI.encounterTranscript` (`migrations/sql/0004_create_encounter_transcript.sql`) records `promptId` and a hash of the `AI.prompt` text. Decide the columns for fragment ids and versions before the first audit write.
- Check that the reinstated table keeps a filtered index on active, PASSED rows, so the per-run read stays one indexed query with no cache.

---

### PEA-803

**Title:** Migrate the legacy AI.prompt rows once and take them off the agent's path

**Description:**
As a platform engineer, I want one re-run-safe migration that reads every legacy `AI.prompt` row once and seeds it into versioned fragments, so that cutover happens on a known day, cannot run twice by accident, and leaves the agent no longer reading the old table.

On DEV the agent uses promptId 20, "test universal prompt", for account 1. Its text asks for ICD and CPT codes and a follow-up date, says "Always return 'NA' if you are not sure" and says no fields are missing, while the agent's own output rules say an unmentioned field is null. The legacy table has also held a row whose whole body is `sdwdxs`. The migration copies no junk forward and picks no winner between contradictory lines; it records them for a person to settle.

**Scope**

- in: one read of every `AI.prompt` row, mapping to draft fragments, a skip log, provenance, a guard against a second run, the version-1 exception, and removing the agent's `usp_getPrompt` read
- out: dropping or changing `AI.prompt`, `usp_getPrompt` or the legacy admin page and UI, which keep using them; the table itself (Epic 2)

**Acceptance criteria**

- Every legacy row is either mapped into a new fragment version or logged as skipped, with a reason and its `promptId`. Each fragment the migration creates records the `promptId` it came from.
- A row whose whole body is junk, such as `sdwdxs`, is never written forward as an active fragment. It is logged as skipped for a person to confirm.
- Contradictory instructions across rows of one template family ("Always return NA" against "never write N/A") are not resolved automatically. Both source `promptId`s are recorded against one draft `contract` for an admin to finish through PEA-801 and PEA-806 before it is activated.
- Version-1 fragments are created with `isActive` 1 and `passedEvaluation` PASSED. The reason is stated once, in the migration module: a version 1 has no earlier version to compare with.
- A second run changes nothing, reports that the migration already ran, and creates no duplicate version 1.
- A migrated `task` fragment keeps the legacy `<<name>>` placeholders, which `composePrompt` already fills. It passes PEA-805's check unchanged, or it is logged for a person when a required placeholder is missing.
- After cutover, the guard no longer runs `GET_PROMPT_SQL`. A lint rule reports any reference to `AI.prompt` or `usp_getPrompt` under `src/` outside the migration module, with a planted violation.

**Technical notes**

- `src/prompts/migration.ts` holds one class, `MigrateLegacyPrompts`, with one `run()`. An npm script starts it through an entry file at the `src/` root, like `src/migrate.ts`, because a module that runs on import would fail the whole-tree import check. It is a data migration, separate from `npm run migrate`, and `AI.prompt` stays as history.
- It reads through one `SELECT_LEGACY_PROMPTS_SQL` constant. `usp_getPrompt` does not filter `isDeleted`, so the migration reads that column itself.
- It writes through PEA-801's write module, with no back door. The version-1 activation is the only exception.
- Before it writes anything, it checks whether any fragment already carries a legacy `promptId`. On a second run it does nothing.
- Splitting each row into kinds is a one-time classification that a person reviews, not a parser. Boilerplate repeated across rows becomes the `contract` candidate (finished in PEA-806). The rest becomes `task`, `specialty` or `template_override`, scoped global unless the row belonged to one account.
- Tests: `tests/unit/prompts/migration.test.ts`, with seeded rows for the junk case, the contradiction and the second run.

**Before you build (due diligence)**

- Inventory `AI.prompt` read-only on DEV and in production first: rows, `isActive`, `isUniversal`, `isDeleted`, `accountId`, and the templates that point at each row. In 1,000 production calls, 19 system prompts appeared and one universal prompt carried 895. Confirm the `sdwdxs` row and the NA/N-A pair still exist; they are unverified here.
- Agree with the owner of the prompt text at Saisystems how each row is split, and who signs off. The ICD, CPT and follow-up requests, "return NA" and "no fields are missing" do not belong in field extraction. Measured: they cost about 1.4K tokens per request and fight the null rule, and the current system that sends them invented seven review-of-systems values on a note that had none. Recall matters most to the client now, so drop them only with a measured run.
- The accuracy suite (`npm run eval`) compares a run with a stored benchmark, not with an earlier version. A version 1 can therefore be gated. Decide whether the version-1 exception is still needed.
- After cutover, edits made in the legacy admin page still change `AI.prompt`, which the agent no longer reads. Decide whether to freeze that page, warn on it, or sync it.
- Run `npm run eval` on the stored prompt and on the migrated fragments, same day and same model, and compare before switching.

---

### PEA-804

**Title:** Block a prompt fragment from resolving until it passes evaluation

**Description:**
As an AI/clinical admin, I want my edit blocked from taking effect until it has passed evaluation, so that I cannot roll a regression out to every clinician the moment I save it.

A new version cannot resolve until `passedEvaluation` is PASSED. The column holds the verdict as given (PENDING_EVAL when inserted, then PASSED, BLOCKED or INCOMPLETE), so a version nobody has evaluated and one that failed stay distinct. The verdict comes from the accuracy suite today (`npm run eval`: five reference queries, three runs each, precision and recall against a benchmark that only ratchets up) and from Epic 10's replay and promotion metrics later. This story owns only the gate on the table: no activation before PASSED, and no verdict set by hand.

**Scope**

- in: the activation check, the narrow path that records a verdict, the rejection message and its attribution
- out: computing the verdict (the accuracy suite today, Epic 10 later) and the shared metric vocabulary (Epic 10)

**Acceptance criteria**

- Version 8 of `contract`, saved and marked active while PENDING_EVAL, is not returned. The resolver returns PASSED version 7.
- When the verdict on version 8 is BLOCKED with recall as the failing metric, activation is rejected. The rejection names recall, and the status stays BLOCKED.
- When the verdict is PASSED, it is recorded on version 8, an admin can activate it, and the resolver returns it. Version 7 stays stored, inactive and readable.
- A version marked INCOMPLETE is not returned. The admin listing shows INCOMPLETE, not PENDING_EVAL.
- No admin method takes `passedEvaluation` as input. Only the verdict-recording path writes it.
- A rejected activation is logged with who tried, which version, and the failing metric.

**Technical notes**

- Read side: PEA-802's filter already requires `isActive` and PASSED. This story pins that filter down with its own tests.
- Write side: activation in `src/prompts/studio.ts` refuses unless the version is PASSED. The verdict is written by a separate class in `src/prompts/` whose `_SQL` constant is the only statement that sets `passedEvaluation`.
- Until Epic 10 lands, the verdict comes from the accuracy suite's run summary (`logs/eval/latest.json`), which names the rate that fell below the benchmark.
- The rejection text is an exported constant. PEA-803's migration is the only caller that inserts a row already active and PASSED.
- Tests: `tests/unit/prompts/gate.test.ts`.

**Before you build (due diligence)**

- The suite runs the agent as deployed, and the resolver returns only active, PASSED versions. So a candidate cannot be evaluated yet. Design a way to pin a candidate version for an evaluation run only, and make sure it cannot become a back door in production.
- The suite covers one DEV template (457), one account and five synthetic queries. It takes about 11 minutes and $0.76 per run, and its tolerance is 5 points. Decide whether that is enough to gate a `contract` change for every account, and which queries to add first.
- The client cares about recall more than precision. Decide the rule: for example, recall may not fall at all, and precision may fall within the tolerance.
- A verdict covers a combination of fragments, but `passedEvaluation` sits on one row. Decide whether versions are promoted as a set.
- Model change: a verdict holds for the model it ran on (the benchmark records gpt-4.1). gpt-4.1 is closed to new customers and retires on 2027-04-14. Newer reasoning models mostly do not accept temperature 0, so a replay "at temperature 0" no longer applies. Record the model with each verdict, and decide whether a model change resets every fragment to PENDING_EVAL.

---

### PEA-805

**Title:** Require the task fragment's per-request placeholders when it is saved

**Description:**
As an AI/clinical admin, I want the task fragment to declare exactly which per-encounter values it needs (task type, template name, place of service, date of service and the slot list), so that a fragment I save can never silently leave out a value the agent needs.

`composePrompt` fills `<<name>>` placeholders in one pass, and blocks the run as PROMPT_PLACEHOLDER_UNFILLED when the text names one it does not fill, such as `<<todayDate>>`, which it never fills by design. The old UI's string replacement once shipped "Dynamic Location" where the place of service belonged. That check runs per request, after the text is live; this story runs it when the fragment is saved.

**Scope**

- in: save-time validation of a `task` fragment's placeholders
- out: filling them (Epic 4's `composePrompt`), the slot list's content (Epic 3) and any user interface

**Acceptance criteria**

- A `task` fragment that contains every required placeholder is saved as a new version.
- A `task` fragment without the slot-list placeholder (`<<encounterFields>>`) is rejected, and the rejection names it.
- When several are missing, the rejection names each one.
- A placeholder the agent never fills, such as `<<todayDate>>`, is rejected at save and named.
- The check uses the same `<<name>>` syntax as `composePrompt`, so a migrated legacy row that has the placeholders passes unchanged.
- A unit test fails if the required set names a placeholder that `composePrompt` does not fill.

**Technical notes**

- `TASK_FRAGMENT_REQUIRED_PLACEHOLDERS` is an exported constant in `src/prompts/studio.ts`, never a literal at the check site. Today's names are `templateName`, `encounterPOS`, `DOSDate` and `encounterFields`, plus a task-type placeholder.
- The check uses the same pattern as `composePrompt` (`/<<(\w+)>>/g` in `src/agents/prompt.ts`).
- The request-time PROMPT_PLACEHOLDER_UNFILLED block stays as the last line of defence.
- The rejection is a return value that the Prompt Studio displays. Its text is an exported constant.
- Tests: in `tests/unit/prompts/studio.test.ts`.

**Before you build (due diligence)**

- There is one task today, extraction. `composePrompt` fills no task type, and `templateProcess` is the UI's fixed "admitted". Decide with the owner: add `<<taskType>>` to `composePrompt`, or drop task type from the required set.
- Decide which of `composePrompt`'s other placeholders are required. `promptBody` carries the section prompts, and the review-of-systems fields recovered when it was first sent.
- Use PEA-803's inventory to list each legacy row's placeholders, so the migrated `task` fragment passes this check.
- Decide whether a placeholder in a non-`task` fragment is filled or rejected.

---

### PEA-806

**Title:** Author the contract fragment as one byte-identical, auditable rule set

**Description:**
As a compliance officer, I want the rules every extraction follows to live in one fragment whose resolved bytes are provably identical on every encounter, so that I can show an auditor or a clinical buyer that the model's rules never varied by template, specialty or task.

Today two places hold rules: the stored row says "Always return 'NA' if you are not sure", while `OUTPUT_RULES`, appended once by code, says an unmentioned field is null and an unsure one is ABSTAINED, and ends by saying these rules win where they conflict. The `contract` fragment becomes the one place for these rules. It is keyed only by scope, account and version, so an account gets the same bytes on every call. An auditor can compare the bytes, and the provider can reuse the cached text.

**Scope**

- in: the version-1 text of seven rules, the content tests, and the byte-identical property
- out: whether the model obeys the rules on real notes (the evaluation gate); the tools rule 5 names (Epic 7)

**Acceptance criteria**

- Rule 1: "Fill only the slots listed in the slot list. Never invent a slot."
- Rule 2: every FOUND value quotes the exact span it came from (`found_in`, copied character for character).
- Rule 3: when the note is silent the slot is null; when the text exists but the value cannot be filled reliably it is ABSTAINED, with the reason in `remark`. An abstention is better than a guess. A unit test fails if `ExtractedValue`'s status values and the ones the contract names differ.
- Rule 4: "Report units exactly as written. Never convert."
- Rule 5: "Never calculate." It names Epic 7's date and BMI tools by the names Epic 7 registers (planned: `resolve_date` and `compute_bmi`).
- Rule 6: "A section slot summarises its child slots; do not duplicate a child value into it."
- The text has no instruction about JSON validity, key names or brace matching, and no "NA" or "N/A" token.
- For one account, the `contract` resolved for template 457 and for a second template is byte-identical. It changes only through a new version saved (PEA-801) and promoted (PEA-804).

**Technical notes**

- The version-1 text is an exported string constant in `src/prompts/seeds/contract-v1.ts`, reviewed like any code. PEA-803 seeds it, and nobody edits it after that. A constant ships with the build, because `tsc` emits only `.js`.
- It starts from `OUTPUT_RULES` (`src/schema/contract.ts`, 978 characters), which already states rules 2 and 3 in measured wording. Once the `contract` resolves, `composePrompt` stops appending `OUTPUT_RULES`, so each rule exists once.
- The tests check that each rule is present and the banned text is absent. They are content tests, not behaviour tests: `tests/unit/prompts/contract-v1.test.ts`.
- A later edit that weakens a rule is for the evaluation gate (PEA-804) to catch before promotion, not for this test.

**Before you build (due diligence)**

- Decide where the contract lives. `OUTPUT_RULES` is code, reviewed in a PR and gated by `npm run eval`, and it explains the keys of `ExtractedValue`. A row an admin can edit can drift from the schema it explains. Confirm with the owner before moving it.
- Rule 5 names tools the agent does not have: there are no tools today (Epic 7 not started). Hold rule 5 until the tools exist, then measure it.
- The schema has one slot per field and no section slots, so check that rule 6 applies. The recall work wants one fact to fill several fields (review of systems), so rule 6 must not turn into "one fact, one field".
- Rule wording moves recall. On 2026-10-12, one line of the output rules took recall on the simple note from 68.8% to 89.6% (three runs against three). Run every contract change through `npm run eval`, and on a model change run it on the new model too.
- Azure caches an identical prompt prefix. Today the stored row comes first and `OUTPUT_RULES` after it. Measure `usage_metadata.input_token_details.cache_read` before and after putting the contract first.

---

### PEA-807

**Title:** Roll back a fragment by re-activating an earlier version; compare two

**Description:**
As an AI/clinical admin, I want to make an earlier version of a fragment current again with one action, and to see two versions side by side first, so that undoing a bad prompt is as fast as making the mistake, and I never rebuild the old wording from memory.

Today the only way back for the stored row is typing the old text in again. That is another unversioned overwrite, and it destroys the record of the bad version; only `promptTemplateHash` on past runs remains. Here, rollback changes which version is active and never touches text. Comparison shows two versions without changing which one is live.

**Scope**

- in: rollback as an activation change, read-only comparison, and the record of who rolled back and when
- out: re-evaluating the target version, and any diff display (Prompt Studio)

**Acceptance criteria**

- Rolling `contract` back from version 8 to version 7 makes the resolver return version 7. Version 8's row and text are unchanged, and the rollback records who did it and when.
- Rolling back to a version that already passed resolves at once, with no new evaluation.
- Rolling back to version 6, which never reached PASSED, is refused, and the resolver still returns version 7.
- Comparing versions 7 and 8 returns both texts, version numbers and `passedEvaluation` values, and changes neither `isActive` flag.
- After a rollback, the restored version's text hashes to the same value as before.
- After a rollback, exactly one version of that kind, scope and account is active.

**Technical notes**

- `src/prompts/studio.ts` holds `RollbackFragment` and `CompareFragmentVersions` as separate classes, each with one `run()`, so comparing can never change the active version.
- Rollback is one `UPDATE` that sets `isActive` to 1 on the target and 0 on the others of that kind, scope and account. One statement is atomic, and `database` has no transaction helper. It never reads or writes `fragmentText`.
- It reuses PEA-804's PASSED check, with no bypass. A version that passed before keeps that verdict.
- The rollback record has the same who-and-when shape as a save (PEA-801). Version roles are named parameters (`targetVersion`), never bare literals.
- Tests: `tests/unit/prompts/rollback.test.ts`; an integration test for the single-statement switch.

**Before you build (due diligence)**

- The drafted table has only `updatedUtc`, with no event table. Decide where "who rolled back, when, from which version" is stored.
- When a contract and a task were promoted together, rolling back one of them creates a combination nobody evaluated. Decide whether rollback works on a set.
- A version that passed on gpt-4.1 is unproven on a newer reasoning model. Decide whether rollback to a version evaluated on another model needs a new run.
- The guard resolves once per run, so a rollback affects only later runs. Confirm that is acceptable for runs in flight.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-801 | Not started (later sprint) | 5 | PEA-205 (Epic 2, withdrawn) | Nothing yet. No `promptFragment`, `src/prompts/` or Prompt Studio code anywhere in `PacEHR_AI` (grep, 2026-10-14). | `pacehr/prompts/studio.py` becomes `src/prompts/studio.ts` with a new `#prompts/*` alias. The import-graph test becomes an ESLint `no-restricted-imports` guard with a planted violation, the house pattern for structural rules. The two database roles (`aiPromptAdmin`, `aiServiceRuntime`) are gone: no roles or grants by project decision, so the boundary is code only. A save records the admin's Entra object id. | `AI.promptFragment` was withdrawn on 2026-10-06 (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` §A3). No roles and no `GRANT`s, 2026-10-05 (same table). The draft DDL `docs/sql/0006_create_prompt_fragment.sql` has no created-by, legacy-promptId or failing-metric column. There is no HTTP route for the Prompt Studio (`docs/tickets/GAPS.md` #22). |
| PEA-802 | Not started (later sprint) | 5 | PEA-801, PEA-205 | Nothing yet. | `resolver.py` becomes `src/prompts/resolver.ts`, pure functions. A tie reuses PROMPT_AMBIGUOUS and a missing required kind reuses PROMPT_NOT_FOUND, both existing GUARD codes, instead of a new "precedence-conflict" or the removed PROMPT_FRAGMENT_MISSING. Adds a cross-account test (GAPS "should exist" #8). The call site is Epic 4's guard `prompt_load` step (there is no `before_model`). | Epic 4 PEA-404 is Done against the stored row and dropped its PEA-802 dependency (`docs/js-tickets/epic-04-agent-core.md`), so wiring the resolver into the guard needs an owner. Grain: the Python story has no `templetID`; the D11 draft DDL adds one. The audit columns in `migrations/sql/0004_create_encounter_transcript.sql` record `promptId` and the `AI.prompt` hash only. |
| PEA-803 | Not started (later sprint) | 5 | PEA-801, PEA-805, PEA-806 | Nothing yet. Today `src/agents/middleware/guard.ts` runs `GET_PROMPT_SQL` (`usp_getPrompt`); on DEV that is promptId 20, account 1 (`tests/manual/agentResponse.manual.ts`). | `migration.py` becomes `src/prompts/migration.ts` plus a root entry script like `src/migrate.ts`. `mssql_python` and `asyncio.to_thread` give way to `database.execute`. The repository-wide search becomes a lint rule. The story also removes the guard's `GET_PROMPT_SQL`. The placeholder clash (GAPS #21) is gone, because legacy rows and `composePrompt` share `<<name>>`. | Stored-prompt content: `docs/2026-10-09-pacehr-ai-change-log.md` open issue 2 (ICD/CPT/follow-up, "NA", "no fields are missing", about 1.4K tokens). `docs/2026-10-12-five-query-comparison.md`: the current system invented 7 review-of-systems values on Q2 (precision 69%). The promptIds 12 and 15 pair and the `sdwdxs` row are not verified. `usp_getPrompt` defects (Epic 2 doc S19). The legacy admin page keeps writing `AI.prompt`. |
| PEA-804 | Not started (later sprint) | 5 | PEA-801, PEA-802; Epic 4 PEA-408 (today's verdict source); Epic 10 PEA-1004/1007/1008 (later) | Nothing yet. The accuracy suite exists: `npm run eval`, `tests/eval/` (`benchmark.json`, `history.jsonl`, `promote.ts`). | The verdict source is PEA-408's suite until Epic 10 lands. The example failing metric changes from "evidence-bound rate" to recall, because the suite reports precision and recall. `test_promotion_gate.py` becomes `tests/unit/prompts/gate.test.ts`. | Candidate pinning for evaluation runs. Coverage: template 457 and five synthetic queries; 5-point tolerance from a measured spread of precision 78–91% and recall 75–80% (`tests/eval/CLAUDE.md`). Recall-first gate rule. Verdict per set or per row. Model on the verdict. Epic 10's "replay at temperature 0" does not fit reasoning models. |
| PEA-805 | Not started (later sprint) | 3 | PEA-801 | Nothing yet. The request-time check exists: PROMPT_PLACEHOLDER_UNFILLED in `src/agents/prompt.ts`, tests in `tests/unit/agents/prompt.test.ts`. | The snake_case names (`task_type`, `slot_manifest` and others) become the `<<name>>` placeholders `composePrompt` fills: `templateName`, `encounterPOS`, `DOSDate`, `encounterFields`, plus a task type. A `frozenset` becomes an exported constant. Two checks are added, both implied by today's code: reject a placeholder the agent never fills (`<<todayDate>>`), and test the required set against `composePrompt`. GAPS #20 no longer applies, because PEA-404 does fill placeholders. | No task-type placeholder exists today, and `templateProcess` is the fixed "admitted". Decide whether `promptBody` is required (change log A2: review-of-systems recovery when section prompts were sent). |
| PEA-806 | Not started (later sprint) | 8 | PEA-801, PEA-802 | Nothing yet. The closest thing today is `OUTPUT_RULES` in `src/schema/contract.ts` (978 characters), appended by `composePrompt`. | `seeds/contract_v1.txt` becomes a TypeScript constant, `src/prompts/seeds/contract-v1.ts`. The status values FOUND/ABSENT/ABSTAINED become `ExtractedValue`'s FOUND/ABSTAINED plus null for absence. The text starts from `OUTPUT_RULES`, which stops being appended once the contract resolves. The size is about 1K characters today, not about 1.7K. | Contract in code or in a row (decision). Rule 5 names Epic 7 tools that do not exist; the agent has no tools. Rule 6: no section slots, and it conflicts with recall experiment E2, "one fact fills several fields" (`docs/2026-10-13-recall-observability-brainstorm.md` §7). F3 recall evidence: change log F3 (68.8% to 89.6%). Prompt-prefix caching order. |
| PEA-807 | Not started (later sprint) | 5 | PEA-801, PEA-804 | Nothing yet. | `RollbackFragment.run()` and `CompareFragmentVersions.run()` are kept as TypeScript classes. "One transaction" becomes one `UPDATE` statement, because `database` has only `execute` and `run`, with no transaction helper (GAPS #17 still holds). Adds a hash check on the restored text. | Where the rollback event is stored. Set rollback. Rollback across a model change. |

Total: 36 points (5 + 5 + 5 + 5 + 3 + 8 + 5), the same as the Python epic. None started.

### Notes

- **What changed from the Python edition, epic-wide:**
  - Code lives in `src/prompts/` (`studio.ts`, `resolver.ts`, `migration.ts`, `seeds/contract-v1.ts`) with a new `#prompts/*` alias. Tests are `node:test` under `tests/unit/prompts/` and `tests/integration/prompts/`.
  - SQL is `_SQL` constants run through `database.execute` with `@name` parameters. There is no blocking driver and no `to_thread`.
  - Structural rules (the agent never imports the write module; nothing reads `AI.prompt` after cutover) are ESLint guards with planted violations in `tests/unit/source-rules.test.ts`, not source-parsing tests. `CLAUDE.md` says tests assert behaviour, not shape.
  - No new reason codes. Resolution failures reuse PROMPT_AMBIGUOUS and PROMPT_NOT_FOUND, and PROMPT_PLACEHOLDER_UNFILLED stays the request-time backstop (`src/agents/failure-modes.ts`).
  - The promotion gate consumes the PEA-408 accuracy suite now, and Epic 10 later.
  - Placeholders use the existing `<<name>>` syntax. The contract's status values follow `ExtractedValue`, which is FOUND/ABSTAINED plus null.
- **Decisions and conflicts the team must resolve:**
  - **The table this epic writes was withdrawn.** On 2026-10-06, `AI.promptFragment` and `AI.fieldDescription` were withdrawn, and prompts come from `AI.prompt` (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` §A3). The repository's migrations `0001`–`0006` do not create it. Epic 8 cannot start until the owner reinstates it. The draft DDL (`docs/sql/0006_create_prompt_fragment.sql`, decision D11) adds `templetID` and a sentinel 0; the Python story's grain has no `templetID`. Pick one.
  - **No database roles or grants** (2026-10-05, same table). The Python epic's two-layer "agent never writes" rests on one layer, the lint rule, unless the write path gets its own login.
  - **Who wires the resolver into the agent.** Epic 4's PEA-404 is Done against the stored row (`docs/js-tickets/epic-04-agent-core.md`). Either reopen it or add the guard change to PEA-802.
  - **Who owns the prompt text.** Template and prompt data are owned by the client (spec O21, cited in `docs/2026-10-13-single-vs-multi-agent.md` §6). The legacy C# `AI.prompt` admin page stays unchanged (Epic 2 doc §A3). Name the Saisystems person who authors and signs off fragments, and decide what happens to edits made in the legacy page after cutover.
  - **The stored prompt works against recall.** The change log (`docs/2026-10-09-pacehr-ai-change-log.md`, open issue 2 and F3) and the five-query comparison (`docs/2026-10-12-five-query-comparison.md`) show the ICD/CPT, "NA" and "no fields are missing" lines fighting the null rule and the old system inventing review-of-systems values. The client now cares about recall over precision. Recall brainstorm §3 proposes "a prompt change with a range > 5 pts does not ship". Experiment E2 (§7) is itself a contract change.
  - **Evaluation gate scope.** `tests/eval/CLAUDE.md` and `docs/2026-10-14-agent-eval-suite.md` cover template 457 on DEV account 1 only. Production uses 19 prompts, with prompt 2 on 895 of 1,000 calls (`docs/2026-10-12-clinician-usage-behaviour.md`). The gate needs more queries and templates before it can gate account-scoped fragments.
  - **Model change.** gpt-4.1 is closed to new customers and retires 2027-04-14. Newer models are reasoning models, mostly without temperature 0 (`docs/2026-10-13-single-vs-multi-agent.md` §5). Verdicts must record the model, and a model switch needs a re-run of every active fragment set.
  - **SOP fit.** No SOP item asks for fragments, precedence or a gate. The epic exists because of live contradictions, and because a benchmark is meaningless if the prompt can change underneath it (`docs/tickets/SOP-COVERAGE.md`). `specialty` fragments are the natural host for SOP 7.1, which has no story.
