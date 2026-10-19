# Epic 11 — Azure Deployment & Operations

**Epic id:** E11 · **Phase:** 1 · **Stories:** PEA-1101..PEA-1106 · **Points:** 26

## Goal

One dockerized Azure Function is the only new thing this project adds to the customer's
Azure subscription, and when this epic is done it is running on a plan that can host it,
authenticating everywhere as itself, reachable to Azure OpenAI only over a private path,
and traced into the tenant's existing observability. Real production traffic has flowed
through it in shadow mode against a stated, measured bar before it is ever allowed to
write a single value to a patient chart.

## Scope

**In:** the hosting topology and plan for the one new compute component; the container
build-and-release pipeline; Managed Identity from the Function to SQL, Key Vault, Blob
Storage and Azure OpenAI; the Private Endpoint network path to Azure OpenAI; wiring
traces to the existing Application Insights instance; the shadow-mode rollout mechanism
and the measurable bar that gates cutover.

**Out:** the API gateway, the .NET 8 App Service, the SQL Server instance, the Azure
OpenAI resource, and Key Vault itself — all already exist in the customer's subscription
and appear here only as dependencies this Function calls. The DDL for the four `AI`
tables (Epic 02). The agent pipeline, guards and validators that run inside the Function
(Epics 04–08). The two endpoints' request/response contract (Epic 09). Trace span
content and the operational dashboard (Epic 10). Redis prompt caching and the
memory/learning layer are Phase 2 — deferred entirely, not built here.

## Dependencies

Epic 01 (repository foundation) must exist to have a Python service to containerize.
Epic 09 (HITL review & API surface) owns the two endpoints this Function serves. Epic 02
(data layer) owns the DDL for the four `AI` tables this deployment's SQL access reaches.
Epics 04–08 (agent core, guardrails, tools, prompts, validation) own the pipeline that
runs inside this Function; this epic hosts it, it does not build it. Epic 10
(observability & evaluation) owns the trace span content and the operational dashboard
that reads the shadow-mode and production metrics this epic's tracing wiring makes
possible.

---

### PEA-1101 — Host the extraction agent as the one new Azure Function, on a plan that can run a container

**Type:** Story · **Epic:** E11 · **Phase:** 1 · **Points:** 5
**Depends on:** none · **Satisfies:** REQ-11-01, REQ-11-02, REQ-11-03, REQ-11-09, REQ-11-10, REQ-11-11

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want the extraction agent hosted as a single dockerized Azure
Function on a plan that supports custom containers and keeps at least one instance warm,
so that the CTO's "one new component" commitment holds in production and clinicians
never wait on a cold start.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The CTO has already been told the Phase 1 story: one dockerized Azure Function runs the
extraction agent, everything else already exists. That sentence only stays true if this
ticket enforces it as a boundary, not a suggestion — the gateway, the .NET 8 App Service,
the SQL database, Azure OpenAI, and Key Vault are dependencies this Function calls, never
components this epic rebuilds or duplicates.

The container-image decision has a hosting-plan consequence and a cost consequence that
belong in the same conversation, not fifty pages apart. A custom container image cannot
run on the Azure Functions Consumption plan, and it cannot run on Flex Consumption
either — Microsoft Learn documents Flex Consumption's container support as "None": code
only, container not supported. **A Functions-hosted custom container runs on Premium
(Elastic Premium) or Dedicated (App Service Plan) only** (verified 2026-09-23 against
`00-langchain-api-truth.md` §11.6 trap 5) — stated here plainly so it is never
rediscovered the hard way, during a deployment window. Either of those two plans is what
makes an always-ready instance possible, and an always-ready instance is what removes the
multi-second cold start of importing Python plus LangChain before the first clinician of
the day gets a response. That instance is billed continuously, whether or not a clinician
presses the AI button at 3 a.m. — this is a standing operating cost, not a one-time build
cost, and it is owed to the CTO at architecture review, not discovered on the first
monthly invoice.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The hosting plan is rejected if it cannot run a custom container
  Given an infrastructure change proposing the Function App's hosting plan
   When the plan SKU is Consumption (Y1)
   Then the deployment fails validation
    And the failure reason states "Consumption plan does not support custom container images"

Scenario: A qualifying plan is accepted
  Given an infrastructure change proposing the Function App's hosting plan
   When the plan SKU is Premium (EPx) or Dedicated (App Service Plan)
   Then the deployment proceeds

Scenario: Flex Consumption is rejected too — it cannot run a custom container either
  Given an infrastructure change proposing the Function App's hosting plan
   When the plan SKU is Flex Consumption
   Then the deployment fails validation
    And the failure reason states "Flex Consumption does not support custom container
        images"

Scenario: At least one instance stays warm
  Given the Function App is deployed on a qualifying plan
   When `siteConfig.minimumElasticInstanceCount` — the always-ready instance count — is
        read from the plan configuration
   Then it is at least 1

Scenario: The scale-out buffer is set from a measurement, not left at its default
  Given the Function App is deployed on a qualifying plan
   When `siteConfig.preWarmedInstanceCount` — the buffer of instances warmed during
        scale-out, a different setting from the always-ready count — is read
   Then its value is backed by a recorded cold-start measurement of this image

Scenario: No second new compute component appears
  Given the full set of Azure resources tagged to this project
   When resources are enumerated
   Then exactly one net-new compute resource exists — the extraction agent's Function App
    And the API gateway, the .NET 8 App Service, Azure OpenAI, and Key Vault are present
        only as pre-existing resources, unmodified in kind

Scenario: The existing request path is unchanged in front of the new Function
  Given a clinician's browser calls the existing encounter API
   When the request is traced end to end
   Then it passes through the existing API gateway, then the existing .NET 8 App Service
        acting as a thin proxy
    And the .NET 8 App Service still performs authentication, tenancy scoping and rate
        limiting
    And only then does the request reach the new Function

Scenario: The four Phase 1 AI tables add no new data store
  Given the deployed environment's data resources
   When resources are enumerated
   Then `AI.promptFragment`, `AI.fieldConstraint`, `AI.agentRun`, and `AI.fieldOutcome`
        all resolve to the existing SQL Server instance
    And no new Azure SQL server, elastic pool, or alternate data store resource was
        created to host them
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- **Hosting plan is Premium (Elastic Premium) or Dedicated (App Service Plan) — the only
  two that run a custom container image.** Flex Consumption does not qualify: Microsoft
  Learn documents its container support as "None" — code-only, container not supported
  (verified, `00-langchain-api-truth.md` §11.6 trap 5). Flex Consumption is out alongside
  Consumption (Y1), not an alternative to it; this is a category constraint the infra
  pipeline enforces, not a preference stated in a README.
- ⚠️ **230 seconds is a hard ceiling on any HTTP response from this Function, whatever
  `functionTimeout` is set to** — it is the platform Load Balancer's own idle timeout, not
  a setting this project controls. Past 230 seconds the caller receives HTTP 502 and the
  function keeps running with nowhere left to reply (verified,
  `00-langchain-api-truth.md` §11.6 trap 1). Every extraction request — the guard, model
  and validation pipeline behind `POST /ai/encounter/extract` and
  `POST /ai/encounter/resolve` that Epics 04–09 build — must complete and reply inside
  that budget; raising `functionTimeout` cannot buy back time past 230 seconds.
- The always-ready instance count is `siteConfig.minimumElasticInstanceCount`: instances
  the app runs on continuously regardless of load, maximum 20 per app, and the plan's billed
  minimum. It is an infra parameter, minimum 1, never a bare number in a template — per
  `CLAUDE.md` § Numbers. That floor of 1 is as far as documentation goes:
  Microsoft describes custom-container cold start only as "a long warm-up time" and
  publishes no number for a Python image carrying LangChain (verified,
  `00-langchain-api-truth.md` §11.6 trap 6 and §10 #12). Any count above the floor of 1 is
  therefore a measured decision, not an asserted one — measure this image's actual
  cold-start latency (a freshly started instance's time to first successful response,
  agent-compile cost included) against the chosen plan before setting
  `minimumElasticInstanceCount` above 1, and repeat the measurement whenever the base
  image or the dependency set changes materially.
- ⚠️ `siteConfig.preWarmedInstanceCount` is a **different setting** and is not a synonym for
  the always-ready count (`00-langchain-api-truth.md` §11.6 trap 7): it is the buffer of
  instances warmed ahead of a scale-out, it defaults to 1, and it is not settable in the
  portal. It is the one Learn points at for a custom container, whose warm-up is long (trap
  6), so it is the setting to raise when scale-out latency is the problem rather than the
  first request of the day. Both counts come from the same measurement and neither is
  asserted from documentation (§10 #12).
- Cost is continuous, not incremental to usage: an always-ready instance is billed
  whether or not the AI button is pressed. This plan and its standing cost are stated
  together, not left as a footnote for someone to discover later.
- The Angular SPA is unchanged and not redeployed by this epic (REQ-11-09) — out of
  scope, named only as a boundary.
- The API gateway and the .NET 8 App Service keep doing what they already do — TLS,
  routing, rate limiting, authentication, tenancy scoping. This epic adds a callee behind
  them, not a replacement for them.
- The four Phase 1 `AI` tables (Epic 02) live inside the existing SQL Server; this
  ticket's job is to confirm no new data-store resource is provisioned for them, not to
  author their DDL.
- Performance: the always-ready instance is the direct mitigation REQ-11-03 exists for —
  it removes LangChain's multi-second import time from landing on a clinician's request.
- Security/API impact: none beyond what PEA-1103/PEA-1104 own; this ticket is topology,
  not identity or network path.

#### 5. Definition of Done (DoD) Checklist

- [ ] Infra template (Bicep/ARM, matching the existing pipeline's IaC convention) defines
      the Function App on a Premium (Elastic Premium) or Dedicated (App Service Plan) plan
- [ ] A policy/lint check fails the deploy if the plan SKU is Consumption (Y1) or Flex
      Consumption — neither supports a custom container image
- [ ] `minimumElasticInstanceCount` is an infra parameter, minimum 1, sourced from
      environment configuration — not a bare literal in the template
- [ ] Any `minimumElasticInstanceCount` above the floor of 1 is backed by a recorded
      cold-start measurement of this image on the chosen plan (value and date), not
      asserted from documentation, which publishes no cold-start number for a custom
      container
- [ ] `preWarmedInstanceCount` is set from that same measurement and is recorded separately
      from `minimumElasticInstanceCount`, never as one combined number
- [ ] Resource inventory / tagging confirms exactly one net-new compute resource for this
      project
- [ ] Integration test confirms the existing gateway → App Service → Function path is
      unchanged and still enforces auth, tenancy and rate limiting ahead of the Function
- [ ] Confirms the four `AI` tables resolve to the existing SQL Server (no new
      server/data-store resource created)
- [ ] Reviewed against `CLAUDE.md` § Numbers for both instance-count parameters

---

### PEA-1102 — Build the container image with `uv` and release it through the existing pipeline

**Type:** Story · **Epic:** E11 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-1101 · **Satisfies:** REQ-11-04, REQ-11-12

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want the Function's container image built with `uv` from the
committed lockfile and published through the existing Azure DevOps pipeline, so that the
dependency set reviewed in CI is byte-for-byte what runs in production, with no new
deployment mechanism for the operations team to learn.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The nearest-term incident risk here isn't "the model is wrong," it's "the shipped image
doesn't match what anyone tested." A container that installs from a floating dependency
spec at build time can pass CI on Tuesday and drift silently by Wednesday with no code
change at all. Pinning `uv.lock` into the image build makes the dependency set
reviewable, and reusing the Azure DevOps pipeline the rest of this codebase already
deploys through means no new release tooling for anyone to staff or debug at 2 a.m.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The image build honours the committed lockfile
  Given a commit containing pyproject.toml and uv.lock
   When the CI pipeline builds the container image
   Then the build runs `uv sync --frozen` (or equivalent) against uv.lock
    And the build fails if uv.lock is missing or out of sync with pyproject.toml

Scenario: No dependency is installed outside the lockfile
  Given the built image
   When the installed package set is compared against uv.lock
   Then every installed package and version matches an entry in uv.lock
    And no package was installed by a separate pip install step

Scenario: The runtime version is pinned, not floating
  Given the Dockerfile's base image line
   When the tag is inspected
   Then it names an exact Python patch version
    And it is not "latest" or a bare major.minor floating tag

Scenario: Release uses the existing pipeline, not a new one
  Given a merge to the release branch
   When the pipeline runs
   Then the image is published to the existing Azure Container Registry using the
        existing Azure DevOps pipeline definitions
    And the deployed Function App is updated to reference the new image by exact digest,
        not by a mutable tag

Scenario: A broken lockfile blocks release before it reaches production
  Given uv.lock does not resolve against pyproject.toml
   When the pipeline runs
   Then the build stage fails
    And no image is published
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- `uv` manages dependencies per `CLAUDE.md` § Configuration: add packages to
  `pyproject.toml`, commit `uv.lock`, never `pip install` into the running environment.
  The image build is where this rule is enforced, not just a developer's laptop.
- The Dockerfile pins an exact Python patch version as its base image tag; a floating tag
  is a promise that today's build and next month's build are the same image when they
  are not.
- ⚠️ **The base image's Python version and the pinned `azure-functions` package line are
  one decision, made together, not left to a resolver.** `azure-functions` 2.x (`2.3.0`)
  requires Python 3.13+; 1.25.0 is the line for Python 3.10–3.12; either satisfies the v2
  programming model's own floor of `azure-functions>=1.11.1` (verified,
  `00-langchain-api-truth.md` §11.6 trap 11). The base image named for this project,
  `mcr.microsoft.com/azure-functions/python:4-python3.12` (trap 10), pins the 1.25.0 line;
  moving the Dockerfile to a `python3.13` image is only valid alongside moving
  `pyproject.toml` to the 2.x line at the same time. `pyproject.toml` pins
  `requires-python = ">=3.10"` with no upper bound, so nothing in the dependency spec
  itself stops a resolver from choosing an `azure-functions` line the base image cannot
  run — this ticket pins the image tag and the `azure-functions` constraint together as
  one build decision.
- Deploy-by-digest, not by mutable tag: the Function App's image reference is the
  specific digest the pipeline just published, so "what passed CI" and "what's running"
  cannot silently diverge between two builds that happen to share a tag.
- No new deployment pattern: this extends the existing Azure DevOps pipeline's
  build-and-publish step; it does not introduce a second CI system, a second registry, or
  a manual deployment path.
- Security: this ticket's whole purpose is supply-chain integrity — making the shipped
  artifact traceable to a reviewed commit. No UI/UX impact.

#### 5. Definition of Done (DoD) Checklist

- [ ] Dockerfile builds via `uv sync --frozen` against the committed `uv.lock`
- [ ] CI fails the build when `uv.lock` is missing or out of sync with `pyproject.toml`
- [ ] Dockerfile base image tag names an exact Python patch version, never `latest`
- [ ] The base image's Python version and the pinned `azure-functions` package line are
      chosen together (2.x only with a 3.13+ image, 1.25.0 with a 3.10–3.12 image) and
      both are recorded in the Dockerfile / `pyproject.toml` — not left for the resolver
      to decide under the repository's open-ended `requires-python = ">=3.10"`
- [ ] Pipeline publishes to the existing Azure Container Registry via the existing Azure
      DevOps pipeline definitions — no new registry, no new pipeline system
- [ ] Release step updates the Function App to an image digest, not a mutable tag
- [ ] A pipeline smoke test confirms the deployed image's installed package set matches
      `uv.lock`

---

### PEA-1103 — Authenticate to SQL, Key Vault, Blob Storage and Azure OpenAI as the Function's own identity

**Type:** Story · **Epic:** E11 · **Phase:** 1 · **Points:** 5
**Depends on:** PEA-1101 · **Satisfies:** REQ-11-05, REQ-11-06

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want the Function to reach SQL, Key Vault, Blob Storage and
Azure OpenAI as itself, with no password, key or connection secret anywhere in its
configuration, so that a leaked app setting or a compromised config file reveals no path
into clinical data.

#### 2. Business Context & Problem Statement (Why are we doing this?)

The current system's known failure mode is a hardcoded API key and a per-request
database lookup of a model key — exactly the pattern this deployment retires. Managed
Identity removes the credential from the blast radius of a config leak, a source-control
accident, or a departing contractor's laptop entirely: there is no secret to steal,
because there is no secret. This is table stakes for a system that authenticates to a
clinical database as itself, and it is the one security property every other guarantee in
this project — masking, validation, audit — assumes already holds.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The Function reaches Azure OpenAI with a Managed Identity token
  Given the Function's system-assigned identity has the Cognitive Services OpenAI User role
   When it calls Azure OpenAI
   Then the request is authenticated by a bearer token obtained through
        get_bearer_token_provider against the "https://cognitiveservices.azure.com/.default" scope
    And no AZURE_OPENAI_API_KEY value is present in the deployed app settings

Scenario: The Function reaches SQL with no embedded credential
  Given the deployed connection string
   When it is inspected
   Then it contains Authentication=ActiveDirectoryMsi, a server name, and a database name
    And it contains no Uid, Pwd, or access-key parameter of any kind

Scenario: The Function reaches Key Vault as itself
  Given the Function's Managed Identity has a Key Vault access policy or RBAC role scoped
        to the secrets it needs
   When it constructs a SecretClient
   Then the client is built with vault_url and the Function's own credential, never a Key
        Vault connection string or access key

Scenario: The Function reaches Blob Storage as itself
  Given the Function's Managed Identity has an appropriate Storage Blob Data role
   When it constructs a BlobServiceClient
   Then the client is built from account_url and the Function's own credential, never
        from_connection_string with an account key

Scenario: A key-based fallback is not the deployed path
  Given the deployed Function's app settings
   When they are scanned for credential-shaped values
   Then no connection string, API key, or access key for SQL, Key Vault, Blob Storage, or
        Azure OpenAI is present
    And removing any developer-only local API-key fallback from the codebase does not
        change deployed behavior
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Credential classes are `ManagedIdentityCredential` (`azure.identity`) for a deployed-only
  path, or `DefaultAzureCredential` where the same module also runs on a developer
  machine, per `CLAUDE.md` § Configuration and `00-langchain-api-truth.md` §7.
  `ManagedIdentityCredential` defaults to the system-assigned identity; pass `client_id`
  only if a user-assigned identity is in use.
- Azure OpenAI: `get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")`
  feeds `AzureChatOpenAI(azure_ad_token_provider=...)` — the managed-identity path the API
  truth file names explicitly. `api_key` / `AZURE_OPENAI_API_KEY` is a local-development
  fallback only, never a deployed value.
- SQL: `mssql_python` has no credential-free connection form — Managed Identity for Azure
  SQL is expressed as a connection-string parameter, `Authentication=ActiveDirectoryMsi`
  (per `00-langchain-api-truth.md` §7), not as a stored secret. This is the one place
  where "no connection string" means "no connection string carrying a credential" rather
  than "no connection string at all" — what remains carries a server name, a database
  name, and an auth-mode flag, and the driver exchanges that for a token at call time.
  Because Azure SQL has no native async driver, any async call site on top of this
  connection is `asyncio.to_thread` around the blocking `mssql_python` call, never a
  native `async`/`await` driver.
- Key Vault: `SecretClient(vault_url=..., credential=...)` from `azure.keyvault.secrets`
  (`azure.keyvault.secrets.aio` for the async form).
- Blob Storage: `BlobServiceClient(account_url=..., credential=...)` from
  `azure.storage.blob` — never `.from_connection_string`, which is exactly the
  connection-string-with-embedded-key form this story exists to remove. Blob Storage is
  reached wherever this service reads or writes document content (`core/documents`, per
  the repository's folder schema).
- Singletons: each client is a `cached_property` on the module-level manager that owns
  it, per `CLAUDE.md` § Singletons — `__init__` touches no network, first use builds the
  client, the process reuses it. ⚠️ This is a deployment constraint, not only a style
  rule: the Azure Functions Python worker has a **60-second, non-configurable ceiling to
  start**, and everything that runs at module scope — every import, and any client built
  eagerly instead of lazily — is spent inside that same budget (verified,
  `00-langchain-api-truth.md` §11.6 trap 3). A credential or client constructed in
  `__init__` rather than deferred to a `cached_property` is exactly the kind of
  module-scope work that can push a cold start past 60 seconds and fail the worker
  outright, not just run slowly.
- Security: this is the control every masking and audit guarantee in the project assumes
  holds. A credential leak here is not a bug in this ticket alone — it bypasses every
  downstream protection.

#### 5. Definition of Done (DoD) Checklist

- [ ] Azure OpenAI client is built with `azure_ad_token_provider` from
      `get_bearer_token_provider`, not `api_key`, in the deployed configuration
- [ ] SQL connection string template contains `Authentication=ActiveDirectoryMsi` and no
      `Uid`/`Pwd`
- [ ] Key Vault access goes through `SecretClient(vault_url=..., credential=...)`
- [ ] Blob Storage access goes through `BlobServiceClient(account_url=..., credential=...)`,
      never `from_connection_string`
- [ ] `tests/integration/` asserts a real call succeeds against each of SQL, Key Vault,
      Blob Storage and Azure OpenAI using only Managed Identity in the deployed
      environment
- [ ] A deploy-time or CI scan confirms no credential-shaped app setting (API key,
      connection string with `Pwd`/account key) is present
- [ ] Reviewed against `CLAUDE.md` § Singletons for client construction

---

### PEA-1104 — Reach Azure OpenAI only through a Private Endpoint

**Type:** Story · **Epic:** E11 · **Phase:** 1 · **Points:** 2
**Depends on:** PEA-1101 · **Satisfies:** REQ-11-07

#### 1. User Story (As a... I want... So that...)

As a compliance officer, I want every call from the Function to Azure OpenAI to travel
over a Private Endpoint rather than the public internet, so that a clinical note in
transit to the model never crosses a public network path.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Masking protects identifiers inside the payload (Epic 05); this ticket protects the wire
the payload travels on. Even a masked clinical note is still clinical content, and the
expectation this deployment must meet is that it never leaves the tenant's private
network boundary on its way to the model. This is a small ticket in points and a large
one in what a network diagram has to show a security reviewer.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: The Function's calls to Azure OpenAI resolve to a private address
  Given the Function is VNet-integrated into the subnet holding the Private Endpoint
   When it resolves the Azure OpenAI endpoint hostname
   Then the hostname resolves to a private IP address inside that VNet

Scenario: The Azure OpenAI resource is not reachable from the public internet
  Given the Azure OpenAI resource's public network access setting
   When it is inspected
   Then public network access is disabled, and the resource is reachable only through the
        Private Endpoint

Scenario: A misconfigured deploy that removes VNet integration is caught before release
  Given an infrastructure change that removes the Function's VNet integration
   When the change is validated
   Then validation fails, naming the loss of the Private Endpoint path to Azure OpenAI as
        the reason
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Requires the Function to be VNet-integrated, which the plan chosen in PEA-1101
  (Premium or Dedicated) supports and Consumption does not — the two constraints
  reinforce each other.
- Azure OpenAI itself is a pre-existing resource (named as a dependency, not built here);
  this ticket's scope is the network path to it, not the resource.
- Security: this is a network-layer control, independent of and in addition to the
  Managed Identity authentication in PEA-1103 — losing this path is a network exposure,
  not an authentication failure, and the two must not be conflated in an incident review.
- No UI/UX or performance impact beyond the network hop already implied by VNet
  integration.

#### 5. Definition of Done (DoD) Checklist

- [ ] Function is VNet-integrated into the subnet holding the Azure OpenAI Private
      Endpoint
- [ ] Azure OpenAI resource has public network access disabled
- [ ] DNS resolution test confirms the Azure OpenAI hostname resolves privately from
      inside the Function's network context
- [ ] Infra validation fails a change that would remove VNet integration or re-enable
      public access
- [ ] Reviewed against the epic's network diagram before sign-off

---

### PEA-1105 — Wire the Function's traces into the existing Application Insights instance

**Type:** Story · **Epic:** E11 · **Phase:** 1 · **Points:** 3
**Depends on:** PEA-1103 · **Satisfies:** REQ-11-08

#### 1. User Story (As a... I want... So that...)

As a platform engineer, I want the Function's OpenTelemetry traces exported to the
tenant's existing Application Insights instance, authenticated and configured the same
way every other credential in this service is, so that every run is observable in the one
place the operations team already looks, with nothing new to stand up.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Observability content — what a span records about a run, a prompt hash, a per-field
verdict — belongs to Epic 10. What belongs here is narrower and easy to get wrong under
deadline pressure: pointing the export at the tenant's own, already-running Application
Insights resource, not a new one, and sourcing its connection string the same
credential-free way as everything else in this epic. Standing up a second telemetry
resource by accident, or hardcoding a connection string to make a demo work, is the kind
of shortcut that stays invisible until the next environment promotion breaks silently.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Traces land in the existing Application Insights instance
  Given the Function processes an encounter extraction request
   When the run completes
   Then a trace appears in the tenant's existing Application Insights resource
    And no new Application Insights or Log Analytics resource was provisioned for this
        epic

Scenario: The connection string is not a literal in source
  Given the Function's telemetry configuration
   When the codebase and deployed app settings are inspected
   Then the Application Insights connection string appears only as a Settings field
        sourced from Key Vault
    And no connection string literal appears in any module

Scenario: A clinical value never reaches a span attribute
  Given a run that processes a note containing a patient identifier
   When the resulting trace is inspected
   Then no span attribute contains the identifier or any other raw clinical value
    And per CLAUDE.md, only tokens or non-clinical metadata appear
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Entry point is `configure_azure_monitor` (`azure-monitor-opentelemetry`), called once at
  process start, reading `APPLICATIONINSIGHTS_CONNECTION_STRING` — per `CLAUDE.md` §
  Configuration that value is a `Settings` field, not a literal, and per REQ-11-06 it is
  sourced from Key Vault via the `SecretClient` wired in PEA-1103, not a bare app setting.
- The Application Insights instance is a pre-existing dependency (named in the epic's
  Dependencies, not built here); this ticket configures the Function to export to it, and
  its DoD includes a check specifically for a second instance being stood up by accident.
- Span and attribute *content* — run id, prompt hash, model identity, token counts,
  latency, per-field decisions — is Epic 10's contract; this ticket does not define new
  attributes, it makes sure the pipe those attributes travel through is configured,
  authenticated, and pointed at the right existing resource.
- PHI: per `CLAUDE.md`'s clinical rule, a trace logs the token, never the value — the DoD
  includes the negative test, not just the positive one.

#### 5. Definition of Done (DoD) Checklist

- [ ] `configure_azure_monitor()` is called once, at process start, reading the
      Application Insights connection string from a `Settings` field
- [ ] The connection string's value is sourced from Key Vault via the `SecretClient` from
      PEA-1103, not hardcoded or a raw app setting
- [ ] Infra review confirms exactly zero new Application Insights or Log Analytics
      resources were created for this epic
- [ ] `tests/integration/` confirms a trace reaches the existing instance for a real run
- [ ] A test asserts no raw clinical value or identifier appears in any span attribute
- [ ] Reviewed against `CLAUDE.md` § Clinical and PHI rules

---

### PEA-1106 — Run real traffic in shadow mode and gate cutover on a measured exit bar

**Type:** Story · **Epic:** E11 · **Phase:** 1 · **Points:** 8
**Depends on:** PEA-1101, PEA-1102, PEA-1103, PEA-1104, PEA-1105 · **Satisfies:** REQ-11-01, REQ-11-08

#### 1. User Story (As a... I want... So that...)

As an AI/clinical admin, I want the extraction agent to run against real production
traffic in shadow mode — deciding every field but writing nothing to the chart — and to
require a stated, measured bar before it is allowed to write anything, so that going live
is a deliberate, evidenced decision instead of a deadline.

#### 2. Business Context & Problem Statement (Why are we doing this?)

Before cutover, a wrong verdict costs a bad number in a report. After cutover, it costs a
clinical chart entry. That asymmetry is the entire reason this ticket exists, and it is
why the bar for ending shadow mode has to be a number the code checks, not a feeling
someone reports in a status meeting. Ending shadow mode without a stated, measurable exit
bar is the single largest delivery risk in this epic — it is the exact moment clinical
risk stops being zero. This ticket makes that moment a deliberate, logged, criteria-gated
action rather than a quiet flag flip.

#### 3. Acceptance Criteria (Written in Given-When-Then / Gherkin format)

```gherkin
Scenario: Shadow mode processes real traffic without writing to the chart
  Given EXTRACTION_MODE is "shadow"
    And a clinician finalizes a dictated note through the existing (live) path
   When the extraction agent processes the same encounter in shadow
   Then the agent runs the full guard, validation and verdict pipeline
    And an AI.agentRun row and AI.fieldOutcome proposal rows are written as usual
    And no value is written to any clinical encounter field

Scenario: A shadow-mode write is a hard failure, not a warning
  Given EXTRACTION_MODE is "shadow"
   When any code path attempts to write a value to a clinical encounter field
   Then the write is blocked
    And the shadow-mode clock (consecutive days and encounter count) resets to zero
    And the incident is recorded as a release-blocking defect

Scenario: Cutover is refused before the exit bar is met
  Given EXTRACTION_MODE is "shadow"
    And shadow traffic has run for 9 consecutive days across 500 encounters
   When an operator attempts to flip EXTRACTION_MODE to "live"
   Then the flip is refused
    And the refusal names the unmet criterion: "9 of 14 required consecutive days"

Scenario: Cutover is permitted once every threshold holds at once
  Given EXTRACTION_MODE is "shadow"
    And shadow traffic has run for at least 14 consecutive days across at least 500
        encounters
    And the field-level agreement rate against the value ultimately committed through the
        legacy path is at least 90%
    And the block rate across all fields decided is at most 5%
    And the evidence-bound rate for FOUND values is at least 98%
    And zero clinical-table writes occurred during the entire shadow window
    And a named clinical safety reviewer and the engineering lead have both recorded
        sign-off
   When an operator flips EXTRACTION_MODE to "live"
   Then the flip succeeds
    And the cutover event, the metrics at the time of cutover, and both sign-offs are
        written to the audit trail

Scenario: The first value reaches a chart only after cutover
  Given EXTRACTION_MODE was flipped to "live" at a recorded timestamp
   When the next encounter is processed
   Then this is the first run whose validated fields are permitted to commit to the
        encounter form
    And every run before that timestamp remains, in the audit trail, a shadow run that
        wrote nothing clinical
```

#### 4. Technical Considerations & Constraints (Security, performance, UI/UX, or API impacts)

- Mode is `Settings.EXTRACTION_MODE: Literal["shadow", "live"]`, defaulting to `"shadow"`
  — a config field per `CLAUDE.md` § Configuration, never a branch on an environment
  name.
- `after_agent` checks this flag as its last step: in `shadow`, every other behavior in
  the pipeline is unchanged, and the encounter-form commit call is replaced with a no-op;
  the legacy path continues to own the chart, untouched, for the whole shadow window.
- The comparison job runs off the request's hot path — a scheduled batch reading
  `AI.fieldOutcome` proposals (Epic 02) against the corresponding value in the existing,
  unchanged clinical tables once each source encounter is finalized through the legacy
  flow. It requires no new column on an Epic 02 table: shadow mode changes what is
  committed, not what is recorded.
- Exit-bar constants — `SHADOW_MIN_DAYS = 14`, `SHADOW_MIN_ENCOUNTERS = 500`,
  `SHADOW_MIN_FIELD_AGREEMENT_RATE = 0.90`, `SHADOW_MAX_BLOCK_RATE = 0.05`,
  `SHADOW_MIN_EVIDENCE_BOUND_RATE = 0.98`, `SHADOW_MAX_WRITES = 0` — are named module
  constants, each carrying this reasoning as its comment, per `CLAUDE.md` § Numbers. 500
  encounters is a deliberate fraction of the fleet's documented steady-state volume
  (~1,000 AI-assisted encounters/day), not an assumption that shadow traffic starts at
  full fleet scale. They are the release gate this ticket defines; changing any of them is
  a product/clinical-safety decision, not a code review comment.
- The cutover flip is a deliberate, logged operator action gated by a precondition check
  the code enforces — it is never a scheduled job that flips itself, and it is never
  permitted on numbers alone: a recorded sign-off from a named clinical safety reviewer
  and the engineering lead is a separate, non-numeric condition the flip also checks.
- Depends on every other story in this epic: shadow traffic must travel over the real
  hosting, image, identity, network and tracing path this epic builds, or the shadow
  signal proves nothing about production.
- Security/PHI: shadow runs carry the same PHI-masking and audit obligations as live runs
  (Epic 05) — running silently relaxes none of them.

#### 5. Definition of Done (DoD) Checklist

- [ ] `Settings.EXTRACTION_MODE` field exists, defaults to `"shadow"`, and gates the
      commit step in `after_agent`
- [ ] A shadow-mode write to any clinical encounter field is blocked by test, not by
      convention, and resets the shadow clock
- [ ] Exit-bar constants (`SHADOW_MIN_DAYS`, `SHADOW_MIN_ENCOUNTERS`,
      `SHADOW_MIN_FIELD_AGREEMENT_RATE`, `SHADOW_MAX_BLOCK_RATE`,
      `SHADOW_MIN_EVIDENCE_BOUND_RATE`, `SHADOW_MAX_WRITES`) are module constants, each
      commented with the reasoning above
- [ ] Cutover precondition check refuses the flip and names the unmet criterion when any
      threshold is not met
- [ ] Cutover succeeds only when every threshold holds simultaneously and both named
      sign-offs are recorded
- [ ] Cutover event, metrics snapshot, and both sign-offs are written to the audit trail
      atomically with the flip
- [ ] `tests/integration/` covers: a shadow run writes nothing clinical, a forced write
      resets the clock, premature cutover is refused with a named reason, cutover
      succeeds once all thresholds and sign-offs hold
- [ ] A runbook documents how an operator reads current shadow metrics and performs the
      flip
