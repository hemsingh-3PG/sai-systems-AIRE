# Epic 5 — Azure Layer: Additions Beyond the JS Ticket

**Status:** **Approved by Hem Singh and built, 2026-10-15,** on `3p-dev/epic-05-Guardrails`, not pushed. Not in
`js-tickets/epic-05-guardrails.md`. X1 stays switched off until the admin's filter exists (the request is with the
admin, not yet done). X4 test 2 waits for that filter. See "As built" at the end
**Estimate:** about 2 points in total, outside the JS ticket's 16
**Code baseline:** `pacEHR_AI` branch `PacEHR-AI-Develop-Main` at `b93f989` (Epic 4 merged in PR 12886, 2026-10-15)
**Why it exists:** these items are the code side of the Azure content filter that the client's Azure admin is asked to
create ([Azure-Portal-Changes.md](../Azure/Azure-Portal-Changes.md) and the three client documents). The JS ticket only
touches this in one PEA-501 due-diligence item: *"Check whether the DEV deployment's content filter has prompt shields
turned on."*

---

## 1. Why these are kept, and kept apart

- **Azure's default filter blocks prompts rated Medium** for self-harm, violence, sexual content and hate. Clinical
  wording reaches that level, for example "Hx of suicidal ideation", "laceration from assault" or "sexual history".
  Such a note ends as `PROMPT_CONTENT_FILTERED` with zero recall. The JS ticket has no test for this.
- **Azure's filter fails open.** If the filtering system is unavailable, the call completes unfiltered. Our scanner
  (PEA-501) is the layer that can't fail open.
- **Every item is dormant until it's switched on.** None of them changes behaviour until
  `AZURE_OPENAI_CONTENT_FILTER_POLICY` is set or a jailbreak is refused. So they can merge independently of the JS
  stories.

| # | Item | Points | Needs |
|---|---|---|---|
| X1 | Select the filter per call with the `x-policy-id` header | 0.5 | Approval. The admin's filter must exist before the setting is set |
| X2 | `PROMPT_JAILBREAK_FILTERED` reason code, plus logging the filtered categories | 0.5 | Approval **and** the Epic 10 owner. Epic 10 reconciles the code list before freezing it |
| X3 | `injection attempt` warning with the clinician's ids | 0.5 | Approval. Replaces paid Defender AI threat protection (Q4) |
| X4 | Live test: Azure's filter doesn't refuse the benign corpus | 0.5 | X1, and the admin's dev filter |

**Dropped from our earlier pack, because they conflict with the JS ticket:**
- the configurable `MAX_NOTE_LENGTH_CHARS` setting (JS: a `MAX_NOTE_CHARS` constant);
- five `INJECTION_*` codes (JS: `INJECTION_BLOCKED` plus `patternClass`);
- `clinician-message.ts` (JS: a `BLOCKED_RUN_MESSAGE` constant);
- the ESLint no-throw rule (JS: behaviour tests).

---

## X1. `x-policy-id`: our code selects the filter

**`src/core/settings.ts`**, after `PORT`:

```diff
+  // Name of the Azure content filter (raiPolicy) each call selects with x-policy-id. Unset sends no header, so the
+  // deployment's attached filter applies. Set only once the filter exists on the resource.
+  AZURE_OPENAI_CONTENT_FILTER_POLICY: z.preprocess(unsetIfBlank, text.optional()),
```

- Add the name to `.env.example` below `PORT`, with a one-line comment, and leave it empty.
- `tests/unit/core/settings.test.ts:75`: append `'AZURE_OPENAI_CONTENT_FILTER_POLICY'` after `'PORT'` in the expected
  `OPTIONAL` list. The test at line 165 already checks that `.env.example` names every setting.
- This one is a setting under `CLAUDE.md` § Numbers, because it varies by environment.

**`src/core/llm.ts`**, `azureOpenaiGpt41Llm`:

```diff
-    const { azureOpenaiGpt41Deployment: deployment, azureOpenaiEndpoint: endpoint, azureOpenaiApiVersion } = settings();
-    log.info({ deployment, endpoint }, 'initialising azure openai model');
+    const { azureOpenaiGpt41Deployment: deployment, azureOpenaiEndpoint: endpoint, azureOpenaiApiVersion,
+      azureOpenaiContentFilterPolicy: policy } = settings();
+    log.info({ deployment, endpoint, policy }, 'initialising azure openai model');
     const value = new AzureChatOpenAI({
       ...
       timeout: REQUEST_TIMEOUT_MS,
+      // Azure applies the named content filter to each call; an Azure admin creates it (Azure-Portal-Changes.md).
+      ...(policy && { configuration: { defaultHeaders: { 'x-policy-id': policy } } }),
       ...this.authentication,
     });
```

| Setting | Effect |
|---|---|
| Unset | No header. The deployment's current filter applies, as today |
| Set, and the filter exists | Every call uses our filter |
| Set, and the filter doesn't exist | Azure answers `InvalidContentFilterPolicy`. The run ends as `MODEL_CALL_FAILED` and the `llm` health check goes red. This fails closed |

**Test:** in a new file, `tests/unit/core/llm.policy.test.ts` (one environment per file):
- delete `llmManager.azureOpenaiGpt41Llm`, stub `fetch` and invoke once;
- assert `x-policy-id` is in the request headers when the setting is set;
- in a second file, assert the header is absent when the setting is unset.

**Rollout:** add `AZURE_OPENAI_CONTENT_FILTER_POLICY: pacehr-clinical-extraction` to
`pipelines/variables/<env>-environment.yml` **only after the admin confirms the filter exists in that environment**.

## X2. `PROMPT_JAILBREAK_FILTERED`: tell an attack from a clinical false positive

**`src/agents/failure-modes.ts`:**

```diff
   PROMPT_CONTENT_FILTERED: { kind: 'MODEL_CALL' },
+  // Azure Prompt Shields refused the note as a jailbreak: the second layer caught what the scanner did not.
+  PROMPT_JAILBREAK_FILTERED: { kind: 'MODEL_CALL' },
```

**`src/agents/middleware/model-call.ts`** (against `b93f989`):

```diff
+type FilterResult = Record<string, { filtered?: boolean } | undefined>;
+
+/** The categories Azure's prompt filter blocked on: fixed names like 'jailbreak' or 'self_harm', never content. */
+export function filteredCategories(error: APIError): string[] {
+  const result = (error.error as { innererror?: { content_filter_result?: FilterResult } } | undefined)
+    ?.innererror?.content_filter_result ?? {};
+  return Object.keys(result).filter((category) => result[category]?.filtered === true);
+}
+
 function reasonFor(error: unknown): ReasonCode {
   ...
-  if (error instanceof APIError && error.status === 400 && error.code === 'content_filter') return 'PROMPT_CONTENT_FILTERED';
+  if (error instanceof APIError && error.status === 400 && error.code === 'content_filter') {
+    return filteredCategories(error).includes('jailbreak') ? 'PROMPT_JAILBREAK_FILTERED' : 'PROMPT_CONTENT_FILTERED';
+  }
   return 'MODEL_CALL_FAILED';
 }
 ...
       const reasonCode = reasonFor(error);
       const { status, code } = error as { status?: number; code?: unknown };
+      const filtered = error instanceof APIError && code === 'content_filter' ? filteredCategories(error) : undefined;
-      log.warn({ runId, reasonCode, err: { class: …, name: … }, status, code, latencyMs }, 'model call failed');
+      log.warn({ runId, reasonCode, filtered, err: { class: …, name: … }, status, code, latencyMs }, 'model call failed');
```

- `kind: 'MODEL_CALL'` keeps the outcome `FAILED`, like the other filter codes. **Decided 2026-10-16 (Hem Singh): an
  attack Azure catches stays `FAILED`,** although the same attack caught by the scanner ends `BLOCKED`. Raised by three
  code reviews. The reason code `PROMPT_JAILBREAK_FILTERED` and the `injection attempt` log line still mark it as an
  attack, so it can be counted apart from model failures.
- `agentRun.reasonCode` has no CHECK, so no migration is needed.
- **Tests:** add a harness helper that returns a 400 response whose `innererror.content_filter_result` has
  `{ [category]: { filtered: true } }`. Assert:
  - `jailbreak` gives `PROMPT_JAILBREAK_FILTERED`;
  - `self_harm` gives `PROMPT_CONTENT_FILTERED`;
  - `filtered` is logged;
  - `'refused'` (the error message) appears in no log line.
- **Verify once on dev** after the admin creates the filter: send one synthetic jailbreak and paste the redacted
  `innererror` into the PR.

## X3. `injection attempt`: who is sending attacks

```ts
// guard.ts — in block(), for the scanner's code only (userId and accountId are already read from runtime.context)
if (reasonCode === 'INJECTION_BLOCKED') log.warn({ runId, userId, accountId, patternClass: fields.patternClass, layer: 'scanner' }, 'injection attempt');

// model-call.ts — in the catch, for Azure's jailbreak code only
if (reasonCode === 'PROMPT_JAILBREAK_FILTERED') log.warn({ runId, userId, accountId, layer: 'azure' }, 'injection attempt');
```

- `userId` and `accountId` identify the clinician and practice, not the patient.
- No alert rule: the endpoint is private and the audience is closed. The lines are searchable in the logs.
- **Test:**
  - the real-scanner Whitfield test (PEA-501 §6.2) also asserts one `injection attempt` line, with
    `layer: 'scanner'`, ids and `patternClass` only;
  - the X2 jailbreak test asserts one line with `layer: 'azure'`.

## X4. Live test: Azure doesn't refuse real clinical text

`tests/integration/guards/azureFilter.test.ts` (on demand, not part of `npm test`; about 55 short calls):

- **Setup:** import `benignClinical` from `../../unit/guards/corpus.js`. Follow the skip pattern in
  `tests/integration/agents/provider.test.ts`.
- **Test 1:** send each benign entry as the user message under a short fixed system prompt ("Reply with the single
  word OK."). Collect `${id} ${filteredCategories(error)}` for every `content_filter` refusal, and assert the list is
  empty.
- **Test 2:** a model built with `x-policy-id: pacehr-no-such-filter` gets `InvalidContentFilterPolicy`. This proves
  the header reaches Azure, so test 1 ran under our filter.
- **If a benign entry is refused:**
  - don't edit the entry;
  - decide the filter change as in [Azure-Foundry-Guardrails.md §2.3](../Azure/Azure-Foundry-Guardrails.md);
  - update [Azure-Portal-Changes.md](../Azure/Azure-Portal-Changes.md) and ask the admin to apply it;
  - re-run the test.

**Measure first (the client options analysis):** run test 1 **without** X1, against the deployment's current filter.
If nothing is refused, the custom filter may not be needed at all.

## Definition of Done (if approved)

- [ ] Each approved item has a ticket or is attached to a named story. *Approved 2026-10-15 and built on the Epic 5
      branch; no ticket yet*
- [x] X2's code is agreed with the Epic 10 owner (confirmed by Hem Singh when approving X2, 2026-10-15)
- [x] Code and tests as above; `npm run typecheck`, `npm test` and `npm run build` are clean (2026-10-15: 390 tests,
      379 passing, 0 failing, 11 todo). X1–X3 change `src/`, so
      each push needs a passing `npm run eval` recorded in `tests/eval/history.jsonl` (pre-push hook)
- [ ] X4 passes on dev and QA after the admin's filter exists; output pasted in the PR

## As built (2026-10-15)

Built on `3p-dev/epic-05-Guardrails` after the Epic 5 stories, one reviewed chunk each. Not pushed.

| # | Files | How it differs from the design above |
|---|---|---|
| X2 | `failure-modes.ts`, `model-call.ts`, `harness.ts` (`filterError()`), `model-call.test.ts` | As designed. The `reasonCode` column is `VARCHAR(40)` with no CHECK (migration 0004), so the 25-character code needs no migration |
| X4 | `tests/integration/guards/azureFilter.test.ts` (new) | Test 1 as designed, with 57 benign entries. **Added:** a second subtest sends the 27 adversarial entries and reports, without asserting, what the filter did with each. Any `jailbreak` means Prompt Shields is on (PEA-501 §7). **Not built:** test 2 (`pacehr-no-such-filter`), which needs X1 switched on |
| X1 | `settings.ts`, `.env.example`, `llm.ts`, `settings.test.ts`, `llm.api-key.test.ts`, `llm.content-filter-policy.test.ts` (new) | As designed. Unset or blank: no `x-policy-id` header (checked in `llm.api-key.test.ts`). Set: every call sends it, beside the API key (the new file, because settings load once per file) |
| X3 | `guard.ts`, `model-call.ts`, `encounter.test.ts`, `model-call.test.ts` | As designed, plus one test: a refusal that isn't a jailbreak (`self_harm`) writes no `injection attempt` line |

Run X4 by hand, VPN on: `node --import tsx/esm --test tests/integration/guards/azureFilter.test.ts` (about 85 short
calls). `npm run test:integration` would also run the database tests.
