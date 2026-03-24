---
phase: 11-driver-stock-loading
plan: 01
subsystem: database, ui
tags: [supabase, rpc, rls, riverpod, flutter, bluetooth-printing]

requires:
  - phase: 07-stock-inventory
    provides: stock_on_hand field, stock_movements table, deduct/replenish RPCs
  - phase: 10-structural-improvements
    provides: set_updated_at trigger, CHECK constraints, dashboard RPC
provides:
  - driver_loads + driver_load_items tables
  - create_driver_load atomic RPC (stock deduction + movement logging)
  - get_driver_loads RPC (with driver name, item counts)
  - Load creation screen (admin/owner)
  - Load receipt screen with Bluetooth printing
  - Load list screen with status badges
  - Dashboard entry points (owner + admin)
affects: [11-02-shift-close, order-integration]

tech-stack:
  added: []
  patterns: [driver-load-atomic-rpc, per-table-rls-subquery]

key-files:
  created:
    - supabase/migrations/020_driver_loads.sql
    - lib/features/driver_loads/repositories/driver_load_repository.dart
    - lib/features/driver_loads/providers/driver_load_providers.dart
    - lib/features/driver_loads/screens/create_load_screen.dart
    - lib/features/driver_loads/screens/load_receipt_screen.dart
    - lib/features/driver_loads/screens/load_list_screen.dart
  modified:
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/features/admin/screens/admin_dashboard_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "PostgREST column-based FK disambiguation for two FKs to users table"
  - "Partial unique index for one-active-load-per-driver enforcement"
  - "FOR UPDATE row lock on product stock to prevent concurrent over-deduction"

patterns-established:
  - "driver:users!driver_id(name) — column-based PostgREST FK disambiguation"
  - "EXISTS subquery RLS on child tables without business_id column"

duration: ~45min
started: 2026-03-24T00:00:00Z
completed: 2026-03-24T00:00:00Z
---

# Phase 11 Plan 01: Driver Load Schema & Load Creation Summary

**Atomic driver stock loading with warehouse deduction, receipt printing, and admin/owner dashboard integration — admin picks driver + products, RPC deducts warehouse stock and logs movements, receipt prints via Bluetooth.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~45 min |
| Tasks | 3 completed |
| Files created | 6 |
| Files modified | 4 |
| L10n strings added | 18 (AR + EN) |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Atomic Load Creation | Pass | RPC creates load, items, deducts stock, logs movements atomically |
| AC-2: One Active Load Per Driver | Pass | Partial unique index + RPC guard both enforce |
| AC-3: Stock Validation on Load | Pass | FOR UPDATE lock + quantity check with RAISE EXCEPTION |
| AC-4: Load Receipt Printing | Pass | RepaintBoundary + PrintService.printFromWidget pattern |
| AC-5: Load List View | Pass | RPC-backed list with status badges, FAB to create |

## Accomplishments

- Atomic `create_driver_load` RPC with 6 validation guards (auth, business, driver role, empty items, active load, stock)
- `driver_loads` + `driver_load_items` tables with RLS (explicit EXISTS subquery on child table)
- Load creation screen following established create_order_screen pattern
- Load receipt + load list screens with dashboard entry points for owner and admin

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/020_driver_loads.sql` | Created | Tables, RPCs, RLS, indexes, triggers, grants |
| `lib/features/driver_loads/repositories/driver_load_repository.dart` | Created | Repository with createLoad, getLoads, getLoadDetail |
| `lib/features/driver_loads/providers/driver_load_providers.dart` | Created | Riverpod providers (repo, list, detail) |
| `lib/features/driver_loads/screens/create_load_screen.dart` | Created | Driver picker + product picker + confirm flow |
| `lib/features/driver_loads/screens/load_receipt_screen.dart` | Created | Receipt card + Bluetooth print |
| `lib/features/driver_loads/screens/load_list_screen.dart` | Created | Card list + detail loader + FAB |
| `lib/features/dashboard/screens/owner_dashboard_screen.dart` | Modified | Added truck icon → LoadListScreen |
| `lib/features/admin/screens/admin_dashboard_screen.dart` | Modified | Added truck icon → LoadListScreen |
| `lib/core/l10n/app_ar.arb` | Modified | +18 Arabic strings |
| `lib/core/l10n/app_en.arb` | Modified | +18 English strings |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Column-based FK disambiguation (`driver:users!driver_id`) | Two FKs to users table require PostgREST hint | Future queries on driver_loads must use this pattern |
| EXISTS subquery RLS on driver_load_items | Supabase RLS doesn't cascade through FK joins | Consistent pattern for child tables without business_id |
| ALTER stock_movements CHECK first | Existing CHECK blocks 'load_out' inserts | Migration order matters — ALTER before any RPC calls |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 1 | Missing FK references on driver_id + loaded_by — added during verification |
| Scope additions | 0 | — |
| Deferred | 1 | Adjust active load feature |

### Auto-fixed Issues

**1. Missing FK references on driver_loads**
- **Found during:** User verification (load detail screen errored)
- **Issue:** `driver_id` and `loaded_by` columns had no `REFERENCES users(id)`, breaking PostgREST joins
- **Fix:** Added FK constraints to migration + fixed repository to use column-based disambiguation
- **Files:** `020_driver_loads.sql`, `driver_load_repository.dart`, `load_list_screen.dart`
- **Verification:** User confirmed load detail screen works after fix

### Deferred Items

- Adjust active load quantities (user request) — add to Plan 11-02 scope

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| Load detail screen error (PostgREST join fail) | Added FK constraints + column-based disambiguation |

## Next Phase Readiness

**Ready:**
- driver_loads + driver_load_items tables exist with data
- stock_movements accepts 'load_out' and 'load_return' types
- quantity_sold and quantity_returned columns ready for Plan 11-02 RPCs
- Load list and receipt screens can be extended for shift close

**Concerns:**
- Adjust active load feature not yet built (user requested — deferred to 11-02)

**Blockers:**
- None

---
*Phase: 11-driver-stock-loading, Plan: 01*
*Completed: 2026-03-24*
