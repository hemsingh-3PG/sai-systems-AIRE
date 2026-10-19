# PacEHR — HL7 v2, ADT Ingestion & Messaging Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/06-hl7-adt-ingestion-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Inbound ADT — audit-first ingestion

The raw HL7 message is persisted before anything that can fail. Note the endpoint is unauthenticated, and the queue has no consumer in either repository.

```mermaid
sequenceDiagram
  participant EXT as External system (MatrixCare / SigmaCare)
  participant MW as JWTMiddleware
  participant CT as MatrixCareController.saveADTMessage
  participant SVC as MatrixCareServices
  participant DB as SQL MatrixCare.usp_ProcessAudit_Insert
  participant SB as Azure Service Bus matrixcare-hl7
  participant ZZZ as ??? consumer

  EXT->>MW: POST /saveADTMessage (raw HL7 v2 body)
  Note over MW: /saveADTMessage is in excludedPaths<br/>→ no body decryption
  Note over MW: [AllowAnonymous] → no authentication
  MW->>CT: forward
  CT->>CT: read raw body from Request.Body
  CT->>SVC: saveProcessAudit("RealtimeWebhook", body)
  SVC->>DB: persist raw HL7, return processAuditId
  DB-->>CT: processAuditId
  CT->>SB: SendMatrixCareHL7MessageAsync(processAuditId + message)
  CT-->>EXT: 200 status Y successfully
  SB-->>ZZZ: no consumer exists in either repository
```

---

## 2. Outbound HL7

Outbound queueing is table-based, not Service Bus — a different mechanism from the inbound path.

```mermaid
sequenceDiagram
  participant UI as SPA / trigger
  participant CT as HL7OutboundController
  participant SVC as HL7OutboundServices
  participant DB as SQL
  participant Q as HL7OutboundMessageQueue table
  participant H as Hl7Helper
  participant EXT as External target

  UI->>CT: POST /triggerHL7Outbound
  CT->>SVC: insertHL7ProcessingParameters(patientId, encounterId, externalTarget, userId, accountId, docType)
  SVC->>DB: proc writes a work item
  DB->>Q: row queued
  Note over Q,H: processing driven from the DB queue table
  H->>H: GetHL7Format / GetHL7Format1 / GetHL7Format2<br/>using HL7_HL7SegmentFieldMapping rows
  H->>EXT: message dispatched
```

---

## 3. The messaging transport — 18 producers, 0 consumers

Every asynchronous flow in PacEHR dispatches to a queue that nothing in either repository reads.

```mermaid
flowchart TB
  subgraph Producers["Producers — ServiceBusQueueHelper, 18 send methods"]
    P1["SendMatrixCareHL7MessageAsync → matrixcare-hl7"]
    P2["SendMatrixCareProgressNoteMessageAsync → matrixcare-progress-note"]
    P3["SendMessageUpdoxAsync → UpdoxQueueName"]
    P4["SendUpdoxFaxAsync → UpdoxFaxQueueName"]
    P5["SendCCMEncounterMessageAsync → CCMEncounterQueueName"]
    P6["SendACOeCQMSMessageAsync → ACOeCQMSQueueName"]
    P7["SendPccDocumentMessageAsync → pccDocumentsSentQueueName"]
    P8["SendMessageAsyncForFacilityConfiguration → FacilityConfigurationQueueName"]
    P9["SendDiagnosisMessageAsync → DrFirst"]
    P10["SendMessageAsyncForHIE / ForHIEPatientData"]
    P11["SendAuditLogMessageAsync / SendAuditLogMessagesAsync"]
    P12["SendMessageChartAuditAsync · SendMessageToQuanticianAsync<br/>SendPQRSEncounterQMMessageAsync · SendMessageAsyncForPccProgressNote"]
  end

  subgraph Bus["Azure Service Bus"]
    Q["10+ named queues"]
  end

  subgraph Consumers["Consumers in pacEHR_API + PacEHR"]
    C["NONE<br/>0 ServiceBusProcessor · 0 CreateReceiver<br/>0 ServiceBusTrigger · 0 QueueTrigger"]
  end

  P1 & P2 & P3 & P4 & P5 & P6 & P7 & P8 & P9 & P10 & P11 & P12 --> Q
  Q -.->|"consumers live outside this workspace"| C
```

---

## 4. Inbound audit chain

How a raw HL7 message is correlated to staging rows and to any error.

```mermaid
erDiagram
  ProcessAudit ||--o{ ErrorException : "processAuditId"
  ProcessAudit ||--o{ StageHL7MSH : "raw message parsed into"
  StageHL7MSH ||--|| StageHL7PID : "same message"
  StageHL7MSH ||--|| StageHL7PV : "same message"
  StageHL7MSH ||--|| StageHL7EVN : "same message"
  StageHL7PID ||..o{ Patients : "matched by external id (no FK)"

  ProcessAudit {
    bigint processAuditId PK
    string source "RealtimeWebhook"
    string rawMessage "full HL7 v2 payload"
  }
  ErrorException {
    bigint processAuditId
    string source
    string sectionName
    string errorMessage "stack trace"
    string exMessage
  }
  StageHL7MSH {
    string messageControlId
    string sendingApplication
  }
  StageHL7PID {
    string externalPatientId
    string firstName
    string lastName
    date DOB
  }
```

---

**Full analysis**: `docs/architecture/current/06-hl7-adt-ingestion-deep-dive.md`
