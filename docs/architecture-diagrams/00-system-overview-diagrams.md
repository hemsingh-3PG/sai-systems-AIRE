# PacEHR — System Overview Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/00-system-overview.md`
**Produced by**: ARCHITECT (`aire-brownfield-inspect`, Phase 5)
**Audience**: BA / Product / anyone who wants the pictures without the prose

> These are the Mermaid diagrams extracted verbatim from the system overview. Preview them in any Markdown viewer with Mermaid support (VS Code "Markdown Preview Mermaid Support", GitHub, Azure DevOps wiki).

---

## 1. System Context & Containers

What talks to what: the browser SPA, the single .NET 8 API, the scheduled worker, the data tier, and every external clinical or platform service.

```mermaid
flowchart TB
  subgraph Client["Browser"]
    SPA["Angular 18 SPA<br/>322 components / 309 standalone<br/>11 top-level routes, 50 feature areas"]
  end

  subgraph Azure["Azure (App Service / Functions)"]
    API["PacEHR.API<br/>ASP.NET Core 8<br/>94 controllers, ~1,012 endpoints"]
    FUNC["PacEHR.Functions.Process<br/>Isolated worker, 5 timer triggers"]
    SIGR["SignalR services<br/>(external repos: referral lock, chat)"]
  end

  subgraph Data["Data Tier"]
    SQL[("SQL Server<br/>1,120 tables / 1,553 procs<br/>47 views / 27 functions")]
    REDIS[("Redis<br/>PCC token + response cache")]
    COSMOS[("Cosmos DB<br/>PCC request/response logs")]
    BLOB[("Azure Blob Storage<br/>documents, images, audio")]
    LAW[("Log Analytics<br/>audit + error tables")]
  end

  subgraph Ext["External Systems"]
    PCC["PointClickCare"]
    MC["MatrixCare"]
    DRF["DrFirst (eRx)"]
    UPD["Updox (fax/secure msg)"]
    IMO["IMO terminology"]
    HL7["HL7 ADT feeds"]
    TW["Twilio (voice/video/SMS)"]
    SG["SendGrid / SMTP"]
    PBI["Power BI Embedded"]
    GSP["Google Cloud Speech"]
    OAI["OpenAI"]
  end

  SPA -->|"HTTPS JSON + AES payload encryption"| API
  SPA -->|WebSocket| SIGR
  SPA -->|WebSocket audio| API

  API --> SQL
  API --> REDIS
  API --> COSMOS
  API --> BLOB
  API --> LAW
  API -->|Azure Service Bus queues| FUNC
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
```

---

## 2. Backend Layer Structure

How the nine .NET projects depend on each other, from controllers down to the SSDT database project.

```mermaid
flowchart TB
  C["PacEHR.API<br/>Controllers · Filters · Middleware · Hubs"]
  DS["pacEHR.DomainServices<br/>106 service implementations"]
  DSI["pacEHR.DomainServices.Interfaces<br/>112 interfaces"]
  PCCS["pacEHR.PCC.Services<br/>PointClickCare client, models, certs"]
  DTO["pacEHR.Data.Dtos<br/>321 DTOs + settings POCOs"]
  DATA["PacEHR.Data<br/>928 EF Core models + generated proc context"]
  DB["PacEHR.Database (SSDT)<br/>2,857 .sql objects"]

  C --> DSI
  DSI -.implemented by.-> DS
  DS --> DATA
  DS --> PCCS
  C --> DTO
  DS --> DTO
  DATA --> DB
```

---

**Full analysis**: `docs/architecture/current/00-system-overview.md`
