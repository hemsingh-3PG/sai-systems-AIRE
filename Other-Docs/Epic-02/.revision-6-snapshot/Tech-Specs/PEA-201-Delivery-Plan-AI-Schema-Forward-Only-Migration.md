# PEA-201 Delivery Plan — Create the AI Schema via a Forward-Only Migration Mechanism

**Epic:** E2 — Data Layer — AI Schema Tables · **Story:** PEA-201 · **Points:** 5 as written; **8–13 recommended**
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — for engineering review · **Build target:** TypeScript/Node.js

**Revision:** 6 (2026-09-30) — supersedes Revision 5 (2026-09-29). Prior revision snapshot:
`Epic-02/.revision-5-snapshot/`.

> 🔴 **Revision 6 — the build target is a port, not a greenfield build.**
> Every Revision 5 document in this folder stated that the AI service *"does not exist in any
> repository"* and that its foundation had *"no repository, no skeleton, no pipeline and no
> backlog."* **That was verified against two repositories out of three.**
>
> `pacEHR_AI/` exists and holds a **complete, tested Epic 01 in Python** — `core/settings.py`,
> `core/database.py`, `core/llm.py`, `core/auth.py`, `core/errors.py`, `core/logging.py`;
> 2,229 lines with unit and integration suites; `mssql_python` over managed identity; the
> module-singleton pattern; and the two PHI guards enforced as tests rather than as
> convention.
>
> **Consequence for this story:** the foundation dependency (M9) is a **module-for-module port
> at 5–8 points**, not a 13+-point build. The DDL, the vocabularies, the constraints and the
> clinical reasoning in this spec are **unchanged** — they never depended on the language.
> What changes is the readiness of the runtime half and the confidence of its estimate.
>
> ⚠️ **The port's acceptance criterion is three invariants, not six files:** `process.env`
> confined to `src/core/settings.ts`, no interpolated log message, and no network access at
> import time. Each has a Python test in `pacEHR_AI/tests/unit/` to translate. Porting the
> modules without the tests yields a service that looks complete with both PHI guards
> silently gone (rollup risk R18).
>
> 🔴 **Also open — D1b.** `docs/architecture/design/12-ai-phase1-implementation-architecture.md`
> Part 2 recommends **in-solution `PacEHR.AI.*` (.NET)** and defers a standalone service to
> Phase 2/3. No Revision 5 document cites it. The owner has selected standalone TypeScript;
> that choice overrides a written recommendation and should be recorded as such.

---

## Scope and premises

**The build target is a TypeScript/Node.js AI service, ported from `pacEHR_AI/`.** It will
live in a **new, standalone TypeScript repository** that has not yet been created and is not
ingested into this solution. **No existing C# AI logic is reused or migrated** — that part of
the Revision 5 framing stands. What changes at Revision 6 is the starting point: the service
is **not** greenfield in its foundation layer, because `pacEHR_AI/` already implements Epic 01
in Python and is the port source. The runtime call chain is **Angular frontend → .NET Web API
→ TypeScript AI service → Azure OpenAI**.

**The DDL is language-neutral, and that is the critical engineering point.** Every table,
column, datatype, key, index, CHECK constraint and role in this plan is T-SQL and is
completely unaffected by the host language of the service that runs it. The schema work is
portable as-is.

**Only five things are language-bound:** the migration runner, the repository/writer classes,
the driver, the config mechanism and the test framework. Specifically
**src/core/databaseMigrations.ts** rather than a Python runner; the `mssql` npm package
(node-mssql, over tedious) rather than `mssql_python`; zod-validated config in
**src/core/settings.ts** rather than pydantic-settings; vitest rather than pytest. Finding 2
and Phase 0 carry the full mechanism specification.

**⚠️ Revision 6 re-ranks the binding constraint: it is principals and deployment, not the
foundation.** The service still needs **src/core/settings.ts** (zod config),
**src/core/database.ts** (the `database` singleton, natively async via `mssql`),
**src/core/llm.ts**, **src/core/errors.ts**, **src/core/logging.ts** and **src/core/auth.ts**
before any migration script or repository class in this epic can run — every one of them calls
that singleton. But all six **exist in Python** at `pacEHR_AI/core/`, tested, so that
dependency is a 5–8-point port with a reference implementation.

**M1 (principals and grants) and M2 (a database deployment pipeline) have no reference
implementation and no precedent anywhere in 2,857 SQL files.** They are now the longest pole.
Phase 0 and the risk register are revised accordingly.

**The team-space Python corpus is the reference design and is deliberately unmodified.** It
comprises 12 epics and 75 stories plus four governing documents —
[CLAUDE.md](solution-doc:5093) (engineering standard),
[00-source-index.md](solution-doc:5092) (requirement index with line citations),
[00-langchain-api-truth.md](solution-doc:5091) (a verified Python symbol allow-list) and
[GAPS.md](solution-doc:5089) (an independent eight-review audit), with the build order fixed
in [README.md](solution-doc:5090): **Epic 1 → Epics 2 & 3 → Epic 4 → 5/6/7 → 9/8/10 → 11 →
12.** Where those documents specify Python, they record approved design intent; this document
records the build target. ⚠️ **Doc 5091 governs Python libraries only — a Node dependency
allow-list must be authored**, with `pacEHR_AI/pyproject.toml`'s seven pinned dependencies as
the shape to map.

**🔴 Revision 6 correction to this paragraph.** Revision 5 closed it with *"no
Epic-01-equivalent backlog exists for Node."* True of the backlog, and misleading about the
work: **Epic 01 is not merely backlogged, it is delivered** — in Python, in `pacEHR_AI/`, with
tests. The reference corpus is no longer only a paper design; its first epic is running code.

The repository excavation in §1–§2 describes the system the TypeScript AI service must coexist
with, read from, and not break. Those constraints are **more** load-bearing under a new
service, not less, because it inherits every one of them without inheriting the SSDT tooling
that currently manages them.

**Two claims commonly made about this repository are false, and are recorded here so they are
not re-raised:**

| Claim | Verdict | What is actually true |
|---|---|---|
| "Phantom `.sqlproj` registration — `Scripts\Script.25-Oct-2026\demo.sql` does not exist on disk." | ❌ **False** | The folder and file **both exist**. `pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql` is a one-line stub containing only `GO`. The registration is not phantom, and a PR "fixing" it would delete a working registration. |
| "It is registered as `<Build>` when rule 5 requires `<None>`." | ⚠️ **Technically true, wrongly framed** | It is registered as `<Build>` — but so is nearly everything. ⚠️ **Corrected 2026-09-30:** the `.sqlproj` contains **12** `<None Include=…>` entries against **2,852** `<Build>`, not zero as Revision 5 recorded. The framing survives the correction: a path used twelve times in a 2,857-file project is not one anyone should rely on silently. See Finding 6. |

---

## 1. Findings That Change the Story

### Finding 1 — The `AI` schema already exists ✅ — and is **not in source control** 🔴

The epic's goal states *"a copy of the production database with no AI schema."* That is false.

- `AI.prompt` is deployed and live — `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` opens with `CREATE TABLE [AI].[prompt]`.
- Three stored procedures read and write it: `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditAiPrompt.sql`, `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getAiPrompts.sql`, `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_deleteAiPrompt.sql`.
- A **full admin UI** already manages it: `PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` plus an add/edit modal, talking to `PacEHR/src/app/core/services/prompt.service.ts`.

**🔴 Revision 6 adds the half of this finding that was missed — the schema is live and is not in source control.** There is **no `CREATE SCHEMA [AI]` statement anywhere** in the 2,857 `.sql` files (re-verified 2026-09-30), yet `[AI].[prompt]` is registered in the `.sqlproj` and deployed. The schema was created out of band, and the SSDT project has carried an undeclared dependency on it ever since — a fresh deploy to an empty target would fail on the first `[AI].` object.

**Impact:** `CREATE SCHEMA AI` is a no-op **against production** and is **not** a no-op against source control or a clean environment. PEA-201's real deliverables are therefore four, not three: the three roles, the migration mechanism, **and bringing the existing `AI` schema under source control for the first time** (defect X9). That last one changes the story's character — PEA-201 is a *reconciliation*, not a greenfield create, and its `0001` must be written `IF NOT EXISTS` for correctness rather than merely for idempotent re-runs.

And PEA-205's "legacy `AI.prompt` taken off the runtime path" is not a data migration — it is the **replacement of a shipped, in-use admin feature**. That is not a 3-point story.

### Finding 2 — The build target is a TypeScript/Node.js service **ported from `pacEHR_AI/`**

**The language question is settled: TypeScript/Node.js.** What remains open is not *which
platform* but a programme-sequencing question — **is the new TypeScript repository stood up,
and is it staffed?** That is a narrower blocker, and it is tracked in Phase 0 and the risk
register.

**🔴 Revision 6 changes the size of that blocker.** Revision 5 recorded that the TypeScript
repository *"does not exist in any form"* and treated its foundation as unwritten. The
repository indeed does not exist — but **the foundation it needs does**, in Python, at
`pacEHR_AI/core/`: `settings.py`, `database.py`, `llm.py`, `auth.py`, `errors.py`,
`logging.py`, with unit and integration suites. The Epic-01 work this story waits on is a
**port at 5–8 points**, not a build at 13+.

**The mechanism** (reference design: [epic-02-data-layer.md](solution-doc:5077), adapted to TypeScript):

| Element | Specification |
|---|---|
| Runner | `class MigrationRunner` in `src/core/databaseMigrations.ts`, one public method `applyPending()` |
| Scripts | migrations/sql/0001_create_ai_schema.sql … 0006_create_field_description.sql — **UNCHANGED**. The same numbered T-SQL scripts apply regardless of host language |
| Idempotency | `IF NOT EXISTS` existence checks per object — **UNCHANGED**. Still deliberately no migration-history ledger table |
| Driver | `mssql` npm package (node-mssql, over tedious), reached through a `database` singleton in `src/core/database.ts` |
| Async path | **Natively async — a genuine improvement over the Python design.** The Node SQL driver (`mssql`) is async by construction. The `asyncio.to_thread` thread-pool wrapper Python needed to make the synchronous `mssql_python` driver work in an async context simply disappears. This is one of the few places the language change makes the design simpler rather than merely different. Call it `execute()` — no wrapper, no thread pool |
| Roles | `aiServiceRuntime`, `aiPromptAdmin`, `aiTemplateAdmin` — **UNCHANGED** |

⚠️ **The no-ledger decision deserves a second look before Phase 2.** `IF NOT EXISTS` proves an object exists; it does not prove *which script version created it*. A script edited after it has been applied in production will silently short-circuit on every subsequent run, and nothing records the drift. The epic's stated reason — avoiding a sixth table — is a real cost, but it is a smaller cost than an undetectable divergence between the script set and the deployed schema. Recommend raising this with the epic author rather than implementing around it. This concern is language-independent.

The repository observation still stands: `src/core/databaseMigrations.ts`, the `MigrationRunner` class, the `mssql` driver wiring, and the numbered scripts migrations/sql/0001_–0006_ do not yet exist on disk in any repository, because the TypeScript AI service repository has not been created. **Note the asymmetry Revision 6 introduces:** `src/core/database.ts` has a working Python counterpart to port from, whereas `src/core/databaseMigrations.ts` does not — no migration runner was ever written in `pacEHR_AI/` either. **The runner is the genuinely new code in this story**, and it should be estimated as such.

**Contingency mapping only** — this table is what a .NET/SSDT rewrite *would* look like if the TypeScript AI service were abandoned in favour of the existing .NET infrastructure. It is retained as an archaeological record and is **not a recommendation**:

| Epic assumes (TypeScript + `mssql` driver) | Repository actually is |
|---|---|
| TypeScript + `mssql` driver; `src/core/databaseMigrations.ts` | .NET 8 (`pacEHR_API/pacEHR.sln`), C# |
| `src/core/databaseMigrations.ts` | SSDT project (`pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj`) |
| Numbered scripts under `migrations/sql/` | Dated release folders under PacEHR.Database/Scripts/ |
| Repository classes, `_SQL` constants | Stored procs bound on `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` |

**The twist:** there *is* Python in this repository — but it is release **tooling**, not application code. `pacEHR_API/.claude/skills/pacehr-release-sql/` contains four Python scripts and a PowerShell driver that consolidate a release folder into deployable DDL and SP files. See Finding 5; this is the mechanism PEA-201 should actually target for the DDL itself.

**What the architecture documents establish, and where this document differs:**

- **Doc 3777 §3.1** names a new component outright: an **AI Orchestrator · NEW**, comprising an Ingest Gateway, a pipeline, and a Prompt + Config Registry. The ownership split is stated explicitly: *"The .NET API keeps owning auth, persistence and the existing contract. The orchestrator owns AI decisioning only."* `AIController` becomes a thin proxy to the orchestrator. **This split is unchanged and remains correct.**
- **Doc 3777 §14** puts the orchestrator as the **opening item of the Phase 1 roadmap** — it is the first thing to be built, not a stretch goal. **Also unchanged.**
- ⚠️ **The difference is the language, and only the language.** Doc 3777 §14 specifies that orchestrator as a "Python sidecar + LangGraph", and **Doc 3776** corroborates at implementation level (`create_react_agent` from `langgraph.prebuilt`, Pydantic response models, `init_chat_model`). Those documents are the **reference design and are deliberately left as they are** — and `pacEHR_AI/` is that design's Epic 01, built and tested in Python. The build target is a **TypeScript/Node.js service ported from it** — new repository, no reuse of the existing C# AI logic, runtime chain Angular → .NET Web API → TypeScript AI service → Azure OpenAI. Confirm with Architecture that this is the target of record before PEA-201 is picked up — and settle **D1b**, since `docs/architecture/design/12-ai-phase1-implementation-architecture.md` recommends a third answer (in-solution `PacEHR.AI.*`, .NET) that no Epic-02 document has cited.

**Impact.** The language question is **answered: TypeScript/Node.js.** The .NET/SSDT mapping table above is a **contingency**, not a recommended path; do not action it as a rewrite.

What remains is a **narrower** blocker — a programme-sequencing question rather than an architecture one — but a demanding one, because the TypeScript repository does not exist in any form:

1. Does the AI service **exist yet** — is there a Node repository, a skeleton, a CI pipeline? **No Node one.** Neither `PacEHR/` nor `pacEHR_API/` contains a Node/TypeScript backend: no `nest-cli.json`, no `serverless.yml`, no backend `package.json`; the only TypeScript there is the Angular SPA. ⚠️ **But `pacEHR_AI/` is a third repository and it does contain the service** — in Python, with Epic 01 complete and tested. The question is therefore not "does a foundation exist?" (it does) but: **who ports it, and when?**
2. Is it **staffed**, and by whom? Doc 3777 is "approved for planning", which is not the same as "in flight" — and it planned a *Python* service, so its staffing assumptions do not transfer directly.
3. Is Epic 02 sequenced **before or after** the service stands up? If before, PEA-201 ships correct, empty tables that nothing writes to for an unknown interval.
4. **Who authors the Node foundation and its dependency allow-list?** Under the Python plan, Epic 01 (PEA-101…106) delivered **core/settings.py**, **core/database.py**, **core/llm.py** and the governing allow-list [00-langchain-api-truth.md](solution-doc:5091). **None of that transfers** — the allow-list constrains Python libraries and has no force over a Node runtime. A TypeScript equivalent (**src/core/settings.ts** via zod, **src/core/database.ts** via node-mssql, plus **llm.ts** / **errors.ts** / **logging.ts** / **auth.ts**) plus a Node dependency allow-list must be authored, and there is no published backlog for it. **This is the largest new risk the retarget introduces.**

**The DDL itself is unaffected either way.** Doc 3777 §3.1 places the AI tables in the *same SQL Server instance* as `Template.*` and `Log.AILogs` — there is no separate AI datastore. The schema, roles and constraints PEA-201 delivers are correct regardless of which service writes them, in which language, and regardless of when that service arrives. **PEA-201 is not blocked on the orchestrator.** Only its *value realisation date* is.

### Finding 3 — Datatype violations are real, but the approved list is already widely ignored ⚠️

`CLAUDE.md` § SQL rule 3 restricts new tables to `BIT` · `INT` · `NVARCHAR` · `VARCHAR` · `DATETIME` · `DATE` · `DATETIME2`.

| Epic column | Epic type | Precedent in repo | Recommendation |
|---|---|---|---|
| `plausibleMin/Max`, `abnormalMin/Max` (PEA-206) | `FLOAT` | `DECIMAL(6,2)` used for the identical concept — `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` | **Use `DECIMAL(6,2)`.** Matches precedent, avoids float comparison bugs in clinical ranges, and sidesteps the exception entirely |
| `runID`, `outcomeID` (PEA-202/203) | `BIGINT` | Widely used — 267 matches across Tables/, e.g. `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` uses `BIGINT IDENTITY` | Justified by the 10.95M rows/year volume. Request the exception with the volume figure attached |
| `sourceProse`, `fragmentText` | `NVARCHAR(MAX)` | Pervasive, incl. `AI.prompt.prompt` itself | Effectively already house style. Low-risk exception |
| `promptHash` (PEA-202) | `CHAR(64)` | None found | Use `VARCHAR(64)` — a SHA-256 hex digest is fixed-length ASCII; the storage saving from `CHAR` is nil and `VARCHAR` is on the approved list |

**Impact:** two of four can be designed away rather than escalated. Only `BIGINT` and `NVARCHAR(MAX)` genuinely need sign-off.

### Finding 4 — 🔴 The epic's central premise about token counts is correct, and worse than stated

PEA-202 justifies `AI.agentRun` partly because `Log.AILogs` carries *"client-asserted token counts."* **Verified true, with the exact mechanism:**

1. The browser reads the model's `usage` object out of the streaming response and parks it in browser storage — `PacEHR/src/app/core/services/open-ai.service.ts` lines 277, 351, 414: `if (json.usage) { localStorage.setItem('OpenAIStreamTokenData', JSON.stringify(json.usage)); }`
2. Three separate components later read that key back and POST it to the server — `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` line 618, `PacEHR/src/app/features/dashboard/add-rounding-notes/add-rounding-notes.component.ts` line 1009, `PacEHR/src/app/features/encounter-list/encounter-form/ai-summary-prompt/ai-summary-prompt.component.ts` line 229 — each sending `prompt_tokens: tokenData?.prompt_tokens ?? 0`.
3. The server stores whatever arrives. `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditAILogs.sql` takes `@prompt_tokens`, `@completion_tokens`, `@total_tokens` **as parameters** and inserts them verbatim. Nothing is computed or validated server-side.

**Why this is worse than the epic says:**
- Token counts are **fully client-controlled** — writable from any browser console. If these numbers inform cost attribution or capacity planning, they are unreliable by construction.
- If the browser tab closes mid-stream, **no log row is written at all.** The AI call happened; the audit record does not exist. For a clinical AI audit trail this is a material gap.
- The same path also carries `system_content`, `user_content` and `resp_content` — **prompt and response text round-trips through the browser** before being stored.

**Impact:** this is the strongest available argument for `AI.agentRun`, and it should be the epic's headline justification rather than a footnote. It also makes the server-side write in PEA-202 a **correctness fix, not a nice-to-have**.

### Finding 5 — 🔴 There is no database CI/CD at all

Twelve pipeline files exist under `pacEHR_API/pipelines/`. I searched all of them for `dacpac`, `SqlPackage`, `sqlproj` and `Database`: **one match, and it is a comment.**

- `pacEHR_API/pipelines/deploy-pacehrapis.yml` and `pacEHR_API/pipelines/jobs/deploy-pacehrapis-job.yml` publish `PacEHR.API.csproj` to an Azure Web App. **No step builds the SSDT project, produces a `.dacpac`, or deploys schema.**
- No `.dacpac`, `.publish.xml`, or `.publishsettings` file exists anywhere.
- Database deployment is **entirely manual**, assisted by the release harness at `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` — which consolidates a dated release folder into a DDL file and an SP file, runs a duplicate-object report that *gates* the build, and verifies output against a git ref. It reads from a git ref, never the working tree.

**Impact:** any plan that assumes a "CI/CD automation" path for schema is describing a pipeline that does not exist. PEA-201's migration mechanism must either (a) plug into the existing manual release-harness flow, or (b) include building the database CI/CD that is currently absent — which is far more than 5 points. **This is the second blocking decision.**

### Finding 6 — Roles and schemas have *no* precedent in the SSDT project

Searched all 2,834 `.sql` files:

| Pattern | Matches |
|---|---|
| `CREATE SCHEMA` | **0** |
| `CREATE ROLE` / `CREATE USER` / `ALTER ROLE` / `GRANT ` | **0** (the only hits are the word "auto-grant" in two unrelated referral procedure comments) |
| A `Security/` folder | **Does not exist** |
| `<None Include=…>` entries in the `.sqlproj` | **0** of ~2,845 |

**Impact — this is the quiet killer for PEA-201.** The story's deliverables are a schema and three roles. This project has **never** deployed either. Every schema in the database (`AI`, `Encounter`, `Log`, `Patient`, `Template`, …) was created outside SSDT and is inferred at deploy time. So PEA-201 is not "write a script in the established pattern" — it is **establishing a pattern that does not exist**, including deciding where security objects live, how they are reviewed, and how they reach production given Finding 5. That alone justifies re-pointing the estimate.

### Finding 7 — Prior art already exists for three of the five proposed tables

The epic treats all five tables as greenfield. Three overlap existing structures:

| Proposed table | Existing overlap | Assessment |
|---|---|---|
| `AI.fieldConstraint` (unit, plausible/abnormal min-max) | `Patient.vitalConfig` — has `unit VARCHAR(20)`, `normalMinValue`/`normalMaxValue`, `abnormalMinValue`/`abnormalMaxValue`, `alertOnMinValue`/`alertOnMaxValue`, all `DECIMAL(6,2)` | **Different grain** (vital-type + patient-scoped vs. template-field-scoped), so not a duplicate — but the column design and datatypes should be copied deliberately, and someone must decide which wins when both describe the same measurement |
| `AI.fieldDescription` / `AI.promptFragment` | `Template.fields` already has `prompt VARCHAR(MAX)`, `allowAISummary BIT`, and `aiSummaryPrompt NVARCHAR(MAX)` — see `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` lines 14–16 | **Direct functional overlap.** Per-field AI prompt text already exists and is already wired to the UI. The epic never mentions it. Migration and precedence rules are undefined |
| `AI.fieldOutcome` (proposal vs. decision) | `Template.normals` + `pacEHR_API/PacEHR.Database/Tables/Tables2/templatefieldNormals.sql` + `Encounter.encounterNormals` | Not equivalent — those are a curated response library and a per-encounter selection log, with no proposal/decision split. **No real overlap**; the epic's design is sound here |

**Impact:** PEA-206 and PEA-207 need a "what happens to `Template.fields.aiSummaryPrompt`" answer before they can be built. Two prompt-storage locations with no precedence rule is a defect waiting to ship.

### Finding 8 — Three different spellings of "template" are live simultaneously

| Spelling | Where | Type |
|---|---|---|
| `templetID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` | `INT NOT NULL` |
| `templeteId` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 16 | `INT NULL` |
| `encounterTempleteID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` | `INT IDENTITY` PK |

All three are load-bearing, and the misspellings propagate into TypeScript — `PacEHR/src/app/core/models/template-editor.model.ts` declares `templetID: number`. Per `CLAUDE.md` § SQL rule 8, **do not "correct" any of them.** The new AI tables reference the *mapping* grain, so they must use `templetID`.

---

## 2. Current State — Verified Inventory

### 2.1 Platform

- **Azure SQL**, managed as an SSDT project: `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` (2,920 lines, ~2,845 `<Build>` registrations, 2,834 `.sql` files on disk).
- ⚠️ **The project's schema provider is `Sql170DatabaseSchemaProvider`** (`PacEHR.Database.sqlproj` line 10) — that targets **SQL Server 2022**, not Azure SQL. If the target really is Azure SQL Database, this is a latent mismatch worth confirming: it permits on-prem-only syntax to compile and then fail at deploy.
- The ~11-file gap between registrations and files on disk was not resolved and should be treated as unknown, not as zero.

**Forward-looking — the approved target platform is wider than what is on disk.** The inventory above describes the platform *as built*: .NET 8 + SSDT + Angular. The target call chain adds a **TypeScript/Node.js AI service** as a new, standalone component: Angular frontend → .NET Web API → TypeScript AI service → Azure OpenAI. Two consequences for this plan:

- The database remains **one SQL Server instance**. Doc 3777 §3.1 places the new AI tables in the same box as `Template.*` and `Log.AILogs`. There is no second datastore, no polyglot persistence, and therefore no change to how PEA-201 delivers DDL. This is unaffected by the language switch.
- The **writer** of those tables will be the TypeScript/Node.js AI service, not the .NET API. That matters for PEA-201 only in one place: the three roles it creates must be grantable to a service principal that the Node service can authenticate as. The `mssql` npm package (node-mssql) supports Azure AD / Managed Identity authentication natively — confirm the service principal is provisioned using that mechanism before the roles are finalised. See Phase 0.

### 2.2 The existing AI footprint — larger than the epic accounts for

| Object | File | Contents |
|---|---|---|
| `AI.prompt` | `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` | `promptId`, `prompt NVARCHAR(MAX)`, `isActive`, `templateId`, `promptName`, `accountId`, `type`, `isUniversal`, audit columns |
| `Log.AILogs` | `pacEHR_API/PacEHR.Database/Tables/Tables1/AILogs.sql` | `system_content`, `user_content`, `resp_role`, `resp_content`, `prompt_tokens`, `completion_tokens`, `total_tokens` — all `NULL`-able |
| `Log.AIAcoEncounterLogs` | `pacEHR_API/PacEHR.Database/Tables/Tables1/AIAcoEncounterLogs.sql` | Same shape minus `resp_role` and the modified-by columns |
| `Log.AISummaryLog` | `pacEHR_API/PacEHR.Database/Tables/Tables1/AISummaryLog.sql` | `selectedEncounterIds`, `selectedEligibleFields` — no token columns |
| `Template.fields` AI columns | `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` | `prompt`, `allowAISummary`, `aiSummaryPrompt` (Finding 7) |

Server-side writers: `usp_addEditAILogs.sql`, `usp_addAISummaryLogs.sql` (both Procs1) and `pacEHR_API/PacEHR.Database/Stored Procedures/Procs2/usp_InsertAIAcoEncounterLog.sql`. All three take token counts as parameters; none compute them.

### 2.3 The live runtime AI path

- All LLM calls originate in `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` — raw `HttpClient` via `IHttpClientFactory`, **no Azure OpenAI SDK**.
- **The model is hardcoded** as `"gpt-4o"` with `temperature = 0` at four sites (lines 176, 230, 282, 334). PEA-202's `modelDeployment` column would therefore record a compile-time literal, not a configured value — worth noting, since the column exists to support model comparison.
- Credentials resolve from a database settings table (`OPENAI_API_KEY`, `OPENAI_API_URL`) with a fallback to the `APIkeySettings:openAIapiKey` configuration key. No Key Vault or managed identity wiring was found.
- 🔴 **Credential hygiene:** a live-looking key value appears to be committed in `pacEHR_API/PacEHR.API/appsettings.json`. **Verify and rotate if confirmed.** Out of scope for PEA-201, but it should not wait on an epic.
- Endpoints live in `pacEHR_API/PacEHR.API/Controllers/AIController.cs` — `streamCompletion`, `streamCompletionWithData`, `getCompletion`, `streamTemplateCompletion`, plus prompt CRUD and `addEditAILogs`.
- The browser never calls OpenAI directly — verified zero references to `openai.azure.com` or `api.openai.com` in the Angular source. All traffic goes through the API. ✅

### 2.4 No vector infrastructure — and none needed in Phase 1

Zero matches for `pgvector`, `VECTOR(`, or `embedding` across the API repository. `pgvector` is a PostgreSQL extension and is not applicable to Azure SQL regardless. Phase 1 introduces no embeddings; see §3.3.

### 2.5 🔴 No clinician review surface exists

There is **no existing UI where a clinician reviews or accepts an AI-proposed field value before it is committed.** AI summary results are applied straight into the encounter form. `AI.fieldOutcome`'s proposal/decision split — the evaluation ground truth for the whole programme — therefore has **no UI to populate `acceptedValue`, `decidedByProviderId`, or `decidedAtUtc`.** Those columns will be uniformly `NULL` until a review queue is built in a later epic. Build the table, but do not expect decision data from it in Phase 1.

> **Independently confirmed, and worse than the paragraph above implies.** [GAPS.md](solution-doc:5089) §3 item 1 reaches the same conclusion from the opposite direction and states it more bluntly: the Angular review panel and admin UI are **out of scope in Epics 9, 10 and 11 alike**, so no epic in the 75-story backlog owns building them. Its summary — *"the feature has no user"* — is not rhetorical. [Epic 9](solution-doc:5085) specifies the review payload in full detail (`PEA-903`: suggested value, `found_in` quote, confidence band, reason code, three actions) and `PEA-904` specifies applying the decisions, but both describe a **JSON contract with no client**. Something must render those cards and something must call resolve; neither exists and neither is scheduled.
>
> This makes the issue larger than "decision columns stay NULL in Phase 1" — it is a **programme-level scope hole**. It is the same defect tracked as **M5** (nobody owns prompt-authoring/versioning UI), now revealed to be much larger than prompt authoring: it is the entire clinician-facing and admin-facing surface. See the [grooming rollup](solution-doc:5006) §5 for the consolidated position and the estimate impact.

### 2.6 Patterns with precedent ✅ *(good news for the epic)*

| Pattern the epic uses | Precedent | Example |
|---|---|---|
| `CHECK` constraints | ✅ 5 files | `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql`, `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql` |
| Filtered indexes (`… WHERE …`) | ✅ 10 files | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterCPT.sql` — `WHERE ([calculatorEntryId] IS NOT NULL)` |
| `BIGINT IDENTITY` | ✅ | `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` |
| Audit triggers to `Log.*` | ✅ pervasive | `fields.sql`, `encounterTempletMapping.sql` |

The epic's `IX_fieldOutcome_pending` filtered index and its `CHECK` constraints are all consistent with house practice. No exception needed.

### 2.7 Name-collision check ✅ **all clear**

Case-insensitive search across all 2,834 `.sql` files: `agentRun`, `fieldOutcome`, `promptFragment`, `fieldConstraint`, `fieldDescription` — **zero matches each.** No collisions *in the database*.

✅ **The cross-document naming collision is resolved — `agentRun` wins.** [Doc 3777 §3.1](solution-doc:3777) calls the run-level telemetry table `AI.runAudit` while the epic calls it `AI.agentRun`, so the canonical name had to be settled before PEA-202 could be built.

The evidence settles it. [epic-02-data-layer.md](solution-doc:5077) is the newer document and it carries **full DDL for `AI.agentRun`**; three further epics in the same corpus — [Epic 9](solution-doc:5085) (`PEA-902`), [Epic 10](solution-doc:5086) (`PEA-1003`) and [GAPS.md](solution-doc:5089) — all name `AI.agentRun` and none mentions `runAudit` anywhere. A single passing reference in an older architecture document does not outweigh a DDL block plus three consuming specifications.

**Decision: `AI.agentRun` is canonical.** D17/D18 in the [Epic 02 grooming rollup](solution-doc:5006) are closed on this basis. No rename, no FK churn in PEA-203. The only residual action is editorial: doc 3777 §3.1 should be corrected when someone next touches it, so the stale name does not resurface in a future design review.

### 2.8 Column types confirmed — resolves an epic open question

| Column | Source | Type |
|---|---|---|
| `encounterID` (PK) | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 2 | **`INT IDENTITY(1,1) NOT NULL`**, `PK_encounterID` |
| `encounterID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterData.sql` | `INT NOT NULL` |
| `templetID` / `sectionID` / `fieldID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` | `INT NOT NULL` |
| `fieldID` (PK) | `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` | `INT IDENTITY`, `PK_fieldID` |
| `providerID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 6 | `INT NULL` — note the **uppercase `ID`** |

**PEA-202's open question is answered:** `Encounter.encounter.encounterID` is `INT`, so `AI.agentRun.encounterID INT` aligns and a physical FK is now technically possible. Whether to *add* one remains a judgement call — the epic's instinct to omit it (an append-only telemetry table should not fail an insert because an encounter was purged) is defensible. Keep it omitted, but now for a stated reason rather than an unknown.

Note `decidedByProviderId` in PEA-203 should be `decidedByProviderID` if it is to match `encounter.providerID`. Per rule 8, match the live convention.

---

## 3. Proposed Architecture & Schema Changes

### 3.1 What PEA-201 actually delivers

PEA-201 ships **no tables**. Its deliverables:

1. A canonical, idempotent `AI` schema definition — a no-op against production, correct on a fresh database.
2. Three database roles: `aiServiceRuntime`, `aiPromptAdmin`, `aiTemplateAdmin`.
3. **A security-object convention that does not currently exist** (Finding 6) — where these files live, how they are registered, how they are reviewed.
4. The re-runnable release mechanism the other six stories plug into, aligned to the actual harness (Finding 5).
5. A CI scope guard rejecting any script touching a non-`AI` object.

Items 3 and 4 are why 5 points is too low. **Re-estimate at 8–13.**

### 3.2 Conceptual DDL

```sql
/* PEA-201 · AI schema + roles · re-runnable
   NOTE: the AI schema already exists in production (AI.prompt).
   This guard makes the script a verified no-op there, and correct on a fresh DB. */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'AI')
    EXEC('CREATE SCHEMA [AI]');
GO

-- Runtime identity: the extraction service
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'aiServiceRuntime')
    CREATE ROLE [aiServiceRuntime];
GO

-- Prompt Studio's identity (Epic 8 write path)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'aiPromptAdmin')
    CREATE ROLE [aiPromptAdmin];
GO

-- Template editor's identity (Epic 3 / Epic 6 authoring surfaces)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'aiTemplateAdmin')
    CREATE ROLE [aiTemplateAdmin];
GO

/* No table-level GRANT here. Each table's own story grants exactly what that table needs. */
```

**Why no migration-ledger table.** The epic is explicit: existence checks substitute for a ledger, keeping the table count at five. This also matches how re-runnability is already achieved in this repo — `IF NOT EXISTS (SELECT 1 FROM sys.columns …)` guards, not a version table.

⚠️ **Caveat:** the `CREATE ROLE` statements above have **no precedent in this project** (Finding 6). Confirm with whoever owns database security that roles belong in SSDT at all — they may be managed by a DBA outside source control, in which case PEA-201's role deliverable moves out of this repository entirely and the story changes shape.

### 3.3 In scope / out of scope

**In scope across Epic 2** (delivered by PEA-202..207, not PEA-201): `AI.agentRun` (invocation metadata, server-side token counts — name confirmed canonical, §2.7), `AI.fieldOutcome` (proposal vs. decision), `AI.promptFragment` (versioned prompts), `AI.fieldConstraint` (units and ranges), `AI.fieldDescription` (field semantics).

**Out of scope but specified elsewhere — the writer.** Per Finding 2, the service that writes these tables is the **TypeScript/Node.js AI service**, not the .NET API. PEA-201 does not build it, but the grants it defines must target that service's identity, and **the TypeScript foundation must land before any of Epic 02's repository classes can be written at all** — they all call the shared **src/core/database.ts** singleton. One boundary case needs an owner before PEA-206: doc 3777 has the orchestrator *reading* `AI.fieldConstraint` at decision time while the constraint registry is authored elsewhere — so `aiServiceRuntime` needs `SELECT` there but not `INSERT`/`UPDATE`. Confirm the split rather than granting broadly.

**Explicitly NOT in scope:**
- **No embedding vectors. No vector index. No RAG store.** `REQ-02-10` states no new data store is introduced.
- If embeddings are later wanted, three constraints bite at once: Azure SQL's `VECTOR` type is preview-stage; `VARBINARY`/`NVARCHAR(MAX)` emulation needs a rule-3 exception; an external store violates `REQ-02-10`.
- **Recommendation:** keep embeddings out of Epic 2. Separate ADR, with its own store decision.

---

## 4. Forward-Only Migration Mechanism (The Plan)

### 4.1 What "forward-only" means operationally

- **No down-migration scripts. Ever.** Undoing a bad migration is a new, higher-numbered forward script.
- A merged script is **immutable**. If it was wrong, the fix is `0007_fix_…`, not a rewrite of `0003_…`.
- Rationale: by the time a rollback is wanted, these tables hold real clinical rows. A blind down-migration deletes them.

### 4.2 Step-by-step

**Step 1 — Order and name the scripts.** One object per file, applied in filename order.

| # | Script | Story | Creates |
|---|---|---|---|
| 0001 | `create_ai_schema` | PEA-201 | Schema guard + 3 roles |
| 0002 | `create_agent_run` | PEA-202 | `AI.agentRun` + grants |
| 0003 | `create_field_outcome` | PEA-203 | `AI.fieldOutcome` + indexes + column-level grants |
| 0004 | `create_prompt_fragment` | PEA-205 | `AI.promptFragment` + grants |
| 0005 | `create_field_constraint` | PEA-206 | `AI.fieldConstraint` + grants |
| 0006 | `create_field_description` | PEA-207 | `AI.fieldDescription` + grants |

**Step 2 — Statically literal SQL.** No string building, no runtime parameters, no dynamic DDL beyond the `EXEC('CREATE SCHEMA [AI]')` that SQL Server syntactically requires.

**Step 3 — Guard every statement.** `sys.schemas`, `sys.database_principals`, `sys.objects`, `sys.indexes`, `sys.columns`. Re-running the full set must raise nothing and change nothing.

**Step 4 — Dual-place every object** per `CLAUDE.md` § SQL rule 7 — canonical file **and** release-folder copy, **copy never move**. Canonical locations for the schema and roles must be decided first (Finding 6): rule 7 nominates a Security/ folder, which does not exist yet and would be created by this story.

**Step 5 — Register every file** in `PacEHR.Database.sqlproj`. An unregistered `.sql` is **silently never deployed** — it compiles, reviews and merges clean, then does not exist in the target database. Note the project uses `<Build>` universally; follow the *actual* pattern, and raise the `<None>` discrepancy separately rather than being the only story that complies.

**Step 6 — Add the CI scope guard.** Parse every shipped script and assert:
- ✅ Only `CREATE SCHEMA [AI]`, `CREATE TABLE [AI].`, `CREATE INDEX … ON [AI].`, `CREATE ROLE`, `GRANT … ON [AI].`
- ❌ No `ALTER`, `DROP`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` outside `AI`
- ❌ No reference to `Encounter.`, `Patient.`, `Template.`, `Log.`, `dbo.`

Place it in `pacEHR_API/PacEHR.Tests.UnitTests/` alongside the existing AI tests (`pacEHR_API/PacEHR.Tests.UnitTests/Controllers/AIControllerTests.cs`, `pacEHR_API/PacEHR.Tests.UnitTests/DomainServices/AIPromptServicesTest.cs`). Note: **no existing test validates database scripts or the `.sqlproj` manifest** — this guard would be the first of its kind here.

**Step 7 — Run the release harness.** `pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1` with the release date. Its duplicate-object report **gates** the build — if any object is scripted under more than one Jira id, stop and resolve before shipping. Read the verify verdict as classified (`PASS` / `WIRING` / `CASE-BUG` / `DRIFT` / `UNCLASSIFIED`); do not reinterpret a `FAIL` by hand.

⚠️ Watch the documented trap: **one release can span two folders** (`Script.20-Sept-2026` and `Script.20Sept2026` are both the 20 Sept release). Building from one alone silently ships without the other's scripts.

### 4.3 Version control & idempotency

| Concern | Mechanism |
|---|---|
| Version control | Git + numeric filename ordering. No ledger table |
| Idempotency | `IF NOT EXISTS` against system catalog views, per statement |
| Drift detection | SSDT build + schema compare against target |
| Immutability | Branch protection; a diff touching a merged migration is an automatic reject |

Note on precedent: `CREATE OR ALTER PROCEDURE` appears in roughly **5 of ~627** procedures — the re-runnability convention is aspirational, not established. PEA-201's scripts should follow it regardless, but do not assume reviewers are used to it.

### 4.4 CI/CD — what exists and what must be built

There is no database pipeline (Finding 5). What exists:

- `pacEHR_API/pipelines/deploy-pacehrapis.yml` — API only, triggered on `release/dev|qa|uat|production|automation`.
- `pacEHR_API/pipelines/pr-checklist-validation.yml` — enforces the PR checklist.
- Database changes: **manual**, via the release harness.

**What PEA-201 should add** (and should be costed honestly):
- SSDT project build on PR — currently the `.sqlproj` is not built by any pipeline.
- The scope-guard test (Step 6).
- A bidirectional registration test: every `.sql` on disk appears in the `.sqlproj`, and every `.sqlproj` entry exists on disk. This would resolve the unexplained ~11-file gap.

**Jira linkage:** the literal key (e.g. `PAC-835`) must appear in **branch name, commit message, and PR title**. Azure DevOps matches the literal key only — a bare number or `AB#1234` does not link, and **the failure is silent.** Verify the Development panel; never assume.

### 4.5 Production safety

| Mechanism | How it applies |
|---|---|
| **Additive-only DDL** | Nothing but `CREATE` inside one schema. No clinical table altered, dropped or written to |
| **Zero downtime** | New tables nothing reads yet — no locks on clinical tables |
| **Transactional DDL** | Wrap each script in `BEGIN TRAN`/`COMMIT` with `XACT_ABORT ON`. SQL Server DDL is transactional — use it |
| **Separation of identity** | The deploy identity holds schema-creation rights; `aiServiceRuntime` never does |
| **Permission-level enforcement** | Append-only on `AI.agentRun` is a `GRANT`, not a convention. Application bugs cannot bypass it |
| **Feature flags** | The AI write path stays dark until tables are verified in production |
| **Blue-green DB** | ❌ **Not recommended.** One live production database with real patient data; a blue-green split needs a clinical-data sync path — more risk than the additive DDL it protects. Use a staging restore |
| **Backup checkpoint** | Confirm the point-in-time restore window covers the deployment before applying |

### 4.6 PHI discipline

- `AI.fieldOutcome.proposedValue`, `.acceptedValue`, `.foundIn` carry clinical text.
- **Log the token, never the value** — log `outcomeID`/`runID` only.
- PEA-204's retention-refusal log names the missing setting, never a row's content.
- `AI.agentRun` and PEA-201's own scripts store **no** clinical value — state this in the DoD rather than silently skipping the rule.
- ⚠️ Note the existing path already routes prompt and response text through the browser (Finding 4). Any PHI review of the new tables should cover that path too.

---

## 5. Delivery & Exploration Roadmap

### 5.0 The story at a glance

**Assume nothing is delivered.** The live `AI` schema and `AI.prompt` are constraints to
reconcile with, not progress against this story.

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `0001_create_ai_schema.sql` — `IF NOT EXISTS` schema reconciliation (X9) + three roles | A — language-neutral, **can start today** | D2/M1, D3/M2 | 3–5 |
| **DDL** | CI schema-scope check (regex: `AI`-schema objects only, no `ALTER`/`DROP`/DML elsewhere) | A | — | 1–2 |
| **Runtime** | `src/core/databaseMigrations.ts`, `MigrationRunner.applyPending()`, `npm run migrate` | C — **genuinely new code**, no Python counterpart to port | M9 port, M10 allow-list | 3–5 |
| **Runtime** | Double-apply integration test against a scratch database | C | M9 | 1 |
| **Surface** | none — this story has no user-facing surface | — | — | 0 |
| | | | **Total** | **8–13** |

**The one asymmetry worth planning around:** every *other* module this story depends on has a
tested Python counterpart in `pacEHR_AI/core/` to port from. The migration runner does not —
`pacEHR_AI` never had one. Estimate it as new work and review it as new work.

**Exit criterion for the whole story:** `applyPending()` runs twice against a staging restore
of production; the second run raises nothing, creates nothing, and every clinical-table
checksum is unchanged across both.


### Phase 0 — Unblock (2–4 days) 🚦

**Nothing else starts until these are answered.**

- [x] ~~**Platform decision (Finding 2):** which language owns the AI service?~~ **CLOSED — TypeScript/Node.js**, a new standalone service. See Finding 2.
- [x] ~~**Table-name collision (§2.7):** `AI.agentRun` vs `AI.runAudit`.~~ **CLOSED — `agentRun`.** [epic-02-data-layer.md](solution-doc:5077) carries the DDL and three consuming epics agree. See §2.7.
- [ ] 🔴 **Settle D1b — three architectures are live.** `docs/architecture/design/12-ai-phase1-implementation-architecture.md` Part 2 recommends **in-solution `PacEHR.AI.*` (.NET)** and defers a standalone service to Phase 2/3; the reference corpus and `pacEHR_AI/` say **standalone Python**; this plan says **standalone TypeScript**. The owner has chosen TypeScript. **Record the override and its reason**, or it is reopened at integration. Half an hour, and it protects every estimate below.
- [ ] 🟠 **The foundation port must land first (M9) — bounded, with a reference.** The reference backlog's [epic-01-foundation.md](solution-doc:5099) delivers the Python equivalents, and **`pacEHR_AI/core/` is that delivery, on disk**. The TypeScript service needs the same six primitives ported — **src/core/settings.ts** (zod ← `settings.py`), **src/core/database.ts** (node-mssql ← `database.py`), **src/core/llm.ts**, **src/core/errors.ts**, **src/core/logging.ts**, **src/core/auth.ts**. **Every migration runner and every repository class in Epic 02 calls the shared `database` singleton.** [README.md](solution-doc:5090) fixes the epic order: Epic 1 → Epics 2 & 3 → Epic 4 → 5/6/7 → 9/8/10 → 11 → 12. Nothing in Epic 02 can be merged before those interfaces are stable. **5–8 points, tracked as M9** in the [grooming rollup](solution-doc:5006).
- [ ] 🔴 **Port the three invariant tests with the modules, not after.** `pacEHR_AI/tests/unit/test_settings.py` proves `os.environ` appears in one module; `test_logging_hygiene.py` proves no log call interpolates; `test_repo_scaffold.py` proves import touches no network. A port that carries the six modules and none of these three looks finished and has silently dropped both PHI guards (rollup R18). **These are the acceptance criteria for M9.**
- [ ] **Repository readiness (Finding 2):** does the *Node* repository exist yet — skeleton, `package.json`, `tsconfig.json`, CI pipeline? **No.** **Pin `mssql`, `zod`, `vitest`, the Azure OpenAI client and the Azure Identity package versions before the first ticket lands.**
- [ ] 🟠 **Node dependency allow-list (M10).** [00-langchain-api-truth.md](solution-doc:5091) governs Python libraries and has no force over a Node runtime. An equivalent must be authored before any dependency is added — **with `pacEHR_AI/pyproject.toml`'s seven pinned dependencies as the shape to map**, so this is a translation with a fixed target rather than an open design.
- [ ] **Service auth model (§2.1):** managed identity or SQL login? PEA-201's three roles must be grantable to whatever principal the Node service authenticates as. Managed identity is the right answer — node-mssql supports Azure AD / MSI authentication natively — but the principal itself must be provisioned by someone.
- [ ] **Table-ownership boundary (§3.3):** the runtime reads `AI.fieldConstraint` at decision time but does not author it. Decide which principal holds `INSERT`/`UPDATE` there before PEA-206 writes its grants — over-granting now is very hard to claw back later. Note this is the same territory as [00-source-index.md](solution-doc:5092) open question **B9** (who approves constraint bounds and fragment activation — *no RBAC model exists*), which is unowned.
- [ ] ⚠️ **No-ledger idempotency (Finding 2):** the epic deliberately omits a migration-history table. Confirm the team accepts that an edited-after-deployment script short-circuits silently with no drift record, or add the sixth table.
- [ ] **Deployment decision (Finding 5):** does PEA-201 plug into the manual release harness, or build database CI/CD? Re-cost accordingly.
- [ ] **Security-object ownership (Finding 6):** do schemas and roles belong in SSDT, or with a DBA outside source control? This determines whether PEA-201 is even a code story.
- [ ] **Datatype exceptions (Finding 3):** `BIGINT` and `NVARCHAR(MAX)` only — redesign `FLOAT` → `DECIMAL(6,2)` and `CHAR(64)` → `VARCHAR(64)` instead of escalating.
- [ ] **Prompt-storage precedence (Finding 7):** what happens to `Template.fields.aiSummaryPrompt` when `AI.promptFragment` and `AI.fieldDescription` land?
- [ ] **`Log.AILogs` future (Finding 4):** decommission, coexist, or backfill? And is the missing-row-on-tab-close gap accepted until `AI.agentRun` ships?
- [ ] **Retention window (PEA-204 / open question B7):** compliance must supply a number, or the purge stays fail-closed indefinitely. **Corroborated as genuinely open** — [doc 3777 §16](solution-doc:3777) carries the same question as Q5 ("retention for PHI evidence spans"), so this is an unanswered programme-level question, not a gap in the epic.
- [ ] **Confirm the target platform** matches the `Sql170` schema provider (§2.1).

### Phase 1 — Discovery (2–3 days) 🔍

- Run the §5.5 catalog audit against a **read-only** production replica. Never explore against live.
- Record actual column types in a findings note — *verify, do not recall.*
- Confirm the three roles do not already exist under different names **in the database** (the SSDT project has no roles at all, but the database may).
- Resolve the ~11-file registration gap.
- Branch from `PacEHR-DevelopAPI-Main` as `PAC-xxx-ai-schema-migration`. Prototype against a restored copy, never a shared environment. Catalog queries are `SELECT`-only.

### Phase 2 — Development & Testing (5–8 days) 🔨 *(widened)*

- Author the canonical schema and role definition files, establishing the convention (Finding 6).
- Write the release-folder copy for the current release cycle.
- Register everything in `PacEHR.Database.sqlproj`.
- Build the scope guard + bidirectional registration test — **the first database tests in this project.**
- **Double-apply test:** run the full set twice against a scratch DB; the second run must raise nothing and create nothing.
- **Negative test:** a draft script containing `ALTER TABLE Encounter.encounter ADD aiFlag BIT` must fail CI.
- **Isolation test:** snapshot clinical-table row counts and checksums before/after; assert zero delta.

### Phase 3 — Staging / Dry Run (2 days) 🧪

- Restore a **recent production backup** to staging — real shape, real volume.
- 🔴 **Also dry-run against an empty database.** Production already has the `AI` schema, so a
  production-restore test cannot exercise the `CREATE SCHEMA` branch at all — the branch X9
  says has never been in source control. Test both targets or that branch ships unexecuted.
- Run the release harness end to end; confirm a clean duplicate-object report. Time the apply.
- Re-apply. Confirm no-op.
- Verify the three roles exist and hold no unintended permissions.
- Re-verify clinical-table checksums unchanged.
- **Second-engineer review** of every script, line by line, before production is scheduled.

### Phase 4 — Production (1 release window) 🚀

**Pre-flight:** second-engineer sign-off recorded · staging dry-run evidence attached · point-in-time restore window confirmed · AI write path still behind its flag · Jira Development panel link **visually verified**.

**Execute** — apply in numeric order, capture full output, run the §5.5 verification set.

**Post-flight:** delete the release folder and its registrations (rule 7 — the folder is a staging area, not an archive) · confirm canonical files survived intact · confirm the SSDT project still builds.

### 5.5 Verification queries

```sql
-- Schema present
SELECT name FROM sys.schemas WHERE name = 'AI';                          -- expect 1 row

-- All three roles present
SELECT name FROM sys.database_principals
WHERE name IN ('aiServiceRuntime','aiPromptAdmin','aiTemplateAdmin');     -- expect 3 rows

-- agentRun is append-only AT THE SERVER -- the single most important check
SELECT dp.permission_name, dp.state_desc
FROM sys.database_permissions dp
JOIN sys.objects o ON dp.major_id = o.object_id
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE o.name = 'agentRun' AND pr.name = 'aiServiceRuntime';
-- expect SELECT + INSERT only. Any UPDATE or DELETE row is a FAILED deployment.

-- Not one clinical object was touched
SELECT s.name AS sch, o.name, o.modify_date
FROM sys.objects o JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name <> 'AI' AND o.modify_date >= CAST(GETDATE() AS DATE);
-- expect ZERO rows
```

### 5.6 Success metrics

| Metric | Target |
|---|---|
| Clinical tables altered | **0** — non-negotiable |
| Clinical rows added / changed / removed | **0** |
| Second-run errors (idempotency) | **0** |
| Down-migration scripts in the tree | **0** |
| `UPDATE`/`DELETE` grants on `AI.agentRun` | **0** |
| Duplicate-object report entries | **0** |
| `.sql` files on disk missing from `.sqlproj` | **0** (currently unknown — ~11-file gap) |
| Objects created outside the `AI` schema | **0** |
| Deployment window | Sub-minute — all DDL, no data movement |

### 5.7 Evidence to retain

Full execution output, both runs, timestamped · before/after clinical-table checksums · `sys.database_permissions` dump for all three roles · the `sys.objects` modify_date query returning zero rows · duplicate-object report · second-engineer approval · Jira Development panel screenshot.

---

## 6. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| ~~Platform mismatch (Finding 2) blocks all coding~~ **Closed — TypeScript/Node.js is the build target** (Finding 2) | ⬜ Closed | No action |
| ~~Table-name collision — `agentRun` vs `runAudit`~~ **Closed — resolved.** [epic-02-data-layer.md](solution-doc:5077) carries `AI.agentRun` DDL; three consuming epics agree (§2.7) | ⬜ Closed | Editorial only: correct doc 3777 §3.1 when next touched |
| 🟠 **The TypeScript foundation is an unported hard dependency** — every Epic 02 migration runner and repository class calls its `database` singleton, and no Node backlog exists for it (M9). **Downgraded at Revision 6:** `pacEHR_AI/core/` is a working, tested port source, so this is 5–8 points of translation rather than 13+ of design | 🟠 Med–High | Sequence the port first ([README.md](solution-doc:5090) build order). Epic 02's TypeScript track cannot start in parallel; the interfaces must be stable, not merely planned. **Accept the port only against the three invariant tests** — modules without them is the real failure mode (R18) |
| 🔴 **The `AI` schema is live in production and absent from source control (X9).** A `0001` written as a clean create is correct against an empty target and wrong against production; a `0001` that assumes the schema exists is the reverse | 🔴 High | `IF NOT EXISTS` on the schema for correctness, not merely for re-runnability. Dry-run against **both** a production restore *and* an empty database before the release window — Revision 5's Phase 3 tested only the first |
| 🟠 **Three architectures are live simultaneously (D1b)** — in-solution .NET, standalone Python, standalone TypeScript. Building the runner against the wrong one wastes the whole story | 🟠 Med | Settle and record before Phase 2. The DDL half is safe under all three; only the runner is exposed |
| 🔴 **No Node dependency allow-list** (M10) — [00-langchain-api-truth.md](solution-doc:5091) constrains Python libraries only and has no force over a Node runtime | 🔴 High | Author a TypeScript equivalent in Phase 0, before the first dependency is added. This is the largest governance gap the language choice introduces |
| **TypeScript repository not stood up** — no skeleton, no `package.json`, no CI | 🟡 Medium | Phase 0: create the repository and pin `mssql`, `zod`, `vitest` and the Azure client versions before the first ticket |
| **node-mssql returns `DECIMAL` as a JS `number`** (IEEE-754 double), weakening the `DECIMAL(6,2)`-over-`FLOAT` correction in PEA-206 | 🟡 Medium | Push range comparisons into SQL, or compare with an explicit tolerance. Never compare bounds with `===` after a driver round-trip |
| **No migration-history ledger** — an edited-after-deploy script short-circuits silently, leaving schema drift undetectable (Finding 2) | 🟡 Medium | Raise with the epic author. Either accept explicitly and add a CI checksum over the script set, or add the sixth table |
| **Grant boundary** left implicit — over-granting `aiServiceRuntime` on `AI.fieldConstraint` (§3.3); overlaps unowned open question **B9** (no RBAC model) | 🟡 Medium | Decide the read/author split in Phase 0. Permissions are far easier to widen later than to narrow |
| 🔴 **Nothing owns writing the validated fields back to the encounter form** — [GAPS.md](solution-doc:5089) Gap 1, three independent confirmations. Epic 9 claims it writes to the chart; `REQ-02-07` forbids writing any existing clinical table. No repository class, no `_SQL` constant, no `GRANT`, no upsert exists anywhere in the 75 stories | 🔴 High | **The product's only output has no implementation.** Escalate above Epic 02 — this is the sharper, better-evidenced form of the "storage without a writer" concern in §2.5. Epic 02's grants cannot resolve it: the write target is a clinical table `REQ-02-07` puts out of bounds |
| No database CI/CD exists (Finding 5); story is scoped as if it does | 🔴 High | Phase 0 decision; re-cost. Do not assume a pipeline |
| No precedent for schemas or roles in SSDT (Finding 6) | 🔴 High | Confirm ownership with DB security before designing files |
| Token counts remain client-asserted until PEA-202 ships (Finding 4) | 🔴 High | Treat as a correctness defect; consider a standalone fix ahead of the epic |
| Unregistered `.sql` silently never deploys | 🔴 High | Bidirectional CI registration test |
| Script moved instead of copied → object lost when folder is deleted | 🔴 High | Rule 7 copy-never-move; post-release canonical-file check |
| Two prompt-storage locations with no precedence rule (Finding 7) | 🔴 High | Resolve `Template.fields.aiSummaryPrompt` before PEA-205/207 |
| Release spans two folders → half the scripts silently omitted | 🟡 Medium | Harness matches on date; verify folder count in its output |
| `AI.prompt` replacement is a live UI feature, not a data migration (Finding 1) | 🟡 Medium | Re-point PEA-205; bring the Prompt Studio UI into its scope |
| 🔴 **No review or admin UI is owned by any epic** — [GAPS.md](solution-doc:5089) §3 item 1: out of scope in Epics 9, 10 *and* 11 (§2.5). `fieldOutcome` decision columns stay `NULL`; the review payload has no client | 🔴 High | Escalate as a programme scope hole, not an Epic 02 issue. Supersedes M5. Until owned, Epic 02's tables are write-only and the evaluation ground truth never accumulates |
| `Sql170` provider vs. Azure SQL target (§2.1) | 🟡 Medium | Confirm target; on-prem-only syntax would compile then fail at deploy |
| Jira link fails silently | 🟡 Medium | Literal key in all three places; visually verify the panel |
| Three live spellings of "template" (Finding 8) | 🟡 Medium | Cite rule 8 in the PR; use `templetID` at the mapping grain |
| Committed API key in `appsettings.json` (§2.3) | 🟡 Medium | Verify and rotate independently of this epic |

---

## 7. Recommended Immediate Actions

1. 🔴 **Escalate the two programme-level scope holes before anything else in this list.** Neither is an Epic 02 defect and neither can be fixed inside it: (a) [GAPS.md](solution-doc:5089) **Gap 1** — nothing owns writing validated fields to the encounter form, so the product has no output; (b) **GAPS.md §3 item 1** — no epic owns the review panel or admin UI, so the product has no user. Epic 02 can ship all five tables perfectly and neither hole closes. Raise them with the backlog author as a pair.
2. **Escalate deployment (Finding 5) and security-object ownership (Finding 6) together** — they interlock, and deciding one at a time will stall twice. The platform question is closed; do not re-litigate it.
3. **Confirm Epic 01 is sequenced and staffed ahead of Epic 02.** It is the hard upstream gate ([README.md](solution-doc:5090) build order), and nothing in Epic 02 can be written against unstable interfaces.
2. **Re-point PEA-201 from 5 to 8–13.** It establishes two conventions that do not exist, rather than following one that does.
3. **Redesign two datatypes instead of escalating them** — `FLOAT` → `DECIMAL(6,2)` (matching `vitalConfig`), `CHAR(64)` → `VARCHAR(64)`. Escalate only `BIGINT` and `NVARCHAR(MAX)`.
4. **Raise the token-count integrity defect (Finding 4) as its own ticket.** It is a live audit-trail gap; it should not wait for a six-story epic.
5. **Resolve the prompt-storage overlap (Finding 7)** before PEA-205/206/207 are estimated.
6. **Amend PEA-201's wording** — "creates the `AI` schema" should read "guarantees the `AI` schema and its roles exist," because the schema is already there.
7. **Do not treat `pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql` as a phantom registration.** The file exists on disk (a one-line `GO` stub) and its `.sqlproj` entry is valid. No fix is required.
8. **The `agentRun` / `runAudit` name needs no further action** — `AI.agentRun` is canonical (§2.7).
9. **Read this plan alongside the [Epic 02 grooming rollup](solution-doc:5006)**, which carries the corpus re-anchoring across all seven stories, plus the cross-story defect and ownership registers.
10. **Treat [CLAUDE.md](solution-doc:5093) as binding on every Epic 02 code deliverable, not as style guidance.** Specifically for PEA-201: `_SQL` constants are SCREAMING_SNAKE and declared above the class that runs them; no SQL interpolation, ever; singletons are created on the module's last line; one class exposes one public method; the live database's own misspellings (`templetID`) are preserved rather than corrected. Cite it in the PR template so review has something to check against.

---

## Referenced Paths

Files analyzed for this document. Every path was verified to exist via glob, grep or read. Proposed new files are deliberately excluded because they do not exist yet.

**Solution documents consulted** (not repository files, so not tracked for drift): [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) — read in full; source of the Finding 2 platform resolution, the `AI.runAudit` name collision (§3.1), the single-database placement of the AI tables, the Phase 1 roadmap ordering (§14) and the open question on PHI retention (§16 Q5). [Phase 1](solution-doc:3776) — read in full; corroborates the LangGraph/Pydantic implementation and the two-band constraint model. [Epic 02 Data Layer — Cross-Story Grooming Rollup](solution-doc:5006) — carries the same resolution across all seven stories.

### High Relevance
- `pacEHR_API/CLAUDE.md` - Binding SQL, migration, release-script and PR rules; source of the approved-datatype list, copy-never-move, and `.sqlproj` registration requirements
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - SSDT manifest; proves the registration mechanism, the zero-`<None>` finding, and the `Sql170` provider mismatch
- `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` - Proves the `AI` schema already exists (Finding 1); the legacy table PEA-205 replaces
- `PacEHR/src/app/core/services/open-ai.service.ts` - Proves token counts originate in the browser (Finding 4), lines 277/351/414
- `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` - Browser-side assembly and POST of the AI log payload including token counts
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditAILogs.sql` - Confirms token counts are stored as passed-in parameters, never computed server-side
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - The entire live LLM call path; hardcoded `gpt-4o`, credential resolution
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The real release mechanism PEA-201 must target (Finding 5)
- `pacEHR_API/pipelines/deploy-pacehrapis.yml` - Proves the deployment pipeline covers the API only, not the database
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - Prior art overlap: `prompt`, `allowAISummary`, `aiSummaryPrompt` already exist (Finding 7)
- `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` - Prior art for `AI.fieldConstraint`; source of the `DECIMAL(6,2)` recommendation
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Authoritative `encounterID INT IDENTITY` and `providerID`; resolves PEA-202's FK question
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` - Authoritative spelling and types of `templetID`, `sectionID`, `fieldID`

### Medium Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AILogs.sql` - The client-written AI log `AI.agentRun` supersedes; decommissioning unaddressed by the epic
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AIAcoEncounterLogs.sql` - Third AI logging table, absent from the epic entirely
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AISummaryLog.sql` - Existing AI-adjacent logging in the `Log` schema
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs2/usp_InsertAIAcoEncounterLog.sql` - Server-side writer for the ACO AI log
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addAISummaryLogs.sql` - Server-side writer for the AI summary log
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditAiPrompt.sql` - Live consumer writing `AI.prompt`; must keep working through the transition
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getAiPrompts.sql` - Live consumer reading `AI.prompt`
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_deleteAiPrompt.sql` - Live consumer of `AI.prompt`
- `pacEHR_API/PacEHR.API/Controllers/AIController.cs` - AI endpoint surface including `addEditAILogs`
- `pacEHR_API/PacEHR.API/appsettings.json` - Credential configuration keys; apparent committed key value
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The stored-procedure binding layer all DB access flows through
- `PacEHR/src/app/features/dashboard/add-rounding-notes/add-rounding-notes.component.ts` - Second browser-side AI logging call site
- `PacEHR/src/app/features/encounter-list/encounter-form/ai-summary-prompt/ai-summary-prompt.component.ts` - Third browser-side AI logging call site
- `PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` - The existing Prompt admin UI that PEA-205 would displace
- `PacEHR/src/app/core/services/prompt.service.ts` - Frontend service for `AI.prompt` CRUD
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` - Third spelling of "template"; `promptId`, `ambientPrompt` columns
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterData.sql` - Authoritative `encounterID` spelling at the data grain
- `pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql` - A release-folder stub that exists on disk; its `.sqlproj` registration is valid

### Low Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/section.sql` - Template section grain referenced by the new tables
- `pacEHR_API/PacEHR.Database/Tables/Tables1/normals.sql` - Assessed for overlap with `AI.fieldOutcome`; not equivalent
- `pacEHR_API/PacEHR.Database/Tables/Tables2/templatefieldNormals.sql` - Template-field-to-normal mapping; assessed for overlap
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterNormals.sql` - Per-encounter normal selection log; assessed for overlap
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql` - Precedent for `CHECK` constraints
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql` - Precedent for `CHECK` constraints and filtered indexes
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterCPT.sql` - Precedent for filtered indexes
- `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` - Precedent for `BIGINT IDENTITY`
- `pacEHR_API/PacEHR.Tests.UnitTests/Controllers/AIControllerTests.cs` - Existing AI test coverage; where the scope guard would live
- `pacEHR_API/PacEHR.Tests.UnitTests/DomainServices/AIPromptServicesTest.cs` - Existing AI service test coverage
- `pacEHR_API/pipelines/pr-checklist-validation.yml` - PR checklist enforcement
- `pacEHR_API/pipelines/jobs/deploy-pacehrapis-job.yml` - Deployment job; confirms no database step
- `pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1` - The release harness entry point
- `PacEHR/src/app/core/models/template-editor.model.ts` - Shows the DB misspelling propagating into TypeScript
- `pacEHR_API/pacEHR.sln` - Confirms the .NET 8 solution structure underpinning Finding 2
