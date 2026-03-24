# Enterprise Plan Audit Report

**Plan:** .paul/phases/11-driver-stock-loading/11-02-PLAN.md
**Audited:** 2026-03-24
**Verdict:** Conditionally acceptable → Acceptable after auto-applied fixes

---

## 1. Executive Verdict

**Conditionally acceptable**, elevated to **acceptable** after applying 2 must-have and 2 strongly-recommended fixes.

The plan correctly extends 11-01's foundation with shift close, order integration, and add-to-load. The RPC designs follow established patterns. However, source-level verification revealed a critical lifecycle gap: introducing quantity_sold tracking in create_order_atomic without corresponding reversal in cancel_order would cause shift close reconciliation errors after any cancellation.

I would sign this plan after the applied fixes.

## 2. What Is Solid

- **CREATE OR REPLACE approach** for create_order_atomic — additive Step 6, preserves all existing logic. Low-risk modification.
- **Graceful skip** when product not in driver's load — allows drivers to sell warehouse-only items without errors.
- **close_driver_load auth flexibility** — both driver (own load) and admin/owner can close. Correct for field operations.
- **add_to_driver_load upsert** — handles both new items and quantity increase on existing items.
- **Driver stock screen design** — loaded/sold/remaining columns with color coding. Clean UX.
- **6th tab insertion at index 1** — stock view after Orders is the correct position for driver workflow.

## 3. Enterprise Gaps Identified

### G-1: cancel_order does NOT reverse driver_load_items.quantity_sold (CRITICAL)
Plan 11-02 introduces quantity_sold tracking in Step 6 of create_order_atomic. If an order is then cancelled via cancel_order (migration 018), quantity_sold remains inflated. Shift close will show incorrect "sold" numbers, and returned quantity validation will be wrong.

### G-2: close_driver_load has no business_id for stock_movements INSERT
The RPC takes only p_load_id and p_returns. stock_movements requires a business_id column. The plan doesn't specify where to get it from. Must SELECT business_id FROM driver_loads at load validation step.

### G-3: close_driver_load SET quantity_returned = quantity_returned (self-assignment typo)
The plan says `SET quantity_returned = quantity_returned` which is a no-op. Should be `SET quantity_returned = v_returned` (the value from the input JSONB).

### G-4: No returned quantity validation
The plan allows any quantity_returned value. Should validate: 0 <= quantity_returned <= (quantity_loaded - quantity_sold). Returning more than physically possible indicates a data error.

### G-5: cancel_order doesn't restore stock_on_hand (pre-existing gap)
restore_stock_for_cancellation RPC exists (migration 013) but cancel_order (migration 018) never calls it. While pre-existing, this should be fixed in the same migration since we're already modifying cancel_order.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | cancel_order must reverse driver_load_items.quantity_sold + restore stock_on_hand | Task 1 action | Added full cancel_order modification with quantity_sold reversal, stock restoration, and stock_movements logging. Uses GREATEST(..., 0) to prevent negative values. |
| 2 | close_driver_load needs business_id + returned qty validation + typo fix | Task 1 action | Added business_id fetch in load validation step, returned quantity range validation, fixed self-assignment to use v_returned variable. |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | add_to_driver_load needs business_id fetch | Task 1 action | Added business_id fetch note to load validation step. |
| 2 | Verification checklist gaps | Verification section | Added cancel_order check and close_driver_load validation check. |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Idempotency guard on close_driver_load | Closing a load is a one-time operation by admin/owner. Partial unique index already prevents re-opening. Risk is low. |
| 2 | Quantity cap on driver_load_items (quantity_sold <= quantity_loaded) | CHECK constraint would be ideal but current flow already validates at UI level and GREATEST prevents negatives. |

## 5. Audit & Compliance Readiness

**Audit Evidence:** Strong after fixes. The full lifecycle is now traceable: load creation → stock_movements(load_out) → order creation → quantity_sold incremented → cancellation → quantity_sold reversed + stock restored → shift close → stock_movements(load_return). Every state change has a corresponding audit trail entry.

**Silent Failure Prevention:** The cancel_order fix (G-1) was the primary silent failure risk — without it, driver stock reconciliation would silently drift from reality after cancellations. Now explicit.

**Post-Incident Reconstruction:** Given a disputed driver stock count at shift close, an auditor can: query stock_movements for the load_id (load_out on creation, load_return on close), cross-reference with order_lines (quantity_sold tracking), and verify the full chain.

## 6. Final Release Bar

**What must be true before this ships:**
- cancel_order reverses driver_load_items.quantity_sold ✓ (applied)
- close_driver_load validates returned quantities ✓ (applied)
- All RPCs use correct business_id source ✓ (applied)

**Remaining risks:**
- No idempotency on close_driver_load — acceptable for admin-controlled operation
- 6-tab driver shell may feel dense — functional but could be revisited in future UX pass

**Sign-off:** I would approve this plan for production after the applied fixes.

---

**Summary:** Applied 2 must-have + 2 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
