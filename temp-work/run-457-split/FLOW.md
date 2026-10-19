# Run 457 — Request/Response Flow

This documents how the files in this directory relate to each other, split out of the original
`temp-work/run-457.log` trace of a single agent run (template ID `457`).

## Diagram

```
01-agent-config.json  ──┐
02-template-config.json ├──► 03-response-schema.json ──┐
                         │                              │
04-user-query.txt  ──────┼──────────────────────────────┤
05-system-prompt.txt ─────┘                              ▼
                                            06-http-request-body.json
                                                         │
                                            (sent to Azure OpenAI)
                                                         ▼
                                            07-http-response-body.json
                                                         │
                                            (wrapped by the agent)
                                                         ▼
                                              08-agent-result.json
```

`00-run-log.jsonl` sits outside this data flow — it's just the process-level pino log lines
(model init, "model call completed") that bookend the run in time.

## File-by-file

### 01-agent-config.json — agent/model setup
Which model/deployment is being used (`gpt-4.1`, Azure endpoint, API version), the middleware
chain (`BindTemplate`, `ModelCall`, `Outcome`), and the `templateId` (`457`) being processed.
This is configuration, not data — it doesn't change per note.

### 02-template-config.json — the clinical note template
The source-of-truth definition of what needs to be extracted: every **section** (e.g.
`History14`, `AIMS Scale`) and every **field** within it (`slotKey`, `fieldId`, `displayName`,
`fieldType`, `variant`, `aiSummaryPrompt`). Everything downstream is derived from this.

### 03-response-schema.json — generated from 02
A JSON Schema with one property per `slotKey` from the template, each shaped as:
```json
{ "value": "...", "unit": "...", "found_in": "...", "status": "FOUND|ABSENT|ABSTAINED", "confidence": "HIGH|..." }
```
This schema is embedded verbatim into the HTTP request (`response_format.json_schema.schema`)
so the model is forced to return structured, per-field output instead of free text.

### 04-user-query.txt — the input note
The clinician's free-text note — the actual data the model extracts field values from.

### 05-system-prompt.txt — extraction instructions
Tells the model how to behave: use only what's stated in the note, never invent/infer, and
how to mark fields as `FOUND` / `ABSENT` / `ABSTAINED`.

### 06-http-request-url.txt + 06-http-request-body.json — the actual API call
The literal `POST` sent to Azure OpenAI. Assembled from the pieces above:
- `messages`: `[ {role: "system", ...05}, {role: "user", ...04} ]`
- `response_format.json_schema.schema`: the full content of `03-response-schema.json`
- `model`, `temperature`, `stream`: from `01-agent-config.json`

This is config + template + query all merged into one outbound request.

### 07-http-response-status.txt + 07-http-response-body.json — the raw API response
Azure OpenAI's raw reply:
- `choices[0].message.content`: the model's answer, as a **JSON string** conforming to the
  schema in `03`
- `choices[0].content_filter_results`: Azure content-safety checks (hate, self-harm, sexual, etc.)
- `usage`: token counts (`prompt_tokens`, `completion_tokens`, `cached_tokens`, latency breakdown)

### 08-agent-result.json — the agent's final, post-processed output
Wraps the raw HTTP response into the agent's own result shape:
- `messages[0]`: a LangChain `AIMessage` — `kwargs.content` holds the same payload as
  `07`'s `choices[0].message.content`, but parsed here into a nested, readable object
  instead of an escaped one-line string
- `noteText`: echoes `04-user-query.txt`
- `modelName`, `inputTokens`, `outputTokens`, `latencyMs`: final run metrics
- `outcome`: `"COMPLETED"`
- `structuredResponse`: the same extracted data as `kwargs.content`, parsed and keyed by
  `slotKey` (`s1_f5`, `s1_f917`, ...) — matching the `slotKey`s defined back in
  `02-template-config.json`. This is the field-by-field result an application would actually
  consume.

## Summary

| Stage | File(s) | Role |
|---|---|---|
| Config | `01-agent-config.json` | Model + template selection |
| Template | `02-template-config.json` | Defines fields to extract |
| Schema | `03-response-schema.json` | Generated from template; constrains model output shape |
| Input | `04-user-query.txt`, `05-system-prompt.txt` | What the model reads and how it should behave |
| Request | `06-http-request-*` | Everything above, assembled into one API call |
| Raw response | `07-http-response-*` | Azure OpenAI's unprocessed reply |
| Final result | `08-agent-result.json` | Parsed, structured, metered result the agent returns |
| Trace | `00-run-log.jsonl` | Process-level timing log (not part of the data flow) |
