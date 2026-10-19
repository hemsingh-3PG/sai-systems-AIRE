# Story 2.4: Purge AI.fieldOutcome rows past the configured retention window

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.4 | **PEA**: PEA-204 | **Jira**: PEA-204
**Date**: 2026-10-05 | **Points**: 2 | **State**: ⏳ Next
**Wave**: 4
**Requires**: [2.3]
**Enables**: []
**Files Touched**:
  - `src/repositories/fieldOutcomeRetention.ts`
  - `src/core/settings.ts`
  - `tests/unit/env.ts`
  - `tests/unit/repositories/fieldOutcomeRetention.test.ts`
  - `.env.example`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-204 live in:

> **`dev-stories/Work-In-Progress/Epic-02/epic-02-data-layer.md`** → section **`PEA-204 — Purge AI.fieldOutcome rows past the configured retention window`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## Build state

⏳ **Next to build.** The **mechanism** is fully buildable today; the **number** is not.

`AI.fieldOutcome` is the only table in this epic that grows meaningfully — ~30 rows per encounter,
~10.95M rows/year at 1,000 AI-assisted encounters a day — and it holds clinical values, so a
retention policy is not optional.

## 🔴 The trap in this story, and it fails silently

**The setting must be `z.coerce.number().int().positive().optional()` — never `.default(0)`.**

`settings.ts` throws on a missing required field, which is exactly the fail-closed behaviour the
purge depends on. The idiomatic zod default would turn an unmade compliance decision into a
**full-table DELETE** of clinical data. Port the behaviour, not the field list.

## Why the number is not in this story

Neither primary source document states a retention period (open question B7 / decision **D4**), and
inventing a day-count here would be the unsupported number `CLAUDE.md`'s numbers rule forbids. D4 is
the longest-lead item in the epic — two documents have already stalled on it.

Whatever window compliance sets must also stay longer than Epic 10's evaluation harness needs; that
harness replays recent real notes (REQ-10-08), not the full corpus, so a reasonable window does not
starve it. The exact minimum is Epic 10's to specify.

## Acceptance focus for review

- With the setting unset: **zero rows deleted**, and a logged refusal naming the missing setting —
  **never any row's content**
- With it set to a positive integer: rows older than the window deleted, rows inside untouched
- The refusal path is testable **without** the retention number, so this story can be completed and
  reviewed while D4 is still open
- Adding the setting means touching `src/core/settings.ts`, `tests/unit/env.ts` and `.env.example` —
  all `shared_files`. `tests/unit/env.ts` must name the new variable or a developer's `.env.local`
  leaks into tests

## Related open risk

**No patient-request erasure path exists** (Q7). `proposedValue`, `acceptedValue` and `foundIn` are
PHI; time-based retention is not a deletion-on-request mechanism.

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
