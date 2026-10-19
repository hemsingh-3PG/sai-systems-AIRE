# Story 2.7: Store the per-mapping field description in AI.fieldDescription, admin-write only

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.7 | **PEA**: PEA-207 | **Jira**: PEA-207
**Date**: 2026-10-05 | **Points**: 3 | **State**: ✅ Built
**Wave**: 2
**Requires**: [2.1]
**Enables**: []
**Files Touched**:
  - `migrations/sql/0005_create_field_description.sql`
  - `src/repositories/fieldDescriptionRepository.ts`
  - `tests/unit/repositories/fieldDescriptionRepository.test.ts`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-207 live in:

> **`Other-Docs/Epic-02/epic-02-data-layer.md`** → section **`PEA-207 — Store the per-mapping field description in AI.fieldDescription, admin-write only`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## Build state

✅ **Built.** The authoring surface (M6 — template editor) is **not** built and is gated on D7.

## Why this table exists at all

`REQ-03-01` is **the highest-value requirement in the corpus**: a field's AI-facing description must
be keyed on `(templetID, sectionID, fieldID)`, never globally per `fieldID`, because the same
`fieldID` legitimately recurs across sections with a different meaning each time — Blood Pressure in
Review of Systems versus Exam. The description is the one sentence that tells the model what
distinguishes this slot from a similarly-named one, and only a per-mapping description can carry a
section-specific instruction such as *"only when re-measured … leave empty if already captured
elsewhere."*

## Why it is a fifth table when REQ-02-10 names four

`REQ-02-10` names four Phase 1 tables, matching the 4Pager's enumeration, and neither mentions a
description table — because the 4Pager predates reconciling per-mapping storage with `REQ-02-07`'s
*"existing clinical tables remain read-only and unchanged."*

A per-mapping description **cannot** be a new column on `Template.fields` or
`Encounter.encounterTempletMapping` — both are existing clinical tables this service may only read.
It has to be an `AI`-schema sidecar, and `AI`-schema DDL is this epic's job. `REQ-02-10`'s
substantive clause — *"no new data store is introduced"* — still holds: one more table in the same
existing database is not a new store.

## One fact per mapping, deliberately

`name`, `type` and `unit` are **absent**. They are live columns on `Template.fields`, read-only, and
joined in at request time by Epic 3's schema-builder. Copying them here would create a second source
of truth that drifts silently.

## Acceptance focus for review

- The composite key **is** the whole key — no surrogate id, because nothing references a description
  by id and the mapping grain is the identity
- One description per mapping, enforced by the PK, so no secondary index earns its place
- No foreign key to `Template.*` — a foreign key would be a write dependency on tables this service
  may only read
- The agent never writes here

## Open decision

**D6** — description versus the existing `aiSummaryPrompt`. Run PEA-207 §5.4's sizing query first;
it may make the decision trivial. Also gates Epic 3.

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
