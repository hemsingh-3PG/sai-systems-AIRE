# Workspace and systems — what everyone should know first

Last verified: 2026-10-19 against PacEHR@401caa134, pacEHR_API@0f611f65c, PacEHR_AI@ef172ea.

## The three products (client repos, Azure DevOps `Saisystems-PaaS/PacEHR`)
| Repo | Tech | Role | Base branch for PRs |
|---|---|---|---|
| `PacEHR` | Angular 18 SPA | Browser UI | `PacEHR-DevelopUI-Main` |
| `pacEHR_API` | ASP.NET Core 8 + SQL Server (SSDT) + Azure Functions | API, business logic mostly in stored procedures | `PacEHR-DevelopAPI-Main` |
| `PacEHR_AI` | Node 22 / TypeScript, LangChain, Azure OpenAI | Clinical-note field extraction service | `PacEHR-AI-Develop-Main` |

`sai-systems-AIRE` is **ours**: the AIRE framework, analysis docs, ticket work, context. Nothing from it is ever committed to a client repo.

## How they connect today (verified 2026-10-19)
SPA → API (~1,039 RPC-style endpoints) → SQL Server. The API also talks to PointClickCare, MatrixCare, DrFirst, Updox, IMO, Twilio, Azure services.
`PacEHR_AI` is **not connected yet**: nothing in the SPA or API calls it; its only routes are `/health` and `/health/ready`. The AI features users can reach today use the older OpenAI path in the API/SPA.
Full picture: `docs/architecture/current/00-system-overview.md` and modules 01–13.

## Jira
Keys seen in the repos: `PAC-` (API/platform), `AITP-` (UI guided workflow work), `PEA-` (PacEHR_AI). Confirm the full list with the lead.
The literal key goes in the branch, every commit and the PR title. Jira's Development panel matches only the literal key and fails silently otherwise.

## Environments
API/UI base URLs per environment live in `PacEHR/src/environments/*.ts` and `pacEHR_API/PacEHR.API/appsettings.<Env>.json`. Do not copy secrets from those files into any doc or chat.
`Development` points at the shared DEV Azure SQL database — a local API container talks to real DEV data. Treat it accordingly.

## Data and PHI
This is an EHR. Never paste patient data, tokens, keys or connection strings into tickets, docs, PRs or AI prompts. The PacEHR_AI service sends notes to Azure OpenAI under the client's BAA (decision recorded; the PHI masker is deliberately an identity step) — that decision does not extend to any other tool or model.

## Known security findings under triage
Read `docs/status.md` (Deep-Dive 2026-10-19 entry). Do not copy or spread them; raise defects through `aire-raise-defect`.

## Glossary
| Term | Meaning |
|---|---|
| SSDT | SQL Server Data Tools project (`PacEHR.Database`) — the schema as code |
| Release script | Dated folder under `PacEHR.Database/Scripts/Script.<dd-Mon-yyyy>/` carrying a release's SQL |
| PCC | PointClickCare, the main external EHR integration |
| Eval | `npm run eval` in PacEHR_AI: the accuracy gate (recall/precision vs benchmark) |
| AIRE | 3Pillar's SDLC agentic framework (the `aire-*` workflows) |
| Baseline docs | `docs/architecture/current/` — the pinned description of how the code works today |
