# Deep-Dive - AI Assistance & Dictation

**Date**: 2026-10-19
**Analyzed By**: ARCHITECT
**Status**: Draft (awaiting user confirmation)
**Method**: AIRE `aire-brownfield-deep-dive` - refresh of the 2026-09-30 deep-dive; every claim re-verified against current code
**Scope**: (1) the LEGACY AI path in `pacEHR_API` + `PacEHR` - OpenAI chat completions, Google Cloud Speech ambient dictation over WebSocket, prompt management, client-side PHI masking and prompt-injection detection; (2) the NEW Dragon Copilot dictation (PAC-584) - `dragon-copilot.service.ts`, `WebUiTokenController`, `usp_GetDragonSubByUserId`, `DragonCopilot` DTO. The standalone Node service is covered in `13-pacehr-ai-service-deep-dive.md` and only cross-referenced here.
**Evidence base (HEADs analysed)**: `PacEHR` @ `401caa134`, `pacEHR_API` @ `0f611f65c`, `pacEHR_AI` @ `ef172ea`. Previous deep-dive: `pacEHR_API` @ `9f2a6ee19`, `PacEHR` @ `3034de845`.

> **Headline finding (new)**: the Dragon Copilot partner-JWT **RSA private key is committed** in all six environment config files, **including `appsettings.Production.json`**, and the **same key** (identical 1,700-character value) is used in every environment. The public half is published by the API itself at `/.well-known/jwks.json` under `kid` `dragon-saisystems-key-1`, so anyone with repository read access can mint a Dragon partner token for any `sub`. `appsettings.json` says the opposite in a comment ("PrivateKey MUST come from Key Vault ... never committed here").
>
> **Carried, corrected**: `/speechToText` is still an `[AllowAnonymous]` WebSocket and still excluded from `JWTMiddleware`'s body handling and token check, so any caller can stream audio to Google Cloud Speech (billable). But the old claim that a caller can have a transcript **written to any patient's chart is not supported by the code** - the four query-string ids are passed into `HandleSpeechToText` and used only in commented-out code; nothing is persisted (see Changes #2).
>
> **Carried**: PHI masking and prompt-injection detection run **only in the browser**; the API forwards `userPrompt` to OpenAI verbatim. Live OpenAI keys remain committed in 5 of 7 `appsettings*.json` files.

---

## Changes since 2026-09-30

| # | Change / correction | Evidence |
|---|---|---|
| 1 | **New**: Dragon Copilot dictation replaces the retired Nuance SpeechAnywhere integration (PAC-584, PAC-1396; commits `713917770`, `0f3f5e3ec`, `a1a367410` API, 2026-10-05/06; SPA `d1d8307b3`, `d6570ff1f`, `162057e10`, 2026-10-05/08). New API surface: `GET /webUiToken` (authenticated), `GET /.well-known/openid-configuration` and `GET /.well-known/jwks.json` (both `[AllowAnonymous]`). New proc `usp_GetDragonSubByUserId`, new DTO `usp_GetDragonSubByUserIdResult`, new `IUserService.getDragonSub`. | `WebUiTokenController.cs:42,167,201`; `UserService.cs:375-379`; `pacEHR.Data.Dtos/DragonCopilot.cs` |
| 2 | **Corrected**: the old doc said the WebSocket handler "persists transcript against notesId / patientId" and listed *integrity* ("forged transcripts on any patient's chart") as a risk. In `HandleSpeechToText` (`AIController.cs:481-813`) `notesId`, `userId`, `accountId`, `patientId` appear only in the signature and in commented-out blob-upload code (`:792-798`). No database call is made; transcripts are only sent back over the socket. **Integrity finding dropped**; cost (unauthenticated billable Google streaming) and unbounded memory remain. | `AIController.cs:481,792-798`; no `_proceduresInterface`/service call between 481-813 |
| 3 | **Corrected**: the old test table said `AIController` and `AIPromptServices` have "none found". `AIControllerTests.cs` (63 tests, added 2026-05-07) exists and runs in the PR pipeline's controller subset; `AIPromptServicesTest.cs` (13 tests) exists but is **excluded from compilation** by the csproj `Compile Remove="DomainServices\**"` (module 11). No test references `speechToText`. | `PacEHR.Tests.UnitTests/Controllers/AIControllerTests.cs`; `PacEHR.Tests.UnitTests.csproj:13-18` |
| 4 | **Corrected/extended**: committed OpenAI keys: `APIkeySettings:openAIapiKey` is present in `appsettings.json`, `.QA`, `.Uat`, `.Test`, `.Automation` (one identical 56-character value in all five) and `.Development` (a different 164-character value). `appsettings.Production.json` has **no** `openAIapiKey`. `"gpt-4o"` is hardcoded **4 times** (old doc: "at least two"). | `appsettings*.json` (grep + value hashes); `AIPromptServices.cs:176,230,282` + one more |
| 5 | **Unchanged and re-confirmed**: `AIController.cs` 1,152 lines / 23 `[Route]`s; `AIPromptServices.cs` 365 lines; `open-ai.service.ts` 423; `phi-masker.ts` 304; `prompt-sanitizer.ts` 115 - **no commits to any of these since 2026-09-10**. | `git log --since=2026-09-10` |
| 6 | **Re-confirmed**: no server-side PHI masking / injection check; `Google-Credentials.json` (service-account key, added 2026-01-09) is tracked in git; `phi-masker.ts` / `prompt-sanitizer.ts` have no spec file. | `git ls-files`; `find src -name 'phi-masker*'` |
| 7 | **New**: Dragon dictation in the SPA is wired into the encounter form, rounding notes, patient notes, patient alert, mobile encounter facade, and the new guided-workflow Note Capture bar (AITP-32). Gated by the user's `isspeechToText` setting (`'none'` = off). | `grep -ril dragon src/app` |
| 8 | **New**: SQL migration `PAC-584-AlterScripts.sql` copies `Account.users.nuanceUserId` to `nuanceUserId_old`, **sets `nuanceUserId = NULL` for every user**, renames lookup `Nuance Enterprise Speechkit` to `MS Dragon Copilot Speechkit` and deactivates `Nuance Trial Speechkit`. The script ends with `COMMIT TRANSACTION` commented out. | `Scripts/Script.16-Oct-2026/PAC-584-AlterScripts.sql` |
| 9 | **Cross-reference**: the Node `pacEHR_AI` service (Azure OpenAI gpt-4.1, LangChain agent, guards) is not yet called by this module's code paths - see module 13. The SPA's `guided-workflow` feature (AITP-32/117) is the UI that will sit in front of it. | `13-pacehr-ai-service-deep-dive.md` |

---

## Module Overview

| Component | Path | Size (re-measured) |
|---|---|---|
| `AIController` (legacy) | `pacEHR_API/PacEHR.API/Controllers/AIController.cs` | **1,152 lines, 23 routes** (unchanged) |
| `AIPromptServices` (legacy) | `pacEHR_API/pacEHR.DomainServices/AIPromptServices.cs` | 365 lines (unchanged) |
| `WebUiTokenController` (new) | `pacEHR_API/PacEHR.API/Controllers/WebUiTokenController.cs` | 252 lines, 3 routes |
| `usp_GetDragonSubByUserId` (new) | `pacEHR_API/PacEHR.Database/Stored Procedures/Procs2/usp_GetDragonSubByUserId.sql` | 26 lines |
| `DragonCopilot` DTO (new) | `pacEHR_API/pacEHR.Data.Dtos/DragonCopilot.cs` | `usp_GetDragonSubByUserIdResult { userId, dragonSub, email }` |
| `UserService.getDragonSub` (new) | `pacEHR_API/pacEHR.DomainServices/UserService.cs:375-379` | 5 lines |
| `DragonCopilotService` (new, SPA) | `PacEHR/src/app/core/services/dragon-copilot.service.ts` | **969 lines** |
| `DragonRecordButtonComponent` (new, SPA) | `PacEHR/src/app/_shared/components/dragon-record-button/` | 153 lines + spec |
| `OpenAiService` (legacy, SPA) | `PacEHR/src/app/core/services/open-ai.service.ts` | 423 lines (also owns the WebSocket dictation client) |
| PHI masker (SPA) | `PacEHR/src/app/configs/phi-masker.ts` | 304 lines |
| Prompt sanitiser (SPA) | `PacEHR/src/app/configs/prompt-sanitizer.ts` | 115 lines |
| Prompt admin UI | `PacEHR/src/app/features/ai-prompt/` | component + `add-edit-ai-prompt` |
| Storage | `AI.prompt`, `Log.AILogs`, `Patient.AmbientDetails`, `Patient.roundingNotes`, ambient error/audio tables, `Account.users` (`nuanceUserId`, `speechToText`), app-settings rows | |

**Supplementary documents** `12a-ai-request-payload-reference.md` and `12b-ai-prompt-examples.md`: banner re-checked in this pass. The source files they document have no commits since 2026-09-10, so the legacy content is expected to hold; it was **carried, not re-verified line by line**, and it does not cover Dragon or `pacEHR_AI`.

### Two dictation vendors, one setting

`Account.users.speechToText` (VARCHAR 255) is surfaced to the SPA as `isspeechToText` (`login.component.ts:254,641`, `header.component.ts:2589`). Dragon UI is shown when the value is neither empty nor `'none'` (`DragonCopilotService.isSpeechEnabled`, `dragon-copilot.service.ts:28-30`; `encounter-form.component.html:5`). The legacy Google ambient path is started separately from the rounding-note screen (`add-rounding-notes.component.ts:738,1280`). The two coexist.

### `AIController` routes (23, unchanged)

| Group | Routes |
|---|---|
| Prompt management | `addEditAIPrompt`, `getAIPromptList`, `deleteAIPrompt`, `getPrompt`, `getAmbientPrompt` |
| Completions | `getCompletion`, `streamCompletion`, `streamCompletionWithData`, `streamTemplateCompletion` |
| Dictation | `speechToText` (WebSocket) |
| Ambient notes | `getAmbientDetails`, `addEditAmbientDetails`, `deleteAmbientDetails` |
| Rounding notes | `addEditRoundingNotes`, `getPatientRoundingNote`, `getRoundingNotesByEncounter`, `deleteRoundingNote` |
| Context | `getPreviousEncounterDetails`, `getPatientDetailsByProviderFacility`, `getImportPatientDetailsToEncounterForm` |
| External patients | `addExternalPatients`, `getExternalPatientDetails` |
| Logging | `addEditAILogs` |

### `WebUiTokenController` routes (3, new)

| Route | Auth | Behaviour |
|---|---|---|
| `GET /webUiToken` | authenticated (JWTMiddleware sets `Items["userId"]`, `JWTMiddleware.cs:141`) | 401 if no user id; 403 `{ missing: ["nuanceUserId"] }` if the user has no Dragon id; 500 `{ missing: [...] }` listing absent config keys; else RS256 JWT, lifetime 3600 s (+300 s clock-skew backdating) |
| `GET /.well-known/openid-configuration` | `[AllowAnonymous]` | `{ issuer, jwks_uri, id_token_signing_alg_values_supported, subject_types_supported }`; `Cache-Control: public, max-age=3600`; `Access-Control-Allow-Origin: *` |
| `GET /.well-known/jwks.json` | `[AllowAnonymous]` | Public RSA key (`kty, use, alg, kid, n, e`) derived from the same `DragonCopilot:PrivateKey` |

---

## Component Breakdown

| Layer | Component | Responsibility |
|---|---|---|
| SPA | `DragonCopilotService` | Loads the Dragon Copilot SDK (`window.DragonCopilotSDK`), initialises it, exchanges the API's partner JWT for a Dragon token, starts/stops dictation, pushes SDK DOM writes into Angular forms via synthetic `input` events, handles voice commands ("move to field"), microphone-permission state, retry-until-confirmed start (3 attempts x 2.5 s) |
| SPA | `DragonRecordButtonComponent` | Start/stop control shown in a host form once a text field is focused; shows mic-blocked popup |
| SPA | `index.html:20-22` | Loads the SDK script from `download.microsoft.com` (`dragon-copilot-sdk-mainline.js`) - an **unpinned "mainline" build** |
| SPA | `environment*.ts` `dragonCopilot` block | `services: 'us'`, `partnerGuid`, `environmentId`, `customerId`, `productId`, `tokenEndpoint: 'webUiToken'`, `scope` (GUID identifiers, not secrets) |
| API | `WebUiTokenController` | Looks up the caller's Dragon id, signs the partner JWT, publishes OIDC discovery + JWKS so Dragon can verify it |
| API | `IUserService.getDragonSub` -> `usp_GetDragonSubByUserIdAsync` | `SELECT TOP 1 userId, NULLIF(LTRIM(RTRIM(nuanceUserId)),'') AS dragonSub, email FROM Account.users WITH (NOLOCK) WHERE userId=@userId AND isActive=1` |
| Config | `DragonCopilot:{Issuer, KeyId, PrivateKey, Audience, EnvironmentId, CustomerId, ClockSkewSeconds, JwksUri}` | Read via `IConfiguration`. `DragonCopilot:Subject` exists in every appsettings file but **no code reads it** (dead config) |
| Legacy SPA | `OpenAiService` | `getCompletion`, `streamCompletion`, `streamCompletionWithData` (via `fetch` + manual AES encryption), WebSocket dictation (`startStreaming` / `pauseStreaming` / `resumeStreaming` / `stopStreaming`, 48 kHz `AudioContext`) |
| Legacy SPA | `phi-masker.ts`, `prompt-sanitizer.ts` | Client-side PHI redaction and injection detection |
| Legacy API | `AIController` + `AIPromptServices` | Prompt CRUD, 4 OpenAI call shapes (3 streaming/1 not), Google Speech WebSocket, ambient/rounding-note CRUD |

---

## Key Workflows

### Workflow 1 (NEW): Dragon Copilot dictation - partner JWT, token exchange, start

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

Observations (all verified in code):

1. The per-user `sub` is the user's own `nuanceUserId` - each clinician dictates as themselves (`usp_GetDragonSubByUserId.sql` header comment). A user without one gets a 403 with `missing: ["nuanceUserId"]`, which the SPA surfaces as a toast (`dragon-copilot.service.ts:617-650`).
2. `exp` = now + 3,600 + 300 s skew, `iat`/`nbf` backdated by 300 s, but the response reports `expiresIn: 3600` (`WebUiTokenController.cs:106-110,147`).
3. The token is cached client-side until ~2 minutes before expiry and concurrent callers share one request (`:617-650`).
4. `PrivateKey` is read from `IConfiguration` with `\n` unescaping (`:93`) - so it is intended to arrive from Key Vault / env, but the repo also carries a committed value (see Pattern "committed signing key").
5. The SDK is initialised with `isAmbientEnabled: false`; only dictation is enabled (`dragon-copilot.service.ts:323-331`).
6. `traceJwt` decodes claims for diagnostics only when `localStorage.dragonDebug === '1'`; it never logs a raw token (`:90-130`).

### Workflow 2 (LEGACY, corrected): Ambient dictation over an unauthenticated WebSocket

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

Verified facts:

1. Exempt from authentication twice: `[AllowAnonymous]` (`AIController.cs:440`) **and** `JWTMiddleware.excludedPaths` (`JWTMiddleware.cs:49`). Note that `excludedPaths` only skips body decryption - the token check is skipped because of `[AllowAnonymous]`.
2. Id parsing: `int.TryParse ... = 0; // or return 400 if mandatory` for all four ids (`AIController.cs:452-469`).
3. **No persistence and no use of the ids** between `HandleSpeechToText` (`:481`) and its end (`:813`) other than the commented-out upload (`:792-798`). The old "integrity" risk (forged transcripts on a patient's chart) therefore does not exist in the current code; if the upload is ever re-enabled the ids would become security-critical.
4. Remaining risks: **cost** (anonymous, billable Google streaming; no rate limit seen), **availability** (unbounded per-socket `MemoryStream`, `:498`), and **credential handling** (below).
5. Pause/resume and duplicate suppression are carefully implemented (`isPaused`, `pauseStartTime`, `totalPausedDuration`, `sentTranscripts`, `pendingTranscripts`).
6. Credentials: `GoogleCredential.FromFile("google-credentials.json")` (`:609-612`) - lower-case file name; the tracked file is `PacEHR.API/Google-Credentials.json` (a `service_account` key, added 2026-01-09). No `csproj` copy rule for it was found; **how the file reaches the deployed artifact was not verified**.

### Workflow 3 (LEGACY, carried): A chat completion - where the safety controls run

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

Carried from the previous deep-dive and spot-checked: DB-first key lookup with `appsettings` fallback at `AIPromptServices.cs:161-163` (and the three sibling methods at 215-217, 267-269, 319-320); `model = "gpt-4o"`, `temperature = 0` (`:176-178`).

### Workflow 4 (LEGACY, carried): Prompt management

```mermaid
flowchart LR
  A["ai-prompt feature (SPA)<br/>admin UI"] --> B["addEditAIPrompt, deleteAIPrompt<br/>getAIPromptList"]
  B --> C[("AI.prompt table")]
  D["Runtime"] --> E["getPrompt / getAmbientPrompt"]
  E --> C
  C --> F["streamTemplateCompletion<br/>token substitution of the stored system prompt:<br/>templateName, templateProcess, sectionCount,<br/>sectionName, promptBody, encounterFields,<br/>encounterPOS, DOSDate, todayDate"]
  F --> G["OpenAI gpt-4o"]
```

System prompts are stored in `AI.prompt` and edited through an admin screen (`AIPromptServices.cs:40,77,97`). The nine-token substitution list is **carried, not re-verified** in this pass (the file has not changed since 2026-09-10).

---

## Data Models

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

Notes: table definitions from `PacEHR.Database/Tables/Tables1/{prompt,AILogs,AmbientDetails}.sql` and `Tables2/users.sql:52,57`; `AI.prompt` lives in schema `AI`, `AILogs` in `Log`, `AmbientDetails` in `Patient`, `users` in `Account`. The `USERS`-`LOOKUP` link is **logical only** (no FK was verified; `speechToText` is a `VARCHAR`). `roundingNotes` columns are abbreviated (key columns only - full column list not re-read). `nuanceUserId_old` exists only if the PAC-584 alter script has been run; it is not in `users.sql`.

DTO (new): `usp_GetDragonSubByUserIdResult { int userId; string? dragonSub; string? email }` - `dragonSub` is `NULL` when the user has no Dragon id.

---

## Pattern Catalog

### Pattern: committed signing key (NEW) - critical

```json
// ACTUAL - PacEHR.API/appsettings.Production.json:47 (and .Development:217, .QA:198, .Uat:210, .Test:200, .Automation:198)
"PrivateKey": "-----BEGIN RSA PRIVATE KEY-----\n<redacted - 1,700 chars, identical in all six files>..."
```

```csharp
// DO - per the comment already in appsettings.json:3-4 and :10-11
// "PrivateKey MUST come from Key Vault (deployed) or user-secrets / env var (local) - never committed here."
// Declare no PrivateKey in any committed file; WebUiTokenController already reads IConfiguration["DragonCopilot:PrivateKey"].
```

Evidence: all six `appsettings.<Env>.json` files carry a `DragonCopilot.PrivateKey` whose SHA-256 prefix is identical (`b722958690`); it first appeared in `4fcacd350` ("Merged PR 12351: PAC-584 ... partner JWT", 2026-10-06). The matching public key is served anonymously by `GetJwks` (`WebUiTokenController.cs:201-244`) under `kid` `dragon-saisystems-key-1`. Impact: repository read access is sufficient to forge a Dragon token for any `sub` in the Saisystems Dragon tenant, in any environment. Rotation requires a new key pair, a new `kid`, and Dragon-side re-registration of the issuer; history purge is also needed because the key is in git history.

### Pattern: committed third-party credentials (carried, extended)

```csharp
// ACTUAL - AIPromptServices.cs:161-163 (repeated at 215-217, 267-269, 319-320)
var settings = await _proceduresInterface.usp_getAppSettingsForMultipleAsync("OPENAI_API_KEY,OPENAI_API_URL");
var apiKey = settings.FirstOrDefault(s => s.key == "OPENAI_API_KEY")?.value
             ?? _configuration["APIkeySettings:openAIapiKey"];   // appsettings fallback is live
```

- `openAIapiKey` committed in `appsettings.json`, `.QA`, `.Uat`, `.Test`, `.Automation` (one identical 56-char value) and `.Development` (a different 164-char value); absent from `.Production`.
- `PacEHR.API/Google-Credentials.json` - a `service_account` key file tracked since 2026-01-09.
- Still open from 2026-09-08: whether the SQL `OPENAI_API_KEY` row exists in every environment (gates safe rotation), and whether the Google key was ever rotated.

### Pattern: error handling

```csharp
// DO - Dragon controller: specific status per failure, names what is missing, never echoes key material
// WebUiTokenController.cs:52,60-64,90
return StatusCode(401, new { error = "No signed-in user." });
return StatusCode(403, new { error = "Dragon dictation is not set up for this user.", missing = new[] { "nuanceUserId" } });
return StatusCode(500, new { error = "Dragon Copilot token configuration is incomplete.", missing });
```

```csharp
// DON'T - legacy controller: log and rethrow, with a 200 + "F" envelope for business failures
// AIController.cs:175-178 (pattern repeated through the file; HandleSpeechToText itself uses Console.WriteLine + throw at :808-812)
catch (Exception ex) { ApplicationInsightsLogger.LogError(_telemetry, ex); throw; }
```

The new controller deliberately does not use the `BuildDictionaryResult` envelope (it returns bare JSON, and standards-shaped documents for `.well-known`); the SPA reads `err.error.missing` from it (`dragon-copilot.service.ts:640-645`). Note `GetOpenIdConfiguration` rethrows (`:197`) whereas `GetJwks` returns a 500 body (`:242`) - inconsistent.

SPA side: Dragon failures are mapped to a user-readable `initError` / `authFailure` and a toast (`dragon-copilot.service.ts:486-491`) instead of silent no-ops.

### Pattern: logging

```csharp
// DO - Application Insights, no secrets (WebUiTokenController.cs:141-142)
ApplicationInsightsLogger.LogInfo(_telemetry, $"Dragon JWT signed - user={userId} sub={subject} iss={issuer}");
```

`sub` (the user's Dragon id) is logged on every token mint - acceptable but worth a retention decision. Legacy `AIController` logs start/success/"No Data Found" strings per route. The SPA logs with `console.*` and gates verbose tracing behind `localStorage.dragonDebug` (`dragon-copilot.service.ts:90-101`), never logging a raw token.

### Pattern: database access

```csharp
// DO - one proc call behind an interface, covered by a unit test
// UserService.cs:375-379; UserServiceTest.cs:786-795 (#region getDragonSub (PAC-584))
var rows = await _proceduresInterface.usp_GetDragonSubByUserIdAsync(userId);
return rows.FirstOrDefault();
```

`usp_GetDragonSubByUserId` is `SELECT TOP 1 ... WITH (NOLOCK)`, filtered to `isActive = 1`, trimming blanks to `NULL` (`NULLIF(LTRIM(RTRIM(...)),'')`). Legacy AI code uses the same `_proceduresInterface.usp_*Async` pattern; the OpenAI key lookup runs a DB query on **every** completion call (no caching).

### Pattern: API response

New controller: bare JSON bodies (`{ accessToken, expiresIn, token_type }`) and OIDC/JWKS documents with `Cache-Control: public, max-age=3600` and `Access-Control-Allow-Origin: *`. Legacy controller: `IDictionary<string,object>` via `BuildDictionaryResult(200, "Y"/"F", msg, data)`.

### Pattern: naming

SPA: `dragon-copilot.service.ts`, `dragon-record-button.component.ts` (kebab-case, brand-neutral suffix) while the user property is still named after the old vendor: `nuanceUser`, `speechToTextCooke` (sic), `nuanceUserId` (`notes.component.ts:108-111`, `add-rounding-notes.component.ts:176-178`, `login.component.ts:55`). DB column `Account.users.nuanceUserId` stays Nuance-named while holding a Dragon Copilot id - the rename was done in the lookup values only. API route naming: `webUiToken`, `.well-known/*` follow the established lowerCamel-route convention except where a standard dictates otherwise.

### Pattern: strong - PHI masker and prompt-injection detection (carried, still good)

`phi-masker.ts` (304 lines; two-pass: exact patient values, then regex sweep; `NAME_COMMON_WORD_SKIPLIST` so "stool was brown" survives) and `prompt-sanitizer.ts` (115 lines; fail-closed `PromptInjectionError`) are well constructed, applied at all three `OpenAiService` entry points, and the AI audit log (`AddEditAILogs`) is masked too. Unchanged since 2026-09-10.

### Pattern: weak - both controls are client-side only (carried, re-confirmed)

```csharp
// ACTUAL - AIPromptServices.cs:171-185 (shape repeated in 4 methods): userPrompt used as received
messages = new[] { new { role = "system", content = systemPrompt }, new { role = "user", content = userPrompt } }
```

No `maskPhi`/`redact`/`detectInjection` anywhere in `pacEHR_API`. A modified client, direct API call, or an SPA call site that omits the optional `patient` argument bypasses masking (Pass 1 is silently skipped; only the regex sweep runs). Decision context outside this repo: `pacEHR_AI` records that Azure OpenAI is BAA-covered and PHI masking there was closed by decision; **no equivalent decision is recorded for the legacy `api.openai.com`-style path** (BAA position open - Question 5).

### Pattern: weak - anonymous WebSocket (carried, narrowed)

```csharp
// ACTUAL - AIController.cs:438-472
[Route("speechToText")]
[HttpGet]
[AllowAnonymous]
...
if (!int.TryParse(userIdStr, out int userId)) { userId = 0; // or return 400 if mandatory }
var webSocket = await HttpContext.WebSockets.AcceptWebSocketAsync();
```

```csharp
// DO - authenticate the upgrade with a short-lived single-use ticket obtained from an authenticated endpoint
// (browsers cannot set custom headers on WebSocket upgrades); derive identity server-side; do not accept ids from the query.
```

The new `/webUiToken` endpoint is effectively the pattern the legacy WebSocket lacks: authenticated, user derived from the session, short-lived token.

### Pattern: weak - hardcoded model, `AIController` mixes concerns, leftover fields (carried, re-confirmed)

- `model = "gpt-4o"` literal x4 in `AIPromptServices.cs` while key/URL are configurable.
- `AIController` (1,152 lines) mixes prompt CRUD, completions, WebSocket streaming, ambient/rounding-note CRUD, external patients and logging; instance fields `audioStartTime`, `sentTranscripts`, `_audioBuffer` (`:22-27`) shadow the live locals in `HandleSpeechToText`.
- `streamCompletionWithData` in the SPA re-implements header building and body encryption outside the interceptors (cost of using `fetch` for streaming) - a path that silently misses future interceptor changes.

### Pattern: weak - unpinned SDK and a 969-line service (NEW)

`index.html:22` loads `dragon-copilot-sdk-mainline.js` - a moving "mainline" build from `download.microsoft.com`, with no integrity attribute and no version pin. `dragon-copilot.service.ts` is 969 lines mixing SDK init, token exchange, mic permission, field watching and voice-command resolution (`handleVoiceCommand`, `resolveTarget`, `buildTargetIndex` from line 718). The comments cite an SDK API that changed shape between versions (event renamed to `dictationProcessingFinishedForElement`, option spelled `scopeBehavor` "sic"), which is exactly the risk of an unpinned script.

---

## Testing Patterns

| Target | Tests | Notes |
|---|---|---|
| `WebUiTokenController` | **37** xUnit tests (`WebUiTokenControllerTests.cs`) | claims, header, skew, signature verified against the published JWKS, 401/403/500 branches, PEM escapes, no exception detail leak - well covered |
| `UserService.getDragonSub` | tests in `UserServiceTest.cs:786+` | |
| `dragon-copilot.service.ts` | 35 `it(` in `dragon-copilot.service.spec.ts` (541 lines) | |
| `dragon-record-button.component.ts` | 5 `it(` | |
| `add-rounding-notes.component` | 19 `it(` | includes Dragon-related behaviour (file references dragon) |
| `AIController` | 63 tests (`AIControllerTests.cs`) | CRUD routes; **0 for `speechToText`** and completions not seen - route list not exhaustively re-checked |
| `AIPromptServices` | 13 tests in `AIPromptServicesTest.cs` - **not compiled** (csproj `Compile Remove`) | |
| `phi-masker.ts` (304 lines) | **0** | pure, dependency-free, ideal test target |
| `prompt-sanitizer.ts` (115 lines) | **0** | |
| `HandleSpeechToText` state machine | **0** | |
| `ai-prompt.component.spec.ts` | present | |

```csharp
// DO - signature-verifies the minted token against the JWKS the same controller publishes
// WebUiTokenControllerTests.cs:488
public void wellKnownJwksJson_PublishedKey_VerifiesATokenFromWebUiToken()
```

The Dragon work arrived with tests (37 + 35 + 5); the legacy privacy controls still have none.

---

## Entry Points

| Entry | Route / trigger | Auth | Notes |
|---|---|---|---|
| Dragon token | `GET /webUiToken` | authenticated | per-user JWT; 401/403/500 as above |
| Dragon issuer discovery | `GET /.well-known/openid-configuration` | anonymous (by design, Dragon calls server-to-server) | public, cached 1 h, CORS `*` |
| Dragon JWKS | `GET /.well-known/jwks.json` | anonymous (by design) | public key only |
| Dictation (legacy) | `GET /speechToText` (WebSocket) | **anonymous** | ids from query string, unused |
| Completion | `POST /getCompletion` | authenticated | non-streaming |
| Streaming | `POST /streamCompletion`, `/streamCompletionWithData`, `/streamTemplateCompletion` | authenticated | SSE via `fetch` |
| Prompt admin / runtime | `POST /addEditAIPrompt`, `/getAIPromptList`, `/deleteAIPrompt`, `/getPrompt`, `/getAmbientPrompt` | authenticated | |
| Ambient / rounding notes | `POST /getAmbientDetails`, `/addEditAmbientDetails`, `/deleteAmbientDetails`, `/addEditRoundingNotes`, `/getPatientRoundingNote`, `/getRoundingNotesByEncounter`, `/deleteRoundingNote` | authenticated | |
| AI logging | `POST /addEditAILogs` | authenticated | masked client-side |
| SPA dictation | `DragonRecordButton`, guided-workflow Note Capture bar | user setting `isspeechToText` not `'none'` | |

---

## Open Questions for the Team

1. **Is the committed Dragon `PrivateKey` the real production key, and has Dragon-side registration been rotated?** The same value is in every environment's file. (New, highest priority.)
2. **Is `/speechToText` reachable from the public internet?** If yes, it is an open billable Google Speech proxy. (Carried; integrity risk dropped.)
3. **Should the dormant ids on `/speechToText` be removed?** They suggest persistence that does not happen; the blob upload is commented out (audio is discarded). If recordings are needed for review, they are not being kept.
4. **Are `OPENAI_API_KEY` / `OPENAI_API_URL` populated in SQL app-settings for every environment?** (Open since 2026-09-08.) Gates rotation of the five identical committed keys.
5. **What is the BAA position for the legacy OpenAI endpoint and Google Cloud Speech?** The Azure OpenAI BAA recorded for `pacEHR_AI` does not obviously cover them.
6. **Was client-only PHI masking a deliberate, accepted decision for the legacy path?** (Open since 2026-09-08.)
7. **Has every active clinician been re-provisioned a Dragon id after the PAC-584 script nulled `nuanceUserId`?** Without it `/webUiToken` returns 403 for them.
8. **Is the PAC-584 alter script (with `COMMIT` commented out) the one that was applied in production?** Not verifiable from the repo.
9. **Can the Dragon SDK URL be pinned to a versioned build?**
10. **Will the legacy completion/ambient paths be retired in favour of `pacEHR_AI`?** (See module 13 and `12-ai-assistance-target-architecture-diagrams.md`.)

---

## Recommendations

| # | Recommendation | Rationale | Priority |
|---|---|---|---|
| 1 | Rotate the Dragon signing key and `kid`; remove `PrivateKey` from all six `appsettings.<Env>.json`; load it from Key Vault; give each environment its own key; purge from git history | Committed, identical across environments incl. Production; public half is published | Immediate |
| 2 | Rotate the committed OpenAI keys and `Google-Credentials.json`; purge from history; remove the `appsettings` fallback after confirming SQL rows | Live third-party credentials in source control | Immediate |
| 3 | Authenticate `/speechToText` (short-lived ticket), derive identity server-side, remove the unused id parameters (or authorise them if persistence returns) | Anonymous billable endpoint | Immediate |
| 4 | Port `maskPHI` and `detectInjection` to the API (or retire the legacy path in favour of `pacEHR_AI`) | Controls protecting PHI from a third-party LLM run only in the browser | High |
| 5 | Add unit tests for `phi-masker.ts` and `prompt-sanitizer.ts` | Pure functions; correctness equals PHI containment | High |
| 6 | Repair and re-include `AIPromptServicesTest.cs`; add `speechToText` and completion-route tests | 13 tests are not compiled; entry points uncovered | High |
| 7 | Confirm every clinician has a `nuanceUserId`; surface the 403 in an admin report | Dictation fails per user otherwise | Medium |
| 8 | Pin the Dragon SDK script version (and add SRI if the vendor allows) | Unpinned "mainline" build | Medium |
| 9 | Bound or remove the per-socket `MemoryStream` audio buffer | Unbounded memory per anonymous socket | Medium |
| 10 | Make the model id configurable; split `AIController` into prompt / completion / dictation controllers | 4 hardcoded `gpt-4o`; 1,152 lines | Medium |
| 11 | Rename `nuanceUser`/`speechToTextCooke`/`nuanceUserId` to vendor-neutral names (DB column via a view or alias) | Naming still reflects the retired vendor | Low |
| 12 | Delete dead config `DragonCopilot:Subject` and the unused controller instance fields | Imply behaviour that does not exist | Low |
| 13 | Split `dragon-copilot.service.ts` (SDK init / auth / voice commands) | 969 lines, three concerns | Low |

---

**Cross-references**: `11-test-infrastructure-cicd-deep-dive.md` (why `AIPromptServicesTest` does not run), `13-pacehr-ai-service-deep-dive.md` (the Node AI service), `12-ai-assistance-target-architecture-diagrams.md` and `12-ai-phase1-implementation-architecture-diagrams.md` in `docs/architecture-diagrams/` (design-time diagrams, not edited in this pass).
