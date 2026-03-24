# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** v0.3 Driver Stock Loading & Notifications

## Current Position

Milestone: v0.3 Driver Stock Loading & Notifications (v0.3.0)
Phase: 11 of 12 (Driver Stock Loading & Shifts) — In Progress
Plan: Phase 11 complete
Status: Phase 11 DONE — ready for Phase 12
Last activity: 2026-03-24 — Phase 11 complete (2 plans, driver stock loading lifecycle)

Progress:
- Milestone v0.1: [██████████] 100% COMPLETE
- Milestone v0.2: [██████████] 100% COMPLETE
- Milestone v0.2.1: [██████████] 100% COMPLETE
- Milestone v0.3: [█████░░░░░] 50%
  - Phase 11: [██████████] 100% COMPLETE
  - Phase 12: [░░░░░░░░░░] 0%

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ✓        ✓     [Loop complete — Phase 11 DONE]
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
| AEGIS full diagnostic audit completed | v0.2.1 | 99 findings, 5 DA challenges, 7-section report. Remediation roadmap drives phases 8-10. |
| Enterprise audit on 08-01: Applied 1 must-have + 2 strongly-recommended | 08-01 | Plan strengthened: migration deployment step, generated l10n verification, REVOKE signature validation |
| Enterprise audit on 09-01: Applied 2 must-have + 2 strongly-recommended | 09-01 | Plan strengthened: added reject_expired_discounts + update_store_balance_on_order to hardening list, REVOKE on trigger function, deployment step |
| Enterprise audit on 09-02: Applied 2 must-have + 3 strongly-recommended | 09-02 | Plan strengthened: idempotency guard (client UUID), cross-business store validation, discount status validation, deactivated user UX, SelectableText on force-update URL |
| Enterprise audit on 09-03: Applied 1 must-have + 2 strongly-recommended | 09-03 | Plan strengthened: mandatory widget_test.dart deletion, closeTo() for float assertions, User construction pattern for AppUser tests |
| Enterprise audit on 10-01: Applied 0 must-have + 2 strongly-recommended | 10-01 | Plan strengthened: REVOKE on set_updated_at trigger function, consolidated cancel_order into single UPDATE with CASE |
| Enterprise audit on 10-02: Applied 1 must-have + 1 strongly-recommended | 10-02 | Plan strengthened: COALESCE on all SQL aggregates (NULL → 0/[]), type-safe Dart extraction from RPC response |
| Enterprise audit on 11-01: Applied 2 must-have + 4 strongly-recommended | 11-01 | Plan strengthened: ALTER stock_movements CHECK constraint, explicit driver_load_items RLS (no FK cascade), FOR UPDATE row lock, driver role+business validation, empty items guard, REVOKE FROM PUBLIC pattern |
| Enterprise audit on 11-02: Applied 2 must-have + 2 strongly-recommended | 11-02 | Plan strengthened: cancel_order reverses quantity_sold + restores stock_on_hand, close_driver_load business_id fetch + returned qty validation + typo fix, add_to_driver_load business_id fetch |

### Deferred Issues
| Issue | Origin | Effort | Revisit |
|-------|--------|--------|---------|
| Printer model selection | PRD | S | Before Phase 2 |
| Arabic thermal printer encoding | Ideation | M | Before Phase 2 |
| Store selector UI needs improvement | 04-01 user report | S | Future plan |
| Remove debug error messages from login | 01-02 | S | Before production |
| Abstract repository interfaces | AEGIS F-01-005 | M | Not needed at current scale |
| GoRouter migration for all routes | AEGIS F-01-004 | L | Not needed for sideloaded APK |
| Drift offline integration | AEGIS F-01-002 | L | Park until field data confirms connectivity gaps |
| Localization of hardcoded Arabic | AEGIS F-09-004 | M | App is Arabic-only for now |
| PrintService singleton refactor | AEGIS F-01-009 | S | Pragmatically correct as-is |

### Blockers/Concerns
None.

## Session Continuity

Last session: 2026-03-24
Stopped at: Phase 11 complete, session paused
Next action: /paul:plan for Phase 12 (Push Notifications via FCM)
Resume file: .paul/HANDOFF-2026-03-24-phase11.md
Resume context:
- Phase 11 COMPLETE: 2 plans, 2 migrations (020+021), 11 new screens/files, 19 modified files
- Bug fixes shipped: stale endDate, 5 missing invalidations, tab-switch refresh, load-aware picker, seller rename, FK fix
- v0.3 milestone 50% complete (Phase 11 done, Phase 12 remaining)
- Phase 12 NEXT: Firebase Cloud Messaging — free push notifications

---
*STATE.md — Updated after every significant action*
