# AI Encounter Schema — Jira Stories

Source: `2026-10-07-ai-encounter-schema-design.md` (rev 7) and `AI-Schema-Tables.md`.
Epic: AITP-68 (AI Encounter schema migrations).
Scope: schema only — one story per table/view, functional requirements only (no NFRs).
Creation order matters and is carried into "Dependencies" on each story: EncounterSummary → PatientSummary → ClinicianSummary → EncounterTranscript → EncounterFieldReview → EncounterUsage (view).

---

## Story 1 — Create AI.EncounterSummary table

**As a** system,
**I want** a table that stores one version of one encounter's AI summary,
**so that** later turns, the patient summary, and reporting have a durable, versioned record of what was generated and from what.

**Acceptance Criteria**
- `AI.EncounterSummary` exists in the `AI` schema, created before `AI.PatientSummary` (which will reference it).
- Each row records: `summaryID`, `encounterID`, `summaryText`, `version`, `sourceTurns`, `lastTranscriptID`, `isActive`, `modelName`, `inputTokens`, `outputTokens`, `inputCostUsd`, `outputCostUsd`, `traceId`, `createdDate`, `updatedDate`.
- At most one row per `encounterID` can have `isActive = 1`.
- A row cannot exist with `sourceTurns` ≤ 0.
- `(encounterID, version)` is unique, so every version stays addressable.
- `updatedDate` is never earlier than `createdDate`.
- Re-running the migration script creates nothing and raises no error.

**Dependencies:** none (first table in creation order).

---

## Story 2 — Add sourceSummaryID to AI.PatientSummary

**As a** system,
**I want** each patient-summary version to record exactly which encounter-summary version was folded into it,
**so that** the text used to build a patient summary stays reproducible even after the source encounter summary is regenerated.

**Acceptance Criteria**
- `AI.PatientSummary` gains a nullable `sourceSummaryID` column.
- `sourceSummaryID` is a foreign key to `AI.EncounterSummary.summaryID`.
- `sourceSummaryID` is `NULL` only for a version written before any encounter summary existed; every later version records a value.
- All existing `AI.PatientSummary` columns and behavior (active-version uniqueness per patient, version numbering, date checks) are unchanged.
- Re-running the migration script creates nothing and raises no error.

**Dependencies:** Story 1 (`AI.EncounterSummary` must exist first).

---

## Story 3 — Create AI.ClinicianSummary table

**As a** system,
**I want** a table that stores one version of a clinician's AI summary,
**so that** the AI has clinician style/shorthand context once enough encounters exist, without ever holding a patient value.

**Acceptance Criteria**
- `AI.ClinicianSummary` exists in the `AI` schema.
- Each row records: `summaryID`, `clinicianID`, `summaryText`, `version`, `sourceEncounters`, `lastEncounterID`, `isActive`, `modelName`, `inputTokens`, `outputTokens`, `inputCostUsd`, `outputCostUsd`, `traceId`, `createdDate`, `updatedDate`.
- At most one row per `clinicianID` can have `isActive = 1`.
- `(clinicianID, version)` is unique, so every version stays addressable.
- `updatedDate` is never earlier than `createdDate`.
- Re-running the migration script creates nothing and raises no error.

**Dependencies:** none (independent of Stories 1–2; order relative to them is not required by a foreign key, but ships after them in the file sequence).

---

## Story 4 — Create AI.EncounterTranscript table

**As a** system,
**I want** a table that stores one row per chat turn, including which summaries the AI was shown,
**so that** every turn's input, output, and context are fully reconstructable.

**Acceptance Criteria**
- `AI.EncounterTranscript` exists in the `AI` schema.
- Each row records: `transcriptID`, `encounterID`, `templeteId`, `clinicianQuery`, `aiResponse`, `reasonCode`, `promptId`, `promptHash`, `patientSummaryID`, `clinicianSummaryID`, `historyEncounterIds`, `historySummaryIds`, `modelName`, `inputTokens`, `outputTokens`, `inputCostUsd`, `outputCostUsd`, `latencyMs`, `traceId`, `createdBy`, `createdDate`.
- `patientSummaryID` is a foreign key to `AI.PatientSummary.summaryID`; `clinicianSummaryID` is a foreign key to `AI.ClinicianSummary.summaryID`.
- `historySummaryIds` holds a JSON array of the `AI.EncounterSummary` version ids read for each entry in `historyEncounterIds`, in the same order; stored as validated JSON (no foreign key, since it is multi-valued).
- A row has a reply or a reason, never both.
- A finished turn (reply or reason present) always has `latencyMs` set.
- A reply always carries a `modelName`.
- Model usage columns (`modelName`, token and cost fields) are either all set or all `NULL` together.
- Re-running the migration script creates nothing and raises no error.

**Dependencies:** Story 2 (`AI.PatientSummary`) and Story 3 (`AI.ClinicianSummary`) must exist first.

---

## Story 5 — Create AI.EncounterFieldReview table

**As a** system,
**I want** a table that records the clinician's decision on each AI-suggested field,
**so that** accuracy of AI suggestions can be tracked per field, per turn, without the decision ever disagreeing with the values it was built from.

**Acceptance Criteria**
- `AI.EncounterFieldReview` exists in the `AI` schema, with primary key `(transcriptID, sectionID, fieldID)`.
- Each row records: `transcriptID`, `sectionID`, `fieldID`, `aiValue`, `aiUnit`, `aiConfidence`, `aiRemark`, `aiEvidence`, `isEvidenceDeleted`, `finalValue`, `finalUnit`, `action`, `isValueCorrect`, `isUnitCorrect`, `isDeleted`, `reviewedBy`, `createdDate`, `updatedDate`.
- `transcriptID` is a foreign key to `AI.EncounterTranscript.transcriptID`.
- `action`, `isValueCorrect`, and `isUnitCorrect` are computed from `aiValue`/`aiUnit`/`finalValue`/`finalUnit` — never set directly by the client.
- A row cannot carry a unit without a value, and must have at least a suggested or an added value.
- A rejected field (no `finalValue`) carries no `finalUnit`.
- Evidence can only be struck (`isEvidenceDeleted = 1`) if `aiEvidence` was present.
- A decision can be withdrawn (`isDeleted = 1`) and later re-decided.
- `updatedDate` is never earlier than `createdDate`.
- Re-running the migration script creates nothing and raises no error.

**Dependencies:** Story 4 (`AI.EncounterTranscript`) must exist first.

---

## Story 6 — Create AI.EncounterUsage view

**As a** reporting consumer,
**I want** a view that aggregates AI usage per encounter,
**so that** turn counts, token totals, and cost totals are available without separately summing `AI.EncounterTranscript` each time.

**Acceptance Criteria**
- `AI.EncounterUsage` exists in the `AI` schema as a view over `AI.EncounterTranscript`, grouped by `encounterID`.
- For each `encounterID` it exposes: `turns` (count of all turns, successful and failed), `inputTokens`, `outputTokens`, `inputCostUsd`, `outputCostUsd` (each summed across the encounter's turns), `firstTurnDate`, and `lastTurnDate`.
- The view is created only if it does not already exist; any future change to its definition ships as a new, separately numbered migration script.
- Re-running the migration script creates nothing and raises no error.

**Dependencies:** Story 4 (`AI.EncounterTranscript`) must exist first.
