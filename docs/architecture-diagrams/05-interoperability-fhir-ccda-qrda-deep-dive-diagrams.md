# PacEHR — Interoperability Diagrams (FHIR / CCDA / QRDA / eCQM)

**Date**: 2026-10-19
**Source**: `docs/architecture/current/05-interoperability-fhir-ccda-qrda-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, refresh)
**Status**: Draft (awaiting user confirmation)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. A FHIR request: what actually happens

```mermaid
sequenceDiagram
  participant X as External FHIR client
  participant MW as JWTMiddleware
  participant DI as DI container
  participant CT as FhirPatientController
  participant SVC as FhirPatientService

  X->>MW: GET /fhir/Patient<br/>Authorization: token
  Note over MW: excludedPaths is an exact match, so /fhir/Patient is not excluded<br/>(no body on GET, nothing to decrypt)
  MW->>MW: token = headers["Authorization"] because the URL contains fhir<br/>CryptoHelper.Decrypt(token, "SecretKey123")
  Note over MW: a plain Bearer JWT is not AES ciphertext<br/>so decrypt throws and the client gets 401 Invalid or malformed token
  MW--xX: 401 for any client that does not pre-encrypt its token

  rect rgba(255,0,0,0.08)
  Note over DI,CT: If a caller sends an AES-encrypted token and passes the middleware:
  MW->>DI: activate FhirPatientController
  DI->>DI: resolve IFhirPatientService (registered, Program.cs:380)
  DI->>DI: resolve IFhirMedicationService (registered)
  DI->>DI: resolve IMapper NOT REGISTERED
  DI--xCT: InvalidOperationException<br/>Unable to resolve service for type AutoMapper.IMapper
  end

  Note over SVC: 7,525 lines of FHIR service code<br/>are never reached
```

---

## 2. CCDA document generation

```mermaid
sequenceDiagram
  participant SPA as SPA
  participant CT as ReadXMLController (GenerateCCDA, DownloadCCDAFile)
  participant GEN as CCDAGenerator (1,839 lines)
  participant DB as SQL usp_get*ForCCDA procs
  participant DLL as CCDA.dll (binary, repo root)
  participant FS as App_Data/CCDA/download

  SPA->>CT: POST GenerateCCDA (patientId, userId, startDate, endDate)
  CT->>GEN: GenerateCDA(CCDAType.CCDA or Referral_Note, ...)
  GEN->>DB: usp_getPatientForCCDA, usp_getAllergyForCCDA,<br/>usp_getMedicationsForCCDA, usp_getCareTeamForCCDA,<br/>usp_getVitalPatientForCCDA, usp_getEncDaignosisForCCDA ...
  DB-->>GEN: section datasets
  GEN->>DLL: build CDA document
  DLL-->>GEN: CCDA XML
  GEN->>FS: write file to App_Data/CCDA/download
  GEN-->>CT: status string
  CT-->>SPA: dictionary envelope
```

---

## 3. QRDA / eCQM quality reporting

```mermaid
flowchart LR
  A["QRDAController<br/>downloadQRDAXML, downloadQRDA, getQRDAMeasures"] --> B["QRDAServices<br/>4,157 lines"]
  B --> C[("PQRS schema (34 tables)<br/>ECQM schema (16)<br/>ACO schema (17)<br/>HCC schema (10)")]
  D["ECQMController<br/>SendEcqmServiceBus, UpdateECQMEnableStatus"] --> E["Azure Service Bus<br/>ACOeCQMSQueueName = acoecqms-sbq"]
  D --> H[("usp_SaveECQMMessageQueue")]
  E --> F["Downstream eCQM processing<br/>(no consumer in this workspace)"]
  B --> G["QRDA XML download"]
```

---

## 4. Automated quality-measure exclusions (new)

```mermaid
sequenceDiagram
  participant UI as SPA (Quality Measures button / Sign and Close)
  participant CT as QualityMeasureExclusionController
  participant SVC as PqrsService
  participant DB as SQL PQRS.usp_EvaluatePatientMeasureExclusions

  UI->>CT: POST evaluateEncounterExclusions (encounterID)
  CT->>CT: GetHeaders(), reject encounterID or AccountID <= 0 with 400
  CT->>SVC: EvaluateEncounterExclusions(accountId, encounterId, userId, ct)
  SVC->>SVC: GetEncounterExclusionScope (patientID, measureYear)
  SVC->>DB: usp_EvaluatePatientMeasureExclusionsAsync
  SVC->>DB: usp_GetPatientMeasureExclusionsAsync
  DB-->>SVC: applied / reversed counts + exclusions
  SVC-->>CT: EvaluateEncounterExclusionsResult
  CT-->>UI: 200 Y (or 404 N when the encounter is missing)
  Note over CT,UI: any exception is logged and returned as 200 with flag F (fail-open),<br/>so Sign and Close is never blocked
```

---

## 5. FHIR model layering

```mermaid
flowchart LR
  DB[("SQL Server")] --> DM["Dm domain models<br/>(PatientDm, etc.)"]
  DM --> MAP{"AutoMapper IMapper<br/>NOT REGISTERED"}
  MAP --> RM["Rm resource models<br/>(PatientRm, BundleRm of T)"]
  RM --> JSON["FHIR JSON"]
  HL7["Hl7.Fhir.R4<br/>Bundle, Patient, ..."] -.-> MAP
```

---

**Full analysis**: `docs/architecture/current/05-interoperability-fhir-ccda-qrda-deep-dive.md`
