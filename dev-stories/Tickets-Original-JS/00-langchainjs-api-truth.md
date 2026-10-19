# 00 — LangChain JS / Node / Azure API ground truth

**Status:** verified 2026-09-29 on Node v24.18.0 and npm 12.0.1. **This file is the allow-list.**
A ticket may not name a library, Node or Azure symbol that is missing from this file. The
exception is a plain ECMAScript language construct (`class`, `Object.defineProperty`,
`structuredClone`, `Promise.all`), which is not a vendor API and so has no row. §14.9 still
gives the lazy-member pattern built from them, and that snippet was run.

**Verification path.** Every row says where it came from in the `Verified by` column:

| Marker | Meaning |
|---|---|
| **run:** `sNN` / `ref/*` | A script this task wrote under `$JW` and executed with `node`. It exited 0 with its assertions passing. |
| **read:** `path` | An installed file under `$JW/node_modules` that this task read (`.d.ts`, compiled `dist/*.js`, `package.json`). |
| **npm:** | `npm view` / `npm ls` output from this task's install. |
| **MCP:** | The `reference-langchain` or `docs-langchain` server. |
| **web:** | A page fetched with `WebFetch` or `curl`, not an installed package or an MCP server. |
| **claim `ID`** | A claim from this workflow's research record that at least one independent skeptic check confirmed by running or reading something (the id is as in the record). This task did not re-run it. Refuted or disputed claims never appear under this marker: this task re-ran each one, and its row cites that **run:**. |

`$JW` = `/private/tmp/claude-503/-Users-akash-saxena-saisystem-projects/cbc72f0a-9422-4b3e-8c9f-b371e66b4d7a/scratchpad/jswrite`.
`$JW/run-all.sh` runs every script again, and its last output is in `$JW/run-all.out`.

`$JA` = the sibling `scratchpad/jsamend` folder: `zod` 4.6.5, `mssql` 12.7.2 (`tedious` 20.0.0),
`typescript` 7.0.2 and `@types/node` 24.19.0, installed by `npm install` on 2026-09-29. A **run:**
`$JA/...` row means that script was executed with `node` and its assertions passed.

`$JF` = the sibling `scratchpad/jsfix` folder. It holds the review-round runs, on the same pinned
versions (its `node_modules` resolves to `langchain` 1.5.14, `@langchain/openai` 1.6.0, `openai`
7.23.0, `@azure/identity` 4.13.3, `mssql` 12.7.2, `tedious` 20.0.0, `jose` 6.2.12, `pino` 10.3.1,
`eslint` 10.11.0, `typescript` 7.0.2). A **run:** `$JF/...` row means that script was executed
with `node` and printed the result the row states. `$JF/proj` is a miniature repository whose
`npm test` (8 tests, 8 passing) exercises the preloads, the fetch seam and the `dns.lookup` seam
together.

`$JE` = the sibling `scratchpad/e4` folder, run 2026-10-05 against the `PacEHR_AI` repository's
own `node_modules` (`langchain` 1.5.14, `@langchain/langgraph` 1.4.18, `@langchain/openai` 1.6.0,
`openai` 7.23.0, `zod` 4.6.5). Each script drives a real `AzureChatOpenAI` through a fake
`globalThis.fetch` that records every request body. **run:** `$JE/pN` means `probeN.mjs` (the
first is `probe.mjs`) printed the result the row states; `$JE/run-all.out` holds all six outputs.

**Platform:** Azure only. No AWS package, service or identifier is allowed. §1.3 covers the
AWS strings that the dependency tree carries anyway.
**Language:** TypeScript since PR 12447 (`src/**/*.ts`, run with `tsx`, built with `tsc`).
§1–§16 were verified with JavaScript scripts; the runtime facts are unchanged by the language.
§12.7 (`tsc --checkJs`) describes the JavaScript edition and is superseded by `tsc --noEmit` over
`.ts`. §17 holds the agent-core facts Epic 4 rests on.

### Pinned versions behind these entries (resolved by `npm install` in `$JW`, 2026-09-29)

| Package | Resolved | Role |
|---|---|---|
| `langchain` | **1.5.14** | `createAgent`, `createMiddleware`, `tool`, `initChatModel`, strategies |
| `@langchain/core` | **1.2.13** | peer of `langchain` and `@langchain/openai`, so it is a direct dependency |
| `@langchain/openai` | **1.6.0** | `AzureChatOpenAI` |
| `@azure/identity` | **4.13.3** | credentials and the bearer-token provider |
| `mssql` | **12.7.2** | Azure SQL (depends on `tedious` **20.0.0** and `tarn` **3.1.2**) |
| `jose` | **6.2.12** | inbound Entra token validation |
| `pino` | **10.3.1** | logging (depends on `sonic-boom` **4.2.1**) |
| `zod` | **4.6.5** | schemas (`langchain` accepts `^3.25.76 \|\| ^4`) |
| `@azure/functions` | **4.16.5** | Functions v4 programming model (only the entrypoint epic needs it) |
| dev: `typescript` | **7.0.2** | `tsc --checkJs` only |
| dev: `@types/node` | **24.19.0** | |
| dev: `@types/mssql` | **12.3.0** | mssql ships no types |
| dev: `eslint` | **10.11.0** | the guard rules (§12.8) |
| transitive: `openai` | **7.23.0** | used by `@langchain/openai` |
| transitive: `@langchain/langgraph` | **1.4.18** | used by `langchain`. Also the import for `Command` and `MemorySaver` (§4.6) |
| transitive: `langsmith` | **0.10.5** | used by `@langchain/core` |

Verified by **npm:** `npm ls --depth=0` and `npm ls openai tedious @langchain/langgraph sonic-boom tarn` in `$JW`.

---

## 1. Packages, engines, module format

### 1.1 Engines and module type

| Package | `engines.node` | Module type / types | Verified by |
|---|---|---|---|
| `langchain` 1.5.14 | `>=20` | ESM with a CJS build; `.d.ts` and `.d.cts` bundled | claim C08, lc-01 |
| `@langchain/core` 1.2.13 | `>=20` | ESM with a CJS build; types bundled. No `peerDependencies` | claim C08, lc-02 |
| `@langchain/openai` 1.6.0 | **`>=22`** | ESM; peer `@langchain/core ^1.2.13`; deps `openai ^7.10.0`, `zod`, `js-tiktoken` | claim C09, lc-03; **read:** `node_modules/@langchain/openai/package.json` (zod range) |
| `@azure/identity` 4.13.3 | **`>=22.0.0`** | ESM (`type: module`) with a CommonJS build; types bundled | claim C10 |
| `mssql` 12.7.2 | `>=18.19.0` | **CommonJS, no types** (use `@types/mssql` 12.3.0). No install scripts | claim C11 |
| `tedious` 20.0.0 | `>=22` | CommonJS | **read:** `node_modules/tedious/package.json` |
| `jose` 6.2.12 | none | **ESM only**: `exports['.']` = `./dist/webapi/index.js`, types `./dist/types/index.d.ts` | claim C12, jose-8 |
| `pino` 10.3.1 | none | CommonJS with `pino.d.ts` | **run:** `s07` (`import pino from 'pino'`) |
| `zod` 4.6.5 | none | ESM with types | claim C13 |
| `@azure/functions` 4.16.5 | `>=20.0` | `main: ./dist/azure-functions.js` | claim C07; **read:** its `package.json` |
| `typescript` 7.0.2 | — | native binary; 2 packages | claim C31 |
| `eslint` 10.11.0 | `^20.19.0 \|\| ^22.13.0 \|\| >=24` | — | claim C33 |

**Floor:** `"engines": { "node": ">=22.13" }`. It is the highest floor the tree declares:
`@langchain/openai`, `@azure/identity` and `tedious` need 22, and `eslint` needs `^22.13.0`.
Node 24 satisfies it.

### 1.2 Import forms

| Symbol | Import | Note | Verified by |
|---|---|---|---|
| mssql API | `import sql from 'mssql'` | **Only the default import carries the API.** `import * as ns from 'mssql'` gives `ns.ConnectionPool === undefined` | **run:** `s05` |
| pino | `import pino from 'pino'` | default import | **run:** `s07` |
| zod | `import * as z from 'zod'` or `import { z } from 'zod'` | both work; `zod/mini` and `zod/v3` subpaths also ship | **run:** `s01` (`* as z`); claim zod-1 |
| everything else | named imports (`import { createAgent } from 'langchain'`) | ESM packages | **run:** all scripts |

### 1.3 Zero AWS — what the tree still carries

| Fact | Detail | Verified by |
|---|---|---|
| `openai@7.23.0` optional peers | `peerDependencies` names `@aws-sdk/credential-provider-node`, `@smithy/hash-node` and `@smithy/signature-v4`, each `optional: true`. `undici`, `ws` and `zod` are optional peers too | **read:** `node_modules/openai/package.json` |
| nothing AWS installed | `node_modules` has no `@aws-sdk` or `@smithy` directory. `npm install-scripts ls` reports "No packages with unreviewed install scripts." | **run:** `ls`/`npm` in `$JW` |
| lockfile text | `package-lock.json` lines 2161–2175 contain those three names as openai's peer metadata | **run:** `grep -n -i "aws\|smithy" package-lock.json` |
| shipped files | `node_modules/openai/bedrock.{js,mjs,d.ts}` exist, and `langchain` exports `bedrockPromptCachingMiddleware` | **run:** `ls`; `node -e "import('langchain')"` |

Our source must never import any of these (§15). Epic 1 PEA-101 accepts the lockfile text,
pending the user's confirmation (§16 #1).

---

## 2. Agent factory

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `createAgent` | `import { createAgent } from 'langchain'` | `createAgent(params)` → `ReactAgent`. **Synchronous**: it is called without `await`. It throws "`model` option is required to create an agent." when `model` is missing | **run:** `s01`, `s02`; **MCP:** `get_symbol(package="langchain", symbol="createAgent", language="javascript")` |
| `CreateAgentParams` keys | — | `model`, `tools`, `systemPrompt` (`string \| SystemMessage`), `stateSchema`, `contextSchema`, `checkpointer` (`BaseCheckpointSaver \| boolean`), `store`, `responseFormat`, `middleware`, `name`, `description`, `includeAgentName` (`'inline'`), `signal`, `version` (`'v1' \| 'v2'`), `streamTransformers`. **There is no `prompt` key and no `llm` key.** | claim lc-15; **run:** `createAgent({ llm: 'x' })` threw the missing-model error |
| `model` (param) | — | a chat model instance, or a `"<provider>:<model>"` string resolved through `initChatModel` | **MCP:** `get_symbol(createAgent)` |
| `systemPrompt` (param) | — | sent as the first message: `{ role: 'system', content: [{ type: 'text', text }] }` | **run:** `s01` (captured request body) |
| `agent.invoke` | — | `await agent.invoke({ messages: [{ role: 'user', content }] }, { context })` → final state | **run:** `s01`, `s02` |
| `result.messages` | — | the full message list | **run:** `s02` |
| `result.structuredResponse` | — | the parsed structured output (§3). Custom middleware state keys also appear at the top level of the result | **run:** `s01`, `s02` (`modelCalls: 2`) |
| message ids | — | State `messages` **merge by `id`**. A fake completion that reuses an id overwrites the earlier message in place, and the run ends **early**: with reused ids there were 2 model calls and messages `human,ai,tool`, against 3 calls and `human,ai,tool,ai,tool,ai` with unique ids. It never adds calls. Every fake response gets a unique `id` | **run:** `s02b` (this settles the refuted claim lc-28) |

### Messages

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `AIMessage`, `HumanMessage`, `SystemMessage`, `ToolMessage` | `import { AIMessage } from 'langchain'` (these are re-exports; `@langchain/core/messages` also works) | `new AIMessage('text')`. A hook constructs one to inject a canned reply | **run:** `ref/middleware.mjs` (from `langchain`), `s02` (from `@langchain/core/messages`); **read:** `langchain/dist/index.d.ts` export list |
| `AIMessage.usage_metadata` | — | `{ input_tokens, output_tokens, total_tokens, input_token_details, output_token_details }` | **run:** `s03` |
| `AIMessage.response_metadata` | — | keys observed: `tokenUsage`, `finish_reason`, `model_provider`, `model_name`, `usage` | **run:** `s03` |

---

## 3. Structured output — the load-bearing section

**The parsed result is at `result.structuredResponse`.**

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `providerStrategy` | `import { providerStrategy } from 'langchain'` | `providerStrategy(schema)` or `providerStrategy({ schema, strict })`. `strict` **defaults to `true`**; `{ strict: false }` reads back `false` | **run:** `s01` |
| provider wire shape | — | `response_format: { type: 'json_schema', json_schema: { name: 'extract', description, schema, strict: true } }`. The object-level `.describe()` becomes `json_schema.description` | **run:** `s01` (captured) |
| `toolStrategy` | `import { toolStrategy } from 'langchain'` | `toolStrategy(schema, { toolMessageContent?, handleError? })` returns an **array** of `ToolStrategy`, and the `.d.ts` agrees (`interface TypedToolStrategy<T> extends Array<ToolStrategy<any>>`, `responses.d.ts:79`). The tool is named after the schema title, or `extract-<n>` when there is none. It is sent with `strict: false` and `tool_choice: 'required'`. An unset `handleError` means retry | **run:** `s01` (`Array.isArray`, `instanceof ToolStrategy`); **read:** `langchain/dist/agents/responses.d.ts:79`; **run:** this settles the refuted claim lc-19 |
| `ProviderStrategy`, `ToolStrategy` | `import { ProviderStrategy, ToolStrategy } from 'langchain'` | classes, for `instanceof` checks | **run:** `s01` |
| `StructuredOutputParsingError` | `import { StructuredOutputParsingError } from 'langchain'` | thrown when a terminal output **is valid JSON but fails the schema** | **run:** `s01` (`{"complaint":5}`) |
| non-JSON output | — | Content that is not JSON rejects with a **`SyntaxError`** ("Error reading response: invalid structured output JSON."). That is **not** `instanceof StructuredOutputParsingError`, so a boundary must handle both | **run:** `s01` (`'not json'`) — this settles the disputed claim lc-18 |
| `MultipleStructuredOutputsError` | `import { MultipleStructuredOutputsError } from 'langchain'` | exported | **run:** `typeof` check |
| `responseFormat` accepts | — | a zod schema, an array of zod schemas, a JSON Schema object, a Standard Schema, `toolStrategy(...)` or `providerStrategy(...)` | claim lc-15 (research §4) |

### Selection rule for a bare schema

A bare zod schema passed as `responseFormat` gets `ProviderStrategy` only when
`model.profile.structuredOutput === true`. Anything else gets `ToolStrategy`.

| `model` value on `AzureChatOpenAI` | `profile.structuredOutput` | Verified by |
|---|---|---|
| `'gpt-5.5'`, `'gpt-5'`, `'gpt-5.1'`, `'gpt-4.1'`, `'gpt-4o'` | `true` | **run:** one-liner in `$JW` |
| `'gpt-3.5-turbo'` (the default when `model` is omitted) | `false` | **run:** same; claim lc-13 |
| a deployment alias such as `'gpt-5-5-deployment'` | `undefined` → **ToolStrategy** | **run:** same; `s01` saw `tool_choice: 'required'` and no `response_format` |

**Ticket instruction:** always write `responseFormat: providerStrategy(schema)` explicitly, and
set `model` to the deployed model's real name. An alias silently downgrades a bare schema to
a client-side retry loop.

### Schema descriptions reach the provider

A zod `.describe()` on a field becomes `properties.<field>.description`, under both
strategies. Zod 4 emits JSON Schema draft 2020-12 with `additionalProperties: false`.
Verified by **run:** `s01` (`followUpDays` description, `additionalProperties === false`); claim lc-26.

---

## 4. Middleware — the spine

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `createMiddleware` | `import { createMiddleware } from 'langchain'` | `createMiddleware({ name, stateSchema?, contextSchema?, tools?, streamTransformers?, beforeAgent?, beforeModel?, wrapModelCall?, afterModel?, wrapToolCall?, afterAgent? })` | **run:** `s02`, `ref/middleware.mjs`; claim lc-20 |
| node-style hook | — | `(state, runtime) => update \| undefined`, or `{ hook, canJumpTo: ('model' \| 'tools' \| 'end')[] }` | **run:** `s02`; claim lc-21 |
| `wrapModelCall` | — | `async (request, handler) => AIMessage \| Command`. `request` has `model`, `messages`, `systemPrompt`, `systemMessage`, `tools`, `state`, `runtime`, and optionally `toolChoice`, `responseFormat`, `modelSettings` | **run:** `s02`, `s02b`; claim lc-23 |
| `wrapToolCall` | — | `async (request, handler) => ToolMessage \| Command`. `request` has `toolCall`, `tool`, `state`, `runtime` | **run:** `s02` (`request.toolCall.name`); claim lc-23 |
| `stateSchema` | — | a zod object (`z.object({ modelCalls: z.number().default(0) })`), `StateSchema` or `AnnotationRoot`. A hook returns a partial update, and the key appears in the result | **run:** `s02` (`modelCalls === 2`) |
| `contextSchema` / `runtime.context` | — | pass it with `agent.invoke(input, { context })` and read it as `runtime.context`. It is **validated**: a wrong type rejects with `$ZodError` | **run:** `s02` |

### Execution order

| Case | Observed order | Verified by |
|---|---|---|
| one middleware, one tool round | `beforeAgent > beforeModel > wrapModelCall > afterModel > wrapToolCall:<tool> > beforeModel > wrapModelCall > afterModel > afterAgent` | **run:** `s02` |
| `middleware: [m1, m2]`, no tools | `bA1 bA2 bM1 bM2 w1> w2> <w2 <w1 aM2 aM1 aA2 aA1`. `before*` runs first to last, `after*` runs last to first, and `wrap*` nests with the first one outermost | **run:** `s02b` |

### How a hook ends the run — and why it must not throw

| Case | Observed | Verified by |
|---|---|---|
| `beforeAgent` declared `{ canJumpTo: ['end'], hook }` returns `{ messages: [new AIMessage(...)], jumpTo: 'end' }` | 0 model calls. The injected message is last. **`afterAgent` still runs**: the order was `beforeAgent > afterAgent` | **run:** `s02`, `ref-run.mjs` (the audit row was written for the blocked run) |
| a `beforeAgent` hook **throws** | `invoke` rejects with that error, and **`afterAgent` does not run**: the order was `beforeAgent` only | **run:** `s02` |
| jump targets | exactly `'model'`, `'tools'`, `'end'` (`JUMP_TO_TARGETS`) | claim lc-21 |

**Architectural consequence (same as the Python edition):** a guard that blocks a run returns
`jumpTo: 'end'` from a hook that declared `canJumpTo: ['end']`. That way `afterAgent` writes
the audit row for the blocked run. A guard must never throw to block, because a throw skips
`afterAgent` and loses the audit row.

### 4.6 Human in the loop

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `humanInTheLoopMiddleware` | `import { humanInTheLoopMiddleware } from 'langchain'` | `humanInTheLoopMiddleware({ interruptOn })`. It **requires a `checkpointer`** on `createAgent`. The `when` predicate needs `langchain>=1.4.6` | claim lc-24 (**MCP:** `/oss/javascript/langchain/human-in-the-loop.mdx`) |
| `Command`, `MemorySaver` | `import { Command, MemorySaver } from '@langchain/langgraph'` | resume a run with `new Command({ resume: { decisions: [...] } })`. **Neither is exported from `langchain`.** `@langchain/langgraph` is transitive today, so it becomes a direct dependency before any ticket imports it | **run:** `typeof` checks (`langchain.Command === undefined`; `@langchain/langgraph` has both) |

---

## 5. Models — Azure OpenAI

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `AzureChatOpenAI` | `import { AzureChatOpenAI } from '@langchain/openai'` | `new AzureChatOpenAI(fields)`. A string first argument, `new AzureChatOpenAI('gpt-4.1', fields)`, sets `model` and the deployment name. Construction makes **no network call** | **run:** `s03`, `ref-run.mjs` (under the no-network preload); claim lc-05 |
| `model` | — | the deployed model's real name. It is sent as `body.model` and drives `profile`. **It defaults to `'gpt-3.5-turbo'`** | **run:** `s03`; claim lc-13 |
| `azureOpenAIEndpoint` | — | `https://<resource>.openai.azure.com`, **with no trailing slash**. The URL is built as `${endpoint}/openai/deployments/${deployment}/chat/completions?api-version=${v}`. A trailing slash is not stripped and produces `//openai` | **run:** `s03`, `s03b` |
| `azureOpenAIApiDeploymentName` | — | the deployment name (alias `deploymentName`) | **run:** `s03` |
| `azureOpenAIApiVersion` | — | sent as `?api-version=` (alias `openAIApiVersion`) | **run:** `s03` |
| `azureADTokenProvider` | — | `() => Promise<string>`, usually from `getBearerTokenProvider` (§8). Sent as `Authorization: Bearer <token>`, with no `api-key` header | **run:** `s03` |
| `azureOpenAIApiKey` | — | sent as an `api-key` header, with no `Authorization` header. Local development only | **run:** `s03b` |
| `maxRetries` | — | owned by core's `AsyncCaller` (`model.caller.maxRetries`) and **defaults to 6**. The inner openai client runs with `maxRetries: 0` | **run:** `s03` (reads back 2); claim lc-12 |
| `timeout` | — | milliseconds, passed to the openai client | claim lc-12 |
| `temperature` | — | `undefined` unless set | **run:** `s03` |
| `configuration: { fetch }` | — | injects the fetch the client uses. This is the offline test seam | **run:** `s01`–`s03b` |
| `globalThis.fetch`, with no `configuration.fetch` | — | the openai client inside the model uses the `globalThis.fetch` it sees on the model's **first invoke** and keeps it. Constructed under stub PRE, invoked under stub A, then invoked again under stub B: both replies came from A. A test that stubs the global per test deletes the lazy model member first, so a new model captures that test's stub. Without the delete, a second test's stub got 0 calls | **run:** `$JF/v-fetchseam.mjs` (`first A`, `after swap A`); `$JF/proj/tests/unit/core/llm.test.js` (three tests, each `delete` + `t.mock.method(globalThis, 'fetch')`, each stub called once; the no-delete test's stub called 0 times) |
| `model.profile.structuredOutput` | — | see the §3 table | **run** |
| `azureOpenAIBasePath`, `azureOpenAIApiInstanceName` | — | Both exist and are not deprecated. Precedence is basePath, then endpoint, then instanceName, and instanceName hardcodes `openai.azure.com`. **Do not use them**; pass `azureOpenAIEndpoint` | claim lc-06 |

### 5.1 Hidden environment reads — every Azure field is passed explicitly

When a field is omitted, the library reads `process.env` on its own. It reads
`AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_API_INSTANCE_NAME`, `AZURE_OPENAI_API_DEPLOYMENT_NAME`,
`AZURE_OPENAI_API_VERSION`, `AZURE_OPENAI_BASE_PATH` and `AZURE_OPENAI_ENDPOINT` (in
LangChain's `_constructAzureFields`). The ChatOpenAI base also reads `OPENAI_API_KEY`,
`OPENAI_ORGANIZATION` and `OPENAI_API_BASE`/`OPENAI_BASE_URL`. The openai `AzureOpenAI` client
defaults `apiKey` from `AZURE_OPENAI_API_KEY`, `apiVersion` from `OPENAI_API_VERSION`, and
`endpoint` from `AZURE_OPENAI_ENDPOINT`. Verified by claim lc-08, and by **run:** in `$JW`: with `AZURE_OPENAI_ENDPOINT` set,
`new AzureChatOpenAI({ azureOpenAIEndpiont: 'https://typo…' , ... })` read back the **env**
endpoint, so the misspelled field is masked (§12.7).

| Trap | Observed | Verified by |
|---|---|---|
| no key, no token provider, no env | the constructor throws `Azure OpenAI API key or Token Provider not found` | **run:** `s03b` |
| **a stray `AZURE_OPENAI_API_KEY` in the real env, plus `azureADTokenProvider`** | construction succeeds, and **the first `invoke` rejects** with "…mutually exclusive…". Passing `azureOpenAIApiKey: ''` does not help | **run:** `s03b`; claim lc-09 |
| a misspelled field | behaviour tests pass when the env var of the same name is set. Only `tsc --checkJs` catches it (§12.7) | **run:** `proj/typo/llm.js` → TS2769 |
| **`AZURE_OPENAI_BASE_PATH` in the real env, with `azureOpenAIEndpoint` passed explicitly** | the env base path **wins**: the request, `Authorization: Bearer` included, went to `https://evil.example/openai/deployments/dep/chat/completions?...`. The same happened with `azureOpenAIBasePath: undefined` or `null`. Only an explicit `azureOpenAIBasePath: ''` kept the request on the endpoint. This refines claim lc-06's precedence | **run:** `$JF/llm-basepath.mjs` |
| `LANGSMITH_TRACING`, `LANGSMITH_TRACING_V2`, `LANGCHAIN_TRACING`, `LANGCHAIN_TRACING_V2` = `true` in the real env | each made one plain `invoke` (with `configuration.fetch` answering the model call) also call `globalThis.fetch('https://api.smith.langchain.com/info')`, a non-Azure host. Under the §14.8 preload each run exited 99. With none set, `globalThis.fetch` was never called | **run:** `$JF/llm-tracing.mjs` under `no-network-full.js`, one process per name (`$JF/trace-<NAME>.out`, all `status=99`; `trace-NONE.out` `status=0`, no global fetch) |
| `LANGCHAIN_VERBOSE=true` in the real env | `invoke` printed an `[llm/start]` block to stdout containing the prompt text (`"content": "note text"`). It made no global fetch | **run:** `$JF/llm-tracing.mjs` (`$JF/trace-LANGCHAIN_VERBOSE.out`) |
| a whitespace-only `AZURE_OPENAI_API_KEY` (`'   '`) in the real env, plus `azureADTokenProvider` | construction and `invoke` both succeeded, and the request carried an `api-key` header (whitespace, which `Headers` trims to `''`) **beside** `Authorization: Bearer TOKEN`. It did not throw the mutually-exclusive error a non-blank key throws | **run:** `$JF/llm-wskey.mjs` (`{"apiKey":"","auth":"Bearer TOKEN"}`) |

### 5.2 `initChatModel`

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `initChatModel` | `import { initChatModel } from 'langchain'` | **async**: `await initChatModel('azure_openai:gpt-4.1', fields)` returns a lazy `ConfigurableModel`. `modelProvider: 'azure_openai'` also works | **run:** `s03b` (`_getModelInstance()` is an `AzureChatOpenAI`); claim lc-14 |
| `azure_openai` (provider prefix) | — | the exact prefix string. **`'azure:'` fails** with "Unable to infer model provider" | **run:** `s03b` |

`_getModelInstance()` is private. It appears only in the verification script, and no ticket
may call it.

---

## 6. Tools

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `tool` | `import { tool } from 'langchain'` | `tool(async (input, runtime) => ..., { name, description, schema })`. Other fields are `responseFormat?`, `returnDirect?`, `metadata?` and `verboseParsingErrors?`. `langchain`'s `tool` wraps `@langchain/core/tools`'s `tool` and is not the same function object; use the `langchain` one | **run:** `s02`; claim lc-25 |
| tool wire shape | — | `{ name, description, parameters: { type: 'object', properties: { mrn: { type: 'string', description } }, required, additionalProperties: false } }`. Field `.describe()` text reaches `parameters.properties.<f>.description` | **run:** `s02` (captured) |
| `runtime` (2nd tool argument) | — | an object (a `ToolRuntime`) | claim lc-25 |

---

## 7. zod 4

| Symbol | Signature / usage | Verified by |
|---|---|---|
| `z.object`, `z.string`, `z.number().int()`, `z.boolean`, `.describe(text)`, `.default(v)`, `.optional()` | `.default` applies only to `undefined`, not to `''`. `.optional()` leaves the key absent. **Unknown keys are stripped** | **run:** `s01`, `s02`; claim zod-6 |
| `schema.parse` / `schema.safeParse` | `parse` throws `z.ZodError`. `safeParse` returns `{ success: true, data }` or `{ success: false, error }`. `error.issues[]` = `{ code, path, message, ... }` | claim zod-2 |
| `z.prettifyError`, `z.flattenError`, `z.treeifyError` | the v4 error helpers | claim zod-3 |
| `z.url()`, `z.uuid()`, `z.email()`, `z.guid()` | the top-level forms. `z.uuid()` enforces the RFC version and variant bits | claim zod-4 |
| `z.stringbool()` | maps true/1/yes/on/y/enabled and false/0/no/off/n/disabled, ignoring case, and rejects anything else | claim zod-5 |
| `$ZodError` | the class name of a context-validation failure seen by `createAgent` | **run:** `s02` |
| `z.string().trim().min(1)` | `.trim()` runs before `.min(1)`: `'  x  '` parses to `'x'` and `'   '` fails with code `too_small` | **run:** `$JA/s03-zod-symbols.mjs` |
| `z.preprocess(fn, schema)` | `fn` runs on the raw input first. With `fn` mapping `''` to `undefined`, `''` reaches `.optional()` as absent and `.default(v)` as `v` | **run:** `$JA/s03-zod-symbols.mjs` |
| `.toLowerCase()`, `.transform(fn)` | string schema methods: `'WARN'` parses to `'warn'`; `.transform((s) => s.replace(/\/$/, ''))` turns `'https://h/'` into `'https://h'` | **run:** `$JA/s03-zod-symbols.mjs` |
| `objectSchema.shape` | the declared entries, keyed as declared, in declaration order. `shape[k].safeParse(undefined).success` is `true` exactly for an entry that is optional or has a default | **run:** `$JA/s03-zod-symbols.mjs`, `$JA/s02-settings.mjs` |
| `error.issues` from an object `safeParse` | one issue per failing key, each with `path: [key]`; stripped keys raise none. A default issue carries no `input` field, and a `too_small` message names no value | **run:** `$JA/s03-zod-symbols.mjs` |
| `z.uuid()` vs `z.guid()` | `z.uuid()` rejects `11111111-1111-1111-1111-111111111111` (RFC version bits); `z.guid()` accepts it | **run:** `$JA/s04-uuid.mjs` |
| settings shape, end to end | the PEA-102 schema (every entry `z.preprocess(unsetIfBlank, ...)`) met every PEA-102 scenario: derived lists, missing names, frozen memo, trimming, trailing slash, lowercased level, whitespace failure, `.env.local` precedence with cwd elsewhere, stray key stripped, refused names. `tsc --checkJs --strict` over it exited 0 | **run:** `$JA/s02-settings.mjs` against `$JA/proj/core/settings.js`; `tsc -p $JA/proj` |

---

## 8. Azure Identity (outbound credentials)

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `DefaultAzureCredential` | `import { DefaultAzureCredential } from '@azure/identity'` | `new DefaultAzureCredential(options?)`. The options are `{ managedIdentityClientId?, workloadIdentityClientId? }`, `{ managedIdentityResourceId }`, or `{ tenantId?, processTimeoutInMs?, requiredEnvVars? }`. **Construction makes no network, DNS or child-process call** | **run:** `s11` (under the preload that blocks network and spawn); claim id-3, id-7 |
| `requiredEnvVars` | — | the constructor throws when a listed variable is missing or empty | **run:** `s11` |
| `AZURE_TOKEN_CREDENTIALS` | env | `'prod'` = Environment, WorkloadIdentity, ManagedIdentity. `'dev'` = VS Code, Azure CLI, PowerShell, azd, Broker. One credential name selects only that credential. **Any other value throws at construction** | **run:** `s11` (`'bogus'` throws, `'prod'` builds); **read:** `credentials/defaultAzureCredential.js` 60–128; claim id-5 |
| MI client id inside the chain | — | `options.managedIdentityClientId ?? process.env.AZURE_CLIENT_ID` | claim id-6 |
| default chain order | — | with `AZURE_TOKEN_CREDENTIALS` unset: `EnvironmentCredential`, `WorkloadIdentityCredential`, `ManagedIdentityCredential`, then VS Code, Azure CLI, Azure PowerShell, Azure Developer CLI and Broker | **read:** `dist/esm/credentials/defaultAzureCredential.js` 66–77 (the dev and prod lists) and 128 (`[...prod, ...dev]`) |
| `EnvironmentCredential` variables | env | `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_CLIENT_CERTIFICATE_PATH`, `AZURE_CLIENT_CERTIFICATE_PASSWORD`, `AZURE_USERNAME`, `AZURE_PASSWORD`, `AZURE_ADDITIONALLY_ALLOWED_TENANTS`, `AZURE_CLIENT_SEND_CERTIFICATE_CHAIN` | **read:** `dist/esm/credentials/environmentCredential.js` 17–27 (`AllSupportedEnvironmentVariables`) |
| `ManagedIdentityCredential` | `import { ManagedIdentityCredential } from '@azure/identity'` | `new ManagedIdentityCredential({ clientId })`, `(clientId, options?)`, `({ resourceId })` or `({ objectId })`. Offline construction | **run:** `s11`; claim id-4 |
| `getBearerTokenProvider` | `import { getBearerTokenProvider } from '@azure/identity'` | `getBearerTokenProvider(credential, scopes: string \| string[], options?) => () => Promise<string>`. **It caches**: 3 concurrent calls plus 1 later call made 1 `getToken`, and 12 concurrent `AzureChatOpenAI.invoke` calls over one provider made 1 `getToken`. Build one per scope and reuse it | **run:** `s11`; `$JF/llm-globalfetch.mjs` (`requests: 12, getToken: 1`); **read:** `dist/esm/tokenProvider.d.ts:38`; claim id-2 |
| `getBearerTokenProvider`, rejection | — | **A rejection is shared, not cached.** Over a credential whose first `getToken` rejects: 12 concurrent provider calls all rejected with 1 `getToken`, and a 13th call made a 2nd `getToken` and resolved. Through `AzureChatOpenAI` with `maxRetries: 2`, 12 concurrent invokes all **resolved** (the model's `AsyncCaller` retried), with exactly 2 `getToken` calls in about 1.9 s, and a 13th invoke made none. With `maxRetries: 0` all 12 rejected with "Failed to get token from 'apiKey' function: …" | **run:** `$JF/provider-reject.mjs`; `$JF/llm-tokenfail.mjs 2` and `llm-tokenfail.mjs 0` |
| Azure OpenAI scope | — | `'https://cognitiveservices.azure.com/.default'` | **MCP:** `docs-langchain` `/oss/javascript/integrations/chat/azure.mdx` lines 134–157; **run:** `s03` (the scope reached `getToken`) |
| `TokenCredential` | type | any object with `async getToken(scopes) => { token, expiresOnTimestamp }`. This is the test double | **run:** `fakes.mjs` in `s03`, `s11` |
| `ChainedTokenCredential` | `import { ChainedTokenCredential } from '@azure/identity'` | `new ChainedTokenCredential(...credentials)` | **run:** `s11` |
| `CredentialUnavailableError`, `AuthenticationError`, `AggregateAuthenticationError` | `@azure/identity` | see the error contract below | **run:** `s11` |

**Error contract** (this settles the refuted claim id-8, by **run:** `s11` and **read:**
`chainedTokenCredential.js` 69–82):

- When every credential throws `CredentialUnavailableError`, the chain rejects with
  `AggregateAuthenticationError`. Its `.errors` holds one entry per credential that threw
  `CredentialUnavailableError` or `AuthenticationRequiredError`. It does **not** hold one entry
  per chain member: `DefaultAzureCredential`'s placeholders for credentials that could not be
  constructed add nothing.
- A credential that was reached and **rejected** (`AuthenticationError`) is thrown **as-is**,
  not wrapped. `s11` threw `AuthenticationError` with status 400 from the middle of a chain.

---

## 9. Azure SQL — `mssql` over `tedious`

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `sql.ConnectionPool` | `import sql from 'mssql'` | `new sql.ConnectionPool(config)` **does no I/O**. `pool.connected === false`. `pool.config` is readable (`port` defaults to 1433) | **run:** `s05`, `ref-run.mjs`; claim sql-11 |
| `pool.connect()` | — | returns a Promise that resolves to the pool. **Concurrent calls are coalesced into one physical attempt.** On failure every caller gets the same error instance, and a later call retries | **run:** `s05b` (3 callers made 1 attempt with the same `ESOCKET` error, and a retry made attempt 2); `$JF/proj/tests/unit/dns.test.js` (12 concurrent `execute` calls: 1 `dns.lookup`, all 12 rejected with the same `ConnectionError` instance, code `ESOCKET`; a 13th call made lookup 2); claim sql-12 |
| hostname resolution | — | tedious resolves the server through `_dns.default.lookup`, read when it connects, so `t.mock.method(dns, 'lookup', ...)` on `node:dns`'s default export is an offline seam that opens no socket, and it replaces the §14.8 blocker for that test | **read:** `tedious/lib/connection.js:1260` (`connect(connectOpts, _dns.default.lookup, signal)`); **run:** `$JF/proj/tests/unit/dns.test.js` under `npm test` with the network preload |
| login failure code | — | a failed login is `ConnectionError` `'Login failed.'`, code **`ELOGIN`** | **read:** `tedious/lib/connection.js` 2388, 2437, 2523 |
| `options.maxRetriesOnTransientErrors`, `options.connectionRetryInterval` | tedious defaults **3** and **500** ms, applied when tedious builds its `Connection`. A login that fails with a transient error (SQL errors 4060, 10928, 10929, 40197, 40501, 40613) is retried after the interval. `new sql.ConnectionPool(config)` without them leaves both keys out of `pool.config.options`. `parseConnectionString` drops `ConnectRetryCount` and turns `ConnectRetryInterval=10` into `connectionRetryInterval: 10000` | **run:** `$JA/s01-retry-defaults.mjs`; **read:** `tedious/lib/connection.js` 66, 459, 490, 1133, 2341–2354, `tedious/lib/transient-error-lookup.js`, `mssql/lib/base/connection-pool.js` 170–175 |
| `pool.close()` | — | resolves to the pool on a pool that never connected. It rejects with `ConnectionError` "Cannot close a pool while it is connecting" | **run:** `s05`; claim sql-13 |
| `pool.on('error', fn)` | — | **Required.** An EventEmitter `'error'` with no listener kills the process (exit 1), and the mssql pool re-emits connection errors as `'error'` | **run:** `node -e "new EventEmitter().emit('error', …)"` exited 1; **read:** `mssql/lib/tedious/connection-pool.js:112`; `ref/database.mjs` attaches it |
| `pool.request().input(name, value)` / `.input(name, type, value)` | — | chains. Referenced as `@name` and bound server-side through `sp_executesql`. A bad name throws `RequestError` `EINJECT`, and a duplicate name throws `EDUPEPARAM`. `undefined`/`NaN` become NULL | **run:** `s05`, `ref-run.mjs`; claim sql-14 |
| `request.query(statement)` | — | `Promise<{ recordsets, recordset, output, rowsAffected }>`. `recordset` rows are **objects keyed by column name**, so alias computed columns (`COUNT(*) AS tableCount`). On a pool that is not connected it **rejects** with `ConnectionError` `ECONNCLOSED` | **run:** `s05`; claim sql-14 |
| `sql.NVarChar(n)`, `sql.MAX` | — | `{ type: sql.NVarChar, length: n }`; `sql.MAX === 65535` | **run:** `s05` |
| `sql.ConnectionError`, `sql.RequestError` | — | error classes with a string `code` | **run:** `s05`, `s05b` |
| pool config defaults | — | tarn `max: 10`, `min: 0`, `idleTimeoutMillis: 30000`. `connectTimeout`/`requestTimeout` default to 15000 ms. `encrypt: true`, `trustServerCertificate: false` | claims sql-8, sql-9, sql-10 |
| `requestTimeout` | — | milliseconds, top level of the config | **run:** `s05`; claim sql-9 |
| `options.encrypt` | — | `true` by default. `'strict'` (TDS 8) type-checks and is accepted by tedious, but has not been tried against Azure SQL (§16) | claim sql-8 |

### 9.1 Authentication types

tedious 20 accepts exactly these values (claim sql-2): `default`, `ntlm`,
`token-credential`, `azure-active-directory-password`, `azure-active-directory-access-token`,
`azure-active-directory-msi-vm`, `azure-active-directory-msi-app-service`,
`azure-active-directory-service-principal-secret` and `azure-active-directory-default`.
Any other value makes `connect()` reject with a `TypeError`.

| Form | Behaviour | Verified by |
|---|---|---|
| `{ type: 'azure-active-directory-default', options: { clientId } }` | tedious builds `new DefaultAzureCredential({ managedIdentityClientId: clientId })` **on every physical login**. The config reads back offline. Omit `clientId` for a system-assigned identity | **run:** `s05`, `ref-run.mjs`; claim sql-3, sql-7 |
| `{ type: 'token-credential', options: { credential } }` | the **same** credential instance reaches tedious, so one token cache can be shared with Azure OpenAI | **run:** `s05` (identity check); claim sql-5 |
| `azure-active-directory-msi-vm` / `-msi-app-service` | `new ManagedIdentityCredential(clientId?)`. They do not work on a laptop, and they hang rather than fail fast there | claim sql-4, sql-6 |
| top-level `clientId` merged with `authentication.options` | a **shallow** `Object.assign`: if `authentication.options` is given at all (even `{}`), the top-level `clientId` is dropped | claim sql-7 |
| connection-string form | **Do not transliterate** the ODBC string. `ConnectionPool.parseConnectionString` maps `Authentication=ActiveDirectoryMsi;Encrypt=strict` to `{ authentication_type: 'default', options: { encrypt: true } }`, which is a SQL login and not TDS 8 strict | **run:** `sql.ConnectionPool.parseConnectionString(...)` in `$JW` |

---

## 10. Inbound Entra ID token validation — `jose` (this is not `@azure/identity`)

`@azure/identity` gets outbound tokens. Validating a caller's bearer token is a different job,
done here by `jose` against Entra's published JWKS.

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `createRemoteJWKSet` | `import { createRemoteJWKSet } from 'jose'` | `createRemoteJWKSet(url: URL, options?)`. **The URL must be a `URL` instance**; a string throws `TypeError`. **It fetches nothing until the first verify.** Concurrent first verifies share one fetch. Defaults: `timeoutDuration` 5000, `cooldownDuration` 30000, `cacheMaxAge` 600000 (ms) | **run:** `s06` (under the no-network preload), `ref-run.mjs`; **read:** `dist/webapi/jwks/remote.js:42`; claims jose-1, jose-2 |
| `jwtVerify` | `import { jwtVerify } from 'jose'` | `await jwtVerify(token, jwks, { algorithms: ['RS256'], audience, issuer })` → `{ payload, protectedHeader, key? }`. `exp`/`nbf` are enforced. **A token with no `oid` still verifies**: `payload.oid === undefined`, so require it (next row) | **run:** `s06`, `ref-run.mjs`; claim jose-3 |
| `requiredClaims` (jwtVerify option) | — | `requiredClaims: ['oid']` rejects a token without `oid` as `JWTClaimValidationFailed`, code `ERR_JWT_CLAIM_VALIDATION_FAILED`, `claim` `'oid'`, `reason` `'missing'`. A token with `oid` verifies unchanged | **run:** `$JF/v-jose.mjs` (`requiredClaims missing oid -> JWTClaimValidationFailed ERR_JWT_CLAIM_VALIDATION_FAILED oid missing`); **read:** `dist/webapi/lib/jwt_claims_set.js:64` |
| `globalThis.fetch` read time | — | `createRemoteJWKSet` reads the global `fetch` when it fetches, not when it is built: `fetchJwks(url, headers, signal, fetchImpl = fetch)`. A stub installed after `createRemoteJWKSet` served the key set | **read:** `dist/webapi/jwks/remote.js:10`; **run:** `$JF/jose-calltime.mjs` (`after-construction stub used: o hits 1`) |
| `decodeProtectedHeader` | `import { decodeProtectedHeader } from 'jose'` | `{ alg, kid }` **without verifying**. On garbage it throws a plain `TypeError`, not a `JOSEError` | **run:** `s06`; claim jose-7 |
| `errors` | `import { errors } from 'jose'` | every class extends `errors.JOSEError` and carries `.code` | **run:** `s06`; claim jose-5 |
| test-only: `generateKeyPair`, `exportJWK`, `SignJWT`, `createLocalJWKSet` | `jose` | `generateKeyPair('RS256', { extractable: true })`; `new SignJWT(claims).setProtectedHeader({ alg, kid }).setIssuer().setAudience().setIssuedAt().setExpirationTime('5m').sign(privateKey)`; `createLocalJWKSet({ keys: [...] })` is jose's real resolver over a local key set | **run:** `s06`, `ref-run.mjs` |
| `errors.JWTClaimValidationFailed` constructor | — | `new errors.JWTClaimValidationFailed(message, payload, claim?, reason?)`, where reason is `'check_failed' \| 'invalid' \| 'mismatch' \| 'missing' \| 'unspecified'` | **read:** `dist/types/util/errors.d.ts:14,45`; **run:** `ref-run.mjs` |

### Failure contract (**run:** `s06`)

| Input | Class | `code` | `claim` |
|---|---|---|---|
| expired | `JWTExpired` | `ERR_JWT_EXPIRED` | `exp` |
| unknown `kid` | `JWKSNoMatchingKey` | `ERR_JWKS_NO_MATCHING_KEY` | — |
| foreign key under a published `kid` | `JWSSignatureVerificationFailed` | `ERR_JWS_SIGNATURE_VERIFICATION_FAILED` | — |
| wrong audience | `JWTClaimValidationFailed` | `ERR_JWT_CLAIM_VALIDATION_FAILED` | `aud` |
| wrong issuer | `JWTClaimValidationFailed` | `ERR_JWT_CLAIM_VALIDATION_FAILED` | `iss` |
| malformed | `JWSInvalid` | `ERR_JWS_INVALID` | — |
| HS256 against `algorithms: ['RS256']` | `JOSEAlgNotAllowed` | `ERR_JOSE_ALG_NOT_ALLOWED` | — |
| JWKS endpoint unreachable | **`TypeError`** ("fetch failed"), **not a `JOSEError`**, with no `code` | — | — |
| JWKS endpoint answers non-200 (503) | the **base** `JOSEError` (not a subclass), "Expected 200 OK from the JSON Web Key Set HTTP response" | `ERR_JOSE_GENERIC` | — |
| JWKS endpoint answers 200 with a body that is not JSON (`<html>`) | the base `JOSEError`, "Failed to parse the JSON Web Key Set HTTP response as JSON" | `ERR_JOSE_GENERIC` | — |
| JWKS endpoint answers 200 with JSON that is not a key set (`{"no":1}`) | `JWKSInvalid`, a `JOSEError` subclass | `ERR_JWKS_INVALID` | — |
| JWKS endpoint hangs | `JWKSTimeout` / `ERR_JWKS_TIMEOUT` | | |

Audience and issuer failures share one class, so assert `code` plus `claim`. The unreachable
row was checked by **run:** `jwtVerify` against `http://127.0.0.1:1/keys`. The hanging row is
claim jose-4. The non-200, non-JSON and not-a-key-set rows are **run:** `$JF/v-jose.mjs` and
`$JF/jose-calltime.mjs`, and **read:** `dist/webapi/jwks/remote.js:20,24` (the only two
`new JOSEError(` in jose's `dist/webapi`) and `dist/webapi/jwks/local.js:30` (`JWKSInvalid`).
Four of the five endpoint failures are `JOSEError`s, so a status mapping classifies by `code`,
never by `instanceof errors.JOSEError` alone.

**PHI:** jose's claim errors carry the whole claim set as `payload`, `oid` included (port-map
§6). Never attach one as `cause` and never log it. Log `e.code`, `e.claim` and the `kid`.

### Entra facts (all **web:**)

| Fact | Value | Verified by |
|---|---|---|
| JWKS URI (v2.0) | `https://login.microsoftonline.com/{tenant-id}/discovery/v2.0/keys` (the `jwks_uri` of the v2.0 metadata) | **web:** `WebFetch(learn.microsoft.com/en-us/entra/identity-platform/access-tokens)` — "Validate the signing key issuer" |
| metadata URL | v2.0: `https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration`. For v1.0, drop `/v2.0`. The token's `ver` claim decides which | **web:** same page — "v1.0 and v2.0 tokens" |
| issuer (v2.0, single tenant) | `https://login.microsoftonline.com/{tenant-id}/v2.0`. "If the token issued is a v2.0 token … the URI ends in `/v2.0`." It must exactly match `iss` | **web:** same page; `WebFetch(.../access-token-claims-reference)` (`iss` row) |
| `aud` | "In v2.0 tokens, this value is always the client ID of the API." "This value must be validated" | **web:** access-token-claims-reference (`aud` row) |
| `oid` | "The immutable identifier for the requestor, which is the verified identity of the user or service principal." A GUID string | **web:** access-token-claims-reference (`oid` row) |
| algorithm | "Microsoft Entra ID issues tokens signed using … asymmetric encryption algorithms, such as RS256"; select the key by `kid` | **web:** access-tokens |
| key refresh | "A reasonable frequency to check for updates to the public keys … is every 24 hours." jose's 10-minute `cacheMaxAge` is well inside that, so leave it untuned | **web:** access-tokens |

---

## 11. Logging — pino 10

| Symbol | Import | Signature / usage | Verified by |
|---|---|---|---|
| `pino(options, destination)` | `import pino from 'pino'` | `pino({}, pino.destination({ dest: 1, sync: true }))` — a sync stdout destination **adds no `exit` listener** | **run:** `s07`, `ref-run.mjs` |
| `pino()` with no destination | — | an async SonicBoom on fd 1, plus one shared `exit` listener. No active handles or timers | claim C27, pino-6 |
| `logger.child(bindings)` | — | adds the bindings to every line. A child with no level of its own **follows later root level changes** | **run:** `s07`; claim pino-3 |
| `log.<level>(fields, 'literal message')` | — | **fields first.** `log.info('msg', { k })` **drops** `k`, because extra arguments are printf values | **run:** `s07`; claim pino-1 |
| `logger.level` | — | default `'info'`. The levels are `trace` 10, `debug` 20, `info` 30, `warn` 40, `error` 50, `fatal` 60, plus `silent`. **Lower case only**: `'INFO'` throws `unknown level` | **run:** `s07`; claim pino-4 |
| `logger.isLevelEnabled(level)` | — | boolean | claim pino-4 |
| `{ err }` key | — | an `Error` under `err` serialises as `{ type, message, stack, ...own props }`, including the `cause` chain. **No other key is serialised as an error** | **run:** `s07`; claim pino-2 |
| `redact` | — | `string[]` or `{ paths, censor?, remove? }`. It supports wildcards (`*.password`); the default censor is `'[Redacted]'` | claim pino-5 |
| `logger.flush()` | — | exists (`pino.final` does not) | claim C27 |
| capturing output in a test | — | `t.mock.method(fs, 'writeSync', (fd, s) => ...)` on `node:fs`'s default export captures every line of the sync destination: one `warn` from a child came back as JSON with `module`, `reason` and `msg` as top-level keys, and after `logger.level = 'error'` the child's `warn` wrote nothing. The stub is restored after the test (`fs.writeSync` was the original in the next test) | **run:** `$JF/v-mock.test.mjs` under `node --test` (pass 2, skip 1) |

---

## 12. Node built-ins and tooling (Node v24.18.0; floor 22.13)

### 12.1 Modules

| Symbol | Usage | Verified by |
|---|---|---|
| `"type": "module"` | `.js` files are ESM | **run:** every script |
| package.json `"imports": { "#core/*": "./core/*" }` | `import { greet } from '#core/greet.js'` works in Node, `node --test` and `tsc`. **Without the extension it fails** with `ERR_MODULE_NOT_FOUND` | **run:** `proj/` (`npm test`, `tsc`); claim C01 |
| `'#/…'` subpaths | allowed only from **v24.14.0**, so they are forbidden under a 22 floor | claim C02 |
| `node:` prefix | `import { readFileSync } from 'node:fs'` | **run:** `ref/settings.mjs` |
| bare import from a copied file | a module copied into a temporary directory outside the repository resolves `zod` once that directory holds `symlinkSync(repoNodeModules, join(dir, 'node_modules'), 'junction')` | **run:** `$JA/s02-settings.mjs` |

### 12.2 Configuration reads

| Symbol | Usage | Verified by |
|---|---|---|
| `parseEnv` | `import { parseEnv } from 'node:util'`. `parseEnv(text)` → an object. It handles quotes and comments, returns `''` for `EMPTY=`, and **writes nothing into `process.env`** | **run:** `s04`, `ref-run.mjs` |
| `readFileSync(url, 'utf8')` | accepts a `URL`, so `new URL('../.env.local', import.meta.url)` makes the path independent of the cwd. A missing file throws with `code === 'ENOENT'` | **run:** `s04` (run with cwd `/`) |
| `process.loadEnvFile(path)` | **it mutates `process.env`** (it fills only missing keys, and the real env wins). A missing file throws `ENOENT`. Not experimental since v24.10.0 | claim C15, C16, C17 |
| `--env-file` / `--env-file-if-exists` | a missing file exits 9 / continues | claim C17 |
| `process.env.X = undefined` | stores the **string** `"undefined"`. `delete` is the only way to unset | **run:** `s04`; claim C18 |

`process.loadEnvFile` and `--env-file` are listed so tickets can reject them (§15). The
libraries in §5 and §8 read `process.env` on their own.

### 12.3 Test runner — `node:test`

| Symbol | Usage | Verified by |
|---|---|---|
| `test` | `import { test } from 'node:test'`. `test(name, fn)`, `test(name, { skip: reason }, fn)` | **run:** `proj/tests/unit/core/greet.test.js` |
| `assert` | `import assert from 'node:assert/strict'` | **run:** every script |
| `t.mock.fn(impl)` | `fn.mock.callCount()`, `fn.mock.calls[i].arguments` | **run:** `greet.test.js`; claim C19 |
| `t.mock.method(obj, name, impl)` | restored automatically after the test | **run:** `greet.test.js` |
| `t.mock.module` | **`undefined`** without `--experimental-test-module-mocks` (Stability 1.0) | **run:** `greet.test.js`; claim C20 |
| `node --test "tests/unit/**/*.test.js"` | **Quote the glob and always pass it.** Bare `node --test` also collects `tests/integration`, and a directory argument fails with `MODULE_NOT_FOUND` | **run:** `proj/` `npm test` (the integration file was not collected); claim C21 |
| per-test `{ skip: reason }` | the test is reported as skipped with its reason | **run:** `greet.test.js` |
| `--experimental-test-coverage` | still the flag name. Threshold flags (`--test-coverage-lines=N`) make the run exit 1 | claim C22 |

### 12.4 No-network proof

| Symbol | Usage | Verified by |
|---|---|---|
| `syncBuiltinESMExports` | `import { syncBuiltinESMExports } from 'node:module'`. Call it after patching built-ins, or named ESM imports (`import { lookup } from 'node:dns'`) keep the originals | **run:** `no-network.js` under every `--import` run; claim C25 |
| `--import <file>` | preloads the patch module | **run:** `run-all.sh` |
| `spawnSync(process.execPath, ['--import', preload, '--input-type=module', '-e', "await import('#core/x.js')"], { env: {}, cwd, encoding: 'utf8' })` | the child proof: assert `status === 0` and `stderr === ''`. A swallowed attempt still exits **99** | **run:** `greet.test.js` (both cases); `$JF/proj/tests/unit/spawn.test.js` with `no-spawn.js` (a swallowed `fetch` and a swallowed `execSync` each exited 99; importing `#core/llm.js` exited 0 with empty stderr) |
| `node --import <preload> --test "<glob>"` | the preload is loaded into **every test file's process**. A test file whose process ends with exit code 99 is reported failed, even when all its tests passed, and the run exits 1. The same file without the preload passes | **run:** `$JF/evidence/swallow.test.js` (with `--import tests/unit/no-network.js`: `✖ tests/unit/swallow.test.js`, exit 1; without: exit 0) |
| a test under the network preload | `t.mock.method(globalThis, 'fetch', ...)` and `t.mock.method(dns, 'lookup', ...)` replace the blocker for that test and restore it afterwards; `spawnSync` of a child still works, because the network-only preload leaves `child_process` alone | **run:** `$JF/proj` `npm test` (`llm.test.js`, `dns.test.js`, `spawn.test.js`: 8 of 8 pass) |
| `--permission` | **does not gate the network**, and there is no `--allow-net` | claim C24 |

### 12.5 Errors and process behaviour

| Symbol | Usage | Verified by |
|---|---|---|
| `class PacEHRError extends Error { name = this.constructor.name; }` | the subclass gets its own `name` and its stack line. `instanceof` holds through the chain. No own `cause` unless one is passed | **run:** `s08` |
| `new Error(msg, { cause })` | passing `{ cause: undefined }` still creates an own `cause` | **run:** `s08`; claim C28 |
| `Error.isError` | exists on Node 24 | **run:** `s08` |
| `structuredClone(err)` | loses subclass identity (`name === 'Error'`) | **run:** `s08` |
| unhandled rejection | the default crashes the process with exit 1. **Adding a listener disables the crash** | claim C29 |
| `process.once('SIGTERM', ...)` + `process.exitCode` | a clean exit 0 once the handles are closed | claim C30 |

### 12.6 npm 12

| Fact | Detail | Verified by |
|---|---|---|
| defaults | `save-exact=false`, `save-prefix=^`, `package-lock=true`, `engine-strict=false`, lockfile v3 | claim C32 |
| install scripts | dependency install scripts are blocked until `npm install-scripts approve <pkg>`. This tree has none | **run:** `npm install-scripts ls` in `$JW`; claim C32 |
| `npm ci` | installs from an in-sync lock file (exit 0). When `package.json` names a dependency the lock file lacks, it **refuses**: exit 1, `EUSAGE`, "`npm ci` can only install packages when your package.json and package-lock.json are in sync", "Missing: dep-b@1.0.0 from lock file" | **run:** `$JF/npmci` on npm 12.0.1 (two local `file:` packages; `ci.out`) |

### 12.7 Type checking JavaScript — `tsc --checkJs`

| Fact | Detail | Verified by |
|---|---|---|
| tsconfig | `{ allowJs, checkJs, noEmit, strict, module: 'nodenext', target: 'es2024', types: ['node'], skipLibCheck }`. `types: ['node']` needs `@types/node` | **run:** `proj/tsconfig.json`, `$JW/tsconfig.json` |
| catches a misspelled `AzureChatOpenAI` field | `TS2769 … 'azureOpenAIEndpiont' does not exist in type 'AzureChatOpenAIFields'. Did you mean to write 'azureOpenAIEndpoint'?` | **run:** `npx tsc -p proj` |
| catches a JSDoc `@param` violation | `TS2345` through the `#core/*` alias | **run:** same |
| the reference snippets in §14 type-check clean | exit 0 | **run:** `npx tsc -p $JW` |
| `@types/mssql` accepts `authentication: { type: 'azure-active-directory-default', options: { clientId } }` | no error | **run:** `proj/typo/llm.js` |

### 12.8 ESLint 10 as a test oracle

| Symbol | Usage | Verified by |
|---|---|---|
| `ESLint` | `import { ESLint } from 'eslint'`; `new ESLint({ overrideConfigFile: true, overrideConfig: [ { files, languageOptions, rules } ] })` | **run:** `s09` (`ESLint.version` 10.11.0) |
| `eslint.lintText(code, { filePath })` | → `[{ messages: [{ line, column, ruleId, message }] }]` | **run:** `s09` |
| `eslint.lintFiles(patterns)` | the same result shape, one per file. `new ESLint().lintFiles(['.'])` with `eslint.config.js` at the root linted every `.js` file and skipped the README-only folders. A folder list that includes a folder holding only `README.md` (`['core', 'chat', 'pacehr', 'tests']`, or `['chat']`) **throws** `AllFilesIgnoredError` ("All files matched by 'chat' are ignored.") | **run:** `$JF/lint-check.mjs` over `$JF/lint` |
| `no-restricted-properties` | `{ object: 'process', property: 'env' }` also catches `const { env } = process`; `{ object: 'globalThis', property: 'process' }` catches `globalThis.process.env` | **run:** `s09` |
| `no-restricted-imports` | `{ paths: ['node:process', 'process'] }` catches `import { env } from 'node:process'` | **run:** `s09` |
| `no-restricted-syntax` selectors | `CallExpression[callee.property.name=/^(trace\|debug\|info\|warn\|error\|fatal)$/][arguments.length>2]`, `… > TemplateLiteral`, `… > BinaryExpression`, `TaggedTemplateExpression[tag.property.name='query']`. Each flagged its planted violation, and `log.warn({ cause, kid }, 'literal')` / `log.info('ready')` stayed clean | **run:** `s09` |
| last argument is not a non-empty string literal | `${LOG} > :last-child:not(Literal[value=/./])`, with `LOG` as in §14.10. Together with `${LOG}[arguments.length>2]` it flagged each of ``log.info(`note ${x}`)``, `log.info('note ' + x)`, `log.info({ a }, 'x %s', a)`, `log.info({ a }, msg)`, `log.info(noteText)`, `log.info({ a })`, `log.error(err)` and `log.info('')` at its line, and passed `log.warn({ cause, kid }, 'bearer token rejected')`, `log.info('ready')` and `log.error({ err }, 'query failed')`. The env rules in the same config flagged all five env forms and were off for `core/settings.js` | **run:** `$JF/lint-check.mjs` with `$JF/lint/eslint.config.js` (`lint-check ok`) |

---

## 13. Azure Functions — Node.js v4 model

| Symbol / fact | Detail | Verified by |
|---|---|---|
| supported Node | **24** GA to April 30 2028, **22** GA to April 30 2027. Node 22 is the last version on Linux Consumption | **web:** claim C03 (supported-languages, updated 2026-09-17) |
| programming model | v4: "New projects should use v4." Linux version: `az functionapp config set --linux-fx-version "node\|22"`. Windows: `WEBSITE_NODE_DEFAULT_VERSION=~22`. ESM is documented only as the `.mjs` extension, marked **preview** | **web:** claim C05 |
| base images | `mcr.microsoft.com/azure-functions/node:4-node22` and `:4-node24` (plus `-appservice`, and `4-node24-chiseled`). **There are no `-slim` tags for 22/24** | **web:** claim C04 (MCR manifests) |
| `app` | `import { app } from '@azure/functions'` | **run:** `s12` |
| `app.http(name, options)` | `options: { route?, methods?: HttpMethod[], authLevel?: 'anonymous' \| 'function' \| 'admin', handler }`. Also `app.get(...)` / `app.post(...)` | **read:** `types/app.d.ts:34,69`, `types/http.d.ts:42–82`; **run:** `s12` |
| `HttpHandler` | `(request: HttpRequest, context: InvocationContext) => HttpResponseInit \| HttpResponse \| Promise<...>` | **read:** `types/http.d.ts:37` |
| `HttpRequest` | `request.headers` is a Fetch `Headers` (**case-insensitive `.get`**). `request.query` is `URLSearchParams`. `request.params` holds the route params. `await request.json()` / `.text()`. `new HttpRequest(init)` is "for testing purposes only" | **read:** `types/http.d.ts:104–173`; **run:** `s12` |
| `request.json()` on a malformed body | rejects with `SyntaxError` (seen in test mode, not on the host) | **run:** `s12` |
| `HttpResponseInit` | `{ status?, jsonBody?, body?, headers? }`. `jsonBody` wins over `body` | **read:** `types/http.d.ts:231–250` |
| `HttpMethod` | `'GET' \| 'POST' \| 'DELETE' \| 'HEAD' \| 'PATCH' \| 'PUT' \| 'OPTIONS' \| 'TRACE' \| 'CONNECT'` | **read:** `types/http.d.ts:222` |
| `InvocationContext` | `invocationId`, `functionName`, `log(...args)` | **read:** `types/InvocationContext.d.ts:28–50` |
| `app.hook.appStart(handler)` / `app.hook.appTerminate(handler)` | each takes **one** argument and returns `Disposable`. appTerminate "will not be executed if your application is terminated forcefully. Hooks have a limited time to execute" | **read:** `types/hooks/registerHook.d.ts:15,25`; **run:** `s12`; claim C06 |
| outside the host | importing and calling `app.http` prints "Switching … to test mode" and skips registration. It does not throw | **run:** `s12` |

---

## 14. Working reference snippets — every one was run

Each snippet below is the **exact content** of a file under `$JW/ref/`.
`node --import ./no-network.js ref-run.mjs` exercised all of them with network and
child-process calls blocked, using a fake `fetch` and a fake `TokenCredential`, and exited 0.
`npx tsc -p .` over `ref/` exited 0 as well. Snippets 14.8–14.10 are self-contained scripts
that were run directly. Snippets 14.6 and 14.8 were replaced in the review round, and each now
names its `$JF` file and the run that exercised it.

### 14.1 Azure OpenAI chat model (`ref/llm.mjs`)

```js
import { DefaultAzureCredential, getBearerTokenProvider } from '@azure/identity';
import { AzureChatOpenAI } from '@langchain/openai';

const COGNITIVE_SERVICES_SCOPE = 'https://cognitiveservices.azure.com/.default';

/**
 * Azure OpenAI chat model. Every Azure field is passed explicitly: an omitted one falls back to process.env.
 * @param {{ endpoint: string, deployment: string, apiVersion: string, modelName: string, apiKey?: string, clientId?: string }} config
 * @param {import('@azure/identity').TokenCredential} [credential]
 */
export function buildChatModel(config, credential = new DefaultAzureCredential(
  config.clientId ? { managedIdentityClientId: config.clientId } : {})) {
  const authentication = config.apiKey
    ? { azureOpenAIApiKey: config.apiKey }
    : { azureADTokenProvider: getBearerTokenProvider(credential, COGNITIVE_SERVICES_SCOPE) };
  return new AzureChatOpenAI({
    model: config.modelName,                       // drives model.profile, and so the structured-output strategy
    azureOpenAIEndpoint: config.endpoint,          // no trailing slash
    azureOpenAIApiDeploymentName: config.deployment,
    azureOpenAIApiVersion: config.apiVersion,
    maxRetries: 2,
    ...authentication,
  });
}
```

Run result: the managed-identity branch sent `Authorization: Bearer TOKEN` to
`https://r.openai.azure.com/openai/deployments/gpt-5-5-prod/chat/completions?api-version=2024-10-21`.
The key branch sent `api-key`. The `DefaultAzureCredential` branch built with the network blocked.

### 14.2 Agent with structured output (`ref/agent.mjs`)

```js
import * as z from 'zod';
import { createAgent, providerStrategy } from 'langchain';

export const EncounterSummary = z.object({
  complaint: z.string().describe("Chief complaint in the clinician's words"),
  followUpDays: z.number().int().describe('Days until follow-up'),
}).describe('Structured summary of one encounter');

/** @param {import('@langchain/openai').AzureChatOpenAI} model @param {string} note */
export async function summarise(model, note) {
  const agent = createAgent({
    model,
    tools: [],
    systemPrompt: 'You summarise clinical encounters.',
    responseFormat: providerStrategy(EncounterSummary),
  });
  const result = await agent.invoke({ messages: [{ role: 'user', content: note }] });
  return result.structuredResponse;
}
```

Run result: `{ complaint: 'cough', followUpDays: 7 }`, with `response_format.type === 'json_schema'` on the wire.
In production the agent is compiled once, not per call (CLAUDE.md "The agent"). The per-call
`createAgent` here only keeps the snippet short.

### 14.3 Middleware that blocks and still audits (`ref/middleware.mjs`)

```js
import * as z from 'zod';
import { AIMessage, createMiddleware } from 'langchain';

/** Blocks a request with jumpTo 'end' (never by throwing), so afterAgent still writes the audit row. */
export function auditedGuard(/** @type {(row: object) => void} */ writeAudit) {
  return createMiddleware({
    name: 'AuditedGuard',
    stateSchema: z.object({ blocked: z.boolean().default(false) }),
    contextSchema: z.object({ callerOid: z.string() }),
    beforeAgent: {
      canJumpTo: ['end'],
      hook: (state) => {
        if (String(state.messages.at(-1)?.content).includes('BLOCK')) {
          return { blocked: true, messages: [new AIMessage('Request blocked.')], jumpTo: 'end' };
        }
      },
    },
    afterAgent: (state, runtime) => {
      writeAudit({ callerOid: runtime.context.callerOid, blocked: state.blocked, messages: state.messages.length });
    },
  });
}
```

Run result: two invocations, one blocked, made **1** model call in total and wrote **2** audit rows (`blocked: true`, then `false`).

### 14.4 `.env.local` without touching `process.env` (`ref/settings.mjs`)

```js
import { readFileSync } from 'node:fs';
import { parseEnv } from 'node:util';

/** The optional .env.local as a plain object. Writes nothing into process.env; only a missing file is tolerated. */
export function readEnvFile(/** @type {URL} */ url) {
  try {
    return parseEnv(readFileSync(url, 'utf8'));
  } catch (error) {
    if (/** @type {NodeJS.ErrnoException} */ (error).code === 'ENOENT') return {};
    throw error;
  }
}
// Caller: const values = { ...readEnvFile(new URL('../.env.local', import.meta.url)), ...process.env };
```

### 14.5 Azure SQL pool and parameterised execute (`ref/database.mjs`)

```js
import sql from 'mssql';

export const SCHEMA_EXISTS_SQL =
  'SELECT COUNT(*) AS tableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = @schema';

/** A pool is configuration until its first connect(): building one opens nothing. */
export function buildPool(/** @type {{ server: string, database: string, clientId?: string }} */ config) {
  const pool = new sql.ConnectionPool({
    server: config.server,
    database: config.database,
    authentication: {
      type: 'azure-active-directory-default',
      options: config.clientId ? { clientId: config.clientId } : {},
    },
    options: { encrypt: true },
    requestTimeout: 10_000,
  });
  pool.on('error', (error) => console.error({ code: error.code }, 'sql pool error')); // an unheard 'error' kills the process
  return pool;
}

/** Every value is bound server-side as @name; the statement is a module constant. */
export async function execute(/** @type {import('mssql').ConnectionPool} */ pool, /** @type {string} */ statement, params = {}) {
  const request = (await pool.connect()).request();   // mssql coalesces concurrent connect() calls
  for (const [name, value] of Object.entries(params)) request.input(name, value);
  return (await request.query(statement)).recordset;
}
```

Run result: `pool.config.authentication` read back offline. A hostile schema value arrived
intact as the bound `schema` input against a stub pool. The live `connect()` behaviour is in
`s05`/`s05b`. `console.error` stands in for the project logger only to keep the snippet
standalone.

### 14.6 Inbound bearer token to `oid` (`$JF/ref/auth.mjs`)

```js
import { createRemoteJWKSet, jwtVerify } from 'jose';

/** Built once and reused: the key cache lives on this function. Fetches nothing until the first verify. */
export const jwksFor = (/** @type {string} */ tenantId) =>
  createRemoteJWKSet(new URL(`https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`));

/** @returns {Promise<string>} the caller's oid */
export async function verifyBearer(/** @type {string} */ token, /** @type {any} */ jwks, /** @type {{ tenantId: string, audience: string }} */ { tenantId, audience }) {
  const { payload } = await jwtVerify(token, jwks, {
    algorithms: ['RS256'],
    audience,
    issuer: `https://login.microsoftonline.com/${tenantId}/v2.0`,
    requiredClaims: ['oid'],   // a missing oid rejects as JWTClaimValidationFailed, claim 'oid', reason 'missing'
  });
  return /** @type {string} */ (payload.oid);   // Entra's oid is a GUID string
}
```

Run result: `$JF/v-jose.mjs` imports this file. With a `createLocalJWKSet` stand-in, `'oid-1'`
came back, and a token without `oid` was rejected by `requiredClaims` with code
`ERR_JWT_CLAIM_VALIDATION_FAILED` and claim `oid`. The failure-contract rows in §10 came back
unchanged. `tsc -p` over this file alone (`checkJs`, `strict`) exited 0. The earlier `$JW`
version built its own `JWTClaimValidationFailed` for a missing `oid`; `requiredClaims` replaces
it.

### 14.7 Root logger (`ref/logging.mjs`)

```js
import pino from 'pino';

export const logger = pino({}, pino.destination({ dest: 1, sync: true }));   // adds no exit listener
// Module use: const log = logger.child({ module: 'core.auth' }); log.warn({ cause: e.code }, 'bearer token rejected');
```

### 14.8 No-network preloads (`$JF/proj/tests/unit/no-network.js` and `no-spawn.js`)

`no-network.js` is loaded with `--import` by `npm test`, so every unit test file runs under it:

```js
// --import preload for every unit test: any network attempt throws and forces exit code 99.
import net from 'node:net';
import tls from 'node:tls';
import dns from 'node:dns';
import dnsPromises from 'node:dns/promises';
import http from 'node:http';
import https from 'node:https';
import { syncBuiltinESMExports } from 'node:module';

export const block = (what) => () => {
  process.exitCode = 99;
  const error = new Error(`network blocked: ${what}`);
  error.code = 'ERR_NETWORK_BLOCKED';
  throw error;
};
net.connect = net.createConnection = block('net.connect');
net.Socket.prototype.connect = block('net.Socket#connect');
tls.connect = block('tls.connect');
dns.lookup = block('dns.lookup');
dnsPromises.lookup = block('dns/promises.lookup');
http.request = http.get = block('http.request');
https.request = https.get = block('https.request');
globalThis.fetch = block('fetch');
syncBuiltinESMExports(); // without this, `import { lookup } from 'node:dns'` keeps the original
```

`no-spawn.js` is the preload for the import-proof child. It adds `child_process`, which the suite
itself cannot block, because its tests spawn children:

```js
// --import preload for the import-proof child: the network block plus child_process, which DefaultAzureCredential spawns.
import childProcess from 'node:child_process';
import { syncBuiltinESMExports } from 'node:module';
import { block } from './no-network.js';

for (const name of ['spawn', 'spawnSync', 'exec', 'execSync', 'execFile', 'execFileSync', 'fork']) {
  childProcess[name] = block(`child_process.${name}`);
}
syncBuiltinESMExports();
```

Run result: `$JF/proj` `npm test` passed 8 of 8 with `no-network.js` preloaded (§12.4 rows), and
`spawn.test.js` proved `no-spawn.js` exits 99 on a swallowed `fetch` and on a swallowed
`execSync`. The earlier single-file `$JW/no-network.js`, which blocked both in one file, is
`$JF/no-network-full.js`; the §5.1 tracing probes ran under it. The original child-process test
is in `$JW/proj/tests/unit/core/greet.test.js`, which passed under `npm test`.

### 14.9 Lazy member — the `cached_property` shape (`$JW/s13-lazy-member.mjs`)

```js
// The cached_property shape: a prototype getter that replaces itself with an own value on first read.
import assert from 'node:assert/strict';
let builds = 0;
const buildClient = () => ({ id: ++builds });

class Manager {
  get client() {
    const value = buildClient();
    Object.defineProperty(this, 'client', { value, configurable: true });
    return value;
  }
}

const m = new Manager();
assert.equal(Object.hasOwn(m, 'client'), false);          // nothing built at construction
assert.equal(m.client, m.client); assert.equal(builds, 1);
assert.throws(() => { m.client = 1; }, TypeError);        // ESM is strict: assignment onto the value throws
delete m.client; assert.equal(m.client.id, 2);            // delete is the reset
const seeded = new Manager();
Object.defineProperty(seeded, 'client', { value: 'stub', configurable: true });
assert.equal(seeded.client, 'stub'); assert.equal(builds, 2); // a seed skips the getter
const fresh = new Manager(); assert.throws(() => { fresh.client = 1; }, TypeError); // getter-only accessor
console.log('s13 ok');
```

### 14.10 ESLint guard as a test (`$JW/s09-eslint.mjs`)

```js
// ESLint 10 Node API as a test oracle: the env-read and log-call guards, run with no config file.
import assert from 'node:assert/strict';
import { ESLint } from 'eslint';

const LOG = "CallExpression[callee.property.name=/^(trace|debug|info|warn|error|fatal)$/]";
const eslint = new ESLint({
  overrideConfigFile: true,
  overrideConfig: [{
    files: ['**/*.js'],
    languageOptions: { ecmaVersion: 'latest', sourceType: 'module' },
    rules: {
      'no-restricted-properties': ['error',
        { object: 'process', property: 'env' }, { object: 'process', property: 'loadEnvFile' }, { object: 'globalThis', property: 'process' }],
      'no-restricted-imports': ['error', { paths: ['node:process', 'process'] }],
      'no-restricted-syntax': ['error',
        { selector: `${LOG}[arguments.length>2]`, message: 'log call with more than two arguments' },
        { selector: `${LOG} > TemplateLiteral`, message: 'interpolated log message' },
        { selector: `${LOG} > BinaryExpression`, message: 'concatenated log message' },
        { selector: "TaggedTemplateExpression[tag.property.name='query']", message: 'tagged-template SQL' }],
    },
  }],
});

const lint = async (code) => (await eslint.lintText(code, { filePath: 'core/planted.js' }))[0].messages.map((m) => `${m.line}:${m.ruleId}`);
assert.deepEqual(await lint('const a = process.env.X;'), ['1:no-restricted-properties']);
assert.deepEqual(await lint('const { env } = process;'), ['1:no-restricted-properties']);
assert.deepEqual(await lint("import { env } from 'node:process';"), ['1:no-restricted-imports']);
assert.deepEqual(await lint('globalThis.process.env.X;'), ['1:no-restricted-properties']);
assert.deepEqual(await lint('\nlog.info(`note ${x}`);'), ['2:no-restricted-syntax']);
assert.deepEqual(await lint("log.info('a ' + x);"), ['1:no-restricted-syntax']);
assert.deepEqual(await lint("log.info({ a }, 'msg %s', x);"), ['1:no-restricted-syntax']);
assert.deepEqual(await lint('pool.query`select ${x}`;'), ['1:no-restricted-syntax']);
assert.deepEqual(await lint("log.warn({ cause, kid }, 'bearer token rejected'); log.info('ready');"), []);
console.log('ESLint.version', ESLint.version);
console.log('s09 ok');
```

Both scripts ran with `node` and exited 0 (`run-all.out`).

---

## 15. DO-NOT-USE

| Symbol | What it is | Use instead |
|---|---|---|
| `createReactAgent` (`@langchain/langgraph/prebuilt`) | `@deprecated` "`createReactAgent` has been moved to langchain package" (**read:** `react_agent_executor.d.ts:158`) | `createAgent` from `langchain` |
| `prompt:` / `llm:` on `createAgent` | Not `CreateAgentParams` keys. The API reference example still shows `llm:` (**MCP:** `get_symbol(createAgent)`), but at runtime it throws "`model` option is required" | `model:`, `systemPrompt:` |
| a bare schema as `responseFormat` | the strategy is then left to `model.profile`, and an alias silently falls back to ToolStrategy | `providerStrategy(schema)` |
| throwing from a hook to block a run | skips `afterAgent` and loses the audit row (**run:** `s02`) | `return { ..., jumpTo: 'end' }` with `canJumpTo: ['end']` |
| `catch (e) { if (e instanceof StructuredOutputParsingError) ... }` as the only structured-output handler | misses the `SyntaxError` a non-JSON output raises (**run:** `s01`) | handle both |
| omitting any Azure field on `AzureChatOpenAI` | silently falls back to `process.env` (§5.1) | pass endpoint, deployment, version, `maxRetries`, auth and `model` |
| `azureOpenAIApiInstanceName` / `azureOpenAIBasePath` | hardcoded domain / an alternate path | `azureOpenAIEndpoint` without a trailing slash |
| an endpoint with a trailing slash | produces `//openai/...` (**run:** `s03b`) | strip it in `settings()` |
| `'azure:<model>'` in `initChatModel` | throws "Unable to infer model provider" | `'azure_openai:<model>'` |
| `Command` / `MemorySaver` from `langchain` | not exported there | `@langchain/langgraph` |
| `import * as sql from 'mssql'` / named mssql imports | `undefined` (**run:** `s05`) | `import sql from 'mssql'` |
| `sql.connect(config)` (the global pool) | a second call with another config silently reuses the first pool (claim sql-15) | `new sql.ConnectionPool(config)` |
| `` pool.query`...${v}` `` / `` request.query`...` `` | tagged-template SQL. It binds values, but it breaks the "statement is a module constant" rule | a constant with `@name` and `.input()` |
| the ODBC connection string (`Authentication=ActiveDirectoryMsi;Encrypt=strict`) | mssql misparses it as SQL login `default` | an `authentication` object (§9.1) |
| `azure-active-directory-msi-*` for local runs | there is no IMDS endpoint, so it hangs (claim sql-6) | `azure-active-directory-default` or `token-credential` with `DefaultAzureCredential` |
| `createRemoteJWKSet('https://...')` (a string) | throws `TypeError` | `new URL(...)` |
| a new `createRemoteJWKSet` per request | loses the key cache and the fetch dedupe | build once per process |
| `catch (e) { if (e instanceof errors.JOSEError) → 401 }` treating everything else as unrelated | the unreachable failure is a `TypeError`, and a non-200, non-JSON or not-a-key-set answer is a `JOSEError` (§10), so an outage reaches the 401 path | classify by `code`: `ERR_JOSE_GENERIC`, `ERR_JWKS_INVALID`, `ERR_JWKS_TIMEOUT` and any non-`JOSEError` are endpoint failures |
| a jose error as `cause`, or logged | carries the claim set, including `oid` | log `code`, `claim`, `kid` |
| `log.info('message', { fields })` | the fields are dropped | `log.info({ fields }, 'message')` |
| `logger.level = 'INFO'` | throws | lower case |
| `pino.final` | removed | `logger.flush()` |
| `process.loadEnvFile` / `--env-file` / `dotenv` | writes into `process.env`, which §5 and §8 libraries read behind `settings()`'s back | `parseEnv(readFileSync(url))` (§14.4) |
| `process.env.X = undefined` | stores `"undefined"` | `delete process.env.X` |
| `t.mock.module` / `mock.module` | needs `--experimental-test-module-mocks` (Stability 1.0) | seed the instance member; `t.mock.fn` / `t.mock.method` |
| `node --test` with no glob, or with a directory | collects integration tests / fails | a quoted glob |
| `node --permission` as a network sandbox | does not gate the network | the `--import` preload (§14.8) |
| `'#/…'` import aliases | need Node ≥ 24.14 | `#core/*` |
| an extensionless import | `ERR_MODULE_NOT_FOUND` | write `.js` |
| a `process.on('unhandledRejection')` that only logs | disables Node's crash-on-rejection | no listener in `core/` |
| any AWS package, service or identifier — `@aws-sdk/*`, `@smithy/*`, `openai/bedrock`, `bedrockPromptCachingMiddleware`, `@langchain/aws`, `bedrock*` provider prefixes | out of scope by constraint | Azure OpenAI, `@azure/identity`, Azure SQL, Entra ID |
| `anthropicPromptCachingMiddleware` and other non-Azure provider middleware | exported by `langchain`, but not for an Azure OpenAI model | — |
| `-slim` Functions images for Node 22/24 | they do not exist (claim C04) | `4-node22` / `4-node24` |
| `_getModelInstance()` | a private method | only in verification scripts |
| `beforeModel: { canJumpTo: ['end'], ... }` to block a run | its `end` is the graph's `END`, so **`afterAgent` never runs** and the audit row is lost (§17.3) | block from `beforeAgent`, or short-circuit `wrapModelCall` with a `Command` |
| `modelSettings: { temperature }` on a `wrapModelCall` request | never reaches the wire (§17.2) | `temperature` on the `AzureChatOpenAI` constructor |
| a `wrapModelCall` `Command` that omits `structuredResponse` | the parsed output is lost from the result (§17.2) | copy `structuredResponse` from the handler result into the update |
| trusting `WrapModelCallHandler`'s declared `AIMessage` return | under a `responseFormat` it returns `{ structuredResponse, messages }` (§17.2) | narrow the result; the `AIMessage` is `messages.at(-1)` |
| a private (`_`-prefixed) key as `agent.invoke` input | dropped before the first hook (§17.4) | a public input key, overwritten in place by the hook that owns it |
| `.optional()` on a field of a strict provider schema | the field leaves `required` while `strict: true` is sent (§17.1) | `.nullable()` |
| `e.name === 'ContentFilterFinishReasonError'` | `name` is `'Error'` (§17.5) | `instanceof ContentFilterFinishReasonError` from `openai/error` |

---

## 16. Unverified — do not let a ticket assert these

1. **Zero-AWS and the lockfile.** `package-lock.json` will contain `@aws-sdk/credential-provider-node`,
   `@smithy/hash-node` and `@smithy/signature-v4` as openai's optional-peer metadata, and
   `node_modules/openai` ships `bedrock.*` files (§1.3). No AWS package is installed. Epic 1
   PEA-101 accepts the lockfile text, because none of the three is installed, imported or in
   source, and CLAUDE.md records it as accepted. The user has not yet confirmed that this
   satisfies "zero AWS identifiers anywhere". A test asserts that the `node_modules/@aws-sdk`
   and `node_modules/@smithy` directories are absent. It cannot make the lockfile text go away
   without dropping `@langchain/openai`.
2. **`"type": "module"` `.js` entry files on the Azure Functions host.** Learn documents ESM
   only as `.mjs`, marked preview (claim C05). Settle it with `func start` and a deployed smoke
   test in the entrypoint epic.
3. **Whether Azure OpenAI accepts `//openai/...`** (an endpoint with a trailing slash). It was
   not sent to a real resource. Strip the slash; do not rely on either answer.
4. **`providerStrategy` `strict: true` against the real deployment and API version.** Only the
   wire shape was verified, against a fake fetch. `profile.structuredOutput === true` for
   `'gpt-4.1'` is a LangChain profile value, not proof from Azure. Run one integration call
   before relying on provider enforcement. Epic 1's PEA-104 integration test checks text and
   `usage_metadata` only, so this passes to Epic 4's PEA-401.
5. **`options.encrypt: 'strict'` (TDS 8) against Azure SQL.** It type-checks and tedious
   accepts it (claim sql-8). No connection was made.
6. **Whether pino's stdout JSON reaches Application Insights with invocation correlation**,
   the way `InvocationContext.log` does. It was not measured on a host.
7. *Resolved.* The HTTP status for a key-endpoint failure is decided in Epic 1 PEA-106: 500.
   The library behaviour it rests on is in §10.
8. **The snippets on Node 22.** Everything in §14 ran on v24.18.0 only. The Node 22.23.3
   pass recorded in the design-decision report was on a different tree. The floor rests on
   the declared `engines` (§1.1), and `#core/*` under Node 22 rests on that report.
9. **Whether `ManagedIdentityCredential.getToken` honours its `abortSignal` off-Azure.** One
   check saw it hang past a 20 s signal (claim sql-6). A ticket must not promise a bound on
   local credential failure time.
10. **The column key mssql uses for an unaliased computed column** (`COUNT(*)`). Always alias it.
11. **tedious login-retry settings as an equivalent of ODBC `ConnectRetryCount`/`ConnectRetryInterval`.**
    The tedious defaults are now a §9 row, but they are a different mechanism, and neither
    side's values have a measurement against Azure SQL. Epic 1 PEA-103 keeps the tedious
    defaults and copies no ODBC value.
12. **`request.json()` behaviour on the real Functions host.** `SyntaxError` was seen only in
    the package's test mode (`s12`).
13. *Resolved.* `eslint.lintFiles` and the last-argument selector are now **run:** rows in §12.8.
14. **`humanInTheLoopMiddleware` at runtime.** Its rows rest on the docs (claim lc-24). No
    interrupt-and-resume was run here. Run one before Epic 5 names its decision shapes.
15. **Azure accepting the per-request strict schema.** Only the wire shape was captured (§17.1).
    OpenAI documents that strict mode needs every property in `required`; whether this
    deployment rejects an `.optional()` field, and accepts a `.nullable()` one, is unmeasured.
    Epic 4 PEA-401 runs it, once the Azure OpenAI firewall admits the caller (403 since
    2026-09-29).
16. **The `beforeModel` end-jump on a later `langchain`.** §17.3 reads like an inconsistency in
    1.5.14 (`ReactAgent.js` maps `END` to the `afterAgent` exit for `beforeAgent` and `afterModel`,
    not for `beforeModel`). Re-run `$JE/p2` on any upgrade; until then no hook blocks from
    `beforeModel`.

---

## 17. Agent core — what Epic 4 rests on (all **run:** `$JE`, 2026-10-05)

### 17.1 Per-request binding in `wrapModelCall`

| Fact | Detail | Verified by |
|---|---|---|
| per-request schema | `handler({ ...request, responseFormat: providerStrategy(schema) })` sends that schema (`strict: true`) and `result.structuredResponse` is parsed against it, not the compiled one | **run:** `$JE/p1` T1 |
| no compile-time `responseFormat` needed | an agent compiled with none still sends `response_format` and parses `structuredResponse` when `wrapModelCall` supplies it. No baseline schema is required | **run:** `$JE/p1` T1c |
| system prompt | `{ ...request, systemPrompt }` and `{ ...request, systemMessage }` each become the wire's first message, with or without a compile-time `systemPrompt` | **run:** `$JE/p1` T2a–T2c |
| messages | `agent.invoke({ messages: [] })` runs. `{ ...request, messages: [new HumanMessage(text), ...request.messages] }` sends exactly that list; state `messages` then holds only the AI reply | **run:** `$JE/p1` T3 |
| second pass after a tool | `request.messages` is `[assistant(tool_calls), tool]`, so the rebuilt wire list is `user, assistant, tool`. Order: `beforeModel > wrapModelCall > afterModel > wrapToolCall > beforeModel > wrapModelCall > afterModel`. `tools` and `response_format` travel together | **run:** `$JE/p1` T10 |
| a zod schema in state | a `z.custom()` state key carries the zod object from a hook to `wrapModelCall` intact | **run:** `$JE/p5` b |
| strict wire shape | `.optional()` drops the field from `required` while `strict: true` and `additionalProperties: false` are sent; `.nullable()` keeps it required as `type: ['string', 'null']` | **run:** `$JE/p4` strictWire |

### 17.2 What `wrapModelCall` gets back and how it writes state

| Fact | Detail | Verified by |
|---|---|---|
| handler result under a `responseFormat` | a plain object `{ structuredResponse, messages }`, **not** an `AIMessage`, although `WrapModelCallHandler` is typed `=> PromiseOrValue<AIMessage>` (`middleware/types.d.ts:127`). The `AIMessage` is `messages.at(-1)` | **run:** `$JE/p2` B; **read:** `langchain/dist/agents/middleware/types.d.ts` |
| handler result with no `responseFormat` | an `AIMessage` | **run:** `$JE/p3` |
| writing state | `return new Command({ update: { structuredResponse, ...fields } })` keeps the AI reply in `messages` and the parsed output in the result. A `Command` without `structuredResponse` loses it; returning a plain object with extra keys drops the keys | **run:** `$JE/p3` R1–R3, `$JE/p1` T4 |
| usage and model | on the `AIMessage`: `usage_metadata.input_tokens` / `output_tokens`, `response_metadata.model_name` (`'gpt-4.1-2025-04-14'` from the fake) | **run:** `$JE/p3` R3 |
| temperature | `modelSettings: { temperature: 0 }` is spread into the tool-binding options and **never reaches the wire**. `new AzureChatOpenAI({ temperature: 0 })` sends `temperature: 0`; with neither, the body has no `temperature` key | **run:** `$JE/p1` T7, `$JE/p2` A; **read:** `langchain/dist/agents/nodes/AgentNode.js:515-518` |
| `Command` import | `import { Command } from '@langchain/langgraph'` (§4.6) | **run:** all `$JE` scripts |

### 17.3 Which jumps still run `afterAgent`

| Hook that returns `{ jumpTo: 'end' }` (declared `canJumpTo: ['end']`) | Model calls | `afterAgent` runs | Verified by |
|---|---|---|---|
| `beforeAgent` (middleware first or last in the list) | 0 | **yes** | **run:** `$JE/p2` C1, C4 |
| `beforeModel` (first, last, or in the same middleware as `afterAgent`) | 0 | **no** | **run:** `$JE/p2` C2, C3, D |
| `afterModel` | 1 | **yes** | **run:** `$JE/p3` |
| `wrapModelCall` returning a `Command` without calling `handler` | 0 | **yes**, and it sees the `Command`'s update | **run:** `$JE/p5` a |

Cause: `ReactAgent.js` maps `END` to the last `afterAgent` node for `beforeAgent` and the model
routers (`:188`, `:201`, `:237`), but the `beforeModel` edges (`:209-212`) keep the graph's own
`END`. The docs say every `end` reaches the first `afterAgent`; 1.5.14 does not.

### 17.4 State and context

| Fact | Detail | Verified by |
|---|---|---|
| one shared `stateSchema` | two middleware passing the same zod object both read and write its keys (`'A'` then `'AB'`) | **run:** `$JE/p1` T11 |
| private keys | a `_`-prefixed key written by a hook is readable by later hooks and absent from the `invoke` result | **run:** `$JE/p5` c |
| private keys as input | `agent.invoke({ messages: [], _noteText })` — the first hook sees `undefined` | **run:** `$JE/p6` |
| public input keys | `agent.invoke({ messages: [], noteText })` — hooks read it, a hook may overwrite it, and it appears in the result | **run:** `$JE/p1` T3 |
| no persistence | `createAgent` without `checkpointer`/`store`: `agent.options` holds only the keys passed (`model`, `middleware`) | **run:** `$JE/p6` |

### 17.5 Failures inside `handler`, caught in `wrapModelCall`

Every row: thrown inside `handler`, so `wrapModelCall` can catch it. Uncaught, `invoke` rejects
with `MiddlewareError` and **`afterAgent` does not run**. Caught and turned into
`new Command({ update: { reasonCode } })`, `invoke` resolves after one request,
`structuredResponse` is `undefined`, and `afterAgent` runs and sees the reason code.

| Cause on the wire | Error caught | Verified by |
|---|---|---|
| JSON that violates the schema (`{"painScore":5}` for a string) | `StructuredOutputParsingError` (`langchain`) | **run:** `$JE/p1` T9, `$JE/p4` |
| content that is not JSON | `SyntaxError` | **run:** `$JE/p4` |
| `finish_reason: 'content_filter'`, `content: null` | `ContentFilterFinishReasonError` from `openai/error` (not the `openai` root); its `name` is `'Error'` | **run:** `$JE/p1` T6, `$JE/p4` |
| HTTP 400 with `error.code: 'content_filter'` (prompt filter) | `BadRequestError`, `status` 400, `code` `'content_filter'` | **run:** `$JE/p1` T6b, `$JE/p4` |
| HTTP 429 past `maxRetries` | `RateLimitError`, `status` 429 | **run:** `$JE/p4` |
| HTTP 500 past `maxRetries` | `InternalServerError`, `status` 500 | **run:** `$JE/p1` T5a–T5d |

`APIError` (the parent of the HTTP errors) and `ContentFilterFinishReasonError` are classes in the
transitive `openai` package, so importing them makes `openai` a direct dependency. Returning an
empty `AIMessage`, a `Command` with an empty `AIMessage`, or a `Command` with `goto: '__end__'`
also resolved with `afterAgent` run (`$JE/p1` T5b–T5d); the update-only `Command` is the
smallest.
