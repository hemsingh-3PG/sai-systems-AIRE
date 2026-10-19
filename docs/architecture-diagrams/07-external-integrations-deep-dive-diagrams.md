# PacEHR — External Integrations Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/07-external-integrations-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. The anonymous-endpoint surface

56 `[AllowAnonymous]` actions across 10 controllers. Some are legitimately pre-authentication; many are not.

```mermaid
flowchart TB
  subgraph Internet["Unauthenticated callers"]
    X["Anyone who can reach the URL"]
  end

  subgraph Anon["56 [AllowAnonymous] actions across 10 controllers"]
    V["VideoCallController — 15 of 16 routes<br/>sentLinkBySMS · sentLinkByEmail · AddVideoLink<br/>DeleteVideoCall · updateVideoCallStatus<br/>ProviderStartedVideoCall · ProviderEndedVideoCall<br/>getActiveRoomByProvider · getRecentVideoCall<br/>getStatusOfVideoCall · checkMeetingId ..."]
    C["VoiceCallMessagesController — 16 of 27<br/>makecall · incoming · callforward · forwordaction<br/>handle-call · handle-incommingcall · save-voicemail<br/>transcribe · TwiliojwtToken · TwiliojwtCall<br/>registerPushNotification · sendPushNotification ..."]
    U["UserController — 13<br/>verifyUser · validateOtp · sendOtpViaSms<br/>resetUserPassword · updateUserPassword · addEditUser<br/>enableTFA · Verify2FA · setUpCode · generateToken<br/>getUserandAccountDetailsByToken · sendEmail · sendSMS"]
    O["OAuthController — 3 (class-level)"]
    H["HIEController — 2<br/>getHIEPatientData · triggerDocumentQueue"]
    M["MatrixCareController — 2<br/>saveADTMessage · MatrixCarePatientSyncLoad"]
    P["PccTokenRenewalController — 2"]
    A["AIController · AccountController · HealthMonitoring — 1 each"]
  end

  X --> V & C & U & O & H & M & P & A
  V --> SMS["Twilio SMS / SendGrid email<br/>— metered, billable"]
  C --> TW["Twilio voice — metered, billable"]
  U --> ID["Identity mutation:<br/>password reset, TFA enable, user create"]
  H --> PHI["Patient data"]
```

---

## 2. Twilio voice — webhook callbacks

Webhooks must be anonymous; the control that makes that safe — signature validation — is missing.

```mermaid
sequenceDiagram
  participant P as Provider (browser)
  participant API as VoiceCallMessagesController
  participant TW as Twilio
  participant CB as Twilio webhook callbacks
  participant DB as SQL

  P->>API: POST /TwiliojwtToken  [AllowAnonymous]
  API-->>P: Twilio access token (JWT)
  P->>TW: place call with token
  TW->>CB: POST /incoming  [AllowAnonymous]
  Note over CB: no X-Twilio-Signature validation anywhere
  CB->>API: /handle-call, /handle-incommingcall,<br/>/callforward, /forwordaction
  API-->>TW: TwiML
  TW->>CB: POST /save-voicemail, /updatevoicecalllog,<br/>/updateoutvoicecalllog, /transcribe
  CB->>DB: persist call logs, voicemail, transcript
```

---

## 3. DrFirst — the one well-protected outbound path

The policy pattern the other integrations should adopt.

```mermaid
sequenceDiagram
  participant F as EveryFiveMinutesFunction
  participant S as DRFirstServices
  participant CT as DrFirstController
  participant HC as HttpClient DrFirst
  participant POL as Polly retry to circuit-breaker to timeout
  participant DF as DrFirst Rcopia

  F->>S: poll (TimerTrigger every 5 min)
  CT->>HC: _httpClientFactory.CreateClient("DrFirst")
  HC->>POL: 20s overall ceiling
  POL->>POL: per-try timeout 8s
  POL->>DF: XML API call
  alt transient 5xx / 408 / timeout
    POL->>DF: ONE retry after 500ms
  end
  alt 5 failures in window
    POL--xDF: circuit open for 30s, fail fast
  end
  DF-->>CT: response
```

---

**Full analysis**: `docs/architecture/current/07-external-integrations-deep-dive.md`
