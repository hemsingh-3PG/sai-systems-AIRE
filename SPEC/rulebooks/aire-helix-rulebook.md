---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-06-14"
component: "3Pillar AIRE SDLC Agentic Framework"
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---


# Helix Rulebook

## Purpose

Strict rules for working with the **Helix platform over MCP** — querying the code knowledge graph, reading/writing Helix solution documents, and **syncing Helix artifacts down into the local `docs/helix/` tree** so they are versioned alongside the project.

These rules govern the `aire-helix-sync` workflow and any agent action that calls a `mcp__helix__*` tool.

---

## Preconditions (verify before any Helix action)

| Check | How | If it fails |
|-------|-----|-------------|
| `helix` MCP server is connected | The agent has `mcp__helix__*` tools available | STOP. Tell the user to run `aire helix connect --solution-id <id> --ide <name>` and reload the IDE. See `Helix-MCP-Connect.md`. |
| Session is authenticated & live | `mcp__helix__get_session_context_tool` returns context without error | STOP. The endpoint is WIP / may be unpublished, or OAuth not completed. Report the exact error to the user; do not retry blindly. |
| Bound to the intended solution | The `x-solution-id` in context matches what the user expects | STOP and confirm with the user before reading/writing anything. |

---

## Absolute Rules & Constraints

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | CONFIRM SOLUTION FIRST | ALWAYS call `get_session_context_tool` and confirm the bound solution before any read or write. |
| 🔴 CRITICAL | GRAPH IS READ-ONLY | NEVER attempt to mutate the code graph. Only `codebase_agent_query`, `codebase_cypher_query`, `graph_change_impact` are permitted against the graph. |
| 🔴 CRITICAL | CONFIRM BEFORE DESTRUCTIVE WRITES | NEVER call `delete_solution_document_tool` or `rewrite_solution_document_tool` without explicit user confirmation naming the document. |
| 🔴 CRITICAL | CONFIRM LIFECYCLE TRANSITIONS | NEVER call `change_document_lifecycle_tool` without explicit user confirmation naming the document AND the target state (e.g. `CURRENT` → `DEPRECATED`). It is a governed, state-changing write (audit trail + search-index sync), not a metadata edit. Supply the `rationale` the transition requires (min 10 chars) and pass `expected_version` from your most recent read for optimistic locking; on a `version_conflict`, re-read the document and retry — never force. Official/published documents are **UI-only** (the tool returns `official_document_ui_only`); do not attempt to transition them via MCP — tell the user to use Helix Studio's Publish/Unpublish controls. |
| 🔴 CRITICAL | PREFER APPEND OVER REWRITE | When adding to an existing Helix document, use `append_to_solution_document_tool`; reserve `rewrite_solution_document_tool` for a user-approved full replacement. |
| 🔴 CRITICAL | NO SECRETS IN ARTIFACTS | NEVER write tokens, OAuth bearer values, or credentials into `docs/helix/`. The `x-solution-id` is an identifier and may be recorded; secrets must not. |
| 🟡 REQUIRED | DON'T CLOBBER LOCAL EDITS | Before overwriting a file under `docs/helix/`, if it has local modifications not present in the last sync manifest, surface the conflict to the user instead of silently overwriting. |
| 🟡 REQUIRED | DETERMINISTIC SLUGS | File names derive from a stable slug of the document id/title (lowercase, kebab-case, ASCII). The Helix document **id** is the source of truth, recorded in frontmatter. |
| 🟡 REQUIRED | FRONTMATTER ON EVERY SYNCED DOC | Every synced document file carries frontmatter: `helix_id`, `title`, `solution_id`, `synced_at`, and any Helix metadata. |
| 🟡 REQUIRED | MANIFEST IS AUTHORITATIVE | `docs/helix/INDEX.md` records what was pulled, when, and from which solution. Update it on every sync. |
| 🟡 REQUIRED | REPORT, DON'T GUESS | If a tool returns an error or empty result, report it verbatim to the user; never fabricate document content or graph results. |

---

## Target layout — `docs/helix/`

```
docs/helix/
  INDEX.md                       # manifest: solution id, last sync timestamp, table of synced artifacts
  context/
    session-context.md           # from get_session_context_tool (no secrets)
  documents/
    <doc-slug>.md                # one file per solution document (frontmatter + body)
  graph/
    <query-slug>.md              # saved graph outputs (the query + its result), on demand
```

### File conventions

- **Document files** (`documents/<slug>.md`) — frontmatter then body:
  ```markdown
  ---
  helix_id: "<helix document id>"
  title: "<document title>"
  solution_id: "<x-solution-id>"
  synced_at: "<ISO 8601 timestamp, supplied by the user or environment>"
  helix_metadata: { ... }        # whatever update_document_metadata_tool exposes
  ---

  <document body as returned by get_solution_document_tool>
  ```
- **Graph files** (`graph/<slug>.md`) — record the question/query AND the result, so the artifact is self-describing:
  ```markdown
  ---
  kind: "agent-query | cypher-query | change-impact"
  query: "<the natural-language question or Cypher>"
  solution_id: "<x-solution-id>"
  synced_at: "<ISO 8601 timestamp>"
  ---

  <result>
  ```
- **`INDEX.md`** — a manifest table: `helix_id | title | local path | synced_at`, plus a header with the solution id and the latest sync time. This is what "DON'T CLOBBER" and "MANIFEST IS AUTHORITATIVE" check against.

> **Timestamps:** the agent does not invent timestamps. Ask the user for the current date/time, or use a value provided by the environment, and record it in `synced_at`. When `helix` is connected, `get_current_date_tool` returns today's UTC date and is an acceptable source. (Note: to embed a date *inside* a Helix document you save, write the literal `{{date}}` token — Helix fills it in at save time.)

---

## Direction of sync

- **Down (Helix → local):** the default for `aire-helix-sync` — read Helix artifacts and write them under `docs/helix/`. Non-destructive to Helix.
- **Up (local → Helix):** only on explicit user request — e.g. persisting a generated `docs/architecture/...` overview into Helix via `save_solution_document_tool` / `append_to_solution_document_tool`. Governed by the CONFIRM-BEFORE-DESTRUCTIVE-WRITES and PREFER-APPEND rules above.

---

## Downstream consumption — `docs/helix/` as reference context

The synced tree is not just an archive: AIRE workflows consume it as **read-only reference context** during their Reference Check / Before Starting steps (`aire-project-kickoff`, `aire-brownfield-inspect`, `aire-brownfield-deep-dive`, `aire-brownfield-requirements`, `aire-brownfield-architecture`, `aire-greenfield-requirements`, `aire-greenfield-architecture`).

| Priority | Rule | Description |
|----------|------|-------------|
| 🟡 REQUIRED | ENTER VIA THE MANIFEST | Always read `docs/helix/INDEX.md` first and pick relevant artifacts from it; never scan the tree blindly. If `INDEX.md` is missing, treat the tree as absent. |
| 🟡 REQUIRED | CONSUMERS NEVER EDIT | Downstream workflows never modify files under `docs/helix/` — local edits become conflicts at the next sync (see DON'T CLOBBER). New content belongs under `docs/` proper (e.g. `docs/architecture/`), optionally persisted up to Helix per "Direction of sync". |
| 🟡 REQUIRED | CHECK FRESHNESS | The tree is a snapshot, not live Helix state. Check `synced_at` in the manifest header; if it predates significant changes, suggest re-running `aire-helix-sync` before relying on it. |

---

## Quality Gates

| Gate | Target | Description |
|------|--------|-------------|
| Solution confirmed | 100% | Every run confirms the bound solution before acting. |
| Frontmatter present | 100% | Every synced file has the required frontmatter keys. |
| Manifest current | 100% | `INDEX.md` reflects exactly what is on disk after the run. |
| No secrets | 100% | No tokens/credentials anywhere under `docs/helix/`. |
| Errors surfaced | 100% | Any tool error is reported to the user, not swallowed or faked. |
