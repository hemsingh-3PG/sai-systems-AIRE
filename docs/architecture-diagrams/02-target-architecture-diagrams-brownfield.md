# Target Architecture Diagrams — PacEHR Encounter Agent, Data Layer (Epic 02)

**Source**: `docs/architecture/design/02-target-architecture-brownfield.md`
**Generated**: 2026-10-05

> Mermaid diagrams extracted from the target architecture document for easy preview.
> Annotations: 🆕 new · 🟡 modified · 🟢 unchanged · 🔴 not built / blocked

---

## Target System Context

```mermaid
flowchart TB
  subgraph Client["Browser — unchanged in this epic"]
    SPA["Angular 18 SPA<br/>🟢 unchanged"]
    REVIEW["review surface<br/>🔴 NOT BUILT — M4/D7"]
  end

  subgraph Existing["Existing deployables — unchanged"]
    API["PacEHR.API<br/>ASP.NET Core 8<br/>🟢 unchanged"]
    AICTRL["AIController + AIPromptServices<br/>🟢 coexists, not migrated"]
  end

  subgraph NewSvc["🆕 PacEHR_AI — Node 22 / TypeScript"]
    HEALTH["core/app.ts<br/>/health · /health/ready"]
    MIG["core/databaseMigrations.ts<br/>MigrationRunner.applyPending()"]
    DB["core/database.ts<br/>execute · run · transaction"]
    REPO["repositories/<br/>one class per AI.* table"]
    AGENT["pacehr/ — agent, tools, prompts<br/>⏳ Epics 4, 7, 8"]
  end

  subgraph Data["Azure SQL — ONE existing production database"]
    AISCH[("🆕 AI schema<br/>agentRun · fieldOutcome<br/>fieldConstraint · fieldDescription")]
    AIPROMPT[("AI.prompt<br/>🟢 legacy, untouched")]
    CLIN[("Existing clinical tables<br/>🟢 READ-ONLY, proven unchanged")]
  end

  AOAI["Azure OpenAI<br/>🆕 BAA + ZDR"]

  SPA --> API
  REVIEW -.->|"no writer exists<br/>fieldOutcome stays half-NULL"| REPO
  API --> AICTRL
  AICTRL --> AIPROMPT
  AICTRL --> CLIN

  MIG --> DB
  REPO --> DB
  AGENT --> REPO
  AGENT -->|"Managed Identity"| AOAI
  DB --> AISCH
  DB -.->|"read only"| CLIN

  style NewSvc fill:#eef,stroke:#446
  style AISCH fill:#dfd,stroke:#080
  style REVIEW fill:#fdd,stroke:#b00,stroke-width:2px
  style CLIN fill:#ffe,stroke:#a80
```

---

## Component Architecture (Target)

```mermaid
flowchart TB
  subgraph entry["Entrypoints"]
    SERVER["src/server.ts<br/>npm start · owns shutdown"]
    MIGRATE["src/migrate.ts<br/>deploy-time · applies and exits"]
  end

  subgraph core["src/core — 🆕 Epic 01, delivered"]
    SET["settings.ts<br/>zod schema · ONLY process.env reader"]
    DBS["database.ts<br/>export const database"]
    MIGR["databaseMigrations.ts<br/>MigrationRunner · batches()"]
    LLM["llm.ts<br/>export const llmManager"]
    AUTH["auth.ts<br/>trust boundary"]
    LOG["logging.ts"]
    ERR["errors.ts<br/>PacEHRError"]
    APP["app.ts<br/>/health · /health/ready"]
  end

  subgraph repos["src/repositories — 🆕 Epic 02"]
    ARW["agentRunWriter<br/>INSERT only"]
    FOR["fieldOutcomeRepository<br/>propose · decide · pending"]
    FCR["fieldConstraintRepository<br/>read by template"]
    FDR["fieldDescriptionRepository<br/>bulk read by template"]
    PFR["promptFragmentRepository<br/>🔴 blocked — ADR-05"]
  end

  subgraph sql["migrations/sql — forward-only"]
    S1["0001 schema"] --> S2["0002 agentRun"] --> S3["0003 fieldOutcome"]
    S3 --> S4["0004 fieldConstraint"] --> S5["0005 fieldDescription"]
    S6["0006 promptFragment<br/>🔴 do not write — ADR-05"]
  end

  MIGRATE --> MIGR
  SERVER --> APP
  MIGR --> DBS
  MIGR -.reads.-> sql
  ARW --> DBS
  FOR --> DBS
  FCR --> DBS
  FDR --> DBS
  DBS --> SET
  LLM --> SET
  APP --> DBS
  APP --> LLM

  style repos fill:#eef,stroke:#446
  style PFR fill:#fdd,stroke:#b00
  style S6 fill:#fdd,stroke:#b00
```

---

## Data Model Changes

```mermaid
erDiagram
  agentRun ||--o{ fieldOutcome : "runID (FK)"
  fieldConstraint }o--|| MAPPING : "templetID+sectionID+fieldID"
  fieldDescription }o--|| MAPPING : "templetID+sectionID+fieldID"

  agentRun {
    bigint runID PK "IDENTITY"
    int encounterID
    int templetID "NULL"
    varchar promptHash "NULL - CK_reachedModel"
    nvarchar modelDeployment "NULL - CK_reachedModel"
    varchar configVersion "NULL"
    int inputTokens "NULL"
    int outputTokens "NULL"
    int latencyMs "NULL"
    varchar outcome "COMMITTED|AWAITING_REVIEW|BLOCKED"
    varchar reasonCode "NULL - CK_blockedHasReason"
    datetime2 createdUtc
  }
  fieldOutcome {
    bigint outcomeID PK "IDENTITY"
    bigint runID FK
    int encounterID
    int templetID
    int sectionID
    int fieldID
    nvarchar proposedValue "NULL"
    nvarchar proposedUnit "NULL"
    varchar proposedStatus "FOUND|ABSENT|ABSTAINED"
    varchar proposedConfidence "HIGH|MEDIUM|LOW"
    nvarchar foundIn "NULL - evidence span"
    varchar verdict "ACCEPT|REVIEW|BLOCK"
    nvarchar reasonCode "NULL"
    nvarchar acceptedValue "NULL - no writer yet"
    nvarchar acceptedUnit "NULL - no writer yet"
    varchar acceptedStatus "NULL - no writer yet"
    int decidedByProviderID "NULL"
    datetime2 decidedAtUtc "NULL"
    datetime2 createdUtc
  }
  fieldConstraint {
    int constraintID PK "IDENTITY"
    int templetID "UQ_mapping"
    int sectionID "UQ_mapping"
    int fieldID "UQ_mapping"
    nvarchar unit "NULL - as authored"
    decimal plausibleMin "NULL - blocks"
    decimal plausibleMax "NULL - blocks"
    decimal abnormalMin "NULL - flags"
    decimal abnormalMax "NULL - flags"
    nvarchar sourceProse "NULL"
    bit isActive
    datetime2 createdUtc
    datetime2 updatedUtc
  }
  fieldDescription {
    int templetID PK
    int sectionID PK
    int fieldID PK
    nvarchar description
    datetime2 createdUtc
    datetime2 updatedUtc
  }
  MAPPING {
    int templetID "Template.* - READ ONLY"
    int sectionID "Template.templateSection - READ ONLY"
    int fieldID "Template.fields - READ ONLY"
  }
```

> `MAPPING` is **not a table**. It is the `(templetID, sectionID, fieldID)` triple identifying a
> field's use within a template, living in existing read-only clinical tables. The two
> configuration tables key on it and hold **no foreign key to it** — a foreign key would be a
> write dependency on tables this service may only read.
