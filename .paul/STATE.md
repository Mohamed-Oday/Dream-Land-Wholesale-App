# Project State

## Project Reference

See: .paul/PROJECT.md (updated 2026-03-21)

**Core value:** Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.
**Current focus:** Phase 8 — Day-1 Fixes (AEGIS Remediation)

## Current Position

Milestone: v0.2.1 AEGIS Audit Remediation (v0.2.1)
Phase: 9 of 10 (Security & Atomicity) — Planning
Plan: 09-01 complete
Status: Loop closed, ready for Plan 09-02
Last activity: 2026-03-23 — Unified 09-01 (SQL Security Hardening)

Progress:
- Milestone v0.1: [██████████] 100% COMPLETE
- Milestone v0.2: [██████████] 100% COMPLETE
- Milestone v0.2.1: [███░░░░░░░] 33%

## Loop Position

Current loop state:
```
PLAN ──▶ APPLY ──▶ UNIFY
  ✓        ✓        ✓     [Loop complete — ready for Plan 09-02]
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

Last session: 2026-03-23
Stopped at: Plan 09-01 loop closed, session paused
Next action: /paul:plan for 09-02 (Atomic Order RPC + Deactivation + Version Check)
Resume file: .paul/HANDOFF-2026-03-23.md
Resume context:
- AEGIS audit complete: 99 findings, 7-section report at .aegis/report/AEGIS-REPORT.md
- Phase 8 DONE: Day-1 fixes (migration 015)
- Phase 9 Plan 01 DONE: SQL security hardening (migration 016 — needs deployment)
- Phase 9 Plan 02 NEXT: Atomic order RPC + deactivation + version check (most complex plan)
- Phase 9 Plan 03 AFTER: Minimum test suite
- Total: 8 phases, 24 plans delivered + 1 plan remaining in Phase 9
Resume file: .aegis/report/AEGIS-REPORT.md (Section 5 — Remediation Roadmap)
Resume context:
- v0.1 COMPLETE: Core loop, money, visibility, hardening (4 phases, 16 plans)
- v0.2 COMPLETE: Admin expansion, procurement, stock & inventory (3 phases, 7 plans)
- v0.2.1 IN PROGRESS: AEGIS audit remediation (3 phases planned)
- Total: 7 phases, 23 plans delivered across 2 milestones
- AEGIS audit: 99 findings across 12 agents, 5 DA challenges resolved
- Next: Plan Phase 8 (Day-1 Fixes — 7 trivial items)

---
*STATE.md — Updated after every significant action*
