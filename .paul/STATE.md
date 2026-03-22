# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** Phase 3 — Visibility & Control — Plan 02 created, awaiting approval

## Current Position

Milestone: v0.1 Initial Release (v0.1.0)
Phase: 3 of 4 (Visibility & Control) — Planning
Plan: 03-04 complete — Phase 3 COMPLETE
Status: Phase 3 finished, Phase 4 next
Last activity: 2026-03-22 — Unified 03-04, Phase 3 complete

Progress:
- Milestone: [████████░░] 75%
- Phase 3: [██████████] 100% (4 of 4 plans)

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ✓        ✓     [Phase 3 COMPLETE — transition to Phase 4]
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
| Enterprise audit on 03-01: Applied 2 must-have + 5 strongly-recommended | 03-01 | Plan strengthened: migration filename fix (004 not 002), timezone to Algeria local, RPC auth check, GRANT EXECUTE, migration deployment step, query index, refresh completion |
| Enterprise audit on 03-02: Applied 2 must-have + 4 strongly-recommended | 03-02 | Plan strengthened: removed BACKGROUND_LOCATION perm, GPS service check, filter inactive drivers, silent insert failures, OSM attribution, migration deployment |
| Enterprise audit on 03-03: Applied 1 must-have + 4 strongly-recommended | 03-03 | Plan strengthened: RPC exception for stale actions, provider location fix, receipt hides rejected discounts, migration deploy, race condition UI handling |
| Enterprise audit on 03-04: Applied 1 must-have + 3 strongly-recommended | 03-04 | Plan strengthened: frontmatter file fix, session restore error handling, package name join, orphaned auth user handling |

### Deferred Issues
| Issue | Origin | Effort | Revisit |
|-------|--------|--------|---------|
| Printer model selection | PRD | S | Before Phase 2 |
| Arabic thermal printer encoding | Ideation | M | Before Phase 2 |
| Discount timeout duration | Ideation | S | Implemented (3 min auto-reject) |
| Live countdown timer on pending discounts | 03-03 user report | S | Phase 4 (static text, needs periodic setState) |
| Block order print/finalize while discount pending | 03-03 user report | S | Phase 4 (driver should wait for approval before printing) |
| Store location picker on map | 01-03 user request | M | Phase 3 (OpenStreetMap) |
| Remove debug error messages from login | 01-02 | S | Before production |
| App feels ~30fps laggy (performance tuning) | 03-01 user report | M | Phase 4 (profile rebuilds, optimize widget trees, provider caching) |

### Blockers/Concerns
None.

## Session Continuity

Last session: 2026-03-22
Stopped at: Phase 3 complete — transition needed
Next action: Phase transition → Phase 4 (Polish & Hardening)
Resume file: .paul/phases/03-visibility-control/03-04-SUMMARY.md
Resume context:
- Phase 3 complete: dashboard, GPS, discounts, store detail, user management
- Milestone v0.1 at 75% — Phase 4 is the final phase
- Phase 4 scope: in-app updates, filters, alerts, performance, edge cases
- Deferred items: ~30fps lag, live countdown, block print pending, admin expansion

---
*STATE.md — Updated after every significant action*
