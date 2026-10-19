# PacEHR — Data & SQL Tier Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/03-data-sql-tier-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, refresh)
**Status**: Draft (awaiting user confirmation)
**HEADs analysed**: PacEHR `401caa134`, pacEHR_API `0f611f65c`, pacEHR_AI `ef172ea`

---

## 1. Core clinical ER - relationships by convention

```mermaid
erDiagram
  ACCOUNTS ||..o{ USERS : "accountID (no FK)"
  ACCOUNTS ||..o{ PATIENTS : "accountID (no FK, NULLABLE)"
  ACCOUNTS ||..o{ SESSION : "accountId (no FK)"
  PATIENTS ||..o{ ENCOUNTER : "patientID (no FK)"
  USERS ||..o{ ENCOUNTER : "providerID (no FK)"
  FACILITIES ||..o{ PATIENTS : "facilityID (no FK)"
  PATIENTS ||..o{ TASKS : "patientID (no FK)"
  USERS ||..o{ TASKS : "providerID (no FK)"
  USERS ||..o| USERPREFERENCES : "userId (no FK, new PAC-1269)"

  ACCOUNTS {
    int accountID PK
  }
  USERS {
    int userId PK
    int accountID
    string PasswordHash
    bit isGuidedWorkflowEnabled "new AITP-108"
  }
  USERPREFERENCES {
    int userId PK
    bit hideLinkedRecordWarnings
  }
  PATIENTS {
    int patientID PK
    int accountID "NULLABLE tenant key"
    string firstName
    string lastName
    date DOB
    string SSN "VARCHAR(20), plaintext"
    int facilityID
    int pccPatientId
    int isActive
    int isDeleted
  }
  ENCOUNTER {
    int encounterID PK
    int patientID
    int providerID
    int isActive
    int isDeleted
  }
  SESSION {
    int sessionId PK
    int userId
    int accountId
    string token
    datetime lastLogin
  }
```

## 2. Where the logic lives

```mermaid
flowchart TB
  subgraph CS["C# (pacEHR_API)"]
    SVC["domain services<br/>orchestration + mapping"]
    GEN["pacehr_devContextProcedures<br/>generated + hand-written partials"]
  end
  subgraph DB["SQL Server — PacEHR.Database, 3,046 .sql files"]
    P["1,602 stored procedures<br/>49 with TRY/CATCH · 43 with transactions<br/>622 using NOLOCK · ~60-80 backup copies"]
    T["1,131 tables<br/>14 with a FOREIGN KEY<br/>630 with no PRIMARY KEY"]
    V["47 views · 31 functions<br/>100 table-valued types"]
  end
  SVC --> GEN
  GEN --> P
  P --> T
  P --> V
```

## 3. Release path for a schema or proc change

```mermaid
flowchart LR
  A["Developer change<br/>ticket PAC-nnnn"] --> B["Canonical object<br/>Stored Procedures/Procs1 or Procs2<br/>or Tables/Tables1 or Tables2"]
  A --> C["Ticket-prefixed copy<br/>Scripts/Script.DD-Mon-YYYY"]
  B --> D["SSDT build<br/>Build Include in sqlproj"]
  C --> E["Release SQL built from the folder<br/>Alter file + SP file"]
  E --> F["Run against environment"]
  C -.-> G["Same object under two Jira ids<br/>run order decides final body"]
```

## 4. Dynamic SQL - four qualities and the reachable gap

```mermaid
flowchart TB
  A["10 procedures using dynamic SQL"] --> B["a. Parameterised via sp_executesql<br/>usp_getPatientsList (PAC-1018)"]
  A --> C["b. Allowlisted identifiers via CASE<br/>sort-column procs"]
  A --> D["c. Escape-based mitigation<br/>proc_getICDCodes (quote doubling, Mar 2026)"]
  A --> E["d. No mitigation<br/>proc_getMultipleICDCodes"]

  B --> B1["Safe - the standard to follow"]
  C --> C1["Safe - identifiers never interpolated from input"]
  D --> D1["Mitigated but brittle - still string-built"]
  E --> E1["Probable injection vector"]

  E1 --> F["Reachable: POST getMultipleICDCodes<br/>ICDCodeController.cs:59<br/>then ICDCodeService<br/>then proc_getMultipleICDCodes<br/>then EXEC(@sql) at line 46"]
  F --> G["C# binds @searchString as SqlParameter,<br/>but the proc then concatenates that value<br/>into a string - boundary parameterisation<br/>gives no protection"]
```

