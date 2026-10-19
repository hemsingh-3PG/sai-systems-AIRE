# Epic 2 — Data layer (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Data layer: the AI-schema tables behind a forward-only migration runner

**Description:** This epic gives the encounter agent its own tables in the `AI` schema of the existing Azure SQL database. Forward-only, idempotent migrations create them, and those migrations touch nothing outside that schema. No existing clinical table is altered or written. The five tables are `AI.agentRun` (one audit row per run), `AI.fieldOutcome` (the AI's proposal beside the clinician's decision), `AI.promptFragment`, `AI.fieldConstraint` and `AI.fieldDescription`. `AI.fieldOutcome` matters most: it feeds the review queue, it is the labelled set Epic 10 evaluates against, and, now that the client cares most about recall, it shows which values the note gave and the AI missed. Every key column keeps the live database's spelling (`templetID`, `sectionID`, `fieldID`). Several table designs exist, so each ticket asks the team to confirm the approved one before building.

### PEA-201

**Title:** Apply the AI schema through a forward-only, idempotent migration runner

**Description:**
As a platform engineer, I want one runner that applies forward-only, idempotent scripts to the `AI` schema and refuses anything else, so that I can run it against the live database, which already holds real patient data, without risking anything that exists there today.

Every other ticket in this epic assumes the `AI` schema, its tables and its access rules exist. This ticket is the one place where a mistake reaches production data that predates the project. Each script is plain, literal SQL that a reviewer can read from start to finish. There is no down-migration to run by accident: a fix is always a new numbered script.

**Scope**

- in: `migrations/sql/` and its naming rule, the runner, the deploy-time entrypoint, the schema-scope check, a guarded script that creates the `AI` schema on an empty database
- in: the roles `aiServiceRuntime`, `aiPromptAdmin` and `aiTemplateAdmin`, if the owner confirms roles (see due diligence)
- out: the tables (PEA-202 to PEA-207), and the pipeline step that runs the entrypoint (Epic 11)

**Acceptance criteria**

- `npm run migrate` applies every script under `migrations/sql/` in filename order, one `GO`-separated batch at a time. Afterwards the `AI` schema exists (and the three roles, if confirmed), and no row in any existing clinical table was added, changed or removed.
- A second run raises nothing and creates or alters nothing, because every `CREATE` sits behind its own existence check.
- A script containing `ALTER TABLE Encounter.encounter ADD aiFlag BIT` fails the unit suite. The runner also refuses the whole set before it runs any script.
- A script that drops, truncates or alters a table, writes rows outside `AI`, or creates an object without an `AI.` prefix is refused.
- A failed batch ends the process with exit code 1. The log names the script and the batch number, never the SQL text.
- Importing the runner opens no connection, and the unit import proof still passes.
- A second engineer reviews each script, and it runs against a copy of production before production. The post-apply checks then show that nothing outside `AI` changed that day.

**Technical notes**

- `src/core/databaseMigrations.ts` exports the singleton `migrationRunner` with one method, `applyPending()`, and exports `validate`, `readScripts` and `batches` for tests. `src/migrate.ts` is the entrypoint (`npm run migrate`, or `npm run migrate:prod` on the built output). It lives outside `src/core/` because it runs on import.
- Each batch goes through `database.run(batch)`, the shared pool's method for statements that return no rows. The runner opens no second connection.
- Scripts are named `NNNN_lower_snake.sql`, so filename order is numeric order. Idempotency comes from each script's `IF NOT EXISTS` guards, not from a history table, so every run re-checks every script.
- The scope check is plain regular expressions over comment-stripped text. The unit test and the runner both run it. No new dependency.
- If roles are confirmed, the identity that runs migrations is not the one that serves requests, so the runtime identity never holds schema-creation rights.
- Tests: `tests/unit/core/databaseMigrations.test.ts`, and `tests/integration/core/databaseMigrations.test.ts`, which applies the set twice to the configured database.

**Before you build (due diligence)**

- Confirm which table design is approved before adding any script. Four exist: this epic's five tables, a seven-table multi-turn design (2026-10-06), a three-table chat design (draft rev 5), and the merged set (rev 7: five tables and a view). The merged set already uses script numbers 0001 to 0006, so any new script takes the next free number.
- Confirm whether roles and GRANTs are in scope. On 2026-10-05 the owner decided that the application controls access, with no roles and no GRANTs. If that stands, every "no write grant" criterion in this epic becomes a code-review check, and "append-only" becomes a convention. If roles come back, the runner needs a change first: it currently refuses `GRANT SELECT, INSERT ON AI.x` and `GRANT INSERT, UPDATE ON AI.x` as "writes on with no schema". It accepts `GRANT SELECT` and a column-level `GRANT UPDATE (…)`.
- Run the post-apply checks against DEV to learn whether the merged set was applied. The integration test skips when SQL is unreachable, so a green run proves nothing on its own.
- The merged scripts assume the `AI` schema already exists, because it holds the existing prompt table. Decide whether an empty database needs a guarded create-schema script. Confirm with DevOps that no SSDT publish runs with "drop objects not in source", which would delete every `AI` object.
- The entrypoint reads the same settings as the service. Check that the pipeline gives it its own managed identity. Also extend the lint rule against SQL built at the call site to cover `database.run`, which it does not cover today.

---

### PEA-202

**Title:** Record one append-only AI.agentRun row per agent run, blocked runs included

**Description:**
As a compliance officer, I want an append-only record of every agent run, including runs that never reached the model, so that "show me every AI call on this chart" always has an answer that no application code changed afterwards.

Today the browser writes the only log of an AI call, after the response ends. It carries token counts the client reports itself, and it is missing whenever the client fails. `AI.agentRun` replaces it with a row the agent writes on the server, once per run. A guard block ends the run with `jumpTo: 'end'`, which still runs the outcome hook, so a blocked run gets its row too. That is the run most worth recording. Nobody edits this table: a wrong row is corrected by a new run.

**Scope**

- in: the migration for `AI.agentRun`, the writer and its one INSERT, the `outcome`, `reasonCode` and `failureMode` columns matched to the agent's own codes, and the rule that the service can never update or delete a row
- out: the transaction that commits this row with the field rows (Epic 9, PEA-902), and the dashboards (Epic 10)

**Acceptance criteria**

- A run that ends COMPLETED writes exactly one row with no reason code. `promptId`, `promptTemplateHash`, `promptHash`, `modelName`, `inputTokens`, `outputTokens` and `latencyMs` are all set.
- A run the guard blocks, for example with INJECTION_BLOCKED, still runs the outcome hook. It writes exactly one row with outcome BLOCKED and that reason code. Model name, tokens and latency are NULL, because the model was never called.
- A failed model call, for example MODEL_CALL_FAILED, writes one row with outcome FAILED, its reason code and no failure mode. An extraction failure, for example OUTPUT_TRUNCATED, also carries failure mode FORMAT.
- The table refuses an inconsistent row: COMPLETED with a reason code, another outcome without one, a failure mode on a run that is not FAILED, or a run that is not BLOCKED but has no prompt hash.
- Each of the agent's 14 reason codes fits the `reasonCode` column, and a row for each one passes the table's checks.
- The service's database principal holds only SELECT and INSERT on `AI.agentRun` (checked in `sys.database_permissions`), and the server refuses an UPDATE from it.
- The writer issues one statement, an INSERT. It has no update or delete path (checked in review).
- The table stores no clinical value: only hashes, the model name, counts, timing and codes.

**Technical notes**

- `migrations/sql/NNNN_create_agent_run.sql`, using the next free number. Each CREATE in the script sits behind its own existence check.

```sql
CREATE TABLE AI.agentRun (                                            -- one append-only row per agent run, blocked and failed runs included
  runID              BIGINT IDENTITY NOT NULL,                        -- run id; ascending = order written
  encounterID        INT             NOT NULL,                        -- Encounter.encounter.encounterID; logical reference, no foreign key (SSDT-owned table)
  promptId           INT             NULL,                            -- AI.prompt.promptId from dbo.usp_getPrompt; NULL if blocked before the prompt loaded
  promptTemplateHash CHAR(64)        NULL,                            -- SHA-256 of the stored prompt row as read; that row is edited in place
  promptHash         CHAR(64)        NULL,                            -- SHA-256 of the exact system text sent; NULL only on a BLOCKED run
  modelName          NVARCHAR(100)   NULL,                            -- model name the provider reported; NULL when no reply came back
  inputTokens        INT             NULL,                            -- from the response, summed over the run's model calls; NULL when no reply came back
  outputTokens       INT             NULL,                            -- same, output side
  latencyMs          INT             NULL,                            -- time in model calls, measured by the service; NULL when the model was never called
  outcome            VARCHAR(10)     NOT NULL,                        -- COMPLETED | BLOCKED | FAILED
  reasonCode         VARCHAR(40)     NULL,                            -- one of the agent's reason codes; NULL exactly when COMPLETED; no CHECK, so a new code needs no migration
  failureMode        VARCHAR(14)     NULL,                            -- FORMAT | ROUTING | AMBIGUITY | COMPREHENSION; only on a FAILED run with an extraction code
  createdUtc         DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(), -- when the row was written
  CONSTRAINT PK_agentRun PRIMARY KEY (runID),
  CONSTRAINT CK_agentRun_outcome CHECK (outcome IN ('COMPLETED', 'BLOCKED', 'FAILED')),
  CONSTRAINT CK_agentRun_reason CHECK ((outcome = 'COMPLETED' AND reasonCode IS NULL) OR (outcome <> 'COMPLETED' AND reasonCode IS NOT NULL)),  -- every run that did not complete says why
  CONSTRAINT CK_agentRun_reachedModel CHECK (outcome = 'BLOCKED' OR promptHash IS NOT NULL),                                                       -- only a blocked run may lack the prompt hash
  CONSTRAINT CK_agentRun_failureMode CHECK (failureMode IS NULL OR (outcome = 'FAILED' AND failureMode IN ('FORMAT', 'ROUTING', 'AMBIGUITY', 'COMPREHENSION')))
);
GRANT SELECT, INSERT ON AI.agentRun TO aiServiceRuntime;              -- only if roles are confirmed; never UPDATE or DELETE
```

- `src/repositories/agentRunWriter.ts` holds `INSERT_AGENT_RUN_SQL` above `class AgentRunWriter`, which has one method, `record(...)`. The method calls `database.execute` with `OUTPUT INSERTED.runID AS runID`, so the field rows can link to the run. The module exports the singleton `agentRunWriter`.
- The values come from what Epic 4 already puts in run state: promptId, promptTemplateHash, promptHash, modelName, inputTokens, outputTokens, latencyMs, outcome, reasonCode and failureMode. `encounterId` comes from the context. The call goes in the existing outcome hook (`src/agents/middleware/outcome.ts`, the only `afterAgent`), never in a second one.
- Outcome, reason-code and failure-mode values are imported from `src/agents/failure-modes.ts`, never retyped.
- Tests: `tests/unit/repositories/agentRunWriter.test.ts` stubs `database.execute` with `t.mock.method` and checks the bound values for a COMPLETED, a BLOCKED and a FAILED run. `tests/integration/repositories/agentRunWriter.test.ts` inserts live rows, checks each CHECK refusal, and checks that the server refuses an UPDATE.

**Before you build (due diligence)**

- Confirm the approved design. The merged chat design records each turn in `AI.EncounterTranscript` instead. That row is inserted when the request arrives and completed by one UPDATE, so it is not append-only, and it has no outcome or failure-mode column. Pick one design and do not build both.
- Decide what happens when this INSERT fails inside the outcome hook. A throw from `afterAgent` rejects `invoke`, so a database outage would also lose the extraction. Measure this on the installed `langchain` 1.5.14 before choosing between log-and-continue and fail (to verify).
- Today a failed model call records only its reason code and latency (`model-call.ts`), but Azure may still bill tokens for some failures. Check whether usage can be read from the thrown error.
- The model is gpt-4.1. It is deprecated for new customers and retires on 2027-04-14. Newer models are reasoning models, and their output tokens include reasoning tokens. Confirm that the token columns keep their meaning and that the model name the provider reports is what gets stored.
- Check the type of `encounterID` in `information_schema.columns` on DEV. Decide whether to add `templetID`, which the context already carries, so that results can be split per template. Decide BIGINT or INT: the driver returns BIGINT as a string.

---

### PEA-203

**Title:** Store the AI's proposal beside the clinician's decision in AI.fieldOutcome

**Description:**
As an AI/clinical admin, I want every field the AI proposed stored beside what the clinician finally kept, with the AI's own FOUND, ABSENT or ABSTAINED status kept apart from the clinician's, so that edit rate and recall are computed numbers and every reviewed encounter becomes a labelled example without hand-labelling.

`AI.fieldOutcome` is the only honest accuracy measurement this project has. It drives the review queue, and Epic 10's harness replays real rows from it as its labelled set. All of that depends on two things. The proposal and the decision sit in the same row. ABSENT and ABSTAINED never collapse into one "no value". The current system writes NA for both, and stopping that is why this table exists. Now that the client values recall over precision, these rows also show which values the note gave and the AI missed.

**Scope**

- in: the migration and its indexes, the proposal writer (one row per template field per run), and the decision writer (accepted columns only)
- out: the resolve endpoint that calls the decision writer (Epic 9), the validators that set `verdict` and `reasonCode` (Epic 6), the evaluation harness and recall reporting (Epic 10)

**Acceptance criteria**

- A field the note never mentions (its slot is `null`) is written as ABSENT with no value. A field the model abstained on is written as ABSTAINED with no value. Grouping the rows by `proposedStatus` returns them as two separate groups.
- A run writes one row per slot of its template, keyed by `templetID`, `sectionID` and `fieldID` parsed from the slot key. A field used in two sections gets two rows.
- `proposedConfidence` is the band the evidence check derived for that slot, never the model's own band.
- When the clinician accepts "187 lb" for a weight proposed as "187" with no unit, `acceptedValue`, `acceptedUnit` and `acceptedStatus` are set, along with who decided and when. Every proposed column is unchanged.
- The decision statement names only `acceptedValue`, `acceptedUnit`, `acceptedStatus`, `decidedByProviderId` and `decidedAtUtc`. If roles are confirmed, a column-level GRANT UPDATE names the same list, and the server refuses an UPDATE of `proposedValue` from the service principal.
- With 50,000 rows of which 40 are undecided, the review-queue query returns exactly the 40, and its plan is a seek on the filtered index.
- No log line, trace attribute or error message carries `proposedValue`, `acceptedValue` or `foundIn`. Logs name `outcomeID` or `runID` only.

**Technical notes**

- `migrations/sql/NNNN_create_field_outcome.sql`, after the agentRun script. A comment carries the volume and its source: about 30 rows per encounter × about 1,000 AI encounters a day ≈ 10.95M rows a year.

```sql
CREATE TABLE AI.fieldOutcome (                                        -- one row per template field per run: the AI's proposal beside the clinician's decision
  outcomeID           BIGINT IDENTITY NOT NULL,                       -- row id
  runID               BIGINT          NOT NULL,                       -- the AI.agentRun row this proposal came from
  encounterID         INT             NOT NULL,                       -- Encounter.encounter.encounterID; logical reference, no foreign key
  templetID           INT             NOT NULL,                       -- the template, in the live spelling
  sectionID           INT             NOT NULL,                       -- parsed from the slot key s<sectionID>_f<fieldID>
  fieldID             INT             NOT NULL,                       -- parsed from the slot key
  proposedValue       NVARCHAR(400)   NULL,                           -- the slot's value; NULL unless FOUND (width to measure, see due diligence)
  proposedUnit        NVARCHAR(50)    NULL,                           -- the slot's unit; NULL when the note stated none
  proposedStatus      VARCHAR(10)     NOT NULL,                       -- FOUND | ABSENT (the slot was null) | ABSTAINED; never collapsed
  proposedConfidence  VARCHAR(6)      NOT NULL,                       -- HIGH | MEDIUM | LOW as the evidence check derived it; never a number
  foundIn             NVARCHAR(1000)  NULL,                           -- the slot's verbatim quote from the note; NULL when ABSENT
  verdict             VARCHAR(10)     NOT NULL,                       -- ACCEPT | REVIEW | BLOCK for this field (Epic 6)
  reasonCode          NVARCHAR(50)    NULL,                           -- why REVIEW or BLOCK; Epic 6 names the codes
  acceptedValue       NVARCHAR(400)   NULL,                           -- the value the clinician kept; NULL until decided
  acceptedUnit        NVARCHAR(50)    NULL,                           -- the unit the clinician kept
  acceptedStatus      VARCHAR(10)     NULL,                           -- FOUND | ABSENT | ABSTAINED as decided
  decidedByProviderId INT             NULL,                           -- who decided (identity to confirm, see due diligence)
  decidedAtUtc        DATETIME2       NULL,                           -- when; NULL = still in the review queue
  createdUtc          DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(), -- when the proposal was written
  CONSTRAINT PK_fieldOutcome PRIMARY KEY (outcomeID),
  CONSTRAINT FK_fieldOutcome_agentRun FOREIGN KEY (runID) REFERENCES AI.agentRun (runID),  -- inside the AI schema, so allowed
  CONSTRAINT CK_fieldOutcome_proposedStatus CHECK (proposedStatus IN ('FOUND', 'ABSENT', 'ABSTAINED')),
  CONSTRAINT CK_fieldOutcome_proposedConfidence CHECK (proposedConfidence IN ('HIGH', 'MEDIUM', 'LOW')),
  CONSTRAINT CK_fieldOutcome_verdict CHECK (verdict IN ('ACCEPT', 'REVIEW', 'BLOCK')),
  CONSTRAINT CK_fieldOutcome_acceptedStatus CHECK (acceptedStatus IN ('FOUND', 'ABSENT', 'ABSTAINED'))
);
CREATE INDEX IX_fieldOutcome_run ON AI.fieldOutcome (runID);
CREATE INDEX IX_fieldOutcome_pending ON AI.fieldOutcome (encounterID, createdUtc) WHERE decidedAtUtc IS NULL;  -- the review queue: tens of rows, not the whole table
CREATE INDEX IX_fieldOutcome_field_history ON AI.fieldOutcome (templetID, sectionID, fieldID, createdUtc);    -- Epic 10's recent examples per field
GRANT SELECT, INSERT ON AI.fieldOutcome TO aiServiceRuntime;                                                    -- only if roles are confirmed
GRANT UPDATE (acceptedValue, acceptedUnit, acceptedStatus, decidedByProviderId, decidedAtUtc) ON AI.fieldOutcome TO aiServiceRuntime;
```

- `src/repositories/fieldOutcomeRepository.ts` holds two statements, each above its own class with one method. `INSERT_FIELD_OUTCOME_SQL` sits above `FieldOutcomeProposalWriter.record(...)`, and `UPDATE_FIELD_OUTCOME_DECISION_SQL` above `FieldOutcomeDecisionWriter.record(...)`. The exported singletons are `fieldOutcomeProposalWriter` and `fieldOutcomeDecisionWriter`.
- The proposal writer runs in the outcome hook, after `agentRunWriter.record`. It reads the parsed output (`structuredResponse`) and `state.evidence`. One exported function parses the slot key back, kept beside the code that builds it.
- `verdict` and `reasonCode` take Epic 6's values. This ticket owns the columns only.
- Tests: `tests/unit/repositories/fieldOutcomeRepository.test.ts` covers ABSENT and ABSTAINED rows from a null slot and an abstained slot, and checks that the decision statement's column list has no proposed column. `tests/integration/repositories/fieldOutcomeRepository.test.ts` checks the filtered-index seek (actual plan or `sys.dm_db_index_usage_stats`) and the refused proposed-column update.

**Before you build (due diligence)**

- Confirm the approved design. The merged chat design's `AI.EncounterFieldReview` writes a row only when the clinician decides, and it has no status column. ABSENT and ABSTAINED both appear there as an empty AI value, and the status survives only inside the turn's stored JSON. That is the collapse this ticket forbids, so decide where the status lives before building either table.
- Recall is now the client's priority. These rows, with the AI's value beside the clinician's, are the only live recall ground truth: a value the clinician added that also appears in the note is a missed extraction. Confirm who writes the clinician's value: this service through a resolve call, or the .NET API on form save. Confirm that values typed straight into the chart, and fields committed without review, still reach `acceptedValue`. Otherwise recall is under-counted.
- Measure value sizes first. In the 2026-10-14 evaluation run on template 457, the longest value was 1,003 characters and the longest quote was 790. A value over 400 characters makes the INSERT fail. Any NVARCHAR(MAX) column needs approval.
- Spike the bulk write. Template 457 has 99 slots, so one INSERT per slot means 99 round trips. Compare one `INSERT … SELECT FROM OPENJSON(@rows)` (needs compatibility level 130 or higher) with a table-valued parameter. The installed mssql binds every JS string as NVARCHAR unless a type is given, and returns BIGINT ids as strings.
- Decide who `decidedByProviderId` is. The context carries the PacEHR `userId` and the Entra `clinicianOid`, and nothing yet says which one identifies the clinician. Check the four key columns' types in `information_schema.columns`.

---

### PEA-204

**Title:** Purge AI.fieldOutcome rows past the configured retention window

**Description:**
As a compliance officer, I want `AI.fieldOutcome` rows older than a configured retention window deleted, and I want the purge to refuse to run when no window is set, so that a table holding clinical values does not grow forever and never mass-deletes on a guessed default.

`AI.fieldOutcome` is the only table in this epic that grows fast: about 10.95M rows a year at the stated volume (PEA-203). It also holds clinical values. Nobody has decided the retention period yet, and inventing one here would be a guess. What can be built now is the mechanism: a setting that, while unset, makes the purge delete nothing. Whatever window compliance sets must also be longer than Epic 10's evaluation replays need. Epic 10 states that minimum.

**Scope**

- in: one setting, the purge statement and its class, and the fail-closed refusal
- out: the schedule that runs the purge (Epic 11), the retention period itself (compliance), and Epic 10's minimum window

**Acceptance criteria**

- With `AI_FIELD_OUTCOME_RETENTION_DAYS` set to a positive integer, the purge deletes the rows whose `createdUtc` is older than that many days. Rows inside the window are untouched.
- With the setting unset, the purge deletes nothing. It logs one refusal that names the setting and no row content.
- A value that is not a positive integer, such as `0`, `-5` or `30d`, makes `settings()` fail with an error that names the variable.
- The purge returns the number of rows deleted. It runs on its own, with no scheduler, so Epic 11 can attach any trigger.
- The delete is a hard DELETE, not a soft-delete flag.
- A test shows the refusal log line contains no value column.

**Technical notes**

- Add one optional entry to the zod schema in `src/core/settings.ts`: `AI_FIELD_OUTCOME_RETENTION_DAYS`, a positive integer with no default, read as `settings().aiFieldOutcomeRetentionDays`. Add it to `.env.example`.
- `src/repositories/fieldOutcomeRetention.ts` holds `DELETE_FIELD_OUTCOME_BEFORE_SQL` above `class FieldOutcomeRetentionPurger`, which has one method, `purge()`. The module exports `fieldOutcomeRetentionPurger`. The day count is bound as `@retentionDays`, and the cutoff is computed in SQL from `SYSUTCDATETIME()`.
- The refusal is a `warn` line, fields first: `log.warn({ setting: 'AI_FIELD_OUTCOME_RETENTION_DAYS' }, 'retention purge refused')`.
- A comment beside the statement carries the 10.95M-rows-a-year figure and its source.
- Tests: `tests/unit/repositories/fieldOutcomeRetention.test.ts` stubs `database.execute` and runs once with `useTestEnv` setting the value and once without it, as two files because each file has one environment. The settings test gains the new entry.

**Before you build (due diligence)**

- Confirm what retention means here. This ticket deletes every row past the window. The owner's 2026-10-06 decision purges decided rows only, which keeps undecided rows forever. The chat design blanks the clinical text and keeps the rows. Compliance has set a period for none of them.
- A single DELETE of millions of rows holds locks and grows the log on a live database. Measure a batched delete (`DELETE TOP (n)` in a loop) on a DEV copy, and choose `n` from that measurement.
- Ask Epic 10 for the minimum window its replays need before compliance chooses a number.
- Check the delete's plan. The filtered review-queue index does not cover decided rows, so a scan on `createdUtc` may need its own index.

---

### PEA-205

**Title:** Store versioned prompt fragments in AI.promptFragment, admin-write only

**Description:**
As an AI/clinical admin, I want every prompt fragment stored as an addressable, versioned row that only Prompt Studio can write, so that a bad prompt edit can be rolled back, two versions can be compared, and the agent can never write its own instructions.

`AI.promptFragment` replaces the free-text prompt blob with versioned, composable fragments. This ticket is the storage contract only: the table, its keys, and the rule that the agent reads it and never writes it. Composition order, account-versus-global precedence, activation gating, rollback and A/B comparison all belong to Epic 8.

**Scope**

- in: the migration, a read-only reader, and the write boundary
- out: composition and gating (Epic 8), the evaluation verdict written by Epic 10's gate, and Prompt Studio's write module (Epic 8)

**Acceptance criteria**

- A new "task" fragment saved for account 42 is stored with kind `task`, scope `account`, accountId 42, version 1, isActive 0 and passedEvaluation `PENDING_EVAL`.
- Version 4 of kind `contract`, scope `global` can be saved beside version 3. Both rows remain, and the unique key on (kind, scope, accountId, version) accepts both.
- A second row with the same kind, scope, accountId and version is refused.
- `accountId` is set only when scope is `account`. The table refuses a global fragment with an account, and an account fragment without one.
- `kind`, `scope` and `passedEvaluation` refuse any value outside their lists.
- The service principal holds only SELECT on the table, and Prompt Studio's principal holds INSERT and UPDATE.
- The reader returns the active fragments for an account. No module the agent imports can write this table (checked in review).

**Technical notes**

- `migrations/sql/NNNN_create_prompt_fragment.sql`:

```sql
CREATE TABLE AI.promptFragment (                                      -- one version of one prompt fragment; rows are never deleted
  fragmentID       INT IDENTITY  NOT NULL,                            -- row id
  kind             VARCHAR(20)   NOT NULL,                            -- contract | task | specialty | template_override (Epic 8's vocabulary)
  scope            VARCHAR(10)   NOT NULL,                            -- global | account
  accountId        INT           NULL,                                -- the account, existing spelling; set only when scope = account
  version          INT           NOT NULL,                            -- 1, 2, … within (kind, scope, accountId)
  fragmentText     NVARCHAR(MAX) NOT NULL,                            -- the fragment's text; NVARCHAR(MAX) needs approval
  isActive         BIT           NOT NULL DEFAULT 0,                  -- 1 = in use; set by Epic 8's gate
  passedEvaluation VARCHAR(12)   NOT NULL DEFAULT 'PENDING_EVAL',     -- PENDING_EVAL | PASSED | BLOCKED | INCOMPLETE, written by Epic 10's gate
  createdUtc       DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),   -- when the version was saved
  updatedUtc       DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),   -- when isActive or passedEvaluation last changed
  CONSTRAINT PK_promptFragment PRIMARY KEY (fragmentID),
  CONSTRAINT UQ_promptFragment_version UNIQUE (kind, scope, accountId, version),                 -- every version stays addressable for rollback
  CONSTRAINT CK_promptFragment_kind CHECK (kind IN ('contract', 'task', 'specialty', 'template_override')),
  CONSTRAINT CK_promptFragment_scope CHECK (scope IN ('global', 'account')),
  CONSTRAINT CK_promptFragment_scopeAccount CHECK ((scope = 'global' AND accountId IS NULL) OR (scope = 'account' AND accountId IS NOT NULL)),
  CONSTRAINT CK_promptFragment_passedEvaluation CHECK (passedEvaluation IN ('PENDING_EVAL', 'PASSED', 'BLOCKED', 'INCOMPLETE'))
);
GRANT SELECT ON AI.promptFragment TO aiServiceRuntime;
GRANT INSERT, UPDATE ON AI.promptFragment TO aiPromptAdmin;          -- only if roles are confirmed
```

- `src/repositories/promptFragmentReader.ts` holds `SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL` above `class PromptFragmentReader`, which has one method, `activeFragments(accountId)`. The module exports `promptFragmentReader`. Epic 8 owns its own write module.
- `passedEvaluation` holds a verdict, not a yes/no, because a version nobody has evaluated and one that failed need different action. Epic 8 resolves PASSED only, so every other value fails closed.
- No PHI: fragment text is authored prompt content.
- Tests: `tests/unit/repositories/promptFragmentReader.test.ts`, and `tests/integration/repositories/promptFragmentReader.test.ts` for the unique key, the scope check and the grants.

**Before you build (due diligence)**

- Confirm this table is still wanted. The owner withdrew it on 2026-10-06. The agent now reads the existing prompt table through `dbo.usp_getPrompt`, fills its placeholders, and records `promptId` plus a hash of the row, because that row is edited in place. Building this ticket needs Epic 8 back in scope.
- A `template_override` fragment cannot name its template with these columns. An earlier draft added `templetID` and used 0 for "applies everywhere". Decide before the first script, because the runner refuses ALTER TABLE.
- The runner refuses ALTER TABLE in every schema. So a fifth `kind` cannot be added later by changing the CHECK in a forward script. Decide how a vocabulary change ships.
- Get approval for NVARCHAR(MAX) on `fragmentText`, or measure the longest fragment and choose a bounded width.

---

### PEA-206

**Title:** Store per-mapping field guards in AI.fieldConstraint, admin-write only

**Description:**
As a clinical template administrator, I want the unit, plausible-range and abnormal-range guard I write for a field in one section of a template to apply only to that mapping, so that the same field reused in another section never inherits a bound I wrote for somewhere else.

`AI.fieldConstraint` is keyed on (templetID, sectionID, fieldID), the same grain as the per-mapping description (PEA-207), not on fieldID alone. Epic 3 (PEA-301) argues for that grain: one edit to a global field name was measured reaching 179 of 458 templates. Most bounds will be the same in every section, so duplicate rows cost a little storage. A coarser grain cannot express a difference at all, and fixing it later needs a migration. The agent never writes here. Bounds are compiled from the author's prose in the template editor and confirmed on save.

**Scope**

- in: the migration, a read-only reader, and the write boundary
- out: the prose-to-bounds compiler and the template editor, and the validators that read the bounds (Epic 6)

**Acceptance criteria**

- fieldID 412 ("Blood Pressure") mapped into section 11 and section 12 of templet 3 gets two rows. Updating the section 12 row leaves the section 11 row unchanged.
- A second row for the same (templetID, sectionID, fieldID) is refused.
- `unit` reads back exactly as configured, for example `kg|lb`, and no bound is converted or normalised.
- `fieldConstraintReader.forMapping(templetID, sectionID, fieldID)` returns that mapping's row, or `null` when there is none.
- The service principal holds only SELECT on the table, and the template editor's principal holds INSERT and UPDATE.
- The columns are spelled `templetID`, `sectionID` and `fieldID`, exactly as the live database spells them.

**Technical notes**

- `migrations/sql/NNNN_create_field_constraint.sql`. There is one current row per mapping, updated in place on save, not a version history.

```sql
CREATE TABLE AI.fieldConstraint (                                     -- one current guard per template-section-field mapping
  constraintID INT IDENTITY  NOT NULL,                                -- row id
  templetID    INT           NOT NULL,                                -- the template, live spelling
  sectionID    INT           NOT NULL,                                -- the section, live spelling
  fieldID      INT           NOT NULL,                                -- the field, live spelling
  unit         NVARCHAR(20)  NULL,                                    -- unit as authored, e.g. kg|lb; never converted here
  plausibleMin FLOAT         NULL,                                    -- below this the value is blocked
  plausibleMax FLOAT         NULL,                                    -- above this the value is blocked
  abnormalMin  FLOAT         NULL,                                    -- below this the value is flagged and kept
  abnormalMax  FLOAT         NULL,                                    -- above this the value is flagged and kept
  sourceProse  NVARCHAR(MAX) NULL,                                    -- the author's prose this row was compiled from; NVARCHAR(MAX) needs approval
  isActive     BIT           NOT NULL DEFAULT 1,                      -- 0 = switched off by the author
  createdUtc   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),       -- when first saved
  updatedUtc   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),       -- when last saved
  CONSTRAINT PK_fieldConstraint PRIMARY KEY (constraintID),
  CONSTRAINT UQ_fieldConstraint_mapping UNIQUE (templetID, sectionID, fieldID)
);
GRANT SELECT ON AI.fieldConstraint TO aiServiceRuntime;
GRANT INSERT, UPDATE ON AI.fieldConstraint TO aiTemplateAdmin;       -- only if roles are confirmed
```

- `src/repositories/fieldConstraintReader.ts` holds `SELECT_FIELD_CONSTRAINT_SQL` above `class FieldConstraintReader`, which has one method, `forMapping(templetID, sectionID, fieldID)`. The module exports `fieldConstraintReader`. Epic 6's validators call it.
- The driver reads FLOAT back as a JS number, and binds a JS number with a fraction as FLOAT.
- Growth is flat: one row per active mapping, not per encounter. No retention concern and no PHI.
- Tests: `tests/unit/repositories/fieldConstraintReader.test.ts` uses fieldID 412 in two sections as fixture data. `tests/integration/repositories/fieldConstraintReader.test.ts` checks the unique key, the `kg|lb` round trip and the grants.

**Before you build (due diligence)**

- Confirm when to build it. The 2026-10-06 handover kept this table, and the chat design defers it to Epic 6. Build it together with Epic 6's validators, not before.
- The guard Epic 6 compiles carries more than these columns: a risk class, components, roles, and a date field's direction and horizon. Agree the column list with Epic 6 first, because adding a column later needs ALTER TABLE, which the runner refuses.
- Decide FLOAT or DECIMAL. A comparison at a boundary on binary floating point is unreliable. An earlier draft used DECIMAL(6,2), which needs approval and limits values to under 10,000. Decide whether the comparison happens in SQL or in TypeScript.
- Epic 6 checks every slot of a template on each request, 99 on template 457. One query per slot is 99 round trips, so check with Epic 6 whether a per-template read is needed.

---

### PEA-207

**Title:** Store per-mapping field descriptions in AI.fieldDescription, admin-write only

**Description:**
As a clinical template administrator, I want the description I write for a field in one section of a template saved against that exact mapping, so that the same field reused in another section of the template never inherits words I wrote for somewhere else.

The field description the model sees must be stored per (templetID, sectionID, fieldID), never per fieldID. The same field recurs across sections with a different meaning, and the description is the sentence that tells the model which slot is which. It cannot be a new column on an existing template table, because this service may only read those tables. So it is a sidecar table in the `AI` schema. It stores one fact per mapping, the description. Name, type and unit stay on the template tables, and Epic 3 joins them in at request time. This is the fifth table, one more than the four the requirements list, for exactly this reason.

**Scope**

- in: the migration, a read-only reader for one template, and the write boundary
- out: the schema builder that reads it (Epic 3), and the template editor that writes it

**Acceptance criteria**

- fieldID 412 in sections 11 and 12 of templet 3 keeps two descriptions. Editing the section 12 description changes only the (3, 12, 412) row.
- A description saved for (3, 11, 425) is used by the very next extraction request for templet 3, with no deployment and no restart.
- `fieldDescriptionReader.forTemplet(3)` returns every mapping's description for that template in one query.
- The table has no name, type or unit column.
- The primary key is (templetID, sectionID, fieldID), with no surrogate id.
- The service principal holds only SELECT on the table, and the template editor's principal holds INSERT and UPDATE.

**Technical notes**

- `migrations/sql/NNNN_create_field_description.sql`:

```sql
CREATE TABLE AI.fieldDescription (                                    -- the AI-facing description of one template-section-field mapping
  templetID   INT            NOT NULL,                                -- the template, live spelling
  sectionID   INT            NOT NULL,                                -- the section, live spelling
  fieldID     INT            NOT NULL,                                -- the field, live spelling
  description NVARCHAR(1000) NOT NULL,                                -- one line telling the model what this slot holds
  createdUtc  DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),       -- when first saved
  updatedUtc  DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),       -- when last edited
  CONSTRAINT PK_fieldDescription PRIMARY KEY (templetID, sectionID, fieldID)  -- the mapping is the identity; leads with templetID, the one access pattern
);
GRANT SELECT ON AI.fieldDescription TO aiServiceRuntime;
GRANT INSERT, UPDATE ON AI.fieldDescription TO aiTemplateAdmin;      -- only if roles are confirmed
```

- `src/repositories/fieldDescriptionReader.ts` holds `SELECT_FIELD_DESCRIPTION_SQL` above `class FieldDescriptionReader`, which has one method, `forTemplet(templetID)`. The module exports `fieldDescriptionReader`.
- The reader keeps nothing between requests: no lazy member and no memo. Caching the rows would break "takes effect on the next request".
- The caller is Epic 3's `templateService.getAIConfig(templetID)`. Today it builds each slot's description from the field's name and its own prompt.
- No PHI, and growth is bounded by the number of mappings.
- Tests: `tests/unit/repositories/fieldDescriptionReader.test.ts` uses fieldID 412 in two sections as fixture data. An integration test checks the composite key and the grants.

**Before you build (due diligence)**

- Confirm this table is still wanted. The owner withdrew it on 2026-10-06. Field and section instructions now come from the template tables' own prompt columns, and the Epic 3 code builds each slot's description from the field name and its prompt. Those prompts are per field, not per mapping, so the cross-section problem this ticket solves is still open. Decide with Epic 3 (PEA-301).
- If it stays, decide whether it is read through Epic 3's planned AI template-config procedure or through its own query, so that loading a template stays one round trip.
- Check the triple's column types in `information_schema.columns` on DEV.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-201 | Partly done | 5 | Epic 1 (`database`, PEA-103) | `migrations/sql/` with the naming rule and six scripts (`0001`–`0006`, rev 7 tables), `migrations/verification/post-apply-checks.sql`, `src/core/databaseMigrations.ts`, `src/migrate.ts`, `npm run migrate` / `migrate:prod`, `database.run()` in `src/core/database.ts`. Tests: `tests/unit/core/databaseMigrations.test.ts` (15) and `database.run.test.ts` (1), `tests/integration/core/databaseMigrations.test.ts` (3 subtests). Merged in PR 12745 (AITP-68, Hem; commits `157e055`, `1be022c`; merge `058308d`, 2026-10-13). | `MigrationRunner.apply_pending()` became `migrationRunner.applyPending()`. `aexecute` became `database.run`. `python -m` with `asyncio.run` became `src/migrate.ts` with exit codes. The scope check runs inside the runner as well as in the unit test, and it also bans TRUNCATE and ALTER TABLE in every schema. Not built: `0001_create_ai_schema.sql` and the three roles, because the merged set assumes `AI` exists and the owner ruled out roles. Script numbers `0001`–`0006` belong to the rev 7 tables, not to this epic's tables. | DEV apply not verified, and there is no apply evidence in `PacEHR_AI/logs/`. Run `post-apply-checks.sql`. The runner refuses `GRANT … INSERT/UPDATE ON AI.x` (probe run 2026-10-14). The PR text says "tracked so each script runs once", but the code has no history table and re-runs every script. The lint rule in `eslint.config.js` covers `execute` and `query`, not `run`. The integration test skips silently. The unmerged branch `feature/AITP-136-EncounterSummary` (`a4796bb`) adds a `0007` procedures script. |
| PEA-202 | Not started | 3 | PEA-201; Epic 4 state and codes (PEA-405, PEA-407) | Nothing for `AI.agentRun`. The nearest thing built is rev 7's `AI.EncounterTranscript` (merged `0004`, no writer). `src/agents/middleware/outcome.ts` only tags state. `src/` has no INSERT, UPDATE, MERGE or DELETE outside the runner's own rules (grep, 2026-10-14). | The outcome vocabulary is now `OUTCOMES` (COMPLETED, BLOCKED, FAILED), not committed / awaiting_review / guard_blocked / error. Added `reasonCode`, `failureMode`, `promptId` and `promptTemplateHash`, from Epic 4 state. `modelDeployment` became `modelName` (provider-reported). `promptHash` is nullable for BLOCKED runs. The "exactly one SQL constant" test became a review item, because tests assert behaviour, not shape (repo `CLAUDE.md`). The module moved from `core/agent_run_repository.py` to `src/repositories/agentRunWriter.ts`. | Choose between this table and `AI.EncounterTranscript` (insert, then one UPDATE; not append-only). Decide behaviour when the INSERT fails inside `afterAgent`. Failed model calls record no tokens (`model-call.ts:67-73`). `templetID` is missing for per-template slicing (`docs/tickets/SOP-COVERAGE.md` 2.2). BIGINT comes back as a string (`tedious/lib/value-parser.js` `readBigInt`). |
| PEA-203 | Not started | 5 | PEA-201, PEA-202; Epic 6 (verdict); Epic 9 (resolve) | Nothing for `AI.fieldOutcome`. The nearest thing built is rev 7's `AI.EncounterFieldReview` (merged `0005`, no writer). | Verdict values are upper case (ACCEPT, REVIEW, BLOCK). Confidence is the band `src/agents/middleware/evidence.ts` derives (Epic 6 PEA-607/608), never the model's own. ABSENT is a `null` slot, because the contract's status is FOUND or ABSTAINED only (`src/schema/contract.ts`). Keys are parsed from `s<sectionID>_f<fieldID>`. The module is `src/repositories/fieldOutcomeRepository.ts`. | Value widths: the 2026-10-14 eval run (`PacEHR_AI/logs/eval/20261014-192807`, 15 runs) had a 1,003-character value and a 790-character quote, against NVARCHAR(400) and NVARCHAR(1000). Recall ground truth (see Notes). Who writes decisions (rev 5 O3). `decidedBy` identity (`docs/tickets/GAPS.md` #6). No slot-key parser exists (`docs/2026-10-09-pacehr-ai-gaps-and-improvements.md` B6). Spike the bulk insert. |
| PEA-204 | Not started | 2 | PEA-203 | Nothing. `src/core/settings.ts` has no retention setting. Hem's `src/jobs/fieldOutcomeRetention.ts` was never pushed. | The pydantic `Settings` field became one zod entry, `AI_FIELD_OUTCOME_RETENTION_DAYS`. `purge()` returns a count and logs a refusal instead of raising. The module is `src/repositories/fieldOutcomeRetention.ts`. | What to delete: all rows past the window (this ticket), decided rows only (handover §B8 D4), or redaction (rev 5 §13). The period is undecided (rev 5 O8; Python B7). Batch size not measured. |
| PEA-205 | Not started | 3 | PEA-201; Epic 8 | Nothing. The runtime reads `AI.prompt` through `dbo.usp_getPrompt` (`src/agents/middleware/guard.ts`, `GET_PROMPT_SQL`). | The module is `src/repositories/promptFragmentReader.ts`. A CHECK ties `accountId` to `scope`, where the Python ticket had only a test. | Withdrawn by the owner on 2026-10-06 (handover §A3). `templetID` for `template_override` (`docs/sql/0006_create_prompt_fragment.sql`, decision D11). The runner refuses ALTER TABLE, so the vocabulary cannot change as written. NVARCHAR(MAX) needs approval. |
| PEA-206 | Not started | 3 | PEA-201; Epic 3 PEA-301; Epic 6 | Nothing. | `for_mapping(templet_id, …)` became `fieldConstraintReader.forMapping(templetID, sectionID, fieldID)`. The module is `src/repositories/fieldConstraintReader.ts`. | Kept by the handover (§A3) but deferred to Epic 6 by rev 5 (§15). Missing guard columns (`docs/tickets/GAPS.md` #7). FLOAT vs DECIMAL(6,2) (`docs/sql/0004_create_field_constraint.sql`). `sourceProse` NVARCHAR(MAX) needs approval. |
| PEA-207 | Not started | 3 | PEA-201; Epic 3 PEA-301 | Nothing. Epic 3 builds slot descriptions from `usp_getTemplateMapping` rows (`src/repositories/templateRepository.ts`, `src/services/templateService.ts`). | "Not a `cached_property` singleton" became "no lazy member, no memo". The module is `src/repositories/fieldDescriptionReader.ts`. | Withdrawn by the owner on 2026-10-06 (handover §A3), but the per-mapping grain problem is still open. A possible home is `usp_getAITemplateConfig` (PEA-301; `ponytail:` comment in `templateRepository.ts`). |

Total: 24 points (PEA-201 5, PEA-202 3, PEA-203 5, PEA-204 2, PEA-205 3, PEA-206 3, PEA-207 3), the same as the Python epic. 5 points partly done, 19 not started.

### Notes

**State of the code, checked 2026-10-14** (`PacEHR_AI` HEAD `89099ab` on `3p-dev/epic-4-agent-core`; it contains `PacEHR-AI-Develop-Main` at `058308d`; the working tree is clean)

- The brief said there is no migrations folder. That is out of date. PR 12745 (AITP-68, merged 2026-10-13) added `migrations/sql/0001`–`0006`, the runner, `src/migrate.ts` and `database.run()`. Its tables follow "AI Encounter Schema Design rev 7": `AI.EncounterSummary`, `AI.PatientSummary`, `AI.ClinicianSummary`, `AI.EncounterTranscript`, `AI.EncounterFieldReview` and the view `AI.EncounterUsage`. The rev 7 document is not under `docs/`; only rev 5 is.
- SQL in `src/` is read-only: `usp_getTemplateMapping` and `Template.encounterTempletes` (`src/repositories/templateRepository.ts`), `dbo.usp_getPrompt` (`src/agents/middleware/guard.ts`), and the readiness `SCHEMA_EXISTS_SQL` (`src/core/database.ts`). Nothing writes any table. The first write path, `AI.usp_upsertEncounterSummary` with `src/repositories/summaryRepository.ts`, exists only on the unmerged branch `feature/AITP-136-EncounterSummary` (`a4796bb`, 2026-10-14).
- Whether the merged set is applied to DEV is not verified. No apply log was found.
- Tests run 2026-10-14: `node --import tsx/esm --import ./tests/unit/no-network.ts --test tests/unit/core/databaseMigrations.test.ts tests/unit/core/database.run.test.ts` gave 16 tests, 16 passed. The integration test was not run.
- Runner probe, 2026-10-14: `validate()` rejects `GRANT SELECT, INSERT ON AI.agentRun TO aiServiceRuntime` and `GRANT INSERT, UPDATE ON AI.promptFragment TO aiPromptAdmin` with "writes on with no schema". It accepts `GRANT SELECT ON …` and `GRANT UPDATE (col) ON …`. The cause is the `WRITE` pattern in `src/core/databaseMigrations.ts`, whose lookbehind skips only `ON UPDATE` / `ON DELETE`.
- Driver facts used above, read in `node_modules`: `mssql/lib/shared.js` `getTypeByValue` binds a JS string as NVarChar and a JS number with a fraction as Float. `tedious/lib/value-parser.js` `readBigInt` returns BIGINT as a string.

**Four designs. The team must pick one before any new script**

| Design | Where | Objects | State |
|---|---|---|---|
| This epic (Python tickets) | `docs/tickets/epic-02-data-layer.md`; DDL drafts `docs/sql/0001`–`0006` (2026-10-06) | `AI` schema, 3 roles, `agentRun`, `fieldOutcome`, `promptFragment`, `fieldConstraint`, `fieldDescription` | Drafts only. The drafts already drop roles and use outcomes COMMITTED / AWAITING_REVIEW / BLOCKED |
| Hem's handover | `docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` (2026-10-06) | `extractionSession`, `transcript`, `agentRun`, `fieldOutcome`, `fieldEvidence`, `fieldState`, `fieldConstraint` | "Not applied, not pushed". Its branch `3p-dev/PEA-201-ai-schema-data-layer` is not among the remote refs, and `origin/3p-dev/epic-02-data-schema` sits at `ee9c990` with no Epic 2 work. It withdrew `promptFragment` and `fieldDescription` and has no roles |
| Chat design rev 5 | `docs/superpowers/specs/2026-10-07-ai-encounter-schema-design.md` | `encounterTranscript`, `encounterFieldReview`, `behaviorSummary`, view `encounterUsage`, 5 procedures | "Draft for review", open items O1–O21. §15 drops `fieldConstraint` (to Epic 6), `extractionSession` and `fieldState` |
| Rev 7 (merged) | `PacEHR_AI/migrations/sql/0001`–`0006` (PR 12745) | `EncounterSummary`, `PatientSummary`, `ClinicianSummary`, `EncounterTranscript`, `EncounterFieldReview`, view `EncounterUsage` | Merged. No procedures and no writers. DEV apply not verified |

**What changed from the Python edition, epic-wide**

| Python edition | TypeScript edition |
|---|---|
| `core/database_migrations.py`, `MigrationRunner.apply_pending()` | `src/core/databaseMigrations.ts`, `migrationRunner.applyPending()` (built) |
| `python -m core.database_migrations`, `asyncio.run(...)` | `src/migrate.ts`, `npm run migrate` / `npm run migrate:prod`, exit code 0 or 1 |
| `database.aexecute` | `database.execute` (returns rows) and `database.run` (no rows) |
| `core/*_repository.py` with `_SQL` constants | `src/repositories/*.ts` with `*_SQL` constants above the class and an exported singleton |
| `ai_field_outcome_retention_days` on pydantic `Settings` | one zod entry, `AI_FIELD_OUTCOME_RETENTION_DAYS`, in `src/core/settings.ts` |
| pytest, a `re` scope check | `node:test`, regular expressions in `validate()`, which the runner also enforces |
| `after_agent`, `before_agent` with `jump_to: "end"` | `afterAgent` in `outcome.ts`, `beforeAgent` with `jumpTo: 'end'` |
| Tests that count SQL constants | Review items (repo `CLAUDE.md`: tests assert behaviour, not shape) |
| Outcomes committed / awaiting_review / guard_blocked / error | COMPLETED / BLOCKED / FAILED, plus `reasonCode` and `failureMode` from `failure-modes.ts` |
| Verdict accept / review / block | ACCEPT / REVIEW / BLOCK |

**Reason codes checked against `PacEHR_AI/src/agents/failure-modes.ts`** (14 codes: 8 GUARD, 3 MODEL_CALL, 3 EXTRACTION; outcomes COMPLETED / BLOCKED / FAILED; modes FORMAT / ROUTING / AMBIGUITY / COMPREHENSION)

- Python PEA-202's CHECK (committed, awaiting_review, guard_blocked, error) matches none of the outcomes. `error` has no producer (`docs/tickets/GAPS.md` #9).
- `docs/sql/0002_create_agent_run.sql` allows COMMITTED, AWAITING_REVIEW and BLOCKED. It has no FAILED, so a failed model call cannot be recorded.
- Hem's handover §B4 S10 still lists PROMPT_SLOT_UNFILLED, which Epic 4 removed, and §B4 S11 leaves out OUTPUT_TRUNCATED.
- Rev 5 open item O10 asked for OUTPUT_TRUNCATED. It is now in `failure-modes.ts`.
- The merged `0004_create_encounter_transcript.sql` gives example codes that all exist. Its `VARCHAR(40)` fits the longest code, PROMPT_PLACEHOLDER_UNFILLED (27 characters). It has no outcome or failure-mode column, so the failure mode is lost for transcript rows.

**Decisions the team must resolve**

1. **Which design to build** (table above). This epic's tickets keep the Python agenda. Rev 7 is the only design in code. Its transcript row is not append-only (PEA-202), and its review row cannot tell ABSENT from ABSTAINED without parsing the turn's JSON (PEA-203).
2. **Roles and GRANTs.** The owner ruled them out on 2026-10-05 (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md` §A3; `docs/sql/0001_create_ai_schema.sql` header). The Python tickets rest on them. If they return, the runner's `WRITE` rule must allow `GRANT` lists first.
3. **PEA-205 and PEA-207** were withdrawn on 2026-10-06 (handover §A3). Keep them as tickets, re-point them, or close them. The per-mapping description problem (179 of 458 templates) is still unsolved.
4. **Recall ground truth.** The client now values recall over precision (2026-10-12 feedback). Field-review rows, with the AI's value beside the clinician's, are the only live recall signal. An ADDED value found in the note is S5, the "only live recall ground truth" (`docs/2026-10-13-recall-observability-brainstorm.md` §2.3 and §3). Three things decide whether it can be measured:
   - who writes the clinician's value (rev 5 O3);
   - whether values typed straight into the chart, and auto-committed fields, produce a row (`docs/tickets/GAPS.md` #25; brainstorm S5 "under-counts until the UI behaviour is confirmed");
   - whether a row exists for every field, which PEA-203 provides, or only for decided fields, as in rev 7.
5. **Type approvals.** The merged rev 7 set already uses NVARCHAR(MAX) ×4 (`clinicianQuery`, `aiResponse`, `aiValue`, `finalValue`) and DECIMAL(12,6) ×8 (two per table in four tables). Rev 5 O5 asked approval for four of each under pacEHR_API `CLAUDE.md` rule 3. Find out whether that approval was given.
6. **LangSmith.** Four merged tables carry `traceId` described as a "LangSmith run id". `src/core/settings.ts` refuses the LangSmith tracing variables, and the brainstorm (§4) rules LangSmith cloud out for production. Decide what `traceId` holds, for example an App Insights operation id.
7. **House DDL rules.** Each merged script ends with a "Column reference" table in comments, which the house rule (one line per column with a trailing comment, no column tables) does not allow. The scripts are forward-only, so they stay unless the rule is relaxed. The DDL in Part 1 follows the rule.
8. **ALTER TABLE is banned outright.** The PR 12745 note says a later change should be "a new numbered script using CREATE OR ALTER". That works only for views and procedures, so a column or CHECK on any `AI` table can never change. Decide whether the runner should allow additive `ALTER TABLE AI.x ADD` / `ADD CONSTRAINT`.
9. **Retention meaning and period:** delete, delete decided rows only, or redact (PEA-204). The period is with compliance (rev 5 O8).
10. **Model dependency.** gpt-4.1 is deprecated for new customers and retires on 2027-04-14. Newer reasoning models change what the token columns mean (PEA-202).
