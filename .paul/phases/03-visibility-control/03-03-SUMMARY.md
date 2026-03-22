---
phase: 03-visibility-control
plan: 03
subsystem: discounts
tags: [discount-approval, supabase-rpc, owner-control, auto-reject, financial-data]

requires:
  - phase: 01-04
    provides: Order creation flow (discount fields on orders table)
  - phase: 02-01
    provides: Payment/credit balance system (store credit_balance adjustment on reject)
provides:
  - Driver discount request during order creation
  - Owner approve/reject on dashboard with confirmation dialogs
  - Auto-reject expired discounts (>3 min) via server-side RPC
  - Discount status display on order list and receipt
  - Atomic credit_balance adjustment on rejection
affects: [phase-4-live-countdown, phase-4-block-print-pending]

tech-stack:
  added: []
  patterns:
    - "Supabase RPC for atomic financial operations (reject updates order + store balance)"
    - "Auto-reject via server-side RPC called before fetching pending (no client timers)"
    - "RPC raises 'discount_already_processed' for stale UI race condition handling"
    - "Collapsible discount input section on create order form"

key-files:
  created:
    - supabase/migrations/006_discount_functions.sql
  modified:
    - lib/features/orders/screens/create_order_screen.dart
    - lib/features/orders/screens/order_list_screen.dart
    - lib/features/orders/screens/receipt_preview_screen.dart
    - lib/features/orders/repositories/order_repository.dart
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/features/dashboard/providers/dashboard_provider.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Server-side auto-reject (RPC) over client-side timer — reliable, no dependency on app state"
  - "Collapsible discount section — doesn't clutter order creation for most orders without discounts"
  - "Receipt hides discount line when rejected — prevents misleading printed receipts"
  - "Atomic reject: order total recalculated + store credit_balance adjusted in single transaction"

duration: ~25min
completed: 2026-03-22
---

# Phase 3 Plan 03: Discount Approval Flow Summary

**Driver discount request on order creation with collapsible input, owner approve/reject on dashboard with confirmation dialogs, auto-reject expired discounts via server-side RPC, discount status chips on order list, conditional discount line on receipt.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~25 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 1 |
| Files modified | 8 |
| Supabase RPCs added | 3 (approve, reject, reject_expired) |
| L10n strings added | 17 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Driver Can Request Discount | Pass | Collapsible section, pending status, info label |
| AC-2: Discount Cannot Exceed Subtotal | Pass | Client-side validation with error message |
| AC-3: Discount Status on Order List | Pass | Colored chips: pending/approved/rejected |
| AC-4: Receipt Shows Discount Line | Pass | Only for approved/pending, hidden for rejected |
| AC-5: Owner Sees Pending on Dashboard | Pass | Section above debtors with time remaining |
| AC-6: Owner Can Approve | Pass | Confirmation dialog, status updated, card disappears |
| AC-7: Owner Can Reject | Pass | Confirmation dialog, total recalculated, balance adjusted |
| AC-8: Auto-Reject After 3 Min | Pass | Server-side RPC fires on dashboard load/refresh |

## Accomplishments

- Discount input with collapsible section on create order screen
- 3 Supabase RPCs: approve_discount, reject_discount, reject_expired_discounts
- Atomic reject: order total + store credit_balance adjusted in single transaction
- "Pending Discounts" section on owner dashboard with approve/reject actions
- Discount status chips (_DiscountStatusChip) on order list cards
- Conditional discount line on receipt (hidden when rejected)
- Race condition handling: RPCs raise 'discount_already_processed', UI catches gracefully

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/006_discount_functions.sql` | Created | 3 RPCs: approve, reject, auto-reject expired |
| `lib/features/orders/screens/create_order_screen.dart` | Modified | Collapsible discount input, validation, pending status |
| `lib/features/orders/screens/order_list_screen.dart` | Modified | _DiscountStatusChip for pending/approved/rejected |
| `lib/features/orders/screens/receipt_preview_screen.dart` | Modified | Discount deduction line (approved/pending only) |
| `lib/features/orders/repositories/order_repository.dart` | Modified | approve/reject/rejectExpired/getPendingDiscounts methods |
| `lib/features/dashboard/screens/owner_dashboard_screen.dart` | Modified | Pending discounts section with approve/reject UI |
| `lib/features/dashboard/providers/dashboard_provider.dart` | Modified | pendingDiscountsProvider with auto-reject-first pattern |
| `lib/core/l10n/app_ar.arb` | Modified | 17 discount-related Arabic strings |
| `lib/core/l10n/app_en.arb` | Modified | 17 discount-related English strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | None |
| Deferred | 2 | UX polish → Phase 4 |

**Total impact:** Clean execution. Two UX refinements deferred.

### Deferred Items

- **Live countdown timer:** Dashboard shows static "متبقي 2:45" text — needs periodic setState to tick down. Logged for Phase 4.
- **Block print while discount pending:** Driver can currently print/finalize order while discount is still pending. Should wait for approval before printing. Logged for Phase 4.

## Skill Audit

Skill audit: All required skills invoked ✓

| Skill | Phase | Invoked |
|-------|-------|---------|
| /ui-ux-pro-max | PLAN | ✓ |
| /frontend-design | APPLY | ✓ |

## Next Phase Readiness

**Ready:**
- Phase 3 at 75% — Plan 03-04 (drill-downs + admin user management) is next
- All visibility features complete: dashboard, map, discount approval
- Owner has full operational control

**Concerns:**
- ~30fps lag (from Plan 03-01) + map rendering load — Phase 4 performance tuning needed
- Live countdown and print-blocking deferred to Phase 4

**Blockers:** None

---
*Phase: 03-visibility-control, Plan: 03*
*Completed: 2026-03-22*
