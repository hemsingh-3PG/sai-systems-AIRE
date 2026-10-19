# System Overview — Diagrams

**Source**: `docs/architecture/current/00-system-overview.md` (2026-10-19)
**Purpose**: human-readable preview of every Mermaid diagram in the overview.

---

## System Context & Containers

```mermaid
flowchart TB
  subgraph Client["Browser"]
    SPA["Angular 18 SPA<br/>340 components / 304 standalone<br/>54 feature folders"]
  end

  subgraph Azure["Azure"]
    API["PacEHR.API<br/>ASP.NET Core 8<br/>100 controllers, ~1,039 endpoints"]
    FUNC["PacEHR.Functions.Process<br/>Isolated worker, 5 timer triggers"]
    AISVC["pacEHR_AI<br/>Node 22 / TypeScript<br/>LangChain agent, /health only"]
    SIGR["SignalR services<br/>(external repos)"]
  end

  subgraph Data["Data Tier"]
    SQL[("SQL Server<br/>PacEHR schema: 1,132 table scripts<br/>1,602 procedure scripts")]
    AISQL[("AI schema<br/>same Azure SQL database<br/>10 migrations")]
    REDIS[("Redis<br/>PCC token + response cache")]
    COSMOS[("Cosmos DB<br/>PCC request/response logs")]
    BLOB[("Azure Blob Storage")]
    LAW[("Log Analytics")]
  end

  subgraph Ext["External Systems"]
    PCC["PointClickCare"]
    MC["MatrixCare"]
    DRF["DrFirst (eRx)"]
    UPD["Updox"]
    IMO["IMO terminology"]
    HL7["HL7 ADT feeds"]
    TW["Twilio"]
    SG["SendGrid / SMTP"]
    PBI["Power BI Embedded"]
    GSP["Google Cloud Speech"]
    OAI["OpenAI (legacy prompt path)"]
    DRG["Dragon Copilot<br/>dictation SDK"]
    AOAI["Azure OpenAI<br/>gpt-4.1"]
    ENTRA["Microsoft Entra ID<br/>JWKS"]
  end

  SPA -->|"HTTPS JSON + AES payload encryption"| API
  SPA -->|WebSocket| SIGR
  SPA -->|"WebSocket audio"| API
  SPA -->|"SDK, token from API"| DRG

  API --> SQL
  API --> REDIS
  API --> COSMOS
  API --> BLOB
  API --> LAW
  API -->|"Service Bus queues"| FUNC
  FUNC --> SQL

  API --> PCC
  API --> MC
  API --> DRF
  API --> UPD
  API --> IMO
  API --> HL7
  API --> TW
  API --> SG
  API --> PBI
  API --> GSP
  API --> OAI

  AISVC --> AISQL
  AISVC -->|"managed identity"| AOAI
  AISVC -.->|"verifies bearer JWT"| ENTRA
  AISQL -.- SQL
  SPA -. "no caller yet" .-> AISVC
```

## Backend Layer Structure

```mermaid
flowchart TB
  C["PacEHR.API<br/>Controllers · Filters · Middleware · Hubs"]
  DS["pacEHR.DomainServices<br/>109 service files"]
  DSI["pacEHR.DomainServices.Interfaces<br/>122 files"]
  PCCS["pacEHR.PCC.Services<br/>PointClickCare client"]
  DTO["pacEHR.Data.Dtos<br/>330 files"]
  DATA["PacEHR.Data<br/>928 EF Core models + generated proc context"]
  DB["PacEHR.Database (SSDT)<br/>3,046 .sql files"]

  C --> DSI
  DSI -.implemented by.-> DS
  DS --> DATA
  DS --> PCCS
  C --> DTO
  DS --> DTO
  DATA --> DB
```

## PacEHR_AI Agent Middleware Spine

```mermaid
flowchart LR
  REQ["EncounterRequest<br/>note + context"] --> G
  subgraph Spine["Agent middleware spine — src/agents/middleware"]
    G["guardMiddleware<br/>beforeAgent<br/>injection scan · size limit · PHI mask seam"]
    M["modelCallMiddleware<br/>wrapModelCall<br/>the only model call"]
    E["evidenceMiddleware<br/>afterModel<br/>value bound to note → HIGH/MEDIUM/LOW"]
    O["outcomeMiddleware<br/>afterAgent<br/>tags how the run ended"]
    G --> M --> E --> O
  end
  M --> LLM["AzureChatOpenAI<br/>gpt-4.1, temperature 0<br/>DefaultAzureCredential"]
  G -. "blocked: INJECTION_BLOCKED / size" .-> O
  SCH["schema/builder<br/>template → response schema"] --> M
  O --> OUT["EncounterResult<br/>invoke or per-field stream"]
  G --> DBW[("AI schema<br/>audit rows")]
  SVC["templateService · summaryService<br/>patientManager · clinicianManager"] --> REPO["repositories<br/>mssql"] --> DBW
```

