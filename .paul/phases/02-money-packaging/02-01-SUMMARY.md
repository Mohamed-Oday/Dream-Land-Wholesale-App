---
phase: 02-money-packaging
plan: 01
subsystem: payments
tags: [supabase, riverpod, payments, credit-balance, rpc, rtl]

requires:
  - phase: 01-04
    provides: Order creation flow, Repository/Provider/Screen patterns, store credit_balance field
provides:
  - Payment collection flow (select store → enter amount → confirm → record)
  - Atomic credit balance updates via Supabase RPC (SECURITY DEFINER)
  - Store credit_balance increases on order creation
  - Store credit_balance decreases on payment collection
  - Payment list for driver (own) and owner (all)
  - has_users RPC for init screen detection (bugfix)
affects: [02-02-packaging, 02-03-printing, phase-3-dashboard]

tech-stack:
  added: []
  patterns:
    - "Supabase RPC for atomic multi-table operations (SECURITY DEFINER)"
    - "FOR UPDATE row lock to prevent race conditions on concurrent balance updates"
    - "JWT business_id validation in RPC functions for cross-tenant protection"
    - "Fire-and-forget balance update on order creation (non-blocking)"

key-files:
  created:
    - supabase/migrations/002_payment_functions.sql
    - lib/features/payments/repositories/payment_repository.dart
    - lib/features/payments/providers/payment_provider.dart
    - lib/features/payments/screens/payment_list_screen.dart
    - lib/features/payments/screens/payment_form_screen.dart
  modified:
    - lib/features/driver/screens/driver_shell.dart
    - lib/features/owner/screens/owner_shell.dart
    - lib/features/orders/screens/create_order_screen.dart
    - lib/routing/app_router.dart
    - lib/features/auth/providers/auth_provider.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Supabase RPC (SECURITY DEFINER) for balance updates — drivers can't UPDATE stores directly via RLS"
  - "FOR UPDATE row lock on create_payment to prevent race conditions"
  - "JWT business_id validation in RPC to prevent cross-tenant access"
  - "Fire-and-forget balance update on order creation — order is priority, balance is secondary"
  - "has_users() RPC function to fix init screen bug (RLS blocks unauthenticated user queries)"

patterns-established:
  - "RPC function pattern: client.rpc('function_name', params: {...})"
  - "Atomic balance update: SELECT FOR UPDATE → INSERT → UPDATE in single transaction"
  - "Overpayment warning: non-blocking orange text when amount > balance"
  - "Payment card layout: store name, amount (green), date, balance change arrow"

duration: ~30min
completed: 2026-03-22
---

# Phase 2 Plan 01: Payment Collection + Credit Balance Summary

**Driver collects cash payments from stores with atomic credit balance updates. Orders increase store debt, payments decrease it. Owner views all payment activity.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~30 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 5 |
| Files modified | 7 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Driver Records Payment | Pass | RPC creates payment + updates balance atomically |
| AC-2: Payment Form Shows Balance | Pass | Current balance displayed below store selector |
| AC-3: Balance Decreases on Payment | Pass | Verified in Supabase after payment |
| AC-4: Balance Increases on Order | Pass | Order creation calls update_store_balance_on_order RPC |
| AC-5: Payment List Shows History | Pass | Cards with store, amount, date, balance change |
| AC-6: Empty Payment State | Pass | Icon + message + FAB |
| AC-7: Owner Views All Payments | Pass | Dashboard AppBar icon → PaymentListScreen(isOwner: true) |
| AC-8: Confirmation Dialog | Pass | Shows store, amount, balance change before submit |
| AC-9: Payment Validation | Pass | Required store, amount > 0 |
| AC-10: Overpayment Warning | Pass | Orange warning when amount > balance (non-blocking) |

## Accomplishments

- Complete payment collection flow with atomic Supabase RPC functions
- Credit balance tracking: orders increase debt, payments decrease it
- Row-level locking prevents race conditions on concurrent payments
- JWT authorization in RPC prevents cross-tenant access
- Overpayment warning for driver awareness
- Fixed init screen bug (has_users RPC bypasses RLS for unauthenticated detection)

## Deviations from Plan

### Auto-fixed (2)

**1. Init screen showing despite existing users**
- **Found during:** Human verify (testing in Chrome)
- **Issue:** Both `hasUsersProvider` and `AppRouterNotifier._init()` queried users table directly — RLS returned empty for unauthenticated sessions
- **Fix:** Added `has_users()` RPC function (SECURITY DEFINER) + updated both provider and router to use it
- **Files:** auth_provider.dart, app_router.dart, 002_payment_functions.sql

**2. Supabase anon role needed GRANT EXECUTE**
- **Found during:** Human verify
- **Issue:** `has_users()` function not callable by anon role by default
- **Fix:** Added GRANT EXECUTE ON FUNCTION has_users() TO anon, authenticated
- **Files:** Supabase SQL Editor (manual)

## Next Phase Readiness

**Ready:**
- Payment infrastructure exists — Phase 2 Plan 02 (packaging) can proceed
- RPC function pattern established for future atomic operations
- Store credit_balance is live — dashboard metrics can read it (Phase 3)

**Concerns:**
- GRANT statements for RPC functions need to be included in migration file for reproducibility
- Orphan auth user from early driver creation bug still exists in Supabase Auth

**Blockers:** None

---
*Phase: 02-money-packaging, Plan: 01*
*Completed: 2026-03-22*
