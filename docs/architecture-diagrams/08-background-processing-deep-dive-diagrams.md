# PacEHR — Background Processing Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/08-background-processing-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, refresh)
**Status**: Draft (awaiting user confirmation)
**HEADs analysed**: PacEHR `401caa134`, pacEHR_API `0f611f65c`, pacEHR_AI `ef172ea`

---

## 1. Functions timer worker - DrFirst poll

```mermaid
sequenceDiagram
  participant T as Azure Functions host (timer)
  participant F as EveryFiveMinutesFunction
  participant S as DRFirstServices
  participant DB as SQL
  participant HC as new HttpClient() per account
  participant DF as DrFirst Rcopia
  participant AI as Application Insights

  T->>F: TimerTrigger 0 */5 * * * *
  F->>F: _logger.LogInformation(DateTime.Now)
  F->>S: getDrFirstAccounts()
  S->>DB: proc
  DB-->>S: account list
  loop for each account - NO try/catch
    F->>S: getDrFirstAccountCredentials / getDrFirstCredentials
    alt drCred == null
      F->>F: continue
    end
    F->>HC: using var httpClient = new HttpClient()
    HC->>DF: XML POST with LastUpdateDate 03/29/2022 08:21:11 hard-coded
    DF-->>HC: response body read into respContent
    F->>F: doc.LoadXml(result) where result is string.Empty
    Note over F: XmlException - respContent is never parsed
  end
  Note over F: an exception on ANY account aborts<br/>the whole run - remaining accounts skipped
  F--xAI: AddApplicationInsightsTelemetryWorkerService()<br/>is COMMENTED OUT - nothing reaches App Insights
```

## 2. In-process log workers

```mermaid
sequenceDiagram
  participant MW as Audit / Error / PCC middleware
  participant CH as Channel (unbounded)
  participant W as AuditWorker / ErrorLogWorker / PCCLogWorker
  participant TM as PeriodicTimer 2s
  participant LAW as Log Analytics

  MW->>CH: EnqueueAsync(json)
  Note over CH: Channel.CreateUnbounded - no back-pressure
  par reader loop
    W->>CH: ReadAllAsync
    W->>W: buffer.Add(json)
    alt buffer.Count >= 1000
      W->>LAW: FlushBatchAsync
    end
  and flush timer (Audit and Error workers only)
    TM->>W: every 2s
    W->>LAW: FlushBatchAsync(partial batch)
  end
  alt flush throws
    W->>W: Console.WriteLine("Error flushing logs: " + ex.Message)
    Note over W: the whole batch is lost - no retry,<br/>no dead-letter, not visible in App Insights
  end
```

## 3. PccCosmosWorker - the bounded-channel reference

```mermaid
flowchart TB
  F["PccCosmosLoggingFilter"] --> CH["PccCosmosChannel<br/>CreateBounded(10000)<br/>FullMode = DropWrite"]
  CH -->|"full"| D["TryEnqueue returns false<br/>Interlocked drop counter<br/>_logger.LogWarning every 100 drops"]
  CH -->|"ok"| W["PccCosmosWorker<br/>BatchSize 200 · FlushIntervalMs 2000<br/>MaxConcurrentUpserts 32"]
  W --> E["EnsureContainerWithRetryAsync"]
  E --> C[("Cosmos DB<br/>TTL: RetentionDays, default 90")]
  W --> L["ILogger&lt;PccCosmosWorker&gt;"]
```

## 4. Where background work is started

```mermaid
flowchart LR
  subgraph FN["PacEHR.Functions.Process (own host)"]
    A["5 timer functions"] --> B["DRFirstServices · EmailEncounterJob<br/>CCMBHIAutoBillingService"]
  end
  subgraph API["PacEHR.API (web app host)"]
    C["AddHostedService x4<br/>Audit · Error · PCCLog · PccCosmos"]
    D["Controllers enqueue<br/>HL7 outbound, HIE queue"]
  end
  B --> DB[("SQL via pacehr_devContextProcedures")]
  D --> DB
  D --> SB["Azure Service Bus"]
  SB -.-> X["Consumers outside these repos<br/>PacEHR_AppService function"]
  C --> LAW["Log Analytics / Cosmos"]
```

## 5. Job queue tables - relationships by convention

```mermaid
erDiagram
  HL7OUTBOUNDMESSAGEQUEUE ||..o{ HL7OUTBOUNDPROCESSING : "message state (by convention)"
  HL7INBOUNDMESSAGEQUEUE ||..o{ HL7INBOUNDMESSAGEQUEUE_REPROCESS : "reprocess (by convention)"
  HL7INBOUNDSETTINGS ||..o{ HL7INBOUNDMESSAGEQUEUE : "partner config (by convention)"
  HL7LTC_REPROCESS {
    int id "LTC reprocess"
  }
```

