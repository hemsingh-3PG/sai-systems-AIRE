# PacEHR — AI Assistance & Dictation: Target Architecture Diagrams

**Date**: 2026-09-08
**Source**: `docs/architecture/design/12-ai-assistance-target-architecture.md`
**Produced by**: ARCHITECT
**Module 12 (target state)** — counterpart to `12-ai-assistance-deep-dive-diagrams.md`

> Mermaid diagrams extracted verbatim from the target-architecture design note.
> Each is paired with the current-state diagram it replaces.

---

## 1. Target trust boundaries — the guards move server-side

Replaces current-state diagram 2. Today `maskPHI`, `detectInjection` and body encryption all sit in the browser, so anything that can reach the host bypasses them, and the credential is resolved from SQL app settings. Here every guard is enforced inside the host, authorisation runs before anything else, and Managed Identity removes the credential entirely.

```mermaid
flowchart LR
    subgraph BROWSER["Browser — no security role"]
        CMP["Angular component"]
        CMP --> CALL["AI client<br/>transport only"]
    end
    subgraph HOST["pacEHR_API — Azure"]
        direction TB
        AUTH["AuthN / AuthZ<br/>tenant + role + patient scope"]
        GW["PacEHR.AI.Gateway"]
        POL["PHI policy<br/>minimum-necessary selection"]
        INJ["injection screen<br/>untrusted spans"]
        REG["prompt registry<br/>version-pinned"]
        VAL["output schema validation<br/>+ field whitelist"]
        AUD[("audit log — unmasked<br/>restricted store<br/>promptVer, modelId, spans")]
        AUTH --> GW --> POL --> INJ --> REG
        REG --> VAL --> AUD
    end
    subgraph EXT["Azure AI Foundry — inside BAA + Private Link"]
        MODEL["model endpoint<br/>per-task config"]
    end
    CALL -->|"TLS + Entra token"| AUTH
    REG -->|"Managed Identity — no API key"| MODEL
    MODEL --> VAL
    DIRECT["Any client reaching the host"] -->|"hits AuthN first"| AUTH
    style GW fill:#dfd,stroke:#080,stroke-width:2px
    style DIRECT fill:#dfd,stroke:#080
```

---

## 2. Provider abstraction and per-task routing

Model (`gpt-4o`) and `temperature = 0` are currently hardcoded in four `AIPromptServices` methods. Lifting them to per-task configuration behind one `IModelProvider` is what turns a model change into a config change — and what makes an A/B against the eval set possible without a deploy.

```mermaid
flowchart LR
    subgraph TASKS["Per-task configuration — not per-method constants"]
        EX["extraction<br/>temp 0 + schema"]
        NOTE["note synthesis<br/>reasoning model"]
        JUDGE["grounding judge<br/>cheap model"]
    end
    IFACE["IModelProvider"]
    EX --> IFACE
    NOTE --> IFACE
    JUDGE --> IFACE
    IFACE --> A["Azure OpenAI adapter"]
    IFACE --> B["Anthropic adapter"]
    IFACE --> C["Bedrock adapter"]
    A --> EVALSET[("versioned eval set<br/>gates the deploy")]
    B --> EVALSET
    C --> EVALSET
```

---

## 3. Two-pass generation, verification, and the attestation gate

Replaces current-state diagram 4 — the one where model output reaches a saved encounter unvalidated. `timer(1000)` is gone. Extraction is schema-constrained with ID enums, every field carries the transcript span it came from, three independent checks run against it, unverifiable fields are dropped rather than guessed, and a clinician acts before anything is written.

```mermaid
flowchart TB
    subgraph ASSEMBLE["C. Context assembly — cacheable prefix"]
        FHIR[("FHIR R4 + SQL")] --> ART["structured patient artifact<br/>problems · meds · allergies · vitals<br/>template fields + valid ID enums"]
    end
    T["dictated transcript<br/>UNTRUSTED — delimited data block"]
    ART --> P1
    T --> P1["Pass 1 — constrained extraction<br/>schema-enforced, IDs enum-bound<br/>each field + verbatim evidence span"]
    P1 --> V1["deterministic span check<br/>does the span exist in the transcript?"]
    P1 --> V2["Text Analytics for Health<br/>independent clinical NER cross-check"]
    P1 --> V3["cheap LLM judge<br/>unsupported-claim scan"]
    V1 --> STAGE
    V2 --> STAGE
    V3 --> STAGE
    STAGE["staging structure<br/>per-field confidence + provenance<br/>unverifiable fields DROPPED"]
    STAGE --> UI["E. Attestation gate<br/>AI fields highlighted, span on hover<br/>accept / edit / reject per field"]
    UI -->|"human action only"| SAVE["onSubmit() — encounter saved"]
    UI -.->|"accept / edit / reject events"| EVAL[("eval corpus<br/>+ medico-legal record")]
    style STAGE fill:#dfd,stroke:#080,stroke-width:2px
    style SAVE fill:#dfd,stroke:#080,stroke-width:2px
```

---

## 4. Where each control layer sits in the target state

Replaces current-state diagram 5. In the current state the "Neither" box holds prompt validation and model output schema validation. Here it is empty: nothing that matters is left to the browser, and the one control that belongs with a person is explicitly assigned to one.

```mermaid
flowchart TB
    subgraph ENFORCED["Enforced server-side — target state"]
        AUTHZ["authN / authZ incl. /speechToText"]
        PHI["PHI policy — minimum necessary"]
        INJ["injection screening"]
        SCHEMA["model output schema validation"]
        WL["field whitelist + ID enums"]
        TOK["token accounting (finally block)"]
        KEY["credential — Managed Identity"]
        AUDIT["unmasked audit log"]
    end
    subgraph HUMAN["Enforced by a person"]
        ATT["clinician attestation before save"]
    end
    subgraph CLIENTONLY["Client-side — convenience only, no security role"]
        UX["inline validation, optimistic UI"]
    end
    style ENFORCED fill:#dfd,stroke:#080,stroke-width:2px
    style HUMAN fill:#dfd,stroke:#080,stroke-width:2px
```

---

## Reading order

| Current state | Target state | What changes |
|---|---|---|
| `12-...-deep-dive-diagrams.md` #2 — trust boundaries | #1 above | Guards move browser → host; credential removed |
| `12-...-deep-dive-diagrams.md` #1 — streaming completion | #1 and #2 above | Gateway interposed; provider becomes swappable |
| `12-...-deep-dive-diagrams.md` #4 — extraction auto-commit | #3 above | Validation, evidence spans and human attestation added |
| `12-...-deep-dive-diagrams.md` #5 — control layers | #4 above | "Neither" box emptied |
| `12-...-deep-dive-diagrams.md` #3 — ambient dictation | *(no diagram — see design note §G)* | Speech consolidated into one BAA boundary; socket authenticated; audio-retention posture decided |
