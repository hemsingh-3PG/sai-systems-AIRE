-- PEA-207. The per-mapping field description the schema builder sends to the model.
-- Forward-only: once merged this file is never edited.
--
-- A sidecar in the AI schema rather than a column on Template.fields, because no existing
-- clinical table is altered by this service.
--
-- name, type and unit are deliberately absent: they are live columns on Template.fields, and
-- copying them here would create a second source of truth that drifts silently.
--
-- The composite key is the whole key -- no surrogate, because nothing references a description
-- by id and the mapping grain is the identity. One description per mapping, enforced by the PK,
-- so no secondary index earns its place.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[AI].[fieldDescription]') AND type = N'U')
CREATE TABLE [AI].[fieldDescription] (
    [templetID]   INT             NOT NULL,
    [sectionID]   INT             NOT NULL,
    [fieldID]     INT             NOT NULL,
    [description] NVARCHAR (1000) NOT NULL,
    [createdUtc]  DATETIME2 (7)   CONSTRAINT [DF_fieldDescription_createdUtc] DEFAULT (getutcdate()) NOT NULL,
    [updatedUtc]  DATETIME2 (7)   CONSTRAINT [DF_fieldDescription_updatedUtc] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_fieldDescription] PRIMARY KEY CLUSTERED ([templetID] ASC, [sectionID] ASC, [fieldID] ASC)
);
