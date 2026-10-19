# Story 2.3: Store the AI's proposal beside the clinician's decision in AI.fieldOutcome

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.3 | **PEA**: PEA-203 | **Jira**: PEA-203
**Date**: 2026-10-05 | **Points**: 5 | **State**: ✅ Built ⚠️
**Wave**: 3
**Requires**: [2.1, 2.2]
**Enables**: [2.4]
**Files Touched**:
  - `migrations/sql/0003_create_field_outcome.sql`
  - `src/repositories/fieldOutcomeRepository.ts`
  - `tests/unit/repositories/fieldOutcomeRepository.test.ts`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-203 live in:

> **`dev-stories/Work-In-Progress/Epic-02/epic-02-data-layer.md`** → section **`PEA-203 — Store the AI's proposal beside the clinician's decision in AI.fieldOutcome`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## Build state

✅ **Table and repository built.** ⚠️ **The accepted-value columns have no writer.**

## Why this story matters most in the epic

`AI.fieldOutcome` is not an audit table with a clinical flavour. It is the only honest accuracy
measurement the programme has, it drives the review queue, and it is the free pre-labelled
evaluation set Epic 10 consumes with no hand-labelling step. All three depend on one fact never
being fudged: **what the AI proposed and what the clinician accepted sit in the same row, unedited
relative to each other.**

🔴 **`FOUND` / `ABSENT` / `ABSTAINED` must never collapse.** Production writes `NA` whether the note
said nothing or the model was guessing — that is the defect this table exists to stop reproducing.
Edit rate, the review queue and Epic 10's metrics are all computed by querying `proposedStatus`; a
collapsed value makes every one of those queries lie.

## 🔴 The open hole

**Nothing writes `acceptedValue`, `acceptedUnit`, `acceptedStatus`, `decidedByProviderID` or
`decidedAtUtc`.** The review surface (M4) is out of scope in Epics 9, 10 and 11, and D7 — the UI
scope decision — is undecided. Until it lands, the table is permanently half-NULL and the edit-rate
metric cannot be computed (risk R1; GAPS #25).

Compounding it: **clinician identity is undefined** (Q3 / GAPS #6). `decidedByProviderID INT` has no
agreed source — three incompatible shapes across the backlog, never reconciled. The audit cannot
answer *"who decided this."*

## Acceptance focus for review

- `CK_fieldOutcome_proposedStatus` admits exactly three values; no read path collapses them
- Confidence is a **band** (`HIGH`/`MEDIUM`/`LOW`), never a float — nothing in the runtime produces
  a calibrated probability
- The decision update is scoped `AND [decidedAtUtc] IS NULL` so a clinician acting on a stale screen
  cannot silently overwrite the first decision, and the caller can tell via `SELECT @@ROWCOUNT`
- The proposal insert and the decision update **never touch each other's columns**
- Both guarantees are **mutation-tested** — removing the `decidedAtUtc` guard, or making the
  proposal insert touch `acceptedValue`, must fail the suite
- The filtered index `IX_fieldOutcome_pending` is the review queue

---

## Patterns that apply

Governed by `docs/architecture/design/03-patterns-and-standards-brownfield.md`, which defers to
`PacEHR_AI/CLAUDE.md` (ADR-03) — **not** to `SPEC/rulebooks/aire-clean-architecture.md`.

| Concern | Rule |
|---|---|
| Statements | One `_SQL` constant per statement, `SCREAMING_SNAKE`, above its class. `@name` binding only. No interpolation. Tagged-template `query` banned. |
| Singletons | Use the exported `database`. Never construct a pool. |
| Naming | Live database spelling preserved: `templetID`, `sectionID`, `fieldID`. |
| Logging | Fields first, literal message second. No clinical value in any log line. |
| Numbers | No bare number in an expression — a named constant traceable to a measurement, or a `settings()` field. |
| Tests | `node:test`, tier by directory, unit tier network-blocked. Assert behaviour, not shape. |
