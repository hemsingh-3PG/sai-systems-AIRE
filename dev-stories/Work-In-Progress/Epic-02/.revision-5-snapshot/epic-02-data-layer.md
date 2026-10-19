# Epic 2 — Data Layer — AI Schema Tables

**Epic id:** E2 · **Phase:** 1 · **Stories:** PEA-201..PEA-207 · **Points:** 24

> **⚠ Private copy — build target is TypeScript/Node.js.**
> All DDL (five tables, three roles, every column, constraint and index), all Gherkin
> acceptance criteria and all REQ- requirement IDs are language-neutral — they are T-SQL and
> clinical rules that hold across any runtime. Only the runner, driver, repository,
> validation and test layers are expressed in TypeScript terms below. The team-space copy of
> this epic is the Python reference design and is deliberately unmodified.

## Goal

Five tables exist in the `AI` schema of the existing production Azure SQL database —
`agentRun`, `fieldOutcome`, `promptFragment`, `fieldConstraint`, `fieldDescription` —
created by one forward-only, reviewable, idempotent migration mechanism that touches
nothing outside that schema. No existing clinical table is altered, dropped, or written
to by this service; every one of them stays exactly as read-only as it is today. Every
column that references an existing key carries that key's exact live spelling,
misspellings included. `AI.fieldOutcome` exists as the asset the rest of the program is
built on: it is what `after_agent` writes to, what the review queue reads from, and —
with no hand-labelling — what Epic 10's evaluation harness treats as ground truth.

## Scope

**In:**
- The `AI` schema itself, three database roles (`aiServiceRuntime`, `aiPromptAdmin`,
  `aiTemplateAdmin`), and a forward-only, idempotent migration mechanism runnable
  against the live production database.
- Five Phase 1 tables and their DDL: `AI.agentRun`, `AI.fieldOutcome` (with its index and
  retention/purge mechanism), `AI.promptFragment`, `AI.fieldConstraint`,
  `AI.fieldDescription`.
- The read/write authority boundary for every table, enforced as a database-level
  `GRANT`, not merely a code convention.
- The minimal repository-level TypeScript surface under `src/repositories/` (module-scope
  SCREAMING_SNAKE `_SQL` constants and one-method classes) other epics call to read or write
  these tables — not the callers themselves. The SQL text inside those constants is
  unchanged from the reference design.

**Out:**
- `AI.memoryEvent`, `AI.memory` — Epic 12, Phase 2.
- The *grain* and clinical justification for keying `AI.fieldDescription` and
  `AI.fieldConstraint` on `(templetID, sectionID, fieldID)` instead of `fieldID` alone —
  Epic 3, `PEA-301`. This epic ships the DDL both tables need and treats the grain as
  settled by that story; it does not re-argue it.
- Prompt fragment composition, precedence resolution, activation/promotion gating,
  rollback and A/B comparison — Epic 8, which reads and writes through this epic's
  `AI.promptFragment` table.
- The validators that read `AI.fieldConstraint` at request time, and the schema-builder
  that reads `AI.fieldDescription` at request time — Epic 6 and Epic 3 respectively.
- The `/ai/encounter/resolve` endpoint that calls this epic's decision-update class —
  Epic 9.
- The evaluation harness that reads `AI.fieldOutcome` as its labelled set — Epic 10.
- The deployment pipeline step that invokes this epic's migration runner, and the
  schedule trigger for the retention purge job — Epic 11.
- The Prompt Studio UI/API and the template editor UI that call the admin-write paths
  this epic only grants permissions for — outside this epic's numbered scope.

**A note on table count.** The source index's `REQ-02-10` names four Phase 1 tables
(`promptFragment`, `fieldConstraint`, `agentRun`, `fieldOutcome`), matching the 4Pager's
own enumeration. This epic ships a fifth: `AI.fieldDescription`. `REQ-03-01` requires the
per-mapping field description to be stored keyed on `(templetID, sectionID, fieldID)`,
and `REQ-02-07` forbids storing anything new on an existing clinical table — so the
description cannot live where the source index implicitly assumed it would when it wrote
"four." It has to be an `AI`-schema sidecar at the mapping grain, and `AI`-schema DDL is
this epic's job, not Epic 3's. Five tables, not four; `REQ-02-10`'s "no new data store is
introduced" still holds — this is one more table in the same existing database, not a
new store.

## Dependencies

**A TypeScript equivalent of Epic 01 must land first.** Every migration script and every
repository class in this epic calls the module-level `database` singleton that the
foundation epic defines — **src/core/database.ts** (node-mssql) in the build target,
**core/database.py** in the Python reference design — and this epic adds one field to that
epic's `Settings` object, **src/core/settings.ts** (zod) in the build target.

⚠️ **This is the largest new risk the TypeScript retarget introduces, and it is a
prerequisite with no published backlog.** Epic 01's Python deliverables (PEA-101…106) do
**not** transfer: **core/settings.py** becomes a zod schema, **core/database.py** becomes a
node-mssql wrapper, and the governing dependency allow-list
[00-langchain-api-truth.md](solution-doc:5091) constrains Python libraries and has **no
force over a Node runtime at all**. A Node dependency allow-list has to be authored
alongside the `src/core/` foundation (`settings.ts`, `database.ts`, `llm.ts`, `errors.ts`,
`logging.ts`, `auth.ts`) before any story here can ship its repository layer. The DDL
stories can proceed in parallel; the repository and test layers cannot.

No other epic is a prerequisite. Epics 3, 6, 8, 9, 10 and 12 depend on tables this epic creates, not the
other way around; Epic 3's `PEA-301` supplies the clinical justification `PEA-206` and
`PEA-207` cite for their shared key.

---

### PEA-201 — Create the AI schema via a forward-only migration mechanism

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 5
**Depends on:** none · **Satisfies:** REQ-02-07, REQ-02-10

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want a migration mechanism that creates the `AI` schema and its
supporting roles idempotently and forward-only, so that I can run it against the live
production database — with real patient data already in it — without risking anything
that exists there today.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Every other story in this epic assumes the `AI` schema and its access-control roles
already exist. This story is where that assumption becomes true, and it is the one place
in the epic where a mistake reaches production data that predates this project. The
database this runs against is not a sandbox: it holds real encounters for real patients,
and the standing instruction is absolute — no existing clinical table is altered, and
nothing about this migration mechanism may create a way for that to happen by accident,
including on a bad re-run. "Reviewable" and "forward-only" are the two properties that
make that true: every script is a plain, literal file an engineer can read start to
finish before it runs, and there is no down-migration to accidentally invoke against a
database that has since accumulated new rows in the tables this epic owns.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Applying the Phase 1 migration set creates the schema and nothing else
  Given a copy of the production Azure SQL database with no AI schema
   When the migration runner applies every script under migrations/sql/ in numeric order
   Then the AI schema exists
    And the roles aiServiceRuntime, aiPromptAdmin and aiTemplateAdmin exist
    And no row in any existing clinical table has been added, changed or removed

Scenario: Re-running the full migration set is a no-op
  Given the Phase 1 migration set has already been applied once
   When the migration runner is invoked again against the same database
   Then no error is raised
    And no schema, role or table is recreated or altered
    And every existence check short-circuits its CREATE statement

Scenario: A script touching an object outside the AI schema is rejected before merge
  Given a draft migration script containing "ALTER TABLE Encounter.encounter ADD aiFlag BIT"
   When the schema-scope check runs in CI
   Then the check fails
    And the script cannot be merged

Scenario: No down-migration exists
  Given the migrations/sql/ directory after this story lands
   When it is inspected
   Then no script drops or reverses a prior script
    And undoing a bad migration is a new forward script, never an edit to a merged one
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Migration files live at `migrations/sql/0001_create_ai_schema.sql` through
  `0006_create_field_description.sql` (this story ships `0001` only; each later story in
  this epic adds its own numbered file). Every file is static, fully literal SQL, never
  string-built and never taking a runtime parameter — the same "no value ever reaches SQL
  by interpolation" discipline CLAUDE.md states for application queries (§ Naming),
  applied to DDL for the identical reason: a reader sees exactly what will run.
- `0001` is idempotent by existence check, not by a tracking table:
  `IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'AI') EXEC('CREATE SCHEMA AI');`
  and the equivalent against `sys.database_principals` for each role. **No migration-history
  ledger table is introduced** — a fifth table for that purpose would make this epic's own
  table count six against the five this epic already explains as a deviation from
  `REQ-02-10`; idempotent existence checks substitute for a ledger entirely.
- The runner is `class MigrationRunner` in **src/core/databaseMigrations.ts**, one public
  method `applyPending()`, reading `migrations/sql/` in filename order and executing each
  script's full text via the existing `database` singleton's `execute()` — it does not open
  a second connection (CLAUDE.md § Singletons). **The dual sync/async hazard disappears in
  Node.** The Python design had to warn against publishing a synchronous `execute` beside
  `aexecute`, and had to bridge with `asyncio.run(...)` at the CLI boundary, because
  `mssql_python` is a synchronous PEP 249 driver. The **mssql** npm package (node-mssql,
  over tedious) is **natively async**, so there is one `execute()` and no thread-pool
  wrapper — a genuine simplification, not merely a translation. The CLI entry point is a
  top-level `await migrationRunner.applyPending()`.
  **mssql** is the underlying driver; this story does not touch it directly, only through
  the singleton. ⚠️ Note the governing allow-list
  [00-langchain-api-truth.md](solution-doc:5091) §7 pins the *Python* driver and does not
  apply here — the Node dependency allow-list that replaces it is a prerequisite (see
  Dependencies).
- Three roles created here, used by every later story in this epic: `aiServiceRuntime`
  (mapped to the extraction Function's own managed identity — CLAUDE.md § Configuration:
  "Deployed code authenticates with managed identity"), `aiPromptAdmin` (Prompt Studio's
  identity — Epic 8), `aiTemplateAdmin` (the template editor's identity — Epic 3 and
  Epic 6's authoring surfaces). No table-level `GRANT` is issued in this script; each
  table's own story grants exactly what that table needs.
- CI schema-scope check: a small **vitest** spec at
  **tests/unit/databaseMigrations.test.ts** performing a regex check that every top-level
  statement in every shipped script matches `CREATE SCHEMA AI`, `CREATE TABLE AI.`,
  `CREATE INDEX ... ON AI.`, `CREATE ROLE`, or `GRANT ... ON AI.` — and asserts no `ALTER`,
  `DROP`, `INSERT`, `UPDATE` or `DELETE` keyword appears against any object outside the
  `AI` schema. Built-in `RegExp`, no new dependency.
- Security: the identity that runs migrations (deploy-time) is distinct from
  `aiServiceRuntime` (runtime) — schema-creation rights are never held by the identity
  that serves clinician requests.
- Invocable standalone (an npm script such as `npm run migrate`, or
  `node dist/core/databaseMigrations.js`), so it does not block on Epic 11's pipeline
  definition; Epic 11 later wires this same entry point into its deployment step.

#### 5. Definition of Done (DoD) Checklist

- [ ] `migrations/sql/0001_create_ai_schema.sql` creates the `AI` schema and the three
      roles, each guarded by an existence check
- [ ] **src/core/databaseMigrations.ts** defines `class MigrationRunner` with one public
      method `applyPending()`, calling the `database` singleton's `execute()`
- [ ] **tests/unit/databaseMigrations.test.ts** (vitest) asserts every migration script
      under `migrations/sql/` touches only `AI`-schema objects and contains no `ALTER`,
      `DROP`, `INSERT`, `UPDATE` or `DELETE` against anything else
- [ ] **tests/integration/databaseMigrations.test.ts** (vitest) applies the full script set
      twice against a scratch database and asserts the second run raises no error and
      creates nothing
- [ ] No file under `migrations/sql/` drops or reverses another
- [ ] Migration reviewed by a second engineer and dry-run against a staging copy of the
      production database before being applied to production
- [ ] Reviewed against CLAUDE.md § Singletons (no second connection opened) and § Naming
      (no interpolated SQL). **The "no synchronous `execute` beside `aexecute`" check does
      not apply** — node-mssql is natively async and there is only one `execute()`
- [ ] **The Node dependency allow-list exists and pins `mssql`** (see Dependencies); the
      Python allow-list [00-langchain-api-truth.md](solution-doc:5091) is not authoritative
      for this repository

---

### PEA-202 — Record one append-only AI.agentRun row per invocation

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-201 · **Satisfies:** REQ-02-03, REQ-02-07, REQ-02-09

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want an immutable, append-only record of every AI invocation —
including the ones that never reached the model — so that "show me every AI call on this
chart" always has an answer no application code can have edited after the fact.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The current system's only log of an AI call is written by the browser after the response
ends, carries client-asserted token counts, and is simply absent when the client fails.
`AI.agentRun` replaces that with a server-side row written unconditionally by the agent
itself — once per invocation, including runs that were blocked by a guard before any
model call happened. That last case is not an edge case to handle later: the middleware
architecture this project is built on (`jump_to: "end"` from `before_agent`) exists
specifically so `after_agent` still runs on a blocked request, and this table is the
reason that property matters — a blocked run is exactly the run most worth having an
immutable record of. No human ever writes to this table; if a row is wrong, the fix is a
new run, not an edit to an old one.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A committed run writes exactly one row
  Given a request that completes with every field accepted
   When after_agent runs
   Then exactly one row is inserted into AI.agentRun
    And its outcome is "committed"
    And its promptHash, modelDeployment, inputTokens, outputTokens and latencyMs are all populated

Scenario: A guard-blocked run still writes its row
  Given a note containing a prompt-injection pattern
   When before_agent blocks the run by returning jump_to "end"
   Then after_agent still executes
    And exactly one AI.agentRun row is inserted with outcome "guard_blocked"
    And inputTokens, outputTokens and latencyMs are NULL because the model was never called

Scenario: The service cannot modify a written row
  Given the extraction service's database principal, aiServiceRuntime
   When its grants on AI.agentRun are inspected via sys.database_permissions
   Then only SELECT and INSERT are granted
    And no UPDATE or DELETE permission exists

Scenario: The repository exposes no update path
  Given src/repositories/agentRunWriter.ts
   When its module-level SQL constants are enumerated
   Then exactly one is present, INSERT_AGENT_RUN_SQL
    And no constant exists that could update or delete a row
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `AI.agentRun` created by `migrations/sql/0002_create_agent_run.sql`:
  `runID BIGINT IDENTITY(1,1) PRIMARY KEY`, `encounterID INT NOT NULL`,
  `promptHash CHAR(64) NOT NULL` (SHA-256 hex digest of the composed prompt, hashed before
  the model call per REQ-10-03), `modelDeployment NVARCHAR(100) NOT NULL`,
  `inputTokens INT NULL`, `outputTokens INT NULL`, `latencyMs INT NULL`,
  `outcome VARCHAR(20) NOT NULL CHECK (outcome IN ('committed','awaiting_review','guard_blocked','error'))`,
  `createdUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`. Token/latency columns are
  nullable specifically because `guard_blocked` runs never reach the model.
- `encounterID` is a logical reference to `Encounter.encounter`'s own key, spelled to match
  `Encounter.encounterData`'s own `encounterID` column (verified in
  `pacEHR-AI-Approach-2-Proposed.md` §3.2 and `pacEHR-Encounter-Template-Data-Model.md`).
  No physical `FOREIGN KEY` constraint is added: `Encounter.encounter`'s own canonical DDL
  is not derivable from this repository's source documents, so its exact column type must
  be verified against `information_schema.columns` on the live database before any
  constraint is added — per CLAUDE.md § Code standard, "verify, do not recall." Do not add
  an unverified constraint.
- `outcome` is fixed forever at the single moment `after_agent` writes it — this table
  never learns that a flagged run was later resolved. Whether a run is still awaiting
  review is a derived fact, obtained by joining to `AI.fieldOutcome` and checking whether
  its `decidedAtUtc` columns are populated (see PEA-203). This keeps "append-only, written
  only by the agent" an absolute invariant rather than one with an exception for the
  resolve path.
- Module: **src/repositories/agentRunWriter.ts**. `INSERT_AGENT_RUN_SQL` is the one
  `SCREAMING_SNAKE`, `_SQL`-suffixed constant, declared above `class AgentRunWriter` — both
  names survive the language change unchanged — whose one public method `record(...)` is an
  `async` function calling the singleton's `database.execute(INSERT_AGENT_RUN_SQL, ...)` —
  one class, one surface, one method, per CLAUDE.md § Code standard. The row shape is a zod
  schema with `z.infer<>` rather than a Pydantic model, giving runtime validation and the
  compile-time type from one declaration.
- `GRANT SELECT, INSERT ON AI.agentRun TO aiServiceRuntime;` — no `UPDATE`/`DELETE` grant
  is ever issued, at the database level, independent of what application code does.
- `outcome` values are module constants (`OUTCOME_COMMITTED`, `OUTCOME_AWAITING_REVIEW`,
  `OUTCOME_GUARD_BLOCKED`, `OUTCOME_ERROR`), never bare string literals, per CLAUDE.md
  § Numbers/Naming.
- No clinical value is stored in this table — prompt hash, deployment name, counts and
  timing only. No PHI masking concern here, unlike `AI.fieldOutcome`.
- Performance: one insert per invocation (~1,000/day at current stated volume); `runID`
  as an ever-increasing clustered key avoids page-split fragmentation on this
  insert-heavy, never-updated table.

#### 5. Definition of Done (DoD) Checklist

- [ ] `migrations/sql/0002_create_agent_run.sql` creates `AI.agentRun` with the CHECK
      constraint on `outcome` and the column-level nullability described above
- [ ] **src/repositories/agentRunWriter.ts** defines `INSERT_AGENT_RUN_SQL` and
      `class AgentRunWriter.record(...)`; no other SQL constant in the module
- [ ] `GRANT SELECT, INSERT ON AI.agentRun TO aiServiceRuntime` applied; no `UPDATE`/
      `DELETE` grant exists, verified against `sys.database_permissions`
- [ ] **tests/unit/agentRunWriter.test.ts** (vitest) covers: a committed run's row shape, a
      guard-blocked run's row shape (NULL token/latency columns), and asserts the module
      exports exactly one SQL constant
- [ ] **tests/integration/agentRunWriter.test.ts** (vitest) inserts a row against a real
      database and confirms an attempted `UPDATE` from `aiServiceRuntime` is rejected by
      the server, not merely absent from application code
- [ ] No log line, trace attribute or exception message tied to this table carries a
      clinical value — not applicable here by design, and the DoD says so rather than
      silently skipping CLAUDE.md § Clinical and PHI rules
- [ ] Reviewed against CLAUDE.md § Naming (constant placement, no interpolation)

---

### PEA-203 — Store the AI's proposal beside the clinician's decision in AI.fieldOutcome

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-201, PEA-202 · **Satisfies:** REQ-02-04, REQ-02-08, REQ-02-09

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want every field the AI ever proposed stored beside whatever
the clinician ultimately accepted, with the AI's own FOUND/ABSENT/ABSTAINED verdict kept
distinct from the clinician's own, so that edit rate is a real, computed number instead
of a claim, and so that every accepted encounter becomes a labelled training example
without anyone hand-labelling anything.

#### 2. Business Context & Problem Statement (Why are we doing this?)

This is not an audit table with a clinical flavor. `AI.fieldOutcome` is the only honest
accuracy measurement this project has, it is what drives the review queue a clinician
resolves against, and it is the free, already-labelled evaluation set Epic 10's prompt
harness consumes with no hand-labelling step in between — a fragment edit is judged by
replaying it against real rows already sitting in this table. All three of those depend
on the same underlying fact never being fudged: what the AI proposed and what the
clinician accepted must sit in the same row, unedited relative to each other, and the
AI's own three-state verdict — FOUND, ABSENT, or ABSTAINED — must never collapse into a
single "no value" encoding. The current production system writes `NA` whether the note
said nothing or the model was guessing, and that is precisely the defect this table
exists to stop reproducing: this design fails the moment a row makes ABSENT and ABSTAINED
indistinguishable, because everything downstream — edit rate, the review queue, Epic 10's
metrics — is computed by querying `proposedStatus`, and a collapsed value makes that query
lie.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: An absent field and an abstained field are never the same row shape
  Given a note that never mentions the patient's smoking status
    And a separate encounter whose note discusses smoking ambiguously
   When after_model produces a verdict for the "Smoking Status" field on each encounter
   Then the first AI.fieldOutcome row has proposedStatus "ABSENT" and proposedValue NULL
    And the second has proposedStatus "ABSTAINED" and proposedValue NULL
    And a query grouping rows by proposedStatus returns both as distinct groups

Scenario: The agent's proposal and the clinician's decision sit side by side
  Given an AI.fieldOutcome row proposing weight "187" with no unit, proposedStatus ABSTAINED
   When the clinician resolves the flagged field by accepting "187 lb"
   Then acceptedValue is "187", acceptedUnit is "lb", acceptedStatus is "FOUND"
    And proposedValue, proposedUnit and proposedStatus are unchanged from the original proposal
    And decidedByProviderId and decidedAtUtc are populated

Scenario: The proposed side cannot be altered by the decision path
  Given src/repositories/fieldOutcomeRepository.ts
   When the column list of UPDATE_FIELD_OUTCOME_DECISION_SQL is inspected
   Then it names only acceptedValue, acceptedUnit, acceptedStatus, decidedByProviderId and decidedAtUtc
    And it names no proposed* column
    And the database's column-level GRANT UPDATE on AI.fieldOutcome for aiServiceRuntime names that same column list

Scenario: The review queue reads only undecided rows without a table scan
  Given 50,000 AI.fieldOutcome rows, 40 of them with decidedAtUtc NULL
   When the review-queue query runs
   Then it executes as an index seek against the filtered index on decidedAtUtc IS NULL
    And it returns exactly the 40 undecided rows
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `AI.fieldOutcome` created by `migrations/sql/0003_create_field_outcome.sql`:
  `outcomeID BIGINT IDENTITY(1,1) PRIMARY KEY`,
  `runID BIGINT NOT NULL FOREIGN KEY REFERENCES AI.agentRun(runID)` (a real, verifiable
  constraint — `AI.agentRun` is this epic's own table), `encounterID INT NOT NULL`,
  `templetID INT NOT NULL`, `sectionID INT NOT NULL`, `fieldID INT NOT NULL` (exact live
  spelling, matching `Encounter.encounterTempletMapping`'s own triple),
  `proposedValue NVARCHAR(400) NULL`, `proposedUnit NVARCHAR(50) NULL`,
  `proposedStatus VARCHAR(10) NOT NULL CHECK (proposedStatus IN ('FOUND','ABSENT','ABSTAINED'))`,
  `proposedConfidence VARCHAR(6) NOT NULL CHECK (proposedConfidence IN ('HIGH','MEDIUM','LOW'))`
  (REQ-03-09 — never numeric), `foundIn NVARCHAR(1000) NULL` (populated only when
  `proposedStatus = 'FOUND'`), `verdict VARCHAR(10) NOT NULL CHECK (verdict IN ('accept','review','block'))`
  (REQ-06-08's per-field verdict — deliberately a distinct vocabulary from `agentRun.outcome`,
  which is run-level), `reasonCode NVARCHAR(50) NULL` (populated when `verdict <> 'accept'`;
  Epic 6 writes the value, Epic 10 aggregates it per REQ-10-14 — this story only owns the
  column), `acceptedValue NVARCHAR(400) NULL`, `acceptedUnit NVARCHAR(50) NULL`,
  `acceptedStatus VARCHAR(10) NULL CHECK (acceptedStatus IN ('FOUND','ABSENT','ABSTAINED') OR acceptedStatus IS NULL)`,
  `decidedByProviderId INT NULL` (matches the existing `providerId` spelling convention
  used elsewhere in this database, e.g. `Patient.roundingNotes.providerId`),
  `decidedAtUtc DATETIME2 NULL`, `createdUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`.
- Same "verify, do not recall" caveat as PEA-202 applies to `encounterID`/`templetID`/
  `sectionID`/`fieldID`'s exact source column types — confirm against
  `information_schema.columns` before finalizing the migration.
- **Volume, and where the number comes from:** ~30 rows per encounter, ~1,000
  AI-assisted encounters/day ⇒ 30 × 1,000 × 365 ≈ 10.95M rows/year
  (`pacEHR-Encounter-Agent-4Pager.md` line 111). `BIGINT` identity is chosen — not
  `INT` — specifically because the retention window that bounds this table's steady-state
  size is not yet numerically fixed (open question B7); `BIGINT` costs 4 extra bytes/row
  and removes any question of the identity range being revisited later.
- Indexes: clustered PK on `outcomeID`; `IX_fieldOutcome_run NONCLUSTERED (runID)`;
  `IX_fieldOutcome_pending NONCLUSTERED (encounterID, createdUtc) WHERE decidedAtUtc IS NULL`
  — a filtered index sized to the review queue's actual working set (tens of rows) rather
  than the whole 11M-row table; `IX_fieldOutcome_field_history NONCLUSTERED (templetID, sectionID, fieldID, createdUtc)`
  supporting Epic 10's evaluation harness pulling recent examples per field slot
  (REQ-10-08) without a table scan.
- Module: **src/repositories/fieldOutcomeRepository.ts**. Two `_SQL` constants,
  `INSERT_FIELD_OUTCOME_SQL` and `UPDATE_FIELD_OUTCOME_DECISION_SQL`, each declared above
  its own one-method class — `class FieldOutcomeProposalWriter.record(...)` (called from
  `after_agent`, alongside `AgentRunWriter.record(...)`) and
  `class FieldOutcomeDecisionWriter.record(...)` (called from Epic 9's
  `/ai/encounter/resolve` handler — this story owns the function, not the endpoint).
- **The same `aiServiceRuntime` principal performs both writes** — the clinician never
  connects to the database directly, they go through this same backend service via HTTP,
  so no fourth database role is needed. What stops the decision path from touching the
  proposed side is the column-level grant, not a different identity:
  `GRANT SELECT, INSERT ON AI.fieldOutcome TO aiServiceRuntime;`
  `GRANT UPDATE (acceptedValue, acceptedUnit, acceptedStatus, decidedByProviderId, decidedAtUtc) ON AI.fieldOutcome TO aiServiceRuntime;`
  — the server itself refuses a write to any `proposed*` column from this identity,
  independent of any application-level bug.
- Security/PHI: `proposedValue`, `acceptedValue` and `foundIn` can carry clinical text
  extracted from the note. Per CLAUDE.md § Clinical and PHI rules ("log the token, never
  the value"), any log line referencing a row logs `outcomeID`/`runID`, never these
  columns' contents.

#### 5. Definition of Done (DoD) Checklist

- [ ] `migrations/sql/0003_create_field_outcome.sql` creates `AI.fieldOutcome` with both
      CHECK constraints, the FK to `AI.agentRun`, and both nonclustered indexes
      (including the filtered one)
- [ ] **src/repositories/fieldOutcomeRepository.ts** defines both `_SQL` constants and both
      writer classes described above, with zod schemas (`z.enum([...])` for `proposedStatus`,
      `proposedConfidence` and `verdict`) replacing the Pydantic `Literal` types
- [ ] Column-level `GRANT UPDATE (...)` applied exactly as listed; a test asserts an
      `UPDATE` naming `proposedValue` from `aiServiceRuntime` is rejected by the server
- [ ] **tests/unit/fieldOutcomeRepository.test.ts** (vitest) covers: an ABSENT row and an
      ABSTAINED row are distinguishable by a straight equality query on `proposedStatus`,
      and the decision-update statement leaves every `proposed*` column absent from its
      own column list
- [ ] `tests/integration/` proves the filtered index is used (query plan or
      `sys.dm_db_index_usage_stats`) for the review-queue query, not a table scan
- [ ] No log line, trace attribute or exception message carries `proposedValue`,
      `acceptedValue` or `foundIn` — reviewed against CLAUDE.md § Clinical and PHI rules
- [ ] The 30-rows/encounter, ~10.95M-rows/year figure appears as a code comment citing
      `pacEHR-Encounter-Agent-4Pager.md` line 111, per CLAUDE.md § Numbers
- [ ] Reviewed against CLAUDE.md § Naming and § Code standard (one class, one method,
      per SQL statement)

---

### PEA-204 — Purge AI.fieldOutcome rows past the configured retention window

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 2
**Depends on:** PEA-203 · **Satisfies:** REQ-02-08

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want AI.fieldOutcome rows older than a configured retention
window deleted, and I want that deletion to refuse to run at all rather than guess a
number, so that a table holding real clinical values does not grow forever and does not
silently mass-delete on a bad default.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`AI.fieldOutcome` is the only one of this epic's tables that grows meaningfully — see
PEA-203 for the ~10.95M-rows/year figure — and it holds clinical values, so a retention
policy is not optional. But the exact retention period is a genuinely open question:
neither primary source document states one (open question B7 in the source index), and
inventing a specific day-count here would be exactly the kind of unsupported number
CLAUDE.md's numbers rule forbids. The resolvable part is the mechanism: a configurable
window that fails closed when unset, so the absence of a compliance decision can never
be read by the code as "delete everything" or "delete nothing older than some guessed
number." Whatever window compliance eventually sets must also stay longer than Epic 10's
evaluation harness needs — that harness replays "recent real notes" (REQ-10-08), not the
full historical corpus, so a reasonable window does not starve it; the exact minimum is
Epic 10's to specify, not invented here.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Rows older than the configured window are purged
  Given AI_FIELD_OUTCOME_RETENTION_DAYS is set to a positive integer
    And AI.fieldOutcome rows exist with createdUtc older than that many days ago
   When the retention purge job runs
   Then those rows are deleted
    And rows inside the window are untouched

Scenario: An unset retention period fails closed
  Given AI_FIELD_OUTCOME_RETENTION_DAYS is unset
   When the retention purge job is invoked
   Then no row is deleted
    And the job logs a refusal that names the missing setting, not any row's content
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `aiFieldOutcomeRetentionDays` added to the foundation epic's **src/core/settings.ts**
  zod schema as
  **`z.coerce.number().int().positive().optional()`** — reading the environment variable
  `AI_FIELD_OUTCOME_RETENTION_DAYS` (**env key casing unchanged**). A limit that is a
  compliance decision rather than a code constant is a settings field per CLAUDE.md
  § Numbers, not a hardcoded literal.
  🔴 **Never `.default(0)`.** `.optional()` yields `undefined` when unset, which the purge
  treats as "refuse and delete nothing". A `.default(0)` would silently turn an unmade
  compliance decision into "purge everything older than zero days" — i.e. the whole table.
  **Unset ≠ zero.** `.positive()` additionally rejects an explicitly-configured `0`, so
  neither route can reach a mass delete. This is the single most dangerous line in the
  TypeScript retarget and warrants its own reviewer sign-off.
- Module: **src/jobs/fieldOutcomeRetention.ts**. `DELETE_FIELD_OUTCOME_BEFORE_SQL` is the
  one `_SQL` constant, declared above `class FieldOutcomeRetentionPurger` — both names
  survive the language change — whose one public method `purge()` refuses (rather than
  defaulting to some invented number) when the setting is `undefined` — the same
  fail-closed posture CLAUDE.md applies to PHI guards, extended here to a mass-deletion
  risk against the project's only labelled evaluation set.
- Who invokes it and how often is Epic 11's to schedule; this story owns only the purge
  function and its guard, not the schedule. In the build target the natural host is
  **Azure Functions Node.js v4** — `app.timer('purgeFieldOutcome', { schedule, handler })`
  from `@azure/functions`, with **no per-function `function.json`** (the v4 model registers
  in code). ⚠️ **Open decision for the owner:** the existing .NET
  `PacEHR.Functions.Process` host already runs five live timer jobs, so the purge could run
  there instead of standing up a second Functions host — but note that no pipeline
  currently deploys that .NET Functions project either.
- The purge is a hard `DELETE`, not a soft-delete flag — the point of a retention policy
  on a table holding clinical values is that the data stops existing at the end of the
  window.
- Security/PHI: the refusal log line names the missing setting only, never any row's
  `proposedValue`/`acceptedValue`/`foundIn` — per CLAUDE.md § Clinical and PHI rules.
- Performance: `DELETE ... WHERE createdUtc < ?` benefits from the same clustered
  ordering used for inserts; no additional index is required beyond what PEA-203 already
  defines, since `createdUtc` is the leading column of the filtered review-queue index's
  companion column set on this same table's insert-heavy tail.

#### 5. Definition of Done (DoD) Checklist

- [ ] `aiFieldOutcomeRetentionDays` added to **src/core/settings.ts** as
      `z.coerce.number().int().positive().optional()`, reading
      `AI_FIELD_OUTCOME_RETENTION_DAYS`
- [ ] 🔴 **A reviewer has explicitly confirmed the schema is `.optional()` and NOT
      `.default(0)`**, and a test asserts that an unset variable yields `undefined` (not
      `0`) and that `purge()` consequently deletes nothing
- [ ] **src/jobs/fieldOutcomeRetention.ts** defines `DELETE_FIELD_OUTCOME_BEFORE_SQL` and
      `class FieldOutcomeRetentionPurger.purge()`
- [ ] **tests/unit/fieldOutcomeRetention.test.ts** (vitest) covers: rows older than the
      window are targeted, rows inside the window are excluded, and an unset setting
      purges zero rows and raises/logs a named refusal
- [ ] The refusal log line is asserted (by test) to never contain a row's value columns
- [ ] The 10.95M-rows/year arithmetic and its source line are recorded as a code comment,
      per CLAUDE.md § Numbers
- [ ] `purge()` is invocable standalone with no dependency on a specific scheduler, so
      Epic 11 can wire its own trigger without a code change here

---

### PEA-205 — Store versioned prompt fragments in AI.promptFragment, admin-write only

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-201 · **Satisfies:** REQ-02-01, REQ-02-07, REQ-02-09

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want every prompt fragment stored as an addressable, versioned
row that only Prompt Studio can write, so that a bad prompt edit can be rolled back, two
versions can be compared, and the agent itself is structurally incapable of writing its
own instructions.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`AI.promptFragment` replaces the free-text blob in the legacy `AI.prompt` table — taken
off the runtime path entirely at migration (REQ-08-09) — with versioned, composable
fragments. This story is the storage contract only: the table, its keys, and the
boundary that the agent reads it and never writes it. Composition order, precedence
between an account-specific and a global fragment, activation gating on passed
evaluation, rollback and A/B comparison all belong to Epic 8, which is the only consumer
of what this table stores beyond the raw rows.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A fragment row records its kind, scope and version
  Given an AI/clinical admin saves a new "task" fragment for account 42 through Prompt Studio
   When the row is written
   Then kind is "task", scope is "account", accountId is 42, version is 1
    And isActive is 0 and passedEvaluation is PENDING_EVAL until the evaluation gate sets them

Scenario: Two versions of the same fragment coexist
  Given fragment kind "contract", scope "global", version 3 already exists
   When version 4 of the same kind and scope is saved
   Then both rows exist afterward
    And the uniqueness constraint on (kind, scope, accountId, version) accepts both

Scenario: The extraction agent cannot write to this table
  Given the extraction service's database principal, aiServiceRuntime
   When its grants on AI.promptFragment are inspected
   Then only SELECT is granted
    And no INSERT, UPDATE or DELETE permission exists
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `AI.promptFragment` created by `migrations/sql/0004_create_prompt_fragment.sql`:
  `fragmentID INT IDENTITY(1,1) PRIMARY KEY`,
  `kind VARCHAR(20) NOT NULL CHECK (kind IN ('contract','task','specialty','template_override'))`
  (Epic 8's vocabulary, REQ-08-10 — stored here because this table is this epic's;
  composing with it is Epic 8's job), `scope VARCHAR(10) NOT NULL CHECK (scope IN ('global','account'))`,
  `accountId INT NULL` (existing spelling — already used this way in `AI.prompt` and
  `Patient.roundingNotes`; populated only when `scope = 'account'`), `version INT NOT NULL`,
  `fragmentText NVARCHAR(MAX) NOT NULL`, `isActive BIT NOT NULL DEFAULT 0`,
  `passedEvaluation VARCHAR(12) NOT NULL DEFAULT 'PENDING_EVAL' CHECK (passedEvaluation IN ('PENDING_EVAL','PASSED','BLOCKED','INCOMPLETE'))`,
  `createdUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`,
  `updatedUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`, plus
  `UNIQUE (kind, scope, accountId, version)` — every version stays addressable, so Epic 8
  can roll back or A/B compare (REQ-08-14) without ever deleting a row.
- `passedEvaluation` carries the evaluation verdict itself, not a yes/no. A `BIT` cannot
  tell a version nobody has evaluated yet from one that was evaluated and failed, and those
  are different operational situations: the first is waiting on a replay, the second is a
  rejected edit an admin has to act on. The four values are the verdict Epic 10's gate
  (PEA-1008) writes — `PENDING_EVAL` at insert, then `PASSED`, `BLOCKED` or `INCOMPLETE` —
  and Epic 8's gate (PEA-804) resolves `PASSED` only, so every other state fails closed at
  runtime. The CHECK constraint is what keeps a fifth value out.
- Module: **src/repositories/promptFragmentRepository.ts**.
  `SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL` is the only constant this epic's module carries,
  declared above `class PromptFragmentReader`, one public method `activeFragments(...)`
  (camelCased from `active_fragments`; the class name survives). No write constant ships in any module the
  agent's runtime imports — Epic 8 owns its own write-side module against this same
  table.
- `GRANT SELECT ON AI.promptFragment TO aiServiceRuntime; GRANT INSERT, UPDATE ON AI.promptFragment TO aiPromptAdmin;`
  — the write identity is Prompt Studio's, never the runtime identity.
- Adding a fifth `kind` later is a new forward migration altering this table's own CHECK
  constraint, not a code change to any of its readers.
- No PHI: fragment text is prompt-engineering content, not patient data — no masking
  concern here, unlike `AI.fieldOutcome`.

#### 5. Definition of Done (DoD) Checklist

- [ ] `migrations/sql/0004_create_prompt_fragment.sql` creates `AI.promptFragment` with
      both CHECK constraints and the `(kind, scope, accountId, version)` unique
      constraint
- [ ] **src/repositories/promptFragmentRepository.ts** defines
      `SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL` and
      `class PromptFragmentReader.activeFragments(...)` only
- [ ] `GRANT SELECT ON AI.promptFragment TO aiServiceRuntime` and
      `GRANT INSERT, UPDATE ON AI.promptFragment TO aiPromptAdmin` applied; a test
      asserts `aiServiceRuntime` has no write grant, verified against
      `sys.database_permissions`
- [ ] **tests/unit/promptFragmentRepository.test.ts** (vitest) covers: two versions of the same
      `(kind, scope, accountId)` coexist, and the module exposes no write function
- [ ] A test covers `accountId` populated only when `scope = 'account'`
- [ ] Reviewed against CLAUDE.md § Clinical and PHI rules — no clinical value is stored
      here, noted explicitly rather than silently skipped

---

### PEA-206 — Store per-mapping field guards in AI.fieldConstraint, admin-write only

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-201 · **Satisfies:** REQ-02-02, REQ-02-07, REQ-02-09

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want the unit, plausible-range and abnormal-range
guard I write for a field in one section of a template to apply only to that mapping, so
that reusing the same field in a second section with a different meaning never inherits
a bound I wrote for somewhere else.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`AI.fieldConstraint` is keyed on `(templetID, sectionID, fieldID)` — the same triple as
the per-mapping field description this epic also stores (PEA-207) — not on `fieldID`
alone. `PEA-301` (Epic 3) is where that grain is argued at length, from the same evidence
that already forced the per-mapping description: `Template.fields.displayName` is global
today and one edit to it was measured reaching 179 of 458 templates
(`pacEHR-AI-Approach-2-Proposed.md` §3.2). A global, `fieldID`-only constraint would let a
bound written for one section's use of a field silently apply to every other section
reusing that `fieldID` — the identical collision, one table over. This story does not
re-argue that; it inherits the grain and ships the table. In most cases the bound really
will be identical across sections — blood pressure is 70–200 mmHg wherever it appears —
and duplicate rows at the finer grain cost a little storage. A coarser grain that cannot
express a difference costs correctness, and cannot be fixed later without a migration.
The agent never writes here: bounds are compiled from prose the clinical author writes in
the template editor and confirmed on save; this story is the storage those reads and
writes land in, not the compiler.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The same fieldID in two sections gets two independent constraint rows
  Given fieldID 412 ("Blood Pressure") mapped into sectionID 11 ("Review of Systems") of templetID 3
    And the same fieldID 412 mapped into sectionID 12 ("Exam") of the same templetID 3
   When a clinical template administrator saves different plausible bounds for each mapping
   Then two AI.fieldConstraint rows exist, one per (templetID, sectionID, fieldID)
    And updating the Exam row's bounds does not change the Review of Systems row

Scenario: A weight field's unit ambiguity is stored, not resolved, here
  Given fieldID 425 ("Weight") configured with unit "kg|lb"
   When its AI.fieldConstraint row is read
   Then unit reads "kg|lb" exactly as configured
    And no conversion or normalization has been applied to plausibleMin or plausibleMax

Scenario: The extraction agent cannot write to this table
  Given the extraction service's database principal, aiServiceRuntime
   When its grants on AI.fieldConstraint are inspected
   Then only SELECT is granted
    And no INSERT, UPDATE or DELETE permission exists
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `AI.fieldConstraint` created by `migrations/sql/0005_create_field_constraint.sql`:
  `constraintID INT IDENTITY(1,1) PRIMARY KEY`, `templetID INT NOT NULL`,
  `sectionID INT NOT NULL`, `fieldID INT NOT NULL` (exact live spelling, per REQ-02-09),
  `unit NVARCHAR(20) NULL`, `plausibleMin FLOAT NULL`, `plausibleMax FLOAT NULL`,
  `abnormalMin FLOAT NULL`, `abnormalMax FLOAT NULL`, `sourceProse NVARCHAR(MAX) NULL`
  (the clinical author's original prose this row was compiled from — traceability for
  why a bound says what it says), `isActive BIT NOT NULL DEFAULT 1`,
  `createdUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`,
  `updatedUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`, plus
  `UNIQUE (templetID, sectionID, fieldID)`. Unlike `AI.promptFragment`, this is one
  current row per mapping, updated in place on save — "confirmed on save" (REQ-06-09)
  describes a mutation of the active definition, not an appended version history.
- Module: **src/repositories/fieldConstraintRepository.ts**. `SELECT_FIELD_CONSTRAINT_SQL`
  is the only constant, declared above `class FieldConstraintReader`, one public method
  `forMapping(templetId, sectionId, fieldId)` — Epic 6's validators are the caller.
- ⚠️ **node-mssql surfaces `DECIMAL` as a JavaScript `number`** (an IEEE-754 binary
  double), which partly undoes the reason PEA-206's tech spec chose `DECIMAL(6,2)` over
  `FLOAT` in the first place: exact decimal comparison of clinical bounds. The column type
  stays `DECIMAL(6,2)` — storage precision and the two range CHECK constraints are still
  enforced server-side — but any comparison performed **in TypeScript** is floating-point
  and must not assume exactness. Prefer pushing range comparisons into SQL, or compare with
  an explicit tolerance. This is a genuine new hazard introduced by the runtime change, not
  present in the Python design.
- `GRANT SELECT ON AI.fieldConstraint TO aiServiceRuntime; GRANT INSERT, UPDATE ON AI.fieldConstraint TO aiTemplateAdmin;`
  — the compiling/write path is the template editor's own identity (Table B item B9
  leaves that surface's approval workflow open; this story asserts only "not the agent,"
  nothing beyond it).
- Performance: flat growth — one row per active field mapping across all templates, not
  per encounter — `INT` identity is sufficient, no filtered index or retention concern
  unlike `AI.fieldOutcome`.
- No PHI: bounds and units are template metadata, not patient data.

#### 5. Definition of Done (DoD) Checklist

- [ ] `migrations/sql/0005_create_field_constraint.sql` creates `AI.fieldConstraint` with
      the `(templetID, sectionID, fieldID)` unique constraint
- [ ] **src/repositories/fieldConstraintRepository.ts** defines
      `SELECT_FIELD_CONSTRAINT_SQL` and `class FieldConstraintReader.forMapping(...)` only
- [ ] **A test asserts no exact floating-point equality is used** when comparing
      `DECIMAL(6,2)` bounds read through node-mssql; range checks either run in SQL or use
      an explicit tolerance
- [ ] `GRANT SELECT ON AI.fieldConstraint TO aiServiceRuntime` and
      `GRANT INSERT, UPDATE ON AI.fieldConstraint TO aiTemplateAdmin` applied; a test
      asserts `aiServiceRuntime` has no write grant
- [ ] **tests/unit/fieldConstraintRepository.test.ts** (vitest) covers: fieldID 412 mapped into
      two sections of the same templet produces two independently-updatable rows, using
      the exact field/section numbers from `pacEHR-AI-Approach-2-Proposed.md` §3.1
- [ ] A test asserts `unit` round-trips exactly as configured (e.g. `"kg|lb"`) with no
      conversion applied
- [ ] Column spelling reviewed against CLAUDE.md § Clinical and PHI rules and REQ-02-09 —
      `templetID`, `sectionID`, `fieldID` spelled exactly as the live database spells
      them, not "corrected"

---

### PEA-207 — Store the per-mapping field description in AI.fieldDescription, admin-write only

**Type:** Story · **Epic:** E2 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-201 · **Satisfies:** REQ-02-07, REQ-02-09, REQ-02-10

#### 1. User Story (As a... I want... So that...)

As a clinical template administrator, I want the description I write for a field in one
section of a template saved against that exact mapping, so that the same field reused in
a different section of the same template never inherits words I wrote for somewhere
else.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`REQ-03-01` — the highest-value requirement in the corpus — requires the AI-facing field
description to be stored keyed on `(templetID, sectionID, fieldID)`, never globally per
`fieldID`, because the same `fieldID` legitimately recurs across sections with a different
meaning each time, and the description is the one sentence that tells the model what
distinguishes this slot from a similarly-named one. `PEA-301` (Epic 3) argues that grain
at length; this story does not repeat the argument, only the table it requires.

This table is also why this epic's own count changed. The source index's `REQ-02-10`
names four Phase 1 tables, matching the 4Pager's own enumeration — and neither mentions a
description table, because the 4Pager was written before the per-mapping storage
requirement was fully reconciled with `REQ-02-07`'s "existing clinical tables remain
read-only and unchanged." A per-mapping description cannot be a new column on
`Template.fields` or `Encounter.encounterTempletMapping` — both are existing clinical
tables this service may only read. It has to be a new `AI`-schema table, and this epic is
where `AI`-schema DDL lives. This story stores exactly one new fact per mapping: the
description text itself. `name`, `type` and `unit` are not duplicated here — they already
exist on `Template.fields`, are read-only, and are joined in by Epic 3's schema-builder at
request time; copying them into this table would create a second source of truth for
data that already has one.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The same fieldID in two sections keeps two independent descriptions
  Given fieldID 412 ("Blood Pressure") mapped into sectionID 11 ("Review of Systems") of templetID 3
    with description "Vital sign as measured and stated at the bedside. Systolic over diastolic."
    And the same fieldID 412 mapped into sectionID 12 ("Exam") of the same templetID 3
    with description "Blood pressure only when re-measured during the physical examination. If the value was already captured in Review of Systems, leave this empty."
   When a clinical template administrator edits the Exam mapping's description
   Then only the (3, 12, 412) row changes
    And the (3, 11, 412) row is unchanged

Scenario: An edit takes effect on the next request with no deployment
  Given a clinical template administrator saves a new description for (templetID 3, sectionID 11, fieldID 425)
   When the very next extraction request for that template runs
   Then Epic 3's schema-builder reads the updated description
    And no code change or deployment occurred between the save and that request

Scenario: The extraction agent cannot write to this table
  Given the extraction service's database principal, aiServiceRuntime
   When its grants on AI.fieldDescription are inspected
   Then only SELECT is granted
    And no INSERT, UPDATE or DELETE permission exists
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `AI.fieldDescription` created by `migrations/sql/0006_create_field_description.sql`:
  `templetID INT NOT NULL`, `sectionID INT NOT NULL`, `fieldID INT NOT NULL`,
  `PRIMARY KEY (templetID, sectionID, fieldID)` — no surrogate id; the mapping itself is
  the identity, matching how the requirement itself describes it. `description NVARCHAR(1000) NOT NULL`
  ("one line of description per field," REQ-03-03), `createdUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`,
  `updatedUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`. Same verify-before-relying-on-it
  caveat as PEA-203/PEA-206 applies to the triple's exact source column types.
- Module: **src/repositories/fieldDescriptionRepository.ts**. `SELECT_FIELD_DESCRIPTION_SQL`
  is the only constant, declared above `class FieldDescriptionReader`, one public method
  `forTemplet(templetId)` returning every mapping's description for that template in
  one call — matching REQ-03-04's "once per request... loads the current template's
  sections, fields, types and descriptions." The composite PK's leading column is
  `templetID`, which is exactly the one access pattern this table serves; no secondary
  index is needed.
- `GRANT SELECT ON AI.fieldDescription TO aiServiceRuntime; GRANT INSERT, UPDATE ON AI.fieldDescription TO aiTemplateAdmin;`
- Not cached at module or process scope: this class holds no state. CLAUDE.md's singleton
  pattern is for expensive clients reused across requests; caching this table's rows
  across requests would silently violate REQ-03-06's "takes effect on the very next
  request, with no deployment."
  ⚠️ **The Node failure modes differ from the Python ones and are easier to hit
  accidentally.** A Node module body runs once per process, so a module-scope `const` or
  `Map` populated at import is a cache even though it does not look like one. Likewise
  **Azure Functions v4 warm-instance reuse**: anything assigned outside the `app.*` handler
  survives between invocations. Also barred: `lru-cache`/`node-cache`, a memoised
  `forTemplet()`, and rows held on a long-lived reader instance.
- `name`, `type` and `unit` are deliberately absent from this table — see Section 2. Do
  not add them here even if convenient; they belong to `Template.fields`.
- No PHI, no retention concern: template configuration metadata, flat growth bounded by
  the number of active field mappings, not by encounter volume.

#### 5. Definition of Done (DoD) Checklist

- [ ] `migrations/sql/0006_create_field_description.sql` creates `AI.fieldDescription`
      with composite primary key `(templetID, sectionID, fieldID)`
- [ ] **src/repositories/fieldDescriptionRepository.ts** defines
      `SELECT_FIELD_DESCRIPTION_SQL` and `class FieldDescriptionReader.forTemplet(...)`;
      no write constant in any module the agent's runtime imports
- [ ] `GRANT SELECT ON AI.fieldDescription TO aiServiceRuntime` and
      `GRANT INSERT, UPDATE ON AI.fieldDescription TO aiTemplateAdmin` applied; a test
      asserts `aiServiceRuntime` has no write grant, verified against
      `sys.database_permissions`
- [ ] **tests/unit/fieldDescriptionRepository.test.ts** (vitest) covers: fieldID 412 in two
      sections of the same templet returns two independent rows, using the exact
      description text from `pacEHR-AI-Approach-2-Proposed.md` §3.1 as fixture data
- [ ] A test/review confirms no `name`, `type` or `unit` column exists on this table
- [ ] This story's DDL is reviewed against this epic's Scope note on table count — this
      is Phase 1 table five of five, not one of the four `REQ-02-10` names, and the epic
      file states why