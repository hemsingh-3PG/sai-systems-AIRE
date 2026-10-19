# Epic 11 — Azure deployment and operations (Node.js / TypeScript edition)

## Part 1 — Tickets (copy-paste)

### Epic

**Title:** Deploy the agent to Azure as one container and prove it in shadow mode

**Description:** This epic puts the Node.js extraction agent into the client's Azure subscription as one new compute component: one container image, hosted as an Azure Function on a plan that can run a container and keep an instance warm. Everything it calls already exists: the API gateway, the .NET 8 App Service, Azure SQL, Azure OpenAI, Key Vault and Application Insights. The Function authenticates to each of them with its own managed identity, reaches Azure OpenAI only over a private endpoint, and sends its traces to the existing Application Insights instance. Before it may write a single value to a patient chart, it runs on real traffic in shadow mode, and cutover is allowed only when a measured exit bar and two named sign-offs are recorded. The agent, its guards and its endpoints are built in other epics; this epic hosts them.

### PEA-1101

**Title:** Host the agent as the one new Azure Function on a container-capable plan

**Description:**
As a platform engineer, I want the extraction agent hosted as a single container on an Azure Functions plan that runs custom containers and keeps at least one instance warm, so that the "one new component" commitment holds in production and clinicians never wait on a cold start.

The CTO has been told that Phase 1 adds one container-hosted Azure Function and nothing else, so this ticket treats that as a boundary. Among the Functions plans, only Premium (Elastic Premium) and Dedicated (App Service plan) run a custom container; Consumption and Flex Consumption do not. Those two plans can keep an instance always ready, which keeps Node.js and LangChain start-up off the first clinician's request of the day. That instance is billed all the time, so the plan and its standing cost are presented together at architecture review.

**Scope**

- in: the hosting plan for the one new compute component, the always-ready and prewarmed instance counts, the Functions entrypoint that puts the agent's routes on the host, the deployed health probe, a check that no second compute or data resource appears.
- out: the gateway, the .NET 8 App Service, Azure SQL, Azure OpenAI and Key Vault (they exist and are only called); the AI table DDL (Epic 2); the agent, guards and validators (Epics 4–8); the endpoint contract (Epic 9); span content and the dashboard (Epic 10); Redis and the memory layer (Phase 2).

**Acceptance criteria**

- An infrastructure change that puts the Function App on Consumption (Y1) fails validation with "Consumption plan does not support custom container images".
- An infrastructure change that puts it on Flex Consumption fails validation with "Flex Consumption does not support custom container images".
- A Premium (EPx) or Dedicated plan passes validation and deploys.
- `siteConfig.minimumElasticInstanceCount` (always-ready instances) is at least 1 and comes from an environment parameter, never a bare number in the template.
- `siteConfig.preWarmedInstanceCount` (the scale-out buffer, a separate setting) is set from a recorded cold-start measurement of this image on the chosen plan, kept with its value and date, and recorded apart from the always-ready count.
- Listing the resources tagged to this project finds exactly one net-new compute resource. The gateway, the .NET 8 App Service, Azure OpenAI and Key Vault appear only as existing, unchanged resources.
- A traced request passes the existing gateway, then the .NET 8 App Service (which still does authentication, tenancy scoping and rate limiting), and only then the Function.
- The AI-schema tables (Epic 2) resolve to the existing Azure SQL database. No new SQL server, elastic pool or other data store was created.

**Technical notes**

- The Functions entrypoint (proposed `src/functions/`) registers routes with `app.http` from `@azure/functions` and sets the log level from `settings().logLevel`, as `src/server.ts` does locally. `src/server.ts` and `PORT` stay local; the host chooses its own port.
- The Functions worker has a 60-second start limit that cannot be changed. Importing the tree builds nothing and does no I/O, and there is no top-level `await`, so start-up stays well inside it.
- An HTTP response must finish within 230 seconds whatever `functionTimeout` says: that is the platform load balancer's limit, and past it the caller gets HTTP 502 while the function runs on. One model attempt may wait 300 seconds today and the client retries twice, so the request budget must be brought under this limit.
- The SQL pool is closed in an `app.hook.appTerminate` hook. That hook does not run on forced termination, so nothing durable depends on it.
- The platform health probe calls `/health`, which does no I/O. `/health/ready` makes a billed model call on every hit; it is for a person, not a probe.

**Before you build (due diligence)**

- Settle the hosting conflict first. A Web App for Containers image and a pipeline that deploys it to five environments already exist. Decide with the CTO between a Function on Premium and the Web App, and update the architecture document to match.
- Prove streaming end to end on the chosen host. SSE from a Function needs `app.setup({ enableHttpStream: true })`, `@azure/functions` 4.3.0 or later and host runtime 4.28 or later. Check that the gateway and the .NET proxy do not buffer the stream, and whether a stream that keeps sending stays open past 230 seconds.
- Run the compiled ES-module build (`"type": "module"` with `.js` files) under `func start` and in a deployed smoke test. Microsoft documents ES modules on Functions only as `.mjs` files, marked preview.
- Measure cold start on the chosen plan and SKU: a fresh instance's time to its first successful response, first agent compile included. Repeat it when the base image or the dependencies change.
- Find out who owns the client's infrastructure code (Bicep or ARM) and where the plan check can run. The repository holds none today.

---

### PEA-1102

**Title:** Build the image with npm ci and release it through the existing pipeline

**Description:**
As a platform engineer, I want the Function's container image built from the committed lock file and published through the existing Azure DevOps pipeline, so that the dependency set reviewed in CI is exactly what runs in production, with no new deployment mechanism for operations to learn.

The nearest incident risk is not a wrong model answer; it is a shipped image that does not match what was tested. An install that resolves versions at build time can pass CI one day and drift the next with no code change. `npm ci` installs exactly what `package-lock.json` says and refuses a lock file that disagrees with `package.json`. Reusing the existing pipeline means nobody has to staff or debug a second release system.

**Scope**

- in: the Dockerfile (build stage and runtime stage), the pinned base image, the pipeline's build, publish and release steps, release by image digest, a package-set smoke test.
- out: the hosting plan (PEA-1101), app settings and identity (PEA-1103), the network path (PEA-1104).

**Acceptance criteria**

- The build stage runs `npm ci` against the committed `package-lock.json`, and the runtime stage runs `npm ci --omit=dev`.
- The build fails, and no image is published, when the lock file is missing or disagrees with `package.json`.
- Every package in the image matches an entry in the lock file. No package is added by `npm install` or any other step.
- The base image names an exact Node version or a digest, never `latest` and never a moving tag such as `22-alpine`.
- The base image's Node major and the pinned `@azure/functions` version are chosen together, and both are recorded in the Dockerfile and `package.json`.
- A release publishes the image through the existing Azure DevOps pipeline definitions to the existing Azure Container Registry. No second registry, pipeline system or manual path is added.
- The release step points the Function App at the digest it just published, never at a mutable tag.
- A pipeline smoke test compares the deployed image's installed packages with the lock file.

**Technical notes**

- Two stages: the build stage runs `npm ci` and `npm run build` (`tsc` with `noEmitOnError`, then `tsc-alias` to rewrite the `#` aliases); the runtime stage copies only `dist/` and the runtime dependencies, and runs as a non-root user with `node` as process 1.
- The Functions base images are `mcr.microsoft.com/azure-functions/node:4-node22` and `:4-node24`. There are no `-slim` tags for 22 or 24, so the pin is a digest.
- `.dockerignore` keeps every `.env*` file out of the image. `settings()` reads `.env.local` from beside the code, so a copied file would ship secrets and could switch the deployed service onto the API-key branch.
- `engines.node` stays `>=22.13`. The runtime image's Node must satisfy it, and the unit suite runs on the same major the image ships.

**Before you build (due diligence)**

- Read the existing image pipeline end to end. It builds once and promotes the same image through five environments, which this ticket wants. It also pushes a `latest` tag, restarts the app so it pulls that tag, and logs in to the registry with an admin password. List what changes for digest release and an identity-based pull.
- Choose one Node major for build, test and runtime. Functions supports Node 22 until 2027-04-30 and Node 24 until 2028-04-30. The current image ships 22 and the tests run on 24.
- Prove that `npm ci --omit=dev` installs every runtime import, by importing the built entrypoint inside the image. A package our code imports must be a direct dependency.
- Decide whether the pipeline runs `npm test` before the image build. Today a type error stops the build, but a failing unit test does not.
- Confirm that the Function App accepts an image reference by digest (`@sha256:`) and that the release identity can set it. To verify.

---

### PEA-1103

**Title:** Authenticate to SQL, Key Vault, Blob and Azure OpenAI with managed identity

**Description:**
As a compliance officer, I want the Function to reach Azure SQL, Key Vault, Blob Storage and Azure OpenAI as itself, with no password, key or connection secret in its configuration, so that a leaked app setting or config file opens no path into clinical data.

Today's system has a hard-coded API key and looks up a model key in the database on each request; this deployment retires that pattern. With managed identity there is no secret to steal, so a config leak, a source-control accident or a departing contractor's laptop exposes nothing. Every other control in this project, from masking to validation and audit, assumes this one holds.

**Scope**

- in: managed-identity authentication from the deployed service to Azure OpenAI, Azure SQL, Key Vault and Blob Storage; the role assignments it needs; a scan of deployed app settings; live checks in the deployed environment.
- out: the network path (PEA-1104); validating inbound bearer tokens (Epic 1, wired in Epic 9); the Key Vault and storage resources themselves (they exist).

**Acceptance criteria**

- With the Cognitive Services OpenAI User role on the service's identity, every model call carries a Bearer token for the `https://cognitiveservices.azure.com/.default` scope and no `api-key` header.
- No `AZURE_OPENAI_API_KEY` value is set in the deployed app settings.
- The SQL pool authenticates as `azure-active-directory-default` (with the identity's client id when it is user-assigned). The deployed settings hold no `AZURE_SQL_USER` or `AZURE_SQL_PASSWORD`, and no user name, password or access key of any kind.
- Key Vault is reached through a `SecretClient` built from the vault URL and the service's credential, never from a connection string or access key.
- Blob Storage is reached through a `BlobServiceClient` built from the account URL and the service's credential, never through `BlobServiceClient.fromConnectionString`.
- A deploy-time scan of app settings finds no API key, client secret, password or connection string carrying a key, for any of the four services.
- Live tests in `tests/integration/` make one real call to each of the four services in the deployed environment, using managed identity only.
- Removing the local API-key and SQL-login fallbacks from the code would not change deployed behaviour, because neither is set there.

**Technical notes**

- Azure OpenAI and SQL already work this way in `src/core/llm.ts` and `src/core/database.ts`: `DefaultAzureCredential` with `managedIdentityClientId` from `settings().azureClientId`, and `getBearerTokenProvider` feeding `azureADTokenProvider`. The API key and the SQL login are local-development fallbacks only.
- `settings()` chooses the API-key branch whenever `AZURE_OPENAI_API_KEY` is set, so the deployed check is simply that it is not set.
- SQL takes an `authentication` object, never a connection string. The ODBC form `Authentication=ActiveDirectoryMsi` must not be copied across: mssql parses it as a SQL login.
- Key Vault (`@azure/keyvault-secrets`) and Blob Storage (`@azure/storage-blob`) are not installed yet. Each client is a lazy getter on the singleton that owns it: built on first use, reused after, and never built at import.
- Every import counts against the Functions worker's 60-second start limit, which is one more reason no client is built at import.

**Before you build (due diligence)**

- Confirm which Phase 1 features actually read Key Vault or Blob Storage. No code does today. Add each client with the feature that first needs it.
- Read the `SecretClient` and `BlobServiceClient` constructors in the installed `.d.ts` before writing to them. On npm (2026-10-14) the packages are `@azure/keyvault-secrets` 4.11.2 and `@azure/storage-blob` 12.34.0. To verify.
- Decide system-assigned or user-assigned identity per environment. A user-assigned identity needs `AZURE_CLIENT_ID`; a system-assigned one needs it unset.
- `DefaultAzureCredential` tries environment credentials before managed identity, so a stray `AZURE_CLIENT_SECRET` in app settings would win without a word. Add it to the scan, and consider `AZURE_TOKEN_CREDENTIALS=ManagedIdentityCredential` in deployed settings. To verify on the installed `@azure/identity`.
- Confirm with the client's DBA that the identity exists as a database user in each environment, with only the roles the service needs.

---

### PEA-1104

**Title:** Reach Azure OpenAI only through a private endpoint

**Description:**
As a compliance officer, I want every call from the Function to Azure OpenAI to travel over a private endpoint rather than the public internet, so that a clinical note on its way to the model never crosses a public network path.

Masking (Epic 5) protects identifiers inside the payload; this ticket protects the wire the payload travels on. A masked note is still clinical content, and it must stay inside the client's private network on its way to the model. The ticket is small in points and large in what the network diagram has to show a security reviewer.

**Scope**

- in: VNet integration of the Function, the private endpoint and private DNS for Azure OpenAI, public network access disabled on the resource, an infrastructure check that fails a change removing either.
- out: the Azure OpenAI resource itself (it exists); authentication (PEA-1103).

**Acceptance criteria**

- The Function is VNet-integrated into the subnet that reaches the Azure OpenAI private endpoint.
- From inside the Function's network, the Azure OpenAI hostname resolves to a private IP address in that VNet.
- The Azure OpenAI resource has public network access disabled and answers only through the private endpoint.
- An infrastructure change that removes the Function's VNet integration fails validation, naming the lost private path to Azure OpenAI as the reason.
- An infrastructure change that re-enables public network access fails validation.
- The setup is reviewed against the epic's network diagram before sign-off.

**Technical notes**

- VNet integration needs Premium or Dedicated (PEA-1101); the old Consumption plan has none, so the two constraints reinforce each other. A Premium plan's subnet needs at least 100 free addresses.
- This is a network control, separate from managed identity (PEA-1103). Losing it is a network exposure, not an authentication failure, and an incident review keeps the two apart.
- A refused network shows up as HTTP 403 ("Access denied due to Virtual Network/Firewall rules"). The readiness check reports it as `HTTP 403`, and the live tests skip with that reason.

**Before you build (due diligence)**

- Find out how the DEV Azure OpenAI resource is locked today. It answers HTTP 403 to networks outside its rules, which points to selected networks rather than public access disabled. Confirm whether a private endpoint and a private DNS zone already exist, and in which VNet.
- Plan developer and CI access before public access is turned off: the integration tests and the accuracy suite call the DEV deployment from laptops today. Choose between VPN with private DNS, a build agent inside the VNet, or a DEV-only exception.
- Treat Azure SQL the same way. A laptop reaches DEV SQL through its firewall allow-list today. Decide whether the Function reaches SQL through a private endpoint too, and test it with the same DNS check.
- Confirm the Azure OpenAI resource's region and deployment type, and that the model the client wants is deployable there with enough quota. gpt-4.1 is closed to new customers and retires on 2027-04-14. Newer models reach Global Standard before Data Zone or regional deployments, and PHI may require Data Zone. A model in another resource needs its own private endpoint.

---

### PEA-1105

**Title:** Export the Function's traces to the existing Application Insights instance

**Description:**
As a platform engineer, I want the Function's OpenTelemetry traces exported to the client's existing Application Insights instance, configured as credential-free as everything else in this epic, so that every run is visible where the operations team already looks, with nothing new to stand up.

What a span records about a run (run id, prompt hash, model, tokens, per-field decisions) belongs to Epic 10. This ticket is narrower and easy to get wrong under deadline pressure: point the export at the existing resource, not a new one, and source its connection string the same way as everything else here. A second telemetry resource created by accident, or a connection string pasted in to make a demo work, stays invisible until the next environment promotion breaks.

**Scope**

- in: OpenTelemetry export from the Functions host and from our code to the existing Application Insights resource; the connection string as a `settings()` field whose deployed value comes from Key Vault; a negative PHI test on span attributes.
- out: span and attribute content and the dashboard (Epic 10); the Application Insights resource itself (it exists).

**Acceptance criteria**

- After an extraction request completes, its trace appears in the client's existing Application Insights resource.
- No new Application Insights or Log Analytics resource was created for this epic.
- The connection string reaches the code only as a `settings()` field whose deployed value comes from Key Vault. No module holds a connection-string literal.
- Telemetry is set up once, at process start, before the first request.
- For a run on a note with a seeded patient identifier, no span attribute contains the identifier or any other raw clinical value.
- A live test in `tests/integration/` finds the trace of a real run in the existing instance.

**Technical notes**

- On Functions, `"telemetryMode": "OpenTelemetry"` in `host.json` exports the host's telemetry, and our code adds `@azure/functions-opentelemetry-instrumentation` with the Azure Monitor exporter. On another host, an Azure Monitor OpenTelemetry distro does the same job.
- The exporter libraries read `APPLICATIONINSIGHTS_CONNECTION_STRING` from the environment on their own. Pass it explicitly from `settings()`, as every Azure field is passed explicitly elsewhere.
- The Functions host forwards everything written to stdout, so pino's JSON lines reach Application Insights too. They carry fields only, never clinical text.
- An ES-module app must load the instrumentation before the modules it instruments, with a `node --import` preload.
- The LangSmith and LangChain tracing variables stay refused by `settings()`: they send prompts to a host outside Azure.

**Before you build (due diligence)**

- Choose the package set and check its maturity. On npm (2026-10-14), `@azure/monitor-opentelemetry-exporter` is still `1.0.0-beta.32` and `@azure/functions-opentelemetry-instrumentation` is `0.3.0`; the distros are `@azure/monitor-opentelemetry` 1.20.1 and `@microsoft/opentelemetry` 1.5.0. All need Node 22 or later. To verify against the installed `.d.ts`.
- Decide how the connection string comes from Key Vault: a Key Vault reference in app settings needs no code, while a read at start needs PEA-1103's `SecretClient`. Decide also whether ingestion requires Entra authentication.
- Microsoft recommends one Application Insights resource per app. Sharing the existing one needs a distinct cloud role name (`OTEL_SERVICE_NAME`), so confirm the sharing with the operations team.
- Check what the auto-instrumentations record (HTTP URLs, SQL statement text, request bodies) and include their spans in the PHI test, not only our own.
- Measure whether pino lines from our code are correlated with the invocation's trace on the host. Nobody has measured it yet.

---

### PEA-1106

**Title:** Run real traffic in shadow mode and gate cutover on a measured exit bar

**Description:**
As an AI/clinical admin, I want the extraction agent to run against real production traffic in shadow mode, deciding every field but writing nothing to the chart, and to require a stated, measured bar before it may write anything, so that going live is a deliberate, evidenced decision instead of a deadline.

Before cutover, a wrong value costs a bad number in a report. After cutover, it costs a clinical chart entry. That is why the bar for ending shadow mode is a number the code checks, not a feeling reported in a status meeting. Ending shadow mode is the moment clinical risk stops being zero, so it is a logged, criteria-gated action and never a quiet flag flip.

**Scope**

- in: the `EXTRACTION_MODE` setting, the shadow gate in the outcome hook, the off-path comparison job, the exit-bar constants, the cutover check and its audit record, an operator runbook.
- out: the run and proposal tables (Epic 2), the commit to the encounter form (Epic 9), the metrics dashboard (Epic 10), enabling one template or account at a time (not in this epic).

**Acceptance criteria**

- With `EXTRACTION_MODE` set to `shadow`, a run for an encounter finalised through the existing path goes through the full guard, validation and outcome pipeline, writes its run row and proposal rows as usual, and writes no value to any clinical encounter field.
- In shadow mode, any attempt to write a clinical encounter field is blocked, resets the shadow clock (consecutive days and encounter count) to zero, and is recorded as a release-blocking defect.
- After 9 consecutive days and 500 encounters in shadow, a cutover attempt is refused and names the unmet criterion: "9 of 14 required consecutive days".
- Cutover succeeds only when all of these hold at once: at least 14 consecutive days; at least 500 encounters; field-level agreement of at least 90% with the value finally committed through the existing path; a block rate of at most 5% of fields decided; an evidence-bound rate of at least 98% for FOUND values; zero clinical writes in the whole window; and recorded sign-offs from a named clinical safety reviewer and the engineering lead.
- The cutover event, the metrics at that moment and both sign-offs are written to the audit trail together with the flip.
- The first run after the recorded cutover time is the first whose validated fields may commit. Every earlier run stays, in the audit trail, a shadow run that wrote nothing clinical.
- `tests/integration/` covers four cases: a shadow run writes nothing clinical, a forced write resets the clock, a premature cutover is refused with its reason, and cutover succeeds once every threshold and both sign-offs hold.
- A runbook tells an operator how to read the current shadow metrics and how to perform the flip.

**Technical notes**

- `EXTRACTION_MODE` is one zod entry in `src/core/settings.ts`: `shadow` or `live`, default `shadow`. No code branches on an environment name.
- The gate sits in the outcome middleware's `afterAgent` (`src/agents/middleware/outcome.ts`), the only `afterAgent` in the spine. Epic 9 adds the commit to that hook; in shadow mode the commit is a no-op, and the existing path keeps owning the chart.
- The comparison runs off the request path as a scheduled batch. It reads the agent's proposals against the values committed through the existing flow once each encounter is finalised, and it adds no column to an Epic 2 table.
- The exit-bar constants live in one module, each with its reasoning as a comment: `SHADOW_MIN_DAYS` 14, `SHADOW_MIN_ENCOUNTERS` 500 (a deliberate fraction of the ~1,000 AI-assisted encounters a day), `SHADOW_MIN_FIELD_AGREEMENT_RATE` 0.90, `SHADOW_MAX_BLOCK_RATE` 0.05, `SHADOW_MIN_EVIDENCE_BOUND_RATE` 0.98, `SHADOW_MAX_WRITES` 0. Changing one is a clinical-safety decision, not a review comment.
- The flip is a deliberate operator action that checks the bar and both sign-offs. It is never a scheduled job. `settings()` is read once per process, so a mode change takes effect on restart.
- The evidence-bound rate reads the evidence middleware's per-slot match (`src/agents/middleware/evidence.ts`). Shadow runs keep every masking and audit duty of live runs.

**Before you build (due diligence)**

- Confirm the exit bar with the client against their feedback of 2026-10-12: recall now matters more than precision. One agreement rate hides that trade-off, so decide whether the bar states recall and precision separately. The accuracy suite measured 78.4% recall and 90.8% precision on five reference queries.
- Decide where the scheduled comparison runs. On Functions, a timer trigger in the same Function App keeps one compute component (check `app.timer` in the installed `@azure/functions`). A Web App has no built-in scheduler.
- Decide how a refused flip is enforced. Anyone with portal rights can change an app setting, so the service must treat `live` as shadow until a valid cutover record exists.
- Decide whether a model, prompt or template change during the window resets the clock, given the client wants the latest models.
- Confirm with the data owners where the finally committed value of each field lives, and that the run and proposal tables exist in each environment. The code does not create them yet.

---

## Part 2 — Status and tracking

| Ticket | Status | Points | Depends on | Delivered (files / tests / PR) | Changed from the Python ticket | Open items |
|---|---|---|---|---|---|---|
| PEA-1101 | Not started (later sprint) | 5 | — (uses Epic 1 PEA-101, PEA-107) | Nothing for the Function design: no Function App, no `src/functions/`, no `@azure/functions` dependency, no `host.json`, no IaC in the repository. `.gitignore` already ignores `local.settings.json`. Related but on a different host: the Web App image and pipeline (PEA-1102 row). | Node.js and LangChain JS start-up replaces Python import cost. The "four Phase 1 AI tables" (`promptFragment`, `fieldConstraint`, `agentRun`, `fieldOutcome`) became "the AI-schema tables Epic 2 creates" (see Notes). Learn (updated 2026-09-18) also lists Azure Container Apps as a GA host for a Functions container; the "only Premium or Dedicated" rule holds for the Functions plans. Adds the deployed-probe decision Epic 1 PEA-107 handed to this epic. Gherkin became checkable bullets. | Hosting conflict with the Web App (Notes, decision 1). Request budget against 230 s (decision 2). ES modules on the Functions host are unverified (truth §16 #2). Cold start was measured only on the local demo container on 2026-10-12: `start` event 4.81 s cold vs 2.94 s warm, first field 11.06 s vs 6.56 s (`docs/2026-10-12-streaming-api.md`, Evidence); not on any plan. |
| PEA-1102 | Partly done | 3 | PEA-1101 | `Dockerfile` (two stages on `node:22-alpine`: `npm ci` + `npm run build`, then `npm ci --omit=dev`, `USER node`, `CMD ["node", "dist/server.js"]`), `.dockerignore`, `pipelines/pacehr-ai-docker-images.yml`, `pipelines/templates/push-image-stage.yml`, `pipelines/variables/{dev,qa,uat,preprod,prod}-environment.yml`. Builds once, saves a TAR artifact, promotes DEV → QA → UAT → PreProd → Production into each environment's ACR (`thesnfist{d,q,u,preprod,p}eastus2acr`) and runs `az webapp restart` on `pacehr-{d,q,u,preprod,p}-aiengine-app`. Merged in PR 12453 (squash `3e49236`, 2026-10-09) on `PacEHR-AI-Develop-Main`. | `uv sync --frozen` became `npm ci` (which refuses a lock that disagrees with `package.json`). The Python-patch and `azure-functions` 1.25/2.x coupling became the Node major plus `@azure/functions` (4.16.5 on npm; HTTP streams need 4.3.0+), on `4-node22` or `4-node24` base images. What exists targets Web App for Containers, not a Function App. | Base image floats on `node:22-alpine` (the file's own `ponytail:` comment defers the digest). Release pushes `$(Build.BuildId)` and `latest`, and the app pulls `latest` on restart: not a digest. Registry login uses the ACR admin user and a secret password variable, not an identity. The pipeline is `trigger: none` and runs no `npm test`. No package-set smoke test. PreProd and Production share service connection `newthsnfistsc` (open point in the PR). The image ships Node 22; the unit suite ran on Node 24.18.0. The image serves only `/health` and `/health/ready` (`src/core/app.ts`); no extraction route exists yet. |
| PEA-1103 | Partly done | 5 | PEA-1101 | Azure OpenAI: `src/core/llm.ts` (`DefaultAzureCredential` with `managedIdentityClientId`, `getBearerTokenProvider` → `azureADTokenProvider`; API-key fallback). SQL: `src/core/database.ts` (`azure-active-directory-default` with optional `clientId`; SQL-login fallback). Unit: `tests/unit/core/llm.test.ts`, `llm.api-key.test.ts`, `database.test.ts`, `database.system-identity.test.ts`, `database.sql-login.test.ts`. Live: `tests/integration/core/llm.test.ts`, `tests/integration/core/database.test.ts` (they use whatever credential the machine has). Epic 1 PEA-103/104, merged in PR 12410. `npm test` 151 of 151 on Node 24.18.0, run 2026-10-14 on `3p-dev/epic-4-agent-core`. | `get_bearer_token_provider` became `getBearerTokenProvider`. The ODBC `Authentication=ActiveDirectoryMsi` connection string became an mssql `authentication` object: mssql parses the ODBC form as a SQL login (truth §9.1, §15). `cached_property` with a thread lock became a lazy self-overwriting getter, which needs no lock (truth §14.9). `asyncio.to_thread` is gone: the driver is asynchronous. | Key Vault and Blob Storage: no package, no code, no consumer. No deployed-settings scan. No live test runs inside a deployed environment. PR 12453 states the Web App uses its system-assigned identity; that cannot be checked from the repository. `DefaultAzureCredential` puts `EnvironmentCredential` first (truth §8). |
| PEA-1104 | Not started (later sprint) | 2 | PEA-1101 | Nothing in the repository; network configuration lives outside it. | Language-neutral, so the ticket is unchanged in substance. The due diligence adds Azure SQL's private path, laptop and CI access, and the model's region and deployment type. | The DEV Azure OpenAI resource answered HTTP 403 ("Virtual Network/Firewall rules") to developer networks from 2026-09-29. The live provider tests passed on 2026-10-13 and the accuracy suite on 2026-10-14 from the developer machine (Epic 4 notes), so DEV admits an allow-listed network and is not private-only. Region and quota: see decision 4. |
| PEA-1105 | Not started (later sprint) | 3 | PEA-1103; Epic 10 for span content | No telemetry package or code. pino writes JSON to stdout (`src/core/logging.ts`, Epic 1). | `configure_azure_monitor` became host-level `telemetryMode: OpenTelemetry` plus worker instrumentation on Functions, or a JS distro elsewhere. The connection string is passed explicitly from `settings()` because the libraries read the environment on their own. ES modules need a `node --import` preload (Learn, Enable OpenTelemetry, updated 2026-10-09). | The Functions-recommended Node exporter is still beta. pino-to-invocation correlation is unmeasured (truth §16 #6). Option E of the observability brainstorm (App Insights + OpenTelemetry, in tenant) is the path this ticket wires (`docs/2026-10-13-recall-observability-brainstorm.md` §5). |
| PEA-1106 | Not started (later sprint) | 8 | PEA-1101 to PEA-1105; Epic 2 run and proposal tables; Epic 9 commit; Epic 6 evidence check | No `EXTRACTION_MODE`, no exit-bar constants, no comparison job, no cutover check. The hook it extends exists: `src/agents/middleware/outcome.ts` (only `afterAgent`); the evidence middleware `src/agents/middleware/evidence.ts` exists on `3p-dev/epic-4-agent-core` (commit `89099ab`, 2026-10-14). | `Settings.EXTRACTION_MODE: Literal[...]` became a zod enum entry in `settings.ts`. `after_agent` became the outcome middleware's `afterAgent`. pytest became `node:test` under `tests/integration/`. | The exit bar predates the 2026-10-12 recall-first feedback (decision 5). Per-template or per-account enablement is the SOP's largest scope gap (decision 6). The run and proposal tables exist on no branch (Notes). |

Total: 26 points (5 + 3 + 5 + 2 + 3 + 8), equal to the Python epic. Status: 2 partly done, 4 not started.

### Notes

**What changed from the Python edition, epic-wide**

| Python edition | TypeScript edition |
|---|---|
| Python image with LangChain imports, `uv sync --frozen`, `uv.lock` | Node image, `npm ci` from `package-lock.json`, `npm ci --omit=dev` at runtime |
| `mcr.microsoft.com/azure-functions/python:4-python3.12` and the `azure-functions` 1.25/2.x line | `mcr.microsoft.com/azure-functions/node:4-node22` or `:4-node24` (no `-slim` tags) and `@azure/functions` 4.x; Node 22 supported to 2027-04-30, 24 to 2028-04-30 (truth §13) |
| `function_app.py` | a Functions entrypoint registering `app.http` routes (proposed `src/functions/`); `src/server.ts` stays the local entrypoint and the only reader of `PORT` |
| `get_bearer_token_provider`, `ManagedIdentityCredential` | `getBearerTokenProvider`, `DefaultAzureCredential` with `managedIdentityClientId` (already built in Epic 1) |
| ODBC `Authentication=ActiveDirectoryMsi` | mssql `authentication: { type: 'azure-active-directory-default' }`; the ODBC string is banned (truth §15) |
| `cached_property` + thread lock | lazy getter that overwrites itself; no lock needed |
| `configure_azure_monitor()` | `host.json` `telemetryMode` + `@azure/functions-opentelemetry-instrumentation`, or an Azure Monitor JS distro; connection string passed from `settings()` |
| `Settings.EXTRACTION_MODE: Literal`, `after_agent` | zod entry in `src/core/settings.ts`; outcome middleware `afterAgent` |
| pytest, `tests/integration/` | `node:test` with `node:assert/strict`, same tier folders |

**State of the repository** (`/Users/akash.saxena/saisystem/projects/PacEHR_AI`, checked 2026-10-14)

- The checkout is on `3p-dev/epic-4-agent-core` at `89099ab` (2026-10-14), up to date with its remote, working tree clean. The Epic 4 work that earlier notes call "uncommitted" is in that commit.
- The brief's "unmerged branch" is merged. `git log PacEHR-AI-Develop-Main..origin/feature/docker-webapp-pipeline` lists 11 commits only because the branch was squash-merged as PR 12453 (`3e49236`, 2026-10-09). `git diff --stat PacEHR-AI-Develop-Main origin/feature/docker-webapp-pipeline -- Dockerfile .dockerignore pipelines` is empty.
- So the Web App path is on the main development line, not a side branch. `Dockerfile` is the Web App production image (`node:22-alpine`, compiled `dist/server.js`). The demo image is now `Dockerfile.stream` (`node:24.18.0-slim`, runs `tests/manual/streamServer.manual.ts` through `tsx`, `PORT=3100`), added in `89099ab`. It is not the production image.
- Verified in code: `PORT` is read only by `src/server.ts` (comment in `src/core/settings.ts`: "the Functions host chooses its own port"); `src/server.ts` closes the pool on SIGINT and SIGTERM only if it was built; no module under `src/` has a top-level `await`.
- No branch creates `AI.agentRun` or `AI.fieldOutcome` (`git grep agentRun` over `src` and `migrations` on every local and remote branch: 0 files). Main's AITP-68 migrations (PR 12745) create `AI.EncounterSummary`, `AI.PatientSummary`, `AI.ClinicianSummary`, `AI.EncounterTranscript`, `AI.EncounterFieldReview` and a usage view. The Epic 2 design (`docs/Epic-02-AI-Engine-Handover-and-Data-Design.md`) names `agentRun`, `fieldOutcome`, `fieldState` and others. Epic 2 owns reconciling the two; PEA-1101 and PEA-1106 only depend on the result.

**Decisions and conflicts the team must resolve**

1. **Function on Premium, or Web App for Containers.** The CTO document (`docs/pacEHR-Azure-Deployment-Architecture.md`, 2026-09-18) promises "one dockerized Azure Function". PR 12453 ships an image and a pipeline for five Web Apps (`pacehr-*-aiengine-app` in `thesnfist-*-eastus2-pacehr`). Either keeps one new compute component, but they differ. A Function on Premium brings always-ready and prewarmed instances, a timer trigger for the PEA-1106 comparison job, SSE through `enableHttpStream`, a 60-second worker start limit, ES modules documented only as `.mjs` preview, and a Functions base image. The Web App brings the plain `node:http` server the demo already streams from, Always On, no built-in scheduler, and a pipeline that is already wired. Both share the 230-second HTTP limit, VNet integration, private endpoints and managed identity. If the team keeps the Web App, PEA-1101's plan checks re-target to the App Service plan SKU and Always On, and the CTO document changes. That document's §3 also says Flex Consumption runs custom containers; Learn says it does not ("Container support: None", updated 2026-09-18).
2. **Request budget against 230 seconds.** `src/core/llm.ts` allows 300 s per model attempt with `MAX_RETRIES` 2, so a stalled run can wait about 900 s. The slowest measured model call was 88.7 s for 6,599 output tokens (2026-10-09, comment in `llm.ts`). Decide whether to lower the per-attempt timeout, cut retries for the HTTP path, or rely on a stream that keeps sending (unverified on either host). Reasoning models add reasoning tokens and change this budget again.
3. **Inbound access.** Epic 11 secures only egress (`docs/tickets/GAPS.md` §2 item 24). Decide the Function's `authLevel` or the Web App's access restrictions or inbound private endpoint, and where `entraAuthenticator` (Epic 1, wired to no route yet) runs. Agree the .NET proxy contract (GAPS §3 item 6), including that it neither buffers SSE nor times out first.
4. **Model availability, region and quota.** The pipeline's resources are in East US 2. gpt-4.1 is closed to new customers and retires 2027-04-14, and the client wants the latest models (`docs/2026-10-13-single-vs-multi-agent.md` §5). Confirm the Azure OpenAI resource's region, deployment type (Global, Data Zone or regional, which matters for PHI residency) and TPM quota. Capacity, quota and a spend ceiling have no story yet (GAPS §3 item 5), nor do BAA and residency evidence (item 7).
5. **The exit bar against recall-first feedback.** The bar uses one agreement rate. The client now weights recall over precision, and the observability brainstorm sets the guardrail that recall never moves alone (`docs/2026-10-13-recall-observability-brainstorm.md` §3). It also proposes the shadow comparison against `Log.AILogs` (§2.3, S7). Measured so far: recall 78.4%, precision 90.8% (`npm run eval`, 2026-10-14, Epic 4 PEA-408); 54 of 240 supported items missed over 3 runs, against the current system's 13 of 80 (`docs/2026-10-12-five-query-comparison.md`). The client and the clinical safety reviewer set the numbers.
6. **One global switch.** `EXTRACTION_MODE` is all-or-nothing and changes on restart. The SOP asks for auto-fill switched on per category once it meets a threshold, and for pilot accounts (`docs/tickets/SOP-COVERAGE.md` §2, 2.3 and §10, 10.1). GAPS §3 item 2 asks for per-template enablement and a runtime off switch. Neither is in this epic's agenda; decide whether it becomes a new story.
7. **Library facts still to verify** before code depends on them: ES modules on the Functions host (truth §16 #2); `app.timer` and `enableHttpStream` in the installed `@azure/functions`; `SecretClient`, `BlobServiceClient` and the OpenTelemetry packages in their installed `.d.ts`; `AZURE_TOKEN_CREDENTIALS` on `@azure/identity` 4.13.3 against the managed-identity endpoint; release by digest on the Function App.

**Sources read for this edition**

- Microsoft Learn: Functions hosting options (updated 2026-09-18), Premium plan (2026-07-14), Node.js developer reference (2026-09-16), OpenTelemetry with Functions (2026-06-15), Enable OpenTelemetry in Application Insights (2026-10-09).
- npm registry (`npm view`, 2026-10-14): `@azure/functions` 4.16.5, `@azure/keyvault-secrets` 4.11.2, `@azure/storage-blob` 12.34.0, `@azure/monitor-opentelemetry` 1.20.1, `@microsoft/opentelemetry` 1.5.0, `@azure/functions-opentelemetry-instrumentation` 0.3.0, `@azure/monitor-opentelemetry-exporter` 1.0.0-beta.32. None of these is installed in `PacEHR_AI`.
