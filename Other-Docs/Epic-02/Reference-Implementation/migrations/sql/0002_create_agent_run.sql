-- PEA-202. One append-only audit row per AI invocation, including runs that never reached the
-- model. Forward-only: once merged this file is never edited.
--
-- The two CHECKs are the point of the design, not decoration. promptHash and modelDeployment are
-- nullable because a guard-blocked run has neither -- but a *successful* run without a prompt hash
-- would destroy reproducibility, so CK_agentRun_reachedModel makes nullability legal on exactly
-- one path. CK_agentRun_blockedHasReason is its mirror: a blocked run may omit the model columns,
-- never why. Every row is "reached the model, here is the hash" or "did not, here is the reason".

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[agentRun]') AND type = N'U')
CREATE TABLE [AI].[agentRun] (
    [runID]            BIGINT         IDENTITY (1, 1) NOT NULL,
    [encounterID]      INT            NOT NULL,
    [templetID]        INT            NULL,
    [promptHash]       VARCHAR (64)   NULL,
    [modelDeployment]  NVARCHAR (100) NULL,
    [configVersion]    VARCHAR (64)   NULL,
    [inputTokens]      INT            NULL,
    [outputTokens]     INT            NULL,
    [latencyMs]        INT            NULL,
    [outcome]          VARCHAR (20)   NOT NULL,
    [reasonCode]       VARCHAR (64)   NULL,
    [createdUtc]       DATETIME2 (7)  CONSTRAINT [DF_agentRun_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_agentRun] PRIMARY KEY CLUSTERED ([runID] ASC),
    CONSTRAINT [CK_agentRun_outcome] CHECK ([outcome]='COMMITTED' OR [outcome]='AWAITING_REVIEW' OR [outcome]='BLOCKED'),
    CONSTRAINT [CK_agentRun_reachedModel] CHECK (
        ([outcome]='BLOCKED')
        OR ([promptHash] IS NOT NULL AND [modelDeployment] IS NOT NULL)
    ),
    CONSTRAINT [CK_agentRun_blockedHasReason] CHECK (
        ([outcome]<>'BLOCKED') OR ([reasonCode] IS NOT NULL)
    )
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_agentRun_encounter' AND object_id = OBJECT_ID(N'[AI].[agentRun]'))
CREATE NONCLUSTERED INDEX [IX_agentRun_encounter]
    ON [AI].[agentRun]([encounterID] ASC, [createdUtc] ASC);
