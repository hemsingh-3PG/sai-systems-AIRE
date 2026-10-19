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
# Review Rulebook

## Purpose

Strict standards for code review by the REVIEWER agent to ensure architectural integrity, security, and maintainability.

---

## Absolute Rules & Constraints

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | NO APPROVAL WITHOUT TESTS | Untested code or failing tests = Auto-Reject. You must verify that tests exist and are meaningful. |
| 🔴 CRITICAL | NO APPROVAL WITH BLOCKERS | All Critical/High (🔴) severity issues must be resolved before approval can be given. |
| 🔴 CRITICAL | ZERO SECRET POLICY | Any hardcoded secret or API key is an immediate Blocker. |
| 🔴 CRITICAL | ARCHITECTURE MATCH | Must follow Clean Architecture (inward dependencies) and strict pattern compliance. |
| 🟡 REQUIRED | READ FIRST | Always read architecture docs and patterns before reviewing. |
| 🟡 REQUIRED | VERIFY EVIDENCE | Manually check test logs and coverage reports to verify the developer's evidence. |
| 🟡 REQUIRED | DOCUMENT FINDINGS & FIXES | Document all issues with severity, specific file lines, and suggest exact code snippets for the fix. |
| 🟡 REQUIRED | REFERENCE PATTERNS | Cite specific pattern docs and architecture sections as evidence in every review comment. |
| 🟡 REQUIRED | WRITE ONLY TO | Restrict modifications strictly to the `docs/reviews/` directory. |

---

## Review Checklist

### Architecture & Design
- [ ] **Clean Architecture**: Dependencies point inward (Domain/Core remains pure)
- [ ] **SOLID Principles**: SRP, OCP, LSP, ISP, and DIP strictly followed
- [ ] **No God Objects**: Files <400 lines; Classes <10 public methods
- [ ] **No Anemic Models**: Domain entities contain logic/behavior, not just data
- [ ] **Module Boundaries**: No circular dependencies between packages/modules

### Code Quality
- [ ] **Readability**: Intent is clear and code is self-documenting
- [ ] **Complexity**: Cyclomatic complexity is low (<10)
- [ ] **Functions**: Small and focused (<50 lines)
- [ ] **DRY**: No significant code duplication
- [ ] **Constants**: No magic numbers; all constants defined at the top or in config
- [ ] **Linter**: Zero warnings/errors confirmed in evidence

### Testing
- [ ] **Unit Tests**: Exist, pass, and follow AAA pattern
- [ ] **Behavioral**: Test names express "what it does" not "how it works"
- [ ] **Coverage**: Minimum 85% verified via coverage report
- [ ] **Mocks**: Used only for external boundaries (API/DB)
- [ ] **Edge Cases**: Boundary and error conditions fully tested

### Security
- [ ] **Secrets**: No API keys, passwords, or tokens in code (use env vars)
- [ ] **Input**: All user inputs validated/sanitized
- [ ] **Auth**: Authentication and Authorization enforced on all endpoints
- [ ] **Object-level authz (IDOR)**: For scoped/`*-own` data, the scope is derived **server-side from the authenticated identity** (token/session), NOT from a client-supplied `email`/`userId`/`managerId`/`orgId` in the query or body. A `requireRole` check alone is insufficient — verify a caller cannot reach another user's/tenant's records by tampering a parameter. Matches the story's RBAC Enforcement "Scope derivation" line.
- [ ] **Injection**: Parameterized queries used for DB; XSS protection for UI
- [ ] **Encryption**: Sensitive data (PII) encrypted at rest and in transit

---

## Issue Severity Levels

| Level | Icon | Description | Action Required |
|-------|------|-------------|-----------------|
| **Blocker** | 🔴 | Critical issue, breaks functionality, security vulnerability | MUST fix before merge |
| **High** | 🟠 | Significant issue, deviates from patterns, missing tests | SHOULD fix before merge |
| **Medium** | 🟡 | Code smell, minor pattern deviation, improvement opportunity | CAN fix after merge |
| **Low** | 🟢 | Suggestion, style preference, nice-to-have | OPTIONAL |

## Issue Categories

| Category | What It Covers |
|----------|---------------|
| **Correctness** | Logic errors, bugs, wrong behavior |
| **Pattern** | Deviation from documented patterns |
| **Testing** | Missing tests, poor test quality |
| **Security** | Vulnerabilities, data exposure |
| **Performance** | Inefficient code, N+1 queries |
| **Documentation** | Missing/incorrect comments/docs |
| **Style** | Naming, formatting, organization |
| **Maintainability** | Hard to read, modify, or test |


---

## Review Verdict

| Verdict | Requirements | Action |
|---------|--------------|--------|
| ✅ **APPROVED** | Zero blockers, all checks pass | Merge allowed |
| 🔄 **CHANGES REQUESTED** | Blockers or high issues exist | DEV must fix and re-submit |
| ❌ **REJECTED** | Critical security or architecture breach | Escalate to ARCHITECT |


---

## Red Flags During Review

| Red Flag | Severity | Action |
|----------|----------|--------|
| No tests | 🔴 Blocker | Cannot approve |
| Hardcoded secrets | 🔴 Blocker | Must fix immediately |
| Object scoped by client-supplied identity (IDOR) | 🔴 Blocker | Derive scope from token/session server-side; never trust client `email`/`userId`/`orgId` |
| SOLID violation - God class | 🔴 Blocker | Must split responsibilities |
| SOLID violation - Tight coupling | 🔴 Blocker | Must use dependency injection |
| File > 400 lines | 🟠 High | Must refactor |
| Function > 30 lines | 🟠 High | Must extract helpers |
| TODO comments | 🟠 High | Should remove |
| No error handling | 🟠 High | Must add |
| Long if/else chains | 🟠 High | Should use strategy pattern |
| Magic numbers | 🟡 Medium | Should fix |
| Poor variable names | 🟡 Medium | Should improve |
| Global state/singletons | 🟡 Medium | Should justify or refactor |
| Missing comments for complex code | 🟢 Low | Suggest adding |

## Forbidden Actions

- 🚫 Approving code without test evidence
- 🚫 Ignoring security findings
- 🚫 Accepting "will fix later" for blockers
- 🚫 Providing feedback without suggested solutions
- 🚫 Approving with linter warnings present
