---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-06-14"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Sync Helix platform artifacts (solution documents, session context, graph query outputs) down into the local docs/helix/ tree over the Helix MCP server.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---


# Helix - Artifact Sync

## Agent

**ARCHITECT**

## Before Starting

1. Read `SPEC/agents/AIRE_ARCHITECT.md`
2. Read `SPEC/rulebooks/aire-helix-rulebook.md` — **mandatory**; it defines the `docs/helix/` layout, frontmatter, manifest, and the destructive-write rules.
3. Confirm the `helix` MCP server is connected (you have `mcp__helix__*` tools). If not, STOP and tell the user to run `aire helix connect --solution-id <id> --ide <name>` and reload the IDE (see `Helix-MCP-Connect.md`).

> **Direction:** this workflow syncs **Helix → local** (`docs/helix/`). It is **non-destructive to Helix** — it only reads from Helix. Writing local artifacts back *up* into Helix is a separate, explicit action (see the rulebook).

> ⚠️ **Work in progress:** the Helix endpoint may not be published yet. If the first tool call fails with a connection/auth error, STOP and report it — do not retry blindly.

---

## Execution Steps

### Phase 0: Preconditions (MANDATORY FIRST)
- [ ] Call `mcp__helix__get_session_context_tool`.
- [ ] If it errors → STOP, report the exact error (likely endpoint-WIP or OAuth-not-completed).
- [ ] Confirm the bound **solution id** with the user before reading anything. Do not assume.
- [ ] Ask the user for the **current date/time** (for `synced_at`), or use an environment-provided value. Never invent timestamps.

### Phase 1: Scope
- [ ] Ask the user what to sync (default: **everything**):
  - **Documents** — all solution documents
  - **Context** — the session context
  - **Graph** — only specific saved queries the user names (graph sync is on-demand, not bulk)
- [ ] If `docs/helix/INDEX.md` already exists, read it first — it is the prior manifest used for conflict detection.

### Phase 2: Sync solution documents (if selected)
- [ ] `mcp__helix__list_solution_documents_tool` → enumerate documents.
- [ ] For each document:
  - [ ] `mcp__helix__get_solution_document_tool` → fetch body.
  - [ ] Derive a deterministic kebab-case slug (id is source of truth).
  - [ ] Before overwriting an existing `docs/helix/documents/<slug>.md`, check it against the prior manifest. If it has local edits not in the manifest, **surface the conflict** and ask the user before overwriting.
  - [ ] Write `docs/helix/documents/<slug>.md` with the required frontmatter (`helix_id`, `title`, `solution_id`, `synced_at`, `helix_metadata`) + body.

### Phase 3: Sync session context (if selected)
- [ ] Write `docs/helix/context/session-context.md` from `get_session_context_tool` output.
- [ ] **Strip any secrets** — record the `x-solution-id` and non-sensitive context only; never tokens/credentials.

### Phase 4: Sync graph outputs (on demand only)
- [ ] For each query the user named, run the appropriate tool:
  - `mcp__helix__codebase_agent_query` (natural language), or
  - `mcp__helix__codebase_cypher_query` (Cypher), or
  - `mcp__helix__graph_change_impact` (change scoping).
- [ ] Write `docs/helix/graph/<query-slug>.md` recording **both** the query and its result (frontmatter `kind`, `query`, `solution_id`, `synced_at`).

### Phase 5: Update the manifest
- [ ] Write/refresh `docs/helix/INDEX.md`:
  - Header: solution id + latest `synced_at`.
  - Table: `helix_id | title | local path | synced_at` for every synced artifact.
- [ ] Ensure `INDEX.md` matches exactly what is on disk (MANIFEST IS AUTHORITATIVE).

### Phase 6: Report
- [ ] Summarize to the user: counts synced (documents / context / graph), any conflicts surfaced, any tool errors.

Report to user:
```
✅ Helix sync complete
   Solution: <x-solution-id>
   Documents: <n> synced → docs/helix/documents/
   Context:   docs/helix/context/session-context.md
   Graph:     <n> queries → docs/helix/graph/
   Manifest:  docs/helix/INDEX.md
   Conflicts: <none | listed above>
```

---

## Output

```
docs/helix/
  INDEX.md
  context/session-context.md
  documents/<slug>.md      (one per solution document)
  graph/<slug>.md          (on-demand query outputs)
```

Each file carries the frontmatter defined in `aire-helix-rulebook.md`.

> **Who consumes this tree:** downstream AIRE workflows (`aire-project-kickoff`, `aire-brownfield-inspect`, `aire-brownfield-deep-dive`, `aire-brownfield-requirements`, `aire-brownfield-architecture`, `aire-greenfield-requirements`, `aire-greenfield-architecture`) read `docs/helix/` as read-only reference context during their Reference Check / Before Starting steps — always entering via `INDEX.md`. See "Downstream consumption" in `aire-helix-rulebook.md`.

---

## Rules

- 🔴 Confirm the bound solution before any read (`get_session_context_tool`).
- 🔴 Graph is read-only; never mutate it.
- 🔴 Never write secrets/tokens into `docs/helix/`.
- 🔴 Don't clobber local edits — detect via the prior `INDEX.md` manifest and ask before overwriting.
- 🔴 Report tool errors verbatim; never fabricate document or graph content.
- 🟡 Prefer non-destructive operations; this workflow only reads from Helix.

---

## Mandatory Next Steps in AIRE Workflow

**You are here → `aire-helix-sync`**

| # | Next Command | Purpose |
|---|-------------|---------|
| ▶️ | `aire-brownfield-inspect` | Use the synced Helix context + graph to produce a system overview |
| ▶️ | `aire-brownfield-deep-dive` | Module-level structural analysis using the graph |
