# Enterprise Plan Audit Report

**Plan:** .paul/phases/07-stock-and-inventory/07-01-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable → Accepted after applying 2 must-have + 2 strongly-recommended upgrades

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **accepted** after applying findings.

The plan demonstrates a sound architecture: explicit RPC-based stock mutations with an append-only audit trail, denormalized `stock_on_hand` for fast reads, and deliberate non-blocking of order creation. The two-plan split (data model + automation now, alerts + manual management later) is well-scoped.

However, the original plan had two critical gaps: (a) no idempotency guards on stock RPCs, meaning network retries could silently corrupt inventory counts, and (b) no business_id authorization on RPCs, meaning any authenticated user could manipulate any business's stock. Both have been addressed.

I would approve this plan for production after the applied fixes.

## 2. What Is Solid

- **Denormalized stock_on_hand + stock_movements audit trail**: Correct dual approach. Fast reads from the column, full reconstructibility from the movement log. The column is the cache; the movements are truth.
- **Explicit RPC calls over triggers**: Triggers are notoriously hard to debug in Supabase. RPC calls are visible in Dart code, testable, and follow the project's established pattern (cancel_order, approve_discount, etc.).
- **Non-blocking stock deduction**: The plan correctly treats orders as the primary business event. Stock deduction is best-effort with try/catch. This matches the business reality — a bread delivery driver should never be blocked from recording a sale because of a stock tracking failure.
- **Boundaries are precise**: Dashboard changes deferred to 07-02, no Drift table changes, no product form changes. The scope is tight.
- **Movement type enum via CHECK constraint**: Prevents invalid data at the database level. The 4 types (order_out, purchase_in, cancellation_restore, adjustment) cover all expected flows.

## 3. Enterprise Gaps Identified

### Gap 1: No Idempotency on Stock RPCs (CRITICAL)
All three RPCs (deduct, replenish, restore) blindly process the request without checking if it was already processed. If `deduct_stock_for_order('abc')` is called twice for the same order (network timeout → Dart retry), stock_on_hand would be double-deducted, and two sets of stock_movement records would be created. This corruption is **silent** — no error, no exception, just wrong numbers.

### Gap 2: No Business-ID Authorization on RPCs (CRITICAL)
The RPCs check `auth.uid() IS NOT NULL` but not whether the referenced order/PO belongs to the caller's business. Compare with the existing `cancel_order` RPC which explicitly verifies `p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID`. Without this check, any authenticated user from any business could call `deduct_stock_for_order` with another business's order_id.

### Gap 3: Driver Direct INSERT on stock_movements
The original plan gave drivers INSERT access to stock_movements via RLS. Since all stock mutations go through SECURITY DEFINER RPCs (which bypass RLS), this policy only affects direct PostgREST access. A malicious or buggy client could craft a direct INSERT to `stock_movements`, injecting phantom movements.

### Gap 4: flutter gen-l10n Not Explicit
L10n strings added to .arb files but gen-l10n command only mentioned in verify, not as an action step. Previous audit (06-01) flagged this same pattern. Without running gen-l10n, the Dart localization classes won't include the new strings, causing compile errors.

### Gap 5: Non-atomic cancel + restore (Accepted Risk)
Stock restoration after order cancellation is a separate RPC call from Dart. If cancel_order succeeds but restore_stock fails, stock_on_hand remains depleted for a cancelled order. This is mitigated by: (a) try/catch pattern, (b) adjustment screen in 07-02 for reconciliation, (c) cancel is low-volume owner-only operation.

### Gap 6: No stock reconciliation mechanism
No way to detect if stock_on_hand has drifted from SUM(stock_movements.quantity). Natural fit for 07-02's adjustment screen.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | RPC idempotency guard — all 3 stock RPCs must check for existing stock_movements with matching reference_id + movement_type before processing, preventing double-deduction/restoration on network retry | Task 1 action (RPCs 4, 5, 6) + Task 1 verify | Added idempotency guard to each RPC: IF EXISTS check + early RETURN. Added verify line confirming idempotency guards present. |
| 2 | RPC business_id authorization — all 3 stock RPCs must verify the order/PO belongs to the caller's business via JWT metadata, matching the cancel_order pattern | Task 1 action (RPCs 4, 5, 6) + Task 1 verify | Added business_id verification against auth.jwt() -> 'user_metadata' ->> 'business_id' to each RPC. Added verify line confirming auth checks present. |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Driver stock_movements INSERT policy removed — drivers should only affect stock via SECURITY DEFINER RPCs, not direct table INSERT which allows stock manipulation outside order flow | Task 1 action (RLS section 3) + Task 1 verify | Changed driver policy from INSERT to SELECT-only. Updated verify to confirm driver is SELECT-only. |
| 2 | flutter gen-l10n as explicit action step — previous audit (06-01) flagged this pattern; without running gen-l10n, new l10n strings don't generate Dart classes | Task 2 action (new section 8) | Added explicit "Run flutter gen-l10n" step in Task 2 action after l10n strings are added. |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Atomic stock restoration in cancel_order RPC — could CREATE OR REPLACE cancel_order in migration 013 to include stock restore atomically | Safe to defer: try/catch handles failures gracefully, adjustment screen in 07-02 reconciles discrepancies, cancel is owner-only low-volume operation |
| 2 | Stock reconciliation query — mechanism to detect drift between stock_on_hand and SUM(stock_movements) | Natural fit for 07-02's stock adjustment screen, which is the appropriate place for reconciliation tooling |

## 5. Audit & Compliance Readiness

**Audit Trail:** Strong. Every stock change produces a stock_movement record with movement_type, quantity, reference_id, created_by, and timestamp. The append-only movement log supports full post-incident reconstruction of how stock_on_hand reached its current value.

**Silent Failure Prevention:** Addressed after fixes. Idempotency guards prevent silent double-processing. Try/catch on Dart side means stock RPC failures are caught (not silent), though the order still proceeds. The non-blocking pattern is a deliberate business decision, not an oversight.

**Authorization:** Addressed after fixes. Business_id checks on all RPCs prevent cross-tenant stock manipulation. Driver SELECT-only on stock_movements prevents unauthorized stock injection.

**Ownership:** Clear. Stock changes are always attributed to a specific user (created_by on stock_movements). Order-driven movements use the driver_id; cancellation uses auth.uid() (the owner).

## 6. Final Release Bar

**What must be true before this plan ships:**
- All 3 RPCs have idempotency guards (check before processing)
- All 3 RPCs verify business_id ownership from JWT
- Driver RLS on stock_movements is SELECT-only
- flutter gen-l10n runs successfully after l10n string additions
- Checkpoint verifies full stock flow: purchase → order → cancel → movement log

**Remaining risks if shipped as-is (with applied fixes):**
- Non-atomic cancel + restore could leave stock in inconsistent state on rare failures (mitigated by 07-02 adjustment screen)
- No stock reconciliation tool yet (07-02 scope)
- Initial stock for existing products is 0 — owner must use adjustment screen (07-02) to set starting inventory

**Sign-off:** With the 4 applied upgrades, this plan meets enterprise standards for a small-scale operational tool. The idempotency and authorization gaps were the critical risks; both are now addressed.

---

**Summary:** Applied 2 must-have + 2 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
