# AI Encounter Schema — Repository & Service Layer Jira Stories

Source: `2026-10-07-ai-encounter-schema-design.md` (rev 7) §9–§11, §17 "Next" step 4 ("Build the repositories and the turn, review and finish writes").
Predecessor: `2026-10-13-ai-encounter-schema-jira-stories.md` (schema-only stories — tables already created).
Scope: `src/repositories/` and `src/services/` for the five new `AI` tables plus the `AI.encounterUsage` view. Functional requirements only, no NFRs.

**Conventions used below** (from `pacEHR_AI/CLAUDE.md` and the existing `templateRepository.ts` / `templateService.ts`):
- One repository class per table, singleton export: `class <Entity>Repository` → `export const <entityName>Repository = new <Entity>Repository()`.
- Every SQL/`EXEC` statement is a `SCREAMING_SNAKE_CASE` constant suffixed `_SQL`, declared above the class — never built by string interpolation.
- `database.execute(sql, params)` for anything that returns rows (`SELECT`, or a write with `OUTPUT`); `database.run(sql, params)` for a write that returns no recordset.
- Repository methods return typed domain objects (`src/types/*.types.ts`), mapped from raw rows by a mapper in `src/mappers/*.ts` — never raw `Record<string, unknown>` leaking upward.
- Column names in types keep the live schema's own casing (`summaryID`, `transcriptID`, `templeteId`, etc.) per CLAUDE.md's "preserve the database's own spelling" rule.
- A service method earns its place only when it holds real logic beyond forwarding one repository call (CLAUDE.md "Singletons" rule) — plain lookups stay a direct repository call from the caller.

**Prerequisite note (flag, not a story here):** every write method below wraps one of the five procedures named in design §10 (`AI.usp_addEditEncounterTranscript`, `AI.usp_addEditEncounterFieldReview`, `AI.usp_addBehaviorSummary`, `AI.usp_resetBehaviorSummary`, `AI.usp_purgePatientData`). None of these procedures exist yet — only the tables/view do. Repository/service code and its unit tests can be written now against a mocked `database`, but each write method stays unusable against a real database until its procedure ships as its own migration. Worth its own small story per procedure before — or alongside — these; not included here since the ask was repository/service only.

**Explicitly out of scope for this batch:** the reporting/analytics queries in design §11 — field accuracy, calibration, evidence quality, monthly spend, refusals-by-reason, interrupted-turns sweep (operational, see Story 3), scribe activity. These serve observability/reporting features, not the turn/review/finish write path design §17 calls out as next, and would be premature to build against unbuilt UI consumers. Revisit as a dedicated "AI usage reporting" epic once a consumer exists.

---

## Story 1 — AI.EncounterTranscript repository and turn start/finish service

**As a** developer,
**I want** a repository and service for recording and completing a chat turn,
**so that** the agent has one place to start a turn, finish it, and read back conversation history.

**Repository — `encounterTranscriptRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `startTurn(encounterId, templeteId, clinicianQuery, createdBy)` | `AI.usp_addEditEncounterTranscript` (start mode) | `transcriptID` |
| `completeTurn(transcriptId, { aiResponse \| reasonCode, promptId, promptHash, patientSummaryId, clinicianSummaryId, historyEncounterIds, historySummaryIds, modelName, usage, latencyMs })` | `AI.usp_addEditEncounterTranscript` (finish mode) | `void` — throws if the procedure's `UPDATE` affects 0 rows (turn already finished or doesn't exist) |
| `getConversationHistory(encounterId)` | §11 "Chat history for the next turn" | `{ clinicianQuery, aiResponse }[]`, ordered by `transcriptID`, completed turns only |
| `getById(transcriptId)` | simple `SELECT` by PK | one turn row (needed to build the field-review snapshot, and for the interrupted-turn check) |
| `getHistorySummariesForTurn(transcriptId)` | §11 "What the AI was actually shown as history for one turn" | the pinned `AI.encounterSummary` versions read via `historySummaryIds`, in order |
| `findInterrupted()` | §11 "Interrupted turns" | turns started >5 minutes ago with neither `aiResponse` nor `reasonCode` set — needed by an ops sweep, not a report |

**Service — `turnService`**
- `startTurn(encounterId, clinicianQuery, userId)`: resolves the encounter's current `templeteId`, calls `encounterTranscriptRepository.startTurn`, returns the new `transcriptID`.
- `finishTurn(transcriptId, outcome)`: calls `encounterTranscriptRepository.completeTurn`; on success (a reply, not a refusal/failure), triggers the encounter-summary refresh (Story 3) without the clinician waiting.
- `getHistoryForPrompt(encounterId)`: combines `getConversationHistory` with the active `AI.encounterSummary` (Story 3) to build what the prompt-composition step (`src/agents/prompt.ts`) needs.

**Acceptance Criteria**
- A turn is inserted on arrival (start) before the model is called, and completed by a separate call (finish) — no single method does both, matching design §10's "no lock held during a model call."
- `completeTurn` targets only a row where `aiResponse IS NULL AND reasonCode IS NULL`, and the service surfaces an error if that update hits zero rows (a turn can only finish once).
- `getConversationHistory` returns only turns that got a reply (`aiResponse IS NOT NULL`), in `transcriptID` order.
- All text parameters (`clinicianQuery`, `aiResponse`, JSON columns) bind as `NVarChar`; `reasonCode`, `promptHash`, `traceId` bind as `VarChar(n)`; cost columns bind as `Decimal(12,6)` (design §10 driver rules).

**Dependencies:** `AI.usp_addEditEncounterTranscript` must exist (see prerequisite note). No dependency on the other new tables to read/write a turn itself; `patientSummaryId`/`clinicianSummaryId`/`historySummaryIds` are accepted as already-resolved values from Stories 3–5.

---

## Story 2 — AI.EncounterFieldReview repository and review-decision service

**As a** developer,
**I want** a repository and service for recording a clinician's accept/edit/reject/add decision on an AI-suggested field,
**so that** every field decision is captured exactly once per turn and field, and can be withdrawn and re-made.

**Repository — `encounterFieldReviewRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `recordDecision(transcriptId, sectionId, fieldId, { finalValue, finalUnit, isEvidenceDeleted }, reviewedBy)` | `AI.usp_addEditEncounterFieldReview` (upsert under `UPDLOCK, HOLDLOCK`) | the row's computed `action`/`isValueCorrect`/`isUnitCorrect` |
| `withdrawDecision(transcriptId, sectionId, fieldId, reviewedBy)` | same procedure, sets `isDeleted = 1` | `void` |
| `getByTranscriptId(transcriptId)` | simple `SELECT` by `transcriptID` | every (non-deleted) decision row for that turn |

**Service — `fieldReviewService`**
- `submitDecision(transcriptId, sectionId, fieldId, decision, userId)`: reads the AI's offered value/unit/confidence from the turn's `aiResponse` JSON (via `encounterTranscriptRepository.getById`) so the snapshot the procedure stores can never disagree with what was shown, then calls `encounterFieldReviewRepository.recordDecision`.
- `undoDecision(transcriptId, sectionId, fieldId, userId)`: calls `withdrawDecision`.

**Acceptance Criteria**
- A decision is never written with a client-supplied `action`/`isValueCorrect`/`isUnitCorrect` — those stay DB-computed; the service and repository only ever pass `finalValue`/`finalUnit`/`isEvidenceDeleted`.
- Two concurrent submissions for the same `(transcriptId, sectionId, fieldId)` cannot both insert — the procedure's locking hint guarantees the second becomes an update.
- `withdrawDecision` sets `isDeleted = 1` without clearing `aiEvidence`/`finalValue`; a later `submitDecision` for the same key sets it back to 0.
- `updatedDate` changes on every call; `createdDate` is set once, on the first insert only.

**Dependencies:** `AI.usp_addEditEncounterFieldReview` must exist. Requires Story 1's `getById` to source the AI snapshot.

---

## Story 3 — AI.EncounterSummary repository and encounter-summary write service

**As a** developer,
**I want** a repository and service that write a new encounter-summary version when an encounter finishes, and detect when one is missing or stale,
**so that** the patient-summary refresh and the next encounter's history tool always have an up-to-date, reproducible summary.

**Repository — `encounterSummaryRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `getActiveByEncounterId(encounterId)` | §11 "The encounter summary for the history tool and the PATIENT refresh" | the active `{ summaryID, summaryText }`, or none |
| `addVersion({ encounterId, summaryText, sourceTurns, lastTranscriptId, modelName, usage })` | `AI.usp_addBehaviorSummary` (`ENCOUNTER` scope) | the new `summaryID` |
| `findStaleOrMissing()` | §11 "Retry sweep" | signed encounters whose active summary is missing, or older than their newest replied turn |

**Service — `behaviorSummaryService`** (shared home for all three summary scopes — `ENCOUNTER`, `PATIENT`, `CLINICIAN` — since they share one procedure; see Stories 4–5 for the other two scopes' methods on the same service)
- `refreshEncounterSummary(encounterId)`: idempotency check first — if the active summary's `lastTranscriptID` already covers the newest replied turn, does nothing; otherwise builds the summary text (model call, outside this service) and calls `encounterSummaryRepository.addVersion`, then triggers `refreshPatientSummary` (Story 4) with the new `summaryID`.
- `runRetrySweep()`: calls `findStaleOrMissing`, and re-runs `refreshEncounterSummary` for each one found — covers a lost or failed finish call.

**Acceptance Criteria**
- An encounter with no replied turn gets no summary at all; `addVersion` is never called with `sourceTurns = 0`.
- `refreshEncounterSummary` writes a new version only when turns arrived after the current active version's `lastTranscriptID` (an addendum or a re-sign) — otherwise it is a no-op, so repeated finish calls for the same turns stay idempotent.
- Writing a new version deactivates the previous one (the procedure's job, not the repository's) — the repository only ever sees `isActive = 1` on at most one row per `encounterId` afterward.
- `runRetrySweep` picks up both "missing" (no active row at all) and "stale" (`lastTranscriptID` behind the newest replied turn) cases, per the query's own `reason` column.

**Dependencies:** `AI.usp_addBehaviorSummary` must exist. Story 1 (`findInterrupted`/turn data) feeds the "newest replied turn" comparison; triggers Story 4.

---

## Story 4 — AI.PatientSummary repository and patient-summary write service

**As a** developer,
**I want** a repository and service that write a new patient-summary version whenever its source encounter summary changes,
**so that** the model's patient context always reflects the most recently folded-in encounter, with its provenance pinned.

**Repository — `patientSummaryRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `getActiveByPatientId(patientId)` | §11 "Context for a turn" (the `PATIENT` half) | the active `{ summaryID, summaryText }`, or none |
| `addVersion({ patientId, summaryText, sourceEncounters, lastEncounterId, sourceSummaryId, modelName, usage })` | `AI.usp_addBehaviorSummary` (`PATIENT` scope) | the new `summaryID` |

**Service — methods on the shared `behaviorSummaryService`**
- `refreshPatientSummary(patientId, sourceSummaryId)`: called from `refreshEncounterSummary` (Story 3) right after a new `ENCOUNTER` summary is written; folds the finished encounter in and calls `patientSummaryRepository.addVersion` with that `sourceSummaryId`.

**Acceptance Criteria**
- Every new `AI.patientSummary` row records the `AI.encounterSummary.summaryID` it was built from (`sourceSummaryID`); only a row written before any encounter summary existed may have it `NULL`.
- Writing a new version deactivates the previous one (procedure's job); the repository only ever reads back one active row per `patientId`.
- The patient summary is never generated independently of an encounter summary refresh — there is no standalone "refresh patient summary on demand" entry point in this story.

**Dependencies:** `AI.usp_addBehaviorSummary` must exist (shared with Story 3). Driven by Story 3, not called directly by `turnService`.

---

## Story 5 — AI.ClinicianSummary repository and clinician-summary write/reset service

**As a** developer,
**I want** a repository and service that write a new clinician-summary version after every completed turn, and let a clinician reset their own summary,
**so that** clinician-style context becomes available once enough encounters exist, and a clinician can clear it.

**Repository — `clinicianSummaryRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `getActiveForContext(clinicianId, minSourceEncounters)` | §11 "Context for a turn" (the `CLINICIAN` half, `sourceEncounters >= 30`) | the active `{ summaryID, summaryText }` once past cold start, or none |
| `addVersion({ clinicianId, summaryText, sourceEncounters, lastEncounterId, modelName, usage })` | `AI.usp_addBehaviorSummary` (`CLINICIAN` scope) | the new `summaryID` |
| `resetActive(clinicianId)` | `AI.usp_resetBehaviorSummary` (`CLINICIAN` scope) | `void` |

**Service — methods on the shared `behaviorSummaryService`**
- `refreshClinicianSummary(clinicianId)`: called from `turnService.finishTurn` after every completed turn (not only on encounter finish, unlike `ENCOUNTER`/`PATIENT`); calls `clinicianSummaryRepository.addVersion`.
- `resetClinicianSummary(clinicianId)`: calls `resetActive`; this is the one summary scope a user can trigger directly (the other two are system-driven only).

**Acceptance Criteria**
- `getActiveForContext` returns nothing until `sourceEncounters >= 30` (cold start), even if an active row exists.
- A new version is written after every completed turn, not only when the encounter finishes.
- `resetClinicianSummary` sets every version's `isActive` to 0 for that clinician — after a reset, `getActiveForContext` returns none until a new version is written.
- `summaryText` for this table is never checked against or built from any patient value, identifier, or date of service — the service never accepts those as input.

**Dependencies:** `AI.usp_addBehaviorSummary` and `AI.usp_resetBehaviorSummary` must exist. Called from Story 1's `finishTurn`.

---

## Story 6 — AI.EncounterUsage read-only repository

**As a** developer,
**I want** a repository method to read the per-encounter AI usage totals,
**so that** a single encounter's turn count, token totals, and cost can be surfaced without summing `AI.encounterTranscript` by hand.

**Repository — `encounterUsageRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `getByEncounterId(encounterId)` | `SELECT * FROM AI.encounterUsage WHERE encounterID = @encounterID` | `{ turns, inputTokens, outputTokens, inputCostUsd, outputCostUsd, firstTurnDate, lastTurnDate }`, or none if the encounter has no turns |

**Acceptance Criteria**
- Returns one row per `encounterID`, or none — the view already enforces the grouping, so the repository adds no logic beyond the lookup.
- No service class is added for this — a single pass-through lookup has no business logic to hold (per the "a class earns its place by owning construction, never by forwarding" rule); callers use the repository directly.

**Dependencies:** none beyond the view (already created). Cross-database spend/calibration/accuracy aggregations across multiple tables are explicitly out of scope here (see top of document).

---

## Story 7 — Patient data purge orchestration across the AI tables

**As a** developer,
**I want** a single entry point that removes one patient's AI data in the correct order,
**so that** the existing patient-data purge can delete `AI.*` rows without violating the `sourceSummaryID` foreign key.

**Repository — no new per-table repository method; a dedicated `patientPurgeRepository`**
| Method | Wraps | Returns |
| --- | --- | --- |
| `purgePatient(patientId)` | `AI.usp_purgePatientData` | `void` |

**Service — `patientPurgeService`**
- `purgeAiData(patientId)`: called from the existing patient-data purge flow; calls `patientPurgeRepository.purgePatient`. No per-table logic here — the procedure owns the four-step delete order (review rows → turns → `PATIENT` summaries → `ENCOUNTER` summaries) because `sourceSummaryID` is a foreign key.

**Acceptance Criteria**
- Calling `purgeAiData` for a patient with AI history removes their review rows, turns, `PATIENT` summaries, and the `ENCOUNTER` summaries for their encounters, and nothing else.
- `CLINICIAN` summaries are never touched by this call — they hold no patient data.
- The delete order is never reimplemented in TypeScript — it lives entirely in the one procedure, called once.

**Dependencies:** `AI.usp_purgePatientData` must exist. Must be wired into the existing (pre-AI) patient-data purge call site — exact integration point is an open item (design doc O3/O18-adjacent; confirm with the owner of the existing purge flow).
