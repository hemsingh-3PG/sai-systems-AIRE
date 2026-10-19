# Epic 02 — TypeScript Implementation Flow

**Epic:** E2 — AI Schema Data Layer · **Stories:** PEA-201 … PEA-207
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-30
**Revision:** 6 — supersedes Revision 5 (2026-09-29)
**Status:** Final — implementation flow for a greenfield Node/TypeScript AI service
**Revision:** 7 (2026-09-30) — supersedes Revision 6. Snapshots under
`Epic-02/.revision-6-snapshot/` and `.revision-5-snapshot/`.
**Companion to:** [Grooming Rollup](solution-doc:5006) · [epic-02-data-layer (private copy)](solution-doc:4965)

> ⚠️ **What this document is.** The seven story specs say *what* to build and the Grooming
> Rollup says *what is unresolved*. This document says **in what order, in which files, with
> which primitives** — the build sequence for the Node service that owns the AI data layer.
>
> **What it is not:** it is not a new design. Every table, column, constraint, index, role,
> Gherkin scenario, REQ- ID and point estimate is carried unchanged from the reference corpus.
> Nothing here overrides the DDL.

> ✅ **Revision 7 — three owner decisions, and one of them moves the DDL.**
>
> **1. Greenfield Node, no prior implementation.** `Saisystems-PaaS/PacEHR/PacEHR_AI` was
> created 2026-09-30 and is empty. Earlier revisions described the foundation as unwritten
> (R5) and then as existing-and-portable (R6); **neither holds.** What exists is a
> *specification* — the reference backlog's foundation epic — and what must be built is a
> Node implementation of it. **Phase 0 is 16–26 points of greenfield build.**
>
> **2. `pacEHR_AI/` owns the `AI.*` DDL.** Revision 6 routed the migration scripts through
> `pacEHR_API`'s SSDT project and dated release folders. **Reversed.** `migrations/sql/` ships
> in the AI repository and applies through `MigrationRunner.applyPending()` — the epic's
> original design, and what code separation requires.
>
> **3. Existing AI code is not migrated.** `AIController`, `AIPromptServices`, `AI.prompt` and
> the Angular admin feature stay put. §6.3's interim .NET read path is **withdrawn**.

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
                                 │  Node AI service     │  ◀── pacEHR_AI/ — created
                                 │  owns AI decisioning │      2026-09-30, empty.
                                 │  AND the AI.* schema │      Greenfield build.
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
│   ├── core/                     ◀── M9: greenfield, against the foundation epic's spec
│   │   ├── settings.ts            zod — the only reader of process.env
│   │   ├── database.ts            node-mssql pool, managed identity, bound params
│   │   ├── databaseMigrations.ts  MigrationRunner.applyPending()   ◀── PEA-201
│   │   ├── llm.ts                 Azure OpenAI client
│   │   ├── errors.ts              typed errors
│   │   ├── logging.ts             structured, configured once
│   │   └── auth.ts                JWKS validation
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
>
> **`ai-service/` above is `pacEHR_AI/`** — the repository exists as of 2026-09-30 and is
> empty apart from a template README. Every path in this tree is to be created.
>
> ⚠️ **`migrations/` sits inside this repository, not in `pacEHR_API`'s SSDT project.** That is
> the Revision 7 reversal, and it is what makes `MigrationRunner` a real deliverable rather
> than a formality.

---

## 3. What gets built, in one table

Carried from the story specs so the flow is self-contained. **Left column is the approved
reference corpus; this table is what gets built.**

| Artefact | Built as | Note |
|---|---|---|
| `migrations/sql/0001_…0006_*.sql` | **plain, literal T-SQL** | `IF NOT EXISTS` guards, forward-only, never string-built. **In this repository**, not in `pacEHR_API`'s SSDT project |
| Migration runner | **src/core/databaseMigrations.ts**, `MigrationRunner.applyPending()` | Reads `migrations/sql/` in filename order, executes each script's full text through the `database` singleton |
| SQL driver | `mssql` npm (node-mssql / tedious) | Natively async — no thread-pool bridge, and no sync/async twin to disambiguate |
| Database access | **src/core/database.ts**, `database.execute()` | One entry point. No second connection, no second pool |
| Configuration | **src/core/settings.ts** + zod | ⚠️ See §4.2 — the one place the idiomatic form is dangerous |
| Typed models | zod schemas + `z.infer<>`, `z.enum([...])` | `z.enum` narrows the three vocabularies at compile time **and** validates at runtime |
| Foundation modules | **src/core/llm.ts / errors.ts / logging.ts / auth.ts** | M9 — all of it unwritten |
| Tests | vitest | `tests/unit` imports the whole tree with no environment, credentials or network; `tests/integration` reaches Azure |
| Scheduled work | Azure Functions **Node v4** | `app.timer('name', { schedule, handler })` from `@azure/functions`. **No `function.json`** |
| Repositories | **src/repositories/*Repository.ts** | camelCase files and methods; **SQL text and SCREAMING_SNAKE `_SQL` constants unchanged from the reference design** |
| Retention job | **src/jobs/fieldOutcomeRetention.ts**, `purge()` | PEA-204 |
| Migration entry point | `npm run migrate` → `node dist/core/databaseMigrations.js` | Forward-only; no down-migration exists |

**Roughly 70% of Epic 02 does not appear in this table at all**, because it is
runtime-neutral: all DDL, all Gherkin, all REQ- IDs, all reason codes, confidence bands,
plausibility bounds, HTTP contracts, retention policy, observability signals and the
`templetID` spelling. Those are the parts that were never in question.

⚠️ **Three invariants come from the engineering standard and must each be a test**, because
none of them is enforced by the language: `process.env` appears only in `src/core/settings.ts`;
no log call interpolates its message; importing any module opens no connection. They are cheap,
they guard PHI and configuration integrity, and their absence is invisible (risk R18).

---

## 4. The four primitives to get right first

### 4.1 Database access — node-mssql, one pool, one entry point

**src/core/database.ts** exposes a module-level `database` singleton with a single public
`execute()`. One pool per process: a caller that constructs its own pays for a second TLS
handshake and a second credential acquisition, and **no test catches it** — the cost lands in
production, under load, as latency no local measurement predicted.

Three properties are not negotiable, and each traces to a rule in the engineering standard:

| Property | Why |
|---|---|
| **Managed identity, not a key** | An API key is a local-development fallback and never a deployed path |
| **Every value binds server-side** | No value reaches SQL by interpolation — that is what makes injection impossible, and it applies to the `_SQL` constants verbatim |
| **Importing the module opens nothing** | `tests/unit` must import the whole tree with no environment and no credentials |

**One thing the Node runtime genuinely simplifies.** The reference design had to bridge a
synchronous driver into an async context and carried an explicit rule against publishing a
synchronous twin beside the async one. **node-mssql is natively async, so both the bridge and
the rule disappear.** Name the method `execute()`; there is no sync twin to disambiguate from.

🔴 **And one thing it makes harder, which PEA-202 needs.** The reference design never defined a
transaction primitive, and Epic 02 requires one — `AI.agentRun` and its `AI.fieldOutcome` rows
must land atomically or the audit trail lies. **Design it into `src/core/database.ts` as part
of M9**, not as an afterthought in PEA-202, and expose it as the only way to open a
transaction so no caller invents a second.

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

### 4.3 Schemas — zod as the zod replacement

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

`z.enum([...])` gives the same compile-time narrowing zod's `Literal` gave, and the
runtime parse gives the same boundary validation. **ABSENT must never collapse into
ABSTAINED** — the single strongest justification in the epic, and the reason these are three
values and not two.

### 4.4 Tests — vitest

One-for-one with the vitest suite. Story Gherkin scenarios map to `describe`/`it` names
unchanged, so a reviewer can diff the corpus against the suite by scenario title.
Integration tests need a real SQL Server (or Azure SQL dev database) because the migration
runner's whole contract is idempotency against live catalog state.

---

## 5. Build sequence

### Phase 0 — the foundation port (M9 + M10)

🟠 **This phase is still in nobody's backlog, but it is no longer a build.** Revision 5 scored
it ~29–33 points on the premise that nothing existed to start from. **`pacEHR_AI/` is the
thing that exists is the *specification*** — Epic 01 (PEA-101..106) and the engineering
standard define all six modules, their invariants and their tests. **Nothing is implemented.**
Phase 0 is a greenfield build against a detailed spec: known shape, known invariants, no
discovery.

| # | Work | Why it blocks | Est. |
|---|---|---|---|
| 0.1 | Repository skeleton — `package.json`, `tsconfig.json`, lint, CI | Nothing can be committed | 2 |
| 0.2 | **src/core/settings.ts** (zod) | Every story reads config | 2–3 |
| 0.3 | **src/core/database.ts** — node-mssql pool, managed identity, **and the transaction primitive** (§4.1) | Every story executes SQL; PEA-202 needs the transaction | 5 |
| 0.4 | **src/core/errors.ts**, **src/core/logging.ts** | Every DoD references structured logging | 2 |
| 0.5 | **src/core/auth.ts**, **src/core/llm.ts** | Not needed by Epic 02; needed by E3+ | 5 |
| 0.6 | vitest harness + integration database fixture | Every DoD has tests | 3 |
| **0.6a** | 🔴 **The three invariant tests** — `process.env` confined to `settings.ts`; no interpolated log message; no network at import | **These are the acceptance criteria for Phase 0.** Their absence is invisible: the service looks complete with both PHI guards gone (R18) | **2** |
| **0.7** | 🟠 **Node dependency allow-list** | Without it every import is unconstrained — and that is how an ORM, an `lru-cache` or a hand-rolled connection helper enters the data layer and voids the no-cache and least-privilege rules | 3–5 |
| **0.8** | 🔴 **Deployment path for the service *and its migrations*** (M11, D31) | The DDL now applies through `MigrationRunner`, not through `pacEHR_API`'s reviewed release harness. Who approves a schema change, and which identity executes it? **Not `aiServiceRuntime`** | 5–8 |

**Phase 0 total: ~24–33 points**, unowned. This is action 0 in the Grooming Rollup.

⚠️ **0.2 is the single most hazardous line in the build.** The specified behaviour for an
absent required setting is *raise at startup* — which is what makes PEA-204's retention guard
fail closed. The idiomatic zod translation a reviewer reaches for is `.default(0)`, and zero
days of retention means **purge everything**. Required form:
`z.coerce.number().int().positive().optional()`, with an explicit unset branch that deletes
nothing and logs the refusal.

### Phase 1 — the DDL half (can start today, in parallel with Phase 0)

**All seven stories split in two, and the halves have different readiness.** The DDL half is
language-neutral T-SQL against SSDT and is blocked only by longstanding infrastructure gaps:
M1 (schema principals, roles, grants — there are **zero** `CREATE SCHEMA` / `CREATE ROLE` /
`GRANT` statements across all **2,857** SQL files, re-verified 2026-09-30) and M2 (database
deployment pipeline).

⚠️ **One consequence of that zero worth stating plainly:** the `AI` schema is live in
production and `[AI].[prompt]` is registered in the `.sqlproj`, yet **no `CREATE SCHEMA [AI]`
exists in source control**. The schema was created out of band. PEA-201 is therefore not
purely additive — it is also the story that brings an existing production object under source
control for the first time (defect X9).

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

**Order matters here too.** Each repository class is specified in the reference corpus; write
it against the `_SQL` constants unchanged, because the SQL text is the part that was reviewed
against the DDL.

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

### 6.3 ⛔ The interim .NET read path — withdrawn at Revision 7

Epic 02's tables can land well before the Node service can read them. Tables that ship without
a consumer stay empty, and validators and audits over empty tables **silently pass** (risk R3).

Revisions 5–6 mitigated this by pointing the existing production `AIPromptServices` path at
`AI.fieldConstraint` and `AI.fieldDescription` as **read-only** inputs, so the tables proved
their value before the new service existed.

🔴 **That mitigation is withdrawn.** The owner decision is that everything belonging to the new
AI engine lives in `pacEHR_AI/`, and an interim reader would put AI reads back into
`pacEHR_API` — the exact coupling the separation exists to prevent.

**Say the consequence out loud rather than letting it be discovered:** **R3 now has no
mitigation.** The tables will be correct, empty and unread until the Node service can read
them, and nothing will go red in the meantime. Two honest responses, and the choice should be
made at grooming:

1. **Sequence M9 close behind the DDL**, so the dead interval is short by design.
2. **Accept a long dead interval deliberately**, and record in each table's DDL comment that it
   is expected to be empty until a stated milestone — so the next reader does not mistake an
   empty audit table for a broken one.

What does *not* change: the `AI.*` tables remain readable by anything with the right grant. The
decision here is about **who is allowed to**, not about what is technically possible.

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

The reference design is built on an agent runtime with a compiled state graph and a
five-hook middleware spine (`before_agent` → `before_model` → `wrap_model_call` →
`after_model` → `after_agent`). Epics 4–8 depend on that spine; **Epic 02 does not touch it
at all.**

Candidates when the time comes: **LangChain.js** (closest to the approved design, so the
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

0. 🔴 **Settle which architecture is being built (D1b).** Three are live:
   `docs/architecture/design/12-ai-phase1-implementation-architecture.md` Part 2 recommends
   **in-solution `PacEHR.AI.*` (.NET)** and defers a standalone service to Phase 2/3; the
   reference corpus specifies a standalone sidecar; this document says
   **standalone TypeScript**. The owner has selected TypeScript. Record that as a deliberate
   override of a written recommendation, with the reason — otherwise it is relitigated at
   integration, when it is expensive.
1. 🟠 **Commission Phase 0 (M9 + M10) as a port, with a named owner.** ~20–23 points, currently
   in nobody's backlog. Concrete framing, now that a source exists: *which team creates the
   repository skeleton, and who writes `src/core/{settings,database,llm,auth,errors,logging}.ts`
   **together with the three invariant tests**?* The acceptance criterion is the invariants,
   not the file count.
2. **Split all seven story estimates into DDL half and TypeScript half.** The first is ready;
   the second is blocked on step 1. A single number misrepresents both.
3. **Start the DDL half of PEA-201 now**, with M1 (principals and grants) landing before or
   with it.
4. **Put D4 (retention period) and D24 (one range band or two) in flight immediately.**
   Longest lead times, both non-engineering, both block a story's DDL or its DoD.
5. **Confirm with Architecture that the TypeScript service is the build target of record**
   (doc 3777 §14 still specifies an AI orchestrator, deliberately, **and `pacEHR_AI/` implements
   it**), and that `AI.agentRun` supersedes the architecture document's `AI.runAudit`.
6. **Answer M3** (how does `PacEHR.Functions.Process` reach its environments?), then D30.
7. **Decide (b) Azure OpenAI + Managed Identity** before **src/core/llm.ts** is written — it
   is a five-minute decision now and a rewrite later.
8. **Add the four Node-specific guards to the review checklist:** zod `.optional()` never
   `.default(0)`; no float equality on `DECIMAL` bounds; no module-scope or warm-instance
   memoisation on the description read; imports constrained to the allow-list.
9. ⛔ **The interim .NET read path is withdrawn** (§6.3). R3 now has no mitigation: the tables
   stay empty and unread until the Node service can read them. Either sequence M9 close behind
   the DDL, or accept the dead interval deliberately and record it in each table's DDL comment.
10. **Rotate the committed credentials (X2, X8)** — independent of this epic, and overdue.
    `pacEHR_API/PacEHR.API/appsettings.json` carries a live-looking OpenAI key, a SendGrid key
    and a Google Maps key on the same page; `PacEHR/src/app/core/services/open-ai.service.ts`
    "encrypts" the auth token with the literal `'SecretKey123'` at lines 247, 320 and 382.
11. **Bring the `AI` schema under source control (X9).** It exists in production and in no
    `.sql` file. PEA-201's `0001` is where that is fixed, and the fix must be written as a
    reconciliation — `IF NOT EXISTS` — not as a create that assumes absence.

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
