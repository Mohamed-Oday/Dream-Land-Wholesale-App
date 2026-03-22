# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** Phase 5 — Admin Expansion + Store Creation

## Current Position

Milestone: v0.2 Business Intelligence & Procurement (v0.2.0)
Phase: 5 of 7 (Admin Expansion + Store Creation) — Not started
Plan: Not started
Status: Ready to plan
Last activity: 2026-03-22 — Milestone v0.2 created

Progress:
- Milestone v0.1: [██████████] 100% COMPLETE
- Milestone v0.2: [░░░░░░░░░░] 0%

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ○        ○        ○     [Ready for first PLAN]
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
| Enterprise audit on 04-01: Applied 2 must-have + 3 strongly-recommended | 04-01 | Plan strengthened: RPC auth check, pending discount neutralization on cancel, migration deploy step, cancel loading state, cancel ownership gate |
| Enterprise audit on 04-02: Applied 1 must-have + 2 strongly-recommended | 04-02 | Plan strengthened: date range end boundary (now() not start-of-day), UTC conversion in Supabase queries, store detail isolation verification |
| Enterprise audit on 04-03: Applied 1 must-have + 2 strongly-recommended | 04-03 | Plan strengthened: auth.uid() for adjusted_by (non-spoofable), zero-amount rejection, threshold input validation |
| Enterprise audit on 04-04: Applied 0 must-have + 2 strongly-recommended | 04-04 | Plan strengthened: FutureProvider for config caching, empty download_url handling |
| Enterprise audit on 04-05: Applied 0 must-have + 3 strongly-recommended | 04-05 | Plan strengthened: printer reconnect name persistence, AC for colors, checkpoint color verify |

### Deferred Issues
| Issue | Origin | Effort | Revisit |
|-------|--------|--------|---------|
| Printer model selection | PRD | S | Before Phase 2 |
| Arabic thermal printer encoding | Ideation | M | Before Phase 2 |
| Discount timeout duration | Ideation | S | Implemented (3 min auto-reject) |
| Live countdown timer on pending discounts | 03-03 user report | S | Implemented in 04-01 (order list + dashboard) |
| Block order print/finalize while discount pending | 03-03 user report | S | Implemented in 04-01 (print blocked + info banner) |
| Store selector UI needs improvement | 04-01 user report | S | Future plan (DropdownButtonFormField looks bad) |
| Store location picker on map | 01-03 user request | M | Phase 3 (OpenStreetMap) |
| Remove debug error messages from login | 01-02 | S | Before production |
| App feels ~30fps laggy (performance tuning) | 03-01 user report | M | Phase 4 (profile rebuilds, optimize widget trees, provider caching) |

### Blockers/Concerns
None.

## Session Continuity

Last session: 2026-03-22
Stopped at: Session paused — v0.2 milestone created
Next action: /paul:plan for Phase 5 (Admin Expansion + Store Creation)
Resume file: .paul/HANDOFF-2026-03-22-v02-start.md
Resume context:
- v0.1 COMPLETE (16 plans, 4 phases)
- v0.2 milestone created: 3 phases (5-admin, 6-procurement, 7-stock)
- Phase 5 first: admin dashboard-lite, product mgmt, driver store creation, map location picker
- Enterprise audit enabled
- Cairo font + warm amber palette applied

---
*STATE.md — Updated after every significant action*
