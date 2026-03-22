---
phase: 02-money-packaging
plan: 02
subsystem: packages
tags: [supabase, riverpod, packages, returnable, rpc, rtl]

requires:
  - phase: 02-01
    provides: RPC function pattern, payment flow patterns
provides:
  - Per-product per-store package tracking (given/collected/balance)
  - Auto-logging packages given on order creation for returnable products
  - Standalone package collection screen
  - Package balance via DISTINCT ON RPC query
affects: [02-03-printing, phase-3-dashboard]

tech-stack:
  added: []
  patterns:
    - "DISTINCT ON for latest-per-group queries (package balance)"
    - "Fire-and-forget package logging on order creation"
    - "Per-product balance cards in collection screen"

key-files:
  created:
    - supabase/migrations/003_package_functions.sql
    - lib/features/packages/repositories/package_repository.dart
    - lib/features/packages/providers/package_provider.dart
    - lib/features/packages/screens/package_list_screen.dart
    - lib/features/packages/screens/package_collection_screen.dart
  modified:
    - lib/features/driver/screens/driver_shell.dart
    - lib/features/orders/screens/create_order_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "DISTINCT ON query for efficient per-product balance lookup"
  - "FOR UPDATE lock on create_package_log for concurrent safety"
  - "hasReturnablePackaging added to _LineItem for order hook"
  - "Driver shell: all placeholders removed — 3 main tabs fully wired"

duration: ~25min
completed: 2026-03-22
---

# Phase 2 Plan 02: Per-Product Package Tracking Summary

**Driver tracks returnable packaging per-product per-store. Packages auto-logged on orders, standalone collection for returns. Balance tracked atomically.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~25 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 5 |
| Files modified | 4 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Auto-Log on Order | Pass | Returnable products auto-create package_log entries |
| AC-2: Standalone Collection | Pass | Select store → products with balances → enter collected |
| AC-3: Package List History | Pass | Given/collected badges, balance, date, order indicator |
| AC-4: Empty State | Pass | Icon + message + FAB |
| AC-5: Collection Shows Balances | Pass | Per-product balance displayed via DISTINCT ON RPC |
| AC-6: Validation | Pass | Required store, at least one collected > 0 |
| AC-7: Confirmation Dialog | Pass | Shows products + amounts before submit |
| AC-8: Over-Collection Warning | Pass | Orange warning when collected > balance |

## Accomplishments

- Complete package tracking: auto-given on orders, standalone collection
- Efficient balance query via DISTINCT ON PostgreSQL pattern
- Driver shell fully wired — no more placeholder screens
- Over-collection warning for driver awareness

## Deviations from Plan

None significant. Clean execution.

## Next Phase Readiness

**Ready:**
- Phase 2 Plan 03 (Bluetooth printing) is next
- All driver tabs functional (orders, packages, payments)
- Receipt data available for printing

**Blockers:** None

---
*Phase: 02-money-packaging, Plan: 02*
*Completed: 2026-03-22*
