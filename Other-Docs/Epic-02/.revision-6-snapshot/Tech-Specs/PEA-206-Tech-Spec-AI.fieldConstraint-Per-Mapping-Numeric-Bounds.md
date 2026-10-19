# PEA-206 Tech Spec — AI.fieldConstraint (Per-Mapping Numeric Bounds)

**Epic:** E2 — Data Layer · **Story:** PEA-206 · **Phase:** 1
**Depends on:** PEA-201 · **Satisfies:** REQ-02-02, REQ-02-07, REQ-02-09
**Epic estimate:** 3 points · **Audited estimate:** 3 points for the table; **8–10 with the authoring UI**, which does not exist — see §6
**Prepared for:** Hem · **Solution:** PacEHR-App · **Date:** 2026-09-29
**Status:** Final — audited against the live codebase, evidence-backed, ready for grooming
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

> ⚠️ **Build target: TypeScript/Node.js.** The AI engine is a
> **new, standalone TypeScript/Node.js service** — a repository **not yet created** in this
> solution and **ported from the Python service `pacEHR_AI/`**, and which does **not** reuse the existing C# AI logic in
> `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`. The runtime chain is
> **Angular → .NET Web API → TypeScript AI service → Azure OpenAI**.
>
> The 12-epic Python corpus in the team space is the **reference design and is
> deliberately unmodified**. Everything language-neutral in this spec applies as-is: all T-SQL
> DDL, every column name and datatype, the per-mapping grain, the plausibility bounds, the
> fail-safe-on-missing-constraint rule, the Gherkin acceptance criteria, the REQ- IDs, the
> dependencies and the point estimates. What changes is only the *reader* of this table:
> `src/repositories/fieldConstraintRepository.ts`, calling `database.execute()` on the
> `database` singleton in `src/core/database.ts` (the `mssql` npm package, node-mssql over
> tedious — natively async, so the Python design's `asyncio.to_thread` wrapper disappears),
> with configuration validated by zod in `src/core/settings.ts` and tests in **vitest**.

> **Read this first.** This is the best-fitting story in Epic 02. The table has a near-exact
> structural twin already in production (`Patient.vitalConfig`), and that twin comes with a
> working Angular editor whose validation logic is directly reusable. The two things to fix
> are the `FLOAT` datatype, which is not approved and has a `DECIMAL(6,2)` precedent sitting
> right there, and the assumption that someone can author these bounds — no field-level range
> UI exists anywhere in the product.

---

## 1. Findings — what the audit changed

| # | Finding | Severity | Effect on this story |
|---|---------|----------|----------------------|
| 1 | **`FLOAT` is not an approved datatype**; `DECIMAL(6,2)` is the live precedent for exactly this | 🟠 high | Four column type changes, §3.2 |
| 2 | **`Patient.vitalConfig` is a structural twin** already in production | ✅ major positive | Copy its shape, its types and its editor |
| 3 | **No field-level range/min/max UI exists** — a new editor is in scope or the table is unfillable | 🔴 critical | The real cost of this story |
| 4 | **`add-edit-vital-setting` is directly reusable prior art** for that editor | ✅ major positive | Cuts the UI cost substantially |
| 5 | **Composite PK has almost no precedent** — 1 table in 1,116 | 🟠 high | Relevant to the UNIQUE choice; §3.3 |
| 6 | `unit VARCHAR(20)` matches the live spelling and size exactly | ✅ closed | §3.2 |
| 7 | UNIQUE-constraint precedent confirmed (two live forms) | ✅ closed | §3.1 |
| 8 | `fieldConstraint` name is **free** | ✅ closed | — |
| 9 | **`aiTemplateAdmin` does not exist**; no grants anywhere | 🔴 blocker | Inherited |
| 10 | **No *Node* AI service exists yet** — no `nest-cli.json`, no `serverless.yml`, no backend `package.json` in `PacEHR/` or `pacEHR_API/`. ⚠️ **Revision 6:** `pacEHR_AI/` is a third repository and **does** hold the service, in Python, with Epic 01 complete and tested — so the gate is a 5–8-point port (M9), not an unscoped build | 🟠 med | Sequencing, not a design fault, and narrower than Revision 5 recorded. §1 Finding 10 |
| 11 | `DEFAULT SYSUTCDATETIME()` → `DEFAULT (getutcdate())` | 🟡 medium | §3.2 |
| 12 | The per-mapping grain argument is **correct and well-evidenced** | ✅ endorsed | §2.3 |
| 13 | `"kg\|lb"` in a `unit` column is a **design smell worth flagging** | 🟠 high | §3.4 |
| 14 | **The approved architecture requires TWO range bands; this table has one.** `implausible` blocks, `abnormal` flags and keeps | 🔴 critical | A schema gap Epic 6 cannot work around — §1 Finding 14 |
| 15 | **Fail-safe-on-missing-constraint is an approved requirement**, not just this audit's recommendation | ✅ major positive | Hardens the DoD — §1 Finding 15 |
| 16 | **`AI.fieldConstraint` is named in the architecture's own diagram, with two services touching it** and no ownership boundary stated | 🟠 high | §1 Finding 16 |
| 17 | **Phase 1 should seed the common vitals set**, per the architecture; and `"kg\|lb"` has a proposed answer (`unit` + `alt_units`) | ✅ positive | Mitigates Finding 3 — §1 Finding 17 |

---

### Finding 1 (detail) — `FLOAT` out, `DECIMAL(6,2)` in

The epic specifies `plausibleMin`, `plausibleMax`, `abnormalMin`, `abnormalMax` as `FLOAT`.

CLAUDE.md rule 3's approved list is: `BIT` · `INT` · `NVARCHAR` · `VARCHAR` · `DATETIME` ·
`DATE` · `DATETIME2`. `FLOAT` is not on it.

More usefully, the codebase has already solved this exact problem. `Patient.vitalConfig`
(`pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql`) stores six clinical numeric
bounds and uses `DECIMAL (6, 2)` for every one of them — lines 8, 9, 11, 12, 14, 15. The
mirror file `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig_1.sql` is identical.

`DECIMAL(6,2)` is also *better* here on the merits, not merely more compliant:

- **Binary floating point cannot represent common decimal values exactly.** A plausible
  maximum of `37.5` stored as `FLOAT` is not exactly 37.5, and a boundary comparison
  (`value > plausibleMax`) can therefore go either way at the boundary. For a clinical
  plausibility check, a bound that is ambiguous *precisely at the bound* is the wrong tool.
- `DECIMAL(6,2)` gives a range of ±9999.99 with two decimal places — comfortably covering
  vitals, weights, lab values and scores. If a wider range is ever needed the precedent can be
  widened deliberately; `FLOAT` hides the question.
- Rule 2's SQL → C# → TypeScript chain is cleaner: `DECIMAL` → `decimal?` → `number`.
  `FLOAT` → `double?` invites the same class of mismatch that caused PACT2-1105.

**Recommendation: `DECIMAL (6, 2) NULL` for all four bounds**, matching `vitalConfig` exactly.
If any field genuinely needs a wider range, that is a rule-3 escalation with a stated reason —
not a silent `FLOAT`.

**A secondary point the approved architecture raises: per-field `precision`.**
[2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §11 gives the compiled
constraint shape the orchestrator expects, and it carries a `precision` member alongside the
bounds:

```json
{"field_id":412,"unit":"mmHg","alt_units":[],"implausible":{"min":40,"max":300},
 "abnormal":{"min":90,"max":180},"precision":0,"version":3}
```

`precision: 0` for a blood pressure says *this field is a whole number* — 120, not 120.00.
That is an authored clinical property, not a storage artefact, and the epic's DDL has no
column for it. With `DECIMAL(6,2)` and no `precision` column, rounding behaviour becomes
implicit in the storage type and every consumer decides for itself how many decimals to show
or round to.

This does **not** change the `DECIMAL(6,2)` recommendation — the type is still right, and
storing more precision than a field uses is harmless. It is a smaller gap than the two-band
problem in Finding 14 and can be added later without a data migration, but it is cheaper to
add a `precision TINYINT NULL` column now than to retrofit one once Epic 6 has hardcoded
per-field rounding. Raise it with 0.8 as a single DDL question rather than separately.

### Finding 2 (detail) — the structural twin

`Patient.vitalConfig` and the proposed `AI.fieldConstraint` are the same idea at two grains:

| Concern | `Patient.vitalConfig` | Proposed `AI.fieldConstraint` |
|---|---|---|
| What it bounds | a vital type / level / subtype | a template field mapping |
| Unit | `unit VARCHAR(20) NOT NULL` (line 6) | `unit` — epic says `NVARCHAR(20)` |
| Normal range | `normalMinValue` / `normalMaxValue DECIMAL(6,2)` | — |
| Abnormal range | `abnormalMinValue` / `abnormalMaxValue DECIMAL(6,2)` | `abnormalMin` / `abnormalMax` |
| Alert range | `alertOnMinValue` / `alertOnMaxValue DECIMAL(6,2)` | — |
| Plausibility | — | `plausibleMin` / `plausibleMax` |
| Operators | three `VARCHAR(50) NOT NULL` operator columns | none |
| Active flag | `isActive BIT NULL` | `isActive BIT NOT NULL DEFAULT 1` |
| Tenant | `accountId INT NULL` | — |
| Audit | `createdBy/Date`, `modifiedBy/Date` | `createdUtc`, `updatedUtc` |
| Key | `patientConfigId INT IDENTITY`, PK clustered (line 24) | `constraintID INT IDENTITY` |

Two observations worth carrying into review:

1. **`vitalConfig` stores operators, this table does not.** `vitalConfig` lets an author say
   "abnormal when `>` 100" versus "abnormal when between X and Y" via
   `abnormalOPerator VARCHAR(50)`. `AI.fieldConstraint` encodes only min/max pairs, with NULL
   meaning unbounded. That is a **simpler and better** model — the operator column is why
   `vitalConfig`'s editor needs conditional validators (Finding 4) — but it means an
   open-ended bound is expressed by leaving one side NULL, and that convention must be
   documented or someone will store a sentinel like `0` or `9999`.
2. **`vitalConfig` has no tenant scoping on the constraint itself** in the way this table
   would need if bounds ever vary per account. The epic's grain is
   `(templetID, sectionID, fieldID)` with no `accountId`. Since templates are themselves
   account-scoped, that is probably right — but it should be confirmed, because adding
   `accountId` later changes the unique key.

Note the typo `abnormalOPerator` (capital P) at line 10 of `vitalConfig.sql`. Per CLAUDE.md
rule 8, do not "fix" it — and do not propagate it. The new table has no operator column, so
the question is moot; mentioned only so a reviewer copying `vitalConfig` verbatim does not
carry it across.

### Finding 3 (detail) — nobody can author these bounds today

The table is read by Epic 6's validators. It is written by a human — a clinical author setting
plausibility bounds per field. **That authoring surface does not exist.**

The template editor at `PacEHR/src/app/features/settings/template-editor/` is the natural
home. Its field editor,
`PacEHR/src/app/features/settings/template-editor/add-edit-field/add-edit-field.component.ts`
(319 lines), declares its form controls at lines 70–87:

`fieldID` · `fieldName` · `fieldType` · `displayName` · `defaultValue` · `byUser` · `variant` ·
`isShowinPDF` · `optionValue` · `dataobj` · `prompt` · `allowAISummary` · `aiSummaryPrompt` ·
`isFieldCarryForward` · `templateId` · `sectionId`

**There is no min, max, range, unit or plausibility control among them.** The only numeric
bounds anywhere in the template editor are section-level CPT time brackets — `minMinutes` and
`maxMinutes` at
`PacEHR/src/app/features/settings/template-editor/add-edit-section/add-edit-section.component.ts`
lines 115–116 — which are about billing duration, not clinical value ranges.

So: ship this table and, without new UI, it stays empty. An empty `AI.fieldConstraint` means
Epic 6's validators have nothing to validate against, which means they silently pass
everything. **That is a fail-open outcome reached by an empty table rather than by a bug** —
the most dangerous kind, because nothing errors.

**Recommendation:** either bring the editor into this story (and re-point it accordingly), or
split it into an explicit follow-on story and add a DoD item stating that Epic 6 must treat
"no constraint row" as *unvalidatable* rather than *valid*. The second option is cheap and
must happen either way.

**This recommendation is no longer just the audit's opinion — it is an approved requirement.**
[2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §11 states it directly:

> Fields with **no constraint** default to **REVIEW, not ACCEPT** — absent configuration must
> not silently disable a guard.

And its §13 failure-mode table carries the row *"Constraint missing for R2 field → REVIEW, not
ACCEPT."* So the fail-safe behaviour this spec recommends is already the designed behaviour of
the validator layer that will consume this table. The DoD item in §5.5 should therefore be
stated as **conformance to an approved design**, not as a defensive suggestion — which makes
it much harder to drop in grooming.

**And the architecture gives Phase 1 a concrete scope that mitigates this finding.** Doc 3777
§11 includes this note:

> `Template.normals` holds canned positive/negative *response text*, not numeric ranges. There
> is no existing range data to migrate; `AI.fieldConstraint` is new and starts empty. **Phase 1
> seeds the common vitals set.**

Two things follow. First, it independently confirms this spec's finding that no existing range
data can be migrated. Second, **seeding the common vitals set should be adopted into this
story's Phase 1** — it is the difference between shipping a table that is empty by design and
one that already guards the fields where a bad value does the most harm. `Patient.vitalConfig`
(Finding 2) is a plausible source for those initial rows, since it already holds clinician-set
bounds for the common vitals, though its grain is per-account rather than per-mapping and the
mapping would need care.

**Ownership of the authoring function is confirmed unowned, not merely unmentioned.** Doc 3777
§16 open question **Q6** asks: *"Who owns the clinical constraint registry and approves range
changes?"* — owner "Clinical informatics", blocking its §11. That is the same gap this finding
raises, still open since September.

---

### Finding 14 (detail) — the approved architecture needs two bands; this table has one

**This is the most consequential new finding in this spec, and it is a schema-shape problem
rather than a policy one.**

The epic's DDL gives each row a single range — one minimum and one maximum. The approved
architecture requires **two**. Doc 3777 §8.1 is titled "Two-band ranges", and
[Phase 1](solution-doc:3776) §4 row 6 states the behaviour plainly: *"Two-band ranges;
impossible values are blocked, abnormal-but-real values are flagged and kept."*

The compiled constraint shape in doc 3777 §11 shows exactly what the validator layer expects
per field:

```json
{
  "field_id": 412, "unit": "mmHg", "alt_units": [],
  "implausible": {"min": 40, "max": 300},
  "abnormal":    {"min": 90, "max": 180},
  "precision": 0, "version": 3
}
```

**Why one band cannot be made to work.** The two bands do different jobs and cannot be
collapsed:

| Band | Example (BP systolic) | Validator action | Clinical meaning |
|---|---|---|---|
| `implausible` | 40–300 | **BLOCK** — value never reaches the chart | physiologically impossible; an extraction error |
| `abnormal` | 90–180 | **FLAG and KEEP** — routed to review | real and clinically important; a genuinely sick patient |

A single min/max forces a choice between two failures. Set the range to 90–180 and a real
hypertensive reading of 190 is **blocked** — the system destroys true clinical data and the
guard becomes actively harmful. Set it to 40–300 and abnormal values sail through unflagged,
losing the entire "flag and keep" behaviour the architecture specifies. **Neither is
acceptable, and no runtime logic can recover the missing band from the data.**

**Recommendation — decide this before the DDL is written, because it is a table change either
way.** Two defensible options:

1. **Ship both bands now** (preferred). Four numeric columns instead of two:
   `implausibleMin`, `implausibleMax`, `abnormalMin`, `abnormalMax`, all
   `DECIMAL(6,2) NULL`, with the abnormal band nullable so a field may have only a blocking
   band. Cost is four columns and two more range CHECKs; it makes this table complete against
   the approved validator design on first deploy.
2. **Ship the blocking band only, and record the deferral explicitly** — naming the columns
   `implausibleMin`/`implausibleMax` from the start so the second band can be added without
   renaming, and stating in the story that Epic 6's flagging behaviour is out of scope until
   it lands.

What must **not** happen is shipping `minValue`/`maxValue` with no recorded decision. That
name gives no clue which band it is, and Epic 6's implementer will have to guess — most likely
choosing the narrow clinical range, which is the option that blocks real patient data.

**Two smaller gaps in the same comparison.** The architecture's shape also carries `precision`
(0 for blood pressure — i.e. integer-valued) and `version`, neither of which the epic
specifies. `precision` is discussed in Finding 1; `version` matters because doc 3777 §11
requires constraints to be *"versioned, so a range change is attributable and reversible"* —
this table's `createdBy`/`modifiedBy` audit columns record *who last changed it*, not the
history. If attributable and reversible range changes are a real requirement, a single mutable
row cannot deliver them, and that is worth raising now rather than after the first disputed
range change.

---

### Finding 16 (detail) — two services, one table, no stated boundary

Doc 3777 §3.1's system-context diagram names this table explicitly — **"AI.fieldConstraint
NEW"** — inside the SQL Server box, which independently confirms the storage decision. But the
diagram draws **two** connections into it:

| Consumer | Role in the diagram | What it needs |
|---|---|---|
| `Prompt + Config Registry` (the AI service — now **TypeScript/Node.js**, via `src/repositories/fieldConstraintRepository.ts`) | reads constraints to compile the L4 digest and to run validators | **read** |
| `EncounterController` (.NET API) | connected to the same table, via the template editor's authoring path | **write** |

That split is sensible — the .NET API keeps owning authoring and persistence, the orchestrator
owns AI decisioning — and it matches the architecture's stated division of labour. But
**neither document writes the boundary down**, and this story would be the one to establish
it. Unanswered: does the orchestrator ever write here? Do both go through stored procedures,
or does one use EF Core directly? If the grants in Finding 9 ever materialise, `aiTemplateAdmin`
presumably gets write and the orchestrator's principal gets `SELECT` only — but that is an
inference, not a decision.

**Recommendation:** record the boundary in this story as a one-line contract — *the .NET API
writes, the TypeScript AI service reads* — and implement the read path as a procedure with
`SELECT`-only semantics so the constraint is visible in the schema rather than living only in
a diagram.

**Revision 5 note — the boundary is now cheaper to enforce and more important to state.**
With the AI service in a separate repository and a separate runtime, "the orchestrator never
writes here" is enforceable at the connection level: the service connects as
`aiServiceRuntime`, which holds `SELECT` on this table and nothing else. That is a stronger
guarantee than a code convention inside one .NET solution. It also means the contract must be
written down *now*, because the two sides will be built by different work streams against
different codebases, with no shared compiler to catch a violation.

### Finding 4 (detail) — the editor is largely already written

The good news is that when the authoring UI is built, there is close prior art.
`PacEHR/src/app/features/vital-setting/add-edit-vital-setting/add-edit-vital-setting.component.ts`
(225 lines) is an editor for exactly this kind of data:

| Mechanism | Location | Reusable for |
|---|---|---|
| Dynamic per-row control generation — three controls per (vitalType × category) | `initializeForms()` lines 46–68 | per-field constraint rows |
| Conditional validators driven by the chosen operator | `setDynamicValidators()` lines 70–92 | min/max required-ness |
| Unit selector as a hardcoded switch (Height ft/inch/cm, Weight lbs/kg, Temp °F/°C) | lines 103–124 | the `unit` field — **but see §3.4** |
| Payload mapping, including an alias fix (`alertOn` from `alerton`) | lines 195–210 | the save path |
| List view with `getAllVitalConfig` | `PacEHR/src/app/features/vital-setting/vital-setting.component.ts` line 84 | a constraints list |
| Service calls | `PacEHR/src/app/core/services/settings.service.ts` lines 44–46 | the new service methods |

`setDynamicValidators()` is the most valuable piece: operator `<` or `<=` requires a min;
`>` or `>=` requires a max; `-` requires both. `AI.fieldConstraint` has no operator column, so
this simplifies to "at least one of min/max must be present" — but the pattern of
recomputing validators as the form changes is exactly what is needed.

The hardcoded unit switch at lines 103–124 is reusable as a *pattern* but not as *code* — it
covers three vital types by name, and this table applies to arbitrary template fields.

### Finding 5 (detail) — composite primary keys are essentially unprecedented here

Searching all 1,116 files under `pacEHR_API/PacEHR.Database/Tables/`:

| Pattern | Matches |
|---|---|
| Two-column `PRIMARY KEY CLUSTERED` | **1** — `pacEHR_API/PacEHR.Database/Tables/Tables2/V28Hierarchy.sql` line 6 |
| Three-column `PRIMARY KEY CLUSTERED` | **0** |

The single instance is a pure link table:

```sql
CREATE TABLE [HCC].[V28Hierarchy] (
    [ParentId]  INT          NOT NULL,
    [ChildId]   INT          NOT NULL,
    [GroupName] VARCHAR (50) NULL,
    [RuleType]  VARCHAR (30) DEFAULT ('CMS_V28_HIER') NULL,
    CONSTRAINT [PK_V28Hierarchy] PRIMARY KEY CLUSTERED ([ParentId] ASC, [ChildId] ASC)
);
```

This matters more for **PEA-207** — which proposes a three-column composite PK with no
surrogate — than for this story, since PEA-206 keeps a surrogate `constraintID` and expresses
the grain as a UNIQUE constraint. That is the right call and it is consistent with house
practice: the overwhelming convention here is surrogate identity PK plus a UNIQUE constraint
for the natural key, exactly as `AccountAssessments.sql` line 17 does.

**Keep the surrogate.** It also makes the row addressable by the editor UI without passing
three keys around.

### Finding 13 (detail) — `"kg|lb"` is storing two things in one column

The epic's own fixture requires fieldID 425 "Weight" to carry unit `"kg|lb"` and round-trip
with **no conversion or normalization applied**. The non-conversion requirement is correct and
important: silently converting a clinical unit is a patient-safety bug, and the epic is right
to forbid it.

But the pipe-delimited value is worth flagging. `"kg|lb"` means "either of these units is
acceptable for this field," packed into a scalar column. Consequences:

- `unit` is no longer a unit; it is a *set* of acceptable units, and every consumer must know
  to split on `|`.
- The min/max bounds become ambiguous. If `plausibleMin = 30` and the unit is `"kg|lb"`, is 30
  kilograms or 30 pounds the floor? Those are very different clinical claims. **A single
  numeric bound cannot serve two units.**
- `VARCHAR(20)` holds maybe three unit tokens before truncating.

This is not a reason to block the story, and the round-trip requirement should be implemented
exactly as specified. But the bounds/unit ambiguity is a genuine correctness gap in the epic's
design, and it will surface the first time a multi-unit field has a plausibility bound.

**Recommendation:** implement as specified (store and return the string verbatim), and raise
the ambiguity as an open question for Epic 6 — which owns the validators that must interpret
it. Suggest that a multi-unit field either declares bounds per unit, or declares a canonical
unit for bound interpretation without converting stored values. Do not solve it in this
story; do not let it go unrecorded either.

---

## 2. Current state — verified inventory

### 2.1 The grain columns

| Column | Source | Verified type | Evidence |
|---|---|---|---|
| `templetID` | `Encounter.encounterTempletMapping` | `INT NOT NULL` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` |
| `sectionID` | same | `INT NOT NULL` | same |
| `fieldID` | `Template.fields` | `INT IDENTITY`, PK `PK_fieldID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` |

The `templetID` spelling is mandatory — CLAUDE.md rule 8 and REQ-02-09. Three spellings of
"template" are live simultaneously (`templetID` on the mapping, `templeteId` on
`pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 16,
`encounterTempleteID` on `encounterTempletes.sql`), and the mapping grain is the one this
table references.

### 2.2 `unit` — five live examples

| File | Declaration |
|---|---|
| `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` line 6 | `[unit] VARCHAR (20) NOT NULL` |
| `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig_1.sql` line 6 | `[unit] VARCHAR (20) NOT NULL` |
| `pacEHR_API/PacEHR.Database/Tables/Tables1/pr1_template_field.sql` line 9 | `[unit] VARCHAR (20) NULL` |
| `pacEHR_API/PacEHR.Database/Tables/Tables1/observations.sql` line 12 | `[unit] VARCHAR (55) NULL` |
| `pacEHR_API/PacEHR.Database/Tables/Tables1/pccObservationDetails.sql` line 10 | `[unit] VARCHAR (250) NULL` |

`VARCHAR(20)` is the dominant choice and matches the epic's length. The epic says `NVARCHAR`;
every live example is `VARCHAR`. Unit symbols are ASCII (`kg`, `lb`, `mmHg`, `bpm`, `°F` being
the notable exception — and `°` is not ASCII).

**Recommendation: `NVARCHAR(20)`**, departing from the local precedent deliberately. The
degree sign in `°F` / `°C` is exactly the case that breaks `VARCHAR` under a non-Unicode
collation, and `add-edit-vital-setting.component.ts` lines 103–124 shows the product already
offers those symbols in its unit selector. The storage cost is trivial. Note the departure in
the PR so it reads as a decision rather than an oversight.

`pr1_template_field.sql` is worth a glance for a different reason: it is a `Trimmed`-schema
import table with `unit`, `unit_code`, `loinc_unit` and `friendly_name` columns — external
clinical vocabulary that may eventually be a better source for field units than hand-authored
strings. Out of scope, but relevant to Epic 6.

### 2.3 The grain argument — endorsed

The epic argues the constraint must be keyed on `(templetID, sectionID, fieldID)`, not on
`fieldID` alone. The evidence supports this strongly:

- `Template.fields.displayName` is **global**, and one edit was measured reaching **179 of 458
  templates** (`pacEHR-AI-Approach-2-Proposed.md` §3.2). A `fieldID`-only constraint would leak
  a bound across every template using that field.
- The Gherkin fixtures make the case concretely: fieldID 412 "Blood Pressure" appears in
  sectionID 11 ("Review of Systems") and sectionID 12 ("Exam") of templetID 3, and must carry
  two independent rows.
- The trade-off is stated honestly in the epic: duplicate rows at the finer grain cost
  storage; a coarser grain costs correctness and cannot be fixed without a migration.

Growth is flat — one row per active field mapping — so `INT IDENTITY` is sufficient and there
is no retention concern. No filtered index needed.

### 2.4 Constraint precedent

**UNIQUE — two live forms.** Inline:
`pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` line 17 —
`CONSTRAINT [UQ_AccountAssessments] UNIQUE NONCLUSTERED ([accountID] ASC, [assessmentTemplateId] ASC)`;
also `ProviderAssignedFacility.sql` line 16. Separate unique index:
`SpecialtyCarePathTemplate.sql` line 26, `MedicationDiagnosisLink.sql` line 20.

**CHECK — 5 files**, named `CK_<table>_<col>` with OR chains. Range-check precedent is
directly relevant here: `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql`
lines 20–26 carry six range CHECKs in the form `X IS NULL OR X>=(0) AND X<=(30)`.

**Date defaults.** `DEFAULT (getutcdate())` in table DDL:
`pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` line 11.
`SYSUTCDATETIME()` appears only inside procedures, never in table DDL.
`vitalConfig.sql` line 21 uses `DEFAULT (getdate())` — local time; **do not copy that**, UTC is
correct for new tables.

### 2.5 Name collision check

Case-insensitive search across all 2,834 `.sql` files: **`fieldConstraint` — 0 matches.** Free.

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
CREATE TABLE [AI].[fieldConstraint] (
    [constraintID] INT            IDENTITY (1, 1) NOT NULL,
    [templetID]    INT            NOT NULL,
    [sectionID]    INT            NOT NULL,
    [fieldID]      INT            NOT NULL,
    [unit]         NVARCHAR (20)  NULL,
    [plausibleMin] DECIMAL (6, 2) NULL,
    [plausibleMax] DECIMAL (6, 2) NULL,
    [abnormalMin]  DECIMAL (6, 2) NULL,
    [abnormalMax]  DECIMAL (6, 2) NULL,
    [sourceProse]  NVARCHAR (MAX) NULL,
    [isActive]     BIT            CONSTRAINT [DF_fieldConstraint_isActive] DEFAULT ((1)) NOT NULL,
    [createdUtc]   DATETIME2 (7)  CONSTRAINT [DF_fieldConstraint_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    [updatedUtc]   DATETIME2 (7)  CONSTRAINT [DF_fieldConstraint_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldConstraint] PRIMARY KEY CLUSTERED ([constraintID] ASC),
    CONSTRAINT [UQ_fieldConstraint_mapping] UNIQUE NONCLUSTERED ([templetID] ASC, [sectionID] ASC, [fieldID] ASC),
    CONSTRAINT [CK_fieldConstraint_plausibleRange] CHECK ([plausibleMin] IS NULL OR [plausibleMax] IS NULL OR [plausibleMin]<=[plausibleMax]),
    CONSTRAINT [CK_fieldConstraint_abnormalRange] CHECK ([abnormalMin] IS NULL OR [abnormalMax] IS NULL OR [abnormalMin]<=[abnormalMax])
);
```

### 3.2 Changes from the epic's DDL, with reasons

| Epic | This spec | Why |
|---|---|---|
| `plausibleMin/Max`, `abnormalMin/Max` as `FLOAT` | **`DECIMAL (6, 2)`** | Finding 1. `FLOAT` is not on rule 3's approved list; `vitalConfig.sql` lines 8–15 is the live precedent for clinical bounds; binary float makes boundary comparisons ambiguous exactly at the boundary. |
| `unit NVARCHAR(20)` | `NVARCHAR (20)` — **kept**, against local precedent | §2.2. Every live `unit` column is `VARCHAR`, but `°F`/`°C` are offered by the product's own unit selector and are not ASCII. Deliberate departure; note it in the PR. |
| `DEFAULT SYSUTCDATETIME()` | `DEFAULT (getutcdate())` | Zero precedent for `SYSUTCDATETIME` in table DDL; `patientAlertJobLog.sql` line 11 is the house form. `DATETIME2(7)` retained. Do **not** copy `vitalConfig`'s `getdate()` — UTC is correct. |
| `UNIQUE (templetID, sectionID, fieldID)` | named `UQ_fieldConstraint_mapping`, explicit `NONCLUSTERED` | Matches `AccountAssessments.sql` line 17 exactly. All three columns are `NOT NULL`, so the nullable-UNIQUE trap that complicates PEA-205 does not arise here. |
| — | two range CHECKs added | Cheap correctness: a min above its max is never valid. Precedent: `SpecialtyCarePath.sql` lines 20–26. The `IS NULL OR` leading terms preserve open-ended bounds. |
| `isActive BIT NOT NULL DEFAULT 1` | kept, named constraint | Default-on is correct here (unlike PEA-205's fragments): a constraint an author took the trouble to write should apply immediately. |
| — | **consider `precision TINYINT NULL`** | Doc 3777 §11's compiled constraint carries a per-field `precision` (`"precision":0` for blood pressure — a whole number). That is an authored clinical property with no column here, so rounding becomes implicit in `DECIMAL(6,2)` and each consumer decides for itself. Secondary to the two-band gap (Finding 14) and addable later without migration, but cheapest now. Fold into 0.8. |
| one band of each kind | **see Finding 14 — the DDL above is provisional on 0.8** | Doc 3777 §8.1 requires *two* bands with different behaviours: `implausible` blocks, `abnormal` flags and keeps. The column names above do not say which band they are. If only one ships, name it `implausibleMin`/`implausibleMax`. |

### 3.3 Why a surrogate key, not a composite PK

Finding 5 found exactly one two-column PK in 1,116 table files and zero three-column PKs. The
house convention is overwhelmingly surrogate identity PK + UNIQUE constraint for the natural
key. The epic already specifies that shape for this table — correctly — and it should be kept.

Practical benefits beyond convention: the editor UI can address a row by one id;
`pacehr_devContextProcedures` parameter lists stay short; and if the grain ever needs an
`accountId` (see §1 Finding 2, observation 2) the UNIQUE constraint can be widened without
touching the PK or any foreign reference.

### 3.4 The unit/bounds ambiguity — record it, do not solve it

Per Finding 13: store `"kg|lb"` verbatim, return it verbatim, convert nothing. Add a test
asserting exactly that, using the epic's fieldID 425 fixture.

Then raise as an open question for Epic 6: **when `unit` names more than one unit, which unit
do the numeric bounds refer to?** The table as designed cannot express the answer. Options for
Epic 6 to consider — bounds per unit, or a declared canonical unit for interpretation without
converting stored values. This spec deliberately does not pick one; it records that the gap
exists so it is found in grooming rather than in production.

**Update — the architecture already proposes an answer, and it is the second option.** Doc
3777 §11's compiled constraint shape separates the two concerns explicitly:

```json
{ "field_id": 412, "unit": "mmHg", "alt_units": [], ... }
```

A single canonical `unit` that the bounds are expressed in, plus an `alt_units` array of other
units the *source note* may legitimately state. So the bounds always mean one unit, while the
extractor is still allowed to encounter `lb` in the note and have the pipeline resolve it.
Doc 3776 §4 row 7 confirms the runtime behaviour — *"Explicit resolve; ambiguous goes to
review"* — and §13 of doc 3777 makes it a hard failure mode: *"Unit ambiguous → Forced REVIEW;
never guessed."*

**What this changes for this story.** The recommendation to store `"kg|lb"` verbatim and
convert nothing **still stands** — that is REQ-06 as written, and the round-trip test should be
built exactly as specified. But the target design is now known, which means the pipe-delimited
string is a **transitional shape, not the destination**, and this spec can say so rather than
leaving the question fully open:

| | Column shape | Meaning |
|---|---|---|
| Epic 02 as written | `unit NVARCHAR(20)` = `"kg\|lb"` | ambiguous — bounds refer to an unstated unit |
| Doc 3777 §11 target | canonical `unit` + `alt_units` list | unambiguous — bounds refer to `unit` |

Reaching the target needs either a second column (`altUnits NVARCHAR(100)`, a delimited list,
which merely moves the smell) or a child table keyed on the constraint id. Neither is worth
building blind in Phase 1. **Recommendation:** keep `unit NVARCHAR(20)` and the verbatim
round-trip for now, but record in the story that the canonical-plus-alternates shape is the
known target, so whoever adds it is extending a recognised design rather than discovering the
problem. This also bears on the `NVARCHAR` decision above: if `alt_units` ever becomes a real
column it will hold `°F`/`°C`, so the non-ASCII argument for `NVARCHAR` gets stronger, not
weaker.

### 3.5 Epic design points the audit endorses

- **One current row per mapping, updated in place.** Correct. Unlike `AI.promptFragment`,
  "confirmed on save" (REQ-06-09) is a mutation, not appended history. No version column, no
  history table — a constraint is a current statement of fact, not an auditable decision trail.
- **The agent never writes here.** Correct and important: this is authored configuration, and
  a model that could edit its own plausibility bounds could not be constrained by them.
- **`sourceProse` keeps the clinical author's original wording.** An excellent inclusion —
  it answers "why does this bound say what it says," which is the question that always gets
  asked six months later. `NVARCHAR(MAX)` is right.
- **Flat growth, `INT` identity, no filtered index, no retention.** All correct.
- **No PHI.** Confirmed — bounds and prose are configuration, not patient data. Note that
  `sourceProse` is free text authored by a clinician and *could* have patient detail pasted
  into it; a line in the authoring UI warning against that is a cheap safeguard.

---

## 4. Delivery plan

### 4.0 The story at a glance

**Assume nothing is delivered.** This is the cleanest fit in the epic — good precedent,
settled grain, an editor that is largely already written — and it has one decision in front of
it that cannot be deferred.

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `0005_ai_fieldconstraint.sql` — surrogate PK, `UQ(templetID,sectionID,fieldID)`, `DECIMAL(6,2)` bounds, range CHECKs | A — **can start today** | PEA-201, 🔴 **D24**, D25 | 2 |
| **DDL** | Read/write procedures | A | DDL | 1 |
| **Runtime** | `src/repositories/fieldConstraintRepository.ts` | C | M9 port, **D29** | 1 |
| **Surface** | 🔴 **M6 — constraint authoring in the template editor** | D | **D7** | **5–8** |
| | | | **Total** | **3 · 8–10 with the UI** |

### 4.0a D24 must be answered before the DDL is written — not after

The approved architecture (§8.1) requires **two** bands with **different behaviours**:
`implausible` **blocks** a value, `abnormal` **flags it and keeps it**. The epic's DDL carries
**one unlabelled min/max pair**, which cannot express the difference.

Ship one band and exactly one of two things happens, both silent:

- If the pair is read as *implausible*, genuinely abnormal values pass unflagged — a real
  clinical signal is lost.
- If it is read as *abnormal*, real hypertensive values get blocked as implausible — a correct
  reading is refused.

**Neither is fixable at runtime, and after R3 it is a schema change with Epic 6 built on top of
it.** If the decision cannot be made in time, ship one band named
`implausibleMin`/`implausibleMax` — explicitly, so the next implementer is not guessing which
semantics they inherited — and log the deferral in the DDL comment.

### 4.0b Two engineering traps specific to this table

1. **D29 — `DECIMAL` arrives in Node as a binary double.** node-mssql surfaces
   `DECIMAL(6,2)` as a JS double, which reintroduces exactly the imprecision this story chose
   `DECIMAL` over `FLOAT` to avoid. A bound check of `value > max` can flip at the boundary.
   **Push the range comparison into SQL, or compare with an explicit documented tolerance** —
   decide before the first bound check is written, not after a boundary bug is reported.
2. **D15 — `"kg|lb"` stores two things in one column.** A single min/max pair against a
   multi-unit `unit` string has no unambiguous reading. Record the ambiguity, route the
   resolution to Epic 6, and **do not silently pick one interpretation in the repository
   layer** — that choice belongs where the validation lives.

### 4.0c Merge the UI work with PEA-207's

**PEA-206b and PEA-207b modify the same Angular components** — the template editor's field
editor, which is already written and shipped. Doing them separately means two passes over the
same files and two rounds of regression testing on a live editor. **Merge them into one M6
story (8–10 points) and sequence it once.**

**Exit criterion:** a request-time read returns the correct bounds for a given
`(templetID, sectionID, fieldID)`, a different template using the same `fieldID` returns its
own bounds, and the unit round-trips with no conversion applied anywhere.

### 4.1 Phase 0 — Unblock

| # | Decision | Owner | Blocks |
|---|----------|-------|--------|
| 0.1 | **Is the authoring UI in this story, a follow-on, or deferred?** | Product | the estimate; whether the table is ever populated |
| 0.2 | `DECIMAL(6,2)` range sufficient for all field types, or wider precision needed? | Clinical + tech lead | DDL |
| 0.3 | Do bounds ever vary by account, or is template scoping sufficient? | Product | the UNIQUE key |
| 0.4 | **Multi-unit bound interpretation** (§3.4) — routed to Epic 6; the architecture proposes canonical `unit` + `alt_units` | Architecture | Epic 6's validators |
| 0.5 | Grants: `aiTemplateAdmin` does not exist | Architecture + DBA | the security DoD |
| 0.6 | **Platform question answered** — the AI service is **TypeScript/Node.js** by owner decision, superseding the Python sidecar in doc 3777 §3.1. Residual, and it is wider than before: the repository **does not exist yet at all** — is it stood up, is it staffed, is Epic 02 sequenced around it? | Architecture | sequencing, not the DDL |
| 0.6a | **Who builds the Epic 01 equivalent for TypeScript?** This table's reader needs `src/core/database.ts` (node-mssql), `src/core/settings.ts` (zod) and the logging/errors modules. The Python corpus's Epic 01 specifies that foundation but does not implement it, and the Python library allow-list does not govern a Node runtime | Architecture | the read path in §4.3 |
| 0.7 | Confirm PEA-201 has landed | — | the schema |
| 0.8 | **ONE BAND OR TWO?** §1 Finding 14 — the approved validator design needs `implausible` *and* `abnormal` | Architecture + clinical | **the DDL itself** |
| 0.9 | Are versioned, reversible range changes required? Doc 3777 §11 says constraints are versioned; this table stores only current state | Clinical informatics | whether a history table is in scope |
| 0.10 | Confirm the read/write boundary between the .NET API and the orchestrator (§1 Finding 16) | Architecture | the procedure contract and grants |

**0.8 is now the most urgent item here, ahead of 0.1.** It changes the table's columns, so it
must be answered before any DDL is written — a later band addition is a migration on a table
Epic 6 already depends on. 0.1 is the only item that changes the *estimate*. 0.2 and 0.3 are
cheap to answer now and expensive to answer after go-live.

### 4.2 Phase 1 — The table

1. Create Tables/AI.fieldConstraint.sql per §3.1.
2. Create the re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/&lt;JIRA-KEY&gt;-fieldConstraint.sql,
   guarding the table and each constraint separately.
3. Register **both** in the `.sqlproj` — rule 5.
4. Run the release harness; confirm `PASS`.

### 4.3 Phase 2 — Read path

5. `usp_getFieldConstraint` in Stored Procedures/Procs2/ — rule-6 naming, header block, Jira
   key, `CREATE OR ALTER PROCEDURE`. Takes `@templetID`, `@sectionID`, `@fieldID`; returns the
   active row or nothing.
6. Consider a second procedure returning **all** constraints for a template in one call —
   Epic 6 validating a whole encounter will otherwise issue one round trip per field, and a
   template can carry dozens. Cheap to add now, awkward to retrofit.
7. Expose through `pacehr_devContextProcedures` / `Ipacehr_devContextProcedures`.

Mapping the epic's module. The left column is the Python corpus (the reference design, which
stays as it is); the middle column is the **build target**; the right column is the interim
.NET read path, which matters because the TypeScript repository does not exist yet:

| Epic artefact (Python reference) | TypeScript build target | Interim .NET path |
|---|---|---|
| `core/field_constraint_repository.py` | **`src/repositories/fieldConstraintRepository.ts`** | a domain service beside `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` |
| `SELECT_FIELD_CONSTRAINT_SQL` | **`SELECT_FIELD_CONSTRAINT_SQL`** — unchanged; a module-level SCREAMING_SNAKE constant holding the same T-SQL, no string interpolation | `usp_getFieldConstraint` in Procs2/ |
| `class FieldConstraintReader.for_mapping(templet_id, section_id, field_id)` | **`class FieldConstraintReader { forMapping(templetId, sectionId, fieldId) }`** — class name survives, method camelCased, parameters camelCased. Note `templetId` keeps the live misspelling of the SQL column `templetID` | one read method |
| Pydantic model of the constraint row | **zod schema + `z.infer<>`** for the row type; `DECIMAL(6,2)` values arrive from node-mssql as JS numbers, so the schema should assert finiteness rather than trusting the driver | DTO class |
| `mssql_python` + `asyncio.to_thread` | **`mssql` (node-mssql/tedious), natively async** — `await database.execute(...)`, no thread-pool wrapper | EF Core / Dapper |
| pytest | **vitest** | xUnit |

### 4.4 Phase 3 — Write path

8. `usp_addEditFieldConstraint` — upsert on the mapping triple, setting `updatedUtc`.
9. Grants per 0.5.

### 4.5 Phase 4 — Authoring UI (scope per 0.1)

10. Extend `add-edit-field.component.ts` with unit, plausible min/max, abnormal min/max and
    `sourceProse` controls, following the dynamic-validator pattern in
    `add-edit-vital-setting.component.ts` lines 70–92 (simplified — no operator column).
11. Extend `template-editor.service.ts` with the new service calls, following
    `settings.service.ts` lines 44–46.
12. Add the "do not paste patient detail" guidance on the `sourceProse` input (§3.5).

---

## 5. Verification

### 5.1 Deployment checks

```sql
SELECT s.name AS schemaName, t.name AS tableName
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'AI' AND t.name = 'fieldConstraint';

-- confirm DECIMAL(6,2), not FLOAT
SELECT c.name, ty.name AS dataType, c.precision, c.scale, c.max_length, c.is_nullable
FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'[AI].[fieldConstraint]') ORDER BY c.column_id;

SELECT name, definition FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'[AI].[fieldConstraint]');

SELECT i.name, i.is_unique, i.type_desc FROM sys.indexes i
WHERE i.object_id = OBJECT_ID(N'[AI].[fieldConstraint]');
```

### 5.2 Constraint behaviour

```sql
-- must fail: duplicate mapping
INSERT INTO [AI].[fieldConstraint] (templetID, sectionID, fieldID, plausibleMin, plausibleMax)
VALUES (3, 11, 412, 40.00, 300.00), (3, 11, 412, 50.00, 250.00);
-- expect: conflict with UQ_fieldConstraint_mapping

-- must fail: min above max
INSERT INTO [AI].[fieldConstraint] (templetID, sectionID, fieldID, plausibleMin, plausibleMax)
VALUES (3, 13, 500, 300.00, 40.00);
-- expect: conflict with CK_fieldConstraint_plausibleRange

-- must succeed: open-ended bound (max only)
INSERT INTO [AI].[fieldConstraint] (templetID, sectionID, fieldID, plausibleMax)
VALUES (3, 14, 501, 300.00);
-- expect: 1 row; NULL min means unbounded below, by convention
```

### 5.3 The per-mapping grain — the story's core assertion

```sql
-- fieldID 412 in two sections of templetID 3 must be two independent rows
INSERT INTO [AI].[fieldConstraint] (templetID, sectionID, fieldID, unit, plausibleMin, plausibleMax, sourceProse)
VALUES (3, 11, 412, N'mmHg', 40.00, 300.00, N'Bedside vital sign reading.'),
       (3, 12, 412, N'mmHg', 40.00, 300.00, N'Re-measured during physical examination.');

SELECT templetID, sectionID, fieldID, plausibleMin, plausibleMax, sourceProse
FROM [AI].[fieldConstraint] WHERE templetID = 3 AND fieldID = 412 ORDER BY sectionID;
-- expect: 2 rows, independently updatable. This is why the grain is what it is.
```

### 5.4 Unit round-trip — no conversion

```sql
-- the epic's fieldID 425 fixture: multi-unit value must survive verbatim
INSERT INTO [AI].[fieldConstraint] (templetID, sectionID, fieldID, unit)
VALUES (3, 11, 425, N'kg|lb');

SELECT unit FROM [AI].[fieldConstraint] WHERE fieldID = 425;
-- expect exactly: kg|lb
-- must NOT be normalised, split, converted, trimmed to one unit, or reordered
```

Also assert this through the full C# and TypeScript path, not just in SQL. Conversion bugs
live in mapping layers, not in storage.

### 5.5 Definition of Done

- [ ] Tables/AI.fieldConstraint.sql created per §3.1
- [ ] All four bound columns are **`DECIMAL (6, 2)`**, not `FLOAT` — reviewed against
      CLAUDE.md rule 3 and the `vitalConfig.sql` precedent
- [ ] `templetID`, `sectionID`, `fieldID` spelled exactly as the live database spells them,
      **not** "corrected" — rule 8 and REQ-02-09
- [ ] `UQ_fieldConstraint_mapping` present; a test asserts a duplicate mapping is **rejected**
- [ ] Both range CHECKs present; a test asserts min-above-max is rejected and that an
      open-ended bound (one side NULL) is accepted
- [ ] The NULL-means-unbounded convention documented in the DDL comment and in the code —
      so nobody stores `0` or `9999` as a sentinel
- [ ] A test covers the per-mapping grain using the epic's fixture numbers: fieldID 412 in
      sectionIDs 11 and 12 of templetID 3, two independent rows
- [ ] A test asserts unit `"kg|lb"` (fieldID 425) round-trips **verbatim** through SQL, C#
      **and** TypeScript with no conversion, normalisation or splitting
- [ ] Re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/ with the Jira key;
      table and each constraint independently guarded
- [ ] **Both** files registered in the `.sqlproj` (`<Build>` + `<None>`) — rule 5
- [ ] Release harness run; `PASS` verdict, no duplicate-object hit
- [ ] `usp_getFieldConstraint` in Procs2/ with rule-6 naming, header block, Jira key
- [ ] A bulk read (all constraints for a template) exists, or its absence is a recorded
      decision — Epic 6 will otherwise issue one round trip per field
- [ ] Rule-2 datatype chain verified end to end: `DECIMAL(6,2)` → `decimal?` → `number`.
      **On the TypeScript side this needs an explicit check**: node-mssql surfaces
      `DECIMAL` as a JavaScript `number`, which is a binary double — the precise decimal the
      `DECIMAL(6,2)` choice was made to guarantee (Finding 1) is lost the moment the value
      crosses into JS. Assert the round-trip at the bound values themselves, and if exact
      decimal comparison matters to Epic 6's validators, decide deliberately whether to read
      the column as a string in `src/repositories/fieldConstraintRepository.ts`. This is the
      one place where the TypeScript retarget genuinely weakens a guarantee rather than
      leaving it unchanged.
- [ ] Tests are **vitest** tests in the TypeScript service; the Python corpus's pytest
      framing is reference-only
- [ ] Grants: only assert `aiServiceRuntime` read-only against `sys.database_permissions`
      **if** the principals exist. If 0.5 is unresolved, say so rather than shipping a test
      that passes vacuously.
- [ ] **The PR states explicitly** that no field-level range UI exists, and either scopes it
      here or names the follow-on story (0.1)
- [ ] **The PR states explicitly** that Epic 6 must treat a missing constraint row as
      *unvalidatable*, not *valid* — an empty table must not silently fail open
- [ ] **The PR records** the multi-unit bound ambiguity (§3.4) as an open question for Epic 6
- [ ] No PHI — stated; `sourceProse` flagged as free text with authoring guidance
- [ ] PR title, branch name and commit message all carry the literal Jira key; one concern per PR
- [ ] PR checklist complete: unit tests · DB script · technical documentation · AI usage

---

## 6. Risk register

| # | Risk | L | I | Mitigation |
|---|------|---|---|------------|
| 1 | **No authoring UI → table stays empty → Epic 6 silently validates nothing** | High | **Critical** | Finding 3; the "unvalidatable ≠ valid" DoD item; 0.1 |
| 2 | `FLOAT` shipped; boundary comparisons ambiguous at the bound | Med | High | Finding 1; the §5.1 type assertion |
| 3 | Multi-unit bounds ambiguous (`"kg\|lb"` with one min/max) | Med | High | §3.4; route to Epic 6 before validators are written |
| 4 | A mapping layer "helpfully" normalises or converts `unit` | Med | High | §5.4 asserted through all three layers, not just SQL |
| 5 | Grain flattened to `fieldID` by a reviewer optimising for row count | Low | High | §2.3; the 179-of-458 measurement makes the case |
| 6 | Bulk read missing; per-field round trips at validation time | Med | Med | Phase 2 step 6 |
| 7 | `DECIMAL(6,2)` too narrow for some field type | Low | Med | 0.2; widen deliberately before go-live, not after |
| 8 | `accountId` needed later; UNIQUE key must change | Low | Med | 0.3; surrogate PK makes widening cheap |
| 9 | Sentinel values (`0`, `9999`) used instead of NULL for open bounds | Med | Med | Document the convention in DDL and code |
| 10 | `aiTemplateAdmin` does not exist; write restriction advisory only | High | Med | 0.5; procedure boundary as interim control |
| 11 | PHI pasted into `sourceProse` | Low | High | Authoring-UI guidance; note in the PR |
| 12 | **TypeScript/Node.js service approved but not started — no repo, no skeleton, no pipeline** → table ships correct and empty, waiting on a service that does not yet have a place to live. Wider than the Python-target version of this risk, which at least had a published 12-epic backlog | High | Med | 0.6 and 0.6a; §1 Finding 10. Correct-and-empty is a safe state; declare it in the PR |
| 13 | `.sqlproj` registration missed → silently never deployed | Med | High | Manifest test; harness verdict |
| 14 | `vitalConfig`'s `getdate()` copied instead of `getutcdate()` | Med | Low | §3.2; called out explicitly |
| 15 | SSDT targets SQL Server 2022, deployment may be Azure SQL | Med | Med | Inherited from PEA-201 |
| 16 | **Table ships with one range band; the approved architecture (doc 3777 §8.1) requires two** → either genuinely hypertensive values get blocked as implausible, or abnormal values pass unflagged. A schema change is needed before Epic 6 can implement flagging | **High** | **Critical** | §1 Finding 14; **0.8 must be answered before the DDL is written** |
| 17 | `minValue`/`maxValue` ship with no recorded decision on *which* band they represent → Epic 6's implementer guesses, most likely picking the narrow clinical range, which blocks real patient data | High | **Critical** | Name the columns `implausibleMin`/`implausibleMax` even if only one band ships in Epic 2 |
| 18 | Per-field `precision` (doc 3777 §11) has no column → rounding behaviour becomes implicit in `DECIMAL(6,2)` rather than authored per field | Med | Med | §1 Finding 1 / §3.2; secondary to the two-band gap, but cheaper to add now than later |
| 19 | Range changes are neither attributable nor reversible; only current state is stored, while §11 carries a `version` on every compiled constraint | Med | Med | 0.9 |
| 20 | Two services (the TypeScript AI service + the .NET API) touch one table with no stated ownership boundary. **Now across two repositories and two runtimes**, so no compiler or code review catches a violation | Med | Med | §1 Finding 16; 0.10. Enforce at the connection level: the AI service connects as `aiServiceRuntime` with `SELECT` only |

**On the estimate.** 3 points is right for the table, two procedures and the tests — this is
the cleanest-fitting story in the epic and the precedent is excellent. If the authoring UI
comes into scope it becomes **8–10**, offset somewhat by `add-edit-vital-setting` being
directly adaptable. Recommend splitting: **PEA-206a** (table + procedures, 3) and
**PEA-206b** (template-editor constraint authoring, 5–8).

---

## 7. Recommended immediate actions

1. **Decide 0.1 (authoring UI).** Risk 1 is the only critical-impact risk here, and its
   failure mode is silence: an empty table makes Epic 6's validators pass everything.
2. **Add the "unvalidatable ≠ valid" requirement to Epic 6 now**, regardless of 0.1. It is one
   sentence and it converts a silent fail-open into an explicit state.
3. **Change `FLOAT` to `DECIMAL(6,2)` in the epic text**, so the next reader does not
   re-litigate it. The precedent is unambiguous.
4. **Route the multi-unit bounds question (§3.4) to Epic 6** before its validators are
   specified.
5. **Confirm 0.2 and 0.3 with a clinical stakeholder** — both are cheap now and migrations later.
6. **Point the eventual UI work at `add-edit-vital-setting.component.ts`.** Its
   `setDynamicValidators()` is most of the hard part already solved.
7. 🟠 **Stand up the TypeScript repository, or accept that this table has no reader.**
   (0.6, 0.6a, risk 12.) The AI service is decided but does not exist — no repository, no
   `src/core/` foundation, no pipeline. This story can ship its table into that vacuum
   safely, but the PR must say so. Pair this with the Epic-01-equivalent question: someone
   has to author the Node dependency allow-list and build `src/core/database.ts`,
   `src/core/settings.ts` and the logging/errors modules before any repository class in
   §4.3 can be written.
8. 🟡 **Decide the `DECIMAL` → JavaScript `number` question before Epic 6's validators are
   written** (§5.5). Choosing `DECIMAL(6,2)` over `FLOAT` was this spec's headline
   correction; reading it into a JS double at the boundary partly gives that back. It is a
   one-line decision now and a validator-behaviour investigation later.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig.sql` - The structural twin: `DECIMAL (6, 2)` bounds at lines 8–15, `unit VARCHAR (20)` at line 6, surrogate PK at line 24. The single most important precedent for this story.
- `PacEHR/src/app/features/vital-setting/add-edit-vital-setting/add-edit-vital-setting.component.ts` - Reusable editor prior art: dynamic control generation lines 46–68, conditional validators lines 70–92, unit switch lines 103–124, payload mapping lines 195–210.
- `PacEHR/src/app/features/settings/template-editor/add-edit-field/add-edit-field.component.ts` - Field form controls at lines 70–87 — proves no min/max/range/unit control exists today.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` - The mapping grain; establishes `templetID`/`sectionID`/`fieldID` as INT NOT NULL.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - `fieldID INT IDENTITY PK_fieldID`, the fieldID referent.
- `pacEHR_API/CLAUDE.md` - Rule 3 approved datatypes (excludes FLOAT), rule 2 datatype chain, rules 4–8, § Numbers.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` - Line 17, the inline composite UNIQUE form copied for `UQ_fieldConstraint_mapping`.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql` - Lines 20–26, six range CHECKs in the `X IS NULL OR X>=(0) AND X<=(30)` form — the model for the two range constraints.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/V28Hierarchy.sql` - Line 6: the only composite `PRIMARY KEY CLUSTERED` in 1,116 table files — evidence for keeping a surrogate key.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11, `DEFAULT (getutcdate())` house form.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest; rule-5 silent-failure surface; line 10 DSP targets SQL Server 2022.

### Medium Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables2/vitalConfig_1.sql` - Mirror of vitalConfig; confirms the DECIMAL(6,2) and VARCHAR(20) choices are not a one-off.
- `PacEHR/src/app/features/vital-setting/vital-setting.component.ts` - Line 84 `getAllVitalConfig`, the list-view pattern for a constraints list.
- `PacEHR/src/app/core/services/settings.service.ts` - Lines 44–46, the service-call pattern for the new endpoints.
- `PacEHR/src/app/features/settings/template-editor/add-edit-section/add-edit-section.component.ts` - Lines 115–116 `minMinutes`/`maxMinutes` — the only numeric bounds in the template editor, and they are CPT billing brackets, not clinical ranges.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/pr1_template_field.sql` - Line 9 `unit VARCHAR (20)`; also carries `unit_code`, `loinc_unit` — external clinical vocabulary relevant to Epic 6.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/observations.sql` - Line 12, further `unit` column precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/pccObservationDetails.sql` - Line 10, further `unit` column precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14 named-CHECK style; line 26 separate unique index form.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Line 16 `templeteId`, one of the three live spellings of "template".
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The partial class the new procedures must be exposed through.
- `PacEHR/src/app/core/services/template-editor.service.ts` - Where the constraint authoring service calls would be added.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The actual deployment mechanism.

### Low Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/ProviderAssignedFacility.sql` - Line 16, further inline UNIQUE precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/MedicationDiagnosisLink.sql` - Line 20, separate unique index precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` - The `encounterTempleteID` spelling variant.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql` - Line 13, conditional-CHECK precedent.
- `pacEHR_API/PacEHR.Tests.UnitTests/` - xUnit + Moq project where the new tests land.
- `pacEHR_API/pipelines/` - 12 files; confirmed to contain no database deployment.
