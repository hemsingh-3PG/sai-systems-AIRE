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

# Implementation Rulebook

## Purpose

Strict rules for code implementation by DEV agents, incorporating full Definition of Done (DoD) standards.

---

## Core Philosophy

| Principle | Description |
|-----------|-------------|
| **Test-Driven** | Tests WITH code, never postponed (TDD) |
| **Pattern-Adherent** | Follow documented patterns exactly |
| **Evidence-Based** | All work backed by test output and lint reports |
| **Incremental** | Small changes, verified continuously |
| **Clean Exit** | No secrets, no lint warnings, no breaking changes |

---

## Absolute Rules & Constraints

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | CONFIRM BEFORE CODING | Read requirements first, summarize scope, ask "proceed?" and HALT. Do NOT code before confirmation. |
| 🔴 CRITICAL | ONE STORY RULE | One-by-one: implement exactly ONE story per invocation. Present completion, HALT, wait for user choice. When a wave is run **in-one-go** (`aire-dev-implement` auto-suggests it for a parallelizable wave): the **parent orchestrator** may span a dev's full slice, but each spawned worker is scoped to ONE unit — a **single-agent owns one whole story**; a **component-worker owns one component (disjoint files only)**; an **integrator owns the story-level gates** (wiring, integration/E2E, full suite 100%, coverage ≥85%, lint, review doc). Story-level DoD gates run exactly once, in the single-agent or integrator. |
| 🔴 CRITICAL | DEV-SLICE LOCK | Once a dev declares their slot in `aire-dev-implement`, that run may implement ONLY that dev's assigned stories. A story owned by another dev CANNOT be added in-session — same wave or not, parallel-safe or not. No override; reassignment requires re-running the plan workflow. Only genuinely unassigned stories may be picked up beyond the slice. |
| 🔴 CRITICAL | NO SELF-SKIP | NEVER skip stories on agent judgment (e.g., "no code needed"). Present assessment and let user decide. |
| 🔴 CRITICAL | TESTS WITH CODE | Never implement without tests (TDD). Implement tests alongside code, never postpone. |
| 🔴 CRITICAL | RUN ALL TESTS | Run the full test suite (Unit, Integration, E2E) after every single change. |
| 🔴 CRITICAL | RUN TO COMPLETION | **Applies to the build phase only — after the user confirms "proceed" at the CONFIRM BEFORE CODING gate.** Execute every step and every acceptance criterion in the exact order specified, as one continuous pass. Do NOT pause for "milestones", "good progress", or "session boundaries" — only a real HALT condition (unresolved blocker after exhausting references) or genuine story completion ends the run. CONFIRM BEFORE CODING and ONE STORY RULE gates remain mandatory and are not overridden by this rule. |
| 🔴 CRITICAL | UPDATE STATUS | Track progress and update status with evidence (test output + coverage). |
| 🔴 CRITICAL | RESOLVE FROM REFERENCES FIRST | Before asking the user ANY clarifying question, you MUST first read **every** file in the story's **Must Read** and **Context** sections (in full, not skimmed) and re-read the story body. The answer to most "unclear" points is already in those references — that is why they are listed. Only after the references **and** the story together genuinely fail to resolve the gap or contradiction may you ask the user. When you do ask, state which references you read and exactly what they did not answer. NEVER halt with a question whose answer is in a listed reference. |
| 🔴 CRITICAL | NO ASSUMPTIONS | Clarify before assuming — but clarify against the references first (see RESOLVE FROM REFERENCES FIRST). Ask the user only when the story + all its references leave a genuine, unresolved gap. |
| 🔴 CRITICAL | COVER THE WHOLE STORY | A story is implemented only when EVERY acceptance criterion, EVERY numbered step, and EVERY requirement carried by its Must Read references / PRD / design specs is built and proven. Implementing the "happy path" or a subset and marking the story done is a violation. The Definition of Done — Compliance Gates below are the mandatory proof; they must pass before any status flips to ✅ Done. |
| 🔴 CRITICAL | ZERO SECRETS | Use env vars; never commit API keys or hardcoded credentials. |
| 🔴 CRITICAL | NO LINT ERRORS | Zero warnings or errors allowed in production code. |
| 🔴 CRITICAL | NO TODO COMMENTS | Production code must be complete with no TODOs. |
| 🟡 REQUIRED | APPLY SOLID & NO MONOLITHS| Follow SOLID principles. No god classes, no 500+ line files, no tight coupling. |
| 🟡 REQUIRED | FOLLOW PATTERNS | Use error handling, logging, and naming patterns from architecture docs. |
| 🟡 REQUIRED | BACKWARD COMP | No breaking changes without a migration plan. |
| 🟡 REQUIRED | SELF-REVIEW | Document lessons learned after each story. |
| 🟡 REQUIRED | WRITE ONLY TO | Restrict modifications to production code directories and `docs/stories-implemented/`. |
| 🟡 REQUIRED | NO DUPLICATE CODE | Before creating any utility, hook, component, or helper: search the codebase for an existing implementation. If one exists in the correct shared location, use it. If one exists in the wrong location, use it and flag it for migration — do not create a second copy. Creating a duplicate is a violation; raise it with the user first. |
| 🟡 REQUIRED | UI PRIMITIVE CHECK | Before creating any UI component, ask: is this generic enough to be used outside this feature? If yes, it belongs in the project's shared component library, never in a feature folder. A component is a primitive if it carries no business logic and is reusable across two or more features. Existing components found in the wrong location are tech debt — do not imitate their placement. |

---

## Execution Order

Every implementation story follows this sequence:

1. Read plan story requirements and context files
2. Review patterns from docs
3. Confirm understanding with user
4. Write unit tests first (AAA pattern)
5. Implement code (pass tests + no lint errors)
6. Run unit tests (must pass)
7. Write/Run integration and E2E tests
8. Verify environment (update .env.example if needed)
9. Update status with evidence (test logs + coverage)
10. Update documentation (API docs, README, Diagrams)
11. Write self-review document

---

## Code Standards

### Functions
- Maximum 20-30 lines
- Single responsibility
- Maximum 3-4 parameters
- Descriptive names (verb + noun)

### Error Handling
- Use typed errors
- Never swallow errors
- Log with context
- User-friendly messages

### Naming & Security
- Descriptive variable names (no single-letters except loops)
- No secrets in code (use environment variables)
- Consistent conventions

### Documentation
- Explain WHY, not WHAT
- Document public classes and methods (params, returns, errors)
- No commented-out code
- No TODO/FIXME in production

---

  ## Definition of Done — Compliance Gates (MANDATORY)                                                             
   
  Tests-green ≠ spec-met. A story is NOT ✅ Done until every gate below passes.                                    
  Paste evidence into `docs/stories-implemented/story-N.M-review.md` under "## DoD Evidence".

  ### Gate 1 — Spec Echo
  For every requirement in the story (Acceptance Criteria, **every numbered Step**,
  Quality Checks, Design Tokens, constraints, "must", "must not", numeric thresholds,
  named patterns) **AND every requirement carried by the Must Read / Context references
  (PRD, design specs, API contracts, UX specs)**, cite the `file:line` (or command +
  output) that proves it. The requirement set is the story PLUS its references — a story
  that satisfies its inline AC but ignores a constraint stated only in a referenced PRD
  is NOT done. One row per requirement. No blanks, no "implicit", no "covered by tests".
  If the count of AC rows < the count of AC in the story, the gate FAILS — every single
  AC must appear.

  ### Gate 2 — Negative-Space Check
  For every "must NOT" / "no X in Y" / "out of scope" rule, run a check that would
  fail if violated and paste the result. The check format is your choice (grep,
  lint rule, test, manual diff) — but it must be reproducible by another agent.

  ### Gate 3 — Contract Consistency
  Where a story defines two or more layers (input/output, request/response,
  producer/consumer, schema/handler, doc/code), list them side-by-side and verify
  each element on one side has a matching, intentional behavior on the other.
  Silent acceptance, silent ignore, or silent default = bug.

  ### Sign-off rule
  Mark a story ✅ Done only when the checks were actually run and actually passed — never tick a
  checkbox, cite `file:line` evidence, or report a test as passing that you did not run and see pass.
  If any gate fails, the story stays 🟡 In Progress and status.md must NOT flip to ✅ Done.


## Test Standards

### Unit & Integration Tests
- **TDD Non-negotiable**: Tests written before code
- **AAA Pattern**: Arrange/Act/Assert
- **Behavioral Naming**: Names express behavior, not implementation
- **Edge Cases**: Test null, empty, and boundary values
- **Mocks**: Only for external boundaries (API/DB), not internal logic

### Coverage
- Minimum 85% overall
- 100% of new business logic covered
- Meaningful tests (not just coverage)

---

## Evidence Requirements

Status updates MUST include:
- Test command output (copy/paste)
- Coverage percentage and passing test count
- Linter execution output (confirming 0 errors)
- Any failures and resolution

---

## Quality Gates

| Gate | Target | Description |
|------|--------|-------------|
| Unit Test Coverage | ≥85% | All new code |
| All Tests Passing | 100% | Unit, Integration, and E2E |
| Linter Status | Clean | Zero warnings or errors |
| No TODO Comments | 0 | Production ready |
| Secret Check | Passed | No hardcoded credentials |
| Pattern Compliance | 100% | All patterns followed |
| Self-Review | Required | Document created with evidence |

---
 ## Red Flags

| Red Flag | What You Do |
|----------|-------------|
| "Just copy this pattern" | Understand WHY before copying |
| "This test is flaky" | Fix the flakiness, don't skip it |
| "We'll add tests later" | No. Tests go in now. |
| "It works on my machine" | That's not a deployment strategy |
| "The plan doesn't cover this" | Stop, ask Architect/PM |
| Requirements feel ambiguous | Clarify before implementing |
| "Quick fix" | Take the time to do it right |
| Found a component/utility in a feature folder | Check if it's generic. If yes, it's misplaced tech debt — use it but flag it for migration to the shared library. Do not imitate its location. |
| "There's already a similar component" | Do not create a new one. Reuse the existing one or raise it with the user if it needs to be generalised first. |

---

## Forbidden Actions

- 🚫 Skipping tests or writing them after code
- 🚫 Hardcoding secrets or API keys
- 🚫 Committing code with linter warnings
- 🚫 Skipping action items or changing order
- 🚫 Making assumptions without asking