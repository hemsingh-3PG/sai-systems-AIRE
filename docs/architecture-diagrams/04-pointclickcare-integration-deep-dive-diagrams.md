# PacEHR — PointClickCare Integration Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/04-pointclickcare-integration-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Token acquisition and caching

How a PCC call gets an OAuth token — cache first, then delegation fallback, then refresh.

```mermaid
sequenceDiagram
  participant CT as PccController
  participant CS as PccCoreService
  participant SV as PccScopeValidator
  participant RD as Redis (PccRedisTokenCache)
  participant DB as SQL (Pcc schema)
  participant PCC as PointClickCare OAuth

  CT->>CS: GetPCCToken(connectionDetails, url, userId, accountId, facilityId, apiName, method)
  CS->>SV: GetRequiredScopes(url, method)
  SV-->>CS: e.g. ["user/patient.read"]
  CS->>RD: Get3LeggedToken(redisKey)
  alt cached token valid and scope satisfied
    RD-->>CS: ThreeLeggedTokenStructure
    CS-->>CT: PccTokenResponse (cache hit)
  else no usable token
    CS->>CS: TryPickAdvancedDelegatedTokenAsync(tokens, scopeRank, excludedUserIds)
    alt another user's delegated token fits
      CS-->>CT: that token
    else
      CS->>PCC: pcc3LeggedRefreshAccessToken(refreshToken)
      PCC-->>CS: new access + refresh token
      CS->>RD: UpdateAccessTokenInRedisKey(...)
      CS->>DB: insertPcc3LeggedAccessToken(...)
      CS-->>CT: refreshed token
    end
  end
  Note over CS: scopeValidationFailed flag returned<br/>rather than an exception
```

---

## 2. A PCC data fetch, end to end

From the SPA click to four different stores.

```mermaid
sequenceDiagram
  participant SPA as Angular SPA
  participant AI as AuthInterceptor
  participant CT as PccController
  participant LF as PccCosmosLoggingFilter
  participant CS as PccCoreService
  participant PCC as PCC REST API
  participant SVC as PccService
  participant DB as SQL stage/Pcc tables
  participant CH as PccCosmosChannel
  participant CDB as Cosmos DB

  SPA->>AI: pccGetPatientMedication(...)
  Note over AI: if a full sync is running,<br/>stamps X-Sync-Call: true
  AI->>CT: POST /pccGetPatientMedication
  CT->>LF: action filter (attached by convention)
  CT->>CT: GetHeaders() → accountID, userID, IsSyncCall
  CT->>CT: HasPendingPccWebhookEventsAsync(apiName, accountID, pccPatientId)
  alt no pending webhook events AND not a sync call
    CT-->>SPA: short-circuit — serve from local tables
  else
    CT->>CS: GetPCCToken(...)
    CS-->>CT: token
    CT->>CS: BuildRequestAndGetResponse(url, token, method, body)
    CS->>PCC: HTTPS
    PCC-->>CS: JSON (or PccApiException)
    CS-->>CT: response string
    CT->>SVC: persist via TVP bulk procs
    SVC->>DB: pcc_Insert* / usp_saveStage*Bulk
    CT->>SVC: markPccWebhookEventsProcessed(apiName, accountID, pccPatientId)
  end
  LF->>CH: CaptureAsJson(request, response)
  CH->>CDB: PccCosmosWorker drains → Cosmos
  CT-->>SPA: dictionary envelope
```

---

## 3. Webhook-gated refresh

The rate-limit and cost control on outbound PCC calls — and the header that bypasses it.

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> EventPending: PCC webhook received, event row written
  EventPending --> Fetching: UI calls a pccGet* endpoint
  Fetching --> Processed: data persisted, markPccWebhookEventsProcessed
  Processed --> Idle
  Idle --> Skipped: UI calls pccGet* with no pending events
  Skipped --> Idle
  note right of Skipped
    HasPendingPccWebhookEventsAsync returns false,
    so the controller short-circuits and serves
    local data instead of calling PCC. This is the
    rate-limit / cost control.
  end note
  note right of Fetching
    A full sync (X-Sync-Call: true) bypasses the
    gate: isCalledFromSink skips both the check
    and the mark-processed step.
  end note
```

---

## 4. Where PCC data lands

Four stores participate in one integration, each gated by its own config flag.

```mermaid
flowchart LR
  PCC["PointClickCare API"] --> API["PccController"]
  API --> RD[("Redis<br/>2-legged + 3-legged token lists,<br/>user scopes<br/>NO TTL on keys")]
  API --> SQL[("SQL Server<br/>Pcc schema: 35 tables<br/>stage schema: 107 tables")]
  API --> COS[("Cosmos DB<br/>request/response capture<br/>PccCosmosSettings")]
  API --> LAW[("Log Analytics<br/>PCCLogTableName, PCCLogMode")]
```

---

**Full analysis**: `docs/architecture/current/04-pointclickcare-integration-deep-dive.md`
