# Project Status

**Last Updated**: 2026-10-19 15:00
**Updated By**: ARCHITECT
**Overall Status**: 🟡 IN PROGRESS

---

## Project Overview

**Project**: PacEHR
**Type**: Brownfield
**Start Date**: 2026-09-08
**Target Completion**: TBD
**Active Cycle**: N/A

---

## Progress Summary

| Step | Status | Owner | Updated | Evidence | Recorded |
|------|--------|-------|---------|----------|----------|
| System Discovery | ✅ Done (refreshed, user-confirmed) | AIRE_ARCHITECT | 2026-10-19 | `docs/architecture/current/00-system-overview.md` (3 repos incl. `pacEHR_AI`) | 2026-10-19 12:00 |
| Deep-Dive | ✅ Done (full refresh + module 13) | AIRE_ARCHITECT | 2026-10-19 | `docs/architecture/current/01-…` through `13-pacehr-ai-service-deep-dive.md` (13 modules, 64 diagrams) | 2026-10-19 15:00 |
| Requirements | ✅ Done | AIRE_ANALYST_PM | 2026-10-05 | `docs/requirements.md` (Epic 02 scope) | 2026-10-05 17:05 |
| Target Architecture | ✅ Done | AIRE_ARCHITECT | 2026-10-05 | `docs/architecture/design/02-target-architecture-brownfield.md` | 2026-10-05 17:40 |
| Patterns | ✅ Done | AIRE_ARCHITECT | 2026-10-05 | `docs/architecture/design/03-patterns-and-standards-brownfield.md` | 2026-10-05 18:05 |
| Implementation Plan | ✅ Done | AIRE_PRODUCT_OWNER | 2026-10-05 | `docs/plans/implementation-plan.md` + `dependency-graph.yml` + 7 story files | 2026-10-05 18:35 |
| Review | ✅ Done | AIRE_REVIEWER | 2026-10-06 | **All 7 stories built, reviewed and ✅ APPROVED.** Migration application gated on B14 | 2026-10-06 08:10 |
| QA | 🟡 In Progress | AIRE_QA | 2026-10-06 | `docs/testing/validation-report-epic-2-2026-10-06.md` — ⚠️ CONDITIONAL PASS | 2026-10-06 04:50 |

---

## Current Step Details

### System Discovery — Refresh 2 (2026-10-19)

**Owner**: ARCHITECT
**Status**: ✅ Done — user confirmed 2026-10-19
**Scope**: `PacEHR`, `pacEHR_API`, `pacEHR_AI` (user-specified); outputs written only under `saiystems-AIRE/docs/`
**Analysed at HEAD**: `PacEHR` = 401caa134 (detached, `3p-dev/AITP-117-…`), `pacEHR_API` = 0f611f65c (`PacEHR-DevelopAPI-Main`), `pacEHR_AI` = ef172ea (`3p-dev/epic-05-Guardrails`). All three trees clean.
**Drift since 2026-09-30**: 432 commits (212 UI + 179 API + 41 AI)

**Progress**:
- [x] Phase 0 — Reference check: `SPEC/references/` empty (two empty folders); no `docs/helix/INDEX.md`; helix MCP needs authorization, not used ✅
- [x] Phase 1 — Initial scan ✅
- [x] Phase 2 — Technology analysis ✅
- [x] Phase 3 — Architecture mapping (3 Mermaid diagrams) ✅
- [x] Phase 4 — `docs/architecture/current/00-system-overview.md` rewritten ✅
- [x] Phase 5 — `docs/architecture-diagrams/00-system-overview-diagrams.md` rewritten (3 diagrams; **not render-tested** — no local Mermaid renderer was available) ✅
- [x] Phase 6 — status.md updated ✅
- [x] User confirmation of the overview ✅ (open questions waived by the user: accepted as-is)

**Headline changes**: `pacEHR_AI` is now a real Node 22 / LangChain / Azure OpenAI service (~1,950 lines, 39 test files, 10 migrations, eval gate) but has a health-only HTTP surface and **no caller in the SPA or API**. Dragon Copilot dictation added (SPA service, `webUiToken` endpoint, `usp_GetDragonSubByUserId`). API 100 controllers / ~1,039 endpoints; backend unit tests 3,408.

**Open questions raised**:
1. The 2026-10-06 entries below name AI-schema objects (`agentRun`, `fieldOutcome`, `fieldConstraint`, `promptFragment`) that do not exist among the 10 migrations on `epic-05-Guardrails`. Is that work on another branch?
2. Is the `AI` schema in the same Azure SQL database as the PacEHR schema? (inferred from settings only)
3. Should findings 1–12 (below) be re-verified now? They are carried forward, not re-checked.

**Corrections to the 2026-09-30 overview**: `IDRFirstServices` is registered three times, not twice; `PacEHR.API/Hubs/` does contain two hub classes (no `MapHub` in `Program.cs`).

**No code was modified.** Prior versions backed up to the session scratchpad.

> Deep-dive refresh completed the same day — see the entry below.

---

### Deep-Dive — Full System Refresh 2 + Module 13 (2026-10-19)

**Owner**: ARCHITECT
**Status**: ✅ Done (documents are Draft — awaiting user confirmation of each)
**Scope**: full system — all 12 existing modules re-analysed, plus new module 13 (`pacEHR_AI` service), at `PacEHR` = 401caa134, `pacEHR_API` = 0f611f65c, `pacEHR_AI` = ef172ea
**Method**: 7 parallel analysis agents, one or two modules each; the architect verified diagram parity (every deep-dive diagram byte-identical in its preview file) and dates. No renderer was available, so Mermaid syntax is **not render-tested**. **No code was modified.**

**Progress**:
- [x] Phase 1 — Module analysis ✅  - [x] Phase 2 — Flow analysis ✅  - [x] Phase 3 — Data analysis ✅
- [x] Phase 4 — Pattern extraction (DO/DON'T with file:line) ✅
- [x] Phase 5 — 13 deep-dive documents written ✅
- [x] Phase 6 — 13 diagram-preview files written; 64 diagrams, parity verified ✅
- [x] Phase 7 — status.md updated ✅

| # | Module | Document | Diagrams |
|---|---|---|---|
| 1 | Auth, identity & tenancy | `01-auth-identity-tenancy-deep-dive.md` | 5 |
| 2 | API request & data spine | `02-api-request-data-spine-deep-dive.md` | 4 |
| 3 | Data & SQL tier | `03-data-sql-tier-deep-dive.md` | 4 |
| 4 | PointClickCare integration | `04-pointclickcare-integration-deep-dive.md` | 5 |
| 5 | Interoperability (FHIR/CCDA/QRDA) | `05-interoperability-fhir-ccda-qrda-deep-dive.md` | 5 |
| 6 | HL7 v2 & ADT ingestion | `06-hl7-adt-ingestion-deep-dive.md` | 4 |
| 7 | Other external integrations | `07-external-integrations-deep-dive.md` | 4 |
| 8 | Background processing | `08-background-processing-deep-dive.md` | 5 |
| 9 | SPA shell & navigation | `09-spa-shell-navigation-deep-dive.md` | 5 |
| 10 | SPA feature areas | `10-spa-feature-areas-deep-dive.md` | 6 |
| 11 | Test infrastructure & CI/CD | `11-test-infrastructure-cicd-deep-dive.md` | 4 |
| 12 | AI assistance & dictation (legacy path + Dragon Copilot) | `12-ai-assistance-deep-dive.md` | 5 |
| 13 | **pacEHR_AI service (new)** | `13-pacehr-ai-service-deep-dive.md` | 8 |

`12a-…` and `12b-…` banners changed from STALE to PARTLY STALE (legacy content unchanged since 2026-09-10; no Dragon / `pacEHR_AI` coverage).

**Corrections to the 2026-09-30 findings table** (re-verified against code):
- Finding 1 (`/speechToText`): still anonymous, but the four query-string ids are never used and nothing is persisted — the "forged transcript on any patient's chart" claim is **dropped**; cost and unbounded memory remain.
- Finding 5: only `saveADTMessage` is anonymous; `sigmaCareADTEndPoint` / `sigmaCareCCDEndpoint` need an encrypted `token` header.
- Finding 6: 22 Service Bus send methods (not 18); zero receivers in the three repos, but `HIEController.cs:55-58` names an out-of-workspace consumer.
- Finding 12: the "190 backup tables / 88 procs" figures could not be reproduced (re-count 122–173 tables, 62–79 procs depending on method).
- Findings 2, 3, 4, 7, 8, 10 still hold (3 and 4 re-confirmed; 4's `GetHeaders()` sites rose 126 → 156). Module 02: the 928 EF entity files are `Compile Remove`d — not compiled.

**New findings this pass** (details in the module docs):
- 🔴 **Dragon Copilot RSA private key committed in all 6 `appsettings.<Env>.json` including Production** (first in `4fcacd350`, PAC-584); the matching public key is published anonymously at `/.well-known/jwks.json` (Module 12). Candidate for `aire-raise-defect`.
- Service Bus connection strings with `RootManageSharedAccessKey` in 6 tracked appsettings files (Module 06).
- 548 backend tests in 46 files are excluded from compilation (`Compile Remove="DomainServices\**"`), so they never run (Module 11).
- DrFirst poller likely throws every run: `EveryFiveMinutesFunction.cs` parses an empty string (Module 08).
- Datadog RUM sends staff name, email and role (Module 09).
- `pacEHR_AI` (Module 13): nothing calls the agent; no audit row is written anywhere; `[AI].[usp_getActiveClinicianSummary]` is called but created by no migration; migration runner has no history table (re-runs all scripts, rejects `ALTER TABLE`); the last passing eval does not cover HEAD (`ef172ea` code hash not in `history.jsonl`); a `FOUND` slot with an empty value is banded HIGH; tenancy ids are caller-asserted.

**Unverified items are marked "carried, not re-verified" in each module.**

---

### Deep-Dive — Full System Refresh (2026-09-30 — superseded)

**Owner**: ARCHITECT
**Status**: ✅ Done
**Scope**: full system — all 12 modules re-analysed against current HEAD at user request
**Analysed at HEAD**: `PacEHR` = 3034de845, `pacEHR_API` = 9f2a6ee19
**No code was modified.** Prior versions backed up to the session scratchpad.

**Progress**:
- [x] Phase 1 — Module analysis (files, classes, interfaces, dependencies) for all 12 modules ✅
- [x] Phase 2 — Flow analysis (42 Mermaid sequence/flow/state/ER diagrams) ✅
- [x] Phase 3 — Data analysis (schemas, tables, relationships, ER) ✅
- [x] Phase 4 — Pattern extraction with DO/DON'T examples and file:line citations ✅
- [x] Phase 5 — 12 deep-dive documents rewritten ✅
- [x] Phase 6 — 12 diagram-preview files rewritten; doc↔preview parity verified ✅
- [x] Phase 7 — status.md updated ✅

**Modules analysed**:

| # | Module | Document | Diagrams |
|---|---|---|---|
| 1 | Auth, identity & tenancy | `01-auth-identity-tenancy-deep-dive.md` | 4 |
| 2 | API request & data spine | `02-api-request-data-spine-deep-dive.md` | 4 |
| 3 | Data & SQL tier | `03-data-sql-tier-deep-dive.md` | 3 |
| 4 | PointClickCare integration | `04-pointclickcare-integration-deep-dive.md` | 4 |
| 5 | Interoperability (FHIR/CCDA/QRDA) | `05-interoperability-fhir-ccda-qrda-deep-dive.md` | 4 |
| 6 | HL7 v2 & ADT ingestion | `06-hl7-adt-ingestion-deep-dive.md` | 4 |
| 7 | Other external integrations | `07-external-integrations-deep-dive.md` | 3 |
| 8 | Background processing | `08-background-processing-deep-dive.md` | 3 |
| 9 | SPA shell & navigation | `09-spa-shell-navigation-deep-dive.md` | 4 |
| 10 | SPA feature areas | `10-spa-feature-areas-deep-dive.md` | 3 |
| 11 | Test infrastructure & CI/CD | `11-test-infrastructure-cicd-deep-dive.md` | 3 |
| 12 | AI assistance & dictation | `12-ai-assistance-deep-dive.md` | 3 |

Supplements `12a-ai-request-payload-reference.md` and `12b-ai-prompt-examples.md` were **not** regenerated and now carry a STALE banner.

**Corrections made to earlier documents during this pass**:
- `00-system-overview.md` — the Polly `ResiliencePipeline` is registered but never injected; EF Core's `EnableRetryOnFailure` is what actually protects SQL.
- `01-auth-...` — anonymous-endpoint count corrected to 56 active attributes in 10 controllers (60 textual occurrences, 4 commented out).
- `01-auth-...` — the FHIR reachability question is resolved by Module 05.

---

### 🔴 Findings requiring a decision before requirements (2026-09-30; corrections listed in the 2026-10-19 entry above)

Raised by this pass; each is evidence-based and cited in the linked module.

| # | Finding | Module |
|---|---|---|
| 1 | `/speechToText` — unauthenticated WebSocket taking `userId`/`accountId`/`patientId` from the query string, no ownership check | 12 |
| 2 | `proc_getMultipleICDCodes` — probable SQL injection, reachable via `POST /getMultipleICDCodes`; its sibling was patched in Mar 2026, this one was missed | 03 |
| 3 | FHIR surface non-functional — `IMapper` injected by all 20 controllers, never registered in DI (~9,600 unreachable lines) | 05 |
| 4 | Client-asserted tenancy — 126 `GetHeaders()` sites read `accountID` from a client header vs 2 reads of the server-derived value | 01 |
| 5 | Three unauthenticated clinical ingestion endpoints (`saveADTMessage`, `sigmaCareADTEndPoint`, `sigmaCareCCDEndpoint`), no signature validation | 06 |
| 6 | 18 Service Bus producers, **zero** consumers in either repository | 06 |
| 7 | PHI masking and prompt-injection detection run only in the browser; the API forwards prompts to OpenAI verbatim | 12 |
| 8 | No Twilio webhook signature validation on 16 anonymous endpoints; `VideoCallController` 15 of 16 routes anonymous | 07 |
| 9 | Committed credentials: `wcthesnfist_com.pfx`, `Google-Credentials.json`, `openAIapiKey`, `SecretKey123`, `StaticSalt` | 04, 12, 01 |
| 10 | Deploy pipelines run no tests; PR pipelines use `pr:` triggers that Azure Repos Git ignores | 11 |
| 11 | Decrypted clinical request bodies written to Log Analytics by audit and error middleware | 02 |
| 12 | 190 backup **tables** (patient diagnosis, encounter, medication, insurance snapshots) and 88 backup procedures deployed to production by SSDT | 03, 06 |

Items 1, 2, 3 and 9 are remediation rather than design and are candidates for `aire-raise-defect` now, ahead of the requirements phase.

---

### System Discovery — Refresh (2026-09-30)

**Owner**: ARCHITECT
**Status**: ✅ Done
**Trigger**: user-requested refresh of the 2026-09-08 baseline
**Analysed at HEAD**: `PacEHR` = 3034de845 (2026-09-30), `pacEHR_API` = 9f2a6ee19 (2026-09-29), `PacEHR_AI` = cfc59aa (2026-09-30)
**Drift since baseline**: 301 commits (158 UI + 143 API)

**Progress**:
- [x] Phase 0 — Reference check: `SPEC/references/` empty (two empty folders); no `docs/helix/INDEX.md`; helix MCP unauthenticated, atlassian-rovo MCP timed out ✅
- [x] Phase 1 — Initial scan: repo layout, entry points, config files, dependency manifests ✅
- [x] Phase 2 — Technology analysis: languages, frameworks, DB, external services, build & test tooling ✅
- [x] Phase 3 — Architecture mapping: style, subsystems, layer structure, 2 Mermaid diagrams ✅
- [x] Phase 4 — `docs/architecture/current/00-system-overview.md` rewritten ✅
- [x] Phase 5 — `docs/architecture-diagrams/00-system-overview-diagrams.md` rewritten ✅
- [x] Phase 6 — status.md updated ✅

**Key deltas recorded**: SQL tables 1,048 → 1,120; stored procedures 1,489 → 1,553; API endpoints ~1,025 → ~1,012; SPA components 315 → 322; `PacEHR_AI` repo added (stub only, no source); referral-lock SignalR hub moved out of the API to a standalone service (Feature 32556).

**No code was modified.** Prior versions of both documents backed up to the session scratchpad.

> ⚠️ **Deep-dive docs are now stale.** The 12 module deep-dives (`01-…` through `12-…`) were written against the 2026-09-08 HEAD, 301 commits ago. Re-run `aire-brownfield-deep-dive` before relying on them for requirements.

---

### Deep-Dive (2026-09-08 — superseded by the refresh above)

**Owner**: ARCHITECT
**Status**: ✅ Done
**Started**: 2026-09-08
**Scope**: full system — 11 modules analysed sequentially, plus module 12 (`ai-flow`) added as a targeted supplement

**Progress**:
- [x] Phase 1 — Module analysis (files, classes, interfaces, dependencies) for all 11 modules ✅
- [x] Phase 2 — Flow analysis (28 Mermaid sequence/flow/state diagrams) ✅
- [x] Phase 3 — Data analysis (data models, tables, relationships) ✅
- [x] Phase 4 — Pattern extraction with DO/DON'T code examples and file:line citations ✅
- [x] Phase 5 — 12 deep-dive documents written ✅
- [x] Phase 6 — 12 diagram-preview files created ✅
- [x] Phase 7 — status.md updated ✅
- [x] System overview corrected in place + addendum added (3 corrections, 14 new risk findings, 8 new strengths) ✅

**Modules analysed**:

| # | Module | Document | Diagrams |
|---|---|---|---|
| 1 | Auth, identity & tenancy | `01-auth-identity-tenancy-deep-dive.md` | 4 |
| 2 | API request & data spine | `02-api-request-data-spine-deep-dive.md` | 3 |
| 3 | Data & SQL tier | `03-data-sql-tier-deep-dive.md` | 2 |
| 4 | PointClickCare integration | `04-pointclickcare-integration-deep-dive.md` | 3 |
| 5 | Interoperability (FHIR/CCDA/QRDA) | `05-interoperability-fhir-ccda-qrda-deep-dive.md` | 2 |
| 6 | HL7 v2 & ADT ingestion | `06-hl7-adt-ingestion-deep-dive.md` | 3 |
| 7 | Other external integrations | `07-external-integrations-deep-dive.md` | 3 |
| 8 | Background processing | `08-background-processing-deep-dive.md` | 3 |
| 9 | SPA shell & navigation | `09-spa-shell-navigation-deep-dive.md` | 3 |
| 10 | SPA feature areas | `10-spa-feature-areas-deep-dive.md` | 3 |
| 11 | Test infrastructure & CI/CD | `11-test-infrastructure-cicd-deep-dive.md` | 3 |
| 12 | AI assistance & dictation *(supplements 7)* | `12-ai-assistance-deep-dive.md` | 5 |

**Verification actions raised for the team** (cannot be answered from source alone — these gate the requirements step):

1. Do any PR gates actually run? YAML `pr:` triggers are ignored for Azure Repos Git; check branch policies. (Module 11)
2. Has the FHIR surface ever worked in a deployed environment? Call `GET /fhir/metadata` on dev/QA/prod. (Module 5)
3. Does the Service Bus queue `"matrixcare"` exist and is it drained? Check active + dead-letter counts. (Module 6)
4. How long has the DrFirst prescription sync been failing? The worker emits no telemetry. (Module 8)
5. Evaluate `pacehr-orchestration`'s `kb.sh trace` (UI → endpoint → proc → tables) before requirements. (Module 11)
6. What does `getEncounterRequirement()` actually pass as `additionalData`? DTO types it `string`, client sends `any[]`. One runtime observation classifies it. (Module 12)
7. Are `OPENAI_API_KEY` / `OPENAI_API_URL` populated in the SQL app-settings table per environment, or is every environment on the `appsettings.json` fallback? Gates safe rotation of the committed key. (Module 12)
8. Is client-side-only enforcement of `maskPHI` / `detectInjection` an accepted design decision or unfinished work? (Modules 7, 12)

---

## Quality Metrics

| Metric | Target | Current | Status | Recorded |
|--------|--------|---------|--------|----------|
| Unit Test Coverage | ≥85% | `databaseMigrations.ts` 94.94% lines / 85.00% branch (manual — ISS-005 blocked by ISS-010) | 🟡 | 2026-10-05 20:10 |
| Integration Tests | 100% pass | `PacEHR_AI`: 42 tests, 9 pass / **33 skipped** (no credentials — **never executed against a database**). `pacEHR_API`: still 0 | 🟡 | 2026-10-06 05:30 |
| Code Review | All stories | **7/7 approved** | ✅ | 2026-10-06 08:10 |
| Documentation | All stories | 2/2 planning docs + 1 review remediated | 🟡 | 2026-10-05 19:40 |

---

## Completed Steps

- [x] **Deep-Dive (Full System Refresh 2 + Module 13)**: Done — 2026-10-19
  - Scope: all 12 modules re-analysed + new module 13 (`pacEHR_AI`) at `PacEHR` = 401caa134, `pacEHR_API` = 0f611f65c, `pacEHR_AI` = ef172ea
  - Evidence: `docs/architecture/current/01-…` through `13-pacehr-ai-service-deep-dive.md`
  - Diagrams: `docs/architecture-diagrams/01-…` through `13-…-diagrams.md` (64 Mermaid diagrams; parity verified, not render-tested)
  - No code modified
- [x] **System Discovery (Refresh 2)**: Done — 2026-10-19 — user confirmed
  - Evidence: `docs/architecture/current/00-system-overview.md` (full rewrite, three repos, delta table vs 2026-09-30)
  - Diagrams: `docs/architecture-diagrams/00-system-overview-diagrams.md` (3 Mermaid diagrams)
  - Analysed at HEAD `PacEHR` = 401caa134, `pacEHR_API` = 0f611f65c, `pacEHR_AI` = ef172ea; no code modified
- [x] **System Discovery**: Done — 2026-09-08
  - Evidence: `docs/architecture/current/00-system-overview.md` (corrected + addendum added after deep-dive)
  - Diagrams: `docs/architecture-diagrams/00-system-overview-diagrams.md`
  - Analysed at HEAD `PacEHR` = 5f5890b97, `pacEHR_API` = 151128065; no code modified
- [x] **Deep-Dive**: Done — 2026-09-08
  - Scope: full system, 11 modules; module 12 (AI assistance & dictation) added 2026-09-08 as a route-level supplement to module 7
  - Evidence: `docs/architecture/current/01-…-deep-dive.md` through `11-…-deep-dive.md` (~4,200 lines)
  - Diagrams: `docs/architecture-diagrams/01-…` through `11-…-diagrams.md` (32 Mermaid diagrams)
  - Every pattern cites a real file path; no code modified

- [x] **Deep-Dive (Full System Refresh)**: Done — 2026-09-30
  - Scope: all 12 modules re-analysed at current HEAD
  - Evidence: `docs/architecture/current/01-…` through `12-…-deep-dive.md` (~4,600 lines)
  - Diagrams: `docs/architecture-diagrams/01-…` through `12-…-diagrams.md` (42 Mermaid diagrams)
  - Every pattern cites a real file path; doc↔preview diagram parity verified; no code modified
- [x] **System Discovery (Refresh)**: Done — 2026-09-30
  - Evidence: `docs/architecture/current/00-system-overview.md` (full rewrite, includes delta table vs. baseline)
  - Diagrams: `docs/architecture-diagrams/00-system-overview-diagrams.md` (2 Mermaid diagrams)
  - Analysed at HEAD `PacEHR` = 3034de845, `pacEHR_API` = 9f2a6ee19, `PacEHR_AI` = cfc59aa; no code modified
- [x] **Code Review v2 — Story 2.5 (PEA-205)**: Done — 2026-10-06
  - Mode: FIX_VERIFICATION. Result: **✅ APPROVED** — 🏁 **every story in Epic 02 is now approved**
  - Evidence: `docs/reviews/story-2.5-code-review-v2.md`
  - ISS-501 verified across **every failure shape**, not only the one its test covers: missing
    `fragmentText` / `version` / `fragmentID` all refused, empty string preserved, **and a malformed
    row in second position refused** — the guard runs per row, which matters because a multi-row
    result is the normal case here
  - Zero new 🔴/🟠
  - 🔴 **The approval covers the code, not the migration.** B14 stands: `CK_promptFragment_
    templateOverride` is forward-only DDL built on inference and needs Epic 8's author before the
    migration set is applied anywhere
- [x] **Remediation — Story 2.5 (PEA-205)**: Done — 2026-10-06
  - Source report: `docs/reviews/story-2.5-code-review-v1.md` (annotated in place)
  - Fixed: **the 🟠 + the 🟢**. Three 🟡 deferred, each needing a person or a database
  - ISS-501: row columns checked, not asserted — all three typed-row repositories now agree.
    Used `typeof fragmentText !== 'string'`, **not truthiness**, so an empty fragment survives;
    that distinction was carried over from ISS-703 deliberately rather than rediscovered
  - ISS-505: comment records that `'contract'` leads alphabetically by coincidence, not precedence
  - ⏸️ **ISS-502 deferred and it gates deployment**: `CK_promptFragment_templateOverride` is
    forward-only DDL built on an inference. **Do not apply the migration set anywhere until Epic 8's
    author confirms it**
  - 📌 **Suggested, not implemented**: a lint rule making `as <Type>` on a `database.execute` result
    a guard error. The same defect was found and fixed three times (ISS-604, ISS-703, ISS-501) —
    a review catching it three times is doing a job that belongs upstream
  - Evidence: `npm test` **132 pass / 0 fail**; typecheck clean; integration 9 pass / 33 skipped
- [x] **Code Review — Story 2.5 (PEA-205)**: Done — 2026-10-06
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.5-code-review-v1.md`
  - Issues: 0 🔴 | **1 🟠** | 3 🟡 | 1 🟢
  - 🟠 **ISS-501 — the same defect, third time.** `rows as PromptFragment[]` is the unchecked
    assertion fixed as ISS-604 (2.6) and ISS-703 (2.7), **not applied here**. Verified by execution:
    a renamed column yields `fragmentText: undefined`, which reaches the model as its instruction.
    Worse than either precedent — a `contract` fragment carries the safety rules, so an undefined one
    silently removes *"capture, do not infer"* from the prompt
  - 🟡 ISS-502: `CK_promptFragment_templateOverride` forbids any non-override fragment from naming a
    template — stricter than the spec, and it would block a specialty fragment scoped to one
    template. **Forward-only DDL: confirm with Epic 8 before applying anywhere**
  - 🟡 ISS-503: the filtered index likely cannot seek on the query's `OR` predicates — unverifiable
    until B11 clears, since only a real server produces a plan
  - 🟡 ISS-504: `updatedUtc` is never updated, on **three tables** — a timestamp that silently means
    something other than its name
  - Two spec defects recorded for amendment to the epic text (missing `templetID`, stale `0004` name)
  - `npm test` 130 pass / 0 fail. No code modified — review-only workflow
- [x] **Implementation — Story 2.5 (PEA-205)**: Done — 2026-10-06 — **Epic 02 is now fully built**
  - **D11 settled by owner decision**: sentinel `0` + plain `UNIQUE (kind, scope, accountId,
    templetID, version)`. ADR-05 option A, matching `usp_getPrompt` tier 3's existing `accountId = 0`
  - Files: `migrations/sql/0006_create_prompt_fragment.sql`,
    `src/repositories/promptFragmentRepository.ts`, unit + integration test files (all new)
  - 🔴 **Two spec defects found and recorded, not silently resolved**:
    (1) PEA-205 §4's column list has **no `templetID`**, yet `kind` admits `'template_override'` —
    such a fragment could not name its template. Built with `templetID INT NOT NULL DEFAULT 0`,
    matching the approved unique key;
    (2) the spec names `0004_create_prompt_fragment.sql` — stale, 0004 is `fieldConstraint`. Used
    **0006**, the number reserved in the dependency graph
  - Two CHECKs added beyond the spec, both preventing silent disagreement:
    `CK_promptFragment_scopeAccount` (a global fragment carries no account; an account-scoped one
    must) and `CK_promptFragment_templateOverride` (only a `template_override` names a template)
  - The reader resolves `isActive = 1 AND passedEvaluation = 'PASSED'` only, so `PENDING_EVAL`,
    `BLOCKED` and `INCOMPLETE` all **fail closed** — a rejected prompt edit cannot reach a chart
  - Ships **no write statement**: a test enumerates the module's `_SQL` exports and asserts the
    agent is structurally incapable of writing its own instructions
  - ✅ **Closes ISS-004** (open since story 2.1's first review): `post-apply-checks.sql` check #4
    expects five tables, and five now ship
  - Evidence: `npm test` **130 pass / 0 fail**; typecheck clean; `validate()` accepts the new script;
    integration 9 pass / 33 skipped / 0 fail
- [x] **Remediation — QA defects (Epic 2)**: Done — 2026-10-06
  - Source report: `docs/testing/validation-report-epic-2-2026-10-06.md` (annotated in place)
  - **QA-001 ✅** `pendingForEncounter` — three unit cases + an integration case asserting a decided
    row leaves the review queue while an undecided one stays. All three unit tests **passed on first
    run**: the method was correct, it had no test
  - **QA-002 ✅** the integration skip reason now says *"configuration incomplete, so no connection
    was attempted"* when `settings()` threw. Seven files; `core/llm.test.ts` deliberately untouched
  - **QA-003 ✅** both offending integration files now delete their `encounterID = -1` fixtures
  - 🔴 **QA-004 (NEW, open)** — raised while verifying this remediation's own numbers: **the coverage
    gate cannot be evidenced.** Four identical runs gave 85.23 / 71.38 / 68.05 / 73.59%, and under
    `tsx` erased type declarations and doc comments are counted as uncovered lines —
    `fieldOutcomeRepository.ts` fell 97.99% → 81.88% *after* three passing tests were added.
    **The earlier ✅ on the coverage gate is withdrawn**; the validation report is corrected from
    5 of 9 gates met to **4 of 9**
  - Evidence: `npm test` **124 pass / 0 fail**; typecheck clean; integration 8 pass / 26 skipped
- [x] **QA Validation — Epic 2**: Done — 2026-10-06
  - Evidence: `docs/testing/validation-report-epic-2-2026-10-06.md`
  - Verdict: **⚠️ CONDITIONAL PASS** — 13 of 38 scenarios executed, **5 of 9 quality gates met**
  - ✅ Unit **121/121**, typecheck clean, lint guards firing, coverage 85.23% overall and
    94.94–100% on every Epic 2 module
  - ❌ **25 of 33 integration tests did not execute** — no CHECK constraint, FK, PK, unique
    constraint, column name or `@@ROWCOUNT` in this epic has been exercised once
  - ❌ **Commit gate fails**: 34 uncommitted paths; HEAD `e86c54e` predates the entire epic
  - 🟠 **QA-001 (new)**: `pendingForEncounter` — the clinician review-queue read — has **no test and
    no caller**. Explains 54.55% function coverage against 97.99% line coverage. **Six code reviews
    missed it**; story 2.3's v1 reviewed its return type without noticing nothing ran it
  - 🟡 **QA-002 (new)**: the integration skip reason claims *"Azure SQL did not answer"* when
    `settings()` threw first and the database was never contacted — once credentials exist, a real
    outage, an expired credential and a typo will all produce the same wrong sentence
  - 🟡 **QA-003**: two integration files never clean up their `encounterID = -1` fixtures
  - **No defect was found in the production code of any of the six built stories**
- [x] **QA Test Plan — Epic 2**: Done — 2026-10-06
  - Scope: `epic-2`. Evidence: `docs/testing/test-plan-epic-2.md`
  - **38 scenarios specified**: 31 already implemented, **7 new**, 13 executable today, **25 blocked
    on B11**
  - 🔴 Headline: **this epic does not need more tests written — it needs the ones that exist to be
    run once.** TC-ENV-001 is the highest-value test in the plan
  - Every REQ-02-* maps to a scenario except **REQ-02-01, left explicitly unmapped** because story
    2.5 is unbuilt (D11) — recorded rather than silently omitted
  - Notable new scenarios: **TC-X-004** (an SSDT publish must not propose dropping the `AI` tables —
    ADR-04, a blocker before any deployment, unowned); **TC-RUN-005** (an `UPDATE` on `AI.agentRun`
    is *expected to succeed* after ADR-01 — the test documents the exposure rather than passing);
    **TC-OUT-007** (the `decidedAtUtc IS NULL` guard is tested sequentially today, never
    concurrently); **TC-CON-005** (a value exactly on `plausibleMax`, exposing ADR-06)
  - ⚠️ Fixture hygiene: the 2.2 and 2.3 integration tests leave `encounterID = -1` rows behind; fix
    before TC-ENV-001 is run repeatedly
  - **Schedule deliberately undated** — four of six execution risks are decisions or access with no
    owner, and dates against them would be fiction
- [x] **Code Review v2 — Story 2.4 (PEA-204)**: Done — 2026-10-06
  - Mode: FIX_VERIFICATION. Result: **✅ APPROVED** — the last built story is closed
  - Evidence: `docs/reviews/story-2.4-code-review-v2.md`
  - All six issues verified resolved by executing the live modules: `DELETE TOP (@batchSize)`,
    batch size 4000, `AND [decidedAtUtc] IS NOT NULL`, age bound retained, `MILLISECONDS_PER_DAY`
    exported, `src/purge.ts` present
  - Two new, neither blocking: **ISS-407 🟡** — the `useUTC` test was added to
    `database.sql-login.test.ts` and reads a **memoised pool** built under the first test's
    environment (proved by probe), so it asserts less than its placement implies; **ISS-408 🟢** —
    the batch loop has no iteration cap (terminates correctly, but it is the one destructive loop
    against production)
  - **🏁 Every built story in Epic 02 is now approved**
- [x] **Remediation — Story 2.4 (PEA-204)**: Done — 2026-10-06
  - Source report: `docs/reviews/story-2.4-code-review-v1.md` (annotated in place)
  - **Every issue fixed — 2 🟠, 2 🟡, 2 🟢. Nothing deferred.**
  - ISS-401: `DELETE TOP (@batchSize)` with a loop; `PURGE_BATCH_SIZE = 4000`, chosen under SQL
    Server's ~5,000-lock escalation threshold so the review queue is never blocked behind a purge
  - ISS-402: **owner decision** — undecided rows are preserved (`AND [decidedAtUtc] IS NOT NULL`).
    Escalated rather than decided by the implementer, since it is a clinical-workflow question.
    ⚠️ Accepted consequence: undecided rows now accumulate with no policy; revisit when M4 exists
  - ISS-403: `useUTC: true` stated in the pool config, asserted against the built pool
  - ISS-404: `src/purge.ts` + `npm run purge`. A refusal exits **0**, unlike `migrate.ts` — deleting
    nothing until compliance sets a window is correct, not a failure
  - The integration test was **rewritten, not patched**: its old fixture was entirely undecided, so
    under the new rule it would have passed while proving nothing
  - Evidence: `npm test` **121 pass / 0 fail**; typecheck clean; integration 8 pass / 25 skipped / 0 fail
- [x] **Code Review — Story 2.4 (PEA-204)**: Done — 2026-10-06
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.4-code-review-v1.md`
  - Issues: 0 🔴 | **2 🟠** | 2 🟡 | 2 🟢
  - ✅ **The story's 🔴 DoD reviewer sign-off is given**: the retention schema is `.optional()` and
    **not** `.default(0)`, with `.positive()` rejecting an explicit 0 — both verified by execution.
    Also noted: `z.coerce.number()` would turn `''` into 0, and only the house `unsetIfBlank`
    preprocessor prevents that — the guard holds by convention, not by this field's own design
  - 🟠 ISS-401: **the DELETE is unbounded in row count.** At ~10.95M rows/year the first purge after
    D4 lands would delete everything outside the window in one transaction, on the live production
    database — lock escalation, log growth, and the clinician review queue blocked behind it
  - 🟠 ISS-402: **the purge does not distinguish decided from undecided rows.** A short window would
    silently empty part of the review queue. With R1 open (no writer for accepted values) **every row
    is currently undecided**, so a window configured today would purge the entire eligible table
  - 🟡 ISS-403: UTC correctness rests on tedious's `useUTC: true` default, which nothing states
  - Neither 🟠 can fire today — D4 is unmade so the purge refuses — but both must be settled
    **before** D4 lands, because the first run is unattended
  - `npm test` 116 pass / 0 fail. No code modified — review-only workflow
- [x] **Implementation — Story 2.4 (PEA-204)**: Done — 2026-10-06
  - Dev slot 1, one-by-one. Tracker: local (no `## Project Tracking` block)
  - Files: `src/core/settings.ts`, `src/jobs/fieldOutcomeRetention.ts` (new),
    `src/repositories/fieldOutcomeRepository.ts`, `package.json` (`#jobs/*` alias), `.env.example`,
    `tests/unit/jobs/fieldOutcomeRetention{,.configured}.test.ts` (new),
    `tests/unit/core/settings.retention.test.ts` (new),
    `tests/integration/repositories/fieldOutcomeRetention.test.ts` (new), `tests/unit/repo.test.ts`
  - 🔴 The dangerous line is written as specified: `z.coerce.number().int().positive().optional()`.
    **Never `.default(0)`.** Both halves tested — unset yields `undefined` and purges 0 rows sending
    no statement at all; an explicit `0` is rejected by `settings()`
  - **Deviation from the epic's DoD**: `DELETE_FIELD_OUTCOME_BEFORE_SQL` lives in
    `fieldOutcomeRepository`, not in the job module, because `CLAUDE.md` makes the repository the
    only writer of its table. The job owns the policy; the repository owns the statement
  - Two existing tests caught the change and were updated: the schema-order list in
    `settings.test.ts`, and `.env.example`'s one-line-comment rule
  - Evidence: `npm test` **116 pass / 0 fail**; typecheck clean; integration 8 pass / 23 skipped / 0 fail
- [x] **Code Review v2 — Stories 2.2, 2.3, 2.6, 2.7**: Done — 2026-10-06
  - Mode: FIX_VERIFICATION. Result: **✅ APPROVED (all four)**
  - Evidence: `docs/reviews/story-2.{2,3,6,7}-code-review-v2.md`
  - **All 11 remediated issues verified by executing the live modules**, not by reading diffs:
    one SQL constant on `agentRunWriter`; a blocked run writing `null` tokens; a decision routed
    through a caller-supplied `execute`; `ABSENT`/`ABSTAINED` forwarded distinctly; `constraintKey`
    gone and `mappingKey` shared; an undefined description refused and an empty one preserved
  - **Zero new 🔴/🟠 across all four stories**
  - 2.6's v2 re-checked the `mappingKey` rewire, which landed under **story 2.7's** remediation
    after 2.6's own had closed — recorded so the report and the code do not appear to disagree
  - 🔴 Every approval is bounded by **B11**: 21 of 28 integration tests have never executed, so the
    database-level behaviour in all four stories is asserted in code that has not run
  - **Epic 02's review pass is complete for every built story**
- [x] **Remediation — Story 2.7 (PEA-207)**: Done — 2026-10-06
  - Source report: `docs/reviews/story-2.7-code-review-v1.md` (annotated in place)
  - Fixed: **the 🔴 Blocker + both 🟠**. ISS-704 and ISS-705 deferred
  - ISS-701: zero tests → **five unit + four integration cases**, closing blocker B12 entirely
  - ISS-702: `src/repositories/mapping.ts` exports `mappingKey`, used by **both** repositories.
    `constraintKey` deleted. **This changed story 2.6's code and both its test files** — the defect
    was created by 2.6's own remediation earlier the same day
  - ISS-703: all three columns checked, so a renamed column raises instead of handing the model
    `undefined` as a field's meaning. Implemented with `typeof`, not truthiness, so an **empty-string
    description survives as a value** — rejecting it would turn a configured mapping into an
    unconfigured one
  - Evidence: `npm test` **108 pass / 0 fail**; typecheck clean; integration 7 pass / 21 skipped / 0 fail
- [x] **Code Review — Story 2.7 (PEA-207)**: Done — 2026-10-05
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.7-code-review-v1.md`
  - Issues: **1 🔴** | 2 🟠 | 1 🟡 | 1 🟢
  - 🔴 ISS-701: zero tests — the remaining half of B12
  - 🟠 ISS-703: `row.description as string` means a renamed column hands the model **`undefined` as
    a field's meaning**. Nothing raises; the field just extracts worse. Sharpest correctness issue
    found in the epic, because the failure lands inside the model's instructions
  - 🟠 ISS-702: after 2.6's remediation there are now **two independent key builders for one
    identity** — `constraintKey` exported, the description key inline. Should be one `mappingKey`
  - ISS-704: a missing description is indistinguishable from an unconfigured template — the same
    open question as 2.6; should be settled once by Epic 3, not twice
  - **This completes the first review pass over every built story in Epic 02**
  - `npm test` 103 pass / 0 fail. No code modified — review-only workflow
- [x] **Remediation — Story 2.6 (PEA-206)**: Done — 2026-10-05
  - Source report: `docs/reviews/story-2.6-code-review-v1.md` (annotated in place)
  - Fixed: **the 🔴 Blocker + the 🟠 + ISS-604 🟡**. ISS-603 and ISS-605 deferred
  - ISS-601: story went from **zero tests to six unit + four integration cases**
  - ISS-602: `constraintKey()` exported and used by repository and tests alike, so the key contract
    cannot drift. ⏸️ The empty-Map ambiguity (unconfigured template vs configured-with-a-gap) is
    **left open deliberately** — it is Epic 6's decision to make
  - ISS-604: mapping columns checked rather than asserted; all three repositories now agree
  - Evidence: `npm test` **103 pass / 0 fail**; typecheck clean; integration 6 pass / 17 skipped / 0 fail
  - ⚠️ Observed, not formally raised: the 2.2 and 2.3 integration tests insert `encounterID = -1`
    rows and **never clean up**, so a shared DEV database accumulates rows in the two tables the
    epic budgets growth for. The 2.6 test cleans up after itself
- [x] **Code Review — Story 2.6 (PEA-206)**: Done — 2026-10-05
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.6-code-review-v1.md`
  - Issues: **1 🔴** | 1 🟠 | 2 🟡 | 1 🟢
  - 🔴 ISS-601: **the story has no tests at all** — `grep -rln "fieldConstraint" tests/` returns
    nothing. Auto-Reject under the review rulebook. **Story 2.7 is in the same state**
  - 🟠 ISS-602: the returned Map key `"sectionID:fieldID"` is an undocumented contract that
    **fails open** — a format drift is a silent miss, indistinguishable from "no bound defined",
    so a clinical bound stops applying with no error
  - ISS-603/604: the `DECIMAL`-as-double trap is documented but unenforced; `row as FieldConstraint`
    is an unchecked assertion — the last of the family fixed in 2.2 and 2.3
  - `npm test` 97 pass / 0 fail. No code modified — review-only workflow
- [x] **Remediation — Story 2.3 (PEA-203)**: Done — 2026-10-05
  - Source report: `docs/reviews/story-2.3-code-review-v1.md` (annotated in place)
  - Fixed: **all 3 🟠 plus ISS-304 🟡**. ISS-305/306/307 deferred
  - ISS-301: `recordDecision` now takes the `execute` seam, so Epic 9's resolve can be atomic.
    Integration case asserts the decision does **not** survive a forced rollback
  - ISS-302: status and confidence coverage added — **passed on first run**, so this was a coverage
    gap, not a defect. Recorded as such rather than claimed as a repair
  - ISS-303: `tests/integration/repositories/fieldOutcomeRepository.test.ts` written — ⚠️ **never
    executed**, no `.env.local`. Covers the 9 status×band combinations, the FK, the `@@ROWCOUNT`
    shape and transaction rollback
  - ISS-304: result guards on both write methods, aligning with the ISS-204 fix in `agentRunWriter`
  - Evidence: `npm test` **97 pass / 0 fail**; typecheck clean; integration 5 pass / 13 skipped / 0 fail
- [x] **Code Review — Story 2.3 (PEA-203)**: Done — 2026-10-05
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.3-code-review-v1.md`
  - Issues: 0 🔴 | 3 🟠 | 3 🟡 | 1 🟢
  - ISS-301 🟠: `recordDecision` has no `execute` seam, so it cannot join a transaction — Epic 9's
    atomic resolve (GAPS #17) needs one. Asymmetric with `recordProposal` and `agentRunWriter.record`
  - ISS-302 🟠: **every test uses `proposedStatus: 'FOUND'`** — `ABSENT` and `ABSTAINED`, the
    distinction the whole table exists to preserve, are never written. Same for the confidence bands
  - ISS-303 🟠: no integration test — FK, four CHECKs and the `@@ROWCOUNT` recordset shape unverified
  - Recorded as standing risk, not a defect: the accepted-value columns still have no writer (R1/D7),
    and clinician identity is still undefined (Q3)
  - `npm test` 92 pass / 0 fail. No code modified — review-only workflow
- [x] **Remediation — Story 2.2 (PEA-202)**: Done — 2026-10-05
  - Source report: `docs/reviews/story-2.2-code-review-v1.md` (annotated in place)
  - Fixed: **4 — all 3 🟠 plus ISS-204 🟡** opportunistically. ISS-205/206 deferred
  - ISS-202: `record()` now discriminates on `outcome`, not property presence. Probe re-run confirms
    `inputTokens = null` on a variable-built blocked run
  - ISS-201: SQL-constant enumeration guard added, **proved to fire** by planting
    `UPDATE_AGENT_RUN_SQL` and confirming the failure
  - ISS-203: `tests/integration/repositories/agentRunWriter.test.ts` written — ⚠️ **never executed**,
    no `.env.local`. Must be run once credentials exist
  - 🔴 **Story 2.1 defect found and fixed**: `tests/integration/core/databaseMigrations.test.ts`
    asserted the 3 withdrawn roles **exist**, contradicting ADR-01 and `post-apply-checks.sql`. Green
    only because it skips. Missed by story 2.1 v1 and v2 — addendum added to the v2 review
  - Evidence: `npm test` **92 pass / 0 fail**; typecheck clean; integration 4 pass / 9 skipped / 0 fail
- [x] **Code Review — Story 2.2 (PEA-202)**: Done — 2026-10-05
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.2-code-review-v1.md`
  - Issues: 0 🔴 | 3 🟠 | 2 🟡 | 1 🟢
  - ISS-202 🟠 **verified by execution**: a BLOCKED run assembled as a variable writes token counts
    for a model call that never happened — `record()` discriminates on property presence, not on
    `outcome`. Contradicts the story's own AC
  - ISS-201 🟠: the "no update path" AC scenario is untested, and after ADR-01 withdrew the GRANTs
    that test is the whole of the append-only enforcement
  - ISS-203 🟠: no integration test — no statement in this story has ever reached a SQL Server, so
    the CHECK constraints and the column names are unverified
  - `npm test` 90 pass / 0 fail; typecheck clean. No code modified — review-only workflow
- [x] **Code Review v2 — Story 2.1 (PEA-201)**: Done — 2026-10-05
  - Mode: FIX_VERIFICATION. Result: **✅ APPROVED** — story 2.1 is closed for review
  - Evidence: `docs/reviews/story-2.1-code-review-v2.md`
  - All three v1 issues (1 🔴 + 2 🟠) verified resolved **by executing the validator**, not by
    reading the diff: 10 rejection cases + 1 acceptance case all behave correctly
  - ISS-009 🟠 found and fixed in-pass: the new write rule rejected `ON UPDATE CASCADE`, ordinary
    foreign-key DDL. Regression test added, all guards re-verified
  - ISS-010 🟠 found, **pre-existing and out of scope**: `tests/unit/core/settings.test.ts` fails
    under `--experimental-test-coverage`. Verified against a stashed-clean tree. **Blocks ISS-005** —
    a coverage script cannot be added while the suite is red under instrumentation. Epic 01 concern
  - `npm test` 90 pass / 0 fail; typecheck clean; `databaseMigrations.ts` 94.94% lines
- [x] **Remediation — Story 2.1 (PEA-201)**: Done — 2026-10-05
  - Source report: `docs/reviews/story-2.1-code-review-v1.md` (annotated in place, no separate log)
  - Fixed: **3 issues — 1 🔴 + 2 🟠**, every mandatory item. 5 🟡/🟢 deferred with user consent
  - ISS-001: scope rules moved into `validate()`, so the runner refuses an out-of-scope script, not
    just CI. Deviation from the suggested test-only fix, justified in the report
  - ISS-002: write-ban scoped to non-`AI` targets, unblocking Epic 8's bootstrap fragment
  - ISS-003: teardown rejection caught so a clean apply cannot report failure
  - Evidence: `npm test` **89 pass / 0 fail**; `npm run typecheck` clean; lint guards pass;
    `databaseMigrations.ts` coverage **89.22% → 96.02%** lines
  - Files changed: `src/core/databaseMigrations.ts`, `src/migrate.ts`,
    `tests/unit/core/databaseMigrations.test.ts`
- [x] **Code Review — Story 2.1 (PEA-201)**: Done — 2026-10-05
  - Mode: INITIAL_REVIEW, all severities. Result: **❌ CHANGES REQUESTED**
  - Evidence: `docs/reviews/story-2.1-code-review-v1.md`
  - Issues: 1 🔴 Blocker · 2 🟠 High · 3 🟡 Medium · 2 🟢 Low
  - Blocker: an unqualified `CREATE TABLE` escapes the schema-scope check — verified by running the
    test's own regexes against a synthetic script
  - Verified at review time: `npm test` 88 pass / 0 fail; `npm run typecheck` clean;
    `databaseMigrations.ts` coverage 89.22% lines / 94.74% branch
  - Clean-architecture / DI findings deliberately NOT raised, per ADR-03
  - No code modified — review-only workflow
- [x] **Implementation Plan**: Done — 2026-10-05
  - Scope: Epic 2 — 7 stories (2.1–2.7) mirroring PEA-201…207; 24 points; team_size 1; no build cycles
  - Evidence: `docs/plans/implementation-plan.md`, `docs/plans/dependency-graph.yml`,
    `docs/plans/stories/epic-2-story-2.{1..7}-*.md`
  - 4 waves; Step 7 validation (seed-wave, disjoint-files, wave consistency, requires) all pass
  - Story files are **pointers** to `Other-Docs/Epic-02/epic-02-data-layer.md` Rev 8, not copies —
    one source of truth for acceptance criteria
  - Records as-built state per story: 5 built, 1 blocked (2.5/D11), 1 next (2.4)
  - No code modified
- [x] **Patterns & Standards**: Done — 2026-10-05
  - Scope: the `PacEHR_AI` Node/TypeScript service. The .NET API and Angular SPA keep their own conventions
  - Evidence: `docs/architecture/design/03-patterns-and-standards-brownfield.md`
  - 8 categories decided: 6 `[Current — kept]`, API format deferred to Epic 9, UI skipped (no UI layer)
  - **No new adoptions, so no migration notes** — every pattern is already in shipped code
  - Records ADR-03 prominently: `PacEHR_AI/CLAUDE.md` governs over the clean-architecture and
    design-pattern rulebooks, which prescribe the opposite shape
  - Includes the File/Module Boundary Map and `shared_files` list for the plan workflow
  - Tech debt — shared code: **none in `PacEHR_AI`**; SPA debt recorded as out of scope
  - No code modified
- [x] **Target Architecture**: Done — 2026-10-05
  - Scope: Epic 02 data layer — the `AI` schema, migration mechanism and repository surface
  - Evidence: `docs/architecture/design/02-target-architecture-brownfield.md`
  - Diagrams: `docs/architecture-diagrams/02-target-architecture-diagrams-brownfield.md` (3 Mermaid)
  - 6 decision records (ADR-01…06); 12 risks; delta table; forward-only migration plan
  - Supersedes `design/12-ai-phase1-implementation-architecture.md` on 2 points only (ADR-02, ADR-03)
  - 🔴 Design verified against as-built code, which **corrected two requirements errors** — see below
  - No code modified
- [x] **Requirements**: Done — 2026-10-05
  - Scope: **Epic 02 only** (Data Layer — AI Schema, PEA-201…PEA-207, 24 points)
  - Evidence: `docs/requirements.md`
  - Path: PATH L (local), sourced from `Other-Docs/Epic-02/epic-02-data-layer.md` Rev 8 rather
    than elicited from scratch — a 75-story backlog already existed outside the AIRE tree
  - Covers REQ-02-01…10 + REQ-03-01; 14 open questions; no code modified
  - **Revised 2026-10-05** during the architecture step, against the as-built code: database roles
    and GRANTs withdrawn (authority is application-enforced); `AI.promptFragment` recorded as not
    built. Both were owner decisions later than the epic text the document was synthesised from.

---

## Upcoming

**Next (2026-10-19):** user confirmation of the 13 deep-dives, then `aire-brownfield-requirements`.

**Epic 02's build-and-review cycle is complete for every buildable story.** What remains is not
engineering:

1. 🔴 **Run the integration suite once** (B11) — **25 of 33 tests have never executed**, including
   every proof that the purge deletes the right rows and that the CHECK constraints, FKs and PKs
   behave as designed. Needs an `.env.local`, not engineering. **Highest-value action available.**
2. **D11** (~30 min, Architecture) — unblocks the only unbuilt story, 2.5.
3. **D4** (Compliance) — the retention window. Engineering precondition now cleared.
4. **D7** (Product) — the review surface. Until it exists `AI.fieldOutcome` stays half-populated and
   the purge correctly deletes nothing.
5. **M11** (DevOps, unowned) — no deployment path, so no story can be formally *closed* regardless
   of quality.
6. **Commit the work** — 34 uncommitted paths; HEAD predates the whole epic. The QA validation
   reports against a state no one else can reproduce.
7. **QA-004 / B13** — restate the ≥85% gate in **branch** coverage (exact at 93.81% today, zero
   cost), or decide whether to add `c8` for a reproducible line figure. Until then no line-coverage
   number belongs in a release record.
3. **Run the integration suite once credentials exist** (B11) — **13 of 18 tests have never
   executed**, and they are the only proof the CHECK constraints, the foreign key and the
   `@@ROWCOUNT` guard behave as designed.
3. **`aire-dev-implement story 2.4`** — the retention purge mechanism; buildable now.
4. **Decisions, no engineering** — D11 (~30 min, unblocks 2.5), D4 (longest lead), D7, M11.

Recommended ahead of the above: `aire-raise-defect` for findings 1, 2, 3 and 9 in the table above — these are remediation items, not design decisions.

Optional, in scope given the findings: `aire-raise-defect` for the operational/security items that are remediation rather than design (committed TLS keys and secrets, the process-wide TLS bypass, PHI in git and in Log Analytics, the failing DrFirst sync).

---

## Blockers

| ID | Description | Owner | Opened | Status | Recorded |
|----|-------------|-------|--------|--------|----------|
| B1 | `AI.fieldOutcome` retention window unset (**D4**) — purge fails closed until set. ✅ The engineering precondition is cleared: 2.4's ISS-401 and ISS-402 are resolved, so D4 can land without the first run being dangerous | Compliance | 2026-10-05 | Open — compliance only | 2026-10-06 03:10 |
| B2 | Nothing owns writing to the encounter form — the product's only output has no implementation (GAPS #1) | ARCHITECT | 2026-10-05 | Open | 2026-10-05 17:05 |
| B3 | Clinician identity undefined across three incompatible shapes; audit cannot answer "who decided this" (GAPS #6) | ARCHITECT | 2026-10-05 | Open | 2026-10-05 17:05 |
| B4 | Option B / Option C drift | ARCHITECT | 2026-10-05 | ✅ Resolved — ADR-02 records Option C as accepted; supersedes the 2026-09-09 design doc on that point | 2026-10-05 17:40 |
| B5 | `AI.promptFragment` not built (D11) | ARCHITECT | 2026-10-05 | ✅ **Resolved 2026-10-06** — D11 settled as sentinel `0` + plain UNIQUE; story 2.5 built; REQ-02-01 delivered | 2026-10-06 06:40 |
| B6 | `AI.agentRun` immutability is a convention, not a server-side control (no GRANTs). ADR-01 recommends an `INSTEAD OF UPDATE, DELETE` trigger | ARCHITECT + Compliance | 2026-10-05 | Open | 2026-10-05 17:40 |
| B7 | SSDT publish may propose dropping the `AI` tables — two deployment mechanisms, one database, no exclusion designed. ADR-04 | Epic 11 / DevOps | 2026-10-05 | Open | 2026-10-05 17:40 |
| B8 | No deployment path (M11) — every story's exit criterion ends "against staging"; nothing in Epic 02 can be closed | DevOps, unowned | 2026-10-05 | Open | 2026-10-05 17:40 |
| B9 | `AI.fieldOutcome` accepted-value columns have no writer (M4/D7) — table stays half-NULL, edit rate uncomputable | Product | 2026-10-05 | Open | 2026-10-05 17:40 |
| B10 | `tests/unit/core/settings.test.ts` fails under `--experimental-test-coverage` (pre-existing, Epic 01). Blocks adding a coverage script | Epic 01 / DEV | 2026-10-05 | Open | 2026-10-05 20:10 |
| B14 | **ISS-502 — `CK_promptFragment_templateOverride` is forward-only DDL built on an inference.** It forbids any non-override fragment from naming a template, which would block a specialty fragment scoped to one template. **Do not apply the migration set until Epic 8's author confirms** | ARCHITECT + Epic 8 | 2026-10-06 | Open | 2026-10-06 07:40 |
| B13 | **QA-004 — the ≥85% gate is stated in line coverage, which is non-deterministic**: 65.19–88.18% across five identical runs on an unchanged tree. Branch coverage is exact at 93.81%. Fix is to restate the gate, or adopt `c8` (an owner decision — it adds a devDependency) | DEV + owner | 2026-10-06 | Open | 2026-10-06 05:55 |
| B12 | Stories 2.6 and 2.7 had zero tests | DEV | 2026-10-05 | ✅ **Resolved 2026-10-06** — 2.6: six unit + four integration; 2.7: five unit + four integration | 2026-10-06 00:30 |
| B11 | **The integration suite has never been executed** — no `.env.local`, **26 of 34** tests skip. QA validation 2026-10-06 is a conditional pass solely because of this. Every claim about CHECK constraints, FKs, PKs, unique constraints, column existence and `@@ROWCOUNT` is unproven. The pile has tripled in one day | DEV / DevOps | 2026-10-05 | Open | 2026-10-06 00:30 |

---

## Agent Activity

| Agent | Last Action | Status | Updated | Recorded |
|-------|------------|--------|---------|----------|
| ARCHITECT | Deep-dive full refresh + module 13 (13 modules, 64 diagrams) — awaiting user confirmation | Idle | 2026-10-19 | 2026-10-19 15:00 |
| ANALYST_PM | Requirements generated for Epic 02 (PEA-201…207) | Idle | 2026-10-05 | 2026-10-05 17:05 |
| PRODUCT_OWNER | Implementation plan + dependency graph for Epic 2 | Idle | 2026-10-05 | 2026-10-05 18:35 |
| BUILD_CYCLE_PLANNER | — | Standby | — | 2026-09-08 18:23 |
| DEV | Remediated story 2.5 (ISS-501, ISS-505) | Idle | 2026-10-06 | 2026-10-06 07:40 |
| REVIEWER | v2 approval for story 2.5 — all 7 stories approved | Idle | 2026-10-06 | 2026-10-06 08:10 |
| QA | Validation run (epic-2) — conditional pass | Active | 2026-10-06 | 2026-10-06 04:50 |
