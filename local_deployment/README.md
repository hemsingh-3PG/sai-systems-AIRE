# PacEHR — local deployment on Podman

Runs the **Angular frontend**, the **.NET 8 API** and **PacEHR_AI** (the TypeScript encounter
agent) as three containers on your Mac, managed by Podman / Podman Desktop.

```
  browser
     │
     ├─▶ http://localhost:4200   pacehr-web   nginx  ──┐  (static Angular bundle)
     │                                                 │
     ├─▶ http://localhost:8080   pacehr-api   .NET 8 ──┘──▶  Azure SQL  (pacehr_dev_sqldb)
     │                                                       Service Bus / Redis / PCC …
     │
     └─▶ http://localhost:3000   pacehr-ai    Node 22 (node dist/server.js)
                                                  └──▶  Azure SQL + Azure OpenAI (from PacEHR_AI/.env.local)
```

All three share the `pacehr-local` network, so another container reaches the AI service at
`http://pacehr-ai:3000`.

The Angular bundle is built with the API base URL pointing at `http://localhost:8080`,
so the UI in your browser talks to the API container next to it — not to the cloud.

**Nothing here modifies the repos.** This folder sits *outside* (a sibling of) `PacEHR/`, `pacEHR_API/` and
`PacEHR_AI/`, all of which are used only as read-only build inputs. No file in either
repo is added, edited or committed — including the ignore rules, which are passed to
Podman with `--ignorefile` instead of being dropped in as `.dockerignore`.

---

## 1. Deploy it

```bash
cd <workspace>/sai-systems-AIRE/local_deployment   # <workspace> = the folder holding PacEHR, pacEHR_API, PacEHR_AI
./deploy.sh
```

That runs preflight checks → builds all three images → starts the containers → prints the URLs.

| | URL |
|---|---|
| **Frontend** | **http://localhost:4200** |
| **API (Swagger)** | **http://localhost:8080/swagger** |
| **AI (liveness)** | **http://localhost:3000/health** |
| AI (readiness) | http://localhost:3000/health/ready — checks Azure SQL and the model; a billed model call per hit |

**Only the AI service:** `./deploy.sh --ai-only` (about a minute; no other repo needed).
Any deploy that includes the AI service — the default and `--ai-only` — needs
`PacEHR_AI/.env.local` first; see §5a. Without it, `./deploy.sh --api-only` and
`./deploy.sh --web-only` still work.

First run takes roughly **15–25 minutes** (NuGet restore + `npm install` + `ng build`).
Everything after that is cached — a restart is seconds, a rebuild after a code change is
a few minutes.

---

## 2. Requirements

- **Podman Desktop** (or the `podman` CLI) with a running machine. `./deploy.sh` starts the
  machine for you if it is stopped.
- **~15 GB free inside the Podman VM.** This is the #1 cause of confusing build failures —
  see Troubleshooting.
- Network access to the Azure resources the API talks to (SQL, Service Bus, Redis). If your
  Mac cannot reach `*.database.windows.net`, the API still boots and Swagger still loads,
  but data endpoints will fail.

---

## 3. How to read this folder

```
local_deployment/
├── deploy.sh              ← START HERE. One command: preflight → build → run → status.
├── config.env             ← THE ONLY FILE YOU NORMALLY EDIT. Ports, image names, API URL.
├── README.md              ← this guide
├── containerfiles/
│   ├── api.Containerfile  ← how the .NET API image is built (sdk:8.0 → aspnet:8.0)
│   ├── api.ignore         ← what to keep out of the API build context
│   ├── web.Containerfile  ← how the Angular image is built (node:22 → nginx)
│   ├── web.ignore         ← what to keep out of the web build context
│   ├── ai.Containerfile   ← how the AI image is built (node:22: tsc → dist/, stages: runtime | test)
│   └── ai.ignore          ← keeps every .env file out of the AI build context
└── scripts/
    ├── lib.sh             ← shared helpers; sourced by the others, never run directly
    ├── preflight.sh       ← checks podman, repo paths, AI settings, VM disk, free ports
    ├── build.sh           ← builds the images        (build.sh [api|web|ai] [--no-cache])
    ├── up.sh              ← starts the containers    (up.sh [api|web|ai])
    ├── down.sh            ← stops/removes containers, keeps images (down.sh [api|web|ai])
    ├── status.sh          ← what is running + whether each URL answers
    ├── logs.sh            ← logs.sh api|web|ai [-f]
    ├── test-ai.sh         ← PacEHR_AI typecheck + tests inside a container
    └── clean.sh           ← removes containers, images and the network
```

Reading order if you want to understand the whole thing: **`config.env` → `deploy.sh` →
`scripts/build.sh` → `containerfiles/*.Containerfile`**. Each script is short, sources
`lib.sh` for helpers, and does exactly one job.

---

## 4. Everyday commands

| Goal | Command |
|---|---|
| Deploy everything | `./deploy.sh` |
| Restart without rebuilding | `./deploy.sh --no-build` |
| Rebuild after changing API code | `./scripts/build.sh api && ./scripts/up.sh api` |
| Rebuild after changing UI code | `./scripts/build.sh web && ./scripts/up.sh web` |
| Deploy only the AI service | `./deploy.sh --ai-only` |
| Rebuild after changing AI code | `./scripts/build.sh ai && ./scripts/up.sh ai` |
| AI typecheck + unit tests in a container | `./scripts/test-ai.sh` |
| …plus the Azure integration tests | `./scripts/test-ai.sh --integration` |
| Force a clean rebuild | `./deploy.sh --no-cache` |
| Only the API / only the UI | `./deploy.sh --api-only` / `./deploy.sh --web-only` |
| Is it up? | `./scripts/status.sh` |
| Follow logs | `./scripts/logs.sh api -f` |
| Stop (keep images) | `./scripts/down.sh` |
| Remove everything it created | `./scripts/clean.sh` |

---

## 5. Configuration (`config.env`)

| Setting | Default | What it does |
|---|---|---|
| `API_PORT` / `WEB_PORT` | `8080` / `4200` | Host ports. Change if something else uses them. |
| `ASPNETCORE_ENV` | `Development` | Which `appsettings.<env>.json` the API loads. `Development` = the **DEV** Azure SQL database. |
| `WEB_API_BASE_URL` | `http://localhost:8080` | The API URL baked into the Angular bundle. Point it at the cloud DEV API instead if you only want the UI locally. |
| `WEB_BUILD_CONFIG` | `staging` | Angular configuration. `staging` is what the Azure pipeline builds for every non-prod environment: optimized, no budget limits, keeps `environment.ts` (real DEV blob + SignalR endpoints). |
| `WEB_OPTIMIZE` | `true` | `false` builds faster but ships a large, slow bundle. |
| `API_REPO` / `WEB_REPO` / `AI_REPO` | `../../pacEHR_API` / `../../PacEHR` / `../../PacEHR_AI` | Where the repos are (siblings of `sai-systems-AIRE`). Relative paths resolve against this folder. Override per person in `config.local.env`, not here. |
| `AI_PORT` | `3000` | Host port for the AI service. |
| `AI_ENV_FILE` | `../../PacEHR_AI/.env.local` | The AI service's settings, passed to the container as environment variables. |
| `AI_NODE_IMAGE` | `node:22-alpine` | Base image for the AI service; PacEHR_AI needs Node ≥ 22.13. |

`WEB_API_BASE_URL` is **build-time**, not runtime: Angular compiles it into the bundle.
Change it → rebuild the web image (`./scripts/build.sh web && ./scripts/up.sh web`).

### 5a. PacEHR_AI settings (`.env.local`)

The AI service reads Azure OpenAI, Azure SQL and Entra settings. Create the file once, in the
AI repo (it is git-ignored there), and fill it in:

```bash
cp <workspace>/PacEHR_AI/.env.example <workspace>/PacEHR_AI/.env.local
```

- The seven names with placeholders are required; the container exits at startup naming any
  that is missing, and `./scripts/preflight.sh ai` warns about them first.
- On a Mac there is no managed identity, so set `AZURE_OPENAI_API_KEY`, and `AZURE_SQL_USER` +
  `AZURE_SQL_PASSWORD` (both or neither).
- Write values **unquoted** (`KEY=value`): podman keeps quote characters as part of the value.
- The file is never copied into an image (`ai.ignore`); `up.sh` hands it to `podman run
  --env-file`, the way app settings reach the container in Azure.

---

## 6. How the pieces work

**API image** — multi-stage: `mcr.microsoft.com/dotnet/sdk:8.0` restores and publishes,
then the output is copied into the much smaller `aspnet:8.0` runtime. Only the projects
`PacEHR.API` actually references are copied in; the SSDT database project and the test
projects are excluded. `ASPNETCORE_HTTP_PORTS=8080` makes the listening port explicit.

**Web image** — `node:22-alpine` runs `npm install --legacy-peer-deps` (same as the Azure
pipeline; plain `npm ci` fails because `@agm/core@1.0.0` declares peers for Angular 6–9
while the app is on Angular 18), then `ng build`. The result is served by `nginx:alpine`
with a single-page-app fallback so deep links and refreshes don't 404.

**How the API URL gets in without touching the repo** — during the *image build only*, a
`sed` step rewrites the whole `apiBaseUrl:` line in every `src/environments/environment*.ts`.
That happens inside the build container, on a copy. Your working tree is never written to.
It covers `environment.prod.ts` too, whose committed value is the CI placeholder
`'__apiBaseUrl__'`.

**AI image** — `node:22-alpine`, multi-stage, mirroring the repo's own scripts. The `build`
stage runs `npm ci` and `npm run build` (`tsc -p tsconfig.build.json && tsc-alias`), compiling
`src/*.ts` to `dist/*.js`. The `runtime` stage installs production dependencies only
(`npm ci --omit=dev`), copies just `dist/`, and runs `node dist/server.js` (the repo's
`start:prod`) as the unprivileged `node` user. The `test` stage runs
`npm run typecheck && npm test && npm run build`; `./scripts/test-ai.sh` builds and runs it, so
the checks run on the same Node the service ships on. The AI container restarts at most 3 times on failure, so a
settings error stays one readable line in `./scripts/logs.sh ai` instead of an endless loop.

**CORS** — the API already runs `AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()`, so the
browser calling `localhost:8080` from `localhost:4200` needs no proxy.

---

## 7. Using Podman Desktop

Both containers appear in Podman Desktop automatically — nothing extra to configure. Under
**Containers** you'll see `pacehr-api`, `pacehr-web` and `pacehr-ai`; click any for logs, a
terminal, stats, or start/stop buttons. Images show up as `pacehr-api-local`,
`pacehr-web-local`, `pacehr-ai-local` (and `pacehr-ai-test-local` once you run
`./scripts/test-ai.sh`), and the network as `pacehr-local`.

The scripts and Podman Desktop are two views of the same thing — stopping a container in the
UI is the same as `./scripts/down.sh`.

---

## 8. Troubleshooting

**`no space left on device` during a build**
The Podman VM has its own fixed virtual disk, separate from your Mac's free space.
```bash
podman system df                 # how much is reclaimable
podman system prune -f           # drop dangling layers/containers first
```
Still tight? Grow the VM disk (this stops the machine and any other containers briefly):
```bash
podman machine stop
podman machine set --disk-size 120        # GB
podman machine start
podman machine ssh -- "sudo growpart /dev/vda 4 && sudo xfs_growfs /"
```
The last line matters: growing the virtual disk does **not** grow the filesystem inside it.
This VM is Fedora CoreOS on XFS, so it's `xfs_growfs` — `resize2fs` will fail with
"bad magic number".

**`port is already in use`**
Change `API_PORT` / `WEB_PORT` in `config.env`, or free the port. If you change `API_PORT`,
also update `WEB_API_BASE_URL` to match, then rebuild the web image.

**UI loads but every API call fails**
Check the API is actually up: `./scripts/status.sh` and `./scripts/logs.sh api`. Then confirm
`WEB_API_BASE_URL` matches `API_PORT` — it is compiled into the bundle, so a mismatch needs a
web rebuild, not just a restart.

**API returns `401 Missing token`**
Expected. A global auth filter guards the endpoints — even some marked `[AllowAnonymous]`.
You need a real token from a login flow; this is not a container problem.

**API can't reach the database**
The API talks to a **remote Azure SQL** server; there is no local database. Connection
timeouts usually mean your IP isn't allowed through the Azure SQL firewall, or you're off
the VPN. Nothing in this folder can fix that.

**CCDA features throw at runtime**
`CCDA.dll` is a legacy Windows-targeted assembly. It loads and the app runs, but any code
path that calls into Windows-only APIs can fail inside a Linux container. Same caveat applies
when running the API natively on macOS.

**MatrixCare integration throws about a certificate**
`SslSettings.ReadSslFromAzure` is `true` in every `appsettings` file, so the app looks for a
certificate in an Azure App Service store that doesn't exist locally. It's resolved lazily,
so it only affects that one integration.

**AI container exits right after start**
Almost always settings. `./scripts/logs.sh ai` shows `settings: missing or invalid: <NAMES>`
(names only, never values). Fix `PacEHR_AI/.env.local`, then `./scripts/up.sh ai` — no rebuild
needed, settings are read at startup.

**`/health/ready` answers 503**
`/health` (liveness) does no I/O; `/health/ready` reaches Azure SQL and the model. The body
carries a reason code per check (`HTTP 403`, `ELOGIN`, `TIMEOUT`, `ConnectionError`); the full
error is one `warn` line in `./scripts/logs.sh ai`. Usually the SQL firewall, the VPN, or a
wrong key/endpoint.

**`PacEHR_AI has no src/server.ts + tsconfig.build.json`**
The AI repo is on a branch from before the TypeScript conversion. Check out
`PacEHR-AI-Develop-Main`.

---

## 9. What this is not

- **Not a production deployment.** The Azure pipeline (`pipelines/deploy-pacehrapis.yml`,
  `pipelines/deploy-pacehrui.yml`) deploys to Windows App Services without containers. This
  folder is purely a local convenience and changes nothing about how the app ships.
- **Not isolated from cloud data.** `ASPNETCORE_ENV=Development` points at the shared **DEV**
  Azure SQL database. Anything you write locally is written there.
- **Not safe to publish.** The API image bakes in `appsettings*.json`, which carry live
  plaintext credentials as committed in the repo. Keep these images local; don't push them to
  a registry.
