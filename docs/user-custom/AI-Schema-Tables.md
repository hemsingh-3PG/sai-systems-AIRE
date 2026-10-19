# AI Encounter Schema — Tables Reference

**Quick reference for writing the migrations.** Every `CREATE` block below is lifted verbatim from
[`2026-10-07-ai-encounter-schema-design.md`](2026-10-07-ai-encounter-schema-design.md) (rev 7), which stays the
single source of truth — section references such as §6 or §9 point into it. This file holds the tables only: no
decisions, no rationale, no reporting queries. Every sample row below comes from the one worked example in §3.1
of the design doc (encounter `50123`), so the rows across these tables all refer to each other. **If the two ever disagree, the design doc wins.**

**Five new tables and one view. No existing table is changed.** `AI` schema only, shipped as forward-only
migrations in `PacEHR_AI` under `migrations/sql`, each guarded by `IF NOT EXISTS` / `CREATE OR ALTER`.

---

## Creation order

Fixed, because each object references only objects created before it:

```
1. AI.encounterSummary       -- no FK of its own
2. AI.patientSummary         -- FK -> AI.encounterSummary
3. AI.clinicianSummary       -- no FK
4. AI.encounterTranscript    -- FK -> AI.patientSummary, AI.clinicianSummary
5. AI.encounterFieldReview   -- FK -> AI.encounterTranscript
6. AI.encounterUsage (view)  -- reads AI.encounterTranscript
```

## References that deliberately carry no foreign key

| Column | Points at | Why not |
| --- | --- | --- |
| `encounterID` on `AI.encounterTranscript` and `AI.encounterSummary` | `Encounter.encounter` | SSDT-owned. An FK it doesn't know about would block a table rebuild. The procedure checks the encounter exists instead. |
| `lastTranscriptID` on `AI.encounterSummary` | `AI.encounterTranscript` | It would close the cycle `encounterSummary` → `encounterTranscript` → `patientSummary` → `encounterSummary`, which no creation order can satisfy. Checked by the procedure. |
| `historySummaryIds` on `AI.encounterTranscript` | `AI.encounterSummary` | A JSON array (0..n versions), so no single-column FK is possible. |
| `promptId` on `AI.encounterTranscript` | `AI.prompt` | `AI.prompt` has no primary key. |

## Types needing approval (pacEHR_API CLAUDE.md rule 3)

`NVARCHAR(MAX)` ×4 — `clinicianQuery`, `aiResponse`, `aiValue`, `finalValue`.
`DECIMAL(12,6)` ×8 — the cost pair on the turn and on each of the three summaries. Fallback is `INT` micro-dollars.

---

## 1. `AI.encounterSummary`

**One row is** one version of one encounter’s summary.

Written when the encounter is signed, and only if at least one turn got a reply. Context for the AI, never authority.

```sql
CREATE TABLE AI.encounterSummary (                                              -- one version of the encounter summary; written when the encounter is signed; context for the AI, never authority
  summaryID        INT IDENTITY    NOT NULL,                                    -- version id
  encounterID      INT             NOT NULL,                                    -- Encounter.encounter.encounterID; logical reference, checked by the procedure (§6)
  summaryText      NVARCHAR(4000)  NOT NULL,                                    -- capped (~800 tokens) and rewritten each version, never appended
  version          INT             NOT NULL,                                    -- 1, 2, … for that encounter; 2+ when the summary is regenerated, because later turns arrived or it was rewritten by hand
  sourceTurns      INT             NOT NULL,                                    -- turns that got a reply (aiResponse IS NOT NULL) folded in; refused and failed turns hold no AI reply and are not counted. Cumulative over the encounter, because the text is rewritten each version, never appended
  lastTranscriptID INT             NOT NULL,                                    -- newest of those replied turns: the high-water mark that says whether this version still covers the encounter (§11). No foreign key: it would close the cycle encounterSummary → encounterTranscript → patientSummary → encounterSummary (§6)
  isActive         BIT             NOT NULL DEFAULT 1,                          -- 1 = the version in use; 0 = superseded or rolled back
  modelName        VARCHAR(50)     NOT NULL,                                    -- model that wrote this version
  inputTokens      INT             NOT NULL,                                    -- tokens sent to write it
  outputTokens     INT             NOT NULL,                                    -- tokens returned
  inputCostUsd     DECIMAL(12,6)   NOT NULL,                                    -- at that day's price
  outputCostUsd    DECIMAL(12,6)   NOT NULL,                                    -- at that day's price
  traceId          VARCHAR(36)     NULL,                                        -- LangSmith run of the summarising call
  createdDate      DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),           -- when this version was written
  updatedDate      DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),           -- when isActive last changed (superseded or rolled back); equals createdDate until then. The text never changes
  CONSTRAINT PK_encounterSummary PRIMARY KEY (summaryID),
  CONSTRAINT UQ_encounterSummary_version UNIQUE (encounterID, version),         -- every version stays addressable for rollback
  CONSTRAINT CK_encounterSummary_sourceTurns CHECK (sourceTurns > 0),           -- a summary exists only where there was a replied turn to build it from (§9 rule 7)
  CONSTRAINT CK_encounterSummary_dates CHECK (updatedDate >= createdDate)
);
CREATE UNIQUE INDEX UX_encounterSummary_active ON AI.encounterSummary (encounterID) WHERE isActive = 1;  -- at most one version in use per encounter; the read is one seek
```

| Column | Type | Meaning |
| --- | --- | --- |
| `summaryID` | `INT IDENTITY NOT NULL` | version id |
| `encounterID` | `INT NOT NULL` | Encounter.encounter.encounterID; logical reference, checked by the procedure (§6) |
| `summaryText` | `NVARCHAR(4000) NOT NULL` | capped (~800 tokens) and rewritten each version, never appended |
| `version` | `INT NOT NULL` | 1, 2, … for that encounter; 2+ when the summary is regenerated, because later turns arrived or it was rewritten by hand |
| `sourceTurns` | `INT NOT NULL` | turns that got a reply (aiResponse IS NOT NULL) folded in; refused and failed turns hold no AI reply and are not counted. Cumulative over the encounter, because the text is rewritten each version, never appended |
| `lastTranscriptID` | `INT NOT NULL` | newest of those replied turns: the high-water mark that says whether this version still covers the encounter (§11). No foreign key: it would close the cycle encounterSummary → encounterTranscript → patientSummary → encounterSummary (§6) |
| `isActive` | `BIT NOT NULL DEFAULT 1` | 1 = the version in use; 0 = superseded or rolled back |
| `modelName` | `VARCHAR(50) NOT NULL` | model that wrote this version |
| `inputTokens` | `INT NOT NULL` | tokens sent to write it |
| `outputTokens` | `INT NOT NULL` | tokens returned |
| `inputCostUsd` | `DECIMAL(12,6) NOT NULL` | at that day's price |
| `outputCostUsd` | `DECIMAL(12,6) NOT NULL` | at that day's price |
| `traceId` | `VARCHAR(36) NULL` | LangSmith run of the summarising call |
| `createdDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when this version was written |
| `updatedDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when isActive last changed (superseded or rolled back); equals createdDate until then. The text never changes |

**Sample row** — from the worked example in §3.1 of the design doc:

```
summaryID        7001
encounterID      50123
summaryText      'Routine visit. Weight 82 kg accepted. BP corrected by the clinician to 140/88. ...'
version          1
sourceTurns      3                      -- turns 9001, 9002 and 9004; turn 9003 got no reply
lastTranscriptID 9004                   -- the newest of those three
isActive         1
modelName        'gpt-4.1-2025-04-14'
inputTokens      6240                   outputTokens   610
inputCostUsd     0.012480               outputCostUsd  0.004880
```

---

## 2. `AI.patientSummary`

**One row is** one version of one patient’s standing summary.

Written at the same finish, straight after the encounter summary. Read on every turn for that patient.

```sql
CREATE TABLE AI.patientSummary (                                                -- one version of the patient summary; written when an encounter is signed; context for the AI, never authority
  summaryID        INT IDENTITY    NOT NULL,                                    -- version id; the turns that used it point here
  patientID        INT             NOT NULL,                                    -- Encounter.encounter.patientID; logical reference, checked by the procedure (§6)
  summaryText      NVARCHAR(4000)  NOT NULL,                                    -- capped (~800 tokens) and rewritten each version, never appended
  version          INT             NOT NULL,                                    -- 1, 2, … for that patient
  sourceEncounters INT             NOT NULL,                                    -- finished encounters folded in
  lastEncounterID  INT             NOT NULL,                                    -- newest encounter folded in: the high-water mark for the next refresh
  sourceSummaryID  INT             NULL,                                        -- the AI.encounterSummary version folded into this one; pins which text was used, since that summary can be regenerated. NULL only for version 1 written before any encounter summary existed
  isActive         BIT             NOT NULL DEFAULT 1,                          -- 1 = the version in use; 0 = superseded or rolled back
  modelName        VARCHAR(50)     NOT NULL,                                    -- model that wrote this version
  inputTokens      INT             NOT NULL,                                    -- tokens sent to write it
  outputTokens     INT             NOT NULL,                                    -- tokens returned
  inputCostUsd     DECIMAL(12,6)   NOT NULL,                                    -- at that day's price
  outputCostUsd    DECIMAL(12,6)   NOT NULL,                                    -- at that day's price
  traceId          VARCHAR(36)     NULL,                                        -- LangSmith run of the summarising call
  createdDate      DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),           -- when this version was written
  updatedDate      DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),           -- when isActive last changed (superseded, rolled back or reset); equals createdDate until then. The text never changes
  CONSTRAINT PK_patientSummary PRIMARY KEY (summaryID),
  CONSTRAINT UQ_patientSummary_version UNIQUE (patientID, version),             -- every version stays addressable for rollback
  CONSTRAINT FK_patientSummary_encounterSummary FOREIGN KEY (sourceSummaryID) REFERENCES AI.encounterSummary (summaryID),
  CONSTRAINT CK_patientSummary_dates CHECK (updatedDate >= createdDate)
);
CREATE UNIQUE INDEX UX_patientSummary_active ON AI.patientSummary (patientID) WHERE isActive = 1;  -- at most one version in use per patient; the read is one seek
```

| Column | Type | Meaning |
| --- | --- | --- |
| `summaryID` | `INT IDENTITY NOT NULL` | version id; the turns that used it point here |
| `patientID` | `INT NOT NULL` | Encounter.encounter.patientID; logical reference, checked by the procedure (§6) |
| `summaryText` | `NVARCHAR(4000) NOT NULL` | capped (~800 tokens) and rewritten each version, never appended |
| `version` | `INT NOT NULL` | 1, 2, … for that patient |
| `sourceEncounters` | `INT NOT NULL` | finished encounters folded in |
| `lastEncounterID` | `INT NOT NULL` | newest encounter folded in: the high-water mark for the next refresh |
| `sourceSummaryID` | `INT NULL` | the AI.encounterSummary version folded into this one; pins which text was used, since that summary can be regenerated. NULL only for version 1 written before any encounter summary existed |
| `isActive` | `BIT NOT NULL DEFAULT 1` | 1 = the version in use; 0 = superseded or rolled back |
| `modelName` | `VARCHAR(50) NOT NULL` | model that wrote this version |
| `inputTokens` | `INT NOT NULL` | tokens sent to write it |
| `outputTokens` | `INT NOT NULL` | tokens returned |
| `inputCostUsd` | `DECIMAL(12,6) NOT NULL` | at that day's price |
| `outputCostUsd` | `DECIMAL(12,6) NOT NULL` | at that day's price |
| `traceId` | `VARCHAR(36) NULL` | LangSmith run of the summarising call |
| `createdDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when this version was written |
| `updatedDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when isActive last changed (superseded, rolled back or reset); equals createdDate until then. The text never changes |

**Sample row** — from the worked example in §3.1 of the design doc:

```
summaryID        6730
patientID        4471
summaryText      'AF is chronic, not new. Usual weight 80-83 kg. Systolic usually 135-145.'
version          4
sourceEncounters 12
lastEncounterID  50123
sourceSummaryID  7001                   -- the encounter summary version folded in
isActive         1
inputTokens      2080                   outputTokens   540
inputCostUsd     0.004160               outputCostUsd  0.004320
```

---

## 3. `AI.clinicianSummary`

**One row is** one version of one clinician’s style summary.

Refreshed after every AI turn, in the background. Used only once `sourceEncounters` ≥ 30 (cold start). Holds no patient value, identifier or date of service.

```sql
CREATE TABLE AI.clinicianSummary (                                              -- one version of the clinician summary; a new version is written after every AI turn; context for the AI, never authority
  summaryID        INT IDENTITY    NOT NULL,                                    -- version id; the turns that used it point here
  clinicianID      INT             NOT NULL,                                    -- Account.users.userId of the clinician the summary describes
  summaryText      NVARCHAR(4000)  NOT NULL,                                    -- capped (~800 tokens) and rewritten each version, never appended
  version          INT             NOT NULL,                                    -- 1, 2, … for that clinician
  sourceEncounters INT             NOT NULL,                                    -- encounters folded in, the one in progress included; the summary is used only from 30 (cold start)
  lastEncounterID  INT             NOT NULL,                                    -- newest encounter folded in: the high-water mark for the next refresh
  isActive         BIT             NOT NULL DEFAULT 1,                          -- 1 = the version in use; 0 = superseded, rolled back, or reset by its owner
  modelName        VARCHAR(50)     NOT NULL,                                    -- model that wrote this version
  inputTokens      INT             NOT NULL,                                    -- tokens sent to write it
  outputTokens     INT             NOT NULL,                                    -- tokens returned
  inputCostUsd     DECIMAL(12,6)   NOT NULL,                                    -- at that day's price
  outputCostUsd    DECIMAL(12,6)   NOT NULL,                                    -- at that day's price
  traceId          VARCHAR(36)     NULL,                                        -- LangSmith run of the summarising call
  createdDate      DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),           -- when this version was written
  updatedDate      DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),           -- when isActive last changed (superseded, rolled back or reset); equals createdDate until then. The text never changes
  CONSTRAINT PK_clinicianSummary PRIMARY KEY (summaryID),
  CONSTRAINT UQ_clinicianSummary_version UNIQUE (clinicianID, version),         -- every version stays addressable for rollback
  CONSTRAINT CK_clinicianSummary_dates CHECK (updatedDate >= createdDate)
);
CREATE UNIQUE INDEX UX_clinicianSummary_active ON AI.clinicianSummary (clinicianID) WHERE isActive = 1;  -- at most one version in use per clinician; the read is one seek
```

| Column | Type | Meaning |
| --- | --- | --- |
| `summaryID` | `INT IDENTITY NOT NULL` | version id; the turns that used it point here |
| `clinicianID` | `INT NOT NULL` | Account.users.userId of the clinician the summary describes |
| `summaryText` | `NVARCHAR(4000) NOT NULL` | capped (~800 tokens) and rewritten each version, never appended |
| `version` | `INT NOT NULL` | 1, 2, … for that clinician |
| `sourceEncounters` | `INT NOT NULL` | encounters folded in, the one in progress included; the summary is used only from 30 (cold start) |
| `lastEncounterID` | `INT NOT NULL` | newest encounter folded in: the high-water mark for the next refresh |
| `isActive` | `BIT NOT NULL DEFAULT 1` | 1 = the version in use; 0 = superseded, rolled back, or reset by its owner |
| `modelName` | `VARCHAR(50) NOT NULL` | model that wrote this version |
| `inputTokens` | `INT NOT NULL` | tokens sent to write it |
| `outputTokens` | `INT NOT NULL` | tokens returned |
| `inputCostUsd` | `DECIMAL(12,6) NOT NULL` | at that day's price |
| `outputCostUsd` | `DECIMAL(12,6) NOT NULL` | at that day's price |
| `traceId` | `VARCHAR(36) NULL` | LangSmith run of the summarising call |
| `createdDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when this version was written |
| `updatedDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when isActive last changed (superseded, rolled back or reset); equals createdDate until then. The text never changes |

**Sample row** — from the worked example in §3.1 of the design doc:

```
summaryID        7791
clinicianID      882
summaryText      'Dictates vitals without units. Usually adjusts BP by a few mmHg after review.'
version          55
sourceEncounters 41                     -- >= 30, so this summary is used
lastEncounterID  50123
isActive         1
```

---

## 4. `AI.encounterTranscript`

**One row is** one chat turn: the clinician’s text and what the AI showed back.

Inserted on arrival, completed with the reply or the reason it failed. The audit record of every AI call, interrupted and failed ones included.

```sql
CREATE TABLE AI.encounterTranscript (                                           -- one chat turn; inserted on arrival, completed when it ends
  transcriptID        INT IDENTITY   NOT NULL,                                  -- turn id; ascending = conversation order
  encounterID         INT            NOT NULL,                                  -- Encounter.encounter.encounterID = the conversation id; logical reference, checked by the procedure (§6)
  templeteId          INT            NOT NULL,                                  -- Encounter.encounter.templeteId when the turn started (its spelling); per-template reporting
  clinicianQuery      NVARCHAR(MAX)  NOT NULL,                                  -- text exactly as the clinician sent it
  aiResponse          NVARCHAR(MAX)  NULL,                                      -- what the clinician was shown (§8); NULL while running or when the turn failed
  reasonCode          VARCHAR(40)    NULL,                                      -- why there is no reply: the agent's REASON_CODES, e.g. INJECTION_BLOCKED, PROMPT_PLACEHOLDER_UNFILLED, MODEL_CALL_FAILED
  promptId            INT            NULL,                                      -- AI.prompt.promptId (no FK: AI.prompt has no primary key); NULL if blocked before the prompt loaded
  promptHash          VARCHAR(64)    NULL,                                      -- SHA-256 of AI.prompt.prompt as read, before placeholders: the wording version, since AI.prompt is edited in place
  patientSummaryID    INT            NULL,                                      -- AI.patientSummary version given as patient context; NULL = none (cold start, or summaries switched off)
  clinicianSummaryID  INT            NULL,                                      -- AI.clinicianSummary version given as clinician context; NULL = none
  historyEncounterIds NVARCHAR(400)  NULL,                                      -- JSON array of prior encounterIDs the history tool loaded; NULL if it wasn't called (Epic 7)
  historySummaryIds   NVARCHAR(400)  NULL,                                      -- JSON array of the AI.encounterSummary.summaryID versions those encounters were read at; pins what the AI was actually shown, since a summary can be regenerated (§9 rule 4)
  modelName           VARCHAR(50)    NULL,                                      -- model version the provider reports, e.g. gpt-4.1-2025-04-14; NULL if the model was never called
  inputTokens         INT            NULL,                                      -- summed over every model call in the turn, cached tokens included
  outputTokens        INT            NULL,                                      -- summed over every model call in the turn
  inputCostUsd        DECIMAL(12,6)  NULL,                                      -- at that day's price; cached tokens at the cached price
  outputCostUsd       DECIMAL(12,6)  NULL,                                      -- at that day's price
  latencyMs           INT            NULL,                                      -- the clinician's wait, arrival → reply or refusal; NULL while running
  traceId             VARCHAR(36)    NULL,                                      -- LangSmith run id: feedback is posted against it, and the trace ↔ audit check joins on it
  createdBy           INT            NOT NULL,                                  -- Account.users.userId of the sender
  createdDate         DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),         -- when the request arrived
  CONSTRAINT PK_encounterTranscript PRIMARY KEY (transcriptID),
  CONSTRAINT FK_encounterTranscript_patientSummary FOREIGN KEY (patientSummaryID) REFERENCES AI.patientSummary (summaryID),
  CONSTRAINT FK_encounterTranscript_clinicianSummary FOREIGN KEY (clinicianSummaryID) REFERENCES AI.clinicianSummary (summaryID),
  CONSTRAINT CK_encounterTranscript_result CHECK (aiResponse IS NULL OR reasonCode IS NULL),                         -- a reply or a reason; neither = running, or interrupted if old
  CONSTRAINT CK_encounterTranscript_finished CHECK ((aiResponse IS NULL AND reasonCode IS NULL) OR latencyMs IS NOT NULL),  -- a finished turn records its latency
  CONSTRAINT CK_encounterTranscript_reply CHECK (aiResponse IS NULL OR modelName IS NOT NULL),                        -- a reply always carries its usage
  CONSTRAINT CK_encounterTranscript_usage CHECK ((modelName IS NULL AND inputTokens IS NULL AND outputTokens IS NULL AND inputCostUsd IS NULL AND outputCostUsd IS NULL) OR (modelName IS NOT NULL AND inputTokens IS NOT NULL AND outputTokens IS NOT NULL AND inputCostUsd IS NOT NULL AND outputCostUsd IS NOT NULL)),  -- the model was called (all five set) or not (none set)
  CONSTRAINT CK_encounterTranscript_json CHECK (ISJSON(aiResponse) = 1),
  CONSTRAINT CK_encounterTranscript_history CHECK (ISJSON(historyEncounterIds) = 1),
  CONSTRAINT CK_encounterTranscript_historySummaries CHECK (ISJSON(historySummaryIds) = 1)
);
CREATE INDEX IX_encounterTranscript_encounter ON AI.encounterTranscript (encounterID) INCLUDE (createdDate, createdBy, modelName, inputTokens, outputTokens, inputCostUsd, outputCostUsd);  -- history, totals and cost reports never touch the text
```

| Column | Type | Meaning |
| --- | --- | --- |
| `transcriptID` | `INT IDENTITY NOT NULL` | turn id; ascending = conversation order |
| `encounterID` | `INT NOT NULL` | Encounter.encounter.encounterID = the conversation id; logical reference, checked by the procedure (§6) |
| `templeteId` | `INT NOT NULL` | Encounter.encounter.templeteId when the turn started (its spelling); per-template reporting |
| `clinicianQuery` | `NVARCHAR(MAX) NOT NULL` | text exactly as the clinician sent it |
| `aiResponse` | `NVARCHAR(MAX) NULL` | what the clinician was shown (§8); NULL while running or when the turn failed |
| `reasonCode` | `VARCHAR(40) NULL` | why there is no reply: the agent's REASON_CODES, e.g. INJECTION_BLOCKED, PROMPT_PLACEHOLDER_UNFILLED, MODEL_CALL_FAILED |
| `promptId` | `INT NULL` | AI.prompt.promptId (no FK: AI.prompt has no primary key); NULL if blocked before the prompt loaded |
| `promptHash` | `VARCHAR(64) NULL` | SHA-256 of AI.prompt.prompt as read, before placeholders: the wording version, since AI.prompt is edited in place |
| `patientSummaryID` | `INT NULL` | AI.patientSummary version given as patient context; NULL = none (cold start, or summaries switched off) |
| `clinicianSummaryID` | `INT NULL` | AI.clinicianSummary version given as clinician context; NULL = none |
| `historyEncounterIds` | `NVARCHAR(400) NULL` | JSON array of prior encounterIDs the history tool loaded; NULL if it wasn't called (Epic 7) |
| `historySummaryIds` | `NVARCHAR(400) NULL` | JSON array of the AI.encounterSummary.summaryID versions those encounters were read at; pins what the AI was actually shown, since a summary can be regenerated (§9 rule 4) |
| `modelName` | `VARCHAR(50) NULL` | model version the provider reports, e.g. gpt-4.1-2025-04-14; NULL if the model was never called |
| `inputTokens` | `INT NULL` | summed over every model call in the turn, cached tokens included |
| `outputTokens` | `INT NULL` | summed over every model call in the turn |
| `inputCostUsd` | `DECIMAL(12,6) NULL` | at that day's price; cached tokens at the cached price |
| `outputCostUsd` | `DECIMAL(12,6) NULL` | at that day's price |
| `latencyMs` | `INT NULL` | the clinician's wait, arrival → reply or refusal; NULL while running |
| `traceId` | `VARCHAR(36) NULL` | LangSmith run id: feedback is posted against it, and the trace ↔ audit check joins on it |
| `createdBy` | `INT NOT NULL` | Account.users.userId of the sender |
| `createdDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when the request arrived |

**Sample row** — from the worked example in §3.1 of the design doc:

```
-- a turn that succeeded
transcriptID        9001
encounterID         50123
templeteId          17
clinicianQuery      '82 year old, BP 140/90, weight 82 kg'
aiResponse          '{ "message": "Filled weight and BP.", "fields": [ ... ] }'
reasonCode          NULL
promptId            12                  promptHash  'a91f0c...'
patientSummaryID    6610                -- the versions in use when the turn started
clinicianSummaryID  7788
historyEncounterIds '[49870, 50011]'    -- prior encounters the history tool loaded
historySummaryIds   '[6840, 6902]'      -- the summary version each was read at
modelName           'gpt-4.1-2025-04-14'
inputTokens         3912                outputTokens   1420
inputCostUsd        0.007824            outputCostUsd  0.011360
latencyMs           4180                createdBy      882

-- a turn that failed: still a row, still auditable
transcriptID        9003
clinicianQuery      'temp is Fahrenheit'
aiResponse          NULL
reasonCode          'MODEL_CALL_FAILED'
modelName           NULL                -- nothing was returned to bill
inputTokens         NULL                outputTokens   NULL
latencyMs           30000
```

---

## 5. `AI.encounterFieldReview`

**One row is** one clinician decision on one field, beside what the AI showed.

The procedure copies the AI snapshot from the turn’s own JSON, so the client cannot alter what was shown.

```sql
CREATE TABLE AI.encounterFieldReview (                                          -- one clinician decision on one field, beside what the AI showed; accepts included
  transcriptID      INT            NOT NULL,                                    -- the turn whose suggestion was on screen
  sectionID         INT            NOT NULL,                                    -- same key as Encounter.encounterData
  fieldID           INT            NOT NULL,                                    -- same key as Encounter.encounterData
  aiValue           NVARCHAR(MAX)  NULL,                                        -- value the AI showed; NULL = it showed none (ABSENT or ABSTAINED), so the decision is ADDED
  aiUnit            NVARCHAR(20)   NULL,                                        -- unit the AI showed; NULL for unitless fields
  aiConfidence      VARCHAR(6)     NULL,                                        -- HIGH | MEDIUM | LOW as shown; NULL when the AI returned ABSENT
  aiRemark          NVARCHAR(500)  NULL,                                        -- the AI's note on where and how it got the value, or why it abstained
  aiEvidence        NVARCHAR(500)  NULL,                                        -- the clinician's own words the value came from, verbatim: the ground truth shown on the card
  isEvidenceDeleted BIT            NOT NULL DEFAULT 0,                          -- 1 = the clinician struck the AI's evidence as wrong or not the source; aiEvidence is kept as shown
  finalValue        NVARCHAR(MAX)  NULL,                                        -- value the clinician confirmed; NULL = rejected
  finalUnit         NVARCHAR(20)   NULL,                                        -- unit the clinician confirmed; the value/unit split exists nowhere else (encounterData.Value is one string)
  action            AS CAST(CASE WHEN aiValue IS NULL THEN 'ADDED' WHEN finalValue IS NULL THEN 'REJECTED' WHEN finalValue = aiValue AND ISNULL(finalUnit, '') = ISNULL(aiUnit, '') THEN 'ACCEPTED' ELSE 'EDITED' END AS VARCHAR(8)),  -- computed: never disagrees with the values
  isValueCorrect    AS CAST(CASE WHEN finalValue = aiValue THEN 1 ELSE 0 END AS BIT),                         -- computed: 1 = value right
  isUnitCorrect     AS CAST(CASE WHEN ISNULL(finalUnit, '') = ISNULL(aiUnit, '') THEN 1 ELSE 0 END AS BIT),    -- computed: 1 = unit right
  isDeleted         BIT            NOT NULL DEFAULT 0,                          -- 1 = decision withdrawn (undo); excluded from every report; re-deciding sets it back to 0
  reviewedBy        INT            NOT NULL,                                    -- Account.users.userId of the latest decision, undo or evidence strike
  createdDate       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),           -- when the field was first decided
  updatedDate       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),           -- the latest decision, undo or evidence strike; equals createdDate until then
  CONSTRAINT PK_encounterFieldReview PRIMARY KEY (transcriptID, sectionID, fieldID),  -- one decision per field and turn; a change of mind updates it
  CONSTRAINT FK_encounterFieldReview_transcript FOREIGN KEY (transcriptID) REFERENCES AI.encounterTranscript (transcriptID),
  CONSTRAINT CK_encounterFieldReview_confidence CHECK (aiConfidence IN ('HIGH', 'MEDIUM', 'LOW')),
  CONSTRAINT CK_encounterFieldReview_aiUnit CHECK (aiValue IS NOT NULL OR aiUnit IS NULL),        -- no unit without a value
  CONSTRAINT CK_encounterFieldReview_decision CHECK (aiValue IS NOT NULL OR finalValue IS NOT NULL),  -- something was suggested or added
  CONSTRAINT CK_encounterFieldReview_rejected CHECK (finalValue IS NOT NULL OR finalUnit IS NULL),  -- a rejected field has no unit
  CONSTRAINT CK_encounterFieldReview_evidenceDeleted CHECK (isEvidenceDeleted = 0 OR aiEvidence IS NOT NULL),  -- only evidence that was shown can be struck
  CONSTRAINT CK_encounterFieldReview_dates CHECK (updatedDate >= createdDate)
);
CREATE INDEX IX_encounterFieldReview_reviewer ON AI.encounterFieldReview (reviewedBy, updatedDate);  -- clinician-level reports and the clinician summary
```

| Column | Type | Meaning |
| --- | --- | --- |
| `transcriptID` | `INT NOT NULL` | the turn whose suggestion was on screen |
| `sectionID` | `INT NOT NULL` | same key as Encounter.encounterData |
| `fieldID` | `INT NOT NULL` | same key as Encounter.encounterData |
| `aiValue` | `NVARCHAR(MAX) NULL` | value the AI showed; NULL = it showed none (ABSENT or ABSTAINED), so the decision is ADDED |
| `aiUnit` | `NVARCHAR(20) NULL` | unit the AI showed; NULL for unitless fields |
| `aiConfidence` | `VARCHAR(6) NULL` | HIGH \| MEDIUM \| LOW as shown; NULL when the AI returned ABSENT |
| `aiRemark` | `NVARCHAR(500) NULL` | the AI's note on where and how it got the value, or why it abstained |
| `aiEvidence` | `NVARCHAR(500) NULL` | the clinician's own words the value came from, verbatim: the ground truth shown on the card |
| `isEvidenceDeleted` | `BIT NOT NULL DEFAULT 0` | 1 = the clinician struck the AI's evidence as wrong or not the source; aiEvidence is kept as shown |
| `finalValue` | `NVARCHAR(MAX) NULL` | value the clinician confirmed; NULL = rejected |
| `finalUnit` | `NVARCHAR(20) NULL` | unit the clinician confirmed; the value/unit split exists nowhere else (encounterData.Value is one string) |
| `action` | `AS CAST(CASE WHEN aiValue IS NULL THEN 'ADDED' WHEN finalValue IS NULL THEN 'REJECTED' WHEN finalValue = aiValue AND ISNULL(finalUnit, '') = ISNULL(aiUnit, '') THEN 'ACCEPTED' ELSE 'EDITED' END AS VARCHAR(8))` | computed: never disagrees with the values |
| `isValueCorrect` | `AS CAST(CASE WHEN finalValue = aiValue THEN 1 ELSE 0 END AS BIT)` | computed: 1 = value right |
| `isUnitCorrect` | `AS CAST(CASE WHEN ISNULL(finalUnit, '') = ISNULL(aiUnit, '') THEN 1 ELSE 0 END AS BIT)` | computed: 1 = unit right |
| `isDeleted` | `BIT NOT NULL DEFAULT 0` | 1 = decision withdrawn (undo); excluded from every report; re-deciding sets it back to 0 |
| `reviewedBy` | `INT NOT NULL` | Account.users.userId of the latest decision, undo or evidence strike |
| `createdDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | when the field was first decided |
| `updatedDate` | `DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()` | the latest decision, undo or evidence strike; equals createdDate until then |

**Sample row** — from the worked example in §3.1 of the design doc:

```
-- the AI suggested a BP; the clinician edited it and struck the quote as not the real source
transcriptID      9001
sectionID         2                     fieldID  31
aiValue           '140/90'              aiUnit   'mmHg'    aiConfidence 'HIGH'
aiRemark          'Blood pressure stated in the latest message.'
aiEvidence        'BP 140/90'           -- kept exactly as shown, even though struck
isEvidenceDeleted 1
finalValue        '140/88'              finalUnit 'mmHg'
action            'EDITED'              -- computed
isValueCorrect    0                     -- computed
isUnitCorrect     1                     -- computed
isDeleted         0
reviewedBy        882
```

---

## 6. `AI.encounterUsage` (view)

**One row is** one encounter’s AI totals, computed from the turns and never stored.

```sql
CREATE VIEW AI.encounterUsage AS                                                -- per-encounter totals, computed from the turns, never stored
SELECT encounterID, COUNT(*) AS turns, SUM(inputTokens) AS inputTokens, SUM(outputTokens) AS outputTokens,
       SUM(inputCostUsd) AS inputCostUsd, SUM(outputCostUsd) AS outputCostUsd, MIN(createdDate) AS firstTurnDate, MAX(createdDate) AS lastTurnDate
FROM AI.encounterTranscript GROUP BY encounterID;
```

---

## Indexes

Easy to miss, and each one is load-bearing:

```sql
CREATE UNIQUE INDEX UX_encounterSummary_active ON AI.encounterSummary (encounterID) WHERE isActive = 1;  -- at most one version in use per encounter; the read is one seek
CREATE UNIQUE INDEX UX_patientSummary_active ON AI.patientSummary (patientID) WHERE isActive = 1;  -- at most one version in use per patient; the read is one seek
CREATE UNIQUE INDEX UX_clinicianSummary_active ON AI.clinicianSummary (clinicianID) WHERE isActive = 1;  -- at most one version in use per clinician; the read is one seek
CREATE INDEX IX_encounterTranscript_encounter ON AI.encounterTranscript (encounterID) INCLUDE (createdDate, createdBy, modelName, inputTokens, outputTokens, inputCostUsd, outputCostUsd);  -- history, totals and cost reports never touch the text
CREATE INDEX IX_encounterFieldReview_reviewer ON AI.encounterFieldReview (reviewedBy, updatedDate);  -- clinician-level reports and the clinician summary
```
