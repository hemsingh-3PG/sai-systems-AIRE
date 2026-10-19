# PacEHR - API Request & Data Spine Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/02-api-request-data-spine-deep-dive.md`
**Status**: Draft (awaiting user confirmation)

---

## 1. Workflow 1: The canonical request

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
  participant EF as EF Core SqlQueryRaw
  participant DB as SQL Server

  C->>FH: HTTP POST /getCptBillingRules
  FH->>EH: X-Forwarded-For, X-Forwarded-Proto
  Note over EH: in the pipeline only if ErrorLogMode == 1
  EH->>SW: UseSwagger, UseWebSockets, UseCors(AllowAnyOrigin)
  SW->>AU: only if AuditMode == 1
  Note over AU: reads and decrypts body, extracts<br/>patientId/encounterId, enqueues audit,<br/>then calls next() in a finally block
  AU->>JW: next
  JW->>MVC: identity in HttpContext.Items
  MVC->>MVC: try block
  MVC->>SVC: _cptBillingRuleService.getCptBillingRules(request)
  SVC->>PROC: usp_getCptBillingRulesAsync(searchString, status)
  PROC->>EF: SqlQueryAsync with EXEC text and SqlParameter array
  EF->>DB: parameterised EXEC
  DB-->>EF: result set
  EF-->>PROC: List of usp result rows
  PROC-->>SVC: typed rows
  SVC-->>MVC: rows
  MVC-->>C: HTTP 200 + dictionary status flag msg result
```

## 2. Workflow 2: Error path

```mermaid
flowchart TB
  A["Exception thrown in service or proc"] --> B{"Controller has try/catch?"}
  B -->|"yes, 1,178 catch statements"| C["ApplicationInsightsLogger.LogError(_telemetry, ex)"]
  C --> D{"rethrow or swallow?"}
  D -->|"throw (common)"| E{"ErrorLogMode == 1?"}
  D -->|"return BuildDictionaryResult(500, 'F', ...)"| F["HTTP 200 with flag F"]
  B -->|no| E
  E -->|yes| G["ErrorHandleMiddelware catch"]
  E -->|no| H["JWTMiddleware bare catch returns 400 Bad Request, nothing logged (CommonExceptionHandling never runs)"]
  G --> I["Build ErrorLog: userID, accountID, apiUrl,<br/>clientIP, browser, DECRYPTED reqPayload,<br/>patientId, encounterId, stackTrace, exceptionJson"]
  I --> J["ErrorLogChannelAnalystics.EnqueueAsync"]
  J --> K["ErrorLogWorker to Log Analytics table"]
  G --> L{"Exception type?"}
  L -->|"PccApiException / PccTokenException (app or PCC library)"| M["Mapped PCC status + user message, HTTP 200 flag F"]
  L -->|anything else| N["HTTP 400 'Bad Request'"]
```

## 3. Workflow 3: Audit and error logging to Log Analytics

```mermaid
sequenceDiagram
  participant MW as Audit / Error middleware
  participant CH as ChannelAnalystics (unbounded in-memory Channel)
  participant W as AuditWorker / ErrorLogWorker (IHostedService)
  participant LAW as Azure Log Analytics

  MW->>MW: decrypt body, ExtractIds(patientId, encounterId)
  MW->>CH: EnqueueAsync(JsonConvert.SerializeObject(log))
  Note over CH: Channel.CreateUnbounded,<br/>lost on process recycle
  W->>CH: dequeue
  W->>LAW: POST custom table (LogTableName / ErrorLogTableName)
```

## 4. The stored-procedure access layer

```mermaid
flowchart LR
  SVC["Domain Service<br/>(~109 files)"] --> I["Ipacehr_devContextProcedures<br/>(1,168 lines generated<br/>+ 404 Custom + 15 partials)"]
  I --> P["pacehr_devContextProcedures<br/>(55,534 lines generated<br/>+ 1,923 Custom + 16 partials)"]
  P --> X["DbContextExtensions.SqlQueryAsync&lt;T&gt;<br/>(pacEHR.Data.Dtos)"]
  X --> EF["EF Core SqlQueryRaw / ExecuteSqlRaw"]
  EF --> DB[("SQL Server<br/>stored procedures")]
  P -.-> R["usp_*Result DTO per proc<br/>(pacEHR.Data.Dtos, 330 files)"]
  CTX["pacehr_devContext<br/>(empty shell, 0 DbSet)"] --> EF
```
