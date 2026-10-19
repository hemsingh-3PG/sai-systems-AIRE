# PacEHR Encounter Agent — Backlog

**75 stories · 12 epics · Python · LangChain `create_agent` · Azure OpenAI · Azure SQL**

Built from [`pacEHR-AI-Approach-2-Proposed.md`](../pacEHR-AI-Approach-2-Proposed.md) and
[`pacEHR-Encounter-Agent-4Pager.md`](../pacEHR-Encounter-Agent-4Pager.md).

---

## What is in this folder

| File | What it is |
|---|---|
| `CLAUDE.md` | The engineering standard. Tickets cite it; they never restate it. Destined for the Python repo root. |
| `00-source-index.md` | 128 requirements extracted from the two source documents, each with a `REQ-*` id and a line citation. |
| `00-langchain-api-truth.md` | Every LangChain, Pydantic and Azure symbol the tickets name, verified by tool call against the LangChain doc servers and Microsoft Learn. No ticket names a symbol absent from here. |
| `epic-01` … `epic-12` | The 75 stories. |

Every story has the same five sections: User Story · Business Context & Problem
Statement · Acceptance Criteria (Gherkin) · Technical Considerations & Constraints ·
Definition of Done. Every story's `Satisfies:` line points into `00-source-index.md`.

---

## The epics

| Epic | File | Stories | Phase |
|---|---|---|---|
| 1 Repository foundation & core singletons | `epic-01-foundation.md` | PEA-101–106 | 1 |
| 2 Data layer — AI schema | `epic-02-data-layer.md` | PEA-201–207 | 1 |
| 3 Template config → dynamic schema | `epic-03-template-schema.md` | PEA-301–307 | 1 |
| 4 Agent core — `create_agent` + middleware | `epic-04-agent-core.md` | PEA-401–407 | 1 |
| 5 Guardrails — injection + PHI | `epic-05-guardrails.md` | PEA-501–504 | 1 |
| 6 Deterministic validation engine | `epic-06-validation.md` | PEA-601–608 | 1 |
| 7 Agent tools | `epic-07-tools.md` | PEA-701–705 | 1 |
| 8 Prompt ownership | `epic-08-prompt-ownership.md` | PEA-801–807 | 1 |
| 9 Human review + API surface | `epic-09-review-api.md` | PEA-901–904 | 1 |
| 10 Observability & evaluation | `epic-10-observability.md` | PEA-1001–1009 | 1 (1006 is 2) |
| 11 Azure deployment & operations | `epic-11-azure-deployment.md` | PEA-1101–1106 | 1 |
| 12 Memory layer | `epic-12-memory.md` | PEA-1201–1205 | **2** |

**Phase 1** is Epics 1–11. **Phase 2** is Epic 12 plus PEA-1006. Phase 1 ships and the
system is complete without Phase 2.

---

## Build order

1. **Epic 1** — nothing else compiles without it.
2. **Epic 2** and **Epic 3** — tables and the template→schema path. Epic 3 carries
   **PEA-301**, the highest-value ticket in the backlog.
3. **Epic 4** — the agent and its middleware spine. Start with PEA-401's spike.
4. **Epics 5, 6, 7** — guards, validation, tools. Parallelisable once Epic 4 lands.
5. **Epic 9** — the endpoints. **Epic 8** — prompt ownership. **Epic 10** — observability.
6. **Epic 11** — deploy, shadow mode first.
7. **Epic 12** — only after Phase 1 is measured.

---

## Read before you start

Four things are deliberately unsettled. Each has a cheap empirical check written into
its ticket. Do them before building on them.

1. **Provider-side schema enforcement (PEA-401).** Nobody could confirm from
   documentation that this Azure OpenAI deployment and API version actually enforce the
   response schema. Prove a malformed response is rejected **by the provider**, not by a
   client-side parse. If it is not enforced, Epic 4's central claim fails — find out in
   week one, not at integration.
2. **`@tool` on `@staticmethod` decorator ordering (PEA-701).** Undocumented upstream.
   Build it both ways, print `tool.args_schema.model_json_schema()`, confirm parameters
   appear and `self` does not. Five minutes.
3. **Per-request response-schema override (PEA-406).** If overriding `response_format`
   per request does not change the parsed output, every run extracts into the
   compile-time baseline shape. Fallback is one compiled agent cached per `templetID`.
4. **Container cold start on Premium (PEA-1101).** Microsoft publishes no number.
   Measure before setting `minimumElasticInstanceCount` above 1.

---

## What this backlog does not build

- Ambient speech, telephony, patient roster, developer tooling — out of scope.
- ICD/CPT coding beyond format checking. Without a licensed code set, `lookup_icd_cpt`
  degrades to format validation plus human sign-off.
- Anything in `chat/` or `conversations/`. Those packages belong to the other product on
  this repository; they are scaffolded and left empty.
- Redis prompt caching — Phase 2.

---

## Known gaps in this document

- **The traceability matrix is not built.** Nothing has yet proved mechanically that all
  128 requirements are covered exactly once. Several authors left requirements uncovered
  with stated reasons — architecture-level requirements that are not units of work, and
  Phase 2 items named in Scope-Out sections — but that list has not been reconciled.
- **One correction is outstanding outside this folder.**
  [`pacEHR-Azure-Deployment-Architecture.md:66`](../pacEHR-Azure-Deployment-Architecture.md)
  states that a custom container can run on a Flex Consumption plan. It cannot —
  Microsoft documents Flex Consumption as code-only. Containers are Premium (Elastic
  Premium) or Dedicated only. The tickets are correct; that document is not.
