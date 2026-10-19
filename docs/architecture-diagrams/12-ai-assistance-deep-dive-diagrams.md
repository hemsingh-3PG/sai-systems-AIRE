# PacEHR — AI Assistance & Dictation Diagrams

**Date**: 2026-09-30
**Source**: `docs/architecture/current/12-ai-assistance-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Ambient dictation over an unauthenticated WebSocket

`/speechToText` is exempt from authentication twice, and takes patient and account identity from the query string.

```mermaid
sequenceDiagram
  participant B as Browser (or any WebSocket client)
  participant MW as JWTMiddleware
  participant CT as AIController.Get — /speechToText
  participant G as Google Cloud Speech V1
  participant DB as SQL

  B->>MW: GET wss://.../speechToText?notesId=&userId=&accountId=&patientId=
  Note over MW: /speechToText is in excludedPaths → no body decryption
  Note over MW: [AllowAnonymous] → no authentication
  MW->>CT: forward
  CT->>CT: int.TryParse(query userId)    → 0 on failure
  CT->>CT: int.TryParse(query accountId) → 0 on failure
  CT->>CT: int.TryParse(query patientId) → 0 on failure
  Note over CT: no ownership check — the caller names<br/>the patient and account it writes to
  CT->>CT: AcceptWebSocketAsync()
  loop audio frames, 48kHz mono 16-bit
    B->>CT: binary PCM
    CT->>G: StreamingRecognize (Google-Credentials.json)
    G-->>CT: interim + final transcripts
    CT-->>B: transcript JSON (deduped via sentTranscripts)
  end
  CT->>DB: persist transcript against notesId / patientId
  Note over CT: audio itself is buffered in memory;<br/>the blob upload is commented out
```

---

## 2. A chat completion — where the safety controls run

PHI masking and injection detection happen in the browser. The API forwards the prompt verbatim.

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
    SVC-->>U: PromptInjectionError — request never sent
  end
  SVC->>PM: maskPHI(userPrompt, patient)
  PM-->>SVC: masked text
  SVC->>SVC: AES-encrypt body with SecretKey123
  SVC->>API: fetch POST /streamCompletionWithData
  rect rgba(255,0,0,0.08)
  Note over API,AS: NO server-side masking or injection check
  API->>AS: StreamOpenAICompletionAsync(systemPrompt, userPrompt)
  AS->>DB: usp_getAppSettingsForMultiple(OPENAI_API_KEY, OPENAI_API_URL)
  DB-->>AS: key + url (falls back to appsettings openAIapiKey)
  AS->>OAI: POST chat/completions — userPrompt VERBATIM
  end
  OAI-->>AS: SSE stream
  AS-->>API: IAsyncEnumerable<string>
  API-->>SVC: data chunks
  SVC->>SVC: parse data lines, emit
  SVC-->>U: streamed text
```

---

## 3. Prompt management

System prompts live in the database and are edited through an admin screen; nine tokens are substituted at runtime.

```mermaid
flowchart LR
  A["ai-prompt feature (SPA)<br/>admin UI"] --> B["addEditAIPrompt · deleteAIPrompt<br/>getAIPromptList"]
  B --> C[("AI schema + prompt tables")]
  D["Runtime"] --> E["getPrompt / getAmbientPrompt"]
  E --> C
  C --> F["streamTemplateCompletion<br/>token substitution:<br/>templateName · templateProcess<br/>sectionCount · sectionName<br/>promptBody · encounterFields<br/>encounterPOS · DOSDate · todayDate"]
  F --> G["OpenAI gpt-4o"]
```

---

**Full analysis**: `docs/architecture/current/12-ai-assistance-deep-dive.md`
