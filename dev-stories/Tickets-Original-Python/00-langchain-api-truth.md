# 00 — LangChain / Pydantic / Azure API ground truth

**Status:** verified 2026-09-23. **This file is the allow-list.** A symbol that does not
appear below may not be named by any ticket.

**Verification path:** LangChain symbols verified with the `reference-langchain` and
`docs-langchain` MCP servers. Pydantic, PyJWT and Azure SDK symbols verified against
pydantic.dev / pypi.org, pyjwt.readthedocs.io and learn.microsoft.com via `WebFetch` (the
LangChain MCP servers do not index them). Every row names the call that produced it, and
rows outside the MCP servers' scope are marked **web:** in the `Verified by` column so the
provenance stays visible.

**Platform:** Azure only. No AWS package, service or identifier appears in this file.
Where LangChain documentation used a non-Azure example, the snippet was translated to
Azure OpenAI — each translation is flagged inline.

**Pinned versions behind these entries:** `langchain` v1 (`langchain.agents`,
`langchain_v1` source tree), `langchain-openai`, `pydantic` 2.13.5,
`pydantic-settings` 2.15.0, `pyjwt`, `azure-functions` 2.3.0 (`requires_python >=3.13`) or
1.25.0 (`requires_python >=3.10`) — the major line follows the image's Python version, see
§11.6 — on the Azure Functions **v4 runtime**, **Python v2 programming model**.

---

## 1. Agent factory

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `create_agent` | `from langchain.agents import create_agent` | `create_agent(model, tools=None, *, system_prompt=None, middleware=(), response_format=None, state_schema=None, context_schema=None, checkpointer=None, store=None, interrupt_before=None, interrupt_after=None, debug=False, name=None, cache=None, transformers=None)` → `CompiledStateGraph` | `get_symbol(package="langchain", symbol="create_agent")` |
| `model` (param) | — | `str \| BaseChatModel`. String form is `"<provider>:<model>"`, resolved by `init_chat_model`. | `get_symbol("create_agent")` |
| `tools` (param) | — | `Sequence[BaseTool \| Callable \| dict] \| None`. `None`/empty ⇒ model node only, no tool loop. | `get_symbol("create_agent")` |
| `system_prompt` (param) | — | `str \| SystemMessage \| None`. **This is the parameter name — not `prompt`.** | `get_symbol("create_agent")` |
| `middleware` (param) | — | `Sequence[AgentMiddleware]`, default `()`. | `get_symbol("create_agent")` |
| `response_format` (param) | — | `ResponseFormat[ResponseT] \| type[ResponseT] \| dict \| None`. See §3. | `get_symbol("create_agent")` |
| `state_schema` (param) | — | `type[AgentState[ResponseT]] \| None`. Extends `AgentState`; prefer middleware-scoped state. | `get_symbol("create_agent")` |
| `context_schema` (param) | — | `type[ContextT] \| None` — runtime context schema. | `get_symbol("create_agent")` |
| `checkpointer` (param) | — | `Checkpointer \| None` — per-thread persistence. | `get_symbol("create_agent")` |
| `store` (param) | — | `BaseStore \| None` — cross-thread persistence. | `get_symbol("create_agent")` |
| `interrupt_before` / `interrupt_after` (params) | — | `list[str] \| None` — node names to interrupt on. | `get_symbol("create_agent")` |
| `name` (param) | — | `str \| None` — name of the compiled graph; used when nesting as a subgraph. | `get_symbol("create_agent")` |
| `debug` (param) | — | `bool`, default `False` — verbose node/state logging. | `get_symbol("create_agent")` |
| `cache` (param) | — | `BaseCache[Any] \| None`. | `get_symbol("create_agent")` |
| `AgentState` | `from langchain.agents.middleware import AgentState` | `TypedDict`: `messages: Required[Annotated[list[AnyMessage], add_messages]]`, `jump_to: NotRequired[...]`, `structured_response: NotRequired[...]` | `get_symbol(package="langchain", symbol="AgentState")` |

### Messages and runtime — symbols the snippets in §8 depend on

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `AIMessage` | `from langchain.messages import AIMessage` (re-export of `langchain_core.messages.AIMessage`) | `AIMessage(content=None, content_blocks=None, **kwargs)`. Properties: `tool_calls`, `invalid_tool_calls`, `usage_metadata`, `type`, `content_blocks`. Returned by a chat model; constructed by a hook to inject a canned reply. | `get_symbol(package="langchain-core", symbol="langchain_core.messages.ai.AIMessage")`; import form from `rg -n "from langchain.messages import"` (messages.mdx 19, guardrails.mdx 290, agents.mdx 919) |
| `Runtime` | `from langgraph.runtime import Runtime` | `Runtime[ContextT]` — injected into graph nodes and middleware hooks as the second positional argument. Provides `context`, `store`, `stream_writer`, `previous`, `execution_info`. **Does not carry `config`** — inject `config: RunnableConfig` separately if needed. | `get_symbol(package="langgraph", symbol="Runtime")` |

`NotRequired` (used in §8.2) is `typing_extensions.NotRequired` — a standard-library typing
construct, not a vendor API, so it carries no row.

Agent invocation returns the final state dict:

```python
result = agent.invoke({"messages": [{"role": "user", "content": "..."}]})
result["messages"]             # full message list
result["structured_response"]  # parsed structured output (see §3)
```

---

## 2. Structured output — the load-bearing section

**Where the parsed result lands: `result["structured_response"]`.** This is a real key on
`AgentState`, declared as
`structured_response: NotRequired[Annotated[ResponseT, OmitFromInput]]`.

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `ProviderStrategy` | `from langchain.agents.structured_output import ProviderStrategy` | `ProviderStrategy(schema, *, strict=None)` | `get_symbol(package="langchain", symbol="ProviderStrategy")` |
| `ToolStrategy` | `from langchain.agents.structured_output import ToolStrategy` | `ToolStrategy(schema, *, tool_message_content=None, handle_errors=True)` | `get_symbol(package="langchain", symbol="ToolStrategy")` |
| `structured_response` (state key) | — | Key on the returned state holding the parsed object. | `get_symbol("AgentState")`; `query_docs_filesystem("head -250 /oss/python/langchain/structured-output.mdx")` |
| `ProviderStrategy.strict` | — | `bool \| None`, default `None`. Requests strict provider-side enforcement. Requires `langchain>=1.2`. | `get_symbol("ProviderStrategy")`; structured-output.mdx |
| `ToolStrategy.handle_errors` | — | `bool \| str \| type[Exception] \| tuple[type[Exception], ...] \| Callable[[Exception], str]`, default `True`. `False` ⇒ exceptions propagate. | `get_symbol("ToolStrategy")` |
| `ToolStrategy.tool_message_content` | — | `str \| None` — overrides the emitted `ToolMessage` body. | `get_symbol("ToolStrategy")` |

### What each strategy does, and which one Azure OpenAI gets

* **`ProviderStrategy`** — uses the provider's *native* structured-output API. The provider
  enforces the schema server-side. This is the mode the design depends on: malformed JSON
  is rejected by the provider, not by a retry loop.
* **`ToolStrategy`** — emulates structured output with a tool call, then validates
  client-side and retries per `handle_errors`. Used for models without native support.

**Selection rule (verified, `structured-output.mdx` lines 26–39):** when a bare schema
*type* is passed to `response_format`, LangChain chooses `ProviderStrategy` if the model
and provider support native structured output, otherwise `ToolStrategy`. From
`langchain>=1.1` that capability is read dynamically from the model's **profile data**
(`model.profile`, key `structured_output`) — it is not a hardcoded provider list.

**Azure OpenAI resolves to `ProviderStrategy`.** Azure OpenAI is served by the OpenAI
integration package `langchain-openai`, and the LangChain Azure chat integration page
lists structured output as supported for `AzureChatOpenAI`. OpenAI is named in the docs as
a provider with native structured output.

**Ticket instruction:** pass `ProviderStrategy(Schema)` **explicitly** rather than a bare
schema type. Explicit form is functionally equivalent when native support exists, and it
removes the dependency on profile-data inference (which can silently degrade to
`ToolStrategy` if profile data is missing or stale). See the Unverified section for the
residual risk this leaves.

**Hard rule:** a raw JSON-Schema `dict` is **not** auto-detected. It must be wrapped in
`ProviderStrategy(...)` or `ToolStrategy(...)`, and must carry top-level `title` and
`description`. Passing a bare dict to `response_format` does not select a strategy.

**Return types by schema kind** (same for both strategies): Pydantic `BaseModel` subclass
⇒ validated model instance; dataclass ⇒ `dict`; `TypedDict` ⇒ `dict`; JSON Schema dict ⇒
`dict`.

---

## 3. Middleware — the spine

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `AgentMiddleware` | `from langchain.agents.middleware import AgentMiddleware` | `class AgentMiddleware(Generic[StateT, ContextT, ResponseT])`; subclass and implement hooks | `get_symbol(package="langchain", symbol="AgentMiddleware")` |
| `AgentMiddleware.state_schema` | — | Class attribute: the state schema this middleware's hooks see. | `search_api("AgentMiddleware")` |
| `AgentMiddleware.tools` | — | Class attribute: additional tools registered by the middleware. | `search_api("AgentMiddleware")` |
| `AgentMiddleware.name` | — | Class attribute; defaults to the class name. | `search_api("AgentMiddleware")` |
| `hook_config` | `from langchain.agents.middleware import hook_config` | `hook_config(*, can_jump_to: list[JumpTo] \| None = None)` — decorator on a hook **method** in a class-form middleware | `get_symbol(package="langchain", symbol="hook_config")` |
| `ModelRequest` | `from langchain.agents.middleware import ModelRequest` | `ModelRequest(*, model, messages, system_message=None, system_prompt=None, tool_choice=None, tools=None, response_format=None, state=None, runtime=None, model_settings=None)`; has `.override()` | `get_symbol(package="langchain", symbol="ModelRequest")` |
| `ModelResponse` | `from langchain.agents.middleware import ModelResponse` | `ModelResponse(result: list[BaseMessage], structured_response: ResponseT \| None = None)` | `get_symbol(package="langchain", symbol="ModelResponse")` |
| `ExtendedModelResponse` | `from langchain.agents.middleware import ExtendedModelResponse` | `ExtendedModelResponse(model_response=..., command=Command(update={...}))` — return from `wrap_model_call` to write state | `query_docs_filesystem("sed -n '140,260p' /oss/python/langchain/middleware/custom.mdx")` |
| `ToolCallRequest` | `from langchain.agents.middleware import ToolCallRequest` | Passed to `wrap_tool_call`; exposes `.state`, `.runtime`, the call dict and the `BaseTool` | `get_symbol(package="langchain", symbol="wrap_tool_call")` |

### All six hooks exist, spelled exactly as the design assumes

Verified against `get_symbol("AgentMiddleware")` (method list) and
`/oss/python/langchain/middleware/custom.mdx`. **No hook is renamed; no signature differs
from the design's description.** Every hook has an `a`-prefixed async twin.

| Hook | Style | Signature | Async twin |
|---|---|---|---|
| `before_agent` | node | `before_agent(self, state, runtime) -> dict[str, Any] \| None` | `abefore_agent` |
| `before_model` | node | `before_model(self, state, runtime) -> dict[str, Any] \| None` | `abefore_model` |
| `wrap_model_call` | wrap | `wrap_model_call(self, request: ModelRequest, handler: Callable[[ModelRequest], ModelResponse]) -> ModelResponse \| AIMessage` | `awrap_model_call` |
| `wrap_tool_call` | wrap | `wrap_tool_call(self, request: ToolCallRequest, handler: Callable[[ToolCallRequest], ToolMessage \| Command]) -> ToolMessage \| Command` | `awrap_tool_call` |
| `after_model` | node | `after_model(self, state, runtime) -> dict[str, Any] \| None` | `aafter_model` |
| `after_agent` | node | `after_agent(self, state, runtime) -> dict[str, Any] \| None` | `aafter_agent` |

`runtime` is `Runtime[ContextT]`, imported as `from langgraph.runtime import Runtime`.

### Execution order

For `middleware=[m1, m2, m3]` (verified, custom.mdx §"Execution order"):

* `before_*` hooks: **first to last** — `m1`, `m2`, `m3`.
* `after_*` hooks: **last to first** — `m3`, `m2`, `m1`.
* `wrap_*` hooks: **nested** — `m1` wraps `m2` wraps `m3` wraps the model/tool call.
  First defined = outermost.

Full order: `before_agent` (1→3) → loop start → `before_model` (1→3) →
`wrap_model_call` (1→2→3→model) → `after_model` (3→1) → loop end → `after_agent` (3→1).

### How a hook aborts the run

**Mechanism: a sentinel state key, not an exception.** A node-style hook returns a dict
containing `"jump_to"`, and the hook must declare the jump up front.

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `jump_to` (state key) | — | `return {"jump_to": "end"}` from a node-style hook | `get_symbol("AgentState")`; `rg -n -A12 "To exit early from middleware" custom.mdx` |
| `can_jump_to` (kwarg) | — | `@hook_config(can_jump_to=["end"])` on a class method; `@before_agent(can_jump_to=["end"])` / `@before_model(can_jump_to=["end"])` on a decorator-form hook | `get_symbol("hook_config")`; custom.mdx lines 52, 80, 462; guardrails.mdx lines 186, 239, 301, 347 |

Jump targets (exactly three): `'end'` (end of agent execution, or the first `after_agent`
hook), `'tools'` (the tools node), `'model'` (the model node, or the first `before_model`
hook).

Declaring `can_jump_to` is **required** — it is what establishes the conditional edge in
the compiled graph. Returning `jump_to` from a hook that did not declare it will not wire
a jump.

**`can_jump_to` is supported on the agent-level hooks, not only the model-level ones.**
`/oss/python/langchain/guardrails.mdx` gives the Python form for `before_agent` in both
syntaxes — `@hook_config(can_jump_to=["end"])` on the class method (line 186) and
`@before_agent(can_jump_to=["end"])` on the decorator form (line 239) — and the same for
`after_agent` (lines 301 and 347). The canonical example is a content filter that blocks a
request in `before_agent` before any processing begins. Jump logic therefore belongs in
whichever hook the guard belongs in; there is no restriction to `before_model` /
`after_model`.

Wrap-style hooks do not use `jump_to`. They short-circuit by **not calling `handler`** and
returning a `ModelResponse` / `ToolMessage` directly, or they raise — exceptions from
`wrap_tool_call` propagate unless `handle_tool_errors` is configured on `ToolNode`.

### Architectural consequence: fail closed with `jump_to`, never with `raise`

`jump_to: "end"` goes to **the end of agent execution, or the first `after_agent` hook** —
so **`after_agent` still runs on a blocked run.** That is the property this project depends
on: the design requires an audit row on every run *including runs that failed closed*.

Therefore:

* A guard that blocks a run **must** block with `return {"jump_to": "end"}` from
  `before_agent` (declaring `can_jump_to=["end"]`), and let `after_agent` write the audit
  row on the way out.
* A guard **must not** raise to block a run. An exception propagates as a failure and
  **skips `after_agent`**, losing the audit row for exactly the runs most worth auditing.

No ticket may specify raising an exception as the way to block or abort a run. See
DO-NOT-USE.

### How a hook reads and writes state

* **Read:** node-style hooks receive `state` as the first argument. Wrap-style hooks read
  `request.state`.
* **Write, node-style:** return a plain `dict`; keys map to state fields and are merged
  through the graph's reducers.
* **Write, wrap-style:** `wrap_model_call` returns `ExtendedModelResponse(model_response=...,
  command=Command(update={...}))`. `wrap_tool_call` returns a `Command` directly.
* **Typing:** subclass `AgentState` (a `TypedDict`) and mark added fields `NotRequired`.
  Attach the schema with `state_schema=` on the decorator, or as the class attribute
  `state_schema` on a class-form middleware.
* **Composition:** commands apply inner-first then outer; the outermost middleware wins on
  conflicting non-reducer keys. Messages are additive. On retry, commands from discarded
  `handler()` calls are dropped.

### Decorator form vs class form — both exist

Decorator form, all importable from `langchain.agents.middleware`: `before_agent`,
`before_model`, `after_model`, `after_agent`, `wrap_model_call`, `wrap_tool_call`. Each
accepts `state_schema=`; the node-style ones also accept `can_jump_to=`.

Class form: subclass `AgentMiddleware`, implement the hook as a method, call
`super().__init__()` in `__init__`, and use `@hook_config(can_jump_to=[...])` for jumps.

**Ticket guidance:** use the class form when the middleware holds configuration or needs
several hooks; the decorator form for single stateless hooks.

---

## 4. Models — Azure OpenAI

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `init_chat_model` | `from langchain.chat_models import init_chat_model` | `init_chat_model(model=None, *, model_provider=None, configurable_fields=None, config_prefix=None, **kwargs)` | `get_symbol(package="langchain", symbol="init_chat_model")` |
| `azure_openai` (provider prefix) | — | **The exact prefix string.** `init_chat_model("azure_openai:gpt-5.5", ...)`, or `model_provider="azure_openai"`. Requires `langchain-openai`. | `get_symbol("init_chat_model")` (provider table); `rg -n "azure_openai" /oss/python/` |
| `AzureChatOpenAI` | `from langchain_openai import AzureChatOpenAI` | `AzureChatOpenAI(azure_deployment=..., azure_endpoint=..., api_version=..., temperature=0, max_tokens=None, timeout=None, max_retries=2, ...)` | `get_symbol(package="langchain-openai", symbol="AzureChatOpenAI")` |
| `max_retries` | — | Documented init arg; `max_retries=2` in the reference's own instantiation example. Retries failed requests to the deployment. Companion client params: `timeout`, `max_tokens`. | `get_symbol("AzureChatOpenAI")` (Instantiate example + client params) |
| `azure_deployment` | — | Name of the Azure OpenAI **deployment** (not the model name). | `get_symbol("AzureChatOpenAI")` |
| `azure_endpoint` | — | `https://<resource>.openai.azure.com/`. Env fallback `AZURE_OPENAI_ENDPOINT`. | `get_symbol("AzureChatOpenAI")` (property list) |
| `api_version` | — | Azure REST API version, e.g. `"2025-03-01-preview"`. Env fallback `OPENAI_API_VERSION`. Property name is `openai_api_version`. | `get_symbol("AzureChatOpenAI")`; models.mdx lines 120–150 |
| `azure_ad_token_provider` | — | Callable returning a bearer token — **the managed-identity path.** Async variant: `azure_ad_async_token_provider`. | `get_symbol("AzureChatOpenAI")` (property list) |
| `api_key` / `openai_api_key` | — | Key auth. Env fallback `AZURE_OPENAI_API_KEY`. Prefer managed identity in deployed code. | `get_symbol("AzureChatOpenAI")` |
| `temperature` | — | `temperature=0` — pass as a constructor kwarg on `AzureChatOpenAI`, or as a `**kwargs` passthrough on `init_chat_model`. | `get_symbol("AzureChatOpenAI")`; `get_symbol("init_chat_model")` |
| `usage_metadata` | — | **Token usage.** `ai_msg.usage_metadata` → `{"input_tokens": int, "output_tokens": int, "total_tokens": int}` | `get_symbol("AzureChatOpenAI")` (Token usage section) |
| `response_metadata` | — | `ai_msg.response_metadata` → provider dict: `token_usage`, `model_name`, `finish_reason`, `content_filter_results`, `prompt_filter_results`. | `get_symbol("AzureChatOpenAI")` |
| `model.profile` | — | Capability dict; `structured_output` key drives strategy selection. Requires `langchain>=1.1`. | `rg -A10 "Model profiles" /oss/python/langchain/models.mdx` |
| `with_structured_output` | — | `model.with_structured_output(Schema, include_raw=False)` — model-level structured output, **outside** `create_agent`. Inside an agent use `response_format`. | `get_symbol("AzureChatOpenAI")` (Methods); models.mdx |

**Environment variables:** `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`,
`OPENAI_API_VERSION`, plus `AZURE_OPENAI_DEPLOYMENT_NAME` as used in the docs' examples.

**Azure content filtering** surfaces in `response_metadata` under `content_filter_results`
and `prompt_filter_results`. Tickets touching moderation should read those keys.

---

## 5. Tools

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `tool` (decorator) | `from langchain.tools import tool` (also `from langchain_core.tools import tool`) | `tool(name_or_callable=None, runnable=None, *, description=None, return_direct=False, args_schema=None, infer_schema=True, response_format='content', parse_docstring=False, error_on_invalid_docstring=True, extras=None)` | `get_symbol(package="langchain-core", symbol="langchain_core.tools.convert.tool")` |
| `parse_docstring` | — | **Default `False`.** With `infer_schema` and `parse_docstring=True`, parameter descriptions are parsed from **Google-style** docstrings into the tool schema. | `get_symbol("langchain_core.tools.convert.tool")` |
| `error_on_invalid_docstring` | — | **Default `True`** — with `parse_docstring=True`, a malformed Google-style docstring raises `ValueError`. This is a real build-break risk; tickets mandating `parse_docstring=True` must mandate Google-style docstrings with it. | `get_symbol("langchain_core.tools.convert.tool")` |
| `response_format` (tool kwarg) | — | `'content'` (default) or `'content_and_artifact'`. **This is how a tool returns a value the model sees vs. data it must not see:** with `'content_and_artifact'` the function returns a two-tuple `(content, artifact)`; `content` becomes the `ToolMessage` body the model reads, `artifact` is carried on the `ToolMessage` and is not shown to the model. | `get_symbol("langchain_core.tools.convert.tool")` |
| `return_direct` | — | `bool`, default `False`. `True` short-circuits the agent loop and returns the tool output to the caller. | `get_symbol("langchain_core.tools.convert.tool")` |
| `args_schema` / `infer_schema` | — | Explicit Pydantic arg schema, or inference from type hints (default on). | `get_symbol("langchain_core.tools.convert.tool")` |
| `ToolRuntime` | `from langchain.tools import ToolRuntime` | Add `runtime: ToolRuntime` to a tool signature. Injected by `ToolNode`; **excluded from the schema sent to the model.** Exposes `.state`, `.context`, `.store`, `.tool_call_id`. Generic: `ToolRuntime[ContextT, StateT]`. | `rg -n "ToolRuntime" /oss/python/langchain/tools.mdx` (lines 125–135, 203–253) |
| `Command` | `from langgraph.types import Command` | **How a tool writes state the model must not see.** `Command(update={...})`. When targeting the current graph, the update **must** include a `ToolMessage` whose `tool_call_id` matches `runtime.tool_call_id`, or `ToolNode` raises `ValueError`. | tools.mdx lines 595–640 |
| `ToolMessage` | `from langchain.messages import ToolMessage` | `ToolMessage(content=..., tool_call_id=runtime.tool_call_id)` | tools.mdx lines 608–625 |

**Reserved argument names — do not use as tool parameters:** `config`, `run_manager`,
`callbacks`, `runtime`. A `config` parameter fails at call time with `TypeError`;
`run_manager` and `callbacks` are silently dropped from the generated schema.

---

## 6. Pydantic (v2 — confirmed 2.13.5)

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `BaseModel` | `from pydantic import BaseModel` | Base class for static schemas. | `WebFetch(pydantic.dev/docs/validation/latest/api/pydantic/base_model/)` |
| `Field` | `from pydantic import Field` | `Field(description="...")` — the description is what reaches the provider. | `WebFetch(pydantic json_schema concepts page)` |
| `create_model` | `from pydantic import create_model` | `create_model(model_name, /, *, __config__=None, __doc__=None, __base__, __module__=__name__, __validators__=None, __cls_kwargs__=None, __qualname__=None, **field_definitions)` | `WebFetch(pydantic.dev/docs/validation/latest/api/pydantic/base_model/)` |
| `field_definitions` | — | `**field_definitions: Any \| tuple[Any, Any]` — each value is a bare type, or a two-tuple `(type, Field(...))`. | same |
| `model_json_schema` | — | `Model.model_json_schema()` → jsonable dict. `Field(description=...)` appears as a `"description"` key on each entry under `properties`. | `WebFetch(pydantic json_schema concepts page)` |
| `ConfigDict` | `from pydantic import ConfigDict` | Passed as `__config__` to `create_model`. | `WebFetch(base_model page)` |
| pydantic version | — | **2.13.5** (latest release as of 2026-08-28). Pydantic v2 confirmed. | `WebFetch(pypi.org/pypi/pydantic/json)` |

### Settings — `pydantic-settings` (separate package)

**All rows below are web-verified**, not MCP — the LangChain servers do not index Pydantic.

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `pydantic-settings` (package) | `pip install pydantic-settings` | **`BaseSettings` moved out of core Pydantic into its own package.** It is **not** importable from `pydantic`. Latest release **2.15.0**; requires Python ≥3.10 and `pydantic>=2.7.0`. | **web:** `WebFetch(pydantic.dev/docs/validation/latest/concepts/pydantic_settings/)`; `WebFetch(pypi.org/pypi/pydantic-settings/json)` |
| `BaseSettings` | `from pydantic_settings import BaseSettings` | Subclass it; each field is read from the environment, falling back to the field default. | **web:** `WebFetch(pydantic_settings concepts page)` |
| `SettingsConfigDict` | `from pydantic_settings import SettingsConfigDict` | Assigned to `model_config` on the settings class. | **web:** `WebFetch(pydantic_settings concepts page)` |
| field default | — | Plain Python assignment: `my_var: str = 'default_value'`. No `Field(...)` wrapper needed for a bare default; use `Field(description=...)` when the field also needs documenting. | **web:** `WebFetch(pydantic_settings concepts page)` |
| `env_file` | — | `model_config = SettingsConfigDict(env_file='.env')`. Any valid path or filename, absolute or relative to the current working directory. | **web:** `WebFetch(pydantic_settings concepts page)` |

Minimal form, verbatim from the Pydantic documentation:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env')

    my_var: str = 'default_value'
```

**This is the base class for `core/settings.py`.** It is what makes the "every tunable is a
field default, and `os.environ` appears in exactly one module" rule enforceable: `BaseSettings`
does the environment reading, so application modules never call `os.environ` themselves.

**How field descriptions reach the provider:** `Field(description=...)` →
`model_json_schema()` emits `properties.<field>.description` → LangChain passes that JSON
Schema to the provider as the structured-output schema (`ProviderStrategy`) or the tool
schema (`ToolStrategy`). The description is the only per-field instruction the model sees,
so it is load-bearing, not documentation.

---

## 7. Azure SDK

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `ManagedIdentityCredential` | `from azure.identity import ManagedIdentityCredential` | `ManagedIdentityCredential(*, client_id=None, identity_config=None, **kwargs)`. **The class for managed identity in an Azure Function.** Defaults to the system-assigned identity; pass `client_id` for a user-assigned one. | `WebFetch(learn.microsoft.com/.../azure.identity.managedidentitycredential)` |
| `DefaultAzureCredential` | `from azure.identity import DefaultAzureCredential` | Chained credential: managed identity in Azure, developer credentials locally. Use when the same code runs in both places. | `WebSearch` + Key Vault README `WebFetch` |
| `get_bearer_token_provider` | `from azure.identity import get_bearer_token_provider` | `get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")` → callable for `AzureChatOpenAI(azure_ad_token_provider=...)`. Async: `azure.identity.aio.get_bearer_token_provider`. | `WebSearch(get_bearer_token_provider AzureChatOpenAI)` |
| `azure.identity.aio` | `from azure.identity.aio import DefaultAzureCredential` | Async credentials. Must be closed (`await credential.close()`) or used as async context managers. | Key Vault README `WebFetch` |
| `SecretClient` | `from azure.keyvault.secrets import SecretClient` | `SecretClient(vault_url=..., credential=...)`; `.get_secret(name)`, `.set_secret(name, value)`, `.begin_delete_secret(name)`, `.list_properties_of_secrets()`. Package `azure-keyvault-secrets`. | `WebFetch(learn.microsoft.com/.../keyvault-secrets-readme)` |
| `SecretClient` (async) | `from azure.keyvault.secrets.aio import SecretClient` | Same surface, awaitable. | same |
| `BlobServiceClient` | `from azure.storage.blob import BlobServiceClient` | `BlobServiceClient(account_url="https://<acct>.blob.core.windows.net", credential=...)`; also `.from_connection_string(conn_str=...)`. Package `azure-storage-blob`. | `WebFetch(learn.microsoft.com/.../storage-blob-readme)` |
| `ContainerClient` | `from azure.storage.blob import ContainerClient` | Per-container client; `.create_container()`, `.list_blobs()`, `.get_blob_client(...)`. | same |
| `BlobClient` | `from azure.storage.blob import BlobClient` | Per-blob client; `.upload_blob(data)`, `.download_blob()`. | same |
| `azure.storage.blob.aio` | `from azure.storage.blob.aio import BlobServiceClient, ContainerClient, BlobClient` | Async variants; require an async transport (`aiohttp`). | same |
| `ResourceNotFoundError` | `from azure.core.exceptions import ResourceNotFoundError` | Raised by Key Vault / Storage clients for a missing resource. | Key Vault README `WebFetch` |
| `mssql_python` | `import mssql_python` | **Microsoft's current Python driver for Azure SQL Database.** PEP 249. Direct Database Connectivity (DDBC) — no external driver manager. Python 3.10+. `mssql_python.connect(conn_str)`, `.Cursor`, `.OperationalError`, `.Error`. Package `mssql-python`. | `WebFetch(learn.microsoft.com/.../python-sql-driver-mssql-python)` |
| `pyodbc` | `import pyodbc` | The established alternative, still documented — Microsoft publishes a "Migrate from pyodbc" guide. Requires ODBC Driver 18 for SQL Server installed separately. | same page (migration index) |
| Azure SQL managed-identity connection string | — | `"Server=<srv>.database.windows.net;Database=<db>;Authentication=ActiveDirectoryMsi;Encrypt=strict;ConnectRetryCount=3;ConnectRetryInterval=10;"`, plus `UID=<client_id>;` for a user-assigned identity. | same page (production baseline sample) |
| `configure_azure_monitor` | `from azure.monitor.opentelemetry import configure_azure_monitor` | **OpenTelemetry → Azure Monitor entry point.** Package `azure-monitor-opentelemetry` (the Azure Monitor OpenTelemetry Distro). Reads `APPLICATIONINSIGHTS_CONNECTION_STRING`. Python 3.10+. | `WebFetch(learn.microsoft.com/.../opentelemetry-enable?tabs=python)` |

### Inbound Entra ID token validation — this is NOT `azure-identity`

`azure-identity` acquires **outbound** credentials (this service authenticating to Azure).
Validating an **inbound** bearer token presented by a caller is a different problem and a
different package. Do not conflate them in a ticket.

**There is no Microsoft-published Python library for validating inbound tokens.** Microsoft's
own guidance states that "doing signature validation is outside the scope of this document"
and points to open-source libraries; it names `Microsoft.Identity.Web` only for ASP.NET /
ASP.NET Core. MSAL Python acquires tokens, it does not validate them. **The answer for Python
is the general-purpose library PyJWT**, driven by Entra's published JWKS endpoint.

**All rows below are web-verified**, not MCP.

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `PyJWT` (package) | `pip install pyjwt` | The JWT library. The import name is `jwt`. `pip install pyjwt[crypto]` for RS256 support. | **web:** `WebFetch(pyjwt.readthedocs.io/en/stable/usage.html)` |
| `PyJWKClient` | `from jwt import PyJWKClient` | `PyJWKClient(uri, cache_keys=False, max_cached_keys=16, cache_jwk_set=True, lifespan=300, headers=None, timeout=30, ssl_context=None, cooldown_duration=30)` | **web:** `WebFetch(pyjwt.readthedocs.io/en/stable/api.html)` |
| `get_signing_key_from_jwt` | — | `get_signing_key_from_jwt(token: str \| bytes) -> PyJWK`. Reads `kid` from the token's **unverified** header and resolves the matching key from the JWK set. | **web:** `WebFetch(pyjwt api.html)` |
| `jwt.decode` | `import jwt` | `jwt.decode(token, key, algorithms=["RS256"], audience=..., issuer=...)` | **web:** `WebFetch(pyjwt usage.html)` |
| `cache_jwk_set` | — | **Default `True`** — the JWK set is cached. | **web:** `WebFetch(pyjwt api.html)` |
| `lifespan` | — | **Default `300`** seconds — how long the cached JWK set stays fresh. | **web:** `WebFetch(pyjwt api.html)` |
| `cache_keys` | — | Default `False`. Caches individual resolved signing keys (LRU, `max_cached_keys=16`). Distinct from `cache_jwk_set`. | **web:** `WebFetch(pyjwt api.html)` |
| Entra OIDC metadata URL | — | `https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration` for a v2.0 token; drop `/v2.0` for a v1.0 token. **The token's `ver` claim decides which.** | **web:** `WebFetch(learn.microsoft.com/entra/identity-platform/access-tokens)` |
| `jwks_uri` | — | Property of the OIDC metadata document giving the JWKS location, e.g. `https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys`. This is the `uri` passed to `PyJWKClient`. | **web:** same |
| Claims to validate | — | Signature (select the key by `kid`), `aud` (must be one of this API's AppId URIs), `iss`, and for multitenant also `tid` plus the signing-key issuer. `exp` / `nbf` are enforced by `jwt.decode` by default. | **web:** same |

**Caching is the point, and it lives on the instance.** `PyJWKClient` caches the JWK set by
default (`cache_jwk_set=True`, `lifespan=300`). That cache is **per-instance state** — so a
second `PyJWKClient` object means a second cold JWKS fetch and a second independent cache,
on every cold start and then every 300 seconds. This is exactly the cost the code standard's
"a second JWKS fetch" example is describing. Construct it **once** at module scope and reuse
it; do not build one per request or per handler.

Microsoft separately advises that "a reasonable frequency to check for updates to the public
keys used by Microsoft Entra ID is every 24 hours" — the PyJWT default of 300 seconds is well
inside that, so the default needs no tuning. Entra rotates signing keys on a schedule, so the
client must be allowed to refresh; never pin a key.

### Azure SQL async execution path — read this before writing a ticket

**There is no native async driver for Azure SQL from Python in Microsoft's documentation.**
`mssql-python` is a synchronous PEP 249 driver. Its own documentation describes async
support as: *"Use the driver with `asyncio`-based applications and FastAPI through
ThreadPoolExecutor workarounds."*

The async execution path is therefore **offloading blocking calls to a thread**:

```python
import asyncio
import mssql_python

async def fetch_rows(conn_str: str, sql: str, *params):
    def _run():
        with mssql_python.connect(conn_str) as conn:
            cursor = mssql_python.Cursor(conn, timeout=10)
            cursor.execute(sql, *params)
            return cursor.fetchall()
    return await asyncio.to_thread(_run)
```

Any ticket that says "async Azure SQL" must mean this. Do not name an `async`/`await`
native SQL driver — see DO-NOT-USE.

---

## 8. Working reference snippets

All snippets below are Azure OpenAI. Where the LangChain source example used another
provider, it was **translated to Azure OpenAI**; the originals were not copied.

### 8.1 Agent with structured output

*Translated: the docs' example used a non-Azure model string; the model construction here
is the Azure OpenAI form from `models.mdx`, and the schema/agent wiring is unchanged.*

```python
import os

from langchain.agents import create_agent
from langchain.agents.structured_output import ProviderStrategy
from langchain_openai import AzureChatOpenAI
from pydantic import BaseModel, Field


class LeaveDecision(BaseModel):
    """Structured outcome of a leave request review."""

    approved: bool = Field(description="Whether the leave request is approved")
    reason: str = Field(description="One-sentence justification for the decision")
    days_deducted: int = Field(description="Number of leave days to deduct")


model = AzureChatOpenAI(
    azure_deployment=os.environ["AZURE_OPENAI_DEPLOYMENT_NAME"],
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_version=os.environ["OPENAI_API_VERSION"],
    temperature=0,
)

agent = create_agent(
    model=model,
    tools=[],
    system_prompt="You review employee leave requests against policy.",
    response_format=ProviderStrategy(LeaveDecision),
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "Ravi requests 3 days from Monday."}]}
)

decision = result["structured_response"]   # LeaveDecision instance
print(decision.approved, decision.days_deducted)
```

### 8.2 Middleware class implementing two hooks

*Translated: adapted from the docs' class-form example; hook names, `hook_config`,
`jump_to` and the state-subclass pattern are exactly as documented.*

```python
from typing import Any

from langchain.agents.middleware import AgentMiddleware, AgentState, hook_config
from langchain.messages import AIMessage
from langgraph.runtime import Runtime
from typing_extensions import NotRequired


class AuditState(AgentState):
    """Agent state plus an audit counter."""

    model_calls: NotRequired[int]


class LeaveAuditMiddleware(AgentMiddleware):
    state_schema = AuditState

    def __init__(self, max_model_calls: int = 10) -> None:
        super().__init__()
        self.max_model_calls = max_model_calls

    @hook_config(can_jump_to=["end"])
    def before_model(self, state: AuditState, runtime: Runtime) -> dict[str, Any] | None:
        if state.get("model_calls", 0) >= self.max_model_calls:
            return {
                "messages": [AIMessage("Model call budget exhausted.")],
                "jump_to": "end",
            }
        return None

    def after_model(self, state: AuditState, runtime: Runtime) -> dict[str, Any] | None:
        return {"model_calls": state.get("model_calls", 0) + 1}
```

### 8.3 Dynamic `create_model`

```python
from pydantic import BaseModel, Field, create_model

field_spec = {
    "employee_id": (str, Field(description="Workday employee identifier")),
    "leave_days": (int, Field(description="Number of leave days requested")),
    "manager_note": (str | None, Field(default=None, description="Optional manager note")),
}

LeaveRequest = create_model(
    "LeaveRequest",
    __base__=BaseModel,
    __doc__="A leave request extracted from free-text input.",
    **field_spec,
)

schema = LeaveRequest.model_json_schema()
assert schema["properties"]["leave_days"]["description"] == "Number of leave days requested"
```

Pass `LeaveRequest` straight into `ProviderStrategy(LeaveRequest)`.

### 8.4 Azure OpenAI chat model from config, with managed identity

*Translated: the managed-identity wiring comes from the Azure Identity docs; the LangChain
model construction comes from `models.mdx` and the `AzureChatOpenAI` reference.*

```python
import os

from azure.identity import ManagedIdentityCredential, get_bearer_token_provider
from langchain_openai import AzureChatOpenAI


def build_chat_model() -> AzureChatOpenAI:
    """Azure OpenAI chat model authenticated with the Function's managed identity."""
    credential = ManagedIdentityCredential(
        client_id=os.getenv("AZURE_CLIENT_ID")  # omit for a system-assigned identity
    )
    token_provider = get_bearer_token_provider(
        credential, "https://cognitiveservices.azure.com/.default"
    )
    return AzureChatOpenAI(
        azure_deployment=os.environ["AZURE_OPENAI_DEPLOYMENT_NAME"],
        azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
        api_version=os.environ["OPENAI_API_VERSION"],
        azure_ad_token_provider=token_provider,
        temperature=0,
        max_retries=2,
    )


model = build_chat_model()
response = model.invoke("ping")
print(response.usage_metadata)  # {'input_tokens': ..., 'output_tokens': ..., 'total_tokens': ...}
```

Env-var-only alternative (string form, no explicit class):

```python
import os

from langchain.chat_models import init_chat_model

# Requires AZURE_OPENAI_API_KEY, AZURE_OPENAI_ENDPOINT, OPENAI_API_VERSION.
model = init_chat_model(
    "azure_openai:gpt-5.5",
    azure_deployment=os.environ["AZURE_OPENAI_DEPLOYMENT_NAME"],
    temperature=0,
)
```

---

## 9. DO-NOT-USE

| Symbol | What it was | Use instead |
|---|---|---|
| `create_react_agent` (`langgraph.prebuilt`) | The LangGraph v0 agent factory. **Reference explicitly marks it deprecated in favor of `create_agent`.** | `from langchain.agents import create_agent` |
| `create_react_agent` (`langchain_classic`) | The original ReAct-paper agent. Reference warns it is "older and not well-suited for production applications." | `create_agent` |
| `prompt=` on `create_agent` | Not a parameter. | `system_prompt=` |
| `InjectedState` | Legacy state injection into tools. Docs: *"Older examples used `InjectedState`... Use `ToolRuntime` instead."* | `runtime: ToolRuntime`, then `runtime.state` |
| `InjectedStore` | Legacy store injection. | `runtime.store` |
| `InjectedToolCallId` | Legacy tool-call-id injection. | `runtime.tool_call_id` |
| `get_runtime()` | Legacy runtime accessor inside tools. | `runtime: ToolRuntime` parameter |
| `config` / `run_manager` / `callbacks` / `runtime` as tool **parameter names** | Collide with injected values. `config` raises `TypeError` at call time; `run_manager` and `callbacks` are silently dropped from the schema. | Rename the parameter; use `ToolRuntime` for runtime data |
| A bare JSON-Schema `dict` passed to `response_format` | Not auto-detected — no strategy is selected. | Wrap: `ProviderStrategy(schema_dict)` or `ToolStrategy(schema_dict)` (must have top-level `title` and `description`) |
| `raise` / a custom exception to end an agent run from a hook | Not the abort mechanism. An exception propagates as a failure, does not end the run cleanly, and **skips `after_agent` — destroying the audit row for the blocked run.** | `return {"jump_to": "end"}` with `can_jump_to=["end"]` declared, letting `after_agent` write the audit |
| `jump_to` without `can_jump_to` | The conditional edge is never wired, so the jump does not happen. | Declare `@hook_config(can_jump_to=[...])` or `@before_model(can_jump_to=[...])` |
| Any AWS package, service or identifier — `boto3`, Bedrock, Aurora, Cognito, S3, `langchain-aws`, the `bedrock` / `bedrock_converse` / `anthropic_bedrock` provider prefixes | The platform is Azure only. LangChain's `init_chat_model` provider table lists these; they are out of scope by constraint. | `azure_openai` prefix; `AzureChatOpenAI`; Azure Blob Storage; Azure SQL; Microsoft Entra ID |
| `aioodbc` / any "async Azure SQL driver" | Not documented by Microsoft as the Azure SQL async path. | `mssql-python` (or `pyodbc`) called through `asyncio.to_thread` |
| `opencensus-ext-azure` | The pre-OpenTelemetry Azure Monitor exporter. Microsoft publishes a migrate-from-OpenCensus guide. | `azure-monitor-opentelemetry` / `configure_azure_monitor` |

### Negative results — things checked for and not found

* **No hook named `on_model_call`, `pre_model`, `post_model`, `on_tool_call` or
  `modify_model_request`.** The six hooks in §3 are the complete node/wrap hook set on
  `AgentMiddleware`, each with an `a`-prefixed async twin.
* **No `AgentMiddleware.abort()` / `AgentAbort` / `StopAgent` sentinel class.** Aborting is
  the `jump_to` state key only.
* **No `langchain.agents.middleware.AgentMiddlewareBase`.** The base class is
  `AgentMiddleware`.
* **`ToolStrategy` and `ProviderStrategy` are not exported from `langchain.agents`.** Their
  documented import is `langchain.agents.structured_output`.
* **`parse_docstring` does not default to `True`.** It defaults to `False`; tickets must
  set it explicitly.
* **No documented example of `@tool` on a `@staticmethod`, or on any method.** The string
  `staticmethod` does not occur anywhere in the Python documentation set
  (`rg -ln "staticmethod" /` over the whole docs filesystem returns nothing), and an API
  reference search returns no relevant symbol. **Every documented `@tool` example is a
  module-level function.** This means the upstream docs are silent, **not** that the code
  standard's `@staticmethod` rule is wrong — see Unverified #6. Only the stacking order is
  open, and it must not be guessed.

---

## 10. Unverified — do not let a ticket assert these

1. **That Azure OpenAI's model profile reports `structured_output: True` for the specific
   deployment this project uses.** The *rule* is verified (profile-driven selection) and
   the LangChain Azure integration page lists structured output as supported, but profile
   data is per-model and comes from an upstream dataset (models.dev plus package
   augmentations). It was not possible to read the shipped profile for a named Azure
   deployment through the docs servers. **Mitigation already baked into §2:** pass
   `ProviderStrategy(Schema)` explicitly so selection does not depend on inference. A
   ticket should still include a runtime assertion that the strategy in force is the
   provider one before the design's "malformed JSON is impossible" claim is relied on.
2. **Whether `ProviderStrategy(strict=True)` is accepted by the Azure OpenAI deployment and
   API version in use.** `strict` is documented as provider-dependent and requires
   `langchain>=1.2`; the installed `langchain` minor version for this project was not
   confirmed. Treat `strict=True` as needing a spike, not a ticket.
3. **The exact installed versions of `langchain`, `langchain-openai` and the Azure SDK
   packages.** No dependency manifest was present to read; entries reflect current
   published documentation. Pin versions in the repo before the first ticket lands.
4. **`AzureChatOpenAI` structured-output behaviour under an older `api_version`.** Native
   JSON-schema enforcement is API-version dependent on Azure. The version string in §4 is
   the one used in the current LangChain docs examples, not a tested minimum.
5. **`ToolRuntime` generic parameter order.** Both `ToolRuntime[UserContext]` and
   `ToolRuntime[None, CustomState]` appear in the documentation examples, implying
   `ToolRuntime[ContextT, StateT]`, but the class's own reference page was not retrieved to
   confirm the declaration. Tickets should use the unparameterised `ToolRuntime` unless a
   typed state is genuinely needed.
6. **The decorator stacking order for `@tool` on a `@staticmethod`.** Searched for and **not
   found.** The string `staticmethod` does not appear anywhere in the LangChain Python
   documentation set, and the API reference has no relevant symbol; every documented `@tool`
   example is a module-level function, never a method of any kind.

   **Scope of this negative result — read before citing it.** It says the upstream
   documentation is silent, and nothing more. It is **not** evidence against the code
   standard's rule that tools are `@staticmethod` because `@tool` on an instance method puts
   `self` into the schema the model sees. That rule is about Python's own descriptor
   behaviour, which LangChain's docs have no need to restate; the rule stands, and it is
   simply undocumented upstream. What is open is narrower: **which of the two decorators goes
   outermost.** Do not let this entry be read as licence to drop `@staticmethod`.

   **Neither ordering —
   `@tool` above `@staticmethod` nor `@staticmethod` above `@tool` — is documented, so
   neither may be asserted by a ticket.** This is deliberately left open rather than reasoned
   out from Python decorator semantics: the two orderings differ in what `@tool` receives (a
   `staticmethod` descriptor object versus a plain function), and getting it wrong produces a
   malformed or empty argument schema that presents at runtime as a model failure rather than
   a code failure — expensive to diagnose from the symptom. **Resolve it with a one-off
   empirical check** (construct the tool both ways, print `tool.args_schema.model_json_schema()`,
   confirm the parameters appear and `self`/`cls` does not) and record the result here before
   any ticket names an ordering.

7. **The exception `HttpRequest.get_json()` raises on a malformed body.** The `azure.functions`
   reference documents the method as `get_json() -> Any` and names no exception. A ticket may
   not name one. Validate at the boundary and record the real behaviour once measured against
   the running host.
8. **Whether `HttpRequest.headers` lookup is case-insensitive.** The reference lists `headers`
   as an attribute and the constructor takes `Mapping[str, str]`; nothing states the lookup
   semantics. A ticket must not depend on a particular header casing surviving.
9. **`asyncio.to_thread` is never named in Microsoft's Azure Functions Python documentation.**
   The offload form Microsoft publishes is `await loop.run_in_executor(None, fn, *args)`
   (`python-scale-performance-reference`). §7 already fixes `asyncio.to_thread` as this
   repository's spelling for the Azure SQL path; that choice rests on the Python standard
   library, not on an Azure document. Do not cite Microsoft for it.
10. **Whether a Python v2 project may hold more than one `func.FunctionApp()` instance.** Learn
    documents exactly one `app` in `function_app.py`, with `func.Blueprint()` +
    `app.register_functions(bp)` as the way to split functions across modules. No explicit
    prohibition on a second instance was retrievable. Use one `FunctionApp` and blueprints; do
    not let a ticket assert the single-instance rule as documented.
11. **How `auth_level` composes with inbound Entra token validation (§7, PyJWT).** `AuthLevel`
    governs Functions *access keys* only — `anonymous` / `function` / `admin`. Nothing retrieved
    states how it interacts with a bearer token validated inside the handler, or with App
    Service Authentication. On the evidence available they are independent mechanisms; a ticket
    must not claim one replaces the other without a spike.
12. **Measured cold-start time for this container image on a Premium plan.** Learn states that
    custom containers "have a long warm-up time" and that the language worker process has a
    non-configurable 60-second start ceiling, but publishes no number for a Python image
    carrying LangChain. `preWarmedInstanceCount` and `minimumElasticInstanceCount` must be set
    from a measurement, not from a guess — see §11.6.

---

## 11. HTTP surface — Azure Functions Python

**All rows in this section are web-verified against `learn.microsoft.com`**, not MCP — the
LangChain servers do not index Azure Functions. Every row carries the **web:** marker and the
page that produced it. This section is the allow-list for the two endpoints
`POST /ai/encounter/extract` and `POST /ai/encounter/resolve`; before it existed, no HTTP
symbol was verified and those stories had to be written behaviourally.

**Provenance note.** The Flask sample page links to a "Web frameworks" section of the Python
developer reference (`functions-reference-python#web-frameworks`). **That anchor no longer
exists** — the page was refactored (`ms.date: 2026-08-27`, `ms.custom: py-devguide-refactor`)
and the section is gone from both pivots. The ASGI/WSGI rows in §11.5 are therefore verified
from the `azure.functions` API reference pages and the Flask sample, which are current. Do not
cite the dead anchor.

### 11.1 Which programming model is current

| Model | Shape | Status | Verified by |
|---|---|---|---|
| **v2 (2.x)** | Decorator-based. Triggers and bindings declared in code; each function is a global, stateless method in `function_app.py` or a registered blueprint file. | **"This model version is recommended for new Python apps."** | **web:** `WebFetch(learn.microsoft.com/azure/azure-functions/functions-reference-python)` — "Programming model" table |
| v1 (1.x) | A `function.json` per function directory; the function is `main()` in `__init__.py`. | "This version of the model supports legacy apps." | same |

**Use v2.** Two features this service may want are v2-only: SDK type bindings ("SDK type
bindings support for Python is only available in the Python v2 programming model") and HTTP
streams ("HTTP streams is only supported for the Python v2 programming model").

Project layout for v2 (verified, same page): `function_app.py` at the project root is the
entry point and is required; `host.json` is required; `requirements.txt`, `local.settings.json`,
`.funcignore` and `Dockerfile` are optional. **Python is Linux-only on Functions** — "Linux is
the only supported operating system for the Python runtime stack."

### 11.2 Package, app object, HTTP trigger, route, auth level

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `azure-functions` (package) | `import azure.functions as func` | **The package name is `azure-functions`; the import name is `azure.functions`.** It "defines the programming surface for Python Azure Functions, but it isn't a general-purpose SDK." Must be listed as a project dependency. Do **not** add `azure-functions-worker` — the platform manages the worker. | **web:** `WebFetch(functions-reference-python)`; `WebFetch(learn.microsoft.com/samples/azure-samples/flask-app-on-azure-functions/...)` |
| `FunctionApp` | `app = func.FunctionApp(...)` | `FunctionApp(http_auth_level: AuthLevel \| str = AuthLevel.FUNCTION)`. **The app object.** Declared at module scope in `function_app.py`. | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.functionapp)` |
| `Blueprint` | `bp = func.Blueprint()` | Same decorator surface as `FunctionApp`, but not indexed on its own. Register with `app.register_functions(bp)` in `function_app.py`. **This is the documented way to split functions across modules.** | **web:** `WebFetch(functions-reference-python)` — "Organizing with blueprints" |
| `@app.route` | — | `route(route: str \| None = None, methods: tuple[str, ...] \| None = None, auth_level: AuthLevel \| str \| None = None, trigger_arg_name: str \| None = None, binding_arg_name: str \| None = None, trigger_extra_fields: dict \| None = None, binding_extra_fields: dict \| None = None) -> Callable[[...], Any]`. **The HTTP-trigger decorator.** It adds both the `HttpTrigger` and the `HttpOutput` binding. | **web:** `WebFetch(azure.functions.functionapp)` (method signature); `WebFetch(learn.microsoft.com/azure/azure-functions/functions-bindings-http-webhook-trigger?pivots=programming-language-python)` (property table) |
| `route` (param) | — | "Route for the http endpoint. If None, it will be set to function name if present or user-defined python function name." Route template syntax is ASP.NET Core routing: `products/{product_id}`, `products/{category}/{id}`. | **web:** `WebFetch(functions-bindings-http-webhook-trigger)` |
| `methods` (param) | — | "A tuple of the HTTP methods to which the function responds." The docs' own Python examples pass a **list**: `methods=["GET"]` and `methods=[func.HttpMethod.GET]`. If omitted, the function responds to all HTTP methods. | **web:** same page; `WebFetch(functions-reference-python)` |
| `auth_level` (param) | — | Which Functions access key must be on the request. **When not set explicitly, authorization defaults to the `function` level.** | **web:** `WebFetch(functions-bindings-http-webhook-trigger)` — "Authorization level" |
| `trigger_arg_name` (param) | — | "Argument name for HttpRequest. The default value is `'req'`." | **web:** same |
| `binding_arg_name` (param) | — | "Argument name for HttpResponse. The default value is `'$return'`." | **web:** same |
| `AuthLevel` | `func.AuthLevel` | Enum. **Exactly three members: `ADMIN`, `ANONYMOUS`, `FUNCTION`.** `anonymous` = no access key; `function` = a function-specific key; `admin` = the master key. | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.authlevel)`; `WebFetch(functions-bindings-http-webhook-trigger)` |
| `HttpMethod` | `func.HttpMethod` | Enum. **Members: `DELETE`, `GET`, `HEAD`, `OPTIONS`, `PATCH`, `POST`, `PUT`.** | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.httpmethod)` |
| `Context` | `func.Context` | "Function invocation context." Add `context` as a handler parameter to reach `context.invocation_id` and `context.thread_local_storage` — **required to keep logs from a background thread associated with the invocation.** | **web:** `WebFetch(functions-reference-python)` — "Logging from background threads" |
| route prefix | — | **All function routes are prefixed with `api` by default.** Change or remove it with `extensions.http.routePrefix` in `host.json`. Deployed URL: `https://<APP_NAME>.azurewebsites.net/api/<route>`. | **web:** `WebFetch(functions-bindings-http-webhook-trigger)` |
| `/admin`, `/runtime` | — | **Reserved by the Functions host.** "The host handles requests to these paths, and they never reach your functions; unmatched requests to them return HTTP 404." Only a concern once `routePrefix` is emptied. | **web:** same |

**What this means for the two endpoints.** With the default prefix, `@app.route(route="ai/encounter/extract", ...)` is served at `/api/ai/encounter/extract`. The paths in the stories are written without `/api`. **One of two things must be decided in the ticket, not left implicit:** either the .NET proxy targets `/api/ai/encounter/...`, or `host.json` sets `"extensions": {"http": {"routePrefix": ""}}` and the reserved-path rule above starts to apply. Do not assume.

### 11.3 Request in, JSON out

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `HttpRequest` | `func.HttpRequest` | `HttpRequest(method: str, url: str, *, headers: Mapping[str, str] \| None = None, params: Mapping[str, str] \| None = None, route_params: Mapping[str, str] \| None = None, body: bytes)`. **The request object.** The constructor is also how a unit test builds a mock request with no host running. | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.httprequest)` |
| `HttpRequest.get_json` | — | `get_json() -> Any`. **This is how the request body is read as JSON.** | **web:** same |
| `HttpRequest.get_body` | — | `get_body() -> bytes`. The raw body. | **web:** same |
| `HttpRequest.headers` | — | Attribute. **This is how request headers are read** — `req.headers.get("x-correlation-id")`. Declared `Mapping[str, str]` on the constructor. | **web:** same |
| `HttpRequest.params` | — | Attribute — query-string parameters. `req.params.get("value")`. | **web:** same; `WebFetch(functions-reference-python)` |
| `HttpRequest.route_params` | — | Attribute — route-template parameters. ⚠️ Docs, marked Important: **"In the Python v2 model, don't add route parameters as extra function arguments. Read them from `req.route_params` instead."** | **web:** `WebFetch(functions-reference-python)` |
| `HttpRequest.method` / `.url` / `.files` / `.form` | — | Remaining attributes on the class. | **web:** `WebFetch(azure.functions.httprequest)` |
| `HttpResponse` | `func.HttpResponse` | `HttpResponse(body: str \| bytes \| None = None, *, status_code: HTTPStatus \| int \| None = None, headers: Mapping[str, str] \| None = None, mimetype: str \| None = None, charset: str \| None = None)`. **The response object.** | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.httpresponse)` |
| `status_code` | — | "If not specified, defaults to 200. You can use an int status code or an `http.HTTPStatus` value." | **web:** same |
| `mimetype` | — | ⚠️ **"If not specified, defaults to `'text/plain'`."** A JSON response must pass `mimetype="application/json"` explicitly — serialising with `json.dumps` is not enough. | **web:** same |
| `charset` | — | "If not specified, defaults to `'utf-8'`." | **web:** same |
| `HttpResponse.get_body` | — | `get_body() -> bytes`. What a unit test asserts against. | **web:** same |
| default response | — | ⚠️ **"The default return value for an HTTP-triggered function is `HTTP 204 No Content` with an empty body."** A handler that falls off the end returns 204, not an error. | **web:** `WebFetch(functions-bindings-http-webhook-trigger)` |

### 11.4 Async handlers

| Fact | Detail | Verified by |
|---|---|---|
| Declaration | **`async def` on the handler, under `@app.route(...)`.** "To run a function asynchronously, use the `async def` statement, which runs the function with `asyncio` directly." The docs' own HTTP examples use `async def main(req: func.HttpRequest) -> func.HttpResponse` and `async def stream_sensor_data(req: Request)` under `@app.route`. | **web:** `WebFetch(learn.microsoft.com/azure/azure-functions/python-scale-performance-reference)`; `WebFetch(functions-bindings-http-webhook-trigger)` |
| What the worker does | "In our Python Worker, the worker shares the event loop with the customer's `async` function and it's capable for handling multiple requests concurrently." | **web:** `WebFetch(python-scale-performance-reference)` |
| Non-async handlers | "A function without the `async` keyword is run automatically in a ThreadPoolExecutor thread pool." Size is `PYTHON_THREADPOOL_THREAD_COUNT`; for Python ≥3.9 `max_worker` is `None`. | **web:** same |
| ⚠️ Sync I/O inside `async def` | "Using synchronous I/O operations in functions that are defined as asynchronous **may hurt** the overall performance." | **web:** same |
| ⚠️ `async` with no `await` | "If your function is declared as `async` without any `await` inside its implementation, the performance of your function will be severely impacted since the event loop will be blocked which prohibits the Python worker from handling concurrent requests." | **web:** same |
| Documented offload form | `await eventloop.run_in_executor(None, get, 'SAMPLE_URL')` — Microsoft's worked example wraps a blocking library call into a coroutine this way. | **web:** same |

**This is the join with §7.** `mssql-python` is synchronous, so the database call inside an
`async def` handler must leave the event loop. §7 fixes this repository's spelling as
`asyncio.to_thread`. Microsoft documents `run_in_executor` and **never names `asyncio.to_thread`
anywhere in the Functions Python documentation** — see §10 #9. Both dispatch to a thread; the
choice of spelling is a standard-library decision, and no ticket may attribute it to Microsoft.
The ⚠️ above is the reason the offload is mandatory rather than stylistic: a blocking SQL call
left on the worker's shared event loop stalls every other in-flight request on that instance.

### 11.5 Mounting FastAPI inside a Function — what it is, what it costs

The integration is called **web-framework hosting**, and it comes in two forms: ASGI (FastAPI)
and WSGI (Flask). "Azure Functions supports WSGI and ASGI-compatible frameworks with
HTTP-triggered Python functions."

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `AsgiFunctionApp` | `func.AsgiFunctionApp` | `AsgiFunctionApp(app, http_auth_level: AuthLevel \| str = AuthLevel.FUNCTION, function_name: str = 'http_app_func')`. `app` is the ASGI app object (a FastAPI instance). Module path `azure.functions.decorators.function_app.AsgiFunctionApp`. | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.decorators.function_app.asgifunctionapp)` |
| `WsgiFunctionApp` | `func.WsgiFunctionApp` | `WsgiFunctionApp(app, http_auth_level: AuthLevel \| str = AuthLevel.FUNCTION, function_name: str = 'http_app_func')`. `app` is the WSGI callable (for Flask, `flask_app.wsgi_app`). | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.decorators.wsgifunctionapp)`; Flask sample |
| `AsgiMiddleware` | `func.AsgiMiddleware` | `AsgiMiddleware(app)`, then `await func.AsgiMiddleware(app).handle_async(req, context)` inside a normal HTTP trigger. "This middleware is to adapt an ASGI supported Python server framework into Azure Functions." Also `notify_startup()` / `notify_shutdown()`. | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions.asgimiddleware)` |
| `AsgiMiddleware.handle` | — | ⚠️ **"Deprecated. Please use `handle_async` instead."** | **web:** same |
| `WsgiMiddleware` | `func.WsgiMiddleware` | The WSGI twin: `main = func.WsgiMiddleware(app.wsgi_app).main`. | **web:** `WebFetch(learn.microsoft.com/python/api/azure-functions/azure.functions)` |

**What it costs — all four items documented, none inferred:**

1. **The whole app collapses into one function.** The v2 `function_app.py` "uses
   `WsgiFunctionApp` to redirect **every** invocation to the Flask (WSGI) handler" and
   "automatically handles all routes and forwards them to Flask." That one function is named
   `http_app_func` by default and answers every verb — the sample's own local output reads
   `http_app_func: [GET,POST,DELETE,HEAD,PATCH,PUT,OPTIONS] http://localhost:7071/<route>`.
2. **Authorization becomes app-wide.** "The HTTP route and authorization level are configured
   directly on `WsgiFunctionApp` (via `http_auth_level`)." There is no per-route `auth_level`
   once the framework owns routing.
3. **`host.json` must empty the route prefix.** The sample "sets an empty HTTP `routePrefix` so
   the Flask routes are served from the root path" — which moves the app to the app root and
   activates the reserved `/admin` and `/runtime` rule from §11.2.
4. **The framework is a runtime dependency in the image.** It must be in the dependency
   manifest and therefore in the container, on every cold start.

**Recommendation: native `@app.route` with `func.HttpRequest` / `func.HttpResponse`. Do not
mount FastAPI.** Two POST endpoints behind a proxy need a path, a body and a status code —
exactly what `@app.route` already provides — and the ASGI path buys nothing for that while
collapsing both endpoints into one catch-all function with app-wide auth, forcing a
root-mounted route prefix, and adding a web framework to the cold-start cost of every
container instance.

**A separate thing that also says "FastAPI" — do not confuse them.** HTTP streams uses the
`azurefunctions-extensions-http-fastapi` package to expose FastAPI `Request` / `StreamingResponse`
types in a handler. It is not web-framework hosting and it is not needed here. ⚠️ It is
all-or-nothing per app: "when enabling HTTP streams, the function app will default to using HTTP
streaming, and the original HTTP functionality will not work", and "If you are using HTTP
streams, all HTTP functions in the app need to use streaming. Combining streaming and
non-streaming HTTP functions within the same app is not supported." Requires runtime ≥ 4.34.1
and `PYTHON_ENABLE_INIT_INDEXING=1` (not required on Python 3.13+).
Verified: **web:** `WebFetch(functions-bindings-http-webhook-trigger)` — "HTTP streams".

### 11.6 Traps on this path

| # | Trap | The fact | Verified by |
|---|---|---|---|
| 1 | ⚠️ **230 seconds is the real HTTP ceiling, whatever `functionTimeout` says.** | "Regardless of the function app timeout setting, 230 seconds is the maximum amount of time that an HTTP triggered function can take to respond to a request", because of the Azure Load Balancer idle timeout. "The function will continue running but will be unable to return an HTTP response" — the caller gets **HTTP 502**. | **web:** `WebFetch(learn.microsoft.com/azure/azure-functions/functions-scale)`; `WebFetch(functions-bindings-http-webhook-trigger)` — "Limits" |
| 2 | `functionTimeout` per plan | Default **30** minutes and maximum **unbounded** on Flex Consumption, Premium and Dedicated. Dedicated's unbounded requires **Always On**. Unbounded still has a 60-minute scale-in grace period (Flex/Premium) and 10 minutes during platform updates. All of it is moot for an HTTP response — see trap 1. | **web:** `WebFetch(functions-scale)` — "Function app timeout duration" |
| 3 | ⚠️ **60-second worker start ceiling** | "There's a maximum timeout of 60 seconds for the language-specific worker process to also start. The worker process startup timeout isn't currently configurable." Everything at module scope in `function_app.py` — imports, the compiled agent, any client built eagerly — is spent inside that budget. This is the platform reason behind the repository's rule that `__init__` builds nothing and every expensive member is a `cached_property`. | **web:** `WebFetch(functions-scale)` |
| 4 | Request size / URL limits | **Max request size 210 MB. Max query string length 4096. Max request URL length 8192.** Identical across Flex Consumption, Premium, Dedicated/ASE, Container Apps and Consumption; "These limits are set in the host." | **web:** `WebFetch(functions-scale)` — "Service limits" |
| 5 | ⚠️ **Flex Consumption cannot run a container.** | Hosting-options table: Flex Consumption container support is **"None"**; OS table: "✅ Code-only ❌ Container (not supported)". Functions-hosted containers run on **Premium (Elastic Premium)** or **Dedicated (App Service)** only; Azure Container Apps is the recommended container host. A deployment plan that says "container on Flex" is not buildable. | **web:** `WebFetch(functions-scale)`; `WebFetch(learn.microsoft.com/azure/azure-functions/container-concepts)` |
| 6 | ⚠️ **Container cold start** | "Consider a less common scenario, such as an app running in a custom container. **Because custom containers have a long warm-up time**, you might consider increasing this buffer of prewarmed instances." | **web:** `WebFetch(learn.microsoft.com/azure/azure-functions/functions-premium-plan)` — "Prewarmed instances" |
| 7 | Cold-start mitigation on Premium | Two distinct settings. *Always ready instances*: `siteConfig.minimumElasticInstanceCount`, app runs continuously on them regardless of load, **maximum 20 per app**, and they set the plan's billed minimum. *Prewarmed instances*: `siteConfig.preWarmedInstanceCount`, a buffer during scale-out, **default 1**, not settable in the portal. "Every premium plan always has at least one active (billed) instance." | **web:** `WebFetch(functions-premium-plan)` |
| 8 | Warm-up trigger | "You can also define a warmup trigger that runs during the prewarming process ... to preload custom dependencies during the prewarming process so your functions are ready to start processing requests immediately." Decorator available on the app object as `warm_up_trigger`. | **web:** `WebFetch(functions-premium-plan)`; `WebFetch(azure.functions.decorators.function_app.asgifunctionapp)` (method list) |
| 9 | Cold start on Dedicated | "When it runs in a Dedicated plan, the Functions host can run continuously on a prescribed number of instances, which means that cold start isn't really an issue." Requires Always On. | **web:** `WebFetch(functions-scale)` — "Cold start behavior" |
| 10 | Base image | `mcr.microsoft.com/azure-functions/python:4-python3.12` (or `...-appservice`, which only adds SSH/remote debugging). Track the **`4-` tag** and rebuild regularly: "Don't use tags that specify minor runtime versions, as these tags don't receive updates." | **web:** `WebFetch(container-concepts)` |
| 11 | ⚠️ **The `azure-functions` major version is decided by the Python version.** | `azure-functions` **2.3.0** (2026-08-28) declares `requires_python >=3.13`. The 3.10–3.12 line is `azure-functions` **1.25.0** (2026-08-05), `requires_python >=3.10`. Choosing `python:4-python3.12` in the Dockerfile pins the app to the 1.x line. The v2 *programming model* needs `azure-functions >= 1.11.1`; direct invocation of a handler from the interpreter needs `>= 1.21.0`. | **web:** `curl pypi.org/pypi/azure-functions/json`; Flask sample; `WebFetch(functions-reference-python)` |
| 12 | Supported Python versions | Python 3.10–3.14 are all GA on Functions runtime v4. 3.10 reaches end of support **October 2026**. | **web:** `WebFetch(learn.microsoft.com/azure/azure-functions/supported-languages)` |
| 13 | Python 3.13+ behaviour change | Dependency isolation is on by default — `PYTHON_ISOLATE_WORKER_DEPENDENCIES` "has no impact for apps running on Python 3.13 or later". Worker extensions and shared-memory features are **removed**. HTTP-streaming setup no longer needs app settings. Below 3.13, set `PYTHON_ISOLATE_WORKER_DEPENDENCIES=1` if a dependency collides with the worker's `grpcio` / `protobuf`. | **web:** `WebFetch(functions-reference-python)` |
| 14 | Logging a background thread | A thread started by a handler must receive `context` and set `context.thread_local_storage.invocation_id = context.invocation_id`, or its log lines are not associated with the invocation. Directly relevant: `asyncio.to_thread` work does not carry the invocation id for free. | **web:** `WebFetch(functions-reference-python)` |

### 11.7 DO-NOT-USE — HTTP surface

These rows extend §9 and are scoped to this section.

| Symbol | What it was | Use instead |
|---|---|---|
| `function.json` + `main()` in `__init__.py` (the v1 model) | The legacy programming model. Reference: v2 "is recommended for new Python apps"; v1 "supports legacy apps". SDK type bindings and HTTP streams do not exist in v1. | `func.FunctionApp()` + `@app.route(...)` in `function_app.py` |
| `func.AsgiFunctionApp` / `func.WsgiFunctionApp` / `AsgiMiddleware` / `WsgiMiddleware` **for this service** | Web-framework hosting. Collapses every endpoint into one `http_app_func` answering all verbs, moves authorization to an app-wide `http_auth_level`, forces `routePrefix: ""`, and puts a web framework in the image. | `@app.route(route=..., methods=[func.HttpMethod.POST])` with `func.HttpRequest` / `func.HttpResponse` |
| `AsgiMiddleware.handle(...)` | Reference marks it **"Deprecated. Please use `handle_async` instead."** | `await func.AsgiMiddleware(app).handle_async(req, context)` — only if the ASGI path is ever adopted, which §11.5 says it should not be |
| `azurefunctions-extensions-http-fastapi` / HTTP streams | All-or-nothing per app: enabling it makes "the original HTTP functionality ... not work", and streaming and non-streaming HTTP functions "within the same app is not supported". | `func.HttpResponse` |
| A route parameter declared as an extra handler argument | Docs, marked Important: "In the Python v2 model, don't add route parameters as extra function arguments." | `req.route_params.get("...")` |
| Functions defined in a second module without a `Blueprint` | Not the documented way to split a v2 project; only `function_app.py` is indexed. | `bp = func.Blueprint()` in the module, `app.register_functions(bp)` in `function_app.py` |
| `azure-functions-worker` in the dependency manifest | "the Python worker is manager by Azure Functions platform and manually managing it may cause unexpected issues." | `azure-functions` only |
| Relying on `functionTimeout` to hold an HTTP request open past 230 s | The load balancer returns 502 at 230 s and the response is lost, whatever the plan allows. | Return inside the budget, or return a location the caller polls |
| A custom container on a Flex Consumption plan | Flex Consumption container support is "None". | Premium (Elastic Premium) or Dedicated for a Functions-hosted container; Azure Container Apps otherwise |
| Minor-pinned base image tags (e.g. `python:4.x.y-python3.12`) | "these tags don't receive updates. Your app potentially remains on an unpatched version, no matter how often you rebuild your custom image." | `mcr.microsoft.com/azure-functions/python:4-python3.12` |

### 11.8 Working reference snippet

The shape both endpoint stories may now name. Azure only; no framework mounted.

```python
import json

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)


@app.route(route="ai/encounter/extract", methods=[func.HttpMethod.POST])
async def extract(req: func.HttpRequest) -> func.HttpResponse:
    """The extracted encounter fields, as JSON."""
    correlation_id = req.headers.get("x-correlation-id")
    payload = req.get_json()

    result = await run_extraction(payload, correlation_id)

    return func.HttpResponse(
        json.dumps(result),
        status_code=200,
        mimetype="application/json",   # defaults to text/plain
    )
```

With the default route prefix this is served at `/api/ai/encounter/extract`. `mimetype` is not
optional — see §11.3. `req.get_json()` names no exception on a malformed body — see §10 #7.
