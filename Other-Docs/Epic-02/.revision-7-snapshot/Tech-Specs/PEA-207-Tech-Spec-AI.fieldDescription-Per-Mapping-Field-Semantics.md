# PEA-207 Tech Spec — AI.fieldDescription (Per-Mapping Field Semantics)

**Epic:** E2 — Data Layer · **Story:** PEA-207 · **Phase:** 1
**Depends on:** PEA-201 · **Satisfies:** REQ-02-07, REQ-02-09, REQ-02-10
**Epic estimate:** 3 points · **Audited estimate:** 3 points for the table; **the precedence decision in §1 Finding 1 must be made first** — see §6
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

> ⚠️ **Build target: TypeScript/Node.js.** The AI engine is a
> **new, standalone TypeScript/Node.js service** — a repository **not yet created** in this
> solution and **built greenfield in `pacEHR_AI/`**, and which does **not** reuse the existing C# AI logic in
> `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`. The runtime chain is
> **Angular → .NET Web API → TypeScript AI service → Azure OpenAI**.
>
> The 12-epic reference corpus is the **design of record and is
> deliberately unmodified**. Everything language-neutral in this spec applies as-is: the DDL
> including the **composite primary key on (`templetID`, `sectionID`, `fieldID`) with no
> surrogate**, the read-only stance of REQ-02-07, the no-caching rule, the grain argument,
> the Gherkin acceptance criteria, the REQ- IDs, the dependencies and the point estimates.
> What changes is only the *reader*: **src/repositories/fieldDescriptionRepository.ts**,
> calling `database.execute()` on the `database` singleton in `src/core/database.ts` (the
> `mssql` npm package, node-mssql over tedious — natively async, so the reference design's
> the async driver wrapper disappears), with zod schemas in place of zod models and
> **vitest** in place of vitest.
>
> **Grants are unchanged and still matter more here than anywhere:** `aiTemplateAdmin` gets
> `INSERT`/`UPDATE`, `aiServiceRuntime` gets `SELECT` only. With the reader now in a separate
> repository and a separate runtime, that connection-level grant is the *only* thing
> enforcing REQ-02-07's read-only rule — there is no shared compiler or code review spanning
> both sides.

> **Read this first.** The epic calls REQ-03-01 the highest-value requirement in the corpus,
> and the audit agrees the capability matters. But the product **already has two user-editable
> per-field prompt columns** — `Template.fields.prompt` and `Template.fields.aiSummaryPrompt` —
> exposed in the shipped template editor. This table adds a third authoring surface for
> per-field AI instructions, at a different grain. That may well be correct; it cannot be
> shipped without deciding explicitly what wins when they disagree. §1 Finding 1.

---

## 1. Findings — what the audit changed

| # | Finding | Severity | Effect on this story |
|---|---------|----------|----------------------|
| 1 | **Two per-field AI prompt columns already ship and are already editable** | 🔴 critical | Precedence between them and `description` is undecided |
| 2 | **The composite PK with no surrogate has essentially no precedent** — 1 two-column PK in 1,116 files, zero three-column | 🟠 high | §3.3 argues for keeping it anyway, with reasons |
| 3 | **`Template.fields` carries an audit trigger** — reinforcing the read-only argument | ✅ supports the epic | §2.4 |
| 4 | That trigger **omits `abbreviation`** — a live gap worth reporting separately | 🟡 medium | Not this story; §2.4 |
| 5 | **REQ-02-07 read-only justification is sound**, and the audit strengthens it | ✅ endorsed | §2.4 |
| 6 | The template editor has **no per-field `description` control** | 🟠 high | New UI in scope, or the table stays empty |
| 7 | **Excluding `name`/`type`/`unit` is correct** — they are live columns on `Template.fields` | ✅ endorsed | §3.4 |
| 8 | **The no-caching rule is correct** and must survive translation to .NET | 🟠 high | §3.5 — easy to lose |
| 9 | `fieldDescription` name is **free** | ✅ closed | — |
| 10 | `aiTemplateAdmin` does not exist; no grants anywhere | 🔴 blocker | Inherited |
| 11 | **No *Node* AI service exists yet** — no `nest-cli.json`, no `serverless.yml`, no backend `package.json` in `PacEHR/` or `pacEHR_API/`. ⚠️ **Revision 7:** `pacEHR_AI/` exists (created 2026-09-30) and is empty, so the gate is an 8–13-point greenfield build (M9) against a written spec | 🟠 med | §4.1 item 0.6 — see Finding 11 (detail) |
| 12 | `DEFAULT SYSUTCDATETIME()` → `DEFAULT (getutcdate())` | 🟡 medium | §3.2 |
| 13 | **The approved prompt-composition model has no layer for per-field authored free text** — this table has no assigned home in it | 🔴 critical | Route to Architecture before Epic 3; see Finding 13 (detail) |
| 14 | **Immutable versioned fragments + sha256 prompt hashing rule out option B** more firmly than §1 Finding 1 argued | ✅ strengthens C | Finding 13 (detail) |
| 15 | **This product has a demonstrated history of unvalidated free-text prompt fields rotting in production** — 4 garbage prompts live today | 🟠 high | Authoring validation is day-one scope, not a nicety; Finding 15 (detail) |

---

### Finding 1 (detail) — the product already has per-field AI instructions

`pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` declares, at lines 14–16:

```sql
[prompt]          VARCHAR (MAX)  NULL,
[allowAISummary]  BIT            NULL,
[aiSummaryPrompt] NVARCHAR (MAX) NULL,
```

These are not dormant columns. They are **exposed in the shipped template editor** at
`PacEHR/src/app/features/settings/template-editor/add-edit-field/add-edit-field.component.ts`:

| What | Lines |
|---|---|
| Form controls declared — `prompt`, `allowAISummary`, `aiSummaryPrompt` | 81, 82, 83 |
| Populated when editing an existing field | 101–103 |
| Persisted via `templateEditorService.addEditField()` | 192 |
| Merged back into the field object | 245–247 |

So a template administrator can, today, write free-text AI instructions against a field and
save them.

**The overlap with this story is direct.** `AI.fieldDescription.description` is
"one line of description per field" (REQ-03-03) used by Epic 3's schema builder to tell the
model what a field means. `Template.fields.aiSummaryPrompt` is free-text AI instruction
attached to a field. They are not identical — a *description* states what a field means, an
*instruction* tells the model what to do — but that distinction is conceptual, not enforced,
and nothing stops an author putting either content in either place.

**They differ in grain, and that is the real argument for the new table:**

| | `Template.fields.aiSummaryPrompt` | `AI.fieldDescription.description` |
|---|---|---|
| Grain | **global per field** | **per (template, section, field)** |
| Blast radius of one edit | every template using that field — measured at **179 of 458** | one mapping |
| Can differ per section | ❌ no | ✅ yes |
| Length | `NVARCHAR(MAX)` | `NVARCHAR(1000)` |
| Editable today | ✅ yes | ✗ no UI |

The epic's own fixtures are precisely the case the global column cannot express — fieldID 412
"Blood Pressure" needs *different* text in sectionID 11 than in sectionID 12:

- (3, 11, 412) = "Vital sign as measured and stated at the bedside. Systolic over diastolic."
- (3, 12, 412) = "Blood pressure only when re-measured during the physical examination. If the
  value was already captured in Review of Systems, leave this empty."

A global `aiSummaryPrompt` on fieldID 412 must be one of these, or a compromise that is
correct in neither section. **So the finer grain is genuinely necessary and the table is
justified.**

**What is not decided: precedence.** When a field has both an `aiSummaryPrompt` (global) and
a `fieldDescription` (per-mapping), what does Epic 3's schema builder send to the model?
Four possible answers, each defensible, none chosen:

| Option | Behaviour | Risk |
|---|---|---|
| A | `fieldDescription` wins; `aiSummaryPrompt` ignored when present | silently changes behaviour for fields that have both |
| B | Both sent — description as semantics, prompt as instruction | prompt bloat; contradictory instructions reach the model |
| C | `aiSummaryPrompt` deprecated and migrated into `fieldDescription` | cleanest end state; a migration and a UI removal |
| D | `fieldDescription` is a fallback when `aiSummaryPrompt` is empty | inverts the grain argument — global beats specific |

**Recommendation: option C as the target, option A as the interim**, and in either case
**write the rule down in this story**. Option D should be explicitly rejected: it would let
the global value override the per-section value, defeating the reason the table exists.

This must be decided before Epic 3 builds the schema builder, because Epic 3 is where the rule
gets implemented, and an unstated rule becomes whatever the first implementer assumed.

### Finding 2 (detail) — composite PK with no surrogate is near-unprecedented

The epic specifies `PRIMARY KEY (templetID, sectionID, fieldID)` with no surrogate id.
Searching all 1,116 files under `pacEHR_API/PacEHR.Database/Tables/`:

| Pattern | Matches |
|---|---|
| Two-column `PRIMARY KEY CLUSTERED` | **1** — `pacEHR_API/PacEHR.Database/Tables/Tables2/V28Hierarchy.sql` line 6 |
| Three-column `PRIMARY KEY CLUSTERED` | **0** |

The one instance is `[HCC].[V28Hierarchy]` — `([ParentId] ASC, [ChildId] ASC)` on a pure
parent/child link table with two attribute columns. So there is *a* precedent for a natural
composite PK on a link-style table, and that is structurally what this table is.

The house convention everywhere else is surrogate `INT IDENTITY` PK plus a UNIQUE constraint
for the natural key — exactly what PEA-206 does, and what
`pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` line 17 models.

**Recommendation: keep the composite PK**, contrary to the numerical weight of precedent, for
three reasons:

1. The epic's reasoning is sound — the composite key's leading column is `templetID`, which is
   the single access pattern (`for_templet(templet_id)` returning every mapping's description
   in one call, REQ-03-04). A clustered index on `(templetID, sectionID, fieldID)` serves that
   read perfectly, and a surrogate PK would need a secondary index to match it.
2. There is exactly one row per mapping and no separate identity for it. A surrogate would be
   a number nothing refers to.
3. `V28Hierarchy` establishes that this shape is acceptable here.

But **note the departure in the PR**, because a reviewer accustomed to the surrogate
convention will flag it. Note also the divergence from PEA-206, which keeps a surrogate: the
difference is that PEA-206's rows are addressed individually by an editor UI, whereas this
table is read wholesale per template.

### Finding 11 (detail) — the AI service exists in `pacEHR_AI/`; the architecture resolves the design question, the owner decision resolves the language

No AI service application exists in this repository today. This repository is .NET 8 + SSDT + Angular. The corpus's modules (`fieldDescriptionRepository`, the agent runtime, typed response models, the chat-model factory) therefore cannot live here — but that does not make the epic wrong.

The [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) (status: approved for planning, dated 2026-09-10) §3.1 names exactly this service: **"AI Orchestrator · NEW"** (Ingest Gateway, pipeline, Prompt + Config Registry). Its stated division of ownership is: "The .NET API keeps owning auth, persistence and the existing contract. The orchestrator owns AI decisioning only." That division is unchanged and correct.

⚠️ **What the owner decision changes.** Doc 3777 §14 and [Phase 1](solution-doc:3776) specify that orchestrator at implementation level. Those documents are the **reference design and stay as they are.** The build target is a **greenfield Node/TypeScript service in `pacEHR_AI/`**, which also owns the `AI.*` DDL. For this story the translation is small and mechanical:

| Corpus (reference design) | Build target (TypeScript) |
|---|---|
| **core/field_description_repository.py** | **src/repositories/fieldDescriptionRepository.ts** |
| `FieldDescriptionReader.for_templet(templet_id)` | `FieldDescriptionReader.forTemplet(templetId)` — class name survives, method camelCased |
| `SELECT_FIELD_DESCRIPTION_SQL` | **unchanged** — a module-level SCREAMING_SNAKE constant holding the same T-SQL, no interpolation |
| zod row model | zod schema + `z.infer<>` |
| the `mssql` npm package + the async driver | `mssql` (node-mssql/tedious), natively async — `await database.execute(...)`, thread-pool wrapper gone |
| vitest | vitest |

**The epic is not in error.** It targets a service that is approved, designed and fully specified, and whose repository now exists. The residual blockers are narrower than "which language?" — that is settled — and are now purely about scheduling:

1. Does the AI service exist yet? **The repository does — `pacEHR_AI/`, created 2026-09-30 — and it is empty.** No skeleton, no pipeline, no code. The reference backlog specifies the foundation; building it is M9, 8–13 pts, and it needs scheduling.
2. Is it staffed?
3. Is Epic 02 (Data Layer, this story's epic) explicitly sequenced before the service so the tables are present when it is built?
4. **Who authors the Node dependency allow-list?** [the reference symbol allow-list](solution-doc:5091) governs libraries and does not apply to a Node runtime at all. A TypeScript equivalent has to be written, along with the `src/core/` foundation (`settings.ts` via zod, `database.ts` via node-mssql, plus `llm.ts`, `errors.ts`, `logging.ts`, `auth.ts`) that this story's reader depends on.

The DDL in §3.1 is unaffected either way — the tables live in SQL Server regardless. Doc 3777 §3.1 places `AI.*` tables in the same SQL Server instance as `Template.*` and `Log.AILogs`, so the database work in this story is correct in either timing scenario. **Update item 0.6 accordingly** — the question is no longer "which platform?" but "is the TypeScript service stood up, and when — and what reads this table until it is?"

### Finding 13 (detail) — the approved composition model has no layer for this table

This is the most consequential thing the architecture review surfaced for PEA-207, and it is
**not** a contradiction of the story — it is a gap in the design the story feeds.

[2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §6.1 specifies a
six-layer prompt composition. Every layer has a stated origin:

| Layer | Content | Where it comes from |
|---|---|---|
| L0 | Contract | invariant, byte-identical across all calls, cacheable |
| L1 | Task | per task type |
| L2 | Specialty | **per template family** |
| L3 | Field manifest | **generated** from the template's field set |
| L4 | Constraint digest | **compiled** from `AI.fieldConstraint` |
| L5 | Runtime facts | typed and escaped at call time |

Read the origins column carefully. **Not one of these six layers is a place where a human
author's free text about a single field is injected.** L3 is generated, not authored. L4 is
compiled from numeric constraint rows, not prose. L2 is authored but sits at template-family
grain — which is coarser than `Template.fields`, let alone coarser than this table's
`(templetID, sectionID, fieldID)` triple.

`AI.fieldDescription.description` is precisely per-field authored free text. **It has no
assigned home in the approved composition.** That does not mean the table is wrong — REQ-03-01
is still, as the epic argues, the highest-value requirement in the corpus, and §6.2's finding
that 30.8% of the live H&P prompt is removable is an argument *for* replacing sprawling prose
with structured per-field semantics. It means the composition model and this table were
designed without reference to each other, and someone has to reconcile them.

**Three questions for Architecture, to be answered before Epic 3 builds the schema builder:**

1. **Where is `description` injected?** Most plausibly it enriches L3 — the field manifest
   stops being purely generated and becomes generated-plus-authored-overlay. That is a real
   change to L3's stated contract and to anything that assumed L3 was deterministic from the
   template.
2. **Is it subject to §6.4's rules?** §6.4 requires immutable versioned fragments, authoring
   validation, a stated precedence order, and — the significant one — **every fragment bound
   to an eval set, with promotion blocked on no regression**. If `description` is a prompt
   fragment in substance, it should carry those obligations. The epic's DDL gives it none:
   one mutable `NVARCHAR(1000)` column, overwritten in place.
3. **Does it participate in the prompt hash?** §6.1 says compiled prompts are sha256-hashed;
   §12 says tracing records fragment versions and `prompt_hash` per call. If `description`
   text changes the prompt but is not versioned, the hash changes with no corresponding
   version to attribute it to — the audit trail records *that* the prompt changed but not
   *what* changed it. That is a weaker trail than §12 intends.

**This does not block the DDL.** The table's shape, grain and content are unaffected by where
the text is injected. It blocks Epic 3, and it should be raised now, while the composition
model is still on paper and cheap to amend.

**It also settles the option B question in Finding 1.** Finding 1 weighed four precedence
options and recommended C (migrate `aiSummaryPrompt` into `fieldDescription`) with A as the
interim, calling B (send both) merely risky for prompt bloat. The architecture makes B worse
than that. Under §6.1/§6.4, prompt content is composed from **immutable versioned fragments**
and the compiled result is **hashed for audit**. Option B means two independently-mutable
free-text columns — one global, one per-mapping, neither versioned — both flowing into the
compiled prompt. Two unversioned inputs to a hashed, audited artefact is directly contrary to
the model: when a prompt hash changes you cannot say which of the two fields moved.
**Option B should now be rejected outright**, not merely deprioritised, and C's case is
correspondingly stronger — one authored surface, one thing to version.

### Finding 15 (detail) — this product has already shipped rotten free-text prompts

Doc 3777 §1.3 audits all 25 rows of the live `AI.prompt` table and catalogues thirteen
defects. Two of them are directly predictive of what happens to an unvalidated
`NVARCHAR(1000)` free-text column in this product:

- **D10 — live garbage prompts.** Four rows contain no usable prompt content at all:
  `sdwdxs` (id 18), `rfvdytvfgvcyt` (id 17), `...` (id 15), `esfsaf@#` (id 22). All four are
  `isActive = 1, isDeleted = 0` — that is, **live**. Somebody typed test junk into a prompt
  field and it reached production and stayed there, because nothing validates prompt content
  on authoring.
- **D7 — copy-paste forks.** Prompt ids 8, 10, 20 and 21 are near-identical variants of the
  same prompt; ids 10 and 20 are **both active simultaneously**. Free-text prompt authoring
  with no diff and no dedup produces divergent near-copies that nobody can tell apart later.

`AI.fieldDescription.description` is the same kind of surface: a free-text box an
administrator types into, whose content silently becomes part of what the model is told. The
epic proposes no validation on it at all.

**Recommendation: authoring validation ships with the write path (§4.4), not as a follow-on.**
The minimum, adapting §6.4's fragment validation rules to this table:

- a minimum meaningful length (a description of `...` or `sdwdxs` must be rejected at write
  time, not discovered in a prompt six months later);
- no unresolved `&lt;&lt;…&gt;&gt;` slot markers — §1.3's D9 shows unescaped slot injection is
  already a live defect via `&lt;&lt;templateName&gt;&gt;`, and a description field is a new
  way in;
- reject control characters and normalise whitespace;
- and on the read side, a simple report of descriptions that are suspiciously short or
  duplicated across mappings, so D7-style forks are visible.

None of this is expensive. All of it is cheaper than the alternative, which this codebase has
already demonstrated.

### Finding 3 & 4 (detail) — the audit trigger, and a gap in it

`pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` lines 23–65 define
`[Template].[fields_Audit_History]`, an `AFTER UPDATE` trigger writing the pre-update row to
`[log].[fields_Audit_History]`.

This **supports the epic's read-only argument** (§2.4): `Template.fields` is not a table to
casually add columns to. A new column would need adding to the table, the log table, and the
trigger's two column lists — three places, with silent data loss if the trigger is missed.

**And that failure has already occurred.** The trigger copies 15 columns — `fieldID`,
`fieldName`, `fieldType`, `displayName`, `createdBy`, `CreatedDate`, `isActive`,
`defaultValue`, `importData`, `chargeCategoryName`, `variant`, `isShowinPDF`, `prompt`,
`allowAISummary`, `aiSummaryPrompt`. The table has **16** columns. **`abbreviation`
(line 17) is not audited** — changes to it are not recorded anywhere.

That is a pre-existing defect, out of scope here, and worth a separate ticket. It is also the
best possible evidence for why this story should not add a column to `Template.fields`: the
last person to add one hit exactly this trap.

### Finding 6 (detail) — no description control exists

Per Finding 1, the field editor exposes `prompt`, `allowAISummary` and `aiSummaryPrompt`. It
does **not** expose a per-mapping `description`, and could not — the editor edits
`Template.fields` rows, which are global, whereas this table is keyed per mapping.

A per-mapping editor is a different UI: the author must be editing *a field within a section
within a template*, not a field. The template editor's structure —
`template-editor.component.ts` composing `add-edit-section` and `add-edit-field` — does place
the author in that context, so the natural home is a description input on the field row *as it
appears within a section*, writing to the mapping triple rather than to `Template.fields`.

Without it the table stays empty, and an empty `AI.fieldDescription` means Epic 3's schema
builder sends the model no field semantics — which is the status quo, and the thing REQ-03-01
exists to fix. Same shape of risk as PEA-206 Finding 3: shipping the table without the
authoring surface delivers nothing observable.

---

## 2. Current state — verified inventory

### 2.1 `Template.fields` as it actually is

```
[fieldID]            INT            IDENTITY (1,1) NOT NULL   -- PK_fieldID
[fieldName]          VARCHAR (255)  NOT NULL
[fieldType]          VARCHAR (255)  NOT NULL
[displayName]        VARCHAR (255)  NOT NULL
[createdBy]          INT            NULL
[CreatedDate]        DATETIME       NULL
[isActive]           INT            NULL
[defaultValue]       VARCHAR (MAX)  NULL
[importData]         VARCHAR (55)   NULL
[chargeCategoryName] VARCHAR (55)   NULL
[variant]            VARCHAR (20)   NULL
[isShowinPDF]        INT            NULL
[prompt]             VARCHAR (MAX)  NULL
[allowAISummary]     BIT            NULL
[aiSummaryPrompt]    NVARCHAR (MAX) NULL
[abbreviation]       VARCHAR (20)   NULL
```

Note `isActive INT` and `isShowinPDF INT` — booleans stored as integers. This is exactly the
shape that caused PACT2-1105 (CLAUDE.md rule 2's cited failure: `bool?` declared against an
integer column, producing an HTTP 400). Relevant because any new code joining this table must
match those types, not assume `BIT`.

There is **no `description` column** on `Template.fields`. The only adjacent thing is
`abbreviation VARCHAR(20)`, which is a short label, not semantics.

`Template.section` does have a `description VARCHAR(1000)` column — section-level, global, and
not per-mapping. Worth noting because the 1000-length choice in this story matches it, which
is a small consistency win.

### 2.2 The grain columns

| Column | Source | Verified type | Evidence |
|---|---|---|---|
| `templetID` | `Encounter.encounterTempletMapping` | `INT NOT NULL` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` |
| `sectionID` | same | `INT NOT NULL` | same |
| `fieldID` | `Template.fields` | `INT IDENTITY`, PK `PK_fieldID` | `fields.sql` line 2 |

All three `NOT NULL`, so a composite PK is viable without sentinel handling.

The `templetID` spelling is mandatory — CLAUDE.md rule 8 and REQ-02-09.

### 2.3 Why this is "table five when REQ-02-10 names four"

The epic addresses this directly and the audit finds the reasoning sound. The 4Pager predates
reconciling per-mapping storage with REQ-02-07's "existing clinical tables remain read-only and
unchanged." A per-mapping description cannot be a column on `Template.fields` (wrong grain —
global) or on `Encounter.encounterTempletMapping` (right grain, but read-only), so it must be a
new AI-schema table.

Worth stating in the PR as "Phase 1 table five of five," per the epic's own scope note, so the
count discrepancy does not read as scope creep.

### 2.4 The read-only argument, strengthened

REQ-02-07 requires existing clinical tables to remain unchanged. The audit adds two concrete
reasons beyond the requirement:

1. **`Encounter.encounterTempletMapping` is the natural grain and is off limits.** It carries
   the exact triple, and it has its own audit trigger to
   `Log.encounterTempletMapping_Audit_History`.
2. **`Template.fields` has an audit trigger whose column list has already drifted**
   (Finding 4). Adding a column there means touching the table, the log table and two lists in
   the trigger — and the `abbreviation` gap proves that process fails in practice.

So the new-table decision is not merely requirement compliance; it avoids a demonstrated
failure mode.

### 2.5 Name collision check

Case-insensitive search across all 2,834 `.sql` files: **`fieldDescription` — 0 matches.** Free.

### 2.6 How it ships

Inherited unchanged: no `dacpac` deployment; manual release via
`pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1` reading a git ref;
CLAUDE.md rule 5 registration in `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` or the
object is **silently never deployed**; rule 4 requires canonical file **and** re-runnable
release script; `.sqlproj` line 10 targets SQL Server 2022, not Azure SQL.

---

## 3. Proposed DDL

### 3.1 The table

```sql
CREATE TABLE [AI].[fieldDescription] (
    [templetID]   INT             NOT NULL,
    [sectionID]   INT             NOT NULL,
    [fieldID]     INT             NOT NULL,
    [description] NVARCHAR (1000) NOT NULL,
    [createdUtc]  DATETIME2 (7)   CONSTRAINT [DF_fieldDescription_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    [updatedUtc]  DATETIME2 (7)   CONSTRAINT [DF_fieldDescription_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldDescription] PRIMARY KEY CLUSTERED ([templetID] ASC, [sectionID] ASC, [fieldID] ASC)
);
```

That is the whole table. Its smallness is a feature — resist additions.

### 3.2 Changes from the epic's DDL, with reasons

| Epic | This spec | Why |
|---|---|---|
| `DEFAULT SYSUTCDATETIME()` | `DEFAULT (getutcdate())` | Zero precedent for `SYSUTCDATETIME` in table DDL; `patientAlertJobLog.sql` line 11 is the house form. `DATETIME2(7)` retained. |
| unnamed PK | named `PK_fieldDescription`, explicit `CLUSTERED` | House convention — `PK_<table>`; `V28Hierarchy.sql` line 6 names its composite PK. |
| — | no other change | The epic's design is right; see §3.4 |

Deliberately **not** added: an `isActive` flag (a description either exists or does not —
deleting the row is the deactivation), a version column (this is current state, not history,
same reasoning as PEA-206), and any secondary index (see §3.3).

### 3.3 The composite PK, and why no secondary index

Keeping the epic's composite PK per Finding 2. The clustered index on
`(templetID, sectionID, fieldID)` directly serves the one access pattern — "give me every
description for this template" — because `templetID` leads. A `WHERE templetID = @x` query is
a single range seek returning contiguous rows.

No secondary index is needed and none should be added speculatively. If a per-field-across-
templates read ever appears (e.g. "where is fieldID 412 described differently?"), that is a new
access pattern warranting a deliberate index, not a pre-emptive one.

### 3.4 Excluding `name`, `type` and `unit` — endorsed

The epic deliberately omits these, and the audit confirms the reasoning holds against the live
schema. `fieldName`, `fieldType` and `displayName` are all live `NOT NULL` columns on
`Template.fields` (lines 3–5). Copying them here would create a second source of truth that
drifts the moment someone renames a field in the template editor — and `displayName` edits are
known to reach up to 179 of 458 templates.

Epic 3's schema builder joins them in at request time. That is correct, and the exclusion
should be defended in review rather than treated as an oversight. The epic's DoD item — a
test or review confirming no `name`/`type`/`unit` column exists — is worth keeping precisely
because the omission looks like a gap to a fresh reader.

`unit` is also now owned by PEA-206's `AI.fieldConstraint`, which is the right home: a unit is
a validation concern, not a semantic description. Two stories agreeing on this makes it a
convention worth stating once, in the epic.

**The approved architecture makes this a third agreeing voice.** Doc 3777 §6.1 defines L3 as a
**generated** field manifest, and [Phase 1](solution-doc:3776) §3 confirms the manifest is
derived from the template's own field set at composition time rather than stored. So name,
type and display name are generated into the prompt from `Template.fields`, and unit reaches
the prompt through L4's constraint digest compiled from `AI.fieldConstraint` (§11's compiled
shape carries `unit` and `alt_units` there, not in any description structure). Three
independent designs — the epic, PEA-206, and the target architecture — all place these
attributes outside this table. The exclusion is not an oversight by any reading, and the DoD
item asserting their absence should be kept and cited to §6.1 in the PR.

### 3.5 No caching — and how that is lost in each runtime

The epic forbids caching this table at module or process scope, because REQ-03-06 requires an
edited description to take effect on the very next request with no deployment.

**This is easy to lose in translation, and the trap differs by runtime.** Both runtimes are in
play: the TypeScript AI service is the eventual owner of the read path, and the .NET API is
the interim first consumer (§4.3).

**TypeScript / Node — the idioms that would break it:**

- **Module-level memoisation.** A Node module body executes once per process, so
  `const descriptions = await loadAll()` at module scope, or a module-scope `Map` keyed by
  `templetID`, freezes the data for the lifetime of the worker. This is the single most likely
  way the rule is broken, because it reads as idiomatic Node rather than as a cache.
- **A singleton repository instance** captured in a closure and reused across requests, with
  rows held on the instance.
- `node-cache`, `lru-cache` or a memoising decorator wrapped around `forTemplet()` — again,
  it would look like a sensible optimisation on a small hot table.
- Azure Functions **Node.js v4 warm-instance reuse**: state assigned outside the `app.*`
  handler survives between invocations on the same instance. Anything cached there persists
  invisibly until the instance recycles.

The correct TypeScript shape is a plain `async forTemplet(templetId)` that issues the query
every call, holding no state on the reader between invocations.

**.NET — the idioms that would break it (relevant while the interim read path exists):**

- registering the reader as a **singleton** instead of scoped —
  `pacEHR_API/PacEHR.Functions.Process/Program.cs` line 14 registers the procedures context as
  **Scoped**, which is the correct precedent to follow;
- `IMemoryCache` around the read;
- EF Core change-tracking holding a stale entity across a request.

The read is a single indexed range seek on a table with one row per field mapping. It is
cheap. **The correct optimisation here is none**, and the DoD should assert it in whichever
runtime ships first: a test or review confirming no module-scope, instance-scope or
library cache wraps the call, and (in .NET) that the reader is not a singleton.

**There is now a second, independent reason for the no-caching rule: the audit trail.** Doc
3777 §12 makes self-hosted tracing mandatory (PHI and BAA constraints rule out SaaS tracing)
and requires every traced call to record the fragment versions and the `prompt_hash` of the
compiled prompt, alongside per-field evidence spans. A cache in front of this read breaks that
guarantee quietly: the trace would record the description text the process happened to be
holding, which may no longer be what the table says. Two runs with identical traces could have
been composed from different description text, and the recorded `prompt_hash` would be the
only hint — with nothing to attribute the change to.

So the rule is not merely a freshness convenience for REQ-03-06. **A cached description makes
the compliance trace unreliable**, which raises the cost of getting it wrong considerably.
State it in the PR in those terms; "no cache, because it must be fresh" invites a reviewer to
propose a short TTL as a compromise, whereas "no cache, because the audit trail must match
what was actually sent" does not.

If this read ever does become hot enough to matter, the correct answer is the one the
architecture already uses for L0: cache the *invariant* layers, never the authored ones.

### 3.6 Epic design points the audit endorses

- **One row per mapping, `description NOT NULL`.** Correct — a row whose description is NULL
  is a row that should not exist.
- **`NVARCHAR(1000)`.** Matches `Template.section.description VARCHAR(1000)`; `NVARCHAR`
  correctly chosen over `VARCHAR` since clinical prose may carry non-ASCII (°, µ, ≥).
  "One line of description" (REQ-03-03) is well within 1000.
- **No surrogate id.** See Finding 2 — defensible, with `V28Hierarchy` as precedent.
- **Bulk read per template** (`for_templet`, REQ-03-04). Correct, and it is why the PK's
  column order is what it is. PEA-206 should adopt the same pattern (noted there).
- **No PHI, no retention concern.** Confirmed — descriptions are configuration authored by
  clinicians about field semantics, not patient data. As with PEA-206's `sourceProse`, the
  free-text field could have patient detail pasted in; authoring guidance is a cheap safeguard.

---

## 4. Delivery plan

### 4.0 The story at a glance

**Assume nothing is delivered.** But note what already ships: `Template.fields` carries both
`prompt` and `aiSummaryPrompt` (plus `allowAISummary`), and the template editor already
exposes per-field AI instructions. **This story overlaps a live surface** — it does not arrive
on empty ground.

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `0006_ai_fielddescription.sql` — composite clustered PK, no surrogate, `NVARCHAR(1000) NOT NULL` | A — **can start today** | PEA-201, D16 | 1–2 |
| **DDL** | Read/write procedures (bulk read by `templetID`) | A | DDL | 1 |
| **Runtime** | `src/repositories/fieldDescriptionRepository.ts` | C | M9 port | 1 |
| **Surface** | 🔴 **M6 — description authoring, merged with PEA-206b** | D | **D7** | **5** |
| **Decision** | 🔴 Precedence vs `aiSummaryPrompt` | — | **D6**, and Epic 3 implements it | 0 |
| | | | **Total** | **3 · 8 with the UI** |


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

### 4.0a Run the sizing query before deciding D6 — it may make the decision trivial

D6 asks whether `AI.fieldDescription.description` or `Template.fields.aiSummaryPrompt` wins.
That reads like an architecture debate; it may be an empirical question. **Count the
non-null, non-empty `aiSummaryPrompt` values first** (the query is in §5.4). If the number is
small, the answer is "migrate them and retire the column," and the debate does not need to
happen. If it is large, D6 is real and Epic 3 needs it settled before its schema builder is
written.

**Either way this runs at grooming, not at implementation** — it is one `SELECT` and it
changes who needs to be in the room.

### 4.0b The two traps this table carries

1. **D20 — this table has no home in the approved prompt composition.** Doc 3777 §6.1's
   six layers L0–L5 have no slot for authored per-field text: L3 is *generated*, L4 is
   *compiled*, L2 is per-template-*family*. So `description` is a column with a writer, a
   reader, and **no defined injection point**. Left open, Epic 3 and Epic 8 will each invent
   one, or the text is silently dropped and nobody notices because nothing errors. **This is
   one question covering two stories** — take it with PEA-205's `template_override`, which is
   orphaned for the same reason (rollup R11).
2. **No caching — and in Node that rule is easy to break without looking like caching.**
   REQ-03-06 forbids caching this read, and the reasoning is sound: it is one indexed range
   seek, and a cached description makes doc 3777 §12's per-call `prompt_hash` stop matching
   what was actually sent. ⚠️ **Module-scope `const`/`Map` memoisation and Azure Functions v4
   warm-instance state both persist across invocations and both read as ordinary Node.**
   Neither looks like a cache in review. Put both on the checklist explicitly (rollup R17) —
   the .NET reviewer's habits (`IMemoryCache`, `AddSingleton`) catch neither.

### 4.0c Authoring validation is not optional here

This product has **already shipped rotten free-text prompts to production** — four
content-free values live in `AI.prompt` because nothing validated authoring. `description` is
the same kind of surface with the same absence of validation. **M8 applies to this column as
much as to `fragmentText`**, and it is 2–3 points for both together. Doing it once, for both,
at the point the authoring UI is built, is the only cheap moment.

**Exit criterion:** a bulk read by `templetID` returns one description per mapping; two
templates sharing a `fieldID` return different descriptions; and a second identical read
issues a second query (proving the no-cache rule, per §5.5).

### 4.1 Phase 0 — Unblock

| # | Decision | Owner | Blocks |
|---|----------|-------|--------|
| 0.1 | **Precedence between `description` and `Template.fields.aiSummaryPrompt`** (Finding 1) | Product + Architecture | Epic 3's schema builder |
| 0.2 | **Is the authoring UI in this story, a follow-on, or deferred?** | Product | whether the table is ever populated |
| 0.3 | Composite PK accepted despite thin precedent (Finding 2) | Tech lead | DDL |
| 0.4 | Is `Template.fields.prompt` also in scope for consolidation, or left alone? | Product | scope |
| 0.5 | Grants: `aiTemplateAdmin` does not exist | Architecture + DBA | the security DoD |
| 0.6 | **AI service readiness: the AI Orchestrator ([doc 3777](solution-doc:3777) §3.1) is approved in design, its repository (`pacEHR_AI/`) exists and is empty, and the greenfield Node build has not started.** Is the Node repository stood up and staffed, and is Epic 02 sequenced around it? Language resolved; timing and staffing are not | Architecture | the module |
| 0.6a | **Who authors the TypeScript foundation this reader sits on?** **src/core/settings.ts** (zod), **src/core/database.ts** (node-mssql), plus `llm.ts`/`errors.ts`/`logging.ts`/`auth.ts` — and a **Node dependency allow-list to replace [the reference symbol allow-list](solution-doc:5091)**, which governs libraries and does not apply to a Node runtime at all. There is no published Node equivalent of the Epic-01 foundation backlog | Architecture + Tech lead | the read path in §4.3 |
| 0.6b | **What reads this table until the TypeScript service exists?** §4.3 proposes the .NET API as interim first consumer. Confirm that is a deliberate first consumer rather than a fallback, and that it stays SELECT-only | Architecture | Phase 2 |
| 0.7 | Confirm PEA-201 has landed | — | the schema |
| 0.8 | **Where does `description` enter the six-layer prompt composition?** The approved model (doc 3777 §6.1) has no layer for per-field authored free text — L3 is generated, L4 compiled, L2 per-template-family. Most plausibly L3 gains an authored overlay, but that changes L3's stated contract | Architecture | Epic 3's schema builder; Finding 13 |
| 0.9 | **Is `description` subject to §6.4's fragment rules** — immutable versions, authoring validation, and an eval set with promotion blocked on no regression? If it is prompt content in substance, it arguably should be; the epic's DDL gives it none of those | Architecture + Product | whether the DDL needs a version column after all |
| 0.10 | **Does `description` participate in the §6.1 `prompt_hash`?** If yes and it is unversioned, the §12 trace records that the prompt changed but not what changed it | Architecture | the compliance trace |

**0.1 is the blocker that matters** for what the model is told, and if it goes unstated,
Epic 3's implementer will pick one by accident. **0.8 is now its equal** — 0.1 decides *which
text* reaches the model, 0.8 decides *whether there is anywhere to put it*. Both are
Architecture conversations that cost an hour now and a redesign later. Note that 0.9 is the
only Phase 0 item that could still change the DDL in §3.1: if `description` must be an
immutable versioned fragment, the current single mutable column is the wrong shape.

### 4.2 Phase 1 — The table

1. Create Tables/AI.fieldDescription.sql per §3.1.
2. Create the re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/&lt;JIRA-KEY&gt;-fieldDescription.sql,
   guarded with an existence check.
3. Register **both** in the `.sqlproj` — rule 5.
4. Run the release harness; confirm `PASS`.

### 4.3 Phase 2 — Read path

⚠️ **Two consumers, one table.** The eventual owner of this read is the ported
**TypeScript AI service**. The **.NET API is the interim first consumer** (per 0.6b) — a
deliberate first consumer, not a fallback, because the TypeScript repository does not exist
yet and the table is worthless unread. Both paths are SELECT-only; neither writes.

**Interim .NET read path:**

5. `usp_getFieldDescriptionsForTemplate` in Stored Procedures/Procs2/ — rule-6 naming, header
   block, Jira key, `CREATE OR ALTER PROCEDURE`. Takes `@templetID`, returns every mapping's
   description in one call (REQ-03-04).
6. Expose through `pacehr_devContextProcedures` / `Ipacehr_devContextProcedures`.
7. Register the reader **Scoped, never Singleton** (§3.5).

**Module mapping — corpus reference to build target:**

| Corpus artefact (reference design) | Build target (TypeScript) | Interim (.NET) |
|---|---|---|
| **core/field_description_repository.py** | **src/repositories/fieldDescriptionRepository.ts** | a domain service beside `pacEHR.DomainServices/AIPromptServices.cs` |
| `SELECT_FIELD_DESCRIPTION_SQL` | **unchanged** — module-level SCREAMING_SNAKE constant holding the same T-SQL, no interpolation | `usp_getFieldDescriptionsForTemplate` in Procs2/ |
| `class FieldDescriptionReader.for_templet(templet_id)` | `class FieldDescriptionReader.forTemplet(templetId)` — class name survives, method camelCased | one read method, scoped lifetime |
| zod row model | zod schema + `z.infer<>` | a POCO/DTO |
| the `mssql` npm package + the async driver | `await database.execute(...)` over node-mssql — **natively async, the thread-pool wrapper disappears** | existing EF/Dapper context |
| vitest | vitest | xUnit |

Note the SQL text itself is identical in all three columns — this table's access pattern is a
single parameterised range seek, so nothing about the query changes with the runtime. What
changes is only which module issues it.

**Ordering consequence:** the TypeScript column above depends on **src/core/database.ts** and
**src/core/settings.ts** existing, which is Phase-0 item 0.6a. Until that foundation lands,
column three is the only column that can ship.

### 4.4 Phase 3 — Write path

8. `usp_addEditFieldDescription` — upsert on the mapping triple, setting `updatedUtc`.
9. **Authoring validation on the write path** (Finding 15), adapting doc 3777 §6.4's fragment
   validation rules to this table. Minimum: reject a description below a meaningful minimum
   length; reject unresolved `&lt;&lt;…&gt;&gt;` slot markers; reject control characters and
   normalise whitespace. This is not gold-plating — §1.3 D10 records four content-free prompts
   live in production today because nothing validated them at authoring time.
10. A delete procedure, or a documented decision that descriptions are never removed. With no
    `isActive` flag, deletion is the only way to remove one, so the path should exist.
11. Grants per 0.5.

### 4.5 Phase 4 — Authoring UI (scope per 0.2)

12. Add a per-mapping description input in the template editor, in the context of a field
    within a section — distinct from the existing global `aiSummaryPrompt` control at
    `add-edit-field.component.ts` line 83.
13. **Make the distinction visible in the UI.** If both surfaces remain (0.1 option A or B), an
    author needs to understand why there are two boxes. Label them by grain: "applies to this
    field everywhere" versus "applies to this field in this section of this template."
14. Surface the step-9 validation errors inline in the editor, so an author sees why a
    description was rejected rather than discovering it silently failed.

---

## 5. Verification

### 5.1 Deployment checks

```sql
SELECT s.name AS schemaName, t.name AS tableName
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'AI' AND t.name = 'fieldDescription';

SELECT c.name, ty.name AS dataType, c.max_length, c.is_nullable
FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'[AI].[fieldDescription]') ORDER BY c.column_id;

-- confirm the composite clustered PK and its column order
SELECT i.name, i.type_desc, i.is_primary_key, c.name AS columnName, ic.key_ordinal
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'[AI].[fieldDescription]')
ORDER BY i.index_id, ic.key_ordinal;
-- expect: PK_fieldDescription, CLUSTERED, templetID(1), sectionID(2), fieldID(3)

-- assert the deliberate omissions (section 3.4)
SELECT COUNT(*) AS mustBeZero FROM sys.columns
WHERE object_id = OBJECT_ID(N'[AI].[fieldDescription]')
  AND name IN ('name','fieldName','type','fieldType','unit','displayName');
```

### 5.2 The per-mapping grain — using the epic's exact fixtures

```sql
INSERT INTO [AI].[fieldDescription] (templetID, sectionID, fieldID, description)
VALUES (3, 11, 412, N'Vital sign as measured and stated at the bedside. Systolic over diastolic.'),
       (3, 12, 412, N'Blood pressure only when re-measured during the physical examination. If the value was already captured in Review of Systems, leave this empty.');

SELECT sectionID, description FROM [AI].[fieldDescription]
WHERE templetID = 3 AND fieldID = 412 ORDER BY sectionID;
-- expect: 2 rows with materially different text — the reason this table exists
```

```sql
-- must fail: duplicate mapping
INSERT INTO [AI].[fieldDescription] (templetID, sectionID, fieldID, description)
VALUES (3, 11, 412, N'A second description for the same mapping.');
-- expect: PK violation

-- must fail: NULL description
INSERT INTO [AI].[fieldDescription] (templetID, sectionID, fieldID, description)
VALUES (3, 13, 500, NULL);
-- expect: NOT NULL violation
```

### 5.3 The bulk read

```sql
-- REQ-03-04: every description for a template in one call, one range seek
EXEC [AI].[usp_getFieldDescriptionsForTemplate] @templetID = 3;
```

Check the actual plan is a clustered index **seek**, not a scan. If it is a scan, the PK column
order is wrong.

### 5.4 Overlap with the existing surface — run this before deciding 0.1

```sql
-- how many fields already carry global AI instructions? This sizes the precedence problem.
SELECT COUNT(*) AS fieldsWithAiSummaryPrompt
FROM [Template].[fields]
WHERE [aiSummaryPrompt] IS NOT NULL AND LTRIM(RTRIM([aiSummaryPrompt])) <> '';

SELECT COUNT(*) AS fieldsWithPrompt
FROM [Template].[fields]
WHERE [prompt] IS NOT NULL AND LTRIM(RTRIM([prompt])) <> '';
```

If these return zero, option C (deprecate and migrate) is nearly free. If they return
hundreds, precedence is a live behavioural question affecting existing output. **Run this
before grooming**, not after.

### 5.5 No caching

Assert in test or review that:

- the reader is registered **Scoped**, not Singleton (compare
  `pacEHR_API/PacEHR.Functions.Process/Program.cs` line 14);
- no `IMemoryCache`, `static` dictionary or lazily-initialised field wraps the read;
- an updated description is visible to the very next request without a restart (REQ-03-06).

### 5.6 Definition of Done

- [ ] Tables/AI.fieldDescription.sql created per §3.1
- [ ] Composite PK `(templetID, sectionID, fieldID)`, clustered, named `PK_fieldDescription`;
      column order verified by the §5.1 query
- [ ] `templetID`, `sectionID`, `fieldID` spelled exactly as the live database spells them,
      **not** "corrected" — rule 8 and REQ-02-09
- [ ] `description NVARCHAR(1000) NOT NULL`; a test asserts NULL is rejected
- [ ] A test or review confirms **no** `name`, `type` or `unit` column exists, with the
      single-source-of-truth reasoning recorded (§3.4)
- [ ] A test covers the per-mapping grain using the epic's **exact** §3.1 fixture text for
      (3, 11, 412) and (3, 12, 412)
- [ ] A test asserts a duplicate mapping is rejected by the PK
- [ ] Re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/ with the Jira key
- [ ] **Both** files registered in the `.sqlproj` (`<Build>` + `<None>`) — rule 5
- [ ] Release harness run; `PASS` verdict, no duplicate-object hit
- [ ] `usp_getFieldDescriptionsForTemplate` in Procs2/ with rule-6 naming, header block, Jira
      key; returns all mappings for a template in one call (REQ-03-04)
- [ ] The read plan is a clustered index **seek**, verified (§5.3)
- [ ] **No cache wraps the read** — asserted by test or review (§5.5). REQ-03-06 requires
      next-request effect with no deployment. In **TypeScript**: no module-scope constant or
      `Map`, no instance state on the reader, no `lru-cache`/`node-cache`/memoised
      `forTemplet()`, and nothing cached outside an Azure Functions v4 handler where warm
      instances would retain it. In **.NET** (interim path): registered Scoped, not Singleton;
      no `IMemoryCache`, `static` dictionary or lazily-initialised field.
- [ ] **If the TypeScript reader ships:** **src/repositories/fieldDescriptionRepository.ts**
      exports `FieldDescriptionReader.forTemplet(templetId)`, the SQL lives in a module-level
      `SELECT_FIELD_DESCRIPTION_SQL` constant with **no string interpolation** (parameterised
      `@templetID` only), the row shape is a zod schema with `z.infer<>`, the call is
      `await database.execute(...)` over node-mssql with **no the async driver-style
      wrapper**, and tests are **vitest**
- [ ] A delete path exists, or its absence is a recorded decision (no `isActive` flag exists)
- [ ] **The PR states explicitly** the precedence rule agreed in 0.1 between
      `AI.fieldDescription.description` and `Template.fields.aiSummaryPrompt`, and names where
      Epic 3 implements it
- [ ] **The PR states explicitly** that this is "Phase 1 table five of five," per the epic's
      scope note, so the REQ-02-10 count discrepancy does not read as scope creep
- [ ] **The PR states explicitly** that no per-mapping description UI exists, and either
      scopes it here or names the follow-on story (0.2)
- [ ] **The PR notes** the composite-PK departure from the surrogate-key convention, with the
      `V28Hierarchy` precedent and the access-pattern reasoning
- [ ] **Authoring validation implemented on the write path** (§4.4 step 9): minimum length,
      no unresolved `&lt;&lt;…&gt;&gt;` slot markers, no control characters. A test asserts a
      junk description is rejected
- [ ] **The PR records** where 0.8 landed — which prompt layer `description` is injected into,
      or that the question is still open with Architecture
- [ ] No PHI — stated; `description` flagged as free text with authoring guidance
- [ ] PR title, branch name and commit message all carry the literal Jira key; one concern per PR
- [ ] PR checklist complete: unit tests · DB script · technical documentation · AI usage

---

## 6. Risk register

| # | Risk | L | I | Mitigation |
|---|------|---|---|------------|
| 1 | **Precedence vs `aiSummaryPrompt` undecided → Epic 3 picks one by accident** | High | **Critical** | 0.1; run §5.4 before grooming |
| 2 | **No authoring UI → table stays empty → REQ-03-01 delivers nothing** | High | High | Finding 6; 0.2 |
| 3 | Reader cached → edits need a restart, breaking REQ-03-06. In TypeScript the likely form is **module-scope memoisation or Azure Functions v4 warm-instance state**, which reads as idiomatic Node rather than as a cache; in .NET it is Singleton registration or `IMemoryCache` | Med | High | §3.5, §5.5; the tempting "optimisation" |
| 4 | Two authoring surfaces confuse template authors | High | Med | Phase 4 step 12 — label by grain |
| 5 | Composite PK flagged and "corrected" to a surrogate, losing the seek | Med | Med | §3.3; note the departure with reasons in the PR |
| 6 | `name`/`type`/`unit` added later as a convenience → second source of truth | Med | High | §3.4; the explicit DoD assertion |
| 7 | Someone adds the column to `Template.fields` instead and misses the audit trigger | Low | High | §2.4 — the `abbreviation` gap is the cautionary precedent |
| 8 | PK column order reversed → bulk read becomes a scan | Low | Med | §5.1 ordinal check; §5.3 plan check |
| 9 | PHI pasted into `description` | Low | High | Authoring guidance; note in the PR |
| 10 | `aiTemplateAdmin` does not exist; write restriction advisory only | High | Med | 0.5; procedure boundary as interim control |
| 11 | No delete path; obsolete descriptions accumulate | Med | Low | Phase 3 step 9 |
| 12 | Node service not yet stood up → table ships correct and empty, waiting on a consumer. **Downgraded at Revision 6:** the wait is a bounded 5–8-point port from `pacEHR_AI/src/core/`, not an unscoped build | Med | Med | 0.6; §1 Finding 11; ⛔ the interim .NET read path is withdrawn at Revision 7 — no mitigation remains |
| 12a | **No TypeScript foundation and no Node dependency allow-list.** **src/core/{settings,database,llm,errors,logging,auth}.ts** do not exist, and `the reference symbol allow-list` governs libraries — it does not constrain a Node runtime at all. Without an equivalent, dependency choices get made ad hoc in the first PR | **High** | High | 0.6a — author the Node allow-list and the `src/core/` foundation before any repository module |
| 13 | `.sqlproj` registration missed → silently never deployed | Med | High | Manifest test; harness verdict |
| 14 | SSDT targets SQL Server 2022, deployment may be Azure SQL | Med | Med | Inherited from PEA-201 |
| 15 | **`description` has no layer in the approved six-layer composition** → Epic 3 either invents an injection point or quietly drops the text; either way the highest-value requirement in the corpus delivers nothing | **High** | **Critical** | §1 Finding 13; 0.8 — raise with Architecture while the model is still on paper |
| 16 | Unvalidated free text rots in production, exactly as `AI.prompt` already has — four garbage prompts live today | **High** | High | §1 Finding 15; authoring validation in Phase 3, not deferred |
| 17 | Option B (send both surfaces) adopted by default → two unversioned inputs to a hashed, audited prompt; a hash change cannot be attributed | Med | High | §1 Finding 13 rejects B outright; 0.1 |
| 18 | `description` unversioned while §6.4 requires immutable versioned fragments → DDL needs a version column after ship | Med | High | 0.9 — the only Phase 0 item that can still change §3.1 |
| 19 | A cache or short TTL added as an optimisation → §12 compliance trace no longer matches what was sent | Med | High | §3.5's audit-trail framing; §5.5 assertion |

**On the estimate.** 3 points is right for the table, two procedures and the tests — this is
the smallest table in the epic. If the authoring UI comes into scope, add 5. The precedence
decision (0.1) costs nothing to make and a great deal to defer.

Recommend splitting if the UI is wanted: **PEA-207a** (table + procedures, 3) and
**PEA-207b** (per-mapping description authoring in the template editor, 5) — and note that
207b and PEA-206b touch the same component, so they should be sequenced together or merged.

---

## 7. Recommended immediate actions

1. **Run the §5.4 overlap query before grooming.** It converts 0.1 from an abstract argument
   into a sized decision: if few fields use `aiSummaryPrompt`, option C is nearly free.
2. **Decide 0.1 and write the precedence rule into the epic**, so Epic 3 implements a decision
   rather than an assumption. This is the single highest-value action on this story.
3. **Decide 0.2 (authoring UI)**, and note that PEA-206b and PEA-207b modify the same template
   editor components — do them together.
4. **Raise the `abbreviation` audit-trigger gap as a separate defect.** `Template.fields`
   changes to that column are silently unaudited today.
5. **Add the no-caching requirement to the code review checklist.** Risk 3 is a plausible,
   well-intentioned optimisation that quietly breaks a stated requirement.
6. **State the "table five of five" framing in the PR** so the REQ-02-10 count is not
   re-litigated.
7. **Take 0.8 to Architecture in the same conversation as 0.1.** The approved six-layer
   composition (doc 3777 §6.1) has no layer for per-field authored free text, so this table
   has no assigned home in the model Epic 3 will build against. This is cheap to fix on paper
   and expensive to fix after the schema builder exists. Ask the three questions in Finding 13:
   where is it injected, is it subject to §6.4's versioning and eval rules, and does it
   participate in the `prompt_hash`.
8. **Put authoring validation in Phase 3, not in a follow-on.** The live `AI.prompt` table
   already carries four content-free prompts and two simultaneously-active near-duplicate
   forks (doc 3777 §1.3, D10 and D7), because nothing validated them at write time. This table
   is the same kind of surface and will decay the same way.
9. **Commission the Node dependency allow-list (0.6a) now — it is the Epic-01-equivalent
   blocker for this story's read path.** The corpus's governing allow-list,
   [the reference symbol allow-list](solution-doc:5091), constrains libraries and has no
   force over a Node runtime. Someone must decide and write down the Node equivalents before
   the first PR makes them by default: **node-mssql** for data access, **zod** for schema and
   config validation, **vitest** for tests, `@azure/functions` v4 for hosting. Note that the
   agent-framework choice (LangChain.js vs Vercel AI SDK vs Mastra) is **not** needed for this
   story — this table's reader is a plain parameterised query — so do not let that larger
   decision block Epic 02.
10. **Confirm 0.6b explicitly: the .NET read is the interim first consumer, not a fallback.**
    The table is worthless unread, and the TypeScript service does not exist. Shipping the
    .NET reader in §4.3 column three is what makes this story observable. Record that it is
    SELECT-only and that ownership transfers to
    **src/repositories/fieldDescriptionRepository.ts** when the service lands — otherwise the
    interim path quietly becomes permanent and a second source of read logic.
11. **Do not let the retarget touch the DDL.** Every invariant in §3.1 — the composite
    clustered `PK_fieldDescription` and its column order, `NVARCHAR(1000) NOT NULL`,
    `DEFAULT (getutcdate())`, the deliberate absence of `name`/`type`/`unit`/`isActive`/
    version, and the `templetID` spelling — is language-neutral and unchanged. The
    TypeScript decision changes which module issues the query and nothing about the table or
    the SQL text itself.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - Lines 14–16 declare the live `prompt`/`allowAISummary`/`aiSummaryPrompt` columns this table overlaps; lines 23–65 the audit trigger; line 17 `abbreviation`, the column the trigger omits.
- `PacEHR/src/app/features/settings/template-editor/add-edit-field/add-edit-field.component.ts` - Lines 81–83 declare the AI prompt controls, 101–103 populate them, 192 persists, 245–247 merges — proof the overlapping surface is already user-editable.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` - The natural grain for this data, and read-only per REQ-02-07; establishes the INT NOT NULL triple.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/V28Hierarchy.sql` - Line 6: the only composite `PRIMARY KEY CLUSTERED` in 1,116 table files — the precedent that makes this story's keyless composite PK defensible.
- `pacEHR_API/CLAUDE.md` - Rule 2 datatype chain (and the PACT2-1105 failure), rules 4–8, § Numbers, § Clinical and PHI rules.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11, `DEFAULT (getutcdate())` house form.
- `pacEHR_API/PacEHR.Functions.Process/Program.cs` - Line 14 registers the procedures context Scoped — the correct lifetime precedent for the no-caching requirement.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest; rule-5 silent-failure surface; line 10 DSP targets SQL Server 2022.

### Medium Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/section.sql` - `description VARCHAR(1000)` — the length precedent this story matches, at section grain.
- `PacEHR/src/app/features/settings/template-editor/template-editor.component.ts` - The parent component composing section and field editors; where a per-mapping description control would live.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` - Line 17, the surrogate-PK-plus-UNIQUE convention this story departs from.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` - The `encounterTempleteID` spelling variant and the template-level prompt surface.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Line 16 `templeteId`, one of the three live spellings of "template".
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The partial class the new read procedure must be exposed through; binds by string name.
- `PacEHR/src/app/core/services/template-editor.service.ts` - `addEditField()` call site; where a description service call would be added.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The actual deployment mechanism.

### Low Relevance
- `PacEHR/src/app/core/models/template-editor.model.ts` - Declares `templetID: number`, showing the spelling reaches TypeScript.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14, named-constraint house style.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` - PEA-206's `unit` home; relevant to the §3.4 exclusion argument.
- `pacEHR_API/PacEHR.Tests.UnitTests/` - xUnit + Moq project where the new tests land.
- `pacEHR_API/pipelines/` - 12 files; confirmed to contain no database deployment.
