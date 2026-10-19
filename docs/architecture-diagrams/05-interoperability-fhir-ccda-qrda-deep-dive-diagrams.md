# PacEHR — Interoperability Diagrams (FHIR / CCDA / QRDA / eCQM)

**Date**: 2026-09-30
**Source**: `docs/architecture/current/05-interoperability-fhir-ccda-qrda-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. A FHIR request — what actually happens

The FHIR surface cannot serve a request: `IMapper` is injected by all 20 controllers and never registered in DI.

```mermaid
sequenceDiagram
  participant X as External FHIR client
  participant MW as JWTMiddleware
  participant DI as DI container
  participant CT as FhirPatientController
  participant SVC as FhirPatientService

  X->>MW: GET /fhir/Patient<br/>Authorization: Bearer jwt
  Note over MW: "/fhir" is in excludedPaths → body decryption skipped
  MW->>MW: token = Authorization header<br/>CryptoHelper.Decrypt(token, SecretKey123)
  Note over MW: a real Bearer JWT is not AES ciphertext<br/>→ throws → 401 Invalid or malformed token
  MW--xX: 401 (most likely stops here)

  rect rgba(255,0,0,0.08)
  Note over DI,CT: If a caller somehow passes the middleware:
  MW->>DI: activate FhirPatientController
  DI->>DI: resolve IFhirPatientService OK (registered, Program.cs:378)
  DI->>DI: resolve IFhirMedicationService OK
  DI->>DI: resolve IMapper — NOT REGISTERED
  DI--xCT: InvalidOperationException:<br/>Unable to resolve service for type AutoMapper.IMapper
  end

  Note over SVC: 7,525 lines of FHIR service code<br/>is never reached
```

---

## 2. FHIR model layering — where it breaks

The `Dm` → `Rm` split is sound design. The break is exactly at the mapper.

```mermaid
flowchart LR
  DB[("SQL Server")] --> DM["*Dm — domain models<br/>(PatientDm, etc.)"]
  DM --> MAP{"AutoMapper IMapper<br/>NOT REGISTERED"}
  MAP --> RM["*Rm — resource models<br/>(PatientRm, BundleRm&lt;T&gt;)"]
  RM --> JSON["FHIR JSON"]
  HL7["Hl7.Fhir.R4 5.11.4<br/>Bundle, Patient, ..."] -.-> MAP
```

---

## 3. CCDA document generation (active)

One stored procedure per document section, assembled by a committed binary.

```mermaid
sequenceDiagram
  participant SPA as SPA / MatrixCare sync
  participant CT as Controller
  participant CS as CCDAServices
  participant GEN as CCDAGenerator (1,839 lines)
  participant DLL as CCDA.dll (binary, repo root)
  participant DB as SQL usp_get*ForCCDA procs
  participant BLOB as App_Data/CCDA/upload

  SPA->>CT: request CCDA
  CT->>CS: generate(patientId, sections)
  CS->>DB: usp_getPatientForCCDA, usp_getAllergyForCCDA,<br/>usp_getMedicationsForCCDA, usp_getCareTeamForCCDA,<br/>usp_getVitalPatientForCCDA, usp_getEncDaignosisForCCDA ...
  DB-->>CS: section datasets
  CS->>GEN: build document
  GEN->>DLL: CCDA template primitives
  DLL-->>GEN: XML
  GEN-->>CS: CCDA XML
  CS->>BLOB: write to App_Data/CCDA/upload
  CS-->>SPA: document
```

---

## 4. QRDA / eCQM quality reporting (active)

```mermaid
flowchart LR
  A["QRDAController<br/>downloadQRDAXML · downloadQRDA · getQRDAMeasures"] --> B["QRDAServices<br/>4,157 lines"]
  B --> C[("PQRS schema (34 tables)<br/>ECQM schema (16)<br/>ACO schema (17)<br/>HCC schema (10)")]
  D["ECQMController<br/>SendEcqmServiceBus · UpdateECQMEnableStatus"] --> E["Azure Service Bus<br/>ACOeCQMSQueueName"]
  E --> F["Downstream eCQM processing<br/>(outside this repo)"]
  B --> G["QRDA XML download"]
```

---

**Full analysis**: `docs/architecture/current/05-interoperability-fhir-ccda-qrda-deep-dive.md`
