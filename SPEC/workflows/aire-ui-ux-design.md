---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
description: UI/UX Design Phase - Create design specification between Architecture and Implementation Planning
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# UI/UX Design Workflow

## Agent

**UI_UX_DESIGNER**

## Before Starting

1. Read `SPEC/agents/AIRE_UI_UX_DESIGNER.md`
2. **MANDATORY**: Read `docs/requirements.md` — if missing, **STOP**:  "Run `aire-greenfield-requirements` (greenfield) or `aire-brownfield-requirements` (brownfield) first."
3. **Detect project type & read architecture** — check for the brownfield indicator file first, then greenfield:
   - **Brownfield** (if `docs/architecture/current/00-system-overview.md` exists): read it — if missing any of the following, **STOP** as noted:
     - Any `docs/architecture/current/01-*-deep-dive.md` files — if none found, **STOP**: Tell user to "Run `aire-brownfield-deep-dive` first."
     - `docs/architecture/design/02-target-architecture-brownfield.md` — if missing, **STOP**: Tell user to "Run `aire-brownfield-architecture` first."
     - `docs/architecture/design/03-patterns-and-standards-brownfield.md` — if missing, **STOP**: Tell user to "Run `aire-brownfield-patterns` first."
   - **Greenfield** (else if `docs/architecture/design/00-system-architecture-greenfield.md` exists): read it. Also read `docs/architecture/design/01-patterns-and-standards-greenfield.md` if it exists (from `aire-greenfield-patterns`) — use it to align design tokens and component choices with the established patterns.
   - **Neither detected** (no `docs/architecture/current/00-system-overview.md` and no `docs/architecture/design/00-system-architecture-greenfield.md`) → **STOP**: "Tell user to run `aire-brownfield-inspect` (brownfield) or `aire-greenfield-architecture` (greenfield) first."
4. List files in `SPEC/references/` (filenames only — do not read yet)
   - If any design files or images exist → ask user: "Found reference files in SPEC/references/. Are these approved final designs with no open decisions? [S] Skip UI/UX workflow / [P] Proceed". Stop if [S].

---

## 12-Step Process

### Phase 1: Init & Discovery (Steps 01-03)

#### Step 01: Read Context Documents

- [ ] Read `docs/requirements.md` (mandatory)
- [ ] **Brownfield** (if `docs/architecture/current/00-system-overview.md` exists): Read it + all `docs/architecture/current/01-*-deep-dive.md` files
  - Read `docs/architecture/design/02-target-architecture-brownfield.md` — use it to understand new components, new tech choices, and integration points that the UI must surface
  - Read `docs/architecture/design/03-patterns-and-standards-brownfield.md` — extract tech stack, existing UI conventions, and naming patterns to align design tokens with the adopted coding standards
- [ ] **Greenfield** (else if `docs/architecture/design/00-system-architecture-greenfield.md` exists): Read it
  - If `docs/architecture/design/01-patterns-and-standards-greenfield.md` exists: read it — extract tech stack constraints, component naming, and icon set references for use in design tokens
- [ ] Extract from requirements:
  - Platform constraints (Desktop/Mobile/Web)
  - Tech stack (React, Chart.js, Tailwind, etc.)
  - Auth method (if applicable)
  - Key features and user flows
- [ ] Extract from architecture:
  - Component structure
  - Technology decisions
  - Integration points
- [ ] For EACH .docx file in `SPEC/references/`: Run `aire read SPEC/references/<filename>.docx`
- [ ] For EACH .pdf file in `SPEC/references/`: Run `aire read SPEC/references/<filename>.pdf`
- [ ] Read all .md, .txt files in `SPEC/references/` directly
- [ ] Create `docs/ui-ux/01-discovery.md` with findings

#### Step 02: Ask Design Questions

**DO NOT ASSUME**. Ask user these questions based on what's NOT clear from requirements/architecture:

```
📋 UI/UX Design Questions:

Based on requirements and architecture, I need clarification on:

1. **Target User Emotion**: What feeling should the UI evoke?
   - [ ] Professional & Trustworthy (Corporate, Finance)
   - [ ] Efficient & Fast (Productivity, Tools)
   - [ ] Friendly & Approachable (Consumer, Social)
   - [ ] Modern & Innovative (Tech, Startups)
   - [ ] Other: [Specify]

2. **Design System Preference**: Do you have a preference?
   - [ ] Material Design (Google-style)
   - [ ] Ant Design (Enterprise-focused)
   - [ ] Tailwind (Utility-first)
   - [ ] Custom (We'll create from scratch)
   - [ ] Existing brand guidelines in SPEC/references/

3. **Data Density**:
   - [ ] High (More info per screen, compact)
   - [ ] Medium (Balanced)
   - [ ] Low (Spacious, minimal)

4. **Primary Navigation Style**:
   - [ ] Fixed Sidebar (Always visible)
   - [ ] Collapsible Sidebar (Can hide)
   - [ ] Top Navigation Bar
   - [ ] Tabs
   - [ ] Other: [Specify]

5. **Error Display Method**:
   - [ ] Inline (below field)
   - [ ] Toast notifications (top-right)
   - [ ] Modal dialogs
   - [ ] Banner at top

6. **Loading States**:
   - [ ] Skeleton screens (content placeholders)
   - [ ] Spinners/loaders
   - [ ] Progress bars
   - [ ] Hybrid approach

7. **Color Preferences** (if not in brand guidelines):
   - Primary color: [Hex code or description]
   - Any colors to avoid: [List]

8. **Accessibility Level** (WCAG AA is enforced as minimum — cannot be lowered):
   - [ ] WCAG AA (Standard, default)
   - [ ] WCAG AAA (Enhanced — stricter contrast, more keyboard coverage)

9. **Inspiration/Reference**: Any apps/sites you want to emulate?
    - [List URLs or app names]

10. **Responsive Target**:
   - [ ] Desktop-only
   - [ ] Desktop + Tablet
   - [ ] All viewports (Desktop + Tablet + Mobile)

Please answer the questions above, or type [S] to skip and use defaults as option A.
```

Wait for user response. DO NOT proceed without answers.

#### Step 03: Document Decisions

- [ ] Document user's answers in `docs/ui-ux/01-discovery.md`
- [ ] Map emotional response to color psychology:
  - Professional/Trust → Blue
  - Efficient → Gray/Blue
  - Friendly → Warm colors (Orange, Green)
  - Modern → Bold colors (Purple, Teal)
- [ ] **SAVE CHECKPOINT**: `docs/ui-ux/03-inspiration.md`

---

### Phase 2: System Design (Steps 04-08)

#### Step 04: Design System

Based on user's answers, create design tokens:

- [ ] **Colors**: Primary, secondary, success, error, warning, backgrounds, text
- [ ] **Spacing**: Base unit (4px, 8px, or custom), scale (4, 8, 16, 24, 32, 48, 64)
- [ ] **Typography**: Font family, base size, scale, weights
- [ ] **Elevation**: Shadow levels (0, 1, 2, 4, 8, 16)

**Platform-Specific Adjustments**:
- Desktop: Dense layouts, smaller touch targets (32px min)
- Mobile: Touch-friendly (44px min), larger spacing
- Web: Responsive breakpoints

**Tech-Specific Adjustments**:
- Chart.js: Use Chart.js default color palette for consistency
- Tailwind: Align with Tailwind spacing scale
- Material UI: Use Material Design tokens

#### Step 05: User Approval Gate

Present to user:
```
🎨 Design System Preview:
Applied Constraints:
- Tech Stack: [e.g., Tailwind CSS detected/selected]
- Platform: [e.g., Mobile-First]
Colors:
- Primary: [Color from user input or default]
- Secondary: [Based on primary]
- Success: #4CAF50 (Green — default, modifiable)
- Error: #F44336 (Red — default, modifiable)

Spacing: [4px / 8px / custom] base unit
Typography: [Font inferred from design system or Inter], [Size] base
Elevation: 6 levels

❓ Approve design system?

[A] Approve  [M] Modify
```

**STOP. DO NOT proceed to Step 06 until user responds with [A] or [M].**
If [M]: ask what to modify, update tokens, re-present preview. Repeat until [A].

#### Step 06: Visual Foundation

- [ ] Define component hierarchy:
  - Atoms: Button, Input, Label, Icon
  - Molecules: FormField, SearchBar, Card
  - Organisms: LoginForm, DataTable, Sidebar
- [ ] Define grid system:
  - Desktop: 12-column grid
  - Tablet: 8-column grid
  - Mobile: 4-column grid
- [ ] Define elevation/shadow system for depth

#### Step 07: Responsive Layout Strategy

Based on user's responsive target (from Step 02 Q10):

- [ ] **Breakpoints**: Define based on responsive target
  - sm: 640px, md: 768px, lg: 1024px, xl: 1280px
  - Omit unused breakpoints for Desktop-only targets
- [ ] **Layout per breakpoint**:
  - Navigation: [from user Step 02 Q4 — adapted per breakpoint]
  - Grid: 12-col (xl/lg) → 8-col (md) → 4-col (sm)
  - Content: max_width_centered (xl) → full_bleed (sm)
- [ ] **Component responsive rules**:
  - Tables: standard_table (lg+) → card_stack (sm)
  - Modals: centered_overlay (lg+) → full_screen_sheet (sm)
  - Forms: multi_column (lg+) → single_column (sm)
  - Charts: full_interactive (lg+) → simplified_readonly (sm)
- [ ] **Touch targets**:
  - Desktop (non-touch): 32px min
  - Touch-enabled viewports: min 44px, comfortable 48px, spacing 8px
- [ ] **Per-viewport typography/spacing scales**:
  - lg scale: [12,14,16,20,24,32] / spacing [4,8,16,24,32,48,64]
  - sm scale: [11,13,15,18,22,28] / spacing [4,8,12,16,24,32,48]

#### Step 08: Checkpoint Save & Approval Gate

- [ ] **SAVE CHECKPOINT**: `docs/ui-ux/08-visual-foundation.md`

Present to user:
```
📐 Visual Foundation Summary:

Component Hierarchy: Atoms → Molecules → Organisms
Grid System: [12/8/4]-column per viewport
Responsive Strategy: [Navigation collapse rules from Step 07]
Touch Targets: [min 44px if touch-enabled, else 32px]
Breakpoints: [Based on responsive target from Step 02]

❓ Approve visual foundation before defining UX patterns?

[A] Approve  [M] Modify
```

**STOP. DO NOT proceed to Phase 3 until user responds with [A] or [M].**
If [M]: ask what to modify, update foundation, re-present. Repeat until [A].

---

### Phase 3: Execution & Polish (Steps 09-12)

#### Step 09: Component Strategy

Map components to features (from `docs/requirements.md`):

- [ ] For each feature in requirements → identify required component(s)

Define reusable patterns (from requirements):
- [ ] List applicable patterns (e.g. DataTable, Modal, Sidebar) — do not assume

#### Step 10: UX Patterns

Use user's answers from Step 02 or read docs/ui-ux/01-discovery.md to define:

- [ ] **Validation**: on-submit (default)
- [ ] **Error Display**: [User's choice from Step 02 or docs/ui-ux/01-discovery.md]
- [ ] **Success Feedback**: Toast/Banner/Inline (define how successful actions are confirmed)
- [ ] **Loading States**: [User's choice from Step 02 or docs/ui-ux/01-discovery.md]
- [ ] **Navigation**: [User's choice from Step 02 or docs/ui-ux/01-discovery.md]
- [ ] **Data Density**: [User's choice from Step 02 or docs/ui-ux/01-discovery.md]
- [ ] **Bulk Actions**: Checkbox select + toolbar (if applicable)
- [ ] **Search/Filter**: Sidebar panel vs inline filters

#### Step 11: User Approval Gate

Present to user:
```
✅ UX Patterns Defined:

Validation: on-submit (default)
Error Display: [From user's choice]
Success Feedback: [Defined in Step 10]
Loading States: [From user's choice]
Navigation: [From user's choice]
Data Density: [From user's choice]
Bulk Actions: [If applicable]
Search/Filter: [If applicable]

❓ Approve UX patterns?

[A] Approve  [R] Revise
```

**STOP. DO NOT proceed to Step 12 until user responds with [A] or [R].**
If [R]: ask what to revise, update patterns, re-present. Repeat until [A].

#### Step 12: Accessibility & Generate Spec

Define accessibility requirements:

- [ ] **WCAG Level**: [User's choice from Step 02]
- [ ] **Focus States**: Visible on all interactive elements
- [ ] **Keyboard Navigation**: Tab order, shortcuts
- [ ] **ARIA Labels**: Required for all icons, buttons
- [ ] **Color Contrast**: 4.5:1 for text, 3:1 for UI components
- [ ] **Screen Reader**: Semantic HTML, proper headings

**⚠️ MANDATORY SUB-GATE**: Every A11y item above must be checked before proceeding. Do NOT generate YAML until all accessibility requirements are fully defined.

Generate final spec:

- [ ] Compile all phases into final specification
- [ ] Use compressed YAML format (no prose)
- [ ] **TOKEN COUNT MUST BE <700 tokens**
- [ ] **SAVE FINAL OUTPUT**: `docs/ui-ux/ui-ux-spec.md`

#### Step 13: Update docs/status.md (MANDATORY)

- [ ] **Read `SPEC/templates/STATUS_FORMAT.md`** — mandatory format for status.md
- [ ] Read existing `docs/status.md` first; if it does not exist, create it using `SPEC/templates/STATUS_FORMAT.md` format
- [ ] Updates to make:
  - **Updated By** → `UI_UX_DESIGNER`
  - **Overall Status** → `🟡 IN PROGRESS`
  - **Progress Summary** → Set "UI/UX Design" row to `✅ Done` with evidence: `docs/ui-ux/ui-ux-spec.md`
  - **Current Step Details** → Mark all UI/UX design phases complete
  - **Completed Steps** → Add UI/UX design with evidence: `docs/ui-ux/ui-ux-spec.md`
  - **Upcoming** → `aire-greenfield-plan` or `aire-brownfield-plan`
  - **Agent Activity** → Update UI_UX_DESIGNER to Idle

Report to user:
```
✅ docs/status.md updated
   Step: UI/UX Design → ✅ Done
   Next: Run aire-greenfield-plan or aire-brownfield-plan
```

> **icons**: No emojis. Use professional icon set inferred from `docs/requirements.md` + `docs/architecture/design/00-system-architecture-greenfield.md` (e.g. Lucide, Heroicons, Material Icons). Add `icons: {set: [inferred], style: outlined|filled}` under `design_tokens`.

---

## Output

**Primary Output**: `docs/ui-ux/ui-ux-spec.md`

**Checkpoints** (for session resume):
- `docs/ui-ux/03-inspiration.md`
- `docs/ui-ux/08-visual-foundation.md`

**Intermediate Outputs** (audit trail, not resume points):
- `docs/ui-ux/01-discovery.md`

**Final Specification Structure**:
```yaml
version: 1.0
platform: [Desktop/Mobile/Web]
tech_stack: [from requirements]

design_tokens:
  colors: {...}
  breakpoints: {sm: 640px, md: 768px, lg: 1024px, xl: 1280px}
  spacing:
    base: [4px/8px/custom]
    scale: {lg: [4,8,16,24,32,48,64], sm: [4,8,12,16,24,32,48]}
  typography:
    font_family: [inferred from design system / SPEC/references/]
    base_size: [14px]
    scale: {lg: [12,14,16,20,24,32], sm: [11,13,15,18,22,28]}
    weights: [400,500,600,700]
  elevation: {...}
  touch_targets: {desktop_min: 32px, touch_min: 44px, comfortable: 48px, spacing: 8px}
  icons: {set: [inferred_from_requirements], style: [outlined|filled]}

responsive_behavior:
  layout:
    navigation: [from user Step 02 Q4 — adapted per breakpoint]
    grid: {xl: 12_columns, lg: 12_columns, md: 8_columns, sm: 4_columns}
    content: {xl: max_width_centered, sm: full_bleed}
  components:
    tables: {lg: standard_table, sm: card_stack}
    modals: {lg: centered_overlay, sm: full_screen_sheet}
    forms: {lg: multi_column, sm: single_column}
    charts: {lg: full_interactive, sm: simplified_readonly}

ux_logic:
  validation: on-submit
  error_display: [from user Step 02]
  success_feedback: [from Step 10]
  loading_states: [from user Step 02]
  navigation: [from user Step 02]
  data_density: [from user Step 02]

component_map:
  navigation: [from user Step 02]
  forms: [from ux_logic]
  tables: [if applicable]
  charts: [if applicable]
  modals: [if applicable]
  notifications: [from ux_logic]

user_journey:
  primary_path: [main user flow]
  critical_flows: [list]

a11y:
  level: [from user Step 02]
  focus_states: true
  keyboard_nav: true
  aria_labels: required
  color_contrast: 4.5:1

patterns:
  error_display: [from ux_logic]
  success_feedback: [from ux_logic]
  bulk_actions: [if applicable]
  search_filter: [if applicable]
```

---

## Rules

- 🔴 ASK design questions - DO NOT assume
- 🔴 Token count <700 for final spec
- 🔴 3 user approval gates (Steps 05, 08, 11)
- 🔴 Platform-aware design (Desktop ≠ Mobile)
- 🔴 Tech-aware design (Chart.js colors, Tailwind spacing)
- 🔴 Accessibility built-in (WCAG AA minimum)
- 🔴 Save checkpoints at Steps 03, 08

---

**Type "proceed" to start UI/UX design workflow.**

---

## 🔄 Next Steps in AIRE Workflow

**You are here → `aire-ui-ux-design`**

*Shared across Greenfield & Brownfield tracks*

| # | Next Command | Purpose |
|---|-------------|---------|
| ▶️ | `aire-greenfield-plan` | Create implementation plan (Greenfield track) |
| ▶️ | `aire-brownfield-plan` | Plan changes with detailed stories (Brownfield track) |

