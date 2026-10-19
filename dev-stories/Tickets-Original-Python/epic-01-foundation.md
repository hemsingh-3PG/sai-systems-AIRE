# Epic 1 — Repository Foundation & Core Singletons

**Epic id:** E1 · **Phase:** 1 · **Stories:** PEA-101..PEA-106 · **Points:** 22

## Goal

Today none of this exists: no repository, no pinned dependencies, no way to configure
the service, reach Azure SQL, call Azure OpenAI, log without leaking a clinical value,
or verify who is calling. When this epic is done, a developer can clone the
repository, run `uv sync`, import every package with no environment variable set and
no network reachable, and run the unit test suite green — and the six singletons every
other epic imports (`settings`, `database`, `llm_manager`, the error and logging
primitives, `entra_authenticator`) already exist, each built exactly once per process,
each seedable by a test without touching Azure.

## Scope

**In:** the repository scaffold and folder schema; the pinned dependency manifest and
the Python version floor; `core/settings.py`; `core/database.py`; `core/llm.py`;
`core/errors.py` and `core/logging.py`; `core/auth.py`.

**Out:**
- The `AI` schema tables and every query against them — Epic 2 (data layer).
- Dynamic Pydantic schema generation from template configuration — Epic 3.
- `create_agent`, the middleware spine, and the compiled agent itself — Epic 4 (agent
  core). This epic hands Epic 4 an authenticated chat model; it does not assemble an
  agent around it.
- PHI masking, the token map, and prompt-injection scanning — Epic 5 (guardrails).
- Deterministic field validation — Epic 6.
- Agent tools (`resolve_date`, `compute_bmi`, `lookup_icd_cpt`, the context-loading
  tools) — Epic 7.
- Prompt fragment storage and versioning — Epic 8.
- The HTTP surface itself (`POST /ai/encounter/extract`, `POST /ai/encounter/resolve`),
  `after_agent`, and review persistence — Epic 9 (review + API surface).
- OpenTelemetry tracing, Azure Monitor export, dashboards, and the evaluation harness
  — Epic 10 (observability).
- The Azure Function host, Key Vault and Managed Identity *infrastructure*
  provisioning, the build/release pipeline, and shadow-mode rollout — Epic 11 (Azure
  deployment). This epic only establishes that application code authenticates with
  managed identity; it does not provision anything.
- The memory layer tables and logic — Epic 12 (Phase 2).
- `core/app_factory`, `core/knowledge_base`, `core/documents`, `core/task_dispatch` and
  `core/shared_tools` — named in `CLAUDE.md`'s folder schema as eventual contents of
  `core/`, but no Phase 1 story in this backlog populates them. They are created by
  whichever epic first needs them (most plausibly Epic 9 for the process entrypoint
  and Epic 7 for tool-shared plumbing), into the folder this epic already scaffolds.
  This epic does not pre-create empty files for them — an empty file nobody's story
  claims is invention, not foundation.

## Dependencies

None. Epic 1 is the first epic; every other epic (2 through 12) depends on it, and it
depends on nothing built elsewhere in this backlog.

---

### PEA-101 — Scaffold the repository, pin dependencies, and lock the Python floor

**Type:** Story · **Epic:** E1 · **Phase:** 1 · **Points:** 3
**Depends on:** none · **Satisfies:** REQ-01-01

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want the repository scaffolded to the folder schema with
every dependency pinned and its reason recorded, so that I can clone the repository,
run `uv sync`, import every package with no credentials configured, and hand the other
eleven epics a tree that already matches the shape they were written against.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The service does not exist yet — the clinician's note is still assembled into a prompt
by nine sequential browser calls with no server-side checking at all. Every other epic
in this backlog was written against a repository shape this story is the first to
actually create: the `core/`, `conversations/`, `chat/` and `pacehr/` folders
`CLAUDE.md` specifies, a dependency manifest that names LangChain and Azure OpenAI as
the stack (`REQ-01-01`), and a test suite a developer can run before a single feature
line exists. `conversations/` and `chat/` belong to the sibling chat product this
repository will eventually also host; this story scaffolds them empty and populates
neither, so that product's team finds the folder waiting rather than colliding with
it. Getting the dependency floor wrong here is expensive precisely because nobody
notices for a while: a floor too low to carry a capability a later epic assumes, or a
resolver conflict eleven epics deep, both trace back to a pin made — or not made —
in this one story.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A fresh clone imports the whole tree with no credentials
  Given a fresh clone with no ".env.local" file and no environment variables set
    And network access is blocked for the duration of the test
   When "uv sync" completes and "python -c \"import core, conversations, chat, pacehr\"" runs
   Then the import succeeds with no exception
    And no socket connection is attempted

Scenario: conversations/ and chat/ are scaffolded but not populated
  Given the scaffolded repository
   When "conversations/" and "chat/" are inspected
   Then each package contains exactly one file, "__init__.py"
    And that file holds a module docstring and no executable statement

Scenario: The locked environment is the reviewed environment
  Given "pyproject.toml" and "uv.lock" committed to the repository
   When a developer runs "uv sync --locked"
   Then the command succeeds
    And the resulting environment contains no package absent from "uv.lock"

Scenario: Test directories are classified by location, not by decorator
  Given placeholder tests committed under "tests/unit", "tests/integration" and "tests/manual"
   When "uv run pytest tests/unit" is invoked with no environment variables set
   Then collection and execution succeed with zero network calls
    And the placeholder under "tests/integration" is never reached by that invocation

Scenario: The construct-once idiom holds on every interpreter the floor admits
  Given a dummy class in "tests/unit/test_construct_once.py" whose "cached_property"
        re-reads "self.__dict__" under a module-level "threading.Lock" before building
   When twelve threads race the first access to that member, each incrementing a shared
        construction counter
   Then the counter reads exactly 1
    And all twelve threads observe the same object
    And the test is the tripwire for the idiom "PEA-104" and "PEA-106" build their
        expensive members with, run on whatever interpreter "requires-python" resolves to
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module paths: repository root (`pyproject.toml`, `uv.lock`, `.gitignore`); package
  markers `core/__init__.py`, `conversations/__init__.py`, `chat/__init__.py`,
  `pacehr/__init__.py`, `pacehr/agents/__init__.py`, `pacehr/tools/__init__.py`,
  `pacehr/prompts/__init__.py`, `tests/__init__.py`, `tests/unit/__init__.py`,
  `tests/integration/__init__.py`, `tests/manual/__init__.py` — every package named or
  implied by `CLAUDE.md` § Folder schema.
- **`requires-python = ">=3.10"` — a floor, with no upper bound.** 3.10 is the minimum
  the drivers themselves document: `mssql-python`, the Azure SQL driver `PEA-103` needs,
  is Python 3.10+ (`00-langchain-api-truth.md` §7). No ceiling is pinned — capping the
  project below 3.12 would forfeit 3.12 and 3.13 on Azure Functions for the life of the
  service.
- **`functools.cached_property` stopped serializing first access in Python 3.12.** It
  carried an undocumented per-property lock through 3.11; Python's own 3.12 changelog
  records the lock's removal for lock contention reasons, after which the getter "could
  run more than once on the same instance, with the latest run setting the cached value"
  (verified against `docs.python.org`'s `functools` page, 2026-09-23). `CLAUDE.md` §
  Singletons mandates `cached_property` for every expensive member, so on 3.12 and later
  two threads racing a cold member can each build one. What that costs is bounded and
  self-correcting: a cold start pays a few redundant handshakes, the losing object is
  dropped, and every later access reads the one cached value — it is not a duplicate that
  persists for the life of the process. So the fix is a `threading.Lock` on the two
  members where a duplicate build costs a network round trip — `PEA-104`'s chat model and
  `PEA-106`'s JWKS client, each specified in its own story — and not an interpreter
  ceiling every future epic would inherit. `PEA-103`'s only `cached_property` formats a
  string and takes no lock.
- `langchain>=1.1` — buys the model-profile-driven structured-output strategy
  selection Epic 4's `PEA-401` depends on (`00-langchain-api-truth.md` §4, `model.profile`;
  confirmed against `get_symbol` for `create_agent`'s `response_format` handling).
  `langchain-openai` has no verified minimum version in `00-langchain-api-truth.md`
  (§10, unverified #3); pin whatever `uv` resolves against the `langchain>=1.1` floor
  and record that resolved version in the pin's own comment rather than asserting an
  unverified number.
- `pydantic>=2.7,<3` and `pydantic-settings` — `2.7.0` is the floor `pydantic-settings`
  itself requires (`00-langchain-api-truth.md` §6).
- `mssql-python`, `pyjwt[crypto]`, `azure-identity` — the drivers `PEA-103`, `PEA-106`
  and `PEA-104` need respectively; each pin's comment names the story that consumes it.
- `pytest` and `pytest-asyncio` as dev dependencies — `pytest-asyncio` is what lets
  `PEA-103`'s non-blocking assertion be written at all.
- Security: `uv sync` pulls only from the configured package index; no credential is
  required to build the environment.
- Performance and API impact: none — this story ships no runtime behavior, only the
  substrate the other five stand on.
- UI/UX: none.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pyproject.toml` pins `requires-python = ">=3.10"` — a floor, no upper bound —
      with the comment naming `mssql-python`'s documented 3.10 minimum as its source
- [ ] Every dependency pin carries a one-line comment naming the capability or the
      story it buys, per `CLAUDE.md` § Numbers
- [ ] `uv.lock` committed; `uv sync --locked` succeeds
- [ ] Folder schema present with every listed `__init__.py`; `conversations/` and
      `chat/` contain nothing else
- [ ] `.gitignore` excludes `.env.local`, `.venv`, `__pycache__` and build artifacts;
      does **not** exclude `uv.lock`
- [ ] `tests/unit/test_repo_scaffold.py`: whole-tree import with environment cleared
      and network blocked
- [ ] `tests/unit/test_construct_once.py`: twelve-thread race against a dummy
      `cached_property` that re-reads `self.__dict__` under a `threading.Lock`, asserts
      exactly one construction
- [ ] A placeholder test exists in each of `tests/unit`, `tests/integration`,
      `tests/manual`
- [ ] Reviewed against `CLAUDE.md` § Folder schema, § Configuration and § Numbers

---

### PEA-102 — Build the single Settings source of configuration

**Type:** Story · **Epic:** E1 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-101 · **Satisfies:** REQ-01-03

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want exactly one `Settings` class as the sole reader of the
environment, so that every other module gets its configuration by calling `settings()`
and no deployment-specific value is ever hardcoded into source.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Every one of the other five stories in this epic — and most stories in the eleven
epics after it — needs a value that differs by environment: an Azure OpenAI endpoint, a
SQL server name, a tenant id. `REQ-01-03` requires the model provider and identity to
be read from configuration at call time and never hardcoded; the only way to make that
hold everywhere, rather than as a convention someone eventually breaks under deadline
pressure, is to make `os.environ` a code-review-visible anomaly anywhere but one file.
Today's browser-driven system has no equivalent single source — nine calls, nine
places a value could have been pasted in. This story is what makes `CLAUDE.md`'s
Configuration rule ("`os.environ` appears in that file and in no other") something a
test enforces rather than something a reviewer has to remember to check by eye.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Settings is the only module that reads the environment
  Given the scaffolded repository from PEA-101
   When every ".py" file under "core/", "conversations/", "chat/", "pacehr/" and "tests/"
        is searched for the strings "os.environ" or "os.getenv"
   Then the only match is inside "core/settings.py"

Scenario: Importing settings.py reads no environment
  Given no environment variables are set
   When "import core.settings" executes
   Then no exception is raised
    And "settings.cache_info().currsize" is 0 before "settings()" is ever called

Scenario: settings() is a cached function, not a module-level instance
  Given "core/settings.py" is inspected
   When its declaration of "settings" is read
   Then "settings" is a function decorated "@lru_cache(maxsize=1)" returning a
        "Settings" instance
    And no module-level "Settings()" instantiation exists anywhere in the file

Scenario: The same object is returned on every call
  Given "AZURE_OPENAI_ENDPOINT" is set to "https://pacehr-dev.openai.azure.com/"
   When "settings()" is called twice in the same process
   Then both calls return the identical object, checked with "is"
    And changing the environment variable between the two calls does not change what
        the second call returns

Scenario: A missing required field fails fast with a clear error
  Given "ENTRA_TENANT_ID" is unset and the field carries no default
   When "settings()" is called
   Then a "pydantic_core.ValidationError" is raised naming "entra_tenant_id"
    And the process fails at startup rather than at the first request that needed it

Scenario: .env.example documents every field; .env.local stays out of version control
  Given "core/settings.py" defines its full field set
   When ".env.example" is inspected
   Then every field with no default appears with a placeholder value and a one-line
        comment
    And ".env.local" is present in ".gitignore" and absent from the committed tree
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module path: `core/settings.py`. Base class `pydantic_settings.BaseSettings`
  (`00-langchain-api-truth.md` §6); `model_config = SettingsConfigDict(env_file=".env.local")`.
- At minimum, fields for: `azure_openai_endpoint`, `azure_openai_api_version`,
  `azure_openai_gpt_5_5_deployment`, `azure_openai_api_key: str | None = None`
  (local-development fallback only, per `CLAUDE.md` § Configuration),
  `azure_client_id: str | None = None` (user-assigned managed identity; `None` means
  system-assigned), `azure_sql_server`, `azure_sql_database`, `entra_tenant_id`,
  `entra_audience`, `log_level: str = "INFO"`. This list is a floor, not a ceiling —
  later epics add fields here rather than reading `os.environ` themselves.
- **Why `settings()` is a function under `@lru_cache(maxsize=1)` and not a
  module-level instance, when every other singleton in this epic is the reverse:**
  `CLAUDE.md` § Singletons carves out exactly this exception because `Settings`
  "returns one value and holds nothing" — in the worst case two threads race a cold
  cache and each build a `Settings()` instance, and both objects hold equivalent field
  values read from the same environment moments apart; neither holds a TLS handshake, a
  socket or a client. That is categorically different from `PEA-104`'s chat model and
  `PEA-106`'s JWKS client, where a duplicate build pays for a second handshake — which
  is why those two, and not this one, take an explicit construction lock. Module-level `x =
  Class()` for `Settings` would work too, but would have to run at import time, which
  is precisely what `core/settings.py`'s own import must not do.
- Real environment variables take precedence over `.env.local`, so the deployed path
  (Azure Function app settings, populated by Epic 11 from Key Vault) needs no file at
  all — `.env.local` is a local-development convenience, never the production
  configuration path.
- Security: `.env.local` never committed; a local API key is the only secret this file
  can hold, and it is never the deployed path.
- Performance: `lru_cache(maxsize=1)` is O(1) after the first call; no measurable cost.
- UI/UX and API impact: none directly — every later epic's config surface is additive
  to this one file.

#### 5. Definition of Done (DoD) Checklist
- [ ] `core/settings.py` defines `Settings(BaseSettings)` and `settings()` per the
      shape above
- [ ] Repo-wide grep test proves `os.environ`/`os.getenv` appear nowhere outside
      `core/settings.py`
- [ ] `tests/unit/test_settings.py`: import hygiene (`cache_info().currsize == 0`
      pre-call), identity across calls, missing-required-field `ValidationError`,
      cache not defeated by a later `monkeypatch.setenv`
- [ ] `.env.example` committed with every field and a placeholder; `.env.local`
      confirmed git-ignored
- [ ] No region, endpoint, deployment name or port literal outside a `Settings` field
      default anywhere in the tree (spot-checked by the same literal scan `PEA-104`
      automates)
- [ ] Reviewed against `CLAUDE.md` § Configuration and § Singletons

---

### PEA-103 — Build the database singleton and its async execution path

**Type:** Story · **Epic:** E1 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-101, PEA-102 · **Satisfies:** REQ-01-02

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want one module-level `database` singleton with a single
async execution path, so that every future story that reads or writes Azure SQL —
patient history, notes, and the `AI` schema tables Epic 2 defines — does so through one
connection convention instead of each writing its own driver code.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`REQ-01-02` requires that patient history and note retrieval move entirely server-side,
out of the nine calls the browser makes today. That is only true in practice if this
repository has one server-side way to reach Azure SQL. Without a single `database`
singleton, the tools Epic 7 writes (`load_patient_history`, `load_note_text`) and the
tables Epic 2 defines would each grow their own connection handling, and `CLAUDE.md`'s
measured cost of a second connection — paid silently, under load, with no test catching
it — would be paid once per caller instead of once per process. Azure SQL has no
native async driver from Python; this story is also where that fact gets resolved once,
in one file, instead of being independently rediscovered by whichever epic writes the
first query.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Importing database.py opens no connection and reads no environment
  Given no environment variables are set and network access is blocked
   When "import core.database" executes
   Then no exception is raised
    And "database.__dict__" contains no cached connection-string entry

Scenario: The connection string is built once from settings and reused
  Given "settings()" resolves "azure_sql_server" to "pacehr-dev.database.windows.net"
        and "azure_sql_database" to "PacEHR"
   When "database.aexecute" runs twice in the same process
   Then the connection-string "cached_property" is computed on the first call only
    And both calls use the identical cached string

Scenario: A test seeds the connection string directly
  Given "tests/unit/test_database.py" assigns "database.__dict__[\"connection_string\"]"
        to a stub value before any call
   When "database.aexecute" is exercised against a stubbed driver
   Then no real "settings()" fields or Azure SQL server are required

Scenario: aexecute binds parameters server-side, never by interpolation
  Given the module constant
        "_SCHEMA_EXISTS_SQL = \"SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ?\""
   When "database.aexecute(_SCHEMA_EXISTS_SQL, \"AI\")" is called against a stubbed cursor
        that records the exact statement and parameter tuple it receives
   Then the recorded statement text is unchanged from the constant
    And the recorded parameters are exactly ("AI",)

Scenario: aexecute is the only public entry point
  Given "core/database.py"
   When its public surface is inspected
   Then no synchronous "execute" method is exported
    And "aexecute" is implemented as "asyncio.to_thread" around a blocking call that
        opens its own connection per call via "mssql_python.connect", matching
        "00-langchain-api-truth.md" §7 exactly

Scenario: A blocking driver call does not stall the event loop
  Given a stubbed driver call that sleeps for 200ms inside the thread-offloaded function
   When "database.aexecute" is awaited concurrently with another coroutine that
        increments a counter every 10ms
   Then the counter has advanced at least once before "aexecute" returns
    And "tests/unit/test_database.py" proves the caller is never blocked
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module path: `core/database.py`. Class `Database`, no custom `__init__` — there is
  nothing a second instance would differ on, and the class docstring states so and
  opens with "Use the module-level `database`." The instance `database` is created on
  the module's last line, per `CLAUDE.md` § Singletons.
- `aexecute(sql: str, *params) -> list` is the only public entry point. It is
  `asyncio.to_thread` around a function that opens a connection per call with
  `mssql_python.connect(connection_string)`, builds a `mssql_python.Cursor`, and calls
  `cursor.execute(sql, *params)` then `cursor.fetchall()` — the verified pattern in
  `00-langchain-api-truth.md` §7. No connection is held open across calls: the
  reference pattern opens fresh per call rather than pooling, and no pooling
  behaviour is asserted here because none is verified.
- The connection string is a `cached_property` built once from `settings()` — cheap to
  rebuild (it is string formatting, not a handshake), cached for consistency with the
  singleton pattern and for the test-seeding convention in `CLAUDE.md` § Singletons,
  not because rebuilding it is expensive. **It therefore takes no construction lock**,
  unlike `PEA-104`'s chat model and `PEA-106`'s JWKS client: two threads racing it on a
  cold start would each format a string and one result would be dropped, which is not a
  cost worth serializing for. Managed-identity form:
  `"Server=<azure_sql_server>;Database=<azure_sql_database>;Authentication=ActiveDirectoryMsi;Encrypt=strict;ConnectRetryCount=3;ConnectRetryInterval=10;"`,
  with `UID=<azure_client_id>;` appended when `settings().azure_client_id` is set —
  exactly the format verified in `00-langchain-api-truth.md` §7. No server, database or
  client-id literal appears outside `Settings` field defaults.
- Every SQL statement is a `SCREAMING_SNAKE_SQL` module constant declared above
  `Database`, per `CLAUDE.md` § Naming. No statement is assembled at call time; no
  value reaches SQL by interpolation — parameters bind through the driver.
- **`aexecute` is `asyncio.to_thread`, not a native async driver, because none exists.**
  `mssql-python` is a synchronous PEP 249 driver; Microsoft's own documentation
  describes async support as thread-pool workarounds. Naming a synchronous `execute`
  beside `aexecute` would be a stalled event loop waiting for a caller to find it
  (`CLAUDE.md` § Naming) — it is deliberately not exported.
- Security: the managed-identity connection string carries no secret; the only credential
  path for Azure SQL in this story is `Authentication=ActiveDirectoryMsi`, resolved by
  the driver itself, not by an in-process `azure-identity` credential object.
- Performance: opening a connection per call has a per-call cost; no pooling
  optimization is in scope here, and none is claimed.
- UI/UX: none. API impact: this module has no HTTP surface of its own; Epic 9 exposes
  one.

#### 5. Definition of Done (DoD) Checklist
- [ ] `core/database.py` defines `Database` (no custom `__init__`) and the module-level
      instance `database` on the last line
- [ ] `aexecute(sql, *params)` implemented as `asyncio.to_thread` around a per-call
      `mssql_python.connect`; no synchronous `execute` exported
- [ ] Connection string is a `cached_property` sourced from `settings()`, seedable via
      `database.__dict__["connection_string"] = stub`; no construction lock — it formats
      a string, it opens nothing
- [ ] Every SQL statement is a `SCREAMING_SNAKE_SQL` module constant above `Database`;
      none built at call time
- [ ] `tests/unit/test_database.py`: import hygiene, cached-string reuse, stubbed
      parameter binding, non-blocking proof — all with no real Azure SQL reachable
- [ ] `tests/integration/test_database.py` exercises `aexecute` against a real Azure
      SQL instance (skipped without Azure credentials present)
- [ ] No SQL server hostname, database name or client id literal appears outside a
      `Settings` field default
- [ ] Reviewed against `CLAUDE.md` § Singletons and § Naming

---

### PEA-104 — Build the llm_manager singleton over Azure OpenAI

**Type:** Story · **Epic:** E1 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-101, PEA-102 · **Satisfies:** REQ-01-01, REQ-01-03

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want one `llm_manager` singleton exposing the Azure OpenAI
deployment as a named, lazily-built client, so that Epic 4's agent and any future model
consumer receive an already-authenticated client instead of each constructing and
authenticating its own.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The current system lets the browser choose among inference endpoints across its nine
calls. `REQ-01-01` and `REQ-01-03` together require that this Python service — not the
browser, not a value copied into a request — decide which Azure OpenAI deployment
answers, and that the decision come from configuration rather than a literal. Epic 4
assembles the actual agent and needs an already-authenticated, already-configured chat
model to hand `create_agent`; this story is what makes that hand-off a single attribute
access (`llm_manager.azure_openai_gpt_5_5_llm`) rather than every future caller
re-deriving credentials and deployment names for itself, each paying for its own TLS
handshake.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Importing llm.py builds no client and reads no environment
  Given no environment variables are set and network access is blocked
   When "import core.llm" executes
   Then no exception is raised
    And "llm_manager.__dict__" contains no "azure_openai_gpt_5_5_llm" entry

Scenario: A test seeds the client without a real Azure OpenAI deployment
  Given a stub chat model recording ".invoke" calls
   When the stub is assigned to "llm_manager.__dict__[\"azure_openai_gpt_5_5_llm\"]"
        before first access
   Then "llm_manager.azure_openai_gpt_5_5_llm" returns the stub
    And no "AzureChatOpenAI" instance or credential is constructed

Scenario: Managed identity is the default authentication path
  Given "settings().azure_openai_api_key" is unset
   When "llm_manager.azure_openai_gpt_5_5_llm" is built for the first time
   Then "AzureChatOpenAI" is constructed with "azure_ad_token_provider" from
        "get_bearer_token_provider" over a "DefaultAzureCredential"
    And no "api_key" argument is passed

Scenario: A local developer's key is honoured when present
  Given "settings().azure_openai_api_key" is set to a non-empty value
   When "llm_manager.azure_openai_gpt_5_5_llm" is built
   Then "AzureChatOpenAI" is constructed with "api_key" set
    And "azure_ad_token_provider" is not passed

Scenario: Deployment, endpoint and API version are never literals
  Given "core/llm.py"
   When the module source is inspected
   Then "azure_deployment", "azure_endpoint" and "api_version" are each assigned from a
        "settings()" attribute
    And no string literal for a deployment name, endpoint host or API version appears
        anywhere in the module

Scenario: The client is built exactly once under a concurrent first access
  Given twelve threads race the first access to "llm_manager.azure_openai_gpt_5_5_llm"
        on a process that has not yet built the client
   When all twelve have returned
   Then "AzureChatOpenAI" is constructed exactly once, confirmed by a call counter on
        the stubbed constructor
    And all twelve threads observe the same client instance
    And the guarantee comes from the getter re-reading "llm_manager.__dict__" under
        "_AZURE_OPENAI_GPT_5_5_LLM_LOCK", not from the interpreter version under test
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module path: `core/llm.py`. Class `LLMManager`, no custom `__init__`; module-level
  instance `llm_manager` on the last line, per `CLAUDE.md` § Singletons.
- Exactly one `cached_property` for Phase 1: `azure_openai_gpt_5_5_llm`, matching
  `CLAUDE.md` § Naming's `<provider>_<model>_llm` rule and the exact provider prefix
  `azure_openai` that `init_chat_model` resolves (`00-langchain-api-truth.md` §4). A
  second deployment or provider is one more `cached_property`, never a second manager
  — say so in the class docstring.
- Construction adapts the working reference snippet in `00-langchain-api-truth.md` §8.4
  (`AzureChatOpenAI(azure_deployment=..., azure_endpoint=..., api_version=...,
  azure_ad_token_provider=..., max_retries=2)`), with every `os.environ`/`os.getenv`
  read in that snippet replaced by the equivalent `settings()` field — `os.environ`
  appears nowhere outside `core/settings.py`, including inside an adapted reference
  snippet.
- **`DefaultAzureCredential`, not the `ManagedIdentityCredential` the reference
  snippet shows.** `CLAUDE.md` § Configuration: "`ManagedIdentityCredential`, or
  `DefaultAzureCredential` in a module that also runs on a developer machine." This
  module is exercised by `tests/integration` and `tests/manual`, both of which run on
  a developer machine, not only inside the deployed Function — so `DefaultAzureCredential`
  is the mandated choice, not the snippet's literal class. Both symbols are verified in
  `00-langchain-api-truth.md` §7; the choice between them is a `CLAUDE.md` policy
  decision, not an API question.
- `max_retries` is a module constant (`_MAX_RETRIES = 2`) with a comment citing the
  reference example in `00-langchain-api-truth.md` §4 as its source; it has not been
  load-tested against Azure OpenAI throttling.
- **Temperature is deliberately not set here.** Epic 4's `PEA-405` (`wrap_model_call`)
  owns pinning temperature to 0 per request; fixing it at client-construction time in
  this story would shadow that per-request control. This is a boundary worth stating
  once, here, so Epic 4 does not have to discover it by finding a temperature default
  already in place.
- **`azure_openai_gpt_5_5_llm` is built inside `_AZURE_OPENAI_GPT_5_5_LLM_LOCK`, a
  module-level `threading.Lock` declared above `LLMManager`.** The getter takes the lock,
  returns `self.__dict__["azure_openai_gpt_5_5_llm"]` if another thread has already put a
  client there, and otherwise builds and returns one — `cached_property` writes the result
  to the instance dict on the way out, so that re-read under the lock is what makes the
  second thread reuse the first thread's client instead of building its own. Above Python
  3.11 `cached_property` no longer serializes first access on its own (`PEA-101`), so
  without the lock two threads racing a cold start each pay for a TLS handshake and a
  token acquisition. The lock is named after the member rather than the class: a second
  deployment is one more `cached_property` and one more lock beside it. Two members in
  this epic need this, so per `CLAUDE.md` § Code standard four duplicated lines in two
  classes beat a shared decorator over `cached_property`, which would be a cache wrapping
  a cache. A test that seeds `llm_manager.__dict__["azure_openai_gpt_5_5_llm"]` never
  reaches the getter and never touches the lock.
- Security: no API key is ever logged; `settings().azure_openai_api_key` is read only
  to decide which branch to construct.
- Performance: the client is built once per process; `max_retries=2` bounds retry cost
  on a failed request.
- UI/UX: none. API impact: none directly — Epic 4 is the only consumer in Phase 1.

#### 5. Definition of Done (DoD) Checklist
- [ ] `core/llm.py` defines `LLMManager` (no custom `__init__`) and module-level
      `llm_manager`
- [ ] Exactly one `cached_property`, `azure_openai_gpt_5_5_llm`; docstring states a
      second deployment is one more `cached_property`, never a second manager
- [ ] Deployment, endpoint and API version sourced from `settings()`; zero literals,
      verified by an automated scan
- [ ] `DefaultAzureCredential` + `get_bearer_token_provider` is the default path;
      `api_key` used only when `settings().azure_openai_api_key` is set
- [ ] `azure_openai_gpt_5_5_llm` builds inside `_AZURE_OPENAI_GPT_5_5_LLM_LOCK` and
      re-reads `self.__dict__` under it before constructing
- [ ] `llm_manager.__dict__["azure_openai_gpt_5_5_llm"]` seedable directly by a test,
      per `CLAUDE.md` § Singletons
- [ ] `tests/unit/test_llm.py`: import hygiene, stub seeding, both credential branches,
      exactly-once under a twelve-thread race, no-literal-deployment scan
- [ ] Reviewed against `CLAUDE.md` § Singletons and § Naming

---

### PEA-105 — Define user-facing error constants and structured PHI-safe logging

**Type:** Story · **Epic:** E1 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-101 · **Satisfies:** CLAUDE.md § Docstrings and comments, CLAUDE.md § Clinical and PHI rules

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want every user-facing error message defined once as a
module constant and every log line structured with named fields instead of
interpolated text, so that a clinician never sees an inconsistent message for the same
failure, and no clinical value can leak into a log line or trace by way of a careless
`f-string`.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Two unrelated failures get fixed by the same file. First, an error a clinician sees
today comes from wherever in nine browser calls it happened to be thrown, worded
differently each time; this repository needs one place a reviewer can read every
message the product says out loud. Second, `CLAUDE.md`'s clinical rules require that a
clinical value never reach a log line, a trace attribute or an exception message — and
the only reliable way to guarantee that a hurried engineer, months from now, does not
write `logger.info(f"rejected note: {note_text}")` past that rule is to make logging
structured by construction and to have a test that fails the day someone tries anyway.
Neither half of this story depends on knowing what a clinical value looks like — that
is Epic 5's job. This story only makes the mechanism that keeps it out of a log line
exist and be enforced.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A user-facing error carries its constant message, never a fresh literal
  Given "core/errors.py" defines "AuthenticationError" paired with the constant
        "AUTHENTICATION_FAILED_MESSAGE"
   When any module raises an authentication failure
   Then it raises "AuthenticationError(AUTHENTICATION_FAILED_MESSAGE)"
    And no raise site anywhere in the tree constructs "AuthenticationError" with any
        other string

Scenario: A log call carries fields, not interpolated clinical text
  Given a caller wants to record that a request was rejected
   When it calls "logger.warning(...)"
   Then the call passes a fixed message string plus an "extra" mapping of named fields
    And no f-string or "%"-interpolation embeds a variable into the message argument

Scenario: A log-hygiene test catches an interpolated call before it ships
  Given a line "logger.info(f\"rejected note: {note_text}\")" is planted anywhere in
        the tree
   When "tests/unit/test_logging_hygiene.py" runs
   Then the test fails and names the offending file and line number

Scenario: Importing logging.py attaches no handler and reads no environment
  Given no environment variables are set
   When "import core.logging" executes
   Then no exception is raised
    And the root logger has no handler attached — attachment happens only when
        "configure_logging(level)" is called explicitly by the process entrypoint
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module paths: `core/errors.py`, `core/logging.py`.
- `core/errors.py` defines `PacEHRError(Exception)` as the base every domain epic's own
  exception subclasses from, and `AuthenticationError(PacEHRError)` — the one exception
  type this epic's own modules (`PEA-106`) need. Domain-specific reason codes
  (guardrail blocks, validation failures) are declared in the modules that raise them,
  next to the code that raises them, not centralized here — this file holds the shared
  base and this epic's own exceptions, not every exception the whole backlog will ever
  need.
- `core/logging.py` defines `configure_logging(level: str) -> None` (attaches a
  structured formatter to the root logger; called once) and `get_logger(name: str) ->
  logging.Logger`. The formatter renders each `extra` field explicitly as structured
  output rather than free text, so what is logged is what is reviewable.
- **This module provides the mechanism, not the guarantee.** `core/logging.py` has no
  notion of what a clinical value is; it only makes structured fields the natural way
  to log and makes an interpolated message a test failure. Epic 5 owns proving that no
  clinical value specifically reaches a log line, a trace attribute, or an exception
  message — this story is the enforcement surface that claim is checked against.
- **Nobody calls `configure_logging` yet.** No process entrypoint exists in this epic.
  The docstring states that the story building the process entrypoint — Epic 9's
  `POST /ai/encounter/extract` handler, or Epic 11's Function host — calls
  `configure_logging(settings().log_level)` once at startup.
- Security: the specific exception class name may be logged; the message text a
  caller sees never varies by cause (see `PEA-106`), and no clinical value or secret is
  a valid `extra` field value by convention — enforced by the hygiene test's ban on
  interpolation, not by a content filter.
- Performance: logging setup is one-time and negligible.
- UI/UX: the constants in `core/errors.py` are the literal text a clinician or reviewer
  eventually sees; consistency here is the UI/UX impact.

#### 5. Definition of Done (DoD) Checklist
- [ ] `core/errors.py`: `PacEHRError` base, `AuthenticationError` subclass, each paired
      with a `SCREAMING_SNAKE` message constant
- [ ] `core/logging.py`: `configure_logging(level)` and `get_logger(name)`; structured
      formatter; no handler attached and no environment read at import
- [ ] `tests/unit/test_logging_hygiene.py` scans the tree for an f-string or
      `%`-interpolated logger call and fails on a planted violation
- [ ] `tests/unit/test_errors.py` asserts each custom exception is raised only with its
      module constant
- [ ] `configure_logging`'s docstring names which future story calls it
- [ ] Reviewed against `CLAUDE.md` § Docstrings and comments and § Clinical and PHI rules

---

### PEA-106 — Validate Entra ID bearer tokens to a caller object id

**Type:** Story · **Epic:** E1 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-101, PEA-102, PEA-105 · **Satisfies:** CLAUDE.md § Singletons, CLAUDE.md § Configuration

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want every inbound request's Entra ID bearer token validated
against the tenant's published signing keys and reduced to a caller object id, so that
every downstream action in this service is attributable to a verified identity rather
than an unverified claim forwarded by a proxy.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Moving context assembly server-side does not just relocate the nine browser calls — it
creates a new network-reachable service that did not exist before, sitting behind a
.NET proxy that itself keeps auth, tenancy and rate limiting (Epic 9). A proxy
authenticating its own caller is not the same guarantee as this service verifying who
is actually invoking it; every audit row Epic 9 later writes server-side is only as
trustworthy as the identity behind the request that produced it. This story turns an
inbound bearer token into a verified, attributable caller object id before any
handler — agent or otherwise — runs.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A validly signed, current token yields the caller's object id
  Given a bearer token signed by a key published at the tenant's JWKS endpoint
    And the token's "aud" matches this API's configured audience
    And the token's "iss" matches "https://login.microsoftonline.com/<tenant>/v2.0"
    And the token is not expired
   When "entra_authenticator.authenticate(token)" is called
   Then it returns the token's "oid" claim as a string
    And no exception is raised

Scenario: An expired token is rejected without leaking why to the caller
  Given a token whose "exp" has passed
   When "entra_authenticator.authenticate(token)" is called
   Then it raises "AuthenticationError(AUTHENTICATION_FAILED_MESSAGE)"
    And the specific cause ("ExpiredSignatureError") is written to the structured log,
        never to the raised message

Scenario: A token signed by an unknown key is rejected
  Given a token whose "kid" matches no key at the tenant's JWKS endpoint
   When "entra_authenticator.authenticate(token)" is called
   Then it raises "AuthenticationError(AUTHENTICATION_FAILED_MESSAGE)"

Scenario: A token for the wrong audience is rejected
  Given a validly signed token whose "aud" names a different application
   When "entra_authenticator.authenticate(token)" is called
   Then it raises "AuthenticationError(AUTHENTICATION_FAILED_MESSAGE)"

Scenario: Importing auth.py fetches no JWKS and reads no environment
  Given no environment variables are set and network access is blocked
   When "import core.auth" executes
   Then no exception is raised
    And "entra_authenticator.__dict__" contains no "jwks_client" entry

Scenario: The JWKS client is fetched once and reused, never once per request
  Given the process has already authenticated one request successfully
   When a second, unrelated request is authenticated
   Then no second "PyJWKClient" is constructed
    And PyJWT's own cached JWK set ("cache_jwk_set=True", "lifespan=300") serves the
        second request

Scenario: Twelve concurrent first requests share one JWKS client, not twelve
  Given twelve threads call "entra_authenticator.authenticate" together, on a process
        that has not yet authenticated a request
   When all twelve have returned
   Then exactly one "PyJWKClient" is constructed, confirmed by a call counter on the
        stubbed constructor
    And all twelve requests are served by that same instance
    And the guarantee comes from the getter re-reading "entra_authenticator.__dict__"
        under "_JWKS_CLIENT_LOCK", not from the interpreter version under test
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Module path: `core/auth.py`. Class `EntraAuthenticator`, no custom `__init__`;
  module-level instance `entra_authenticator` on the last line, per `CLAUDE.md` §
  Singletons.
- **This is an HTTP-layer check, not an agent middleware guard — it raises.**
  `CLAUDE.md` § Clinical and PHI rules' "a guard never raises; fail closed with
  `jump_to`" governs guards running *inside* the compiled agent (Epic 5's guards, via
  `before_agent`). This story runs *before* the agent is ever invoked, at the request
  boundary; `AuthenticationError` propagating and being translated to an HTTP 401 is
  the correct behaviour here, and Epic 9's endpoint (`PEA-901`) is where that
  translation happens. Do not read this story as contradicting the fail-closed rule —
  it operates one layer earlier, where that rule does not apply.
- **The object id returned identifies the calling service principal (the .NET proxy),
  not necessarily an individual clinician.** If Epic 9's "recorded against their name"
  audit requirement needs the clinician's own identity, that identity must travel as a
  separate claim or request field — a decision for Epic 9, not resolved by this story.
  Stating this boundary here removes one of the more consequential ambiguities a
  downstream epic could resolve incorrectly.
- `jwks_client` is a `cached_property` over `PyJWKClient(jwks_uri)`, built from a
  module-constant URI template — `_JWKS_URI_TEMPLATE =
  "https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys"` — formatted with
  `settings().entra_tenant_id`; no tenant id or host literal outside that template and
  the `Settings` field. Defaults are left untuned (`cache_jwk_set=True`, `lifespan=300`):
  Microsoft's own guidance that checking for key updates every 24 hours is reasonable
  is well outside PyJWT's 300-second default, so no override is justified
  (`00-langchain-api-truth.md` §7).
- `authenticate(token)` resolves the signing key via `get_signing_key_from_jwt` against
  the cached `jwks_client`, then calls `jwt.decode(token, signing_key.key,
  algorithms=["RS256"], audience=settings().entra_audience, issuer=<issuer template
  formatted with entra_tenant_id>)`. Any `jwt.PyJWTError` or `PyJWKClientError` is
  caught and re-raised as `AuthenticationError(AUTHENTICATION_FAILED_MESSAGE)` — the
  message never varies by cause; the specific exception class name and the token's
  `kid` (never the raw token, never a claim value) are logged via `core/logging`'s
  `get_logger`, per `CLAUDE.md`'s "log the token, never the value."
- **The `oid` claim is not listed in `00-langchain-api-truth.md`'s "Claims to
  validate" row** (which names `aud`, `iss`, `tid`; `exp`/`nbf` are enforced by
  `jwt.decode` by default) — it is out of that file's scope (a token payload fact, not
  a LangChain/Pydantic/Azure SDK symbol). Independently verified against Microsoft's
  own access-token-claims reference: `oid` is "the immutable identifier for the
  requestor, which is the verified identity of the user or service principal... can be
  used as a key in database tables" — exactly "the caller's object id" this story must
  produce. Flagged in the epic report rather than silently asserted as truth-file-verified.
- Single-tenant assumption, stated rather than left implicit: `iss` is checked against
  this one configured tenant; multitenant issuer validation (`tid` plus the
  signing-key issuer) is out of scope because Epic 11's deployment model is one Azure
  subscription per customer.
- **`jwks_client` is built inside `_JWKS_CLIENT_LOCK`, a module-level `threading.Lock`
  declared above `EntraAuthenticator`** — the same idiom and the same reason as
  `PEA-104`'s chat model, where it is specified in full. The getter takes the lock,
  returns `self.__dict__["jwks_client"]` if another thread has already put a client
  there, and otherwise builds and returns one. Above Python 3.11 `cached_property` no
  longer serializes first access on its own (`PEA-101`), so without the lock twelve
  first requests arriving together can each construct a `PyJWKClient` and each fetch the
  tenant's key set. Seeding `entra_authenticator.__dict__["jwks_client"]` bypasses the
  getter and the lock, so the test convention in `CLAUDE.md` § Singletons is unchanged.
- Security: the raw token is never logged. Performance: the JWKS set is fetched at
  most once per `lifespan` (300s) window per process, not once per request.

#### 5. Definition of Done (DoD) Checklist
- [ ] `core/auth.py` defines `EntraAuthenticator` (no custom `__init__`) and
      module-level `entra_authenticator`
- [ ] `authenticate(token: str) -> str` returns the `oid` claim or raises
      `AuthenticationError(AUTHENTICATION_FAILED_MESSAGE)`
- [ ] `jwks_client` is a `cached_property` over `PyJWKClient` built inside
      `_JWKS_CLIENT_LOCK`, re-reading `self.__dict__` under it before constructing;
      PyJWT's cache defaults left untuned, with the comment citing Microsoft's 24-hour
      guidance
- [ ] `entra_authenticator.__dict__["jwks_client"]` seedable directly by a test with a
      stub JWKS client, per `CLAUDE.md` § Singletons
- [ ] JWKS URI and issuer built from `entra_tenant_id` via module-constant templates —
      no hardcoded tenant id or audience literal outside `Settings` field defaults
- [ ] `tests/unit/test_auth.py`: valid token, expired, unknown `kid`, wrong audience,
      import hygiene, exactly one JWKS client under a twelve-thread race — all against
      a faked JWKS response, no real Entra tenant reachable
- [ ] The raised message never varies by failure reason; the specific `PyJWTError`
      subclass is logged, never returned to the caller
- [ ] Module docstring states the service-identity-vs-clinician-identity boundary
- [ ] Reviewed against `CLAUDE.md` § Singletons and § Configuration
