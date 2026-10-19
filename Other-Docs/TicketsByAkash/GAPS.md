# Gap analysis — PacEHR Encounter Agent backlog

**Method:** eight independent read-only reviews of the 75 stories — six by epic cluster,
one end-to-end trace of a single note through all twelve epics, one sweep for what no
ticket covers at all. No ticket was modified. Detail per review is in
`docs/superpowers/sdd/pacehr-agent-ticket-backlog/reports/gap-1..gap-8`.

**Headline:** the epics are individually strong. **Almost every defect is at an epic
boundary** — story A hands to story B and neither defines the interface. That is the
direct cost of twelve authors writing in parallel, and it is fixable without rewriting
any epic.

Findings below are deduplicated. **Confirmations** counts how many of the eight reviews
found it independently — a high count means high confidence, not high severity.

---

## 1. Blocking — found by more than one review

| # | Gap | Stories | Confirmations |
|---|---|---|---|
| 1 | **Nothing owns writing to the encounter form.** Epic 9 says it writes validated fields to the chart; Epic 2's `REQ-02-07` says no existing clinical table is ever written by this service. No repository, no `_SQL` constant, no `GRANT`, no upsert exists. *"Written to the encounter form"* appears 26 times across 6 epics. **The product's only output has no implementation.** | PEA-902, PEA-904, PEA-201..207 | 3 |
| 2 | **The reason-code enum excludes most codes raised.** `PEA-1004` closes the set at 13 and rejects unrecognised codes on write. Epic 6 raises 17-18, Epic 5 raises 6, Epic 4 raises 5. **Only 3 names match exactly** — `EVIDENCE_NOT_FOUND` vs `EVIDENCE_MISSING`, four date codes against one, three cross-field codes against one, every injection code absent. | PEA-1004, PEA-601, PEA-501, PEA-407 | 4 |
| 3 | **A guard-blocked run cannot write its audit row.** `AI.agentRun` declares `promptHash` and `modelDeployment` NOT NULL; a run blocked in `before_agent` has neither, and `PEA-1003` requires them null. There is also no `reasonCode` or `failureMode` column. The fail-closed guarantee dies on a column constraint. | PEA-202, PEA-502, PEA-1003, PEA-403 | 3 |
| 4 | **The middleware list is specified four incompatible ways.** `PEA-402` fixes six entries with one hook each and merge-blocks a second definer; `PEA-502` declares three separate `before_agent` middlewares; `PEA-1001` needs its own bracketing hooks registered first; `PEA-1203` adds a fourth. At least one DoD test must fail. | PEA-402, PEA-502, PEA-1001, PEA-1203 | 4 |
| 5 | **PHI de-masking has no call site.** `PEA-402` sequences it inside `PEA-902`; `PEA-902` says `PEA-503` already did it; `PEA-503` names no caller. Worse — the Epic 5 reading puts it in an `after_agent` hook, and `after_*` runs **last-to-first**, so it would fire *after* the commit. **`[NAME]` reaches the chart.** | PEA-402, PEA-503, PEA-902 | 3 |
| 6 | **Clinician identity is never defined.** Three incompatible shapes, never reconciled: Entra `oid` (warned to be the proxy's own identity), an unexplained "clinician object id" context field, and `decidedByProviderId INT`. The audit cannot answer *"who decided this."* | PEA-106, PEA-402, PEA-203, PEA-901 | 3 |
| 7 | **`AI.fieldConstraint` cannot store four of the six things the compiled guard carries** — risk class, components, roles, temporal direction and horizon. Kills role binding entirely, leaves the BLOCK-versus-REVIEW branch with no input, and sends **every date field to `NO_GUARD_DEFINED` forever**. | PEA-206, PEA-602, PEA-603, PEA-605, PEA-606 | 2 |
| 8 | **`before_agent`'s verbatim-tested step list omits the fragment load, the context load and the size guard** — yet `PEA-404` assumes fragments are resolved and `PEA-705` assumes its tools ran during context assembly. | PEA-403, PEA-404, PEA-705, PEA-502 | 3 |
| 9 | **Run outcome has two vocabularies and an orphan.** `PEA-202`'s CHECK says `guard_blocked`; Epics 4 and 9 pass `BLOCKED`. The value `error` has no producer anywhere, so a failed model call is audited as a guard block. | PEA-202, PEA-902, PEA-1003, PEA-405 | 3 |

---

## 2. Blocking — single review, high severity

| # | Gap | Stories |
|---|---|---|
| 10 | **`PEA-406` silently sends the wrong payload.** `ModelRequest.override()` returns a *new* instance and leaves the original unchanged. The story applies overrides *before* `handler(request)` — so the bound request is discarded and **the baseline schema, the unbound prompt and the unmasked message list go to the provider.** Must be `handler(request.override(...))`. | PEA-406 |
| 11 | **The description chain is verified only for scalar fields.** Every slot is typed `ExtractedValue`, a nested model, so `model_json_schema()` emits it as `$ref` into `$defs` with `description` as a sibling key. **Whether the per-mapping sentence reaches the wire is unverified** — and it is the single claim the accuracy argument rests on. Needs a captured outbound body, not a schema assertion. | PEA-304, PEA-301 |
| 12 | **`PEA-304` cannot be written as specified.** Pydantic raises `PydanticUserError` when `__config__` and `__base__` are passed together; both are mandated, both are DoD items. | PEA-304 |
| 13 | **PHI escapes on the second pass.** Masking runs once in `before_agent`, but `load_patient_history` and `load_note_text` return unmasked clinical text into the transcript and nothing re-masks. `PEA-406`'s egress test greps only for the original note's identifier, so **it passes while identifiers leave the service.** | PEA-406, PEA-503, PEA-705 |
| 14 | **Tokens are not unique per occurrence, so de-masking is not invertible.** Three mentions collapse to one `[NAME]`. **A relative sharing a surname de-masks into the patient's legal name.** | PEA-503 |
| 15 | **A narrative field's value is never checked by anything.** Evidence binding constrains the quote, not the value. A fabricated summary quoting any real substring **derives HIGH and commits silently**, never reaching review. | PEA-607, PEA-608, PEA-601 |
| 16 | **Masking covers three identifier types and only the patient's own.** Nothing masks a referring physician, relative, caregiver, employer, address, phone, or a second patient. The regex fallback that could reach them is named once and specified nowhere. The skiplist has no owner or source, and its two acceptance criteria are jointly unsatisfiable — **a patient actually surnamed Brown egresses in clear.** | PEA-503, PEA-504 |
| 17 | **No transaction primitive.** `PEA-103` is single-statement, fresh-connection-per-call. Epics 9 and 10 require atomic multi-statement writes with rollback across the form commit, the `fieldOutcome` rows and the `agentRun` row. | PEA-103, PEA-902, PEA-1002 |
| 18 | **No validator dispatch by field type**, and the compiler grammar has no non-numeric construct. Every boolean, multi-select, coded and narrative slot is REVIEW on every encounter forever. Coded fields are validated only by a tool the model may decline to call — **the exact pattern `CLAUDE.md` forbids.** | PEA-601, PEA-602, PEA-704 |
| 19 | **Unknown-slot handling is specified two ways and neither is reachable.** `extra="forbid"` turns one stray key into a whole-response `ValidationError`; `extra="ignore"` drops it before Python sees it, so `SLOT_UNKNOWN` can never be raised. Nobody gets the raw provider payload — `ProviderStrategy` parses internally. | PEA-304, PEA-601 |
| 20 | **The prompt placeholder bug is reproduced.** Epic 8 embeds five placeholders substituted by `before_model`; `PEA-404` concatenates three blocks and never mentions placeholders. **This recreates the live "Dynamic Location" defect the story exists to fix.** | PEA-805, PEA-404 |
| 21 | **Prompt migration may produce nothing resolvable.** `PEA-803` must insert through the ordinary save path with no back door; `PEA-805` rejects text lacking five new-style placeholders; legacy rows use the old `.Replace()` style. No exemption or rewrite step exists. | PEA-803, PEA-805 |
| 22 | **The admin surfaces are unreachable.** The constraint compiler and the Prompt Studio are write-path modules with **no HTTP route** — Epic 9 fixes the Function at exactly two routes by design. | PEA-602, PEA-801, PEA-901 |
| 23 | **No JSON contract and no HTTP status codes.** Both endpoints are prose-only. Every block, failure and resubmit just says "rejected." Three incompatible run-id concepts are never reconciled. | PEA-901, PEA-904, PEA-402, PEA-202 |
| 24 | **Auth is contradictory and the proxy is bypassable.** `PEA-106` says `PEA-901` validates the token; `PEA-901` says the Function authenticates nothing. Epic 11 secures only egress — **no inbound control or `auth_level` is specified**, and `PEA-901` trusts forwarded identity blindly. | PEA-106, PEA-901, PEA-1104 |
| 25 | **An auto-committed field never acquires a final value.** The only two writers on `AI.fieldOutcome` are propose-at-extract and accept-at-resolve. **Edit rate, the memory kill switch and Epic 12's capture all silently depend on a value nothing writes** — narrowing "every field a clinician corrects" to "every reviewed field." | PEA-203, PEA-902, PEA-1004, PEA-1205 |
| 26 | **`create_agent` is never passed `tools=`.** `PEA-701` attributes it to Epic 1; Epic 4 names only `system_prompt`, `middleware`, `response_format`. `resolve_date` and `compute_bmi` are unreachable. | PEA-401, PEA-402, PEA-701 |

---

## 3. Missing entirely — no story, no acceptance criterion, anywhere

**Must exist before go-live**

1. **The review panel and admin UI.** The Angular SPA is out of scope in Epics 9, 10 and 11. Nothing tells the UI team about the review cards, the evidence quote, showing `ABSENT` versus `ABSTAINED` distinctly, or the authoring surfaces for constraints and descriptions. **The feature has no user.**
2. **Per-template / per-account / per-clinician enablement and a runtime off switch.** `EXTRACTION_MODE` is one global field changed by config edit and restart. You cannot pilot one template or disable one bad one without a deploy.
3. **Ongoing clinical sign-off on what the model is told.** Descriptions go live on the next request with mechanical validation only; fragments promote on deterministic metrics alone. Nobody reviews a change to the model's instructions before it reaches a chart.
4. **Alerting and on-call.** `PEA-1005` states outright that no threshold, alert or SLO is asserted. Nobody learns the service is broken except a clinician mid-encounter.
5. **Capacity, quota and a spend ceiling.** `max_retries = 2` is the entire resilience story, untested against throttling. No TPM sizing, no concurrency cap, no budget alarm. **Nothing bounds model calls per request** — no recursion limit anywhere.
6. **The .NET proxy request contract** — what carries clinician identity, agreed with that team.
7. **BAA, data residency and audit evidence.** "BAA" appears once as prose. No story confirms the Azure OpenAI resource is in-region and covered, or produces what an assessor would ask for.

**Should exist before scale**

8. Tenancy isolation is asserted and never tested — `AI.promptFragment` carries explicit account precedence.
9. Security testing — zero mentions of penetration testing, dependency scanning, SAST or a threat model.
10. Patient-request deletion — `proposedValue`, `acceptedValue` and `foundIn` are PHI with no erasure path.
11. Reprocessing after a prompt or description fix — the refinement loop never reaches notes already processed.
12. Template change versus historical data — `AI.agentRun` records no `templetID` and no config version.
13. **Training the clinical authors.** The whole design rests on one-line field descriptions being good. Nothing teaches anyone to write one.
14. A route for a clinician to report a wrong value. Edit rate only catches flagged fields; a wrong value accepted at HIGH has no reporting path.

**Worth naming:** service ownership, a non-production environment with realistic notes, and backup/restore/rotation for the `AI` schema.

---

## 4. What held up

Stated for balance, and because these did not need rework:

- The **template → schema path** (`PEA-301` → `303` → `304` → `305` → `406`) is specified at every hop, and no story assumes construction-time binding.
- The **`(templetID, sectionID, fieldID)` keying argument** and its collision counter-tests.
- The **masking half** of the PHI chain, and the decision to bind evidence against the masked note — consistent across both epics.
- The **`weight 187` / `temp 99.1` ambiguity handling** inside Epic 6 is fully specified.
- **Fail-closed by `jump_to`, never by `raise`**, and the three-state status with a closed confidence band.
- **`PEA-1009`'s judge isolation and `PEA-1204`'s memory-authority boundary** are structurally enforced and CI-blocking — notably rigorous.
- **Shadow mode's exit constants** are real measurable numbers with test coverage and a named sign-off gate.
- Migration rollback, Settings enumeration, missing-row fallbacks and fragment bootstrap were each checked and found sound.
