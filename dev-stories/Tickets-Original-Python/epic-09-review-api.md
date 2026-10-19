# Epic 9 — Human review and the API surface

**Epic id:** E9 · **Phase:** 1 · **Stories:** PEA-901..PEA-904 · **Points:** 18

## Goal

Nine client-orchestrated calls collapse into two endpoints, and every run — whether it fully
resolves, pauses, or fails closed — leaves exactly one audit trail behind, written by the
service itself rather than by a browser that might never call back. When this epic is done, a
clinician who dictates a forty-field note and gets two ambiguous values back reviews exactly
two fields, not the other thirty-eight and not the note again; and a value the deterministic
guards blocked can still reach the chart, but only over a clinician's own name.

## Scope

**In:**
- `POST /ai/encounter/extract` — the single entry point behind the existing .NET proxy; the
  request/response contract for both outcomes a run can end in (committed, awaiting review).
- The `after_agent` commit-or-hold decision: reading every field's verdict, choosing between
  writing to the encounter form and pausing the run, and handing off to Epic 10's audit-row
  writer on every path, including the fail-closed one.
- The `awaiting_review` persistence — one `AI.fieldOutcome` row per field, written once at
  extract time regardless of outcome — and the review payload built from it: exactly the
  fields that still need a decision, each carrying its suggested value, quote, confidence band
  and reason code.
- `POST /ai/encounter/resolve` — applying the clinician's per-field decision (approve, edit,
  reject, including an override of a blocked value), attributing an override to the clinician
  who made it, and completing the run without a second model call.

**Out:**
- The compiled agent, its middleware spine, hook registration and the six-stage execution
  order — Epic 4 (`PEA-402`).
- Producing the per-field verdict (accept/review/block), its reason code, and the confidence
  band — Epic 6 (`PEA-601`..`PEA-608`). This epic reads a verdict; it does not decide one.
- `ExtractedValue` and the three-state `status` field — Epic 3 (`PEA-305`). This epic carries
  `status` through the payload and the persisted row; it does not define it.
- Masking and de-masking patient identifiers — Epic 5 (`PEA-503`). By the time `after_agent`
  runs, the note and every value in it are already in clinician-readable form.
- `AI.agentRun` and `AI.fieldOutcome` DDL, indexes and retention — Epic 2 (`PEA-202`,
  `PEA-203`).
- Building and writing the `AI.agentRun` audit row itself, including the null-vs-zero token
  distinction and the same-transaction guarantee — Epic 10 (`PEA-1003`). This epic's
  `after_agent` calls that writer; it does not re-implement it.
- The reason-code vocabulary and the definition of every tracked metric — Epic 10 (`PEA-1004`).
  This epic surfaces a reason code on a review card; it does not mint one.
- A third endpoint for re-fetching a paused review — deliberately not introduced. REQ-09-01
  fixes the encounter path at exactly two endpoints; durability is met by persisting the full
  review state in Azure SQL, not by adding a read path back onto that surface.
- The Angular SPA and the .NET proxy's own implementation — out of scope entirely (REQ-11-09).
  This epic specifies the contract the proxy forwards; it is not C# and it is not written here.

## Dependencies

| Epic | Why it must land first |
|---|---|
| Epic 02 | `AI.agentRun` (`PEA-202`) and `AI.fieldOutcome` (`PEA-203`) are the tables `after_agent` and `resolve` write to. |
| Epic 03 | `PEA-305` defines `ExtractedValue` and the three-state `status` field this epic's payload and persisted rows carry unchanged. |
| Epic 04 | `PEA-402` registers `after_agent` in the middleware list and owns the request-scoped state schema it reads. `PEA-406` reads the `note_text` state key this epic's extract endpoint seeds and builds the outbound message list from it. |
| Epic 05 | `PEA-503` reverses masking before `after_agent` runs; nothing in this epic ever sees a token. |
| Epic 06 | `PEA-601`..`PEA-608` produce the per-field verdict, reason code and confidence band this epic reads and displays without altering. |
| Epic 10 | `PEA-1003` is the audit-row writer `after_agent` calls on every path; `PEA-1004` owns the reason-code vocabulary this epic surfaces. |

---

### PEA-901 — Expose one extract endpoint that returns committed fields or a review list

**Type:** Story · **Epic:** E9 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-902, PEA-903, PEA-402, PEA-406 · **Satisfies:** REQ-09-01, REQ-09-02

#### 1. User Story (As a... I want... So that...)

As a platform engineer maintaining the .NET proxy, I want one endpoint that accepts an
encounter's note and returns either every field already written to the encounter form or the
short list of fields still needing a clinician's decision, so that the nine calls the browser
used to orchestrate become one call with one contract to integrate against.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Today the browser assembles a prompt across nine separate calls and writes back whatever comes
out, unchecked. Each of those nine calls is a place the flow can fail independently, and none
of them tells the caller, in one answer, whether the encounter is done or whether someone still
needs to look at it. Collapsing the surface to a single request/response pair means there is
exactly one contract for the .NET proxy to forward, and exactly one place a caller looks to
learn the outcome. The proxy keeps doing exactly what it does today — authenticating the
caller, scoping the tenant, enforcing rate limits — and simply forwards one call where it used
to forward nine.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: A clean note returns every field already committed
  Given a note in which all 40 configured fields validate as ACCEPT
   When POST /ai/encounter/extract is called
   Then the response outcome is COMMITTED
    And the response lists all 40 fields, each carrying its value, unit and status
    And no field in the response is marked as needing a decision

Scenario: A note with flagged fields returns a short review list, not the whole note
  Given a note in which 38 of 40 configured fields validate as ACCEPT
    And the remaining 2 fields validate as REVIEW or BLOCK
   When POST /ai/encounter/extract is called
   Then the response outcome is AWAITING_REVIEW
    And the response's review list contains exactly 2 entries
    And the 38 accepted fields do not appear in the review list

Scenario: The service trusts the identity and tenancy the proxy already established
  Given a request forwarded by the .NET proxy carrying an authenticated clinician identity
        and a tenant id
   When POST /ai/encounter/extract handles the request
   Then the service uses the forwarded identity and tenant id directly
    And the service performs no authentication or rate limiting of its own

Scenario: A structurally invalid request never reaches the agent
  Given a request missing the encounter's templetID
   When POST /ai/encounter/extract is called
   Then the request is rejected before the compiled agent is invoked
    And no AI.agentRun row is written for it

Scenario: The note is invoked as state, not as a seeded message, so masking cannot be bypassed
  Given a note containing "Mrs. Eleanor Whitfield, DOB 03/14/1948" is submitted through
        POST /ai/encounter/extract
   When this endpoint invokes the compiled agent
   Then the invocation's initial state carries the raw note under the key note_text
    And the invocation's initial messages list is empty
    And no message at invocation time contains "Whitfield" or any other substring of the note

Scenario: The extract route resolves under the platform's default prefix
  Given the function app keeps the default Azure Functions route prefix "api"
   When the .NET proxy forwards a request for POST /ai/encounter/extract
   Then the request reaches this function at path /api/ai/encounter/extract
    And host.json declares no routePrefix override

Scenario: Every response is returned as JSON, never the platform's default
  Given either a COMMITTED or an AWAITING_REVIEW outcome
   When POST /ai/encounter/extract responds
   Then the HttpResponse is constructed with mimetype "application/json"
    And the response is never the platform's default 204 No Content with an empty body
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/api.py`. Per `CLAUDE.md` § Code standard: one class, one public `run()`
  reading top to bottom: validate, read, build, call, unwrap. `run()`'s only job is to invoke
  the compiled agent (Epic 4) once via `agent.invoke(...)` and map `after_agent`'s outcome
  (`PEA-902`) onto one of exactly two response shapes — it holds no decision logic of its own.
- **HTTP wiring (`00-langchain-api-truth.md` § 11.2–11.3):** the route is declared
  `@bp.route(route="ai/encounter/extract", methods=[func.HttpMethod.POST])` on a
  `bp = func.Blueprint()` in this module; `function_app.py` holds only the module-level
  `app = func.FunctionApp(...)` and calls `app.register_functions(bp)` — a route is indexed
  from `function_app.py` itself or from a `Blueprint` registered there, and nowhere else. The
  decorated function's own signature is `req: func.HttpRequest`; it reads the body with
  `req.get_json()`, passes the result to this class's `run()`, and returns
  `func.HttpResponse(json.dumps(...), status_code=200, mimetype="application/json")`. `run()`
  itself stays plain Python — it takes and returns Pydantic models, never `azure.functions`
  types — which is also what lets `tests/unit/test_extract_endpoint.py` call it directly with
  no host running.
- **Route prefix — decided, not implicit (`00-langchain-api-truth.md` § 11.2):** Azure
  Functions prefixes every route with `api` by default, and this ticket does **not** empty
  `host.json`'s `extensions.http.routePrefix` — emptying it is one of the costs § 11.5
  documents against mounting a web framework, and this ticket already rejects that path. The
  .NET proxy therefore forwards to **`/api/ai/encounter/extract`**, not the bare
  `/ai/encounter/extract` path named in the user story above; a proxy pointed at the bare path
  404s on day one.
- **`func.HttpResponse` defaults, both wrong for this endpoint
  (`00-langchain-api-truth.md` § 11.3):** `mimetype` defaults to `text/plain`, so every
  response — `COMMITTED` or `AWAITING_REVIEW` — is constructed with
  `mimetype="application/json"` explicitly; and a handler that returns nothing gets the
  platform's own default, `HTTP 204 No Content` with an empty body. Neither default may reach a
  caller of this endpoint.
- **The 230-second HTTP ceiling (`00-langchain-api-truth.md` § 11.6 #1):** the platform load
  balancer returns the caller a 502 at 230 seconds regardless of `host.json`'s
  `functionTimeout`, and the function keeps executing with no way left to answer. The one call
  inside `run()` that can run long is `agent.invoke(...)`; the chat model client it bottoms out
  in already takes a `timeout` constructor argument (`00-langchain-api-truth.md` § 4,
  `AzureChatOpenAI`). That timeout, plus whatever validation and persistence follow it, must be
  budgeted with real margin under 230 seconds, so a slow extraction fails inside the budget as
  an ordinary error response — not past it, where the response is lost regardless of what the
  run eventually decides.
- Request and response are Pydantic `BaseModel`s. Every field object in the response carries
  `status` restricted to `FOUND` / `ABSENT` / `ABSTAINED` (`PEA-305`) — never an empty value
  standing in for a status.
- **API impact:** REQ-09-01 fixes the encounter path at exactly two endpoints. There is no
  endpoint to re-fetch a paused review; a client that needs it again relies on the persisted
  state `PEA-903` returns, not a second call to this one.
- **Security:** identity and tenancy are asserted by the .NET proxy before this request
  arrives; this endpoint does not re-authenticate or re-rate-limit (REQ-09-02). It also never
  re-touches masking — by the time a response leaves `after_agent`, de-masking (`PEA-503`) has
  already run.
- The boundary between "no audit row" and "audit row with outcome BLOCKED" is structural
  request validation. A request that fails validation (unknown `templetID`, missing note text)
  never calls `agent.invoke` and never becomes an `AI.agentRun` row, because it never entered
  the compiled graph. Anything that does enter the graph — including a guard's fail-closed
  exit — reaches `after_agent` and gets a row (`PEA-1003`).
- **The invocation contract: the note goes in as state, never as a seeded message.** `run()`
  calls `agent.invoke` with the raw note under a state key `note_text` and `messages` seeded
  **empty**. This is not a stylistic choice: `AgentState.messages` is
  `Annotated[list[AnyMessage], add_messages]` (`00-langchain-api-truth.md` § 1) — an additive
  reducer, not a replaceable value. If the raw note were seeded as a user message instead,
  `before_agent`'s masking pass (`PEA-503`) could only *append* a masked rewrite beside it; the
  original, unmasked message would still be present and would still reach the provider.
  Masking `note_text` in place has no such hazard, because it is an ordinary state key, not a
  reducer-governed one. Epic 4's `PEA-406` reads the masked `note_text` after `before_agent`
  runs and builds the outbound message list as `[user: masked note_text] + transcript` —
  `run()` never constructs that list itself.
- **Performance:** one network hop and one agent invocation where nine calls existed before; no
  polling is introduced by this contract.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/api.py` exposes exactly one handler for `POST /ai/encounter/extract`, as a single
      class with one public `run()`
- [ ] The route is declared `route="ai/encounter/extract", methods=[func.HttpMethod.POST]` on a
      `Blueprint` registered in `function_app.py`, and resolves at
      `/api/ai/encounter/extract` under the default route prefix
- [ ] Every `func.HttpResponse` this endpoint returns sets `mimetype="application/json"`
      explicitly; no code path falls through to the platform's default 204 No Content
- [ ] Test asserts the chat model client behind `agent.invoke` is constructed with an explicit
      `timeout` held under the platform's 230-second HTTP ceiling, with margin for validation
      and persistence
- [ ] Response is a discriminated shape: `outcome` is `COMMITTED` or `AWAITING_REVIEW`, never a
      third value
- [ ] Every field object carries `status` in `{FOUND, ABSENT, ABSTAINED}`, sourced from
      `ExtractedValue` unchanged
- [ ] `tests/unit/test_extract_endpoint.py` covers: COMMITTED response, AWAITING_REVIEW
      response with exactly 2 of 40 fields listed, missing-`templetID` rejection
- [ ] Test asserts a rejected request never calls `agent.invoke` and never produces an
      `AI.agentRun` row
- [ ] `tests/integration/` asserts a real call through the compiled agent produces one of the
      two documented shapes, never a bare field list with no outcome
- [ ] Test asserts `agent.invoke` is called with the raw note under `note_text` and `messages`
      seeded empty — never a seeded user message carrying the raw note
- [ ] Test asserts no substring of the raw note appears in any message at invocation time
      (regression guard against the `add_messages` additive-reducer hazard)
- [ ] No bare literals — `COMMITTED` / `AWAITING_REVIEW` are module constants per `CLAUDE.md`
      § Naming

---

### PEA-902 — Decide commit-or-hold in after_agent and hand off to the audit writer

**Type:** Story · **Epic:** E9 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-402, PEA-503, PEA-601, PEA-1003 · **Satisfies:** REQ-09-03, REQ-09-04

#### 1. User Story (As a... I want... So that...)

As a clinician, I want every field the deterministic validators already accepted to be written
the moment nothing needs my judgement, and to know immediately when something does, so that I
am never made to wait on — or re-check — work the system has already finished correctly.

#### 2. Business Context & Problem Statement (Why are we doing this?)

`after_model` leaves every field of the run with exactly one verdict — accept, review or block
(Epic 6) — and `after_agent` is the single place that turns those verdicts into an outcome for
the whole run. When every field accepts, holding any of them back would cost the clinician time
for no reason. When even one field needs a decision, the run must not write anything to the
encounter form yet — but it must not throw away the other fields that were already fine,
either. `after_agent` writes the AI's proposal for every field to `AI.fieldOutcome` on the way
through, whichever branch it takes, so that the accepted fields exist as finished work the
instant `resolve` is called for the rest — not work that has to be redone.

This is also the one hook that runs no matter how the request ends. A guard that blocks a run
does so by returning `{"jump_to": "end"}` from `before_agent`, never by raising — an exception
would propagate, skip `after_agent`, and destroy the audit trail for exactly the run most worth
auditing. `jump_to: "end"` still reaches `after_agent`
(`00-langchain-api-truth.md` § "Architectural consequence: fail closed with `jump_to`, never
with `raise`"), so this hook calls the same audit hand-off whether the run committed, paused,
or was blocked before a model was ever called.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Zero fields flagged commits every field and audits the run as COMMITTED
  Given after_model produced an ACCEPT verdict for all 40 configured fields of the encounter
   When after_agent runs
   Then all 40 fields are written to the encounter form
    And an AI.fieldOutcome row is written for each of the 40 fields
    And the audit writer (PEA-1003) is called with outcome COMMITTED

Scenario: Flagged fields commit nothing yet, but the clean ones are already finished
  Given after_model held field s11_f425 "Weight" as REVIEW with status ABSTAINED
    And held field s14_f118 "Temperature" as BLOCK with status FOUND
    And accepted the remaining 38 of the encounter's 40 configured fields
   When after_agent runs
   Then no field is written to the encounter form
    And an AI.fieldOutcome row is written for all 40 fields
    And the 38 accepted fields' rows already carry their final value
    And the 2 flagged fields' rows carry no final value and an open decision
    And the audit writer (PEA-1003) is called with outcome AWAITING_REVIEW

Scenario: A guard's fail-closed exit still reaches after_agent and is audited, never by raising
  Given before_agent detects an injection pattern
   When it blocks the run by returning {"jump_to": "end"} with can_jump_to=["end"] declared
   Then after_agent still executes
    And no field is written to the encounter form
    And no AI.fieldOutcome row is written, because no verdict exists to write
    And the audit writer (PEA-1003) is called with outcome BLOCKED
    And no exception was raised to reach this point
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/review.py`, as the `after_agent` hook (decorator form — a single stateless
  hook, per the ticket guidance in `00-langchain-api-truth.md` § 3). Signature:
  `after_agent(state, runtime) -> dict[str, Any] | None`, reading `state["field_verdicts"]`
  (Epic 6, `PEA-601`) for each field's verdict and reason code, and `state["structured_response"]`
  for the underlying value, unit, `found_in` and `status` (Epic 3, `PEA-305`) it writes
  alongside that verdict. It declares no `can_jump_to` — `after_agent` never jumps; it is the
  node every exit path reaches.
- **This hook decides; it does not write the audit row itself.** It calls
  `pacehr/observability/run_record.py`'s writer (`PEA-1003`, Epic 10) to build and persist the
  `AI.agentRun` row, passing the outcome it decided. `PEA-1003` owns the null-vs-zero token
  distinction, the `_SQL` insert constant, and the guarantee that this write shares a
  transaction with any field commit — this hook only has to call it on every branch, including
  the blocked one.
- Writing `AI.fieldOutcome` (`PEA-203`, Epic 2) is this hook's own responsibility: one row per
  field, every time verdicts exist. On the accepted branch the row already carries its final
  value; on the flagged branch it carries the AI's proposal with the decision left open, for
  `PEA-904` to complete later.
- Persistence writes go through the repository's async database wrapper — `mssql_python`
  offloaded via `asyncio.to_thread`, since no native async Azure SQL driver exists
  (`00-langchain-api-truth.md` § 7) — never a synchronous call left exposed beside it
  (`CLAUDE.md` § Naming).
- **Security / PHI:** by the time this hook runs, `PEA-503` (Epic 5) has already de-masked
  every value — nothing here re-touches a token, and nothing clinical is logged (`CLAUDE.md`
  § Clinical and PHI rules).
- **Performance:** one hook, one pass over the field set, one batched `AI.fieldOutcome` write
  and one call to the audit writer — no per-field network round trip.
- **UI/UX impact:** this hook is what makes `PEA-901`'s response and `PEA-903`'s review payload
  each a short, accurate list rather than a re-statement of the whole note — the accepted
  fields exist as finished rows the moment this hook returns.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/review.py` implements `after_agent`, reading verdicts and branching on whether
      any field is REVIEW or BLOCK
- [ ] `AI.fieldOutcome` receives one row per field on every branch that has verdicts; zero rows
      on the blocked-with-no-verdicts branch
- [ ] The audit writer (`pacehr/observability/run_record.py`, `PEA-1003`) is called exactly
      once per invocation, on every branch, with the correct outcome
- [ ] `tests/unit/test_after_agent.py` covers: all-accept (COMMITTED), mixed REVIEW/BLOCK
      (AWAITING_REVIEW), fail-closed with no verdicts (BLOCKED)
- [ ] Test asserts the fail-closed path is reached via `jump_to: "end"`, never via a raised
      exception, and that `after_agent` still runs
- [ ] Test asserts the accepted fields' `AI.fieldOutcome` rows carry a final value while the
      flagged rows do not
- [ ] No bare literals — outcome and verdict strings are module constants per `CLAUDE.md`
      § Naming
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules (fail-closed, never raise)

---

### PEA-903 — Persist every field's outcome, surfacing only the ones needing a decision

**Type:** Story · **Epic:** E9 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-902, PEA-305, PEA-1004 · **Satisfies:** REQ-09-04, REQ-09-07

#### 1. User Story (As a... I want... So that...)

As a clinician, I want the fields flagged after I dictate a note to come back to me as a short
list — each one carrying the suggested value, the exact words it came from, how confident the
system was, and why it was flagged — so that deciding on two fields out of forty takes seconds,
not a re-read of the note.

#### 2. Business Context & Problem Statement (Why are we doing this?)

We are not removing the clinician from the process, we are removing the routine work and
keeping them in control of the exceptions. This story is where that becomes concrete:
`after_agent` (`PEA-902`) has already decided which fields need a person, and written every
field's outcome — decided or open — to `AI.fieldOutcome`. This story turns that persisted state
into the thing the clinician actually sees, and makes it survive long enough to be seen at all.

Two properties matter more than any other here. First, the list the clinician reviews must
contain only the fields that are actually open — a design that re-surfaced all forty fields for
confirmation, even the thirty-eight the validators already accepted, would cost the clinician
the same reading time the extraction was supposed to save, and would be rejected in practice no
matter how accurate the underlying extraction was. Second, a field the note never mentioned and
a field the model saw but wasn't sure about are clinically different facts, and the payload
must never let them look the same — `ABSENT` reads as "not documented," `ABSTAINED` reads as
"documented, but needs your judgement," and collapsing either into a bare empty value is the
exact defect the three-state `status` field exists to remove.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Reviewing two fields does not require re-checking the other thirty-eight
  Given an encounter with 40 configured fields
    And after_agent held 2 fields for review and wrote the remaining 38 as already decided
   When the review payload is built
   Then the payload contains exactly 2 review cards
    And the 38 decided fields carry no card and require no clinician action
    And nothing in the payload asks the clinician to re-confirm any of the 38

Scenario: A review card carries everything needed to decide in seconds
  Given field s11_f425 "Weight" is held for review with suggested value "187", unit "lb",
        found_in "weight 187", confidence LOW, reason code UNIT_AMBIGUOUS
   When the review payload is returned
   Then the card for s11_f425 includes the suggested value and unit, the exact quote
        "weight 187", confidence band LOW, and reason code UNIT_AMBIGUOUS
    And the card offers exactly three actions: approve, edit, reject

Scenario: ABSENT and ABSTAINED are never presented as the same thing
  Given field s12_f203 "Family History of Diabetes" is committed with status ABSENT and no
        value, because the note never mentions it
    And field s11_f425 "Weight" is held for review with status ABSTAINED
   When the response and the persisted rows are inspected
   Then s12_f203 carries status ABSENT and appears on no review card
    And s11_f425's review card carries status ABSTAINED
    And neither is represented as an empty value plus a confidence band

Scenario: The paused review survives a service restart
  Given a run persisted with 2 open field decisions in AI.fieldOutcome
   When the service process restarts
    And the same run's review payload is requested again
   Then the same 2 review cards are returned, built entirely from the persisted rows
    And no in-memory state was required to reconstruct them
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/review.py`, alongside `after_agent` (`PEA-902`): a function that reads the
  run's `AI.fieldOutcome` (`PEA-203`) rows and builds the review payload — every row with an
  open decision becomes a card; every row already carrying a final value is left out entirely.
- The payload's `status` field is `ExtractedValue.status` (`PEA-305`) carried through
  unchanged — `FOUND` / `ABSENT` / `ABSTAINED`, never re-encoded as an empty value with a
  confidence band. The reason code on a card is Epic 6's vocabulary, closed and defined once by
  Epic 10 (`PEA-1004`); this story surfaces whichever code the validator attached and does not
  mint its own.
- **UI/UX:** the review card's four fields — suggested value, quote (`found_in`), confidence
  band, reason code — plus the three actions (approve, edit, reject) are the entire surface a
  clinician needs; nothing on the card requires opening the source note to interpret it.
- **Durability:** nothing about the review payload lives only in process memory. It is
  reconstructed from `AI.fieldOutcome` on every request, so a page refresh or a service restart
  between `extract` and `resolve` returns the identical list.
- **Security / PHI:** `found_in` is a verbatim quote from the clinician's note. By this point it
  has already been de-masked (`PEA-503`); it is still PHI and is never written to a log line or
  trace attribute (`CLAUDE.md` § Clinical and PHI rules).
- **API impact:** this payload is the `AWAITING_REVIEW` branch of `PEA-901`'s response — there
  is no separate endpoint to fetch it, per REQ-09-01's fixed two-endpoint surface.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/review.py` builds the review payload by reading only the rows with an open
      decision from `AI.fieldOutcome`
- [ ] Every card carries suggested value, unit, `found_in`, confidence band and reason code,
      and exactly the three named actions
- [ ] `status` round-trips as `FOUND` / `ABSENT` / `ABSTAINED` in both the persisted row and the
      payload — never an empty value substituting for one
- [ ] `tests/unit/test_review_payload.py` covers: a 40-field encounter with 2 flagged (asserts
      exactly 2 cards), ABSENT-vs-ABSTAINED distinctness, a decided field producing no card
- [ ] `tests/integration/` persists a run's rows to Azure SQL, restarts the reader, and reloads
      an identical payload from the database alone
- [ ] Test asserts `found_in` never appears in a log record or trace attribute
- [ ] No bare literals — status and action strings are module constants per `CLAUDE.md`
      § Naming

---

### PEA-904 — Apply per-field decisions in resolve without ever calling the model again

**Type:** Story · **Epic:** E9 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-903 · **Satisfies:** REQ-09-05, REQ-09-06

#### 1. User Story (As a... I want... So that...)

As a clinician, I want to approve, edit or reject each field that was held for my review —
including overriding a value the system blocked — and have the whole encounter complete on my
decisions alone, so that I stay in control of the exceptions without the system quietly forming
a second opinion behind my back.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Approving, editing or rejecting a flagged field is the clinician exercising judgement the
deterministic validators explicitly declined to exercise for them — that is what a review queue
is for. Clinical authority stays with the clinician: they can finalize a value the validators
blocked outright, because they, not a range check, know the patient in front of them. But that
authority is exercised in the open. An override of a blocked value is written down against the
name of the clinician who made it — not folded anonymously into "the AI's output" — because the
audit exists precisely to answer who decided this, not only what was decided.

And because the note was already extracted and validated once, resolving the run must never
repeat that work. Nothing before the pause is replayed: `resolve` reads the fields `PEA-902`
already staged, applies the clinician's decisions to the ones still open, and completes the
run. It does not invoke the compiled agent and it asks the model nothing — a second, silent
model call would risk answering a question differently from the one the clinician actually
reviewed.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Approving and editing complete the two open fields, and every field commits together
  Given a run awaiting review with 38 already-decided fields and 2 open fields:
        s11_f425 "Weight" (ABSTAINED, suggested "187 lb") and
        s13_f077 "Respiratory Rate" (REVIEW, suggested "10", reason RANGE_ABNORMAL)
   When the clinician resolves s11_f425 by approving "187 lb"
    And resolves s13_f077 by editing the value to "14"
   Then all 40 fields are written to the encounter form in one operation
    And s11_f425 commits as "187 lb" and s13_f077 commits as "14"

Scenario: Overriding a blocked value is recorded against the clinician who made it
  Given s14_f118 "Temperature" is held with BLOCK, reason RANGE_IMPLAUSIBLE, suggested "185°F"
   When clinician "Dr. Amara Osei" resolves the field by approving "185°F" despite the block
   Then s14_f118 commits as "185°F"
    And the field's AI.fieldOutcome row records the override as made by "Dr. Amara Osei"
    And the original reason code RANGE_IMPLAUSIBLE remains on the row alongside the override

Scenario: Rejecting a field leaves it empty rather than committing a guess
  Given a run awaiting review with exactly one open field, s11_f425 "Weight"
        (ABSTAINED, suggested "187")
   When the clinician resolves the field with a reject decision
   Then the field commits with no value
    And the run completes
    And its historical status remains ABSTAINED, distinct from a field that was always ABSENT

Scenario: Resolving never calls the model
  Given a run awaiting review with 2 open fields
   When resolve is called with decisions for both fields
   Then no call is made to the compiled agent and no call is made to the chat model
    And the run completes using only the decisions supplied and the fields already staged

Scenario: Resolve requires every open field decided before the run completes
  Given a run awaiting review with 2 open fields
   When the clinician submits a decision for only 1 of the 2 fields
   Then the request is rejected as incomplete
    And the run remains in its awaiting-review state
    And neither field is written to the encounter form

Scenario: Resolving an already-completed run is rejected
  Given a run that has already been resolved
   When resolve is called again for the same run
   Then the request is rejected
    And no field is committed a second time

Scenario: The resolve route resolves under the platform's default prefix
  Given the function app keeps the default Azure Functions route prefix "api"
   When the .NET proxy forwards a request for POST /ai/encounter/resolve
   Then the request reaches this function at path /api/ai/encounter/resolve
    And host.json declares no routePrefix override

Scenario: The response is always returned as JSON, never the platform's default
  Given any of the outcomes above — completed, partial-decision rejection, or
        already-resolved rejection
   When POST /ai/encounter/resolve responds
   Then the HttpResponse is constructed with mimetype "application/json"
    And the response is never the platform's default 204 No Content with an empty body
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)
- Lives in `pacehr/api.py` as the second single-`run()` class (`CLAUDE.md` § Code standard),
  delegating the apply-decisions work to `pacehr/review.py`. Its `run()` reads top to bottom:
  validate (the run exists, is still open, and every open field has a decision), read (the
  persisted `AI.fieldOutcome` rows), build (merge the clinician's decisions with the
  already-final rows), persist (write all fields to the encounter form and update the decided
  rows) — there is no "call" step, because nothing on this path calls the model.
- **HTTP wiring (`00-langchain-api-truth.md` § 11.2–11.3):** the route is declared
  `@bp.route(route="ai/encounter/resolve", methods=[func.HttpMethod.POST])` on the same
  `bp = func.Blueprint()` as `PEA-901`, registered once in `function_app.py` via
  `app.register_functions(bp)`. The decorated function's own signature is
  `req: func.HttpRequest`; it reads the body with `req.get_json()`, passes the result to this
  class's `run()`, and returns
  `func.HttpResponse(json.dumps(...), status_code=200, mimetype="application/json")`. `run()`
  itself stays plain Python — it takes and returns Pydantic models, never `azure.functions`
  types.
- **Route prefix — the same decision as `PEA-901`, not a second one
  (`00-langchain-api-truth.md` § 11.2):** the default `api` route prefix is kept; `host.json`
  does not empty `routePrefix`. The .NET proxy therefore forwards to
  **`/api/ai/encounter/resolve`**, not the bare `/ai/encounter/resolve` path named in the user
  story above.
- **`func.HttpResponse` defaults, both wrong for this endpoint
  (`00-langchain-api-truth.md` § 11.3):** `mimetype` defaults to `text/plain`, so every
  response — completed, partial-decision rejection, or already-resolved rejection — is
  constructed with `mimetype="application/json"` explicitly; a handler that returns nothing
  gets the platform's own default, `HTTP 204 No Content` with an empty body.
- **This path never imports or invokes the compiled agent.** `AI.agentRun` is not written again
  here — `PEA-1003`'s writer already recorded outcome `AWAITING_REVIEW` for this run at extract
  time, and that row is append-only; resolving is recorded on the field-level `AI.fieldOutcome`
  rows, not by a second run record.
- An override — any clinician-finalized value for a field whose verdict was `BLOCK` — carries
  the resolving clinician's identity on that field's row. That identity is the one the .NET
  proxy already forwarded and authenticated at the extract boundary (`PEA-901`); this endpoint
  trusts it and does not re-authenticate.
- Decision actions (`approve`, `edit`, `reject`) are module constants, never bare literals at
  the call site, per `CLAUDE.md` § Naming.
- **Security / PHI:** resolve operates entirely on already-de-masked values (`PEA-503`) and
  never re-touches a token.
- **Performance:** no model call means resolve's latency is bounded by one read and one write
  of `AI.fieldOutcome` plus the encounter-form commit — nothing here waits on Azure OpenAI, so
  this path stays well inside the platform's 230-second HTTP ceiling
  (`00-langchain-api-truth.md` § 11.6 #1) that binds every HTTP-triggered function.
- **UI/UX:** three actions per open field (approve, edit, reject) is the entire decision
  surface; completing the run requires no field-by-field submission — one call carries every
  open decision.

#### 5. Definition of Done (DoD) Checklist
- [ ] `pacehr/api.py` exposes exactly one handler for `POST /ai/encounter/resolve`, as a single
      class with one public `run()`
- [ ] The route is declared `route="ai/encounter/resolve", methods=[func.HttpMethod.POST]` on
      the same `Blueprint` as `PEA-901`, and resolves at `/api/ai/encounter/resolve` under the
      default route prefix
- [ ] Every `func.HttpResponse` this endpoint returns sets `mimetype="application/json"`
      explicitly; no code path falls through to the platform's default 204 No Content
- [ ] `pacehr/review.py` applies `approve` / `edit` / `reject` per field and merges the result
      with the already-decided fields before committing
- [ ] An override of a `BLOCK`-verdict field writes the resolving clinician's identity onto
      that field's `AI.fieldOutcome` row
- [ ] `tests/unit/test_resolve_endpoint.py` covers: approve, edit, reject,
      override-of-blocked-with-attribution, partial-decision rejection, already-resolved
      rejection
- [ ] A test mocks the compiled agent and the chat model and asserts zero calls to either
      anywhere in the resolve path
- [ ] `tests/integration/` asserts a resolved run writes every field to the encounter form in
      one operation, not two
- [ ] No bare literals — decision actions and outcome strings are module constants per
      `CLAUDE.md` § Naming
- [ ] Reviewed against `CLAUDE.md` § Naming and § Clinical and PHI rules
