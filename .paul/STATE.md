# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** Phase 7 — Stock & Inventory

## Current Position

Milestone: v0.2 Business Intelligence & Procurement (v0.2.0)
Milestone: Awaiting next milestone
Phase: None active
Plan: None
Status: Milestone v0.2 complete — ready for next
Last activity: 2026-03-22 — Milestone v0.2 completed

Progress:
- Milestone v0.1: [██████████] 100% COMPLETE
- Milestone v0.2: [██████████] 100% COMPLETE

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ○        ○        ○     [Milestone complete — ready for next]
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
| Enterprise audit on 05-01: Applied 1 must-have + 3 strongly-recommended | 05-01 | Plan strengthened: ReceiptPreviewScreen fix (compile-blocking), order join pattern, status indicator, RefreshIndicator async |
| Enterprise audit on 05-02: Applied 1 must-have + 1 strongly-recommended | 05-02 | Plan strengthened: SimpleAttributionWidget (matches existing pattern), map tap guard during save |
| Enterprise audit on 06-01: Applied 1 must-have + 1 strongly-recommended | 06-01 | Plan strengthened: cost_price CHECK >= 0 constraint, flutter gen-l10n step |
| Enterprise audit on 06-02: Applied 1 must-have + 0 strongly-recommended | 06-02 | Plan strengthened: created_by FK to users(id) for PostgREST join |
| Enterprise audit on 06-03: Applied 1 must-have + 1 strongly-recommended | 06-03 | Plan strengthened: collection spread compile fix, KpiCard valueColor for green/red profit |
| Enterprise audit on 07-01: Applied 2 must-have + 2 strongly-recommended | 07-01 | Plan strengthened: RPC idempotency guards (prevent double-deduction), RPC business_id auth check, driver SELECT-only on stock_movements, flutter gen-l10n step |
| Enterprise audit on 07-02: Applied 1 must-have + 1 strongly-recommended | 07-02 | Plan strengthened: adjust_stock zero rejection + negative stock prevention with projected result display, flutter gen-l10n step |

### Deferred Issues
| Issue | Origin | Effort | Revisit |
|-------|--------|--------|---------|
| Printer model selection | PRD | S | Before Phase 2 |
| Arabic thermal printer encoding | Ideation | M | Before Phase 2 |
| Discount timeout duration | Ideation | S | Implemented (3 min auto-reject) |
| Live countdown timer on pending discounts | 03-03 user report | S | Implemented in 04-01 (order list + dashboard) |
| Block order print/finalize while discount pending | 03-03 user report | S | Implemented in 04-01 (print blocked + info banner) |
| Store selector UI needs improvement | 04-01 user report | S | Future plan (DropdownButtonFormField looks bad) |
| Store location picker on map | 01-03 user request | M | Implemented in 05-02 (flutter_map tap-to-set + GPS auto-center) |
| Remove debug error messages from login | 01-02 | S | Before production |
| App feels ~30fps laggy (performance tuning) | 03-01 user report | M | Phase 4 (profile rebuilds, optimize widget trees, provider caching) |

### Blockers/Concerns
None.

## Session Continuity

Last session: 2026-03-22
Stopped at: Milestone v0.2 complete, session paused
Next action: /paul:discuss-milestone for v0.3
Resume file: .paul/HANDOFF-2026-03-22-v02-complete.md
Resume context:
- v0.1 COMPLETE: Core loop, money, visibility, hardening (4 phases, 16 plans)
- v0.2 COMPLETE: Admin expansion, procurement, stock & inventory (3 phases, 7 plans)
- Total: 7 phases, 23 plans delivered across 2 milestones
- Next: Define v0.3 milestone scope

---
*STATE.md — Updated after every significant action*
