# Story 2.2: Record one append-only AI.agentRun row per invocation

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.2 | **PEA**: PEA-202 | **Jira**: PEA-202
**Date**: 2026-10-05 | **Points**: 3 | **State**: ✅ Built
**Wave**: 2
**Requires**: [2.1]
**Enables**: [2.3]
**Files Touched**:
  - `migrations/sql/0002_create_agent_run.sql`
  - `src/repositories/agentRunWriter.ts`
  - `tests/unit/repositories/agentRunWriter.test.ts`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-202 live in:

> **`Other-Docs/Epic-02/epic-02-data-layer.md`** → section **`PEA-202 — Record one append-only AI.agentRun row per invocation`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## Build state

✅ **Built.** No call path yet — the instrumentation that writes these rows arrives with Epic 4.

## Deltas from the epic text

🔴 **Append-only is now a convention, not a control.** With no `GRANT`s (ADR-01), nothing at the
server refuses an `UPDATE` or `DELETE` against the audit table. The guarantee is enforced by the
**absence of code**: `agentRunWriter.ts` has exactly one SQL constant, `INSERT_AGENT_RUN_SQL`.

The epic specified this table as a record *"no application code can have edited after the fact"*,
and its sharpest verification check was that the runtime principal held `SELECT + INSERT` only. That
check is gone. If the compliance claim is load-bearing, the substitute is an
`INSTEAD OF UPDATE, DELETE` trigger — no principal, no grant, ~6 lines. **Open decision (Q10).**

## What the as-built DDL resolved

Three `GAPS.md` findings appear closed here. Verification is this review's job:

| GAPS # | Finding | As-built |
|---|---|---|
| #3 | A guard-blocked run cannot write its row — `promptHash`/`modelDeployment` NOT NULL, no reason column | Both nullable, gated by `CK_agentRun_reachedModel`; `reasonCode` exists and `CK_agentRun_blockedHasReason` forces it for blocked runs |
| #9 | Two outcome vocabularies plus an orphan `error` value | `CK_agentRun_outcome` admits exactly `COMMITTED`, `AWAITING_REVIEW`, `BLOCKED` |
| §3 #12 | No `templetID`, no config version | Both columns present |

## Acceptance focus for review

- Exactly one SQL constant in the module; no constant could update or delete a row
- `OUTPUT INSERTED.[runID]` rather than `SCOPE_IDENTITY()` — one round trip, unaffected by a trigger
- A guard-blocked run writes its row with token/latency columns NULL and a non-null `reasonCode`
- The two CHECK constraints are the design, not decoration

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
