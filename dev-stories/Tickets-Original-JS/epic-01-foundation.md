# Epic 1 — Repository foundation and core singletons

## Part 1 — Tickets (copy-paste)

### Epic
**Title:** Set up the repository foundation and shared core services

**Description:** This epic creates the Node.js/TypeScript repository for the PacEHR encounter agent, with locked dependencies, a Node version floor and separate unit, integration and manual test tiers. It builds the shared core services every later epic uses: configuration, Azure SQL access, the Azure OpenAI GPT-4.1 client, error types, structured logging, Entra ID token validation and local health endpoints. Each service is one shared instance per process and is built only on first use. Because of this, the whole codebase can be imported with no credentials and no network. The unit test suite runs offline and fails on any network call. When the epic is done, a developer can clone the repository, run `npm ci`, `npm test` and `npm start`, and see from `/health/ready` whether their machine reaches Azure SQL and the model.

### PEA-101
**Title:** Scaffold the repository, pin dependencies and set the Node 22.13 floor

**Description:**
As a platform engineer, I want a ready-to-use TypeScript repository with locked dependencies and a Node version floor, so that every developer and pipeline installs the same packages and later epics start from a known shape.

Every later epic builds on this repository layout. A wrong dependency pin or Node floor shows up much later and is hard to trace back. The unit tests must run with no credentials and no network, so they are safe on any machine and in CI.

**Scope**
- in: folder layout under `src/` and `tests/`, `package.json` and the committed `package-lock.json`, TypeScript and build configuration, the ESLint guard configuration, the unit-test network block, the whole-tree import check, `.gitignore`, a README that gives the reason for each dependency.
- out: feature code (Epics 2–12), the Azure Functions entrypoint and the pipeline (Epic 11), the contents of the chat product's folders.

**Acceptance criteria**
- `npm ci` installs from the committed lock file and needs no credentials.
- `package.json` declares ES modules, `private: true` and `engines.node` `>=22.13` with no upper limit. A unit test checks the value and that the running Node meets it.
- `npm test` first runs the TypeScript type check (`tsc --noEmit`) and then only `tests/unit`. `npm run test:integration` runs only `tests/integration`. Neither collects `tests/manual`.
- Every `.ts` file under the source folders (all of `src/` except the `src/server.ts` entrypoint) imports in a child process with an empty environment, with network and child processes blocked. The child exits 0 with no output, and none of the shared clients is built.
- Any network call in a unit test fails the run with exit code 99, even when the test catches and ignores the error.
- No AWS SDK package is installed: `node_modules` has no `@aws-sdk` and no `@smithy` folder.
- `npx eslint .` reports nothing on the tree.
- `npm run build` compiles `src/` to `dist/` and rewrites the `#` import aliases. It emits nothing if there is a type error.

**Technical notes**
- Key files: `package.json`, `package-lock.json`, `tsconfig.json`, `tsconfig.build.json`, `eslint.config.js`, `tests/unit/no-network.ts`, `tests/unit/no-spawn.ts`, `tests/unit/repo.test.ts`.
- Folders: `src/core` (this epic), `src/conversations` and `src/chat` (one README each, kept for the sibling chat product), and the feature folders that later epics add (`src/agents`, `src/guards`, `src/schema`, `src/services` and others). Cross-folder imports use aliases such as `#core/*`. There are no barrel files.
- Runtime dependencies: `langchain`, `@langchain/core`, `@langchain/openai`, `@langchain/langgraph`, `openai`, `@azure/identity`, `mssql`, `zod`, `jose`, `pino`. Ranges are carets, and the lock file is the pin.
- Tests use Node's built-in `node:test`, so there is no test framework dependency. `tsx` runs the TypeScript source.
- `eslint.config.js` holds guard rules only: environment reads, log-call shape, SQL built at the call site, and no explicit `any`.

---

### PEA-102
**Title:** Build one validated settings source for all configuration

**Description:**
As a platform engineer, I want one module to read and validate all configuration, so that no environment-specific value is hard-coded and a misconfiguration fails early with a clear message.

Endpoints, server names and tenant ids differ by environment. Some Azure and LangChain libraries also read environment variables on their own. A few of those variables change where data is sent, for example tracing to a non-Azure host. One validated source, backed by a lint rule, keeps all of this in one place.

**Scope**
- in: `src/core/settings.ts`, `.env.example`, reading `.env.local` for local development, the lint rule that bars environment reads anywhere else, the `useTestEnv` test helper.
- out: Key Vault and deployed app settings (Epic 11), settings for later features (added by the story that needs them).

**Acceptance criteria**
- Only `src/core/settings.ts` and the test helper `tests/unit/env.ts` may read `process.env`. ESLint reports any other read at its file and line, and a unit test proves this with planted examples.
- Importing the module reads nothing. The first `settings()` call validates and returns a frozen object with camelCase fields, and every later call returns that same object.
- There are seven required names: `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_VERSION`, `AZURE_OPENAI_GPT_4_1_DEPLOYMENT`, `AZURE_SQL_SERVER`, `AZURE_SQL_DATABASE`, `ENTRA_TENANT_ID`, `ENTRA_AUDIENCE`. The optional names are `AZURE_OPENAI_API_KEY`, `AZURE_CLIENT_ID`, `AZURE_SQL_USER`, `AZURE_SQL_PASSWORD`, `LOG_LEVEL` (default `info`) and `PORT` (default 3000).
- A missing or invalid value throws one plain error that names every bad variable and never includes a value.
- Values are trimmed. An empty value counts as unset, and a value that is only whitespace is an error. The endpoint loses a trailing slash, and `LOG_LEVEL` is lower-cased. `AZURE_SQL_USER` and `AZURE_SQL_PASSWORD` must be set together or not at all.
- `.env.local` fills gaps for local development, and the real environment wins. Unknown keys are ignored and never copied into `process.env`. A missing file is fine, and any other read error fails.
- `settings()` fails when any of six variables is set to a non-blank value in the real environment, because each one redirects or leaks library traffic: `AZURE_OPENAI_BASE_PATH`, `LANGSMITH_TRACING`, `LANGSMITH_TRACING_V2`, `LANGCHAIN_TRACING`, `LANGCHAIN_TRACING_V2`, `LANGCHAIN_VERBOSE`.
- `.env.example` lists every setting with a placeholder and a one-line comment.

**Technical notes**
- One zod schema declares every setting. The required and optional lists are derived from it, so a new setting is one schema entry.
- `.env.local` is parsed with Node's `util.parseEnv` from a path relative to the module. It is never loaded into `process.env`, so libraries cannot pick up its values.
- Error messages carry variable names only, never values, because a value may be the API key. A configuration error is a plain `Error` (a 500), never a `PacEHRError`.
- Each test scenario runs in its own child process against a copy of the module, so a developer's own `.env.local` cannot affect the result.

---

### PEA-103
**Title:** Build the shared Azure SQL connection pool and query method

**Description:**
As a platform engineer, I want one shared Azure SQL connection pool with a single query method, so that every feature reaches the database the same way and pays the connection cost once.

Patient history and note retrieval are moving server-side. Each extra pool means another TLS handshake and Entra login under load, and no test would catch it. The driver's error events must never crash the process.

**Scope**
- in: `src/core/database.ts`, the `database` singleton, `database.execute(sql, params)`, managed-identity and local SQL-login authentication, the lint rule against SQL built at the call site, unit and live tests.
- out: the AI schema tables and their queries (Epic 2), closing the pool on the Functions host (Epic 11), pool tuning.

**Acceptance criteria**
- Importing the module opens no connection. The pool is built on first use and reused for the life of the process.
- `database.execute(statement, params)` binds every parameter server-side as `@name` and returns the rows keyed by column name. A test shows that an injection-style value is passed as data and that the statement is unchanged.
- Authentication has three branches: managed identity with the configured client id, the system-assigned identity when no client id is set, and a SQL login when both local SQL names are set. Each branch has its own test.
- The pool uses encryption, a 10-second request timeout and the driver's default connection retries.
- Twelve concurrent first calls make one connection attempt and all get the same error. A later call tries again, so the failure is not cached.
- A pool error event does not stop the process. It logs one line with the error code only, never the message text.
- ESLint rejects SQL built at the call site with a template literal or string concatenation.
- The live test runs a schema check against Azure SQL, once alone and twice in parallel. When the database cannot be reached, it reports skipped with the reason.

**Technical notes**
- Key file: `src/core/database.ts`. Tests: `tests/unit/core/database.test.ts`, `database.system-identity.test.ts`, `database.sql-login.test.ts` and `tests/integration/core/database.test.ts`.
- `SCHEMA_EXISTS_SQL` is exported for the tests and the readiness check.
- The pool is closed by `src/server.ts` on shutdown, never by core code.
- The SQL login is for local development only. The password lives only in the git-ignored `.env.local` and is never logged.
- The 10-second timeout is not yet measured under load. Tune it from Epic 10 latency data.

---

### PEA-104
**Title:** Build the shared Azure OpenAI GPT-4.1 chat model client

**Description:**
As a platform engineer, I want one shared, lazily built Azure OpenAI GPT-4.1 client, so that the agent and any later model consumer get an authenticated, consistently configured model instead of building their own.

The service, not the browser, must decide which deployment answers, and only from configuration. The LangChain Azure client fills any field it is not given from environment variables, without warning. So a typo can silently read the wrong value. Building the client in one place, with every field passed, closes that gap.

**Scope**
- in: `src/core/llm.ts`, the `llmManager` singleton, managed-identity token authentication with an API-key fallback for local development, model settings (temperature, retries, output cap, request timeout), unit and live tests.
- out: the agent and structured output (Epic 4), tuning retries and timeouts from production data (Epic 10).

**Acceptance criteria**
- Importing the module builds nothing. The model and its authentication are built on first use and then reused.
- Endpoint, deployment and API version come only from settings. A test plants wrong look-alike environment variables and shows that the request still goes to the configured URL.
- Without an API key, requests carry a managed-identity Bearer token and no `api-key` header. With a key (local development), they carry the `api-key` header and no Bearer token.
- Every request sends model `gpt-4.1`, temperature 0 and `max_tokens` 16,384. The client retries twice, and each attempt times out after 300 seconds.
- Twelve concurrent first calls fetch one token. A failed token request is retried by the model and is not cached.
- The first build logs one line with the deployment and the endpoint, and never the key.
- The live test sends one prompt and checks for a text reply and a token count. When no token can be acquired, or the network is refused with HTTP 403, it reports skipped with the reason.

**Technical notes**
- Key file: `src/core/llm.ts`. Tests: `tests/unit/core/llm.test.ts`, `tests/unit/core/llm.api-key.test.ts` and `tests/integration/core/llm.test.ts`.
- Every Azure field is passed explicitly. `npm run typecheck` catches a misspelled field.
- Temperature is set on the client because a per-call temperature does not reach the API.
- The API key is a local-development fallback and is never logged. Deployed code uses managed identity.
- The Azure OpenAI resource currently refuses calls from outside its network (HTTP 403). Until that is opened, the live test skips and readiness reports the model as unavailable from developer machines.

---

### PEA-105
**Title:** Define user-facing error messages and PHI-safe structured logging

**Description:**
As a compliance officer, I want every user-facing error message defined once and every log line written as structured fields, so that users see consistent wording and no clinical value leaks into a log through a careless message.

Today the error a clinician sees depends on which call failed. One base error class lets the request boundary tell a refusal (4xx) from a fault (500). Logging is the easiest place to leak patient data, so a lint rule makes fields-first logging the only shape that passes.

**Scope**
- in: `src/core/errors.ts` (`PacEHRError`, `AuthenticationError`, `AUTHENTICATION_FAILED_MESSAGE`), `src/core/logging.ts` (one pino root logger), the log-call lint rule.
- out: PHI masking and redaction rules (Epic 5), mapping errors to HTTP statuses on the extraction endpoints (Epic 9), export to Application Insights (Epic 10).

**Acceptance criteria**
- `PacEHRError` is the base class for refusals. `AuthenticationError` extends it, is named `AuthenticationError`, and carries the constant message "Authentication failed." with no attached cause.
- Errors that are not refusals, such as a configuration error or a key-endpoint outage, are not `PacEHRError` instances, so they map to a 500.
- ESLint rejects a log call with more than two arguments, or whose last argument is not a non-empty string literal (a template literal, a concatenation, a variable, a lone object or an empty string). A unit test plants each form and checks the file and line.
- Fields-first calls with a literal message pass, for example `log.warn({ cause, kid }, 'bearer token rejected')`.
- Importing the logger writes nothing.
- Each log call writes one JSON line with the fields as top-level keys. Child loggers follow the root level.

**Technical notes**
- Key files: `src/core/errors.ts`, `src/core/logging.ts`, `eslint.config.js`. Tests: `tests/unit/core/logging.test.ts`, `tests/unit/source-rules.test.ts`, and the refusal checks in `tests/unit/core/auth.test.ts`.
- Each module logs through `logger.child({ module: 'core.x' })`. `src/server.ts` sets the level from `LOG_LEVEL`. Errors are logged under the `err` key.
- A token-library (jose) error is never attached as a cause and never logged, because it carries the token's claims.
- Logging writes synchronously to stdout. Switch to an async destination if a slow pipe is ever measured.
- This story provides the mechanism. Epic 5 proves that no clinical value reaches a log.

---

### PEA-106
**Title:** Validate Entra ID bearer tokens and return the caller's object id

**Description:**
As a platform engineer, I want every inbound bearer token checked against our Entra ID tenant's signing keys and reduced to the caller's object id, so that every action can be traced to a verified identity.

The service sits behind a .NET proxy that has its own authentication. This service still has to verify who is calling it, because audit rows are only as trustworthy as that identity. An identity-provider outage must not look like the caller's fault.

**Scope**
- in: `src/core/auth.ts`, `entraAuthenticator.authenticate(token)`, telling token faults apart from key-endpoint outages, unit tests with locally signed tokens.
- out: wiring into HTTP endpoints and the 401/500 mapping (Epic 9), multi-tenant tokens, carrying the clinician's identity separately from the proxy's (Epic 9).

**Acceptance criteria**
- A valid RS256 token with the configured audience, the single-tenant v2.0 issuer, a current expiry and an `oid` claim resolves to that `oid`.
- These tokens are each rejected with `AuthenticationError("Authentication failed.")`: expired, unknown key id, wrong signature, wrong audience, wrong tenant, HS256, missing `oid`, and malformed.
- Each rejection logs one warning with only the error code, the name of the failed claim and the key id. It never logs the token, a claim value, the issuer or the audience.
- An unreachable or failing key endpoint (network error, non-200 answer, invalid key set) is rethrown unchanged and not as a refusal, and nothing is logged. A boundary therefore answers 500, not 401.
- Importing the module fetches nothing. The key-set URL is built from the configured tenant.
- Twelve concurrent first requests share one key fetch, and later requests use the cached keys.

**Technical notes**
- Key file: `src/core/auth.ts`. Tests: `tests/unit/core/auth.test.ts`, which reach no Entra tenant.
- Uses jose with its default key cache (10 minutes), cooldown (30 seconds) and fetch timeout (5 seconds).
- Only RS256 is allowed, which blocks an algorithm downgrade.
- For the .NET proxy's own app token, `oid` is the proxy's service principal, not a clinician. A delegated token carries `oid` only when the client requested the `profile` scope.
- A key-endpoint timeout takes the same path as the other outages but is not unit-tested, because it costs 5 seconds.

---

### PEA-107
**Title:** Serve local health and readiness endpoints for Azure SQL and the model

**Description:**
As a developer, I want `npm start` to serve liveness and readiness endpoints, so that one request tells me whether my machine reaches Azure SQL and the model before any agent code runs.

The database and model clients are built only when first used. Without a readiness check, a bad `.env.local` or a firewall rule would show up much later and look like an agent bug. The first live run proved this: the database answered, and the model returned HTTP 403 from the network firewall.

**Scope**
- in: `src/core/app.ts` (routing and a plain `node:http` server), `src/server.ts` (local entrypoint: log level, port, graceful shutdown).
- out: the deployed health probe and the Azure Functions host (Epic 11), authentication on these routes, the extraction endpoints (Epic 9).

**Acceptance criteria**
- `GET /health` returns 200 with `{ "status": "ok" }` and touches no dependency.
- `GET /health/ready` checks Azure SQL and the model in parallel. It returns 200 only when both answer, and 503 otherwise.
- Each check reports `ok`, the time taken in ms and, on failure, a short reason code such as `HTTP 403`, `ELOGIN` or `TIMEOUT`. The body never contains the error text. The text goes to one server-side warning line, cut to 200 characters.
- Each check gives up after 15 seconds with reason `TIMEOUT`.
- An unknown path returns 404, a non-GET request returns 405, and a malformed URL such as `//` returns 400.
- An unexpected error inside the request handler returns 500 and does not stop the process.
- On SIGINT or SIGTERM the server closes the database pool (if it was opened), stops listening and exits 0.

**Technical notes**
- Key files: `src/core/app.ts`, `src/server.ts`. Tests in `tests/unit/core/app.test.ts` call the router directly, with no port opened.
- The port comes from settings (`PORT`, default 3000).
- Every readiness call is a billed model call. That is fine for a person checking locally, but wrong for a platform probe that polls every few seconds. Epic 11 decides the deployed probe.
- These routes have no authentication. They are local and return no data.
- The 15-second limit stops the wait but does not cancel the underlying call.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the original ticket | Open items |
| --- | --- | --- | --- | --- | --- | --- |
| PEA-101 | Done | 3 | — | `package.json`, `package-lock.json`, `tsconfig.json`, `tsconfig.build.json`, `eslint.config.js`, `tests/unit/no-network.ts`, `no-spawn.ts`, `js-to-ts.js`, `js-to-ts-hooks.js`; `tests/unit/repo.test.ts` (5 tests). Commit `98ef99e` (Jira AITP-46) in PR 12410; TypeScript toolchain in PR 12447 | Python/uv design replaced by Node/TypeScript (agreed port). The `pacehr/` scaffold was removed in PR 12607; the flat feature folders replaced it, and the import proof lists them. Working tree, not committed: `pretest` type-check gate; `tsconfig.build.json` paths reduced to one `#*` rule plus `noEmitOnError`; `@langchain/langgraph` and `openai` added to `package.json` (the committed lock already lists both as direct dependencies, so the committed `package.json` and lock disagree until this lands); `#templates/*` alias removed | README "Project structure" and the repo's `CLAUDE.md` folder schema still show `src/pacehr/`. `npm run build` not re-run in this review |
| PEA-102 | Done | 3 | PEA-101 | `src/core/settings.ts`, `.env.example`, `tests/unit/env.ts`; `tests/unit/core/settings.test.ts` (12 tests); environment guard in `eslint.config.js`, proven in `source-rules.test.ts`. Commit `28bdd0d` (AITP-47) in PR 12410 | pydantic `BaseSettings` replaced by one zod schema; `.env.local` is parsed, never loaded; unknown keys are stripped, not fatal. New in the port: `REFUSED` list, SQL-login pair, `PORT`. `LOG_LEVEL` is lower-cased (pino rejects `INFO`) | None |
| PEA-103 | Done | 5 | PEA-101, PEA-102 | `src/core/database.ts`; `tests/unit/core/database.test.ts` (4), `database.system-identity.test.ts` (1), `database.sql-login.test.ts` (1); `tests/integration/core/database.test.ts` (2 subtests); SQL guard in `eslint.config.js`. Commit `475a21a` (AITP-50) in PR 12410 | Per-call ODBC connect replaced by one `mssql` pool. ODBC MSI auth and retry values replaced by `azure-active-directory-default` and the driver's default retries. Local SQL-login fallback added | 10 s request timeout unmeasured (Epic 10). `ponytail:` note: tedious builds a new credential per physical login; switch to a shared `token-credential` if login latency is measured. Integration test not run in this review |
| PEA-104 | Done | 3 | PEA-101, PEA-102 | `src/core/llm.ts`; `tests/unit/core/llm.test.ts` (8), `llm.api-key.test.ts` (1); `tests/integration/core/llm.test.ts` (1 subtest). Commit `057b6cd` (AITP-54) in PR 12410; `temperature: 0` in PR 12548 (Epic 4, PEA-405) | Deployment is GPT-4.1, not GPT-5.5. Temperature moved from a per-request setting (Epic 4) to the constructor. Working tree, not committed: `maxTokens` 16,384 and a 300 s per-attempt `timeout` (the old ticket listed these as "later work, not Epic 1 scope"), with matching unit assertions; the live test now skips on HTTP 403 instead of failing | Azure OpenAI firewall returns 403 from outside its network, so the live check cannot pass from a developer machine. `MAX_RETRIES = 2` not load-tested (Epic 10). Structured-output check passed to Epic 4 |
| PEA-105 | Done | 3 | PEA-101 | `src/core/errors.ts`, `src/core/logging.ts`; log-call guard in `eslint.config.js`; `tests/unit/core/logging.test.ts` (1), `tests/unit/source-rules.test.ts` (7, shared with PEA-102/103), refusal checks in `auth.test.ts`. Commit `29e48a1` (AITP-59) in PR 12410 | `get_logger` / `configure_logging` and the AST f-string scan replaced by pino child loggers and an ESLint rule | Redaction paths and the "no clinical value in logs" proof belong to Epic 5. Application Insights correlation is an Epic 10 question |
| PEA-106 | Done | 5 | PEA-101, PEA-102, PEA-105 | `src/core/auth.ts`; `tests/unit/core/auth.test.ts` (15). Commit `0908288` (no Jira id) in PR 12410; PR 12447 fixed the `claim` read for jose 6 `JWTExpired` | PyJWT replaced by jose. Key-endpoint failures are now rethrown (500) instead of becoming 401. Missing `oid` is rejected by `requiredClaims` | Not wired to any endpoint yet (Epic 9). Key-endpoint timeout path untested. Where the clinician's identity comes from is Epic 9's decision |
| PEA-107 | Done | 2 | PEA-102, PEA-103, PEA-104, PEA-105 | `src/core/app.ts`, `src/server.ts`; `tests/unit/core/app.test.ts` (6). Commit `75cc067` (no Jira id) in PR 12410 | New in the Node port. Working tree, not committed: a malformed URL (`//`) now returns 400, and the request handler catches any rejection and returns 500. This closes the "known gap" the old ticket listed, where `//` crashed the local server | Manual DEV check (`npm start`, `curl` both routes, SIGTERM exits 0) not re-run. The 500 catch has no unit test. Readiness makes a billed model call on every hit (deployed probe is Epic 11) |

Total: 7 tickets, 24 points. Jira ids: PEA-101 AITP-46, PEA-102 AITP-47, PEA-103 AITP-50, PEA-104 AITP-54, PEA-105 AITP-59; PEA-106 and PEA-107 have none.

### Notes

**Test results (verified 2026-10-13, Node 24.18.0, npm 12.0.1)**
- `npm test`: the `pretest` type check (`tsc --noEmit`) passed, then 131 unit tests ran: 131 pass, 0 fail, 0 skipped, about 2.8 s.
- Epic 1's own unit files alone: 61 tests, all pass. Per file: `repo.test.ts` 5, `source-rules.test.ts` 7, `core/settings.test.ts` 12, `core/database.test.ts` 4, `core/database.system-identity.test.ts` 1, `core/database.sql-login.test.ts` 1, `core/llm.test.ts` 8, `core/llm.api-key.test.ts` 1, `core/logging.test.ts` 1, `core/auth.test.ts` 15, `core/app.test.ts` 6. The old file said 60. The extra test is the malformed-URL 400 test in `app.test.ts`.
- `npx eslint .`: clean.
- `npm run test:integration` was not run. It reaches live Azure SQL and makes a billed model call, and the model is behind the 403 firewall.

**Hardening done after the original merge**
- Request timeout: `REQUEST_TIMEOUT_MS = 300_000` per model attempt in `src/core/llm.ts` (working tree).
- Output cap: `MAX_OUTPUT_TOKENS = 16_384`, sent as `max_tokens` (working tree).
- Malformed URL returns 400, and the server handler returns 500 instead of crashing (working tree).
- Type-check gate: `pretest` runs `tsc --noEmit` before every `npm test` (working tree).
- `temperature: 0` on the model client (merged, PR 12548).
- `tsconfig.build.json` uses `noEmitOnError` and one `#*` path rule (working tree).

**Merged vs working tree** (`git log` / `git status` in `PacEHR_AI`, branch `PacEHR-AI-Develop-Main`, HEAD `ee9c990` "Merged PR 12607", 2026-10-07)
- Merged: the seven Epic 1 commits `98ef99e`..`75cc067` (PR 12410, merge `29d7fa6`), the TypeScript conversion `41c0c9b` (PR 12447, merge `e86c54e`), `temperature: 0` in `84ef706` (PR 12548, merge `5382f95`), and the removal of `src/pacehr/` in `4a28681` (PR 12607).
- Not committed, in Epic 1 files: `src/core/llm.ts`, `src/core/app.ts`, `package.json`, `tsconfig.build.json`, `.gitignore` (adds `logs/`), `tests/unit/core/llm.test.ts`, `tests/unit/core/app.test.ts`, `tests/unit/repo.test.ts` (drops `src/templates` from the import proof), `tests/integration/core/llm.test.ts`.
- Also uncommitted but outside Epic 1: a `Dockerfile` and `.dockerignore` for a demo image of the manual stream server, plus Epic 3/4/5 work in `src/agents`, `src/guards`, `src/schema` and others.

**Other notes**
- The epic-level dependency stands: every call to the Azure OpenAI deployment has returned `403 Access denied due to Virtual Network/Firewall rules` since 2026-09-29. The unit tests do not need it.
- The lock file still names `@aws-sdk/credential-provider-node`, `@smithy/hash-node` and `@smithy/signature-v4` as optional peers of `openai` 7.23.0. None is installed. This is accepted pending the user's confirmation (truth §16 #1).
- Lock file resolves (lockfile v3): `langchain` 1.5.14, `@langchain/core` 1.2.13, `@langchain/openai` 1.6.0, `@langchain/langgraph` 1.4.18, `openai` 7.23.0, `@azure/identity` 4.13.3, `mssql` 12.7.2 over `tedious` 20.0.0, `zod` 4.6.5, `jose` 6.2.12, `pino` 10.3.1; dev: `typescript` 5.9.3, `tsx` 4.23.15, `tsc-alias` 1.9.7, `eslint` 10.11.0, `@typescript-eslint/*` 8.71.0, `@types/node` 24.19.0, `@types/mssql` 12.3.0.
- The previous edition (Gherkin scenarios, the "What changed from the Python edition" table and the truth-file references) is kept at `/private/tmp/claude-503/-Users-akash-saxena-saisystem-projects/cbc72f0a-9422-4b3e-8c9f-b371e66b4d7a/scratchpad/tickets-backup/epic-01-foundation.before-2026-10-13.md`. The library facts behind this epic are cited there and in `00-langchainjs-api-truth.md`.
