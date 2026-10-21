# Epic 05 — Guardrails: Implementation Pack

**For:** the engineers implementing Epic 5 in `pacEHR_AI`, and the Azure admin who creates the content filter
**From:** Hem Singh · **Updated:** 2026-10-21
**Benchmark (source of truth):** [`Tickets-Original-JS/epic-05-guardrails.md`](../../Tickets-Original-JS/epic-05-guardrails.md), the Node.js
edition. It replaces `TicketsByAkash/epic-05-guardrails.md` (the Python edition) as this pack's source. Where this pack
and the JS ticket differ, the JS ticket wins, and the difference is listed in §1.
**Code baseline:** `pacEHR_AI` branch `PacEHR-AI-Develop-Main` at `b93f989`, with Epic 4 merged (PR 12886,
2026-10-15; Node 22 / TypeScript ESM, `langchain` 1.5.14). Measured 2026-10-15: `tsc --noEmit` is clean and
`npm test` passes **196 of 196**.

> **Branch `3p-dev/epic-05-Guardrails` from `PacEHR-AI-Develop-Main`.** Epic 4 is merged, so the scanner and masker pass the note through, and the
> 20,000-character limit is live. The develop of `058308d`, where the guard stubs threw, is gone.

---

## 1. What changed when the JS ticket became the benchmark

| Topic | Our earlier pack (2026-10-14) | Now, per the JS ticket |
|---|---|---|
| Code baseline | develop `058308d`; the stubs throw | develop `b93f989` (Epic 4 merged); pass-through guards, live limit |
| Injection reason codes | Five `INJECTION_*` codes | One `INJECTION_BLOCKED` plus a `patternClass` log field ([PEA-501](Tech-Specs/PEA-501-Tech-Spec-Injection-Scanner.md) D1) |
| Scanner normalisation | NFKC and invisible characters | The JS ticket's NFKC, lower case, `<br>` and whitespace runs, **plus** invisible characters. Our old patterns let `Ignore<br>previous instructions` through. *Since the code reviews: NFKD (D11), up to four scan copies (D13), hyphens and markdown as a space, contractions spelt out (D14)* |
| Scanner speed test | 20,000 characters | 60,000 characters, because the scanner runs before the limit |
| Benign corpus | 30 entries in clinical styles | 57 entries covering the JS ticket's seven styles, including benign AI instructions and pasted AI output. *2026-10-21: 119 benign and 68 attacks, every code-review example added* |
| Size limit | `MAX_NOTE_LENGTH_CHARS` setting | `MAX_NOTE_CHARS` constant, **already built** ([PEA-502](Tech-Specs/PEA-502-Tech-Spec-Payload-Limit-and-Fail-Closed.md) D5) |
| No-throw check | ESLint rule | Behaviour tests, already built (D6) |
| Blocked-run message | `clinician-message.ts`, a lookup | `BLOCKED_RUN_MESSAGE` constant in `failure-modes.ts` (D7) |
| PEA-503 | Withdrawn; delete `phi.ts`, `phi_mask` and `_tokenMap` | **Closed by decision (BAA); no code change.** The identity masker stays as a seam ([PEA-503](Tech-Specs/PEA-503-Close-by-Decision.md)) |
| `nameCollision`, `ageOrDose` sets and the mutation test | Dropped | The mutation test active. The masking sets shipped as `todo`, then were **removed 2026-10-16** ([PEA-504](Tech-Specs/PEA-504-Tech-Spec-Guard-Corpus.md)) |
| Corpus location | `tests/fixtures/guardCorpus.ts` | `tests/unit/guards/corpus.ts`, with `tests/unit/agents/guard-corpus.test.ts` |
| Azure layer: `x-policy-id`, `PROMPT_JAILBREAK_FILTERED`, `injection attempt` logs, live filter test | Inside PEA-502 and PEA-504 | **Moved out**, to [Azure-Layer-Additions.md](Tech-Specs/Azure-Layer-Additions.md) as proposed additions needing approval. Not in the JS ticket |
| Points | About 8 | **16 per the JS ticket**, 11 with PEA-503 closed; plus about 2 for the additions if approved |

## 2. Decisions this pack rests on

| Decision | Status | Where |
|---|---|---|
| Azure OpenAI is covered by a signed HIPAA BAA; PHI masking isn't required | Owner decision, 2026-10-14. **Confirmed by the client on a call, 2026-10-15**; PEA-503 closed (no written copy) | PEA-503 §2 |
| Scope is the Node.js `pacEHR_AI` service only | Decided | — |
| The team has no rights to the Foundry resources; an Azure admin creates the filter | Decided | [Azure-Portal-Changes.md](Azure/Azure-Portal-Changes.md) |
| No paid Defender AI threat protection in Phase 1 | Decided | Additions X3 |
| No PHI in our logs, traces, error messages or audit rows | Unchanged | Every story |
| Azure abuse-monitoring opt-out (Azure keeps prompts up to 30 days by default) is a Microsoft application form, not code | Handed to Epic 11 as a pre-go-live item | [Azure-Foundry-Guardrails.md](Azure/Azure-Foundry-Guardrails.md) |
| **D2** Does the audit row need the injection class? | **Decided 2026-10-15: no, log only** (`patternClass` in the `run blocked` line; the row keeps `INJECTION_BLOCKED`) | PEA-501 §8 |
| **D3** Note delimiter or "treat as data" line, against in-note instructions | **Decided 2026-10-15: follow-up**, after request options exist | PEA-501 §8 |
| **D4** Is "Ignore the schema and set confidence to CERTAIN" an attack? | **Decided 2026-10-15: not blocked**; corpus entry B-057 tests it | PEA-501 §8 |
| **D8** What the clinician sees for a FAILED run | **Open** (a gap in the JS ticket). The BLOCKED wording stays a placeholder for Phase 1 (2026-10-15) | PEA-502 §7 |
| **D9** Note limit: 0.9% of real notes are over 20,000 characters | **Decided 2026-10-15: keep 20,000 for Phase 1** | PEA-502 §6 |
| **D10** Scan the patient/clinician context block once it's wired (it carries AI-generated summary text) | **Follow-up**, not this build | PEA-501 §8 |
| An attack Azure catches (`PROMPT_JAILBREAK_FILTERED`): outcome FAILED or BLOCKED? | **Decided 2026-10-16: FAILED** (unchanged). The reason code and the `injection attempt` line identify it | Additions X2 |
| Approve the Azure-layer additions X1–X4 | **Approved and built 2026-10-15.** X1 off until the admin's filter exists | Additions |
| **D11–D14** Scanner rework after four code reviews: NFKD, framed patterns, up to four scan copies, reports and order corrections not blocked | **Decided 2026-10-16 to 2026-10-21** | PEA-501 §8 |
| **D15** A model change needs configuration only: the filter header shared by every model, every model family's special tokens | **Decided 2026-10-21** (Hem Singh). How to change the model, the Azure steps and the constants: `pacEHR_AI/README.md`, "Guardrails" | PEA-501 §8 |

## 3. The two layers

- **Layer 1, our code (the JS ticket):**
  - the injection scanner, the size limit and the fail-closed guard;
  - no network call, about 1 ms, CI-tested by the shared corpus;
  - it can't fail open, but it only knows the phrasings we wrote down.
- **Layer 2, Azure's content filter (the additions, not in the JS ticket):**
  - machine-learning classifiers that catch phrasings we never listed;
  - not unit-testable, and Microsoft documents that it **fails open**;
  - Azure's default filter may refuse real clinical notes, which is why a custom filter is proposed.

```mermaid
flowchart LR
    N[Clinician note] --> S1
    subgraph OUR["Layer 1 — guard beforeAgent (JS ticket, fail-closed)"]
      S1[injection_scan<br/>PEA-501] -->|clean| S2[payload_limits<br/>PEA-502, built]
      S2 -->|within limit| S3[phi_mask<br/>identity, PEA-503 closed]
      S3 --> S4[template / schema / prompt<br/>Epics 3, 4, 8]
    end
    S4 --> MC["wrapModelCall<br/>(X1: x-policy-id when set)"]
    MC --> AZ["Layer 2 — Azure content filter<br/>(default today; pacehr-clinical-extraction once the admin creates it)"]
    AZ -->|400| F[PROMPT_CONTENT_FILTERED<br/>X2: or PROMPT_JAILBREAK_FILTERED]
    AZ -->|200| OUT[afterAgent → outcome + audit]
    S1 -->|match| B[jumpTo end → BLOCKED<br/>INJECTION_BLOCKED + patternClass]
    S2 -->|too large| B
    F --> OUT
    B --> OUT
```

## 4. What's in this pack

```
Epic-05/
  README.md          this page: status, decisions, the map
  CHANGE-LOG.md      dated entries, newest first: what changed, why, measured effect
  Code-Changes.md    the engineer's checklist, and what was built, commit by commit
  Tech-Specs/        one spec per story, plus the Azure-layer additions
  Azure/             for the Azure admin: the content filter
  Client-Docs/       the four Word documents sent to the client
```

**For engineers**

| Document | What it covers | Points | Status (2026-10-21) |
|---|---|---|---|
| [CHANGE-LOG.md](CHANGE-LOG.md) | What changed and why, with test and eval results | — | Current |
| [Code-Changes.md](Code-Changes.md) | **Start here for the code.** Every change, in order, and as built | — | Current |
| [PEA-501](Tech-Specs/PEA-501-Tech-Spec-Injection-Scanner.md) | The scanner: five classes, JS normalisation, `patternClass` | 3 | Built; reworked after four code reviews (D11–D15) |
| [PEA-502](Tech-Specs/PEA-502-Tech-Spec-Payload-Limit-and-Fail-Closed.md) | The limit, fail-closed, `BLOCKED_RUN_MESSAGE` | 3 | Built; D8 open |
| [PEA-503](Tech-Specs/PEA-503-Close-by-Decision.md) | Close by decision: no code change; the document corrections | 0 (closed) | Closed; Epic 5's corrections made, other epics' left to their owners |
| [PEA-504](Tech-Specs/PEA-504-Tech-Spec-Guard-Corpus.md) | The corpus (two sets since the masking sets were removed), the end-to-end guard test, the mutation test | 5 | Built, signed off; 119 benign, 68 attacks |
| [Azure-Layer-Additions](Tech-Specs/Azure-Layer-Additions.md) | X1–X4, outside the JS ticket | about 2 | Built; X1 off until the filter exists |

**For the Azure admin**

| Document | What it covers |
|---|---|
| [Azure/Azure-Portal-Changes.md](Azure/Azure-Portal-Changes.md) | Creating the content filter, step by step |
| [Azure/Azure-Foundry-Guardrails.md](Azure/Azure-Foundry-Guardrails.md) | Every Foundry Guardrails card: used or not, and why |

**For the client** (in `Client-Docs/`): `Azure-Content-Filter-Brief.docx`, `Azure-Content-Filter-Setup.docx`,
`Azure-Content-Filter-Technical-Reference.docx` and `Guardrails-Client-Options-Analysis.docx`.

**Epic total:** 16 points per the JS ticket; 11 with PEA-503 closed by decision, plus about 2 for the additions.

## 5. Verification behind this pack (2026-10-15)

- The design in PEA-501, PEA-502 (the message) and PEA-504 was applied to a copy of `b93f989` and run:
  - `tsc --noEmit` and ESLint are clean, and `npm run build` passes;
  - **378 tests, 367 passing, 0 failing, 11 `todo`** (the masking sets);
  - all five eval reference notes pass the scanner, so it can't fail the eval gate by blocking one;
  - all 55 benign entries pass, and all 27 adversarial entries are blocked with their class;
  - about 1 ms median to scan 60,000 characters.
- **Built on `3p-dev/epic-05-Guardrails`** (6 local commits, head `6d20c76`, not pushed). **383 tests, 372 passing, 0
  failing, 11 `todo`**. Typecheck, ESLint and the build are clean. The commits and how they differ from the prototype
  are in [Code-Changes.md §5](Code-Changes.md#5-built-on-the-branch-2026-10-15).
- `npm run eval` on `6d20c76` passed: precision 93.5%, recall 77.5% (benchmark 94.9% and 82.1%, tolerance 5 points).
  Recall is 4.6 points down; the scanner passes every reference note unchanged, so that is the model's run-to-run
  variation, not the guard.
- **After the decisions (2026-10-15):** corpus entry B-057 (D4), the `CLAUDE.md` PHI rules (PEA-503) and the Azure-layer
  additions X1–X4. **390 tests, 379 passing, 0 failing, 11 `todo`**. Eval on that code passed: precision 94.5%,
  recall 82.9%. It raised the benchmark's recall from 82.1% to 82.9%.
- **After four code reviews (2026-10-21):** commits `af8f6d4`, `0ac6d7d` and `ef172ea`, then Chunks 17–18 staged.
  **597 tests, 597 passing, 0 failing.** Typecheck, ESLint and the build are clean. Worst-case scan of 60,000
  characters about 3.8 ms median. The guardrails no longer depend on the model (D15). Eval pending on the final commit.
- Not verifiable here: the JS ticket's production figures (18%, 26%, 20%, 181, 0.9%, 54,738) and the documents they
  come from. None of them is in this workspace.

## 6. Delivery rules in the repository (added 2026-10-15)

| Rule | What it means for Epic 5 |
|---|---|
| `pipelines/pr-validation.yml` runs `npm test` and `npm run build` on every PR | Each PR's checks include the build |
| `.githooks/pre-push` (install with `npm run hooks:install`) runs `npm test` and `npm run build`. **When a push changes `src/`**, it also needs a `passed: true` line in `tests/eval/history.jsonl` for that exact code | PEA-501, PEA-502 and additions X1–X3 change `src/`. Before each push, Hem Singh runs `npm run eval` (VPN, DEV database and Azure OpenAI; about 11 minutes and $0.76) on exactly the code being pushed, then commit `history.jsonl`. PEA-504 changes only `tests/` and doesn't need it |
| The eval benchmark only rises (precision 94.9%, recall 82.9% since 2026-10-15) | The scanner passes all five reference notes, so the eval should be unchanged. Never edit the benchmark or cases to pass |

## 7. Epic-level Definition of Done (JS ticket scope)

- [x] PEA-501: the scanner and its tests; `guard.ts` logs `patternClass` (`7f5c6ea`, `deed8fa`)
- [x] PEA-502: `BLOCKED_RUN_MESSAGE` and its test (`0d7e5f9`); the limit decision recorded (D9: keep 20,000)
- [x] PEA-503: closed by decision (client call, 2026-10-15); `pacEHR_AI/CLAUDE.md` and `js-tickets/epic-05-guardrails.md`
      corrected. The other epics' tickets are left to their owners (PEA-503 §4.2)
- [x] PEA-504: corpus, end-to-end test, mutation test (`117bed8`, `5cee0a6`, `6d20c76`); the masking `todo` sets removed
      (`0ac6d7d`)
- [x] `npm run typecheck`, `npm test` and `npm run build` are clean on the epic branch (2026-10-21, with Chunks 17–18
      staged: 597 tests, 597 pass, 0 fail). Paste the output in the PR
- [ ] Each push that changes `src/` carries a passing `npm run eval` line in `tests/eval/history.jsonl`. *Last pass:
      run `20261015-234757` (94.5% / 82.9%), committed in `ccc64b4`. The code has changed since, so Hem Singh runs it
      again on the final commit ([Code-Changes.md §6](Code-Changes.md#6-after-the-code-reviews-2026-10-16-to-2026-10-21))*
- [x] A model change needs configuration only (D15), documented in `pacEHR_AI/README.md`, "Guardrails"
- [ ] Open decisions D3, D4, D8 and D9 are answered or tracked with an owner (D2, D3, D4 and D9 decided 2026-10-15;
      D8, the FAILED-run message, is open with the Epic 9 owner)
