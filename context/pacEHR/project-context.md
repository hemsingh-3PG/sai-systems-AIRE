# PacEHR (Angular UI) — project context

Last verified: 2026-10-19 against PacEHR@401caa134 (a ticket branch, `3p-dev/AITP-117-…`; the team base is `PacEHR-DevelopUI-Main` — re-check on base).
Depth: `docs/architecture/current/09-spa-shell-navigation-deep-dive.md`, `10-spa-feature-areas-deep-dive.md`.

## What it is
Angular 18.2 SPA, TypeScript 5.5, 340 components (304 standalone), 54 feature folders under `src/app/features/`. Talks to `pacEHR_API` over RPC-style HTTP with an AES payload-encryption interceptor.

## Commands (from `package.json` and the pipelines)
| Task | Command |
|---|---|
| Install | `npm install --legacy-peer-deps` — `npm ci` fails (an old `@agm/core` peer on Angular 6–9). The pipeline does the same. Node 22 is what the local container build uses. |
| Run | `npm start` (`ng serve`; dev proxy in `src/proxy.conf.json`) |
| Build | `npx ng build` (what PRs are checked with); production: `npm run build-prod-no-patch` |
| Unit tests | `npm test` (Karma + Jasmine) |
| E2E | `npm run test:e2e` (Playwright, 220 specs; legacy Protractor `e2e/` is dead weight) |

## What "green" means today
> Recorded 2026-10-12 (re-verify before relying on it): the full Karma suite does not compile on the base branch (a type error in `add-edit-patient.component.spec.ts`) and roughly 350 client tests already fail on base even once patched.
To prove you broke nothing: take the failing-test names on a scratch copy of base and on your branch. Identical lists = no regression. Do **not** fix the client's specs inside your ticket.

## Where things live
| Path | What |
|---|---|
| `src/app/features/` | One folder per screen/feature (largest: `patient-list`, `basic-reports`, `encounter-list`) |
| `src/app/core/services/` | All HTTP access goes through here (63 services) |
| `src/app/core/ineterceptors/` | Interceptors (the folder name is misspelled — leave it) |
| `src/app/_store/` | NgRx — only `login` and `error` slices |
| `src/app/configs/` | Constants, `phi-masker.ts`, `prompt-sanitizer.ts` |
| `src/environments/` | Per-environment API/blob/SignalR endpoints |

## Rules people break
1. Never commit `environment.ts` edits you made to point at QA/DEV, or `package-lock.json` churn from a local tool (install such tools with `--no-save`).
2. Feature flags gate new screens (see the guided-workflow gating in module 10); a new screen without its flag check ships to everyone.
3. Match the SQL→C#→TypeScript datatype rule in `pacEHR_API/CLAUDE.md` when you add a field. A `0` for a `bool?` is an HTTP 400 for the whole request, with an error that names the wrong field.
4. PHI: never log, store or paste patient data; `phi-masker.ts` runs in the browser only.
5. Most feature areas have no specs. When you touch one, add specs for the code you changed.

## Known traps
- Angular Material 17 on Angular 18 (version skew) and three charting libraries — do not add a fourth.
- Session identity lives in `sessionStorage`/`localStorage`; logout clears both.
- Datadog RUM is enabled in prod and sends staff name, email and role (module 09) — do not add more identifiers to it.
