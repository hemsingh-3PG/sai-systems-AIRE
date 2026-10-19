# PacEHR — SPA Shell & Navigation Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/09-spa-shell-navigation-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Two composition roots, one live

`main.ts` bootstraps the app. `app.module.ts` still exists, registers a different interceptor list, and is imported by nothing.

```mermaid
flowchart TB
  M["src/main.ts<br/>bootstrapApplication(AppComponent)<br/>LIVE"] --> P["providers[]<br/>appRoutingModule · provideHttpClient(withInterceptorsFromDi())<br/>4 HTTP_INTERCEPTORS · NgRx Store + Effects<br/>NgbModule · Material · NgSelect · GoogleMaps<br/>provideAnimations · provideToastr · provideNgxMask"]
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
  M->>NG: bootstrapApplication(AppComponent, providers)
  NG->>NG: StoreModule.forRoot + forFeature(error, login)<br/>EffectsModule.forRoot([ErrorEffects, LoginEffects])<br/>StoreDevtoolsModule.instrument(maxAge 25, logOnly production)
  NG->>AC: create
  AC->>AC: subscribe to router.events (NavigationStart)
  AC->>AC: read sessionStorage user → isLoggedIn
  AC->>R: initial navigation
  R->>G: canActivate for '' and 'settings'
  G->>G: sessionStorage user.token present?
  alt yes
    G-->>R: true → BasicLayoutModule
  else no
    G->>R: navigate(['/login'])
  end
  AC-->>B: render header + router-outlet + loader
```

---

## 3. Navigation — tabs, not routes

The URL stays at `/` for every authenticated screen. A 31-branch string comparison decides what renders.

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
  BL --> SHELL["BasicLayoutComponent<br/>687 lines TS / 256 lines HTML"]

  SHELL --> ST["LayoutState (NgRx)<br/>basicLayout: BasicLayoutObj[]  ← the open tabs<br/>tabIndex: previous / current<br/>+ 10 cached list collections"]
  ST --> SW["@if (rootContent.component === '...')<br/>a 31-branch chain in the template"]

  SW --> C1["dashboard · patientList · encounterList<br/>patientSummary · encounterForm · groupList<br/>FacilityDetailComponent · AddEditEncounterComponent<br/>GeneratePdfComponent · BasicReportsComponent<br/>scheduler · scheduler2 · EmailsComponent<br/>UpdaoxEmailcomp · CustomUrl · ccm-dashboard<br/>care-program-dashboard(-v2) · referral-queue<br/>referral-enrollment · chart-audit-report<br/>md-activity-log · signalr-chat · task · calling<br/>releasenotes · updox · settings · add-edit-patient<br/>new-ccm-enrollment · sidebar"]

  style SW fill:#ffe6e6
```

---

## 4. State — three stores, unevenly used

NgRx holds tabs and a few lists; browser storage holds everything else.

```mermaid
flowchart LR
  subgraph NgRx["NgRx — narrow"]
    G["Global: login, error"]
    L["Feature: LayoutState<br/>12 fields — tabs + 10 cached lists"]
  end
  subgraph Browser["Browser storage — the real store"]
    SS["sessionStorage<br/>1,937 references<br/>user ×904 · account ×258<br/>providerFacilityIds · ccmStates<br/>DaySheetReportlist · date filters ..."]
    LS["localStorage<br/>952 references"]
  end
  subgraph Svc["66 core services"]
    S["per-feature HTTP + in-memory caches"]
  end

  C["Components"] --> NgRx
  C --> SS
  C --> LS
  C --> Svc
```

---

**Full analysis**: `docs/architecture/current/09-spa-shell-navigation-deep-dive.md`
