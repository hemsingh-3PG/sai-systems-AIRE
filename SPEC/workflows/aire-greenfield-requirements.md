---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Greenfield Phase 1.1 - Requirements Definition. Transform ideas into structured requirements.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Greenfield - Requirements Definition

## Agent

**ANALYST_PM_GREENFIELD** 

## Before Starting

1. Read `SPEC/agents/AIRE_ANALYST_PM_GREENFIELD.md`
2. Read `SPEC/rulebooks/aire-greenfield-rulebook.md`
3. Read `docs/status.md` — if missing, **STOP**: Tell user to "Run `aire-project-kickoff` first."
3. **MANDATORY**: Check `SPEC/references/` - run `aire read` for .docx/.pdf (use CMD on Windows)
4. **IF FAILS**: Ask user to run in CMD and paste output

---
  
## What I Need From You

1. **What are we building?**
2. **Who is it for?**
3. **What problem does it solve?**
4. **What does success look like?**
5. **Any constraints?** (Timeline, tech, budget)
6. **MVP, PoC, or Production-ready?**

---
## Reference Document Adherence (CRITICAL)

**ALWAYS check `SPEC/references/` first before any workflow. Reference documents represent approved decisions and are the absolute source of truth. Treat them as requirements, not suggestions.**

| Rule | Description |
|------|-------------|
| 🔴 **STRICTLY FOLLOW** | Execute the vision exactly as specified. |
| 🔴 **NO CHANGES** | Do not suggest modifications to existing feature definitions. |
| 🔴 **NO ALTERNATIVES** | Do not propose alternative approaches unless explicitly asked. |
| 🔴 **CLARIFY ONLY** | Only ask about genuinely ambiguous points. |
| 🔴 **IMPLEMENT, DON'T REDESIGN**| Your job is execution, not re-architecture. |
| 🔴 **NEVER SKIP FILES** | Never skip `.docx`/`.pdf` files — use `aire read` or ask the user to run it. |
| 🔴 **READ ALL FIRST** | NEVER proceed without reading ALL references. |

---

## Execution Steps:

#### Phase 0: Reference Check (MANDATORY FIRST)

**Execute these steps sequentially before gathering new requirements:**

- [ ] **List Directory:** List all files in `SPEC/references/`.
- [ ] **Process Documents:** - For `.docx`/`.pdf`: Run `aire read SPEC/references/<file>` (if it fails, ask the user to run it in CMD and paste the output).
  - For `.md`/`.txt`: Read directly.
- [ ] **Process Designs:** View images/designs and document them in `docs/requirements.md` under the "Design References" section, noting key UI/UX elements.
- [ ] **Process Builds (`SPEC/references/builds/`):**
  - Run `aire read` for `.docx`/`.pdf`; read others directly.
  - **⚠️ CRITICAL:** Build docs represent the product release plan for this greenfield project. They do NOT mean the project already exists. **Do NOT switch to brownfield.**
  - **If builds are found**, infer the sequence from filenames (e.g., numeric/alpha prefixes).
  - Present to the user: `📦 Found [N] builds: [list with 1-line summaries]. Suggested order: Build 1→2→N. Confirm or reorder?`
  - Record the confirmed sequence in `docs/requirements.md` under "Build Sequence". *(Note: This sequence will drive epic/story grouping in implementation planning).*
- [ ] **Check Synced Helix Context (`docs/helix/`):** If `docs/helix/INDEX.md` exists (synced by `aire-helix-sync`), read it and pull the relevant `docs/helix/documents/` files as prior solution context (e.g. discovery notes, product docs already in Helix). Treat as read-only — never edit synced files; if `synced_at` looks stale, suggest re-running `aire-helix-sync`.
- [ ] **Confirm Status:** Confirm to the user exactly what was found and successfully read before moving to Phase 1.

#### Phase 1: Discovery

1. **Understand the Vision**
   - [ ] What are we building?
   - [ ] What problem does it solve?
   - [ ] Who are the target users?
   - [ ] For each user type, what is their ROLE and what can/can't they do? (seeds the Roles & Permissions Matrix)
   - [ ] What is the business value?

2. **Ask Fundamental Questions**
   - [ ] What does success look like?
   - [ ] What would make this fail?
   - [ ] What are the non-negotiable constraints?
   - [ ] What is the timeline?
   - [ ] What is the quality expectation? (MVP/PoC/Production)

3. **Define Project Type**
   - [ ] MVP (Proof of Concept acceptable)
   - [ ] Production-Ready (NO shortcuts)
   - [ ] Internal Tool vs Customer-Facing
   - [ ] Timeline (days/weeks/months)

4. **Gather Technical Constraints**
   - [ ] Required technologies (if any)
   - [ ] Infrastructure constraints
   - [ ] Integration requirements
   - [ ] Security requirements
   - [ ] Performance requirements

#### Phase 2: Requirements Analysis

5. **Define Success Criteria**
   For each criterion:
   - [ ] Is it specific? (Not vague)
   - [ ] Is it measurable? (Objective test)
   - [ ] Is it achievable? (Within constraints)
   - [ ] Is it relevant? (Ties to goal)
   - [ ] Is it time-bound? (Has deadline)

6. **Define Failure Criteria**
   - [ ] What outcomes are unacceptable?
   - [ ] What would cause project failure?
   - [ ] What quality is non-negotiable?

7. **Define Quality Gates**
   - [ ] Test coverage requirements
   - [ ] Performance benchmarks
   - [ ] Security requirements
   - [ ] Documentation requirements

8. **Define Explicit Scope**
   - [ ] List everything IN scope
   - [ ] List everything explicitly OUT of scope
   - [ ] Identify scope boundaries
   - [ ] Get user confirmation on scope

8.5 **Define Roles & Permissions (Roles & Permissions Matrix)**
   - [ ] Enumerate every persona/role that uses the system (give each a stable canonical name — e.g. Admin, Editor, Viewer)
   - [ ] For each role: short description, key permissions it is ALLOWED, what it is explicitly DENIED, and the auth source (JWT claim / DB role / SSO group / service token)
   - [ ] State role hierarchy if additive (e.g. Admin ⊇ Editor ⊇ Viewer)
   - [ ] Assign stable permission keys (e.g. `users:manage`, `reports:view-all`) — these are referenced verbatim by every story's RBAC Enforcement block
   - [ ] If the system has a single actor with no role variation, record one row plus an explicit "no role variation" note
   - [ ] Get user confirmation — this matrix is the canonical role registry for the whole project

#### Phase 3: Documentation

9. **Confirm Understanding**
   - [ ] Summarize all requirements back to user
   - [ ] State all assumptions explicitly
   - [ ] Get user approval before documenting

10. **Create Requirements Document**
    - [ ] Project overview
    - [ ] Roles & Permissions Matrix
    - [ ] Success criteria (measurable)
    - [ ] Failure criteria (explicit)
    - [ ] Technical constraints
    - [ ] Quality gates
    - [ ] Explicit scope
    - [ ] Timeline and milestones

11. **Request Approval**
    - [ ] Present document to user
    - [ ] Address any questions
    - [ ] Get formal approval

12. Create `docs/requirements.md`
 

### Phase 4: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md`
- [ ] Updates to make:
  - **Updated By** → `ANALYST_PM_GREENFIELD`
  - **Overall Status** → `🟡 IN PROGRESS`
  - **Progress Summary** → Set "Requirements" row to `✅ Done` with evidence: `docs/requirements.md`
  - **Current Step Details** → Mark all requirements phases complete
  - **Completed Steps** → Add requirements with evidence: `docs/requirements.md`
  - **Upcoming** → `aire-greenfield-architecture`
  - **Agent Activity** → Update ANALYST_PM_GREENFIELD to Idle

Report to user:
```
✅ docs/status.md updated
   Step: Requirements → ✅ Done
   Next: Run aire-greenfield-architecture
```

---

## Output

**Location**: `docs/requirements.md`


**Contents**:
- Project overview
- Roles & Permissions Matrix (canonical role registry)
- Success criteria (measurable)
- Failure criteria (explicit)
- Technical constraints
- Quality gates
- Explicit scope (IN vs OUT)
- Timeline

### Requirements Document Template

```markdown
# Requirements - [Project Name]

**Date**: [YYYY-MM-DD]  
**Author**: ANALYST_PM_GREENFIELD  
**Status**: [Draft / Approved]  
**Version**: [1.0]

---

## Project Overview

### Vision
[What are we building and why?]

### Problem Statement
[What problem does this solve?]

### Target Users
[Who will use this?]

### Business Value
[Why is this worth building?]

---

## Roles & Permissions Matrix

> Canonical source of truth for all personas/roles. Every story's User Flow by Persona
> and RBAC Enforcement block references these role names + permission keys verbatim.
> Need a role/permission not listed here? Add it here first.

| Role (canonical) | Description | Key Permissions (allow) | Explicitly Denied | Auth Source |
|------------------|-------------|-------------------------|-------------------|-------------|
| Admin  | [who] | users:manage, reports:view-all, system:configure | delete audit logs | JWT claim / DB role / SSO group |
| Editor | [who] | records:create, records:edit-own | approve, manage users | [auth source] |
| Viewer | [who] | read-only permitted records | any write | [auth source] |
| System/Service | non-human | scheduled jobs / webhooks | n/a — no UI | service token |

**Permission keys** (stable IDs referenced by every story's RBAC Enforcement block):
`users:manage`, `reports:view-all`, `records:create`, `records:edit-own`, ...

**Notes**: state role hierarchy if additive (e.g. Admin ⊇ Editor ⊇ Viewer); the Auth Source must match the architecture authorization model. _Single-actor system?_ Record one row and add the note: "No role variation — single actor."

---

## Project Type

| Attribute | Value |
|-----------|-------|
| Type | [Greenfield - New System] |
| Quality Level | [MVP / Production-Ready] |
| Timeline | [X weeks] |
| Hard Deadline | [Date or "Flexible"] |

---

## Success Criteria (MUST HAVE)

| ID | Criterion | Measurement | Target |
|----|-----------|-------------|--------|
| SC-1 | [Specific success] | [How to measure] | [Specific value] |
| SC-2 | [Specific success] | [How to measure] | [Specific value] |
| SC-3 | [Specific success] | [How to measure] | [Specific value] |

**Examples**:
- ✅ Good: "Response time < 200ms for 95th percentile"
- ❌ Bad: "System should be fast"

---

## Failure Criteria (UNACCEPTABLE)

| ID | Criterion | Description |
|----|-----------|-------------|
| FC-1 | [What would fail] | [Why this is unacceptable] |
| FC-2 | [What would fail] | [Why this is unacceptable] |

---

## Technical Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Language | [Required tech] | [Why] |
| Database | [Required DB] | [Why] |
| Hosting | [Target platform] | [Why] |
| Budget | [If applicable] | [Limits] |

---

## Quality Gates

| Gate | Target | Required |
|------|--------|----------|
| Unit Test Coverage | ≥85% | Yes |
| Integration Tests | 100% pass | Yes |
| No Critical Bugs | 0 | Yes |
| Performance | < 200ms response | Yes |
| Security Scan | Pass | Yes |
| Code Review | Approved | Yes |

---

## Design References

**Location**: `SPEC/references/`

| File | Type | Description | Used In |
|------|------|-------------|---------|
| [filename.png] | Wireframe | [Login page mockup] | Story X.X - Frontend |
| [filename.pdf] | Architecture | [System diagram] | Architecture design |
| [filename.docx] | PRD | [Product requirements] | All stories |

**Note**: All design files must be referenced in implementation stories. Frontend stories MUST include "Design Reference" section pointing to specific files.

---

## Functional Requirements

### Feature: [Feature Name]
**Priority**: [Must Have / Should Have / Nice to Have]

**User Story**: As a [user], I want to [action] so that [benefit].

**Acceptance Criteria**:
- [Specific, testable criterion]
- [Specific, testable criterion]
- [Specific, testable criterion]

---

## Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | Response time | < 200ms (p95) |
| Scalability | Concurrent users | 1000 |
| Availability | Uptime | 99.9% |
| Security | Data encryption | At rest + transit |

---

## Explicit Scope

### IN Scope ✅
- [Feature/capability 1]
- [Feature/capability 2]
- [Feature/capability 3]

### OUT of Scope ❌
- [Explicitly excluded 1]
- [Explicitly excluded 2]
- [Explicitly excluded 3]

### Future Considerations (Not This Epic)
- [Future feature 1]
- [Future feature 2]

---

## Assumptions

| Assumption | Impact if Wrong |
|------------|-----------------|
| [Assumption 1] | [What happens if wrong] |
| [Assumption 2] | [What happens if wrong] |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| [Risk 1] | Medium | High | [How to mitigate] |
| [Risk 2] | Low | Medium | [How to mitigate] |

---

## Timeline

| Milestone | Date | Deliverables |
|-----------|------|--------------|
| Requirements Complete | [Date] | This document |
| Architecture Complete | [Date] | Design docs |
| Implementation Complete | [Date] | Working code |
| Unit test Validation | [Date] | Test reports |
| Release | [Date] | Production deploy |

---

## Approval

| Role | Name | Date | Status |
|------|------|------|--------|
| Stakeholder | [Name] | [Date] | [Approved/Pending] |
| Technical Lead | [Name] | [Date] | [Approved/Pending] |
```
---


## Rules

- 🔴 NO vague requirements ("fast" → "< 200ms")
- 🔴 Measurable success criteria
- 🔴 Explicit scope boundaries
- 🔴 Ask before assuming
- 🔴 Capture a Roles & Permissions Matrix; every role-differentiated feature traces to a matrix row (single-actor systems record one row + a "no role variation" note)

---

**Tell me about your project, then type "proceed".**

---

## 🔄 Next Steps in AIRE Workflow

**You are here → `aire-greenfield-requirements`**

| # | Next Command | Purpose |
|---|-------------|---------|
| ▶️ | `aire-greenfield-architecture` | Design system architecture from scratch |
