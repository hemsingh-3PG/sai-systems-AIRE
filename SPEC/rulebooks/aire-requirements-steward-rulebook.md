---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-05-15"
component: "3Pillar AIRE SDLC Agentic Framework"
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Requirements Steward Rulebook

## Purpose

Enforceable rules for the AIRE_REQUIREMENTS_STEWARD agent (R1–R17). This rulebook is THE source of truth for steward behavior; the agent definition and the merged drift workflow (`aire-drift`) reference rule IDs from this file.

---

## Core Philosophy

| Principle | Description |
|-----------|-------------|
| **Mirror, Not Lens** | The steward records facts and emits verifiable impact tags. It does not interpret, recommend, or classify. |
| **Human Authority** | Every CR, every foundation file mutation, every config change happens AFTER explicit operator approval (R1). |
| **Status-Conditional Immutability** | Foundation stories with status ∈ {`in-progress`, `done`, `blocked`} are frozen — changes happen via superseding CR-born stories (§5.4.1). Stories with status `planned` may be edited in place with an appended `## Change log` block, and new foundation stories may be created when no match exists. |
| **Single Producer** | Only Mode A produces CR-folder content. Non-canonical CRs are invisible to audits (R17). |
| **Single-Gate Apply** | Drafting, direct-edits, new-story creation, and foundation file writes happen in one invocation of `aire-drift` behind one preview-then-confirm gate (R16). |

---

## Section 1 — The 17 Rules (Absolute)

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | **R1** | **Draft, never auto-file.** Every CR and frontmatter change is a proposal. A human explicitly approves before anything is written to `docs/requirements.md`, story files, or external trackers. |
| 🔴 CRITICAL | **R2** | **Anchor-resolution diff.** Snapshot diffs match by anchor: (a) `req-id` blocks if present; (b) markdown H2 heading path otherwise. Never line-based, never semantic-similarity-only. |
| 🟡 REQUIRED | **R3** | **Body changes require version bumps (ID-anchored mode only).** When matched by `req-id`, a body change with no `version:` bump aborts the diff. Not applicable in heading-anchored mode — git records the change. |
| 🔴 CRITICAL | **R4** | **Schemas are load-bearing. Never improvise.** Frontmatter schemas in §4 are fixed. Do not add, rename, or infer fields. Missing required field → abort. |
| 🟡 REQUIRED | **R5** | **Trace by version, not by name.** Stories trace to `REQ-ID@vN`, never `REQ-ID` alone. A story whose trace omits a version is treated as stale. |
| 🟡 REQUIRED | **R6** | **Rationale per flagged item.** Every entry in an impact list ships with a one-sentence rationale citing the specific fragment affected. |
| 🟡 REQUIRED | **R7** | **Operate on the repo only.** No external API calls without config authorization. Keeps the agent portable, testable offline, safe to run on pre-production repos. |
| 🟡 REQUIRED | **R8** | **Impact-tag emission (no severity gate).** Emit `affects_stories`, `affects_requirements`, `modifies_doc_only`, `code_touched`, `affects_shipped` per delta. The agent does NOT classify the delta as CR vs ADR vs line-item vs log-only — humans use the impact tags to decide which artifact to file. |
| 🟡 REQUIRED | **R9** | **Scheduling is separate from severity.** Every CR carries `scheduled-cycle: <N>`. A CR whose work lands in a later cycle is still a CR; approval means "the commitment is real." |
| 🟡 REQUIRED | **R10** | **Epic grouping.** Every drafted CR carries `primary-epic: <Epic-N \| cross-cutting>`. Tie-break: epic with highest affected-story count; ties → epic of `introduced-by` requirement. CRs touching ≥3 epics or infrastructure surfaces are tagged `cross-cutting`. |
| 🟡 REQUIRED | **R11** | **CR collision: append, don't duplicate.** If an affected story is already linked to an open CR (status ∈ {proposed, approved, in-progress}), the steward APPENDS a row to that CR's "Affected stories" — it does NOT draft a parallel CR. |
| 🔴 CRITICAL | **R12** | **Abort on cycle-in-scope; warn on cycle-out-of-scope.** If a `depends-on` cycle's members intersect the CR's directly-affected set or transitive closure → ABORT. Cycles elsewhere in the graph → warn, continue. |
| 🔴 CRITICAL | **R13** | **Output-completeness gate.** Every Mode A and Mode B output ends with a self-verification block listing each mandated check and its computed result. Sections produced empty MUST appear with explicit `none` annotation. Silent omission is forbidden. |
| 🔴 CRITICAL | **R14** | **Status-conditional foundation-edit.** The agent MUST NOT edit a foundation story body when the story's pre-edit `status` ∈ {`in-progress`, `done`, `blocked`} — those changes go through a CR-born superseding story per §5.4.1. The agent MAY edit a foundation story body when pre-edit `status == planned` (no shipped or in-flight code), and MAY create new foundation story files when no matching story exists. Both lightweight paths MUST append a `## Change log` block to the story body recording the delta and pre-edit status. Foundation `docs/requirements.md` body edits remain workflow-owned and happen only via the merged `aire-drift` apply step, except when entry-mode is 2B (user already edited the PRD), in which case the workflow skips PRD writes entirely. |
| 🔴 CRITICAL | **R15** | **Fact-only output.** Output MUST contain only verifiable facts. Forbidden: (a) severity adjectives ("critical", "minor", "urgent", "high-risk", "risky"), (b) action recommendations ("rollback", "should be deferred", "consider", "recommend"), (c) Option A/B suggestions in Resolution, (d) comparators on derived metrics ("below threshold"), (e) scheduling advice in agent prose. Schema-defined values populated from human-set values are facts, not labels. |
| 🔴 CRITICAL | **R16** | **Single-gate preview-then-confirm.** Drafting and applying happen in one invocation of `aire-drift`. The agent stages all writes in memory (CR bundle + direct-edits + new stories + foundation deltas + dependency-graph update + status.md), presents a complete preview including the CR's `change-request.md` body inline, and HALTS for the user to read and type `yes`. NO file is written until the user types `yes`. On `yes`, all writes happen atomically-in-spirit: any sub-step failure → halt + git-rollback instructions, never partial-apply. On `cancel`, nothing is written. |
| 🔴 CRITICAL | **R17** | **Canonical CR producer lock.** Mode A is the ONLY sanctioned producer of content under `{cr-root}/CR-<n>/`. Non-steward agents asked to "create the CR" must redirect: `Invoke the requirements-steward agent in Mode A via aire-drift; non-Mode-A CR production is forbidden under R17.` Every CR's `change-request.md` carries `produced-by: requirements-steward@vN.N.N Mode A` to enable audit. |

---

## Section 2 — Predicates (Executable; §3.2 of source spec)

R13 requires every Mode A/B output to end with a self-verification block that prints **computed results**, never performative checkboxes. The agent runs each predicate against actual output and prints what the regex/glob/lookup returns. Any predicate marked `not-computed` counts as `fail`.

| Rule | Predicate (executable; agent must print actual result) |
|------|----------------------------------------------------|
| **R5** | For every story in `directly-affected ∪ new-trace-stories`: regex `/[A-Z][A-Z0-9-]*@v\d+/` on each `**Traces to**:` / `traces-to:` entry. Print `matched: N / unmatched: M`. Any unmatched → fail. |
| **R10** | For each drafted CR: assert `primary-epic` field present AND value matches `^(Epic-\d+\|cross-cutting)$`. Print the value. Missing → fail. |
| **R11** | For each story-id in the run's directly-affected set: glob `{cr-root}/CR-*/change-request.md`; grep for the story-id in `impacts-stories`. Print list of `(story-id, colliding-cr-id)` pairs or `none`. Collision found but no append patch → fail. |
| **R12** | Walk `depends-on` graph from each anchor; use Tarjan SCC. Print SCC list of size > 1 or `none`. Any SCC intersecting CR scope → abort run. |
| **R13** | Self-verification block printed at end of every Mode A/B output. Each predicate result printed inline. Missing block → fail. |
| **R14** | Three-pronged. (a) For each CR-path story: regex `/\b(edit\|update\|modify\|amend\|change\|patch)\b\s+\S+\s+(in\s+)?S-\d+\.\d+/i` on Resolution of each drafted CR's `change-request.md`. Print match count per CR. >0 → fail. (b) For each direct-edit-path story: read pre-edit `status` from git snapshot. Print `(story-id → pre-edit-status)`. Any non-`planned` → fail. (c) For each direct-edit and new-story file: assert presence of `## Change log` block containing today's date. Missing → fail. |
| **R15** | For each CR file body: regex for severity adjectives `/\b(critical\|minor\|urgent\|high-risk\|low-priority\|important\|risky\|concerning\|blocking)\b/i` outside schema-defined fields; for advisory verbs `/\b(should\|recommend\|consider\|propose to\|advise)\b/i` outside structural `## Proposed resolution` rows. Print counts per category. Any non-zero → fail. |
| **R16** | At end of run: enumerate every file written. Partition into allow-list buckets: (a) `{cr-root}/CR-<n>/*` (CR bundle), (b) `docs/plans/stories/*` where pre-edit status was `planned` OR file is new, (c) `docs/requirements.md` (only when entry-mode ≠ 2B), (d) `docs/architecture/design/*` (only when delta references architecture), (e) `docs/plans/builds/cycle-*/cycle-plan.md`, (f) `docs/plans/implementation-plan.md`, (g) `docs/plans/stories/<foundation>.md` `superseded-by:` audit-writes (R14 byte-identity check on body required), (h) `docs/status.md`, (i) `docs/.requirements-steward.config` (bootstrap only), (j) `docs/plans/dependency-graph.yml` (dependency-graph update when stories are created, superseded, or direct-edited). Assert every written file falls in exactly one allow-list bucket AND that the single-gate confirmation (`yes`) was recorded before any write. Any write outside allow-list OR before confirmation → fail. |
| **R17** | For each drafted CR's `change-request.md` frontmatter: read `produced-by:`. Assert matches regex `^requirements-steward@v\d+\.\d+\.\d+\s+Mode\s+A$`. Print value. Missing/non-canonical → fail. |
| **§5.4.1** | For each directly-affected foundation story-id `S-X.Y`: assert a CR-born story file exists at `{cr-root}/CR-<n>/Epic <K> (Change Request)/CR-<n>.<m>.md` whose frontmatter `supersedes:` contains `S-X.Y`. Print `(S-X.Y → CR-<n>.<m>)` mappings or `MISSING`. Any MISSING → fail. |
| **§5.4.2** | For each CR folder: list files; assert `change-request.md`, `plan-delta.md`, `requirements-delta.md`, `README.md` exist + `Epic <K> (Change Request)/` when stories exist. Print inventory. Any deviation → fail. |
| **§9.1** | For each `change-request.md`: assert headings `## Summary`, `## Impact analysis`, `## Dependency impact`, `## Resolution`, `## Approval` present. Print missing list. Any missing → fail. |

**Why predicates beat checkboxes.** A line like `- [x] R14 — pass` is performative. The agent (or operator) can write it without computing anything. A line like the following is verifiable:

```
- [x] R14 — foundation-edit refusal:
      regex /\b(edit|update|modify|amend)\b\s+\S+\s+(in\s+)?S-\d+\.\d+/ on Resolution:
        CR-1: 0 matches  ✓
        CR-2: 0 matches  ✓
```

If the regex returns matches, the predicate fails and the agent reports the offending lines instead of silently passing.

---

## Section 3 — Pre-Emission Validation (§5.4.4)

11 checks run as the **final step of Mode A drafting**, BEFORE presenting output to the user. Section 2 predicates run AFTER output is presented. §5.4.4 is the pre-emission gate that prevents malformed CRs from reaching the operator.

Run in order; first failure halts:

### (a) Foundation-immutability ↔ CR-born story coverage (§5.4.1 + §5.4.2 + R14)

For every story-id in (∪ over all drafted CRs of `impacts-stories`):

1. Resolve the file: `docs/plans/stories/<glob>` matching the story-id.
2. If the file is foundation (under `docs/plans/stories/`, format `epic-N-story-N.M-*.md` or `STRY-NNNN`):
   - Search planned output for a CR-born story file at `{cr-root}/CR-<n>/Epic <K> (Change Request)/CR-<n>.<m>.md` whose frontmatter `supersedes:` contains this story-id.
   - Found → ok.
   - Not found → R14 violation; abort emission.

### (b) Epic-folder existence + numbering (§5.4.2)

For every drafted CR:

- Compute `is-empty := (impacts-stories == [] AND introduces-stories == [])`
- If `is-empty`: assert NO `Epic <K>` folder in planned output. If found → abort.
- If not is-empty:
  - Assert `Epic <K> (Change Request)/` folder IS in planned output.
  - Compute `K_expected := max(existing-Epic-N across project) + 1`.
  - Assert `K == K_expected`. Mismatch → abort.
  - Assert CR's frontmatter `introduces-epic == Epic-<K>`.
  - Assert every CR-born story in the folder has `epic == Epic-<K>` AND `cr-id == CR-<n>`.

### (c) CR-born story frontmatter integrity (§5.4.2 + §5.2)

For every CR-born story file in planned output:

- `story-id` matches `CR-<n>.<m>` format
- `traces-to` is non-empty AND every entry uses `REQ-ID@vN` format (ID-anchored) OR `<file>::<heading>` format (heading-anchored)
- `supersedes` is either non-empty (replaces a foundation/earlier-CR-born story) OR empty AND the story is genuinely net-new (justified in change-request.md's "Stories introduced (net-new)" subsection)
- `depends-on` is present (may be `[]`). If `supersedes` is non-empty, `depends-on` MUST be a superset of the superseded story's `depends-on` (read from git snapshot), minus any story-ids also superseded in this CR (replaced by their CR-born equivalents). Print `(inherited: N, added: M, dropped-superseded: K)`. Any missing inheritance → fail.
- `cycle` field matches the `active-cycle` from `docs/.requirements-steward.config`
- `cr-id` matches the parent CR

### (d) Per-CR file inventory (§5.4.2)

For every drafted CR folder:

- Assert `change-request.md` exists
- Assert `plan-delta.md` exists
- Assert `requirements-delta.md` exists
- Assert `README.md` exists
- Any missing → abort

### (e) Section presence in `change-request.md` (§9.1)

Assert headings present:

- `## Summary`
- `## Impact analysis`
- `## Dependency impact`
- `## Resolution`
- `## Approval`

Any missing → abort with the list.

### (f) R14 textual scan (CR-path stories only)

For every drafted CR's `change-request.md`, in Resolution section:

- Regex: `/\b(edit\|update\|modify\|amend\|change\|patch)\s+\S+\s+(in\s+)?(foundation\s+)?S-\d+\.\d+/i`
- 0 matches required
- > 0 → abort with offending lines. Hint: "The matched verbs imply in-place edit of a frozen foundation story; convert to a CR-born superseding story per §5.4.1. Note: direct-edit-path stories (pre-edit status: planned) are NOT subject to this scan — they are tracked separately under R14 predicate (b)."

For each direct-edit-path story scheduled this run:

- Read pre-edit `status` from git snapshot (HEAD or `active-base`, whichever predates this run's staging)
- Assert `status == planned`. Any other value → abort with: "<story-id> has pre-edit status `<actual>`; R14 forbids direct edit. Convert to CR-supersede path."
- Assert the staged new body ends with a `## Change log` block whose first child heading matches `### <today YYYY-MM-DD>`. Missing → abort.

For each new-story file scheduled this run:

- Assert the staged body contains a `## Change log` block with a `### <today YYYY-MM-DD> — Created` entry. Missing → abort.

### (g) R15 textual scan

For every drafted CR file body:

- Regex for severity adjectives outside schema-defined values
- Regex for advisory verbs in agent prose
- Regex for Option A/B/C language
- 0 matches required
- > 0 → abort with offending lines + R15 quote.

### (h) CR-born story self-containment (§9.1.1)

For every CR-born story file under `{cr-root}/CR-<n>/Epic <K> (Change Request)/`:

**Six mandatory H2 headings** (unicode emoji optional in regex match):

- `## 📍 Impact within this CR` (or `## Impact within this CR`)
- `## 🔗 PRD source` (or `## PRD source`)
- `## ⏱️ Effort + scheduling` (or `## Effort + scheduling`)
- `## 📋 Plan slice impact` (or `## Plan slice impact`)
- `## 📜 Requirement context` (or `## Requirement context`)
- `## 🌊 Impacted stories — ripple beyond this CR` (or `## Impacted stories — ripple beyond this CR`)

**Bold-prefix metadata fields** (CR-born story body header):

- `**Impacts requirements**:` present, comma-separated `REQ-ID@vN` entries. Each entry must match `[A-Z][A-Z0-9-]*@v\d+`. Net-new reqs (no V1) MUST NOT appear here.
- `**Downstream stories**:` present, comma-separated story-ids OR literal `(none)`. Must contain every foundation story listed in this story's `## 🌊 Impacted stories` ripple table. Must NOT contain the value of `**Supersedes**:` (already named separately). Must NOT contain CR-internal sibling CR-born story-ids.
- `**Impacts epics**:` present, comma-separated epic-ids matching `(BC\d+-)?Epic-\d+`. Must equal `set(epic field of each story in the union of {**Supersedes**} ∪ {**Downstream stories**})`. Must NOT contain this CR-born story's own `Epic-<K>`.
- `**Requires**:` present, comma-separated story-ids OR `[]`. Inherited from the superseded foundation story's dependency-graph entry `requires` field (with superseded-in-this-CR story-ids replaced by their CR-born equivalents) plus any new dependencies introduced by the delta. Missing → fail.
- `**Enables**:` present, comma-separated story-ids OR `[]`. Inherited from the superseded foundation story's dependency-graph entry `enables` field (with the superseded story-id replaced by this CR-born story-id). Missing → fail.
- `**Files Touched**:` present, list of file paths. Union of the superseded story's `files_touched` from `dependency-graph.yml` plus any new files introduced by the CR delta. Missing → fail.

Any missing field, format mismatch, or set-mismatch with the ripple table → fail.

**Per-section content rules** (each section must satisfy its rule; empty/malformed content fails):

| Section | Content rule |
|---------|--------------|
| `## 📍 Impact within this CR` | Markdown table OR literal phrase `(none — this CR introduces only this story).` Empty heading → fail. |
| `## 🔗 PRD source` | At least one markdown link `[...](...)` per entry in the story's `**Traces to**:` line. Link count ≠ Traces-to count → fail. |
| `## ⏱️ Effort + scheduling` | Markdown table with rows for **Effort estimate**, **Type**, **Critical-path position**, **Parallelizable with**, **Scheduled cycle**. Any row missing → fail. |
| `## 📋 Plan slice impact` | Markdown table mapping affected Slice → status. Empty → fail. |
| `## 📜 Requirement context` | One ` ```yaml ` frontmatter block + one blockquote (PRD body verbatim) per entry in `**Traces to**:`. Mismatched count → fail. |
| `## 🌊 Impacted stories — ripple beyond this CR` | See ripple block below. |

**Ripple section content rule** (§9.1.1 v0.3.5):

- If the reverse-walk of `## Prerequisites` across foundation stories yields **≥1 story** citing the superseded story-id AND that story is NOT in this CR's `impacts-stories` set, the section MUST contain ALL FOUR of:
  - (i) a markdown table with columns `[Story | Prerequisite citation | QA impact | DEV impact]`, one row per ripple story
  - (ii) a fenced ` ```mermaid ` block with at least one `--"depended on by"-->` edge from the superseded story to a ripple story
  - (iii) two markdown checklists: **QA verification checklist** and **DEV verification checklist**
  - (iv) a blockquote starting with **Honesty note** containing R15-compliant text about derivation limits

- If reverse-walk yields **zero ripple stories**, the section MUST contain the literal phrase:
  `(none — no foundation stories outside CR-<n> cite <S-X.Y> in their ## Prerequisites)`

- Empty section, or missing any of (i)–(iv) when ripple > 0 → fail.

**Consolidated mermaid block** (folded into ripple section per v0.3.7):

- The fenced ` ```mermaid ` block inside `## 🌊 Impacted stories` must contain ≥1 `graph` or `flowchart` directive. Empty mermaid block → fail.
- Standalone `## 📊 Dependency chart` section was RETIRED in v0.3.7. Its visualization is consolidated inside the ripple section. If a CR-born story still emits a standalone `## 📊 Dependency chart` heading, it is tolerated but not required.

### (i) Single-CR-per-run invariant (§6 step 7 v0.3.3)

For every Mode A or `aire-drift` Phase 8 run:

- Count the CR folders the agent is about to emit under `{cr-root}/`
- If count > 1 AND the run is NOT a collision-driven append (R11) → abort with:

  ```
  v0.3.3 retired domain-clustering. One run = one CR. Move all
  directly-affected stories under a single CR-<n> folder with one
  Epic <K> (Change Request)/ subfolder.
  ```

- **Exception**: append patches per R11 (collision with existing open CR) legitimately produce zero new CR folders + edits to one existing CR. That path is allowed.

### (j) Metadata-only carve-out integrity (§5.4.1 v0.3.4)

For every requirement-id@vN in the run's modified set:

- Resolve every foundation story whose `**Traces to**:` line cites that req-id
- For each such story, the planned output must satisfy EXACTLY ONE of:
  - (i) a CR-born superseding story exists with `supersedes: [<that-story-id>]` AND `traces-to: [<req-id>@<new-version>]`, OR
  - (ii) the parent CR's `change-request.md` `## Impact analysis` contains a `### Metadata-only updates` subsection with a row listing: foundation story-id, req-id, V1→V2 transition, PDM rationale.

- **Both → fail** (over-counted; pick one path)
- **Neither → fail** (uncovered; pick one path)
- For path (ii): the rationale string must be non-empty AND must NOT contain severity/advisory tokens (per R15 regex). Empty or evaluative rationale → fail.

### (k) Dependency-propagation integrity 

For every CR-born story whose `supersedes` list is non-empty:

1. Load the superseded foundation story's `depends-on` from the git snapshot that predates this drift run's staging.
2. Load `docs/plans/dependency-graph.yml` entry for the superseded story-id: extract `requires`, `enables`, `files_touched`, `wave`.
3. Compute **expected `depends-on`** = superseded story's `depends-on`, minus any story-ids also superseded in this CR (replaced by their CR-born equivalents), plus any new dependencies detected via `files_touched` overlap analysis.
4. Assert the CR-born story's staged `depends-on` is a superset of the expected set. Print `(expected: [<list>], actual: [<list>], missing: [<diff>])`. Any missing → fail with:
   ```
   CR-born story <id> supersedes <foundation-id> but does not inherit its dependencies.
   Foundation depends-on: [<list>]. CR-born depends-on: [<list>]. Missing: [<diff>].
   ```
5. Assert the staged `docs/plans/dependency-graph.yml` update contains an entry for the CR-born story-id with `requires` ⊇ expected set. Missing entry → fail.
6. Assert the superseded story's entry is either removed or marked `superseded_by: <cr-born-id>` in the staged graph.

For every new-story file (no superseded foundation):

1. Assert the staged `docs/plans/dependency-graph.yml` update contains an entry for the new story-id.
2. Assert `requires` is populated (may be `[]` — but the entry must exist). Missing entry → fail.

For every direct-edited story:

1. If the delta changes the story's `## Implementation steps` or `**Files Touched**`, assert `docs/plans/dependency-graph.yml` is staged with an updated `files_touched` for this story-id. Unchanged implementation → graph update optional.

If `docs/plans/dependency-graph.yml` does not exist in the repo (project never ran the plan workflow), this check is SKIPPED with a warning:
```
⚠️ No dependency-graph.yml found — dependency propagation skipped.
   Run aire-greenfield-plan or aire-brownfield-plan to generate the graph.
```

### Halt-and-report contract

When pre-emission validation aborts, the operator receives a structured halt message naming the failed check, the offending file/section, the rule violated, and a suggested remediation. The agent does NOT proceed to present output (Phase 8.7 in `aire-drift.md`) until the operator addresses the failure.

---

## Section 4 — Frontmatter Schemas

These are the canonical schemas the steward owns. Producers MUST emit them; consumers MAY rely on them.

### §4.1 Requirement (used in ID-anchored mode; v1.1+)

```yaml
---
req-id: CORE-001         # required; stable identifier, domain-prefixed
version: 1               # required; integer ≥ 1
status: active           # required; active | superseded | retired
supersedes: null         # null if version == 1; otherwise "<req-id>@v<N-1>"
domain: core             # required; matches req-id prefix (lowercased)
introduced-in-cycle: 1   # required; integer
owner: product           # required; team or role owning the requirement
priority: med            # required; low | med | high — set by humans, never by the steward
---
```

The steward never assigns or mutates `priority`. It reads `priority` to sort CR drafts (high first) and annotate audit reports.

### §4.2 Story (extends AIRE story format with optional `traces-to`)

```yaml
---
story-id: epic-2-story-2.3        # foundation: epic-N-story-N.M; CR-born: CR-<n>.<m>
epic: Epic-2                       # global counter, never resets
traces-to:                         # optional; if present, used for precise reverse-walk
  - docs/requirements.md::§FR-13 Void Transfer
  - docs/requirements.md::§FR-14 Variance Handling
depends-on: []                     # REQUIRED for CR-born stories (inherited from superseded story); optional for foundation stories
cycle: 1                           # required
cr-id: null                        # ONLY set when story is CR-born
supersedes: []                     # set when story replaces another story
superseded-by: []                  # audit-computed; DO NOT set manually
status: in-progress                # planned | in-progress | done | blocked
---
```

**Audit-computed fields (allowed write on frozen foundation stories per §5.4.1):**

- `superseded-by: [...]` — reverse pointer; written by Mode C audit or `aire-drift` Phase 8.8h
- `last-audit: { date, result }` — written by Mode C every audit run
- `status-history: [...]` — append-only timeline

### §4.3 Change Request

```yaml
---
cr-id: CR-1                                 # per-cycle, not zero-padded
status: proposed                            # proposed | approved | in-progress | applied | closed | rejected | superseded
introduced-by: "docs/requirements.md::§FR-12 (heading-anchored)"   # OR REQ-ID@v2 (ID-anchored)
impacts-requirements: ["§FR-12 Variance Handling"]
impacts-stories: [epic-4-story-4.1-Variance-Handling]
impacts-epics: [Epic-4]
cycle-introduced: 1                          # cycle the CR was DRAFTED in (immutable)
scheduled-cycle: 1                           # cycle the work is PLANNED for (R9)
primary-epic: Epic-4                         # one of "Epic-N" or "cross-cutting"
introduces-epic: Epic-5                      # OMIT when CR has zero stories
approval-authority: pdm                      # pdm | tech-lead | engineering-principal | product-principal
rationale: |                                 # FACT-ONLY per R15
  §FR-12 Variance Handling body change introduces signature capture
  requirement; foundation story epic-4-story-4.1 currently implements
  role-only check; behavioral delta requires rework.
applies-against-shipped: false               # true when any impacts-stories has status: done
evidence-links: []                           # required when applies-against-shipped: true
produced-by: "requirements-steward@v1.0.0 Mode A"   # R17 — required
---
```

Fields NOT listed above are not recognized. Project-specific fields live BELOW the frontmatter block.

---

## Section 5 — Foundation Immutability (§5.4.1)

Foundation stories under `docs/plans/stories/` are **FROZEN** once a cycle has its first CR. They are never edited in place — no body amendments, no version bumps, no frontmatter mutation, except the steward's audit-computed writes:

| Field | Allowed Writer | When |
|-------|---------------|------|
| `superseded-by: [...]` | `aire-drift` Phase 8.8h, Mode C audit | Computed by walking inverse of CR-born `supersedes:` |
| `last-audit: { date, result }` | Mode C audit | Every audit run |
| `status-history: [...]` | Mode C audit (status reconciliation) | Append-only timeline |

All other fields require operator approval per R1. Any agent action that proposes to write a non-audit field on a foundation story → R14 abort.

**Change to foundation story scope, behavior, or dependencies** happens by drafting a CR whose new story carries `supersedes: [epic-N-story-N.M]` pointing at the foundation story being replaced.

### §5.4.1.1 — Exception for `status: planned` stories

A foundation story whose pre-edit status is `planned` has no shipped contract, no in-flight code, and no QA artifacts to preserve. Direct body edits are permitted via `aire-drift` (no CR ceremony required) as long as the edit appends a `## Change log` entry recording the delta, pre-edit status, and trigger.

The moment a story transitions out of `planned` (any other status — `in-progress`, `done`, `blocked`), it becomes frozen and the CR-supersede path becomes mandatory. The status check is performed against the git snapshot that predates this drift run's staging — operator-edited status fields in the working tree are NOT trusted for this gate.

### §5.4.1.2 — New foundation story creation

When a drift run identifies a requirement with no matching foundation story, the agent creates a new foundation story file under `docs/plans/stories/` using the foundation story template. The new story:

- Carries foundation frontmatter (`cr-id: null`, `supersedes: []`)
- Is assigned to an epic via the routing decision tree:
  - Requirement traces to an existing epic → story-id `epic-<N>-story-<N>.<M+1>` where M = max existing story number in that epic
  - No epic match → operator is prompted inline; on `yes`, next global epic number is allocated; on `assign-to-existing`, operator supplies the epic; on `skip`, the story is dropped
- Has a `## Change log` block seeded with a single `### <YYYY-MM-DD> — Created` entry naming the triggering requirement, epic assignment decision, and seeding PRD sections.

---

## Section 6 — Per-CR File Shape (§5.4.2)

**Universal contract.** This shape binds ANY agent or human operator who creates content under `{cr-root}/CR/`, not just the steward. CRs that do not conform are **invisible** to:

- Mode C audits (walk only `change-request.md` / `plan-delta.md` / `requirements-delta.md`)
- Mode E INDEX rollup (walks only `Epic <K> (Change Request)/*.md`)
- `aire-drift` R11 collision detection (greps the canonical filenames)

A non-conforming CR exists on disk but not in the steward's worldview, breaking the traceability chain.

```
{cr-root}/CR-<n>/
├── change-request.md            (always — CR body + 5 mandatory sections)
├── plan-delta.md                (always — scope delta vs cycle-plan)
├── requirements-delta.md        (always — new req frontmatter blocks; or header-note-only if CR only modifies existing reqs)
├── README.md                    (always — per-CR index + parallel-safety notes)
└── Epic <K> (Change Request)/   (ONLY when CR introduces stories)
    └── CR-<n>.<m>.md            (CR-born story files)
```

### Epic-numbering rule

Epic numbers are **global and sequential across the entire engagement**. They NEVER reset per cycle.

Algorithm:

1. Scan every story frontmatter across the entire project (`docs/plans/stories/**/*.md` + every `**/Epic */**/*.md`)
2. Take `max(N) + 1`
3. That's the new CR's Epic number
4. Create folder `Epic <new-N> (Change Request)/` (folder name uses spaces and parens for human readability)
5. Set `epic: Epic-<new-N>` and `introduces-epic: Epic-<new-N>` in every CR-born story AND in CR's `change-request.md` frontmatter

A CR with zero stories does NOT create the Epic folder and does NOT advance the global counter.

### Per-cycle CR id

Per-cycle, not zero-padded: `CR-1`, `CR-2`, `CR-3`. Cross-cycle references use `cycle-<N>.CR-<n>`. Next-available within a cycle: `max(existing CR-ids in cycle-N/CR/) + 1`, or `CR-1` if no prior CRs.

### Per-CR `README.md` template

```markdown
# CR-<n> (cycle-<N>) — <one-line summary>

**Status:** <see change-request.md frontmatter>
**Drafted:** YYYY-MM-DD by AIRE_REQUIREMENTS_STEWARD
**Introduces Epic:** Epic-<K> (or: "no new stories")

## Files in this CR

- [Change request body](./change-request.md)
- [Plan delta](./plan-delta.md)
- [Requirements delta](./requirements-delta.md)
- [Epic <K> (Change Request)/](./Epic-<K>) — <M> new stor(y|ies) (or: "no story folder")

## Parallel-safety notes

- **Safe alongside:** cycle-<N>.CR-<list> — <reason>
- **Conflicts with:** cycle-<N>.CR-<list> — <reason>
- **Pre-requisite open CRs:** cycle-<N>.CR-<list> — or "none"

## Stories that this CR's stories supersede

- `CR-<n>.<m>` supersedes `epic-N-story-N.M-<name>` — <one-line reason>
- (or "none — this CR introduces only new functionality")
```

---

## Section 7 — R8 §3.1 Pattern Table (Human Reference; NOT Enforced)

For every detected delta, the agent emits the impact-tag block defined in R8. The agent does NOT pick the artifact type. Humans read the tags and choose. Mapping below is for human reference only.

| Impact-tag pattern | Common human choice |
|---|---|
| `affects_stories > 0` AND `code_touched = true` AND `affects_shipped = false` | File a CR via `aire-drift` |
| `affects_stories > 0` AND `affects_shipped = true` | File a CR AND request `evidence-links` (PR/commit/deploy) — work has shipped |
| `affects_stories > 0` AND `modifies_doc_only = true` AND `code_touched = false` | Inline doc edit OR fold into nearest open CR as a line-item |
| `affects_stories = 0` AND `affects_requirements > 0` AND `code_touched = false` | ADR update if architecture-level commitment |
| Gated on open question (`OQ-*` ref, pending decision) | Log-only — list in `docs/status.md` Blockers section; revisit when blocker clears |

The agent emits the tags and stops. The human chooses the artifact. The agent's output never asserts which row applies (R15).

---

## Section 8 — Cycle-Awareness

### Cycle detection

The active cycle comes from `docs/status.md` Project Overview "Active Cycle" field. Fallback order:

1. `active-cycle` field in `docs/.requirements-steward.config`
2. `docs/status.md` Active Cycle field
3. Highest-numbered `docs/plans/builds/cycle-*/` folder
4. None (cycle-less project) → `cr-root = docs/plans/change-requests/`

### Cycle distribution reporting

When affected stories span multiple cycles, the steward reports FACTS only:

```
Cycle distribution:
  Affected stories scheduled in: CYCLE-3 (2: epic-7-story-7.2, epic-8-story-8.1)
  Current active cycle (from docs/status.md): CYCLE-1
  No CYCLE-1 stories affected.
```

NEVER recommend a cycle for scheduling in agent prose. The user reads §7's pattern table and chooses.

### Cycle-introduced vs scheduled-cycle (R9)

- `cycle-introduced` is IMMUTABLE — records when the delta was detected
- `scheduled-cycle` is set by the approver at review time; may be updated later (`scheduled-cycle: 0 → 1` as priorities shift)

The steward proposes `scheduled-cycle = cycle-introduced` as a default; the approver overrides when deferral is appropriate.

---

## Red Flags & Forbidden Actions

| Action | Rule |
|--------|------|
| Drafting a CR that edits a foundation story body via Resolution prose | R14(a) violation |
| Direct-editing a foundation story whose pre-edit `status != planned` | R14(b) violation |
| Direct-editing or creating a foundation story without appending `## Change log` block | R14(c) violation |
| Writing any file before the user types `yes` at the single-gate confirmation | R16 violation |
| Writing a file outside the R16 allow-list buckets | R16 violation |
| Writing `docs/requirements.md` in entry-mode 2B (user already edited it) | R16 violation |
| Hand-authoring CR files from any non-Mode-A path | R17 violation |
| Performative checkbox in R13 block (e.g., `- [x] R14 — pass`) without printing the actual predicate result | R13 violation |
| Severity adjective in agent prose ("critical", "minor", "urgent") | R15 violation |
| Action verb recommendation in agent prose ("you should", "consider", "recommend") | R15 violation |
| Silent override of declared config when drift is detected | R1 violation |
| Creating CR folders with arbitrary file names (not the §6 canonical 4) | §5.4.2 violation |