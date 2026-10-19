-- PEA-201. Creates the AI schema. Forward-only: once merged this file is never edited, and a
-- correction is a new numbered script.
--
-- The schema already exists in production, carrying AI.prompt, but no CREATE SCHEMA statement
-- exists anywhere in source control (defect X9). The guard makes this file correct against both
-- a production database, where it does nothing, and an empty one, where it creates the schema.
--
-- EXEC rather than a bare CREATE: CREATE SCHEMA must be the first statement in its batch, and
-- mssql sends this whole file as one batch.
--
-- No database roles and no GRANTs are created by this epic (owner decision, 2026-10-05).
-- Authority over AI.* is enforced in the application: the service connects as one principal, and
-- which caller may read or write what is decided above the data layer. The consequence to know:
-- AI.agentRun is append-only by convention rather than by permission -- see migrations/verification.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'AI')
    EXEC ('CREATE SCHEMA [AI]');
