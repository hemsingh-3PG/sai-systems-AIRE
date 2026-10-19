# Story 2.1: Create the AI schema via a forward-only migration mechanism

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.1 | **PEA**: PEA-201 | **Jira**: PEA-201
**Date**: 2026-10-05 | **Points**: 5 | **State**: ✅ Built
**Wave**: 1
**Requires**: []
**Enables**: [2.2, 2.5, 2.6, 2.7]
**Files Touched**:
  - `migrations/sql/0001_create_ai_schema.sql`
  - `migrations/verification/post-apply-checks.sql`
  - `src/core/databaseMigrations.ts`
  - `src/migrate.ts`
  - `tests/unit/core/databaseMigrations.test.ts`
  - `tests/integration/core/databaseMigrations.test.ts`
  - `package.json`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-201 live in:

> **`dev-stories/Work-In-Progress/Epic-02/epic-02-data-layer.md`** → section **`PEA-201 — Create the AI schema via a forward-only migration mechanism`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## Build state

✅ **Built.** This is the work on branch `3p-dev/PEA-201-ai-schema-data-layer`.

## Deltas from the epic text — read these before reviewing

The epic doc at Revision 8 is authoritative on intent, but three things changed while building and
are **not** reflected in it:

1. 🔴 **No database roles, no `GRANT`s.** Owner decision 2026-10-05. `0002_create_ai_roles.sql` was
   withdrawn and the remaining scripts renumbered. `0001` creates the schema only. The epic's DoD
   items about `aiServiceRuntime`/`aiPromptAdmin`/`aiTemplateAdmin` are **withdrawn, not passed**.
   See ADR-01 in the target architecture.
2. 🔴 **`GO` is no longer banned — the rule was reversed.** `CREATE INDEX` cannot reference a table
   the same batch is creating, so every spec's DDL uses `GO`. The runner now splits on `GO` and
   sends each part as its own batch. `batches()` is exported and tested directly, because the batch
   is the unit the server actually receives. The epic's and `HANDOFF.md`'s claims about `GO` are
   superseded.
3. The schema **already exists in production** carrying `AI.prompt`, but no `CREATE SCHEMA` exists
   anywhere in source control (defect X9). The existence guard makes `0001` correct against both a
   production database, where it is a no-op, and an empty one.

## Acceptance focus for review

- Idempotency is by existence check against `sys.schemas`, **not** a tracking ledger table
- `EXEC('CREATE SCHEMA [AI]')` — `CREATE SCHEMA` must be first in its batch and mssql sends the file
  as one batch
- No file under `migrations/sql/` drops or reverses another
- The runner opens **no second connection** — it uses the `database` singleton's `execute()`
- The CI scope check is mutation-tested: planted `ALTER TABLE Encounter.encounter`,
  `UPDATE Template.fields`, `DROP TABLE [AI].[agentRun]` and an unguarded `CREATE TABLE` must each
  be caught
- The migration identity is distinct from the runtime principal

## Known defect in this story's own artefacts

⚠️ `migrations/verification/post-apply-checks.sql` check #4 reads *"The five tables exist — expect:
5 rows."* Four ship (`AI.promptFragment` is blocked). The first real deployment will report a false
failure unless the expectation is amended.

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
