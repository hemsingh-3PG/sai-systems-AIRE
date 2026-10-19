---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Brownfield Phase 2.2 - Patterns & Standards. Compare existing codebase patterns against rulebook recommendations and generate a patterns document based on user choice.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Brownfield - Patterns & Standards

## Agent

**ARCHITECT**

## Before Starting

1. Read `SPEC/agents/AIRE_ARCHITECT.md`
2. Read `SPEC/rulebooks/aire-brownfield-rulebook.md`
3. **Read**: `docs/requirements.md` — if missing, **STOP**: Tell user to "Run `aire-brownfield-requirements` first."
4. **Read**: `docs/architecture/current/00-system-overview.md` — if missing, **STOP**: Tell user to "Run `aire-brownfield-inspect` first."
5. **Read**: All `docs/architecture/current/01-*-deep-dive.md` — if missing, **STOP**: Tell user to "Run `aire-brownfield-deep-dive` first."
6. **Read**: `docs/architecture/design/02-target-architecture-brownfield.md` — if missing, **STOP**: Tell user to "Run `aire-brownfield-architecture` first." Use it to understand the target state, new components, and any new patterns implied by the architecture decisions.

---

## Execution Steps:

### Phase 1: Extract Existing Patterns from Codebase

1. **Read Deep-Dive Pattern Catalogs**
   - [ ] Read all `docs/architecture/current/01-*-deep-dive.md` files
   - [ ] For each file, extract the **Pattern Catalog** section
   - [ ] Collect existing patterns with code examples for each category:
     - Error handling
     - Logging
     - Database access
     - API response format
     - Naming conventions
     - Test patterns (unit + integration)
     - Configuration management
   - [ ] Note: where each pattern was found (file path + example)

2. **Read System Overview Context**
   - [ ] Read `docs/architecture/current/00-system-overview.md`
   - [ ] Extract: tech stack, architecture style, existing conventions
   - [ ] Note: any project-wide conventions already documented

2a. **Scan for Duplicate and Misplaced Shared Code** *(mandatory for projects with a UI layer or shared utilities — skip only if purely backend with no shared lib)*
   - [ ] Scan feature folders for components, hooks, utilities, or helpers that are generic (no business logic, usable across 2+ features) but do not live in the project's shared library
   - [ ] Scan for the same utility, hook, or component implemented more than once across different features
   - [ ] List every finding as **tech debt**, not as a pattern to follow — record file path and what it should be replaced with
   - [ ] This list feeds into the patterns document as a "Known Tech Debt — Shared Code" section and must be flagged to the user before implementation begins

3. **Read Target Architecture** (if exists)
   - [ ] Read `docs/architecture/design/02-target-architecture-brownfield.md` :
   - [ ] Extract: new components, new tech choices, any new patterns implied by the target state
   - [ ] Note: which existing patterns the new code must align with

---

### Phase 2: Load Recommended Patterns from Rulebook

4. **Load Rulebook Patterns**
   - [ ] Read `SPEC/rulebooks/aire-design-patterns.md` — extract recommended patterns for all categories
   - [ ] For each category, identify: what the rulebook recommends and why

---

### Phase 3: Pattern Comparison & User Decision

5. **Compare and Present Each Pattern Category**

For **every** category below, present the following comparison block and wait for the user's choice before moving to the next category.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Pattern: [Category Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 CURRENT PATTERN (from your codebase):
Source: [file path where this was found]

[Paste exact code example from deep-dive]

Characteristics:
- [What this pattern does]
- Strengths: [list any positives]
- Gaps: [list weaknesses, inconsistencies, or risks found]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ RECOMMENDED PATTERN (from AIRE rulebook):

[Paste rulebook-recommended code example]

Why this is better:
- [Specific improvement over current pattern]
- [Alignment with industry standard / SOLID / clean architecture]
Migration effort: [Low / Medium / High]
[If High: note what would need to change across the codebase]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❓ Which pattern would you like to standardise on?

  [C] Keep current project pattern
      → Document the existing pattern as the standard.
      → New code must follow this pattern for consistency.

  [N] Adopt new recommended pattern
      → Document the rulebook pattern as the new standard.
      → New code follows new pattern; existing code can be migrated over time.

Your choice (C or N):
```

**Pattern categories to cover** (present one at a time — get decision before moving to next):

- [ ] Error Handling
- [ ] Logging
- [ ] Database Access
- [ ] API Response Format
- [ ] Configuration Management
- [ ] Naming Conventions (files, functions, variables)
- [ ] Code Organisation / Project Structure
- [ ] UI Components / Shared Library *(skip if no UI layer)* — compare how the existing codebase organises shared vs feature-specific components against the recommended pattern. Use the tech debt list from step 2a as evidence of gaps. Flag all misplacements; document the correct rule in the patterns doc with a migration note.

**Special case — if patterns are the same**:

```
✅ Pattern: [Category Name]
Your codebase already follows the AIRE recommended pattern.
No decision needed — documenting as-is.
```

6. **Confirm Final Decisions**

After all categories are decided, present the summary:

```
📋 Pattern Decisions Summary:

| # | Pattern Category | Choice | Migration Effort |
|---|-----------------|--------|-----------------|
| 1 | Error Handling | [C] Current | — |
| 2 | Logging | [N] New | Low |
| 3 | Database Access | [C] Current | — |
| 4 | API Response Format | [N] New | Medium |
| 5 | Configuration | [C] Current | — |
| 6 | Naming Conventions | [C] Current | — |
| 7 | Code Organisation | [N] New | Low |

❓ Confirm these choices and generate the patterns document?
[Y] Yes — proceed
[R] Revise — change one or more decisions
```

---

### Phase 4: Project Structure

7. **Define Project Organisation**
   - [ ] Folder structure (existing + additions for new features from requirements)
   - [ ] File naming conventions (current or updated per choice in Phase 3)
   - [ ] Module organisation aligned with existing architecture
   - [ ] Dependency management approach

8. **Define Code Structure**
   - [ ] Function/class organisation (per choice)
   - [ ] Import ordering (per choice)
   - [ ] File length guidelines
   - [ ] Code formatting rules (consistent with existing tooling — ESLint, Prettier, etc.)

---

### Phase 5: Coding Patterns

> For each pattern below, use the **chosen pattern** (C or N from Phase 3). Include DO and DON'T examples.

9. **Document Error Handling Pattern**
   - [ ] Error types/classes used
   - [ ] Error response format (must match existing API error shape)
   - [ ] Try/catch usage conventions
   - [ ] Error logging approach
   - [ ] Code examples (DO / DON'T)

10. **Document Logging Pattern**
    - [ ] Log levels and when to use each
    - [ ] Log format (structured JSON preferred)
    - [ ] Required context fields (request ID, user ID, module)
    - [ ] What NOT to log (PII, secrets, tokens)
    - [ ] Code examples (DO / DON'T)

11. **Document Database Access Pattern**
    - [ ] Connection management approach
    - [ ] Query patterns (parameterised only — no string concatenation)
    - [ ] Transaction handling
    - [ ] Error handling for DB operations
    - [ ] Code examples (DO / DON'T)

12. **Document API Design Pattern**
    - [ ] Request validation approach
    - [ ] Response format (consistent with existing endpoints)
    - [ ] Error response shape
    - [ ] Authentication handling
    - [ ] Code examples (DO / DON'T)

13. **Document Configuration Pattern**
    - [ ] Environment variables approach
    - [ ] Config file structure
    - [ ] Secrets management
    - [ ] Default values strategy

---

### Phase 6: Testing Patterns

14. **Document Unit Test Pattern**
    - [ ] Test file organisation (aligned with existing test infrastructure from deep-dive)
    - [ ] Test naming convention
    - [ ] Test structure (AAA: Arrange, Act, Assert)
    - [ ] Mocking strategy (consistent with existing approach)
    - [ ] Code examples

15. **Document Integration Test Pattern**
    - [ ] Test environment setup (consistent with existing)
    - [ ] Database handling in tests
    - [ ] External service mocking
    - [ ] Cleanup strategies
    - [ ] Code examples

16. **Document Coverage Requirements**
    - [ ] Minimum coverage: 85%
    - [ ] What to test (all new code; modified code)
    - [ ] What to skip (generated code, config files)
    - [ ] Coverage enforcement (CI gate)

---

### Phase 7: Documentation Standards

17. **Define Documentation Standards**
    - [ ] Code comments guidelines (why, not what)
    - [ ] Function documentation
    - [ ] README structure for new modules
    - [ ] API documentation approach

---

### Phase 7.5: File/Module Boundary Map (MANDATORY)

18. **Define the File/Module Boundary Map for the change set**
    - [ ] List each logical concern impacted by the planned work and the existing file(s) / directory glob(s) that own it (use deep-dive evidence — real paths, not assumed ones)
    - [ ] Add any new modules/directories the target architecture introduces
    - [ ] Identify files that two or more concerns must touch (root config, central route registry, app bootstrap, migrations index, lockfiles, DI container / IoC registry, plugin registration file, feature-flag registry) — these become the `shared_files` list the plan workflow uses in `docs/plans/dependency-graph.yml`
    - [ ] Flag any unavoidable cross-concern files and explain why they exist
    - [ ] This map is the authoritative input the plan workflow uses to populate `files_touched` and `shared_files` in the dependency graph

---

### Phase 8: Create Patterns Document

19. - [ ] Create `docs/architecture/design/03-patterns-and-standards-brownfield.md`
    - [ ] For each pattern: clearly mark whether it is `[Current — kept]` or `[New adoption]`
    - [ ] For patterns marked `[New adoption]`: include a **Migration Note** describing what existing code may need to change and when
    - [ ] Include DO and DON'T examples for every pattern
    - [ ] Include the **File/Module Boundary Map** section
    - [ ] Include quality checklist at the end
    - [ ] Present to user for approval

---

### Phase 9: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `ARCHITECT`
  - **Overall Status** → `🟡 IN PROGRESS`
  - **Progress Summary** → Set "Patterns" row to `✅ Done` with evidence: `docs/architecture/design/03-patterns-and-standards-brownfield.md`
  - **Current Step Details** → Mark all patterns phases complete
  - **Completed Steps** → Add patterns with evidence: `docs/architecture/design/03-patterns-and-standards-brownfield.md`
  - **Upcoming** → `aire-build-cycles` *(optional)* or `aire-brownfield-plan`
  - **Agent Activity** → Update ARCHITECT to Idle

Report to user:
```
✅ docs/status.md updated
   Step: Patterns & Standards → ✅ Done
   Next: Run aire-build-cycles *(optional — skip to aire-brownfield-plan if no build cycles needed)*
```

---

## Output

**Location**: `docs/architecture/design/03-patterns-and-standards-brownfield.md`

**Contents**:
- Project structure (existing + new additions)
- All coding patterns with examples (marked as [Current — kept] or [New adoption])
- Migration notes for newly adopted patterns
- All testing patterns with examples
- DO / DON'T examples for every pattern
- Quality checklist

### Patterns Document Template

```markdown
# Patterns & Standards - [Project Name]

**Date**: [YYYY-MM-DD]
**Author**: ARCHITECT
**Status**: [Draft / Approved]
**Version**: [1.0]
**Based On**:
- docs/architecture/current/00-system-overview.md
- docs/architecture/current/01-[module]-deep-dive.md
- SPEC/rulebooks/aire-design-patterns.md

---

## Pattern Adoption Summary

| Pattern | Decision | Migration Required |
|---------|----------|--------------------|
| Error Handling | [Current — kept] / [New adoption] | [Yes/No] |
| Logging | [Current — kept] / [New adoption] | [Yes/No] |
| Database Access | [Current — kept] / [New adoption] | [Yes/No] |
| API Response Format | [Current — kept] / [New adoption] | [Yes/No] |
| Configuration | [Current — kept] / [New adoption] | [Yes/No] |
| Naming Conventions | [Current — kept] / [New adoption] | [Yes/No] |
| Code Organisation | [Current — kept] / [New adoption] | [Yes/No] |

---

## 1. Project Structure

[Folder structure, naming conventions, module organisation]

---

## 2. Error Handling Pattern

**Decision**: [Current — kept] / [New adoption]
[If New adoption] **Migration Note**: [What to change and when]

### DO
```[lang]
[code example]
```

### DON'T
```[lang]
[code example]
```

---

## 3. Logging Pattern

[Same structure as above for each pattern]

---

## 4. Database Access Pattern

[Same structure]

---

## 5. API Design Pattern

[Same structure]

---

## 6. Configuration Pattern

[Same structure]

---

## 7. Testing Patterns

### Unit Tests
[Pattern, examples, naming convention]

### Integration Tests
[Pattern, examples]

### Coverage Requirements
- Minimum: 85%
- New code: 100% must be covered
- Modified code: existing tests updated as needed

---

## Quality Checklist

- [ ] All new code follows the chosen patterns
- [ ] DO / DON'T examples reviewed
- [ ] Tests follow documented test patterns
- [ ] Coverage meets 85% minimum
- [ ] Code review checked against this document
- [ ] Migration plan noted for [New adoption] patterns
```
---

## Rules

- 🔴 Always compare existing vs recommended — never skip Phase 3
- 🔴 All patterns must have code examples (DO and DON'T)
- 🔴 Mark every pattern as [Current — kept] or [New adoption]
- 🔴 Include migration notes for all [New adoption] patterns
- 🔴 Get user approval on each pattern decision before generating the document
- 🔴 New code for the brownfield project MUST follow the patterns documented here

---

**Type "proceed" to start patterns & standards definition.**

---

## Mandatory Next Steps to suggest user

**You are here → `aire-brownfield-patterns`**

| # | Next Command | Purpose |
|---|-------------|---------|
| ▶️ | `aire-build-cycles` *(optional)* | Break requirements into incremental build cycles — skip if not needed and go to `aire-brownfield-plan` |
| ▶️ | `aire-brownfield-plan` | Create implementation plan with stories (run directly if skipping build cycles) |
