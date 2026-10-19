# Epic 02 — TypeScript Implementation Flow

**Epic:** E2 — AI Schema Data Layer · **Stories:** PEA-201 … PEA-207
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — implementation flow for a greenfield TypeScript/Node.js AI service
**Companion to:** [Grooming Rollup](solution-doc:5006) · [epic-02-data-layer (private copy)](solution-doc:4965)

> ⚠️ **What this document is.** The seven story specs say *what* to build and the Grooming
> Rollup says *what is unresolved*. This document says **in what order, in which files, with
> which primitives** — the build sequence for the TypeScript service that will own the AI
> data layer.
>
> **What it is not:** it is not a new design. Every table, column, constraint, index, role,
> Gherkin scenario, REQ- ID and point estimate is carried unchanged from the approved corpus.
> Nothing here overrides the DDL.
>
> **The team-space/official Python corpus is deliberately unmodified** and is the reference
> design. Where this document and doc 3777 §14 differ on language, this document states the
> build target and doc 3777 states the approved design intent.

---

## 1. Target topology

```
┌─────────────────┐    HTTPS     ┌──────────────────────┐
│  Angular 18 SPA │─────────────>│   .NET 8 Web API     │
│  (PacEHR/)      │              │   (pacEHR_API/)      │
│  ~1,271 TS files│              │   owns auth,         │
│  NgRx, TS 5.5.4 │<─────────────│   persistence, the   │
└─────────────────┘              │   existing contract  │
                                 └──────────┬───────────┘
                                            │ server-to-server
                                            │ (no browser ever
                                            │  reaches the AI tier)
                                            v
                                 ┌──────────────────────┐
                                 │ TypeScript AI service│  ◀── NEW. Does not exist.
                                 │ owns AI decisioning  │      Standalone repository.
                                 │ only                 │
                                 └───┬──────────────┬───┘
                                     │              │
                       node-mssql    │              │  HTTPS + Managed Identity
                       + Managed ID  │              │
                                     v              v
                        ┌────────────────────┐  ┌──────────────┐
                        │  Azure SQL         │  │ Azure OpenAI │
                        │  AI.* tables       │  │              │
                        │  Template.* (read) │  └──────────────┘
                        └────────────────────┘
```

**Four properties of this topology that constrain everything below:**

1. **The .NET API keeps owning auth and persistence.** That division comes from doc 3777 and
   is unchanged by the language switch. The AI service owns AI decisioning only.
2. **The browser never reaches the AI service.** Today the Angular SPA calls OpenAI-adjacent
   endpoints and asserts its own token counts (defect X1). The new tier is server-to-server,
   which is what makes PEA-202's audit row trustworthy for the first time.
3. **The AI service talks to Azure SQL directly**, with its own least-privileged principal.
   This is why PEA-201's three roles exist and why they are not optional.
4. **Azure OpenAI, not the OpenAI public API.** The current C# path
   (`pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`) calls OpenAI directly with a
   hardcoded `model="gpt-4o"` and a key read from configuration. For a PHI workload that is
   the wrong end state — see §8 decision (b).

---

## 2. Repository layout

The service is a **new standalone repository**. Nothing in `PacEHR/` or `pacEHR_API/` is
modified by Epic 02's TypeScript half, with one deliberate exception (§6.3).

```
ai-service/                        ◀── new repository, name TBD
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── .eslintrc / biome.json
├── Dockerfile                     (or Functions host — see §7)
├── migrations/
│   └── sql/
│       ├── 0001_create_ai_schema.sql
│       ├── 0002_ai_agentrun.sql
│       ├── 0003_ai_fieldoutcome.sql
│       ├── 0004_ai_promptfragment.sql
│       ├── 0005_ai_fieldconstraint.sql
│       └── 0006_ai_fielddescription.sql        ◀── PLAIN T-SQL. Byte-identical to the
│                                                    approved corpus. Do not "port" these.
├── src/
│   ├── core/
│   │   ├── settings.ts            zod-validated config (M9)
│   │   ├── database.ts            node-mssql pool + Transaction (M9)
│   │   ├── databaseMigrations.ts  MigrationRunner.applyPending()   ◀── PEA-201
│   │   ├── llm.ts                 Azure OpenAI client (M9)
│   │   ├── errors.ts              (M9)
│   │   ├── logging.ts             (M9)
│   │   └── auth.ts                (M9)
│   ├── schemas/
│   │   ├── agentRun.ts            zod + z.infer<>
│   │   ├── fieldOutcome.ts        z.enum([...]) for the three vocabularies
│   │   ├── promptFragment.ts
│   │   ├── fieldConstraint.ts
│   │   └── fieldDescription.ts
│   ├── repositories/
│   │   ├── agentRunWriter.ts              ◀── PEA-202 (class name survives)
│   │   ├── fieldOutcomeRepository.ts      ◀── PEA-203
│   │   ├── promptFragmentRepository.ts    ◀── PEA-205
│   │   ├── fieldConstraintRepository.ts   ◀── PEA-206
│   │   └── fieldDescriptionRepository.ts  ◀── PEA-207
│   └── jobs/
│       └── fieldOutcomeRetention.ts       ◀── PEA-204 (class + purge() survive)
└── tests/
    ├── unit/*.test.ts
    └── integration/*.test.ts
```

Concretely: **migrations/sql/0001_create_ai_schema.sql**, **src/core/settings.ts**,
**src/core/database.ts**, **src/core/databaseMigrations.ts**, **src/repositories/agentRunWriter.ts**,
**src/jobs/fieldOutcomeRetention.ts**, **tests/integration/databaseMigrations.test.ts**.

> None of these paths exist yet. They are the target layout, not a description of the
> repository. Path-verification warnings against them are expected and correct.

---

## 3. The translation, in one table

Carried from the story specs so the flow is self-contained. **Left column is the approved
Python corpus; right column is what gets built.**

| Python (reference design) | TypeScript (build target) | Note |
|---|---|---|
| `migrations/sql/0001_…0006_*.sql` | **migrations/sql/0001_…0006_*.sql** | **Unchanged.** Plain T-SQL, `IF NOT EXISTS` guards, forward-only |
| **core/database_migrations.py**, `MigrationRunner.apply_pending()` | **src/core/databaseMigrations.ts**, `MigrationRunner.applyPending()` | Class name survives; method camelCased |
| `mssql_python` (sync PEP 249) + `asyncio.to_thread` | `mssql` npm (node-mssql / tedious) | **Natively async — the thread-pool wrapper disappears.** See §4.1 |
| **core/database.py**, `aexecute` | **src/core/database.ts**, `database.execute()` | No `a`-prefix needed; there is no sync twin to disambiguate from |
| **core/settings.py** + pydantic-settings | **src/core/settings.ts** + zod | See §4.2 — the one place the idiomatic translation is dangerous |
| Pydantic models, `Literal[...]` | zod schemas + `z.infer<>`, `z.enum([...])` | Same compile-time narrowing |
| **core/llm.py** / **errors.py** / **logging.py** / **auth.py** | **src/core/llm.ts** / **errors.ts** / **logging.ts** / **auth.ts** | M9 — all of it unwritten |
| pytest | vitest | Same test names, same Gherkin mapping |
| Azure Functions Python v2 | Azure Functions **Node v4** | `app.timer('name', { schedule, handler })` from `@azure/functions`. **No `function.json`** |
| `core/*_repository.py` | **src/repositories/*Repository.ts** | camelCase file + method names |
| `FieldOutcomeRetentionPurger` | **src/jobs/fieldOutcomeRetention.ts** | Class name and `purge()` both survive |
| `python -m core.database_migrations` | `npm run migrate` → `node dist/core/databaseMigrations.js` | Same forward-only entry point |
| snake_case identifiers | camelCase identifiers | **SQL column names and SCREAMING_SNAKE SQL constants are NOT renamed** |

**Roughly 70% of Epic 02 does not appear in this table at all**, because it is
language-neutral: all DDL, all Gherkin, all REQ- IDs, all reason codes, confidence bands,
plausibility bounds, HTTP contracts, retention policy, observability signals and the
`templetID` spelling. The left column is here so a reviewer reading the reference corpus can
find the corresponding file on this side — not as a migration record.

---

## 4. The four primitives to get right first

### 4.1 Database access — node-mssql, and the wrapper that disappears

The Python design carried a standing hazard: `mssql_python` is a synchronous PEP 249 driver,
so every call had to go through `asyncio.to_thread`, and the corpus carried an explicit rule
— *never publish a sync `execute` beside `aexecute`* — because a single accidental sync call
would block the event loop.

**node-mssql is natively async. That hazard, and the rule guarding it, both disappear.** This
is the one place where the retarget is a genuine simplification rather than a lateral move.

It also hands Epic 02 something the Python plan had to defer: **a first-class `Transaction`
object**. Gap 17 in the grooming corpus is "no transaction primitive". node-mssql's
`new sql.Transaction(pool)` with `begin()` / `commit()` / `rollback()` closes it, which
matters for PEA-202 → PEA-203, where an `AI.agentRun` row and its `AI.fieldOutcome` children
must land atomically or not at all.

```ts
// src/core/database.ts — shape only
const pool = await new sql.ConnectionPool({
  server, database,
  authentication: { type: 'azure-active-directory-msi-app-service' },  // §8(b)
  options: { encrypt: true },
}).connect();

export async function execute<T>(text: string, params: Params): Promise<T[]> { /* … */ }
export function transaction(): sql.Transaction { return new sql.Transaction(pool); }
```

**Connection story:** node-mssql supports Azure AD / Managed Identity authentication
directly. Use it. The existing .NET path resolves an API key from configuration and a
live-looking OpenAI key is committed in `pacEHR_API/PacEHR.API/appsettings.json` (defect X2)
— the new service should not inherit that pattern for either SQL or the model endpoint.

🔴 **New hazard — `DECIMAL` becomes a JS number.** node-mssql surfaces `DECIMAL(6,2)` as a
JavaScript `number`, i.e. an IEEE-754 binary double. PEA-206 deliberately chose
`DECIMAL(6,2)` over `FLOAT` to avoid exactly this imprecision, and the driver partly undoes
that choice for any comparison done in process. **Mitigation: push range comparisons into
SQL, or compare with an explicit tolerance — never `===` or a bare `>` at a boundary.**
Tracked as D29 / R16.

### 4.2 Configuration — zod, and the one default that must never be written

The retention setting is the highest-consequence line of configuration in the epic.

```ts
// src/core/settings.ts
AI_FIELD_OUTCOME_RETENTION_DAYS: z.coerce.number().int().positive().optional(),
//                                                            ^^^^^^^^^^^
// 🔴 NEVER .default(0)
```

**Why this is the sharpest edge in the whole retarget.** The rule is *fail closed*: if the
setting is unset, the purge deletes **nothing** and logs a refusal naming the setting. Unset
is not zero — unset means a compliance decision has not been made (D4), and zero means
"retain nothing, purge everything".

Both languages invert this rule *idiomatically*. In .NET, `GetValue<int>` returns `0` for a
missing key. In TypeScript, `.default(0)` is what a reviewer reaches for without thinking.
Either one silently converts an unmade decision into a full-table purge of derived clinical
content. Risk R2, impact Critical, and it is **two characters of code**.

Env key casing `AI_FIELD_OUTCOME_RETENTION_DAYS` is carried verbatim from the corpus.

### 4.3 Schemas — zod as the Pydantic replacement

The three vocabularies stay lexically distinct on purpose (run-level `outcome`, field-level
`verdict`, field-level `proposedStatus`) — overlapping words across grains is how audit
queries end up quietly wrong.

```ts
// src/schemas/fieldOutcome.ts
export const proposedStatus     = z.enum(['FOUND', 'ABSENT', 'ABSTAINED']);
export const proposedConfidence = z.enum(['HIGH', 'MEDIUM', 'LOW']);
export const verdict            = z.enum(['ACCEPT', 'REVIEW', 'BLOCK']);
export type FieldOutcome = z.infer<typeof fieldOutcomeSchema>;
```

`z.enum([...])` gives the same compile-time narrowing Pydantic's `Literal` gave, and the
runtime parse gives the same boundary validation. **ABSENT must never collapse into
ABSTAINED** — the single strongest justification in the epic, and the reason these are three
values and not two.

### 4.4 Tests — vitest

One-for-one with the pytest suite. Story Gherkin scenarios map to `describe`/`it` names
unchanged, so a reviewer can diff the corpus against the suite by scenario title.
Integration tests need a real SQL Server (or Azure SQL dev database) because the migration
runner's whole contract is idempotency against live catalog state.

---

## 5. Build sequence

### Phase 0 — the foundation nobody owns yet (M9 + M10)

🔴 **This phase does not exist in any backlog and is the largest single piece of unowned work
in the programme.** The reference Python design had Epic 01 (PEA-101..106, 22 points) covering
exactly this. For the Node service there is **no repository, no skeleton, no pipeline and no backlog**
— verified: no `nest-cli.json`, no `serverless.yml`, no backend `package.json` anywhere in
either repository. The only TypeScript present is the Angular SPA.

| # | Work | Why it blocks | Est. |
|---|---|---|---|
| 0.1 | Create the repository; `package.json`, `tsconfig.json`, lint, CI | Nothing can be committed | 2 |
| 0.2 | **src/core/settings.ts** (zod) | Every story reads config | 3 |
| 0.3 | **src/core/database.ts** (node-mssql pool + `Transaction`) | Every story executes SQL | 5 |
| 0.4 | **src/core/errors.ts**, **src/core/logging.ts** | Every DoD references structured logging | 3 |
| 0.5 | **src/core/auth.ts**, **src/core/llm.ts** (Azure OpenAI) | Not needed by Epic 02, needed by E3+ | 5 |
| 0.6 | vitest harness + integration database fixture | Every DoD has tests | 3 |
| **0.7** | 🔴 **Node dependency allow-list** — the document that replaces [00-langchain-api-truth.md](solution-doc:5091) | Doc 5091 pins exact Python library APIs and forbids everything outside them. It governs Python only. Without a Node equivalent, every import is unconstrained — and that is how an ORM, an `lru-cache`, or a hand-rolled connection helper enters the data layer and voids the no-cache and least-privilege rules | 3–5 |
| 0.8 | Container or Functions packaging + deployment pipeline | See §7 and M3 | 5+ |

**Phase 0 total: ~29–33 points, unowned.** This is action 0 in the Grooming Rollup and the
first thing to put in front of Architecture.

### Phase 1 — the DDL half (can start today, in parallel with Phase 0)

**All seven stories split in two, and the halves have different readiness.** The DDL half is
language-neutral T-SQL against SSDT and is blocked only by longstanding infrastructure gaps:
M1 (schema principals, roles, grants — there are **zero** `CREATE SCHEMA` / `CREATE ROLE` /
`GRANT` statements across all 2,834 SQL files) and M2 (database deployment pipeline).

```
PEA-201 DDL (AI schema + 0001)
   ├──> PEA-202 DDL (AI.agentRun)
   │        └──> PEA-203 DDL (AI.fieldOutcome — FK runID)
   ├──> PEA-205 DDL (AI.promptFragment)
   ├──> PEA-206 DDL (AI.fieldConstraint — settle D24/D25 first)
   └──> PEA-207 DDL (AI.fieldDescription)
```

⚠️ **Estimating or committing a story as a single unit right now overstates readiness.**
Split the points: DDL half ready, repository half blocked on Phase 0.

### Phase 2 — the TypeScript half (blocked on Phase 0)

```
Phase 0 complete
   └──> PEA-201 runner half — src/core/databaseMigrations.ts, npm run migrate
            ├──> PEA-202 — src/repositories/agentRunWriter.ts
            │        └──> PEA-203 — src/repositories/fieldOutcomeRepository.ts
            │                 └──> PEA-204 — src/jobs/fieldOutcomeRetention.ts
            │                          (+ D4 retention decision, D30 host, M3 deploy)
            ├──> PEA-205 — src/repositories/promptFragmentRepository.ts  ──> M7 cutover
            ├──> PEA-206 — src/repositories/fieldConstraintRepository.ts (D29) ─┐
            └──> PEA-207 — src/repositories/fieldDescriptionRepository.ts ──────┴──> M6
```

**Ordering notes:**

- **PEA-201 gates everything.** Both halves. Nothing else can be written until the schema and
  the migration mechanism exist.
- **PEA-203 depends on PEA-202** for a real foreign key (`runID` → `AI.agentRun`). Same
  release, or guarded scripts. The node-mssql `Transaction` primitive is what makes the
  two-row write atomic.
- **PEA-205, 206 and 207 are independent** of each other and of the 202/203/204 chain. Once
  201 lands they run in parallel — the widest point in the epic.
- **PEA-204 is last and has the longest lead time on its blocker.** D4 is a compliance
  decision, not engineering. Start it now.
- **D4 and D24 should be in flight during Phase 0**, not started when the story is picked up.

---

## 6. Consequences of the topology

### 6.1 Three roles, unchanged

`aiServiceRuntime` (SELECT + INSERT on `AI.agentRun`; SELECT-only elsewhere),
`aiPromptAdmin`, `aiTemplateAdmin`. The runtime principal is the one the TypeScript service
connects as, and its narrow grant is the reason PEA-202's writer and PEA-203's reader are
separate classes rather than one repository with both verbs.

⚠️ **Grants claimed but absent (R4).** DoD items asserting least privilege pass *vacuously*
when the principals do not exist. M1 must land before or with PEA-201 — retrofitting grants
onto five existing tables is more work than granting on creation.

### 6.2 Caching — the rule is unchanged, the review checklist is not

REQ-03-06 forbids caching the description read. One indexed range seek; the correct
optimisation is none. Doc 3777 §12's tracing records `prompt_hash` per call, and a cached
description makes that trace stop matching what was actually sent.

🔴 **The .NET review checklist does not catch the Node violations.** Reviewers looking for
`IMemoryCache` and `AddSingleton` will miss both of the ways this rule actually gets broken
in Node, because both read as completely idiomatic:

1. **Module-scope `const` / `Map` memoisation.** A module-level `const cache = new Map()`
   persists for the process lifetime. This is normal Node style and it is a cache.
2. **Azure Functions v4 warm-instance state.** Anything outside the handler survives between
   invocations on a warm instance. Same effect, less visible.
3. `lru-cache`, `node-cache`, or a memoised class method — the obvious ones.

**Add all three to the DoD checklist**, and note that M10's allow-list is what gives the rule
something enforceable to bind to. Risk R17.

### 6.3 The interim .NET read path — a deliberate first consumer

Epic 02's tables can land months before the TypeScript service exists. Tables that ship
without a consumer stay empty, and validators and audits over empty tables **silently pass**
(risk R3, and R6 at epic scale).

**Mitigation:** point the existing production path
(`pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` via
`pacEHR_API/PacEHR.API/Controllers/AIController.cs`) at `AI.fieldConstraint` and
`AI.fieldDescription` as **read-only** inputs.

Frame this correctly: **a deliberate first consumer, not a fallback.** It proves the tables
carry real value, it exercises the grants, and it makes the DDL's correctness observable
before any TypeScript is written. Two conditions:

- **Read-only.** The write-ownership boundary (D17) must never be crossed by accident.
- **Declared and time-boxed**, so it does not quietly become the permanent architecture.

### 6.4 The existing C# AI engine is not reused

`AIPromptServices.cs` (365 lines) is the current AI implementation — SSE streaming through
`AIController`, `model="gpt-4o"` hardcoded at four call sites, `temperature=0`, no Key Vault,
no managed identity. **Completely greenfield was the owner's decision: none of this logic is
ported.** It survives only as the interim *reader* in §6.3, and as the thing that eventually
becomes a thin proxy per doc 3777.

---

## 7. Hosting the purge job

PEA-204 needs a timer. There are two options and they have different costs.

| | Existing .NET host | New Node host |
|---|---|---|
| **What** | `pacEHR_API/PacEHR.Functions.Process` — Azure Functions v4, net8.0, isolated worker, **five live timer jobs** | New Functions v4 Node app, `app.timer('purgeFieldOutcomes', { schedule, handler })` from `@azure/functions`, no `function.json` |
| **Pro** | Already running in production | Purge logic lives with the repository it calls; one language for the AI tier |
| **Con** | 🔴 **No pipeline in the repository deploys it** (M3). Five timers run from a project with no visible deployment path. Also splits the AI tier across two languages | A second Functions host to provision, secure and deploy |
| **Also** | `pacEHR_API/PacEHR.Functions.Process/Program.cs` registers the procedures context **Scoped** — worth checking against a timer's lifetime | Inherits **src/core/settings.ts**, so the fail-closed retention rule is enforced in one place |

**Recommendation: the new Node host**, on the grounds that the purge must read
`AI.fieldOutcome` through the same settings and logging as everything else, and the
fail-closed rule should have exactly one implementation. But **M3 must be answered either
way** — five production timers with no deployment path is worth knowing regardless of this
epic. Tracked as D30.

---

## 8. Decisions that need the owner

### (a) Agent framework for later epics — **not needed for Epic 02**

The Python design is built on LangChain's `create_agent` / `CompiledStateGraph` and a
five-hook middleware spine (`before_agent` → `before_model` → `wrap_model_call` →
`after_model` → `after_agent`). Epics 4–8 depend on that spine; **Epic 02 does not touch it
at all.**

Candidates when the time comes: **LangChainJS** (closest to the approved design, so the
corpus's hook names survive), **Vercel AI SDK** (lighter, no graph abstraction, more manual
orchestration), **Mastra** (opinionated, closest to a hosted agent runtime).

**Do not decide this to unblock Epic 02** — it is not a blocker, and deciding it early on
thin information is how the middleware list ended up specified four incompatible ways in the
first place. Note that the corpus's middleware spine is one of the five carried conflicts.

### (b) Azure OpenAI + Managed Identity, or the existing direct-OpenAI + API key?

**Strong recommendation: Azure OpenAI with Managed Identity**, for a PHI workload:

- The existing pattern has a live-looking key committed to the repository (X2) — the failure
  mode is not hypothetical.
- Managed Identity removes the credential entirely, for both the model endpoint and SQL
  (node-mssql supports AAD/MSI natively).
- Doc 3777's Azure topology already assumes Azure OpenAI.
- PHI data residency and the enterprise agreement are materially different between the two.

**Cost of the recommendation:** a deployment per model, and `modelDeployment` in
`AI.agentRun` starts meaning a deployment name rather than a model name — which the column
already anticipates.

### (c) Purge job host — see §7. Recommendation: new Node host, but answer M3 first.

### (d) Resolve or carry forward the five conflicts?

Carried in the corpus, **none caused by the language choice and none fixed by it**:

1. **Encounter-form write ownership** — REQ-02-07 vs Epic 9's chart write-back (Gap 1).
2. **Reason-code enum incomplete** — PEA-1004 unpublished.
3. **A guard-blocked run cannot write its own audit row** (Gap 3) — the `CK_agentRun_reachedModel`
   and `CK_agentRun_blockedHasReason` checks are correct; the call path that would satisfy
   them on a pre-model block does not exist.
4. **The middleware list is specified four incompatible ways.**
5. **PHI de-masking has no call site** (and Gap 10: PHI with no erasure path).

Plus the narrower ones: outcome vocabulary split (Gap 9), missing `templetID`/`configVersion`
(Gap 12), auto-commit never setting `acceptedValue` (Gap 25).

**Recommendation: settle #3 and #5 now, carry the rest.** #3 is a DDL-adjacent question and
Epic 02 is the last cheap moment to answer it — once `AI.agentRun` ships, a fix is a
migration. #5 is a PHI question and those do not get cheaper. #1, #2 and #4 belong to later
epics and a greenfield service means nothing has been built against the wrong answer yet.

---

## 9. What to do first, in order

1. 🔴 **Commission Phase 0 (M9 + M10) as its own epic with a named owner.** ~29–33 points,
   currently in nobody's backlog. Concrete framing: *which team creates the repository, who
   writes **src/core/settings.ts** and **src/core/database.ts**, and who authors the Node
   allow-list that replaces [doc 5091](solution-doc:5091)?*
2. **Split all seven story estimates into DDL half and TypeScript half.** The first is ready;
   the second is blocked on step 1. A single number misrepresents both.
3. **Start the DDL half of PEA-201 now**, with M1 (principals and grants) landing before or
   with it.
4. **Put D4 (retention period) and D24 (one range band or two) in flight immediately.**
   Longest lead times, both non-engineering, both block a story's DDL or its DoD.
5. **Confirm with Architecture that the TypeScript service is the build target of record**
   (doc 3777 §14 still specifies a Python sidecar, deliberately), and that `AI.agentRun`
   supersedes the architecture document's `AI.runAudit`.
6. **Answer M3** (how does `PacEHR.Functions.Process` reach its environments?), then D30.
7. **Decide (b) Azure OpenAI + Managed Identity** before **src/core/llm.ts** is written — it
   is a five-minute decision now and a rewrite later.
8. **Add the four Node-specific guards to the review checklist:** zod `.optional()` never
   `.default(0)`; no float equality on `DECIMAL` bounds; no module-scope or warm-instance
   memoisation on the description read; imports constrained to the allow-list.
9. **Declare the interim .NET read path** (§6.3) as an intentional, read-only, time-boxed
   first consumer.
10. **Rotate the committed key (X2)** — independent of this epic, and overdue.

---

## 10. Invariants — do not change these

Listed so a reviewer can check a PR against them without re-reading seven specs.

**All DDL, verbatim:**

- `AI.agentRun` — `runID BIGINT IDENTITY` PK, `promptHash VARCHAR(64)`, `modelDeployment`,
  `reasonCode`, `templetID`, `configVersion`, CHECKs `CK_agentRun_outcome` /
  `CK_agentRun_reachedModel` / `CK_agentRun_blockedHasReason`, `IX_agentRun_encounter`
- `AI.fieldOutcome` — `outcomeID BIGINT IDENTITY` PK, `runID` FK, `proposedStatus`
  FOUND/ABSENT/ABSTAINED, `proposedConfidence` HIGH/MEDIUM/LOW, `verdict`
  ACCEPT/REVIEW/BLOCK, filtered index on `decidedAtUtc IS NULL`
- `AI.promptFragment` — `fragmentID INT IDENTITY` PK, UNIQUE(`kind`,`scope`,`accountId`,`version`),
  `isActive BIT DEFAULT 0`, `passedEvaluation DEFAULT 'PENDING_EVAL'` (four values, never a BIT)
- `AI.fieldConstraint` — `constraintID INT IDENTITY` PK, UQ UNIQUE(`templetID`,`sectionID`,`fieldID`),
  `DECIMAL(6,2)` bounds, two range CHECKs, `sourceProse`
- `AI.fieldDescription` — composite clustered PK `templetID`+`sectionID`+`fieldID`, **no
  surrogate**, `NVARCHAR(1000) NOT NULL`, **no** name/type/unit/isActive/version columns

**House form and spelling:**

- `templetID` stays misspelled. So do `templeteId`, `encounterTempleteID`, `abnormalOPerator`.
  Renames break string-bound procedure calls at **runtime**, not compile time (R7).
- `VARCHAR(64)` over `CHAR(64)`. `DECIMAL(6,2)` over `FLOAT`. `DEFAULT (getutcdate())` over
  `SYSUTCDATETIME()`. Named `CK_<table>_<col>` with a pre-normalised OR chain, not `IN (...)`.
- `decidedByProviderID` casing, locked through SQL → C# → TypeScript.
- The pipe-delimited unit string `'kg|lb'` is stored verbatim; interpretation is Epic 6's.

**Behavioural:**

- `AI_FIELD_OUTCOME_RETENTION_DAYS` — env key casing exact; **unset ≠ zero**; unset deletes
  nothing and logs a refusal naming the setting.
- ABSENT is a successful extraction; ABSTAINED is a request for a human. Never collapse them.
- Confidence is categorical, never numeric — `temperature=0`, no logprobs, so a number would
  be one the model invented about itself.
- `name` / `type` / `unit` stay out of `AI.fieldDescription`; they are live columns on
  `Template.fields` and copying them creates a second source of truth.
- Three vocabularies at two grains stay lexically distinct.
- Per-mapping grain for constraints and descriptions — one `displayName` edit was measured
  reaching **179 of 458 templates**.

**Documentation:**

- Every story's `## Referenced Paths` section stays structurally intact, and **never gains a
  TypeScript-repository path** — those files do not exist and would break drift detection.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - The existing 365-line C# AI engine that is explicitly NOT reused; source of the hardcoded model, `temperature = 0` and the credential pattern the new service must not inherit (§6.4).
- `pacEHR_API/PacEHR.API/Controllers/AIController.cs` - The SSE entry point that becomes a thin proxy, and the host of the interim read path in §6.3.
- `pacEHR_API/PacEHR.API/appsettings.json` - Committed live-looking credential (defect X2); the reason §8(b) recommends Managed Identity.
- `pacEHR_API/PacEHR.Functions.Process/Program.cs` - The existing Functions v4 host with five live timers and a Scoped procedures context; one of the two options in §7.
- `pacEHR_API/CLAUDE.md` - The binding engineering rules the DDL half must satisfy — two-artefact rule, `.sqlproj` registration, never-correct-spellings, datatype chain.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - The registration manifest; unregistered objects are silently never deployed (R5).
- `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` - The shipped `AI.prompt` table, evidence that the `AI` schema already exists and that PEA-205 replaces a live feature.

### Medium Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11, the `DEFAULT (getutcdate())` house form carried as an invariant in §10.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14, the named-CHECK OR-chain house style carried as an invariant in §10.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` - The `DECIMAL (6, 2)` precedent behind PEA-206 and the §4.1 JS-number hazard.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - The overlapping AI prompt columns that make the `AI.fieldDescription` precedence decision (D6) real.
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The string-bound procedure layer that makes rule-8 renames a runtime failure, cited as an invariant.
- `PacEHR/src/app/core/services/open-ai.service.ts` - Client-asserted token usage (defect X1); the reason §1 property 2 matters for PEA-202's audit row.
- `pacEHR_API/pacEHR/Controllers/AIController.cs` - The second AIController; confirms which project hosts the live AI surface.

### Low Relevance
- `pacEHR_API/pipelines/` - Searched and confirmed to contain neither database nor Functions deployment (M2, M3).
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` - The per-mapping grain shared by PEA-203, 206 and 207.
