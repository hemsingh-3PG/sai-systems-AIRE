# PacEHR_AI — project context

Last verified: 2026-10-19 against PacEHR_AI@ef172ea (`3p-dev/epic-05-Guardrails`; team base `PacEHR-AI-Develop-Main`).
Depth: `docs/architecture/current/13-pacehr-ai-service-deep-dive.md`. The repo's own standard: `PacEHR_AI/CLAUDE.md` and `tests/eval/CLAUDE.md` — **tickets cite them and do not restate them; read them first.**

## What it is
Node ≥22.13 / TypeScript (ESM) service that reads a clinician's free-text note and extracts values into the fields of an encounter template. LangChain `createAgent` on Azure OpenAI (gpt-4.1, temperature 0), with four middleware: guard → model call → evidence → outcome. Own `AI` schema in Azure SQL, forward-only migrations in `migrations/sql/`.
**Not integrated yet:** only `/health` and `/health/ready`; no caller in the SPA or API (verified 2026-10-19).

## Commands
| Task | Command |
|---|---|
| Install | `npm ci`, then once per clone `npm run hooks:install` |
| Run | `npm start` (`tsx src/server.ts`), settings from git-ignored `.env.local` |
| Unit tests (offline, network blocked) | `npm test` — also typecheck |
| Integration (reaches Azure) | `npm run test:integration` |
| Accuracy gate | `npm run eval` — needs VPN + DEV database; required when agent behaviour changes |
| Build | `npm run build` |
| Local container | `sai-systems-AIRE/local_deployment/deploy.sh --ai-only` (placeholders: `AI_ENV_FILE=ai.placeholder.env`); `scripts/test-ai.sh` runs the offline tier in a container |

## Rules specific to this repo
1. **Scope:** keep work inside this Node service. Prefer Azure configuration as code.
2. **Settings only through `src/core/settings.ts`** (zod schema) — `process.env` appears nowhere else. A new setting is one schema entry. Values in `.env.local`, unquoted when passed to podman.
3. **Pre-push hook** blocks a push unless `npm test`, the build and — for agent-affecting `src/` changes — a passing eval recorded in `tests/eval/history.jsonl` for exactly that code. Never `--no-verify` to get around it. (At 2026-10-19 the pushed `src/` had no passing eval for its code hash — module 13.)
4. **Every behaviour change:** run the eval, record why and the measured effect in a dated change log under `docs/`, revert a change that does not improve what it set out to. Lead accuracy reports with **recall**; hold precision at/above the benchmark.
5. **PHI:** Azure OpenAI is covered by the client's BAA; sending the note to the model is permitted; the PHI masker is deliberately an identity step (decision recorded; PEA-503 closed). Do not re-open or extend that to other models/vendors.
6. Reference specs: `dev-stories/Tickets-Original-JS/` (Node) is the benchmark; `Tickets-Original-Python/` is older and secondary.

## Known gaps (module 13 — raise as tickets, do not fix in passing)
Nothing calls the agent; no audit row is written; `[AI].[usp_getActiveClinicianSummary]` is called but not created by any migration; the migration runner keeps no history table and re-runs every script; `/health/ready` makes a billed model call on every hit; gpt-4.1 retires 2027-04-14; tenancy ids are caller-asserted.
