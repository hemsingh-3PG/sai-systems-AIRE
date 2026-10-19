---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: Greenfield Phase 1.3 - Patterns & Standards. Define coding patterns and standards.
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Greenfield - Patterns & Standards

## Agent

**ARCHITECT**

## Before Starting

1. Read `SPEC/agents/AIRE_ARCHITECT.md`
2. Read `SPEC/rulebooks/aire-greenfield-rulebook.md`
3. Read `SPEC/rulebooks/aire-design-patterns.md`
4. **Read**: `docs/requirements.md` — if missing, **STOP**: Tell user to "Run `aire-greenfield-requirements` first."
5. **Read**: `docs/architecture/design/00-system-architecture-greenfield.md` — if missing, **STOP**: Tell user to "Run `aire-greenfield-architecture` first."

---

## Execution Steps:

#### Phase 1: Project Structure

1. **Define Project Organization**
   - [ ] Folder structure
   - [ ] File naming conventions
   - [ ] Module organization
   - [ ] Dependency management

2. **Define Code Structure**
   - [ ] Function/class organization
   - [ ] Import ordering
   - [ ] File length guidelines
   - [ ] Code formatting rules

3. **Define UI Primitive Catalogue** *(mandatory for projects with a UI layer — skip only if there is no frontend)*
   - [ ] List all shared visual primitives (e.g. pill, badge, avatar, icon, button, input, tag, tooltip) with their canonical location in the shared library
   - [ ] Define the rule for what makes something a primitive: **no business logic, reusable across two or more features** → shared library; feature-specific → feature folder
   - [ ] Explicitly state the rule: if a component meets the primitive definition, it must be created in the shared library — creating it inside a feature folder is a violation, not an acceptable alternative
   - [ ] Recommend Storybook (or equivalent) to document and visually verify the primitive catalogue
   - [ ] This catalogue must be included in the patterns document and referenced as a required context file in every story that touches UI

#### Phase 2: Coding Patterns

3. **Define Error Handling Pattern**
   - [ ] Error types/classes
   - [ ] Error response format
   - [ ] Try/catch usage
   - [ ] Error logging
   - [ ] Include code examples

4. **Define Logging Pattern**
   - [ ] Log levels and usage
   - [ ] Log format (structured)
   - [ ] Context to include
   - [ ] What NOT to log (PII, secrets)
   - [ ] Include code examples

5. **Define Database Access Pattern**
   - [ ] Connection management
   - [ ] Query patterns
   - [ ] Transaction handling
   - [ ] Error handling
   - [ ] Include code examples

6. **Define API Design Pattern**
   - [ ] Request validation
   - [ ] Response format
   - [ ] Error responses
   - [ ] Authentication handling
   - [ ] Include code examples

7. **Define Configuration Pattern**
   - [ ] Environment variables
   - [ ] Config file structure
   - [ ] Secrets management
   - [ ] Default values

#### Phase 3: Testing Patterns

8. **Define Unit Test Pattern**
   - [ ] Test file organization
   - [ ] Test naming convention
   - [ ] Test structure (AAA)
   - [ ] Mocking strategy
   - [ ] Include code examples

9. **Define Integration Test Pattern**
   - [ ] Test environment setup
   - [ ] Database handling
   - [ ] External service mocking
   - [ ] Cleanup strategies
   - [ ] Include code examples

10. **Define Coverage Requirements**
    - [ ] Minimum coverage (85%)
    - [ ] What to test
    - [ ] What to skip
    - [ ] Coverage enforcement

#### Phase 4: Documentation

11. **Define Documentation Standards**
    - [ ] Code comments guidelines
    - [ ] Function documentation
    - [ ] README structure
    - [ ] API documentation

12. **Define File/Module Boundary Map (MANDATORY)**
    - [ ] List each logical concern (auth, payments, leads, reporting, …) and the file(s) / directory glob(s) that own it
    - [ ] Identify files that two or more concerns must touch (root config, central route registry, root app bootstrap, migrations index, lockfiles) — these become the `shared_files` list the plan workflow uses in `docs/plans/dependency-graph.yml`
    - [ ] Call out any unavoidable cross-concern files and explain why they exist
    - [ ] This map is the authoritative input the plan workflow uses to populate `files_touched` and `shared_files` in the dependency graph

13. **Create Patterns Document**
    - [ ] Create `docs/architecture/design/01-patterns-and-standards-greenfield.md`
    - [ ] All patterns with examples
    - [ ] DO and DON'T examples
    - [ ] File/Module Boundary Map section (concern → owning files/globs + shared_files list)
    - [ ] Quality checklist
    - [ ] Present to user for approval


### Phase 5: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `ARCHITECT`
  - **Overall Status** → `🟡 IN PROGRESS`
  - **Progress Summary** → Set "Patterns" row to `✅ Done` with evidence: `docs/architecture/design/01-patterns-and-standards-greenfield.md`
  - **Current Step Details** → Mark all patterns phases complete
  - **Completed Steps** → Add patterns with evidence: `docs/architecture/design/01-patterns-and-standards-greenfield.md`
  - **Upcoming** → `aire-build-cycles` *(optional)* or `aire-greenfield-plan`
  - **Agent Activity** → Update ARCHITECT to Idle

Report to user:
```
✅ docs/status.md updated
   Step: Patterns → ✅ Done
   Next: Run aire-build-cycles *(optional — skip to aire-greenfield-plan if no build cycles needed)*
```

---
 
## Output

**Location**: `docs/architecture/design/01-patterns-and-standards-greenfield.md`

**Contents**:
- Project structure
- All coding patterns with examples
- All testing patterns with examples
- DO / DON'T examples
- Quality checklist

---

## Next Steps

After patterns approved, present the following to the user:

```
✅ Patterns & Standards complete!

What's next?

aire-build-cycles *(optional)*
 Break requirements into incremental build cycles (cycle-1, cycle-2, etc.) — skip if you don't need multi-cycle delivery; go straight to aire-greenfield-plan.
```


---

## Rules

- 🔴 All patterns must have code examples
- 🔴 Include DO and DON'T examples
- 🔴 Get user approval before proceeding

---

**Type "proceed" to define patterns and standards.**
