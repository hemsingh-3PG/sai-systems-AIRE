-- PEA-203. The AI's proposal beside the clinician's decision, one row per field per run.
-- Forward-only: once merged this file is never edited.
--
-- ABSENT and ABSTAINED are deliberately distinct and must never collapse into one value: the
-- first is a successful extraction finding nothing, the second is the model declining to answer.
-- Production writes NA for both today, which is the defect this table exists to fix.
--
-- Confidence is a band, never a float: nothing in the runtime produces a calibrated probability,
-- so a numeric column would hold a number the model invented about itself.
--
-- The filtered index is the review queue: rows awaiting a decision, by encounter, oldest first.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldOutcome]') AND type = N'U')
CREATE TABLE [AI].[fieldOutcome] (
    [outcomeID]             BIGINT          IDENTITY (1, 1) NOT NULL,
    [runID]                 BIGINT          NOT NULL,
    [encounterID]           INT             NOT NULL,
    [templetID]             INT             NOT NULL,
    [sectionID]             INT             NOT NULL,
    [fieldID]               INT             NOT NULL,
    [proposedValue]         NVARCHAR (400)  NULL,
    [proposedUnit]          NVARCHAR (50)   NULL,
    [proposedStatus]        VARCHAR (10)    NOT NULL,
    [proposedConfidence]    VARCHAR (6)     NOT NULL,
    [foundIn]               NVARCHAR (1000) NULL,
    [verdict]               VARCHAR (10)    NOT NULL,
    [reasonCode]            NVARCHAR (50)   NULL,
    [acceptedValue]         NVARCHAR (400)  NULL,
    [acceptedUnit]          NVARCHAR (50)   NULL,
    [acceptedStatus]        VARCHAR (10)    NULL,
    [decidedByProviderID]   INT             NULL,
    [decidedAtUtc]          DATETIME2 (7)   NULL,
    [createdUtc]            DATETIME2 (7)   CONSTRAINT [DF_fieldOutcome_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldOutcome] PRIMARY KEY CLUSTERED ([outcomeID] ASC),
    CONSTRAINT [FK_fieldOutcome_agentRun] FOREIGN KEY ([runID]) REFERENCES [AI].[agentRun] ([runID]),
    CONSTRAINT [CK_fieldOutcome_proposedStatus] CHECK ([proposedStatus]='FOUND' OR [proposedStatus]='ABSENT' OR [proposedStatus]='ABSTAINED'),
    CONSTRAINT [CK_fieldOutcome_proposedConfidence] CHECK ([proposedConfidence]='HIGH' OR [proposedConfidence]='MEDIUM' OR [proposedConfidence]='LOW'),
    CONSTRAINT [CK_fieldOutcome_verdict] CHECK ([verdict]='ACCEPT' OR [verdict]='REVIEW' OR [verdict]='BLOCK'),
    CONSTRAINT [CK_fieldOutcome_acceptedStatus] CHECK ([acceptedStatus] IS NULL OR [acceptedStatus]='FOUND' OR [acceptedStatus]='ABSENT' OR [acceptedStatus]='ABSTAINED')
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fieldOutcome_run' AND object_id = OBJECT_ID(N'[AI].[fieldOutcome]'))
CREATE NONCLUSTERED INDEX [IX_fieldOutcome_run]
    ON [AI].[fieldOutcome]([runID] ASC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fieldOutcome_pending' AND object_id = OBJECT_ID(N'[AI].[fieldOutcome]'))
CREATE NONCLUSTERED INDEX [IX_fieldOutcome_pending]
    ON [AI].[fieldOutcome]([encounterID] ASC, [createdUtc] ASC)
    WHERE ([decidedAtUtc] IS NULL);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fieldOutcome_field_history' AND object_id = OBJECT_ID(N'[AI].[fieldOutcome]'))
CREATE NONCLUSTERED INDEX [IX_fieldOutcome_field_history]
    ON [AI].[fieldOutcome]([templetID] ASC, [sectionID] ASC, [fieldID] ASC, [createdUtc] ASC);
