# pacEHR_API — project context

Last verified: 2026-10-19 against pacEHR_API@0f611f65c (`PacEHR-DevelopAPI-Main`).
Depth: `docs/architecture/current/01…08`, `11`, `12`. The repo's own rules: `pacEHR_API/CLAUDE.md` (SQL, release-script and stored-procedure rules — **read it fully before touching SQL**; this file only summarises).

## What it is
.NET 8 solution `pacEHR.sln`: `PacEHR.API` (100 controllers, ~1,039 endpoints), `pacEHR.DomainServices` (+ `.Interfaces`), `pacEHR.Data.Dtos`, `PacEHR.Data`, `pacEHR.PCC.Services`, `PacEHR.Functions.Process` (timer functions), `PacEHR.Database` (SSDT, ~3,000 `.sql` files), `PacEHR.Tests.UnitTests`. Business logic is mostly **stored procedures**; C# orchestrates and maps.

## Commands
| Task | Command |
|---|---|
| Build | `dotnet build pacEHR.sln` (needs the .NET 8 SDK) |
| Unit tests | `dotnet test PacEHR.Tests.UnitTests` |
| Local container | `sai-systems-AIRE/local_deployment/deploy.sh --api-only` (builds only the projects the API references; needs the repo's `CCDA.dll`) |

`PacEHR.Tests.Integration` is empty. Note (module 11): `<Compile Remove="DomainServices\**"/>` in the test project excludes 548 tests in 46 files — they never run. Do not assume "all green" means those pass.

## Rules people break (full text in `pacEHR_API/CLAUDE.md`)
1. **Literal Jira key** in branch, commit and PR title — Jira's panel fails silently otherwise.
2. New table: confirm the **schema** first; never silently default to `dbo`.
3. Datatypes: only `BIT INT NVARCHAR VARCHAR DATETIME DATE DATETIME2` without approval; lengths explicit; types must match C# and TypeScript.
4. Table change = an **ALTER script in the release folder AND the `Tables/` file**, together.
5. Every new `.sql` must be registered in `PacEHR.Database.sqlproj` (`Build Include` for objects, `None Include` for release scripts) — an unregistered file is silently never deployed.
6. New procs: `usp_<Verb><Noun>`, under `Stored Procedures/Procs2/`, `CREATE OR ALTER`, schema-qualified, header block with the Jira key.
7. Release scripts are **copies**; the canonical file stays where it is. The `Script.<date>` folder is deleted after release.
8. Never rename or reformat existing SQL "to match the convention" — renames break callers silently at runtime.
9. Calling a proc: add the binding in the area's `pacehr_devContextProcedures.<Area>.cs` partial and its interface declaration.

## Known traps (verified in the 2026-10-19 deep-dives; do not "fix" inside an unrelated ticket)
- Authentication is a custom `JWTMiddleware`; `UseAuthentication()` has no scheme. CORS is open. Swagger is on everywhere (module 01/02).
- Tenant (`accountID`) is read from a client header at ~156 sites (module 01). Any new endpoint must derive tenancy from the session, as `WebUiTokenController`/`ReferralController` do.
- The 928 EF entity files under `PacEHR.Data/Models` are not compiled (`Compile Remove`); the live context is a thin shell (module 02).
- Secrets and keys are committed in several appsettings files (modules 06, 12). Report; never copy or extend.
- `appsettings.Production.json` omits some keys that other environments set, so production inherits base values unless Key Vault overrides — check before assuming parity.
