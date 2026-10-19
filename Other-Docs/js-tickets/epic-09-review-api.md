# Epic 9 — Human review and the API surface (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Human review and API surface: two endpoints, one audit trail per run

**Description:** The nine calls the browser makes today become two endpoints behind the .NET proxy: extract and resolve. Every run that enters the agent leaves exactly one audit record, whether it commits, waits for review, is blocked or fails. The service writes that record itself, not a browser that may never call back. A clinician who gets two doubtful values out of forty reviews those two fields only, each with its value, quote, confidence band and reason. A value the checks blocked can still reach the chart, but only under the clinician's own name, and resolving never calls the model again. The routes are the same whether Epic 11 hosts the service on Azure Functions or on Web App for Containers.

### PEA-901

**Title:** Expose one extract endpoint that returns committed fields or a review list

**Description:**
As a platform engineer maintaining the .NET proxy, I want one endpoint that takes an encounter's note and returns either every field already written to the encounter form or the short list of fields that still need a clinician's decision, so that nine browser calls become one call with one contract.

Today the browser builds the prompt across nine calls and writes back whatever comes out, unchecked. Each call can fail on its own, and none of them says whether the encounter is done or needs a person. One request and one response give the proxy one contract to forward and the caller one place to read the outcome. The proxy keeps authenticating clinicians, scoping the account and rate limiting, as it does today.

**Scope**

- in: `POST /api/ai/encounter/extract`, its zod request and response schemas, the two success shapes (COMMITTED and AWAITING_REVIEW), and the JSON answer for a refused request, a blocked run and a failed run
- in: checking the proxy's bearer token with the existing `entraAuthenticator`, and reading the clinician and account the proxy forwards
- in: one call to the encounter agent per request, with the note as `noteText` and empty messages
- out: the commit-or-hold decision (PEA-902) and the review payload (PEA-903)
- out: the host, its route prefix and its deployment (Epic 11); the .NET proxy and the Angular UI
- out: a third endpoint to fetch a paused review again, and rate limiting

**Acceptance criteria**

- A note whose 40 fields are all accepted returns outcome COMMITTED. The response lists all 40 fields with value, unit and status, and none is marked as needing a decision.
- A note with 38 accepted fields and 2 held fields returns outcome AWAITING_REVIEW. The review list has exactly 2 entries, and none of the 38 accepted fields is in it.
- A request with no `templetID` or no note is refused with 400 before the agent runs. The body names the bad fields only, and no audit row is written.
- The agent is called with the raw note as `noteText` and empty `messages`. For a note that names "Mrs. Eleanor Whitfield, DOB 03/14/1948", no message at call time contains "Whitfield" or any other part of the note.
- A bearer token that `entraAuthenticator` rejects gets 401, and a key-endpoint outage gets 500. The forwarded clinician (`userId`) and account (`accountId`) are used as sent, and the service applies no rate limit of its own.
- A blocked or failed run returns a JSON error body with its outcome and reason code. It never returns COMMITTED or AWAITING_REVIEW, and never the error text.
- Every response, refusals included, has `content-type: application/json` and a JSON body. No path answers 204 or an empty body.
- The route answers at `/api/ai/encounter/extract` on either host: served by `src/core/app.ts` in a container, or declared as route `ai/encounter/extract` under the Functions default `api` prefix.

**Technical notes**

- Proposed home: `src/api/encounter.ts` (a new folder with its own `#api/*` alias). One class per endpoint, one public `run()` that reads top to bottom: validate, read, build, call, unwrap. `src/core/app.ts` routes to it today. On Azure Functions the same `run()` sits behind `app.http('extract', { route: 'ai/encounter/extract', methods: ['POST'], handler })` from `@azure/functions`. `run()` takes and returns plain objects, so unit tests call it with no host.
- Request and response are zod 4 schemas. `outcome` is a `z.enum` over exported constants (COMMITTED, AWAITING_REVIEW). The model's contract has only FOUND and ABSTAINED, so a `null` slot is returned as status ABSENT, never as an empty value. The band shown is the evidence middleware's derived band, not the model's own `confidence`.
- `encounterAgent` owns the input shape (`{ messages: [], noteText }`). The endpoint passes `{ note, context, signal }` and never builds messages. The context (runId, encounterId, templetID, accountId, userId, clinicianOid, dateOfService, placeOfService) is validated again at invoke, so the endpoint validates the body first and a bad request never reaches the audit.
- A refusal is a `PacEHRError` subclass and maps to a 4xx; anything else is a 500. Log lines carry ids, counts and reason codes, never note text: fields first, a literal message second.
- Model time is bounded by `REQUEST_TIMEOUT_MS` (300,000 ms per attempt) and `MAX_RETRIES` (2) in `src/core/llm.ts`. Azure cuts an HTTP request at 230 seconds on App Service and on HTTP-triggered Functions, so the whole request must finish well inside that.
- Tests: `tests/unit/api/encounter.test.ts` (agent and database seeded, network blocked) and `tests/integration/api/encounter.test.ts` (a real run returns one of the two shapes, never a bare field list).

**Before you build (due diligence)**

- Fit the time budget. 300 s per attempt over 3 attempts can reach 900 s, far past the 230-second cut; the slowest measured reply took 89 s. Choose a request deadline under 230 s, pass it to the agent as the abort `signal`, and confirm the cut on the Epic 11 host. Re-measure when gpt-4.1 is replaced (it retires 2027-04-14): newer models are reasoning models and spend extra time on reasoning tokens.
- Decide JSON or SSE. `encounterAgent.stream` and the demo server's events (`start`, one `field` per slot, `done`) already work. If extract streams, the `done` event carries the outcome and review list, the JSON rule covers only refusals sent before the stream opens, and whether a stream that keeps sending events escapes the 230-second cut must be measured (to verify).
- Agree identity with the .NET team. The proxy's token proves the caller is the proxy: its `oid` is the proxy's service principal, not a clinician. So the clinician's `userId` and the `accountId` travel in the request. Confirm the field names, and whether `clinicianOid` stays in the context.
- Decide follow-ups. In 6 days of production, 21 calls were short follow-ups such as "Please remove the review of systems section", sent as new calls, and the agent keeps no history. Confirm that a fragment answers almost all null (eval query 5), and decide what a second extract does while the encounter's last run still awaits review: replace it, refuse it, or keep both.
- Agree the status codes for a blocked run and a failed run with the proxy team. Decide whether an unknown `templetID` or an over-long note stays a guard block that is audited (TEMPLATE_UNAVAILABLE, PAYLOAD_TOO_LARGE) or becomes a 400 that is not; the demo server refuses a long note with 400.

---

### PEA-902

**Title:** Decide commit-or-hold in afterAgent and hand off to the audit writer

**Description:**
As a clinician, I want every field the checks already accepted to be written as soon as nothing needs my judgement, and to know at once when something does, so that I never wait on, or re-check, work the system has already finished.

After the evidence and validation hooks run, every field has one verdict. The `afterAgent` hook is the one place that turns those verdicts into an outcome for the whole run. When every field is accepted it commits them all; when any field needs a decision it writes nothing to the encounter form yet, but keeps the accepted fields as finished work. Every exit reaches this hook, because a guard blocks by jumping to `end` and never by throwing, so the audit hand-off happens whether the run committed, paused, was blocked or failed.

**Scope**

- in: commit-or-hold inside the existing `outcomeMiddleware` `afterAgent` hook, after its outcome tagging
- in: a record for every field of what the AI proposed (status, value, unit, quote, band, reason, decided or open), passed with the outcome to the audit writer
- in: the chart write for a run with every field accepted
- out: producing verdicts and reason codes (Epic 6) and the confidence band (Epic 6, built)
- out: de-masking (Epic 5); the audit row, its columns and its write (Epic 10, PEA-1003); the tables (Epic 2)

**Acceptance criteria**

- All 40 fields accepted: all 40 are written to the encounter form, the stored response lists all 40 as decided, and the audit writer is called with COMMITTED.
- 38 fields accepted, `s11_f425` "Weight" held as ABSTAINED and `s14_f118` "Temperature" held as BLOCK: nothing is written to the form, and the stored response lists all 40. The 38 carry their final value, the 2 are open with no final value, and the audit writer is called with AWAITING_REVIEW.
- A guard block (`jumpTo: 'end'` from `beforeAgent`, declared with `canJumpTo: ['end']`): `afterAgent` still runs, nothing is written to the form, no field record is stored, and the audit writer is called with BLOCKED and the reason code. `invoke` resolves, and nothing was thrown to get there.
- A failed model call, for example MODEL_CALL_FAILED, takes the same path with outcome FAILED.
- The audit writer is called exactly once per run, on every branch.
- A database error inside the hook does not reject `invoke`. The run is answered as failed, and the log line carries only the error class and code.

**Technical notes**

- `src/agents/middleware/outcome.ts` stays the only `afterAgent` in `MIDDLEWARE`. It already tags COMPLETED, BLOCKED or FAILED with a reason code. Commit-or-hold runs after that tag, on COMPLETED runs only. The hook declares no `canJumpTo`.
- Until Epic 6 adds per-field verdicts, a field is held when it is ABSTAINED or listed in `reviewSlots` (FOUND with a band below HIGH, from `src/agents/middleware/evidence.ts`). Nothing is BLOCK yet. A `null` slot is ABSENT: decided, with no value.
- Each slot is joined to its `sectionID` and `fieldID` through the guard's template config, because nothing parses the slot key `s<sectionID>_f<fieldID>` back. The field list is stored as the run's `aiResponse` in `AI.EncounterTranscript` (migration 0004) by Epic 10's writer. Clinician decisions go to `AI.EncounterFieldReview` (PEA-904).
- The chart write goes through the existing `dbo.usp_updateEncounterData`, the procedure the UI's save uses. `database.execute` has no transaction, so any write that must succeed or fail with another sits inside one stored procedure with `SET XACT_ABORT ON`.
- No value, quote or remark reaches a log line; log slot keys and counts. Outcome, verdict and status names are exported constants.
- Tests: `tests/unit/agents/middleware/outcome.test.ts` (all accepted, mixed, blocked, failed, database error) and the spine checks in `tests/unit/agents/encounter.test.ts`.

**Before you build (due diligence)**

- Confirm with Saisystems that this service may call `dbo.usp_updateEncounterData`, its parameters, and how value and unit are joined; nothing in the service writes a clinical table today. Confirm the suggest-first rule too: if auto-fill is off by default, an all-accepted run proposes values instead of writing them.
- Decide where the audit row starts. The AI encounter schema design inserts the turn when the request arrives and completes it at the end. A run aborted by a client hang-up, or a crashed process, may never reach `afterAgent`. Measure whether `afterAgent` runs after the abort `signal` fires mid-call (to verify).
- Place the de-mask. There is one `afterAgent`, and the evidence check needs the masked note, so identifiers must be restored in this hook before the commit or wherever Epic 5 decides. Agree it with Epic 5 before writing the commit.
- Agree the held rule with Epic 6. `reviewSlots` leaves out ABSTAINED slots today, and a quote not found in the note is LOW, not BLOCK. The client values recall over precision, so measure how many fields per run the rule holds on the five eval queries (38 across five runs in the last comparison) before fixing it.
- Check the stored row against the `CK_EncounterTranscript_*` constraints. A blocked or failed run has a reason code and no `aiResponse`, and a reply needs the model name and all usage columns, including cost, which nothing computes yet.

---

### PEA-903

**Title:** Persist every field's outcome, surfacing only the ones needing a decision

**Description:**
As a clinician, I want the flagged fields to come back as a short list, each with the suggested value, the exact words it came from, how confident the system is and why it was flagged, so that deciding on two fields out of forty takes seconds, not a re-read of the note.

We are not removing the clinician from the process; we are removing the routine work and keeping them in control of the exceptions. The list must hold only the open fields, because re-showing all forty costs the reading time the extraction was meant to save. A field the note never mentions and a field the model saw but could not fill are clinically different, so ABSENT and ABSTAINED must never look the same. The list is rebuilt from the database every time, so it survives a page refresh or a restart.

**Scope**

- in: the function that builds the review payload from the run's stored response and its decision rows
- in: the review card (status, suggested value and unit, quote, band, reason code, three actions) and the AWAITING_REVIEW branch of the extract response
- out: writing the stored response (PEA-902 with Epic 10) and applying decisions (PEA-904)
- out: the reason-code vocabulary (Epic 10, PEA-1004) and the review screen (Angular UI)

**Acceptance criteria**

- An encounter with 40 fields and 2 open fields gives exactly 2 cards. Nothing in the payload asks the clinician to re-confirm any of the other 38.
- A field that is already decided produces no card.
- The card for `s11_f425` "Weight" (FOUND, value "187", unit "lb", quote "weight 187", band MEDIUM because the unit is not in the quote, reason UNIT_AMBIGUOUS) carries all of these and offers exactly three actions: approve, edit, reject.
- `s12_f203` "Family History of Diabetes", never mentioned in the note, is ABSENT with no value and no card. An ABSTAINED field's card says ABSTAINED and shows its quote and the model's remark, with no suggested value. Neither is shown as an empty value with a band.
- After the process restarts, the same 2 cards come back, built from Azure SQL alone, with no state held in memory.
- No quote, value or remark appears in a log line.

**Technical notes**

- Proposed `src/services/reviewService.ts` with a repository beside the template one, one `_SQL` constant per statement and `@name` parameters. It reads the turn's `aiResponse` from `AI.EncounterTranscript` and the turn's rows in `AI.EncounterFieldReview`. A field is open when the stored response marks it held and it has no live decision row (`isDeleted = 0`).
- `aiResponse` is JSON text in an `NVARCHAR(MAX)` column. Parse it with a zod schema; never trust its shape.
- `status` is carried unchanged: FOUND, ABSTAINED, or ABSENT for a `null` slot. The band is the code-derived one. The reason code is the one Epic 6 attached, from the closed list Epic 10 defines; this ticket mints none. Status and action names are exported constants.
- `found_in` is a verbatim quote from the note and is PHI. It is returned to the caller and stored, but never logged or put in a trace attribute. About a quarter of real notes use `<br>` line breaks, so a quote can contain them and the UI must render them.
- Tests: `tests/unit/services/reviewService.test.ts` (2 open of 40, ABSENT against ABSTAINED, a decided field has no card) and `tests/integration/services/reviewService.test.ts` (rows written to DEV SQL, read back in a new process, identical payload).

**Before you build (due diligence)**

- Settle how "decided" is stored for a field nobody reviewed. `AI.EncounterFieldReview.reviewedBy` is NOT NULL and its `action` is computed, so an auto-committed field cannot be a review row without counting a machine accept as a clinician's. Confirm with the Epic 2 owner that it lives only in the stored response, for example as a `display` marker.
- Confirm that migrations 0004 and 0005 are applied on DEV, and check every column you read with `information_schema.columns` before writing a query.
- With no third endpoint, decide how the UI gets the cards back after a page refresh. Today extract's own response is the only carrier.
- Recall comes first for the client, and a `null` field gets no card. Decide with the client whether the review lets a clinician add a value to an empty field. The review table already computes ADDED, and an added value that is in the note is the cheapest live recall signal.
- The model returns a flat slot map, while the stored shape is a `fields[]` list with section and field ids. Write that mapping once, as one pure function that PEA-902 and this ticket share.

---

### PEA-904

**Title:** Apply per-field decisions in resolve without ever calling the model again

**Description:**
As a clinician, I want to approve, edit or reject each field held for my review, including overriding a value the checks blocked, and have the encounter complete on my decisions alone, so that I stay in control of the exceptions without the system forming a second opinion behind my back.

A decision on a flagged field is the clinician's judgement where the checks declined to judge. The clinician may finalise a blocked value because they know the patient, but that override is recorded under their own name: the audit must answer who decided, not only what. Resolve reads what extract stored, applies the decisions to the open fields and completes the run. It never calls the agent or the model, because a second, silent call could answer a different question from the one the clinician reviewed.

**Scope**

- in: `POST /api/ai/encounter/resolve`, its zod request and response schemas, and its JSON refusals
- in: approve, edit and reject per open field; attributing an override of a blocked value to the clinician; the chart write for every field in one operation
- out: re-running the agent, `humanInTheLoopMiddleware`, or resuming the graph in any way
- out: the audit row (written once, at extract), the review screen and the .NET proxy

**Acceptance criteria**

- A run has 38 decided fields and 2 open ones: `s11_f425` "Weight" (FOUND "187", unit "lb") and `s13_f077` "Respiratory Rate" (FOUND "10", reason RANGE_ABNORMAL). The clinician approves Weight and edits Respiratory Rate to "14". All 40 fields are written to the form in one operation: Weight as "187 lb" and Respiratory Rate as "14".
- `s14_f118` "Temperature" is held as BLOCK with reason RANGE_IMPLAUSIBLE and value "185°F". When the clinician (Dr. Amara Osei's `userId`) approves it, it commits as "185°F", its review row has `reviewedBy` set to that `userId`, and RANGE_IMPLAUSIBLE can still be read beside the override.
- A rejected field commits with no value and the run completes. Its stored status is unchanged, so an ABSTAINED field stays distinct from one that was always ABSENT.
- Resolve makes no call to `encounterAgent` and none to the chat model; the test stubs both and counts zero calls.
- Decisions for only 1 of 2 open fields are refused as incomplete. The run stays awaiting review, and nothing is written.
- Resolving a run that is already resolved is refused, and no field is written a second time.
- Resolve writes no new audit row. It writes review rows and the chart only.
- Every response is JSON at `/api/ai/encounter/resolve` on either host, refusals included. No path answers 204 or an empty body.

**Technical notes**

- The second class in `src/api/encounter.ts`, with one public `run()`: validate (the run exists, is still open, and every open field has a decision), read (the stored response and decision rows), build (merge the decisions with the decided fields), persist (review rows and the chart). There is no call step. On Functions it is `app.http('resolve', { route: 'ai/encounter/resolve', methods: ['POST'], handler })`.
- The review rows and the chart write commit or roll back together inside one stored procedure (`SET XACT_ABORT ON`), because `database.execute` has no transaction. The AI encounter schema design names `AI.usp_addEditEncounterFieldReview`, which copies the AI's value, unit, band, remark and quote from the stored response itself, so the client cannot change what was shown. It is not written yet.
- The clinician is the `userId` (`Account.users.userId`) the proxy forwards, stored as `reviewedBy`. The proxy's token is checked as in PEA-901.
- The actions are a `z.enum` over exported constants (APPROVE, EDIT, REJECT). The table's own `action` column (ACCEPTED, EDITED, REJECTED, ADDED) is computed from the values and never sent.
- The agent is compiled with no checkpointer, so there is no graph state to resume. This path imports neither `encounterAgent` nor `llmManager`.
- Tests: `tests/unit/api/encounter.test.ts` (approve, edit, reject, override with attribution, partial refusal, already-resolved refusal, zero agent and model calls) and `tests/integration/api/encounter.test.ts` (one chart write per resolve, not two).

**Before you build (due diligence)**

- Check each action against the table's constraints. Rejecting an ABSTAINED field (no AI value and no final value) breaks `CK_EncounterFieldReview_decision`. An ABSTAINED field has no value to approve, so the clinician types one and the row reads ADDED. Agree what reject means for such a field.
- `AI.EncounterFieldReview` has no `reasonCode` column. Confirm that keeping the reason in the stored response, joined on transcriptID, sectionID and fieldID, satisfies the audit. Otherwise Epic 2 adds the column in a new forward-only migration.
- "Already resolved is refused" conflicts with the schema design, which allows a change of mind and an undo on a review row. Decide whether resolve runs once and later changes go through the form.
- Decide who writes the review rows and the chart: this service through resolve, or the .NET API on form save. The schema design leaves it open; settle it with the .NET team.
- A follow-up edit command such as "remove the review of systems section" is a set of per-field rejects in this model. Confirm with product that the UI turns it into resolve decisions rather than a new extract call.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-901 | Not started (later sprint) | 3 | PEA-902, PEA-903; PEA-402 and PEA-406 (Done, Epic 4); PEA-106 (Done, Epic 1, not wired); Epic 11 host (PEA-1101) | Nothing. `src/core/app.ts` serves only `/health` and `/health/ready`. It builds on `encounterAgent.invoke` / `stream` (`src/agents/encounter.ts`, PEA-408) and `entraAuthenticator` (`src/core/auth.ts`, wired to no route). Reference only, not product code: `tests/manual/streamServer.manual.ts` (node:http, SSE `start` / one `field` per slot with evidence / `done` / `error`, a CSV per request), `Dockerfile.stream`, `tests/manual/encounter-stream.postman_collection.json` (`docs/2026-10-12-streaming-api.md`). | Azure Functions `Blueprint`, `func.HttpResponse` and `host.json` become routing in `src/core/app.ts` (node:http) now, and `app.http` if Epic 11 picks Functions. The path is `/api/ai/encounter/extract` on both hosts, so the proxy config does not depend on Epic 11. Pydantic becomes zod. "No authentication of its own" becomes a check of the proxy's token with `entraAuthenticator` (JS Epic 1 PEA-106 left the wiring to Epic 9); the clinician and account come from the request. Tenant id becomes `accountId`. `note_text` becomes `noteText`, set inside `encounterAgent.invoke`. ABSENT is a `null` slot, expanded in the response. An unknown `templetID` is a guard block (TEMPLATE_UNAVAILABLE, audited), not a boundary refusal. | 230 s against `REQUEST_TIMEOUT_MS` 300 s × 3 attempts (`src/core/llm.ts`). JSON or SSE (PEA-408 says the API streams). Follow-ups (`docs/2026-10-12-clinician-usage-behaviour.md` B4). Status codes for blocked and failed runs (`docs/tickets/GAPS.md` #23). Identity (GAPS #6, #24). |
| PEA-902 | Not started (later sprint) | 5 | PEA-402, PEA-407 (Done); PEA-607 and PEA-608 (built in `evidence.ts`); PEA-601 (not built); PEA-503 (not built); PEA-1003 (not built); migration 0004 | Nothing. `src/agents/middleware/outcome.ts` tags COMPLETED, BLOCKED or FAILED and a reason code on state only, and its header names PEA-902 as the extension point. Nothing is written to the database or the chart. `evidence.ts` supplies `evidence` and `reviewSlots`. | The `after_agent` decorator becomes the existing `outcomeMiddleware.afterAgent` (one `afterAgent`, per PEA-407). `field_verdicts` becomes `reviewSlots` plus ABSTAINED until Epic 6. `AI.agentRun` and `AI.fieldOutcome` become `AI.EncounterTranscript` (`aiResponse` holds every field) and `AI.EncounterFieldReview` (decisions only), migrations 0004 and 0005. `mssql_python` with `asyncio.to_thread` becomes `database.execute`; atomic writes live in a stored procedure. A FAILED branch is added, because Epic 4 built model-call failures. | Nothing owns the chart write (GAPS #1); `dbo.usp_updateEncounterData` (schema design §9 rule 6) is unconfirmed. Auto-commit against suggest-first (schema design §16 D2.3, §9 rule 5). Insert on arrival (`docs/2026-10-09-pacehr-ai-gaps-and-improvements.md` S3). De-mask call site (GAPS #5; gaps-and-improvements S6). Cost columns required by `CK_EncounterTranscript_usage`. |
| PEA-903 | Not started (later sprint) | 5 | PEA-902; PEA-305 (contract built in `src/schema/contract.ts`); PEA-1004; migrations 0004 and 0005 | Tables only: `migrations/sql/0004_create_encounter_transcript.sql` and `0005_create_encounter_field_review.sql`, merged in PR 12745 (AITP-68). Whether they are applied on DEV was not checked (firewall). No repository, service or procedure reads them. | One `AI.fieldOutcome` row per field becomes the turn's `aiResponse` JSON (every field) plus `AI.EncounterFieldReview` rows (decisions only). The three-state status stays in the API; the model contract is FOUND or ABSTAINED plus `null`. The band is code-derived (PEA-608), not the model's. The card example's band is MEDIUM, not LOW, to match `evidence.ts` (unit not in the quote). An ABSTAINED card shows quote and remark with no value, because `OUTPUT_RULES` leaves an ABSTAINED value empty. | `reviewedBy` NOT NULL against auto-commit. The refresh path with no third endpoint. ADDED for empty fields (`docs/2026-10-13-recall-observability-brainstorm.md` S5). The slot-map to `fields[]` mapping (gaps-and-improvements B6). |
| PEA-904 | Not started (later sprint) | 5 | PEA-903; PEA-901 (identity); `AI.usp_addEditEncounterFieldReview` (not written); `dbo.usp_updateEncounterData` | Nothing. | The second class in `src/api/encounter.ts`; the Functions route follows PEA-901. Clinician identity is the forwarded `userId` stored as `reviewedBy`, not `decidedByProviderId`. The override's reason code stays in `aiResponse`, as the review table has no `reasonCode` column. No `humanInTheLoopMiddleware` or `Command({ resume })`: the agent has no checkpointer. The approve example moved from an ABSTAINED field to a FOUND one, because an ABSTAINED slot has no value to approve. | `CK_EncounterFieldReview_decision` against rejecting an ABSTAINED field. Change of mind (schema design §9 rule 6, an upsert) against once-only resolve. Who writes review rows (schema design O3). Follow-up edit commands. |

Total: 18 points.

### Notes

- **State checked** on branch `3p-dev/epic-4-agent-core` at `89099ab` (2026-10-14, working tree clean). That commit holds the Epic 4 wiring, the evidence middleware and the demo stream server; it is not yet in `PacEHR-AI-Develop-Main`. No file under `src/` or `tests/` references `encounter/extract`, `encounter/resolve`, `AI.EncounterTranscript` or `AI.EncounterFieldReview`, apart from the migration runner's tests.
- **Two Dockerfiles.** `Dockerfile` builds the product image (`dist/server.js`, health routes only), which `pipelines/pacehr-ai-docker-images.yml` pushes to each environment's ACR. `Dockerfile.stream` builds the demo image that runs `tests/manual/streamServer.manual.ts` with tsx. The streaming doc still calls the demo file `Dockerfile`.

**What changed from the Python edition, epic-wide**

| Python edition | TypeScript edition |
|---|---|
| `pacehr/api.py`, `func.Blueprint`, `@bp.route`, `func.HttpResponse(mimetype=...)`, `host.json` route prefix | `src/api/encounter.ts` (proposed) behind `src/core/app.ts` (node:http) today, or `app.http` from `@azure/functions` if Epic 11 picks Functions; `/api/ai/encounter/*` on both hosts; `content-type: application/json` on every answer |
| Pydantic request and response models | zod 4 schemas; types via `z.infer` |
| `after_agent` hook in `pacehr/review.py` | `afterAgent` in the existing `src/agents/middleware/outcome.ts`; no second `afterAgent` |
| `jump_to` / `can_jump_to` | `jumpTo: 'end'` / `canJumpTo: ['end']` |
| `agent.invoke` with `note_text` and empty messages | `encounterAgent.invoke({ note, context, signal })`; the input shape lives in `src/agents/encounter.ts` |
| `AI.agentRun` and `AI.fieldOutcome` | `AI.EncounterTranscript` and `AI.EncounterFieldReview` (migrations 0004 and 0005) |
| `mssql_python` with `asyncio.to_thread`; a transaction across statements | `database.execute(SQL_CONSTANT, params)`; atomic multi-statement writes inside one stored procedure |
| FOUND / ABSENT / ABSTAINED from the model | FOUND / ABSTAINED from the model, `null` for not mentioned, expanded to ABSENT in the API |
| Trusted forwarded identity and tenant, no auth | The proxy's token checked by `entraAuthenticator`; clinician `userId` and `accountId` forwarded |
| Verdicts ACCEPT / REVIEW / BLOCK from Epic 6 | `reviewSlots` and ABSTAINED until Epic 6; no BLOCK yet |
| pytest files `test_extract_endpoint.py` and others | `node:test` files under `tests/unit` and `tests/integration` mirroring `src/` |

**Decisions and conflicts the team must resolve**

1. **Authentication.** The Python story says the service authenticates nothing. JS Epic 1 built `src/core/auth.ts` for Epic 9 to wire (`docs/js-tickets/epic-01-foundation.md`, PEA-106), and its `oid` is the proxy's service principal, not the clinician. The gap list calls auth contradictory and identity undefined (`docs/tickets/GAPS.md` #6, #24). Proposal: check the proxy's token, and take the clinician's `userId` and `accountId` from the request.
2. **Who writes the chart, and when.** Nothing owns the encounter-form write (GAPS #1). The schema design routes it through `dbo.usp_updateEncounterData` (`docs/superpowers/specs/2026-10-07-ai-encounter-schema-design.md` §9 rule 6) and also says auto-fill is off by default and a filled field is never overwritten (§9 rule 5, §16 D2.3). That conflicts with PEA-902 committing accepted fields at once. Who writes review rows, this service or the .NET API, is open (O3).
3. **Data model.** The Python epic writes one `AI.fieldOutcome` row per field at extract time. The merged tables store every field in the turn's `aiResponse` and only decisions as `AI.EncounterFieldReview` rows. `reviewedBy` is NOT NULL, `CK_EncounterFieldReview_decision` blocks rejecting an ABSTAINED field, there is no `reasonCode` column, and the schema design allows a change of mind where PEA-904 refuses a second resolve. Each needs an owner decision before PEA-903 and PEA-904.
4. **When the audit row is written.** The schema design inserts the turn on arrival and completes it at the end (§9 rules 2–3; gaps-and-improvements S3). The Python epic writes it once from the final hook. A run aborted by a hang-up may never reach `afterAgent`; measure it.
5. **Time budget.** `REQUEST_TIMEOUT_MS` is 300,000 per attempt with 2 retries (`PacEHR_AI/src/core/llm.ts`), up to 900 s, while Azure cuts HTTP at 230 s (`docs/tickets/00-langchain-api-truth.md` §11.6 #1). The JS truth doc does not record the 230-second limit for either host (to verify in Epic 11).
6. **JSON or SSE.** PEA-408 says the API streams with `encounterAgent.stream` (`docs/js-tickets/epic-04-agent-core.md`), and the demo's event format works (`docs/2026-10-12-streaming-api.md`). The Python contract is one JSON response. Choose one before PEA-901.
7. **Follow-ups.** Clinicians send edit commands as new calls: 21 short follow-ups in 6 days, and the agent keeps no history (`docs/2026-10-12-clinician-usage-behaviour.md` B4). Decide what a second extract does while a review is open, and whether the UI turns edit commands into resolve decisions. History itself belongs to the schema design's §9 rule 4 and Epic 12.
8. **Recall.** The client values recall over precision. The review covers held fields only; an "add" for an empty field would make ADDED rows, the cheapest live recall signal (`docs/2026-10-13-recall-observability-brainstorm.md` S5). The agent flagged 38 fields across the five reference queries and caught 9 of its 11 errors among them (`docs/2026-10-12-five-query-comparison.md`, Review effort).
9. **Verdict source.** Epic 6's ACCEPT / REVIEW / BLOCK verdicts are not built. `reviewSlots` leaves out ABSTAINED slots, and a quote not found in the note is LOW, not BLOCK (`PacEHR_AI/src/agents/middleware/evidence.ts`). The override path has nothing to override until Epic 6 lands.
10. **De-mask.** De-masking has no call site (GAPS #5), and masking is a pass-through today. With a single `afterAgent`, the restore must happen in that hook before the commit (gaps-and-improvements S6). Agree it with Epic 5.
11. **Hosting.** Epic 11 decides between Azure Functions and Web App for Containers. The product image and its ACR pipeline already exist, and `@azure/functions` is not installed. Whether `jsonBody` sets `content-type` on the Functions host is to verify.
12. **Model.** gpt-4.1 retires 2027-04-14. Its replacement is likely a reasoning model, which is slower and mostly ignores temperature, so the time budget (PEA-901) must be re-measured on it.
