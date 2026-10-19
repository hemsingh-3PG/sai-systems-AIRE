# PEA-201 — Handoff

**Date:** 2026-10-05 · **Target:** `pacEHR_AI` @ `e86c54e` · **Artefacts:** `./` (see `README.md`)

Everything a reviewer and an applier need: the DoD against evidence, the self-review the DoD
asks for, the PR package, and the apply runbook.


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

## 1. Definition of Done, against evidence

The epic's checklist, each item resolved to something checkable rather than asserted.

| # | DoD item | State | Evidence |
|---|---|---|---|
| 1 | `0001` creates the `AI` schema and the three roles, each guarded by an existence check | ✅ **done, split** | `0001` schema, `0002` roles. Every `CREATE` guarded; the split isolates the D2-blocked half (§3) |
| 2 | `databaseMigrations.ts` defines `class MigrationRunner` with one public method `applyPending()`, calling the `database` singleton | ✅ done | `applyPending()` is the only public method; calls `database.run()` — see §2 for why `run` and not `execute` |
| 3 | Unit test asserts every script touches only `AI` objects and contains no `ALTER`/`DROP`/`INSERT`/`UPDATE`/`DELETE` elsewhere | ✅ done | `tests/unit/core/databaseMigrations.test.ts`, 11 cases, **mutation-tested** — three planted violations each caught and named |
| 4 | Integration test applies the set twice and asserts the second run raises nothing and creates nothing | ✅ **written** · ⏸ **unrunnable** | `tests/integration/core/databaseMigrations.test.ts`. Needs a database — blocked on **M11** |
| 5 | No file under `migrations/sql/` drops or reverses another | ✅ done, enforced | Its own test case, so the rule survives the next author |
| 6 | Reviewed by a second engineer and dry-run against a staging copy before production | ⏸ **blocked** | Needs **M11** (no staging path exists) and a named reviewer |
| 7 | Reviewed against CLAUDE.md § Singletons and § Naming | ✅ **self-reviewed** | §2 below — including the two places it bends a rule |

**Items 1–3, 5 and 7 are complete. Item 4 is written and cannot run. Item 6 cannot start.**
The story is **not** closable; see §5.

### Verification run

Scratch clone of `pacEHR_AI@e86c54e`, these files overlaid, repository's own `node_modules`:

```
npm run typecheck   clean
npm test            88 pass, 0 fail      (60 before — 28 added)
npm run build       dist/migrate.js + dist/core/databaseMigrations.js emitted
```

Both repo-wide guards pass: *the tree imports with no environment, no network and no child
process*, and *the tree reports no guard message*.

---

## 2. Self-review against the engineering standard

DoD item 7. Honest, including where it bends.

### § Singletons

| Rule | Holds? |
|---|---|
| Instance exported on the last line, named after the class | ✅ `export const migrationRunner = new MigrationRunner();` |
| Opening comment reads "Use the exported `x`." | ✅ |
| Construction reads nothing, builds nothing, touches no network | ✅ no constructor; proved by the repo's import test, which this file now passes |
| Expensive members are self-overwriting lazy getters | n/a — no members. Script reading happens inside `applyPending`, once per process run |
| The pool is closed by the entrypoint, never by `core/` | ✅ `src/migrate.ts` closes it; `databaseMigrations.ts` never does |

⚠️ **Where it bends: "a class earns its place by owning construction. It never earns it by
forwarding."** `MigrationRunner` owns no construction and holds no state — by that rule
`applyPending` should be a plain exported function and the class deleted.

It is a class because the DoD and all ten Epic-02 documents specify `class MigrationRunner` with
one public method. **Deviating silently would fail the DoD; following it bends the rule.**
Thirty seconds in review: amend the DoD and delete the class, or keep both and accept it.

### § Naming

| Rule | Holds? |
|---|---|
| `SCREAMING_SNAKE` constants, unit in the name | ✅ `SCRIPT_DIRECTORY`, `SCRIPT_NAME`, `BATCH_SEPARATOR` |
| No value reaches SQL by interpolation | ✅ `0001`/`0002` are literal; `run`/`execute` bind every parameter server-side |
| Anything a user reads is an exported constant | n/a — no user-facing text; operator messages name files, never SQL or values |
| Unexported means one module owns it | ✅ the three constants are module-private; `validate`, `readScripts`, `Script` are exported because the unit test needs the seam |

⚠️ **Where it bends: the `_SQL` constant rule.** § Naming requires one statement per
`SCREAMING_SNAKE` `_SQL` constant above the class that runs it, so a reader sees every statement
a module can issue. **Migration text comes from files instead.** The intent is met differently —
`migrations/sql/` is the one place to read the whole schema — and the module comment says so.
Flagged rather than hidden, because it is a documented rule being departed from.

### § Tests

*"Tests assert behaviour, not shape. A test that parses source to check where an instance is
declared breaks on every refactor."* — `databaseMigrations.test.ts` parses text, which is close
to that line. It parses the **migration scripts**, which are data and are the artefact under
test, not TypeScript source; what it asserts is what the set will do to a database. The epic
requires exactly this check. **It does not parse any `.ts` file.**

### § Logging and PHI

- Every log call is `(fields, literalMessage)` — enforced by lint, not by this review.
- No SQL text, parameter value or script body reaches a log line or an error message. A failure
  names the **file**: `migrations: 0003_x.sql failed`, with the driver's error as `cause`.

---

## 3. Two decisions a reviewer must ratify

### 3a. No roles — and the one thing to decide about `AI.agentRun`

Roles and grants are withdrawn (2026-10-05). That closes D2 and M1 and removes the hard blocker
on `0001`. **One consequence needs a yes or no rather than a shrug.**

PEA-202 specifies `AI.agentRun` as an audit record *"no application code can have edited after
the fact"*, and REQ-02-03 exists so that *"show me every AI call on this chart"* has an answer
nobody could have tampered with. Under application-only authority that becomes *no application
code **does** edit it* — true today, unverifiable tomorrow, and not a control an auditor can test.

**If the claim matters, a trigger restores it and needs no principal, no grant and no
provisioning.** It would be `0006_agent_run_append_only.sql`:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'TR_agentRun_appendOnly')
EXEC ('CREATE TRIGGER [AI].[TR_agentRun_appendOnly] ON [AI].[agentRun]
       INSTEAD OF UPDATE, DELETE AS
       BEGIN
           THROW 50001, ''AI.agentRun is append-only.'', 1;
       END');
```

**Three things to weigh before taking it:**

- ✅ It is the only mechanism that makes the compliance claim testable without permissions, and
  the purge in PEA-204 does not touch this table — it deletes from `AI.fieldOutcome`.
- ⚠️ `INSTEAD OF` triggers are near-unprecedented in this product; the existing triggers are
  `AFTER UPDATE` audit copies. This would be a new pattern for the team to own.
- ⚠️ It fires on **every** write path forever, including a future legitimate correction — which
  is the point, and is also what someone will want to work around at 2am. A forward migration
  dropping and recreating it is the escape hatch, and it leaves a trace.

**If the answer is no, say so in the PR** rather than leaving it unsaid — so the next person
reading REQ-02-03 knows the guarantee was traded deliberately and not forgotten.

### 3b. Script numbering and role membership

**`0001`/`0002` split, shifting the table scripts to `0003`–`0007`.** Isolates the D2-blocked
half so the schema and runner can land now. ⚠️ **Renumbering is free before the first merge and
impossible after it** — forward-only means a merged script is never edited. Decide now.

🔴 **Role membership is absent, and the epic did not account for it.** Mapping `aiServiceRuntime`
to the service's managed identity needs that identity's name, which differs per environment,
while every script here is static literal SQL taking no runtime parameter. **Membership is a
deployment step (D31/M11), not a migration.** Consequence to state at grooming: **`0002`
produces three roles that nothing is a member of and nothing grants to**, until M11 exists.

---

## 4. PR package

Per `pacEHR_API/CLAUDE.md` the Jira key goes in all three places and Azure DevOps matches the
literal string — **a wrong key fails silently and the Development panel just looks empty.**
⚠️ Repository commits use **`AITP-`** keys; confirm this story's before cutting the branch.

```
Branch   AITP-xxx-ai-schema-migration
Commit   AITP-xxx create the AI schema and the forward-only migration runner
PR title AITP-xxx | AI schema + forward-only migration mechanism
```

**PR description checklist** (their four headings):

- **Unit test cases** — 28 added, 88 total passing. Scope check mutation-tested: three planted
  violations each caught and named; transaction rollback mutation-tested twice.
- **DB script** — `migrations/sql/0001_create_ai_schema.sql`, `0002_create_ai_roles.sql`.
  Forward-only, idempotent by existence check, no history table. **Not** SSDT: the AI schema is
  owned by this repository (Revision 7 decision).
- **Technical documentation** — `Epic-02/Tech-Specs/PEA-201-Delivery-Plan…md`; this handoff.
- **AI usage** — artefacts drafted with Claude Code, verified by running the suite, the build and
  mutation tests against a scratch clone of `e86c54e`.

**One concern per PR.** The `src/core/database.ts` additions (`run`, `transaction`) touch a
shared surface and serve PEA-202 as well — **consider a separate PR** so they get a reviewer who
cares about the primitive rather than one reviewing a migration.

---

## 5. Apply runbook

**Do not run step 3 until M11 exists and D2 is answered.** Steps 1–2 are useful now.

**1. Prove the set is clean, offline** — no database needed:

```bash
npm test                     # the scope check and the runner's own rules
npm run typecheck
```

**2. Dry-run against *two* targets.** A production restore has the `AI` schema already (defect
X9), so it **cannot exercise the `CREATE SCHEMA` branch at all** — the branch that has never been
in source control. Run both or that branch ships unexecuted:

```bash
npm run migrate              # against a restored production copy  → schema exists, no-op
npm run migrate              # against an empty database           → schema created
npm run migrate              # second time, each target             → no-op, exit 0
```

**3. Apply, then verify.** Run `verification/post-apply-checks.sql` and keep the output.
Expected: schema 1 row, roles 3 rows, **zero** rows from the clinical-object query.

**4. Evidence to retain** — full output of both runs, timestamped; the verification results;
before/after clinical-table checksums; second-engineer approval; the Jira Development panel
showing the link resolved.

**Rollback.** There is none, by design. A bad migration is corrected by a **new forward script** —
never an edit to a merged one, never a `DROP`. The unit suite enforces this.

---

## 6. Why this story cannot be closed

| Blocker | Effect |
|---|---|
| **D2 / M1** — the three principals | `0002` runs and produces three roles with no members and no grants |
| **M11** — no CI, pipeline, container or Functions host in `pacEHR_AI` | *"`applyPending()` runs twice against staging"* has no staging to run against |

**Claim the mergeable half.** Closing against the full DoD while the exit criterion is unmet is
how a migration mechanism nobody has ever run reaches a production release window.
