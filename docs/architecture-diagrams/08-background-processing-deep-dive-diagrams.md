# PacEHR — Background Processing Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/08-background-processing-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. The Functions timer worker

The DrFirst poller: no error isolation, its own HttpClient per account, and no telemetry.

```mermaid
sequenceDiagram
  participant T as Azure Functions host (timer)
  participant F as EveryFiveMinutesFunction
  participant S as DRFirstServices
  participant DB as SQL
  participant HC as new HttpClient() per account
  participant DF as DrFirst Rcopia
  participant AI as Application Insights

  T->>F: TimerTrigger every 5 minutes
  F->>F: _logger.LogInformation(DateTime.Now)
  F->>S: getDrFirstAccounts()
  S->>DB: proc
  DB-->>S: account list
  loop for each account — NO try/catch
    F->>S: getDrFirstAccountCredentials / getDrFirstCredentials
    alt drCred is null
      F->>F: continue
    end
    F->>HC: using var httpClient = new HttpClient()
    HC->>DF: XML API call
    DF-->>HC: response (or throw)
  end
  Note over F: an exception on ANY account aborts<br/>the whole run — remaining accounts skipped
  F--xAI: AddApplicationInsightsTelemetryWorkerService()<br/>is COMMENTED OUT — nothing reaches App Insights
```

---

## 2. In-process log workers

Unbounded channels, and a failed flush silently discards up to 1,000 audit records.

```mermaid
sequenceDiagram
  participant MW as Audit / Error middleware
  participant CH as Channel (unbounded)
  participant W as AuditWorker / ErrorLogWorker
  participant TM as PeriodicTimer 2s
  participant LAW as Log Analytics

  MW->>CH: EnqueueAsync(json)
  Note over CH: Channel.CreateUnbounded — no back-pressure
  par reader loop
    W->>CH: ReadAllAsync
    W->>W: buffer.Add(json)
    alt buffer.Count >= 1000
      W->>LAW: FlushBatchAsync
    end
  and flush timer
    TM->>W: every 2s
    W->>LAW: FlushBatchAsync(partial batch)
  end
  alt flush throws
    W->>W: Console.WriteLine("Error flushing logs")
    Note over W: the whole batch is lost — no retry,<br/>no dead-letter, not visible in App Insights
  end
```

---

## 3. PccCosmosWorker — the same pattern done right

Bounded capacity, a named overload policy, a drop counter, structured logging and a TTL.

```mermaid
flowchart TB
  F["PccCosmosLoggingFilter"] --> CH["PccCosmosChannel<br/>CreateBounded(10000)<br/>FullMode = DropWrite"]
  CH -->|"full"| D["TryEnqueue returns false<br/>Interlocked drop counter<br/>_logger.LogWarning every 100 drops"]
  CH -->|"ok"| W["PccCosmosWorker<br/>BatchSize 200 · FlushIntervalMs 2000<br/>MaxConcurrentUpserts 32"]
  W --> E["EnsureContainerWithRetryAsync"]
  E --> C[("Cosmos DB<br/>TTL: RetentionDays, default 90")]
  W --> L["ILogger&lt;PccCosmosWorker&gt;"]
```

---

**Full analysis**: `docs/architecture/current/08-background-processing-deep-dive.md`
