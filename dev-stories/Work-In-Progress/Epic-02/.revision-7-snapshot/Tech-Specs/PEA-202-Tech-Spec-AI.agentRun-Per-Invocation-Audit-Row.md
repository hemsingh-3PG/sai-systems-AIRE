# PEA-202 Tech Spec — AI.agentRun (Per-Invocation Audit Row)

**Epic:** E2 — Data Layer · **Story:** PEA-202 · **Phase:** 1
**Depends on:** PEA-201 · **Satisfies:** REQ-02-03, REQ-02-07, REQ-02-09
**Epic estimate:** 3 points · **Audited estimate:** 5–8 points (see §6)
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — audited against the live codebase, evidence-backed, ready for grooming
**Build target:** TypeScript/Node.js

**Revision:** 7 (2026-09-30) — supersedes Revision 6. Snapshots: `Epic-02/.revision-6-snapshot/`,
`Epic-02/.revision-5-snapshot/`.

> ✅ **Revision 7 — three owner decisions close this epic's long-running ambiguities.**
>
> **1. The AI engine is Node.js, and nothing else.** The repository
> `Saisystems-PaaS/PacEHR/PacEHR_AI` was created on 2026-09-30 and is empty (one commit, a
> template README). It is a **true greenfield Node/TypeScript build**. There is no port
> source and no prior implementation in any language — earlier revisions of this document
> said otherwise and were wrong. The *logic* in this spec — every table, column, constraint,
> vocabulary, bound and acceptance criterion — carries over unchanged; only the runtime is
> Node.
>
> **2. Everything belonging to the new AI engine lives in `pacEHR_AI/` — including its DDL.**
> The `AI.*` schema, the numbered migration scripts and the migration runner are **owned by
> the AI repository**, not by `pacEHR_API`'s SSDT project. Revision 6 retargeted this story's
> DDL to SSDT release folders; **that is reversed.** `migrations/sql/0001…0006` ship in
> `pacEHR_AI/` and reach a database through `MigrationRunner.applyPending()`.
>
> **3. Existing AI code stays where it is.** `AIController`, `AIPromptServices`, `AI.prompt`,
> `usp_getPrompt` and the Angular `ai-prompt` admin feature are **not migrated**. Only new AI
> work goes in the new repository. Consequences are noted per story — the largest lands on
> PEA-205, whose premise was replacing a shipped feature.
>
> **What this costs, stated plainly.** A greenfield repository owning its own schema means the
> AI tables are invisible to the SSDT model, so nothing validates at build time that a
> reference into `Template.*` or `Encounter.*` still resolves. That guard has to be replaced
> by an integration test against a real database — see each story's verification section.

> **Read this first.** This spec is not a restatement of the epic. Every DDL fragment, module
> path and grant statement in the epic story has been re-derived against what is actually on
> disk. Where the epic is right, this spec says so and cites the proof. Where it is wrong,
> §1 says exactly what is wrong.
>
> **Build target.** The AI engine is a **TypeScript/Node.js** service, ported from the AI service `pacEHR_AI/`, in a new
> repository that does not yet exist; the runtime chain is Angular → .NET Web API →
> TypeScript AI service → Azure OpenAI. The DDL, acceptance criteria and all SQL in this spec
> are language-neutral — the table lives in the same SQL Server instance regardless of which
> service writes it. Only the runner/driver/repository/test layer is expressed in TypeScript
> terms below. The reference design corpus is unmodified.
>
> **DDL and gap analysis.** The table name `AI.agentRun` is
> **confirmed canonical** (Finding 10, §2.8), and an independent audit
> ([GAPS.md](solution-doc:5089)) has surfaced **four defects that land directly on this
> table** — Gaps 3, 9, 12 and 17, recorded as Findings 11–14 below. Gap 3 is the serious
> one: as specified, this table **cannot store the audit row for a blocked run**, which is
> the exact case the story exists to guarantee.

---

## 1. Findings — what the audit changed

| # | Finding | Severity | Effect on this story |
|---|---------|----------|----------------------|
| 1 | The `encounterID` datatype question the epic left open is **resolved: `INT IDENTITY(1,1) NOT NULL`** | ✅ closed | DDL below is now final, not provisional |
| 2 | **Token counts are asserted by the browser, not measured by the server** | 🔴 critical | This is the story's real justification — and the epic understates it |
| 3 | **`modelDeployment` would record a compile-time literal**, not a deployment name | 🟠 high | Column is near-useless until §3.3 is done |
| 4 | **`latencyMs` cannot be populated** — nothing times the model call today | 🟠 high | New instrumentation, not just a column |
| 5 | **The host service is specified but unbuilt.** **src/repositories/agentRunWriter.ts** belongs in the new TypeScript repository, and the **foundation layer is its hard prerequisite** — it supplies the `database` singleton this class calls. No Node repository, skeleton, pipeline or backlog exists yet | 🟡 sequencing | Not a language question. Sequence the foundation first; DDL unaffected |
| 6 | **No database CI/CD.** No pipeline deploys schema | 🔴 blocker | Ship path is manual; inherited from PEA-201 |
| 7 | **`CHAR(64)` is outside the approved datatype list** | 🟡 medium | Use `VARCHAR(64)`; see §3.2 |
| 8 | **`GRANT` and `CREATE ROLE` have zero precedent** in 2,834 SQL files | 🔴 blocker | Grants cannot be shipped through the current mechanism |
| 9 | **`DEFAULT SYSUTCDATETIME()` has zero precedent** in table DDL | 🟡 medium | Established form is `DEFAULT (getutcdate())`; see §3.2 |
| 10 | `agentRun` name is **free in the database**, and the cross-document collision is now **resolved in its favour** | ✅ closed | No rename. [epic-02-data-layer.md](solution-doc:5077) carries the DDL; Epics 9, 10 and GAPS.md all say `agentRun` — §2.8 |
| 11 | 🔴 **A guard-blocked run cannot write its audit row.** `promptHash` and `modelDeployment` are `NOT NULL`, but a run blocked in `before_agent` has neither — and `PEA-1003` explicitly requires them null ([GAPS.md](solution-doc:5089) Gap 3) | 🔴 **blocker** | **Directly contradicts this story's own acceptance criteria.** The fail-closed guarantee dies on a column constraint. DDL change required — §3.2 |
| 12 | 🔴 **The outcome vocabulary is split, and one value has no producer.** This story's `CHECK` says `guard_blocked`; Epics 4 and 9 pass `BLOCKED`. The value `error` is produced by nothing, anywhere ([GAPS.md](solution-doc:5089) Gap 9) | 🔴 **blocker** | Every blocked run violates the `CHECK` and the insert fails. Vocabulary must be closed once, centrally — §3.2 |
| 13 | **No `reasonCode` or `failureMode` column** — a blocked run records *that* it was blocked, never *why* ([GAPS.md](solution-doc:5089) Gap 3) | 🟠 high | Add the column; without it the audit trail cannot distinguish an injection block from a validator crash |
| 14 | **No `templetID` and no config version on the row** — a template edited after the fact makes historical rows uninterpretable ([GAPS.md](solution-doc:5089) Gap 12) | 🟠 high | Add both. This is cheap now and unrecoverable later — the rows are append-only and years-lived |
| 15 | **No transaction primitive exists.** `PEA-103` is single-statement, fresh-connection-per-call; this story requires the audit row to share a transaction with the field commit ([GAPS.md](solution-doc:5089) Gap 17) | 🔴 **blocker** | An Epic 01 gap, surfacing here. `PEA-1003`'s "audit write failure prevents the commit" is unimplementable as specified — §3.3 |

---

### Finding 2 (detail) — the audit column this table replaces is client-controlled

This is the single most important fact in this spec, and it is the reason `AI.agentRun`
should be built even if everything else in Epic 02 slips.

Token usage is captured in the **browser**, parked in `localStorage`, read back by a
component, and POSTed to the API, which inserts it verbatim.

**Step 1 — the browser stores what the model streamed back:**

`PacEHR/src/app/core/services/open-ai.service.ts` — lines 277, 351 and 414 each contain:

```ts
if (json.usage) { localStorage.setItem('OpenAIStreamTokenData', JSON.stringify(json.usage)); }
```

**Step 2 — three separate components read it back and send it:**

| Component | Line |
|-----------|------|
| `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` | 618 |
| `PacEHR/src/app/features/dashboard/add-rounding-notes/add-rounding-notes.component.ts` | 1009 |
| `PacEHR/src/app/features/encounter-list/encounter-form/ai-summary-prompt/ai-summary-prompt.component.ts` | 229 |

each passing `prompt_tokens: tokenData?.prompt_tokens ?? 0`.

**Step 3 — the server inserts it without checking:**

`pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditAILogs.sql` accepts
`@prompt_tokens`, `@completion_tokens`, `@total_tokens` as parameters and inserts them
directly. Nothing is computed server-side.

**Four consequences, in order of severity:**

1. **The numbers are writable from any browser console.** `localStorage.setItem` is not a
   trusted channel. Cost and usage reporting built on `Log.AILogs` token columns is
   unauditable.
2. **If the tab closes mid-stream, no audit row is written at all.** The POST never fires.
   There is no server-side record that the invocation happened. For a clinical AI feature
   this is the defect that matters most — the absence is silent.
3. **`⁠0` and "not measured" are indistinguishable.** `?? 0` collapses "the model reported
   zero" into "we lost the data." Same failure class as the `NA` collapse PEA-203 exists to fix.
4. **Prompt and response text round-trip through the browser** to be logged, widening the
   PHI surface beyond what a server-side write would need.

**Recommendation:** raise this as a **standalone defect ticket** against the current AI
logging path, independent of Epic 02. It is a live data-integrity issue in shipped code, and
it should not wait on a new schema to be acknowledged. `AI.agentRun` is the fix; the defect
ticket is the record that the problem predates the fix.

---

### Finding 3 (detail) — `modelDeployment` records a constant

The epic specifies `modelDeployment NVARCHAR(100) NOT NULL` so that a future model swap is
visible in the audit trail. Today it would record the same string on every row.

All LLM calls live in `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`, which uses a
raw `HttpClient` from `IHttpClientFactory` — **there is no Azure OpenAI SDK in the project**.
Four methods make calls:

| Method | Lines |
|--------|-------|
| `GetOpenAICompletionAsync` | 156–198 |
| `StreamOpenAITemplateCompletionAsync` | 200–259 |
| `StreamOpenAICompletionWithDataAsync` | 261–312 |
| `StreamOpenAICompletionAsync` | 314–363 |

In each, the model is the hardcoded literal `"gpt-4o"` with `temperature = 0`, at lines
**176, 230, 282 and 334**. Credentials come from DB settings (`OPENAI_API_KEY`,
`OPENAI_API_URL`) read via `usp_getAppSettingsForMultipleAsync`, with a config fallback key
`APIkeySettings:openAIapiKey`. There is no Key Vault and no managed identity.

The column is still correct to create — it is the audit contract — but it delivers no value
until the model name is resolved from configuration at call time. That work is listed in
§3.3 and is part of why this story is larger than 3 points.

> 🔴 **Separate security finding, out of scope but must not be dropped:** a live-looking API
> key appears committed in `pacEHR_API/PacEHR.API/appsettings.json`. Verify and rotate. Raise
> as its own security ticket — do not fold it into this story.

---

### Finding 4 (detail) — nothing measures latency today

`latencyMs` has no source. A grep of `AIPromptServices.cs` for `Stopwatch`,
`ElapsedMilliseconds` and `latency` returns **zero matches**. The four call sites listed above
issue the HTTP request and stream the response without timing it.

Populating this column means wrapping each of the four methods in a stopwatch and threading
the elapsed value into the audit write. That is a real change to shipped runtime code in a
class that handles every AI call in the product — it needs regression coverage, not just a
column.

---

### Finding 5 (detail) — the TypeScript host and its foundation layer are the gate

The reference design's technical section specifies a module with a constant
`INSERT_AGENT_RUN_SQL` and a `class AgentRunWriter.record()`. **The build target is
TypeScript/Node.js** — a repository not yet created, built greenfield in `pacEHR_AI/`. The equivalent
artefact is **src/repositories/agentRunWriter.ts**, exporting a class `AgentRunWriter` whose
`record()` method calls `database.execute()` on the module-level `database` singleton from
**src/core/database.ts**. The SQL constant retains its SCREAMING_SNAKE name:
`INSERT_AGENT_RUN_SQL`. No prior application code is being migrated or reused.

**The TypeScript foundation layer is the hard prerequisite — and at Revision 6 it has a port
source.** It must supply **src/core/database.ts** with the module-level `database` singleton
whose `execute()` method wraps the `mssql` npm package (node-mssql over tedious). The `mssql`
driver is **natively async**, so the thread-pool wrapper the reference design required
disappears — a genuine simplification. Config is zod-validated in **src/core/settings.ts**
rather than zod. `AgentRunWriter.record()` calls that singleton and cannot be
written against an interface that does not exist yet.

**`pacEHR_AI/core/database.py` is that interface, already written and tested.** Port it rather
than designing it: the connection-string template, `Authentication=ActiveDirectoryMsi`,
`Encrypt=strict`, `ConnectRetryCount=3`, the 10-second cursor timeout and the `?`-parameter
binding discipline all carry across. ⚠️ **One thing does not carry across, and this story is
the one that needs it:** `database.py` exposes `aexecute` and nothing else — **there is no
transaction primitive specified in the reference foundation either.** Blocker 0.6 below is
therefore genuinely new work, not something the foundation epic hands you.

⚠️ **The fail-closed guarantee remains unchanged.** The audit row for a blocked run must
still be written. Any TypeScript implementation that blocks by throwing an unhandled exception
before the audit write destroys the row for exactly the runs most worth auditing. The
middleware/hook that writes `AI.agentRun` must execute on both the success and guard-blocked
paths — equivalent to the `after_agent` constraint in the reference design.

`pacEHR_API` carries release tooling scripts; it is not an AI application host:
`pacEHR_API/.claude/skills/pacehr-release-sql/` contains `SKILL.md`,
`Invoke-ReleaseSql.ps1`, `build-release-sql.py`, `verify-release-sql.py`,
`dupe-sp-report.py` and `release_out.py`.

**The DDL in §3 is unaffected by the runtime choice** — the AI tables live in the same SQL
Server instance as `Template.*` and `Log.AILogs` regardless of which service writes them.

The residual question is narrower and sharper: **is the TypeScript repository stood up, is
the foundation layer staffed, and is Epic 02 sequenced behind it?** If these
tables land before the service that writes them, the tables are correct and empty — a safe
state, but one that should be declared explicitly in the PR rather than left to be discovered.

**TypeScript implementation artefacts (proposed paths — new repo, not yet on disk):**

| Epic artefact | TypeScript location |
|---|---|
| `INSERT_AGENT_RUN_SQL` constant | module-level const in `src/repositories/agentRunWriter.ts` |
| `class AgentRunWriter.record()` | class `AgentRunWriter` in `src/repositories/agentRunWriter.ts`, calling `database.execute()` |
| `database` singleton | `src/core/database.ts`, using the `mssql` npm package (natively async — no thread-pool wrapper needed) |
| config | zod-validated `src/core/settings.ts` |
| outcome values | module-level string constants in one place; never inline literals |

The epic's *intent* — one insert statement in one place, outcome values never inline
literals — survives the language change intact. That intent is worth preserving explicitly in
the DoD (§5).

> **✅ Table-name collision — RESOLVED, no rename.** [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) section 3.1 named this table `AI.runAudit`; every current source names it `AI.agentRun`. Three independent later documents confirm `AI.agentRun`: [epic-02-data-layer.md](solution-doc:5077) carries the full DDL, [epic-09-review-api.md](solution-doc:5085) and [epic-10-observability.md](solution-doc:5086) both write to `AI.agentRun`, and [GAPS.md](solution-doc:5089) discusses it under that name throughout. **Build `AI.agentRun`.** The residual action is editorial only: correct doc 3777 §3.1 so the stale name stops propagating.

---

## 2. Current state — verified inventory

### 2.1 What already logs AI activity

Three tables exist, all in the `Log` schema, all written by stored procedures:

| Table | File | Key columns | Writer |
|-------|------|-------------|--------|
| `Log.AILogs` | `pacEHR_API/PacEHR.Database/Tables/Tables1/AILogs.sql` | `Id INT IDENTITY` PK_AILogs; `accountId`/`patientId`/`encounterId INT`; `system_content`/`user_content`/`resp_content NVARCHAR(MAX)`; `resp_role NVARCHAR(10)`; `prompt_tokens`/`completion_tokens`/`total_tokens INT`; `createdDate`/`modifiedDate DATETIME`; `createdBy`/`modifiedBy INT` | usp_addEditAILogs |
| `Log.AIAcoEncounterLogs` | `pacEHR_API/PacEHR.Database/Tables/Tables1/AIAcoEncounterLogs.sql` | as above, minus `resp_role`, `modifiedDate`, `modifiedBy`; PK_AIAcoEncounterLogs | usp_InsertAIAcoEncounterLog |
| `Log.AISummaryLog` | `pacEHR_API/PacEHR.Database/Tables/Tables1/AISummaryLog.sql` | `AISummaryLogId INT IDENTITY` PK; `accountId`/`userId INT NOT NULL`; `encounterId INT`; `selectedEncounterIds`/`selectedEligibleFields NVARCHAR(MAX)`; `createdDate DATETIME` — **no token columns** | usp_addAISummaryLogs |

**Every column in `Log.AILogs` is nullable.** A row can exist with no account, no encounter
and no tokens. There is no constraint expressing what a valid audit row is. `AI.agentRun`'s
`NOT NULL` columns are the corrective.

### 2.2 Relationship between `AI.agentRun` and `Log.AILogs`

These are not the same table and the new one does not replace the old one in Phase 1.

| | `Log.AILogs` | `AI.agentRun` |
|---|---|---|
| Grain | one row per successful client POST | one row per **invocation**, including blocked and errored |
| Content | full prompt and response text | a hash; **no text** |
| Written by | browser-initiated POST | server, in the call path |
| Trust | client-asserted | server-measured |
| Guard-blocked calls | not recorded | recorded (`outcome = 'guard_blocked'`) |
| Nullability | everything nullable | audit columns `NOT NULL` |

They will coexist. Decommissioning `Log.AILogs` is not in this story and should not be
implied in the PR. Note that the two will **disagree** on token counts once both are live —
that disagreement is a useful signal, not a bug, and the verification query in §5.4 surfaces
it deliberately.

### 2.3 The FK target — resolved

`pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql`:

- line 2 — `[encounterID] INT IDENTITY (1, 1) NOT NULL`, constraint `PK_encounterID`
- line 6 — `[providerID] INT NULL` (**uppercase `ID`** — relevant to PEA-203)

So `AI.agentRun.encounterID INT NOT NULL` is correct, and the epic's caveat that the type was
unverified is now closed. The epic's decision to declare **no physical foreign key** stands,
and the audit supports it for a reason the epic did not give: `Encounter.encounter` carries
audit triggers and a large dependency surface, and the release mechanism (§2.5) has no
transactional grouping, so a physical FK would make the AI table's deployment order
load-bearing on a table nobody wants to touch.

### 2.4 Datatype and DDL precedent

CLAUDE.md rule 3 lists the approved datatypes: `BIT`, `INT`, `NVARCHAR`, `VARCHAR`,
`DATETIME`, `DATE`, `DATETIME2`. Against that list and against what is actually on disk:

| Epic proposes | Verdict | Evidence |
|---|---|---|
| `runID BIGINT IDENTITY` | ⚠️ needs approval, **precedent exists** | `BIGINT IDENTITY` in `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` and `pacEHR_API/PacEHR.Database/Tables/Tables1/gehrimedData_OMH.sql`; 267 `BIGINT` matches across Tables/ |
| `promptHash CHAR(64)` | ❌ **change to `VARCHAR(64)`** | `CHAR` is not on the approved list; `VARCHAR` is |
| `outcome VARCHAR(20)` + CHECK | ✅ approved, precedent exists | 5 files carry CHECK constraints — see below |
| `createdUtc DATETIME2` | ✅ approved, preferred by rule 3 | — |
| `DEFAULT SYSUTCDATETIME()` | ❌ **change to `DEFAULT (getutcdate())`** | zero matches for `SYSUTCDATETIME` in any table DDL; `getutcdate()` is the established form — `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` line 11 |
| `GRANT SELECT, INSERT` | 🔴 **no precedent at all** | see §2.6 |

**CHECK constraint precedent — confirmed, 5 files.** The named-constraint style to copy:

- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` line 14 —
  `CONSTRAINT [CK_SpecialtyCarePathTemplate_stage] CHECK ([stage]='Discharge' OR [stage]='Subsequent' OR [stage]='Initial')`
  — this is the closest analogue to `outcome`: a small closed vocabulary expressed as an OR chain.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql` lines 20–26 — six range CHECKs
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql` lines 13–15
- `pacEHR_API/PacEHR.Database/Tables/Tables1/medicalDirectorActivity.sql` lines 18–19
- `pacEHR_API/PacEHR.Database/Tables/Tables2/treatmentPlanGoal_1.sql` line 22

Note the house style: SSDT normalises `IN (...)` into an `OR` chain and names the constraint
`CK_<table>_<column>`. Write it that way to avoid a diff on first deploy.

### 2.5 How this table actually ships

There is no `dacpac` deployment. Across the 12 files in `pacEHR_API/pipelines/`, a search for
`dacpac|SqlPackage|sqlproj|Database` returns **one** match — a comment in `kb-refresh.yml`.
`deploy-pacehrapis.yml` and `jobs/deploy-pacehrapis-job.yml` publish `PacEHR.API.csproj` to an
Azure Web App and nothing else. There is no `.publish.xml` and no `.publishsettings`.

Database changes ship through the release harness
`pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1`, invoked as
`-Release '<date>'`, which:

1. discovers release folders matching the date,
2. runs a duplicate-object report that **gates** the build,
3. builds `<tag>-DDL.sql` and `<tag>-SP.sql`,
4. verifies the output against a git ref.

It reads from a **git ref, never the working tree** (default `-Feature origin/PacEHR-DevelopAPI-Main`,
`-Base origin/release/production`). Verdicts are `PASS`, `WIRING`, `CASE-BUG`, `DRIFT`,
`UNCLASSIFIED`; exit 0 clean, 1 blocking, 2 error.

**Two traps.** One release can span two folders whose names differ only in punctuation
(`Script.20-Sept-2026` vs `Script.20Sept2026`) because `-Release` matches on the date. And an
empty bucket writes no file at all — so a DDL-only release produces no SP file, which looks
like a failure and is not.

Only one release script has ever existed:
`pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql`, which contains a single
`GO`. This story's ALTER script would be, in practice, the first real use of the mechanism.

Per CLAUDE.md rule 5, every `.sql` file must be registered in
`pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` — `<Build>` for schema objects, `<None>`
for release scripts. **An unregistered file is silently never deployed.** Of ~2,845
registrations in that 2,920-line file, `<None Include=...>` entries number **zero** — so the
rule-5 `<None>` path for release scripts has never once been exercised. Expect friction.

Also note `<DSP>Microsoft.Data.Tools.Schema.Sql.Sql170DatabaseSchemaProvider</DSP>` at line 10
of the `.sqlproj` — that is **SQL Server 2022, not Azure SQL**. A latent target mismatch that
this story does not fix but should not be surprised by.

### 2.6 Grants and roles — the hard blocker

Across all 2,834 `.sql` files in `pacEHR_API/PacEHR.Database/`:

| Pattern | Matches |
|---|---|
| `CREATE SCHEMA` | **0** |
| `CREATE ROLE` | **0** |
| `CREATE USER` | **0** |
| `ALTER ROLE` | **0** |
| `GRANT ` | **0** (only the words "auto-grant" in comments in two referral procs) |

There is no `Security/` folder. CLAUDE.md rule 7 says a new schema belongs at
`Security/<Schema>.sql` — a convention that has never been used.

**The principal `aiServiceRuntime` does not exist and cannot be created by this story's
script alone.** The epic's `GRANT SELECT, INSERT ON AI.agentRun TO aiServiceRuntime` is a
correct security design and an unshippable line of SQL today. §4.3 gives the sequencing.

### 2.7 The `AI` schema already exists

`pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` line 1 is
`CREATE TABLE [AI].[prompt] (...)`. So PEA-201 does not create the `AI` schema — it already
carries a live, in-use table. Confirming this satisfies CLAUDE.md rule 1 for this story.

### 2.8 Name collision check

Case-insensitive search across all 2,834 `.sql` files: **`agentRun` — 0 matches.** The name
is free *in the database*. (Same clean result for `fieldOutcome`, `promptFragment`,
`fieldConstraint`, `fieldDescription`. `runAudit` is also 0 matches.)

✅ **The design-document disagreement is now settled — `AI.agentRun`, no rename.** [Doc 3777](solution-doc:3777) §3.1 called the run-level telemetry table `AI.runAudit`. Every current source calls it `AI.agentRun`: the epic's own DDL ([epic-02-data-layer.md](solution-doc:5077)), the consumer that writes it ([epic-10-observability.md](solution-doc:5086), PEA-1003), the consumer that delegates to it ([epic-09-review-api.md](solution-doc:5085)), and the gap analysis that critiques it ([GAPS.md](solution-doc:5089)). Three independent later documents, written by the team that will build it, against one earlier design sketch.

**Build `AI.agentRun`.** D17/D18 in the [Epic 02 grooming rollup](solution-doc:5006) are closed, and risk 15 is retired. The only residual work is editorial: correct doc 3777 §3.1 so `runAudit` stops propagating into new documents. PEA-203's FK targets `agentRun` unchanged.

### 2.9 Existing test surface

`pacEHR_API/PacEHR.Tests.UnitTests/` is xUnit + Moq. Two AI-relevant files exist:
`pacEHR_API/PacEHR.Tests.UnitTests/Controllers/AIControllerTests.cs` and
`pacEHR_API/PacEHR.Tests.UnitTests/DomainServices/AIPromptServicesTest.cs`.

**No test validates database scripts or the `.sqlproj` manifest.** Given that rule 5's
failure mode is silent non-deployment, a test that asserts every `.sql` file on disk has a
matching `.sqlproj` registration would be the highest-value test this epic could add — and
it is cheap. Recommended in §5.

---

## 3. Proposed DDL

### 3.1 The table

Written in house style: named constraints, SSDT column alignment, `getutcdate()` default,
approved datatypes only.

```sql
CREATE TABLE [AI].[agentRun] (
    [runID]            BIGINT         IDENTITY (1, 1) NOT NULL,
    [encounterID]      INT            NOT NULL,
    [templetID]        INT            NULL,
    [promptHash]       VARCHAR (64)   NULL,
    [modelDeployment]  NVARCHAR (100) NULL,
    [configVersion]    VARCHAR (64)   NULL,
    [inputTokens]      INT            NULL,
    [outputTokens]     INT            NULL,
    [latencyMs]        INT            NULL,
    [outcome]          VARCHAR (20)   NOT NULL,
    [reasonCode]       VARCHAR (64)   NULL,
    [createdUtc]       DATETIME2 (7)  CONSTRAINT [DF_agentRun_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_agentRun] PRIMARY KEY CLUSTERED ([runID] ASC),
    CONSTRAINT [CK_agentRun_outcome] CHECK ([outcome]='COMMITTED' OR [outcome]='AWAITING_REVIEW' OR [outcome]='BLOCKED'),
    CONSTRAINT [CK_agentRun_reachedModel] CHECK (
        ([outcome]='BLOCKED')
        OR ([promptHash] IS NOT NULL AND [modelDeployment] IS NOT NULL)
    ),
    CONSTRAINT [CK_agentRun_blockedHasReason] CHECK (
        ([outcome]<>'BLOCKED') OR ([reasonCode] IS NOT NULL)
    )
);
GO

CREATE NONCLUSTERED INDEX [IX_agentRun_encounter]
    ON [AI].[agentRun]([encounterID] ASC, [createdUtc] ASC);
```

⚠️ **This DDL is materially different from the one in [epic-02-data-layer.md](solution-doc:5077),
and the differences are not cosmetic.** Six of them exist because
[GAPS.md](solution-doc:5089) found the epic's own DDL contradicts its own consumers. Each is
justified in §3.2. Do not reconcile this spec back to the epic's DDL without reading Gaps 3,
9 and 12 first — the epic's version cannot store the rows PEA-1003 is required to write.

**The two new CHECKs are the point of the change, not decoration.** Making `promptHash` and
`modelDeployment` nullable is necessary but on its own it is a loss: it would let a
*successful* run be written with no prompt hash, which destroys the reproducibility guarantee
that is the whole reason the column exists. `CK_agentRun_reachedModel` gives that guarantee
back in a form the database enforces — nullable only on the one path where the values
genuinely do not exist. `CK_agentRun_blockedHasReason` is its mirror: a blocked run may omit
the model columns, but it may not omit *why*. Together they mean every row is either "reached
the model, here is the hash" or "never reached it, here is the reason." There is no third,
unexplained state.

### 3.2 Changes from the epic's DDL, with reasons

| Epic | This spec | Why |
|---|---|---|
| `promptHash CHAR(64)` | `promptHash VARCHAR(64)` | `CHAR` not on CLAUDE.md rule 3's approved list. A SHA-256 hex digest is always exactly 64 chars so `CHAR` is technically the better fit — but the rule is the rule, and rule 3 exists because of a real production failure (PACT2-1105). If `CHAR(64)` is wanted, escalate it explicitly rather than quietly shipping it. |
| `DEFAULT SYSUTCDATETIME()` | `DEFAULT (getutcdate())` | Zero precedent for `SYSUTCDATETIME` in table DDL; `getutcdate()` is used throughout (e.g. patientAlertJobLog.sql:11). Both are UTC; the house form avoids a needless novelty. `DATETIME2(7)` is retained for precision, per rule 3's preference. |
| `CHECK (outcome IN (...))` | named `CK_agentRun_outcome` as an OR chain | Matches SpecialtyCarePathTemplate.sql:14 exactly. SSDT rewrites `IN` to `OR` anyway; writing it pre-normalised prevents a spurious schema diff. |
| no index specified | `IX_agentRun_encounter` | The epic notes the clustered key is ever-increasing (correct, avoids page splits) but names no secondary index. Every consumer query is "runs for this encounter" — PEA-203 joins on `runID`, and §5.4's verification queries filter by encounter. Without this index those are scans. |
| `GRANT SELECT, INSERT` | deferred to §4.3 | No precedent; principal does not exist. |
| `BIGINT` | `BIGINT`, **but flag it** | Right choice for an append-only table with no retention policy, and precedent exists (HL7_MSH.sql). Still needs the rule-3 escalation. |
| `promptHash ... NOT NULL` | **`NULL`, gated by `CK_agentRun_reachedModel`** | 🔴 **Gap 3.** [epic-10-observability.md](solution-doc:5086) PEA-1003 *requires* that a guard-blocked run record `promptHash`, model and token columns as **null** — the run never reached the model, so there is no hash and no deployment to record. `NOT NULL` makes that row unwritable. The epic's DDL and the epic's own acceptance criteria contradict each other. Nullable is the correct resolution; the CHECK stops it from becoming a licence to omit the hash on runs that *did* call the model. |
| `modelDeployment ... NOT NULL` | **`NULL`, same CHECK** | 🔴 Gap 3, same mechanism. Note this also retires Finding 3's complaint on the happy path only — a successful run must still record a real deployment name, and now the database enforces it. |
| *(no column)* | **`reasonCode VARCHAR(64) NULL`** | 🟠 Gap 3. A blocked run with every model column null and no reason code is an audit row that records *that* something was refused and nothing about *why* — useless for the safety case this table exists to support. [epic-10-observability.md](solution-doc:5086) PEA-1004 owns the closed vocabulary (e.g. `USAGE_METADATA_ABSENT`); this column is where it lands. **Deliberately un-CHECKed**: PEA-1004 has not published the list, and a CHECK constraint that must be ALTERed every time a reason code is added is worse than application-side validation. Revisit once PEA-1004 closes. |
| *(no column)* | **`templetID INT NULL`** | 🟠 Gap 12. `(templetID, sectionID, fieldID)` is the keying the rest of the schema uses, and without `templetID` you cannot answer "how did this template perform" — the single most likely question anyone will ask of this table. Nullable because a run blocked before template resolution genuinely has none. **No physical FK** to `Template.*`, consistent with the epic's "verify, do not recall" stance on cross-schema FKs. Note the live misspelling `templetID` is preserved deliberately (CLAUDE.md); it is confirmed live in 7 files in this repository. |
| *(no column)* | **`configVersion VARCHAR(64) NULL`** | 🟠 Gap 12. `promptHash` identifies the prompt but not the surrounding configuration — model parameters, guard set, fragment activation state. Two runs with identical hashes can behave differently. Without this the table cannot support "what changed between Tuesday and Wednesday," which is the first question asked after any quality regression. |
| `outcome IN (committed, awaiting_review, guard_blocked, error)` | **`COMMITTED` / `AWAITING_REVIEW` / `BLOCKED`** | 🔴 **Gap 9 — the vocabulary was split and one value had no producer.** Three fixes in one. (1) **Case**: the epic's CHECK is lower_snake; [epic-09-review-api.md](solution-doc:5085) and Epic 4 pass SCREAMING_SNAKE. A CHECK constraint is case-sensitive under a case-sensitive collation and silently permissive under a case-insensitive one — either way it is a defect waiting on a collation setting. SCREAMING_SNAKE matches the producers and matches `proposedStatus`/`proposedConfidence` elsewhere in the schema. (2) **`guard_blocked` → `BLOCKED`**: the producers pass `BLOCKED`; with the epic's CHECK, every blocked run fails to insert. (3) **`error` is dropped**: GAPS found it has no producer anywhere in the 12 epics. An unreachable enum value invites someone to invent a meaning for it later. If genuine infrastructure failures need recording, that is a `reasonCode` on a `BLOCKED` row, not a fourth outcome — one dimension, not two. |

### 3.3 Runtime work this table implies

The table is the smallest part of this story. To make its columns mean anything:

| Column | Work required | Where |
|---|---|---|
| `promptHash` | compute SHA-256 of the composed prompt **before** the model call (REQ-10-03) | `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`, 4 call sites |
| `modelDeployment` | resolve model name from config instead of the `"gpt-4o"` literal at lines 176/230/282/334 | same file |
| `latencyMs` | stopwatch around each HTTP call | same file |
| `inputTokens`/`outputTokens` | read from the **server-side** response body, not from the browser | same file |
| `outcome` | set at write time from the call's real result, including the guard-blocked path | new service |
| `reasonCode` | consume the closed vocabulary once PEA-1004 publishes it; until then, application-side validation against a module-level constant | `src/repositories/agentRunWriter.ts` |
| `templetID` | carry the resolved template id through to the audit write; null if the run blocked before resolution | `src/repositories/agentRunWriter.ts` |
| `configVersion` | derive from the active fragment set + model parameters at run start, not at write time | `src/repositories/agentRunWriter.ts` |

**Who actually writes this row.** It is not the caller.
[epic-09-review-api.md](solution-doc:5085) settles it: the after-agent hook writes
`AI.fieldOutcome` itself but **delegates the `AI.agentRun` write to
**src/repositories/agentRunWriter.ts**** (class `AgentRunWriter`, module-level constant
`INSERT_AGENT_RUN_SQL`, calling `database.execute()` from **src/core/database.ts**), owned by
PEA-1003 in [epic-10-observability.md](solution-doc:5086). This story owns the *table*;
PEA-1003 owns the *writer*. That is a cleaner split than the reference design's
`core/agent_run_repository` naming suggested, and it is the boundary to hold at review — two
writers on one audit table is how audit tables stop being trustworthy.

⚠️ **The full digest, never truncated.** [epic-10-observability.md](solution-doc:5086)
specifies the complete sha256 hex digest. `VARCHAR(64)` fits it exactly, with no room for a
prefix convention to creep in. If anyone proposes storing a short hash for readability,
refuse: a truncated hash cannot prove a prompt was not altered, which is the column's only job.

### 3.3a 🔴 Blocker — there is no transaction primitive, and this table needs one

[GAPS.md](solution-doc:5089) Gap 17 is the most easily-missed of the blockers because it is
an *absence* rather than a contradiction, and it lands squarely on this story.

**What the foundation layer must provide.** The reference design specifies a single `execute` on the module-level `database` singleton — in TypeScript, **src/core/database.ts** using the `mssql` npm package (node-mssql over tedious). The `mssql` driver is natively async, so the thread-pool wrapper the reference design required disappears. Config is zod-validated in **src/core/settings.ts**. But a bare `execute` gives no `begin`, no `commit`, no `rollback`, and no way to hold a connection across two statements. Node's `mssql` package does expose a first-class `Transaction` object, so the primitive is available — it simply has to be part of the foundation's public surface rather than an afterthought.

**What this table's consumers require.** [epic-10-observability.md](solution-doc:5086)
PEA-1003 states the audit row shares a transaction with the field commit, and that an audit
write failure prevents the commit. With a fresh connection per statement that is not merely
hard — it is **unimplementable as specified**. Two `database.execute()` calls cannot be
atomic with each other.

**Why it matters more here than anywhere else.** The guarantee being lost is the one that
makes the table worth building: *no clinical field is committed without a corresponding
audit row*. Without atomicity the failure is silent and one-directional — the field write
succeeds, the audit write fails, and the system has committed AI-derived content to a
patient record with no record of which model produced it, under which prompt, at what
confidence. That is precisely the state the regulator asks about. It will not be detected by
any test that checks the happy path.

**Resolution — this is a foundation-layer change, not a workaround here.** The correct fix is
a transaction primitive on the `database` singleton: a scoped helper holding one connection
across multiple statements, committing on clean exit and rolling back on exception, built on
the `mssql` package's `Transaction` object. Raise it against the foundation backlog now —
retrofitting transaction support
into a fresh-connection-per-call design after four epics have been written against it is
substantially more expensive than adding it before the first ticket. **Do not accept a
compensating-write workaround** (insert the audit row, then delete it if the commit fails):
it cannot be made correct against a process crash between the two statements, and it puts a
DELETE grant on an append-only audit table, which defeats the table's purpose.

SHA-256 is available and already used in this codebase — `SHA256.Create()` /
`ComputeHash(...)` appears in `pacEHR_API/pacEHR.DomainServices/VideoCallService.cs` lines
116–118, so there is a working in-repo pattern to copy. Note that the only hashing in the
*database* layer is SHA1, at
`pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getHIEDocumentQuery.sql` line 45 —
do not copy that; the requirement is SHA-256 and it must be computed in application code
before the model call, not in SQL after it.

### 3.4 Design points from the epic that the audit endorses

These are correct and should survive review unchanged:

- **`outcome` is fixed at write time.** "Awaiting review" as a *current state* is derived by
  joining `AI.fieldOutcome.decidedAtUtc IS NULL`, not by updating this row. The table stays
  append-only, which is what makes it an audit trail.
- **One row per invocation, including blocked ones.** This is why `inputTokens`,
  `outputTokens`, `latencyMs` — and, per Gap 3, `promptHash` and `modelDeployment` — are
  nullable: a blocked call never reaches the model, so those values do not exist to record.
  The nullability is semantic, not laziness. The DoD asserts it in both directions: the
  blocked row must persist, and `CK_agentRun_reachedModel` must reject a committed row that
  omits the hash.
- **No PHI in this table.** A hash, not the prompt. This is the discipline CLAUDE.md states
  as "log the token, never the value," and it is the reason this table can have a longer
  retention window than `AI.fieldOutcome`.
- **Volume is trivial.** ~1,000 inserts/day against an ever-increasing clustered key. No
  partitioning, no retention job, no filtered index needed.

---

## 4. Delivery plan

### 4.0 The story at a glance

**Assume nothing is delivered.** `Log.AILogs` is the surface this table supersedes, not a
partial delivery of it.

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `0002_ai_agentrun.sql` — table, three CHECKs, `IX_agentRun_encounter` | A — **can start today** | PEA-201, 0.5 DDL blockers | 2 |
| **DDL** | `GRANT SELECT, INSERT` to `aiServiceRuntime` | A | **M1 — principal does not exist** | 0.5 |
| **Runtime** | `src/repositories/agentRunWriter.ts`, `AgentRunWriter.record()` | C | M9 port | 1–2 |
| **Runtime** | 🔴 Transaction primitive in `src/core/database.ts` | C — **new in both languages**; `pacEHR_AI` has none either | M9, 0.6 | 1–2 |
| **Runtime** | Instrument the call path: latency, tokens, reason codes, the guard-blocked branch | C — **the real work in this story** | M9 | 2–3 |
| **Surface** | none user-facing; one operational dashboard tile (§4.0 exit criterion) | D | R2 shipped | 0.5 |
| | | | **Total** | **5–8** |


⚠️ **Revision 7 — where the DDL lives.** Every `000N_*.sql` above ships in
**`pacEHR_AI/migrations/sql/`** and reaches a database through `MigrationRunner.applyPending()`
— **not** through `pacEHR_API`'s SSDT project, its dated release folders or its `.sqlproj`.
Revisions 5–6 said otherwise; code separation reverses it. Two consequences for this story:

- **"Can start today" means "as soon as the repository has a skeleton."** The scripts are plain
  literal T-SQL and need no foundation code, but they need somewhere to live and a runner to
  apply them (PEA-201).
- 🔴 **Nothing validates the cross-repository keys at build time any more.** Columns this table
  references are owned by `pacEHR_API`, which can rename them without seeing this repository.
  Under SSDT that failed the build; now it fails at runtime, in the environment. **A CI
  integration test against a restored database is the replacement** (risk R20, decision D33).

**Where the estimate actually goes.** The table is two points and a morning. Everything else
is instrumenting a call path that today measures nothing — there is no `Stopwatch`, no
`ElapsedMilliseconds` and no latency field anywhere in `AIPromptServices.cs` (X5), and the
only token figures in the system are asserted by the browser (X1). **This story is where both
defects get fixed, and it should be estimated as instrumentation work, not as a table.**

**Split it.** PEA-202a = DDL + writer (2–3). PEA-202b = instrument the call path (5). They have
different blockers and 202b cannot start until there is a call path in the new service to
instrument.

**Exit criterion:** one real extraction produces exactly one `AI.agentRun` row; one
guard-blocked run produces exactly one row with a reason code and `reachedModel = 0`; and the
daily row count tracks `Log.AILogs` within the margin §5.4's query defines.

### Phase 0 — Unblock (not this story's code, but gates it)

| # | Action | Owner | Blocks |
|---|--------|-------|--------|
| 0.1 | ~~Decide the platform~~ **CLOSED.** The AI engine is implemented in **TypeScript/Node.js**, in a repository not yet created, **built greenfield in `pacEHR_AI/`**, which also owns the `AI.*` DDL. The 12-epic corpus remains the reference design for all runtime-neutral decisions (DDL, acceptance criteria, sequencing). ✅ **D1b closed at Revision 7**; residual action is to record the override of the .NET in-solution recommendation. | — | nothing |
| 0.2 | Get rule-3 approval for `BIGINT` and `VARCHAR(64)` | Tech lead | §4.1 |
| 0.3 | Decide whether grants/roles ship in this epic or a separate infra story | Architecture + DBA | §4.3 |
| 0.4 | Confirm PEA-201 has landed (`AI` schema confirmed, forward-only mechanism agreed) | — | all |
| 0.5 | 🔴 **Settle the three DDL blockers** — Gap 3 (nullable model columns), Gap 9 (`outcome` vocabulary), Gap 12 (`templetID`/`configVersion`). §3.2 has the proposals | Epic 02 + Epic 9/10 owners | **§4.1 — the DDL cannot be written until this closes** |
| 0.6 | 🔴 **Put the transaction primitive in the foundation's public surface** (§3.3a, Gap 17) | Foundation owner | §4.2 write path; PEA-1003's atomicity AC |
| 0.7 | Confirm **the foundation port is sequenced ahead and staffed** (M9, 5–8 pts against `pacEHR_AI/src/core/`), the repository is stood up, and dependency versions are pinned. The reference allow-list ([the reference symbol allow-list](solution-doc:5091) §10) does not bind a Node runtime — a TypeScript equivalent must be authored, mapping `pacEHR_AI/package.json`'s seven dependencies | Architecture | §4.2 |

**0.1 is closed and should not be re-litigated.** The two sharper items are
0.5 and 0.6 — both are cases where the epic's own DDL cannot store what the epic's own
consumers are required to write, and both are far cheaper to settle before the table exists
than after. 0.5 in particular gates §4.1: writing the DDL first means an ALTER on a live
audit table, which is the one kind of table where an ALTER is hardest to justify.

### Phase 1 — Ship the table

1. Create Tables/AI.agentRun.sql with the §3.1 DDL (canonical object file, per rule 7).
2. Create a re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/&lt;JIRA-KEY&gt;-agentRun.sql,
   guarded with `IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[agentRun]') AND type = N'U')`.
3. Register **both** files in `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` —
   `<Build>` for the canonical table, `<None>` for the release script. Rule 5; silent failure
   if skipped.
4. Run the release harness in report mode and confirm a `PASS` verdict with no duplicate-object hit.

Per CLAUDE.md rule 4 both artefacts are required, every time — the canonical table file
*and* the release script. Not one or the other.

### Phase 2 — Write path

⚠️ **Steps 5–7 and 8–12 below describe a .NET write path and are a *contingency*, not the
plan.** The writer is TypeScript: **src/repositories/agentRunWriter.ts**
(class `AgentRunWriter`), the work owned by PEA-1003 in [epic-10-observability.md](solution-doc:5086),
calling the `database` singleton in **src/core/database.ts** via `database.execute()` with an
`INSERT_AGENT_RUN_SQL` SCREAMING_SNAKE module-level constant and no string interpolation
(CLAUDE.md). The steps are retained because the *ordering* and the review checks they
encode — one insert statement in one place, outcome values as named constants, never inline
literals — translate directly and are worth keeping visible. Read "stored procedure" as
"module-level `_SQL` constant" and "domain service" as "the single public method on the
writer class."

5. Add the insert procedure `usp_addAgentRun` in Stored Procedures/Procs2/ using
   `CREATE OR ALTER PROCEDURE`, schema-qualified, with the rule-6 header block and Jira key.
   (Note: `CREATE OR ALTER` appears in only ~5 of ~627 procedures — it is the documented
   convention but not yet the established practice. Follow the rule.)
6. Expose it through `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` and
   `Ipacehr_devContextProcedures.cs`, matching the existing `SqlParameter` / `OutputParameter<T>`
   pattern. All data access in this repo goes through that partial class — there is no Dapper
   in the API project.
7. Add the writer service with outcome values as **named constants, never inline literals**
   (preserving the epic's intent).

### Phase 3 — Instrumentation

8. Add SHA-256 prompt hashing before the model call, at all four sites.
9. Replace the `"gpt-4o"` literal with config resolution.
10. Add stopwatch timing.
11. Move token capture server-side; stop trusting `localStorage`.
12. Wire the `BLOCKED` path (depends on Epic 6 existing; until then that outcome value is
    created but never written — state this in the PR rather than leaving it to be
    discovered). The guard must block via `return {"jump_to": "end"}`, **never** `raise` —
    an exception skips `after_agent` and the audit row is lost for exactly the runs most
    worth auditing ([the reference symbol allow-list](solution-doc:5091) §3).

### Phase 4 — Grants

13. Whatever 0.3 decided. See §4.3 below.

### 4.3 Grant sequencing

Because there is no precedent, the safe order is:

1. A **separate infrastructure story** creates the database principals and roles
   (`aiServiceRuntime`, and for later stories `aiPromptAdmin` / `aiTemplateAdmin`), plus the
   `Security/` folder convention rule 7 anticipates but nothing has used.
2. That story establishes whether principals are managed in SSDT at all, or provisioned
   outside it by the DBA. **This is a genuine fork**: SSDT can manage users and roles, but
   this project never has, and putting them in the `.sqlproj` changes what a deployment can
   do to a production database.
3. Only then can `GRANT SELECT, INSERT ON AI.agentRun TO aiServiceRuntime` ship.

Until then, `AI.agentRun` is reachable by whatever principal the API already uses. **Say this
plainly in the PR.** The least-privilege property the epic describes will not exist on first
deploy, and a DoD item that claims otherwise would be false.

---

## 5. Verification

### 5.1 Deployment checks

```sql
-- table exists in the right schema
SELECT s.name AS schemaName, t.name AS tableName
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'AI' AND t.name = 'agentRun';

-- columns, types and nullability match §3.1
SELECT c.name, ty.name AS dataType, c.max_length, c.is_nullable
FROM sys.columns c
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'[AI].[agentRun]')
ORDER BY c.column_id;

-- the CHECK constraint is present and its definition is what we wrote
SELECT name, definition FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'[AI].[agentRun]');

-- the secondary index exists
SELECT i.name, i.type_desc FROM sys.indexes i
WHERE i.object_id = OBJECT_ID(N'[AI].[agentRun]');
```

### 5.2 Constraint behaviour

```sql
-- must fail: outcome outside the vocabulary
INSERT INTO [AI].[agentRun] (encounterID, promptHash, modelDeployment, outcome)
VALUES (1, REPLICATE('a',64), 'gpt-4o', 'pending');
-- expect: conflict with CK_agentRun_outcome

-- must fail: the retired lower_snake spellings (Gap 9 regression guard)
INSERT INTO [AI].[agentRun] (encounterID, promptHash, modelDeployment, outcome)
VALUES (1, REPLICATE('a',64), 'gpt-4o', 'guard_blocked');
-- expect: conflict with CK_agentRun_outcome. Same for 'committed' and 'error'.
-- If this INSERT succeeds, the database is running a case-insensitive collation and the
-- CHECK is not doing the work you think it is — escalate, do not shrug.

-- must succeed: a BLOCKED row with no model columns at all (Gap 3 — the row PEA-1003
-- is required to write, and the row the epic's own DDL made impossible)
INSERT INTO [AI].[agentRun] (encounterID, templetID, outcome, reasonCode)
VALUES (1, 42, 'BLOCKED', 'USAGE_METADATA_ABSENT');
-- expect: 1 row; promptHash, modelDeployment, inputTokens, outputTokens, latencyMs
-- all NULL; createdUtc populated

-- must fail: a BLOCKED row with no reason code
INSERT INTO [AI].[agentRun] (encounterID, outcome) VALUES (1, 'BLOCKED');
-- expect: conflict with CK_agentRun_blockedHasReason

-- must fail: a COMMITTED row that skipped the hash — the nullability from Gap 3 must
-- not leak onto the happy path
INSERT INTO [AI].[agentRun] (encounterID, outcome) VALUES (1, 'COMMITTED');
-- expect: conflict with CK_agentRun_reachedModel

-- must succeed: a normal committed run
INSERT INTO [AI].[agentRun] (encounterID, templetID, promptHash, modelDeployment,
                             configVersion, inputTokens, outputTokens, latencyMs, outcome)
VALUES (1, 42, REPLICATE('a',64), 'gpt-4o', 'cfg-2026-09-29', 1200, 340, 1850, 'COMMITTED');
-- expect: 1 row; promptHash is the full 64-char digest, never truncated
```

### 5.3 Grant assertion (only once §4.3 is done)

```sql
SELECT p.permission_name, p.state_desc, pr.name AS principalName
FROM sys.database_permissions p
JOIN sys.database_principals pr ON pr.principal_id = p.grantee_principal_id
WHERE p.major_id = OBJECT_ID(N'[AI].[agentRun]');
-- expect exactly SELECT and INSERT for aiServiceRuntime; no UPDATE, no DELETE
```

### 5.4 The finding-2 reconciliation query

Once both paths are live, this is the query that proves Finding 2 was real:

```sql
-- where the client-asserted tokens disagree with the server-measured ones
SELECT r.runID, r.encounterID, r.inputTokens AS serverInput, l.prompt_tokens AS clientInput
FROM [AI].[agentRun] r
LEFT JOIN [Log].[AILogs] l ON l.encounterId = r.encounterID
WHERE r.outcome = 'COMMITTED'
  AND (l.prompt_tokens IS NULL OR l.prompt_tokens <> r.inputTokens);
```

Rows where `clientInput IS NULL` are the invocations the current system lost entirely — most
likely closed tabs. That count is the size of the existing audit gap, and it is worth
reporting to whoever owns AI cost reporting.

### 5.5 Definition of Done

- [ ] Tables/AI.agentRun.sql created with the §3.1 DDL; datatypes are approved-list only
      (`VARCHAR(64)` not `CHAR(64)`), with `BIGINT` escalation recorded
- [ ] Re-runnable release script created under Scripts/Script.&lt;DDMonYYYY&gt;/ named with the
      Jira key; guarded by an `IF NOT EXISTS` existence check
- [ ] **Both** files registered in the `.sqlproj` (`<Build>` + `<None>`) — rule 5
- [ ] Release harness run; `PASS` verdict, no duplicate-object hit
- [ ] `usp_addAgentRun` created in Procs2/ with rule-6 naming, header block and Jira key
- [ ] Insert exposed through `pacehr_devContextProcedures` / `Ipacehr_devContextProcedures`
- [ ] Outcome values exist as named constants in exactly one place; a test asserts no inline
      outcome literal appears at any call site
- [ ] A test asserts a `BLOCKED` row persists with NULL `promptHash`, `modelDeployment`,
      `inputTokens`, `outputTokens` and `latencyMs` — the nullability is semantic (Gap 3) and
      must not be tightened later by accident
- [ ] A test asserts `CK_agentRun_reachedModel` **rejects** a `COMMITTED` row with a NULL
      `promptHash` — the nullability must not become a licence to skip the hash on runs that
      did reach the model
- [ ] A test asserts `CK_agentRun_blockedHasReason` rejects a `BLOCKED` row with no `reasonCode`
- [ ] A test asserts the CHECK constraint rejects a fourth `outcome` value, and specifically
      that it rejects the retired `guard_blocked` and `error` spellings (Gap 9)
- [ ] `templetID` and `configVersion` are populated on every run that resolved a template;
      a test asserts they survive the round-trip (Gap 12)
- [ ] Prompt hash is SHA-256, computed **before** the model call (REQ-10-03), with a test on a
      known input/digest pair
- [ ] `modelDeployment` resolves from configuration; the `"gpt-4o"` literal is gone from all
      four sites in `AIPromptServices.cs` (lines 176/230/282/334) — or, if deferred, the PR
      states that the column records a constant
- [ ] Token counts are read server-side; the PR states whether the `localStorage` path is
      retired or still running in parallel
- [ ] No PHI column exists on this table — reviewed against CLAUDE.md § Clinical and PHI rules
      and recorded explicitly, not silently skipped
- [ ] The 1,000-inserts/day figure and its source are recorded as a comment, per CLAUDE.md § Numbers
- [ ] PR title, branch name and commit message all carry the literal Jira key (silent failure
      in Azure DevOps otherwise); one concern per PR
- [ ] PR checklist complete: unit tests · DB script · technical documentation · AI usage
- [ ] **Recommended addition:** a test asserting every `.sql` file on disk has a `.sqlproj`
      registration — closes rule 5's silent-failure mode for this epic and every future one

---

## 6. Risk register

| # | Risk | L | I | Mitigation |
|---|------|---|---|------------|
| 1 | ~~Platform undecided; module has no host~~ **Closed** — the platform is TypeScript/Node.js (doc 3777 §3.1's original target is reference design, not build target) | ⬜ | ⬜ | Closed. See risk 14 |
| 2 | Grants unshippable — least privilege absent on first deploy | High | High | Separate infra story; disclose in PR |
| 3 | `.sqlproj` registration missed → table silently never deployed | Med | High | Manifest test; harness verdict check |
| 4 | `BIGINT`/`VARCHAR(64)` rejected at review | Med | Low | Escalate in Phase 0.2 with the HL7_MSH.sql precedent |
| 5 | `modelDeployment` ships recording a constant | High | Med | Accept for Phase 1, disclose; fix in Phase 3 |
| 6 | `latencyMs` ships permanently NULL | High | Low | Same — nullable by design |
| 7 | Client token path left running; two disagreeing sources of truth | Med | Med | §5.4 query; retire the client path explicitly |
| 8 | Instrumenting `AIPromptServices.cs` regresses live AI features | Med | High | Four call sites, all streaming; existing `AIPromptServicesTest.cs` coverage must be extended first |
| 9 | Release folder date-collision trap (two folders, one date) | Low | Med | Check folder listing before invoking the harness |
| 10 | `BLOCKED` never written until Epic 6 lands | High | Low | Expected; state in PR |
| 11 | SSDT target is SQL Server 2022, deployment target may be Azure SQL | Med | Med | Inherited from PEA-201; do not fix here, do not be surprised |
| 12 | Story is estimated at 3 points but carries runtime instrumentation | High | Med | Re-point to 5–8, or split §3.3 into its own story |
| 13 | Committed API key in appsettings.json | — | High | Separate security ticket; rotate |
| 14 | 🟠 **TypeScript service decided but not started** — this table ships with no writer for some interval | Med | Med | The Node repository does not exist yet. **Downgraded at Revision 6:** the foundation is a 5–8-point port from `pacEHR_AI/src/core/`, not an unscoped build, so the interval is bounded. Confirm sequencing in Phase 0.1. Correct-and-empty remains a safe state; declare it in the PR |
| 15 | 🔴 **The table ships and nothing ever writes to it, undetected.** An audit table that is empty looks identical to an audit table whose writer was never wired up | Med | **High** | The signal is free: compare daily `AI.agentRun` row count against daily `Log.AILogs` row count (§5.4's reconciliation query). A ratio far from 1 means the instrumentation is incomplete. Put it on a dashboard in Phase 3, not in a runbook nobody opens |
| 15 | ~~**Table-name collision** — `AI.runAudit` vs `AI.agentRun`~~ **Closed** — resolved in favour of `agentRun` by three independent later sources (§2.8) | ⬜ | ⬜ | Closed. Residual: editorial correction to doc 3777 §3.1 |
| 16 | 🔴 **Gap 3 — a guard-blocked run cannot write its audit row.** `promptHash`/`modelDeployment` NOT NULL vs PEA-1003's requirement that they be null | High | **High** | §3.1 DDL change (nullable + `CK_agentRun_reachedModel`). **Must be settled before the table ships** — an ALTER on a live audit table is far worse than getting it right once |
| 17 | 🔴 **Gap 9 — outcome vocabulary split.** Epic's CHECK says `guard_blocked` lower_snake; producers pass `BLOCKED`. Every blocked run fails to insert | High | **High** | §3.1 closes the CHECK on `COMMITTED`/`AWAITING_REVIEW`/`BLOCKED` and drops the producerless `error`. Confirm with Epic 4/9 owners in one message, not four |
| 18 | 🔴 **Gap 17 — no transaction primitive.** The foundation's `database` singleton is single-statement, fresh-connection-per-call; PEA-1003 requires the audit row to share a transaction with the field commit | High | **High** | §3.3a. Put a transaction scope on the foundation's public surface **before it is called done** — `mssql` exposes a first-class `Transaction`, so the capability exists. Failure mode is silent: field committed, audit lost. Reject compensating-write workarounds |
| 19 | 🟠 **Gap 12 — no `templetID`, no config version.** Table cannot answer "how did this template perform" or "what changed since Tuesday" | High | Med | Two nullable columns added in §3.1. Cheap now, an ALTER + backfill-with-nulls later — and a backfilled null is indistinguishable from a genuine one |
| 20 | 🟠 **`reasonCode` vocabulary is owned elsewhere** — PEA-1004 has not published the closed list | Med | Low | Column is deliberately un-CHECKed; validate application-side against one module-level constant. Revisit the CHECK once PEA-1004 closes |
| 21 | 🟡 **Blocking by `raise` destroys the audit row** — an exception skips `after_agent`, so the runs most worth auditing are the ones not recorded | Med | **High** | [the reference symbol allow-list](solution-doc:5091) §3 forbids it; guards must `return {"jump_to": "end"}` with `@hook_config(can_jump_to=["end"])`. Add a review check — this is a code-review-only defence, no test catches it |

**On the estimate.** The epic's 3 points are defensible for the DDL alone. They are not
defensible for the DDL *plus* SHA-256 hashing, config-driven model resolution, latency
instrumentation and server-side token capture across four streaming call sites in the
product's central AI class. **Either re-point to 5–8, or split:** "PEA-202a create the table"
at 2–3 points, and "PEA-202b instrument the call path" at 5. The split is cleaner and honours
CLAUDE.md's one-concern-per-PR rule.

---

## 7. Recommended immediate actions

*Items 1–3 outrank everything else on this list: all three are cases where the epic's own DDL
cannot store what the epic's own consumers are required to write. They are cheap to fix now
and expensive to fix after the table ships.*

1. 🔴 **Settle the three DDL blockers in one conversation, before any SQL is written.**
   Gap 3 (nullable `promptHash`/`modelDeployment`), Gap 9 (the `outcome` vocabulary), Gap 12
   (`templetID` + `configVersion`). They have the same root cause — [epic-02-data-layer.md](solution-doc:5077)
   was written before Epics 9 and 10 existed — and the same audience. Taking them separately
   costs three rounds of the same meeting. §3.1 and §3.2 have the proposed resolutions; they
   need agreement, not more analysis.
2. 🔴 **Put the transaction primitive in the foundation layer** (§3.3a, Gap 17). This is the
   one item on this list that cannot be fixed inside Epic 02. The foundation must not be
   accepted as done without it, because retrofitting transaction support after four epics have been
   written against a fresh-connection-per-call `database.execute()` is a substantially larger
   change than adding it before the first ticket. Note the `mssql` (node-mssql) driver
   exposes a first-class `Transaction` object, so the primitive is cheaper to build in
   TypeScript than the reference design implied — but it still has to be *designed in*, not
   bolted on.
3. 🟡 **Confirm the TypeScript foundation is sequenced ahead of Epic 02 and staffed.**
   [README.md](solution-doc:5090) makes the foundation epic the upstream gate for everything;
   this story's writer calls the `database` singleton it creates
   (**src/core/database.ts**). Also confirm the **TypeScript repository is stood up** —
   it does not exist yet in any form — and that dependency versions are pinned in a
   committed `package.json` + lockfile. [the reference symbol allow-list](solution-doc:5091) §10
   records that no dependency manifest existed at the time of writing; that allow-list is
   reference-only and a Node equivalent must be authored before the first ticket, or the
   pinning becomes retro-fitting to whatever npm happened to resolve.
4. **Raise the client-asserted-token defect as its own ticket.** Finding 2 is a live
   data-integrity issue in shipped code. It should be on the board whether or not Epic 02 proceeds.
5. **Verify and rotate the API key** in `pacEHR_API/PacEHR.API/appsettings.json`. Separate
   security ticket.
6. **The language question is closed** — TypeScript/Node.js, with the 12-epic reference corpus
   as the language-neutral specification. The name collision that rode along with it is also
   closed (§2.8, `agentRun`). Residual: an editorial correction to doc 3777 §3.1.
7. **Open the grants/roles infrastructure story now.** Four of the six Epic 02 stories depend
   on principals that do not exist. It is on the critical path and nobody owns it.
   [epic-02-data-layer.md](solution-doc:5077) names three roles — `aiServiceRuntime`,
   `aiPromptAdmin`, `aiTemplateAdmin` — which sharpens the requirement but does not change
   the fact that this repository has zero `CREATE ROLE` and zero `GRANT` precedent (§2.6).
8. **Get rule-3 sign-off on `BIGINT` and `VARCHAR(64)`** before any DDL is written, with the
   HL7_MSH.sql precedent attached.
9. **Add the `.sqlproj` manifest test.** Small, and it retires a silent-failure mode that
   threatens every story in this epic.
10. **Re-point or split this story** per risk 12 before it enters a sprint. The §3.1 DDL is
    larger than the one the 3-point estimate was written against.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - All four LLM call sites; hardcoded gpt-4o at lines 176/230/282/334; no timing, no SDK. The class this story must instrument.
- `PacEHR/src/app/core/services/open-ai.service.ts` - Lines 277/351/414 write token usage to localStorage — the root of Finding 2.
- `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` - Line 618 reads localStorage tokens back and POSTs them.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AILogs.sql` - The existing all-nullable audit table this one corrects.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Line 2 resolves encounterID as INT IDENTITY; line 6 shows providerID casing.
- `pacEHR_API/CLAUDE.md` - Binding rules 1–8: datatypes, dual-artefact scripts, .sqlproj registration, proc naming, release-script copying.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest; line 10 DSP shows SQL Server 2022 target; zero `<None>` entries.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14 is the CHECK-constraint style to copy for `outcome`.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11 establishes `DEFAULT (getutcdate())` as the house form.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The actual deployment mechanism for this table.

**Solution documents consulted at Revision 4** (the reference Epic corpus — not repository files, so not drift-tracked here): epic-02-data-layer.md (5077), GAPS.md (5089), README.md (5090), the reference symbol allow-list (5091), CLAUDE.md (5093), epic-01-foundation.md (5099), epic-09-review-api.md (5085), epic-10-observability.md (5086).

### Medium Relevance
- `PacEHR/src/app/features/dashboard/add-rounding-notes/add-rounding-notes.component.ts` - Line 1009, second client token POST site.
- `PacEHR/src/app/features/encounter-list/encounter-form/ai-summary-prompt/ai-summary-prompt.component.ts` - Line 229, third client token POST site.
- `pacEHR_API/PacEHR.API/Controllers/AIController.cs` - Endpoint surface including addEditAILogs.
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The partial class every new procedure must be exposed through.
- `pacEHR_API/pacEHR.DomainServices/VideoCallService.cs` - Lines 116–118, the in-repo SHA-256 pattern to copy.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AIAcoEncounterLogs.sql` - Second existing AI log table.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AISummaryLog.sql` - Third AI log table; no token columns.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` - BIGINT IDENTITY precedent for the rule-3 escalation.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql` - Lines 20–26, further CHECK-constraint precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` - Proves the AI schema already exists (rule 1 check).
- `pacEHR_API/PacEHR.Tests.UnitTests/DomainServices/AIPromptServicesTest.cs` - Existing coverage that must be extended before instrumenting.
- `pacEHR_API/PacEHR.API/appsettings.json` - Contains the live-looking key flagged for rotation.

### Low Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql` - Additional CHECK precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/medicalDirectorActivity.sql` - Additional CHECK precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/treatmentPlanGoal_1.sql` - Additional CHECK precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/gehrimedData_OMH.sql` - Second BIGINT IDENTITY precedent.
- `pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql` - The only release script that has ever existed.
- `pacEHR_API/PacEHR.Tests.UnitTests/Controllers/AIControllerTests.cs` - Existing AI controller coverage.
- `pacEHR_API/pipelines/` - 12 pipeline files; searched and confirmed to contain no database deployment.
