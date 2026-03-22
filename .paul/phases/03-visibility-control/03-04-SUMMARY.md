---
phase: 03-visibility-control
plan: 04
subsystem: drill-downs, user-management
tags: [store-detail, user-management, admin, role-based, supabase-auth]

requires:
  - phase: 01-03
    provides: Store CRUD, product CRUD
  - phase: 02-01
    provides: Payment data (getByStore)
  - phase: 02-02
    provides: Package tracking (getBalancesByStore)
provides:
  - Store detail drill-down screen (orders, payments, packages per store)
  - User management for owner (create admin+driver) and admin (create driver)
  - Owner 5th tab for user management
  - Admin drivers tab with real functionality
affects: [phase-4-admin-expansion, phase-4-per-driver-detail]

tech-stack:
  added: []
  patterns:
    - "FutureProvider.family for parameterized data fetching (ordersByStoreProvider)"
    - "Reusable screen with isOwner flag for role-based behavior (UserManagementScreen)"
    - "Supabase Auth signUp + session restore pattern for user creation"
    - "Client-side product name join for package balances (RPC returns product_id only)"

key-files:
  created:
    - lib/features/stores/screens/store_detail_screen.dart
    - lib/features/driver/repositories/user_repository.dart
    - lib/features/driver/providers/user_management_provider.dart
    - lib/features/driver/screens/user_management_screen.dart
  modified:
    - lib/features/orders/repositories/order_repository.dart
    - lib/features/orders/providers/order_provider.dart
    - lib/features/stores/screens/store_list_screen.dart
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/features/admin/screens/admin_shell.dart
    - lib/features/owner/screens/owner_shell.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Single UserManagementScreen with isOwner flag — avoids code duplication between admin and owner"
  - "Owner gets 5th tab (Users) — Material allows up to 5, most discoverable placement"
  - "Deactivation over deletion for users — preserves order/payment/package referential integrity"
  - "Scrolling sections over tabs for store detail — simpler, better for variable-height content on mobile"
  - "Client-side product name join — RPC returns product_id only, products already cached via productListProvider"

duration: ~25min
completed: 2026-03-22
---

# Phase 3 Plan 04: Store Detail + User Management Summary

**Store detail drill-down with orders/payments/packages per store, reusable user management screen for owner (admin+driver creation) and admin (driver creation), owner 5th tab, admin placeholder replaced.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~25 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 4 |
| Files modified | 8 |
| L10n strings added | 22 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Store Detail Shows Info | Pass | Card with address, phone, contact, balance |
| AC-2: Store Detail Recent Orders | Pass | Last 10 with status + discount chips |
| AC-3: Store Detail Recent Payments | Pass | Last 10 with amount + driver name |
| AC-4: Store Detail Package Balances | Pass | Per-product with name join from productListProvider |
| AC-5: Dashboard Debtors Navigate to Detail | Pass | onTap wired on debtor ListTile |
| AC-6: Owner and Admin Can List Users | Pass | Owner sees drivers+admins, admin sees drivers only |
| AC-7: Owner Can Create Admin or Driver | Pass | Role selector dropdown in create dialog |
| AC-8: Admin Can Create Driver | Pass | Role hardcoded, no selector shown |
| AC-9: Deactivate/Activate Users | Pass | Confirmation dialog, status toggles |

## Accomplishments

- StoreDetailScreen with info card + 3 scrolling sections (orders, payments, packages)
- Store list onTap navigates to detail (edit moved to detail AppBar)
- Dashboard debtors tap navigates to store detail
- UserManagementScreen reusable for owner (isOwner=true) and admin (isOwner=false)
- Owner 5th tab "المستخدمين" with full user management
- Admin drivers tab replaced with real UserManagementScreen
- UserRepository with Supabase Auth signUp + session restore + users table insert
- No more placeholder screens in the entire app

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `lib/features/stores/screens/store_detail_screen.dart` | Created | Drill-down with info, orders, payments, packages |
| `lib/features/driver/repositories/user_repository.dart` | Created | CRUD for users (create via Auth, deactivate/activate) |
| `lib/features/driver/providers/user_management_provider.dart` | Created | allUsersProvider + driversOnlyProvider |
| `lib/features/driver/screens/user_management_screen.dart` | Created | Reusable user list with isOwner role-based behavior |
| `lib/features/orders/repositories/order_repository.dart` | Modified | Added getByStore(storeId) method |
| `lib/features/orders/providers/order_provider.dart` | Modified | Added ordersByStoreProvider (FutureProvider.family) |
| `lib/features/stores/screens/store_list_screen.dart` | Modified | onTap → StoreDetailScreen (was StoreFormScreen) |
| `lib/features/dashboard/screens/owner_dashboard_screen.dart` | Modified | Debtor ListTile onTap → StoreDetailScreen |
| `lib/features/admin/screens/admin_shell.dart` | Modified | Replaced placeholder with UserManagementScreen |
| `lib/features/owner/screens/owner_shell.dart` | Modified | Added 5th tab "Users" with UserManagementScreen |
| `lib/core/l10n/app_ar.arb` | Modified | 22 new strings (store detail + user management) |
| `lib/core/l10n/app_en.arb` | Modified | 22 new strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | None |
| Deferred | 2 | Future enhancement |

**Total impact:** Clean execution.

### Deferred Items

- **Admin feature expansion:** User noted admins should have more features in future. Currently admin has: driver management + stores. Could add: order viewing, payment viewing, package tracking.
- **Per-driver/per-product detail screens:** Explicitly scoped out. Owner has all data via existing list screens.

## Skill Audit

Skill audit: All required skills invoked ✓

| Skill | Phase | Invoked |
|-------|-------|---------|
| /ui-ux-pro-max | PLAN | ✓ |
| /frontend-design | APPLY | ✓ |

## Next Phase Readiness

**PHASE 3 COMPLETE — Ready for Phase Transition**

All 4 plans delivered:
- 03-01: Owner Dashboard (KPIs, debtors, alerts)
- 03-02: GPS Tracking + Live Map (on-duty, OSM)
- 03-03: Discount Approval (request, approve, auto-reject)
- 03-04: Store Detail + User Management (drill-down, admin)

**Phase 4 (Polish & Hardening) is next.**

**Concerns carried forward:**
- ~30fps app lag — needs profiling
- Live countdown timer on pending discounts
- Block print while discount pending
- Admin feature expansion
- Per-driver/per-product detail views

**Blockers:** None

---
*Phase: 03-visibility-control, Plan: 04*
*Completed: 2026-03-22*
