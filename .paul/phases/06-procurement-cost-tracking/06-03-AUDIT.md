# Enterprise Plan Audit Report

**Plan:** phases/06-procurement-cost-tracking/06-03-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally Acceptable (now enterprise-ready after applying fixes)

---

## 1. Executive Verdict

**Conditionally acceptable** — upgraded to enterprise-ready after applying 1 must-have and 1 strongly-recommended fix.

Clean, focused plan. Two KPI cards and a margin badge — minimal scope, maximum business value. The profit calculation (revenue - purchases) is intentionally simple, which is correct for this stage.

Would I sign off? **Yes**, after the applied fixes.

## 2. What Is Solid

- **Derived profit provider:** `todayProfitProvider` watches both revenue and purchases providers — automatically recalculates when either changes. Clean reactive pattern.
- **Existing pattern reuse:** getTodayPurchases follows exact getTodayRevenue pattern. No new patterns introduced.
- **Admin dashboard untouched:** Correctly keeps admin dashboard as "lite" — only owner gets financial KPIs.
- **Scope discipline:** No margin history, no trends, no overhead calculations. Simple and correct for MVP.

## 3. Enterprise Gaps Identified

### Gap 1: Collection spread compile error (blocking)
Task 2's trailing widget code declares `final` variables inside a collection literal's `if` spread (`if (p['cost_price'] != null) ...[final sell = ...]`). Dart doesn't allow variable declarations inside collection spreads. This would fail to compile.

### Gap 2: KpiCard doesn't support value coloring
AC-2 requires profit value to be green (positive) or red (negative). KpiCard uses hardcoded `onSurface` color for values. Without modification, the profit KPI would show in default color regardless of sign.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | `final` in collection spread | Task 2 action | Moved margin calculation before widget tree; pre-computed `marginPct` and `margin` variables |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | KpiCard valueColor | Task 1 action, boundaries, files_modified | Added Step 2 to add optional `valueColor` param to KpiCard; profit card passes green/red based on value |

### Deferred (Can Safely Defer)

None.

## 5. Audit & Compliance Readiness

No compliance concerns — this plan adds read-only KPI display from existing data. No writes, no state mutations beyond UI.

## 6. Final Release Bar

**What must be true:** Margin calculations use correct arithmetic (sell - cost, not cost - sell). KpiCard valueColor is backwards-compatible (null defaults to existing color).

**Sign-off:** Approved after fixes.

---

**Summary:** Applied 1 must-have + 1 strongly-recommended upgrade. Deferred 0 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
