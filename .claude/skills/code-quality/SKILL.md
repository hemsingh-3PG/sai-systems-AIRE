---
name: code-quality
description: Write and review code based on SOLID principles, clean code practices, and maintainability standards. Use this skill when writing new code, reviewing PRs, or refactoring to ensure high-quality output.
version: "1.0.0"
---

# Code Quality Skill — SOLID & Clean Code

## When to Use
- Writing or reviewing code in any language
- Refactoring existing code
- PR reviews focused on quality and maintainability

---

## SOLID Principles

### S — Single Responsibility
- One class/function = one reason to change
- Flag: god classes, functions doing multiple things, names with "And" (`validateAndSave`)
- Guideline: functions < 20 lines, classes < 200 lines, max 5-7 public methods

### O — Open/Closed
- Open for extension, closed for modification
- Flag: long if-else/switch chains based on type, modifying existing code for new features
- Fix: use polymorphism, strategy pattern, or plugin architecture

### L — Liskov Substitution
- Subtypes must be drop-in replacements for base types
- Flag: subclasses throwing `NotImplementedError`, empty overrides, type-checking before method calls

### I — Interface Segregation
- No client should depend on methods it doesn't use
- Flag: fat interfaces (>5 methods), `pass`/no-op implementations, forced empty overrides

### D — Dependency Inversion
- Depend on abstractions, not concretions
- Flag: `new`/direct instantiation inside constructors, no DI, static calls to external services
- Fix: inject dependencies via constructor parameters

---

## Dead Code Detection
Flag and recommend removal of:
- Code after `return`/`throw`/`break`
- Unused variables, imports, parameters, functions
- Commented-out code blocks (use version control instead)
- Impossible conditions, always-true/false feature flags, redundant checks

---

## Code Smells to Flag
- **Bloaters**: long methods, large classes, >4 parameters, primitive obsession
- **Couplers**: feature envy, train wrecks (`a.b().c().d()`), inappropriate intimacy
- **Change Preventers**: shotgun surgery, divergent change
- **Dispensables**: duplicate code (DRY), lazy classes, speculative generality

---

## Clean Code Rules
- **Naming**: descriptive, intention-revealing names; follow language conventions (snake_case, camelCase, PascalCase)
- **Functions**: do ONE thing, max 3-4 params (use objects for more), consistent abstraction level
- **Complexity**: cyclomatic complexity < 10, max nesting depth 3; use guard clauses/early returns
- **Magic values**: extract to named constants
- **Comments**: explain WHY not WHAT; code should be self-documenting
- **Modularity**: high cohesion within modules, low coupling between them; organize by feature, not by type

---

## Refactoring Guidance
Apply when: Rule of Three (3rd duplication), hard to add features, repeated bugs in same area.

Key patterns:
- **Extract Method** — break long functions into focused helpers
- **Extract Class** — split classes with multiple responsibilities
- **Replace Conditional with Polymorphism** — eliminate type-checking chains
- **Introduce Parameter Object** — group related parameters
- **Move Method** — put behavior where the data lives

---

## Review Checklist
When reviewing code, verify:
- [ ] Each function/class has a single clear responsibility
- [ ] No dead code (unused vars, imports, functions, commented code)
- [ ] No code duplication
- [ ] Nesting depth ≤ 3, complexity < 10
- [ ] Dependencies injected, not hardcoded
- [ ] Descriptive names, no magic numbers
- [ ] Consistent abstraction levels within functions

Always explain which principle was applied or violated and why.
