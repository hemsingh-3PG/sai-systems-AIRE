# Epic 8 — Prompt ownership

**Epic id:** E8 · **Phase:** 1 · **Stories:** PEA-801..PEA-807 · **Points:** 36

## Goal

Every clinical instruction the model receives is a versioned row in `AI.promptFragment`
(Epic 2, PEA-205), authored only through the Prompt Studio's write path and only ever
read by the agent through the read path Epic 2 already built — never overwritten in
place, and never written by the agent itself. A fragment reaches production only after it
is both marked active and has passed evaluation, and a bad version is undone by promoting
an earlier one, never by editing text back. The `contract` fragment — the model's
non-negotiable safety and epistemic rules — resolves to byte-for-byte identical text on
every encounter for a given account, regardless of which task or template is running.
Today's live contradiction is representative of why this matters: one row in the legacy
`AI.prompt` table instructs *"Always return \"NA\" if you are not sure about your response
or if the information is not specified,"* and an audit of the same table found another
instruction telling the model never to write `N/A` — both active simultaneously on the
H&P Initial family, with nothing in the data model saying which one binds. When this epic
is done, that class of defect is not fixed by policy; it is structurally impossible,
because there is exactly one resolved fragment of each kind per account, and getting a new
one live requires a version, a gate, and a named human.

## Scope

**In:** the fragment write path and version-numbering semantics against `AI.promptFragment`
(admin-write, agent read-only, enforced at the database grant level by Epic 2 and at the
import-graph level here); the resolution precedence engine across the four fragment kinds
(`contract`, `task`, `specialty`, `template_override`) — account beats global, highest
version wins, active + passed-evaluation required, deterministic behavior on a tie; the
task fragment's required per-request placeholder contract; the `contract` fragment's
authored content and its byte-for-byte-identical property; the one-time migration of the
legacy `AI.prompt` table off the runtime path; the promotion gate; rollback and A/B version
comparison.

**Out:** `AI.promptFragment`'s table, its `CHECK`/`UNIQUE` constraints, its database-level
`GRANT`s, and the agent-facing read repository (`core/prompt_fragment_repository.py`,
`PromptFragmentReader.active_fragments(...)`) — all Epic 2 (**PEA-205**); this epic is a
consumer of that reader and builds only the write side. Concatenating resolved fragments
into final prompt bytes and hashing them at request time is Epic 4's `before_model`
(**PEA-404**), referenced throughout, never implemented here. The replay-based evaluation
set and the deterministic promotion metrics that decide pass or block are Epic 10's
(**PEA-1007**, **PEA-1008**); the shared reason-code and metric vocabulary they and every
other epic read from is Epic 10's **PEA-1004**. This epic's gate consumes that verdict, it
does not compute it. The `resolve_prompt`, `resolve_date` and `compute_bmi` tools are Epic
7's. Building the slot manifest's actual field-level content from template configuration is
Epic 3's — this epic only guarantees the task fragment has somewhere for that content to
go. The Prompt Studio's own user interface is an existing, separate admin surface this
backlog does not build; this epic ships the write behavior it calls.

## Dependencies

**Epic 2** must land first: **PEA-205** creates `AI.promptFragment` with its
`(kind, scope, accountId, version)` uniqueness, its `isActive` flag and `passedEvaluation` state,
its database grants (`SELECT` to `aiServiceRuntime`, `INSERT`/`UPDATE` to `aiPromptAdmin`),
and the agent-facing read repository every story here either extends (the write side) or
calls (the resolver). **Epic 3** supplies the slot manifest content that PEA-805's
task-fragment placeholder receives. **Epic 4** and **Epic 10** are downstream peers this
epic hands off to, not stories it implements: Epic 4's `before_model` (**PEA-404**) already
depends on this epic's resolver (**PEA-802**) to assemble and hash the final prompt; Epic
10's replay harness and metric gate (**PEA-1007**, **PEA-1008**) produce the pass/block
verdict this epic's promotion gate (**PEA-804**) consumes, and PEA-803's migration seeds
version-1 fragments as an explicitly documented, one-time exception to that gate. Epic 7
calls this epic's resolver from its `resolve_prompt` tool (REQ-07-06) and is the home of
the `resolve_date` / `compute_bmi` tools this epic's contract fragment instructs the model
to use by name (REQ-08-05).

**A note on `AI.promptFragment`'s grain, for whoever builds against it next.** Epic 2's
landed schema keys a fragment on `(kind, scope, accountId, version)` only — there is no
`specialityId` or `templetId` column. That means the `specialty` and `template_override`
kinds can vary by account and by version, but **not** by which specific specialty or
template is in play: at most one active, passed fragment of each optional kind resolves
per account, and it applies uniformly whenever it exists. Every story below is built
against this actual schema, not against a richer per-specialty design. If per-specialty or
per-template targeting turns out to be required, it is a follow-up migration on Epic 2's
table, not a change any story here can make unilaterally.

---

### PEA-801 — Build the write path and version-numbering for prompt fragments

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-205 · **Satisfies:** REQ-08-10, REQ-08-13

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want to save a new version of a prompt fragment of any of the
four defined kinds through the Prompt Studio, with the agent able only to read what I
publish, so that every change to what the model is told is deliberate, attributable to me,
and impossible for the agent itself to alter.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today `AI.prompt` is one undifferentiated free-text blob, and an edit is a blind in-place
overwrite: `UPDATE ... SET prompt = ...`, with no version, no history, and no gate. Epic 2
(PEA-205) has already created `AI.promptFragment` — the table, its
`(kind, scope, accountId, version)` uniqueness, and the database grant that gives
`aiServiceRuntime` (the agent's own connection) `SELECT` only, never write. What Epic 2
explicitly left to this epic is the write side: the module that turns an admin's edit into
a new row rather than a mutated one. Saving a change never overwrites version N — it
inserts version N+1 alongside it, and N stays retrievable forever. That is the difference
between being able to see what changed and only ever being able to see what a thing
currently is. Equally load bearing: the module the agent imports to read fragments must
have no write method reachable through it at all — the moment an agent can rewrite its own
instructions, no auditor can trust that the instructions in force today are the ones a
human approved. That is an acceptance criterion here, not an assumption resting on the
database grant alone.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Saving an edit inserts a new version rather than overwriting one
  Given the `task` fragment at scope "global", version 4, exists
   When an AI/clinical admin saves an edited body through the Prompt Studio write path
   Then a new row is inserted as version 5, same kind and scope
    And the version 4 row's fragmentText is unchanged and still queryable

Scenario: A newly saved version is not automatically live
  Given an AI/clinical admin saves version 5 of the `contract` fragment at scope "global"
   When the save completes
   Then version 5 is created with isActive = 0 and passedEvaluation = PENDING_EVAL
    And version 4 remains the version the agent resolves until an admin explicitly
        activates version 5 through the promotion gate (PEA-804)

Scenario: The agent's own read path exposes no write method
  Given `core/prompt_fragment_repository.py`'s `PromptFragmentReader` (Epic 2, PEA-205),
        which the agent, Epic 4's before_model, and Epic 7's resolve_prompt tool all import
   When its public interface is inspected
   Then it exposes only `active_fragments(...)`
    And no mutating operation is reachable through that import path

Scenario: An unrecognized fragment kind is rejected before it reaches the database
  Given an AI/clinical admin submits a new fragment with kind "guidance"
   When the save is validated
   Then the save is rejected with a message naming the four recognized kinds — contract,
        task, specialty, template_override — before any SQL is issued
    And if that check were ever bypassed, Epic 2's own `CHECK (kind IN (...))` constraint
        (PEA-205) would still refuse the row
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `pacehr/prompts/studio.py` is this epic's write-side module against Epic 2's
  `AI.promptFragment` — Epic 2's own scope statement is explicit that "Epic 8 owns its own
  write-side module against this same table." It connects as `aiPromptAdmin`
  (`INSERT`, `UPDATE` granted, per PEA-205); it never connects as `aiServiceRuntime`.
- A save always issues an `INSERT` for a new version, computed as
  `MAX(version) + 1` over rows matching `(kind, scope, accountId)` — including inactive,
  not-yet-passed rows, so the next version number is correct even though
  `PromptFragmentReader.active_fragments(...)` (Epic 2) only ever returns the active,
  passed subset. This module therefore carries its own narrow read query for
  version-numbering and admin-facing listing; it is not a second copy of Epic 2's
  agent-facing reader.
- `UPDATE` is used only for `isActive`, `passedEvaluation` and `updatedUtc` — never for
  `fragmentText`, `kind`, `scope`, `accountId` or `version`, which are write-once at
  `INSERT`. This is an application-level discipline on top of a grant that technically
  permits broader `UPDATE`; a test asserts no SQL constant in this module can touch those
  five columns.
- SQL is module-level `SCREAMING_SNAKE` constants suffixed `_SQL`, parameters bind
  server-side, per `CLAUDE.md` § Naming — consistent with Epic 2's own
  `SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL` naming.
- A test enforces the admin/agent boundary structurally: nothing under `pacehr/agents/` or
  `pacehr/tools/` may import `pacehr/prompts/studio.py`. Combined with Epic 2's database
  grant, this makes "the agent never writes to it" (REQ-08-13) true at two independent
  layers — the network cannot reach the privilege even if the import boundary were ever
  breached, and vice versa.
- Security: every save records who made it; fragment bodies are prompt-engineering text,
  not clinical PHI, so no masking concern applies here, matching Epic 2's own note on this
  table.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/studio.py` implements the save operation as an `INSERT`-only write
      against `AI.promptFragment`, connected as `aiPromptAdmin`
- [ ] `tests/unit` asserts saving twice against the same `(kind, scope, accountId)`
      produces versions N and N+1, and the old row's `fragmentText` is unchanged
- [ ] `tests/unit` asserts a fragment kind outside the four recognized values is rejected
      before any SQL is issued, naming the four valid kinds
- [ ] `tests/unit` asserts no SQL constant in this module updates `fragmentText`, `kind`,
      `scope`, `accountId` or `version`
- [ ] An import-graph test asserts no module under `pacehr/agents/` or `pacehr/tools/`
      imports `pacehr/prompts/studio.py`
- [ ] `tests/integration` confirms a newly saved version has `isActive=0`,
      `passedEvaluation='PENDING_EVAL'` by default

---

### PEA-802 — Resolve prompt fragments by account precedence and version, failing closed on a tie

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-801, PEA-205 · **Satisfies:** REQ-08-11, REQ-08-16

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want fragment resolution to follow one deterministic, tested
precedence order — including failing closed on any tie — so that which prompt text
reached the model is never a matter of implementation accident, and any output can be
traced back to the exact fragment versions that produced it.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Resolution precedence is defined and tested: an account-specific fragment beats a global
one, the highest version wins, and a fragment resolves only when it is both active and has
passed evaluation (PEA-804). Today's legacy table has three competing dimensions — `type`,
`isUniversal`, `accountId` — with no documented winner; the real precedence order can only
be discovered by reading application code, and nothing tests it. This is the module Epic
4's `before_model` (PEA-404) already depends on, and Epic 7's `resolve_prompt` tool calls
the same way — one resolution implementation, not two.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Account-specific beats global, even at a lower version
  Given the `contract` fragment at scope "global" is active and passed at version 9
    And the `contract` fragment at scope "account", accountId 118, is active and passed
        at version 3
   When the resolver resolves the `contract` fragment for accountId 118
   Then version 3, the account-scoped fragment, is returned
    And version 9, the global fragment, is not used

Scenario: Highest version wins within the winning scope
  Given the `task` fragment at scope "global" has versions 3, 4 and 5
    And only versions 3 and 5 are active and passed
   When the resolver resolves the `task` fragment for an account with no account-scoped
        override
   Then version 5 is returned

Scenario: A fragment resolves only when both active and passed
  Given the `contract` fragment at scope "global", version 8, is active but has not
        passed evaluation
    And version 7 is active and passed
   When the resolver resolves the `contract` fragment
   Then version 7 is returned
    And version 8 is not considered a candidate

Scenario: Two equally-ranked candidates fail closed rather than being picked arbitrarily
  Given a data integrity fault has produced two rows sharing the same kind, scope,
        accountId and version, both active and passed
   When the resolver attempts to resolve that fragment
   Then the resolver does not return either row
    And it reports a precedence-conflict rather than guessing
    And the run this resolution serves aborts (REQ-04-05, Epic 4) rather than composing a
        prompt from an ambiguous choice

Scenario: An optional kind with no eligible candidate is omitted silently
  Given an account has no active, passed `specialty` fragment at either scope
   When the resolver resolves fragments for that account
   Then no `specialty` fragment is included in the result
    And resolution still succeeds for the required `contract` and `task` fragments

Scenario: The resolution result names the exact version behind every fragment returned
  Given resolution yields `contract` version 7 and `task` version 4 for an account
   When the resolver returns its result
   Then the result carries, for each resolved kind, its fragmentID, version and
        fragmentText — not bare concatenated text
    And this is what Epic 4's before_model (PEA-404) hashes alongside the composed
        prompt, and what Epic 10's trace records as which prompt fragments resolved
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `pacehr/prompts/resolver.py` implements the order as pure functions over rows already
  read by Epic 2's `PromptFragmentReader.active_fragments(...)` (PEA-205) — no direct
  database access inside the resolver itself, so it is cheap to unit test against
  in-memory fixtures: (1) defensively confirm `isActive` and `passedEvaluation = 'PASSED'` on every
  candidate, even though the reader is expected to have already filtered to them; (2) for
  each required or present kind, prefer `scope='account'` matching the caller's
  `accountId`, falling back to `scope='global'`; (3) within the winning scope, take the
  highest `version`; (4) `specialty` and `template_override` are optional — no candidate
  is a silent omission, never an error; a missing `contract` or `task` is the one hard
  failure, surfaced to the caller as a failure the caller turns into an abort, never a
  guess.
- **Known schema limitation, stated once, here:** `AI.promptFragment` keys a fragment on
  `(kind, scope, accountId, version)` only (Epic 2, PEA-205) — there is no `specialityId`
  or `templetId` column. This resolver therefore cannot select a different `specialty` or
  `template_override` fragment per specialty or per template; at most one of each
  resolves per account and applies uniformly. This is a property of the schema this story
  is built against, not a choice this story makes.
- The tie / data-integrity case is defense in depth behind Epic 2's
  `UNIQUE (kind, scope, accountId, version)` constraint; this code path exists for the
  case where that invariant is ever violated — a manual data fix, a replication artifact
  — and it fails closed rather than choosing arbitrarily.
- This module is the single resolution implementation. Epic 4's `before_model` (PEA-404)
  already lists this story as a dependency, and Epic 7's `resolve_prompt` tool
  (REQ-07-06) calls it too; neither reimplements precedence.
- The `contract` kind's resolution key carries no dimension beyond scope, account and
  version — exactly like every other kind in this schema — so by construction it cannot
  vary along a template or task axis. This is the mechanism behind PEA-806's byte-for-byte
  claim; this story owns the mechanism, PEA-806 owns the content and the reason.
- Performance: resolution reads a handful of rows — fragments are small and change
  rarely, and Phase 1 explicitly defers caching (REQ-11-13). No cache is introduced here;
  a correct, uncached read is the Phase 1 bar.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/resolver.py` implements the precedence order as pure functions over
      rows read via Epic 2's `PromptFragmentReader.active_fragments(...)`
- [ ] `tests/unit/test_prompt_resolver.py` covers: account beats global at a lower
      version; highest version wins within a scope; active+passed both required; the tie
      case fails closed; an absent optional kind resolves silently; a missing required
      `contract` or `task` is reported as a hard failure
- [ ] Resolution result is a structured object carrying `(kind, fragmentID, version,
      fragmentText)` per resolved fragment — `tests/unit` asserts it is never bare
      concatenated text
- [ ] No caching introduced — reviewed against REQ-11-13 and `CLAUDE.md` § Singletons

---

### PEA-803 — Migrate the legacy AI.prompt table once and retire it from the runtime path

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-801, PEA-805, PEA-806 · **Satisfies:** REQ-08-09

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want a single, re-run-safe migration that reads every row of the
legacy `AI.prompt` table exactly once and seeds it forward into versioned fragments, so
that the cutover happens on a known day, cannot be repeated by accident, and never leaves
the agent depending on the old table again.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The legacy table holds a handful of live rows, including at least one whose entire body is
the literal text `sdwdxs` — visible proof that the legacy free-text column has never had a
content check of any kind, because an in-place-editable blob has no way to enforce one.
Migration is the one moment those rows are read; after it runs, `AI.prompt` is retained
only as a historical record, and no runtime code path — not the agent, not `before_model`,
not the `resolve_prompt` tool — reads it again. This is also the moment the contradictory
NA/N-A instructions described in this epic's goal are confronted directly: migration does
not get to silently pick a winner between two contradictory legacy rows, because that
would just relocate today's ambiguity into tomorrow's "version 1," rather than removing
it.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Every legacy row is read exactly once and mapped forward
  Given rows exist in the legacy `AI.prompt` table
   When the migration runs
   Then every row is either mapped into a new `AI.promptFragment` version or explicitly
        logged as skipped, with a reason
    And each fragment the migration creates records the legacy promptId it came from

Scenario: A junk row is not silently promoted
  Given a legacy row's entire body is the text "sdwdxs"
   When the migration runs
   Then this row is not written forward as an active fragment
    And it is logged as skipped, with the reason and the source promptId, for a human to
        confirm

Scenario: A live contradiction across legacy rows is surfaced, never auto-resolved
  Given legacy row promptId 12, template family "H&P Initial", instructs "Always return
        \"NA\" if you are not sure about your response or if the information is not
        specified"
    And legacy row promptId 15, same template family, instructs the model never to write
        "N/A"
   When the migration runs
   Then the migration does not choose one instruction over the other automatically
    And both source rows are recorded against the same draft `contract` candidate for an
        AI/clinical admin to resolve and finalize through the Prompt Studio (PEA-801,
        PEA-806) before that fragment is marked active

Scenario: Migrated fragments are usable on day one without a first evaluation cycle
  Given the migration has just completed
   When an AI/clinical admin reviews the newly created version-1 fragments
   Then each carries isActive = 1 and passedEvaluation = PASSED, set by the migration itself
    And the reason is recorded once, here: a version-1 fragment has no prior version to
        compare against, so Epic 10's replay-based evaluation (PEA-1007), which compares
        a candidate against an incumbent, has nothing to replay it against

Scenario: The migration will not run twice
  Given the migration has already completed once
   When it is invoked again
   Then it makes no changes and reports that migration has already run
    And no duplicate version-1 fragments are created

Scenario: No runtime code reads the legacy table after cutover
  Given the migration has completed
   When the codebase is scanned for references to AI.prompt outside the migration module
   Then none are found
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `pacehr/prompts/migration.py` implements one class, `MigrateLegacyPrompts`, with one
  public `run()` method, per `CLAUDE.md` § Code standard (one class per surface, one
  public method). This is a one-time data migration, distinct from Epic 2's schema
  migration `migrations/sql/0004_create_prompt_fragment.sql` (PEA-205), which must already
  have run.
- Reads via a single `SELECT_LEGACY_PROMPTS_SQL` constant (per `CLAUDE.md` § Naming); the
  underlying access path is the project's Azure SQL driver (`mssql_python`, per
  `00-langchain-api-truth.md` §7) — a one-off script needs no `asyncio.to_thread` wrapper,
  that pattern is for the request path, not a migration.
- Writes go through PEA-801's write module (`pacehr/prompts/studio.py`), connected as
  `aiPromptAdmin` like any other save — `INSERT` only for `fragmentText`, `kind`, `scope`,
  `accountId` and `version` — migration gets no back door around the versioning rules it
  is seeding into existence for everyone else.
- Idempotency guard: the migration checks whether any fragment already carries a non-null
  migration-provenance marker before writing anything; on a second invocation it detects
  prior completion and no-ops rather than re-inserting.
- Splitting each legacy row's free-text body across the four kinds is a one-time
  content-classification exercise, not a general-purpose parser: shared boilerplate
  repeated across legacy rows becomes the `contract` candidate (finalized in PEA-806); the
  remainder becomes `task`, `specialty`, or `template_override` candidates, scoped
  `global` unless the legacy row was already account-specific. Ambiguous or contradictory
  input is logged for a human decision, per the scenario above, never guessed.
- The bootstrap exemption from the promotion gate (PEA-804) — version-1 fragments are
  seeded `isActive = 1`, `passedEvaluation = 'PASSED'` directly — is stated once, here, and
  nowhere else in this epic, because this is the only place it is legal: every version
  after version 1 goes through the ordinary save-then-promote path with no exemption.
- After cutover, `AI.prompt` is retained, unindexed by the application, as a historical
  record only. Dropping the table is out of scope — nothing here requires deletion, and
  deleting audit-adjacent history is a separate decision this story does not make.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/migration.py` reads legacy `AI.prompt` exactly once, via one
      documented query
- [ ] Each fragment the migration creates records its source legacy `promptId`
- [ ] A legacy row whose body is content-free junk is excluded from being written forward
      as an active fragment; `tests/unit` covers this case
- [ ] A detected content contradiction across legacy rows in the same template family is
      logged for human resolution, never auto-resolved; `tests/unit` covers this case
- [ ] Version-1 fragments are created with `isActive=1`, `passedEvaluation='PASSED'`, with the
      bootstrap reason recorded in the migration module's own docstring, not silently
- [ ] Running the migration a second time is a safe no-op; `tests/unit` asserts no
      duplicate rows are created
- [ ] `tests/integration` confirms no module outside `pacehr/prompts/migration.py`
      queries `AI.prompt`
- [ ] A repository-wide search confirms `AI.prompt` is referenced nowhere else in the
      tree outside this module and its tests

---

### PEA-804 — Block a prompt fragment from resolving until it passes evaluation

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-801, PEA-802 · **Satisfies:** REQ-08-12, REQ-08-15

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want my own edit blocked from taking effect until it has passed
evaluation, so that I cannot accidentally roll out a regression to every clinician using
this template the moment I save it.

#### 2. Business Context & Problem Statement (Why are we doing this?)

An edit saves as a new version that cannot resolve at runtime until it passes evaluation —
the deterministic metrics that decide pass or block (schema validity, validator pass rate,
evidence-bound rate, exact match against the accepted value, token/latency deltas) belong
to Epic 10's replay harness and gate (PEA-1007, PEA-1008); the shared metric and
reason-code vocabulary they read from is Epic 10's PEA-1004. This story owns only the gate
as it touches `AI.promptFragment` itself: the `passedEvaluation` state (Epic 2, PEA-205) a
version must carry before an admin's activation has any effect, and the guarantee that
nothing — not the admin, not the agent — can set that state by hand. The column holds the
gate's verdict verbatim — `PENDING_EVAL` at insert, then `PASSED`, `BLOCKED` or
`INCOMPLETE` — so a version nobody has evaluated and a version that was evaluated and
failed stay distinguishable to the admin who has to explain why neither reaches a
clinician. This story gates on one of those four values: `PASSED` resolves, and every
other state does not.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A fresh, unevaluated save cannot resolve, even if marked active
  Given an AI/clinical admin saves version 8 of the `contract` fragment at scope "global"
    And immediately marks it isActive = 1
   When the resolver (PEA-802) resolves the `contract` fragment
   Then version 8 is not returned, because passedEvaluation is still PENDING_EVAL
    And the previously active, passed version 7 is returned instead

Scenario: A version Epic 10 verdicts BLOCKED is refused promotion
  Given version 8 of the `contract` fragment has been replayed against version 7 by
        Epic 10's evaluation gate (PEA-1008)
    And the verdict is BLOCKED, naming evidence-bound rate as the failing metric
   When an AI/clinical admin attempts to set isActive = 1 on version 8
   Then the activation is rejected
    And the rejection names "evidence-bound rate" as the metric the verdict failed on
    And passedEvaluation remains BLOCKED

Scenario: A version Epic 10 verdicts PASSED can be promoted
  Given version 8 has been replayed by Epic 10's evaluation gate (PEA-1008)
    And the verdict is PASSED
   When Epic 10's callback records the verdict
   Then passedEvaluation becomes PASSED on version 8
    And an AI/clinical admin can now set isActive = 1
    And version 8 becomes the version the resolver returns
    And version 7 remains stored, inactive, and fully retrievable

Scenario: An incomplete evaluation is not a pending one, and neither resolves
  Given version 8 carries passedEvaluation = INCOMPLETE after a replay that did not finish
   When the resolver (PEA-802) resolves the `contract` fragment
   Then version 8 is not returned
    And the admin listing shows INCOMPLETE, not PENDING_EVAL, so the replay is known to
        have been attempted and to have failed to complete

Scenario: passedEvaluation cannot be set by hand
  Given an AI/clinical admin's available write operations on a fragment version
   When those operations are inspected
   Then setting passedEvaluation directly is not one of them
    And the only path to passedEvaluation = PASSED is the callback Epic 10's evaluation
        gate (PEA-1008) invokes with its verdict
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Read-side half: PEA-802's resolver candidate filter already requires `isActive` and
  `passedEvaluation = 'PASSED'`; this story's contribution is pinning that filter down as a
  gate with its own tests, rather than an incidental side effect of the filter's phrasing.
  The comparison is against `PASSED` and never against "not blocked", so a state added
  later fails closed instead of resolving by default.
- Write-side half: `pacehr/prompts/studio.py`'s activation method (PEA-801) refuses to
  set `isActive = 1` unless `passedEvaluation` is `'PASSED'`, and no public method in that
  module accepts `passedEvaluation` as caller-supplied input. The only writer of
  `passedEvaluation` is a narrow callback Epic 10's evaluation gate (PEA-1008) invokes with
  its verdict, which this story depends on but does not implement.
- This is the module boundary that makes "promotion of a fragment that fails evaluation
  is blocked" (REQ-08-15) a property of the code rather than a policy someone has to
  remember: the write surface has no argument that lets an admin, or the agent, set
  `passedEvaluation` directly.
- The bootstrap exception is PEA-803's migration, which is the one caller allowed to
  insert a row already `isActive = 1` and `passedEvaluation = 'PASSED'`; that exception is
  documented there, not reintroduced here.
- Security: rejecting an activation attempt must still record who attempted it and what
  metric blocked it, so a pattern of blocked promotions is itself visible, not just the
  individual rejection.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/studio.py`'s activation method rejects `isActive=1` unless
      `passedEvaluation='PASSED'`
- [ ] No public write method accepts `passedEvaluation` as a parameter; `tests/unit`
      asserts only Epic 10's evaluation-gate callback path can set it
- [ ] `tests/unit/test_promotion_gate.py` covers: a `PENDING_EVAL` version is not
      returned by the resolver even when marked active; a `BLOCKED` version stays blocked
      from activation; an `INCOMPLETE` version is refused activation and reads back as
      `INCOMPLETE` rather than `PENDING_EVAL`; a `PASSED` version activates and resolves
- [ ] Rejection surfaces the specific failing metric name from the verdict, not a generic
      failure
- [ ] Rejected activation attempts are attributable to who attempted them, per
      `CLAUDE.md`'s audit posture

---

### PEA-805 — Give the task fragment a required, validated context-placeholder contract

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-801 · **Satisfies:** REQ-08-08

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want the task fragment to declare exactly which per-encounter
values it expects — task type, template name, place of service, date of service, and the
slot manifest — so that a fragment I save can never silently omit a value the agent needs
to compose a complete prompt.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The composed prompt must include the task type, the template name, the place of service,
the date of service, and the full slot manifest built from the template configuration —
for example, the reference shape `TASK: extract · Template: H&P Initial · POS: SNF · DOS:
2026-09-22` followed by the manifest. Today this is raw string substitution —
`.Replace("<<encounterPOS>>", req.pos)` — with no escaping and no check that a placeholder
actually resolved; production has shipped a prompt containing the literal, unreplaced text
`"Dynamic Location"` where a Place of Service value belonged. Because `AI.promptFragment`
has no per-template column (Epic 2, PEA-205), one `task` fragment must serve every
template through parametrized placeholders rather than one row per template — which makes
this story's validation the only thing standing between a well-formed fragment and a
silently broken one. This story does not perform the substitution — Epic 4's
`before_model` (PEA-404) does that at request time, and separately aborts the run if a
required slot is still unfilled (REQ-04-05). This story's job is earlier and narrower:
validate, the moment a task fragment is *saved*, that it declares every placeholder it
must carry.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A well-formed task fragment declares every required placeholder
  Given an AI/clinical admin saves a `task` fragment
    And its fragmentText declares the placeholders task_type, template_name,
        place_of_service, date_of_service, and slot_manifest
   When the save is validated
   Then the save succeeds as a new version

Scenario: A task fragment missing the slot manifest placeholder is rejected
  Given an AI/clinical admin saves a `task` fragment
    And its fragmentText declares task_type, template_name, place_of_service and
        date_of_service but not slot_manifest
   When the save is validated
   Then the save is rejected
    And the rejection names slot_manifest as the missing placeholder
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Extends PEA-801's save path in `pacehr/prompts/studio.py`: when `kind == "task"`, the
  fragmentText is checked against `TASK_FRAGMENT_REQUIRED_PLACEHOLDERS`, a module-level
  constant — `frozenset({"task_type", "template_name", "place_of_service",
  "date_of_service", "slot_manifest"})` — never a bare literal at the check site, per
  `CLAUDE.md` § Numbers.
- The `slot_manifest` placeholder's actual content (the per-field descriptions) is Epic
  3's construction (REQ-03-04, REQ-03-05); this story only guarantees the task fragment
  has somewhere for it to land.
- This is authoring-time validation and is deliberately redundant with, not a replacement
  for, Epic 4's request-time unfilled-slot abort (REQ-04-05): this check catches the
  defect when the fragment is saved; that one catches it, as the last line of defense, if
  something still slips through.
- No UI/UX surface is built here — the rejection message is a return value the Prompt
  Studio (out of scope, see epic Scope) renders; this story's contract is the message's
  content (names the missing placeholder), not its presentation.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/studio.py` validates a `task`-kind save against
      `TASK_FRAGMENT_REQUIRED_PLACEHOLDERS`
- [ ] `tests/unit` covers: all five placeholders present (accepted); `slot_manifest`
      missing (rejected, names the missing placeholder)
- [ ] Rejection names the specific missing placeholder(s), never a generic error
- [ ] No bare literal placeholder names at the call site — module constant per
      `CLAUDE.md` § Numbers

---

### PEA-806 — Author the contract fragment as one byte-identical, auditable safety ruleset

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 8
**Depends on:** PEA-801, PEA-802 · **Satisfies:** REQ-08-01, REQ-08-02, REQ-08-03, REQ-08-04, REQ-08-05, REQ-08-06, REQ-08-07

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want the safety and epistemic rules every extraction must
follow to live in exactly one fragment whose resolved bytes are provably identical on
every encounter, so that I can show an auditor — or a clinical buyer evaluating the
product — that the model's non-negotiable rules never varied by template, specialty or
task.

#### 2. Business Context & Problem Statement (Why are we doing this?)

This is the fragment the epic goal describes. Today's `AI.prompt` row for the H&P Initial
family instructs, verbatim: *"Always return \"NA\" if you are not sure about your response
or if the information is not specified."* An audit of the same table found a second,
contradictory instruction telling the model never to write `N/A` — both active
simultaneously, with nothing in the data model saying which one binds. Under this design
there is exactly one resolved `contract` per account (PEA-802), so that specific
contradiction becomes structurally impossible rather than merely discouraged: the seven
rules below are that fragment's entire authored content, and REQ-08-03's replacement for
both `NA` readings is Epic 3's explicit `status` field — `FOUND`, `ABSENT`, or `ABSTAINED`
— so "not documented" and "the model was guessing" are finally two different values
instead of the same three letters.

Two properties matter about this fragment's resolved text, and they are different claims.
First, it is cacheable: because `AI.promptFragment` keys every kind, including `contract`,
on `(kind, scope, accountId, version)` alone (PEA-802) — no task or template dimension —
the same account resolves the same bytes on every call regardless of which template or
task is running, which is what makes the text eligible for reuse rather than
re-transmission on every request. Second — the one that matters to a clinical buyer — it
makes the safety rules provably identical on every encounter: an auditor does not have to
take it on trust that two encounters got the same treatment, they can diff the bytes and
see it.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Slot discipline — fill only what the manifest lists
  Given the resolved `contract` fragment's text
   Then it contains the instruction "Fill only the slots listed in the SLOT MANIFEST.
        Never invent a slot."

Scenario: Every found value must quote its source
  Given the resolved `contract` fragment's text
   Then it contains the instruction "Every FOUND value must quote the exact substring it
        came from."

Scenario: The contract distinguishes not-documented from not-sure, and prefers abstaining
  Given the resolved `contract` fragment's text
   Then it instructs that when the note is silent on a slot, status is ABSENT
    And it instructs that when text exists but the model is unsure, status is ABSTAINED
    And it states plainly that abstaining is correct and a guess is worse than an
        abstention
    And these three literal values match Epic 3's `ExtractedValue.status` field exactly

Scenario: Units are reported verbatim, never converted
  Given the resolved `contract` fragment's text
   Then it contains the instruction "Report units exactly as written. Never convert."

Scenario: Arithmetic is delegated to tools, never performed by the model
  Given the resolved `contract` fragment's text
   Then it contains the instruction "Never calculate. Use resolve_date and compute_bmi."
    And it names the same two tools Epic 7 exposes for exactly this purpose (REQ-07-01,
        REQ-07-02)

Scenario: A section slot must not duplicate a child slot's value
  Given the resolved `contract` fragment's text
   Then it contains the instruction "A section slot summarises its child slots; do not
        duplicate a child value into it."

Scenario: No JSON-mechanics instruction survives in the shipped text
  Given the resolved `contract` fragment's text
   When it is scanned for JSON-mechanics language
   Then it contains no instruction about JSON validity, key names, or brace matching
    And it contains no instance of the literal tokens "NA" or "N/A"

Scenario: The resolved contract is byte-for-byte identical across two different templates
  Given accountId 118 has exactly one active, passed `contract` fragment at scope
        "account", version 3
   When the resolver resolves the `contract` fragment for an encounter using template
        "H&P Initial"
    And separately for an encounter using a different template, "Cardiology Follow-up",
        same account
   Then both resolutions return identical bytes
    And the only way those bytes change is a new version being authored and promoted
        through the Prompt Studio (PEA-801, PEA-804)
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- The version-1 text is authored as a reviewed asset in this repository —
  `pacehr/prompts/seeds/contract_v1.txt` — not typed directly into a runtime edit surface.
  PEA-803's migration loads it as the seed for the first `contract` version. After that
  seed, the only way this text changes is a save through the Prompt Studio write path
  (PEA-801) followed by promotion through the gate (PEA-804); this seed file is never
  edited in place again — doing so would reintroduce the exact overwrite-with-no-version
  failure mode this epic exists to remove.
- Content is verified by presence/absence assertion against the resolved fragment's text —
  this is a content test, not a behavioral eval. Whether the model actually obeys these
  rules on real notes is Epic 10's evaluation gate (PEA-1007, PEA-1008), not this story.
- REQ-08-03's `ABSENT` / `ABSTAINED` language must name the same literal values as Epic
  3's `ExtractedValue.status: Literal["FOUND", "ABSENT", "ABSTAINED"]`; asserting the
  fragment text contains no `"N/A"` or `"NA"` token is a direct, faithful test of this
  requirement, not an invented one — it is what makes the historical contradiction
  unrepresentable in the new text.
- REQ-08-05's tool names (`resolve_date`, `compute_bmi`) are Epic 7's tools (REQ-07-01,
  REQ-07-02); this story only asserts the contract instructs their use by name — it does
  not implement them.
- A future edit that weakens or removes one of these seven lines is caught by Epic 10's
  evaluation gate (PEA-1007, PEA-1008) — for example, a real-shaped edit that dropped
  tokens 13% by deleting the quote-the-source-text requirement also dropped the
  evidence-bound rate 16.7 points, and PEA-1008's own acceptance criteria block exactly
  that edit — before promotion (PEA-804), not by this story's content test, which only
  guards the version this story ships.
- Performance: the reference shape of this text is small (roughly 1,700 characters,
  ≈436 tokens, per the design corpus) — no size concern for Phase 1.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/seeds/contract_v1.txt` holds the authored version-1 text, reviewed
      like any other repository change
- [ ] `tests/unit/test_contract_fragment_content.py` asserts presence of all seven
      instructions, one assertion per REQ-08-01 through REQ-08-07
- [ ] The same test asserts absence of `"N/A"`, `"NA"`, and any JSON-validity /
      brace-matching / key-name language
- [ ] `tests/unit` asserts two resolutions of the same account's `contract` fragment
      against two different templates return byte-identical text
- [ ] DoD note recorded in the test module: a later edit weakening any of these seven
      lines is Epic 10's evaluation gate (PEA-1007, PEA-1008) to catch before promotion
      (PEA-804), not this test's job

---

### PEA-807 — Roll back a prompt fragment by promoting an earlier version; compare two side by side

**Type:** Story · **Epic:** E8 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-801, PEA-804 · **Satisfies:** REQ-08-14

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want to make an earlier version of a fragment current again
with one action, and see two versions side by side before I do, so that undoing a bad
prompt is as fast as making the mistake was, and I never have to reconstruct the old
wording from memory.

#### 2. Business Context & Problem Statement (Why are we doing this?)

A bad prompt is reverted by making an earlier version current, never by editing text back.
Editing text back would itself be an undated, unversioned overwrite — indistinguishable
from the exact defect this epic exists to remove — and it would destroy the record that
the bad version ever existed. Rollback is therefore not a text operation at all: it is a
pointer operation over rows PEA-801 already made immutable. A/B comparison exists for the
step before that decision: seeing two versions' text side by side without committing to
either.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Rolling back promotes an old version rather than rewriting text
  Given `contract` version 8 passed evaluation and is currently active at scope "global"
    And version 7 was active before it and remains stored, unchanged
   When an AI/clinical admin rolls the `contract` fragment back to version 7
   Then version 7 becomes the version the resolver (PEA-802) returns
    And version 8's row and fragmentText are untouched — nothing was edited, only which
        version is current changed
    And the rollback is recorded as an event naming who performed it and when

Scenario: Rolling back to a version that already passed evaluation needs no new cycle
  Given version 7 was itself active and passed before version 8 replaced it
   When the admin rolls back to version 7
   Then version 7 resolves immediately
    And no new evaluation cycle is required, because version 7 already passed one when
        it was first promoted

Scenario: Rolling back to a version that never passed evaluation is refused
  Given version 6 exists but passedEvaluation never reached PASSED
   When an admin attempts to roll the `contract` fragment back to version 6
   Then the rollback is refused
    And the fragment resolved remains version 7

Scenario: Comparing two versions never changes which one is live
  Given `contract` versions 7 and 8 both exist
   When an AI/clinical admin requests an A/B comparison of versions 7 and 8
   Then both versions' full fragmentText, version number, and passedEvaluation status
        are returned together
    And neither version's isActive flag is changed by requesting the comparison
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `pacehr/prompts/studio.py`'s `RollbackFragment.run()` sets `isActive = 1` on the target
  version and `isActive = 0` on whatever was active before it, inside one transaction; it
  never reads or writes the target version's `fragmentText`.
- Rollback reuses PEA-804's activation gate exactly — a rollback target must have
  `passedEvaluation = 'PASSED'` — there is no rollback-specific bypass. The one exception is that
  a version already passed in the past keeps that status; it is never re-evaluated solely
  because it is being restored.
- `CompareFragmentVersions.run()` is read-only and lives as a separate public method from
  `RollbackFragment.run()`, per `CLAUDE.md` § Code standard (one class per surface, one
  public method) — the comparison surface must never be able to change which version is
  active as a side effect of being called.
- The rollback event's "who and when" is the same shape as any other version-creating
  action from PEA-801 — no new audit mechanism is invented for this story.
- Performance/UI-UX: comparison returns both versions' full text in one call; at the
  reference fragment size (roughly 1,700 characters for a `contract` fragment) this is
  negligible payload, no pagination or truncation is needed in Phase 1.

#### 5. Definition of Done (DoD) Checklist

- [ ] `pacehr/prompts/studio.py` implements `RollbackFragment` as an activation-pointer
      change only; `tests/unit` asserts the restored version's fragmentText is
      byte-identical to what it was before the rollback
- [ ] `tests/unit` covers: rollback to a previously-passed version succeeds without a new
      evaluation cycle; rollback to a never-passed version is refused
- [ ] `CompareFragmentVersions` is read-only; `tests/unit` asserts calling it changes
      neither version's `isActive` flag
- [ ] Rollback records who performed it and when, per `CLAUDE.md`'s audit posture
- [ ] No bare literals for version-role labels ("previous", "target") — named parameters,
      per `CLAUDE.md` § Numbers
