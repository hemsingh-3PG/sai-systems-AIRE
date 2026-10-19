# PacEHR — Test Infrastructure & CI/CD Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/11-test-infrastructure-cicd-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. The deploy path — no quality gate

Both deploy pipelines go from build to production with no test, lint or smoke step.

```mermaid
flowchart LR
  A["Push to release/dev|qa|uat|production|automation"] --> B["Notify Pipeline Started"]
  B --> C["Prepare environment-specific appsettings.json<br/>(PowerShell rewrite)"]
  C --> D["dotnet publish"]
  D --> E["PublishBuildArtifacts"]
  E --> F["Stop Azure Web App + staging slot"]
  F --> G["AzureRmWebAppDeployment"]
  G --> H["Start Web App + staging slot"]
  H --> I["Notify Pipeline Status"]

  style D fill:#ffe6e6
  X["dotnet test — 3,053 tests"]:::missing -.->|NOT PRESENT| D
  Y["ng test / ng lint"]:::missing -.->|NOT PRESENT| D
  Z["Playwright smoke"]:::missing -.->|NOT PRESENT| G
  classDef missing stroke-dasharray: 5 5,fill:#fff,color:#c00
```

---

## 2. The PR path — may never run

YAML `pr:` triggers are ignored for Azure Repos Git. Two further conditions can skip the tests even when the pipeline does run.

```mermaid
flowchart TB
  A["Developer opens a PR in Azure Repos Git"] --> B{"Does a BRANCH POLICY<br/>reference these pipelines?"}
  B -->|"No — the YAML 'pr:' trigger<br/>is IGNORED for Azure Repos Git"| Z["Nothing runs.<br/>No tests, no checklist, no AI review."]
  B -->|Yes| C["test-validation-pipeline.yml"]
  C --> D["ValidateControllerTestUpdates.ps1<br/>sets ValidateTests.RunTests"]
  D --> E{"RunTests == 'true'?"}
  E -->|no| Y["All remaining steps skipped —<br/>PR passes with zero tests executed"]
  E -->|yes| F["ValidateControllerRouteTests.ps1"]
  F --> G["dotnet restore PacEHR.Tests.UnitTests.csproj"]
  G --> H["dotnet test --filter FullyQualifiedName~ControllerTests<br/>--collect XPlat Code Coverage"]
  H --> I["PublishCodeCoverageResults@2<br/>failIfCoverageEmpty: true"]
  I --> J["PR green"]

  style Z fill:#ffe6e6
  style Y fill:#fff3cd
```

---

## 3. The E2E suite — built, capable, never run by CI

```mermaid
flowchart TB
  A["207 Playwright specs in e2e-playwright/"] --> B["regression/smoke — 38 files<br/>role-scoped: [role:provider] / [role:superadmin]"]
  A --> C["_scripts/ — discovery tooling<br/>crawl-live · discover-interactions · discover-tabs-and-dropdowns<br/>discover-list-filters · discover-write-flows · discover-reports<br/>extract-static-routes · cleanup-smoke-orphans"]
  A --> D["Targeted regression specs<br/>bug-33713 · bug-30701 · PACT2-1200 · PAC-1177 ..."]

  B --> E["npm run test:e2e:smoke<br/>test:e2e:smoke:provider / :superadmin<br/>test:e2e:smoke:csv"]
  E --> F["Custom csv-reporter.mjs<br/>status, duration_seconds, retries, error_first_line"]

  G["CI pipelines"] -.->|"never invoked"| A
  style G stroke-dasharray: 5 5
```

---

**Full analysis**: `docs/architecture/current/11-test-infrastructure-cicd-deep-dive.md`
