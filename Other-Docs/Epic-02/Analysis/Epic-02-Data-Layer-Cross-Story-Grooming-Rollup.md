# Epic 02 (Data Layer) — Cross-Story Grooming Rollup

**Epic:** E2 — AI Schema Data Layer · **Stories:** PEA-201 … PEA-207
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-10-05
**Revision:** 8 — supersedes Revision 7. Snapshots at `Epic-02/.revision-7-snapshot/`,
`.revision-6-snapshot/`, `.revision-5-snapshot/`.
**Status:** Final — synthesis of seven story-level audits, for grooming **and** for delivery
**Build target:** TypeScript/Node.js, **built greenfield in `pacEHR_AI/`**


> ⛔ **Amended 2026-10-06 — PEA-205 (`AI.promptFragment`) and PEA-207 (`AI.fieldDescription`) are
> withdrawn.** Prompts stay in the existing `AI.prompt` table (account-level master prompt, chosen
> by `dbo.usp_getPrompt`); field and section instructions stay in `Template.fields.prompt` and
> `Template.section.prompt`. Neither table is created. Rationale and accepted costs:
> `DELIVERY-PLAN.md`, decision of 2026-10-06. Text below that describes either table is history.
> ✅ **Revision 8 — the foundation is delivered; M9 and M10 are closed.**
> Verified against `pacEHR_AI/` commit `e86c54e` (2026-10-01): `src/core/{settings,database,llm,auth,errors,logging,app}.ts`
> and `src/server.ts` are built, merged and tested (AITP-47/50/54/59). The blocker that gated
> every story's runtime half since Revision 5 is gone, and the three PHI/config invariants
> shipped as **ESLint rules with planted-violation tests** — stronger than specified.
>
> 🔴 **Two stack facts in Revisions 5–7 were wrong and are corrected throughout: the test
> runner is `node --test` with tsx, not vitest**, and the agent framework is already chosen
> (`langchain`, `@langchain/core`, `@langchain/openai` are dependencies). Also settled by the
> code: zod v4, `mssql` ^12.7.2, pino, jose, Node >=22.13. **D28 is closed.**
>
> **The critical path is now entirely database and deployment infrastructure:** D2/M1 the three
> principals, D31 migration authority, M11 a deployment path. None is in the epic; none has an
> owner. ⚠️ Repository commits use **`AITP-`** keys, not `PEA-`.
>
> ---
>
> 📜 **Revision 7 (retained as the record of the three owner decisions; item 1 is superseded
> by Revision 8 above).**
>
> **1. Node.js, greenfield.** ~~The repository is empty; M9 is 8–13 points of greenfield
> build.~~ **Superseded — M9 was delivered 2026-10-01.** Revisions 5, 6 and 7 each described
> the foundation wrongly in turn (5: "no backlog exists anywhere"; 6: "a tested implementation
> exists, port it"; 7: "specified but unbuilt"). **Revision 8 is the first to describe code
> that was read at the commit it names** — `e86c54e`. The lesson is cheap and worth keeping:
> verify the repository before estimating against it.
>
> **2. `pacEHR_AI/` owns everything belonging to the new AI engine — including its DDL.** The
> `AI.*` schema, `migrations/sql/0001…0006` and the migration runner ship in the AI
> repository and reach a database through `MigrationRunner.applyPending()`. **Revision 6
> retargeted the DDL to `pacEHR_API`'s SSDT project; that is reversed.** Code separation is
> the governing principle.
>
> **3. Existing AI code is not migrated.** `AIController`, `AIPromptServices`, `AI.prompt`,
> `usp_getPrompt` and the Angular `ai-prompt` admin feature stay in place. Only new AI work
> goes in the new repository.
>
> **What is unchanged, and always was:** every table, column, constraint, index, role, Gherkin
> scenario, REQ- ID, vocabulary and clinical bound. The data model never depended on the
> language or the repository that hosts it.
>
> **Three consequences that cost something** — each tracked below, none of them a design flaw:
> **(a)** the AI tables leave the SSDT model, so no build-time check proves a reference into
> `Template.*` or `Encounter.*` still resolves (new risk **R20**); **(b)** the interim .NET
> read path, recommended throughout Revisions 5–6 as the first consumer, is **withdrawn** —
> it would put AI reads back in `pacEHR_API`; **(c)** decision **D5** is settled as *coexist*,
> which shrinks PEA-205 sharply and creates a two-prompt-systems problem in its place.

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
| | **+ infrastructure (M11 deployment)** | | — | **5–8** | ✅ M9/M10 delivered 2026-10-01; M11 remains |

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
| **D1** | ~~Platform?~~ — **RESOLVED: greenfield Node/TypeScript in `pacEHR_AI/`**, see §2.1 | closed | was: every story's runtime half |
| **D1a** | ✅ **CLOSED — delivered 2026-10-01** (`pacEHR_AI` `e86c54e`). `src/core/{settings,database,llm,errors,logging,auth,app}.ts` and `src/server.ts` are merged and tested. 🔴 **Residual, and now the open item: M11 — a deployment path for the service and its migrations** (see D31) | closed | — |
| **D1b** | ✅ **CLOSED at Revision 7.** Standalone Node service in `pacEHR_AI/`, owning all new AI code and the `AI.*` DDL. This overrides `docs/architecture/design/12-ai-phase1-implementation-architecture.md` Part 2, which recommends in-solution `PacEHR.AI.*` (.NET) and defers a separate deployable to Phase 2/3. **Record the override and its reason** so it is not reopened at integration | closed | was: the whole programme |
| **D2** | ✅ **CLOSED 2026-10-05 — no roles, no grants.** `aiServiceRuntime`, `aiPromptAdmin` and `aiTemplateAdmin` are **not created**. Authority over `AI.*` is enforced in the application; the service connects as one principal. The four stories' security DoD items are **withdrawn**, not satisfied. 🔴 Cost: `AI.agentRun` loses its server-side append-only guarantee — recoverable with an `INSTEAD OF UPDATE, DELETE` trigger, which needs no principal | closed | was: 203, 205, 206, 207 |
| **D3** | ⚠️ **Restated at Revision 7 — it is no longer about SSDT.** The `AI.*` DDL ships in `pacEHR_AI` and applies through `MigrationRunner`, so the question is how *that* reaches an environment. Tracked as **M11**, and still open | DevOps | all seven exit criteria |
| **D31** | 🔴 **NEW — who runs migrations against production, and with what credential?** The DDL now ships in `pacEHR_AI/` and applies through `MigrationRunner`, not through `pacEHR_API`'s release harness. That harness, manual as it is, has a review step and a DBA. **The new path has neither yet.** Schema-change rights must not be held by the runtime identity (`aiServiceRuntime`) | Architecture + DBA | PEA-201, and every story's DDL |


### Tier 2 — blocks one story, cannot be decided by engineering

| # | Decision | Owner | Story |
|---|---|---|---|
| **D4** | **Retention period (open question B7).** How long must derived clinical content be kept? Must also exceed Epic 10's replay window, which is also unstated | Clinical + Compliance | 204 |
| **D5** | ✅ **CLOSED at Revision 7 — coexist.** Existing AI code is not migrated, so `AI.prompt` and `usp_getPrompt` keep serving production. 🔴 Closes one question and opens a harder one — see **D32** and risk R21 | closed | 205 |
| **D6** | **Precedence: `AI.fieldDescription.description` vs `Template.fields.aiSummaryPrompt`** | Product + Architecture | 207, and Epic 3 implements it |
| **D7** | **Are the authoring and review UIs in scope, follow-on, or deferred?** | Product | 203, 205, 206, 207 |
| **D17** | ✅ **CLOSED at Revision 7 — the Node AI service owns them.** All new AI code, and the `AI.*` DDL, live in `pacEHR_AI/`. No two-writer problem. Residual: the cross-repository schema coupling now has no build-time guard (risk **R20**) | closed | all seven write paths |
| **D18** | **Is `AI.agentRun` (epic) or `AI.runAudit` (architecture §3.1) the intended name?** Same role, two names, two documents | Architecture | 202 |
| **D19** | **Q5 from the architecture doc is D4 restated and still open:** retention for evidence spans containing PHI. Confirm one answer serves both | Compliance | 204 |
| **D20** | **Where does authored per-field text enter the six-layer prompt composition?** Doc 3777 §6.1's L0–L5 has no layer for it — L3 is *generated*, L4 *compiled*, L2 per-template-*family*. This orphans both `AI.fieldDescription.description` (207) and `kind='template_override'` (205). Two stories, one root cause | Architecture | 205, 207, and Epic 3 |
| **D21** | **Is authored prompt-adjacent text subject to §6.4's fragment rules** — immutable versions, authoring validation, eval-bound promotion? If yes, 207's single mutable column is the wrong shape and 205 needs an eval-set binding column | Architecture | 205, 207 |
| **D22** | ⚠️ **Narrowed by D5 = coexist — there is no migration, so this is no longer a cutover target but a *comparison* question.** Which precedence is authoritative for 205 — — live `usp_getPrompt` behaviour, or doc 3777 §6.4's written ordering (`Organization-Universal > Organization > System-Universal > System`)? They differ, and §6.4 has no template tier | Architecture | 205; informs D5 |
| **D23** | ⚠️ **No longer a backfill gate (D5 = coexist), but the defects stay live in production either way.**  Doc 3777 §1.3 audits all 25 live `AI.prompt` rows and finds 13 defects: four content-free garbage prompts live in production, four near-duplicate forks (two simultaneously active), and two prompts with contradictory NA-handling rules. Which rows migrate, and which of the two contradictory rules is correct? | Product + clinical content owner | 205 |
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
| **D28** | ✅ **CLOSED by the code.** `mssql` ^12.7.2, zod v4, **`node --test` with tsx** (not vitest), pino, jose, Node >=22.13, ESM with `.js` specifiers and the `#core/*` alias. `package.json` is the allow-list; `settings.ts`'s `REFUSED` list rejects tracing variables that leak prompt text | 201–207 |
| **D29** | **How are `DECIMAL(6,2)` bounds compared?** node-mssql surfaces `DECIMAL` as a JS binary double, so in-process comparison reintroduces the float imprecision PEA-206 chose `DECIMAL` to avoid. Options: push range comparisons into SQL, or compare with an explicit tolerance. Must be settled before the first bound check is written | 206 |
| **D30** | **Where does the purge timer run** — the existing .NET `PacEHR.Functions.Process` host (five live timers, but no pipeline deploys it — see M3) or a **new Node Functions v4 host**? Affects M3's scope and PEA-204's DoD | 204 |

| **D32** | 🔴 **NEW — when both prompt systems are live, which serves a given request?** `AI.prompt`/`usp_getPrompt` (legacy, .NET, in production) and `AI.promptFragment` (new, Node). With no written rule the answer is "whichever path the request took" — a clinician-visible behaviour difference nobody can predict or debug. **This replaces the cutover D5 used to force** | Product + Architecture | 205 |
| **D33** | 🔴 **NEW — what is the contract on `Template.*` and `Encounter.*` columns across the two repositories?** Five `AI.*` tables key on `templetID`, `sectionID`, `fieldID`, `encounterID`, owned by `pacEHR_API`. SSDT used to fail the build on a breaking rename; nothing does now | Architecture | all seven; risk R20 |

### 2.1 D1 — CLOSED: a standalone Node AI service in `pacEHR_AI/`

The architecture documents answer the *design* half of this question.
[2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) is marked **"Design /
approved for planning"** and its §3.1 system context diagram names an explicit new component:

> **AI Orchestrator · NEW** — Ingest Gateway, pipeline, Prompt + Config Registry

The division of responsibility is stated unambiguously: *"The .NET API keeps owning auth,
persistence and the existing contract. The orchestrator owns AI decisioning only."*
`AIController` becomes a **thin proxy**. **That division is unchanged and remains correct** —
and it is what makes the Revision 7 code-separation decision an implementation of the approved
architecture rather than a departure from it.

⚠️ **The language and the repository are settled by owner decision, not by those documents.**
The build target is a **greenfield Node/TypeScript service in `pacEHR_AI/`**: a standalone
repository owning all new AI code *and* the `AI.*` schema, with no reuse of the existing C# AI
logic. Runtime chain: Angular → .NET Web API → Node AI service → Azure OpenAI.

**One framing to avoid.** It is tempting to read this epic's module paths
(`src/repositories/agentRunWriter.ts` and siblings) as an error on the grounds that the
solution is .NET 8 + SSDT + Angular. That reasoning is right about those repositories and
wrong about the plan: **the epic targets a service that does not exist yet, in a repository
that now does.** The .NET/SSDT mapping tables carried in each story spec are a contingency
record, **not** the recommended path — and at Revision 7 they are explicitly not the path.

**✅ Revision 7 — the question this section tracked for five revisions is closed.**

The build target is a **greenfield Node/TypeScript service in `pacEHR_AI/`**, which owns all
new AI code and the `AI.*` schema. The repository exists as of 2026-09-30 and is empty.

**What the epic inherits, and what it must build.** The reference backlog specifies the
foundation completely — PEA-101…106 define settings, database access, the LLM client, auth,
errors and logging, and the governing engineering standard defines the singleton pattern, the
PHI rules and the Numbers rule. **None of it is implemented.** So D1a is implementation
against a detailed specification: known shape, known invariants, no discovery.

| Foundation module | What the spec fixes | Node form |
|---|---|---|
| `src/core/settings.ts` | one reader of the environment; required fields raise at startup | zod schema + a single cached accessor |
| `src/core/database.ts` | one entry point to Azure SQL; managed identity; server-side parameter binding, never interpolation | node-mssql pool |
| `src/core/llm.ts` | the authenticated chat model, built once per process | Azure OpenAI client |
| `src/core/auth.ts` | a verified caller object id, or an error | JWKS validation |
| `src/core/errors.ts`, `src/core/logging.ts` | typed errors; structured logging configured once | — |
| `src/core/databaseMigrations.ts` | 🔴 **new — specified by no prior epic** | `MigrationRunner.applyPending()` |

🔴 **Three invariants are the acceptance criteria for M9, and each needs a test written for
it.** They guard PHI and configuration integrity, and they are cheap:

1. **`process.env` appears in `src/core/settings.ts` and nowhere else.** A repo-wide scan
   fails the suite otherwise. This is what makes a value pasted into a module a test failure
   rather than a code-review opinion.
2. **No log call interpolates its message.** A fixed string plus a structured payload; a
   template literal in a log line is how a clinical value leaks.
3. **Importing any module touches no network and needs no credentials.** This is what lets the
   unit suite import the whole tree, and what keeps a cold start from paying for a client it
   never uses.

**A Node service makes one of these harder than it was.** Module-scope `const`/`Map`
memoisation and Azure Functions v4 warm-instance state both persist across invocations and
both read as ordinary Node — neither looks like a cache in review, and both break the no-cache
rule REQ-03-06 depends on (risk R17).

**And two hazards the runtime introduces, both of which fail silently:**

| Hazard | Required form |
|---|---|
| A missing retention setting read as `0` → full-table purge | `z.coerce.number().int().positive().optional()` — **never `.default(0)`** — with an explicit unset branch that deletes nothing (R2) |
| `DECIMAL(6,2)` surfaced as a JS binary double → boundary comparisons flip | Push range comparisons into SQL, or compare with an explicit documented tolerance (D29, R16) |

### 2.2 Where the DDL lives — reversed at Revision 7

**The `AI.*` schema belongs to `pacEHR_AI/`.** Revisions 5 and 6 routed this epic's DDL through
`pacEHR_API`'s SSDT project and its dated release folders; the owner decision on code
separation reverses that. The shape is the epic's original design:

```
pacEHR_AI/
├── migrations/sql/0001_create_ai_schema.sql … 0006_create_field_description.sql
└── src/core/databaseMigrations.ts   MigrationRunner.applyPending()
```

**What this buys:** one repository owns the AI engine end to end, the migration mechanism is
reviewable as plain literal T-SQL, and no AI change has to transit another team's release
train.

🔴 **What it costs, and what has to replace it.** Three safeguards come free with SSDT and do
not come with a migrations folder:

| Lost | Replacement, and whose job it is |
|---|---|
| **Build-time model validation** — SSDT fails the build if a reference into `Template.*` or `Encounter.*` no longer resolves | An integration test against a restored database, run in CI. **This is not optional** — the AI tables key on `templetID`, `sectionID`, `fieldID` and `encounterID`, all owned by another repository that can change them without seeing this one. New risk **R20** |
| **A human release gate** — the manual harness has a duplicate-object report and a DBA | D31: a named approver and a deploy-time identity distinct from `aiServiceRuntime` |
| **One place to read the whole schema** | The `migrations/sql/` folder is that place — which is why no script may ever be edited after it merges |

⚠️ **The cross-repository coupling is now unguarded and deserves naming.** `pacEHR_API` owns
`Template.fields`, `encounterTempletMapping` and `encounter`; `pacEHR_AI` will key five tables
on their columns — including the misspellings (`templetID`) that must never be corrected. A
rename in `pacEHR_API` breaks `pacEHR_AI` **at runtime, in the environment**, with nothing at
build time to catch it. Put the contract in writing and put a test behind it.

---

## 3. Work the epic implies but does not contain

These are not gaps in the specs. They are stories that need to exist.

| # | Missing work | Why it is needed | Est. |
|---|---|---|---|
| **M1** | ✅ **WITHDRAWN 2026-10-05** — no principals, roles or grants are created by this epic. The `Security/` folder and the three roles are not built | — | **0 — withdrawn** |
| **M2** | **Database deployment pipeline** | Nothing deploys the SSDT project. Releases go through a manual PowerShell harness reading a git ref | 8+ |
| **M3** | **Azure Functions deployment** | Five live timer jobs run from a project no pipeline in this repository deploys. Blocks PEA-204 and anything scheduled. Scope now depends on D30 (existing .NET host vs new Node host) | 3–5 |
| **M9** | ✅ **DELIVERED 2026-10-01** (`pacEHR_AI` `e86c54e`) — Node service foundation: `src/core/{settings,database,llm,auth,errors,logging,app}.ts`, `src/server.ts`, `tsconfig`, lint and the test harness. ⚠️ **CI and deployment packaging did *not* ship with it — that is M11** | **Every one of PEA-201's siblings imports these, and they are merged and tested.** The three PHI/config invariants shipped as ESLint rules with planted-violation tests, plus a repo-wide proof that the tree imports with no environment, network or child process. 🔴 **Note for PEA-202: no transaction primitive was included** | **0 — closed** |
| **M10** | ✅ **CLOSED at Revision 8, in a better form than a document.** The dependency set is `package.json` with a committed lock file, and `src/core/settings.ts` carries a `REFUSED` list that *rejects* environment variables observed to leak prompt text or call an external endpoint (`LANGSMITH_TRACING`, `LANGCHAIN_VERBOSE` and siblings). A list that fails the process beats a list that fails review | **0 — closed** |
| **M4** | **Clinician review UI** (Epic 9's `/ai/encounter/resolve` + front end) | Without it, half of `AI.fieldOutcome` is permanently NULL | 8+ |
| **M5** | **Prompt versioning / diff / rollback UI** | `AI.promptFragment` stores every version specifically so Epic 8 can roll back and A-B compare (REQ-08-14). No version, history, diff, rollback, preview or approve concept exists anywhere in the front end — **and it appears in neither architecture document's roadmap either**, while doc 3777 §6.4 requires the behaviours it would expose. A genuine ownership gap, not just an unscoped story | 8+ |
| **M6** | **Template-editor authoring for constraints and descriptions** | PEA-206b + PEA-207b, merged | 8–10 |
| **M7** | **Legacy prompt cutover** — backfill, precedence parity, retire four procedures and an admin feature | PEA-205b | 8 |
| **M8** | **Authoring validation for prompt-adjacent free text** | Doc 3777 §1.3 D10 records four content-free prompts (`sdwdxs`, `rfvdytvfgvcyt`, `...`, `esfsaf@#`) live in production because nothing validated authoring, and D9 an unescaped `&lt;&lt;…&gt;&gt;` injection surface. Both PEA-205's `fragmentText` and PEA-207's `description` are the same kind of surface. §6.4 specifies the rules; nobody has scoped implementing them | 2–3 |

✅ **M9 and M10 are closed as of 2026-10-01.** **M1 and M11 remain on the critical path and
neither is in the epic.** M3 is a prerequisite for PEA-204 that nobody has noticed because the
Functions host was assumed not to exist.
**M9 and M10 total 11–18 points and are the gate on every story's repository layer.** They are
not in the epic and have no owner. At Revision 7 they are at least fully specified: the
foundation epic says what to build and the engineering standard says how.

**M11 is new at Revision 7 and belongs on this list:** 🔴 **a deployment path for
`pacEHR_AI/`** — how the service and its migrations reach an environment, with what identity,
and who approves a schema change. M2 covered this for the SSDT project; moving the DDL into
the AI repository moves the problem rather than solving it. **5–8 pts**, unowned, and it
blocks PEA-201's exit criterion. See D31.

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
TRACK A — DDL, IN pacEHR_AI/migrations/sql/   (starts as soon as the repo has a skeleton)
D1  ✅ target settled: greenfield Node in pacEHR_AI/
D2/M1  principals + roles  ──┬──> 0001_create_ai_schema.sql   (PEA-201)
D31 who runs migrations  ────┘        │
M11 deployment path ─────────────────┘        │
                                ├──> 0002 agentRun ──> 0003 fieldOutcome  (FK)
                                ├──> 0004 promptFragment
                                ├──> 0005 fieldConstraint   (D24/D25 decided first)
                                └──> 0006 fieldDescription

TRACK B — THE NODE FOUNDATION   (greenfield; gate on every runtime half)
D1a owner ──> M9 src/core/* (8–13) ──> M10 allow-list (3–5) ──> D28 stack choices
                       │  settings.ts   zod — NEVER .default(0) on retention (R2)
                       │  database.ts   node-mssql, managed identity, bound params
                       │  llm / auth / errors / logging.ts
                       │  + the three invariant tests, or R18 is live
                       v
TRACK C — REPOSITORY LAYER + THE RUNNER
        ├──> PEA-201 databaseMigrations.ts  ◀── new; specified by no prior epic
        ├──> PEA-202 agentRunWriter.ts ──> PEA-203 fieldOutcomeRepository.ts
        │                                          │
        │                                    D4 ──>┴──> PEA-204 purge job
        │                                                 + D30 host + M11 deploy
        ├──> PEA-205 promptFragmentRepository.ts   (D32 precedence first)
        ├──> PEA-206 fieldConstraintRepository.ts  (D29)
        └──> PEA-207 fieldDescriptionRepository.ts

TRACK D — SURFACES   (~21–25 pts; the epic implies these and contains none of them)
        M4 clinician review UI      ← PEA-203 is half-NULL without it
        M5 prompt version/rollback  ← required by §6.4, on nobody's roadmap
        M6 template-editor authoring (PEA-206b + PEA-207b, merged — same components)
        M8 authoring validation     ← applies to fragmentText AND description
        ⛔ M7 legacy prompt cutover — WITHDRAWN at Revision 7 (D5 = coexist).
           Replaced by D32: a written precedence rule between the two systems.
```

⚠️ **Track D now sits in `PacEHR/` and `pacEHR_API/`, not in `pacEHR_AI/`.** The review and
authoring surfaces are Angular components against the existing .NET API. Code separation
applies to the **AI engine**, not to the UI that eventually feeds it — worth stating so nobody
tries to build an Angular feature inside the AI service repository.

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
- **D1, D1b and now D2 are closed** (§2.1). The Tier 1 gates are **D31** (who runs migrations and with what credential) and **M11** (a deployment path) — and with roles withdrawn, D31 is the only access-control question left anywhere in this epic.
  **D31** (who runs migrations and with what credential) and **M11** (a deployment path for
  `pacEHR_AI/`), running alongside **D1a/M9/M10** at 16–26 points. **None of the four is in
  the epic and none has an owner** — that is the binding constraint, and it is infrastructure,
  not design.
- 🔴 **Every story splits in two, and the halves have different readiness.**
  The DDL half of all seven stories is language-neutral and can be built today against
  SSDT. The repository/config/test half cannot start until **M9** lands. Estimating or
  committing a story as a single unit overstates readiness — split the points.
- 🔴 **The interim .NET read path is withdrawn.** Revisions 5–6 recommended pointing the
  existing `AIPromptServices` at `AI.fieldConstraint` and `AI.fieldDescription` as a
  read-only first consumer, so the tables proved their value before the AI service existed.
  **Code separation rules that out** — it would put AI reads back in `pacEHR_API`. That is a
  coherent decision, but it removes the only mitigation for **R3**, so the honest consequence
  is: **the tables will be empty and unread until the Node service can read them.** Sequence
  M9 accordingly, or accept a longer dead interval and say so at grooming.
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
| **R4** | ⚠️ **Restated 2026-10-05.** ~~Grants claimed but absent~~ — there are no grants now, by decision. The DoD items are withdrawn rather than vacuous, which is honest. **What replaces the risk:** nothing at the server refuses an `UPDATE` or `DELETE` against `AI.agentRun`, so its append-only property is an application convention | Med | **High** | D2 |
| **R5** | **`.sqlproj` registration missed → object silently never deployed** | Med | High | all; X6 |
| **R6** | 🟠 **The Node service has no skeleton or pipeline yet → tables ship correct and empty, waiting on a service nobody has scheduled.** ⛔ **Worse at Revision 7:** the interim .NET read path that mitigated this is withdrawn, so nothing reads the tables until the Node service can | Med | High | §2.1, D1a, M9 |
| **R18** | 🔴 **The foundation ships without its invariant tests.** `process.env` containment, no-log-interpolation and no-network-at-import are cheap to test and invisible when absent — the service looks complete with both PHI guards gone. Nothing fails; the leak is only visible in a log line nobody reads until an incident | **High** | **Critical** | M9; §2.1 |
| **R19** | ✅ **Closed at Revision 7** — the target is settled (standalone Node in `pacEHR_AI/`). Residual: the decision overrides a written architecture recommendation and that override is not yet recorded anywhere | Low | Med | D1b |
| **R20** | 🔴 **NEW — the cross-repository schema coupling has no build-time guard.** Five `AI.*` tables key on `templetID`, `sectionID`, `fieldID` and `encounterID`, all owned by `pacEHR_API`. Under SSDT a breaking rename failed the build. With the DDL in `pacEHR_AI/`, it fails **at runtime, in the environment**, and only on the code path that touches the renamed column | Med | **High** | §2.2; replace with a CI integration test against a restored database |
| **R21** | 🟠 **NEW — two prompt systems run side by side indefinitely.** D5 is settled as *coexist*: `AI.prompt` + `usp_getPrompt` keep serving production while `AI.promptFragment` accumulates. Two sources of prompt truth, no stated precedence between them, and a clinician-visible behaviour difference depending on which path served the request | Med | **High** | D5; PEA-205 |
| **R7** | **Existing spellings "corrected" by a well-meaning reviewer → runtime binding failure** | Med | High | all |
| **R8** | **Retention unresolved while ~11M rows/year accumulate** | High | Med | D4 |
| **R9** | **Purge silently deletes Epic 10's replay inputs** — nothing errors, the replay set just shrinks | Med | High | 204 §3.4 |
| **R10** | **SQL Server 2022 target vs Azure SQL deployment** | Med | Med | X7 |
| **R11** | **Authored per-field text has no layer in the approved composition** → Epic 3 and Epic 8 each invent an injection point, or the text is quietly dropped | High | **Critical** | D20; 205 Finding 15, 207 Finding 13 |
| **R12** | **`AI.fieldConstraint` ships with one range band where the architecture needs two** → either genuinely abnormal values pass unflagged, or real hypertensive values get blocked as implausible. Not fixable at runtime | High | **Critical** | D24; 206 Finding 14 |
| **R13** | **205's backfill faithfully migrates audited-defective data** — 13 catalogued defects including four garbage prompts and two contradictory active rules — and the parity gate certifies the result as correct | High | **Critical** | D22, D23; 205 Findings 13–14 |
| **R14** | **No authoring validation on any new free-text column** → the pattern that produced `sdwdxs` in production repeats in `fragmentText` and `description` | High | High | M8 |
| **R15** | 🟠 **No Node dependency allow-list yet.** [Doc 5091](solution-doc:5091) constrains libraries to an exact pinned API surface; nothing equivalent exists for Node. Unconstrained imports are how an ORM, a cache library or a hand-rolled connection helper enters the data layer and quietly voids the no-cache and least-privilege rules. **Downgraded at Revision 6:** `pacEHR_AI/package.json`'s seven dependencies fix the target shape, so the list is a mapping with a known answer | Med | High | M10, D28 |
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

0. ✅ **M9 and M10 are delivered** (2026-10-01, `pacEHR_AI` `e86c54e`) and D1a/D28 are closed.
   **M11 — a deployment path for the service and its migrations — is not**, and it is now the
   highest-leverage open item. Concrete framing: *how does `pacEHR_AI` reach an environment,
   what runs `applyPending()` there, and under which identity?* **5–8 points**, no owner.
   ⚠️ Two gaps the foundation did not close and that this epic needs: **no transaction
   primitive** (PEA-202) and **`execute()` returns `undefined` for DDL while typed as an
   array** (PEA-201). Both belong to whoever next touches `src/core/database.ts`.
0a. 🔴 **Answer D31 before the first migration runs against a shared database.** The DDL now
   applies through `MigrationRunner`, not through `pacEHR_API`'s release harness — which,
   manual as it is, has a duplicate-object report, a review step and a DBA. **The new path has
   none of that yet.** Decide who approves a schema change and which identity executes it; it
   must not be the runtime identity (`aiServiceRuntime`).
0b. 🟠 **Record the D1b override.** `docs/architecture/design/12-ai-phase1-implementation-architecture.md`
   Part 2 recommends in-solution `PacEHR.AI.*` (.NET) and defers a standalone deployable to
   Phase 2/3, on the stated grounds that adding a deployable to an organisation with known
   CI/CD gaps compounds risk. **The decision is standalone Node anyway.** That is legitimate;
   it is not yet written down. Thirty minutes, and it stops the question being reopened at
   integration review.
1. **Replace the guard that SSDT used to provide (D33, R20).** Five `AI.*` tables key on
   `templetID`, `sectionID`, `fieldID` and `encounterID` — columns owned by `pacEHR_API`,
   which can rename them without ever seeing the AI repository. Under SSDT that failed the
   build. **Now nothing catches it until runtime, in the environment.** Put the column
   contract in writing and back it with a CI integration test against a restored database.
   Confirm `AI.agentRun` is the canonical name over `AI.runAudit` in the same pass.
2. **Re-point PEA-205 in grooming.** 3 points describes about a fifth of it. Take the a/b/c
   split in §1.
3. **Assign D4 (retention) to a named data owner with a date.** Longest lead time, purely
   non-engineering, and PEA-204 cannot complete without it.
4. **Open M1 (principals and grants) and M11 (a deployment path for `pacEHR_AI/`) as real
   stories.** Four of seven stories depend on M1; all seven depend on M11. ⚠️ **M2 no longer
   applies to this epic** — the AI DDL has left the SSDT project — but it remains a real gap
   for `pacEHR_API`, and PEA-205's coexisting legacy prompt path still lives behind it.
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
    (zod `.optional()`, **never `.default(0)`**), "no row means unvalidatable", **no float
    equality on `DECIMAL` bounds (D29/R16)**, **no module-scope or warm-instance memoisation
    on the description read (R17)**, and **a migration script is never edited after it
    merges** — the replacement for the `.sqlproj` manifest test now that registration is no
    longer the failure mode.
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
13. **Settle D32 — which prompt system serves a request — before PEA-205's read path is
    written.** D5 is closed as *coexist*, so there is no backfill and no cutover; what
    replaces them is a written precedence rule between `AI.prompt` and `AI.promptFragment`.
    Without one, behaviour depends on which code path served the request (risk R21).
    ⚠️ **And note what coexistence does not fix:** the 13 audited defects in the 25 live
    `AI.prompt` rows — four content-free prompts, two contradictory NA-handling rules — stay
    in production serving clinicians. They are no longer a migration problem; they are still
    a clinical-content problem, and they now have no forcing function at all.
14. **Name an owner for M5.** The prompt-versioning surface is required by doc 3777 §6.4 and
    absent from every roadmap. Concrete framing that gets an answer: *after PEA-205 ships,
    how does an author create v2 of a fragment, diff it, promote it, and roll it back?*
15. ⛔ **Withdrawn at Revision 7 — the interim .NET read path is off the table.** Revisions
    5–6 recommended pointing `AIPromptServices` at `AI.fieldConstraint` and
    `AI.fieldDescription` as a read-only first consumer. **Code separation rules that out.**
    The consequence is direct and should be said at grooming rather than discovered: **the
    new tables stay empty and unread until the Node service can read them**, so R3 has no
    mitigation. Either sequence M9 close behind the DDL, or accept the dead interval
    deliberately.
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
*constraints* to reconcile with (X9), not progress against this epic. `pacEHR_AI/src/core/` is a
*port source*, not a delivered increment of this epic.

### 10.1 The five releases

| R | Name | Contains | Points | Gated on | Exit criterion |
|---|---|---|---|---|---|
| **R0** | Unblock | D2/M1 principals, **D31** migration authority, **M11** deployment path, D24, X2+X8 rotation | ~13–21 | nothing | A migration reaches staging through an approved path, and three roles exist |
| **R1** | Schema & runner | ✅ M9 and M10 delivered 2026-10-01; **PEA-201 only** | **5–8** | R0 | `applyPending()` runs twice against staging, second run a no-op |
| **R2** | Audit spine | PEA-202, PEA-203 (tables + write paths) | ~10–13 | R1 | One real extraction writes one `agentRun` row and N `fieldOutcome` proposals |
| **R3** | Config tables | PEA-205a, PEA-206a, PEA-207a (tables + read paths) | ~9–13 | R1 (parallel with R2) | A request-time read returns per-mapping bounds and descriptions |
| **R4** | ⚠️ **Restated 2026-10-05.** ~~Grants claimed but absent~~ — there are no grants now, by decision. The DoD items are withdrawn rather than vacuous, which is honest. **What replaces the risk:** nothing at the server refuses an `UPDATE` or `DELETE` against `AI.agentRun`, so its append-only property is an application convention | Med | **High** | D2 |
| **R5** | Coexistence & retention | PEA-205b/c, M5, PEA-204 | ~13–21 | R4, D4, **D32**, D30/M3 | A written precedence rule is live and tested; purge runs and refuses when unset |

**R0 is the release most likely to be skipped and the one that cannot be.** Four of seven
stories have security DoD items that pass *vacuously* if the principals do not exist (R4), and
nothing reaches an environment without M11. Shipping R1 before R0 produces tables that are
correct, ungoverned and undeployable.

⚠️ **R5 shrank at Revision 7 and that is not all good news.** D5 = coexist removes the
backfill, the parity gate and the retirement of four procedures — roughly 8 points. What it
does not remove is the reason those existed: two prompt systems now run indefinitely with no
stated precedence (**D32**, risk **R21**), and the 13 audited defects in the live `AI.prompt`
rows stay in production with nothing forcing a decision about them.

### 10.2 What each story owes, in one line

| Story | DDL half — `pacEHR_AI/migrations/sql/` | Runtime half — `pacEHR_AI/src/` | Surface half — `PacEHR/`, `pacEHR_API/` | Total |
|---|---|---|---|---|
| PEA-201 | `0001` + schema reconciliation (X9) + CI scope check | `databaseMigrations.ts`, `applyPending()` | — | **5–8** |
| PEA-202 | `0002_ai_agentrun.sql` | `agentRunWriter.ts` + instrument the call path | — | 5–8 |
| PEA-203 | `0003_ai_fieldoutcome.sql` + filtered index | `fieldOutcomeRepository.ts` proposal path | decision path + M4 review UI | 5 (+8 UI) |
| PEA-204 | purge procedure | `fieldOutcomeRetention.ts` + fail-closed guard | timer host (D30) + M3 deploy | 2 (+3–5 host) |
| PEA-205 | `0004_ai_promptfragment.sql` | `promptFragmentRepository.ts` | **D32 precedence rule**, M5 | 6–13 |
| PEA-206 | `0005_ai_fieldconstraint.sql` (D24 first) | `fieldConstraintRepository.ts` (D29) | authoring UI (M6) | 3 (+5–8 UI) |
| PEA-207 | `0006_ai_fielddescription.sql` | `fieldDescriptionRepository.ts` | authoring UI (M6, merged with 206b) | 3 (+5 UI) |

**Read the three halves as three different readiness states, not three tasks.** Track A is
ready now. Track C is ready when M9 lands. Track D is ready when Product answers D7 — and
until then, **every Track D estimate is a placeholder, not a commitment.**

### 10.3 The four dates to set at grooming

Ordered by lead time, longest first. Each is non-engineering and each blocks a release.

1. **D4 — retention period** (Clinical + Compliance) → gates R5. Longest lead time in the
   epic and the only blocker on an otherwise ready 2-point story. Start it at grooming.
2. **D32 — prompt precedence between the two live systems** (Product + Architecture) → gates
   R5. Replaces the cutover that D5 = coexist removed. Until it is written down, which prompt
   a clinician gets depends on which code path served the request.
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
| A `pacEHR_API` release that renames a `Template.*` column | Caught by the CI integration test, or caught by a clinician (R20, D33) |
| `PASSED` count in `promptFragment.passedEvaluation` | Should be **zero** until Epic 10 exists. Any other number means D10 was defaulted and the gate is failing open |

The last row is the cheapest fraud detector in the epic: a single `SELECT COUNT(*)`.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_AI/src/core/` - ✅ **The delivered foundation (M9), commit `e86c54e`, 2026-10-01.** `settings.ts` (the only environment reader, zod v4), `database.ts` (the `database` singleton over `mssql` ^12.7.2, managed identity with a local SQL-login fallback, `execute(sql, params)` binding `@name` server-side), `llm.ts`, `auth.ts`, `errors.ts`, `logging.ts`, `app.ts`. 🔴 **No transaction primitive — PEA-202 needs one.** 🔴 **`execute()` returns `undefined` for DDL while typed as an array — PEA-201 must not read its result.**
- `pacEHR_AI/eslint.config.js` + `tests/unit/source-rules.test.ts` - ✅ The three invariants, enforced as lint rules rather than conventions: `process.env` confined to `src/core/settings.ts`; a log call must be `(fields, literalMessage)`; SQL built by template literal or concatenation at a call site is refused. Each rule ships with its planted violation. `tests/unit/repo.test.ts` additionally proves the tree imports with no environment, network or child process. Closes R18.
- `pacEHR_AI/package.json` - The seven pinned dependencies M10's Node allow-list must map.
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
