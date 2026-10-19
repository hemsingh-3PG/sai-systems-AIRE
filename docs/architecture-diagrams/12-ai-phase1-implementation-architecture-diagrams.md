# PacEHR — AI Phase 1 Implementation Architecture Diagrams

**Date**: 2026-09-09
**Source**: `docs/architecture/design/12-ai-phase1-implementation-architecture.md`
**Produced by**: ARCHITECT
**Module 12 (Phase 1)** — see also `12-ai-assistance-deep-dive-diagrams.md` (current state)

> Mermaid diagrams extracted verbatim from the Phase 1 design note.

---

## 1. End-to-end Phase 1 architecture

The Angular SPA is retained with four surgical changes (design note §2.7). The new `PacEHR.AI`
module sits behind an adapter that preserves the four existing route contracts, so a feature flag
can route traffic per tenant or template and both engines can run in shadow mode. No new external
integrations — patient data comes from existing internal APIs (M12).

Note the yellow node: **Dragon writes recognised text straight into the DOM, so the backend never
sees a transcript** — only the final field value. That constraint drives the input-modality
abstraction and the input-time provenance tagging.

```mermaid
flowchart TB
    subgraph FE["Angular 18 SPA — retained (4 surgical changes, §2.7)"]
        FORM["encounter form<br/>field order unchanged"]
        DRG["Nuance SpeechAnywhere<br/>→ Dragon Copilot SDK (Phase 1.5)"]
        AMB["ambient capture<br/>/speechToText"]
    end
    subgraph API["PacEHR.API — Azure App Service"]
        ADPT["legacy contract adapter<br/>4 existing routes, shapes preserved"]
        NEWEP["new: field/section regeneration<br/>+ completeness"]
        subgraph ENGINE["PacEHR.AI — new bounded module"]
            GATE["1 Entitlement + AuthZ"]
            CFG["2 Template Config Compiler"]
            RES["3 Instruction Resolver"]
            CTX["4 Context Assembly"]
            RULES["5 Deterministic Rules Engine"]
            ORCH["6 Generation Orchestrator"]
            VER["7 Verification + Provenance"]
            AUD["8 Audit + Telemetry"]
        end
    end
    subgraph DATA["Existing data — no new integrations (M12)"]
        SQL[("Azure SQL<br/>templates · prompts · normals<br/>validations · encounters")]
        INTAPI["existing internal APIs<br/>meds · vitals · demographics · problems"]
    end
    subgraph AI["Azure OpenAI — BAA + ZDR + Private Link"]
        MODEL["model deployment<br/>structured outputs, strict"]
    end
    FORM --> ADPT
    FORM --> NEWEP
    DRG -.->|"DOM text only — no transcript"| FORM
    AMB --> ADPT
    ADPT --> GATE
    NEWEP --> GATE
    GATE --> CFG --> RES --> CTX --> RULES --> ORCH
    ORCH -->|"Managed Identity"| MODEL
    MODEL --> VER --> AUD
    CFG --> SQL
    CTX --> INTAPI
    RULES --> SQL
    AUD --> SQL
    style ENGINE fill:#eef,stroke:#446
    style DRG fill:#ffe,stroke:#a80
```

---

## 2. Instruction Resolver — composition replacing selection

The fix for the conflict problem. Today `usp_getPrompt` is winner-takes-all with an early
`RETURN`, so a template-level prompt **replaces** the universal prompt and silently drops the
safety rules it contained — including "do not create a diagnosis the provider did not provide."

Here Layer 0 is immutable and cannot be overridden by any narrower layer, `prohibition` and
`required` directives merge by union, and contradictions are caught by a linter at publish time
rather than surfacing as inconsistent model behaviour in production. The resolved bundle is
content-hashed and the hash is logged with every completion, which is what makes generations
reproducible and A/B comparison meaningful.

```mermaid
flowchart TB
    L0["Layer 0 — SAFETY INVARIANTS (immutable)<br/>capture don't infer · no unstated diagnosis · output contract<br/>NOT OVERRIDABLE BY ANY LAYER"]
    L1["Layer 1 — specialty / care setting<br/>Behavioral Health · Primary Care"]
    L2["Layer 2 — account / organisation"]
    L3["Layer 3 — template"]
    L4["Layer 4 — section"]
    L5["Layer 5 — field"]
    L0 --> L1 --> L2 --> L3 --> L4 --> L5 --> MERGE
    MERGE["merge algebra by directive type"]
    MERGE --> LINT{"conflict linter<br/>compile time"}
    LINT -->|"contradiction found"| FAIL["publish REFUSED<br/>report to prompt author"]
    LINT -->|"clean"| HASH["resolved bundle<br/>+ content hash → logged with every completion"]
    style L0 fill:#dfd,stroke:#080,stroke-width:2px
    style FAIL fill:#fdd,stroke:#b00,stroke-width:2px
```

---

## Current state → Phase 1 mapping

| Current-state diagram | Phase 1 counterpart | What changes |
|---|---|---|
| `12-...-deep-dive-diagrams.md` #1 — streaming completion | #1 above | Engine interposed behind the same contract; Managed Identity replaces the API key |
| `12-...-deep-dive-diagrams.md` #2 — trust boundaries | #1 above | Guards move browser → host; entitlement enforced server-side |
| `12-...-deep-dive-diagrams.md` #3 — ambient dictation | #1 above (yellow node) | Two input modalities made explicit; Dragon's missing transcript named as a constraint |
| `12-...-deep-dive-diagrams.md` #4 — extraction auto-commit | #1 above | `timer(1000)` removed; schema-constrained decode makes invalid JSON unreachable |
| `12-...-deep-dive-diagrams.md` #5 — control layers | #2 above | Instruction composition replaces prompt selection |
