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


# Brownfield Rulebook

## Purpose

Strict rules for analyzing and working with existing (brownfield) codebases.


## Absolute Rules & Constraints

| Priority | Rule | Description |
|----------|------|-------------|
| 🔴 CRITICAL | NO CODE CHANGES | Analysis phase NEVER modifies, refactors, or alters existing code. |
| 🔴 CRITICAL | NO README TRUST | Base documentation on actual code analysis only, not existing READMEs. |
| 🔴 CRITICAL | NO ASSUMPTIONS | Clarify before assuming; ask the user if anything is unclear. |
| 🔴 CRITICAL | CHECK REFERENCES | ALWAYS check `SPEC/references/` and NEVER proceed without reading all reference docs. |
| 🟡 REQUIRED | USE AIRE READ | For `.docx` or `.pdf` files, you MUST run the `aire read <file>` command - NEVER skip. |
| 🟡 REQUIRED | READ & VERIFY | Always analyze code before documenting and cross-check findings against actual code. |
| 🟡 REQUIRED | CONFIRM UNDERSTANDING | Always confirm understanding with the user before proceeding to the next step. |
| 🟡 REQUIRED | DOCUMENT PATTERNS | Extract and document existing code patterns as you find them. |


---

## Quality Gates

| Gate | Target | Description |
|------|--------|-------------|
| Diagram Accuracy | 100% | Diagrams match actual code |
| Pattern Examples | Required | All patterns have code examples |
| **User Confirmation** | Required | User confirms before proceeding |
| Code Verification | Required | All findings verified against code,  No README-based assumptions |

## Red Flags

| Red Flag | What You Do |
|----------|-------------|
| "The README says..." | Verify against actual code |
| "I assume this means..." | Stop and ask |
| "This should work like..." | Analyze the actual implementation |
| Large module with no tests | Document as risk |
| Inconsistent patterns | Document variations |
| Undocumented external calls | Investigate thoroughly |