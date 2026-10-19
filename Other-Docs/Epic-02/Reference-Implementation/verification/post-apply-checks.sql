-- PEA-201 post-apply verification. Read-only: every statement here is a SELECT.
-- Run after each apply, against each target, and keep the output as deployment evidence.
--
-- These are operator checks, not application statements, so they live here rather than as _SQL
-- constants in a module. Nothing in the service ever runs this file.

-- 1. The schema exists.                                                    expect: 1 row
SELECT name FROM sys.schemas WHERE name = 'AI';

-- 2. No database role was created by this epic.                          expect: 0 rows
--    Authority lives in the application (owner decision, 2026-10-05). A row here means someone
--    reintroduced a role out of band -- find out who, and whether the application still agrees.
SELECT name, type_desc FROM sys.database_principals
WHERE type = 'R' AND name IN ('aiServiceRuntime', 'aiPromptAdmin', 'aiTemplateAdmin');

-- 3. Nothing has been granted on any AI.* object.                         expect: 0 rows
--    The service connects as one principal with whatever rights that login already holds.
--    ⚠️ Read this one knowing what it means: AI.agentRun is append-only by application
--    convention, not by permission. Nothing at the server refuses an UPDATE or DELETE against
--    the audit table. If that guarantee is needed, it is a trigger, not a grant -- see HANDOFF.
SELECT pr.name AS grantee, dp.permission_name, dp.state_desc, o.name AS object_name
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'AI';

-- 4. The five tables exist.                                               expect: 5 rows
SELECT o.name, o.type_desc FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'AI' AND o.type = 'U' AND o.name <> 'prompt'
ORDER BY o.name;

-- 5. THE CHECK THAT MATTERS: not one object outside the AI schema was touched today.
--                                                                        expect: 0 rows
--    Any row is a failed deployment. Stop, keep the output, and do not proceed.
SELECT s.name AS schema_name, o.name AS object_name, o.type_desc, o.modify_date
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name <> 'AI'
  AND o.modify_date >= CAST(GETDATE() AS DATE);

-- 6. What the AI schema now holds. Informational -- after PEA-201 this is AI.prompt only,
--    the pre-existing table. The five new tables arrive in PEA-202..207.
SELECT o.name, o.type_desc, o.create_date
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'AI'
ORDER BY o.name;
