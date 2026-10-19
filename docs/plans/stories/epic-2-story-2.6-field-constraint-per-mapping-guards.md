# Story 2.6: Store per-mapping field guards in AI.fieldConstraint, admin-write only

**Epic**: 2 — Data Layer, AI Schema | **ID**: 2.6 | **PEA**: PEA-206 | **Jira**: PEA-206
**Date**: 2026-10-05 | **Points**: 3 | **State**: ✅ Built
**Wave**: 2
**Requires**: [2.1]
**Enables**: []
**Files Touched**:
  - `migrations/sql/0004_create_field_constraint.sql`
  - `src/repositories/fieldConstraintRepository.ts`
  - `tests/unit/repositories/fieldConstraintRepository.test.ts`

---

## 🔴 Authoritative source

This file is a **pointer**. The User Story, Business Context, Gherkin Acceptance Criteria,
Technical Considerations and Definition of Done for PEA-206 live in:

> **`Other-Docs/Epic-02/epic-02-data-layer.md`** → section **`PEA-206 — Store per-mapping field guards in AI.fieldConstraint, admin-write only`** (Revision 8, 2026-10-05)

Read that section before implementing or reviewing. **When this file and the epic doc disagree, the
epic doc wins.** This file adds only the planning metadata above and the notes below.

---

## Build state

✅ **Built.** The authoring surface (M6 — template editor) is **not** built and is gated on D7.

## The grain, and why it is not re-argued here

Keyed on `(templetID, sectionID, fieldID)`, not on `fieldID` alone. `PEA-301` (Epic 3) argues this
at length from measured evidence: `Template.fields.displayName` is global today, and **one
displayName edit was measured reaching 179 of 458 templates**. A global, `fieldID`-only constraint
would let a bound written for one section silently apply to every other section reusing that
`fieldID` — the identical collision, one table over.

In most cases the bound really will be identical across sections — blood pressure is 70–200 mmHg
wherever it appears — and duplicate rows at the finer grain cost a little storage. **A coarser grain
that cannot express a difference costs correctness, and cannot be fixed later without a migration.**

## Two bands, not one — and the failure is silent in both directions

| Band | Behaviour |
|---|---|
| `plausibleMin` / `plausibleMax` | **Blocks** a value |
| `abnormalMin` / `abnormalMax` | **Flags** it and keeps it |

One unlabelled pair cannot express that difference: either real abnormal values pass unflagged, or
real hypertensive readings are refused as implausible.

## ⚠️ ADR-06 — the decimal trap

`DECIMAL(6, 2)` was chosen precisely because binary floating point makes a boundary comparison a
coin toss. **node-mssql surfaces `DECIMAL` as a JS double**, which reintroduces the exact defect the
column type was chosen to avoid.

**Push the comparison into SQL, or carry an explicit documented tolerance derived from the column
scale — never a bare `<=` in JavaScript.** Decide before the first bound check is written, not after
an intermittent boundary bug is reported. The shipped DDL carries a `ponytail:` note saying the
resolution belongs to the read path. Tracked as Q13 / R10.

## Open gap to verify

GAPS #7 claims this table cannot store four of the six things the compiled guard carries — risk
class, components, roles, temporal direction and horizon — which would kill role binding, leave the
BLOCK-versus-REVIEW branch with no input, and send every date field to `NO_GUARD_DEFINED` forever.
**Verify against the shipped DDL before closing.** The compiler itself is Epic 6's.

## Acceptance focus for review

- `UQ_fieldConstraint_mapping` on the triple — one row per mapping
- The two range CHECKs allow NULLs but reject `min > max`
- `unit` stored **as authored**, never converted here; a multi-unit value such as `kg|lb` against one
  min/max pair is ambiguous by construction, and the resolution belongs to the validator
- The agent never writes here — bounds are compiled from prose a clinical author writes

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
