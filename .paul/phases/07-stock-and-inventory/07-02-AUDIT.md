# Enterprise Plan Audit Report

**Plan:** .paul/phases/07-stock-and-inventory/07-02-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable → Accepted after applying 1 must-have + 1 strongly-recommended upgrades

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **accepted** after applying findings.

This is a well-scoped final plan for the v0.2 milestone. The architecture is sound — Dart-side filtering for low stock queries (pragmatic for <100 products), dedicated RPC for adjustments (follows established pattern), and clear separation between dashboard alerts, adjustment screen, and history view. The two-task split is clean: Task 1 for data + dashboard, Task 2 for new screens.

The original plan had one critical gap: no input validation on the adjust_stock RPC or UI, meaning zero-quantity adjustments would create meaningless records and negative stock results could silently occur. Both addressed.

## 2. What Is Solid

- **Dart-side filtering for low stock**: PostgREST cannot do column-to-column comparison (`stock_on_hand <= low_stock_threshold`). Fetching products with threshold > 0 and filtering in Dart is pragmatic and correct for the data scale (<100 products). No RPC needed.
- **adjust_stock RPC follows established pattern**: Auth check, business_id verification, SECURITY DEFINER — consistent with deduct/replenish/restore from 07-01.
- **Movement history with type-based icons**: Clear visual language (red arrow for orders out, green arrow for purchases in, orange tune for adjustments). Well-specified.
- **Product form as navigation hub**: Accessing adjustment and history from the product form (edit mode) is intuitive. The owner is already looking at a specific product.
- **Boundaries are precise**: Correctly protects 07-01 work, limits scope to owner-only, defers batch operations and export.

## 3. Enterprise Gaps Identified

### Gap 1: Zero Quantity Adjustment (Data Quality)
The adjust_stock RPC accepts p_quantity = 0, which would create a stock_movement record (quantity=0, type='adjustment') without changing stock_on_hand. This is a data quality issue — meaningless records pollute the movement history. Prior audit (04-03) flagged the identical pattern for balance adjustments ("zero-amount rejection").

### Gap 2: No Negative Stock Prevention on Adjustments
The user explicitly requested in 07-01 checkpoint: "the stock in the database should be real data and can't go over it." The adjustment screen allows entering any negative quantity without validating the result. An adjustment of -999 on a product with stock_on_hand=5 would result in stock_on_hand=-994. The UI should display projected result and block if negative.

### Gap 3: flutter gen-l10n Not Explicit
Same finding as audits 06-01, 07-01. L10n strings mentioned in each task but gen-l10n not called out as a numbered step.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | adjust_stock RPC zero rejection + UI negative stock prevention — RPC must reject p_quantity=0, adjustment screen must validate (current+quantity)>=0 with projected result display | Task 1 action (RPC section) + Task 2 action (adjustment screen) + Task 1 verify | Added zero rejection to RPC, added projected result display with negative check to adjustment screen, added verify line |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | flutter gen-l10n as explicit numbered step — previous audits (06-01, 07-01) flagged this pattern | Task 1 action (new step 7) + Task 2 action (new step 7) | Added explicit "Run flutter gen-l10n" step in both tasks |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | stock_movements FK name verification — PostgREST join syntax depends on auto-generated FK name, may need runtime verification | Safe to defer: implementer will verify FK name during APPLY; if name differs, adjust join syntax on the spot |

## 5. Audit & Compliance Readiness

**Audit Trail:** Strong. Adjustments logged with created_by (auth.uid()), quantity, reason (notes), and timestamp. Movement history screen makes these records accessible.

**Data Quality:** Addressed. Zero-quantity rejection prevents pointless movement records. Negative stock prevention maintains data integrity.

**Authorization:** Correct. adjust_stock RPC verifies auth + business_id. Stock adjustment is owner-only (not exposed to admin or driver shells).

**Accountability:** Strong. Every stock change has attribution (created_by) and reason (notes field required on adjustment form).

## 6. Final Release Bar

**What must be true before this plan ships:**
- adjust_stock RPC rejects p_quantity = 0
- Adjustment screen shows projected result and blocks negative outcomes
- Dashboard Low Stock Alerts section shows products below threshold
- Movement history shows all 4 movement types with correct icons
- flutter gen-l10n runs successfully

**Remaining risks if shipped as-is (with applied fixes):**
- Movement history FK join name is assumed (verifiable during APPLY)
- No stock reconciliation tool (acceptable — adjustment screen covers manual corrections)

**Sign-off:** With the applied upgrades, this plan meets enterprise standards. The zero-quantity and negative-stock validations are the key additions — both prevent silent data quality issues.

---

**Summary:** Applied 1 must-have + 1 strongly-recommended upgrades. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
