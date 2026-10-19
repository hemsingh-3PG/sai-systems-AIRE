# PacEHR — Data & SQL Tier Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/03-data-sql-tier-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Core clinical ER — relationships by convention

Dotted lines are deliberate: these relationships exist in application code and naming, **not** as declared foreign keys. Only 14 of 1,120 tables declare a FK.

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

  ACCOUNTS {
    int accountID PK
  }
  USERS {
    int userId PK
    int accountID
    string PasswordHash
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

---

## 2. Where the logic lives

The SQL tier is not a persistence layer — 1,553 stored procedures against 106 C# service classes means it is the application.

```mermaid
flowchart TB
  subgraph CS["C# (pacEHR_API)"]
    SVC["106 domain services<br/>orchestration + mapping"]
    GEN["pacehr_devContextProcedures<br/>55,457 generated lines"]
  end
  subgraph DB["SQL Server — PacEHR.Database, 2,857 .sql files"]
    P["1,553 stored procedures<br/>38 with TRY/CATCH · 29 with transactions<br/>585 using NOLOCK · 88 backup copies"]
    T["1,120 tables<br/>14 with a FOREIGN KEY<br/>630 with no PRIMARY KEY"]
    V["47 views · 27 functions<br/>99 table-valued types"]
  end
  SVC --> GEN
  GEN --> P
  P --> T
  P --> V
```

---

## 3. Dynamic SQL — four qualities in ten procedures

Only 10 of 1,553 procedures build SQL dynamically, but they are not equally safe.

```mermaid
flowchart TB
  A["10 procedures using dynamic SQL"] --> B["a. Parameterised via sp_executesql<br/>usp_getPatientsList (PAC-1018)"]
  A --> C["b. Allowlisted identifiers via CASE<br/>usp_getTaskBypagination"]
  A --> D["c. Escape-based mitigation<br/>proc_getICDCodes (quote doubling, Mar 2026)"]
  A --> E["d. No mitigation<br/>proc_getMultipleICDCodes"]

  B --> B1["✅ Safe — the standard to follow"]
  C --> C1["✅ Safe — identifiers never interpolated from input"]
  D --> D1["🟡 Mitigated but brittle — still string-built"]
  E --> E1["🔴 Probable injection vector"]

  E1 --> F["Reachable: POST /getMultipleICDCodes<br/>→ ICDCodeController<br/>→ ICDCodeService<br/>→ proc_getMultipleICDCodesAsync<br/>→ EXEC(@sql)"]
  F --> G["C# binds @searchString as SqlParameter,<br/>but the proc then concatenates that value<br/>into a string — boundary parameterisation<br/>gives no protection"]
```

---

**Full analysis**: `docs/architecture/current/03-data-sql-tier-deep-dive.md`
