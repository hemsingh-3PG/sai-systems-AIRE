# Story 2.5: Store versioned prompt fragments in AI.promptFragment, admin-write only

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.5 | **PEA**: PEA-205 | **Jira**: PEA-205
**Date**: 2026-10-05 | **Points**: 3 | **State**: 🔴 BLOCKED — D11
**Wave**: 2
**Requires**: [2.1]
**Enables**: []
**Files Touched**:
  - `migrations/sql/0006_create_prompt_fragment.sql`
  - `src/repositories/promptFragmentRepository.ts`
  - `tests/unit/repositories/promptFragmentRepository.test.ts`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-205 live in:

> **`dev-stories/Work-In-Progress/Epic-02/epic-02-data-layer.md`** → section **`PEA-205 — Store versioned prompt fragments in AI.promptFragment, admin-write only`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## 🔴 DO NOT BUILD — the spec contradicts itself

**Do not write `0006_create_prompt_fragment.sql` until decision D11 is settled.** This is the one
place in the epic where building to the written spec would have shipped a hole.

| Section | Says |
|---|---|
| §3.1 DDL | Ships a filtered unique index: `WHERE ([accountId] IS NOT NULL AND [templetID] IS NOT NULL)` |
| §3.1 inline comment | *"use computed sentinels in a unique index"* — which is **not** what the DDL does |
| §3.3 | Analyses it properly and recommends **sentinel `0`**, warning *"do not ship a plain `UNIQUE` over nullable columns and assume it means what it reads like"* |

### Why the filtered index is worse than either option it replaces

It enforces uniqueness only where **both** columns are non-null — account-scoped
`template_override` fragments alone. A global `contract` fragment has both columns NULL, falls
outside the filter, and **can be inserted twice at the same version with no error.** Two
simultaneously-active v1 contract fragments is precisely the near-duplicate-fork defect the audit
already found in live `AI.prompt` data.

### Recommendation (ADR-05)

Adopt §3.3 option A: `accountId` and `templetID` `NOT NULL DEFAULT 0`, the two conditional CHECKs
testing `= 0` rather than `IS NULL`, and a plain
`UNIQUE (kind, scope, accountId, templetID, version)`.

It matches existing precedent in this exact domain — `usp_getPrompt.sql` tier 3 already uses
`accountId = 0` for universal prompts — and needs no filter and no computed column.

**~30 minutes to decide. Owner: Architecture.**

## Consequence while blocked

REQ-02-01 is undelivered, and **Epic 8 (prompt ownership) has no storage.** This table replaces the
free-text blob in the legacy `AI.prompt`, taken off the runtime path at migration (REQ-08-09).

## Scope note

This story is the **storage contract only** — the table, its keys, and the boundary that the agent
reads it and never writes it. Composition order, precedence between account-specific and global
fragments, activation gating on passed evaluation, rollback and A/B comparison all belong to Epic 8.
A second decision, **D32** (prompt precedence), gates the read path.

## Migration number

`0006` is **reserved** for this story. The sequence is forward-only and shared, so the number is
allocated now even though the script is not written.

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
