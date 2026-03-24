# Enterprise Plan Audit Report

**Plan:** .paul/phases/11-driver-stock-loading/11-01-PLAN.md
**Audited:** 2026-03-24
**Verdict:** Conditionally acceptable → Acceptable after auto-applied fixes

---

## 1. Executive Verdict

**Conditionally acceptable**, elevated to **acceptable** after applying 2 must-have and 4 strongly-recommended fixes.

The plan demonstrates solid architectural thinking: atomic RPC pattern, partial unique index for one-active-load guard, SECURITY DEFINER with RLS, and clear separation of Plan 01 (load creation) from Plan 02 (shift close + order integration). The core data model is sound.

However, source-level verification revealed two release-blocking gaps: the stock_movements CHECK constraint would cause runtime failures, and the driver_load_items RLS was specified as "same via join" which is not how Supabase RLS works. Both are now fixed.

I would sign this plan after the applied fixes.

## 2. What Is Solid

- **Partial unique index** (`WHERE status = 'active'`) for one-active-load enforcement — database-level guarantee, not application-level check. Correct.
- **SECURITY DEFINER RPC** for all mutations — prevents direct table manipulation. Follows established project pattern.
- **Stock movement logging** — maintains full audit trail of warehouse-to-driver transfers. Consistent with existing order_out/purchase_in pattern.
- **Plan scope discipline** — cleanly separates load creation (11-01) from shift close + order integration (11-02). Avoids over-scoping.
- **ON DELETE CASCADE** on driver_load_items FK — appropriate for child records.
- **UNIQUE(load_id, product_id)** — prevents duplicate product entries per load. Correct constraint.
- **Navigator.push for sub-screens** — follows established routing decision. No GoRouter changes needed.

## 3. Enterprise Gaps Identified

### G-1: stock_movements CHECK constraint blocks 'load_out' inserts (CRITICAL)
Migration 013 defines: `CHECK (movement_type IN ('order_out', 'purchase_in', 'cancellation_restore', 'adjustment'))`. The plan's RPC inserts `'load_out'` records. Without ALTERing the CHECK first, every load creation will fail with a constraint violation. The plan mentioned this as a conditional "NOTE: If ... has a CHECK" — it's not conditional, the constraint exists.

### G-2: driver_load_items RLS cannot cascade through FK joins
Supabase RLS evaluates per-table. The plan said "SELECT: same as driver_loads (join through load_id → driver_loads)" which is not how Postgres RLS works. Without explicit policies, PostgREST direct queries on driver_load_items would return empty results (or all rows if no policy exists with ENABLE RLS).

### G-3: No FOR UPDATE row lock on product stock check
The create_order_atomic RPC uses `FOR UPDATE` when checking stock_on_hand to prevent race conditions. Without it, two concurrent load creations could both pass the `stock_on_hand >= quantity` check and over-deduct below zero.

### G-4: No driver validation in RPC
The RPC accepts any UUID as `p_driver_id` without verifying the user exists, has role='driver', and belongs to the same business. In a multi-admin scenario, typos or stale UUIDs could create orphaned loads.

### G-5: No empty items guard
If `p_items` is NULL or `[]`, the RPC would create a driver_loads record with no items — an empty load with no stock movements. Logically invalid state.

### G-6: REVOKE pattern incomplete
Existing migration 018 uses `REVOKE EXECUTE ... FROM PUBLIC` before granting to authenticated. The plan only specified `REVOKE from anon`, leaving the PUBLIC role (which includes all Supabase roles) with implicit access.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | stock_movements CHECK constraint blocks 'load_out' | Task 1 action (top) | Added explicit ALTER TABLE to drop and recreate CHECK with 'load_out' + 'load_return'. Removed conditional "NOTE" wording. Added to verify section. |
| 2 | driver_load_items RLS needs explicit per-table policies | Task 1 RLS section | Replaced "same as driver_loads via join" with explicit EXISTS subquery policies for owner/admin and driver roles. |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | FOR UPDATE row lock on product stock check | Task 1 RPC action | Added `FOR UPDATE` to product stock SELECT, matching create_order_atomic pattern. |
| 2 | Driver validation (role + business) | Task 1 RPC action | Added driver existence check: `SELECT 1 FROM users WHERE id = p_driver_id AND role = 'driver' AND business_id = p_business_id`. |
| 3 | Empty items guard | Task 1 RPC action | Added NULL/empty array check with RAISE EXCEPTION before processing. |
| 4 | REVOKE FROM PUBLIC pattern | Task 1 grants section | Added `REVOKE EXECUTE FROM PUBLIC` on both RPCs before GRANT to authenticated. |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Idempotency guard (client-provided load UUID) | Loads are created by admin/owner in controlled environment, not by drivers in the field with flaky connectivity. Risk of accidental double-creation is low. Can add if field evidence shows need. |
| 2 | business_id column on driver_load_items | EXISTS subquery RLS is functionally correct. Direct column would improve query performance but at <10 drivers with <50 loads, this is premature optimization. |
| 3 | Dedicated load detail RPC | getLoadDetail() via direct SELECT + RLS is adequate. RPC would add consistency but no functional gap. |

## 5. Audit & Compliance Readiness

**Audit Evidence:** Strong. Every load creation produces: driver_loads record (who loaded, when, which driver), driver_load_items (what products, how many), and stock_movements (load_out entries with reference_id = load_id). Full chain from warehouse deduction to driver allocation is traceable.

**Silent Failure Prevention:** The CHECK constraint fix (G-1) was the main silent failure risk — without it, the RPC would throw a Postgres error that Dart-side error parsing might not match, leading to generic "something went wrong" UX. Now explicit.

**Post-Incident Reconstruction:** Given a disputed stock count, an auditor can: query stock_movements WHERE movement_type = 'load_out' AND reference_id = load_id, cross-reference with driver_load_items, and verify quantities match. The loaded_by column identifies who authorized the transfer.

**Ownership:** Clear — loaded_by defaults to auth.uid() (non-spoofable via SECURITY DEFINER). The partial unique index prevents creating a second active load to "reset" stock counts.

## 6. Final Release Bar

**What must be true before this ships:**
- All 2 must-have fixes applied (CHECK constraint ALTER, explicit RLS) ✓
- All 4 strongly-recommended fixes applied (FOR UPDATE, driver validation, empty guard, REVOKE pattern) ✓
- Migration deploys successfully to Supabase before Flutter code tests

**Remaining risks if shipped as-is (after fixes):**
- No idempotency — acceptable for admin-initiated operations
- No soft-delete on loads — loads can only be 'active' or 'closed', not 'cancelled'. If a load is created by mistake, there's no undo. Mitigated by: this is a small-scale operation (<10 drivers) where the admin is physically present.

**Sign-off:** I would approve this plan for production after the applied fixes. The data model is clean, the RPC is properly guarded, and the audit trail is complete.

---

**Summary:** Applied 2 must-have + 4 strongly-recommended upgrades. Deferred 3 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
