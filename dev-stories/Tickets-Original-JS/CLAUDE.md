# CLAUDE.md — PacEHR Encounter Agent

**This file is the engineering standard for this repository.** Tickets cite it and do not
restate it. Every rule below rests on something that was run, and names the failure it
prevents.

## What this repository is

This is the Node.js service in the Azure DevOps repository `PacEHR_AI`, checked out at
`/Users/akash.saxena/saisystem/projects/PacEHR_AI`. It reads a clinician's free-text note and extracts structured
clinical values into the fields of an encounter template. Extraction runs as a LangChain JS
agent built with `createAgent` against Azure OpenAI, with the checking done by ordinary
JavaScript in middleware the model cannot decline to run.

Azure is the only cloud in this repository: no other cloud's package is installed, and no
other cloud's import, client or identifier appears in its source. The lock file still names
three AWS packages as `openai`'s optional-peer metadata. That text is accepted pending the
user's confirmation (`00-langchainjs-api-truth.md` §16 #1). TypeScript is the source
language: ES modules, types in type annotations, no `.js` source file.

## Folder schema

```text
src/core/        settings, app (HTTP), database, LLM clients, knowledge base,
                 documents, auth, errors, logging, task dispatch, shared tools
src/conversations/  conversation + message persistence, shared by both products
src/chat/        WebSocket app, protocol, socket, turn pacing
src/pacehr/      agents, tools, prompts
src/server.ts    local npm start entrypoint
tests/           unit / integration / manual — the directory is the marker
```

`src/conversations/` and `src/chat/` belong to the other product on this repository: the
encounter agent scaffolds them and populates neither. A scaffold folder holds exactly one
file, its `README.md`, because git tracks no empty folder. A folder is created by the epic
that puts code in it.

There is no barrel file. The root holds `package.json`, `package-lock.json`,
`tsconfig.json`, `tsconfig.build.json`, `eslint.config.js`, `.env.example`, `.gitignore`,
`README.md` and this file. Built output goes to `dist/` (git-ignored).

A test is classified by the directory it lives in. `tests/unit` imports the whole tree with
no environment, no credentials and no network. `tests/integration` reaches Azure.
`tests/manual` is run by a person. A test file mirrors its source path under its tier —
`src/core/llm.ts` is tested by `tests/unit/core/llm.test.ts` — and a test that spans the
tree sits at the tier root.

## Modules

- `"type": "module"`. Source files are `.ts`; import specifiers keep `.js` extensions
  (TypeScript's NodeNext resolution maps `.js` → `.ts` at compile time). Built-ins are
  imported with the `node:` prefix.
- Across folders, and from every test, imports use the package alias with the extension
  written: `import { settings } from '#core/settings.js'`. Inside one folder, imports are
  relative: `./errors.js`. An import without its extension fails with `ERR_MODULE_NOT_FOUND`.
- A new top-level alias (`#pacehr/*`) arrives with the first file there that is imported from
  another folder. `#/*` is never used: it needs Node 24.14 and the floor is lower.
- CommonJS packages are imported by their default export: `import sql from 'mssql'`,
  `import pino from 'pino'`. mssql's named ESM exports are `undefined`.
- **No top-level `await` in the tree.** It blocks every importer on I/O, which is the one way
  an ES module breaks import hygiene without a constructor.

## Configuration

- Configuration comes from `src/core/settings.ts` and from nowhere else. `process.env`
  appears in that file and in `tests/unit/env.ts`, and in no other file in the tree.
- **Every setting is declared once, as an entry in the zod 4 schema in `src/core/settings.ts`.**
  Required versus optional, the default, trimming and normalisation live in that entry.
  `REQUIRED` and `OPTIONAL` are derived from the schema, never hand-maintained, and a field's
  camelCase name is derived from its environment name. A new setting is one schema entry.
- Values live in `.env.local`, which is git-ignored. `.env.example` is the committed
  template and carries every name in `REQUIRED` and `OPTIONAL` with a placeholder.
- `settings()` reads `.env.local` with `util.parseEnv` on a path resolved from
  `import.meta.url`, and tolerates only `ENOENT`. The Functions host chooses the working
  directory, so a relative path finds no file in production. **Never `process.loadEnvFile`,
  never `--env-file`**: both write into `process.env`, and `@azure/identity`, LangChain and
  `openai` read `process.env` on their own, so a line in `.env.local` would steer a library
  behind `settings()`'s back.
- The real environment wins over the file. The merged object is parsed by the schema, which
  strips every key it does not declare.
- **A name measured to steer a library even when every field is passed explicitly is listed
  in `REFUSED`**, and `settings()` throws if any of them is set to a non-blank value in the
  real environment. `AZURE_OPENAI_BASE_PATH` redirected the Bearer token to its own host, the
  LangSmith and LangChain tracing names sent requests to a non-Azure host, and
  `LANGCHAIN_VERBOSE` printed the prompt. A new name joins the list together with the probe
  that found it.
- In the schema, values are trimmed and an empty value is unset. A value that is only
  whitespace is a configuration error naming the variable — a whitespace API key was measured
  sending a junk `api-key` header beside the Bearer token. The endpoint loses its trailing slash (the client
  builds `//openai/...` from one). `LOG_LEVEL` is lowercased (pino throws on `INFO`).
- A failed parse throws one plain `Error` naming every missing or invalid variable. It names
  keys only, never a value or a zod message: the value may be the API key. It is never a
  `PacEHRError`: a configuration fault is a 500, never a refusal.
- The result is `Object.freeze`d, with camelCase fields; environment names stay
  SCREAMING_SNAKE.
- **`AZURE_OPENAI_API_KEY` keeps that name.** LangChain and `openai` read the same variable
  themselves, and with it set beside a token provider the first `invoke` throws `The apiKey
  and azureADTokenProvider arguments are mutually exclusive` — construction succeeds, so no
  import or unit test catches it. `settings()` choosing the key branch whenever that variable
  is non-blank is what keeps the two in agreement.
- **No hardcoded environment values.** No region, deployment name, endpoint, resource id,
  container name or port literal appears outside `src/core/settings.ts`. A value pasted into
  a module is correct in one environment and wrong in every other.
- Deployed code authenticates with managed identity — `ManagedIdentityCredential`, or
  `DefaultAzureCredential` in a module that also runs on a developer machine — with
  `managedIdentityClientId` passed from `settings().azureClientId`. An API key is a
  local-development fallback and never a deployed path.
- **`AZURE_SQL_USER` and `AZURE_SQL_PASSWORD` are the SQL-login fallback**, local development
  only, exactly like the API key: a laptop has no managed identity, and the DEV database
  accepts a SQL login. Both or neither — half a login would fall back to managed identity and
  fail as an unrelated Entra error, so the schema rejects it naming both. Never set when
  deployed.
- `PORT` (default 3000) is read by `src/server.ts` alone; the Functions host chooses its own port.

## Health endpoints

`npm start` serves two local routes from `src/core/app.ts`. `/health` is liveness and does no I/O.
`/health/ready` checks Azure SQL and the model concurrently, each bounded at 15 s, and returns
200 or 503. The body carries a reason code per check (`HTTP 403`, `ELOGIN`, `TIMEOUT`), never
the error text, which goes to one `warn` line. Every readiness hit is a billed model call:
right for a person, wrong for a platform probe.

## Dependencies

- npm manages dependencies. `npm install <pkg>` writes `package.json` and
  `package-lock.json`; both are committed. CI and the container run `npm ci`, which refuses a
  lock file that disagrees with `package.json`. A package in `node_modules` and not in the
  lock file is a package the deployed Function does not have.
- Ranges are carets; the lock file is the pin. A package imported by our code is a direct
  dependency — importing a transitive one breaks the day its parent drops it.
  `@langchain/core` is direct because it is a peer of `langchain` and `@langchain/openai`.
- JSON carries no comments, so the reason for each dependency is a row in the README table.
- `"engines": { "node": ">=22.13" }` is a floor with no ceiling: the highest floor any
  installed package declares. No `engine-strict`. A test asserts the declared value and that
  the running Node satisfies it. A dependency that raises its floor raises this one.
- npm's install-script approval stays on.

## Code standard

- **No function that exists to call one other function.** A one-line function that forwards
  its argument, or returns `row.name`, is a jump the reader makes for nothing. One caller and
  no branching means inline it.
- **No wrapper over a wrapper.** Before adding a cache, an accessor or a manager, check
  whether the thing underneath already provides it. `settings()` is already a memo; a getter
  that returns `settings()` is a second cache reaching the same object. mssql dedupes an
  in-flight `connect()`, jose dedupes an in-flight JWKS fetch, and `getBearerTokenProvider`
  caches its token until the refresh window — each was measured, and none gets a cache of ours.
- **One class per surface, one public method.** An endpoint's logic belongs in one `run()`
  that reads top to bottom: validate, read, build, call, unwrap.
- **Duplicating five lines across two classes beats sharing them through a helper the reader
  must go find.**
- **Formatting lives with the thing being formatted, in one method.** One method emitting one
  array of lines shows the whole output shape at once.
- **No promise floats.** Every promise is awaited or returned. An unhandled rejection exits
  the process with code 1. `core/` installs no `unhandledRejection` listener: a listener
  switches that crash off and the process runs on in an unknown state. The entrypoint owns
  that decision.
- **Verify, do not recall.** Every claim about a library, Node, the schema or Azure is checked
  by running something: `information_schema.columns` against the live database, a field read
  back off a constructed client, the `.d.ts` of the installed version, a live call. Node and
  LangChain material from memory is stale; documented numbers go stale.

## Singletons — the pattern this repository is built on

One object per process per job, the same shape everywhere. Read `src/core/llm.ts` and
`src/core/database.ts` and you have seen all of it.

- **The instance is exported on the last line of the module that defines the class**,
  named after it — `export const llmManager = new LLMManager();` — and the class's opening
  comment reads "Use the exported `llmManager`." The module cache makes it one object per process.
- A caller that constructs its own copy pays for a second TLS handshake, a second JWKS fetch
  or a second compiled agent, **and no test catches it.** The cost lands in production, under
  load, as latency no local measurement predicted.
- **Construction reads nothing, builds nothing and touches no network.** Importing any module
  works with no environment and no credentials — that is what lets `tests/unit` import the
  whole tree, and what keeps a cold start from paying for a client it never uses. A class has
  no constructor unless it binds what a second instance would differ on.
- **Every expensive member is a lazy getter that overwrites itself.** The prototype getter
  builds the value, stores it with `Object.defineProperty(this, name, { value, configurable:
  true })` and returns it. First use builds it; the process reuses it. A getter that does not
  `await` runs to completion before any other JavaScript runs, so it needs no guard: twelve
  concurrent callers were measured getting one object.
- A test seeds a member with `Object.defineProperty` before first read, and the getter never
  runs; `Reflect.deleteProperty(instance, 'member')` restores it. Plain assignment onto a
  getter throws a `TypeError`. An expensive member is never a `#private` field, because a
  test cannot seed it.
- **An initialiser that awaits before it caches builds once per concurrent caller** —
  twelve callers, twelve builds, measured. Cache the promise synchronously and evict it on
  rejection; a cached rejected promise fails every later caller for the life of the process.
  When the library already dedupes (the mssql pool does), cache the library's object and
  await its method instead.
- **An EventEmitter member gets its `'error'` listener in the getter that builds it.** An
  `'error'` event with no listener kills the process, and the mssql pool emits one for
  connection failures. The listener logs fields only.
- **The pool is closed by the entrypoint's shutdown path**, never by `core/`. Azure Functions
  terminate hooks do not run on forced termination, so nothing durable depends on shutdown
  running.
- A manager is a namespace with a lifetime, not a service layer. **A class earns its place by
  owning construction. It never earns it by forwarding.**

## Naming

- The instance is the class name in camelCase: `LLMManager` → `llmManager`,
  `EntraAuthenticator` → `entraAuthenticator`. Members are camelCase.
- Where one class has several instances, the product prefixes them.
- The database entry point is `database.execute(sql, params)`. The driver is asynchronous
  JavaScript over sockets; there is no blocking twin and no prefix marking one.
- LLM members are `<provider><Model>Llm` — `azureOpenaiGpt41Llm` — matching `azure_openai`,
  the provider prefix `initChatModel` resolves. A new provider is one more getter, not a new
  manager.
- **One statement per constant, `SCREAMING_SNAKE`, suffixed `_SQL`, declared above the class
  that runs it**, so the reader sees every statement a module can issue without opening a
  method. Parameters are `@name` placeholders bound with `request.input(name, value)`, which
  tedious sends through `sp_executesql`. No statement is assembled at call time, and **no
  value ever reaches SQL by interpolation** — server-side binding is what makes injection
  impossible. A template literal in a statement constant interpolates a fixed column list
  only. The tagged-template `query` form is banned: it binds, but it moves the statement to
  the call site and reads as interpolation.
- Rows come back as objects keyed by column name. Every computed column carries an alias.
- **Anything the user reads is an exported constant, not a literal at the throw site** —
  `AUTHENTICATION_FAILED_MESSAGE`. One place to read what the product says out loud.
- Unexported means one module owns it. When a second module wants it, the question is
  whether the two callers are one caller.

## Comments

Fewer comments. Each one is short and states a fact: a measurement, a constraint, or why a
non-obvious line exists. Never a change log, never an essay, never that a rule forced it.

- **The comment at the top of a module says what the module is and why it is not the module
  beside it.** That sentence is what prevents the next wrong merge.
- A summary comment is the result, not the activity: "The recordset rows." "The caller's
  Entra object id, or `AuthenticationError`."
- Types are TypeScript annotations. `npm run typecheck` (`tsc --noEmit`) checks them
  against the installed libraries' own types. That is the only check that catches a misspelled
  `AzureChatOpenAI` field: our variable names are the ones LangChain falls back to, so a typo
  silently reads the right value from the environment. It is reported as `TS2769`.
- A deliberate shortcut with a known ceiling carries a `ponytail:` comment naming the ceiling
  and the upgrade path.
- A date appears only as the date of a measurement against a live system. Never a changelog
  entry.
- ⚠️ marks a trap that has already cost a run, and nothing else.
- **Deleted code is deleted.** A commented-out block survives only with the sentence
  explaining why putting it back is wrong.

## Numbers

**A bare number in an expression is a bug.** Every tunable is a module constant whose comment
carries the observation that produced it, and whose name carries its unit —
`REQUEST_TIMEOUT_MS`. **A constant nobody can trace back to a measurement is a guess wearing
a name.**

A limit that varies by environment is a `settings()` field. A limit that belongs to a
protocol is a constant — changing it means changing something outside this repository, and a
value that can disagree with its external contract is worse than a literal.

## Logging

- One root logger: `src/core/logging.ts` exports `logger`, pino on a synchronous stdout
  destination, which registers no exit listener at import. Each module takes
  `logger.child({ module: 'core.llm' })`. The entrypoint sets the level from
  `settings().logLevel`; children follow it.
- **Fields first, a literal message second:** `log.warn({ cause, kid }, 'bearer token
  rejected')`. The reverse order silently drops the fields, and extra arguments are printf
  values that write their contents into the message.
- An error is logged under the `err` key; pino serialises no other key as an error.
- ESLint rejects a log call with more than two arguments, and one whose last argument is not
  a non-empty string literal.

## Errors

- `PacEHRError extends Error` and sets `name = this.constructor.name`. A subclass has no
  body. The boundary dispatches on `instanceof`: a `PacEHRError` is a refusal and maps to a
  4xx; anything else is a 500.
- **A jose error is never attached as `cause` and never logged.** jose's claim errors carry
  the token's full claim set as `payload`, `oid` included, and a logged chain writes it into
  the line. Log `e.code`, `e.claim` and the `kid`.
- A key-endpoint failure surfaces as a `TypeError` when the host is unreachable, or as a
  `JOSEError` with code `ERR_JOSE_GENERIC`, `ERR_JWKS_INVALID` or `ERR_JWKS_TIMEOUT`. A catch
  that narrows on `errors.JOSEError` alone sends an outage down the token-fault path, so jose
  errors are classified by `code`. The status each returns is fixed by a test.

## The agent

- One compiled agent per process. `createAgent` is synchronous and is called once, inside
  the getter that owns it; the request that triggers a second compilation pays for it.
- The chat model is `new AzureChatOpenAI({...})` with **every Azure field passed
  explicitly** — endpoint, deployment, API version, `maxRetries`, authentication, and `model`
  set to the deployed model's name. An omitted field falls back to `process.env` without a
  word. `model` defaults to `gpt-3.5-turbo`, and it decides the model's profile.
  `temperature: 0` is a constructor field too: a per-call `modelSettings.temperature` never
  reaches the wire (truth §17.2).
- **Structured output is declared `responseFormat: providerStrategy(schema)`, explicitly.** A
  bare schema leaves the strategy to `model.profile`, and a deployment alias with no profile
  selects `ToolStrategy`: the schema is then enforced by a client-side retry loop instead of
  by the provider. Nothing raises when that happens — the agent still returns an object — so
  the enforcement the design rests on is lost in silence. The parsed object is
  `result.structuredResponse`.
- **Per-request values are bound in `wrapModelCall`** — `handler({ ...request, systemPrompt,
  messages, responseFormat })`. The agent compiles with no schema and no system prompt; both
  are per request (truth §17.1).
- ⚠️ **Under a `responseFormat`, `handler` returns `{ structuredResponse, messages }`**, whatever
  its declared `AIMessage` type says; the `AIMessage` is `messages.at(-1)`. A `Command` that
  writes state from `wrapModelCall` copies `structuredResponse` into its update, or the parsed
  output is lost without an error (truth §17.2).
- **`wrapModelCall` catches every failure thrown inside `handler`** — a schema violation, a
  content filter, an exhausted retry — and returns a `Command` carrying the reason code.
  Uncaught, `invoke` rejects and `afterAgent` never writes the audit row (truth §17.5).
- The system prompt is `systemPrompt`. A zod field's `.describe()` text is the only
  per-field instruction the model receives. It is specification, not documentation, and the
  prompt does not repeat it.
- **A tool's `description` and its schema's `.describe()` texts are its API.** They go to the
  model verbatim; the prompt does not repeat them.

## Tests

- `node:test` with `node:assert/strict`. `npm test` runs `node --import tsx/esm --import
  ./tests/unit/no-network.ts --test "tests/unit/**/*.test.ts"`; `npm run test:integration`
  runs the integration glob with no preload. The glob is always quoted and always given: a
  bare `node --test` also collects `tests/integration`, and a directory argument fails.
- **The unit suite runs with the network blocked.** `tests/unit/no-network.ts` patches
  `net.Socket.prototype.connect`, `tls`, `dns`, `http`, `https` and `fetch`, calls
  `syncBuiltinESMExports()` so named imports see the patch, and sets exit code 99 on any
  attempt. `node --test` loads it into every test file's process, and a file whose process
  exits 99 fails the run, so a library that swallows the error still fails. Prototype methods
  are patched; classes are never replaced. `--permission` does not gate the network and is no
  substitute.
- **The unit import proof.** A child process started with `env: {}` and the
  `tests/unit/no-spawn.ts` preload imports every `.ts` under `src/core`, `src/conversations`,
  `src/chat` and `src/pacehr`, and exits 0 with empty stderr, with no lazy member built.
  `no-spawn.ts` is the network block plus `child_process`, which `DefaultAzureCredential`
  spawns. The suite itself cannot block `child_process`, because the tests that need a fresh
  process spawn one.
- An ES module namespace is read-only, so no test replaces a module's export. A test seeds
  an instance member, or stubs with `t.mock.fn` and `t.mock.method`. No `mock.module`: it
  needs an experimental flag.
- **One environment per test file.** Each file runs in its own process, so each starts with
  an empty `settings()` memo. `useTestEnv(overrides)` from `tests/unit/env.ts` sets every
  name before the first `settings()` call, `''` for the names a test does not use, so a
  developer's `.env.local` can neither fill a gap nor flip a test onto another branch. A
  second branch is a second file. Never assign `undefined` to `process.env`; it stores the
  string `"undefined"`.
- The LLM test clears the `AZURE_OPENAI_*` variables that share our names after its first
  `settings()` call, then reads the real client's fields, so a field the code forgot to pass
  cannot be filled from the environment.
- An HTTP-level test runs `Reflect.deleteProperty(llmManager, 'azureOpenaiGpt41Llm')`, stubs
  `globalThis.fetch` with `t.mock.method`, and asserts the captured request. The openai
  client keeps the `fetch` it saw on its first invoke, so a model built under an earlier
  test's stub keeps calling that stale stub; deleting the member rebuilds it. Each fake
  completion carries a unique `id`; the message reducer merges by id.
- An integration test computes its skip reason once, catching every failure, and passes
  `{ skip: reason }` to each test. A skipped `describe` reports zero tests.
- **Tests assert behaviour, not shape.** A test that parses source to check where an instance
  is declared breaks on every refactor that keeps the behaviour. Shape belongs in review.
- **The two guards are lint rules run inside `npm test`.** `eslint.config.js` holds the guard
  rules and nothing else: `process.env`, `process.loadEnvFile`, `globalThis.process` and any
  import of `node:process` outside `src/core/settings.ts` and `tests/unit/env.ts`; the
  log-call rules above; the tagged-template `query`; `@typescript-eslint/no-explicit-any`.
  `tests/unit/source-rules.test.ts` lints the tree and a set of planted violations and
  asserts each one's file and line. A guard change ships with the planted violation that
  proves it fires.

## Clinical and PHI rules

- **Identifiers are masked before egress and restored after.** The token map is
  request-scoped state, **never a module singleton** — a singleton leaks identifiers across
  concurrent requests. This is the one place the pattern above is forbidden.
- **Log the token, never the value.** No clinical value reaches a log line, a trace attribute
  or an error message.
- **Validators are plain TypeScript in a middleware hook, never tools.** A tool the model may
  decline to call cannot prove a check ran.
- **Any guard failure ends the run before a model call. Fail closed.** A guard is declared
  `beforeAgent: { canJumpTo: ['end'], hook }` and blocks by returning `{ jumpTo: 'end' }`.
  **Never from `beforeModel`**: in `langchain` 1.5.14 its `end` skips `afterAgent`, measured
  (truth §17.3). A per-call check lives at the top of `wrapModelCall` and short-circuits with
  a `Command`, which does reach `afterAgent`.
  **A guard never throws.** A jump still runs `afterAgent`, so the audit row is written on
  the way out; a throw rejects `invoke`, skips `afterAgent`, and destroys the audit row for
  exactly the runs most worth auditing. Both were measured: jump, 0 model calls and
  `afterAgent` ran; throw, 0 model calls and `afterAgent` did not run.
- **Confidence is the band `HIGH`, `MEDIUM` or `LOW`.** Never a number — a self-reported
  probability is not a calibrated measurement, and a number invites arithmetic that means
  nothing.
- **Preserve the live database's own spelling, including its inconsistencies** — `templetID`,
  `fieldID`, `sectionID`, in SQL and as row keys. Retro-fitting conventions onto existing SQL
  is forbidden; a column is named what it is named.

## Review

A change is checked for correctness first, then for whether the code needed to exist.

The ladder — stop at the first rung that holds, after tracing the flow end to end:

1. **Does this need to exist?** Speculative need is skipped, in one line.
2. **Already in this codebase?** Reuse the helper, type or pattern that lives here.
3. **Node's standard library does it?** Use it.
4. **A platform feature?** A database constraint over app code, a driver setting over a
   wrapper.
5. **An installed dependency?** Use it. Never add one for what a few lines do.
6. **One line?** One line.
7. **Only then:** the minimum that works.

| Tag | Means |
| --- | --- |
| `delete:` | Dead code, unused flexibility, speculative feature. Replacement: nothing. |
| `stdlib:` | Hand-rolled thing Node ships. Name the function. |
| `native:` | Code doing what the platform or driver already does. Name the feature. |
| `yagni:` | Abstraction with one implementation, config nobody sets, layer with one caller. |
| `shrink:` | Same logic, fewer lines. Show the shorter form. |

Format: `<file>:L<line>: <tag> <what to cut>. <replacement>.`

Hunt: single-implementation interfaces, factories with one product, wrappers that only
delegate, barrels, dead flags, hand-rolled built-ins, a function that exists to call one
other function.

Never cut:

- **Input validation at a trust boundary.** `src/core/auth.ts` is one.
- **The two guards** — the `process.env` rule and the log-call rule — and their planted
  violations.
- **Error handling that prevents data loss**, and anything the ticket explicitly asked for.
- **The one runnable check** behind non-trivial logic. A smoke test is the minimum, not bloat.
