# PacEHR - pacEHR_AI Service Diagrams

**Date**: 2026-10-19
**Source**: `docs/architecture/current/13-pacehr-ai-service-deep-dive.md`
**Produced by**: ARCHITECT (`aire-brownfield-deep-dive`, Phase 6)
**Audience**: BA / Product / anyone who wants the pictures without the prose

---

## 1. Where the service sits

The service in context: callers (none in production), the in-process layers and the Azure dependencies.

```mermaid
flowchart LR
  subgraph Callers["Callers (none today)"]
    NET["Planned: .NET API proxy<br/>or Epic 9 extract endpoint"]
    EVAL["tests/eval gate<br/>(developer machine, VPN)"]
    DEMO["tests/manual streamServer<br/>Dockerfile.stream demo"]
  end
  subgraph Svc["pacEHR_AI process"]
    HTTP["core/app.ts<br/>GET /health, /health/ready"]
    AGENT["agents/encounter.ts<br/>invoke and stream"]
    MW["4 middleware<br/>guard, model call, evidence, outcome"]
    GRD["guards<br/>injection, limits, phi"]
    SCH["schema<br/>builder and contract"]
    SRV["services, repositories, mappers"]
    AUTHM["core/auth.ts<br/>Entra JWT verify (no caller)"]
  end
  subgraph Az["Azure"]
    AOAI["Azure OpenAI gpt-4.1<br/>managed identity"]
    SQL[("Azure SQL<br/>dbo, Template, Encounter, Account, AI")]
    ENTRA["Entra JWKS"]
  end
  NET -.->|"no caller yet"| AGENT
  EVAL --> AGENT
  DEMO --> AGENT
  AGENT --> MW
  MW --> GRD
  MW --> SCH
  MW --> SRV
  MW --> AOAI
  SRV --> SQL
  HTTP --> SQL
  HTTP --> AOAI
  AUTHM -.-> ENTRA
```

## 2. One extraction request (invoke)

Guard, model call, evidence and outcome for a single run, including both exits.

```mermaid
sequenceDiagram
  participant C as Caller
  participant A as encounterAgent
  participant G as guardMiddleware
  participant T as templateService
  participant DB as Azure SQL
  participant M as modelCallMiddleware
  participant O as Azure OpenAI
  participant E as evidenceMiddleware
  participant U as outcomeMiddleware

  C->>A: invoke note and context
  A->>A: validate ExtractionContext (zod)
  A->>G: beforeAgent, state.noteText is the raw note
  G->>G: injectionScanner.scan raw note
  G->>G: payloadLimits.check raw note
  G->>G: phiMasker.mask (identity)
  G->>T: getAIConfig templetID
  T->>DB: EXEC usp_getTemplateMapping and SELECT template name
  DB-->>T: rows
  T-->>G: TemplateConfigResponseDto
  G->>G: responseSchemaBuilder.build
  G->>DB: EXEC dbo.usp_getPrompt userId accountId encounterId
  DB-->>G: prompt rows (exactly one required)
  G->>G: composePrompt and hash
  alt any guard step refuses
    G-->>U: jumpTo end with reasonCode
  else all steps pass
    G->>M: state with prompt, schema, config
    M->>O: system prompt, HumanMessage note, strict json_schema
    O-->>M: structured JSON or error
    alt call or parse failed
      M-->>U: Command with reasonCode and latency
    else reply parsed
      M->>E: Command with structuredResponse, model, tokens, latency
      E->>E: checkEvidence per slot
      E->>U: evidence and reviewSlots
    end
  end
  U->>U: tag outcome COMPLETED, BLOCKED or FAILED
  U-->>A: final state
  A-->>C: EncounterResult without underscore keys
```

## 3. Streaming (stream)

How per-field events are produced from the model's token stream.

```mermaid
sequenceDiagram
  participant C as Caller
  participant S as encounterAgent.stream
  participant GR as compiled graph and middleware
  participant FS as FieldScanner
  participant EV as checkEvidence

  C->>S: stream note and context
  S->>GR: graph.stream with modes updates, messages, values
  GR-->>S: updates chunk with guard state (templateConfig)
  S-->>C: event start with templateName and field count
  loop each model token chunk
    GR-->>S: messages chunk (AIMessageChunk)
    S->>FS: push text
    FS-->>S: completed top-level members, if any
    S->>EV: checkEvidence of that one slot against guard noteText
    S-->>C: event field with slotKey, section, field, answer, match, confidence
  end
  GR-->>S: final values chunk
  S->>S: publicState and find slots never streamed
  S-->>C: event field for each missed slot (backfill)
  S-->>C: event done with result, templateConfig, systemPrompt, firstFieldMs, backfilled
```

## 4. Failure modes and outcome tagging

Every reason code, which stage raises it, and how it becomes BLOCKED, FAILED or COMPLETED.

```mermaid
stateDiagram-v2
  [*] --> GuardSteps
  GuardSteps --> GuardBlocked : INJECTION_BLOCKED, PAYLOAD_TOO_LARGE
  GuardSteps --> GuardBlocked : TEMPLATE_UNAVAILABLE, PROMPT_NOT_FOUND, PROMPT_AMBIGUOUS
  GuardSteps --> GuardBlocked : PROMPT_PLACEHOLDER_UNFILLED, GUARD_STEP_FAILED
  GuardSteps --> ModelCall : all steps pass
  ModelCall --> GuardBlocked : PROMPT_NOT_COMPOSED
  ModelCall --> ModelCallFailed : MODEL_CONTENT_FILTERED
  ModelCall --> ModelCallFailed : PROMPT_CONTENT_FILTERED, PROMPT_JAILBREAK_FILTERED
  ModelCall --> ModelCallFailed : MODEL_CALL_FAILED
  ModelCall --> ExtractionFailed : OUTPUT_SCHEMA_VIOLATION, OUTPUT_TRUNCATED
  ModelCall --> EvidenceCheck : reply parsed
  EvidenceCheck --> Completed : no reasonCode and structuredResponse present
  EvidenceCheck --> ExtractionFailed : OUTPUT_MISSING, no reason and no parsed output
  GuardBlocked --> [*] : outcome BLOCKED, no failureMode
  ModelCallFailed --> [*] : outcome FAILED, no failureMode
  ExtractionFailed --> [*] : outcome FAILED, failureMode FORMAT
  Completed --> [*] : outcome COMPLETED
```

## 5. Evidence and confidence derivation

How the HIGH / MEDIUM / LOW band is computed in code, never from the model.

```mermaid
flowchart TB
  S["slot from structuredResponse"] --> NUL{"slot is an object?"}
  NUL -->|"no (null or other)"| LOWN["match NONE, confidence LOW<br/>never in reviewSlots"]
  NUL -->|yes| Q{"found_in non-empty<br/>after normalise?"}
  Q -->|no| MN["match NONE"]
  Q -->|yes| EX{"note.includes found_in<br/>(raw)?"}
  EX -->|yes| ME["match EXACT"]
  EX -->|no| NRM{"normalised note includes<br/>normalised quote?<br/>(NFKC, lower, one space)"}
  NRM -->|yes| MNORM["match NORMALIZED"]
  NRM -->|no| MNF["match NOT_FOUND"]
  ME --> LOC["located = true"]
  MNORM --> LOC
  MN --> NLOC["located = false"]
  MNF --> NLOC
  LOC --> ST{"status is FOUND?"}
  NLOC --> LOW["confidence LOW"]
  ST -->|no| LOW
  ST -->|yes| VU{"valueInQuote false<br/>or unitInQuote false?"}
  VU -->|yes| MED["confidence MEDIUM<br/>and slot goes to reviewSlots"]
  VU -->|no| HIGH["confidence HIGH"]
  MNF -.->|"FOUND but not located"| REV["reviewSlots (FOUND and not HIGH)"]
  MED --> REV
```

## 6. Managed-identity access (Azure OpenAI and SQL)

Deployed path versus local-development fallback for both resources.

```mermaid
flowchart LR
  ST["settings()<br/>AZURE_CLIENT_ID optional"] --> DAC["DefaultAzureCredential<br/>managedIdentityClientId if set"]
  ST --> KEY{"AZURE_OPENAI_API_KEY<br/>set?"}
  KEY -->|"no (deployed)"| BTP["getBearerTokenProvider<br/>scope cognitiveservices.azure.com/.default"]
  DAC --> BTP
  BTP --> LLM["AzureChatOpenAI<br/>azureADTokenProvider"]
  KEY -->|"yes (local only)"| LLMK["AzureChatOpenAI<br/>azureOpenAIApiKey"]
  LLM --> AOAI["Azure OpenAI deployment"]
  LLMK --> AOAI
  ST --> SQLU{"AZURE_SQL_USER<br/>set?"}
  SQLU -->|"no (deployed)"| AAD["tedious authentication<br/>azure-active-directory-default<br/>clientId if set"]
  SQLU -->|"yes (local only)"| LOGIN["tedious SQL login<br/>user and password"]
  AAD --> SQLDB[("Azure SQL, encrypt true")]
  LOGIN --> SQLDB
```

## 7. AI SQL schema (ER)

Tables, view and references in the AI schema, from the actual DDL in migrations/sql.

```mermaid
erDiagram
  AI_EncounterSummary {
    int summaryID PK
    int encounterID UK
    nvarchar summaryText
    int version UK
    int sourceTurns
    int lastTranscriptID
    bit isActive
    varchar modelName
    int inputTokens
    int outputTokens
    decimal inputCostUsd
    decimal outputCostUsd
    varchar traceId
    datetime2 createdDate
    datetime2 updatedDate
  }
  AI_PatientSummary {
    int summaryID PK
    int patientID UK
    nvarchar summaryText
    int version UK
    int sourceEncounters
    int lastEncounterID
    int sourceSummaryID FK
    bit isActive
    varchar modelName
    int inputTokens
    int outputTokens
    decimal inputCostUsd
    decimal outputCostUsd
    varchar traceId
    datetime2 createdDate
    datetime2 updatedDate
  }
  AI_ClinicianSummary {
    int summaryID PK
    int clinicianID UK
    nvarchar summaryText
    int version UK
    int sourceEncounters
    int lastEncounterID
    bit isActive
    varchar modelName
    int inputTokens
    int outputTokens
    decimal inputCostUsd
    decimal outputCostUsd
    varchar traceId
    datetime2 createdDate
    datetime2 updatedDate
  }
  AI_EncounterTranscript {
    int transcriptID PK
    int encounterID
    int templeteId
    nvarchar clinicianQuery
    nvarchar aiResponse
    varchar reasonCode
    int promptId
    varchar promptHash
    int patientSummaryID FK
    int clinicianSummaryID FK
    nvarchar historyEncounterIds
    nvarchar historySummaryIds
    varchar modelName
    int inputTokens
    int outputTokens
    decimal inputCostUsd
    decimal outputCostUsd
    int latencyMs
    varchar traceId
    int createdBy
    datetime2 createdDate
  }
  AI_EncounterFieldReview {
    int transcriptID PK
    int sectionID PK
    int fieldID PK
    nvarchar aiValue
    nvarchar aiUnit
    varchar aiConfidence
    nvarchar aiRemark
    nvarchar aiEvidence
    bit isEvidenceDeleted
    nvarchar finalValue
    nvarchar finalUnit
    varchar action
    bit isValueCorrect
    bit isUnitCorrect
    bit isDeleted
    int reviewedBy
    datetime2 createdDate
    datetime2 updatedDate
  }
  AI_prompt {
    int promptId
    nvarchar prompt
    bit isActive
    int accountId
    bit isUniversal
  }
  AI_EncounterUsage {
    int encounterID
    int turns
    int inputTokens
    int outputTokens
    decimal inputCostUsd
    decimal outputCostUsd
    datetime2 firstTurnDate
    datetime2 lastTurnDate
  }
  AI_EncounterSummary ||--o{ AI_PatientSummary : "sourceSummaryID"
  AI_PatientSummary ||--o{ AI_EncounterTranscript : "patientSummaryID"
  AI_ClinicianSummary ||--o{ AI_EncounterTranscript : "clinicianSummaryID"
  AI_EncounterTranscript ||--o{ AI_EncounterFieldReview : "transcriptID"
  AI_prompt ||..o{ AI_EncounterTranscript : "promptId, no FK"
  AI_EncounterTranscript }o--|| AI_EncounterUsage : "view groups by encounterID"
```

## 8. How it would be called (not built)

The implied call path from the SPA through the .NET API; dotted edges are unbuilt.

```mermaid
flowchart LR
  SPA["PacEHR SPA<br/>encounter form"] -->|"existing AES-encrypted JSON"| API["pacEHR_API<br/>new proxy endpoint (not built)"]
  API -->|"Entra app token, audience ENTRA_AUDIENCE"| EP["pacEHR_AI extract endpoint<br/>Epic 9 (not built)"]
  EP --> AUTH["auth.ts verify<br/>RS256, aud, iss, oid"]
  AUTH --> CTX["build ExtractionContext<br/>from API-supplied ids"]
  CTX --> AGT["encounterAgent.stream"]
  AGT -->|"field events"| EP
  EP -->|"SSE or chunked JSON"| API
  API --> SPA
  AGT -.->|"PEA-902 not built"| TR[("AI.EncounterTranscript")]
  SPA -.->|"review decisions, not built"| REV[("AI.EncounterFieldReview")]
  PM["patientManager, clinicianManager"] -.->|"wiring waits for fixtures"| AGT
```
