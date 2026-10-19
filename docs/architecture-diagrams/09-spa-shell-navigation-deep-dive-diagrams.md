# PacEHR — SPA Shell & Navigation Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/09-spa-shell-navigation-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, refresh)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Two composition roots, one live

```mermaid
flowchart TB
  M["src/main.ts<br/>initDatadogRum() then bootstrapApplication(AppComponent)<br/>LIVE"] --> P["providers[]<br/>appRoutingModule · provideDatadog() · provideHttpClient(withInterceptorsFromDi())<br/>4 HTTP_INTERCEPTORS · NgRx Store + Effects + Devtools<br/>NgbModule · Material · NgSelect · GoogleMaps<br/>provideAnimations · provideToastr · provideNgxMask"]
  AM["src/app/app.module.ts<br/>@NgModule, bootstrap: []<br/>DEAD — no importer anywhere"] -.->|"duplicates 3 of the 4<br/>interceptors and most imports"| P
```

---

## 2. Application bootstrap

```mermaid
sequenceDiagram
  participant B as Browser
  participant M as main.ts
  participant NG as Angular
  participant AC as AppComponent
  participant R as Router
  participant G as AuthGuard

  B->>M: load main.js
  M->>M: Chart.register(...registerables)
  M->>M: initDatadogRum() (CDN script, masked replay)
  M->>NG: bootstrapApplication(AppComponent, { providers })
  NG->>NG: StoreModule.forRoot(appReducers)<br/>forFeature('error'), forFeature('login')<br/>EffectsModule.forRoot([ErrorEffects, LoginEffects])<br/>StoreDevtoolsModule.instrument({ maxAge: 25, logOnly: production })
  NG->>AC: create
  AC->>AC: subscribe to router.events (NavigationStart)
  AC->>AC: read sessionStorage 'user' → isLoggedIn
  AC->>R: initial navigation
  R->>G: canActivate for '' and 'settings'
  G->>G: sessionStorage 'user'.token present?
  alt yes
    G-->>R: true → BasicLayoutModule
  else no
    G->>R: navigate(['/login'])
  end
  AC-->>B: render @if(isLoggedIn) app-header + router-outlet + app-loader
```

---

## 3. Navigation — tabs, not routes

```mermaid
flowchart TB
  subgraph Routes["app-routing.module.ts — 11 routes total"]
    R1["/login · /forgot-password · /enter-otp · /reset-password<br/>/signup · /setupcode · /re-activate-account"]
    R2["/encounters — AuthGuard COMMENTED OUT"]
    R3["/follow-ups — no guard"]
    R4["'' → BasicLayoutModule [AuthGuard]"]
    R5["/settings → SettingsModule [AuthGuard]"]
  end

  R4 --> BL["BasicLayoutRoutingModule<br/>only 2 child routes:<br/>'' and 'changepassword'"]
  BL --> SHELL["BasicLayoutComponent<br/>711 lines TS / 263 lines HTML"]

  SHELL --> ST["LayoutState (NgRx)<br/>basicLayout: BasicLayoutObj[]  ← the open tabs<br/>tabIndex: { previous, current }<br/>+ 10 cached list collections<br/>mirrored to localStorage 'basicLayout'"]
  ST --> SW["@if (rootContent.component === '...')<br/>33 branches (32 distinct values) in the template"]

  SW --> C1["dashboard · patientList · encounterList<br/>patientSummary · encounterForm · groupList<br/>FacilityDetailComponent · AddEditEncounterComponent<br/>GeneratePdfComponent · BasicReportsComponent<br/>scheduler · scheduler2 · EmailsComponent<br/>UpdaoxEmailcomp · CustomUrl · CcmDashboard<br/>CareProgramDashboard / V2 / V3 · referralQueue<br/>reactivationQueue · referralEnrollment<br/>ChartAuditReport · MdActivityLog · Task · calling<br/>Releasenotes (empty body) · Updox · SettingsComponent<br/>AddEditPatientComponent"]

  style SW fill:#ffe6e6
```

---

## 4. State — three stores, unevenly used

```mermaid
flowchart LR
  subgraph NgRx["NgRx — narrow"]
    G["Global: login, error"]
    L["Feature: LayoutState<br/>12 fields — tabs + 10 cached lists"]
  end
  subgraph Browser["Browser storage — the real store"]
    SS["sessionStorage<br/>1,994 references<br/>'user' ×841 (single-quote getItem) · 'account'<br/>providerFacilityIds · ccmStates<br/>DaySheetReportlist · date filters ..."]
    LS["localStorage<br/>979 references<br/>incl. 'basicLayout' (open tabs), 'devicetypeInformation'"]
  end
  subgraph Svc["63 core services"]
    S["per-feature HTTP + in-memory caches"]
  end

  C["Components"] --> NgRx
  C --> SS
  C --> LS
  C --> Svc
  NgRx -.->|"reducers write"| LS
```

---

## 5. `LayoutState` (`features/basic-layout/_store/layout.state.ts`, 463 lines)

```mermaid
erDiagram
  LAYOUT_STATE ||--o{ BASIC_LAYOUT_OBJ : "basicLayout (open tabs)"
  LAYOUT_STATE ||--|| TAB_INDEX : "tabIndex"
  LAYOUT_STATE ||--o{ PATIENT_LIST : "patientList IPatientModel"
  LAYOUT_STATE ||--o{ PATIENTS_LIST : "patientsList Patients"
  LAYOUT_STATE ||--o{ PCC_PATIENTS : "pccPatientsList"
  LAYOUT_STATE ||--o{ REFERENCE_LISTS : "group facility macro account user pqrs"
  BASIC_LAYOUT_OBJ {
    boolean isTabVisible
    boolean isActive
    any navDetails
    any content
  }
  TAB_INDEX {
    number previous
    number current
  }
```

---
