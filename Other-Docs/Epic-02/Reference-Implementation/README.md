# PEA-201 — Reference Implementation

> ⚠️ **Superseded.** This code now lives, committed and extended, on `pacEHR_AI` branch `3p-dev/PEA-201-ai-schema-data-layer`. The copies here are not maintained — read the branch.

**Story:** PEA-201 · **Date:** 2026-10-05 · **Target repository:** `pacEHR_AI`

Copy-ready artefacts for PEA-201, written against `pacEHR_AI` at commit `e86c54e` (2026-10-01)
and **verified by running them there**. They live here rather than in `pacEHR_AI` because this
folder is the only place this workstream may write.


> ✅ **Decision, 2026-10-05 — no database roles, and no `GRANT`s, in this epic.**
> `0002_create_ai_roles.sql` is withdrawn and the remaining scripts renumbered `0002`–`0005`
> (free: nothing was committed). Authority over `AI.*` is enforced **in the application** — the
> service connects as one principal, and which caller may read or write what is decided above the
> data layer.
>
> **This closes D2 and M1**, which were the hard blocker on four stories' security DoDs and on
> PEA-201's `0001`. Those DoD items are not "passed" — they are **withdrawn**, which is the
> honest reading.
>
> 🔴 **What it costs, recorded once so it is a decision and not a drift.** `AI.agentRun` is
> specified as an audit record *"no application code can have edited after the fact"*, and the
> epic's sharpest verification check was that the runtime principal held `SELECT + INSERT` only.
> Without permissions, nothing at the server refuses an `UPDATE` or `DELETE` against the audit
> table: the guarantee becomes *no application code **does** edit it*, which is a convention, not
> a control. **If the compliance claim matters, the cheap substitute is a trigger, not a role** —
> an `INSTEAD OF UPDATE, DELETE` on `AI.agentRun` that throws needs no principal, no grant and no
> provisioning. Six lines. See `HANDOFF.md` §3.

---

## What is here

```
migrations/sql/0001_create_ai_schema.sql      the AI schema, guarded
migrations/sql/0002_create_ai_roles.sql       the three roles, guarded   ◀── inert until D2
src/core/databaseMigrations.ts                validate() · readScripts() · MigrationRunner
src/migrate.ts                                the deploy-time entrypoint
src/core/database.ts                          ◀── MODIFIED. Two additions, see below
tests/unit/core/databaseMigrations.test.ts    the CI scope check — 11 cases
tests/unit/core/database.transaction.test.ts  transaction + run — 4 cases
tests/integration/core/databaseMigrations.test.ts   double-apply against a live database
```

Copy each file to the same path under `pacEHR_AI/`. **`src/core/database.ts` is a modification of
the existing file**, not a new one — diff it before pasting. Nothing else moves.

### The two additions to `src/core/database.ts`

Both are changes to a shared surface, delivered together so the two stories that trip over them
do not each invent a local workaround.

**`run(statement, params)`** — for a statement that returns no rows. `execute` returns
`(await request.query(statement)).recordset`, and mssql builds that as
`recordset: recordsets && recordsets[0]` (`lib/base/request.js:278`); `recordsets` is empty for
DDL, so `execute` hands back `undefined` while its type promises an array. `MigrationRunner` now
calls `run`. Widening `execute`'s return type instead would push the check onto every caller that
*does* return rows, which is nearly all of them.

**`transaction(work)`** — needed by **PEA-202**: `AI.agentRun` and its `AI.fieldOutcome` rows must
land together, or the audit trail records a completed run whose field outcomes are missing, which
reads worse than no row at all. The callback receives the only way to issue a statement inside the
transaction; the transaction object is never handed out, so a statement sent through
`database.execute` during the work cannot silently run outside it on another connection.

## Evidence

Run in a scratch clone of `pacEHR_AI@e86c54e` with these files overlaid, against the repository's
own `node_modules`:

| Check | Result |
|---|---|
| `npm run typecheck` | clean |
| `npm test` | **88 pass, 0 fail** (60 before, so 28 added) |
| `npm run build` | `dist/migrate.js` and `dist/core/databaseMigrations.js` emitted |
| *the tree imports with no environment, no network and no child process* | passes — the runner has no import side effects |
| *the tree reports no guard message* | passes — lints clean against `eslint.config.js` |

**Mutation-tested**, because a guard nobody has seen fail is not a guard:

| Planted in `migrations/sql/` | Caught by | Message |
|---|---|---|
| `ALTER TABLE Encounter.encounter ADD aiFlag BIT` | 2 cases | `0003_bad_scope.sql references encounter` |
| `DROP TABLE [AI].[agentRun]` | 2 cases | `0003_rollback.sql contains DROP` |
| `CREATE TABLE [AI].[widget]` with no guard | 1 case | `0003_unguarded.sql: 1 CREATE statements, 0 guards` |

Each removal returned the suite to green. The first is the epic's Gherkin scenario *"a script
touching an object outside the AI schema is rejected before merge"*, satisfied literally.

The transaction was mutation-tested the same way, since a rollback that silently did not happen
looks exactly like a commit until the data is wrong:

| Mutation to `database.ts` | Caught |
|---|---|
| rollback removed on the failure path | ✅ 2 cases |
| `commit()` called on the failure path | ✅ 2 cases |

**Failure paths**, both exiting `1` so a pipeline step reads them correctly:

- no configuration → `settings: missing or invalid: AZURE_OPENAI_ENDPOINT, …`
- a script containing `GO` → `migrations: 0003_has_go.sql: contains a GO separator`, logged
  with fields, **refused before any connection is opened**

---

## Three changes to make in `pacEHR_AI` alongside the copy

**1. `package.json` — add the entrypoint.**

```json
"migrate": "tsx src/migrate.ts",
"migrate:prod": "node dist/migrate.js"
```

**2. `CLAUDE.md` — amend the folder schema.** § Folder schema lists the root inventory
explicitly, and `migrations/` is not in it. Without the amendment the next reader treats the
folder as stray. Suggested line, in the code block:

```text
migrations/sql/  forward-only AI-schema scripts, applied by src/core/databaseMigrations.ts
```

**3. `src/core/database.ts` is modified, not added.** Diff it against the current file before
pasting — the two additions are described above. They touch a shared surface, so they want a
reviewer who knows why `execute` and `run` are separate.

---

## Decisions these artefacts embed

**`0002` is split out from `0001`, so the blocked half is one file.** The epic has `0001` create
the schema *and* the roles. The schema half is unblocked today; the roles half waits on **D2**
(who owns the principals). Splitting lets `0001` and the runner land now.

⚠️ **This shifts the five table scripts to `0003`–`0007`.** Renumbering is free before anything
merges and impossible afterwards, because forward-only means a merged script is never edited.
Decide before the first merge, not after.

**Role membership is deliberately absent from `0002`.** Mapping `aiServiceRuntime` to the
service's managed identity needs that identity's name, which differs per environment — and every
script here is static literal SQL that takes no runtime parameter. **Membership is a deployment
step (D31/M11), not a migration.** This was not called out in the epic and is worth raising:
it means the roles are inert until the deployment path exists.

**No transaction wraps the set.** Each script guards its own objects and the set is forward-only,
so a failure leaves earlier scripts applied and a re-run resumes. This is also forced — there is
no transaction primitive in `database.ts` (which **PEA-202 does need**, separately).

**Validation is a set-level gate, not per-script.** Every script is read and checked before any
is executed, because a half-applied set is worse than an unapplied one and there is no
down-migration to undo it with.

**`src/migrate.ts`, not a CLI block inside the runner.** `tests/unit/repo.test.ts` imports every
file under `src/core/` and asserts the process produces no output and touches no network — an
entrypoint that ran on import would fail it. `src/server.ts` is the precedent for a root-level
entrypoint.

---

## One thing to settle in review

`MigrationRunner` holds no state. CLAUDE.md § Singletons says *"a class earns its place by
owning construction. It never earns it by forwarding."* — by that rule `applyPending` could be a
plain exported function and the class deleted.

It is a class here because the story's Definition of Done, and all ten Epic-02 documents, specify
`class MigrationRunner` with one public method `applyPending()`. **Deviating silently would fail
the DoD; following it bends a house rule.** Worth thirty seconds in review — if the DoD is
amended, delete the class and export the function.

## Still blocked

- **D2 / M1** — the three principals. `0002` creates roles but nothing grants to them and nothing
  is a member of them.
- **D31 / M11** — no deployment path exists in `pacEHR_AI` (no CI, no pipeline, no container, no
  Functions host), so the story's exit criterion — *`applyPending()` runs twice against staging,
  second run a no-op* — **cannot be met yet.** The code half is complete; the story is not.
