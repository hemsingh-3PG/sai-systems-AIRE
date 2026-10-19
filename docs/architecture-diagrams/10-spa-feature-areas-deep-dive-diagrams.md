# PacEHR — SPA Feature Areas Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/10-spa-feature-areas-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, refresh)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. A feature area's data path

```mermaid
sequenceDiagram
  participant U as User
  participant C as Feature component
  participant S as core/services/*.service.ts
  participant I as Interceptor chain
  participant API as PacEHR.API
  participant SS as sessionStorage

  U->>C: interact
  C->>SS: read 'user' / 'account' (inline JSON.parse)
  C->>S: this.patientService.getPatientList(payload, pageIndex)
  S->>S: getEndPointUrl(url) → environment.apiBaseUrl + '/' + url
  S->>I: this.http.post<IPatientListModel>(url, payload)
  I->>I: Auth (encrypted headers) → Csrf → Loader → Encrypt (AES body)
  I->>API: POST /getPatientList
  API-->>I: { status, flag, msg, result }
  I-->>S: response
  S-->>C: Observable of typed or any response
  C->>C: if (res.flag === 'Y') { ... } else { ... }
  C->>SS: cache list / filters back to sessionStorage
```

---

## 2. Caching — now in several services

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

## 3. Guided workflow — gating and use

```mermaid
flowchart TB
  L["login.component.ts<br/>stores isGuidedWorkflowEnabled (account)<br/>userGuidedWorkflowEnabled (user) in sessionStorage"] --> F["GuidedWorkflowFeatureService"]
  F --> G1{"account flag AND user flag<br/>AND not native app<br/>(devicetypeInformation)"}
  G1 -->|no| OFF["Today's AI screen, unchanged"]
  G1 -->|yes| G2{"isAIEnabled AND New Dashboard<br/>(account and user)"}
  G2 -->|no| OFF
  G2 -->|yes| ON["Guided workflow"]
  ON --> EF["encounter-form: app-gw-container replaces AI screen card<br/>Open AI prompt build skipped"]
  ON --> RN["Rounding Notes modal: app-gw-template-what-to-cover<br/>reference list of template sections"]
  EF --> NC["app-gw-note-capture<br/>text · dictate · execute (stub) · exit"]
  NC --> DR["GuidedWorkflowDraftService<br/>in-memory Map by encounterId"]
  DR -.->|"cleared on sign / logout / timeout"| X["no browser storage"]
```

---

## 4. What-to-Cover read in the Rounding Notes modal

```mermaid
sequenceDiagram
  participant M as AddRoundingNotes modal
  participant T as app-gw-template-what-to-cover
  participant W as GuidedWorkflowWhatToCoverService
  participant TE as TemplateEditorService
  participant API as PacEHR.API

  M->>T: templateId (form control value)
  T->>T: ngOnChanges → toTemplateId (positive integer or null)
  T->>W: itemsForTemplate(id)
  alt cached for this id
    W-->>T: shared Observable (shareReplay)
  else not cached
    W->>TE: getTemplateMapping({ templateId })
    TE->>API: POST getTemplateMapping
    API-->>W: { flag, result: rows }
    W->>W: flag Y → fromTemplateMapping(rows) ordered by orderby, required if any Hard field
    W->>W: flag F or error → []; error evicts cache entry
    W-->>T: WhatToCoverItem[]
  end
  T-->>M: renders app-gw-what-to-cover in reference mode
```

---

## 5. Guided workflow models (`features/guided-workflow/models/what-to-cover.ts`)

```mermaid
erDiagram
  TEMPLATE_MAPPING_ROW }o--|| WHAT_TO_COVER_ITEM : "grouped by sectionID"
  ENCOUNTER_SECTION ||--o{ ENCOUNTER_FIELD : "sectionid"
  ENCOUNTER_SECTION ||--|| WHAT_TO_COVER_SECTION : "indexEncounterSections"
  WHAT_TO_COVER_SECTION ||--o{ WHAT_TO_COVER_ITEM : "toItems(coverageSignature)"
  TEMPLATE_MAPPING_ROW {
    number sectionID
    number fieldID
    number orderby
    string sectionName
    string customSectionName
    string variant
  }
  WHAT_TO_COVER_ITEM {
    number sectionId
    string title
    string description
    boolean required
    boolean covered
  }
  WHAT_TO_COVER_SECTION {
    number sectionId
    string title
    Field fields
    Field requiredFields
  }
```

---

## 6. Where the SPA's mass sits

```mermaid
flowchart LR
  subgraph Big["Largest feature areas (TypeScript LOC incl. specs)"]
    A["patient-list<br/>39,883 LOC · 183 files · 85 specs"]
    B["basic-reports<br/>23,102 LOC · 99 files · 47 specs"]
    C["encounter-list<br/>19,871 LOC · 54 files · 22 specs"]
    D["dashboard<br/>11,167 LOC · 34 files · 14 specs"]
  end
  subgraph Dense["Few files, very large ones"]
    E["pdf — 6,766 LOC in 8 files"]
    F["referral-enrollment — 2 non-spec files, 3,107-line component"]
    G["account-configurations — 1 non-spec file, 1,553 lines"]
  end
  subgraph Thin["Thinly covered"]
    H["core/services<br/>63 services · 10 specs"]
    I["referral-queue and reactivation-queue<br/>0 specs each"]
  end
```

---
