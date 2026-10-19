---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---
   
# Greenfield Rulebook
## Purpose

Strict rules for designing and building new (greenfield) systems from scratch.

---


## Absolute Rules & Constraints

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | NO VAGUE REQUIREMENTS | Never use vague terms (e.g., "Fast" → "Response < 200ms"). |
| 🔴 CRITICAL | MEASURABLE CRITERIA | All success and failure criteria must be objectively testable. |
| 🔴 CRITICAL | EXPLICIT SCOPE | IN vs OUT must be clearly defined for everything. Everything has a strict boundary (no open scope). |
| 🔴 CRITICAL | VERTICAL FEATURE SLICES | Epic 1 = Foundation (FE+BE setup), then one feature per epic end-to-end. Never use layer-based epics. |
| 🔴 CRITICAL | NO ASSUMPTIONS | Clarify before assuming. Never guess—ask if anything is unclear. |
| 🔴 CRITICAL | CHECK REFERENCES | ALWAYS check `SPEC/references/` before starting ANY workflow. NEVER proceed without reading ALL reference documents. |
| 🟡 REQUIRED | USE AIRE READ | For `.docx` or `.pdf` files, you MUST run the `aire read <file>` command — NEVER skip. |
| 🟡 REQUIRED | CONFIRM UNDERSTANDING | Always confirm understanding and get user approval before proceeding to the next step. |
| 🟡 REQUIRED | WRITE ONLY TO | Restrict file modifications strictly to `docs/`, `docs/architecture/design/`, and `docs/architecture-diagrams/`. |
| 🟡 REQUIRED | DOCUMENT DECISIONS | All architectural and design choices must be recorded with their rationale. |

---

## Quality Gates

| Gate | Target | Description |
|------|--------|-------------|
| Requirement Clarity | 100% | No vague requirements |
| Measurable Criteria | 100% | All criteria objectively testable |
| User Approval | Required | All docs approved before proceeding |
| Complete Scope | 100% | IN/OUT explicitly defined |

---

## Red Flags

| Red Flag | What You Do |
|----------|-------------|
| "Make it fast" | Define: "Response < Xms" |
| "Should be easy to use" | Define specific usability criteria |
| "We'll figure it out later" | Define it now |
| "Just like [competitor]" | Define specific features |
| Unbounded scope | Define explicit boundaries |
| No success criteria | Cannot proceed without them |

---


## Handoff Checklist

Before handing off to DEV:
- [ ] Requirements approved
- [ ] Architecture approved
- [ ] Patterns defined with examples
- [ ] UI/UX spec created (optional) 
- [ ] Implementation plan complete
- [ ] All epics have quality gates
- [ ] User has approved all documentation
