# PEA-204 Tech Spec — AI.fieldOutcome Retention Purge

**Epic:** E2 — Data Layer · **Story:** PEA-204 · **Phase:** 1
**Depends on:** PEA-203 · **Satisfies:** REQ-02-08
**Epic estimate:** 2 points · **Audited estimate:** 2 points for the mechanism — **but it cannot be completed** until open question B7 is answered (see §1 Finding 1)
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — audited against the live codebase and the Epic corpus, evidence-backed, ready for grooming
**Build target:** TypeScript/Node.js

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

> **Build target.** The AI engine is a **TypeScript/Node.js** service in a
> new, separate repository (not yet created, not ingested into this solution), **ported from
> the existing Python service `pacEHR_AI/`**. The
> runtime chain is: Angular frontend → .NET Web API → TypeScript AI service → Azure OpenAI.
> All implementation guidance below is expressed in TypeScript terms. **The retention
> behaviour, acceptance criteria, purge predicate, fail-closed-on-missing-config design and
> all Gherkin scenarios are language-neutral and unaffected.** The scheduling host is the
> **Azure Functions Node.js v4 programming model** (`app.timer(...)` from `@azure/functions`)
> — or an Azure DevOps pipeline step as the stated alternative. The team-space Python corpus
> is the reference design and is unmodified.

> **Read this first.** This story is
> small and well-designed, and it is the only story in Epic 02 whose *blocker is not
> technical*. The retention period is unknown, nobody has been asked, and no amount of
> engineering will produce the number. §7 action 1 is the whole story.
>
> Note that this repository **does** have a working scheduled-job host — see Finding 2.
>
> **B7 is confirmed open across three independent documents, and the exposure it leaves is
> larger than it first appears.**
> [epic-02-data-layer.md](solution-doc:5077) carries the setting forward unchanged —
> `ai_field_outcome_retention_days: int | None = None`, failing closed — and explicitly
> records B7 as **still open and unowned**. [00-source-index.md](solution-doc:5092) lists it
> in Table B alongside B9 as a question with no owner. And [GAPS.md](solution-doc:5089)
> Gap 10 names the consequence directly: `proposedValue`, `acceptedValue` and `foundIn` are
> **PHI with no erasure path**. Three documents, three authors, one unanswered question —
> see Findings 12 and 13.
>
> The fail-closed design is correct and this spec continues to defend it. But note what
> "correct" means in practice here: **the purge never runs.** A safety mechanism that is
> perfectly implemented and permanently dormant accrues exactly the same PHI exposure as no
> mechanism at all. The difference is only that someone can point at it.

---

## 1. Findings — what the audit changed

| # | Finding | Severity | Effect on this story |
|---|---------|----------|----------------------|
| 1 | **The retention number does not exist.** Neither primary source states one | 🔴 blocker | The story's DoD cannot be satisfied; the *mechanism* can |
| 2 | **CORRECTION: a scheduled-job host DOES exist** — 5 live Azure Functions timer triggers | ✅ major positive | Epic 11 is far less work than assumed; a purge job has a home today |
| 3 | **But that Functions project is deployed by no pipeline** | 🔴 blocker | The host exists and builds, and nothing ships it |
| 4 | **Hard `DELETE` has no retention precedent** anywhere in 2,834 SQL files | 🟠 high | This would be the first destructive retention job in the product |
| 5 | The codebase-wide convention is **soft delete** (`isDeleted BIT`) | 🟠 high | A hard DELETE contradicts house practice; §3.3 argues both sides |
| 6 | **The AI engine build target is TypeScript/Node.js (owner decision).** The original epic referenced Python modules (`core/settings.py`, `core/field_outcome_retention.py`) targeting a planned Python sidecar. Hem has confirmed the AI engine will be built in TypeScript in a new, separate repository. This document retargets accordingly — see §1 Finding 6 (updated). | 🟠 high | TypeScript AI service replaces Python sidecar — see §1 Finding 6 (updated) |
| 7 | **`pydantic_settings` is replaced by zod-validated config** in `src/core/settings.ts`. The TypeScript equivalent trap (a numeric default of `0`) is equally real — see §1 Finding 7 (updated) | 🟡 medium | The fail-closed guard must be built correctly in TypeScript — §3.2 |
| 8 | Fail-closed design is **correct and host-independent** — it must survive in whichever language is chosen | ✅ endorsed | The one piece of this story to defend in review |
| 9 | **Purge-host ambiguity** — the AI engine is now TypeScript/Node.js (owner decision), but a retention purge is database maintenance, not AI decisioning — the .NET Functions timer host may still be the right home. The alternative is an Azure Functions Node.js v4 timer trigger in the new TypeScript repo. | 🟠 high | See §1 Finding 9 (updated) |
| 10 | **Q5 / B7 ownership gap** — doc [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §16 Q5 asks the identical retention question, also unanswered — two independent documents weeks apart both stalled on it | 🔴 blocker | Needs a named owner and a date — §1 Finding 10 (new) |
| 11 | **Trace-store scope gap** — PHI-bearing evidence-span data subject to retention exists in both the SQL table and the self-hosted trace store mandated by [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §12 — a purge scoped only to `AI.fieldOutcome` is incomplete | 🟠 high | See §1 Finding 11 (new) |
| 12 | 🔴 **B7 confirmed open in a third document, still unowned.** [epic-02-data-layer.md](solution-doc:5077) carries `ai_field_outcome_retention_days: int \| None = None` forward unchanged; [00-source-index.md](solution-doc:5092) Table B lists it with no owner | 🔴 blocker | Escalates Finding 1 from "unanswered" to "unowned across three documents and an unknown number of weeks" — see Finding 12 |
| 13 | 🔴 **PHI with no erasure path** ([GAPS.md](solution-doc:5089) Gap 10) — `proposedValue`, `acceptedValue`, `foundIn` hold clinical content and the purge that would remove them is permanently dormant | 🔴 blocker | Reframes the whole story: this is an accruing compliance exposure, not a deferred feature. See Finding 13 |
| 14 | 🟠 **The purge's target rows may never reach a terminal state** ([GAPS.md](solution-doc:5089) Gap 25) — auto-committed rows never get an `acceptedValue` or a clinician decision | 🟠 high | Any purge predicate keyed on "decided" or "resolved" would skip the majority of rows forever. See Finding 14 |
| 15 | 🟡 **No transaction primitive** ([GAPS.md](solution-doc:5089) Gap 17) — PEA-103's `aexecute` is single-statement, fresh-connection-per-call | 🟡 medium | Less severe here than elsewhere: a batched purge wants a loop with per-batch commits, which is *closer* to what `aexecute` offers than the atomic multi-statement writes Epics 9/10 need. But "delete rows, then log the purge run" is two statements. See Finding 15 |

---

### Finding 1 (detail) — the number nobody has

The epic is admirably honest about this: `ai_field_outcome_retention_days` defaults to `None`,
and the purge **refuses to run** when unset rather than guessing. The retention period is
recorded as open question **B7**, and the epic states that neither primary source
(`pacEHR-Encounter-Agent-4Pager.md`, `pacEHR-AI-Approach-2-Proposed.md`) specifies one.

Why this cannot be resolved by engineering judgement:

1. **It is a clinical and compliance decision.** `AI.fieldOutcome` holds `proposedValue`,
   `acceptedValue` and `foundIn` — clinical content extracted from notes. How long a
   derived-clinical-content record must be kept, and when it must be destroyed, is a data-owner
   question with a regulatory dimension. A developer picking 90 or 365 days is picking a
   compliance posture.
2. **It has a hard lower bound set by another epic.** REQ-10-08 requires Epic 10's evaluation
   harness to replay "recent real notes." The retention window must stay strictly longer than
   whatever window the harness needs. Epic 10's number is also unstated, so there are two
   unknowns and one dependency between them.
3. **The volume makes it consequential.** ~10.95M rows/year (≈30 rows/encounter × ~1,000
   encounters/day, per `pacEHR-Encounter-Agent-4Pager.md` line 111). Whatever number is chosen
   determines the steady-state table size, and a wrong-by-10× answer is the difference between
   a 3M-row and a 30M-row table.

**What this story can and cannot deliver:** it can deliver the mechanism, the guard, the tests
and the refusal behaviour — genuinely 2 points of work. It cannot deliver a *configured,
running* purge. Those are two different DoDs and the story currently conflates them. §5.4
splits them.

---

### Finding 2 (detail) — CORRECTION: the scheduler exists

An earlier pass of this audit concluded no scheduling mechanism existed and that Epic 11 would
have to build one. **That was wrong.** The correction matters because it makes this story
meaningfully cheaper to land.

`pacEHR_API/PacEHR.Functions.Process/` is a real, live Azure Functions project:

| Property | Value | Evidence |
|---|---|---|
| Target framework | `net8.0` | `pacEHR_API/PacEHR.Functions.Process/PacEHR.Functions.Process.csproj` line 3 |
| Functions runtime | v4 | same file, line 4 |
| Worker model | **isolated** (out-of-process) | `pacEHR_API/PacEHR.Functions.Process/Program.cs` line 10 — `FunctionsApplication.CreateBuilder(args)` |
| Host config | `"version": "2.0"` | `pacEHR_API/PacEHR.Functions.Process/host.json` line 2 |
| Timer extension | `Microsoft.Azure.Functions.Worker.Extensions.Timer` 4.3.1 | csproj lines 11–21 |
| In the solution file | yes | `pacEHR_API/pacEHR.sln` line 35 |

**Five live timer triggers**, all with real bodies:

| Function | Cron | Calls |
|---|---|---|
| `pacEHR_API/PacEHR.Functions.Process/DailyCCMBHFunction.cs` line 24 | `0 0 14 * * *` | `createCCMBHIEncounter()` |
| `pacEHR_API/PacEHR.Functions.Process/DailyEmailFunction.cs` line 20 | `0 0 13 * * *` | `emailEncounterPdf("daily", ...)` |
| `pacEHR_API/PacEHR.Functions.Process/EveryFiveMinutesFunction.cs` line 23 | `0 */5 * * * *` | `updatePrescriptionEvents()` |
| `pacEHR_API/PacEHR.Functions.Process/HourlyEmailFunction.cs` line 19 | `0 0 */1 * * *` | `emailEncounterPdf("hourly", ...)` |
| `pacEHR_API/PacEHR.Functions.Process/TwiceDailyEmailFunction.cs` line 21 | `0 0 */12 * * *` | `emailEncounterPdf("daily twice", ...)` |

(`pacEHR_API/PacEHR.Functions.Process/DailyForTFAFunction.cs` is entirely commented out —
lines 11–34 — with a note at line 8 saying it is believed out of service. Not a template to copy.)

**Crucially, these reach the database exactly the way the API does.**
`pacEHR_API/PacEHR.Functions.Process/Program.cs` line 12 reads the connection string via
`GetConnectionString("PACEHR-DB")`, line 13 registers `pacehr_devContext`, and line 14
registers `Ipacehr_devContextProcedures` / `pacehr_devContextProcedures` as scoped. The job
classes in `pacEHR_API/PacEHR.Functions.Process/lib/` all take
`Ipacehr_devContextProcedures` by constructor injection —
`pacEHR_API/PacEHR.Functions.Process/lib/ScheduleTFAJob.cs` lines 12–14 calls
`usp_checkUserTfaDaysAsync()` through it; `EmailEncounterJob.cs` lines 18–25 and
`ShareFileJob.cs` lines 23–28 follow the same shape. No separate connection string, no raw
`SqlConnection`.

**So the purge has a home today**, and the wiring is a known quantity:

1. add a job class in lib/ implementing a new interface, injecting `Ipacehr_devContextProcedures`;
2. register it scoped in `Program.cs` beside the existing registrations (lines 15–22);
3. add a timer-trigger class at the project root, e.g. `0 0 2 * * *`;
4. **create a deployment path — see Finding 3.**

The epic's requirement that `purge()` be "invocable standalone with no dependency on a
specific scheduler, so Epic 11 can wire its own trigger without a code change" maps cleanly
onto this: the job class is the standalone unit, the timer function is the trigger, and they
are separate types. Keep that separation — it is the epic's design intent and it happens to be
exactly the house pattern.

---

### Finding 3 (detail) — the host exists but nothing deploys it

A search across all 12 files in `pacEHR_API/pipelines/` (including the `jobs/` subfolder) for
`Functions`, `func`, `FunctionApp`, `AzureFunctionApp` and `PacEHR.Functions` returns **zero
matches**. The only near-hits are PowerShell lines reading "Deleted existing appsettings.json"
in the API deployment job — unrelated.

`deploy-pacehrapis.yml` and its `jobs/` job file publish `PacEHR.API.csproj` to an Azure Web
App. Nothing builds or publishes `PacEHR.Functions.Process`.

The project **is** in `pacEHR_API/pacEHR.sln` (line 35), so `dotnet build` compiles it. How the
five live timer functions reach their environment is therefore **unverified** — presumably a
manual publish or a pipeline outside this repository. **COULD NOT VERIFY** from the repository
alone.

This matters concretely: a purge job that is written, tested and merged will not run anywhere
until someone answers "how does this Functions app get deployed?" That question belongs in
Phase 0, not discovered at release.

---

### Finding 4 & 5 (detail) — hard DELETE against a soft-delete codebase

The epic specifies a hard `DELETE`, not a soft delete, and is explicit that this is
deliberate. The audit's job is to flag the collision.

**There is no retention-purge precedent.** A search of all 608 stored-procedure files for
`DATEADD(DAY, -`, `retention`, `purge` and `archive` finds date arithmetic used only for
**reads** — lookback windows, not deletions:

- `usp_getPendingEmailDeliveryStatus.sql` line 19 — `WHERE CreatedDateTime >= DATEADD(DAY, -@lookbackDays, GETDATE())`
- `usp_getPatientDetailsData.sql` lines 50–51, 70–71 — 30-day vital lookback
- `usp_getDashBoardSchedulerEvent.sql` line 63 — 5-day window

Existing `DELETE FROM` statements are all **transactional child-row cleanup**, not
time-based purges — e.g. `pcc_insertDiagnosticReport.sql` lines 44–47 clearing child rows
before re-insert, `usp_DeleteEncounterCPT.sql` line 27, `usp_addEditUser.sql` line 331. Several
are DELETEs against `#temp` tables inside reporting procedures.

Meanwhile **soft delete is the house convention**: `isDeleted BIT` appears throughout,
including on `AI.prompt` itself, and `usp_deleteAiPrompt.sql` lines 13–21 implements "delete"
as `UPDATE ... SET isDeleted = 1`. `usp_deleteNormals.sql` line 16 even has the hard delete
commented out in favour of the soft path.

**The argument for hard DELETE here is nonetheless sound**, and worth stating explicitly so a
reviewer does not reflexively convert it:

- Retention exists **to destroy data**, not to hide it. A soft-deleted row still holds the
  clinical value and still counts toward the table's size. It satisfies neither the compliance
  intent nor the storage one.
- `AI.fieldOutcome` is a derived record, not a source of clinical truth. The encounter form
  holds the accepted value; this table holds the audit of how it got there.
- A soft-delete flag on an 11M-rows/year table adds a column and an index predicate to every
  query for no benefit.

**Recommendation:** keep the hard DELETE, and call it out prominently in the PR as a
*deliberate* departure from the `isDeleted` convention, with these reasons. CLAUDE.md rule 8's
spirit — don't retro-fit conventions blindly — cuts in favour of the epic here, but only if the
reasoning is written down. An undocumented hard DELETE in this codebase will look like a
mistake to the next reader.

One operational addition the epic does not mention: **delete in batches**. A single
`DELETE` against millions of rows on Azure SQL will hold locks and can escalate to a table
lock. §3.1 includes batching.

---

### Finding 6 (detail) — build-target confirmed as TypeScript/Node.js (owner decision)

This spec previously recorded the epic's Python modules as targeting an approved Python
sidecar architecture — that was correct at the time of earlier revisions, and the Python
Epic corpus remains unchanged as the reference design. **What has changed is the build target
for the PacEHR AI engine itself.** Hem (owner decision, 2026-09-29) has confirmed that the
AI engine will be implemented in **TypeScript/Node.js**, not Python, in a standalone
TypeScript repository not yet created and not ingested into this solution. **There is no C#
reuse** — that part stands.

⚠️ **Revision 6 corrects the rest of this sentence.** Revision 5 called the build *"greenfield,
with no Python-to-TypeScript migration; the TypeScript repo starts fresh."* It does not start
fresh. `pacEHR_AI/` holds the reference corpus's **Epic 01 delivered in Python** — six `core/`
modules with unit and integration suites — and the Node service's foundation is a
**module-for-module port of it** (M9, 5–8 points). A Python-to-TypeScript migration is
precisely what the foundation layer is.

The runtime chain is: **Angular frontend → .NET Web API → TypeScript AI service → Azure
OpenAI.** The division of labour remains similar in spirit to the approved architecture's
intent — the .NET API keeps owning auth, persistence and the existing contract; the
TypeScript AI service owns AI decisioning.

**What this means for this story:** the epic's references to `core/settings.py` and
`core/field_outcome_retention.py` map to TypeScript equivalents in the new repo
(`src/core/settings.ts` and `src/jobs/fieldOutcomeRetention.ts` — see §3.2). The fail-closed
guard, acceptance criteria, and purge predicate are completely unaffected by the language
change.

🔴 **And this story is where the port is most dangerous.** `pacEHR_AI/core/settings.py`
declares required fields with **no default**, so an absent value raises at startup — which is
exactly the fail-closed behaviour this story depends on. The idiomatic zod translation a
reviewer reaches for is `.default(0)`, and `0` days of retention means **purge everything**.
The port must carry the *behaviour* — "absent means refuse" — and not merely the field list.
Required form: `z.coerce.number().int().positive().optional()`, with an explicit unset branch
that deletes nothing and logs the refusal. This is rollup risk R2, and it is the single
highest-consequence line in the whole port.

**Sequencing consequence specific to this story:** if Finding 9's recommendation holds and
the purge runs in the .NET Functions host, then the setting lives in `src/core/settings.ts`
in the TypeScript repo while the code that consumes it may live in .NET. That split is
workable but must be deliberate — one must be authoritative, and a retention period
configured in two places that disagree is worse than one configured nowhere.

The purge SQL in §3.1 is unaffected either way. `AI.fieldOutcome` lives in SQL Server
regardless of which service writes it. The TypeScript-to-.NET mapping in §3.2 is therefore a
**contingency** for the case where the purge lands in the existing .NET Functions host
rather than the new TypeScript repo — not a correction of the design intent.

---

### Finding 9 (detail) — which host runs the purge is now itself an open question

The AI engine is TypeScript/Node.js (owner decision). A retention purge is not AI
decisioning — it is scheduled database maintenance. That leaves two plausible homes and
no stated rule:

| Candidate host | For | Against |
|---|---|---|
| **.NET Azure Functions timer** (`pacEHR_API/PacEHR.Functions.Process/`) | Exists today, five live timer functions, already holds a DB connection string, matches "database maintenance" | No pipeline in this repository deploys it (Finding 3) |
| **Azure Functions Node.js v4 timer trigger** (in the new TypeScript repo) | Same language as the AI service; timer pattern: `app.timer('purgeFieldOutcomes', { schedule: '<NCRONTAB>', handler })` from `@azure/functions`; no per-function `function.json` in the v4 model; **keeps the retention setting and the code that reads it in one place** | The TypeScript repo does not exist yet; a purge is database maintenance, not AI decisioning |

**Recommendation:** the .NET Functions host, on the grounds that a time-based DELETE against a
SQL Server table is maintenance work and belongs with the other **six** timer jobs (⚠️
re-counted 2026-09-30: `DailyCCMBHFunction`, `DailyEmailFunction`, `DailyForTFAFunction`,
`EveryFiveMinutesFunction`, `HourlyEmailFunction`, `TwiceDailyEmailFunction` — Revision 5 said
five).

⚠️ **One argument against this recommendation got stronger at Revision 6.** Splitting the
setting from its consumer is what §3.2 warns about — and the fail-closed guard is the thing
being split. If the setting lives in `src/core/settings.ts` (ported, with its
"absent means refuse" behaviour and its test) while the DELETE runs in .NET, then the .NET
side needs its **own** fail-closed guard, written and tested separately, because
`GetValue<int>` yields `0` for an absent key exactly as `.default(0)` would. **Two guards for
one rule is two chances to get it wrong.** Weigh that against the deployment argument, which
M3 may resolve anyway. The Node.js
v4 timer trigger in the TypeScript repo is a legitimate alternative — both are real Azure
Functions v4 patterns and both are candidates Architecture should evaluate. The key
trade-off: the .NET host exists today and is deployable (once Finding 3 is resolved); the
Node.js host will be a greenfield setup but keeps the retention logic co-located with the AI
service that writes to the table. This is a decision for Architecture to make and record, not
for the implementer to assume — and it must be made before Phase 2, because it determines
which language's fail-closed guard gets built and tested.

---

### Finding 10 (detail) — two documents, weeks apart, stalled on the same number

The retention period is not merely undecided in the epic. It is undecided in the architecture
too, and has been since September.

[2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §16 "Open questions"
lists:

> **Q5** — *Retention period for evidence spans containing PHI?* · Owner: **Compliance** ·
> Blocks: **Audit schema**

That is the same question as the epic's open question **B7** and the same question as this
story's blocker, asked independently by a different author weeks earlier, with an owner
already nominated — and still unanswered.

**Why this changes the recommendation's force.** A question that appears once looks like an
oversight. The same question appearing in two independent design documents, with a named owner
class on one of them, means **nobody owns it in practice**. Restating it in a third document
will not resolve it. It needs a named individual and a date, escalated as a compliance action
item rather than carried as a technical dependency. This is the single longest-lead item in
Epic 02 and should be opened now, in parallel with everything else, not when PEA-204 is
groomed.

---

### Finding 11 (detail) — the purge's scope is narrower than the retention obligation

Doc 3777 §12 requires that every run record, per field, its **evidence span** — the character
offsets and quoted substring the value came from. Evidence spans quote the provider's note
verbatim, so they **are PHI**. The same section mandates that tracing be **self-hosted**
(OpenTelemetry collector, or self-hosted LangSmith / Langfuse) precisely because *"PHI/BAA
rules out third-party SaaS tracing."*

The consequence for this story: PHI-bearing derived data subject to retention will exist in
**two** stores, not one.

| Store | Holds | Purged by |
|---|---|---|
| `AI.fieldOutcome` (SQL Server) | proposed values, evidence, decisions | **this story** |
| Self-hosted trace store | full run traces including per-field evidence spans | **nobody — unowned** |

A retention policy satisfied by purging only the SQL table is **incomplete**, and the gap is
invisible: the table will look clean while the trace store keeps the same PHI indefinitely.

**Recommendation:** state explicitly in this story's scope that trace-store retention is *out
of scope but not out of obligation*, and raise it as a separate item against whoever owns the
observability stack. When the Q5 / B7 retention number is finally set, it must be applied to
both stores or the answer is only half-implemented.

---

### Finding 7 (detail) — the fail-closed guard needs a different home

The epic places the setting in Epic 01's core/settings.py as
`ai_field_outcome_retention_days: int | None = None`, using `pydantic_settings.BaseSettings`.
The build target is now TypeScript/Node.js, so the equivalent lives in `src/core/settings.ts`
using **zod** for config validation. Configuration in this repository also comes from:

1. **Database app settings**, read via `usp_getAppSettingsForMultipleAsync` — this is how the
   OpenAI credentials are resolved (`OPENAI_API_KEY`, `OPENAI_API_URL`) in
   `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`.
2. **`appsettings.json`** / `IConfiguration`, e.g. the fallback key
   `APIkeySettings:openAIapiKey`, and `GetConnectionString("PACEHR-DB")` at
   `pacEHR_API/PacEHR.Functions.Process/Program.cs` line 12.

**The fail-closed property must be preserved through this translation, and it is the one thing
in this story that is easy to lose.** The same catastrophe exists in TypeScript in a different
shape — a numeric default of `0` would purge the entire table:

```typescript
// WRONG — both of these silently yield 0, which purges the entire table.
const retentionDays = parseInt(process.env.AI_FIELD_OUTCOME_RETENTION_DAYS ?? '0', 10);

const schema = z.object({
  retentionDays: z.number().int().positive().default(0),  // a 0 default is the same bug
});

// CORRECT — optional(), so the field is undefined when the env var is absent.
const schema = z.object({
  retentionDays: z.number().int().positive().optional(),
});
```

The fail-closed guard in TypeScript:

```typescript
// In src/jobs/fieldOutcomeRetention.ts (class FieldOutcomeRetentionPurger, method purge())
const retentionDays = config.retentionDays;
if (retentionDays === undefined || retentionDays <= 0) {
  // refuse, log the missing setting by name, delete nothing
  logger.warn(
    "Retention purge refused: setting 'AI_FIELD_OUTCOME_RETENTION_DAYS' is not configured. No rows were deleted."
  );
  return 0;  // zero rows purged, by design
}
```

Note `<= 0` is included deliberately: a misconfigured `0` must refuse, not purge everything.

**The trigger condition, stated explicitly.** The same guard applies **if the purge is
implemented in .NET** — which remains the likely outcome for scheduled database maintenance
(Finding 9). The .NET equivalent trap is `IConfiguration.GetValue<int>("...")` returning `0`
for a missing key. The guard must therefore read into a **nullable** type and refuse on null:

```csharp
// Correct: nullable, explicit refusal.
int? retentionDays = _configuration.GetValue<int?>("AI:FieldOutcomeRetentionDays");
if (retentionDays is null or <= 0)
{
    _logger.LogWarning(
        "Retention purge refused: setting 'AI:FieldOutcomeRetentionDays' is not configured. No rows were deleted.");
    return 0;   // zero rows purged, by design
}
```

**Therefore: "refuse on unset or non-positive retention" is a host-independent requirement.**
It must be asserted in whichever language wins, and it must have a dedicated unit test (vitest
in the TypeScript repo, xUnit/NUnit in the .NET host) that fails if the guard is removed —
see §5.1, which is the most important test in this story. Do not let the host decision
(Finding 9) defer this; the guard specification is the same either way.

Prefer the **database app-settings** source over `appsettings.json` if the value should be
changeable without a redeploy — that is the mechanism the AI credentials already use. Either is
acceptable; the choice should be recorded.

✅ **Revision 4 confirms the guard specification unchanged.** [epic-02-data-layer.md](solution-doc:5077)
carries `ai_field_outcome_retention_days: int | None = None` forward verbatim (in the
reference Python corpus) and states the fail-closed behaviour explicitly.
[CLAUDE.md](solution-doc:5093) reinforces it as a binding rule — *"guards fail closed"* and
*"a bare number in an expression is a bug"*, which is precisely the numeric-default trap named
above, stated as a general principle. The design is right and is now backed by a coding
standard. Nothing to change here.

---

### Finding 12 (detail) — 🔴 B7 is not unanswered, it is unowned

Finding 10 recorded the same retention question appearing in two independent documents.
Revision 4 adds a **third**, and the pattern it forms is the finding.

| Document | Where | Status |
|---|---|---|
| The epic (original) | open question **B7** | unanswered |
| [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §16 | **Q5**, owner: Compliance | unanswered |
| [epic-02-data-layer.md](solution-doc:5077) | setting carried forward as `int \| None = None` | unanswered |
| [00-source-index.md](solution-doc:5092) | Table B, listed with **no owner** | unanswered |

Four documents. At least three authors. An owner *class* nominated once ("Compliance") and
never converted into a person. The most recent document in the set — the one written by the
team that will build this — records B7 as **unowned**, which is a regression from doc 3777's
nomination, not progress.

**What this means for how the item should be raised.** A dependency that four documents have
politely deferred will not be resolved by a fifth document deferring it politely. The failure
mode is not that someone forgot; it is that the question has no addressee. Restating it in
this spec is necessary but demonstrably insufficient — it has been tried three times.
Convert it to a named individual with a date, tracked outside the engineering backlog, and
treat the engineering work as blocked-with-a-workaround rather than in-progress.

---

### Finding 13 (detail) — 🔴 correct, dormant, and accruing PHI the whole time

[GAPS.md](solution-doc:5089) Gap 10 states the consequence this spec had implied but never
said plainly: `proposedValue`, `acceptedValue` and `foundIn` are **PHI with no erasure path**.

Follow the logic through. The fail-closed guard is correct — a purge that guesses a retention
period is far more dangerous than one that refuses. This spec defends that design and
continues to. But the guard's correctness is exactly what guarantees the outcome:

1. B7 is unset and unowned (Finding 12).
2. The purge refuses to run when B7 is unset — by design, correctly.
3. Therefore the purge never runs.
4. `AI.fieldOutcome` accrues PHI-bearing clinical content at ~11M rows/year, indefinitely.
5. There is no other erasure path — no soft-delete flag, no archive job, no manual process.

**The uncomfortable part.** Steps 1–3 are each individually correct and defensible. The
system composed from them has the same PHI exposure as having built no retention mechanism
at all. The only difference is that a reviewer can point at a mechanism and conclude the
obligation is handled. That is arguably *worse* than an obvious absence, because an obvious
absence gets escalated.

**This changes what "done" means for this story.** Shipping a correct, permanently-dormant
purge and closing the ticket is a false completion. The DoD (§5.4) is already split into a
mechanism half and an enablement half, which is the right structure — but the enablement
half must be tracked as an **open compliance exposure with an owner**, not as a backlog item
waiting on a dependency. Those are treated very differently by the people who need to act.

**One concrete mitigation worth considering.** If B7 remains unset for longer than some
agreed period, the purge should escalate rather than silently refusing: log at error rather
than warning, and surface it wherever operational alerts are seen. A safety mechanism that
quietly declines to run is indistinguishable from one that is working. Cheap to add now,
and it converts a silent exposure into a visible one.

---

### Finding 14 (detail) — the purge predicate must not depend on a decision that never comes

[GAPS.md](solution-doc:5089) Gap 25 — auto-committed fields never acquire an `acceptedValue`
and never get a clinician decision, so `decidedAtUtc` stays NULL on the majority of rows
(see PEA-203 Finding 13).

**Why that lands here.** A purge predicate is a natural place to reach for "resolved" as a
precondition — *only delete rows that have been decided*, on the reasonable instinct that
undecided rows might still be needed. Against this table that predicate would **skip the
majority of rows forever**, because the majority are auto-committed and never decided. The
purge would appear to work, delete a minority of rows, and leave the bulk of the PHI in
place. A partially-effective purge is the hardest kind of retention failure to detect: the
row count goes down, so it looks like it worked.

**Therefore: purge on `createdUtc` age alone.** That is what the epic specifies, and it is
correct — this finding exists to stop someone "improving" it. If Gap 25 is resolved by
writing `acceptedValue = proposedValue` on the ACCEPT path (PEA-203's recommendation), the
temptation to key on decision state goes away, but the predicate should still be age-based:
retention obligations are measured in elapsed time, not in workflow state.

Add an explicit note to the DoD and a test asserting that an undecided row past the
retention horizon **is** purged.

---

### Finding 15 (detail) — the transaction gap, and why it bites less here

[GAPS.md](solution-doc:5089) Gap 17 — Epic 01's PEA-103 provides a single-statement
`aexecute` with a fresh connection per call and no transaction primitive.

**This story is the least harmed of the three affected.** A batched purge genuinely wants a
loop of independent, individually-committed `DELETE TOP (n)` statements — partial progress
is acceptable and re-running resumes where it left off. That is closer to what a plain
single-statement `database.execute()` already offers than the atomic multi-statement writes
Epics 9 and 10 need.

**One simplification arrives with the TypeScript target, and one problem does not go away.**
The Python design used `mssql_python`, a synchronous PEP 249 driver, so every call had to be
pushed through `asyncio.to_thread` to avoid blocking the event loop. The `mssql` npm package
(node-mssql over tedious) is natively async: the thread-pool wrapper disappears entirely, and
with it a whole class of "which executor is this running on" bugs. That is a genuine
simplification, not a translation artefact. **It does not, however, touch the atomicity
gap below** — native async makes each statement cleaner, not two statements atomic.

**But there is one two-statement sequence, and it matters for a different reason than
correctness.** "Delete this batch" and "log the purge run" are separate statements. If the
process dies between them, rows are destroyed with no record of their destruction. For an
ordinary job that is a minor observability gap; for a *retention* job it undermines the only
evidence that the obligation was discharged. A retention mechanism you cannot prove ran is
not much better than one that did not.

**Recommendation:** if the purge lands in .NET (Finding 9's recommendation), this is a
non-issue — the Functions host has ordinary transaction support, and
`patientAlertJobLog.sql` is the prior art for the run log. If it lands in the TypeScript
service, it needs the Epic 01 transaction primitive that PEA-202 §3.3a and PEA-203 risk 19
are already asking for. The good news is that node-mssql ships a first-class `Transaction`
object, so building that primitive on the TypeScript side is cheaper than the Python design
implied — but it still has to be *designed into* `src/core/database.ts`, not bolted on after
four epics have been written against a fresh-connection-per-call API. **Raise it once, for
all three stories** — this is one request to Epic 01, not three. Another small argument for
the .NET Functions host, which needs none of it.

---

## 2. Current state — verified inventory

### 2.1 What exists

| Thing | Status | Evidence |
|---|---|---|
| Target table `AI.fieldOutcome` | does not exist yet | PEA-203 creates it |
| Scheduled-job host | **exists and is live** | `pacEHR_API/PacEHR.Functions.Process/`, 5 timer functions |
| DB access from that host | **exists**, same as API | `Program.cs` lines 12–14 |
| Deployment for that host | **not in this repo** | zero pipeline matches |
| Retention-purge precedent | **none** | no time-based DELETE in 608 procs |
| Soft-delete convention | pervasive | `isDeleted BIT`; `usp_deleteAiPrompt.sql` lines 13–21 |
| A job-run log table | **exists as prior art** | `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` |
| The retention number | **does not exist** | open question B7 |

### 2.2 Job-run logging — prior art worth copying

`pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` is a close model for
recording purge runs, and it already solves the "how do we know the job ran?" problem:

```
[Id] INT IDENTITY, [jobRunId] UNIQUEIDENTIFIER NOT NULL, [accountId] INT NULL,
[status] VARCHAR(20) NOT NULL, [alertsInserted] INT NULL,
[errorNumber] INT NULL, [errorMessage] NVARCHAR(4000) NULL,
[errorProcedure] NVARCHAR(200) NULL, [errorLine] INT NULL,
[startedAt] DATETIME DEFAULT (getutcdate()) NOT NULL, [completedAt] DATETIME NULL,
CONSTRAINT [PK_patientAlertJobLog] PRIMARY KEY CLUSTERED ([Id] ASC)
```

Its closing procedure is `usp_finishPatientAlertJobLog.sql`, which sets
`[completedAt] = GETUTCDATE()` at line 26.

**Recommendation: add an equivalent `AI.purgeRunLog`** (or extend this pattern) so that
"purge refused because unset" is a *recorded, queryable* event rather than a log line someone
has to find. The epic requires the refusal to be logged; a table makes it auditable, and it
makes the fail-closed behaviour demonstrable to compliance. This is a small addition and it is
the difference between a guard you trust and a guard you hope fired.

Note `status VARCHAR(20)` here has no CHECK constraint — if the pattern is copied, add one, per
the precedent at `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` line 14.

### 2.3 How anything database-side ships

Unchanged from PEA-201/202/203 and inherited:

- No `dacpac` deployment. Across 12 files in `pacEHR_API/pipelines/`, a search for
  `dacpac|SqlPackage|sqlproj|Database` returns one hit — a comment in `kb-refresh.yml`.
- Deployment is manual, via `pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1`,
  reading from a git ref, gated by a duplicate-object report.
- CLAUDE.md rule 5: unregistered `.sql` files in
  `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` are **silently never deployed**.
- Rule 4: canonical object file **and** re-runnable release script — both, every time.
- Rule 6: procedures named `usp_<Verb><Noun>`, in Stored Procedures/Procs2/, `CREATE OR ALTER
  PROCEDURE`, schema-qualified, with a header block and Jira key.

**And now additionally:** the Functions host has its own, undocumented deployment path
(Finding 3). This story touches both, so both must be answered.

---

## 3. Proposed implementation

### 3.1 The purge procedure

Batched, so it cannot lock the table; parameterised, so the guard lives in one place.

```sql
CREATE OR ALTER PROCEDURE [AI].[usp_purgeFieldOutcome]
    @retentionDays INT,
    @batchSize     INT = 5000,
    @rowsDeleted   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Fail closed. A caller that passes NULL or a non-positive window gets nothing
    -- deleted. 0 days would mean "purge everything" and must never be honoured.
    IF (@retentionDays IS NULL OR @retentionDays <= 0)
    BEGIN
        SET @rowsDeleted = 0;
        RETURN 0;
    END;

    DECLARE @cutoff DATETIME2(7) = DATEADD(DAY, -@retentionDays, GETUTCDATE());
    DECLARE @batch  INT = 1;
    SET @rowsDeleted = 0;

    -- Volume note (CLAUDE.md § Numbers): ~30 rows per encounter x ~1,000 encounters/day
    -- = ~10.95M rows/year. Source: pacEHR-Encounter-Agent-4Pager.md line 111.
    -- Batching keeps lock escalation off a table of that size.
    WHILE (@batch > 0)
    BEGIN
        DELETE TOP (@batchSize) FROM [AI].[fieldOutcome]
        WHERE [createdUtc] < @cutoff;

        SET @batch = @@ROWCOUNT;
        SET @rowsDeleted = @rowsDeleted + @batch;
    END;

    RETURN 0;
END;
```

The guard is deliberately duplicated in SQL and in C# (§3.2). Defence in depth: the procedure
must be safe even if called by hand.

### 3.2 The application-side guard

**Contingency mapping — TypeScript-first, with .NET alternative.** The AI engine build target
is TypeScript/Node.js (owner decision), so the primary mapping is TypeScript → .NET. The
purge may land in the existing .NET Functions host (Finding 9's recommendation) or in a new
Azure Functions Node.js v4 timer trigger in the TypeScript repo — Architecture decides.

| Epic artefact (Python reference corpus) | TypeScript repo (greenfield) | .NET alternative |
|---|---|---|
| `ai_field_outcome_retention_days: int \| None = None` in `core/settings.py` | `retentionDays: z.number().int().positive().optional()` in `src/core/settings.ts` | a nullable `IConfiguration` read — DB app settings or `appsettings.json` (§1 Finding 7) |
| `core/field_outcome_retention.py` | `src/jobs/fieldOutcomeRetention.ts` | a job class in `pacEHR_API/PacEHR.Functions.Process/lib/` |
| `DELETE_FIELD_OUTCOME_BEFORE_SQL` | `AI.usp_purgeFieldOutcome` (§3.1) | same |
| `class FieldOutcomeRetentionPurger` / method `purge()` | same class name, same method name — both survive unchanged in TypeScript | one public method on the .NET job class |
| `asyncio.to_thread` wrapper (Python thread-pool bridge) | **disappears** — node-mssql is natively async/await; no thread-pool wrapper needed (a genuine simplification) | `Ipacehr_devContextProcedures` injected by DI |
| `pydantic_settings.BaseSettings` | **zod** schema (`z.object({ retentionDays: z.number().int().positive().optional() })`) | `IConfiguration.GetValue<int?>` with nullable read |
| scheduler-agnostic `purge()` | the job class knows nothing about timers; a separate trigger wires it | same separation — timer-trigger class delegates to job class |

The fail-closed guard and the `undefined`/`null or <= 0` refusal from §1 Finding 7 are the
load-bearing part. Everything else is plumbing.

**If the purge lands in the TypeScript repo** (Azure Functions Node.js v4 timer trigger):

```typescript
// src/jobs/fieldOutcomeRetention.ts
import { app } from '@azure/functions';

// Timer trigger — no per-function function.json in the v4 model
app.timer('purgeFieldOutcomes', {
  schedule: '0 0 2 * * *',   // replace with NCRONTAB from config
  handler: async (_myTimer, _context) => {
    await purger.purge();
  },
});
```

The `FieldOutcomeRetentionPurger` class and its `purge()` method are defined in
`src/jobs/fieldOutcomeRetention.ts`; the timer registration above is the only caller.

**If the purge lands in the .NET Functions host** (following the five live examples):

```csharp
// New class at pacEHR_API/PacEHR.Functions.Process/ root, beside DailyEmailFunction.cs
[Function("DailyFieldOutcomePurge")]
public async Task Run([TimerTrigger("0 0 2 * * *")] TimerInfo myTimer)
    => await _retentionJob.purge();
```

Registered scoped in `pacEHR_API/PacEHR.Functions.Process/Program.cs` beside the existing
registrations at lines 15–22.

### 3.3 The hard-DELETE decision, recorded

Per Finding 4/5: **hard DELETE, deliberately**, because retention exists to destroy data and a
soft-delete flag satisfies neither the compliance intent nor the storage one on an
11M-rows/year table. This departs from the pervasive `isDeleted BIT` convention and from the
example at `usp_deleteAiPrompt.sql` lines 13–21. **Write this reasoning in the PR** — an
undocumented hard DELETE here reads as an error.

### 3.4 Interaction with Epic 10 — the constraint that binds

REQ-10-08 requires Epic 10's harness to replay "recent real notes" from this table. So:

> retention window **must be strictly greater than** Epic 10's replay window.

Neither number exists. The dependency must be recorded as an explicit constraint on B7's
answer, or the purge will silently start deleting the harness's inputs and the harness will
quietly degrade. That is a hard failure to diagnose after the fact, because nothing errors —
the replay set just gets smaller.

**Recommendation:** whatever B7 answers, add an assertion (test or startup check) that the
configured retention window exceeds the configured harness window, and fail loudly if not.

---

## 4. Delivery plan

### 4.0 The story at a glance

**Assume nothing is delivered.** The six live timer functions in
`pacEHR_API/PacEHR.Functions.Process/` are precedent to copy, not infrastructure you inherit —
**no pipeline in either repository deploys that host** (M3).

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `usp_purgeFieldOutcomes` — the purge procedure, boundary-inclusive predicate | A — **can start today** | PEA-203 | 1 |
| **Runtime** | `src/core/settings.ts` retention field, `.optional()` **never `.default(0)`** | C | M9 port | 0.5 |
| **Runtime** | `src/jobs/fieldOutcomeRetention.ts` — `purge()` + the fail-closed guard | C | M9 | 0.5 |
| **Surface** | Timer host + schedule (D30) | D | **D30, M3** | 3–5 |
| **Enable** | Turn the job on | — | 🔴 **D4 — the retention number** | 0 |
| | | | **Total** | **2 · 5–7 with the host** |

### 4.0a This story is deliverable now and completable later — plan for that explicitly

**The mechanism does not need the number.** The procedure, the guard, the refusal path and
every test can be built, reviewed and merged with B7 still open, because the specified
behaviour when the setting is absent is *refuse and log*. That is a testable behaviour, and
it is the **most important test in the story** — more important than the deletion test,
because a purge that deletes too much cannot be undone.

**So split the Definition of Done in two, and say which half you are claiming:**

- **DoD-A (mechanism, ~2 pts):** procedure, guard, job, and a passing test proving that with
  the setting unset the job deletes **zero rows** and logs a refusal naming the missing key.
  Deliverable in R1/R2 without any compliance input.
- **DoD-B (enablement, ~0 pts of code):** D4 answered, the value configured per environment,
  a dry-run row count reviewed by a human, and the job enabled. Gated on Clinical +
  Compliance, and on nothing engineering owns.

Closing a ticket that claims both when only DoD-A is true is how a fail-closed guard quietly
becomes the only thing standing between production and a full-table DELETE, with nobody
tracking the decision that was supposed to replace it.

### 4.0b The four things to get on someone's calendar now

1. **D4 — the retention period.** Longest lead time in the epic. Two documents weeks apart
   have already stalled on this number (Finding 10); a third will too unless it is assigned
   to a named person with a date. **Start at grooming, not when the story is picked up.**
2. **D19 — confirm one answer serves both** D4 and the architecture document's Q5 (retention
   for PHI evidence spans). If they differ, the shorter one binds and the purge predicate
   changes.
3. **D30 — which host.** Determines which language's fail-closed guard is built. Must precede
   Phase 2, not follow it.
4. **M3 — how does `PacEHR.Functions.Process` reach its environments?** Six timers run from a
   project no pipeline here deploys. Worth knowing regardless of this story.

**And one constraint that binds from outside:** Epic 10 replays `AI.fieldOutcome` as its
labelled set. **The retention window must exceed Epic 10's replay window**, which is also
unstated. A purge that silently shrinks the evaluation corpus produces no error and no alert —
the replay set just gets smaller. Raise it as one question with D4, not two.

**Exit criterion for DoD-A:** with the setting unset, `purge()` deletes zero rows and logs a
refusal naming the key. With it set to N days, the boundary tests at N−1, N and N+1 days
behave as §5.2 specifies.

### Phase 0 — Unblock

| # | Action | Owner | Blocks |
|---|--------|-------|--------|
| 0.1 | **Answer B7: what is the retention period?** Clinical + compliance decision | Data owner / compliance | a *configured* purge |
| 0.2 | Establish Epic 10's replay window; confirm 0.1 exceeds it | Architecture | §3.4 assertion |
| 0.3 | **How is `PacEHR.Functions.Process` deployed?** Not in this repo | DevOps | the job ever running |
| 0.4 | **Platform question answered** — the AI engine is a greenfield **TypeScript/Node.js** service (owner decision, supersedes the Python sidecar in doc 3777 §3.1). Residual, and it is sharper than before: the repository **does not exist yet in any form** — no repo, no skeleton, no pipeline. Does it get stood up, is it staffed, and is Epic 02 sequenced around it? | Architecture | sequencing, not the DDL |
| 0.4a | **Which host runs *this* purge** — the existing .NET Functions timer (`PacEHR.Functions.Process`, already live) or an Azure Functions **Node.js v4** timer in the new TypeScript service? §1 Finding 9 recommends the former, precisely because it exists today | Architecture | which runtime's fail-closed guard gets built |
| 0.8 | **Who owns trace-store retention?** §1 Finding 11 — out of this story's scope, but not out of obligation | Observability owner | a complete retention policy |
| 0.5 | Confirm hard-DELETE-over-soft-delete is accepted | Tech lead | §3.3 |
| 0.6 | Decide config source: DB app settings vs `appsettings.json` | Tech lead | §3.2 |
| 0.7 | Confirm PEA-203 has landed | — | the target table |

**0.1 and 0.3 are the only two that actually block.** Everything else can proceed in parallel.

### Phase 1 — The mechanism (deliverable now, without B7)

1. Create the purge procedure per §3.1 in Stored Procedures/Procs2/ — rule 6 naming, header
   block, Jira key, `CREATE OR ALTER PROCEDURE`, schema-qualified.
2. Create the re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/&lt;JIRA-KEY&gt;-purgeFieldOutcome.sql.
3. Register **both** in the `.sqlproj` — rule 5.
4. Expose the procedure through `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs`
   and `Ipacehr_devContextProcedures.cs`.
5. Optionally create `AI.purgeRunLog` on the `patientAlertJobLog` pattern (§2.2) — recommended.
6. Run the release harness; confirm `PASS`.

### Phase 2 — The job

7. Add the job class + interface in `pacEHR_API/PacEHR.Functions.Process/lib/`, injecting
   `Ipacehr_devContextProcedures`, with the nullable-config fail-closed guard from §3.2.
8. Register it scoped in `Program.cs`.
9. Add the timer-trigger class at the project root. Keep it a one-liner that delegates — the
   job class stays scheduler-agnostic, per the epic.

### Phase 3 — Enablement (gated on 0.1 and 0.3)

10. Configure the retention value.
11. Add the §3.4 assertion that retention exceeds the harness window.
12. Deploy — via whatever 0.3 establishes.
13. Verify with §5.

---

## 5. Verification

### 5.1 The refusal path — the most important test

```sql
-- unset / NULL: must delete nothing
DECLARE @rows INT;
EXEC [AI].[usp_purgeFieldOutcome] @retentionDays = NULL, @rowsDeleted = @rows OUTPUT;
SELECT @rows AS shouldBeZero;

-- zero: must also delete nothing (the catastrophic-inversion guard)
EXEC [AI].[usp_purgeFieldOutcome] @retentionDays = 0, @rowsDeleted = @rows OUTPUT;
SELECT @rows AS shouldAlsoBeZero;

-- negative: must delete nothing
EXEC [AI].[usp_purgeFieldOutcome] @retentionDays = -30, @rowsDeleted = @rows OUTPUT;
SELECT @rows AS shouldAlsoBeZero;
```

### 5.2 Boundary behaviour

```sql
-- rows outside the window are targeted, rows inside are untouched
SELECT
    SUM(CASE WHEN createdUtc <  DATEADD(DAY, -90, GETUTCDATE()) THEN 1 ELSE 0 END) AS wouldPurge,
    SUM(CASE WHEN createdUtc >= DATEADD(DAY, -90, GETUTCDATE()) THEN 1 ELSE 0 END) AS wouldKeep
FROM [AI].[fieldOutcome];
```

Run this **before** the first live purge, in every environment. It is the dry run, and a
destructive first-of-its-kind job deserves one.

### 5.3 Post-purge assertion

```sql
-- after a purge with a 90-day window, nothing older may remain
SELECT COUNT(*) AS mustBeZero
FROM [AI].[fieldOutcome]
WHERE createdUtc < DATEADD(DAY, -90, GETUTCDATE());
```

### 5.4 Definition of Done — split, per Finding 1

**Part A — the mechanism (deliverable now):**

- [ ] `AI.usp_purgeFieldOutcome` created in Procs2/ with rule-6 naming, header block, Jira key
- [ ] The procedure fails closed on NULL, `0` and negative windows — a test covers all three
- [ ] Deletion is **batched**; a test or review confirms no unbounded single-statement DELETE
- [ ] Re-runnable release script created under Scripts/Script.&lt;DDMonYYYY&gt;/ with the Jira key
- [ ] **Both** files registered in the `.sqlproj` (`<Build>` + `<None>`) — rule 5
- [ ] Release harness run; `PASS` verdict, no duplicate-object hit
- [ ] Procedure exposed through `pacehr_devContextProcedures` / `Ipacehr_devContextProcedures`
- [ ] Job class in `PacEHR.Functions.Process/lib/` reads retention into a **nullable** type and
      refuses on unset — a test asserts a missing setting purges **zero** rows and logs a named
      refusal. **This is the single most important test in the story**: the naive
      `GetValue<int>` idiom would return 0 and purge everything.
      **If 0.4a instead selects the TypeScript host**, the equivalent is class
      `FieldOutcomeRetentionPurger` with its `purge()` method in
      `src/jobs/fieldOutcomeRetention.ts`, reading `AI_FIELD_OUTCOME_RETENTION_DAYS` through
      the zod schema in `src/core/settings.ts` as
      `z.coerce.number().int().positive().optional()` — **`.optional()`, never `.default(0)`** —
      and the test is a **vitest** test asserting the same zero-rows-plus-named-refusal
      behaviour. The requirement is identical in both runtimes; only the idiom that would
      break it differs.
- [ ] A test asserts the refusal log line names the missing setting and contains **no row
      content** — reviewed against CLAUDE.md § Clinical and PHI rules. `AI.fieldOutcome` holds
      clinical values, so a purge log must never echo them.
- [ ] Tests cover: rows older than the window are targeted; rows inside are excluded
- [ ] **The purge predicate is `createdUtc` age alone** — a test asserts that a row past the
      retention horizon with `decidedAtUtc IS NULL` **is** purged. Per Finding 14, keying on
      decision state would skip the majority of rows forever, and the row count would still
      go down, so it would look like it worked
- [ ] The job class is invocable standalone with no scheduler dependency; the timer-trigger
      class is a separate type that only delegates (epic's explicit requirement)
- [ ] The 10.95M-rows/year arithmetic and its source line
      (`pacEHR-Encounter-Agent-4Pager.md` line 111) recorded as a comment — CLAUDE.md § Numbers
- [ ] The hard-DELETE-over-soft-delete decision is stated in the PR **with reasons** (§3.3)
- [ ] The PR states that the purge is **not enabled** and will refuse until B7 is answered
- [ ] PR title, branch name and commit message all carry the literal Jira key; one concern per PR
- [ ] PR checklist complete: unit tests · DB script · technical documentation · AI usage

**Part B — enablement (blocked; do not mark this story done on Part A alone without saying so).**
⚠️ **Revision 4: track Part B as an open compliance exposure with a named owner, not as a
backlog item waiting on a dependency.** Per Finding 13, until Part B completes the purge
never runs and PHI accrues with no erasure path. Those two framings reach different people
and produce different response times.

- [ ] B7 answered by a named data owner, with the number and its rationale recorded
- [ ] The same number applied to the **self-hosted trace store**, not only to
      `AI.fieldOutcome` (Finding 11) — otherwise the policy is half-implemented and the
      remaining PHI is invisible because the table looks clean
- [ ] The refusal path escalates from warning to error after an agreed unset period
      (Finding 13), so a dormant purge is distinguishable from an undeployed one
- [ ] Epic 10's replay window established; retention confirmed strictly greater (§3.4)
- [ ] An assertion enforces that relationship and fails loudly if violated
- [ ] `PacEHR.Functions.Process` deployment path established (Finding 3)
- [ ] Timer function registered and deployed; the §5.2 dry run executed per environment
- [ ] First live purge verified with §5.3

---

## 6. Risk register

| # | Risk | L | I | Mitigation |
|---|------|---|---|------------|
| 1 | **B7 never answered; story sits "done" but purge never runs** | High | High | Split the DoD (§5.4); assign 0.1 to a named data owner |
| 2 | **`GetValue<int>` returns 0 and purges the whole table** | Med | **Critical** | Nullable read + `<= 0` guard in both SQL and C#; the §5.1 test |
| 3 | Functions project has no deployment path in this repo | High | High | Finding 3; answer 0.3 before Phase 2 |
| 4 | Purge deletes Epic 10's replay inputs silently | Med | High | §3.4 assertion; nothing errors when this goes wrong |
| 5 | Unbatched DELETE escalates to a table lock on 11M rows | Med | High | §3.1 batching |
| 6 | Hard DELETE reverted to soft delete by a reviewer following house convention | Med | Med | §3.3; document the reasoning in the PR |
| 7 | First destructive retention job in the product; no precedent | Med | High | §5.2 dry run in every environment before enabling |
| 8 | Refusal is a log line nobody reads | High | Med | Add `AI.purgeRunLog` (§2.2) |
| 9 | Purge host undecided → guard built in the wrong language, or twice | Med | Med | 0.4a; §1 Finding 9 recommends the .NET Functions host |
| 10 | `.sqlproj` registration missed → procedure silently never deployed | Med | High | Manifest test; harness verdict |
| 11 | Purge runs before PEA-203's table exists | Low | Low | Guard the release script; sequence the stories |
| 12 | Retention set too short; clinical audit trail destroyed | Low | **Critical** | 0.1 must be a data-owner decision, never a developer default |
| 13 | **Retention answered for the SQL table only; the self-hosted trace store keeps the same PHI indefinitely** — invisible, because the table looks clean | High | High | §1 Finding 11; 0.8 needs an owner |
| 14 | Q5 / B7 restated in a third document instead of being escalated → still unowned in six months | **High** | High | §1 Finding 10; action 1 must name a person, not a role |
| 15 | 🔴 **B7 now unowned across four documents** — [00-source-index.md](solution-doc:5092) Table B lists it with **no owner at all**, a regression from doc 3777's nomination of Compliance | **High** | **High** | Finding 12. Four documents have deferred it politely; a fifth will not resolve it. Track outside the engineering backlog |
| 16 | 🔴 **Correct, dormant, and accruing PHI** (GAPS Gap 10) — the fail-closed guard guarantees the purge never runs while B7 is unset, so ~11M rows/year of clinical content accrue with no erasure path | **High** | **High** | Finding 13. Treat the enablement half of the DoD as an open compliance exposure with an owner, not a backlog item. Consider escalating the refusal from warning to error after an agreed period |
| 17 | 🟠 **A "resolved-only" purge predicate would skip the majority of rows forever** (GAPS Gap 25) — auto-committed rows never acquire a decision | Med | **High** | Finding 14. Purge on `createdUtc` age alone, as the epic specifies. Add a test asserting an undecided row past the horizon **is** purged — this exists to stop a well-meaning "improvement" |
| 18 | 🟡 **Rows destroyed with no record of their destruction** (GAPS Gap 17) — "delete batch" and "log the run" are two statements with no transaction primitive | Med | Med | Finding 15. A non-issue in the .NET Functions host (another argument for Finding 9's recommendation). In the TypeScript service it needs the Epic 01 primitive — node-mssql's `Transaction` object makes it cheap to build, but it must be designed into `src/core/database.ts`. Raise once for PEA-202/203/204 together |
| 19 | 🟡 **Retention setting configured in two places** — the TypeScript service's `src/core/settings.ts` owns `AI_FIELD_OUTCOME_RETENTION_DAYS` (zod-validated at module load, `z.coerce.number().int().positive().optional()`, fail-closed when absent), but the .NET Functions host may read the same value from its own configuration | Med | **High** | One must be authoritative. Two disagreeing retention periods is worse than none: whichever is shorter silently wins, and nobody knows which one ran. Note the two runtimes validate differently — zod refuses to start on a malformed value, .NET binding may coerce it — so "the same setting" is not the same guarantee |

**On the estimate.** 2 points is right for Part A. Part B is not engineering work at all — it
is a decision plus a deployment answer. Tracking them as one story is how this ends up
perpetually 90% done.

---

## 7. Recommended immediate actions

1. **Assign B7 to a named individual with a date — not to "Compliance".** This is the whole
   story. It is a clinical and compliance question about derived clinical content, and no
   engineer can answer it. **Escalate it rather than restate it:** the identical question is
   already open as Q5 in [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777)
   §16, nominally owned by Compliance, and has been unanswered since September (§1 Finding 10).
   A role-level owner has already been tried and did not produce an answer.
   **Revision 4 strengthens this to the point of urgency:** the question is now open in a
   *fourth* document, and the most recent one — [00-source-index.md](solution-doc:5092)
   Table B — lists it with **no owner at all**. That is movement backwards. Frame the
   escalation using [GAPS.md](solution-doc:5089) Gap 10's language rather than this spec's:
   the issue is not "a configuration value is missing", it is **"PHI-bearing clinical
   content is accruing at ~11M rows per year with no erasure path."** The first framing has
   been ignored four times; the second is a compliance finding and will be read by a
   different audience.
2. **Scope the retention answer to the trace store as well.** Per §1 Finding 11, evidence spans
   are PHI and doc 3777 §12 puts them in a self-hosted trace store that no story purges. When
   B7 / Q5 is answered, it must be applied to both stores — otherwise the policy is
   half-implemented and the gap is silent.
3. **Confirm which host runs the purge** (0.4a). §1 Finding 9 recommends the existing .NET
   Functions timer host on the grounds that a scheduled DELETE is database maintenance, not AI
   decisioning — but Architecture should record the decision, because it determines which
   language's fail-closed guard is built and tested.
4. **Ask DevOps how `PacEHR.Functions.Process` reaches its environments.** Five live timer
   functions are running from a project no pipeline in this repository deploys. That gap is
   worth knowing about independently of this story.
5. **Establish Epic 10's replay window** and record the "retention > replay" constraint before
   B7 is answered, so the answer is bounded correctly from the start.
6. **Flag the zero-retention trap in code review guidance now**, in whichever language wins.
   Risk 2 is the one defect in this story that would be catastrophic and is a single keystroke
   away — `GetValue<int>` in .NET, and in TypeScript a zod schema written
   `z.coerce.number().int().default(0)` instead of `.optional()`. Both turn "nobody
   configured this" into "delete everything eligible". Per §1 Finding 7, the guard
   specification is host-independent; do not wait on 0.4a to write the test.
7. **Add `AI.purgeRunLog`** on the `patientAlertJobLog` pattern so the fail-closed behaviour is
   auditable rather than merely logged. **Revision 4 raises the value of this item:** given
   Finding 13 (the purge is likely dormant for a long time), the run log is the only artefact
   that will distinguish "the mechanism is working and correctly refusing" from "the
   mechanism was never deployed." Those look identical today.
8. 🟡 **Escalate the refusal path after an agreed period** (Finding 13). A guard that
   silently declines to run is indistinguishable from one that is broken. Log at error
   rather than warning once B7 has been unset for longer than some agreed window, and
   surface it where operational alerts are seen. Cheap, and it converts a silent compliance
   exposure into a visible one.
9. 🟠 **Fix the purge predicate now, in writing** (Finding 14, GAPS Gap 25). Purge on
   `createdUtc` age alone — never on decision state. Add the DoD item and the test asserting
   an undecided row past the horizon **is** purged. This exists to stop a reviewer
   "improving" the predicate into one that skips most of the table.
10. **Decide where the retention setting is authoritative** (risk 19). The TypeScript
    service's `src/core/settings.ts` owns `AI_FIELD_OUTCOME_RETENTION_DAYS` per the corpus
    mapping; the .NET Functions host is the recommended runner per Finding 9. Pick one
    source of truth and make the other read from it — and note the two runtimes do not
    validate identically, so "both read the same env var" is not sufficient.
8. **Correct the record on Epic 11.** A working timer-trigger host already exists with five
   live jobs and shared DB access — Epic 11's scheduling scope is smaller than assumed, and
   that is worth re-estimating.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/PacEHR.Functions.Process/Program.cs` - Lines 10–22: isolated worker host, `GetConnectionString("PACEHR-DB")`, scoped registration of the shared procedures interface. The purge job's home and wiring template.
- `pacEHR_API/PacEHR.Functions.Process/PacEHR.Functions.Process.csproj` - Lines 3–21: net8.0, Functions v4, Timer extension 4.3.1 — proves the scheduler host is real.
- `pacEHR_API/PacEHR.Functions.Process/DailyEmailFunction.cs` - Line 20: the timer-trigger pattern to copy for a nightly purge.
- `pacEHR_API/PacEHR.Functions.Process/lib/ScheduleTFAJob.cs` - Lines 12–21: job class injecting `Ipacehr_devContextProcedures` and calling a stored procedure — the exact shape the purge job takes.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Job-run log prior art, and the `DEFAULT (getutcdate())` house form at line 11.
- `pacEHR_API/CLAUDE.md` - Rules 4, 5, 6 (scripts, registration, proc naming), § Numbers, § Clinical and PHI rules.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_deleteAiPrompt.sql` - Lines 13–21: the soft-delete convention this story deliberately departs from.
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - How configuration is actually resolved here (DB app settings + `appsettings.json` fallback) — the basis for §3.2.

**Solution documents consulted at Revision 4** (the Python Epic corpus — not repository files, so not drift-tracked here): GAPS.md (5089), epic-02-data-layer.md (5077), 00-source-index.md (5092), README.md (5090), epic-01-foundation.md (5099), CLAUDE.md (5093).
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest; rule-5 silent-failure surface.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The actual deployment mechanism for the procedure.

### Medium Relevance
- `pacEHR_API/PacEHR.Functions.Process/host.json` - Line 2 confirms Functions v4 host config.
- `pacEHR_API/pacEHR.sln` - Line 35 confirms the Functions project is in the solution and builds.
- `pacEHR_API/PacEHR.Functions.Process/DailyCCMBHFunction.cs` - Line 24, second live timer trigger.
- `pacEHR_API/PacEHR.Functions.Process/EveryFiveMinutesFunction.cs` - Line 23, third live timer trigger.
- `pacEHR_API/PacEHR.Functions.Process/HourlyEmailFunction.cs` - Line 19, fourth live timer trigger.
- `pacEHR_API/PacEHR.Functions.Process/TwiceDailyEmailFunction.cs` - Line 21, fifth live timer trigger.
- `pacEHR_API/PacEHR.Functions.Process/DailyForTFAFunction.cs` - Lines 8–34: fully commented out; not a template.
- `pacEHR_API/PacEHR.Functions.Process/lib/EmailEncounterJob.cs` - Lines 18–25, second example of the DI job-class shape.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_finishPatientAlertJobLog.sql` - Line 26, how a job-run log row is closed.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getPendingEmailDeliveryStatus.sql` - Line 19, date arithmetic used for reads only — evidence of no purge precedent.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getPatientDetailsData.sql` - Lines 50–51, 70–71, further read-only lookback evidence.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_deleteNormals.sql` - Line 16, hard delete commented out in favour of soft delete.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` - `isDeleted BIT` on the AI schema's own existing table.

### Low Relevance
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/pcc_insertDiagnosticReport.sql` - Lines 44–47, existing DELETEs are transactional child cleanup, not retention.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_DeleteEncounterCPT.sql` - Line 27, same pattern.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditUser.sql` - Line 331, same pattern.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getDashBoardSchedulerEvent.sql` - Line 63, read-only date window.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14, CHECK-constraint style if `AI.purgeRunLog` is added.
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The partial class the purge procedure must be exposed through.
- `pacEHR_API/pipelines/` - 12 files; searched and confirmed to contain no Functions deployment and no database deployment.
- `pacEHR_API/PacEHR.Functions.Process/readme.md` - Timer-trigger cron documentation for the project.
