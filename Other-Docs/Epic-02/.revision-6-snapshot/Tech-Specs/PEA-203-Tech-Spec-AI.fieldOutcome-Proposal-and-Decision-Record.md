# PEA-203 Tech Spec — AI.fieldOutcome (Proposal and Decision Record)

**Epic:** E2 — Data Layer · **Story:** PEA-203 · **Phase:** 1
**Depends on:** PEA-201, PEA-202 · **Satisfies:** REQ-02-04, REQ-02-08, REQ-02-09
**Epic estimate:** 5 points · **Audited estimate:** 5 points for the table, 8+ if the review UI is in scope (see §6)
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
> new, separate repository not yet created, **ported from the existing Python service
> `pacEHR_AI/`** (Epic 01 complete and tested there). The runtime chain is: Angular
> frontend → .NET Web API → TypeScript AI service → Azure OpenAI. The DDL
> (`AI.fieldOutcome` and all its columns), the filtered index on `decidedAtUtc IS NULL`, and
> all three acceptance scenarios are **language-neutral**. Only the repository class, the
> database driver and the validation-schema layer are expressed below in TypeScript terms.
> The team-space Python corpus is the reference design and is unmodified.

> **Read this first.** This is the
> most important table in Epic 02 and the one with the sharpest gap between design and
> current reality. Its central purpose — keeping a model's *proposal* separate from a
> clinician's *decision* — assumes a clinician review step that **does not exist in the
> product today and is not owned by any of the 12 epics**.
>
> The corpus does not soften that finding; it corroborates and hardens it.
> [GAPS.md](solution-doc:5089) §3 item 1 states the review panel and admin UI are out of
> scope in Epics 9, 10 and 11 and concludes, in its own words, that **"the feature has no
> user."** Worse, its Gap 1 — the first and most serious of its blocking findings, carried
> with three independent confirmations — is that **nothing in the entire backlog owns
> writing the accepted value back to the encounter form.** The product's only output has no
> implementation. That is upstream of this table and it changes what this table means: see
> new Finding 12.
>
> Three further corpus findings land directly on this DDL — Gap 25 (an auto-committed field
> never acquires a final value), Gap 17 (no transaction primitive), and the outcome/verdict
> vocabulary. Findings 12–15 below.

---

## 1. Findings — what the audit changed

| # | Finding | Severity | Effect on this story |
|---|---------|----------|----------------------|
| 1 | `encounterID` type **resolved: `INT`**; `templetID`/`sectionID`/`fieldID` all **`INT NOT NULL`** | ✅ closed | DDL is final |
| 2 | **Clinician review UI is designed and approved but not yet built** — architecture specifies HITL interrupt cards (value, source quote, reason code); sequencing problem, not a design gap | 🔴 critical | Decision columns NULL until UI ships; write-timing open question for Architecture (§Finding 2) |
| 3 | `decidedByProviderId` casing — **both spellings are live**; pick by referent | 🟡 medium | See §3.3; this is a real decision, not a typo |
| 4 | **Column-level `GRANT UPDATE` has zero precedent** — and no `GRANT` of any kind exists | 🔴 blocker | The story's core security mechanism is unshippable as written |
| 5 | **Filtered indexes have strong precedent** (10 files) | ✅ closed | `IX_fieldOutcome_pending` is safe to ship |
| 6 | **CHECK constraints have precedent** (5 files), including nullable-column CHECKs | ✅ closed | All four CHECKs are safe |
| 7 | **`UNIQUE`/composite-key precedent confirmed**; `DEFAULT (getutcdate())` is the house form, not `SYSUTCDATETIME()` | 🟡 medium | Small DDL corrections, §3.2 |
| 8 | **No TypeScript AI service exists in this repository yet** — but an approved architecture calls for exactly such a service in a new TypeScript/Node.js repo; the epic targets that future service | 🟡 medium | Sequencing question: is the TypeScript AI service staffed? See §Finding 8 |
| 9 | **No database CI/CD** | 🔴 blocker | Inherited |
| 10 | `fieldOutcome` name is **free** | ✅ closed | — |
| 11 | The `NA` collapse the table exists to fix — **confirmed real**, see §2.2 | ✅ justified | Strongest argument for this story |
| 12 | 🔴 **Nothing owns writing the accepted value back to the encounter form** ([GAPS.md](solution-doc:5089) Gap 1, three confirmations). Epic 9 claims it; REQ-02-07 forbids writing any existing clinical table; no repository, `_SQL`, GRANT or upsert exists anywhere in 12 epics | 🔴 **programme blocker** | This table becomes the system's *terminal* store rather than a staging record. See Finding 12 |
| 13 | 🔴 **An auto-committed field never acquires a final value** ([GAPS.md](solution-doc:5089) Gap 25). Only two writers exist on this table, and neither populates `acceptedValue` on the ACCEPT path | 🔴 blocker | Edit-rate metrics, the memory kill switch and Epic 12 capture all read a column nothing writes. See Finding 13 |
| 14 | 🔴 **No transaction primitive** ([GAPS.md](solution-doc:5089) Gap 17). PEA-103 is single-statement, fresh-connection-per-call | 🔴 blocker | This table's write must be atomic with the `AI.agentRun` audit row. Raise against Epic 01 |
| 15 | 🟠 **Verdict and outcome vocabularies confirmed and closed** — [epic-06-validation.md](solution-doc:5081) fixes `verdict` at ACCEPT/REVIEW/BLOCK, one per field, written from `after_model`; reason codes are owned by PEA-1004, not by this story | 🟡 medium | Resolves §4.1 decision 0.5's default-verdict question. See Finding 15 |
| 16 | ✅ **Name collision closed** — `AI.agentRun` is canonical (three later sources); the `runAudit` spelling is retired | ✅ closed | This table's FK target is `AI.agentRun`, unchanged. Risk 16 retired |

---

### Finding 2 (detail) — the decision half of this table has a designed but unbuilt writer

`AI.fieldOutcome` is deliberately split down the middle: `proposed*` columns written by the
agent, `accepted*` columns plus `decidedByProviderId` and `decidedAtUtc` written when a
clinician accepts or overrides. The epic's whole grant design (§4.3) exists to keep those two
writes distinguishable.

**The clinician review UI is designed and approved — but not yet built.** [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) module 9 "HITL Review" specifies interface `interrupt(cards) -> Resolutions` depending on a Checkpointer, and section 13 confirms the pause is durable — surviving a page refresh or process restart. [Phase 1](solution-doc:3776) section 5 gives a concrete per-field card mockup: per-field approve / edit / reject / skip, each card showing the proposed value, the source quote it came from, and a machine-readable reason code. The decision-half columns therefore have a designed writer; the gap is that it is unbuilt, which is a **sequencing problem** rather than a design gap.

Today, in the absence of the review UI, AI summary output is applied directly
into the encounter form by `addAiSummaryDataToEncounterForm` in
`PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts`
(approximately lines 1433–1450). There is no intermediate state, no accept/reject affordance, no reason capture in the current product.

**Consequences for Phase 1, stated plainly:**

1. `acceptedValue`, `acceptedUnit`, `acceptedStatus`, `decidedByProviderId` and
   `decidedAtUtc` will be **uniformly NULL** on every row until the HITL review UI ships.
2. `IX_fieldOutcome_pending` — the filtered index on `decidedAtUtc IS NULL` — will match
   **100% of rows**, which makes it a full-table index with filter overhead and no
   selectivity benefit. It is still correct to create (it becomes selective the moment the UI
   lands) but it will not help anything in Phase 1. Say so rather than letting someone
   discover it in a query plan.
3. `verdict` is written by Epic 6's validators. Until Epic 6 exists, either every row carries
   a single default verdict or this story cannot write rows at all. **This is a genuine
   sequencing gap** — see §4.1, decision 0.5. Doc 3777 section 13 corroborates defaulting to `review`: it repeatedly forces REVIEW as the fail-safe state ("Evidence unbindable → Field cannot ACCEPT; forced to REVIEW", "Unit ambiguous → Forced REVIEW; never guessed", "Constraint missing for R2 field → REVIEW, not ACCEPT").
4. The `UPDATE_FIELD_OUTCOME_DECISION_SQL` statement and its writer class are specified by
   the epic but have **no caller yet**. The epic names Epic 9's `/ai/encounter/resolve` endpoint
   as the caller; that endpoint does not exist — but the architecture for it now does (doc 3777 module 9).

**Open question for Architecture — write timing (see also §4.1 decision 0.7):** Doc 3777 section 13 states that an abandoned HITL review results in "State persists on thread; nothing written; resumable or expires". The durable pause lives in LangGraph's own Checkpointer, not in SQL Server. This implies `AI.fieldOutcome` rows may be written only at resolution time — conflicting with this spec's Phase 1 model of pending rows (`decidedAtUtc IS NULL`) that are written at proposal time and await a decision. If the architecture intends rows to be written only on clinician resolution, the `IX_fieldOutcome_pending` filtered index changes meaning entirely and the Phase 1 dormancy figures are zero rows rather than all rows. **This must be resolved before Epic 9 is designed.**

**This is not an argument against the table.** It is an argument for building the table with
its decision columns and being explicit that half of it is dormant until Epic 9 and a review
UI land. The alternative — adding the decision columns later — would be a migration against a
table already holding ~11M rows/year, which is exactly the trap the epic's open question B7
is circling.

**Recommendation:** ship the full column set now; skip or defer the decision-writer module
until its caller exists; disclose the dormancy in the PR and in the DoD rather than shipping a
DoD item that claims a working decision path.

⚠️ **This is stronger than a sequencing problem, and the difference matters.**
It is tempting to treat the missing review UI as a scheduling issue: the design exists,
someone will build it. [GAPS.md](solution-doc:5089) §3 item 1 removes that comfort. The
review panel and admin UI are **explicitly out of scope** in Epics 9, 10 and 11 — the three
epics that would plausibly own them — and no other epic picks them up. GAPS states the
conclusion without hedging: *"the feature has no user."* A design existing in doc 3777 is
not the same as a backlog item existing in the plan, and only the latter ships. Escalate
this as a scope hole, not a sequencing note.

---

### Finding 12 (detail) — 🔴 nothing writes the accepted value back to the encounter form

This is [GAPS.md](solution-doc:5089) Gap 1, and it is the single most consequential finding
in the corpus for this table.

**The claim, and why it holds.** GAPS carries it with three independent confirmations:
Epic 9 *claims* the write-back; REQ-02-07 *forbids* writing to any existing clinical table;
and an exhaustive search across all 12 epics finds no repository class, no `_SQL` constant,
no `GRANT`, and no upsert targeting the encounter form. Not an under-specified write — an
**absent** one. The product's only user-visible output has no implementation anywhere in
the backlog.

**Why it lands on PEA-203 specifically.** Everything this spec says about `AI.fieldOutcome`
assumes it is a *staging* record: the agent proposes here, a clinician decides here, and the
decided value then flows onward into the patient's encounter form where it does clinical
work. Remove the onward flow and the table's role changes fundamentally. It becomes the
**terminal** store — the only place an AI proposal ever lands. Every row is then a
suggestion that was recorded and never acted upon.

**The contradiction is structural, not an oversight.** REQ-02-07's prohibition on writing
existing clinical tables is a deliberate safety boundary and a good one; Epic 9's write-back
claim is a product necessity. Both are correct in isolation and they cannot both be
satisfied by the current design. Something must give, and it should be an explicit decision
by someone who owns the clinical risk — not a gap discovered during implementation by a
developer who then picks whichever interpretation unblocks their ticket.

**What this story should do about it.** Nothing structural: the DDL does not change. But do
not let the spec imply a flow that has no implementation. The DoD should state that at the
end of Epic 02 an AI proposal reaches `AI.fieldOutcome` and stops there. And this must be
escalated **paired with §3 item 1** — "no write-back" and "no review UI" are the same hole
seen from two ends, and raising them separately invites two partial answers.

---

### Finding 13 (detail) — 🔴 an auto-committed field never acquires a final value

[GAPS.md](solution-doc:5089) Gap 25. Subtler than Gap 1 and easier to ship past, because
nothing fails loudly.

**The mechanism.** There are exactly two writers on this table. The proposal writer
(`after_agent`, per [epic-09-review-api.md](solution-doc:5085)) populates the `proposed*`
columns. The decision writer (resolve, Epic 9) populates the `accepted*` columns **only
when a clinician decides**. On the ACCEPT path — verdict ACCEPT, outcome COMMITTED, no human
in the loop by design — no clinician decides, so no writer ever populates `acceptedValue`.
The row's final value column stays NULL forever.

**Why that is worse than it sounds.** `acceptedValue` is not decoration. Three downstream
capabilities read it:

- **Edit rate** — the headline quality metric, computed as the proportion of proposals a
  clinician changed. Against a table where auto-committed rows have NULL `acceptedValue`,
  the metric either silently excludes them (inflating the apparent edit rate, since only
  reviewed rows count) or treats NULL as "not edited" (deflating it). Both are wrong and
  neither announces itself.
- **The memory kill switch** — a safety control that disables learned behaviour when
  quality degrades. A safety control reading a column that is NULL on the majority of rows
  is a safety control that does not fire.
- **Epic 12 capture** — builds on accepted values as ground truth.

**The fix is cheap if made now.** On the ACCEPT path, write `acceptedValue = proposedValue`
at commit time, with `decidedByProviderId` NULL and `decidedAtUtc` set. The semantics are
honest: the system committed this value, no human decided it, here is when. The alternative
— deriving it downstream with `COALESCE(acceptedValue, proposedValue)` — pushes the same
logic into every consumer and guarantees one of them gets it wrong.

⚠️ **But note the interaction with `CK_fieldOutcome_decision` (§3.1).** If that constraint
requires `decidedByProviderId` and `decidedAtUtc` to be set or NULL together, the
auto-commit row above violates it. The constraint needs to distinguish a *human* decision
from a *system* commit. Resolve this before the DDL ships — it is one CHECK definition now
and a data-correcting migration later.

---

### Finding 15 (detail) — the verdict vocabulary is now closed, which retires an open decision

[epic-06-validation.md](solution-doc:5081) settles what §4.1 decision 0.5 left open:

| Question | Corpus answer |
|---|---|
| Verdict values | **ACCEPT / REVIEW / BLOCK** — closed set, exactly one per field |
| Who writes it | Epic 6's validators, from the `after_model` middleware hook |
| Who owns reason codes | **PEA-1004**, not this story and not Epic 6 |
| Confidence representation | **HIGH / MEDIUM / LOW band, never a numeric score** (CLAUDE.md: "a bare number in an expression is a bug") |
| Proposed status | **FOUND / ABSENT / ABSTAINED** — confirms §2.5's three-way split against the legacy `NA` collapse |

Two consequences. First, **this story does not invent a default verdict** — the question was
whether Epic 02 must pick one before Epic 6 lands, and the answer is that the vocabulary is
already fixed, so the only remaining question is sequencing, and REVIEW is the correct
fail-safe default (corroborated by doc 3777 §13's repeated forcing of REVIEW). Second,
`reasonCode` on this table must **not** be given a CHECK constraint: PEA-1004 owns the list
and has not published it, and a CHECK that must be ALTERed on every vocabulary addition is
worse than validating application-side.

---

### Finding 3 (detail) — `decidedByProviderId` vs `decidedByProviderID`

Both spellings are live in this database. This is not a typo to fix but a referent to choose.

| Spelling | Count in Tables/ | Representative files |
|---|---|---|
| `[providerID] INT` | 12 | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 6; `pacEHR_API/PacEHR.Database/Tables/Tables1/Tasks.sql` line 4; `pacEHR_API/PacEHR.Database/Tables/Tables1/FinalEncounterlist.sql` line 4 |
| `[providerId] INT` | 16 | `pacEHR_API/PacEHR.Database/Tables/Tables1/roundingNotes.sql` line 5; `pacEHR_API/PacEHR.Database/Tables/Tables1/clinicalNotes.sql` line 4; `pacEHR_API/PacEHR.Database/Tables/Tables1/patientCallLogs.sql` line 4; `pacEHR_API/PacEHR.Database/Tables/Tables2/treatmentPlanGoal.sql` line 10 |

The uppercase form clusters on the **encounter family** — `encounter.sql`,
`encountercurrent.sql`, `encounter_Audit_History.sql`, `FinalEncounterlist.sql`. The lowercase
form clusters on notes, scheduling and care-plan tables.

**Recommendation: use `decidedByProviderID`** (uppercase `ID`). This table is keyed on
`encounterID` and joins the encounter family; matching that neighbourhood is the consistent
choice, and `encounter.sql` line 6 is the nearest referent. Whichever is chosen, CLAUDE.md
rule 2 requires the SQL → C# → TypeScript chain to match it exactly. Rule 2 exists because of
a real production failure (PACT2-1105, `isPendoEnabled` declared `bool?` against an integer
column, producing an HTTP 400) — a casing mismatch here fails the same way, and
`pacehr_devContextProcedures` binds by string name, so it fails at runtime, not compile time.

---

### Finding 4 (detail) — column-level grants cannot ship

The epic's security design is elegant: one principal, `aiServiceRuntime`, writes both the
proposal and the decision, and the separation is enforced by a column-scoped grant:

```sql
GRANT UPDATE (acceptedValue, acceptedUnit, acceptedStatus, decidedByProviderId, decidedAtUtc)
    ON AI.fieldOutcome TO aiServiceRuntime;
```

Across all 2,834 `.sql` files in `pacEHR_API/PacEHR.Database/`:

| Pattern | Matches |
|---|---|
| `GRANT ` | **0** (only the words "auto-grant" in comments in two referral procs) |
| `CREATE ROLE` | **0** |
| `CREATE USER` | **0** |
| `ALTER ROLE` | **0** |
| `CREATE SCHEMA` | **0** |

No `Security/` folder exists, though CLAUDE.md rule 7 anticipates one. So: column-level
grants have no precedent because **grants of any kind** have no precedent, and the principal
does not exist.

**Three options, and the trade-off is real:**

| Option | Gets least privilege | Precedent | Cost |
|---|---|---|---|
| A — infra story creates principals + grants | ✅ yes | none, must be established | highest; blocks 4 of 6 epic stories |
| B — enforce in application code only | ❌ no, advisory only | matches how this codebase works today | lowest |
| C — two stored procedures, no direct table grant | partially — procedure boundary instead of column boundary | ✅ strong; every write in this repo goes through a proc | low |

**Recommendation: option C for Phase 1, option A as the target.** Two procedures —
`usp_addFieldOutcomeProposal` (INSERT) and `usp_setFieldOutcomeDecision` (UPDATE, touching
only the five decision columns) — give a real enforcement boundary using the mechanism this
codebase already uses everywhere. Every data access in the API goes through
`pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs`; there is no ad-hoc SQL and
no Dapper. A procedure that only ever sets five columns is enforceable, testable and
shippable today. Column-level grants can be layered on later without changing the table.

Option B should be rejected explicitly, not by default. Do not write a DoD item asserting
`aiServiceRuntime` has no UPDATE grant on the proposal columns until option A has actually
landed — that item would pass vacuously because the principal does not exist.

---

### Finding 5 (detail) — filtered indexes are safe

The epic's `IX_fieldOutcome_pending` uses a filtered index, which is the right tool. Precedent
is strong — 10 files:

- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterCPT.sql` — `WHERE ([calculatorEntryId] IS NOT NULL)`, the closest analogue to a NULL-predicate filter
- `pacEHR_API/PacEHR.Database/Tables/Tables1/MedicationDiagnosisLink.sql` line 20 — `UX_MedicationDiagnosisLink_ActivePair`, a **unique** filtered index
- `pacEHR_API/PacEHR.Database/Tables/Tables1/ReferralStageProgress.sql` line 23 — `UX_ReferralStageProgress_ActiveStage`
- also `vital.sql`, `encounterpqrs.sql`, `pccWebhookEventsMapping.sql`, `AssociatedCareProgramMaster.sql`

Note the house naming: `UX_` for unique filtered, `IX_` for non-unique. The epic's `IX_`
prefix is correct for this index.

Caveat from Finding 2: in Phase 1 the filter matches every row.

---

## 2. Current state — verified inventory

### 2.1 The join targets — all resolved

| Column | Source | Verified type | Evidence |
|---|---|---|---|
| `encounterID` | `Encounter.encounter` | `INT IDENTITY(1,1) NOT NULL`, PK `PK_encounterID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 2 |
| `templetID` | `Encounter.encounterTempletMapping` | `INT NOT NULL` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` |
| `sectionID` | same | `INT NOT NULL` | same |
| `fieldID` | `Template.fields` | `INT IDENTITY` PK `PK_fieldID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` |
| `runID` | `AI.agentRun` (PEA-202) | `BIGINT IDENTITY` | this epic |

So the epic's "verify the triple's source column types before relying on them" caveat is
**closed: all three are `INT`**.

### 2.2 The spelling that must not be corrected

Three spellings of "template" are live simultaneously:

| Spelling | Where | Type |
|---|---|---|
| `templetID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` | `INT NOT NULL` |
| `templeteId` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` line 16 | `INT NULL` |
| `encounterTempleteID` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` | `INT IDENTITY` PK |

It propagates to TypeScript: `PacEHR/src/app/core/models/template-editor.model.ts` declares
`templetID: number`.

CLAUDE.md rule 8 forbids "correcting" any of them — renames break the string-bound procedure
calls in `pacehr_devContextProcedures` at runtime. This table's triple references the
**mapping grain**, so **`templetID`** is the correct spelling, matching
`encounterTempletMapping.sql`. REQ-02-09 says the same thing.

### 2.3 The defect this table exists to fix — confirmed

The epic's central design claim is that `ABSENT` (the note says the patient does not have it)
and `ABSTAINED` (the model declined to answer) must never collapse into one value, because
current production writes `NA` for both. This is exactly the failure class already documented
in this codebase from the client side: `prompt_tokens: tokenData?.prompt_tokens ?? 0` in
`PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` line 618
collapses "the model reported zero" into "we lost the data."

Same shape, different column. A clinical `NA` that means both "documented absent" and "no
answer given" is not auditable, and in a clinical record that is a safety issue rather than a
reporting inconvenience. The three-value `proposedStatus` vocabulary plus a separate
`proposedConfidence` is the corrective, and the CHECK constraints are what keep a fourth value
out.

**This is the strongest justification in the story. Lead the PR with it.**

### 2.4 Confidence is categorical, not numeric

REQ-03-09 requires `proposedConfidence` to be `HIGH`/`MEDIUM`/`LOW`, never a number. The audit
supports this for a reason beyond the requirement: nothing in the current runtime produces a
calibrated probability. All calls go through `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs`
with `temperature = 0` (lines 176, 230, 282, 334) and no logprobs request. A numeric
confidence column would be populated with a number the model was asked to invent about
itself — false precision in a clinical audit record. `VARCHAR(6)` with a CHECK is the honest
representation.

### 2.5 Two vocabularies, deliberately distinct

| Column | Table | Values | Written by |
|---|---|---|---|
| `outcome` | `AI.agentRun` | **`COMMITTED`, `AWAITING_REVIEW`, `BLOCKED`** | PEA-1003's writer, run-level |
| `verdict` | `AI.fieldOutcome` | **`ACCEPT`, `REVIEW`, `BLOCK`** | Epic 6's validators via `after_model`, field-level |
| `proposedStatus` | `AI.fieldOutcome` | `FOUND`, `ABSENT`, `ABSTAINED` | the agent, field-level |
| `proposedConfidence` | `AI.fieldOutcome` | `HIGH`, `MEDIUM`, `LOW` — **never numeric** | the agent, field-level |

✅ **Revision 4 — the casing question below is now settled, and one value is retired.** All
four vocabularies are SCREAMING_SNAKE, matching every producer in the Python corpus. Two
specific corrections to what this section previously recorded: `guard_blocked` is
**`BLOCKED`**, and the fourth `outcome` value `error` is **dropped entirely** —
[GAPS.md](solution-doc:5089) Gap 9 found it has no producer anywhere in the 12 epics. A
genuine infrastructure failure is a `reasonCode` on a `BLOCKED` row, not a fourth outcome.

Four closed vocabularies at two grains. The epic is right to keep them lexically distinct —
overlapping words across grains is how audit queries end up silently wrong. Worth stating in
the PR so a reviewer does not "simplify" them into one.

**Independently corroborated by the approved architecture.**
[2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §5 defines the output
contract in Python — that document is part of the reference corpus and stays Python — and it
arrives at the same three-state split from the same reasoning. The **build-target form** is
the zod equivalent:

```typescript
// src/schemas/fieldOutcome.ts
export const proposedStatusSchema = z.enum(['FOUND', 'ABSENT', 'ABSTAINED']);
//   FOUND     -> present in the note
//   ABSENT    -> note is silent on it        (was: "NA")
//   ABSTAINED -> present but model unsure    (was: also "NA")

export type ProposedStatus = z.infer<typeof proposedStatusSchema>;
```

Note this is strictly stronger than the Python original: `Literal[...]` is a static type hint
that does nothing at runtime unless a Pydantic model validates it, whereas `z.enum([...])`
**is** the runtime validation boundary and yields the compile-time union via `z.infer<>` for
free. One declaration, both guarantees.

The same section states the principle in one line: **"ABSENT is a successful extraction.
ABSTAINED is a request for a human."** That is the clearest available justification for
`proposedStatus`, it predates the epic, and it should be quoted in the PR — this split is the
reason the table exists, and it is the thing most likely to be argued away as over-modelling
by someone who has not seen why `NA` was harmful.

**One reconciliation item, though.** Doc 3777 §5 also defines a *separate*, pipeline-owned
per-field decision enum — `Literal["ACCEPT","REVIEW","BLOCK"]`, alongside `risk_class` (R0–R4)
and machine-readable `reason_codes`. That is the same concept as this table's `verdict`, in
upper case:

| Layer | Column / field | Values |
|---|---|---|
| Storage (this epic, original) | `verdict` | `accept`, `review`, `block` |
| Pipeline (doc 3777 §5) | `decision` | `ACCEPT`, `REVIEW`, `BLOCK` |
| **Corpus (epic-06-validation.md, canonical)** | `verdict` | **`ACCEPT`, `REVIEW`, `BLOCK`** |

✅ **Resolved at Revision 4 in favour of SCREAMING_SNAKE.**
[epic-06-validation.md](solution-doc:5081) — the epic that owns the writer — fixes the
values at ACCEPT / REVIEW / BLOCK, one per field, written from the `after_model` middleware
hook. That agrees with doc 3777 §5 and with every other vocabulary in the schema. Apply it
in the CHECK constraint, the zod `z.enum(['ACCEPT','REVIEW','BLOCK'])`, and the API contract
identically. **This also
carries a latent trap worth naming**: a CHECK constraint is case-sensitive under a
case-sensitive collation and silently permissive under a case-insensitive one, so a
lower-case `verdict` written against an upper-case CHECK will either error loudly or pass
quietly depending on a database setting nobody in this story controls. Verify which
collation is in play; do not rely on the CHECK alone.

**The `reason_codes` question is now answered too — and the answer is "not here."**
[epic-06-validation.md](solution-doc:5081) assigns reason-code ownership to **PEA-1004**,
which also owns the closed vocabulary for `AI.agentRun.reasonCode`. One vocabulary, one
owner, two tables. If this table needs a `reasonCode` column, it must be **un-CHECKed** for
the same reason PEA-202's is: PEA-1004 has not published the list, and a CHECK that must be
ALTERed on every addition is worse than validating application-side. Note also that
`risk_class` (R0–R4) is stored nowhere at all — see PEA-206 and GAPS Gap 7, where the same
absence is a blocker.

### 2.6 Volume

~30 rows per encounter × ~1,000 encounters/day ≈ **10.95M rows/year**. The 1,000/day figure
comes from `pacEHR-Encounter-Agent-4Pager.md` line 111 (solution document, official, v2).

`BIGINT` is the right key because retention is **unresolved** — open question B7, which
PEA-204 owns and cannot answer either. An `INT` identity would exhaust in roughly 196 years at
this rate, so `INT` would technically survive; `BIGINT` is chosen because an append-only
clinical audit table whose retention policy nobody has set should not have a ceiling that
depends on the volume estimate staying accurate. Per CLAUDE.md § Numbers, that arithmetic and
its source must appear as a comment in the DDL and in the code — not as a bare constant.

### 2.7 Prior art — related but not duplicative

Three existing tables are in the neighbourhood. None is a duplicate:

| Existing | File | Grain | Verdict |
|---|---|---|---|
| `Template.normals` | `pacEHR_API/PacEHR.Database/Tables/Tables1/normals.sql` | curated response library per field | no proposal/decision split — **no overlap** |
| `Encounter.encounterNormals` | `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterNormals.sql` | per-encounter selection log | records *which* normal was picked, not a model proposal — **no overlap** |
| `Template` field-normal mapping | `pacEHR_API/PacEHR.Database/Tables/Tables2/templatefieldNormals.sql` | field↔normal mapping | configuration — **no overlap** |

`encounterNormals` is the closest thing to a "what got written into this field" record, and
the distinction is worth stating in the PR: it logs a human's selection from a fixed list,
with no confidence, no abstention concept and no separate proposal. It cannot be extended to
carry this table's semantics.

### 2.8 Name collision check

Case-insensitive search across all 2,834 `.sql` files: **`fieldOutcome` — 0 matches.** Free.

### 2.9 How it ships, and the grants problem

Identical to PEA-202 §2.5–2.6, and inherited without change:

- No `dacpac` deployment. Across 12 files in `pacEHR_API/pipelines/`, a search for
  `dacpac|SqlPackage|sqlproj|Database` yields **one** hit — a comment in `kb-refresh.yml`.
- Deployment is manual, via `pacEHR_API/.claude/skills/pacehr-release-sql/Invoke-ReleaseSql.ps1`,
  which reads from a git ref (not the working tree) and whose duplicate-object report gates
  the build.
- CLAUDE.md rule 5: every `.sql` must be registered in
  `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` or it is **silently never deployed**.
  Zero `<None Include=...>` entries exist among ~2,845 registrations, so rule 5's release-script
  path has never been exercised.
- Rule 4: the canonical table file **and** a re-runnable release script — both, every time.
- `.sqlproj` line 10 targets SQL Server 2022 (`Sql170DatabaseSchemaProvider`), not Azure SQL.

---

## 3. Proposed DDL

### 3.1 The table

```sql
CREATE TABLE [AI].[fieldOutcome] (
    [outcomeID]             BIGINT         IDENTITY (1, 1) NOT NULL,
    [runID]                 BIGINT         NOT NULL,
    [encounterID]           INT            NOT NULL,
    [templetID]             INT            NOT NULL,
    [sectionID]             INT            NOT NULL,
    [fieldID]               INT            NOT NULL,
    [proposedValue]         NVARCHAR (400) NULL,
    [proposedUnit]          NVARCHAR (50)  NULL,
    [proposedStatus]        VARCHAR (10)   NOT NULL,
    [proposedConfidence]    VARCHAR (6)    NOT NULL,
    [foundIn]               NVARCHAR (1000) NULL,
    [verdict]               VARCHAR (10)   NOT NULL,
    [reasonCode]            NVARCHAR (50)  NULL,
    [acceptedValue]         NVARCHAR (400) NULL,
    [acceptedUnit]          NVARCHAR (50)  NULL,
    [acceptedStatus]        VARCHAR (10)   NULL,
    [decidedByProviderID]   INT            NULL,
    [decidedAtUtc]          DATETIME2 (7)  NULL,
    [createdUtc]            DATETIME2 (7)  CONSTRAINT [DF_fieldOutcome_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldOutcome] PRIMARY KEY CLUSTERED ([outcomeID] ASC),
    CONSTRAINT [FK_fieldOutcome_agentRun] FOREIGN KEY ([runID]) REFERENCES [AI].[agentRun] ([runID]),
    CONSTRAINT [CK_fieldOutcome_proposedStatus] CHECK ([proposedStatus]='FOUND' OR [proposedStatus]='ABSENT' OR [proposedStatus]='ABSTAINED'),
    CONSTRAINT [CK_fieldOutcome_proposedConfidence] CHECK ([proposedConfidence]='HIGH' OR [proposedConfidence]='MEDIUM' OR [proposedConfidence]='LOW'),
    CONSTRAINT [CK_fieldOutcome_verdict] CHECK ([verdict]='ACCEPT' OR [verdict]='REVIEW' OR [verdict]='BLOCK'),
    CONSTRAINT [CK_fieldOutcome_acceptedStatus] CHECK ([acceptedStatus] IS NULL OR [acceptedStatus]='FOUND' OR [acceptedStatus]='ABSENT' OR [acceptedStatus]='ABSTAINED')
);
GO

CREATE NONCLUSTERED INDEX [IX_fieldOutcome_run]
    ON [AI].[fieldOutcome]([runID] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_fieldOutcome_pending]
    ON [AI].[fieldOutcome]([encounterID] ASC, [createdUtc] ASC)
    WHERE ([decidedAtUtc] IS NULL);
GO

CREATE NONCLUSTERED INDEX [IX_fieldOutcome_field_history]
    ON [AI].[fieldOutcome]([templetID] ASC, [sectionID] ASC, [fieldID] ASC, [createdUtc] ASC);
```

⚠️ **Revision 4 — one DDL change is settled and one is deliberately left open.**

**Settled:** `CK_fieldOutcome_verdict` is now SCREAMING_SNAKE (`ACCEPT` / `REVIEW` / `BLOCK`),
matching [epic-06-validation.md](solution-doc:5081), which owns the writer. See §2.5.

**Open, and it needs a decision before this ships:** Gap 25 (Finding 13) requires the ACCEPT
path to write `acceptedValue = proposedValue` at commit time — otherwise the majority of
rows never acquire a final value and three downstream capabilities read NULL. That write
produces a row with `acceptedValue` set, `decidedAtUtc` set, and `decidedByProviderID`
**NULL** — a system commit, not a human decision. No constraint above forbids it today, but
the obvious "tidy-up" a reviewer will propose — *"surely `decidedAtUtc` and
`decidedByProviderID` should be set or NULL together"* — would forbid exactly the row Gap 25
requires. **Do not add that constraint.** If the distinction needs to be enforceable, the
correct form is a three-state one:

```sql
-- illustrative, not yet agreed — see Finding 13
CONSTRAINT [CK_fieldOutcome_decision] CHECK (
    -- pending: nothing decided
    ([decidedAtUtc] IS NULL AND [acceptedValue] IS NULL AND [decidedByProviderID] IS NULL)
    -- system commit: decided, no human
    OR ([decidedAtUtc] IS NOT NULL AND [decidedByProviderID] IS NULL)
    -- human decision: decided, with an identified clinician
    OR ([decidedAtUtc] IS NOT NULL AND [decidedByProviderID] IS NOT NULL)
)
```

The value of writing it out is that it makes the three states explicit and named. The cost is
that it hard-codes the Gap 25 resolution into DDL before anyone has agreed it. **Recommend
raising it in grooming with Finding 13, and shipping without this constraint if Gap 25 is
still open** — a missing constraint can be added; a wrong one blocks a legitimate write in
production.

### 3.2 Changes from the epic's DDL, with reasons

| Epic | This spec | Why |
|---|---|---|
| `decidedByProviderId` | `decidedByProviderID` | Finding 3 — matches the encounter family this table joins (`encounter.sql` line 6). Rule 2 then binds the casing through C# and TypeScript. |
| `DEFAULT SYSUTCDATETIME()` | `DEFAULT (getutcdate())` | Zero precedent for `SYSUTCDATETIME` in table DDL; `getutcdate()` is the house form (`patientAlertJobLog.sql` line 11). `DATETIME2(7)` retained. |
| `CHECK (x IN (...))` | named `CK_fieldOutcome_*` OR chains | Matches `SpecialtyCarePathTemplate.sql` line 14. SSDT normalises `IN` to `OR`; pre-normalising avoids a spurious first-deploy diff. |
| `acceptedStatus ... CHECK (… OR NULL)` | explicit `IS NULL OR` leading term | Matches the nullable-CHECK style at `SpecialtyCarePath.sql` line 20 (`[alertLeadDays] IS NULL OR ...`). Same semantics, house form. |
| FK to `AI.agentRun` | **kept** | The epic specifies a physical FK here and none on `encounterID` — correct and worth keeping. Both tables are new, in the same schema, deployed in the same release, so ordering is controllable. The `encounterID` FK is still rightly omitted: `Encounter.encounter` carries audit triggers and a wide dependency surface, and the release harness has no transactional grouping. |
| — | `BIGINT` flagged for rule-3 escalation | Not on the approved list; precedent exists (`HL7_MSH.sql`, `gehrimedData_OMH.sql`). |

### 3.3 Nullability, read as a contract

The nullability pattern encodes the story's semantics and should not be "tidied" later:

| Column | Null when | Non-null when |
|---|---|---|
| `proposedValue` | status is `ABSENT` or `ABSTAINED` | status is `FOUND` |
| `foundIn` | status is not `FOUND` | status is `FOUND` (REQ cites evidence only for found values) |
| `reasonCode` | verdict is `ACCEPT` | verdict is `REVIEW` or `BLOCK` |
| all `accepted*`, `decidedBy*`, `decidedAtUtc` | no decision yet — **all Phase 1 rows** | a clinician has decided |

⚠️ **Revision 4 — the last row of that table is where Gap 25 bites.** "Non-null when a
clinician has decided" is exactly the reading that leaves auto-committed fields with a NULL
`acceptedValue` forever (Finding 13). The corrected contract is:

| Column | Null when | Non-null when |
|---|---|---|
| `acceptedValue`, `acceptedUnit`, `acceptedStatus` | no decision **and** no auto-commit | a clinician decided **or** the system auto-committed on verdict ACCEPT |
| `decidedAtUtc` | no decision and no auto-commit | either path — this is "when the value became final", not "when a human acted" |
| `decidedByProviderID` | pending, **or auto-committed with no human in the loop** | a clinician decided |

Read that way, `decidedByProviderID IS NULL AND decidedAtUtc IS NOT NULL` is a meaningful,
queryable state: *the system committed this without human review*. That is a state anyone
auditing clinical AI will want to count, and under the original contract it was
indistinguishable from "pending".

A reviewer may reasonably ask why these are not enforced by CHECK constraints — e.g.
`CHECK (proposedStatus <> 'FOUND' OR proposedValue IS NOT NULL)`. Precedent for exactly that
conditional style exists: `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql`
line 13 does `CHECK ([sourceScreen]='Encounter' AND [encounterId] IS NOT NULL OR ...)`.

**Recommendation: add the two that are safe** (`FOUND` implies `proposedValue`; non-accept
verdict implies `reasonCode`) and **not** the decision-column ones, since Finding 2 means
those would have to permit the all-NULL Phase 1 state anyway. Raise it in grooming rather
than deciding silently — a constraint that later blocks a legitimate write is worse than one
never added.

---

## 4. Delivery plan

### 4.0 The story at a glance

**Assume nothing is delivered.** This is the best-justified story in the epic and the one most
likely to ship as a half-empty table.

| Half | Deliverable | Track | Blocked on | Est. |
|---|---|---|---|---|
| **DDL** | `0003_ai_fieldoutcome.sql` — table, CHECKs, filtered index on `decidedAtUtc IS NULL` | A — **can start today** | PEA-201, PEA-202 (FK), 0.2/0.4/0.5 | 2 |
| **DDL** | `usp_addFieldOutcomeProposal` | A | DDL | 1 |
| **DDL** | `usp_setFieldOutcomeDecision` | A | DDL | 1 |
| **DDL** | Grants per 0.3 | A | **M1 — principals do not exist** | 0.5 |
| **Runtime** | `src/repositories/fieldOutcomeRepository.ts` — proposal path | C | M9 port | 1–2 |
| **Runtime** | Decision path wiring | C | M4, Epic 9 `/ai/encounter/resolve` | 1 |
| **Surface** | 🔴 **M4 — the clinician review UI** | D | **D7 (Product)** | **8+** |
| | | | **Total** | **5 · 13+ with M4** |

### 4.0a The thing this plan must not let happen

**Half of this table is NULL by construction until M4 ships.** `acceptedValue`,
`acceptedUnit`, `acceptedStatus`, `decidedByProviderID` and `decidedAtUtc` have exactly one
writer — a clinician review surface that **does not exist anywhere in the product** and is in
no roadmap. Ship the table without M4 and you get a proposal log, not the proposal-and-decision
record the story is named for. Worse, Epic 10 is specified to treat this table as ground truth
**with no hand-labelling** — and a table with no decisions has no ground truth in it at all.

**Three consequences for sequencing:**

1. **D7 is not a nice-to-have on this story, it is the story.** Get the answer before R2.
2. **If M4 is deferred, say so in the PR and in the table's DDL comment.** A future reader
   finding 10 million rows with NULL decisions should find the reason next to the column.
3. **Measure it.** Proportion of rows with a non-NULL `decidedAtUtc`, on a dashboard, from the
   first day the table has rows. Expected value before M4 is exactly zero — and a metric
   sitting visibly at zero is what gets M4 funded.

### 4.0b Split

PEA-203a = table + proposal path (5). PEA-203b = decision path + M4 review UI (8+). 203b
depends on Epic 9 and on a Product decision; do not carry it in the same estimate as 203a.

**Exit criterion for 203a:** one extraction writes N proposals with correct
`proposedStatus`/`proposedConfidence` and no decision columns touched.
**Exit criterion for 203b:** a clinician accepts one field and exactly those five columns move.

### 4.1 Phase 0 — Unblock

| # | Decision | Owner | Blocks |
|---|----------|-------|--------|
| 0.1 | **Platform answered; build target is TypeScript ported from `pacEHR_AI/`.** Residual blockers: (a) confirm the service is staffed and Epic 02 is sequenced around it; (b) 🔴 **D1b** — `docs/architecture/design/12-ai-phase1-implementation-architecture.md` recommends in-solution `PacEHR.AI.*` (.NET) instead. Record the override | Architecture | the write path |
| 0.2 | Rule-3 approval for `BIGINT` | Tech lead | DDL |
| 0.3 | Grants: option A, B or C from Finding 4 | Architecture + DBA | the security DoD items |
| 0.4 | `decidedByProviderID` casing signed off | Tech lead | DDL + rule-2 chain |
| 0.5 | **What writes `verdict` before Epic 6 exists?** | Architecture | whether rows can be written at all |
| 0.6 | Confirm PEA-201 and PEA-202 have landed | — | FK target |

Decision 0.5 is the one most likely to be missed. `verdict` is `NOT NULL` with a
three-value CHECK and is Epic 6's to write. Three viable answers: (a) default every Phase 1
row to `review`, which is honest and matches Finding 2's reality; (b) make the column nullable
until Epic 6 lands, which weakens the contract; (c) hold this story until Epic 6. **Option (a)
is recommended** — it is truthful (nothing is validated yet, so everything warrants review)
and it needs no later migration.

**On decision 0.1 — the platform question is closed; the build target was updated by owner decision.** [2026-09-10 AI Orchestration — Target Architecture](solution-doc:3777) §3.1 originally named the "AI Orchestrator · Python · NEW" (Ingest Gateway, LangGraph Pipeline, Prompt + Config Registry) and stated: "The .NET API keeps owning auth, persistence and the existing contract. The orchestrator owns AI decisioning only." **That ownership split is unchanged and remains correct.** The language has been retargeted: the AI engine will be built in **TypeScript/Node.js** in a standalone repository not yet created. [Phase 1](solution-doc:3776) confirms the service boundary — Angular → .NET Web API → TypeScript AI service → Azure OpenAI.

**🔴 Revision 6 adds two corrections to this paragraph.**

1. **The Python orchestrator is not merely "approved for planning" — its foundation is built.**
   `pacEHR_AI/` implements the reference corpus's Epic 01 complete and tested. The TypeScript
   service is therefore a **port** of a working service, and M9 is 5–8 points, not 13+.
2. **A third architecture is live and no Revision 5 document cited it.**
   `docs/architecture/design/12-ai-phase1-implementation-architecture.md` Part 2 recommends
   **Option B — `PacEHR.AI.*` projects inside the existing .NET solution** — and explicitly
   defers a standalone deployable (its Option C) to Phase 2/3, on the grounds that adding a
   deployable to an organisation with known CI/CD gaps compounds risk. **The owner has chosen
   the standalone TypeScript path anyway.** That is a legitimate call; it is not a recorded
   one. Record it as D1b, with the reason, before this story's write path is built.

The residual open question for Architecture is unchanged: whether Epic 02 is gated behind the
service or proceeds in parallel against the interim .NET read path.

### 4.2 Phase 1 — Ship the table

1. Create Tables/AI.fieldOutcome.sql with the §3.1 DDL (canonical object file, rule 7).
2. Create the re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/&lt;JIRA-KEY&gt;-fieldOutcome.sql,
   guarded with `IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldOutcome]') AND type = N'U')`.
   Guard the three `CREATE INDEX` statements separately with `sys.indexes` checks — a partially
   applied script must be safely re-runnable.
3. Register **both** files in the `.sqlproj` (`<Build>` + `<None>`) — rule 5.
4. Record the 10.95M-rows/year arithmetic and its source line as a DDL comment — CLAUDE.md § Numbers.
5. Run the release harness; confirm `PASS` and no duplicate-object hit.

### 4.3 Phase 2 — Proposal write path

6. `usp_addFieldOutcomeProposal` in Stored Procedures/Procs2/ — `CREATE OR ALTER PROCEDURE`,
   schema-qualified, rule-6 header block with Jira key. Writes the proposal columns only;
   never touches the decision columns.
7. Expose it through `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` and
   `Ipacehr_devContextProcedures.cs`, following the existing `SqlParameter` /
   `OutputParameter<T>` pattern.
8. Status, confidence and verdict values as **named constants in one place** — never inline
   literals. This preserves the epic's intent through the platform translation.

### 4.4 Phase 3 — Decision write path (deferred)

9. `usp_setFieldOutcomeDecision` — UPDATE touching only `acceptedValue`, `acceptedUnit`,
   `acceptedStatus`, `decidedByProviderID`, `decidedAtUtc`. Ship the procedure; note it has
   no caller until Epic 9's `/ai/encounter/resolve` exists.
10. Grants per decision 0.3.

**Contingency mapping — applies only if the approved TypeScript AI service plan is deferred or reversed; this is not the recommended path.** The recommended path is the TypeScript/Node.js AI service defined in the owner decision (2026-09-29). If that plan is deferred, the epic's artefacts would map to this repo's idiom as follows:

| Epic artefact (TypeScript AI service) | .NET equivalent |
|---|---|
| `src/repositories/fieldOutcomeRepository.ts` | a domain service beside `pacEHR.DomainServices/AIPromptServices.cs` |
| `INSERT_FIELD_OUTCOME_SQL` | `usp_addFieldOutcomeProposal` in Procs2/ |
| `fieldOutcomeWriter.ts` — `FieldOutcomeProposalWriter.record()` | a method on that service |
| `UPDATE_FIELD_OUTCOME_DECISION_SQL` | `usp_setFieldOutcomeDecision` in Procs2/ |
| `FieldOutcomeDecisionWriter.record()` | a second method, no caller yet |
| vocabulary as `z.enum([...])` constants with inferred TypeScript union type (`z.infer<typeof ...>`) | C# `enum` or `static class` of constants |

---

## 5. Verification

### 5.1 Deployment checks

```sql
SELECT s.name AS schemaName, t.name AS tableName
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'AI' AND t.name = 'fieldOutcome';

SELECT c.name, ty.name AS dataType, c.max_length, c.is_nullable
FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'[AI].[fieldOutcome]')
ORDER BY c.column_id;

-- all four CHECK constraints present
SELECT name, definition FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'[AI].[fieldOutcome]');

-- the FK to agentRun
SELECT name, delete_referential_action_desc FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID(N'[AI].[fieldOutcome]');

-- three indexes, and the filter predicate on the pending one
SELECT i.name, i.type_desc, i.has_filter, i.filter_definition
FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[AI].[fieldOutcome]');
```

### 5.2 The constraint that matters most

```sql
-- must fail: the NA collapse this table exists to prevent
INSERT INTO [AI].[fieldOutcome] (runID, encounterID, templetID, sectionID, fieldID,
       proposedStatus, proposedConfidence, verdict)
VALUES (1, 1, 3, 11, 412, 'NA', 'HIGH', 'review');
-- expect: conflict with CK_fieldOutcome_proposedStatus

-- must fail: numeric confidence
INSERT INTO [AI].[fieldOutcome] (runID, encounterID, templetID, sectionID, fieldID,
       proposedStatus, proposedConfidence, verdict)
VALUES (1, 1, 3, 11, 412, 'FOUND', '0.87', 'accept');
-- expect: conflict with CK_fieldOutcome_proposedConfidence

-- must succeed: ABSENT and ABSTAINED are two distinct rows, not one NA
INSERT INTO [AI].[fieldOutcome] (runID, encounterID, templetID, sectionID, fieldID,
       proposedStatus, proposedConfidence, verdict)
VALUES (1, 1, 3, 11, 412, 'ABSENT',    'HIGH', 'accept'),
       (1, 1, 3, 12, 412, 'ABSTAINED', 'LOW',  'review');
-- expect: 2 rows, distinguishable forever
```

### 5.3 The per-mapping grain

```sql
-- fieldID 412 in two sections of templetID 3 must be two independent rows
SELECT templetID, sectionID, fieldID, proposedStatus, proposedValue
FROM [AI].[fieldOutcome]
WHERE templetID = 3 AND fieldID = 412
ORDER BY sectionID;
-- expect: one row for sectionID 11, one for sectionID 12, independently updatable
```

Fixture numbers are the epic's own, from `pacEHR-AI-Approach-2-Proposed.md` §3.1/§3.2:
fieldID 412 "Blood Pressure", sectionID 11 "Review of Systems", sectionID 12 "Exam",
templetID 3; fieldID 425 "Weight" with unit `"kg|lb"`.

### 5.4 Finding 2 made visible

```sql
-- in Phase 1 this should return 100% — which is the point
SELECT COUNT(*) AS totalRows,
       SUM(CASE WHEN decidedAtUtc IS NULL THEN 1 ELSE 0 END) AS undecidedRows
FROM [AI].[fieldOutcome];
```

Report this number. It is the measure of how much of this table is dormant, and it is the
business case for Epic 9's review UI.

### 5.5 Definition of Done

- [ ] Tables/AI.fieldOutcome.sql created with the §3.1 DDL, all four CHECK constraints, the
      FK to `AI.agentRun`, and all three indexes
- [ ] `templetID`, `sectionID`, `fieldID` spelled exactly as the live database spells them,
      **not** "corrected" — reviewed against CLAUDE.md rule 8 and REQ-02-09
- [ ] `decidedByProviderID` casing signed off and matched through SQL → C# → TypeScript per rule 2
- [ ] Re-runnable release script under Scripts/Script.&lt;DDMonYYYY&gt;/ named with the Jira key;
      table **and** each index independently guarded by existence checks
- [ ] **Both** files registered in the `.sqlproj` (`<Build>` + `<None>`) — rule 5
- [ ] Release harness run; `PASS` verdict, no duplicate-object hit
- [ ] `usp_addFieldOutcomeProposal` in Procs2/ with rule-6 naming, header block, Jira key;
      writes proposal columns only
- [ ] `usp_setFieldOutcomeDecision` in Procs2/; updates **only** the five decision columns —
      a test asserts it cannot modify any proposal column
- [ ] Both exposed through `pacehr_devContextProcedures` / `Ipacehr_devContextProcedures`
- [ ] Vocabulary values (`FOUND`/`ABSENT`/`ABSTAINED`, `HIGH`/`MEDIUM`/`LOW`,
      `ACCEPT`/`REVIEW`/`BLOCK`) are declared **once** as zod `z.enum([...])` schemas in
      `src/schemas/fieldOutcome.ts`, with the TypeScript unions derived via `z.infer<>`
      rather than re-typed by hand; a vitest test asserts no inline literal at any call site
- [ ] A test asserts the `verdict` CHECK rejects the lower-case spellings — if it does not,
      the database is on a case-insensitive collation and the constraint is not enforcing
      what it appears to (risk 21)
- [ ] **Gap 25 decided and recorded:** either the ACCEPT path writes
      `acceptedValue = proposedValue` at commit time (with `decidedByProviderID` NULL), or
      the PR states explicitly that auto-committed rows carry no final value and names who
      owns the consequence for edit rate, the memory kill switch and Epic 12
- [ ] **The PR states explicitly** that nothing in the 12-epic backlog writes the accepted
      value back to the encounter form ([GAPS.md](solution-doc:5089) Gap 1) — a proposal
      reaches this table and stops here
- [ ] A test asserts `ABSENT` and `ABSTAINED` round-trip as distinct values and that no code
      path maps either to `NA` — this is the story's reason for existing
- [ ] A test asserts the CHECK constraints reject a fourth status, a numeric confidence and a
      fourth verdict
- [ ] A test asserts `acceptedStatus` accepts NULL as well as the three values
- [ ] A test covers the per-mapping grain using the exact fixture numbers from
      `pacEHR-AI-Approach-2-Proposed.md` §3.1 (fieldID 412 in sectionIDs 11 and 12 of templetID 3)
- [ ] The 10.95M-rows/year arithmetic and its source line (`pacEHR-Encounter-Agent-4Pager.md`
      line 111) recorded as a comment in both DDL and code — CLAUDE.md § Numbers
- [ ] PHI reviewed against CLAUDE.md § Clinical and PHI rules: `proposedValue`,
      `acceptedValue` and `foundIn` **do** hold clinical content, so logging is by
      `outcomeID`/`runID` only. A test asserts no log line contains a value column.
- [ ] **The PR states explicitly** that the decision columns are dormant in Phase 1 (no review
      UI exists), that `IX_fieldOutcome_pending` therefore matches all rows, and that
      `usp_setFieldOutcomeDecision` has no caller until Epic 9
- [ ] **The PR states explicitly** which grant option (A/B/C) was chosen, and does **not**
      claim least-privilege separation unless option A actually landed
- [ ] PR title, branch name and commit message all carry the literal Jira key; one concern per PR
- [ ] PR checklist complete: unit tests · DB script · technical documentation · AI usage

---

## 6. Risk register

| # | Risk | L | I | Mitigation |
|---|------|---|---|------------|
| 1 | 🔴 **No review UI, and no epic owns building one** — upgraded at Revision 4 from "sequencing" to a scope hole. [GAPS.md](solution-doc:5089) §3 item 1: out of scope in Epics 9/10/11, *"the feature has no user"* | **High** | **High** | Finding 2. Disclose in PR and DoD, and escalate as a scope hole paired with risk 17 — a design in doc 3777 is not a backlog item, and only backlog items ship |
| 2 | Column-level grants unshippable; least privilege claimed but absent | High | High | Finding 4; choose option C now, A later; do not write a vacuous DoD item |
| 3 | `verdict` NOT NULL with no writer before Epic 6 | High | Med | **Vocabulary now closed** — ACCEPT/REVIEW/BLOCK, written from `after_model` ([epic-06-validation.md](solution-doc:5081)). Residual is sequencing only; default to `REVIEW` as the fail-safe |
| 4 | ~~Platform undecided; repository module has no host~~ **Retired** — decided: TypeScript/Node.js AI service (owner decision, 2026-09-29) | ⬜ | ⬜ | Closed. Superseded by risk 15 |
| 5 | `decidedByProviderId` casing mismatch through the stack | Med | High | Rule 2; PACT2-1105 is the precedent failure; runtime not compile-time |
| 6 | `templetID` "corrected" by a well-meaning reviewer | Med | High | Rule 8; call it out in the PR description |
| 7 | `.sqlproj` registration missed → table silently never deployed | Med | High | Manifest test; harness verdict |
| 8 | `IX_fieldOutcome_pending` non-selective in Phase 1 | High | Low | Expected; state it |
| 9 | Retention unresolved (B7); 11M rows/year accumulating | High | Med | PEA-204 owns the mechanism but cannot set the number — escalate to clinical/compliance |
| 10 | `BIGINT` rejected at rule-3 review | Med | Low | Escalate in 0.2 with the `HL7_MSH.sql` precedent |
| 11 | FK to `AI.agentRun` breaks if PEA-202 has not deployed | Med | Med | Sequence in one release; guard the script |
| 12 | Conditional CHECKs added later would block existing rows | Low | Med | Decide in grooming (§3.3), not after go-live |
| 13 | Partially applied release script not re-runnable | Med | Med | Guard each index separately, not just the table |
| 14 | SSDT targets SQL Server 2022, deployment may be Azure SQL | Med | Med | Inherited from PEA-201; do not fix here |
| 15 | **TypeScript/Node.js service fully specified but unbuilt; Epic 01 is the gate** — proposal columns have no writer either, not just the decision half | Med | Med | Confirm Epic 01 is sequenced first and staffed ([README.md](solution-doc:5090) build order). Compounds risk 1: with no service *and* no review UI, the whole table is dormant at first deploy |
| 16 | ~~**FK target may be renamed** — `AI.runAudit` vs `AI.agentRun`~~ **Retired** — `agentRun` confirmed canonical by three later sources (PEA-202 §2.8) | ⬜ | ⬜ | Closed. The FK as written in §3.1 is correct |
| 17 | 🔴 **Nothing writes the accepted value back to the encounter form** ([GAPS.md](solution-doc:5089) Gap 1) — this table becomes terminal, not staging | High | **High** | Finding 12. Escalate **paired with the missing review UI** (risk 1) — same hole, two ends. Do not let the spec imply a flow that has no owner |
| 18 | 🔴 **Auto-committed fields never acquire a final value** (Gap 25) — `acceptedValue` NULL on the majority of rows | **High** | **High** | Finding 13. Fix is cheap now: write `acceptedValue = proposedValue` on the ACCEPT path. Failure is silent — edit rate skews, the memory kill switch does not fire |
| 19 | 🔴 **No transaction primitive** (Gap 17) — this table's write cannot be atomic with the `AI.agentRun` audit row | High | **High** | Raise against Epic 01 before PEA-103 is accepted. See PEA-202 §3.3a |
| 20 | 🟠 **The "tidy" decision CHECK would forbid the Gap 25 row** — a reviewer proposing `decidedAtUtc`/`decidedByProviderID` set-or-NULL-together breaks auto-commit | Med | **High** | §3.1 records the three-state form. Ship without the constraint if Gap 25 is unresolved — a missing constraint can be added; a wrong one blocks production writes |
| 21 | 🟡 **`verdict` CHECK is collation-dependent** — lower-case values pass silently under a case-insensitive collation | Med | Med | Verify the collation; do not rely on the CHECK alone. Enforce in the zod `z.enum(['ACCEPT','REVIEW','BLOCK'])` as well — unlike a Python `Literal`, zod rejects a wrong-case value at runtime, so the service-side guard holds regardless of the database collation |
| 22 | 🟡 **PHI with no erasure path** (GAPS Gap 10) — `proposedValue`, `acceptedValue` and `foundIn` hold clinical content; B7 retention is unset and fails closed | High | **High** | Reinforces risk 9. PEA-204 owns the mechanism, nobody owns the number. This is a compliance exposure, not a housekeeping item |

**On the estimate.** 5 points is fair for the table, two procedures and the tests — this story
is genuinely mostly DDL, unlike PEA-202. But if grooming pulls the review UI or the Epic 9
resolve endpoint into scope, it becomes 8+ and should be split. Keep the boundary explicit:
**this story is storage, not workflow.**

---

## 7. Recommended immediate actions

*Revised at Revision 4. Items 1 and 2 are new and outrank everything below them: both are
programme-level holes rather than story-level decisions, and both are invisible from inside
this story unless someone states them.*

1. 🔴 **Escalate Gap 1 and the missing review UI together, as one item.** "Nothing writes the
   accepted value back to the encounter form" ([GAPS.md](solution-doc:5089) Gap 1) and "no
   epic owns building the review panel" (§3 item 1) are the same hole seen from two ends.
   Raised separately they will get two partial answers — someone will scope a review UI
   without a write-back, or a write-back with nowhere to review. Raise them to whoever owns
   the clinical risk, not to the Epic 02 team: REQ-02-07's prohibition on writing existing
   clinical tables is a deliberate safety boundary, and overriding it is not a developer's
   decision.
2. 🔴 **Settle Gap 25 before the DDL ships** (Finding 13). Write `acceptedValue = proposedValue`
   on the ACCEPT path, or accept explicitly that the majority of rows never acquire a final
   value and name who owns the consequence. The reason this cannot wait: the fix is one line
   in the writer today, and a data-correcting migration against ~11M rows/year later — and
   the migration cannot reconstruct what the value *would* have been for rows already
   written.
3. 🔴 **Raise the transaction primitive against Epic 01** (Gap 17) before PEA-103 is accepted
   as done. Shared with PEA-202 §3.3a — raise it once, for both tables.
4. ~~**Decide 0.5 (`verdict` before Epic 6) in grooming.**~~ **Largely closed** — the
   vocabulary is fixed at ACCEPT/REVIEW/BLOCK by [epic-06-validation.md](solution-doc:5081).
   Residual: confirm `REVIEW` as the interim default and **verify the database collation**,
   or the CHECK constraint is not enforcing what it appears to (risk 21).
5. **Choose the grant option (Finding 4) and write it down.** Option C is shippable now;
   option B must be rejected explicitly rather than by default. Note the corpus names three
   roles — `aiServiceRuntime`, `aiPromptAdmin`, `aiTemplateAdmin` — which sharpens option A
   without making it any more shippable against a repository with zero `GRANT` precedent.
6. **Sign off `decidedByProviderID` casing** and record the SQL → C# → TypeScript chain.
7. **Escalate retention (B7) to clinical/compliance.** 10.95M rows/year with no policy is a
   question for a data owner, not a developer, and PEA-204 cannot proceed without an answer.
   Reinforced by GAPS Gap 10: `proposedValue`, `acceptedValue` and `foundIn` are PHI with no
   erasure path. The corpus leaves the setting unset and **fails closed** — on the TypeScript
   build target that is `AI_FIELD_OUTCOME_RETENTION_DAYS` read through the zod schema in
   `src/core/settings.ts` as `z.coerce.number().int().positive().optional()`, with the purge
   refusing to delete anything and logging a refusal that names the setting when it is
   absent. Correct behaviour, but it means the purge never runs until someone sets a number,
   and nobody owns setting it. **Unset is not zero** — zero would mean "delete everything
   eligible", and the two must never collapse into one code path.
8. ~~**Read the two design documents** to close the platform question.~~ **Fully closed at
   Revision 4** — moot, not merely answered. The name collision that rode along with this
   item is also closed: `AI.agentRun`, so this table's FK as written in §3.1 is correct
   (risk 16 retired).
9. **Open the grants/roles infrastructure story** — four of six Epic 02 stories depend on
   principals that do not exist and nobody owns.
10. **Put the Finding 2 dormancy statement in the PR template** for this story, so it is
    disclosed rather than discovered — and extend it with the Gap 1 statement from item 1.

---

## Referenced Paths

The following files and paths were analyzed to create this document:

### High Relevance
- `PacEHR/src/app/features/encounter-list/encounter-form/facades/encounter-ai.facade.ts` - Applies AI output straight into the encounter form (~1433–1450), proving no review step exists; line 618 shows the same `?? 0` collapse pattern this table prevents.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounter.sql` - Line 2 resolves encounterID as INT IDENTITY; line 6 is the `providerID` casing referent; line 16 shows the `templeteId` spelling variant.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletMapping.sql` - The mapping grain; establishes `templetID`/`sectionID`/`fieldID` as INT NOT NULL.

**Solution documents consulted at Revision 4** (the Python Epic corpus — not repository files, so not drift-tracked here): GAPS.md (5089), epic-02-data-layer.md (5077), epic-06-validation.md (5081), epic-09-review-api.md (5085), epic-10-observability.md (5086), README.md (5090), 00-langchain-api-truth.md (5091), CLAUDE.md (5093).
- `pacEHR_API/PacEHR.Database/Tables/Tables1/fields.sql` - fieldID INT IDENTITY PK_fieldID, the fieldID referent.
- `pacEHR_API/CLAUDE.md` - Rules 1–8; rule 2 datatype chain, rule 4 dual artefacts, rule 5 registration, rule 8 do-not-correct-spellings, § Numbers, § Clinical and PHI rules.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePath.sql` - Lines 20–26, the nullable-CHECK style copied for `acceptedStatus`.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/SpecialtyCarePathTemplate.sql` - Line 14, the closed-vocabulary CHECK style copied for status/confidence/verdict.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/MedicationDiagnosisLink.sql` - Line 20, unique filtered-index precedent for `IX_fieldOutcome_pending`.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterCPT.sql` - Filtered index on an IS NOT NULL predicate — closest analogue to the pending filter.
- `pacEHR_API/PacEHR.Database/PacEHR.Database.sqlproj` - Registration manifest; line 10 DSP shows SQL Server 2022; zero `<None>` entries.
- `pacEHR_API/.claude/skills/pacehr-release-sql/SKILL.md` - The actual deployment mechanism.

### Medium Relevance
- `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` - temperature = 0 at lines 176/230/282/334, no logprobs — why confidence must be categorical.
- `pacEHR_API/pacEHR.DomainServices/pacehr_devContextProcedures.cs` - The partial class both new procedures must be exposed through; binds by string name.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientPrognosisHistory.sql` - Line 13, conditional CHECK precedent for the §3.3 nullability question.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/roundingNotes.sql` - Line 5, the lowercase `providerId` spelling cluster.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/clinicalNotes.sql` - Line 4, further lowercase `providerId` evidence.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/Tasks.sql` - Line 4, further uppercase `providerID` evidence.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterTempletes.sql` - The `encounterTempleteID` spelling variant.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/normals.sql` - Prior art assessed: curated response library, no proposal/decision split.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/encounterNormals.sql` - Prior art assessed: per-encounter selection log, closest analogue but not extensible to this grain.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/templatefieldNormals.sql` - Prior art assessed: configuration mapping only.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/HL7_MSH.sql` - BIGINT IDENTITY precedent for the rule-3 escalation.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/patientAlertJobLog.sql` - Line 11 establishes `DEFAULT (getutcdate())` as the house form.
- `PacEHR/src/app/core/models/template-editor.model.ts` - Declares `templetID: number`, showing the spelling reaches TypeScript.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/ReferralStageProgress.sql` - Line 23, further filtered-index precedent.

### Low Relevance
- `pacEHR_API/PacEHR.Database/Tables/Tables1/medicalDirectorActivity.sql` - Additional CHECK precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/treatmentPlanGoal_1.sql` - Additional CHECK precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables2/treatmentPlanGoal.sql` - Line 10, further lowercase `providerId` evidence.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/gehrimedData_OMH.sql` - Second BIGINT IDENTITY precedent.
- `pacEHR_API/PacEHR.Database/Tables/Tables1/AccountAssessments.sql` - Line 17, composite UNIQUE constraint precedent.
- `pacEHR_API/PacEHR.Database/Scripts/Script.25-Oct-2026/demo.sql` - The only release script that has ever existed.
- `pacEHR_API/pipelines/` - 12 pipeline files; confirmed to contain no database deployment.
- `pacEHR_API/PacEHR.Tests.UnitTests/` - xUnit + Moq test project where the new tests land.
