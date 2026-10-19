# PacEHR — API Request & Data Spine Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/02-api-request-data-spine-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. The canonical request

Every one of the ~1,012 endpoints follows this path from HTTP to SQL and back.

```mermaid
sequenceDiagram
  participant C as Client
  participant FH as UseForwardedHeaders
  participant EH as ErrorHandleMiddelware
  participant SW as Swagger / WebSockets / CORS
  participant AU as AuditMiddleware
  participant JW as JWTMiddleware
  participant MVC as Controller (PacEHRCommonController)
  participant SVC as Domain Service
  participant PROC as pacehr_devContextProcedures
  participant EF as EF Core / SqlQueryRaw
  participant DB as SQL Server

  C->>FH: HTTP POST /getCptBillingRules
  FH->>EH: X-Forwarded-For, X-Forwarded-Proto
  Note over EH: only wraps if ErrorLogMode == 1
  EH->>SW: UseSwagger, UseWebSockets, UseCors(AllowAnyOrigin)
  SW->>AU: only if AuditMode == 1
  Note over AU: reads + decrypts body, extracts<br/>patientId/encounterId, enqueues audit,<br/>then calls next() in a finally block
  AU->>JW: 
  JW->>MVC: identity in HttpContext.Items
  MVC->>MVC: try { ... }
  MVC->>SVC: _cptBillingRuleService.getCptBillingRules(request)
  SVC->>PROC: usp_getCptBillingRulesAsync(searchString, status)
  PROC->>EF: SqlQueryAsync<T>("EXEC [dbo].[usp_...] @p = @p", SqlParameter[])
  EF->>DB: parameterised EXEC
  DB-->>EF: result set
  EF-->>PROC: List<usp_...Result>
  PROC-->>SVC: typed rows
  SVC-->>MVC: rows
  MVC-->>C: 200 + dictionary { status, flag, msg, result }
```

---

## 2. Error path

Three competing error strategies in one pipeline, and which one runs depends on configuration.

```mermaid
flowchart TB
  A["Exception thrown in service or proc"] --> B{"Controller has try/catch?"}
  B -->|"yes — 1,141 blocks"| C["ApplicationInsightsLogger.LogError(_telemetry, ex)"]
  C --> D{"rethrow or swallow?"}
  D -->|"throw (common)"| E{"ErrorLogMode == 1?"}
  D -->|"return BuildDictionaryResult(500, 'F', ...)"| F["HTTP 200 with flag F"]
  B -->|no| E
  E -->|yes| G["ErrorHandleMiddelware catch"]
  E -->|no| H["JWTMiddleware bare catch → 400 'Bad Request'<br/>nothing logged"]
  G --> I["Build ErrorLog: userID, accountID, apiUrl,<br/>clientIP, browser, DECRYPTED reqPayload,<br/>patientId, encounterId, stackTrace, exceptionJson"]
  I --> J["ErrorLogChannelAnalystics.EnqueueAsync"]
  J --> K["ErrorLogWorker → Log Analytics table"]
  G --> L{"Exception type?"}
  L -->|"PccApiException / PccTokenException"| M["Mapped PCC status + user message"]
  L -->|anything else| N["400 'Bad Request'"]
```

---

## 3. Audit and error logging to Log Analytics

How request bodies reach the ops log store.

```mermaid
sequenceDiagram
  participant MW as Audit / Error middleware
  participant CH as ChannelAnalystics (in-memory Channel)
  participant W as AuditWorker / ErrorLogWorker (IHostedService)
  participant LAW as Azure Log Analytics

  MW->>MW: decrypt body, ExtractIds(patientId, encounterId)
  MW->>CH: EnqueueAsync(JsonConvert.SerializeObject(log))
  Note over CH: unbounded in-process channel;<br/>lost on process recycle
  W->>CH: dequeue
  W->>LAW: POST custom table (LogTableName / ErrorLogTableName)
```

---

## 4. The stored-procedure access layer

There is no repository pattern — every read and write goes through generated proc wrappers.

```mermaid
flowchart LR
  SVC["Domain Service<br/>(106 classes)"] --> I["Ipacehr_devContextProcedures<br/>(1,167 lines generated<br/>+ 386 lines Custom)"]
  I --> P["pacehr_devContextProcedures<br/>(55,457 lines generated<br/>+ 1,875 Custom + 7 partials)"]
  P --> X["DbContextExtensions.SqlQueryAsync&lt;T&gt;"]
  X --> EF["EF Core SqlQueryRaw / ExecuteSqlRaw"]
  EF --> DB[("SQL Server<br/>1,553 procs")]
  P -.-> R["usp_*Result DTO per proc<br/>(in pacEHR.Data.Dtos, 321 files)"]
```

---

**Full analysis**: `docs/architecture/current/02-api-request-data-spine-deep-dive.md`
