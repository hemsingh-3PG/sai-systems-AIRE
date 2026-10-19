# PEA-503 — PHI Masking: Close by Decision, Keep the Seam

**Type:** Story · **Epic:** E5 · **Points:** 5 if built (JS ticket); **0 to build if closed** · **Status:** **Closed by decision (BAA), 2026-10-15.** The client confirmed the BAA on a call; no code change
**Benchmark:** [`js-tickets/epic-05-guardrails.md`](../../js-tickets/epic-05-guardrails.md) PEA-503 and Notes, *"PHI masking:
owner decision vs other documents"*
**Code baseline:** `pacEHR_AI` branch `PacEHR-AI-Develop-Main` at `b93f989` (Epic 4 merged in PR 12886, 2026-10-15)

---

## 1. What the JS ticket asks

The JS ticket keeps PEA-503 on hold. Today the masker returns the note unchanged, because the owner decided the client
contract covers sending the note to Azure OpenAI. The ticket gives two ways to finish:

- **build masking**, if the owner reverses the decision; or
- **close it by decision** and correct the documents that still say PHI is masked before egress.

This spec takes the second path. The decision is recorded in §2.

## 2. Decision record

| | |
|---|---|
| **Decision** | `pacEHR_AI` doesn't mask patient identifiers before the model call, and doesn't restore them afterwards |
| **Why** | Azure OpenAI use is covered by a signed HIPAA BAA (owner decision; `docs/2026-10-09-pacehr-ai-change-log.md` A5; the comment in `src/guards/phi.ts`) |
| **Date** | 2026-10-14 |
| **What stays in the code** | Everything that exists today. The `phi_mask` step, the identity masker in `src/guards/phi.ts`, `_tokenMap` in state, and `tests/unit/guards/phi.test.ts` all stay. The JS ticket's `ponytail:` note says PEA-503 "replaces the body, not the signature" if masking returns, so the seam is kept on purpose |
| **What does not change** | No PHI in logs, traces, error messages or audit rows. The BAA covers Azure OpenAI, not our own outputs |
| **When to revisit** | A model provider without a BAA is added, or compliance decides the minimum-necessary standard requires masking. Then build PEA-503 as the JS ticket specifies. Its criteria and due diligence (identifier source in DEV, the skiplist, the token-uniqueness GAPS #14, restore placement) are the spec. For the identifier source: `src/repositories/patientRepository.ts` already reads the encounter's patient from `Encounter.encounter` joined to `Patient.patients`, not the `dbo.Patient` the JS ticket guesses |
| **Consistent with new code** | `patientManager` (added 2026-10-15, not yet wired) sends only age, sex and the AI summary. The date of birth stays in SQL (age is computed there), and ages over 89 are top-coded to "90 or older" per HIPAA Safe Harbor |
| **Sign-off** | **Confirmed by the client on a call, 2026-10-15.** Hem Singh judged the call enough to close the story; there is no written copy. The JS ticket's first due-diligence item asks for it in writing, so get a written confirmation if an audit asks |

> **Change from our earlier pack:** we previously withdrew PEA-503 and deleted `phi.ts`, the `phi_mask` step and
> `_tokenMap`, because on `PacEHR-AI-Develop-Main` at `058308d` the stub threw and blocked every run. On the current baseline
> the masker passes the note through and blocks nothing, so **no code change is needed**, and deleting the seam would
> contradict the JS ticket.

## 3. Code changes

**None.** On `b93f989`:
- `phi.ts` returns `{ maskedText: note, tokenMap: new Map() }`;
- `guard.ts` stores both;
- `phi.test.ts` asserts the note is unchanged, with a fresh map each call.

PEA-504's `nameCollision` and `ageOrDose` sets first shipped as `todo` tests in `phi.test.ts`; they were removed on
2026-10-16 (see PEA-504 §4).

## 4. Documents to correct when it's closed

### 4.1 The three documents the JS ticket names

These still say PHI is masked before egress. **None of them is in this workspace**, so the owner of each needs to make
the change.

| Document | Location | Change |
|---|---|---|
| `docs/2026-10-12-clinician-usage-behaviour.md` | B7 and §7 row 5 ("Real PHI masking before real notes"; that row cites PEA-501 but means PEA-503) | Mark it resolved by decision: masking is covered by the BAA |
| `docs/Speaking Notes — AI Encounter Form Population_ Validated & Controlled Flow.md` | Line 184, "PHI is masked before egress" | Change to: "The note goes to Azure OpenAI under the BAA. No identifier reaches our logs, traces or audit rows" |
| `docs/tickets/SOP-COVERAGE.md` | Row 1.1 (cites PEA-503) | Point to this decision |

### 4.2 JS tickets that depend on PEA-503 or assume masking will happen

Lines that only say the masker "passes the note through today" stay true and need no change. These do need a change:

| File | Lines | Change |
|---|---|---|
| `js-tickets/CLAUDE.md` and `pacEHR_AI/CLAUDE.md` | 365; § Clinical and PHI rules | Replace "Identifiers are masked before egress and restored after" with "The note reaches Azure OpenAI as sent, under the BAA. It never reaches a log line, trace attribute, error message or audit row." Change "Log the token, never the value" to "Log the code, never the value" |
| `js-tickets/epic-06-validation.md` | 205, 241, 314 | Remove the PEA-503 dependency from PEA-607 and from "keeping the date of birth off the wire". Lines 240, 246 and 257 stay true (the note sent is the note) |
| `js-tickets/epic-09-review-api.md` | 74, 98, 198, 236 | PEA-902: remove the PEA-503 dependency and the "place the de-mask" item. There's nothing to restore |
| `js-tickets/epic-07-tools.md` | 193, 205, 222, 234 | PEA-705: loaded history still goes through the injection scan and size limit; drop "no unmasked identifier" and "share one token map"; remove the "Epic 5 masker" dependency |
| `js-tickets/epic-10-observability.md` | 63, 75, 258, 272 | Hashes and replay run on the note as sent. Line 272's compliance check on replaying real notes **stays**; only the masking premise changes |
| `js-tickets/epic-11-azure-deployment.md` | 146, 250 | "Masking (Epic 5) protects identifiers inside the payload" becomes "The BAA covers the payload". Shadow runs keep their audit duties |
| `js-tickets/epic-12-memory.md` | 138 | The memory block still needs the injection scan; there's no masker decision to make |
| `js-tickets/epic-03-template-schema.md` | 168 | "PHI masking of `found_in` (Epic 5)": no masking applies |
| `js-tickets/epic-05-guardrails.md` | PEA-503 row in Part 2 | Status becomes "Closed by decision (BAA)"; points 0; link to this file. PEA-504's open item is answered: the masking sets ship as `todo` |

`js-tickets/epic-04-agent-core.md` (lines 70–303) describes the identity masker as it is. It stays true and needs no
change.

**Done for Epic 5 only (2026-10-15).** `js-tickets/epic-05-guardrails.md` is corrected: the PEA-503 row is "Closed by
decision (BAA)" with 0 points, PEA-504's open item is answered, and the Notes bullet is marked resolved.
`pacEHR_AI/CLAUDE.md` is corrected on the epic branch. **The other epics' tickets (3, 6, 7, 9, 10, 11 and 12) are left
unchanged by decision (Hem Singh: don't change anything outside this epic).** Their owners make the rows above when
they pick up those epics.

## 5. Definition of Done

- [x] The owner's decision is recorded: confirmed by the client on a call, 2026-10-15 (no written copy; see §2)
- [ ] The three documents in §4.1 are corrected, or tracked with an owner
- [x] The JS-ticket edits in §4.2 that belong to Epic 5 are made: `epic-05-guardrails.md` and `pacEHR_AI/CLAUDE.md`
      (2026-10-15). The other epics' rows are handed to their owners, unchanged here by decision
- [x] No code change: `phi.ts`, `phi_mask` and `_tokenMap` stay; `npm test` still passes (2026-10-15: 390 tests, 379
      passing, 0 failing, 11 todo)
