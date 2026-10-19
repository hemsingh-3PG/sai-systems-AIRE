# CLAUDE.md — PacEHR Encounter Agent

**This file is the engineering standard for this repository.** Tickets cite it and do not
restate it. Every rule below was arrived at by deleting code that broke it.

## What this repository is

This is the Python service that reads a clinician's free-text note and extracts structured
clinical values into the fields of an encounter template. Extraction runs as a LangChain
agent built with `create_agent` against Azure OpenAI, with the checking done by ordinary
Python in middleware the model cannot decline to run.

Azure is the only cloud in this repository. Python is the only language in it.

## Folder schema

```
core/            settings, app factory, database, LLM clients, knowledge base,
                 documents, auth, errors, logging, task dispatch, shared tools
conversations/   conversation + message persistence, shared by both products
chat/            WebSocket app, protocol, socket, turn pacing
pacehr/          agents, tools, prompts
tests/           unit / integration / manual — the directory is the marker
```

`conversations/` and `chat/` belong to the other product on this repository: the encounter
agent scaffolds them and populates neither.

A test is classified by the directory it lives in, not by a decorator. `tests/unit` imports
the whole tree with no environment, no credentials and no network. `tests/integration`
reaches Azure. `tests/manual` is run by a person.

## Configuration

- Configuration comes from `core/settings.py` and from nowhere else. `os.environ` appears in
  that file and in no other file in the tree.
- Values live in `.env.local`, which is git-ignored. `.env.example` is the committed
  template and carries every field with a placeholder.
- **No hardcoded environment values.** No region, deployment name, endpoint, resource id,
  container name or port literal appears outside a `Settings` field default. A value pasted
  into a module is a value that is correct in one environment and wrong in every other.
- Deployed code authenticates with managed identity — `ManagedIdentityCredential`, or
  `DefaultAzureCredential` in a module that also runs on a developer machine. An API key is
  a local-development fallback and never a deployed path.
- `uv` manages dependencies. Add them to `pyproject.toml`, commit `uv.lock`, never
  `pip install` into `.venv`. A package that is in the virtualenv and not in the lock file
  is a package the deployed Function does not have.

## Code standard

- **No function that exists to call one other function.** A one-line `def` that forwards its
  argument, or returns `row["name"]`, is not abstraction — it is a jump the reader makes for
  nothing. One caller and no branching means inline it.
- **No wrapper over a wrapper.** Before adding a cache, an accessor or a manager, check
  whether the thing underneath already provides it. `settings()` is already `@lru_cache`; a
  `cached_property` returning `settings()` is a second cache reaching the same object.
- **One class per surface, one public method.** An endpoint's logic belongs in one `run()`
  that reads top to bottom: validate, read, build, call, unwrap.
- **Duplicating five lines across two classes beats sharing them through a helper the reader
  must go find.**
- **Formatting lives with the thing being formatted, in one method.** Six functions turning
  rows into text is six places to look; one method emitting one list of lines shows the
  whole output shape at once.
- **Comments state the fact, once** — a measurement, a constraint, or the reason a
  non-obvious line exists. Not a change log, not a rationale essay, and **never that a rule
  forced it.**
- **Verify, do not recall.** Every claim about a library, the schema or Azure is checked by
  running something: `information_schema.columns` against the live database rather than a
  migration document, `usage_metadata` off a real response rather than an estimate, a live
  call rather than an assumption. Documented numbers go stale.

## Singletons — the pattern this repository is built on

One object per process per job, the same shape everywhere. Read `core/llm.py` and
`core/database.py` and you have seen all of it.

- **The instance is created on the last line of the module that defines the class**, named
  after it, and the class docstring opens with "Use the module-level `x`."
- A caller that constructs its own copy pays for a second TLS handshake, a second JWKS fetch
  or a second compiled agent, **and no test catches it.** The cost lands in production, under
  load, as latency no local measurement predicted.
- **Module level, not `@lru_cache`, for anything holding members.** The import lock makes
  `x = Class()` atomic. `lru_cache` locks its dict and not the call: twelve threads racing a
  cold cache were measured building twelve separate objects. `@lru_cache(maxsize=1)` is
  right for `settings()` alone, which returns one value and holds nothing.
- **`__init__` reads nothing, builds nothing, and touches no network.** Importing any module
  must work with no environment and no credentials — that is what lets `tests/unit` import
  the whole tree, and what keeps a cold start from paying for a client it never uses.
  `__init__` exists only to bind what a second instance would differ on.
- **Every expensive member is a `cached_property`** — Azure SDK clients, the JWKS client,
  compiled agents. First use builds it and the process reuses it. Through 3.11,
  `cached_property` guaranteed that itself: an internal lock serialized first access. 3.12
  dropped the lock for lock contention, and this repository's `requires-python = ">=3.10"`
  carries no upper bound, so 3.12 and later are in scope too. Unlocked there, two threads
  finding the property cold both run the getter, and the loser's client — a TLS handshake or a
  JWKS fetch it already paid for — is discarded. A test still seeds it with
  `instance.__dict__["client"] = stub`: `cached_property`'s own pre-check finds that value
  before the getter runs, so neither the getter nor a lock inside it is ever reached, and
  seeding is unchanged.
- **A member whose construction does that real work — a TLS handshake, a JWKS fetch, a
  compiled agent — declares a module-level `threading.Lock`, named after the member, above
  the class.** The getter takes the lock and re-reads `self.__dict__` first: if another thread
  has already put a value there, it returns that value instead of building a second one. The
  Azure OpenAI client and the JWKS client do this today. A member that only reads settings
  takes no lock — there is no race worth losing.
- A manager is a namespace with a lifetime, not a service layer. **A class earns its place by
  owning construction. It never earns it by forwarding.**

## Naming

- The instance is the class name in snake_case: `LLMManager` → `llm_manager`.
- Where one class has several instances, the product prefixes them.
- **An `a` prefix is the async twin**, and where the driver blocks it is the only public
  entry point: `database.aexecute`, `document_store.aread`. Azure SQL has no native async
  driver — `mssql_python` is a synchronous PEP 249 driver — so `aexecute` is
  `asyncio.to_thread` around the blocking call and the blocking call is not exported. A
  synchronous `execute` published beside `aexecute` is a stalled event loop waiting for a
  caller to find it.
- LLM members are `<provider>_<model>_llm` — `azure_openai_gpt_5_5_llm` — matching
  `azure_openai`, the exact provider prefix `init_chat_model` resolves. A new provider is one
  more `cached_property`, not a new manager.
- **One statement per constant, `SCREAMING_SNAKE`, suffixed `_SQL`, declared above the class
  that runs it**, so the reader sees every statement a module can issue without opening a
  method. No statement is assembled at call time, and **no value ever reaches SQL by
  interpolation** — parameters bind server-side, which is what makes injection impossible. An
  f-string in a statement interpolates a fixed column tuple only, and carries the
  `# noqa: S608` that says so.
- **Anything the user reads is a module constant, not a literal at the raise site.** One
  place to read what the product says out loud.
- A leading underscore means one module owns it. When a second module wants one, the question
  is whether the two callers should be one caller.

## Docstrings and comments

- **The module docstring says what the module is and why it is not the module beside it.**
  That paragraph is what prevents the next wrong merge.
- A function docstring's first line is the result, not the activity: "(job_id, created)."
  "The object's bytes." "The caller's Entra object id, or `AuthenticationError`."
- **A tool's docstring is its API.** Tools are declared `@tool(parse_docstring=True)`, so the
  summary and every `Args:` entry go to the model: the docstring is the specification and the
  prompt does not repeat it. `parse_docstring` defaults to `False`, so it is set explicitly on
  every tool; `error_on_invalid_docstring` defaults to `True`, so a docstring that is not
  Google-style raises `ValueError` at import. **Google-style `Args:` blocks are what keeps the
  package importable.**
- **Tools are `@staticmethod`.** The decorator on an instance method puts `self` into the
  schema the model sees.
- A date appears only as the date of a measurement against a live system, because that is what
  makes the number checkable. Never a changelog entry.
- ⚠️ marks a trap that has already cost a run, and nothing else.
- **Deleted code is deleted.** A commented-out block survives only with the paragraph
  explaining why putting it back is wrong. Without that paragraph, delete it.

## Numbers

**A bare number in an expression is a bug.** Every tunable is a module constant whose comment
carries the observation that produced it. **A constant nobody can trace back to a measurement
is a guess wearing a name.**

A limit that varies by environment is a `Settings` field. A limit that belongs to a protocol
is a constant — changing the latter means changing something outside this repository, and a
value that can disagree with its external contract is worse than a literal.

## The agent

- One compiled agent per process. `create_agent` is called once, inside the `cached_property`
  that owns it, and the request that triggers a second compilation pays for it.
- **Structured output is declared `response_format=ProviderStrategy(Schema)`, explicitly.** A
  bare schema type leaves the choice of strategy to the model's profile data, and when that
  data is missing or stale LangChain selects `ToolStrategy`: the schema is then enforced by a
  client-side retry loop instead of by the provider. Nothing raises when that happens — the
  agent still returns an object — so the enforcement the design rests on is lost in silence.
  The parsed object is `result["structured_response"]`.
- A `Field(description=...)` is the only per-field instruction the model receives. It is
  specification, not documentation, and the prompt does not repeat it.

## Clinical and PHI rules

- **Identifiers are masked before egress and restored after.** The token map is
  request-scoped state, **never a module singleton** — a singleton leaks identifiers across
  concurrent requests. This is the one place the pattern above is forbidden.
- **Log the token, never the value.** No clinical value reaches a log line, a trace attribute
  or an exception message.
- **Validators are plain Python in a middleware hook, never tools.** A tool the model may
  decline to call cannot prove a check ran.
- **Any guard failure ends the run before a model call. Fail closed.** A guard blocks by
  returning `{"jump_to": "end"}` from `before_agent`, with `can_jump_to=["end"]` declared on
  the hook. **A guard never raises.** `jump_to: "end"` still runs `after_agent`, so the audit
  row is written on the way out; an exception propagates as a failure, skips `after_agent`,
  and destroys the audit row for exactly the runs most worth auditing.
- **Confidence is the band `HIGH`, `MEDIUM` or `LOW`.** Never a float — a self-reported
  probability is not a calibrated measurement, and a number invites arithmetic that means
  nothing.
- **Preserve the live database's own spelling, including its inconsistencies** — `templetID`,
  `fieldID`, `sectionID`. Retro-fitting conventions onto existing SQL is forbidden; a column
  is named what it is named.
