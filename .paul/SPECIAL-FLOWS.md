# Special Flows

## IMPORTANT: Auto-Invocation Rule

**Claude MUST automatically invoke these skills without asking the user.** Do NOT prompt the user to run these skills manually. When the trigger condition is met, invoke the skill immediately.

## Configured Skills

### UI UX Pro Max — Design & Planning
- **Role:** Design planning, design system decisions, UX patterns, layout strategy
- **Trigger:** ANY task involving UI planning, screen design, layout decisions, design system setup, or component specs
- **Auto-invoke:** YES — Claude invokes `/ui-ux-pro-max` automatically during PLAN phase for any frontend work
- **Purpose:** Color systems, typography scales, spacing, component specs, interaction states, accessibility, RTL layout strategy, brand palette (#F5A623), Material Design 3 theming, Flutter-specific design patterns

### Frontend Design — Implementation
- **Role:** Code implementation of designed screens
- **Trigger:** ANY task involving writing Flutter UI code, building screens, creating widgets, or implementing components
- **Auto-invoke:** YES — Claude invokes `/frontend-design` automatically during APPLY phase for any UI implementation
- **Purpose:** Production-grade frontend code with high design quality, translating design specs into polished Flutter widgets, avoiding generic AI aesthetics

## Flow Rules

- Skills are AUTO-INVOKED by Claude — never ask the user to invoke them
- **Plan UI → UI UX Pro Max fires automatically** (design decisions, specs, layout)
- **Build UI → Frontend Design fires automatically** (code implementation from specs)
- Never implement UI without design planning first
- UI UX Pro Max outputs feed directly into Frontend Design inputs

## Flow Sequence

```
PLAN phase:  [AUTO] /ui-ux-pro-max  →  design specs, component plans, layout strategy
APPLY phase: [AUTO] /frontend-design →  Flutter code from those specs
```

---
*Configured: 2026-03-21*
