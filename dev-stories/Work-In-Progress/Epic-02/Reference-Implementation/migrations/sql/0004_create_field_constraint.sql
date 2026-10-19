-- PEA-206. Per-mapping numeric bounds, keyed on (templetID, sectionID, fieldID).
-- Forward-only: once merged this file is never edited.
--
-- The grain is per mapping, not per field: one displayName edit was measured reaching 179 of 458
-- templates, so a global grain would leak a bound across every template using that field.
--
-- Two bands, with different behaviours: plausible* blocks a value, abnormal* flags it and keeps
-- it. One unlabelled pair cannot express that difference, and getting it wrong is silent in both
-- directions -- either real abnormal values pass unflagged, or real hypertensive readings are
-- refused as implausible.
--
-- DECIMAL, not FLOAT: a bound is compared, and binary floating point makes a comparison at the
-- boundary a coin toss. ponytail: node-mssql surfaces DECIMAL as a JS double, so the comparison
-- must happen in SQL or carry an explicit tolerance -- see the read path, not this file.
--
-- unit is stored as authored and never converted here. A multi-unit value such as "kg|lb" against
-- one min/max pair is ambiguous by construction; the resolution belongs to the validator.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldConstraint]') AND type = N'U')
CREATE TABLE [AI].[fieldConstraint] (
    [constraintID] INT            IDENTITY (1, 1) NOT NULL,
    [templetID]    INT            NOT NULL,
    [sectionID]    INT            NOT NULL,
    [fieldID]      INT            NOT NULL,
    [unit]         NVARCHAR (20)  NULL,
    [plausibleMin] DECIMAL (6, 2) NULL,
    [plausibleMax] DECIMAL (6, 2) NULL,
    [abnormalMin]  DECIMAL (6, 2) NULL,
    [abnormalMax]  DECIMAL (6, 2) NULL,
    [sourceProse]  NVARCHAR (MAX) NULL,
    [isActive]     BIT            CONSTRAINT [DF_fieldConstraint_isActive] DEFAULT ((1)) NOT NULL,
    [createdUtc]   DATETIME2 (7)  CONSTRAINT [DF_fieldConstraint_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    [updatedUtc]   DATETIME2 (7)  CONSTRAINT [DF_fieldConstraint_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldConstraint] PRIMARY KEY CLUSTERED ([constraintID] ASC),
    CONSTRAINT [UQ_fieldConstraint_mapping] UNIQUE NONCLUSTERED ([templetID] ASC, [sectionID] ASC, [fieldID] ASC),
    CONSTRAINT [CK_fieldConstraint_plausibleRange] CHECK ([plausibleMin] IS NULL OR [plausibleMax] IS NULL OR [plausibleMin]<=[plausibleMax]),
    CONSTRAINT [CK_fieldConstraint_abnormalRange] CHECK ([abnormalMin] IS NULL OR [abnormalMax] IS NULL OR [abnormalMin]<=[abnormalMax])
);
