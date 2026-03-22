---
phase: 04-polish-hardening
plan: 01
subsystem: orders, discounts, dashboard
tags: [countdown-timer, print-blocking, order-cancellation, supabase-rpc, l10n]

requires:
  - phase: 03-03
    provides: Discount approval flow (request, approve, reject, auto-reject)
  - phase: 01-04
    provides: Order creation, receipt preview
provides:
  - Live countdown timer on pending discount chips (order list + dashboard)
  - Print blocked while discount pending (receipt preview)
  - Order cancellation flow with balance reversal (owner/admin only)
affects: [phase-4-remaining-plans]

tech-stack:
  added: []
  patterns:
    - "Timer.periodic for live countdown on StatefulWidget chips"
    - "Ownership gate on destructive actions (owner/admin only for cancel)"
    - "Local order state mutation + setState for immediate UI feedback after RPC"

key-files:
  created:
    - supabase/migrations/007_order_cancellation.sql
  modified:
    - lib/features/orders/screens/order_list_screen.dart
    - lib/features/orders/screens/receipt_preview_screen.dart
    - lib/features/orders/repositories/order_repository.dart
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Cancel restricted to owner/admin only — user feedback that drivers should not cancel without approval"
  - "Dashboard countdown added despite boundary exclusion — user explicitly requested it"
  - "Removed updated_at from cancel RPC — column does not exist on orders table"
  - "Pending discount neutralized on cancellation (discount_status → 'none') — prevents auto-reject balance inflation"

duration: ~30min
completed: 2026-03-22
---

# Phase 4 Plan 01: Discount UX Polish + Order Cancellation Summary

**Live countdown timer on pending discount chips (order list + dashboard), print blocked while discount pending, order cancellation with balance reversal restricted to owner/admin.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~30 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 1 |
| Files modified | 6 |
| L10n strings added | 4 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Live Countdown on Pending Discount Chips | Pass | M:SS format, Timer.periodic, auto-refresh on expiry |
| AC-2: Print Blocked While Discount Pending | Pass | Print button disabled + warning banner with hourglass icon |
| AC-3: Order Cancellation with Balance Reversal | Pass | RPC with auth check, pending discount neutralization, confirmation dialog |
| AC-4: Cancel Button Respects Ownership | Pass | Changed to owner/admin only per user feedback (stricter than plan) |

## Accomplishments

- _DiscountStatusChip converted to StatefulWidget with live M:SS countdown, auto-refresh on expiry
- _PendingDiscountTile on dashboard also converted to live countdown with approve/reject disabled on expiry
- Receipt preview print button gated by discount_status with info banner
- cancel_order RPC with JWT auth check, FOR UPDATE locking, pending discount neutralization
- Cancel button with loading state, confirmation dialog, owner/admin-only gate

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/007_order_cancellation.sql` | Created | cancel_order RPC with auth, locking, balance reversal, discount neutralization |
| `lib/features/orders/screens/order_list_screen.dart` | Modified | _DiscountStatusChip → StatefulWidget with Timer.periodic countdown |
| `lib/features/orders/screens/receipt_preview_screen.dart` | Modified | Print blocking, info banner, cancel button with ownership gate + loading state |
| `lib/features/orders/repositories/order_repository.dart` | Modified | Added cancelOrder(orderId) method |
| `lib/features/dashboard/screens/owner_dashboard_screen.dart` | Modified | _PendingDiscountTile → StatefulWidget with live countdown, buttons disabled on expiry |
| `lib/core/l10n/app_ar.arb` | Modified | 4 new strings (discountPendingPrintBlocked, cancelOrder, cancelOrderConfirm, orderCancelled) |
| `lib/core/l10n/app_en.arb` | Modified | 4 new strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 1 | Essential — orders table has no updated_at column |
| Scope additions | 1 | User-requested — dashboard countdown |
| Scope changes | 1 | User-requested — cancel restricted to owner/admin only |
| Deferred | 1 | Store selector UI needs improvement |

**Total impact:** Essential fixes + user-driven scope adjustments. No uncontrolled creep.

### Auto-fixed Issues

**1. Database: updated_at column does not exist on orders table**
- **Found during:** Task 2 (user testing)
- **Issue:** cancel_order RPC included `updated_at = NOW()` but orders table has no updated_at column
- **Fix:** Removed `updated_at = NOW()` from the UPDATE statement
- **Verification:** Migration applies cleanly, cancel RPC works

### Scope Changes

**1. Dashboard countdown (user-requested)**
- Plan boundaries excluded lib/features/dashboard/ but user explicitly requested live countdown on dashboard pending discounts
- Converted _PendingDiscountTile from StatelessWidget to StatefulWidget with Timer.periodic
- Approve/reject buttons auto-disable on expiry

**2. Cancel restricted to owner/admin only (user feedback)**
- Plan had ownership gate allowing drivers to cancel their own orders
- User feedback: drivers should not cancel without owner/admin approval
- Changed canCancel to `currentUser.isOwner || currentUser.isAdmin` only

### Deferred Items

- **Store selector UI:** User noted the DropdownButtonFormField for store selection looks bad on the create order screen. Pre-existing issue, not related to this plan. Should be addressed in a future plan (possibly 04-02 or dedicated UI polish).

## Skill Audit

Skill audit: All required skills invoked ✓

| Skill | Phase | Invoked |
|-------|-------|---------|
| /ui-ux-pro-max | PLAN | ✓ |
| /frontend-design | APPLY | ✓ |

## Next Phase Readiness

**Ready:**
- Order lifecycle complete: create → (cancel) or (deliver), with discount approval flow fully polished
- Dashboard shows live countdown, order list shows live countdown
- 4 plans remaining in Phase 4 (04-02 through 04-05)

**Concerns:**
- Store selector UI needs improvement (deferred)
- orders table lacks updated_at column — future plans should not assume it exists

**Blockers:** None

---
*Phase: 04-polish-hardening, Plan: 01*
*Completed: 2026-03-22*
