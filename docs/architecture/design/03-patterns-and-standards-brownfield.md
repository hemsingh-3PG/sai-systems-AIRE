# Patterns & Standards — PacEHR Encounter Agent (`PacEHR_AI`)

**Date**: 2026-10-05
**Author**: ARCHITECT
**Status**: Draft — awaiting user approval
**Version**: 1.0
**Scope**: the `PacEHR_AI` Node/TypeScript service. The .NET API and Angular SPA keep their own
conventions, documented in `docs/architecture/current/01-…12-*-deep-dive.md`, and are **not**
governed by this document.

**Based On**:
- `docs/architecture/current/00-system-overview.md`
- `docs/architecture/current/01-…12-*-deep-dive.md`
- `docs/architecture/design/02-target-architecture-brownfield.md`
- `docs/requirements.md`
- `SPEC/rulebooks/aire-design-patterns.md`
- **`PacEHR_AI/CLAUDE.md`** — the governing standard, per ADR-03

---

## 🔴 Which standard governs

**`PacEHR_AI/CLAUDE.md` governs this service. `SPEC/rulebooks/aire-design-patterns.md` and
`SPEC/rulebooks/aire-clean-architecture.md` do not.**

This is recorded as **ADR-03** in the target architecture and chosen explicitly by the user in this
workflow. It matters because the two prescribe opposite shapes: the rulebook lists *"Singleton
Abuse → use dependency injection"* as an anti-pattern, and module-level singletons are precisely
what this service is built on.

The reason is not preference. A caller constructing its own copy of `database` or `llmManager` pays
for a second TLS handshake, a second JWKS fetch or a second compiled agent — **and no test catches
it.** The cost lands in production, under load, as latency no local measurement predicts. The
rulebook's own decision checklist (*"Patterns add complexity. Only use when benefit > cost"*)
reaches the same answer.

**A reviewer applying the clean-architecture rulebook to this service will raise findings that are
wrong.** That is the single most likely source of spurious review output, and the reason this
section is first.

---

## Pattern Decisions Summary

| # | Pattern Category | Choice | Migration Effort |
|---|---|---|---|
| 1 | Error Handling | **[C] Current — kept** | — |
| 2 | Logging | **[C] Current — kept** | — |
| 3 | Database Access | **[C] Current — kept** | — |
| 4 | API Response Format | **Deferred — owned by Epic 9** | — |
| 5 | Configuration Management | **[C] Current — kept** | — |
| 6 | Naming Conventions | **[C] Current — kept** | — |
| 7 | Code Organisation | **[C] Current — kept** | — |
| 8 | UI Components / Shared Library | **Skipped — no UI layer** | — |

**No pattern is a new adoption, so no migration note is required anywhere in this document.** Every
pattern below is already implemented in shipped code, and most are enforced by lint rather than by
review.

---

## Project Structure `[Current — kept]`

```text
src/core/           settings, app (HTTP), database, LLM clients, knowledge base,
                    documents, auth, errors, logging, task dispatch, shared tools
src/conversations/  conversation + message persistence (scaffold only)
src/chat/           WebSocket app, protocol, socket, turn pacing (scaffold only)
src/pacehr/         agents, tools, prompts
src/repositories/   one class per AI.* table, the only readers and writers of it
src/server.ts       local npm start entrypoint
src/migrate.ts      deploy-time entrypoint: applies migrations/sql/ and exits
migrations/sql/     forward-only AI-schema scripts
tests/              unit | integration | manual — the directory is the marker
```

**Rules**

- **There is no barrel file.** A folder is created by the epic that puts code in it; a scaffold
  folder holds exactly one file, its `README.md`, because git tracks no empty folder.
- `"type": "module"`. Source is `.ts`; import specifiers keep `.js` extensions (NodeNext maps
  `.js` → `.ts` at compile time). Built-ins take the `node:` prefix.
- Across folders and from every test, imports use the package alias **with the extension written**:
  `import { settings } from '#core/settings.js'`. Inside one folder, imports are relative.
- **No top-level `await` in the tree.** It blocks every importer on I/O.
- File length: no fixed limit. The constraint is one public method per surface — the largest file
  in the service is 106 lines.

---

## 1. Error Handling `[Current — kept]`

### The pattern

`PacEHRError extends Error` sets `name = this.constructor.name`. A subclass has no body. The request
boundary dispatches on `instanceof`: a `PacEHRError` is a refusal → 4xx; anything else → 500.

```typescript
// ✅ DO — src/core/errors.ts, verbatim
export const AUTHENTICATION_FAILED_MESSAGE = 'Authentication failed.';

/** A refusal: the boundary maps it to a 4xx, and anything that is not one to a 500. */
export class PacEHRError extends Error {
  name = this.constructor.name;
}

/** The bearer token was rejected. Never given a jose error as `cause`: its `payload` carries the claims. */
export class AuthenticationError extends PacEHRError {}
```

```typescript
// ❌ DON'T — a jose error attached as cause
catch (e) {
  throw new AuthenticationError('bad token', { cause: e });   // leaks the full claim set
}
```

**Why**: jose's claim errors carry the token's entire claim set as `payload`, `oid` included, and a
logged chain writes it into the line. Log `e.code`, `e.claim` and the `kid` — nothing else.

### Rules

| Rule | Reason |
|---|---|
| A configuration fault is a plain `Error`, never a `PacEHRError` | It is a 500, never a refusal. It names keys only — the value may be the API key |
| A jose error is never attached as `cause` and never logged | Its `payload` is the claim set |
| Key-endpoint failures are classified **by `code`**, not by `instanceof errors.JOSEError` | An unreachable host surfaces as a `TypeError`; narrowing on `JOSEError` sends an outage down the token-fault path |
| **A guard never throws.** It blocks by returning `{ jumpTo: 'end' }` | A jump still runs `afterAgent` so the audit row is written. A throw rejects `invoke`, skips `afterAgent`, and destroys the audit row for exactly the runs most worth auditing. **Both measured**: jump → 0 model calls, `afterAgent` ran; throw → 0 model calls, `afterAgent` did not |
| Every promise is awaited or returned | An unhandled rejection exits with code 1. `core/` installs no `unhandledRejection` listener — a listener switches that crash off and runs on in an unknown state |

### Anything a user reads is an exported constant

```typescript
// ✅ DO
throw new AuthenticationError(AUTHENTICATION_FAILED_MESSAGE);

// ❌ DON'T
throw new AuthenticationError('Authentication failed.');   // now in two places
```

---

## 2. Logging `[Current — kept]`

```typescript
// ✅ DO — src/core/logging.ts, verbatim
export const logger = pino({}, pino.destination({ dest: 1, sync: true }));

// in a module
const log = logger.child({ module: 'core.database' });
log.warn({ cause, kid }, 'bearer token rejected');     // fields first, literal message second
```

```typescript
// ❌ DON'T
log.warn('bearer token rejected', { cause, kid });     // fields silently dropped
log.warn({ cause }, `rejected ${kid}`);                // kid interpolated into the message
log.error({ error: e }, 'failed');                     // only `err` serialises as an error
log.info({ a }, 'one', 'two');                         // extra args are printf values
```

| Rule | Enforcement |
|---|---|
| Fields first, a **literal** message second | ESLint — rejects a call whose last arg is not a non-empty string literal |
| At most two arguments | ESLint |
| An error is logged under the `err` key | pino serialises no other key as an error |
| One root logger; each module takes `logger.child({ module: '…' })` | Convention |
| The entrypoint sets the level from `settings().logLevel`; children follow | Convention |

### 🔴 What is never logged

**No clinical value reaches a log line, a trace attribute or an error message.** Log the token,
never the value. This covers `proposedValue`, `acceptedValue`, `foundIn`, patient identifiers, the
note text, and every field of `AI.fieldOutcome` that holds a clinical value.

The retention purge is the worked example: when the window is unset it **logs a refusal naming the
missing setting, not any row's content.**

---

## 3. Database Access `[Current — kept]`

Chosen over the rulebook's Repository Pattern in this workflow. The rulebook's version uses
constructor injection (rejected by ADR-03), `mapToEntity()` into domain entities (an abstraction
with one implementation — the rulebook's own `yagni`), and positional `?` binding (weaker than
named binding for a twelve-column insert).

### The singleton

```typescript
// ✅ DO — src/core/database.ts, abridged
class Database {
  /** The process's pool, built from `settings()` on first read. Building it opens nothing. */
  get pool(): sql.ConnectionPool {
    const value = new sql.ConnectionPool({ /* … */ });
    // An unheard 'error' exits the process, and the pool re-emits connection failures.
    value.on('error', (e: Error & { code?: string }) => log.error({ code: e.code }, 'sql pool error'));
    Object.defineProperty(this, 'pool', { value, configurable: true });
    return value;
  }
}
export const database = new Database();
```

```typescript
// ❌ DON'T
const myPool = new sql.ConnectionPool(config);   // a second TLS handshake, no test catches it
class DatabaseCache { get db() { return database; } }   // a cache over a thing already cached
```

| Rule | Reason |
|---|---|
| The instance is exported on the module's **last line**, named after the class | The module cache makes it one object per process |
| **Construction reads nothing, builds nothing, touches no network** | Lets `tests/unit` import the whole tree with no environment; keeps a cold start from paying for a client it never uses |
| Every expensive member is a **lazy getter that overwrites itself** via `Object.defineProperty(this, name, { value, configurable: true })` | First use builds it; the process reuses it. A getter that does not `await` runs to completion before any other JavaScript — twelve concurrent callers measured getting one object |
| An expensive member is never a `#private` field | A test could not seed it |
| An EventEmitter member gets its `'error'` listener **in the getter that builds it** | An `'error'` with no listener kills the process; the mssql pool emits one for connection failures |
| The pool is closed by the **entrypoint's** shutdown path, never by `core/` | Azure Functions terminate hooks do not run on forced termination |
| **No wrapper over a wrapper** | mssql dedupes an in-flight `connect()`, jose dedupes an in-flight JWKS fetch, `getBearerTokenProvider` caches to its refresh window — each measured, none gets a cache of ours |

### Statements

```typescript
// ✅ DO — src/repositories/fieldOutcomeRepository.ts, verbatim
export const SET_FIELD_OUTCOME_DECISION_SQL = `
UPDATE [AI].[fieldOutcome]
   SET [acceptedValue]       = @acceptedValue,
       [acceptedUnit]        = @acceptedUnit,
       [acceptedStatus]      = @acceptedStatus,
       [decidedByProviderID] = @decidedByProviderID,
       [decidedAtUtc]        = getutcdate()
 WHERE [outcomeID] = @outcomeID
   AND [decidedAtUtc] IS NULL;
SELECT @@ROWCOUNT AS [changed]`;
```

```typescript
// ❌ DON'T
const sqlText = `SELECT * FROM AI.fieldOutcome WHERE encounterID = ${id}`;   // injection
await pool.request().query`SELECT … ${id}`;   // tagged template — banned by lint
function buildWhere(filters) { … }            // statement assembled at call time
```

| Rule | Reason |
|---|---|
| **One statement per constant, `SCREAMING_SNAKE`, suffixed `_SQL`, declared above the class that runs it** | The reader sees every statement a module can issue without opening a method |
| Parameters are `@name` placeholders bound with `request.input(name, value)` | Server-side binding through `sp_executesql` is what makes injection impossible |
| **No statement is assembled at call time; no value ever reaches SQL by interpolation** | — |
| The tagged-template `query` form is **banned** | It binds, but moves the statement to the call site and reads as interpolation |
| A template literal in a statement constant interpolates a **fixed column list only** | — |
| Rows come back as objects keyed by column name; every computed column carries an alias | `SELECT @@ROWCOUNT AS [changed]` |
| `OUTPUT INSERTED.[…]` rather than `SCOPE_IDENTITY()` | Insert and id in one round trip, unaffected by a trigger adding rows elsewhere |
| **Preserve the live database's own spelling, including its inconsistencies** — `templetID`, `fieldID`, `sectionID` | REQ-02-09. Retro-fitting conventions onto existing SQL is forbidden |

### Transactions

```typescript
// ✅ DO
await database.transaction(async (execute) => {
  const { runID } = (await execute(INSERT_AGENT_RUN_SQL, run))[0];
  for (const f of fields) await execute(INSERT_FIELD_OUTCOME_SQL, { ...f, runID });
});
```

The callback's `execute` is **the only way** to issue a statement inside the transaction, and the
transaction object itself is never handed out — so no statement can escape it onto a different
connection. Closes GAPS #17.

### Authority lives here `[Current — kept]`

Per **ADR-01** there are no database roles and no `GRANT`s. Authority is enforced by the shape of
this layer, which makes these rules load-bearing rather than stylistic:

| Table | Allowed statements | Forbidden |
|---|---|---|
| `AI.agentRun` | `INSERT_AGENT_RUN_SQL` — **that constant and no other** | Any update or delete constant. Its absence *is* the append-only guarantee |
| `AI.fieldOutcome` | proposal insert; decision update scoped `AND [decidedAtUtc] IS NULL` naming only accepted-value columns; pending-queue select | A statement touching both proposal and accepted columns |
| `AI.fieldConstraint`, `AI.fieldDescription` | reads on the request path | Agent writes — these are admin-authored |

**Mutation-tested**, so the guarantee is verified rather than asserted: removing
`AND [decidedAtUtc] IS NULL`, or making the proposal insert touch `acceptedValue`, each fails the
suite.

> ⚠️ **ADR-06 — `DECIMAL(6,2)` arrives in Node as a binary double.** A bound comparison written in
> JavaScript can flip at the boundary, which is the exact defect `DECIMAL` was chosen to avoid.
> Push the comparison into SQL, or carry an explicit documented tolerance. Decide before the first
> bound check is written, not after an intermittent bug is reported.

---

## 4. API Response Format — *deferred*

**Epic 02 adds no HTTP route.** The only committed convention is the health surface:

| Route | Rule |
|---|---|
| `GET /health` | Liveness. **Does no I/O.** |
| `GET /health/ready` | Checks Azure SQL and the model concurrently, each bounded at 15 s. Returns 200 or 503 with a **reason code per check** (`HTTP 403`, `ELOGIN`, `TIMEOUT`) — **never the error text**, which goes to one `warn` line |

⚠️ Every readiness hit is a billed model call: right for a person, wrong for a platform probe.

The request/response/error envelope for `/ai/encounter/extract` and `/ai/encounter/resolve` is
**owned by Epic 9** and deliberately not invented here. Note for whoever writes it: GAPS #23 records
that both endpoints are prose-only today — no JSON contract, no status codes, and three
irreconcilable run-id concepts. That is a real gap, not an omission of this document.

---

## 5. Configuration Management `[Current — kept]`

```typescript
// ✅ DO — one schema entry is the whole declaration of a setting
AI_FIELD_OUTCOME_RETENTION_DAYS: z.coerce.number().int().positive().optional(),
```

```typescript
// ❌ DON'T
AI_FIELD_OUTCOME_RETENTION_DAYS: z.coerce.number().default(0),   // 🔴 a full-table DELETE
process.loadEnvFile();                                           // writes into process.env
const region = 'eastus2';                                        // hardcoded environment value
```

**The `.default(0)` line is the sharpest trap in this service.** `settings.ts` throws on a missing
required field, which is the fail-closed behaviour the retention purge depends on. The idiomatic zod
default would turn an unmade compliance decision into a full-table DELETE. **Port the behaviour, not
the field list.**

| Rule | Reason |
|---|---|
| Configuration comes from `src/core/settings.ts` and nowhere else. `process.env` appears in that file and `tests/unit/env.ts` only | ESLint-enforced, with a planted-violation test |
| **Every setting is one entry in the zod schema.** `REQUIRED`/`OPTIONAL` are derived, never hand-maintained | A new setting is one schema entry |
| `settings()` reads `.env.local` with `util.parseEnv` on a path resolved from `import.meta.url` | The Functions host chooses the working directory, so a relative path finds no file in production |
| **Never `process.loadEnvFile`, never `--env-file`** | Both write into `process.env`, and `@azure/identity`, LangChain and `openai` read it on their own — a line in `.env.local` would steer a library behind `settings()`'s back |
| A name measured to steer a library even when every field is passed explicitly goes in `REFUSED`, and `settings()` throws if it is set | `AZURE_OPENAI_BASE_PATH` redirected the Bearer token to its own host; the LangSmith/LangChain tracing names sent requests off-Azure; `LANGCHAIN_VERBOSE` printed the prompt |
| Values are trimmed; empty is unset; whitespace-only is an error naming the variable | A whitespace API key was measured sending a junk `api-key` header beside the Bearer token |
| A failed parse throws one plain `Error` naming **keys only** | The value may be the API key |
| The result is `Object.freeze`d, camelCase fields, SCREAMING_SNAKE env names | — |
| **No hardcoded environment values** — no region, deployment name, endpoint, resource id, container name or port literal outside `settings.ts` | Correct in one environment, wrong in every other |
| Deployed code authenticates with managed identity; API key and SQL login are local-development fallbacks | `AZURE_SQL_USER`/`AZURE_SQL_PASSWORD`: both or neither — half a login falls back to managed identity and fails as an unrelated Entra error |

---

## 6. Naming Conventions `[Current — kept]`

| Thing | Convention | Example |
|---|---|---|
| Singleton instance | Class name in camelCase | `LLMManager` → `llmManager` |
| Members | camelCase | `azureOpenaiGpt41Llm` |
| LLM members | `<provider><Model>Llm` | matches the `azure_openai` prefix `initChatModel` resolves |
| SQL constants | `SCREAMING_SNAKE` + `_SQL`, above their class | `INSERT_AGENT_RUN_SQL` |
| User-facing text | Exported constant | `AUTHENTICATION_FAILED_MESSAGE` |
| Tunables | Module constant carrying its unit | `REQUEST_TIMEOUT_MS` |
| Database columns | **The live database's own spelling, misspellings included** | `templetID`, `sectionID`, `fieldID` |
| Database entry point | `database.execute(sql, params)` — no sync/async prefix | The driver is async; there is no blocking twin |
| Test files | Mirror the source path under their tier | `src/core/llm.ts` → `tests/unit/core/llm.test.ts` |
| Migrations | `NNNN_snake_case.sql`, forward-only | `0003_create_field_outcome.sql` |

**Numbers**: a bare number in an expression is a bug. Every tunable is a module constant whose
comment carries the observation that produced it. *A constant nobody can trace back to a measurement
is a guess wearing a name.* A limit that varies by environment is a `settings()` field; a limit
belonging to a protocol is a constant.

---

## 7. Code Organisation `[Current — kept]`

| Rule | Reason |
|---|---|
| **No function that exists to call one other function** | One caller, no branching → inline it |
| **One class per surface, one public method** | An endpoint's logic in one `run()` that reads top to bottom: validate, read, build, call, unwrap |
| **Duplicating five lines across two classes beats sharing them through a helper the reader must go find** | — |
| **Formatting lives with the thing being formatted, in one method** | One method emitting one array of lines shows the whole output shape at once |
| A manager is a namespace with a lifetime, not a service layer | **A class earns its place by owning construction. It never earns it by forwarding** |
| **Verify, do not recall** | Every claim about a library, Node, the schema or Azure is checked by running something. Node and LangChain material from memory is stale |

### Comments

Fewer comments; each states a fact — a measurement, a constraint, or why a non-obvious line exists.
Never a change log, never an essay, never that a rule forced it.

- **The comment at the top of a module says what the module is and why it is not the module beside
  it.** That sentence is what prevents the next wrong merge.
- A summary comment is the result, not the activity: *"The recordset rows."*
- A deliberate shortcut with a known ceiling carries a `ponytail:` comment naming the ceiling and
  the upgrade path.
- A date appears only as the date of a measurement against a live system.
- ⚠️ marks a trap that has already cost a run, and nothing else.
- **Deleted code is deleted.** A commented-out block survives only with the sentence explaining why
  putting it back is wrong.

---

## 8. Testing Patterns `[Current — kept]`

`node:test` with `node:assert/strict`. **A test is classified by the directory it lives in.**

| Tier | Command | Reaches |
|---|---|---|
| `tests/unit` | `npm test` | Nothing — no environment, no credentials, **network blocked** |
| `tests/integration` | `npm run test:integration` | Azure |
| `tests/manual` | a person | — |

```bash
node --import tsx/esm --import ./tests/unit/no-network.ts --test "tests/unit/**/*.test.ts"
```

**The glob is always quoted and always given**: a bare `node --test` also collects
`tests/integration`, and a directory argument fails.

### The network block

`tests/unit/no-network.ts` patches `net.Socket.prototype.connect`, `tls`, `dns`, `http`, `https` and
`fetch`, calls `syncBuiltinESMExports()` so named imports see the patch, and **sets exit code 99 on
any attempt**. A file whose process exits 99 fails the run, so a library that swallows the error
still fails. Prototype methods are patched; classes are never replaced. `--permission` does not gate
the network and is no substitute.

### The import proof

A child process started with `env: {}` and the `tests/unit/no-spawn.ts` preload imports every `.ts`
under `src/core`, `src/conversations`, `src/chat` and `src/pacehr`, and **exits 0 with empty stderr,
with no lazy member built.** `no-spawn.ts` is the network block plus `child_process`, which
`DefaultAzureCredential` spawns.

### Seeding, not mocking

```typescript
// ✅ DO — seed the member; the getter never runs
Object.defineProperty(llmManager, 'azureOpenaiGpt41Llm', { value: fake, configurable: true });
Reflect.deleteProperty(llmManager, 'azureOpenaiGpt41Llm');   // restore

// ❌ DON'T
llmManager.azureOpenaiGpt41Llm = fake;   // TypeError — plain assignment onto a getter
mock.module('#core/llm.js', …);          // needs an experimental flag
```

An ES module namespace is read-only, so **no test replaces a module's export.** Stub with
`t.mock.fn` / `t.mock.method`.

### One environment per test file

Each file runs in its own process, so each starts with an empty `settings()` memo.
`useTestEnv(overrides)` sets **every** name before the first `settings()` call — `''` for names a
test does not use — so a developer's `.env.local` can neither fill a gap nor flip a test onto
another branch. **A second branch is a second file.** Never assign `undefined` to `process.env`; it
stores the string `"undefined"`.

### Rules that have already caught bugs

| Rule | What it catches |
|---|---|
| The LLM test clears the `AZURE_OPENAI_*` variables after its first `settings()` call, then reads the client's fields | A field the code forgot to pass cannot be filled from the environment |
| An HTTP-level test runs `Reflect.deleteProperty(llmManager, 'azureOpenaiGpt41Llm')` before stubbing `fetch` | The openai client keeps the `fetch` it saw on its first invoke; a model built under an earlier stub keeps calling that stale stub |
| Each fake completion carries a unique `id` | The message reducer merges by id |
| An integration test computes its skip reason once and passes `{ skip: reason }` to each test | A skipped `describe` reports zero tests |

### 🔴 Tests assert behaviour, not shape

A test that parses source to check where an instance is declared breaks on every refactor that keeps
the behaviour. **Shape belongs in review.**

### Mutation testing for guarantees

Where a guarantee is enforced by the *absence* or *scope* of code, a test asserting the happy path
proves nothing. Plant the violation and assert the suite fails:

| Planted | Must be caught |
|---|---|
| `ALTER TABLE Encounter.encounter ADD aiFlag BIT` in a migration | Scope check |
| `UPDATE Template.fields SET prompt = NULL` | Scope check |
| `DROP TABLE [AI].[agentRun]` | Scope check |
| `AND [decidedAtUtc] IS NULL` removed from the decision update | Repository test |
| Proposal insert made to touch `acceptedValue` | Repository test |
| Transaction rollback removed / `commit()` on the failure path | Transaction test |

### Coverage

**Minimum 85%.** All new and modified code. Skip generated code and config. Enforced in CI —
⚠️ noting that `11-test-infrastructure-cicd-deep-dive.md` records that
`test-validation-pipeline.yml`'s `pr:` trigger **is ignored by Azure DevOps for Azure Repos Git**,
so tests are not gated today. That is R2/M11's problem, and it means "enforced in CI" is currently
aspirational.

### The two lint guards

`eslint.config.js` holds the guard rules **and nothing else**: `process.env` /
`process.loadEnvFile` / `globalThis.process` / `node:process` outside `settings.ts` and
`tests/unit/env.ts`; the log-call rules; the tagged-template `query`;
`@typescript-eslint/no-explicit-any`. `tests/unit/source-rules.test.ts` lints the tree **and a set
of planted violations**, asserting each one's file and line.

**A guard change ships with the planted violation that proves it fires.**

---

## 9. Documentation Standards `[Current — kept]`

| Artefact | Standard |
|---|---|
| Module header | What the module is, and **why it is not the module beside it** |
| Function doc | The result, not the activity. *"The caller's Entra object id, or `AuthenticationError`."* |
| Types | TypeScript annotations. `npm run typecheck` (`tsc --noEmit`) is the only check that catches a misspelled `AzureChatOpenAI` field — our variable names are LangChain's own fallbacks, so a typo silently reads the right value from the environment. Reported as `TS2769` |
| Dependency rationale | A row in the README table — JSON carries no comments |
| New module README | Only for a scaffold folder, so git tracks it |
| API docs | Deferred with the API contract (Epic 9) |

---

## File / Module Boundary Map

Authoritative input for `files_touched` and `shared_files` in `docs/plans/dependency-graph.yml`.
Paths are relative to `PacEHR_AI/`.

### Concern → owning files

| Concern | Owner | State |
|---|---|---|
| Settings schema | `src/core/settings.ts` | Built — Epic 02 adds `AI_FIELD_OUTCOME_RETENTION_DAYS` |
| Connection pool, execute, transaction | `src/core/database.ts` | Built |
| Migration runner | `src/core/databaseMigrations.ts` | Built |
| Migration scripts | `migrations/sql/0001…0005_*.sql` | Built (4 tables) |
| Post-apply verification | `migrations/verification/post-apply-checks.sql` | Built — ⚠️ check #4 expects 5 tables, 4 ship |
| `AI.agentRun` writes | `src/repositories/agentRunWriter.ts` | Built |
| `AI.fieldOutcome` reads/writes | `src/repositories/fieldOutcomeRepository.ts` | Built |
| `AI.fieldConstraint` reads | `src/repositories/fieldConstraintRepository.ts` | Built |
| `AI.fieldDescription` reads | `src/repositories/fieldDescriptionRepository.ts` | Built |
| Retention purge | `src/repositories/fieldOutcomeRetention.ts` | ⏳ Next — mechanism testable without the number |
| `AI.promptFragment` | `migrations/sql/0006_*.sql`, `src/repositories/promptFragmentRepository.ts` | 🔴 Blocked — ADR-05 |
| Deploy entrypoint | `src/migrate.ts` | Built |
| Local server entrypoint, shutdown | `src/server.ts` | Built |
| Health endpoints | `src/core/app.ts` | Built |
| Logging root | `src/core/logging.ts` | Built |
| Error base class, user-facing messages | `src/core/errors.ts` | Built |
| Trust boundary | `src/core/auth.ts` | Built — **never cut** |
| Agent, tools, prompts | `src/pacehr/` | ⏳ Epics 4, 7, 8 |

### 🔴 `shared_files` — two or more concerns must touch these

| File | Why it is shared | Collision risk |
|---|---|---|
| `src/core/settings.ts` | **Every** epic adds schema entries | **High** — the single most contended file. One entry per setting; merge conflicts are line-level and benign, but two epics adding the same name silently is not |
| `package.json` / `package-lock.json` | Every dependency change | **High** — `npm ci` refuses a lock disagreeing with `package.json` |
| `migrations/sql/` | Numbered sequence; **two epics choosing `0006` collide** | **High** — forward-only means a merged number is permanent. Allocate numbers before writing |
| `eslint.config.js` + `tests/unit/source-rules.test.ts` | Guard rules and their planted violations change together | **Medium** — a guard change ships with its planted violation |
| `tests/unit/env.ts` | Must name **every** settings variable | **High** — adding a setting without adding it here lets a developer's `.env.local` leak into tests |
| `src/core/database.ts` | Every repository depends on its surface | **Medium** — additive change only |
| `README.md` dependency table | One row per dependency | **Low** |
| `migrations/verification/post-apply-checks.sql` | Expected table count changes with each new table | **Medium** — currently stale |

**No DI container, no route registry, no plugin registration file, no feature-flag registry exists**
— so the usual brownfield cross-concern hotspots are absent by construction. That is a direct
benefit of ADR-03 worth stating: there is no central registration file for two epics to fight over.

---

## Known Tech Debt — Shared Code

**None in `PacEHR_AI`.** 750 lines across 12 source files; no `utils/` or `shared/` directory, no
duplicated helper, no generic component outside a shared library, no UI layer.

Out of scope but recorded so it is not mistaken for an absence: the Angular SPA carries real
shared-code debt — three charting stacks, two PDF engines, a dead Protractor suite, 317 specs
concentrated in two of 50 feature areas, and a misspelled `core/ineterceptors/` directory. See
`09-spa-shell-navigation-deep-dive.md` and `10-spa-feature-areas-deep-dive.md`. **Epic 02 touches
none of it.**

---

## Quality Checklist

Before a change in this service is reviewed:

- [ ] `npm test` passes — unit tier, network blocked, exit code not 99
- [ ] `npm run test:integration` passes, or its skip reason is stated
- [ ] `npm run typecheck` clean
- [ ] ESLint guards pass; any guard change ships with its planted violation
- [ ] Coverage ≥85%
- [ ] No `process.env` outside `settings.ts` / `tests/unit/env.ts`
- [ ] No value reaches SQL by interpolation; every statement is a `_SQL` constant above its class
- [ ] No clinical value in any log line, trace attribute or error message
- [ ] No second connection, client or agent constructed outside its singleton
- [ ] Every promise awaited or returned
- [ ] Every new tunable is a named constant traceable to a measurement, or a `settings()` field
- [ ] Live database spelling preserved on every column referencing an existing key
- [ ] A new migration takes the next unused number and reverses nothing
- [ ] A guarantee enforced by absent or scoped code has a planted-violation test
- [ ] Module header says what this module is and why it is not the one beside it
- [ ] No commented-out code without the sentence explaining why restoring it is wrong

### 🔴 Never cut, in any review

- **Input validation at a trust boundary** — `src/core/auth.ts` is one
- **The two lint guards** and their planted violations
- **Error handling that prevents data loss**, and anything the ticket explicitly asked for
- **The one runnable check** behind non-trivial logic — a smoke test is the minimum, not bloat

---

**Next workflow**: `aire-brownfield-plan` (or `aire-build-cycles` first, which is optional)
