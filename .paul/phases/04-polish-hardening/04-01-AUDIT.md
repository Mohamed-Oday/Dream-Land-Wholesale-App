# Enterprise Plan Audit Report

**Plan:** .paul/phases/04-polish-hardening/04-01-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable (now acceptable after applying fixes)

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **acceptable** after applying 2 must-have and 3 strongly-recommended fixes.

The plan correctly identifies the three most impactful UX friction points from Phase 3 and proposes clean vertical solutions. However, the original cancel_order RPC had two critical gaps: a missing authorization check (any authenticated user could cancel orders across businesses) and a balance integrity bug where cancelling an order with a pending discount would allow the auto-reject to later inflate the store's credit balance. Both have been remediated.

I would approve this plan for production after fixes applied.

## 2. What Is Solid

- **Vertical slice scope**: Countdown, print blocking, and cancellation are tightly related to order lifecycle. No scope creep.
- **Timer implementation**: Using `Timer.periodic` with per-widget setState isolates rebuilds to the chip only. Correct approach for a per-second update in a list.
- **Package log non-reversal**: Correct decision. Physical goods are delivered; cancelling the financial record doesn't un-deliver crates. This avoids a class of reconciliation bugs.
- **Confirmation dialog on destructive action**: Required pattern, present.
- **Boundaries are comprehensive**: Dashboard, location, packages, payments all properly protected. Prior migrations protected.
- **FOR UPDATE locking in RPC**: Correct for preventing concurrent modification of the same order.

## 3. Enterprise Gaps Identified

### Gap 1: Missing Authorization Check in cancel_order (CRITICAL)
All existing RPCs in `006_discount_functions.sql` verify `auth.jwt() -> 'user_metadata' ->> 'business_id'` matches the `p_business_id` parameter. The proposed cancel_order RPC omitted this check. Since the function is `SECURITY DEFINER`, any authenticated user from any business could cancel orders in other businesses by passing a different business_id.

### Gap 2: Balance Integrity Bug — Pending Discount + Cancellation
Scenario: Order created with 1000 DA subtotal, 100 DA pending discount, total = 900 DA.
1. Create order: store balance += 900
2. Cancel order: store balance -= 900 (net: 0) ✓
3. `reject_expired_discounts` runs later: finds order still has discount_status='pending', adds 100 DA back to store balance (net: +100) ✗

The auto-reject function would process the cancelled order's discount, inflating the store balance by the discount amount. This is a silent data corruption bug — no error would be raised, but financial records would be wrong.

### Gap 3: No Ownership Gate on Cancel Button
Without ownership checking, any driver could cancel any other driver's order if they navigate to that receipt. While the UI normally only shows a driver's own orders, edge cases (deep links, shared devices, store detail drill-down) could expose other drivers' orders.

### Gap 4: Double-Tap Race Condition
The cancel button had no loading state, unlike the print button which correctly uses `_isPrinting`. A user rapidly tapping cancel could fire multiple RPC calls. While the database lock would serialize them, the second call would fail with "Only created orders can be cancelled" and show an error to the user.

### Gap 5: No Migration Deployment Verification
Prior plans (03-01 through 03-04) all included explicit migration deployment steps. This plan omitted it for 007_order_cancellation.sql.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Missing auth.jwt() business_id verification in cancel_order RPC | Task 2 action (RPC SQL) | Added `IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID` check matching existing 006 patterns |
| 2 | Pending discount not neutralized on cancellation — allows auto-reject to inflate balance | Task 2 action (RPC SQL) + AC-3 | Added `IF v_order.discount_status = 'pending' THEN UPDATE discount_status = 'none'` block. Extended AC-3 to verify this behavior. |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Migration deployment verification missing | Task 2 verify, Verification section | Added `supabase db push` deployment step to verify and verification checklist |
| 2 | Cancel button has no loading state (double-tap risk) | Task 2 action (Part D), AC-4 | Added `_isCancelling` state pattern matching existing `_isPrinting`. Added AC-4 with double-tap verification. |
| 3 | No ownership gate — any driver could cancel any order | Task 2 action (Part D), AC-4 | Added ownership check: cancel visible only if user is owner/admin OR user.id matches order's driver_id. Added to AC-4. |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Timer clock skew between server UTC and device local time | Minor inaccuracy in a 3-minute window. Field devices may have imprecise clocks, but countdown is informational — auto-reject runs server-side regardless of client display. |
| 2 | Countdown timer not on dashboard pending discounts section | Dashboard is explicitly out of scope per plan boundaries. Dashboard has its own pending discounts list with approve/reject buttons; adding countdown there is a separate concern. |

## 5. Audit & Compliance Readiness

**Authorization**: Now adequate. The cancel_order RPC verifies business_id via JWT, preventing cross-business access. UI-level ownership check provides defense-in-depth.

**Audit trail**: Order status transition is recorded via `updated_at = NOW()`. The cancellation is visible in order history. Balance reversal amount is returned in the RPC response. No silent mutations.

**Balance integrity**: The pending discount neutralization prevents a class of balance inflation bugs. The financial path is now: create → (cancel with reversal) OR (discount approve/reject) — never both.

**Idempotency**: The `status != 'created'` check ensures cancel is idempotent — calling it on an already-cancelled order raises an exception rather than double-reversing. The `_isCancelling` UI state prevents the user from even reaching this edge case.

**Post-incident reconstruction**: An auditor can reconstruct the order lifecycle from: orders.status, orders.discount_status, orders.updated_at, and stores.credit_balance. All state transitions are in the database.

## 6. Final Release Bar

**What must be true before shipping:**
- cancel_order RPC must include JWT authorization check ✓ (applied)
- Pending discounts must be neutralized on cancellation ✓ (applied)
- Migration 007 must be deployed before app update reaches devices

**Remaining risks if shipped as-is (after fixes):**
- Timer display may be off by a few seconds due to client/server clock skew (cosmetic only)
- Package logs are not reversed on cancellation (intentional — documented in boundaries)

**Sign-off:** With the 5 applied upgrades, I would sign my name to this plan. The financial integrity path is sound, authorization is consistent with existing patterns, and the UX improvements directly address user-reported friction.

---

**Summary:** Applied 2 must-have + 3 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
