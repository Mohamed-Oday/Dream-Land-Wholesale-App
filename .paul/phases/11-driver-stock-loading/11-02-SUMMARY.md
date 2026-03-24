---
phase: 11-driver-stock-loading
plan: 02
subsystem: database, ui
tags: [supabase, rpc, riverpod, flutter, bluetooth-printing, cache-invalidation]

requires:
  - phase: 11-driver-stock-loading/01
    provides: driver_loads + driver_load_items tables, create_driver_load RPC, load UI
provides:
  - close_driver_load RPC (stock restoration + shift close)
  - add_to_driver_load RPC (upsert items to active load)
  - create_order_atomic Step 6 (driver sales tracking)
  - cancel_order enhanced (reverses driver sales + restores warehouse stock)
  - Driver stock screen (loaded/sold/remaining)
  - Shift close screen + return receipt
  - Add-to-load screen for admin/owner
  - Driver shell 6th tab (Stock)
  - Load-aware product picker (only driver's loaded products selectable)
affects: [phase-12-push-notifications]

tech-stack:
  added: []
  patterns: [load-aware-order-creation, shift-close-reconciliation]

key-files:
  created:
    - supabase/migrations/021_driver_load_operations.sql
    - lib/features/driver_loads/screens/driver_stock_screen.dart
    - lib/features/driver_loads/screens/shift_close_screen.dart
    - lib/features/driver_loads/screens/return_receipt_screen.dart
    - lib/features/driver_loads/screens/add_to_load_screen.dart
  modified:
    - lib/features/driver_loads/repositories/driver_load_repository.dart
    - lib/features/driver_loads/providers/driver_load_providers.dart
    - lib/features/driver/screens/driver_shell.dart
    - lib/features/driver_loads/screens/load_list_screen.dart
    - lib/features/orders/screens/create_order_screen.dart
    - lib/features/orders/screens/receipt_preview_screen.dart
    - lib/features/orders/providers/order_provider.dart
    - lib/features/orders/repositories/order_repository.dart
    - lib/features/payments/providers/payment_provider.dart
    - lib/features/packages/providers/package_provider.dart
    - lib/features/packages/screens/package_collection_screen.dart
    - lib/features/products/screens/product_form_screen.dart
    - lib/features/suppliers/screens/supplier_form_screen.dart
    - lib/features/purchase_orders/providers/purchase_order_provider.dart
    - lib/features/owner/screens/owner_shell.dart
    - lib/features/admin/screens/admin_shell.dart
    - lib/core/providers/date_range_provider.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Load-aware product picker: driver can only sell products in their load"
  - "Date ranges use startDate only (no endDate) to prevent stale query results"
  - "Tab switch triggers provider invalidation for fresh data"
  - "Driver → Seller rename throughout l10n"

patterns-established:
  - "Always invalidate relevant providers after any mutation"
  - "Date ranges: startDate only, no endDate bound"
  - "Tab switch invalidation in all shells"

duration: ~60min
started: 2026-03-24T00:00:00Z
completed: 2026-03-24T00:00:00Z
---

# Phase 11 Plan 02: Shift Close, Order Integration & Add-to-Load Summary

**Complete driver stock lifecycle: order creation tracks driver sales, shift close with return receipt, add-to-load for admin, load-aware product picker, and app-wide stale data fixes (date range + provider invalidation).**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~60 min |
| Tasks | 3 completed |
| Files created | 5 |
| Files modified | 19 |
| L10n strings added | 12 (AR + EN) |
| Bug fixes (bonus) | 8 stale-data issues fixed |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Close Driver Load | Pass | RPC restores stock, logs load_return movements, validates returned qty |
| AC-2: Order Tracks Driver Sales | Pass | Step 6 in create_order_atomic increments quantity_sold |
| AC-3: Driver Stock View | Pass | 6th tab shows loaded/sold/remaining with color coding |
| AC-4: Return Receipt | Pass | Bluetooth printing with loaded/sold/returned columns |
| AC-5: Add to Active Load | Pass | Upsert RPC + product picker screen + load list action buttons |

## Accomplishments

- 4 RPCs in migration 021: close_driver_load, add_to_driver_load, modified create_order_atomic (Step 6), modified cancel_order (reverses driver sales + restores stock)
- Driver stock screen with shift close flow and return receipt
- Load-aware product picker: driver can only order products in their active load
- App-wide stale data fixes: removed endDate from all date range queries, added provider invalidation to 5 screens missing it, added tab-switch refresh to all 3 shells

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 8 | Stale data bugs across the app — date range endDate + missing provider invalidations |
| Scope additions | 2 | Load-aware product picker + driver→seller rename |
| Deferred | 0 | — |

### Auto-fixed Issues

**1. Stale endDate in date range queries (ALL list screens)**
- **Found during:** User verification — new orders not appearing in list
- **Issue:** `todayRange()` computed `endDate = DateTime.now()` once at app start; orders created later fell outside the range
- **Fix:** Removed endDate from all 7 provider queries across orders, payments, packages, purchase orders
- **Files:** date_range_provider.dart, order_provider.dart, payment_provider.dart, package_provider.dart, purchase_order_provider.dart, order_repository.dart

**2. Missing provider invalidations (5 screens)**
- **Found during:** Codebase audit for similar issues
- **Fix:** Added invalidations after mutations in: package_collection_screen, product_form_screen, supplier_form_screen, receipt_preview_screen (cancel), receipt_preview_screen (done)

**3. Tab switch not refreshing data (3 shells)**
- **Found during:** User report
- **Fix:** Added provider invalidation in onDestinationSelected for driver_shell, owner_shell, admin_shell

**4. Order receipt missing store name**
- **Found during:** User verification
- **Fix:** Added `orderData['stores']` with store name before navigating to receipt

### Scope Additions

**1. Load-aware product picker** — User requested that drivers should only be able to order products in their active load. Products not in load are greyed out with "غير محمّل" label.

**2. Driver → Seller rename** — User requested changing "سائق" to "بائع" throughout the app. Updated all l10n strings and the driver shell role label.

## Next Phase Readiness

**Ready:**
- Phase 11 COMPLETE — full driver stock loading lifecycle operational
- Phase 12 (Push Notifications) is next
- All stock tracking, shift management, and load operations working end-to-end

**Concerns:**
- None

**Blockers:**
- None

---
*Phase: 11-driver-stock-loading, Plan: 02*
*Completed: 2026-03-24*
