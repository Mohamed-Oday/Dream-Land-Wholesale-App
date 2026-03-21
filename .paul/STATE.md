# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** Phase 1 — Core Loop — Plan 03 complete, ready for Plan 04

## Current Position

Milestone: v0.1 Initial Release (v0.1.0)
Phase: 1 of 4 (Core Loop) — In progress
Plan: 01-03 complete
Status: Loop closed, ready for next PLAN
Last activity: 2026-03-21 — Plan 01-03 unified

Progress:
- Milestone: [██░░░░░░░░] 20%
- Phase 1: [██████░░░░] 75% (3 of 4 plans)

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ✓        ✓     [Loop complete - ready for next PLAN]
```

## Accumulated Context

### Decisions
| Decision | Phase | Impact |
|----------|-------|--------|
| Riverpod for state management | 01-01 | All providers use Riverpod |
| Direct l10n imports | 01-01 | package:tawzii/core/l10n/... |
| targetTable on SyncQueue | 01-01 | Avoids Drift reserved name |
| Init screen for first-user setup | 01-02 | Self-service owner creation |
| AppRouterNotifier pattern | 01-02 | Single ChangeNotifier for routing |
| username@tawzii.local email format | 01-02 | All Supabase Auth uses this |
| RLS reads user_metadata (not top-level JWT) | 01-03 | get_user_role() uses -> 'user_metadata' ->> 'role' |
| Repository pattern: SupabaseClient + businessId | 01-03 | All data access follows this |
| Navigator.push for sub-screens within shells | 01-03 | GoRouter for top-level, Navigator for in-shell |

### Deferred Issues
| Issue | Origin | Effort | Revisit |
|-------|--------|--------|---------|
| Printer model selection | PRD | S | Before Phase 2 |
| Arabic thermal printer encoding | Ideation | M | Before Phase 2 |
| Discount timeout duration | Ideation | S | Phase 3 |
| Store location picker on map | 01-03 user request | M | Phase 3 (OpenStreetMap) |
| Remove debug error messages from login | 01-02 | S | Before production |

### Blockers/Concerns
None.

## Session Continuity

Last session: 2026-03-21
Stopped at: Plan 01-03 loop closed, ready for 01-04
Next action: Run /paul:plan for Plan 01-04 (Order creation + receipt preview)
Resume file: .paul/HANDOFF-2026-03-21.md
Resume context:
- Phase 1 is 75% complete (3/4 plans done)
- Plan 01-04 is the most complex: multi-step order form, line items, calculations, receipt preview
- After 01-04: Phase 1 transition → Phase 2
- Supabase is live and connected, RLS functions fixed
- Auto-invoke ui-ux-pro-max and frontend-design for UI work

---
*STATE.md — Updated after every significant action*
