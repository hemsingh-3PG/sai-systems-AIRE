/* =====================================================================================================
   PacEHR AI — Golden Dataset extraction queries (Azure SQL / SQL Server 2017+)
   -----------------------------------------------------------------------------------------------------
   What a golden record is:
       INPUT     = what the clinician said/wrote        -> Patient.roundingNotes.noteDetails
                                                         + Patient.AmbientDetails (ambient transcript lines)
                                                         + AI.EncounterTranscript.clinicianQuery (new agent)
       EXPECTED  = what the clinician signed            -> Encounter.encounterData (final field values)
                                                         + Encounter.encounterDiagnosis / encounterCPT
       BASELINE  = what the AI suggested (optional)     -> Log.AILogs.resp_content (legacy, pre-edit)
                                                         + AI.EncounterFieldReview (new agent, per-field verdict)

   Data lineage (verified in code):
       Add Rounding Note (dashboard)  -> Patient.roundingNotes (notesId, noteDetails, templeteId)
       Ambient listening              -> Patient.AmbientDetails (notesId = roundingNotes.notesId, sequenceOrder)
       "Save & Create Encounter"      -> usp_addEditEncounter sets roundingNotes.encounterId + noteStatus='inActive'
       Fill fields (manual / AI)      -> Encounter.encounterData (encounterID, sectionID, fieldID, Value)
       Legacy AI call (frontend)      -> Log.AILogs (user_content = note, PHI-masked; resp_content = AI JSON)
       Sign & close                   -> Encounter.encounter.verifiedFlag = 1, encounterSignedDate
                                         usp_updateVerifyFlag sets roundingNotes.isVerified = 1
       Encounter.encounter.verifiedFlag: 0 = Open, 1 = Closed/Signed, 2 = Review (pending co-sign)

   !! PHI: noteDetails, AmbientDetails.ambientNotes and encounterData.Value are NOT masked.
      Run in an environment approved for PHI, and de-identify before the dataset leaves it.
      These queries never select patient names; demographics are reduced to age band + gender.

   Run the whole file top-to-bottom in ONE batch (no GO) — later steps read the #temp tables.
   ===================================================================================================== */

SET NOCOUNT ON;

-- ---------------------------------------------------------------------------------------------------
-- PARAMETERS — tune these
-- ---------------------------------------------------------------------------------------------------
DECLARE @FromSignedDate   DATETIME = '2026-01-01';
DECLARE @ToSignedDate     DATETIME = '2026-10-01';
DECLARE @AccountIds       VARCHAR(500) = NULL;   -- e.g. '12,45,67'; NULL = all accounts
DECLARE @PerStratum       INT = 10;              -- encounters sampled per (template x complexity) stratum
DECLARE @TargetTotal      INT = 300;             -- design doc §4.4: 150–300 encounters
DECLARE @MinNoteChars     INT = 200;             -- drop notes too short to extract anything from
DECLARE @RequireInput     BIT = 1;               -- 1 = encounter must have a rounding note or ambient transcript
DECLARE @ExcludeAmended   BIT = 1;               -- 1 = drop encounters with Encounter.encounterAmendment rows
DECLARE @OnlyAIFields     BIT = 0;               -- 1 = expected fields limited to Template.fields.allowAISummary = 1
DECLARE @SampleSeed       INT = 20261013;        -- fixed seed -> reproducible sample (NEWID() is not)


/* =====================================================================================================
   STEP 0 — PROFILING: what source data actually exists in this environment?
   Run these first; they decide which input source(s) the golden set can use.
   ===================================================================================================== */

-- 0.1 Encounter status distribution in the window
SELECT  CASE e.verifiedFlag WHEN 1 THEN '1-Closed/Signed' WHEN 2 THEN '2-Review (co-sign)'
                            WHEN 0 THEN '0-Open' ELSE 'NULL' END AS status,
        COUNT(*) AS encounters
FROM    Encounter.encounter e WITH (NOLOCK)
WHERE   ISNULL(e.isDeleted, 0) = 0 AND e.isActive = 1
  AND   e.createdDate >= @FromSignedDate AND e.createdDate < @ToSignedDate
GROUP BY e.verifiedFlag
ORDER BY status;

-- 0.2 How many SIGNED encounters have each kind of clinician input / AI trace
SELECT  COUNT(*)                                                               AS signed_encounters,
        SUM(CASE WHEN rn.encounterId IS NOT NULL THEN 1 ELSE 0 END)            AS with_rounding_note,
        SUM(CASE WHEN amb.notesId   IS NOT NULL THEN 1 ELSE 0 END)             AS with_ambient_transcript,
        SUM(CASE WHEN ail.encounterId IS NOT NULL THEN 1 ELSE 0 END)           AS with_legacy_ai_log
FROM    Encounter.encounter e WITH (NOLOCK)
OUTER APPLY (SELECT TOP 1 r.encounterId, r.notesId FROM Patient.roundingNotes r WITH (NOLOCK)
             WHERE r.encounterId = e.encounterID AND r.isDeleted = 0) rn
OUTER APPLY (SELECT TOP 1 a.notesId FROM Patient.AmbientDetails a WITH (NOLOCK)
             WHERE a.notesId = rn.notesId AND a.isDeleted = 0) amb
OUTER APPLY (SELECT TOP 1 l.encounterId FROM Log.AILogs l WITH (NOLOCK)
             WHERE l.encounterId = e.encounterID) ail
WHERE   e.verifiedFlag = 1 AND ISNULL(e.isDeleted, 0) = 0 AND e.isActive = 1
  AND   e.encounterSignedDate >= @FromSignedDate AND e.encounterSignedDate < @ToSignedDate;

-- 0.2b New encounter agent (AI schema, PacEHR_AI migrations 0001–0006) — skipped where not deployed
IF OBJECT_ID(N'AI.EncounterTranscript') IS NOT NULL
    SELECT  COUNT(DISTINCT t.encounterID)                                   AS encounters_with_ai_turns,
            COUNT(DISTINCT CASE WHEN e.verifiedFlag = 1 THEN t.encounterID END) AS signed_with_ai_turns,
            COUNT(*)                                                        AS turns,
            SUM(CASE WHEN t.aiResponse IS NOT NULL THEN 1 ELSE 0 END)       AS replied_turns,
            (SELECT COUNT(*) FROM AI.EncounterFieldReview WITH (NOLOCK) WHERE isDeleted = 0) AS field_reviews
    FROM    AI.EncounterTranscript t WITH (NOLOCK)
    JOIN    Encounter.encounter e WITH (NOLOCK) ON e.encounterID = t.encounterID;

-- 0.3 Legacy AI logs not tied to an encounter (AI run before the encounter was saved -> encounterId 0/NULL)
SELECT  SUM(CASE WHEN ISNULL(encounterId, 0) = 0 THEN 1 ELSE 0 END) AS logs_without_encounter,
        SUM(CASE WHEN ISNULL(encounterId, 0) > 0 THEN 1 ELSE 0 END)  AS logs_with_encounter,
        SUM(CASE WHEN ISJSON(resp_content) = 1 THEN 1 ELSE 0 END)    AS logs_with_valid_json_response
FROM    Log.AILogs WITH (NOLOCK)
WHERE   createdDate >= @FromSignedDate AND createdDate < @ToSignedDate;

-- 0.4 Field types in use — decide which types belong in the golden set (free text vs checkbox vs dropdown…)
SELECT  f.fieldType, COUNT(DISTINCT f.fieldID) AS fields, SUM(CASE WHEN f.allowAISummary = 1 THEN 1 ELSE 0 END) AS ai_enabled_fields
FROM    Template.fields f WITH (NOLOCK)
WHERE   f.isActive = 1
GROUP BY f.fieldType
ORDER BY fields DESC;

-- 0.5 Template volume in the window (for stratification) incl. ambient/AI flags and specialty IDs
SELECT  t.encounterTempleteID, t.encounterTempleteName, t.speciality, t.ambientFlag, t.promptId,
        COUNT(*) AS signed_encounters
FROM    Encounter.encounter e WITH (NOLOCK)
JOIN    Template.encounterTempletes t WITH (NOLOCK) ON t.encounterTempleteID = e.templeteId
WHERE   e.verifiedFlag = 1 AND ISNULL(e.isDeleted, 0) = 0 AND e.isActive = 1
  AND   e.encounterSignedDate >= @FromSignedDate AND e.encounterSignedDate < @ToSignedDate
GROUP BY t.encounterTempleteID, t.encounterTempleteName, t.speciality, t.ambientFlag, t.promptId
ORDER BY signed_encounters DESC;


/* =====================================================================================================
   STEP 1 — CANDIDATE POOL: signed encounters + availability / complexity features
   ===================================================================================================== */
IF OBJECT_ID('tempdb..#cand') IS NOT NULL DROP TABLE #cand;

;WITH ed AS (   -- latest value per field; encounterData has no PK, so de-duplicate defensively
    SELECT d.encounterID, d.sectionID, d.fieldID, d.Value,
           ROW_NUMBER() OVER (PARTITION BY d.encounterID, d.sectionID, d.fieldID ORDER BY d.createdDate DESC) AS rn
    FROM   Encounter.encounterData d WITH (NOLOCK)
    JOIN   Encounter.encounter e WITH (NOLOCK) ON e.encounterID = d.encounterID
    WHERE  e.verifiedFlag = 1
      AND  e.encounterSignedDate >= @FromSignedDate AND e.encounterSignedDate < @ToSignedDate
)
SELECT  e.encounterID,
        e.patientID,
        e.accountID,
        e.facilityID,
        e.providerID,
        e.coSingProviderId,
        e.templeteId,
        t.encounterTempleteName,
        t.speciality                                               AS templateSpecialityIds,
        TRY_CONVERT(DATE, e.DOS, 101)                              AS dos,
        e.encounterSignedDate,
        e.eventTypeId,
        e.POS,
        rnAgg.notesIds,
        ISNULL(rnAgg.noteChars, 0)                                 AS noteChars,
        ISNULL(amb.ambientLines, 0)                                AS ambientLines,
        ISNULL(amb.ambientChars, 0)                                AS ambientChars,
        ISNULL(fld.filledFields, 0)                                AS filledFields,
        ISNULL(dx.dxCount, 0)                                      AS dxCount,
        ISNULL(cpt.cptCount, 0)                                    AS cptCount,
        CASE WHEN ail.n > 0 THEN 1 ELSE 0 END                      AS hasLegacyAILog,
        CASE WHEN EXISTS (SELECT 1 FROM Encounter.encounterAddendums x WITH (NOLOCK) WHERE x.encounterID = e.encounterID) THEN 1 ELSE 0 END AS hasAddendum,
        CASE WHEN EXISTS (SELECT 1 FROM Encounter.encounterAmendment x WITH (NOLOCK) WHERE x.encounterID = e.encounterID) THEN 1 ELSE 0 END AS hasAmendment,
        CASE WHEN ISNULL(e.coSingProviderId, 0) > 0 THEN 1 ELSE 0 END AS isCoSigned,
        CAST(NULL AS VARCHAR(6))                                   AS complexity
INTO    #cand
FROM    Encounter.encounter e WITH (NOLOCK)
JOIN    Template.encounterTempletes t WITH (NOLOCK) ON t.encounterTempleteID = e.templeteId
OUTER APPLY (SELECT STRING_AGG(CAST(r.notesId AS VARCHAR(20)), ',') AS notesIds,
                    SUM(LEN(ISNULL(r.noteDetails, N'')))           AS noteChars
             FROM   Patient.roundingNotes r WITH (NOLOCK)
             WHERE  r.encounterId = e.encounterID AND r.isDeleted = 0) rnAgg
OUTER APPLY (SELECT COUNT(*) AS ambientLines, SUM(LEN(a.ambientNotes)) AS ambientChars
             FROM   Patient.roundingNotes r WITH (NOLOCK)
             JOIN   Patient.AmbientDetails a WITH (NOLOCK) ON a.notesId = r.notesId AND a.isDeleted = 0
             WHERE  r.encounterId = e.encounterID AND r.isDeleted = 0) amb
OUTER APPLY (SELECT COUNT(*) AS filledFields FROM ed
             WHERE  ed.encounterID = e.encounterID AND ed.rn = 1 AND NULLIF(LTRIM(RTRIM(ed.Value)), N'') IS NOT NULL) fld
OUTER APPLY (SELECT COUNT(*) AS dxCount FROM Encounter.encounterDiagnosis x WITH (NOLOCK)
             WHERE  x.encounterID = e.encounterID AND ISNULL(x.IsDeleted, 0) = 0) dx
OUTER APPLY (SELECT COUNT(*) AS cptCount FROM Encounter.encounterCPT x WITH (NOLOCK)
             WHERE  x.encounterId = e.encounterID) cpt
OUTER APPLY (SELECT COUNT(*) AS n FROM Log.AILogs l WITH (NOLOCK) WHERE l.encounterId = e.encounterID) ail
WHERE   e.verifiedFlag = 1                                   -- signed & closed only
  AND   e.isActive = 1 AND ISNULL(e.isDeleted, 0) = 0
  AND   e.encounterSignedDate >= @FromSignedDate AND e.encounterSignedDate < @ToSignedDate
  AND   (@AccountIds IS NULL OR e.accountID IN (SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@AccountIds, ',')));

-- Remove test/demo accounts (adjust the patterns to your naming)
DELETE c FROM #cand c
JOIN   Account.accounts a WITH (NOLOCK) ON a.accountID = c.accountID
WHERE  a.accountName LIKE '%test%' OR a.accountName LIKE '%demo%' OR a.accountName LIKE '%QA%' OR a.accountName LIKE '%training%';

-- Input / quality gates
DELETE FROM #cand WHERE @RequireInput = 1 AND noteChars + ambientChars < @MinNoteChars;
DELETE FROM #cand WHERE @ExcludeAmended = 1 AND hasAmendment = 1;
DELETE FROM #cand WHERE filledFields = 0;

-- Complexity band (tune thresholds after looking at the distribution query below)
UPDATE #cand
SET    complexity = CASE WHEN filledFields >= 40 OR dxCount >= 8 OR noteChars + ambientChars >= 6000 THEN 'HIGH'
                         WHEN filledFields <  15 AND dxCount <= 3 AND noteChars + ambientChars < 1500 THEN 'LOW'
                         ELSE 'MEDIUM' END;

-- 1.1 Pool distribution by stratum
SELECT encounterTempleteName, complexity, COUNT(*) AS candidates,
       SUM(CASE WHEN ambientLines > 0 THEN 1 ELSE 0 END) AS withAmbient,
       SUM(hasLegacyAILog) AS withLegacyAI,
       AVG(filledFields) AS avgFields, AVG(dxCount) AS avgDx
FROM   #cand
GROUP BY encounterTempleteName, complexity
ORDER BY encounterTempleteName, complexity;


/* =====================================================================================================
   STEP 2 — STRATIFIED, REPRODUCIBLE SAMPLE  (template x complexity, spread across providers)
   ===================================================================================================== */
IF OBJECT_ID('tempdb..#golden') IS NOT NULL DROP TABLE #golden;

;WITH ranked AS (
    SELECT c.*,
           -- one provider shouldn't dominate a stratum: rank within provider first
           ROW_NUMBER() OVER (PARTITION BY c.templeteId, c.complexity, c.providerID
                              ORDER BY CHECKSUM(c.encounterID * @SampleSeed)) AS rnProvider
    FROM   #cand c
), stratified AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY r.templeteId, r.complexity
                              ORDER BY r.rnProvider, CHECKSUM(r.encounterID * @SampleSeed)) AS rnStratum
    FROM   ranked r
)
SELECT TOP (@TargetTotal) s.*
INTO   #golden
FROM   stratified s
WHERE  s.rnStratum <= @PerStratum
ORDER BY s.rnStratum, s.templeteId, s.complexity;   -- round-robin across strata if TargetTotal cuts in

-- 2.1 Sample manifest (keep this file — it IS the golden-set definition)
SELECT g.encounterID, g.templeteId, g.encounterTempleteName, g.templateSpecialityIds, g.complexity,
       g.providerID, g.accountID, g.dos, g.encounterSignedDate, g.noteChars, g.ambientLines,
       g.filledFields, g.dxCount, g.cptCount, g.hasLegacyAILog, g.hasAddendum, g.isCoSigned
FROM   #golden g
ORDER BY g.encounterTempleteName, g.complexity, g.encounterID;


/* =====================================================================================================
   STEP 3 — INPUT: clinician note + ambient transcript per golden encounter
   ===================================================================================================== */

-- 3.1 One row per encounter: the full text the AI would be given
SELECT  g.encounterID,
        g.templeteId,
        -- rounding note; the UI stores newlines as <br>
        (SELECT STRING_AGG(CAST(REPLACE(REPLACE(r.noteDetails, '<br>', CHAR(10)), '<br/>', CHAR(10)) AS NVARCHAR(MAX)),
                           CHAR(10) + N'---' + CHAR(10)) WITHIN GROUP (ORDER BY r.notesId)
         FROM   Patient.roundingNotes r WITH (NOLOCK)
         WHERE  r.encounterId = g.encounterID AND r.isDeleted = 0)                        AS clinicianNote,
        -- ambient transcript in spoken order, speaker-labelled
        (SELECT STRING_AGG(CAST(ISNULL(a.speakerIdentifier, N'Speaker') + N': ' + a.ambientNotes AS NVARCHAR(MAX)), CHAR(10))
                WITHIN GROUP (ORDER BY r.notesId, a.sequenceOrder, a.createdDate)
         FROM   Patient.roundingNotes r WITH (NOLOCK)
         JOIN   Patient.AmbientDetails a WITH (NOLOCK) ON a.notesId = r.notesId AND a.isDeleted = 0
         WHERE  r.encounterId = g.encounterID AND r.isDeleted = 0)                        AS ambientTranscript,
        -- context the model also receives (no identifiers)
        DATEDIFF(YEAR, p.DOB, g.dos) / 10 * 10                                           AS ageBand,
        p.gender
FROM    #golden g
LEFT JOIN Patient.patients p WITH (NOLOCK) ON p.patientID = g.patientID
ORDER BY g.encounterID;

-- 3.2 Ambient transcript as individual turns (for diarisation / turn-level tests)
SELECT  g.encounterID, r.notesId, a.ambientId, a.sequenceOrder, a.speakerIdentifier, a.ambientNotes, a.createdDate
FROM    #golden g
JOIN    Patient.roundingNotes r WITH (NOLOCK) ON r.encounterId = g.encounterID AND r.isDeleted = 0
JOIN    Patient.AmbientDetails a WITH (NOLOCK) ON a.notesId = r.notesId AND a.isDeleted = 0
ORDER BY g.encounterID, r.notesId, a.sequenceOrder, a.createdDate;

-- 3.3 Legacy AI input as it was actually sent (PHI-masked by the frontend before logging).
--     Extraction calls only — the "human-language commands" calls are JSON edits, not extraction.
SELECT  g.encounterID, l.Id AS aiLogId, l.createdDate, l.user_content AS noteSentToAI, l.system_content AS systemPrompt
FROM    #golden g
CROSS APPLY (SELECT TOP 1 * FROM Log.AILogs x WITH (NOLOCK)
             WHERE  x.encounterId = g.encounterID
               AND  x.system_content NOT LIKE N'You are provided with a JSON object and a set of human-language commands%'
             ORDER BY x.createdDate) l
ORDER BY g.encounterID;


/* =====================================================================================================
   STEP 4 — EXPECTED OUTPUT (ground truth): the signed values, field by field
   ===================================================================================================== */
IF OBJECT_ID('tempdb..#expected') IS NOT NULL DROP TABLE #expected;

;WITH ed AS (
    SELECT d.encounterID, d.sectionID, d.fieldID, d.Value, d.byUser, d.createdDate,
           ROW_NUMBER() OVER (PARTITION BY d.encounterID, d.sectionID, d.fieldID ORDER BY d.createdDate DESC) AS rn
    FROM   Encounter.encounterData d WITH (NOLOCK)
    WHERE  d.encounterID IN (SELECT encounterID FROM #golden)
)
SELECT  g.encounterID,
        g.templeteId,
        ed.sectionID,
        s.sectionName,
        ed.fieldID,
        f.fieldName,
        f.displayName,
        f.fieldType,
        f.allowAISummary,
        m.orderby,
        ISNULL(m.isSectionCarryForward, 0) | ISNULL(m.isFieldCarryForward, 0)    AS isCarryForward,
        CASE WHEN ed.Value = f.defaultValue THEN 1 ELSE 0 END                    AS equalsDefault,
        ed.Value                                                                 AS expectedValue,
        ed.byUser                                                                AS enteredBy,
        ed.createdDate                                                           AS enteredDate
INTO    #expected
FROM    #golden g
JOIN    ed ON ed.encounterID = g.encounterID AND ed.rn = 1
JOIN    Template.section s WITH (NOLOCK) ON s.sectionID = ed.sectionID
JOIN    Template.fields  f WITH (NOLOCK) ON f.fieldID   = ed.fieldID
OUTER APPLY (SELECT TOP 1 etm.orderby, etm.isSectionCarryForward, etm.isFieldCarryForward
             FROM   Encounter.encounterTempletMapping etm WITH (NOLOCK)
             WHERE  etm.templetID = g.templeteId AND etm.sectionID = ed.sectionID AND etm.fieldID = ed.fieldID
             ORDER BY etm.isActive DESC, etm.ID DESC) m
WHERE   NULLIF(LTRIM(RTRIM(ed.Value)), N'') IS NOT NULL
  AND   (@OnlyAIFields = 0 OR f.allowAISummary = 1);

-- 4.1 Ground-truth field values.
--     isCarryForward = 1 / equalsDefault = 1 rows were NOT said by the clinician in this note:
--     keep them out of extraction scoring (or score them separately) — otherwise the model is
--     penalised for not inventing values, which is exactly what it must not do.
SELECT * FROM #expected ORDER BY encounterID, orderby, sectionID, fieldID;

-- 4.2 Expected diagnoses (ICD-10 + SNOMED, in clinician order)
SELECT  d.encounterID, d.orderNo, d.code AS icd10, d.snomed, d.description, d.assessment, d.billable, d.hcc
FROM    Encounter.encounterDiagnosis d WITH (NOLOCK)
WHERE   d.encounterID IN (SELECT encounterID FROM #golden) AND ISNULL(d.IsDeleted, 0) = 0
ORDER BY d.encounterID, d.orderNo;

-- 4.3 Expected CPT / billing
SELECT  c.encounterId, c.orderNo, c.code AS cpt, c.modifier, c.unit, c.description, c.billable, c.isAddendum
FROM    Encounter.encounterCPT c WITH (NOLOCK)
WHERE   c.encounterId IN (SELECT encounterID FROM #golden)
ORDER BY c.encounterId, c.orderNo;

-- 4.4 Field universe per template (fields the AI COULD fill — needed to score ABSENT/abstain correctly)
SELECT  etm.templetID, etm.sectionID, s.sectionName, etm.fieldID, f.fieldName, f.displayName, f.fieldType,
        f.allowAISummary, f.aiSummaryPrompt, etm.orderby
FROM    Encounter.encounterTempletMapping etm WITH (NOLOCK)
JOIN    Template.section s WITH (NOLOCK) ON s.sectionID = etm.sectionID
JOIN    Template.fields  f WITH (NOLOCK) ON f.fieldID   = etm.fieldID
WHERE   etm.isActive = 1 AND etm.templetID IN (SELECT DISTINCT templeteId FROM #golden)
ORDER BY etm.templetID, etm.orderby;


/* =====================================================================================================
   STEP 5 — BASELINE: what the AI suggested vs what was signed (post-edit corpus)
   ===================================================================================================== */

-- 5.1 Legacy AI (Log.AILogs). resp_content is JSON { "<Section>": { "<Field>": "<value>" } }.
--     Keys are section/field labels, so they are matched by name — check unmatched rows (aiKeyMatched = 0).
;WITH firstLog AS (
    SELECT g.encounterID, g.templeteId, l.Id AS aiLogId, l.resp_content
    FROM   #golden g
    CROSS APPLY (SELECT TOP 1 * FROM Log.AILogs x WITH (NOLOCK)
                 WHERE  x.encounterId = g.encounterID
                   AND  x.system_content NOT LIKE N'You are provided with a JSON object and a set of human-language commands%'
                   AND  ISJSON(x.resp_content) = 1
                 ORDER BY x.createdDate) l
), aiFlat AS (
    SELECT fl.encounterID, fl.aiLogId, sec.[key] AS aiSection, fld.[key] AS aiField, fld.[value] AS aiValue
    FROM   firstLog fl
    CROSS APPLY OPENJSON(fl.resp_content) sec
    CROSS APPLY OPENJSON(CASE WHEN sec.[type] = 5 THEN sec.[value] ELSE N'{}' END) fld   -- type 5 = object
)
SELECT  COALESCE(a.encounterID, x.encounterID)                     AS encounterID,
        a.aiLogId,
        COALESCE(x.sectionName, a.aiSection)                       AS sectionName,
        COALESCE(x.displayName, a.aiField)                         AS fieldName,
        a.aiValue,
        x.expectedValue,
        CASE WHEN a.aiField IS NULL                    THEN 'MISSED_BY_AI'
             WHEN x.fieldID IS NULL                    THEN 'AI_ONLY (clinician removed / unmatched key)'
             WHEN LTRIM(RTRIM(a.aiValue)) = LTRIM(RTRIM(x.expectedValue)) THEN 'ACCEPTED'
             ELSE 'EDITED' END                                     AS outcome,
        CASE WHEN x.fieldID IS NOT NULL AND a.aiField IS NOT NULL THEN 1 ELSE 0 END AS aiKeyMatched
FROM    aiFlat a
FULL OUTER JOIN (SELECT e.* FROM #expected e WHERE e.encounterID IN (SELECT encounterID FROM firstLog)) x
        ON  x.encounterID = a.encounterID
        AND x.sectionName = a.aiSection
        AND (x.displayName = a.aiField OR x.fieldName = a.aiField)
ORDER BY encounterID, sectionName, fieldName;

-- 5.2 New encounter agent (AI schema) — the cleanest ground truth: verbatim clinician text, AI value,
--     evidence quote and the clinician's verdict per field. Skipped where the AI schema is not deployed.
IF OBJECT_ID(N'AI.EncounterFieldReview') IS NOT NULL
SELECT  t.encounterID, t.transcriptID, t.templeteId, t.createdDate, t.clinicianQuery, t.modelName, t.promptId, t.promptHash,
        r.sectionID, r.fieldID, f.displayName,
        r.aiValue, r.aiUnit, r.aiConfidence, r.aiEvidence, r.isEvidenceDeleted,
        r.finalValue, r.finalUnit, r.action, r.isValueCorrect, r.isUnitCorrect
FROM    AI.EncounterTranscript t WITH (NOLOCK)
JOIN    Encounter.encounter e WITH (NOLOCK) ON e.encounterID = t.encounterID AND e.verifiedFlag = 1
LEFT JOIN AI.EncounterFieldReview r WITH (NOLOCK) ON r.transcriptID = t.transcriptID AND r.isDeleted = 0
LEFT JOIN Template.fields f WITH (NOLOCK) ON f.fieldID = r.fieldID
WHERE   t.aiResponse IS NOT NULL                       -- replied turns only (no refusals / failures)
  AND   t.createdDate >= @FromSignedDate AND t.createdDate < @ToSignedDate
ORDER BY t.encounterID, t.transcriptID, r.sectionID, r.fieldID;

-- 5.3 New agent — per-template accuracy baseline (score the golden set against this)
IF OBJECT_ID(N'AI.EncounterFieldReview') IS NOT NULL
SELECT  t.templeteId, r.action, COUNT(*) AS fields,
        CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY t.templeteId) AS DECIMAL(5,1)) AS pct
FROM    AI.EncounterTranscript t WITH (NOLOCK)
JOIN    AI.EncounterFieldReview r WITH (NOLOCK) ON r.transcriptID = t.transcriptID AND r.isDeleted = 0
GROUP BY t.templeteId, r.action
ORDER BY t.templeteId, r.action;

-- 5.4 "Hard cases": fields edited after first entry (Encounter.encounterDataHistory) — good adversarial items
SELECT  h.encounterID, h.sectionID, h.fieldID, f.displayName,
        h.Value AS previousValue, x.expectedValue AS finalValue, h.createdDate, h.updatedDate
FROM    Encounter.encounterDataHistory h WITH (NOLOCK)
JOIN    #expected x ON x.encounterID = h.encounterID AND x.sectionID = h.sectionID AND x.fieldID = h.fieldID
JOIN    Template.fields f WITH (NOLOCK) ON f.fieldID = h.fieldID
WHERE   ISNULL(h.Value, '') <> ISNULL(x.expectedValue, N'')
ORDER BY h.encounterID, h.sectionID, h.fieldID, h.updatedDate;


/* =====================================================================================================
   STEP 6 — EXPORT: one JSON document per golden encounter (feed straight into the eval harness)
   ===================================================================================================== */
SELECT  g.encounterID,
        (SELECT  g.encounterID                 AS [encounterId],
                 g.templeteId                  AS [templateId],
                 g.encounterTempleteName       AS [templateName],
                 g.templateSpecialityIds       AS [specialityIds],
                 g.complexity                  AS [stratum.complexity],
                 -- INPUT
                 (SELECT STRING_AGG(CAST(REPLACE(REPLACE(r.noteDetails, '<br>', CHAR(10)), '<br/>', CHAR(10)) AS NVARCHAR(MAX)), CHAR(10))
                         WITHIN GROUP (ORDER BY r.notesId)
                  FROM Patient.roundingNotes r WITH (NOLOCK)
                  WHERE r.encounterId = g.encounterID AND r.isDeleted = 0)              AS [input.clinicianNote],
                 (SELECT STRING_AGG(CAST(ISNULL(a.speakerIdentifier, N'Speaker') + N': ' + a.ambientNotes AS NVARCHAR(MAX)), CHAR(10))
                         WITHIN GROUP (ORDER BY r.notesId, a.sequenceOrder, a.createdDate)
                  FROM Patient.roundingNotes r WITH (NOLOCK)
                  JOIN Patient.AmbientDetails a WITH (NOLOCK) ON a.notesId = r.notesId AND a.isDeleted = 0
                  WHERE r.encounterId = g.encounterID AND r.isDeleted = 0)              AS [input.ambientTranscript],
                 -- EXPECTED
                 (SELECT x.sectionID, x.sectionName, x.fieldID, x.displayName AS fieldName, x.fieldType,
                         x.expectedValue AS value, x.isCarryForward, x.equalsDefault
                  FROM #expected x WHERE x.encounterID = g.encounterID
                  ORDER BY x.orderby FOR JSON PATH)                                       AS [expected.fields],
                 (SELECT d.orderNo, d.code AS icd10, d.snomed, d.description
                  FROM Encounter.encounterDiagnosis d WITH (NOLOCK)
                  WHERE d.encounterID = g.encounterID AND ISNULL(d.IsDeleted, 0) = 0
                  ORDER BY d.orderNo FOR JSON PATH)                                       AS [expected.diagnoses],
                 (SELECT c.orderNo, c.code AS cpt, c.modifier, c.unit
                  FROM Encounter.encounterCPT c WITH (NOLOCK)
                  WHERE c.encounterId = g.encounterID
                  ORDER BY c.orderNo FOR JSON PATH)                                       AS [expected.cpt]
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)                                            AS goldenRecordJson
FROM    #golden g
ORDER BY g.encounterID;


/* =====================================================================================================
   STEP 7 — SANITY CHECKS on the finished set (all should return 0 rows / sensible numbers)
   ===================================================================================================== */

-- 7.1 Golden encounters with no scorable field (everything carry-forward / default)
SELECT g.encounterID FROM #golden g
WHERE NOT EXISTS (SELECT 1 FROM #expected x WHERE x.encounterID = g.encounterID AND x.isCarryForward = 0 AND x.equalsDefault = 0);

-- 7.2 Golden encounters with neither a note nor a transcript (only possible if @RequireInput = 0)
SELECT encounterID FROM #golden WHERE noteChars = 0 AND ambientLines = 0;

-- 7.3 Same patient appearing many times (leakage across train/holdout splits — split by patient, not encounter)
SELECT patientID, COUNT(*) AS encounters FROM #golden GROUP BY patientID HAVING COUNT(*) > 1 ORDER BY encounters DESC;

-- 7.4 Final mix
SELECT encounterTempleteName, complexity, COUNT(*) AS encounters, COUNT(DISTINCT providerID) AS providers
FROM   #golden GROUP BY encounterTempleteName, complexity ORDER BY encounterTempleteName, complexity;
