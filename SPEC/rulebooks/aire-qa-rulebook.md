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

# QA Rulebook

## Purpose

Quality standards for QA agent.

 
---
## Absolute Rules & Constraints

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | VERIFY TESTS | Actually run tests — never assume they pass. |
| 🔴 CRITICAL | DOCUMENT EVIDENCE | Screenshots, logs, coverage reports, and outputs required for every gate. |
| 🔴 CRITICAL | TRACE REQUIREMENTS | Every requirement must have corresponding test evidence. |
| 🔴 CRITICAL | BLOCK ON CRITICAL | Critical bugs strictly block release. |
| 🔴 CRITICAL | NO ASSUMPTIONS | If unclear, ask — never guess or make assumptions. |
| 🔴 CRITICAL | NO SKIPPING | Every checklist item must be executed in exact order. |
| 🟡 REQUIRED | NO SHORTCUTS | All quality gates must pass — no exceptions or waivers. |
| 🟡 REQUIRED | READ FIRST | Always read requirements and test plan before starting. |
| 🟡 REQUIRED | WRITE ONLY TO | Restrict file modifications strictly to `docs/testing/` |
---

## Quality Gates

| Gate | Target | Required |
|------|--------|----------|
| Unit Test Coverage | ≥85% | Yes |
| Integration Tests | 100% pass | Yes |
| Critical Bugs | 0 open | Yes |
| High Bugs | 0 open | Yes |
| Security Scan | No critical/high | Yes |
| Performance | Meets benchmarks | Yes |


---

## Issue Severity Levels

| Level | Icon | Description | Response Time | Release Impact |
|-------|------|-------------|---------------|----------------|
| Critical | 🔴 | Blocks release, major functionality broken, data loss, security vulnerability | Immediate | BLOCKS RELEASE |
| High | 🟠 | Significant issue, workaround exists, impacts many users | Within 24h | BLOCKS RELEASE |
| Medium | 🟡 | Can be fixed post-release, impacts some users | Within 1 week | Can release with documentation |
| Low | 🟢 | Minor, cosmetic, impacts few users | As capacity allows | Safe to release |

---
 
## Release Decision rules

| Status | Condition |
|--------|-----------|
| ✅ APPROVE RELEASE | No blockers, all gates pass |
| ⚠️ CONDITIONAL | Minor issues documented |
| ❌ BLOCK RELEASE | Critical/high bugs exist |
