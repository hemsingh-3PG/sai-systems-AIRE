# PacEHR — AI Assistance & Dictation Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/12-ai-assistance-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Dragon Copilot dictation - partner JWT, token exchange, start (new)

The API signs a per-user partner JWT and publishes its public key; the browser SDK exchanges it for a Dragon token and starts dictation.

```mermaid
sequenceDiagram
  participant U as Clinician
  participant BTN as DragonRecordButton
  participant SVC as DragonCopilotService (SPA)
  participant API as WebUiTokenController
  participant US as UserService
  participant DB as SQL Account.users
  participant SDK as Dragon Copilot SDK (browser)
  participant DX as Dragon Copilot cloud

  U->>BTN: focus a text field, click Start Dictation
  BTN->>SVC: toggleDictation()
  SVC->>SVC: ensureMicAccess() - toast and stop if the microphone is blocked
  SVC->>SDK: dragon.initialize(services, partnerGuid, daxProductId, acquireAccessToken)
  SDK->>SVC: acquireAccessToken(scope)
  SVC->>API: GET /webUiToken (session token header; cached until ~2 min before expiry)
  API->>API: read userId from HttpContext.Items - 401 if absent
  API->>US: getDragonSub(userId)
  US->>DB: usp_GetDragonSubByUserId(userId)
  DB-->>US: userId, dragonSub (nuanceUserId), email - no row if inactive
  alt dragonSub empty
    API-->>SVC: 403 "not set up for this user", missing nuanceUserId
  else config incomplete
    API-->>SVC: 500 with the list of missing DragonCopilot keys
  else ok
    API->>API: sign RS256 JWT with DragonCopilot:PrivateKey, kid, aud streaming.daxcopilot.com, sub = dragonSub
    API-->>SVC: accessToken, expiresIn 3600, Bearer
  end
  SVC->>SDK: EhrAuthenticationClient.acquireToken(accessToken: partner JWT)
  SDK->>DX: POST token/generate
  DX->>API: GET issuer/.well-known/openid-configuration then jwks_uri (anonymous)
  API-->>DX: discovery document and public key
  DX-->>SDK: Dragon token
  SDK-->>SVC: Dragon token
  loop up to 3 attempts, 2.5 s each
    SVC->>SDK: recording.startRecording(dictation)
    SDK-->>SVC: recordingStarted event
  end
  SDK-->>U: dictated text typed into the focused field
  SVC->>SVC: dispatch input event so ngModel / reactive forms update
```

---

## 2. Ambient dictation over an unauthenticated WebSocket (legacy)

The endpoint is anonymous, streams audio to Google Cloud Speech and persists nothing.

```mermaid
sequenceDiagram
  participant B as Browser (or any WebSocket client)
  participant MW as JWTMiddleware
  participant CT as AIController.Get - speechToText
  participant G as Google Cloud Speech V1

  B->>MW: GET wss://.../speechToText?notesId=&userId=&accountId=&patientId=
  Note over MW: "/speechToText" is in excludedPaths - no body decryption
  Note over MW: [AllowAnonymous] - no token check
  MW->>CT: forward
  CT->>CT: int.TryParse each query value, 0 on failure
  Note over CT: ids are passed to HandleSpeechToText but never used:<br/>only the commented-out blob upload references them
  CT->>CT: AcceptWebSocketAsync()
  CT->>G: StreamingRecognize (credentials loaded from google-credentials.json)
  loop audio frames, 48 kHz mono 16-bit
    B->>CT: binary PCM
    CT->>G: StreamingRecognizeRequest
    G-->>CT: interim and final transcripts
    CT-->>B: transcript JSON (duplicates suppressed via sentTranscripts)
  end
  Note over CT: no database write, audio kept in a per-socket MemoryStream,<br/>blob upload commented out (AIController.cs:792-798)
```

---

## 3. A chat completion - where the safety controls run (legacy)

PHI masking and injection detection run in the browser only; the API forwards the prompt verbatim.

```mermaid
sequenceDiagram
  participant U as Provider
  participant SVC as OpenAiService (browser)
  participant PS as prompt-sanitizer.ts
  participant PM as phi-masker.ts
  participant API as AIController
  participant AS as AIPromptServices
  participant DB as SQL app settings
  participant OAI as OpenAI gpt-4o

  U->>SVC: streamCompletionWithData(systemPrompt, userPrompt, patient)
  SVC->>PS: detectInjection(userPrompt)
  alt injection detected
    PS-->>SVC: patterns
    SVC-->>U: PromptInjectionError - request never sent
  end
  SVC->>PM: maskPHI(userPrompt, patient)
  PM-->>SVC: masked text
  SVC->>SVC: AES-encrypt body with the shared client constant
  SVC->>API: fetch POST /streamCompletionWithData
  rect rgba(255,0,0,0.08)
  Note over API,AS: NO server-side masking or injection check
  API->>AS: StreamOpenAICompletionAsync(systemPrompt, userPrompt)
  AS->>DB: usp_getAppSettingsForMultiple(OPENAI_API_KEY, OPENAI_API_URL)
  DB-->>AS: key and url (falls back to appsettings openAIapiKey)
  AS->>OAI: POST chat/completions - userPrompt VERBATIM
  end
  OAI-->>AS: SSE stream
  AS-->>API: IAsyncEnumerable of string
  API-->>SVC: data chunks
  SVC->>SVC: parse data lines, emit
  SVC-->>U: streamed text
```

---

## 4. Prompt management (legacy)

Stored system prompts edited through an admin screen and filled with placeholder tokens at runtime.

```mermaid
flowchart LR
  A["ai-prompt feature (SPA)<br/>admin UI"] --> B["addEditAIPrompt, deleteAIPrompt<br/>getAIPromptList"]
  B --> C[("AI.prompt table")]
  D["Runtime"] --> E["getPrompt / getAmbientPrompt"]
  E --> C
  C --> F["streamTemplateCompletion<br/>token substitution of the stored system prompt:<br/>templateName, templateProcess, sectionCount,<br/>sectionName, promptBody, encounterFields,<br/>encounterPOS, DOSDate, todayDate"]
  F --> G["OpenAI gpt-4o"]
```

---

## 5. Data model

Users, prompts, AI logs and ambient notes tables touched by this module.

```mermaid
erDiagram
  USERS {
    int userId PK
    varchar email
    varchar speechToText "vendor lookup key or none"
    varchar nuanceUserId "Dragon user id, used as the JWT sub"
    bit isActive
  }
  LOOKUP {
    varchar key "MS Dragon Copilot Speechkit after PAC-584"
    bit isActive
  }
  AI_PROMPT {
    int promptId PK
    nvarchar prompt
    int templateId
    nvarchar promptName
    int accountId
    nvarchar type
    int isUniversal
    bit isDeleted
  }
  AILOGS {
    int Id PK
    int accountId
    int patientId
    int encounterId
    nvarchar system_content
    nvarchar user_content
    nvarchar resp_content
    int total_tokens
  }
  AMBIENT_DETAILS {
    int ambientId PK
    int notesId
    int accountId
    int patientId
    nvarchar ambientNotes
    nvarchar speakerIdentifier
    int sequenceOrder
  }
  ROUNDING_NOTES {
    int notesId PK
    int accountId
    int patientId
  }
  USERS ||--o{ AI_PROMPT : "createdBy"
  USERS ||--o{ AILOGS : "createdBy"
  ROUNDING_NOTES ||--o{ AMBIENT_DETAILS : "notesId"
  USERS }o--o| LOOKUP : "speechToText matches key"
```
