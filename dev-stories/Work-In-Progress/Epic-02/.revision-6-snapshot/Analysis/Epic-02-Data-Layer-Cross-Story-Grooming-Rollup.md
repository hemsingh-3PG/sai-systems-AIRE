# Epic 02 (Data Layer) — Cross-Story Grooming Rollup

**Epic:** E2 — AI Schema Data Layer · **Stories:** PEA-201 … PEA-207
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-30
**Revision:** 6 — supersedes Revision 5 (2026-09-29). Snapshot of the prior revision is at
`Epic-02/.revision-5-snapshot/`.
**Status:** Final — synthesis of seven story-level audits, for grooming **and** for delivery
**Build target:** TypeScript/Node.js, **ported from the existing Python service `pacEHR_AI/`**

> 🔴 **Revision 6 corrects the premise every Revision 5 document was built on.**
> Revision 5 stated, in nine documents, that *"no Node/TypeScript backend exists anywhere"*
> and — more consequentially — that the Epic-01-equivalent foundation *"does not exist"*,
> that there is *"no repository, no skeleton, no pipeline and no backlog"*, and that M9 was
> *"the single largest piece of unowned work the retarget creates"* at **13+ points**.
>
> **That audit examined two repositories. There are three.** `pacEHR_AI/` exists and holds a
> **complete, tested Epic 01 in Python**: `core/settings.py`, `core/database.py`,
> `core/llm.py`, `core/auth.py`, `core/errors.py`, `core/logging.py` — 2,229 lines with unit
> and integration suites, `mssql_python` over managed identity, the module-singleton pattern,
> the `os.environ`-containment test and the log-interpolation PHI guard.
>
> **M9 is therefore a port, not a greenfield build**, and M10 is a translation of an existing
> allow-list rather than the authoring of a new one. Six proven module boundaries, their
> docstrings, their invariants and — most valuably — **their test suites** carry across. The
> foundation work drops from **13+ points to 5–8**, and D1a changes from *"who builds this?"*
> to *"who ports it, and when?"* — a materially smaller and better-specified question.
>
> **What did not change:** every table, column, constraint, index, role, Gherkin scenario,
> REQ- ID, vocabulary and clinical bound in this epic. The DDL was never affected by any of
> this, and it is not affected now.

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
> decision that is materially *harder* under a Node service than under the Python one
> already written, see §2.1.

> **Purpose.** Each story has its own tech spec with full evidence. This document is the
> layer above: the decisions that block more than one story, the work the epic implies but
> does not contain, the defects the audit surfaced that belong to nobody, and what the epic
> actually costs. Read this before grooming; read the story specs during it.

**The one-paragraph version.** Epic 02 is well designed. Its data model is coherent, its
vocabularies are deliberate, and several of its choices — the ABSENT/ABSTAINED split, the
four-value evaluation verdict, the fail-closed retention guard, the per-mapping grain — are
better than what the codebase does today and should be defended in review. Four things stand
between it and delivery: its runtime half targets a **TypeScript service that must first be
ported from the working Python foundation in `pacEHR_AI/`** (§2.1), two of its stories
**replace or duplicate shipped features** without saying so, four of its seven stories depend
on **database principals and grants that have never existed in this product**, and two of its
tables have **no defined position in the approved prompt-composition model** (D20). None of
these is a design flaw. All of them are unowned — but the first is now a **bounded port with a
reference implementation**, not an open-ended greenfield build.

**On the first of those four.** The epic is **not** written against a fantasy platform — doc
3777 establishes that a new AI service is approved architecture, with the .NET API keeping
auth and persistence. Reading it also surfaced five cross-story decisions (D20–D24) and two
critical-impact risks (R11, R12) that no single story audit could have found, because they
only appear when the epic's tables are laid against the composition model they feed.

⚠️ **That first item remains the sharpest of the four, but Revision 6 shrinks it.** The
language question is *settled* — TypeScript/Node.js — so the epic is not waiting on an
architecture choice. Nor is it waiting on an unwritten foundation: **`pacEHR_AI/` already
implements Epic 01 in Python**, and the build target is a **port of that foundation**, module
for module, test for test. The binding question is therefore not "which platform?" and no
longer "who builds the foundation?" but the narrower **"who ports six known modules, and in
which sprint?"** — still unowned, but bounded, estimable and de-risked by a working reference.
**The epic's own DDL is entirely unaffected**, which is why PEA-201's DDL half can start
immediately; the repository layer follows the port.

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
| | **+ foundation port (M9/M10)** | | — | **8–13** (was 16–18 as greenfield) | Port from `pacEHR_AI/`, not authoring |

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
| **D1a** | 🟠 **Who ports the foundation, and in which sprint?** `pacEHR_AI/` already implements Epic 01 in Python — six `core/` modules, 2,229 lines, unit and integration suites. The Node service needs `src/core/{settings,database,llm,errors,logging,auth}.ts` **ported from those six**, plus a Node allow-list derived from `pacEHR_AI/pyproject.toml` and [00-langchain-api-truth.md](solution-doc:5091). Bounded work with a working reference — not authoring. **Downgraded from 🔴 to 🟠 at Revision 6** | Architecture + Eng leadership | every story's repository and test layer (the DDL is unblocked) |
| **D1b** | 🔴 **Three target architectures are live simultaneously and only one can be right.** (a) `docs/architecture/design/12-ai-phase1-implementation-architecture.md` Part 2 recommends **Option B — `PacEHR.AI.*` projects inside the existing .NET solution** — and explicitly defers a separate deployable (Option C) to Phase 2/3; (b) the reference corpus and the built `pacEHR_AI/` specify a **standalone Python service**; (c) this epic specifies a **standalone TypeScript service**. The owner has selected (c). **That selection contradicts a written architecture recommendation that no Epic-02 document cites.** Record the override, or reopen it | Architecture | the whole programme, not just this epic |
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
| **Ownership** | **The real question — but a scheduling one, not an open design one.** |

**The residual blocker is a sequencing question, not a design gap.** Not *"which language?"*
— that is settled — but: **is the Node service staffed, is Epic 02 sequenced before it, and
who ports the foundation and the dependency allow-list?** Revision 5 answered the middle of
that badly, claiming no foundation existed to port. It does: `pacEHR_AI/` carries a published
12-epic backlog *and* a delivered Epic 01. If Epic 02's tables land first they are still
correct and empty — risk R3 at epic scale — but the wait is now one bounded port rather than
an unscoped build. Route this to Architecture with the three architecture documents attached
(including `docs/architecture/design/12-ai-phase1-implementation-architecture.md`, which
recommends a different answer entirely — D1b), and see D1a.

**🔴 Revision 6 — the verification behind this section was incomplete.** Revision 5 recorded
*"verified against both repositories: no Node/TypeScript backend exists anywhere."* That is
still literally true of Node — and it is beside the point, because **the audit examined two of
three repositories**. `pacEHR_AI/` is the third, and it contains a **complete Epic 01 in
Python**:

| Module | Surface | Lines |
|---|---|---|
| `core/settings.py` | `settings()` — the only reader of the environment, `@lru_cache(maxsize=1)` | 47 |
| `core/database.py` | `database.aexecute(sql, *params)` — `mssql_python`, `ActiveDirectoryMsi`, server-side binding | 75 |
| `core/llm.py` | `llm_manager.azure_openai_gpt_5_5_llm` | 86 |
| `core/auth.py` | `entra_authenticator.authenticate(token)` | 118 |
| `core/errors.py`, `core/logging.py` | `PacEHRError`, `AuthenticationError`; `configure_logging(level)` | 56 |
| `tests/unit`, `tests/integration` | incl. the `os.environ`-containment scan and the log-interpolation PHI guard | 1,847 |

**The consequence for this epic is large and favourable.** M9 stops being *"author a
foundation from nothing"* and becomes *"port six modules whose boundaries, invariants,
docstrings and tests already exist."* The `asyncio.to_thread` wrapper in `core/database.py`
disappears in Node rather than needing a design decision; `Settings`' seven required fields
translate to a zod object field for field; the two PHI-guard tests translate to vitest almost
line for line. **Every `_SQL` constant, every class name and every method contract carries
across unchanged.**

**What the port must not lose.** Three invariants in `pacEHR_AI/CLAUDE.md` are enforced by
tests today and have no automatic Node equivalent — carry each one across deliberately, with
its test: (1) `os.environ` appears in exactly one module → `process.env` appears only in
`src/core/settings.ts`; (2) no logger call interpolates its message → no template literal in a
log call; (3) `__init__` touches no network → module import opens no connection, which is what
lets the unit suite import the whole tree with no credentials.

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
| **M9** | 🟠 **TypeScript service foundation — a port of `pacEHR_AI/core/`, not a greenfield build.** A new repository plus **src/core/settings.ts** (zod ← `settings.py`), **src/core/database.ts** (node-mssql pool + `Transaction` ← `database.py`), **src/core/llm.ts**, **src/core/errors.ts**, **src/core/logging.ts**, **src/core/auth.ts**, `tsconfig`, lint, vitest harness, CI, and container/Functions packaging | **Every one of PEA-201's siblings imports these.** Revision 5 scored this 13+ as unowned greenfield authoring. **Revision 6: the six modules exist, tested, in Python** — the work is translation against a working reference, and the three PHI/config invariants come with their tests. Still unowned; no longer open-ended | **5–8** (was 13+) |
| **M10** | 🟠 **Node dependency allow-list** — the document that replaces [00-langchain-api-truth.md](solution-doc:5091) | Doc 5091 pins exact Python library APIs and forbids everything outside them; it governs Python only. Without a Node equivalent, every story's imports are unconstrained and the "no cache" rule has nothing to bind to. **Revision 6: `pacEHR_AI/pyproject.toml` gives the seven-dependency shape to match** (`langchain`, `langchain-openai`, `pydantic`, `pydantic-settings`, `mssql-python`, `pyjwt[crypto]`, `azure-identity`) — the Node list is a mapping exercise with a fixed target, not an open design | **2–3** (was 3–5) |
| **M4** | **Clinician review UI** (Epic 9's `/ai/encounter/resolve` + front end) | Without it, half of `AI.fieldOutcome` is permanently NULL | 8+ |
| **M5** | **Prompt versioning / diff / rollback UI** | `AI.promptFragment` stores every version specifically so Epic 8 can roll back and A-B compare (REQ-08-14). No version, history, diff, rollback, preview or approve concept exists anywhere in the front end — **and it appears in neither architecture document's roadmap either**, while doc 3777 §6.4 requires the behaviours it would expose. A genuine ownership gap, not just an unscoped story | 8+ |
| **M6** | **Template-editor authoring for constraints and descriptions** | PEA-206b + PEA-207b, merged | 8–10 |
| **M7** | **Legacy prompt cutover** — backfill, precedence parity, retire four procedures and an admin feature | PEA-205b | 8 |
| **M8** | **Authoring validation for prompt-adjacent free text** | Doc 3777 §1.3 D10 records four content-free prompts (`sdwdxs`, `rfvdytvfgvcyt`, `...`, `esfsaf@#`) live in production because nothing validated authoring, and D9 an unescaped `&lt;&lt;…&gt;&gt;` injection surface. Both PEA-205's `fragmentText` and PEA-207's `description` are the same kind of surface. §6.4 specifies the rules; nobody has scoped implementing them | 2–3 |

**M1, M2, M9 and M10 are on the critical path and none is in the epic.** M3 is a prerequisite
for PEA-204 that nobody has noticed because the Functions host was assumed not to exist.
**M9 and M10 exist only because the service is a Node build rather than the Python one already
written** — at Revision 6 they total **7–11 points against Revision 5's 16–18**, because both
are ports from `pacEHR_AI/` rather than original work. They remain unowned, and they remain
the gate on every story's repository layer.

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
| **X6** | **`.sqlproj` release-script registration is barely exercised.** ⚠️ **Corrected at Revision 6:** Revision 5 recorded *zero* `<None>` entries; re-verified 2026-09-30 there are **12**, against **2,852** `<Build>`. The conclusion survives the correction — a path used twelve times in a 2,857-file project is not a path anyone should trust silently, and unregistered files are still never deployed. Keep the manifest test; drop the "never exercised" wording | 🟡 Low–Med | `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` |
| **X7** | **SSDT targets SQL Server 2022, not Azure SQL** — a latent target mismatch if deployment is to Azure SQL | 🟠 Med | Same file, line 10 (`Sql170DatabaseSchemaProvider`) |

| **X8** | 🔴 **NEW at Revision 6 — the auth token is "encrypted" with a hardcoded literal key.** Three call sites build an `Authorization`-equivalent header as `encrypt(JSON.stringify(idToken), 'SecretKey123')`. The key is in the shipped bundle, so the transform is obfuscation, not encryption, and it is identical for every tenant and every user | 🔴 High | `PacEHR/src/app/core/services/open-ai.service.ts` lines 247, 320, 382 |
| **X9** | 🟠 **NEW at Revision 6 — the `AI` schema exists in the live database but not in source control.** `[AI].[prompt]` is registered in the `.sqlproj`, and there is no `CREATE SCHEMA [AI]` anywhere in the 2,857 SQL files. The schema was created out-of-band and the SSDT project has been carrying an undeclared dependency on it ever since. **PEA-201 is the story that fixes this** — and it means PEA-201 is not purely additive, it is also a reconciliation | 🟠 Med | `pacEHR_API/PacEHR.Database/` — zero `CREATE SCHEMA` across the tree |

**X1 is the one to raise first.** It undermines the audit trail Epic 02 exists to build: PEA-202
is specified to record token usage per invocation, and the only source of that data today is a
value the browser can edit. **X2 and X8 are the two to fix first** — both are live credential
exposures in committed code, and X2 additionally exposes SendGrid and Google Maps keys on the
same page of the same file.

---

## 5. Sequencing and critical path

```
TRACK A — LANGUAGE-NEUTRAL (starts now, gated only on D2/D3)
D1  language ✔ RESOLVED (TypeScript, ported from pacEHR_AI)
D2/M1 principals ──────┬──> PEA-201 DDL half (0001 + schema reconciliation, X9)
D3/M2 deployment ──────┘        │
                                ├──> PEA-202 DDL ──> PEA-203 DDL   (203 FK needs 202)
                                ├──> PEA-205 DDL
                                ├──> PEA-206 DDL   (D24/D25 decided first)
                                └──> PEA-207 DDL

TRACK B — THE PORT (starts now, in parallel; no longer a build)
D1a owner ──> M9 port from pacEHR_AI/core/ (5–8) ──> M10 Node allow-list (2–3) ──> D28
                       │  settings.py  → settings.ts   (zod; NEVER .default(0) — R2)
                       │  database.py  → database.ts   (node-mssql; to_thread drops away)
                       │  llm/auth/errors/logging.py → .ts
                       │  + the three invariant tests, or R18 is live
                       v
TRACK C — REPOSITORY LAYER (gated on Track A object + Track B)
        ├──> PEA-201 runner half (databaseMigrations.ts)
        ├──> PEA-202 agentRunWriter.ts ──> PEA-203 fieldOutcomeRepository.ts
        │                                          │
        │                                    D4 ──>┴──> PEA-204 purge job
        │                                                 + D30 host + M3 deploy
        ├──> PEA-205 promptFragmentRepository.ts
        ├──> PEA-206 fieldConstraintRepository.ts (D29)
        └──> PEA-207 fieldDescriptionRepository.ts

TRACK D — SURFACES & CUTOVER (the ~40 points the epic implies but does not contain)
        M4 clinician review UI      ← PEA-203 is half-NULL without it
        M5 prompt version/rollback  ← required by §6.4, on nobody's roadmap
        M6 template-editor authoring (PEA-206b + PEA-207b, merged — same components)
        M7 legacy prompt cutover    ← PEA-205b, gated on the parity query
        M8 authoring validation     ← applies to fragmentText AND description
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
- **D1 is no longer on the critical path** (§2.1), and at Revision 6 **D1a is no longer the
  largest item on it.** The Tier 1 gates are now D2/M1 principals and D3/M2 deployment — the
  database infrastructure — with D1a/M9/M10 reduced to a 7–11-point port running in parallel.
  **M1 and M2 are now the binding constraint**, and neither is in the epic.
- 🔴 **Every story splits in two, and the halves have different readiness.**
  The DDL half of all seven stories is language-neutral and can be built today against
  SSDT. The repository/config/test half cannot start until **M9** lands. Estimating or
  committing a story as a single unit overstates readiness — split the points.
- **The new service is a parallel track, not a gate, and at Revision 6 a shorter one.**
  Epic 02's storage can land ahead of its writer; that is a legitimate choice and should be a
  declared one (D17). Revision 5's caveat was that "nothing exists" for Node, making the wait
  between *tables land* and *something writes them* open-ended. **With `pacEHR_AI/core/` as the
  port source, that wait is one bounded piece of work** — which is the difference between
  shipping empty tables on a promise and shipping them against a scheduled consumer.
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
| **R6** | 🟠 **The TypeScript service has no repository or pipeline yet → tables ship correct and empty, waiting on a service nobody has scheduled.** **Downgraded at Revision 6:** an Epic-01-equivalent *does* exist to point at (`pacEHR_AI/core/`), so the wait is a port, not a build. Mitigated in the near term by the interim .NET read path (§5) | Med | High | §2.1, D1a, M9 |
| **R18** | 🔴 **The port silently drops an invariant the Python tests enforce.** `pacEHR_AI` proves `os.environ` containment and no-log-interpolation with two cheap unit tests. A TypeScript port that carries the modules but not the tests looks complete and has lost both PHI guards. Nothing fails; the leak is only visible in a log line nobody reads until an incident | **High** | **Critical** | M9; §2.1 "what the port must not lose" |
| **R19** | 🟠 **Three architectures, one codebase.** `12-ai-phase1-implementation-architecture.md` recommends in-solution `PacEHR.AI.*` (.NET); the reference corpus and `pacEHR_AI/` say standalone Python; this epic says standalone TypeScript. Building against the wrong one is the most expensive mistake available here, and no Epic-02 document cites the .NET recommendation | Med | **Critical** | D1b |
| **R7** | **Existing spellings "corrected" by a well-meaning reviewer → runtime binding failure** | Med | High | all |
| **R8** | **Retention unresolved while ~11M rows/year accumulate** | High | Med | D4 |
| **R9** | **Purge silently deletes Epic 10's replay inputs** — nothing errors, the replay set just shrinks | Med | High | 204 §3.4 |
| **R10** | **SQL Server 2022 target vs Azure SQL deployment** | Med | Med | X7 |
| **R11** | **Authored per-field text has no layer in the approved composition** → Epic 3 and Epic 8 each invent an injection point, or the text is quietly dropped | High | **Critical** | D20; 205 Finding 15, 207 Finding 13 |
| **R12** | **`AI.fieldConstraint` ships with one range band where the architecture needs two** → either genuinely abnormal values pass unflagged, or real hypertensive values get blocked as implausible. Not fixable at runtime | High | **Critical** | D24; 206 Finding 14 |
| **R13** | **205's backfill faithfully migrates audited-defective data** — 13 catalogued defects including four garbage prompts and two contradictory active rules — and the parity gate certifies the result as correct | High | **Critical** | D22, D23; 205 Findings 13–14 |
| **R14** | **No authoring validation on any new free-text column** → the pattern that produced `sdwdxs` in production repeats in `fragmentText` and `description` | High | High | M8 |
| **R15** | 🟠 **No Node dependency allow-list yet.** [Doc 5091](solution-doc:5091) constrains Python libraries to an exact pinned API surface; nothing equivalent exists for Node. Unconstrained imports are how an ORM, a cache library or a hand-rolled connection helper enters the data layer and quietly voids the no-cache and least-privilege rules. **Downgraded at Revision 6:** `pacEHR_AI/pyproject.toml`'s seven dependencies fix the target shape, so the list is a mapping with a known answer | Med | High | M10, D28 |
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

0. 🔴 **Settle D1b — three architectures are live and only one can be right.** Before any
   code: `docs/architecture/design/12-ai-phase1-implementation-architecture.md` Part 2
   recommends in-solution `PacEHR.AI.*` (.NET) and defers a standalone service to Phase 2/3;
   the reference corpus and the built `pacEHR_AI/` say standalone Python; this epic says
   standalone TypeScript. The owner has chosen TypeScript — **record that as an explicit
   override of a written recommendation, with the reason**, or the next reviewer reopens it
   at integration. This is a thirty-minute action that protects every estimate below it.
0a. 🟠 **Commission M9 + M10 as a port, not a build (D1a, D28).** Concrete framing, now that
   the source exists: *which team creates the Node repository, and who ports
   `pacEHR_AI/core/{settings,database,llm,auth,errors,logging}.py` to `src/core/*.ts` **with
   their tests**?* 7–11 points, not 16–18. Until that is scheduled, **only the DDL half of each
   story is truly ready** — split the points accordingly (§5). **The port's acceptance
   criterion is the three invariants, not the six modules** (§2.1, R18): `process.env` confined
   to `settings.ts`, no interpolated log message, no network at import — each with the vitest
   translation of the Python test that proves it.
1. **Confirm with Architecture that the TypeScript service is the build target of record, and
   whether Epic 02 is sequenced before or after it.** D1 itself is closed (§2.1) — language is
   settled as TypeScript/Node.js ported from `pacEHR_AI/`. Note for that conversation: the
   Python service is **not** hypothetical, so "why are we not simply continuing it?" is a
   question the decision should have a recorded answer to. Also
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

---

## 10. Epic delivery plan — end to end

**Added at Revision 6.** Sections 1–9 groom the epic; this section commits it to a sequence.
Scope is **end to end**: storage, runtime, authoring surfaces and legacy cutover — the full
~70–75 points plus the 7–11-point foundation port, not the ~31-point storage core alone. Each
story's own tech spec carries the detailed plan; this is the train they ride.

**Assume nothing is delivered.** `AI.prompt` and the live `AI` schema are pre-existing
*constraints* to reconcile with (X9), not progress against this epic. `pacEHR_AI/core/` is a
*port source*, not a delivered increment of this epic.

### 10.1 The five releases

| R | Name | Contains | Points | Gated on | Exit criterion |
|---|---|---|---|---|---|
| **R0** | Unblock | D1b, D2/M1 principals, D3/M2 DB pipeline, D24, D1a staffing, X2+X8 rotation | ~16–21 | nothing | A migration reaches staging through a pipeline, and three roles exist |
| **R1** | Foundation & schema | M9 port, M10 allow-list, PEA-201 (both halves) | ~16–24 | R0 | `applyPending()` runs twice against staging, second run a no-op |
| **R2** | Audit spine | PEA-202, PEA-203 (tables + write paths) | ~10–13 | R1 | One real extraction writes one `agentRun` row and N `fieldOutcome` proposals |
| **R3** | Config tables | PEA-205a, PEA-206a, PEA-207a (tables + read paths) | ~9–13 | R1 (parallel with R2) | A request-time read returns per-mapping bounds and descriptions |
| **R4** | Surfaces | M4 review UI, M6 authoring (206b+207b), M8 validation, PEA-203 decision path | ~23–28 | R2, R3, D7 | A clinician accepts a field and the decision lands in `fieldOutcome` |
| **R5** | Cutover & retention | PEA-205b/c, M5, M7, PEA-204 | ~21–29 | R4, D4, D22, D23, M3 | Legacy prompt path retired; purge runs and refuses when unset |

**R0 is the release most likely to be skipped and the one that cannot be.** Four of seven
stories have security DoD items that pass *vacuously* if the principals do not exist (R4), and
nothing at all reaches an environment without M2. Shipping R1 before R0 produces tables that
are correct, ungoverned and undeployable.

### 10.2 What each story owes, in one line

| Story | DDL half (Track A) | Runtime half (Track C) | Surface half (Track D) | Total |
|---|---|---|---|---|
| PEA-201 | `0001` + schema reconciliation (X9) + CI scope check | `databaseMigrations.ts`, `applyPending()` | — | 8–13 |
| PEA-202 | `0002_ai_agentrun.sql` | `agentRunWriter.ts` + instrument the call path | — | 5–8 |
| PEA-203 | `0003_ai_fieldoutcome.sql` + filtered index | `fieldOutcomeRepository.ts` proposal path | decision path + M4 review UI | 5 (+8 UI) |
| PEA-204 | purge procedure | `fieldOutcomeRetention.ts` + fail-closed guard | timer host (D30) + M3 deploy | 2 (+3–5 host) |
| PEA-205 | `0004_ai_promptfragment.sql` | `promptFragmentRepository.ts` | backfill triage, parity gate, M5, M7 | 13–26 |
| PEA-206 | `0005_ai_fieldconstraint.sql` (D24 first) | `fieldConstraintRepository.ts` (D29) | authoring UI (M6) | 3 (+5–8 UI) |
| PEA-207 | `0006_ai_fielddescription.sql` | `fieldDescriptionRepository.ts` | authoring UI (M6, merged with 206b) | 3 (+5 UI) |

**Read the three halves as three different readiness states, not three tasks.** Track A is
ready now. Track C is ready when M9 lands. Track D is ready when Product answers D7 — and
until then, **every Track D estimate is a placeholder, not a commitment.**

### 10.3 The four dates to set at grooming

Ordered by lead time, longest first. Each is non-engineering and each blocks a release.

1. **D4 — retention period** (Clinical + Compliance) → gates R5. Longest lead time in the
   epic and the only blocker on an otherwise ready 2-point story. Start it at grooming.
2. **D23 — backfill triage** (Product + clinical content owner) → gates R5. Needs a human to
   rule on four garbage prompts and two contradictory NA rules. The two triage queries in
   PEA-205 §5.4 turn it into a concrete list of `promptId`s; run them at grooming, not at
   migration.
3. **D7 — UI scope** (Product) → gates R4. Decides whether this epic is ~31 points or ~75.
4. **D24 — one range band or two** (Architecture + clinical) → gates R3, and **must precede
   PEA-206's DDL**. After R3 it is a schema change with Epic 6 built on top of it.

### 10.4 How to tell the plan is working

Not "stories closed" — every table in this epic can ship correct and empty, and four of them
will if nobody notices. Track these instead:

| Signal | Read it as |
|---|---|
| Rows in `AI.agentRun` per day vs. `Log.AILogs` rows per day | The instrumented path is live and complete, or it is not |
| Proportion of `AI.fieldOutcome` rows with a non-NULL decision | M4 shipped, or half the table is permanently NULL (R3) |
| Mappings with a `fieldConstraint` row / total mappings | M6 shipped and is being used, or the validators pass vacuously |
| Purge dry-run row count vs. actual | The retention predicate means what R5 thought it meant |
| `PASSED` count in `promptFragment.passedEvaluation` | Should be **zero** until Epic 10 exists. Any other number means D10 was defaulted and the gate is failing open |

The last row is the cheapest fraud detector in the epic: a single `SELECT COUNT(*)`.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_AI/core/` - 🔴 **The port source, and the correction behind Revision 6.** Six modules — `settings.py`, `database.py`, `llm.py`, `auth.py`, `errors.py`, `logging.py` — implementing Epic 01 complete and tested. Revision 5 stated this foundation did not exist.
- `pacEHR_AI/tests/unit/` - The three invariants the port must carry across: `test_settings.py` (`os.environ` containment), `test_logging_hygiene.py` (no interpolated log message), `test_repo_scaffold.py` (import with no environment). R18.
- `pacEHR_AI/pyproject.toml` - The seven pinned dependencies M10's Node allow-list must map.
- `pacEHR_AI/CLAUDE.md` - The engineering standard the ported service inherits; the singleton, PHI and Numbers rules are language-neutral.
- `docs/architecture/design/12-ai-phase1-implementation-architecture.md` - Part 2 recommends in-solution `PacEHR.AI.*` and defers a standalone service to Phase 2/3 — the third live architecture, and the basis of D1b/R19. Cited by no Revision 5 document.
- `pacEHR_API/CLAUDE.md` - The binding engineering rules cited throughout §6; source of rules 2–8, the Numbers rule and the PR checklist.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest behind X6 (**12** `<None>` against 2,852 `<Build>`, re-verified 2026-09-30 — Revision 5 said zero) and X7 (line 10, `Sql170DatabaseSchemaProvider`, targets SQL Server 2022).
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
