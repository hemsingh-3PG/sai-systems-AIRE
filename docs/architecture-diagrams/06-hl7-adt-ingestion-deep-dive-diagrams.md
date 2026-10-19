# PacEHR — HL7 v2, ADT Ingestion & Messaging Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/06-hl7-adt-ingestion-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, refresh)
**Status**: Draft (awaiting user confirmation)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Inbound ADT: audit-first ingestion

```mermaid
sequenceDiagram
  participant EXT as External system (MatrixCare)
  participant MW as JWTMiddleware
  participant CT as MatrixCareController.saveADTMessage
  participant SVC as MatrixCareServices
  participant DB as SQL MatrixCare.usp_ProcessAudit_Insert
  participant SB as Azure Service Bus matrixcare-hl7
  participant ZZZ as consumer (not in workspace)

  EXT->>MW: POST /saveADTMessage (raw HL7 v2 body)
  Note over MW: AllowAnonymous so the token check is skipped<br/>(path is also in excludedPaths: no body decrypt)
  MW->>CT: forward
  CT->>CT: read raw body from Request.Body
  CT->>SVC: saveProcessAudit("RealtimeWebhook", body)
  SVC->>DB: persist raw HL7, return processAuditId
  DB-->>CT: processAuditId
  CT->>SB: SendMatrixCareHL7MessageAsync({processAuditId, responseMessage}, "matrixcare-hl7")
  CT-->>EXT: 200 { status Y, msg successfully }
  SB-->>ZZZ: no receiver exists in any of the three repositories
  Note over CT,EXT: any failure is logged to MatrixCare.Error_Exception<br/>and returned as 404 F Not Found
```

---

## 2. Outbound HL7

```mermaid
sequenceDiagram
  participant UI as SPA / trigger
  participant CT as HL7OutboundController
  participant SVC as HL7OutboundServices
  participant DB as SQL usp_insertHl7outboundprocessing
  participant Q as Hl7outboundprocessing / HL7OutboundMessageQueue tables
  participant EXT as External target

  UI->>CT: POST /triggerHL7Outbound (patientId, encounterId, externalTarget, userId, accountId, docType)
  CT->>SVC: insertHL7ProcessingParameters(...)
  SVC->>DB: EXEC usp_insertHl7outboundprocessing
  DB->>Q: work item queued
  Note over Q,EXT: no reader of these tables or of their procedures<br/>exists in pacEHR_API C# code; the dispatcher is outside this workspace
  Q-->>EXT: dispatch (not visible in code)
```

---

## 3. The messaging transport: 22 producers, 0 in-workspace consumers

```mermaid
flowchart TB
  subgraph Producers["Producers: ServiceBusQueueHelper, 22 send methods"]
    P1["SendMatrixCareHL7MessageAsync to matrixcare-hl7 (literal)"]
    P2["SendMatrixCareProgressNoteMessageAsync to matrixcare-progress-note (literal)"]
    P3["SendMessageUpdoxAsync, SendUpdoxFaxAsync"]
    P4["SendCCMEncounterMessageAsync"]
    P5["SendACOeCQMSMessageAsync, SendPQRSEncounterQMMessageAsync"]
    P6["SendPccDocumentMessageAsync, SendLinkExternalPatinetMessage"]
    P7["SendMessageAsyncForPccProgressNote, SendMessageForPccProgressNoteProcess"]
    P8["SendMessageAsyncForFacilityConfiguration"]
    P9["SendDiagnosisMessageAsync (DrFirst)"]
    P10["SendMessageAsyncForHIE, SendMessageAsyncForHIEPatientData (Kno2)"]
    P11["SendAuditLogMessageAsync, SendAuditLogMessagesAsync"]
    P12["SendMessageAsync, SendMessageChartAuditAsync, SendMessageToQuanticianAsync,<br/>SendMessagePatientEventSeriveBus, SendMessageEncounterEventSeriveBus"]
  end

  subgraph Bus["Azure Service Bus"]
    Q["named queues across several namespaces"]
  end

  subgraph Consumers["Receivers in pacEHR_API, PacEHR, pacEHR_AI"]
    C["NONE<br/>0 ServiceBusProcessor, 0 CreateReceiver, 0 ServiceBusTrigger, 0 QueueTrigger"]
  end

  EXT2["Named out-of-workspace consumer:<br/>HIEPatientDataFunction (kno2-patient-sbq), per code comment only"]

  P1 & P2 & P3 & P4 & P5 & P6 & P7 & P8 & P9 & P10 & P11 & P12 --> Q
  Q -.-> C
  Q -.-> EXT2
```

---

## 4. Inbound audit chain

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
