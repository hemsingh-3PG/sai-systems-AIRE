# PacEHR — External Integrations Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/07-external-integrations-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Status**: Draft (awaiting user confirmation)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. The anonymous-endpoint surface

```mermaid
flowchart TB
  subgraph Internet["Unauthenticated callers"]
    X["Anyone who can reach the URL"]
  end

  subgraph Anon["58 AllowAnonymous actions across 11 controllers"]
    V["VideoCallController - 15 of 15 routes<br/>sentLinkBySMS, sentLinkByEmail, AddVideoLink<br/>DeleteVideoCall, updateVideoCallStatus<br/>ProviderStartedVideoCall, ProviderEndedVideoCall<br/>getActiveRoomByProvider, getRecentVideoCall<br/>getStatusOfVideoCall, checkMeetingId ..."]
    C["VoiceCallMessagesController - 16 of 26<br/>makecall, incoming, callforward, forwordaction<br/>handle-call, handle-incommingcall, save-voicemail<br/>transcribe, TwiliojwtToken, TwiliojwtCall, getVideocallToken<br/>registerPushNotification, sendPushNotification ..."]
    U["UserController - 13<br/>verifyUser, validateOtp, sendOtpViaSms<br/>resetUserPassword, updateUserPassword, addEditUser<br/>enableTFA, Verify2FA, setUpCode, generateToken<br/>getUserandAccountDetailsByToken, sendEmail, sendSMS"]
    O["OAuthController - 3 (class-level plus 2)"]
    H["HIEController - 2<br/>getHIEPatientData, triggerDocumentQueue"]
    M["MatrixCareController - 2<br/>saveADTMessage, MatrixCarePatientSyncLoad"]
    P["PccTokenRenewalController - 2"]
    W["WebUiTokenController - 2 (Dragon, Module 12)<br/>OIDC discovery and JWKS public key"]
    A["AIController, AccountController, HealthMonitoring - 1 each"]
  end

  X --> V & C & U & O & H & M & P & W & A
  V --> SMS["Twilio SMS / email<br/>metered, billable"]
  C --> TW["Twilio voice<br/>metered, billable"]
  U --> ID["Identity mutation:<br/>password reset, TFA enable, user create"]
  H --> PHI["Patient data"]
```

## 2. Twilio voice - webhook callbacks

```mermaid
sequenceDiagram
  participant P as Provider (browser)
  participant API as VoiceCallMessagesController
  participant TW as Twilio
  participant CB as Twilio webhook callbacks
  participant DB as SQL

  P->>API: POST /TwiliojwtToken (AllowAnonymous)
  API-->>P: Twilio access token (JWT)
  P->>TW: place call with token
  TW->>CB: POST /incoming (AllowAnonymous)
  Note over CB: no X-Twilio-Signature validation anywhere
  CB->>API: /handle-call, /handle-incommingcall,<br/>/callforward, /forwordaction
  API-->>TW: TwiML
  TW->>CB: POST /save-voicemail, /updatevoicecalllog,<br/>/updateoutvoicecalllog, /transcribe
  CB->>DB: persist call logs, voicemail, transcript
```

## 3. DrFirst - resilient controller path versus unprotected poll

```mermaid
sequenceDiagram
  participant F as EveryFiveMinutesFunction
  participant CT as DrFirstController
  participant HC as HttpClient "DrFirst"
  participant POL as Polly: retry, circuit-breaker, timeout
  participant DF as DrFirst Rcopia

  F->>DF: new HttpClient() POST get_rcopia_event (timer 0 */5 * * * *, no policy)
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

## 4. Where integration data lands

```mermaid
flowchart LR
  API["PacEHR.API controllers"] --> UPX["Updox JSON API<br/>named client, 30s, no policy"]
  API --> DRF["DrFirst XML API<br/>named client + Polly"]
  API --> MTX["MatrixCare SOAP<br/>named client + client cert"]
  API --> IMO["IMO terminology<br/>IMemoryCache for token and results"]
  API --> TWL["Twilio voice, video, SMS<br/>no signature validation"]
  FN["PacEHR.Functions.Process"] --> DRF
  FN --> PBX["Paubox email"]
  UPX --> SB[("Service Bus queues")]
  MTX --> MSQL[("MatrixCare schema, 16 tables")]
  UPX --> USQL[("Updox schema, 7 tables")]
  API --> BLOB[("Azure Blob")]
  API --> SF["ShareFile, 3 tables"]
```

