# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** Phase 2 — Money & Packaging — Plan 01 created, awaiting approval

## Current Position

Milestone: v0.1 Initial Release (v0.1.0)
Phase: 2 of 4 (Money & Packaging) — Planning
Plan: 02-03 unified, all 3 plans complete
Status: Loop closed, Phase 2 complete
Last activity: 2026-03-22 — Plan 02-03 unified, Phase 2 complete

Progress:
- Milestone: [█████░░░░░] 50%
- Phase 2: [██████████] 100% (3 of 3 plans)

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ✓        ✓     [Loop complete — Phase 2 finished]
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
| Enterprise audit on 01-04: Applied 2 must-have + 3 strongly-recommended | 01-04 | Plan strengthened: atomic insert cleanup, driver name join, confirmation dialog, error categorization |

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

Last session: 2026-03-22
Stopped at: Phase 2 complete
Next action: Phase transition → Phase 3 (Visibility & Control)
Resume file: .paul/phases/02-money-packaging/02-03-SUMMARY.md
Resume context:
- Phase 2 complete: payments, packages, printing
- Milestone v0.1 at 50%
- Phase 3 next: owner dashboard, GPS tracking, live map, discount approval
- Bluetooth printing needs hardware test before production

---
*STATE.md — Updated after every significant action*
