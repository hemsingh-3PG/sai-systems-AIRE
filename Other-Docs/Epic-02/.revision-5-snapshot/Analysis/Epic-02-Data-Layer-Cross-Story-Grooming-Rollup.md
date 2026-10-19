# Epic 02 (Data Layer) — Cross-Story Grooming Rollup

**Epic:** E2 — AI Schema Data Layer · **Stories:** PEA-201 … PEA-207
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — synthesis of seven story-level audits, for grooming, not for implementation
**Build target:** TypeScript/Node.js

> ⚠️ **Scope.** This is a **private-space** document written against a **greenfield
> TypeScript/Node.js AI service**: new standalone repository, no reuse of the existing C# AI
> logic, runtime chain **Angular → .NET Web API → TypeScript AI service → Azure OpenAI**. The
> **team-space/official Python corpus is deliberately unmodified** and is the reference design.
>
> **Language-neutral (roughly 70% of this epic):** all DDL (five tables, three roles, every
> column, constraint and index), all Gherkin scenarios, all REQ- IDs, all point estimates, all
> dependencies, reason codes, confidence bands, plausibility bounds, HTTP contracts, retention
> policy and the `templetID` spelling.
>
> **Language-bound:** the runner, driver, repository, config and test layers — and one
> decision that is materially *harder* under a greenfield Node service, see §2.1.

> **Purpose.** Each story has its own tech spec with full evidence. This document is the
> layer above: the decisions that block more than one story, the work the epic implies but
> does not contain, the defects the audit surfaced that belong to nobody, and what the epic
> actually costs. Read this before grooming; read the story specs during it.

**The one-paragraph version.** Epic 02 is well designed. Its data model is coherent, its
vocabularies are deliberate, and several of its choices — the ABSENT/ABSTAINED split, the
four-value evaluation verdict, the fail-closed retention guard, the per-mapping grain — are
better than what the codebase does today and should be defended in review. Four things stand
between it and delivery: it is written against an **AI service that is designed but does not
exist in any repository** (§2.1), two of its stories **replace or duplicate shipped features**
without saying so, four of its seven stories depend on **database principals and grants that
have never existed in this product**, and two of its tables have **no defined position in the
approved prompt-composition model** (D20). None of these is a design flaw. All of them are
unowned.

**On the first of those four.** The epic is **not** written against a fantasy platform — doc
3777 establishes that a new AI service is approved architecture, with the .NET API keeping
auth and persistence. Reading it also surfaced five cross-story decisions (D20–D24) and two
critical-impact risks (R11, R12) that no single story audit could have found, because they
only appear when the epic's tables are laid against the composition model they feed.

⚠️ **But that first item is the sharpest of the four, and a greenfield Node service makes it
sharper.** The language question is *settled* — TypeScript/Node.js — so the epic is not
waiting on an architecture choice. The difficulty is downstream of that: the approved design's
service was Python with a published 12-epic backlog behind it, and **the Node service has no
repository, no skeleton, no pipeline and no backlog.** The binding question is therefore not
"which platform?" (answerable in a meeting) but **"who builds the foundation, and when?"** — a
staffing and sequencing question with no current owner. **The epic's own DDL is entirely
unaffected**, which is why PEA-201 can start immediately; everything downstream of the
repository layer cannot.

---

## 1. Story-level outcomes

| Story | Scope | Spec | Epic est. | Audited est. | Verdict |
|---|---|---|---|---|---|
| PEA-201 | `AI` schema + migration mechanism | [PEA-201 Delivery Plan](solution-doc:4966) | 5 | **8–13** | Schema already exists; the *mechanism* is the work |
| PEA-202 | `AI.agentRun` | [PEA-202 Tech Spec](solution-doc:4984) | 3 | **5–8** | Table is easy; instrumenting the call path is not |
| PEA-203 | `AI.fieldOutcome` | [PEA-203 Tech Spec](solution-doc:4987) | 5 | **5** (8+ with review UI) | Best-justified story in the epic |
| PEA-204 | Retention purge | [PEA-204 Tech Spec](solution-doc:4988) | 2 | **2** | Mechanism ready; blocked on a non-engineering decision |
| PEA-205 | `AI.promptFragment` | [PEA-205 Tech Spec](solution-doc:4993) | 3 | **13–26** | Replaces a shipped feature; re-point urgently. Backfill is a supervised cleanup of audited-defective data, not a mapping |
| PEA-206 | `AI.fieldConstraint` | [PEA-206 Tech Spec](solution-doc:4997) | 3 | **3** (8–10 with UI) | Cleanest fit; excellent precedent |
| PEA-207 | `AI.fieldDescription` | [PEA-207 Tech Spec](solution-doc:5002) | 3 | **3** (+5 with UI) | Overlaps a shipped surface; decide precedence |
| | **Total** | | **24** | **~31 storage-only · ~70–75 with implied UI and cutover** | |

Both totals are indicative, not commitments. The gap between them is the point: **the epic
scopes storage, and roughly half the work it implies is user interface and migration that sits
in no story.**

### Recommended splits

| Split | Scope | Pts |
|---|---|---|
| PEA-202a / 202b | table / instrument the LLM call path | 2–3 / 5 |
| PEA-205a / 205b / 205c | table + procedures + authoring validation / backfill triage + two-baseline precedence parity + cutover / versioning-rollback UI | 3–5 / **8–13** / 8+ |
| PEA-206a / 206b | table + procedures / constraint authoring UI | 3 / 5–8 |
| PEA-207a / 207b | table + procedures / description authoring UI | 3 / 5 |

**PEA-206b and PEA-207b modify the same Angular components** — the template editor's field
editor. Sequence them together or merge them; doing them separately means two passes over the
same files and two rounds of regression testing on a shipped editor.

---

## 2. Consolidated decision register

Everything that blocks work and cannot be decided by the implementer. Owners are roles, not
names — assigning real names is the grooming outcome.

### Tier 1 — blocks the whole epic

| # | Decision | Owner | Blocks |
|---|---|---|---|
| **D1** | ~~Platform: Python service or .NET against SSDT?~~ — **RESOLVED: greenfield TypeScript/Node.js**, see §2.1 | closed | was: every story's runtime half |
| **D1a** | 🔴 **Who builds the TypeScript foundation, and when?** The Node repository does not exist. `src/core/{settings,database,llm,errors,logging,auth}.ts` and a **Node dependency allow-list to replace [00-langchain-api-truth.md](solution-doc:5091)** must be authored first. There is no published Node equivalent of the Epic-01 backlog | Architecture + Eng leadership | every story's repository and test layer (the DDL is unblocked) |
| **D2** | **Who creates database principals and grants?** `aiServiceRuntime`, `aiPromptAdmin`, `aiTemplateAdmin` do not exist, and no `GRANT` of any kind exists anywhere | Architecture + DBA | 203, 205, 206, 207 security DoDs |
| **D3** | **How does any database change reach an environment?** No pipeline deploys the SSDT project | DevOps | all seven |

### 2.1 D1 — RESOLVED: a new AI service is approved, and the owner has set it to TypeScript

Both architecture documents have been read in full, and they answer the *design* half of D1
directly. [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) is marked
**"Design / approved for planning"**, dated 2026-09-10, and its §3.1 system context diagram
names an explicit new component:

> **AI Orchestrator · NEW** — Ingest Gateway, pipeline, Prompt + Config Registry

The division of responsibility is stated unambiguously: *"The .NET API keeps owning auth,
persistence and the existing contract. The orchestrator owns AI decisioning only."*
`AIController` becomes a **thin proxy**. **That division is unchanged and remains correct.**

⚠️ **The language half is answered by owner decision, not by these documents.** Doc 3777 §14
specifies a "Python sidecar + LangGraph" and [Phase 1](solution-doc:3776) confirms it at
implementation level (`create_react_agent` from `langgraph.prebuilt`, Pydantic models,
`init_chat_model`). Those are **team-space documents and are deliberately left as they are**
— they remain the reference design. The build target for this solution is a **greenfield
TypeScript/Node.js service**: new standalone repository, no reuse of the existing C# AI
logic, runtime chain Angular → .NET Web API → TypeScript AI service → Azure OpenAI.

**One framing to avoid.** It is tempting to read the corpus's module paths
(**core/agent_run_repository.py** and siblings) as an error on the grounds that this
repository is .NET 8 + SSDT + Angular. That reasoning is right about the repository and wrong
about the plan: **the epic is consistent with an approved architecture and is targeting a
service that does not exist *yet*.** The .NET/SSDT mapping table carried in each story spec is
a contingency record, not the recommended path.

What is language-neutral here, and what is not:

| | Effect |
|---|---|
| **Epic 02's DDL** | **Unaffected.** Entirely language-neutral T-SQL. §3.1 puts the AI tables in the same SQL Server box as `Template.*` and `Log.AILogs`. |
| **Epic 02's estimates** | **Largely unaffected.** The storage work is the same. |
| **Repository/config/test layers** | **Expressed in TypeScript:** node-mssql rather than `mssql_python`, zod rather than Pydantic and pydantic-settings, vitest rather than pytest, `src/repositories/*.ts` rather than `core/*_repository.py`, camelCase methods. SQL text, class names and constant names carry over unchanged. |
| **One genuine simplification** | node-mssql is **natively async**, so the `asyncio.to_thread` thread-pool wrapper the Python design needed **disappears**, along with the "never publish a sync `execute` beside `aexecute`" rule. |
| **Two genuine hazards a Node service introduces** | (1) `z.coerce.number().int().positive().optional()` for the retention setting — **never `.default(0)`**, which would turn an unmade compliance decision into a full-table purge. (2) node-mssql surfaces `DECIMAL` as a JS binary double, partly undoing PEA-206's `DECIMAL(6,2)`-over-`FLOAT` choice for in-process comparisons. |
| **Every spec's "runtime work implied"** | **Moves out of this repository** into the new service — not .NET work for this team's backlog, but not free either. |
| **Ownership** | **Now the real question, and harder than before.** |

**The residual blocker is sharper and larger than the language question ever was.** Not *"which
language?"* — that is settled — but: **does the TypeScript service exist yet (no), is it
staffed, is Epic 02 sequenced before it, and who writes the Node foundation and dependency
allow-list?** Under the Python plan there was at least a published 12-epic backlog including
an Epic 01 foundation; for the Node service there is **no repository, no skeleton, no
pipeline and no backlog**. If Epic 02's tables land first, they are correct and empty,
waiting on a service nobody has begun — exactly risk R3 at epic scale, now with a longer
expected wait. Route this to Architecture with the two documents attached, and see D1a.

**Verified against both repositories:** no Node/TypeScript backend exists anywhere — no
`nest-cli.json`, no `serverless.yml`, no backend `package.json`. The only TypeScript present
is the Angular SPA.

**A second point the architecture document settles:** the table-name question. Its
§3.1 names `AI.runAudit`, while Epic 02 specifies `AI.agentRun` (PEA-202). Same role, two
names, and the epic's is the later document. **Confirm `AI.agentRun` is the intended name
before PEA-202 is built** — this is a five-minute conversation that prevents two tables.

### Tier 2 — blocks one story, cannot be decided by engineering

| # | Decision | Owner | Story |
|---|---|---|---|
| **D4** | **Retention period (open question B7).** How long must derived clinical content be kept? Must also exceed Epic 10's replay window, which is also unstated | Clinical + Compliance | 204 |
| **D5** | **Per-template prompts: keep, coexist, or remove?** Removing is a product decision about a shipped capability | Product + Architecture | 205 |
| **D6** | **Precedence: `AI.fieldDescription.description` vs `Template.fields.aiSummaryPrompt`** | Product + Architecture | 207, and Epic 3 implements it |
| **D7** | **Are the authoring and review UIs in scope, follow-on, or deferred?** | Product | 203, 205, 206, 207 |
| **D17** | **Who writes and owns these four tables — the new TypeScript AI service or the .NET API?** §3.1 has the orchestrator reading `AI.fieldConstraint` and the .NET `EncounterController` writing it. Two writers, one table, no stated boundary | Architecture | all seven write paths |
| **D18** | **Is `AI.agentRun` (epic) or `AI.runAudit` (architecture §3.1) the intended name?** Same role, two names, two documents | Architecture | 202 |
| **D19** | **Q5 from the architecture doc is D4 restated and still open:** retention for evidence spans containing PHI. Confirm one answer serves both | Compliance | 204 |
| **D20** | **Where does authored per-field text enter the six-layer prompt composition?** Doc 3777 §6.1's L0–L5 has no layer for it — L3 is *generated*, L4 *compiled*, L2 per-template-*family*. This orphans both `AI.fieldDescription.description` (207) and `kind='template_override'` (205). Two stories, one root cause | Architecture | 205, 207, and Epic 3 |
| **D21** | **Is authored prompt-adjacent text subject to §6.4's fragment rules** — immutable versions, authoring validation, eval-bound promotion? If yes, 207's single mutable column is the wrong shape and 205 needs an eval-set binding column | Architecture | 205, 207 |
| **D22** | **Which precedence is the migration target for 205** — live `usp_getPrompt` behaviour, or doc 3777 §6.4's written ordering (`Organization-Universal > Organization > System-Universal > System`)? They differ, and §6.4 has no template tier | Architecture | 205; informs D5 |
| **D23** | **Backfill triage + D1 prompt contradiction.** Doc 3777 §1.3 audits all 25 live `AI.prompt` rows and finds 13 defects: four content-free garbage prompts live in production, four near-duplicate forks (two simultaneously active), and two prompts with contradictory NA-handling rules. Which rows migrate, and which of the two contradictory rules is correct? | Product + clinical content owner | 205 |
| **D24** | **Does `AI.fieldConstraint` carry one range band or two?** Doc 3777 §8.1 requires `implausible` (blocks) and `abnormal` (flags and keeps) with different behaviours; the epic's DDL has one unlabelled pair | Architecture + clinical | 206 |

### Tier 3 — engineering decisions, needed before DDL is written

| # | Decision | Story |
|---|---|---|
| D8 | `BIGINT` rule-3 escalation (precedent exists: `HL7_MSH.sql`, `gehrimedData_OMH.sql`) | 202, 203 |
| D9 | What writes `verdict` before Epic 6 exists? Recommended: default `review` | 203 |
| D10 | What writes `PASSED` before Epic 10 exists? **Never default to `PASSED`** | 205 |
| D11 | Uniqueness over nullable columns — sentinel `0` or computed columns | 205 |
| D12 | `decidedByProviderID` casing, then locked through SQL → C# → TypeScript | 203 |
| D13 | `DECIMAL(6,2)` precision sufficient for all field types? | 206 |
| D14 | Do constraints or descriptions ever vary by account? | 206, 207 |
| D15 | Multi-unit bound interpretation (`"kg\|lb"` with one min/max) — route to Epic 6 | 206 |
| D16 | Composite PK with no surrogate accepted despite thin precedent | 207 |
| D25 | Does `AI.fieldConstraint` need a `precision` column? Doc 3777 §11's compiled shape carries per-field `precision` (`"precision":0` for BP); the epic's DDL has none. Secondary to D24, addable later without migration | 206 |
| D26 | Does `AI.promptFragment` need an `evalSetID` column for §6.4's eval-set binding, or is that a join table Epic 10 owns? | 205 |
| D27 | Reconcile `kind`'s four values against the six composition layers — L0/L1/L2 map cleanly to `contract`/`task`/`specialty`; L3/L4/L5 are correctly absent; `template_override` has no layer (see D20) | 205 |
| **D28** | **Node/TypeScript stack choices for the data layer:** node-mssql (tedious) as the driver, zod as the schema/config validator, vitest as the test runner. All three are load-bearing across every story and none is covered by an existing allow-list. Decide with D1a, not per story | 201–207 |
| **D29** | **How are `DECIMAL(6,2)` bounds compared?** node-mssql surfaces `DECIMAL` as a JS binary double, so in-process comparison reintroduces the float imprecision PEA-206 chose `DECIMAL` to avoid. Options: push range comparisons into SQL, or compare with an explicit tolerance. Must be settled before the first bound check is written | 206 |
| **D30** | **Where does the purge timer run** — the existing .NET `PacEHR.Functions.Process` host (five live timers, but no pipeline deploys it — see M3) or a **new Node Functions v4 host**? Affects M3's scope and PEA-204's DoD | 204 |

---

## 3. Work the epic implies but does not contain

These are not gaps in the specs. They are stories that need to exist.

| # | Missing work | Why it is needed | Est. |
|---|---|---|---|
| **M1** | **Database security infrastructure** — create the `AI` schema principals, roles and grants; establish a `Security/` folder per CLAUDE.md rule 7 | Four stories' security models depend on principals that do not exist. There are **zero** `CREATE SCHEMA`, `CREATE ROLE`, `CREATE USER`, `ALTER ROLE` or `GRANT` statements across all 2,834 SQL files | 5–8 |
| **M2** | **Database deployment pipeline** | Nothing deploys the SSDT project. Releases go through a manual PowerShell harness reading a git ref | 8+ |
| **M3** | **Azure Functions deployment** | Five live timer jobs run from a project no pipeline in this repository deploys. Blocks PEA-204 and anything scheduled. Scope now depends on D30 (existing .NET host vs new Node host) | 3–5 |
| **M9** | 🔴 **TypeScript service foundation — the Epic-01-equivalent that does not exist.** A new repository plus **src/core/settings.ts** (zod), **src/core/database.ts** (node-mssql pool + `Transaction`), **src/core/llm.ts**, **src/core/errors.ts**, **src/core/logging.ts**, **src/core/auth.ts**, `tsconfig`, lint, vitest harness, CI, and container/Functions packaging | **Every one of PEA-201's siblings imports these.** The Python corpus had a published 12-epic backlog with Epic 01 covering exactly this; **for the Node service there is no repository, no skeleton, no pipeline and no backlog.** This is the single largest piece of unowned work the retarget creates | 13+ |
| **M10** | 🔴 **Node dependency allow-list** — the document that replaces [00-langchain-api-truth.md](solution-doc:5091) | Doc 5091 pins exact Python library APIs and forbids everything outside them; it governs Python only. Without a Node equivalent, every story's imports are unconstrained and the "no cache" and "no sync/async split" rules have nothing to bind to | 3–5 |
| **M4** | **Clinician review UI** (Epic 9's `/ai/encounter/resolve` + front end) | Without it, half of `AI.fieldOutcome` is permanently NULL | 8+ |
| **M5** | **Prompt versioning / diff / rollback UI** | `AI.promptFragment` stores every version specifically so Epic 8 can roll back and A-B compare (REQ-08-14). No version, history, diff, rollback, preview or approve concept exists anywhere in the front end — **and it appears in neither architecture document's roadmap either**, while doc 3777 §6.4 requires the behaviours it would expose. A genuine ownership gap, not just an unscoped story | 8+ |
| **M6** | **Template-editor authoring for constraints and descriptions** | PEA-206b + PEA-207b, merged | 8–10 |
| **M7** | **Legacy prompt cutover** — backfill, precedence parity, retire four procedures and an admin feature | PEA-205b | 8 |
| **M8** | **Authoring validation for prompt-adjacent free text** | Doc 3777 §1.3 D10 records four content-free prompts (`sdwdxs`, `rfvdytvfgvcyt`, `...`, `esfsaf@#`) live in production because nothing validated authoring, and D9 an unescaped `&lt;&lt;…&gt;&gt;` injection surface. Both PEA-205's `fragmentText` and PEA-207's `description` are the same kind of surface. §6.4 specifies the rules; nobody has scoped implementing them | 2–3 |

**M1, M2, M9 and M10 are on the critical path and none is in the epic.** M3 is a prerequisite
for PEA-204 that nobody has noticed because the Functions host was assumed not to exist.
**M9 and M10 exist only because the service is a greenfield Node build**, and together they
are larger than any single story in Epic 02 — see D1a.

---

## 4. Defects surfaced by the audit — separate tickets

None of these belong to Epic 02. All were found while auditing it, and all are real.

| # | Defect | Severity | Evidence |
|---|---|---|---|
| **X1** | **Token counts are client-asserted.** Usage is written to `localStorage` by the browser, read back and POSTed by three components, and inserted verbatim. Writable from any browser console; a closed tab mid-stream produces **no audit row at all**; `?? 0` collapses "zero" with "lost" | 🔴 High | `PacEHR/src/app/core/services/open-ai.service.ts` lines 277, 351, 414; `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` line 618 |
| **X2** | **Live-looking OpenAI key committed to the repository** | 🔴 High | `pacEHR_API/PacEHR.API/appsettings.json` — rotate, then move to Key Vault or managed identity |
| **X3** | **`Template.fields` audit trigger omits `abbreviation`.** The table has 16 columns; the trigger copies 15. Changes to that column are silently unaudited | 🟠 Med | `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` lines 17, 23–65 |
| **X4** | **AI prompt admin is gated by a client-side `userRole === 1` check** read from `sessionStorage`. No named permission, no route guard — not an authorisation boundary | 🟠 Med | `PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` line 45 |
| **X5** | **No latency instrumentation on any LLM call.** Zero matches for `Stopwatch`, `ElapsedMilliseconds` or `latency` | 🟡 Low | `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` |
| **X6** | **`.sqlproj` release-script registration has never been exercised.** ~2,845 `<Build>` entries, **zero** `<None>`. CLAUDE.md rule 5's second path is untested, and unregistered files are silently never deployed | 🟠 Med | `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` |
| **X7** | **SSDT targets SQL Server 2022, not Azure SQL** — a latent target mismatch if deployment is to Azure SQL | 🟠 Med | Same file, line 10 (`Sql170DatabaseSchemaProvider`) |

**X1 is the one to raise first.** It undermines the audit trail Epic 02 exists to build: PEA-202
is specified to record token usage per invocation, and the only source of that data today is a
value the browser can edit.

---

## 5. Sequencing and critical path

```
LANGUAGE-NEUTRAL TRACK (can start now)
D1 language ✔ RESOLVED ┐  (greenfield TypeScript — no longer a gate)
D2/M1 principals ──────┼──> PEA-201 DDL half (schema + migration SQL)
D3/M2 deployment ──────┘        │
                                ├──> PEA-202 DDL ──> PEA-203 DDL
                                ├──> PEA-205 DDL
                                ├──> PEA-206 DDL   (D24/D25 first)
                                └──> PEA-207 DDL

TYPESCRIPT TRACK (blocked until the service exists)
D1a owner ──> M9 TS foundation ──> M10 Node allow-list ──> D28 stack choices
                                        │
                                        ├──> PEA-201 runner half (databaseMigrations.ts)
                                        │        │
                                        │        ├──> PEA-202 agentRunWriter.ts
                                        │        │        └──> PEA-203 fieldOutcomeRepository.ts
                                        │        │                 │
                                        │        │           D4 ──>┴──> PEA-204 purge job
                                        │        │                        + D30 host + M3 deploy
                                        │        ├──> PEA-205 promptFragmentRepository.ts ──> M7
                                        │        ├──> PEA-206 fieldConstraintRepository.ts (D29) ─┐
                                        │        └──> PEA-207 fieldDescriptionRepository.ts ──────┴──> M6
```

Notes on the shape:

- **PEA-201 gates everything.** Nothing else can be written until the schema and the migration
  mechanism exist.
- **PEA-205, 206 and 207 are independent of each other** and of the 202/203/204 chain. They can
  run in parallel once 201 lands — the widest point in the epic.
- **PEA-203 depends on PEA-202** for a real foreign key (`runID` → `AI.agentRun`), so they must
  land in the same release or be sequenced with guarded scripts.
- **PEA-204 is last and has the longest lead time on its blocker.** D4 is a compliance
  decision; start it now, in parallel with everything else, not when the story is picked up.
- **M1 (principals) should land before or with PEA-201**, not after. Retrofitting grants onto
  four existing tables is more work than granting on creation.
- **D1 is no longer on the critical path** (§2.1). The Tier 1 gates are now D2/M1 principals,
  D3/M2 deployment and **D1a/M9/M10 the TypeScript foundation** — all *infrastructure the epic
  does not contain*, none of it owned. That is the epic's binding constraint, not language.
- 🔴 **Every story splits in two, and the halves have different readiness.**
  The DDL half of all seven stories is language-neutral and can be built today against
  SSDT. The repository/config/test half cannot start until **M9** exists. Estimating or
  committing a story as a single unit overstates readiness — split the points.
- **The new service is a parallel track, not a gate — but a long one.** Epic 02's
  storage can land ahead of its writer; that is a legitimate choice, and it should be a
  declared one (D17). The honest caveat: the approved Python design had a published Epic 01
  covering the foundation, whereas for Node **nothing exists** — so the expected wait between
  "tables land" and "something writes them" is long.
- **An interim .NET reader is the pragmatic first consumer.** The existing `AIController` /
  `AIPromptServices` path already runs in production. Pointing it at `AI.fieldConstraint` and
  `AI.fieldDescription` as read-only inputs proves the tables carry real value before the
  TypeScript service exists. Treat this as a **deliberate first consumer, not a fallback** —
  and keep it read-only so the write-ownership boundary (D17) is never crossed by accident.

---

## 6. Requirements that apply to every story

These come from `pacEHR_API/CLAUDE.md` and recur in all seven DoDs. Worth stating once at epic
level so each PR does not re-derive them.

**Every database object, every time:**

1. **Two artefacts, always** (rule 4) — the canonical object file **and** a re-runnable release
   script under Scripts/Script.&lt;DDMonYYYY&gt;/ named with the Jira key. Guard each object
   *and each index* separately so a partially applied script is safely re-runnable.
2. **Register both in the `.sqlproj`** (rule 5) — `<Build>` for schema objects, `<None>` for
   release scripts. **Unregistered means silently never deployed.** Given X6, add a manifest
   test; this path has never been exercised.
3. **Run the release harness** and confirm `PASS` with no duplicate-object hit.
4. **Procedures** (rule 6): `usp_<Verb><Noun>`, in Stored Procedures/Procs2/,
   `CREATE OR ALTER PROCEDURE`, schema-qualified, header block with the Jira key.
5. **Never correct existing spellings** (rule 8) — `templetID`, `templeteId`,
   `encounterTempleteID` and `abnormalOPerator` all stay as they are. Renames break the
   string-bound procedure calls in `pacehr_devContextProcedures` **at runtime**, not at compile
   time.
6. **Datatypes** (rules 2, 3): approved list only, explicit lengths, and the SQL → C# →
   TypeScript chain matched exactly. The cited production failure (PACT2-1105, `bool?` against
   an integer column → HTTP 400) is the reason.
7. **Cite the source for every constant** (§ Numbers) — notably the 10.95M-rows/year figure,
   which traces to [pacEHR-Encounter-Agent-4Pager](solution-doc:4762) line 111.
8. **Jira key in branch name, commit message and PR title** — Azure DevOps matches the literal
   string and **fails silently** otherwise. One concern per PR.

**Two house-form corrections that apply to all five new tables:**

- `DEFAULT SYSUTCDATETIME()` → **`DEFAULT (getutcdate())`**. `SYSUTCDATETIME` has zero
  precedent in table DDL; the house form is at
  `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` line 11.
- `CHECK (x IN (...))` → **named `CK_<table>_<col>` with a pre-normalised OR chain**. SSDT
  rewrites `IN` to `OR`; writing it pre-normalised avoids a spurious first-deploy diff.
  Model: `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` line 14.

---

## 7. Cross-cutting risks

| # | Risk | L | I | Where |
|---|---|---|---|---|
| **R1** | **Precedence silently changes at prompt cutover → different prompts → different clinical output** | High | **Critical** | 205 §5.4 parity gate |
| **R2** | **A missing retention key reads as `0` and purges the entire table.** The .NET form is `GetValue<int>`; the **TypeScript form is zod `.default(0)`**, which is what a reviewer will reach for instinctively. Required: `z.coerce.number().int().positive().optional()` and an explicit unset branch that deletes nothing | Med | **Critical** | 204 §3.2 |
| **R3** | **Tables ship without their UI → stay empty → validators and audits silently pass or record nothing** | High | High | 203, 205, 206, 207 |
| **R4** | **Grants claimed but absent** — DoD items asserting least privilege pass vacuously when the principals do not exist | High | High | D2 / M1 |
| **R5** | **`.sqlproj` registration missed → object silently never deployed** | Med | High | all; X6 |
| **R6** | 🔴 **The TypeScript service is approved in principle but has no repository, no skeleton, no pipeline and no backlog → tables ship correct and empty, waiting on a service nobody has begun.** There is no Epic-01-equivalent to point at | **High** | High | §2.1, D1a, M9 |
| **R7** | **Existing spellings "corrected" by a well-meaning reviewer → runtime binding failure** | Med | High | all |
| **R8** | **Retention unresolved while ~11M rows/year accumulate** | High | Med | D4 |
| **R9** | **Purge silently deletes Epic 10's replay inputs** — nothing errors, the replay set just shrinks | Med | High | 204 §3.4 |
| **R10** | **SQL Server 2022 target vs Azure SQL deployment** | Med | Med | X7 |
| **R11** | **Authored per-field text has no layer in the approved composition** → Epic 3 and Epic 8 each invent an injection point, or the text is quietly dropped | High | **Critical** | D20; 205 Finding 15, 207 Finding 13 |
| **R12** | **`AI.fieldConstraint` ships with one range band where the architecture needs two** → either genuinely abnormal values pass unflagged, or real hypertensive values get blocked as implausible. Not fixable at runtime | High | **Critical** | D24; 206 Finding 14 |
| **R13** | **205's backfill faithfully migrates audited-defective data** — 13 catalogued defects including four garbage prompts and two contradictory active rules — and the parity gate certifies the result as correct | High | **Critical** | D22, D23; 205 Findings 13–14 |
| **R14** | **No authoring validation on any new free-text column** → the pattern that produced `sdwdxs` in production repeats in `fragmentText` and `description` | High | High | M8 |
| **R15** | 🔴 **No Node dependency allow-list.** [Doc 5091](solution-doc:5091) constrains Python libraries to an exact pinned API surface; nothing equivalent exists for Node. Unconstrained imports are how an ORM, a cache library or a hand-rolled connection helper enters the data layer and quietly voids the no-cache and least-privilege rules | **High** | High | M10, D28 |
| **R16** | **`DECIMAL` bounds compared as JS doubles.** node-mssql returns `DECIMAL(6,2)` as a binary double, so `value > max` can flip at the boundary — reintroducing exactly the imprecision PEA-206 rejected `FLOAT` to avoid. Fails silently and only at the edges | Med | High | D29; 206 |
| **R17** | **Node-idiomatic caching breaks REQ-03-06 without looking like caching.** Module-scope `const`/`Map` memoisation and **Azure Functions v4 warm-instance state** both persist across invocations and both read as normal Node. The .NET review checklist (`IMemoryCache`, `AddSingleton`) does not catch either | Med | Med | 207 §3.5 |

R1, R2, R3, R12, R13, R16 and R17 share a shape worth naming: **they all fail silently.** Nothing throws, no
pipeline goes red, and the damage is only visible in output quality or in a table that is
emptier than expected. Each has a cheap, specific guard in its story spec — a parity query, a
nullable type, a DoD sentence. They are cheap now and expensive to detect later.

---

## 8. What the audit endorses

Worth recording, so review does not erode good decisions:

- **ABSENT must never collapse into ABSTAINED** (PEA-203). Current production writes `NA` for
  both. In a clinical record that is a safety issue, not a reporting inconvenience. This is the
  single strongest justification in the epic.
- **Confidence is categorical, never numeric** (REQ-03-09). Nothing in the runtime produces a
  calibrated probability — `temperature = 0`, no logprobs — so a numeric column would hold a
  number the model invented about itself.
- **Four-value `passedEvaluation`, not a BIT** (PEA-205). "Never evaluated" ≠ "evaluated and
  failed"; a BIT makes the gate fail *open* for anything untested. **Now corroborated:**
  doc 3777 §6.4 requires every fragment to be bound to an eval set with promotion blocked on
  regression — the four-value verdict is what records that, and defaulting to `PASSED` is a
  deviation from an approved design, not merely a bad idea.
- **Fail closed on unset retention** (PEA-204). Refusing to run beats guessing. Defend this
  through **both** translations, because the idiomatic path inverts it in each: .NET
  `GetValue<int>` yields `0`, and zod `.default(0)` yields `0`. **Unset ≠ zero.**
- **Per-mapping grain for constraints and descriptions** (PEA-206, PEA-207). One `displayName`
  edit was measured reaching **179 of 458 templates**; a global grain would leak a bound or a
  description across every template using the field.
- **Excluding `name`/`type`/`unit` from `AI.fieldDescription`** (PEA-207). They are live columns
  on `Template.fields`; copying them would create a second source of truth. **Now a third
  agreeing voice:** doc 3777 §6.1 generates the field manifest (L3) from the template itself
  and carries `unit` in the compiled constraint digest (L4), not in any description structure.
- **No caching on the description read** (REQ-03-06). The read is one indexed range seek. The
  correct optimisation is none. **A second reason now applies:** doc 3777 §12's mandatory
  self-hosted tracing records `prompt_hash` per call, and a cached description makes that
  trace stop matching what was actually sent. **Under TypeScript this rule needs a wider
  checklist** — see R17.
- **ABSENT is a successful extraction, ABSTAINED is a request for a human** (PEA-203).
  Doc 3777 §5 states this in almost the same words and carries `(was: NA)` comments in its
  output contract — independent confirmation that collapsing both into `NA` is the defect the
  epic says it is.
- **Three distinct vocabularies at two grains** — run-level `outcome`, field-level `verdict`,
  field-level `proposedStatus`. Lexically distinct on purpose; overlapping words across grains
  is how audit queries end up quietly wrong.

---

## 9. Recommended actions, in order

0. 🔴 **Commission M9 + M10 — the TypeScript foundation and the Node dependency allow-list —
   as their own epic, before any repository-layer story is committed (D1a, D28).** This is the
   highest-leverage action in the list and the one with no current owner. Concrete framing:
   *which team creates the repository, who writes **src/core/settings.ts** and
   **src/core/database.ts**, and who authors the Node allow-list that replaces
   [doc 5091](solution-doc:5091)?* Until that is answered, **only the DDL half of each story is
   truly ready** — split the points accordingly (§5).
1. **Confirm with Architecture that the TypeScript service (not the Python sidecar in doc 3777
   §14) is the build target of record, and whether Epic 02 is sequenced before or after it.**
   D1 itself is closed (§2.1) — language is settled as greenfield TypeScript/Node.js. Also
   confirm `AI.agentRun` is the canonical name over the architecture document's `AI.runAudit`,
   and settle **D17** (who owns the four new tables) before PEA-201 is picked up.
2. **Re-point PEA-205 in grooming.** 3 points describes about a fifth of it. Take the a/b/c
   split in §1.
3. **Assign D4 (retention) to a named data owner with a date.** Longest lead time, purely
   non-engineering, and PEA-204 cannot complete without it.
4. **Open M1 (principals and grants) and M2 (database deployment) as real stories.** Four of
   seven stories depend on M1; all seven depend on M2.
5. **Decide D7 (UI scope).** It is the difference between ~31 and ~70 points, and it determines
   whether four tables are populated or empty.
6. **Raise X1 (client-asserted token counts) as a defect now**, independently of this epic.
   PEA-202's audit row inherits the problem.
7. **Rotate the committed key (X2).**
8. **Decide D6 (description vs `aiSummaryPrompt` precedence)** before Epic 3 starts, and run
   the sizing query in PEA-207 §5.4 first — it may make the decision trivial.
9. **Ask DevOps how `PacEHR.Functions.Process` currently reaches its environments** (M3). Five
   live timer jobs run from a project no pipeline here deploys; that is worth knowing
   regardless of this epic. **Then settle D30** — does the purge timer join that existing .NET
   host, or does PEA-204 stand up a new Node Functions v4 host?
10. **Add the silent-failure guards to the review checklist**: nullable retention config
    (zod `.optional()`, **never `.default(0)`**), parity-before-cutover, "no row means
    unvalidatable", a `.sqlproj` manifest test, **no float equality on `DECIMAL` bounds
    (D29/R16)**, and **no module-scope or warm-instance memoisation on the description read
    (R17)**.
11. **Take D20 to Architecture as one question covering two stories.** The approved six-layer
    composition has no home for authored per-field text, which orphans PEA-207's
    `description` and PEA-205's `template_override` for the same underlying reason. It is
    cheap to settle while the model is on paper and expensive once Epic 3's schema builder
    and Epic 8's composition exist. Pair it with **D21** — whether that text is subject to
    §6.4's versioning and eval rules — because the answer changes PEA-207's DDL.
12. **Settle D24 (one range band or two) before PEA-206's DDL is written.** Doc 3777 §8.1
    requires `implausible` (blocks) and `abnormal` (flags and keeps) to behave differently;
    the epic's single unlabelled pair cannot express that, and the fix is a schema change
    once Epic 6 has built against it. If only one band ships, name the columns
    `implausibleMin`/`implausibleMax` so the next implementer is not guessing.
13. **Start D23's backfill triage at grooming, not at migration.** Two SQL queries (in
    PEA-205 §5.4) turn doc 3777 §1.3's defect catalogue into a concrete list of promptIds,
    and D1's contradictory NA-handling rules need a clinical decision with real lead time.
14. **Name an owner for M5.** The prompt-versioning surface is required by doc 3777 §6.4 and
    absent from every roadmap. Concrete framing that gets an answer: *after PEA-205 ships,
    how does an author create v2 of a fragment, diff it, promote it, and roll it back?*
15. **Declare the interim .NET read path as the deliberate first consumer** (§5). Point the
    existing `AIPromptServices` path at `AI.fieldConstraint` and `AI.fieldDescription` as
    **read-only** inputs so the tables carry value before the TypeScript service exists. Keep
    the write boundary intact (D17) and record it as an intentional step, not a fallback.
16. **Decide whether the five carried conflicts are resolved now or carried forward.** Encounter-form
    write ownership (REQ-02-07 vs Epic 9), the incomplete reason-code enum, the guard-blocked run
    that cannot write its own audit row, the middleware list specified four incompatible ways, and
    PHI de-masking with no call site. **None is caused by the language choice and none is fixed
    by it** — but a greenfield service is the cheapest moment in the programme to settle them,
    because nothing has been built against the wrong answer yet.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/CLAUDE.md` - The binding engineering rules cited throughout §6; source of rules 2–8, the Numbers rule and the PR checklist.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest behind X6 (zero `<None>` entries) and X7 (line 10 targets SQL Server 2022).
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getPrompt.sql` - The live three-tier prompt precedence engine behind D5, M7 and risk R1.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` - The shipped `AI.prompt` table PEA-205 replaces.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - Lines 14–16 the overlapping AI prompt columns behind D6; lines 17 and 23–65 the audit-trigger gap X3.
- `PacEHR/src/app/core/services/open-ai.service.ts` - Lines 277, 351, 414 write token usage to localStorage — the root of defect X1.
- `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` - Line 618 reads it back; ~1433–1450 applies AI output with no review step, driving M4.
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - Hardcoded model, `temperature = 0`, credential resolution, and no latency instrumentation (X5).
- `pacEHR_API/PacEHR.API/appsettings.json` - Committed credential, defect X2.
- `pacEHR_API/PacEHR.Functions.Process/Program.cs` - The scheduled-job host wiring behind M3 and PEA-204's delivery plan.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The manual release harness that stands in for the missing deployment pipeline (M2).

### Medium Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11, the `DEFAULT (getutcdate())` house form applied to all five new tables.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14, the named-CHECK OR-chain house style applied to all five new tables.
- `PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` - Line 45, the client-side role gate behind defect X4.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` - The per-mapping grain shared by PEA-203, 206 and 207.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Resolves encounterID as INT IDENTITY; source of the `templeteId` spelling variant behind risk R7.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` - The `DECIMAL (6, 2)` precedent behind D13 and PEA-206's datatype correction.
- `PacEHR/src/app/features/settings/template-editor/add-edit-field/add-edit-field.component.ts` - The shipped field editor that M6 extends and that evidences the D6 overlap.
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The string-bound procedure layer that makes rule-8 renames a runtime failure (R7).
- `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` - BIGINT precedent supporting the D8 escalation.

### Low Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/gehrimedData_OMH.sql` - Second BIGINT precedent for D8.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/V28Hierarchy.sql` - The sole composite primary key precedent, behind D16.
- `pacEHR_API/pipelines/` - 12 files; searched and confirmed to contain neither database nor Functions deployment (M2, M3).
- `pacEHR_API/pacEHR.sln` - Confirms the Functions project builds as part of the solution.
- `pacEHR_API/PacEHR.Tests.UnitTests/` - The xUnit and Moq project where every story's tests land.
- `pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql` - The only release script that has ever existed.
