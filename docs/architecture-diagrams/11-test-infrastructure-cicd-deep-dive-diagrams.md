# PacEHR — Test Infrastructure & CI/CD Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/11-test-infrastructure-cicd-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. The deploy path - no test gate; production has a slot swap

Neither deploy pipeline runs a test, lint or smoke step. Non-production stops, deploys and starts the app; production deploys to a staging slot, waits for a manual approval, then swaps.

```mermaid
flowchart TB
  A["Push to release/dev|qa|uat|production|automation<br/>or manual run with environment parameter"] --> B["Notify Pipeline Started"]
  B --> C["Prepare environment-specific config<br/>(API: appsettings.json PowerShell rewrite;<br/>UI: environment file rename)"]
  C --> D["Build: dotnet publish / ng build"]
  D --> E["PublishBuildArtifacts"]
  E --> F{"Environment"}
  F -->|"Dev / QA / UAT / Test / Automation"| G["Stop web app<br/>(UI: no stop step)"]
  G --> H["AzureRmWebAppDeployment / AzureWebApp<br/>to the live app"]
  H --> I["Start web app"]
  F -->|Production| J["API: stop staging slot, FTP upload, start staging slot<br/>UI: AzureWebApp to slot 'staging'"]
  J --> K["ManualValidation approval<br/>timeout 1 day, onTimeout reject"]
  K --> L["Swap Slots: staging to production"]
  I --> M["Send Final Pipeline Status"]
  L --> M

  style D fill:#ffe6e6
  X["dotnet test / ng test / ng lint / Playwright smoke"]:::missing -.->|NOT PRESENT| D
  classDef missing stroke-dasharray: 5 5,fill:#fff,color:#c00
```

---

## 2. The PR path (pacEHR_API) - may never run, and runs only controller tests

Needs a branch policy on Azure Repos; skips everything when no controller changed; runs only tests whose name contains ControllerTests.

```mermaid
flowchart TB
  A["Developer opens a PR in Azure Repos Git"] --> B{"Does a BRANCH POLICY<br/>reference these pipelines?"}
  B -->|"No - the YAML 'pr:' trigger<br/>is ignored for Azure Repos Git"| Z["Nothing runs.<br/>No tests, no checklist, no AI review."]
  B -->|Yes| C["test-validation-pipeline.yml"]
  C --> D["ValidateControllerTestUpdates.ps1"]
  D --> D1{"Any file under<br/>PacEHR.API/Controllers changed?"}
  D1 -->|no| Y["RunTests = false:<br/>every later step skipped,<br/>PR passes with zero tests executed"]
  D1 -->|yes| D2{"Does PacEHR.Tests.UnitTests/Controllers/<br/>NameTests.cs exist for each?"}
  D2 -->|"no: exit 1"| X["PR fails: test file missing"]
  D2 -->|yes| E["RunTests = true"]
  E --> F["ValidateControllerRouteTests.ps1<br/>each Route needs a test method prefix"]
  F --> G["dotnet restore + dotnet test<br/>--filter FullyQualifiedName~ControllerTests<br/>--collect XPlat Code Coverage"]
  G --> I["PublishCodeCoverageResults@2<br/>failIfCoverageEmpty: true"]
  I --> J["PR green"]

  style Z fill:#ffe6e6
  style Y fill:#fff3cd
```

---

## 3. The E2E suite (manual)

220 Playwright specs, 35 in the role-scoped smoke suite, plus discovery tooling. No pipeline invokes it.

```mermaid
flowchart TB
  A["220 Playwright specs in PacEHR/e2e-playwright/"] --> B["regression/smoke - 35 files<br/>role-scoped: [role:provider] / [role:superadmin]"]
  A --> C["_scripts/ - discovery tooling<br/>crawl-live, discover-interactions, discover-tabs-and-dropdowns<br/>discover-list-filters, discover-write-flows, discover-reports<br/>extract-static-routes, cleanup-smoke-orphans"]
  A --> D["Ticket-named specs<br/>PAC-1367 engine, PAC-1388, PAC-1057, PAC-1058<br/>PACT2-1187, PACT2-1200, REACTQ-001 ..."]

  B --> E["npm run test:e2e:smoke<br/>:provider / :superadmin / :csv"]
  E --> F["csv-reporter.mjs<br/>status, duration_seconds, retries, error_first_line"]

  G["CI pipelines"] -.->|"never invoked"| A
  style G stroke-dasharray: 5 5
```

---

## 4. pacEHR_AI quality gate - pre-push hook, PR build, eval ledger

Hook runs tests and build, then requires a passing eval run recorded for the exact code hash; the PR pipeline repeats tests and build but not the eval.

```mermaid
flowchart TB
  A["Developer: git push"] --> B[".githooks/pre-push<br/>(installed per clone: npm run hooks:install)"]
  B --> C["npm test<br/>pretest: tsc --noEmit<br/>unit tests with no-network preload<br/>incl. ESLint guards as tests"]
  C --> D["npm run build<br/>tsc + tsc-alias"]
  D --> E{"Push changes src/, cases.json,<br/>queries/ or package-lock.json<br/>vs the remote branch?"}
  E -->|no| P["Push allowed"]
  E -->|yes| F["code-hash.ts: SHA-256 over path + git blob id<br/>of those files in the pushed commit"]
  F --> G{"history.jsonl in the pushed commit has<br/>a run with that codeHash and passed: true?"}
  G -->|yes| P
  G -->|no| X["Push blocked<br/>run npm run eval (VPN, DEV DB, Azure OpenAI)"]
  P --> H["PR to PacEHR-AI-Develop-Main"]
  H --> I{"Build-validation branch policy<br/>configured? (not verifiable)"}
  I -->|yes| J["pr-validation.yml: Node 22, npm ci,<br/>npm test, npm run build<br/>no secrets, no eval"]
  I -->|no| K["No server-side check"]
  L["npm run eval: 5 queries x 3 runs<br/>precision and recall vs benchmark.json, 5-point tolerance"] --> M["Appends history.jsonl;<br/>raises benchmark.json if better (ratchet)"]
  M -.-> G
  Y["--no-verify bypasses the hook"]:::bypass -.-> B
  classDef bypass stroke-dasharray: 5 5,color:#c00
```
