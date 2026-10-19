<!-- AIRE-SDLC-FRAMEWORK:START -->
# AIRE SDLC Agentic Framework Instructions

# AIRE SDLC Agentic Framework - Claude Code Instructions

> This project uses **AIRE SDLC Agentic Framework** for structured software development.

---

## AIRE SDLC Agentic Framework Method Workflows

### Available Workflows

When user says any of these commands, read the corresponding workflow file:

| Command | Workflow File |
|---------|---------------|
| `aire-brownfield-inspect` | `SPEC/workflows/aire-brownfield-inspect.md` |
| `aire-brownfield-deep-dive` | `SPEC/workflows/aire-brownfield-deep-dive.md` |
| `aire-brownfield-requirements` | `SPEC/workflows/aire-brownfield-requirements.md` |
| `aire-brownfield-architecture` | `SPEC/workflows/aire-brownfield-architecture.md` |
| `aire-brownfield-patterns` | `SPEC/workflows/aire-brownfield-patterns.md` |
| `aire-brownfield-plan` | `SPEC/workflows/aire-brownfield-plan.md` |
| `aire-greenfield-requirements` | `SPEC/workflows/aire-greenfield-requirements.md` |
| `aire-greenfield-architecture` | `SPEC/workflows/aire-greenfield-architecture.md` |
| `aire-greenfield-patterns` | `SPEC/workflows/aire-greenfield-patterns.md` |
| `aire-ui-ux-design` | `SPEC/workflows/aire-ui-ux-design.md` |
| `aire-greenfield-plan` | `SPEC/workflows/aire-greenfield-plan.md` |
| `aire-build-cycles` | `SPEC/workflows/aire-build-cycles.md` |
| `aire-project-kickoff` or `aire-kickoff` | `SPEC/workflows/aire-project-kickoff.md` |
| `aire-dev-implement` | `SPEC/workflows/aire-dev-implement.md` |
| `aire-dev-remediate` | `SPEC/workflows/aire-dev-remediate.md` |
| `aire-enhancement` | `SPEC/workflows/aire-enhancement.md` |
| `aire-drift` | `SPEC/workflows/aire-drift.md` |
| `aire-review-code` | `SPEC/workflows/aire-review-code.md` |
| `aire-qa-test-plan` | `SPEC/workflows/aire-qa-test-plan.md` |
| `aire-qa-validate` | `SPEC/workflows/aire-qa-validate.md` |
| `aire-qa-regression` | `SPEC/workflows/aire-qa-regression.md` |
| `aire-qa-triage` | `SPEC/workflows/aire-qa-triage.md` |
| `aire-devops-discover` | `SPEC/workflows/aire-devops-discover.md` |
| `aire-devops-pipeline` | `SPEC/workflows/aire-devops-pipeline.md` |
| `aire-devops-deploy` | `SPEC/workflows/aire-devops-deploy.md` |
| `aire-devops-infra-evolve` | `SPEC/workflows/aire-devops-infra-evolve.md` |
| `aire-archive` | `SPEC/workflows/aire-archive.md` |
| `aire-data-design` | `SPEC/workflows/aire-data-design.md` |
| `aire-pr-generator` or `pr-generator` | `SPEC/workflows/aire-pr-generator.md` |
| `aire-pr-reviewer` or `pr-reviewer` | `SPEC/workflows/aire-pr-reviewer.md` |
| `aire-raise-defect` or `raise-defect` | `SPEC/workflows/aire-raise-defect.md` |
| `aire-helix-sync` | `SPEC/workflows/aire-helix-sync.md` |

### Quick Start

**Brownfield (existing code)**:
1. `aire-brownfield-inspect` - System discovery
2. `aire-brownfield-deep-dive` - Pattern extraction
3. `aire-brownfield-requirements` - Requirements from analysis
4. `aire-brownfield-architecture` - Target state architecture design
5. `aire-brownfield-patterns` - Compare existing vs recommended patterns; define standards
6. `aire-data-design` - Design or migrate the data platform, model & contracts (optional, when there's scope for Data Engineering & Data Architecture)
7. `aire-build-cycles` - Break into build cycles
8. `aire-ui-ux-design` - UI/UX specification (optional, for UI features)
9. `aire-brownfield-plan` - Implementation planning


**Greenfield (new project)**:
1. `aire-greenfield-requirements` - Requirements
2. `aire-greenfield-architecture` - Architecture
3. `aire-greenfield-patterns` - Coding standards
4. `aire-data-design` - Design the data platform, model & contracts (optional, when there's scope for Data Engineering & Data Architecture)
5. `aire-build-cycles` - Break into build cycles 
6. `aire-ui-ux-design` - UI/UX specification (optional, for UI projects)
7. `aire-greenfield-plan` - Implementation plan

**DevOps**:
1. `aire-devops-discover` - Auto-detect app profile + gather deployment requirements
2. `aire-devops-pipeline` - Create CI/CD pipeline (GitHub Actions)
3. `aire-devops-deploy` - Full deployment setup (infra + SSL + monitoring + runbooks)
4. `aire-devops-infra-evolve` - Brownfield infra evolution (analyze existing IaC/pipelines, design architecture, plan changes)

**Data Engineering**:
1. `aire-data-design` - Design/build a data platform, pipeline, or dataset (discovery → ADR → data model → contracts → quality & DataOps). Greenfield by default; Brownfield migration mode (Strangler Fig + dual-write + shadow read) when `docs/data/current-state.md` exists


### Reference Documents (CRITICAL)

**ALWAYS check `SPEC/references/` first before any design or planning task.**

If reference documents exist (PRD, architecture, Figma designs, etc.):
- 🔴 **STRICTLY FOLLOW** the reference - do not suggest changes
- 🔴 **DO NOT MODIFY** existing feature definitions
- 🔴 **IMPLEMENT** exactly as specified

### Workflow Execution Protocol

1. **Check** `SPEC/references/` for existing documents
2. **Read** the workflow file from `SPEC/workflows/`
3. **Read** the agent definition from `SPEC/agents/`
4. **Read** the relevant rulebook from `SPEC/rulebooks/`
5. **Ask** "Type 'proceed' to start" and wait for confirmation
6. **Execute** following the checklist exactly
7. **Document** outputs in `docs/`

### Configuration Files

| Type | Location |
|------|----------|
| Agent Definitions | `SPEC/agents/` |
| Rulebooks | `SPEC/rulebooks/` |
| Workflows | `SPEC/workflows/` |
| Reference Docs | `SPEC/references/` |

---

## Core Rules

1. **Reference First** - Check SPEC/references/ before any design task
2. **Zero Assumptions** - Ask clarifying questions when uncertain
3. **Evidence-Based** - Paste actual test output as proof
4. **Tests with Code** - Never postpone tests (≥85% coverage)
5. **User Approval** - Ask "proceed?" before major actions

---
<!-- AIRE-SDLC-FRAMEWORK:END -->

---

## Team Workspace (sai-systems-AIRE)

This repository is the team's agentic workspace; the product repos (`PacEHR`, `pacEHR_API`, `PacEHR_AI`) are **siblings of this folder** and belong to the client. Read `TEAM-WORKFLOW.md` for the full process and `AIRE-WORKFLOW-GUIDE.md` for how the workflows chain from requirements to QA.

**Before working on any ticket or answering questions about the system:**
1. Read `context/All/*` and `context/<repo>/project-context.md` for each repo involved. Then read the modules in `docs/architecture/current/` the ticket touches. They are pinned to commit SHAs — verify against the code before relying on them.
2. Summarise your understanding to the user and wait for confirmation before changing anything.
3. One ticket = one folder under `dev-stories/Work-In-Progress/<Epic>/<JIRA-ID>-<slug>/` (copy `dev-stories/_templates/ticket`). Write ticket notes there, not in shared `docs/`.
4. Do **not** edit `docs/status.md` on a ticket branch unless the user asks; the release owner maintains it.
5. Never write anything from this repo (SPEC, docs, context, dev-stories, .claude, .mcp.json) into a product repo. Run `tools/guard.sh` before any push to a client repo.
6. Branch, commit and PR format for the product repos: `context/All/01-git-and-pr-conventions.md`. Never invent a Jira id.
7. Never put secrets, connection strings or patient data in any file, prompt, ticket or PR. Name settings, not values.
8. Pushing, opening or commenting on PRs, transitioning Jira, and deleting or rewriting anything are the user's call — ask first, one action at a time.
