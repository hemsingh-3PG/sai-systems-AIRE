# PacEHR — SPA Feature Areas Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/10-spa-feature-areas-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. A feature area's data path

Every screen follows this route from click to API and back — including the inline `sessionStorage` reads and the `flag`-based branching.

```mermaid
sequenceDiagram
  participant U as User
  participant C as Feature component
  participant S as core/services/*.service.ts
  participant I as Interceptor chain
  participant API as PacEHR.API
  participant SS as sessionStorage

  U->>C: interact
  C->>SS: read user / account (inline JSON.parse)
  C->>S: this.patientService.getPatientList(payload)
  S->>S: getEndPointUrl(url) → environment.apiBaseUrl + '/' + url
  S->>I: this.http.post<any>(url, payload)
  I->>I: Auth (encrypted headers) → Csrf → Loader → Encrypt (AES body)
  I->>API: POST /getPatientList
  API-->>I: status, flag, msg, result
  I-->>S: response
  S-->>C: Observable<any>
  C->>C: if (res.flag === 'Y') { ... } else { ... }
  C->>SS: cache list / filters back to sessionStorage
```

---

## 2. Caching — the pattern that exists in one service

`PatientService` memoises reference data correctly. The other 65 services do not.

```mermaid
flowchart TB
  A["Component asks for states / countries / lookups"] --> B{"PatientService cache"}
  B -->|"_states$ exists"| C["return memoised Observable"]
  B -->|"lookups: key = JSON.stringify(payload)"| D["_lookupsCache: Map&lt;string, Observable&gt;"]
  D -->|hit| C
  D -->|miss| E["http.post(...).pipe(shareReplay({refCount:false}))"]
  E --> D
  C --> F["Component subscribes — no second network call"]
```

---

## 3. Where the SPA's mass sits

Two feature areas hold half the code — and 41% of all the tests.

```mermaid
flowchart LR
  subgraph Big["Largest feature areas (TypeScript LOC)"]
    A["patient-list<br/>39,357 LOC · 181 files · 85 specs"]
    B["basic-reports<br/>22,432 LOC · 97 files · 46 specs"]
    C["encounter-list<br/>18,974 LOC · 50 files · 19 specs"]
    D["dashboard<br/>10,902 LOC · 33 files · 13 specs"]
  end
  subgraph Dense["Few files, very large ones"]
    E["pdf — 6,691 LOC in 8 files"]
    F["referral-enrollment — 4,870 LOC in 4 files"]
    G["account-configurations — 2,394 LOC in 2 files"]
  end
  subgraph Thin["Thinly covered"]
    H["core/services<br/>66 services · 10,559 LOC · 7 specs"]
    I["~40 other feature areas<br/>0–6 specs each"]
  end
```

---

**Full analysis**: `docs/architecture/current/10-spa-feature-areas-deep-dive.md`
