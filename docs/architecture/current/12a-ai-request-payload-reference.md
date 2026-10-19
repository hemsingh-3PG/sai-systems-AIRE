# AI Request Payload Reference — everything sent to gpt-4o

> ⚠️ **STALE — not refreshed on 2026-09-30.** This supplement was produced in the 2026-09-08 deep-dive run and has not been re-verified against the current code (301 commits later). See `12-ai-assistance-deep-dive.md` for the refreshed module analysis.

**Date**: 2026-09-10
**Compiled By**: ARCHITECT — read directly from source, not inferred
**Status**: Current state
**Module 12a** — companion to `12-ai-assistance-deep-dive.md`

> Every outbound model request in PacEHR, with the exact wire payload and what fills each field.
> Four service methods, seven distinct calling contexts. All four methods build the body inline in
> `pacEHR.DomainServices/AIPromptServices.cs`; nothing else in either repository calls a model.

---

## 1. The common envelope — identical in all four methods

```http
POST {requestUri}
Authorization: Bearer {apiKey}
Content-Type: application/json; charset=utf-8
```

| Element | Resolution | Source |
|---|---|---|
| `requestUri` | `OPENAI_API_URL` from `usp_getAppSettingsForMultiple` **verbatim, replacing the entire path**; if absent → `v1/chat/completions` | `AIPromptServices.cs:164-169, 218-223, 270-275, 322-327` |
| `apiKey` | `OPENAI_API_KEY` from the same proc; if absent → `_configuration["APIkeySettings:openAIapiKey"]` | same lines |
| Auth scheme | `Bearer` — OpenAI style, **not** Azure's `api-key` header | `:172, 226, 278, 330` |

**Body fields common to all four:**

```jsonc
{
  "model": "gpt-4o",          // hardcoded, 4 sites
  "temperature": 0,           // hardcoded, 4 sites
  "messages": [ ... ]         // route-specific, see §2
}
```

### What is *not* sent — every one of these is absent from all four payloads

| Absent field | Consequence |
|---|---|
| `response_format` / `json_schema` | **The direct cause of the JSON-repair workaround.** Nothing constrains the decoder, so malformed JSON is possible and a second call exists to fix it |
| `max_tokens` | Output is unbounded; cost and latency have no ceiling |
| `seed` | Runs are not reproducible even at `temperature: 0` |
| `user` | No end-user correlation ID at the provider. A completion cannot be traced back to a provider or encounter from the provider side |
| `metadata`, `store` | No provider-side tagging |
| `tools` / `functions` | No structured tool interface anywhere |
| `top_p`, `frequency_penalty`, `presence_penalty` | Provider defaults apply |
| Any request or correlation header | Only `Authorization` and `Content-Type` are set |

---

## 2. The four payload templates

### 2.1 `GetOpenAICompletionAsync` — non-streaming

`AIPromptServices.cs:155-196` · route `/getCompletion` · `HttpClient` + JSON

```jsonc
{
  "model": "gpt-4o",
  "stream": false,
  "temperature": 0,
  "messages": [
    { "role": "system", "content": "{systemPrompt}" },
    { "role": "user",   "content": "{userPrompt}" }
  ]
}
```

Response read as `choices[0].message.content`. This is the only route that **re-throws** on error, so a
failure surfaces as HTTP 400 rather than silently.

### 2.2 `StreamOpenAICompletionAsync` — streaming, two messages

`AIPromptServices.cs:312-365` · route `/streamCompletion` · `fetch` + SSE

```jsonc
{
  "model": "gpt-4o",
  "stream": true,
  "stream_options": { "include_usage": true },
  "temperature": 0,
  "messages": [
    { "role": "system", "content": "{systemPrompt}" },
    { "role": "user",   "content": "{userPrompt}" }
  ]
}
```

### 2.3 `StreamOpenAICompletionWithDataAsync` — streaming, **three** messages

`AIPromptServices.cs:260-310` · route `/streamCompletionWithData`

```jsonc
{
  "model": "gpt-4o",
  "stream": true,
  "stream_options": { "include_usage": true },
  "temperature": 0,
  "messages": [
    { "role": "system", "content": "{systemPrompt}" },
    { "role": "user",   "content": "{userPrompt}" },
    { "role": "user",   "content": "{additionalData}" }   // ← extra conversational turn
  ]
}
```

> 🔴 `additionalData` is **not context appended to the user turn** — it is a third `role: "user"`
> message, i.e. a second conversational turn from the user. And the DTO types it as `string`
> (`AIDto.cs:360`) while the client sends a **five-element array** (§3.4). See §5.1.

### 2.4 `StreamOpenAITemplateCompletionAsync` — streaming, system prompt assembled server-side

`AIPromptServices.cs:198-258` · route `/streamTemplateCompletion`

The **only** route where the server modifies the prompt. Nine placeholders are substituted into the
client-supplied system prompt before the call (`:203-212`):

```
<<templateName>>    ← req.templateName
<<templateProcess>> ← req.templateProcess          (hardcoded 'admitted' client-side)
<<sectionCount>>    ← req.sectionCount
<<sectionName>>     ← req.sectionNames
<<promptBody>>      ← req.promptBody               ← §4: section + field instructions, flattened
<<encounterFields>> ← req.encounterFields          ← JSON of the encounter form values
<<encounterPOS>>    ← req.pos
<<DOSDate>>         ← req.dos
<<todayDate>>       ← req.todayDate
```

```jsonc
{
  "model": "gpt-4o",
  "stream": true,
  "stream_options": { "include_usage": true },
  "temperature": 0,
  "messages": [
    { "role": "system", "content": "{resolvedSystemPrompt}" },  // after 9 substitutions
    { "role": "user",   "content": "{req.userPrompt}" }          // = this.medicalNote
  ]
}
```

---

## 3. The seven calling contexts — what actually fills the messages

| # | Caller | Route | `system` content | `user` content |
|---|---|---|---|---|
| 3.1 | `encounter-ai.facade.ts:232` | template | DB prompt from `usp_getPrompt`, + 9 placeholders resolved server-side | `this.medicalNote` — the provider's dictated/typed encounter note |
| 3.2 | `encounter-ai.facade.ts:275` | getCompletion | *"You are a JSON repair assistant. Your only job is to fix malformed JSON…"* | `"Here is the malformed JSON:\n\n" + malformedJson` |
| 3.3 | `encounter-ai.facade.ts:374` | streamCompletion | `AICommand` | `posList + '\n' + this.openAiCommand` — the provider's free-text AI command |
| 3.4 | `add-rounding-notes.component.ts:873` | **withData** | inline literal pinning a JSON shape (§3.4 below) | `"Note - " + noteDetails` with `\n` → `<br>` |
| 3.5 | `encounter-ai.facade.ts:733` | streamCompletion | ~4,500-char inline CPT-coding literal with `newPOS` interpolated | `this.roundingNote` |
| 3.6 | `add-rounding-notes.component.ts:1539` | streamCompletion | `ambientSettings.ambientPrompt` — from template, else account (`usp_getAmbientPrompt`) | `JSON.stringify(ambientNotes)` — the multi-speaker transcript array |
| 3.7 | `ai-summary-prompt.component.ts:170` | streamCompletion | `genarateSystemPromptForAISummary()` | `JSON.stringify(userData)` |

Prompt provenance splits three ways, which is why a clinical prompt change is a code deploy for
some features and a DB row for others:

| Origin | Contexts |
|---|---|
| **Database** (`AI.prompt`) | 3.1 (via `usp_getPrompt`), 3.6 (via `usp_getAmbientPrompt`) |
| **Inline code literal** | 3.2, 3.4, 3.5 |
| **Generated in the component** | 3.3, 3.7 |

### 3.4 detail — the extraction call, and the ID enumerations

`add-rounding-notes.component.ts:869-891`. The system prompt pins the response shape inline:

```json
{"encounterTempleteID":"","eventTypeId":"","POSID":"","facilityID":"","Date of Service":"","follow-up":""}
```

…with the instructions *"Always return 'NA' if you are not sure"*, *"Do not change JSON structure"*,
and today's date interpolated.

`additionalData` (`generateAdditionalData()`, `:894-903`) is a **five-element string array**, each
element a labelled JSON block:

| Element | Content | Fields projected |
|---|---|---|
| 1 | ``Encounter Template list JSON ```{...}``` `` | `encounterTempleteID`, `encounterTempleteName`, `default` |
| 2 | ``POS list JSON ```{...}``` `` | `POSID`, `POSname`, `default` |
| 3 | ``Location/Facility list JSON ```{...}``` `` | `facilityID`, `facilityName`, `default` |
| 4 | ``Event Types list JSON ```{...}``` `` | `eventTypeId`, `eventType`, `default` |
| 5 | ``Default values JSON ```{...}``` `` | `getDefaultValues()` |

**So the valid ID enumerations *are* being sent** — as prose in a third user turn, rather than as
`enum` constraints on a schema. That is the entire distance between today's design and a
schema-constrained one: the same information, in a position where the decoder cannot enforce it.

---

## 4. Where the three instruction levels actually go

The client-reported template / section / field instruction conflict is mechanically visible here.
All three levels are **flattened into one prose string** with no delimiters, no precedence and no
type information — `getPromptBody()`, `encounter-ai.facade.ts:858-874`:

```
{sectionName}: {sectionPrompt}.                                    ← SECTION level
 In the '{sectionName}' section there are {n} field in this section. Fields are {list}.
{fieldName}: {fieldPrompt}. {fieldName}: {fieldPrompt}. …          ← FIELD level
```

…repeated per section, concatenated into `<<promptBody>>`, substituted into the **template-level**
prompt from `AI.prompt`.

| Level | Storage | Reaches the model as |
|---|---|---|
| Template | `AI.prompt.prompt` via `usp_getPrompt` | the system message body |
| Section | `sectionData.sectionPrompt` | prose inside `<<promptBody>>` |
| Field | `fieldData.prompt` | prose inside `<<promptBody>>` |

Once flattened there is no way to detect that a field instruction contradicts its section
instruction, or that either contradicts the template — the merge has already happened, irreversibly,
in string concatenation. This is the concrete form of the conflict problem.

---

## 5. PHI and data inventory — what patient information leaves the boundary

### 5.1 What is sent

| Data | Contexts | Nature |
|---|---|---|
| **Free-text clinical note** (`medicalNote`, `roundingNote`, `noteDetails`) | 3.1, 3.4, 3.5 | Full narrative PHI — the provider's own words |
| **Ambient transcript** (`ambientNotes`) | 3.6 | Verbatim multi-speaker conversation, patient utterances included |
| **Encounter form values** (`<<encounterFields>>`) | 3.1 | JSON of the entire encounter form |
| **Date of service, today's date** | 3.1, 3.4 | HIPAA Safe Harbor identifiers |
| **Facility / POS / template / event-type lists** | 3.4, 3.3 | Organisational, not patient |
| **Provider free-text command** | 3.3 | Whatever the provider typed |

> 🔴 **`maskPHI` does not run.** `phi-masker.ts:133` is `return text;` — the first statement in the
> function. Every `maskPHI(...)` call in `open-ai.service.ts` (`:47, 54-55, 253, 326, 388`) is a
> pass-through. **All of the above is transmitted unmasked.**
>
> Even if it ran, `phiPatient` only ever populates `firstName`, `lastName` and `age` —
> `middleName`, `dob` and `mrn` are hardcoded empty strings
> (`encounter-ai.facade.ts:643-653`, `add-rounding-notes.component.ts:1032`).

### 5.2 What is *not* sent — the grounding gap

**No structured patient record reaches the model in any of the seven contexts.** Absent from every
payload:

| Absent | Relevance |
|---|---|
| Medication list | The client's own reported gap |
| Vitals | — |
| Allergies | — |
| Active problem list | This is the stated ICD source; the model never sees it |
| Demographics | — |
| Prior encounter / history | — |
| LOINC / SNOMED bindings | Present per-field in `Trimmed.pr1_template_field`, never sent |

The model's entire knowledge of the patient is **whatever the provider dictated in this session**.
Everything else it produces is generated without access to the record it is documenting.

---

## 6. Logging fidelity — the AI log does not match the wire

Relevant to the 10-month log handover: `usp_addEditAILogs` stores something different from what was
sent, on two of the seven contexts.

| Context | Logged `system_content` | Actually sent | Gap |
|---|---|---|---|
| 3.1 template | `this.openAISystemPrompt` — the **unresolved** prompt, `<<promptBody>>` and the other eight placeholders still literal (`encounter-ai.facade.ts:257`) | the resolved prompt after nine server-side substitutions | 🔴 The largest and most variable part of the prompt — all section and field instructions, and every encounter field value — **is not in the log** |
| 3.4 withData | `systemPrompt + " " + JSON.stringify(additionalData)` — concatenated into one string (`add-rounding-notes.component.ts:885`) | three separate messages, `additionalData` as its own `role: "user"` turn | 🟠 Message structure is not recoverable from the log |

Two further limits on the logs as an evidence base:

- `resp_content` for the streaming routes is `htmlData` / `aiResult` — the **client-side accumulated
  and in some cases regex-mangled** text (`encounter-ai.facade.ts:238-247` strips `{`, `"`, `}` and
  rewrites separators), not the raw model output.
- Token counts come from `localStorage.OpenAIStreamTokenData`, cleared only inside the success
  callback, so a failed log write attributes stale figures to the next completion
  (`encounter-ai.facade.ts:617-635`).

**Net:** for the template route the logs cannot reproduce the request, and for all streaming routes
they cannot reproduce the response verbatim. Worth knowing before the corpus is scoped.

---

## 7. Summary of what one request costs you

Taking 3.1, the flagship path, as the worked example — the model receives:

```
system:  DB template prompt
         + every section name and section instruction
         + every field name and field instruction
         + the full encounter field JSON
         + POS, date of service, today's date, section count
user:    the provider's dictated note (unmasked PHI)
```

…with `temperature: 0`, no schema, no token ceiling, no correlation ID, no structured patient
record, and a log that captures the prompt before half of it was assembled.

---

## 8. Direct implications for the Phase 1 rebuild

| Finding | Phase 1 item |
|---|---|
| No `response_format` anywhere | Schema-constrained decoding deletes the JSON-repair call (M4) |
| ID enumerations sent as prose in a third user turn | Same data becomes `enum` constraints in a compiled schema (§3.2 of the Phase 1 note) |
| Three instruction levels flattened irreversibly into one string | Typed directives + composition + conflict linter (M3) |
| No structured patient record in any payload | Context Assembly (S5) — this is the largest single accuracy lever available |
| `maskPHI` inert; `phiPatient` only carries name and age | PHI posture decided server-side, deliberately |
| Logs do not match the wire on 2 of 7 contexts | Audit rewrite is a prerequisite for the post-edit corpus, not a nice-to-have |
| No `user` / correlation ID | Provider-side traceability, needed for incident response |
| No `max_tokens`, no `seed` | Cost ceiling and reproducibility |

---

**Cross-references**: `docs/architecture/current/12-ai-assistance-deep-dive.md` ·
`docs/architecture/design/12-ai-phase1-implementation-architecture.md`
