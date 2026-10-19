# PEA-205 Tech Spec — AI.promptFragment (Versioned Prompt Composition)

**Epic:** E2 — Data Layer · **Story:** PEA-205 · **Phase:** 1
**Depends on:** PEA-201 · **Satisfies:** REQ-02-01, REQ-02-07, REQ-02-09
**Epic estimate:** 3 points · **Audited estimate:** **3 points for the table alone; 13+ for the story as written** — see §6
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — audited against the live codebase, evidence-backed, **re-estimate before committing**
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
> new standalone repository (not yet created; not ingested into this solution), **ported from
> the existing Python service `pacEHR_AI/`**. No
> existing C# AI logic is reused. The runtime chain is: Angular → .NET Web API → TypeScript
> AI service → Azure OpenAI. The DDL for `AI.promptFragment`, the versioning semantics and
> all acceptance criteria are **language-neutral** — the table lands in the same SQL Server
> instance regardless of which service reads it. Only the repository layout, driver library,
> validation library and test framework sections are expressed in TypeScript terms.
> **The team-space copy of this epic's design is the Python reference design and is
> deliberately unmodified.**

> **Read this first.** The epic describes this story as creating a new table. It is not. It
> **replaces a shipped, in-production feature** that has its own admin UI, four stored
> procedures, a live precedence engine, and a foreign-key-like dependency from the template
> editor. Nothing in the epic's 3-point scope accounts for any of that. §1 Findings 1, 2 and 3
> are the story.

---

## 1. Findings — what the audit changed

| # | Finding | Severity | Effect on this story |
|---|---------|----------|----------------------|
| 1 | **`AI.prompt` already exists and is in production** with four live procedures | 🔴 critical | This is a replacement, not a greenfield table |
| 2 | **`usp_getPrompt.sql` is a live 3-tier precedence engine** this table must replicate | 🔴 critical | The hardest part of the story, unmentioned in the epic |
| 3 | **`Template.encounterTempletes.promptId` binds prompts to templates** | 🔴 critical | Blast radius reaches the template editor |
| 4 | **An admin UI for prompts already ships** — and has no version/history/rollback concept | 🔴 critical | REQ-08-14's A-B compare needs UI that does not exist |
| 5 | **No evaluation concept exists anywhere** — `passedEvaluation` has no writer | 🟠 high | The column is dormant until Epic 10 |
| 6 | Composite UNIQUE with a nullable column — **precedent exists but semantics differ in T-SQL** | 🟠 high | §3.3; the epic's constraint does not do what it looks like |
| 7 | `promptFragment` name is **free** | ✅ closed | — |
| 8 | Role gating today is a **raw integer check in a component**, not a permission | 🟠 high | The grant design has no UI-side counterpart |
| 9 | Grants/roles do not exist (inherited) | 🔴 blocker | `aiPromptAdmin` must be created |
| 10 | **No Python application exists in this repository today** — but an approved architecture specifies exactly such a service (see [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §3.1); the residual blockers are narrower (see Finding 10 detail below) | 🟠 high | Orchestrator sequencing; DDL unaffected either way |
| 11 | `DEFAULT SYSUTCDATETIME()` → `DEFAULT (getutcdate())` | 🟡 medium | §3.2 |
| 12 | The four-value `passedEvaluation` design is **right** | ✅ endorsed | Defend it in review |
| 13 | **The live `AI.prompt` data is audited and carries 13 catalogued defects** — contradictory rules, garbage rows, copy-paste forks, all live | 🔴 critical | Migration must not carry them forward; Finding 13 (detail) |
| 14 | **Precedence is no longer fully open — a written target rule exists** (`Organization-Universal > Organization > System-Universal > System`) | ✅ narrows Finding 2 | Parity must be measured against *two* baselines; Finding 14 (detail) |
| 15 | **The approved composition has six layers (L0–L5); this table's `kind` has four values** and they do not line up | 🟠 high | Reconcile before the CHECK constraint ships; Finding 15 (detail) |
| 16 | **`passedEvaluation` has a designed writer after all** — §6.4 requires an eval set per fragment and blocks promotion on regression | ✅ strengthens Finding 5 | 0.2 has an approved answer; Finding 16 (detail) |
| 17 | **205c (versioning/diff/rollback UI) appears in neither document's roadmap** | 🟠 high | Genuine ownership gap; Finding 17 (detail) |

---

### Finding 1 (detail) — what is already live

The `AI` schema is not new and `AI.prompt` is not a stub.

**The table** — `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql`, line 1 is
`CREATE TABLE [AI].[prompt]`:

| Column | Type | Note |
|---|---|---|
| `promptId` | `INT IDENTITY` | PK |
| `prompt` | `NVARCHAR(MAX)` | the text |
| `promptName` | `NVARCHAR(255)` | |
| `description` | `NVARCHAR(100)` | |
| `type` | `NVARCHAR(255)` | the closest thing to the new `kind` |
| `templateId` | `INT` | |
| `accountId` | `INT` | the tenant — **same spelling the new table uses** |
| `isUniversal` | `INT` | the closest thing to the new `scope` |
| `isActive` | `INT` | note: `INT`, not `BIT` |
| `isDeleted` | `BIT` | |
| `createdBy` / `modifiedBy` | `INT` | |
| `createdDate` / `modifiedDate` | `DATETIME2(7)` | |

**Four live stored procedures**, all in `Stored Procedures/Procs1/`:

| Procedure | Role |
|---|---|
| `usp_addEditAiPrompt.sql` | upsert from the admin UI |
| `usp_getAiPrompts.sql` | admin list |
| `usp_deleteAiPrompt.sql` | soft delete (`isDeleted = 1`, lines 13–21) |
| **`usp_getPrompt.sql`** | **the runtime reader** — see Finding 2 |

The epic says the legacy blob is "taken off the runtime path entirely at migration"
(REQ-08-09). That is a correct goal and a substantial piece of work: four procedures, an
Angular admin feature, and a template-editor dependency all point at this table.

### Finding 2 (detail) — the precedence engine the new table must replicate

`pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getPrompt.sql` is 67 lines and is
the live prompt-resolution logic. Signature:
`CREATE PROCEDURE [dbo].[usp_getPrompt] @userId INT, @accountId INT, @encounterId INT`.

It resolves in three tiers, first match wins:

| Tier | Rule | Source |
|---|---|---|
| 1 | **Template-specific** — join `Encounter.encounter` → `Template.encounterTempletes.promptId`; if that `AI.prompt` row is active, return it | most specific |
| 2 | **Account-specific** — `accountId = @accountId AND isUniversal = 1` | tenant override |
| 3 | **Universal** — `accountId = 0 AND isUniversal = 1` | global default |

It is called from `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` at lines 95–97.

**This is the crux of the story and the epic does not mention it.** `AI.promptFragment`'s
`kind` / `scope` / `accountId` columns must express this precedence — or deliberately replace
it — and the mapping is not clean:

| Live concept | New column | Fit |
|---|---|---|
| tier 3, `accountId = 0 AND isUniversal = 1` | `scope = 'global'` | ✅ clean |
| tier 2, `accountId = @accountId AND isUniversal = 1` | `scope = 'account'`, `accountId` set | ✅ clean |
| tier 1, `encounterTempletes.promptId` | `kind = 'template_override'` | ❌ **broken — see below** |

**The gap:** the live tier-1 lookup is keyed by a `promptId` stored *on the template row*.
The new table has no template column at all. `kind = 'template_override'` says a fragment *is*
a template override, but nothing says *which template*. With only
`UNIQUE (kind, scope, accountId, version)`, there can be exactly **one** active
`template_override` per scope — not one per template.

Three ways out:

| Option | Change | Cost |
|---|---|---|
| A | Add `templetID INT NULL` to the table and to the unique key | small DDL change now; matches live behaviour |
| B | Keep tier 1 on `Template.encounterTempletes.promptId` pointing at legacy `AI.prompt` | fragments and legacy coexist indefinitely — contradicts REQ-08-09 |
| C | Drop per-template prompts entirely | a product decision, not an engineering one; **must not be made silently** |

**Recommendation: option A**, plus an explicit product confirmation. Option C may well be the
intent — Epic 8's composition model may supersede per-template prompts — but that is a
feature removal affecting a shipped capability and needs to be decided, not defaulted into by
a column that was never added. Note that tier 1 and the `isUniversal` flag mean per-template
prompts are *in use*, so C has migration consequences.

### Finding 3 (detail) — the template-editor blast radius

`promptId` is a column on `Template.encounterTempletes`
(`pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql`), and it is actively
read and written:

- **Written** by `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditTemplate.sql` — lines 32, 54, 70, 106
- **Read** by `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getEncounterTemplateList.sql` — lines 22, 29
- **Resolved at runtime** by `usp_getPrompt.sql` tier 1

`encounterTempletes` also carries `ambientPrompt VARCHAR(255)` and `ambientFlag BIT` — a
second, separate prompt surface that the epic does not mention at all. Whether ambient prompts
also become fragments is an open question this spec cannot answer.

So retiring `AI.prompt` touches the template save path, the template list path, and the
runtime resolution path. None is a large change individually; together they are well beyond
3 points, and each is a regression risk on a shipped feature.

### Finding 4 (detail) — the admin UI exists, and lacks everything this story assumes

Two Angular components ship today:

| File | Lines | Content |
|---|---|---|
| `PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` | 194 | list view; `userFilter: {promptName:''}` line 25; `typeList` lines 53–58; `statusList` lines 60–63 |
| `PacEHR/src/app/features/ai-prompt/add-edit-ai-prompt/add-edit-ai-prompt.component.ts` | 112 | edit form; controls at lines 64–71 — `promptName`, `prompt`, `isActive`, `createdBy`, `promptId`, `type` |

Service: `PacEHR/src/app/core/services/prompt.service.ts` — `getAIPromptList`,
`addEditAIPrompt`, `deleteAIPrompt`. The list is opened as an `NgbModal` from
`PacEHR/src/app/features/settings/template-editor/template-editor.component.ts` line 19 —
i.e. prompts are edited *from inside the template editor*, reinforcing Finding 3.

**A search across all of `PacEHR/src/app` for "prompt studio", `promptStudio`, `fragment` and
`promptFragment` returns zero matches.** And in the existing UI there is **no concept of**:
version · history · diff · rollback · preview · test run · evaluate · approve.

The new table is explicitly designed to support those — "every version stays addressable so
Epic 8 can roll back or A-B compare (REQ-08-14) without deleting rows." That capability is
worthless without a UI, and no UI exists. Building version history, diff and rollback is a
feature in its own right, comfortably 8+ points on its own.

**This story creates the storage for a feature nobody has scoped the front end for.** That is
defensible if stated. It is not defensible at 3 points with a DoD that implies the capability
works.

### Finding 5 (detail) — `passedEvaluation` has no writer

The four-value `PENDING_EVAL` / `PASSED` / `BLOCKED` / `INCOMPLETE` verdict is a genuinely
good design decision and should be defended: "never evaluated" is not the same as "evaluated
and failed," and collapsing them into a `BIT` would make the gate fail *open* for anything
never tested. Defaulting to `PENDING_EVAL` and having Epic 8's gate resolve only `PASSED`
means every other state fails closed. That is correct.

But: Epic 10's evaluation gate (PEA-1008) is the writer, and Epic 10 does not exist. No
evaluation harness, no test-run concept, nothing in the codebase writes an evaluation verdict.
So in Phase 1 **every row will sit at `PENDING_EVAL` forever**, and if Epic 8's gate is
implemented faithfully, **no fragment will ever be usable**.

This is a sequencing trap with a pleasant-looking exit (default to `PASSED`) that would
destroy the design's entire value. Do not take it. The honest resolutions are: land this table
and do not switch the runtime over until Epic 10 exists; or add an explicit, audited manual
approval path that sets `PASSED` with a recorded approver. **Recommend the latter** — it keeps
fail-closed semantics, is small, and unblocks Phase 1 without lying.

### Finding 10 (detail) — the AI application exists in `pacEHR_AI/` (Python); sequencing is the real blocker

No AI application exists in this repository today — the repository is .NET 8 + SSDT + Angular. **However, this does not mean the epic is in error about the overall architecture.** The [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) (status: Design / approved for planning) §3.1 defines a new component — "AI Orchestrator · NEW" — comprising an Ingest Gateway, a Pipeline, and a Prompt + Config Registry. That document states explicitly: "The .NET API keeps owning auth, persistence and the existing contract. The orchestrator owns AI decisioning only." **By owner decision the orchestrator is now a TypeScript/Node.js service, not Python** — the team-space architecture documents describe the Python reference design and remain unchanged, but the build target for this solution is TypeScript. [Phase 1](solution-doc:3776) describes the reference implementation specifics (Pydantic models, LangGraph pipeline); the TypeScript equivalent is a new standalone repository yet to be created.

So the residual blockers are:

1. Does the orchestrator exist yet in any deployed form? **No — and not even in undeployed
   form.** There is no TypeScript repository, no skeleton, no pipeline.
2. Is it staffed and scheduled, and is Epic 02 sequenced before or after it?
3. Who owns the orchestrator's prompt-reading integration with `AI.promptFragment`?
4. **Who builds the Epic 01 equivalent?** This story's reader depends on a `src/core/`
   foundation — `settings.ts` (zod), `database.ts` (node-mssql), `llm.ts`, `errors.ts`,
   `logging.ts`, `auth.ts` — none of which exists. The Python corpus's Epic 01 is a
   *specification* for that foundation, not an implementation of it, and the Python-specific
   library allow-list in [00-langchain-api-truth.md](solution-doc:5091) does not govern a
   Node runtime at all; a TypeScript equivalent has to be authored. This **raises** the
   Epic 01 dependency risk relative to the Python plan rather than lowering it.

**The DDL is unaffected either way.** Doc 3777 §3.1 places the AI tables in the same SQL Server instance as Template.\* and Log.AILogs — the `AI.promptFragment` table lands in SQL Server regardless of which service reads it. The Phase 0 platform question (0.7) is no longer "which language?" — that is decided — but **"is the TypeScript service ready to consume this table, and if not, what is the interim .NET read path?"** Given that the TypeScript repository does not exist yet in any form, the honest planning assumption is that the interim .NET read path is not a contingency but the **first** consumer, and should be scoped as such rather than treated as a fallback nobody expects to need.

---

### Finding 13 (detail) — the data this table inherits has already been audited, and it is bad

Doc 3777 §1.3 audits **all 25 rows** of the live `AI.prompt` table and catalogues **thirteen
defects, D1–D13**. This is the single most useful thing the architecture review contributes to
PEA-205, because §4.5's backfill (step 10) takes exactly these 25 rows as its input. Migrating
them faithfully means migrating the defects faithfully.

The ones that bear directly on this story:

| Ref | Defect | Why it matters to the migration |
|---|---|---|
| **D1** | **Contradictory live rules.** Prompt id 1 says "Always return NA if you are not sure"; prompt id 2 rule 7 says "do not add N/A…". Both active | Two active prompts give the model opposite instructions on the same question. A backfill that preserves both preserves the contradiction, now spread across two fragments |
| **D3** | A prompt contains the literal string `Consider Place of Service is "Dynamic Location"` sitting beside a raw `&lt;&lt;encounterPOS&gt;&gt;` slot | Authored text and unsubstituted slot markers are already mixed in live data. The fragment model must decide which is which at migration time |
| **D7** | **Copy-paste forks.** Prompt ids 8, 10, 20 and 21 are near-identical; **10 and 20 are both active** | Naively backfilled, these become four fragments at `version = 1` with no relationship between them — the version history starts out already meaningless |
| **D9** | **Unescaped slot injection** via `&lt;&lt;templateName&gt;&gt;` | A live injection surface carried into the new table unless the migration escapes or rejects it |
| **D10** | **Live garbage.** `sdwdxs` (id 18), `rfvdytvfgvcyt` (id 17), `...` (id 15), `esfsaf@#` (id 22) — all `isActive = 1, isDeleted = 0` | Four of 25 rows are test junk that reached production. **16% of the corpus is noise.** Nothing validated prompt content on authoring, which is why they are there |
| **D13** | **Undefined precedence** between `isUniversal`, `accountId = 0`, and the four `type` values | Finding 2 reverse-engineered the precedence from `usp_getPrompt.sql`; §1.3 confirms independently that it was never specified. See Finding 14 |

**Three consequences for §4.5 step 10:**

1. **The backfill is a cleanup, not a copy.** Add an explicit triage step before the insert:
   which of the 25 rows migrate, which are retired, which are merged. D10's four garbage rows
   should not become fragments at all, and D7's four forks are at most one fragment with a
   version history. Done properly the 25 rows probably become fewer than 15 fragments.
2. **D1 must be resolved by a human, not by the migration.** Two contradictory active rules
   cannot both be right; picking one is a clinical-content decision. Route it to whoever owns
   prompt content, and do not let the migration silently preserve both.
3. **This is the strongest possible argument for authoring validation** on the new write path
   (§4.4 step 7). D10 exists because nothing checked. §6.4 specifies the validation rules —
   minimum length, a task marker, at least one slot, and no unresolved `&lt;&lt;…&gt;&gt;` —
   and they should ship with `usp_addEditPromptFragment`, not later.

None of this changes the DDL. It changes what Phase 4 has to do, and it is more evidence for
the §6 re-estimate: a backfill you have to triage row by row is not a script you write in an
afternoon.

### Finding 14 (detail) — the precedence question is narrower than Finding 2 assumed

Finding 2 treated the precedence rule as something to be reverse-engineered from
`usp_getPrompt.sql` and replicated. That is still necessary but no longer sufficient, because
doc 3777 §6.4 **specifies a target precedence in writing**:

> `Organization-Universal > Organization > System-Universal > System`, ties broken by
> `accountId`, then by most recent version.

Note that this is expressed in the *four `type` values* of the existing admin UI (Finding 4's
`typeList` at `ai-prompt.component.ts` lines 53–58), not in the three tiers
`usp_getPrompt.sql` actually implements. So there are now **two baselines**, and they are not
obviously the same rule:

| | Live behaviour | Written target |
|---|---|---|
| Source | `usp_getPrompt.sql` tiers 1–3 | doc 3777 §6.4 |
| Keyed on | `encounterTempletes.promptId`, then `accountId` + `isUniversal` | the four `type` values |
| Template-specific tier | tier 1, first match wins | **not present in the stated ordering** |
| Tie-break | none stated; `TOP 1` by whatever order the query yields | `accountId`, then most recent version |

**This materially changes §5.4's parity gate.** The gate as written compares the new
composition against current live behaviour. But if §6.4 is the approved target and it differs
from live behaviour, then passing the parity gate means **faithfully reproducing behaviour the
architecture intends to change** — and failing it may be correct.

**Recommendation: run the parity comparison against both baselines and classify every
difference.** For each template in §5.4's list, record: matches live / matches §6.4 / matches
neither. A difference that moves toward §6.4 is an intended change and needs sign-off as such.
A difference that matches neither is a bug. Shipping without that classification means nobody
can tell the two apart afterwards.

Also note what §6.4 does **not** address: the template-specific tier. The written ordering has
no slot for "this prompt belongs to this template," which is Finding 2's whole problem. That
is either an omission in §6.4 or evidence that option C (drop per-template prompts) is the
architectural intent. **Ask directly** — 0.1 now has a second input, and if per-template
prompts are genuinely going away, Finding 2's `templetID` column may be unnecessary.

### Finding 15 (detail) — four `kind` values versus six composition layers

§3.1's CHECK constrains `kind` to four values: `contract`, `task`, `specialty`,
`template_override`. Doc 3777 §6.1 defines a six-layer composition:

| Layer | Name | Corresponding `kind` |
|---|---|---|
| L0 | Contract | `contract` ✅ |
| L1 | Task | `task` ✅ |
| L2 | Specialty | `specialty` ✅ |
| L3 | Field manifest | — **generated**, not a stored fragment |
| L4 | Constraint digest | — **compiled** from `AI.fieldConstraint`, not a stored fragment |
| L5 | Runtime facts | — typed and escaped at call time, not a stored fragment |
| — | — | `template_override` — **no layer** |

The first three line up exactly, which is a good sign: the epic's vocabulary and the
architecture's were clearly derived from the same thinking. L3, L4 and L5 legitimately have no
`kind` because they are not authored fragments — they are generated, compiled and runtime
respectively. That is consistent, not a gap.

**The gap is in the other direction: `template_override` has no layer.** The same shape of
problem PEA-207 has with `AI.fieldDescription` (see that spec's Finding 13). A fragment whose
`kind` is `template_override` is authored prompt text with no defined position in the
composition, so nothing says where in the assembled prompt it lands or what it takes
precedence over.

This reinforces Finding 14's reading: the architecture may simply not intend per-template
prompt overrides to survive. **Do not resolve this by adding a fifth `kind`.** Resolve it in
0.1 as a product question, and note that all three signals — §6.4's ordering, §6.1's layers,
and the absence of any template concept in either — point the same way.

**Practical consequence for the DDL:** if 0.1 lands on option C, both `templetID` and the
`template_override` `kind` value come out of §3.1, and `CK_promptFragment_templateKind`
disappears with them. That is a simpler table. **0.1 should therefore be answered before the
DDL is written**, not in parallel with it.

### Finding 16 (detail) — `passedEvaluation` has a designed writer after all

Finding 5 concluded that nothing writes `PASSED`, that Epic 10 is the intended writer, and
that a manual audited approval path is the honest interim. That reasoning stands — but 0.2 is
no longer an open architectural question. **Doc 3777 §6.4 specifies the mechanism:**

> Every fragment is bound to an eval set, and promotion requires no regression.

So the approved model is: a fragment carries an associated evaluation set, and it cannot be
promoted to active use unless it runs against that set without regressing. That is precisely
what `passedEvaluation = 'PASSED'` is meant to record, and it confirms the four-value design
(Finding 5) is aligned with the architecture rather than merely defensible.

Two things follow:

1. **The "default to `PASSED`" shortcut is now explicitly contrary to an approved design**,
   not just a bad idea. Finding 5 called it a trap; it is also a deviation someone would have
   to sign off. That is a stronger position to argue from in grooming.
2. **§6.4 implies a table this story does not create.** "Bound to an eval set" means a
   relationship between a fragment version and a set of evaluation cases. `AI.promptFragment`
   has no column for it and Epic 2 defines no eval-set table. That is Epic 10's to build, but
   the *binding* will need a column or a join table on this side. Worth flagging now: adding a
   nullable `evalSetID INT NULL` later is cheap, but knowing it is coming is cheaper still.

Doc 3777 §14's Phase 1 exit criteria reinforce the same point from the roadmap side — the
phase does not exit on "the tables exist," it exits on demonstrated behaviour. A table full of
`PENDING_EVAL` rows nobody can promote does not meet that bar, which is an argument for
resolving 0.2 inside Epic 2 rather than deferring it to Epic 10.

### Finding 17 (detail) — nobody owns the versioning UI

§6's split proposes **PEA-205c** — versioning, history, diff, rollback and A-B comparison UI,
8+ points — and notes it may belong to Epic 8 rather than Epic 2.

Having read both architecture documents in full: **it appears in neither roadmap.** Doc 3777
§14's phased roadmap covers the sidecar service (specified there as Python; the build target
is now TypeScript/Node.js, which changes nothing about this gap), the agent pipeline, constraint seeding,
tracing and HITL. Doc 3776's Phase 1 scope covers the agent implementation and the HITL review
surface (its §5 mockup is per-field approve/edit/reject cards, not prompt administration).
Neither document describes a prompt-authoring or prompt-versioning UI at all.

Doc 3777 §6.4 *requires* the capabilities — immutable versioned fragments, precedence,
authoring validation, eval-bound promotion — but requires them as properties of the registry,
without naming anything that lets a human see or operate them. Combined with Finding 4's
finding that the shipped admin UI has no concept of version, history, diff or rollback, the
position is:

- the storage will exist (this story),
- the rules will exist (doc 3777 §6.4),
- and **no roadmap item builds the surface an administrator uses to exercise either.**

This is a genuine ownership gap rather than a defect in this story, and it is exactly the kind
of thing that is cheap to name in grooming and expensive to discover in Epic 8. **Recommend
raising it as a question to Architecture and Product jointly**, with the concrete framing:
*after this story ships, how does a prompt author create version 2 of a fragment, compare it
to version 1, promote it, and roll it back?* If the answer is "through the existing
`ai-prompt` admin UI," that UI needs the work Finding 4 describes. If the answer is "the
service's own tooling," that is a TypeScript-side deliverable nobody has listed — and it
lands in a repository that does not exist yet, so there is not even a place to put it.

Keep 205c in the split either way — an unscoped 8-point item that is visible is much safer
than one that is not.

### Finding 8 (detail) — role gating is not a permission

The epic's grants (`aiPromptAdmin` writes, `aiServiceRuntime` only reads) imply a permission
model. What exists is `userRole === 1` read from `sessionStorage` at
`PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` line 45. Role 1 sees all four
`type` options; everyone else gets Organization and Organization-Universal, pre-set to
'Organization' (line 59). There is no named permission constant and no route guard at the
component level.

So the DB-side grant design has no counterpart in the UI, and a client-side `sessionStorage`
check is not an authorisation boundary. If write access to prompt fragments is meant to be
restricted, that restriction must live server-side. Worth raising as a separate finding
regardless of this story's outcome.

---

## 2. Current state — verified inventory

### 2.1 Where prompts live today

| Surface | Location |
|---|---|
| Storage | `AI.prompt` (`pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql`) |
| Per-template binding | `Template.encounterTempletes.promptId` |
| Ambient prompt (separate) | `Template.encounterTempletes.ambientPrompt`, `ambientFlag` |
| Per-field prompt (separate again) | `Template.fields.prompt`, `.aiSummaryPrompt` — see PEA-207 |
| Per-section prompt | `Template.section.prompt` |
| Runtime resolution | `usp_getPrompt.sql`, called from `AIPromptServices.cs` lines 95–97 |
| Admin UI | `PacEHR/src/app/features/ai-prompt/` |
| Admin procedures | `usp_addEditAiPrompt`, `usp_getAiPrompts`, `usp_deleteAiPrompt` |

**There are at least five distinct prompt surfaces in this product.** A fragment-composition
model is a genuinely good answer to that sprawl — which strengthens the case for the story and
enlarges its true scope at the same time.

### 2.2 Name collision check

Case-insensitive search across all 2,834 `.sql` files: **`promptFragment` — 0 matches.** Free.

### 2.3 Constraint precedent

**CHECK constraints — 5 files.** House style is a named `CK_<table>_<col>` with an OR chain.
Closest analogue: `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql`
line 14 — `CONSTRAINT [CK_SpecialtyCarePathTemplate_stage] CHECK ([stage]='Discharge' OR [stage]='Subsequent' OR [stage]='Initial')`.
SSDT normalises `IN (...)` to an OR chain, so writing it pre-normalised avoids a spurious
first-deploy diff.

**UNIQUE constraints — two live forms.** Inline:
`pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` line 17 —
`CONSTRAINT [UQ_AccountAssessments] UNIQUE NONCLUSTERED ([accountID] ASC, [assessmentTemplateId] ASC)`;
also `ProviderAssignedFacility.sql` line 16. Separate unique index:
`SpecialtyCarePathTemplate.sql` line 26, `HL7Outbound_AuditLogs.sql` line 14,
`MedicationDiagnosisLink.sql` line 20.

**Date defaults.** `DEFAULT (getutcdate())` in table DDL:
`pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` line 11.
`SYSUTCDATETIME()` appears only inside procedures, **never in table DDL**.

### 2.4 How it ships

Inherited unchanged from PEA-201/202/203: no `dacpac` deployment (one `Database`-related hit
across 12 files in `pacEHR_API/pipelines/`, a comment in `kb-refresh.yml`); manual release via
`pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1` reading a git ref;
CLAUDE.md rule 5 registration in `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` or the
object is **silently never deployed**; rule 4 requires canonical file **and** re-runnable
release script; `.sqlproj` line 10 targets SQL Server 2022, not Azure SQL.

---

## 3. Proposed DDL

### 3.1 The table

```sql
CREATE TABLE [AI].[promptFragment] (
    [fragmentID]        INT            IDENTITY (1, 1) NOT NULL,
    [kind]              VARCHAR (20)   NOT NULL,
    [scope]             VARCHAR (10)   NOT NULL,
    [accountId]         INT            NULL,
    [templetID]         INT            NULL,
    [version]           INT            NOT NULL,
    [fragmentText]      NVARCHAR (MAX) NOT NULL,
    [isActive]          BIT            CONSTRAINT [DF_promptFragment_isActive] DEFAULT ((0)) NOT NULL,
    [passedEvaluation]  VARCHAR (12)   CONSTRAINT [DF_promptFragment_passedEvaluation] DEFAULT ('PENDING_EVAL') NOT NULL,
    [createdUtc]        DATETIME2 (7)  CONSTRAINT [DF_promptFragment_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    [updatedUtc]        DATETIME2 (7)  CONSTRAINT [DF_promptFragment_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_promptFragment] PRIMARY KEY CLUSTERED ([fragmentID] ASC),
    CONSTRAINT [CK_promptFragment_kind] CHECK ([kind]='contract' OR [kind]='task' OR [kind]='specialty' OR [kind]='template_override'),
    CONSTRAINT [CK_promptFragment_scope] CHECK ([scope]='global' OR [scope]='account'),
    CONSTRAINT [CK_promptFragment_passedEvaluation] CHECK ([passedEvaluation]='PENDING_EVAL' OR [passedEvaluation]='PASSED' OR [passedEvaluation]='BLOCKED' OR [passedEvaluation]='INCOMPLETE'),
    CONSTRAINT [CK_promptFragment_accountScope] CHECK (([scope]='account' AND [accountId] IS NOT NULL) OR ([scope]='global' AND [accountId] IS NULL)),
    CONSTRAINT [CK_promptFragment_templateKind] CHECK (([kind]='template_override' AND [templetID] IS NOT NULL) OR ([kind]<>'template_override' AND [templetID] IS NULL))
);
GO

-- Uniqueness across a nullable pair: see 3.3. A plain UNIQUE constraint does NOT
-- give the intended semantics in T-SQL, so use computed sentinels in a unique index.
CREATE UNIQUE NONCLUSTERED INDEX [UX_promptFragment_version]
    ON [AI].[promptFragment]([kind] ASC, [scope] ASC, [accountId] ASC, [templetID] ASC, [version] ASC)
    WHERE ([accountId] IS NOT NULL AND [templetID] IS NOT NULL);
GO

CREATE NONCLUSTERED INDEX [IX_promptFragment_active]
    ON [AI].[promptFragment]([kind] ASC, [scope] ASC, [accountId] ASC)
    WHERE ([isActive] = 1);
```

### 3.2 Changes from the epic's DDL, with reasons

| Epic | This spec | Why |
|---|---|---|
| no template column | **`templetID INT NULL` added** | Finding 2 option A — without it, `template_override` cannot say *which* template, and the live tier-1 behaviour cannot be reproduced. Spelling per CLAUDE.md rule 8 and REQ-02-09. |
| `DEFAULT SYSUTCDATETIME()` | `DEFAULT (getutcdate())` | Zero precedent for `SYSUTCDATETIME` in table DDL; `patientAlertJobLog.sql` line 11 is the house form. `DATETIME2(7)` retained. |
| `CHECK (x IN (...))` | named `CK_promptFragment_*` OR chains | Matches `SpecialtyCarePathTemplate.sql` line 14; avoids an SSDT normalisation diff. |
| — | `CK_promptFragment_accountScope` added | The epic states `accountId` is populated only when `scope='account'` and makes it a *test*. A CHECK makes it impossible to violate. Conditional-CHECK precedent: `patientPrognosisHistory.sql` line 13. |
| — | `CK_promptFragment_templateKind` added | Same reasoning for the new `templetID`. |
| `UNIQUE (kind, scope, accountId, version)` | unique **filtered index**, see §3.3 | A plain UNIQUE treats NULLs as equal in SQL Server — it would allow only one global row per `(kind, version)`… which is arguably intended, but see §3.3 for why it must be decided explicitly. |
| — | `IX_promptFragment_active` added | The runtime read is "active fragments for this kind/scope/account." Filtered-index precedent: `encounterCPT.sql`, `MedicationDiagnosisLink.sql` line 20. |
| `isActive BIT DEFAULT 0` | kept, named constraint | Default-off is correct: a new fragment version must be activated deliberately. Note `AI.prompt.isActive` is `INT`; do **not** copy that — `BIT` is correct and rule 8 does not require propagating a poor choice into a new table. |

### 3.3 The uniqueness question — the subtle one

In SQL Server, a `UNIQUE` constraint treats **NULLs as equal**: it permits at most one row
with a NULL in a given position. So `UNIQUE (kind, scope, accountId, version)` on global rows
(where `accountId` is NULL) allows exactly one row per `(kind, 'global', NULL, version)` —
which is probably intended, but it is intent arrived at by accident of T-SQL semantics rather
than by design.

Adding `templetID` makes this worse: global non-template fragments would have **two** NULLs.

**Two defensible resolutions:**

| Option | Mechanism | Trade-off |
|---|---|---|
| A | Sentinel values — `accountId` and `templetID` `NOT NULL DEFAULT 0` instead of nullable | simple, uniqueness "just works"; but `0` is a magic value and `AI.prompt` already uses `accountId = 0` for universal (see `usp_getPrompt.sql` tier 3) — **so there is direct precedent in this exact domain** |
| B | Computed persisted columns coalescing NULL to `-1`, unique index over those | no magic value in the data; more moving parts |

**Recommendation: option A, sentinel `0`.** `usp_getPrompt.sql` tier 3 already resolves
universal prompts with `accountId = 0`. Using the same sentinel keeps the new table legible to
anyone who knows the old one, and makes the unique key behave without a filtered index or
computed columns. Adjust the two conditional CHECKs to test `= 0` rather than `IS NULL`.

If sentinels are rejected, use option B — but **do not** ship a plain `UNIQUE` over nullable
columns and assume it means what it reads like. This is the kind of thing that is discovered
when a duplicate insert unexpectedly succeeds in production.

### 3.4 Epic design points the audit endorses

- **Every version stays addressable; nothing is deleted.** Correct for an auditable prompt
  history, and the right foundation for REQ-08-14 rollback and A-B comparison.
- **`passedEvaluation` as a four-value verdict, not a BIT.** The strongest design decision in
  this story (Finding 5). Defend it.
- **Read-only runtime module; no write constant in anything the agent imports.** Correct, and
  it maps cleanly here: the runtime gets a read procedure, the admin path gets separate write
  procedures. The procedure boundary is a stronger enforcement point in this codebase than a
  module-import convention would be.
- **Adding a fifth `kind` is a forward migration, not a code change.** Correct, and the CHECK
  constraint is what makes it so.
- **No PHI.** Confirmed — fragments are instructions, not patient content. Worth stating in
  the PR, because it is what makes the prompt text safely loggable, unlike `AI.fieldOutcome`.

---

## 4. Delivery plan

### 4.0 The story at a glance

🔴 **Assume nothing is delivered — and note that this story is the one where that assumption
is hardest to hold.** `AI.prompt` is live, holds 25 audited rows, is read by four stored
procedures and is managed by a shipped admin UI. **This is a replacement of a working feature,
not a new table**, and the epic's 3-point estimate describes about a fifth of it.

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `0004_ai_promptfragment.sql` — table, `UNIQUE(kind,scope,accountId,version)`, four-value `passedEvaluation` | A — **can start today** | PEA-201, D11 (nullable uniqueness) | 2 |
| **DDL** | Read/write procedures | A | DDL | 1–2 |
| **DDL** | Authoring validation (M8) — the rules §6.4 specifies | A | D21 | 2–3 |
| **Runtime** | `src/repositories/promptFragmentRepository.ts` | C | M9 port | 1–2 |
| **Cutover** | 🔴 Backfill **triage** — which of 25 rows migrate | D | **D23 (clinical)** | 3–5 |
| **Cutover** | 🔴 Precedence parity gate — two baselines | D | **D22 (Architecture)** | 3–5 |
| **Cutover** | Retire four procedures + the shipped admin feature | D | **D5 (Product)** | 2–3 |
| **Surface** | 🔴 **M5 — version / diff / promote / rollback UI** | D | **D7; and nobody owns M5** | **8+** |
| | | | **Total** | **13–26** |

### 4.0a Why the backfill is not a mapping exercise

The 25 live `AI.prompt` rows have been audited and **13 defects were found**: four
content-free prompts (`sdwdxs`, `rfvdytvfgvcyt`, `...`, `esfsaf@#`) running in production
because nothing validated authoring, four near-duplicate forks of which **two are
simultaneously active**, and two prompts carrying **contradictory NA-handling rules**.

A faithful migration carries all thirteen forward, and then the parity gate — which compares
new behaviour against old — **certifies the defects as correct**. That is rollup risk R13, and
it is the most expensive failure available in this epic, because it launders bad clinical
instructions through a process designed to prove correctness.

**So the order is triage first, parity second.** Run the two queries in §5.4 at grooming to
turn the defect catalogue into a concrete list of `promptId`s. Get a clinical ruling on the
two contradictory NA rules. **Only then** build the parity baseline — and build it against
the *triaged* set, not the live set, or the gate is measuring the wrong thing.

### 4.0b The three-way split, and why it is not optional

| | Scope | Pts | Gated on |
|---|---|---|---|
| **PEA-205a** | Table + procedures + authoring validation | 3–5 | D11, D21 |
| **PEA-205b** | Backfill triage + two-baseline precedence parity + cutover | **8–13** | D5, D22, D23 |
| **PEA-205c** | Versioning / rollback UI (M5) | 8+ | D7, and an owner for M5 |

**205c has no owner anywhere.** The table stores every version specifically so Epic 8 can roll
back and A/B compare, and §6.4 requires eval-bound promotion — yet no version, history, diff,
preview, approve or rollback concept exists in the front end, and none appears in either
architecture document's roadmap. That is an ownership gap, not an unscoped story. **Name an
owner or accept that the versioning the table is shaped for will never be reachable.**

### 4.0c The one metric that catches the worst failure

`SELECT COUNT(*) FROM AI.promptFragment WHERE passedEvaluation = 'PASSED'`

**Expected value is zero until Epic 10 exists**, because nothing can legitimately write
`PASSED` before there is an evaluation harness to produce it. Any other number means D10 was
defaulted and the promotion gate is failing open — every fragment reading as evaluated and
passed when none has been evaluated at all. One query, run once a week, catches it.

**Exit criterion for 205a:** a fragment can be authored, versioned and read back, and
`passedEvaluation` defaults to `PENDING_EVAL`.
**Exit criterion for 205b:** the parity harness shows identical composed prompts for the
triaged set across both precedence baselines, reviewed by a clinical owner, before any traffic
moves.

### 4.1 Phase 0 — Unblock

| # | Decision | Owner | Blocks |
|---|----------|-------|--------|
| 0.1 | **Per-template prompts: keep (option A), coexist (B), or remove (C)?** | Product + Architecture | the DDL itself |
| 0.2 | **What writes `PASSED` before Epic 10 exists?** | Architecture | whether any fragment is ever usable |
| 0.3 | Coexistence: how long do `AI.prompt` and `AI.promptFragment` both live? | Architecture | migration plan |
| 0.4 | Uniqueness: sentinel `0` or computed columns (§3.3) | Tech lead | the DDL |
| 0.5 | Does `encounterTempletes.ambientPrompt` also become a fragment? | Product | scope |
| 0.6 | Grants: `aiPromptAdmin` does not exist | Architecture + DBA | the security DoD |
| 0.7 | **Platform: is the approved TypeScript/Node.js service ([2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §3.1) ready to consume this table, and if not, what is the interim .NET read path? Note: the TypeScript repository does not yet exist in any form — no repo, no skeleton, no pipeline — making this a genuine sequencing gate, not a formality.** | Architecture | the module |
| 0.8 | **Is the versioning/rollback UI in this story, a separate story, or deferred?** | Product | the estimate |
| 0.9 | **Which precedence is the target — live `usp_getPrompt` behaviour, or doc 3777 §6.4's written ordering?** They differ (Finding 14). Every parity difference must be classified as intended or defective | Architecture | §5.4's gate and its meaning |
| 0.10 | **Backfill triage: which of the 25 live `AI.prompt` rows migrate?** Four are garbage (D10), four are near-duplicate forks (D7), two carry contradictory rules (D1). A faithful copy migrates all of it | Product (prompt content owner) | §4.5 step 10 |
| 0.11 | **D1: which of the two contradictory live rules is correct** — "always return NA if unsure" (id 1) or "do not add N/A" (id 2 rule 7)? A clinical-content decision, not an engineering one | Clinical / prompt content owner | the backfill |
| 0.12 | **Does the eval-set binding (§6.4) need a column on this table** — e.g. `evalSetID INT NULL` — or is it a join table Epic 10 owns? | Architecture | whether the DDL changes later |

**0.1, 0.2 and 0.8 all change the shape of the work.** None can be answered by engineering
alone. **0.1 is now first among them and should be answered before the DDL is written** —
three independent signals (doc 3777 §6.4's ordering, §6.1's six layers, and the absence of any
template concept in either) suggest per-template prompts may not survive, and if they do not,
`templetID`, the `template_override` kind, and one CHECK constraint all come out of §3.1.

0.9 changes what §5.4 *means* rather than what it does — without it, passing the parity gate
may indicate faithfully reproducing behaviour the architecture intends to change.

### 4.2 Phase 1 — The table

1. Create Tables/AI.promptFragment.sql per §3.1, adjusted for the §3.3 decision.
2. Create the re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/&lt;JIRA-KEY&gt;-promptFragment.sql,
   guarding the table and each index separately.
3. Register **both** in the `.sqlproj` — rule 5.
4. Run the release harness; confirm `PASS`.

### 4.3 Phase 2 — Read path

5. `usp_getActivePromptFragments` in Stored Procedures/Procs2/ — rule-6 naming, header block,
   Jira key, `CREATE OR ALTER PROCEDURE`. Returns active, `PASSED` fragments for a
   kind/scope/account (and template, per 0.1), ordered for composition.
6. Expose it through `pacehr_devContextProcedures` / `Ipacehr_devContextProcedures`.

Mapping the epic's module:

| Epic artefact (Python — reference design) | TypeScript/Node equivalent (new repo) |
|---|---|
| `core/prompt_fragment_repository.py` | `src/repositories/promptFragmentRepository.ts`, calling `database.execute()` from `src/core/database.ts` |
| `SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL` | `SELECT_ACTIVE_PROMPT_FRAGMENTS_SQL` constant (SCREAMING_SNAKE kept) at module level in `promptFragmentRepository.ts`; also backed by `usp_getActivePromptFragments` in the SQL layer |
| `class PromptFragmentReader.active_fragments(...)` | `promptFragmentRepository.activeFragments(...)` — camelCase; uses `mssql` npm package (node-mssql over tedious), natively async; the `asyncio.to_thread` wrapper that was needed for the synchronous PEP 249 `mssql_python` driver disappears entirely — `aexecute` becomes plain `execute` |
| no write constant in the runtime module | write logic remains in a separate admin service; the TypeScript runtime module imports only the read function |
| Pydantic model for `PromptFragment` | zod schema + inferred TypeScript type: `kind` as `z.enum(['contract','task','specialty','template_override'])`, `scope` as `z.enum(['global','account'])`, `passedEvaluation` as `z.enum(['PENDING_EVAL','PASSED','BLOCKED','INCOMPLETE'])`; any `Literal` becomes a zod enum with the same values |
| pydantic-settings `Settings` class | zod-validated config in `src/core/settings.ts` |
| pytest test suite | vitest — every test scenario identical, only the framework changes |

### 4.4 Phase 3 — Write path and admin

7. `usp_addEditPromptFragment` — creates a **new version row**, never updates text in place.
8. **Authoring validation inside that procedure**, per doc 3777 §6.4: minimum meaningful
   length, a required task marker, at least one slot, and **no unresolved
   `&lt;&lt;…&gt;&gt;` markers**. This is not optional polish — §1.3 D10 records four
   content-free prompts (`sdwdxs`, `rfvdytvfgvcyt`, `...`, `esfsaf@#`) live in production
   today precisely because nothing validated authoring, and D9 records a live injection
   surface through an unescaped `&lt;&lt;templateName&gt;&gt;`. Shipping the replacement table
   without validation reproduces both.
9. `usp_setPromptFragmentActive` — activation/deactivation as a distinct operation from
   authoring. Keeping these separate is what makes rollback a single call.
10. Grants per 0.6.

### 4.5 Phase 4 — Migration and cutover (the real work)

11. **Triage the 25 live rows before writing any insert** (Finding 13, 0.10). Classify each as
    migrate / retire / merge. The expected outcome is fewer than 15 fragments, not 25:
    D10's four garbage rows should not migrate at all, and D7's four near-duplicates
    (ids 8, 10, 20, 21 — with 10 and 20 **both active**) collapse to one fragment with a
    version history. Record the disposition of every row; a reviewer should be able to ask
    "what happened to prompt id 17?" and get an answer.
12. **Resolve D1 first** (0.11). Prompt id 1 and prompt id 2 rule 7 give the model opposite
    instructions about NA/N-A handling and both are live. The migration must not preserve
    both. This is a clinical-content decision with a named owner, not a mapping rule.
13. Backfill the surviving rows: each becomes a fragment at `version = 1`.
    `isUniversal = 1, accountId = 0` → `scope='global'`; `isUniversal = 1, accountId = N` →
    `scope='account'`; template-bound rows → `kind='template_override'` with `templetID`
    (**unless 0.1 lands on option C**, in which case those rows need a different disposition
    decided in triage). Escape or reject any unresolved `&lt;&lt;…&gt;&gt;` markers on the way
    in (D3, D9) rather than carrying the live injection surface across.
14. Reimplement `usp_getPrompt`'s three-tier precedence over fragments, or compose fragments
    per Epic 8. **This must be behaviour-compared against the live procedure, per template,
    before cutover** — a silent precedence change alters what the model is told, which changes
    clinical output. Per 0.9 and Finding 14, compare against **both** baselines: live
    behaviour and doc 3777 §6.4's written ordering.
15. Repoint `AIPromptServices.cs` lines 95–97.
16. Repoint or retire the admin UI at `PacEHR/src/app/features/ai-prompt/`.
17. Decide the fate of `Template.encounterTempletes.promptId` and the four legacy procedures.

**Phases 1–3 are roughly the epic's 3 points. Phase 4 is the story** — and steps 11–12 are new
since the architecture review: the backfill is a supervised cleanup of audited-defective data,
not a `INSERT … SELECT`.

---

## 5. Verification

### 5.1 Deployment checks

```sql
SELECT s.name AS schemaName, t.name AS tableName
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'AI' AND t.name = 'promptFragment';

SELECT c.name, ty.name AS dataType, c.max_length, c.is_nullable
FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'[AI].[promptFragment]') ORDER BY c.column_id;

SELECT name, definition FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'[AI].[promptFragment]');

SELECT i.name, i.is_unique, i.has_filter, i.filter_definition
FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[AI].[promptFragment]');
```

### 5.2 Constraint behaviour

```sql
-- must fail: a fifth kind
INSERT INTO [AI].[promptFragment] (kind, scope, accountId, version, fragmentText)
VALUES ('guardrail', 'global', 0, 1, 'x');
-- expect: conflict with CK_promptFragment_kind

-- must fail: account scope with no account
INSERT INTO [AI].[promptFragment] (kind, scope, accountId, version, fragmentText)
VALUES ('task', 'account', 0, 1, 'x');
-- expect: conflict with CK_promptFragment_accountScope

-- must fail: BIT default must be off
INSERT INTO [AI].[promptFragment] (kind, scope, accountId, version, fragmentText)
VALUES ('task', 'global', 0, 1, 'x');
SELECT isActive AS mustBeZero, passedEvaluation AS mustBePendingEval
FROM [AI].[promptFragment] WHERE kind = 'task';

-- must fail: duplicate version within the same key
INSERT INTO [AI].[promptFragment] (kind, scope, accountId, version, fragmentText)
VALUES ('task', 'global', 0, 1, 'second copy');
-- expect: unique violation. If this SUCCEEDS, section 3.3 was resolved incorrectly.
```

That last assertion is the one to watch. It is the whole point of §3.3.

### 5.3 Fail-closed evaluation gate

```sql
-- only PASSED fragments may be returned to the runtime
SELECT passedEvaluation, COUNT(*) FROM [AI].[promptFragment]
WHERE isActive = 1 GROUP BY passedEvaluation;
-- PENDING_EVAL, BLOCKED and INCOMPLETE must never reach the composition path
```

### 5.4 Precedence parity — the cutover gate

```sql
-- for every template, the fragment-composed prompt must match what usp_getPrompt returns
-- today, or the difference must be explicitly signed off
SELECT t.encounterTempleteID, t.encounterTempleteName, t.promptId
FROM [Template].[encounterTempletes] t
WHERE t.promptId IS NOT NULL AND t.isActive = 1
ORDER BY t.encounterTempleteID;
```

Run this before Phase 4 to size the cutover: it is the list of templates whose prompt
resolution changes.

**Compare against two baselines, not one** (Finding 14, 0.9). For every template in that list,
record three results — what `usp_getPrompt` returns today, what doc 3777 §6.4's written
ordering (`Organization-Universal > Organization > System-Universal > System`, ties by
`accountId` then most recent version) would return, and what the new composition returns —
and classify each row:

| Classification | Meaning | Action |
|---|---|---|
| matches live **and** §6.4 | the two baselines agree; no behaviour change | pass |
| matches §6.4, differs from live | an **intended** change toward the approved rule | needs explicit sign-off as a deliberate behaviour change |
| matches live, differs from §6.4 | the implementation is faithful to the old rule, not the target | decide which is wanted; do not let it pass silently as "parity" |
| matches neither | a defect | fix before cutover |

Without this classification, "the parity gate passed" is ambiguous — it could mean the
migration is correct, or it could mean it faithfully reproduced behaviour the architecture
intends to replace. Both look identical in a green test run.

Also sanity-check the corpus itself before comparing, since §1.3 found four of 25 live prompts
are content-free garbage:

```sql
-- prompts that are too short to be a real prompt (D10): expect to find id 15, 17, 18, 22
SELECT promptId, promptName, LEN([prompt]) AS len, isActive, isDeleted
FROM [AI].[prompt]
WHERE isDeleted = 0 AND LEN(LTRIM(RTRIM([prompt]))) < 40
ORDER BY len;

-- unresolved slot markers still present in live prompt text (D3, D9)
SELECT promptId, promptName, isActive
FROM [AI].[prompt]
WHERE isDeleted = 0 AND [prompt] LIKE '%<<%'
ORDER BY promptId;
```

Both queries feed 0.10's triage directly. Run them at grooming, not at migration time.

### 5.5 Definition of Done

- [ ] Tables/AI.promptFragment.sql created per §3.1 with all CHECK constraints
- [ ] §3.3 uniqueness resolved explicitly (sentinel or computed); a test asserts a duplicate
      `(kind, scope, accountId, templetID, version)` is **rejected**
- [ ] `templetID` present or its absence signed off as a deliberate product decision (0.1)
- [ ] `accountId` / `templetID` spellings match the live database exactly — rule 8, REQ-02-09
- [ ] Re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/ with the Jira key;
      table and each index independently guarded
- [ ] **Both** files registered in the `.sqlproj` (`<Build>` + `<None>`) — rule 5
- [ ] Release harness run; `PASS` verdict, no duplicate-object hit
- [ ] `usp_getActivePromptFragments` in Procs2/ with rule-6 naming, header block, Jira key;
      returns only `isActive = 1 AND passedEvaluation = 'PASSED'`
- [ ] A test asserts `PENDING_EVAL`, `BLOCKED` and `INCOMPLETE` fragments are **never**
      returned to the runtime — fail closed
- [ ] A test asserts `accountId` is populated only when `scope = 'account'`
- [ ] Write procedures are **separate objects** from the read procedure; the runtime read path
      has no write capability
- [ ] Grants: **only** assert `aiServiceRuntime` has no write permission against
      `sys.database_permissions` **if** the principals actually exist. If 0.6 is unresolved,
      say so in the PR rather than shipping a test that passes vacuously.
- [ ] Adding a fifth `kind` is documented as a forward migration, not a code change
- [ ] **The PR states explicitly** that this table replaces a shipped feature
      (`AI.prompt`, four procedures, an admin UI, a template-editor dependency) and names the
      coexistence plan agreed in 0.3
- [ ] **The PR states explicitly** that no versioning/rollback/diff UI exists and whether it
      is in scope (0.8)
- [ ] **The PR states explicitly** what writes `PASSED` before Epic 10 (0.2)
- [ ] **Authoring validation implemented in `usp_addEditPromptFragment`** per doc 3777 §6.4 —
      minimum length, task marker, at least one slot, no unresolved `&lt;&lt;…&gt;&gt;`
      markers. A test asserts a `sdwdxs`-class fragment is rejected at write time
- [ ] **The backfill triage is recorded** — every one of the 25 live `AI.prompt` rows has a
      stated disposition (migrate / retire / merge), and a reviewer can trace any promptId
      to its outcome (0.10)
- [ ] **D1's contradiction is resolved by a named owner before the backfill runs**, not
      preserved as two active fragments (0.11)
- [ ] **The §5.4 parity results are classified against both baselines** — live behaviour and
      doc 3777 §6.4's written ordering — and every intended difference is signed off as such
      (0.9). A green parity run with no classification does not satisfy this
- [ ] No PHI — stated, and the reasoning (fragments are instructions, not patient content)
      recorded, since this is what makes fragment text safely loggable
- [ ] PR title, branch name and commit message all carry the literal Jira key; one concern per PR
- [ ] PR checklist complete: unit tests · DB script · technical documentation · AI usage

---

## 6. Risk register

| # | Risk | L | I | Mitigation |
|---|------|---|---|------------|
| 1 | **Estimated at 3 points; actual scope is a feature replacement** | High | High | Re-point; split (see below) |
| 2 | **Precedence silently changes at cutover → different prompts → different clinical output** | High | **Critical** | §5.4 parity gate per template before cutover, classified against both baselines (0.9) |
| 3 | `template_override` cannot identify a template | High | High | Finding 2 option A; decide in 0.1 |
| 4 | Nothing writes `PASSED`; no fragment ever usable | High | High | 0.2 — doc 3777 §6.4's eval-set mechanism is the approved answer (Finding 16); manual approval path as interim, **never default-PASSED** |
| 5 | Plain UNIQUE over nullable columns does not enforce what it appears to | Med | High | §3.3; the §5.2 duplicate test |
| 6 | Template editor regression via `promptId` | Med | High | Finding 3; test `usp_addEditTemplate` and `usp_getEncounterTemplateList` |
| 7 | Versioning UI never built; rollback capability exists only in the schema | High | Med | 0.8; scope it or state it |
| 8 | `ambientPrompt` forgotten entirely | Med | Med | 0.5 |
| 9 | `aiPromptAdmin` does not exist; write restriction is advisory | High | Med | 0.6; procedure boundary as the interim control |
| 10 | Client-side `userRole === 1` is not an authorisation boundary | High | Med | Finding 8; raise separately, enforce server-side |
| 11 | Two prompt systems live indefinitely; confusion about the source of truth | Med | High | 0.3; set a retirement date for `AI.prompt` |
| 12 | TypeScript/Node.js service approved but not yet stood up — no repo, no skeleton, no pipeline → no consumer for this table | High | Med | 0.7; Finding 10 |
| 13 | `.sqlproj` registration missed → silently never deployed | Med | High | Manifest test; harness verdict |
| 14 | `isActive` type differs from `AI.prompt`'s `INT` and confuses a reader | Low | Low | Note it in the PR; `BIT` is correct |
| 15 | SSDT targets SQL Server 2022, deployment may be Azure SQL | Med | Med | Inherited from PEA-201 |
| 16 | **Migration validated against observed behaviour rather than the §6.4 written rule → the new system reproduces a bug faithfully and the green parity gate certifies it** | **High** | **Critical** | Finding 14; 0.9; the four-way classification in §5.4 |
| 17 | **Backfill copies all 25 live rows** → four garbage prompts (D10), four near-duplicate forks (D7) and two contradictory rules (D1) become fragments at `version = 1`, and the version history is meaningless from day one | **High** | High | Finding 13; 0.10; §4.5 step 11 triage |
| 18 | **D1's contradiction is migrated rather than resolved** → two active fragments give the model opposite NA-handling instructions, now harder to spot than before | Med | **Critical** | 0.11 — route to the clinical content owner before the backfill |
| 19 | No authoring validation on the new write path → the new table accumulates the same junk the old one did, and the unescaped `&lt;&lt;…&gt;&gt;` injection surface (D9) carries across | **High** | High | §4.4 step 8, per doc 3777 §6.4's validation rules |
| 20 | `kind = 'template_override'` has no layer in the approved six-layer composition → nothing defines where it lands in the assembled prompt | Med | High | Finding 15; resolve via 0.1, not by adding a fifth `kind` |
| 21 | Eval-set binding (§6.4) needs a column nobody has scoped → DDL change after ship | Med | Low | 0.12; `evalSetID INT NULL` is cheap to anticipate |
| 22 | **205c has no owner in either roadmap** → storage and rules exist, no surface exercises them; an administrator cannot create v2, diff it, promote it or roll it back | **High** | High | Finding 17; raise jointly with Architecture and Product |

**On the estimate.** The epic's 3 points is right for a table and a read procedure and nothing
else. Recommend splitting:

| Story | Scope | Points |
|---|---|---|
| **PEA-205a** | Table + read procedure + write procedures | 3–5 |
| **PEA-205b** | Backfill + precedence parity + runtime cutover + retire `AI.prompt` | 8 |
| **PEA-205c** | Versioning / history / diff / rollback / A-B UI | 8+ |

205c may belong to Epic 8 rather than Epic 2 — but it must belong to *something*, or REQ-08-14
is a schema capability nobody can reach. **Finding 17 confirms it currently belongs to
nothing**: neither doc 3777's §14 roadmap nor doc 3776's Phase 1 scope contains a
prompt-authoring or prompt-versioning surface. Doc 3777 §6.4 requires the *properties*
(immutable versions, precedence, authoring validation, eval-bound promotion) without naming
anything that lets a human operate them.

**205b's estimate should go up, not down, after the architecture review.** It was scoped as a
mapping exercise; Findings 13 and 14 make it a supervised cleanup of audited-defective data
(25 rows, 13 catalogued defects, one clinical-content contradiction needing a human decision)
plus a three-way behaviour comparison against two baselines rather than one. **8 points is now
optimistic; 8–13 is the honest range.**

---

## 7. Recommended immediate actions

1. **Re-point this story in grooming.** 3 points describes about a fifth of it. Take the
   split in §6 to the team.
2. **Decide 0.1 (per-template prompts).** Option C is a product decision about removing a
   shipped capability and must not be defaulted into by an omitted column.
3. **Decide 0.2 (who writes `PASSED`).** Without an answer, the fail-closed design means
   nothing is ever usable — and the tempting fix destroys the design.
4. **Resolve §3.3 uniqueness before writing DDL.** The sentinel-`0` approach already has
   precedent in this exact domain (`usp_getPrompt.sql` tier 3).
5. **Plan the precedence parity gate now** (§5.4). Risk 2 is the only critical-impact risk in
   this story, it is silent, and its blast radius is clinical output.
6. **Raise the `userRole === 1` client-side gate as a separate security finding.** It is not
   this story's problem, but this story is what surfaced it.
7. ~~**Read the two AI architecture design documents** — they describe a model-agnostic agent
   replacing the direct OpenAI path and may already settle 0.1, 0.3 and 0.7.~~ **Done.** Both
   [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) and
   [Phase 1](solution-doc:3776) were read in full. Outcome: the platform question (0.7) is
   settled — and **settled differently than those documents propose.** They approve a Python
   orchestrator — **and `pacEHR_AI/` implements its Epic 01 foundation, tested**; the owner
   decision supersedes the language with a **TypeScript/Node.js service ported from it**,
   service. The Python corpus remains the reference design for everything language-neutral
   (this table's DDL, the precedence rules, the acceptance criteria) and none of that changes.
   What does change: the reader of this table is `src/repositories/promptFragmentRepository.ts`
   calling `database.execute()` from `src/core/database.ts`, and **that repository does not
   exist yet** — so 0.7 is answered as a decision but still open as a dependency.
   Five new findings (13–17) came out of the reading. 0.1 is *not* settled but now has three
   converging signals; 0.2 has an approved mechanism.
8. **Run the two §5.4 corpus queries at grooming** — the short-prompt check and the unresolved
   `&lt;&lt;` marker check. They convert Finding 13's defect catalogue from a document
   reference into a concrete list of promptIds to triage, and they take a minute to run.
9. **Route D1 to whoever owns prompt content, today.** Two live prompts give the model
   opposite instructions about NA handling (ids 1 and 2). That is a live defect independent of
   this story — the migration just forces the issue. It needs a clinical decision, and the
   lead time on getting one is the reason to ask now rather than at cutover.
10. **Put the 205c ownership question on the agenda with Architecture and Product together.**
    Neither architecture document's roadmap contains a prompt-versioning surface, while
    doc 3777 §6.4 requires the behaviours that surface would expose. Framing that gets an
    answer: *after this ships, how does an author create v2, diff it against v1, promote it,
    and roll it back?*

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getPrompt.sql` - The live three-tier precedence engine (67 lines) this table must replicate or deliberately replace. The single most important file for this story.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/prompt.sql` - The existing `AI.prompt` table being replaced; source of the `accountId`/`isUniversal` semantics and the `accountId = 0` sentinel precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` - Carries `promptId`, `ambientPrompt` and `ambientFlag` — the template-editor dependency and a second prompt surface.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditTemplate.sql` - Lines 32, 54, 70, 106 write `promptId`; the template-save blast radius.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getEncounterTemplateList.sql` - Lines 22, 29 read `promptId`; the template-list blast radius.
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - Lines 95–97 call `usp_getPrompt` — the runtime call site that must be repointed.
- `PacEHR/src/app/features/ai-prompt/ai-prompt.component.ts` - The shipped admin list (194 lines); line 45 the `userRole === 1` gate; no version/history/rollback concept.
- `PacEHR/src/app/features/ai-prompt/add-edit-ai-prompt/add-edit-ai-prompt.component.ts` - The shipped edit form; controls at lines 64–71 define today's authoring surface.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_addEditAiPrompt.sql` - Live upsert procedure that must be replaced or retired.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_getAiPrompts.sql` - Live admin list procedure.
- `pacEHR_API/PacEHR.Database/Stored Procedures/Procs1/usp_deleteAiPrompt.sql` - Lines 13–21, soft-delete convention.
- `pacEHR_API/CLAUDE.md` - Rules 3–8, § Numbers; governs datatypes, scripts, registration, proc naming and the do-not-correct-spellings rule.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest; rule-5 silent-failure surface; line 10 DSP targets SQL Server 2022.

### Medium Relevance
- `PacEHR/src/app/core/services/prompt.service.ts` - `getAIPromptList` / `addEditAIPrompt` / `deleteAIPrompt` — the Angular service that must be repointed.
- `PacEHR/src/app/features/settings/template-editor/template-editor.component.ts` - Line 19 opens the prompt list as a modal, tying prompt admin to the template editor.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14, the named-CHECK OR-chain house style; line 26, separate unique index form.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` - Line 17, inline composite UNIQUE constraint precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql` - Line 13, conditional-CHECK precedent for the scope/account and kind/template constraints.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11, `DEFAULT (getutcdate())` house form.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/MedicationDiagnosisLink.sql` - Line 20, unique filtered-index precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterCPT.sql` - Filtered-index precedent for `IX_promptFragment_active`.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - `prompt` and `aiSummaryPrompt` columns — a third prompt surface (see PEA-207).
- `pacEHR_API/PacEHR.Database/Tables/Tables1/section.sql` - `prompt` column — a fourth prompt surface.
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The partial class the new procedures must be exposed through; binds by string name.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The actual deployment mechanism.

### Low Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/ProviderAssignedFacility.sql` - Line 16, further inline UNIQUE precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7Outbound_AuditLogs.sql` - Line 14, separate unique index precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Joined by `usp_getPrompt` tier 1.
- `pacEHR_API/pipelines/` - 12 files; confirmed to contain no database deployment.
- `pacEHR_API/PacEHR.Tests.UnitTests/` - xUnit + Moq project where the new tests land.
- `PacEHR/src/app/features/ai-prompt/` - The full shipped admin feature folder being replaced.
