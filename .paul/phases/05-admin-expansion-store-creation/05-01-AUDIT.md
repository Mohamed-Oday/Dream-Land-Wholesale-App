# Enterprise Plan Audit Report

**Plan:** phases/05-admin-expansion-store-creation/05-01-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally Acceptable (now enterprise-ready after applying fixes)

---

## 1. Executive Verdict

**Conditionally acceptable** — upgraded to enterprise-ready after applying 1 must-have and 3 strongly-recommended fixes.

The plan is well-scoped: single-concern (admin visibility), minimal file changes, reuses existing providers/RLS. The admin dashboard-lite design is a sound business decision — it gives operational visibility without exposing sensitive financial controls (discount approval, revenue totals).

The main risk was a compile-blocking reference to a non-existent screen (`OrderDetailScreen`). After fix, the plan is production-safe.

Would I sign off on this? **Yes**, after the applied fixes.

## 2. What Is Solid

- **RLS pre-validation:** The plan verifies admin has SELECT policies on all required tables before writing code. No runtime auth surprises.
- **SECURITY DEFINER awareness:** Correctly identifies that dashboard RPCs bypass RLS, meaning no migration is needed for admin data access.
- **Scope discipline:** Admin dashboard is intentionally NOT the owner dashboard. No revenue KPIs, no discount approval, no approve/reject. This prevents scope creep into authorization concerns.
- **Existing provider reuse:** `topDebtorsProvider` and `packageAlertsProvider` are reused, not duplicated. Single source of truth.
- **Boundaries section:** Explicitly protects owner_shell, driver_shell, and existing migrations. Clear scope limits prevent drift.
- **Visual consistency:** Task specifies following exact owner dashboard patterns (section headers, card styling, dividers, CircleAvatar). Admin and owner dashboards will look like the same app.

## 3. Enterprise Gaps Identified

### Gap 1: Non-existent screen reference (compile-blocking)
Plan references `OrderDetailScreen(orderId)` for order tap navigation. This class does not exist in the codebase. The order detail view is `ReceiptPreviewScreen(orderId: order['id'])`, used in `order_list_screen.dart` line 102. Would cause immediate compile failure.

### Gap 2: Incomplete join pattern
Plan's `getRecentOrders()` uses `stores(name)` but the established pattern in `OrderRepository.getAll()` is `stores(name, address)`. Missing `address` field breaks consistency and may cause issues if the order display widgets expect the address field.

### Gap 3: Missing order status indicator
Plan specifies "store name, driver name, total, timestamp" for order items but omits order status (created/delivered/cancelled). The existing `OrderListScreen` prominently shows status via `_StatusChip`. Admin needs status context to understand operational state at a glance.

### Gap 4: RefreshIndicator async completion
Plan says "invalidate providers" on refresh, but `ref.invalidate()` is synchronous. RefreshIndicator's `onRefresh` callback must return a Future that completes when data is ready. Without awaiting, the pull-to-refresh animation dismisses immediately (< 100ms), providing no visual feedback to the user.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | `OrderDetailScreen` does not exist | AC-1, Task 1 action, checkpoint | Changed to `ReceiptPreviewScreen(orderId: order['id'])` |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Join pattern missing `address` field | Task 1 Step 1 (getRecentOrders query) | Changed `stores(name)` to `stores(name, address)` to match OrderRepository pattern |
| 2 | Missing order status in dashboard items | AC-1, Task 1 action (Recent Orders section), checkpoint | Added status indicator requirement to order items |
| 3 | RefreshIndicator async completion | Task 1 action (RefreshIndicator setup) | Added `await ref.read(recentOrdersProvider.future)` after invalidation |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Shared widget extraction (section header, empty state, shimmer) between Owner and Admin dashboards | Both dashboards use identical visual patterns. Extracting shared widgets would reduce duplication. However, the screens are separate concerns with different data — duplicating ~30 lines of helper widgets is acceptable for now. Can extract when a third dashboard consumer appears. |

## 5. Audit & Compliance Readiness

**Audit evidence:** The plan produces a new screen with read-only data access. All data flows through existing RLS-protected Supabase queries. No write operations, no state mutations (except packageAlertThreshold which is local/session state). Audit trail is inherited from existing infrastructure.

**Silent failure prevention:** Error states specified for all 3 sections (error display with retry button following owner dashboard pattern). Loading states specified (shimmer placeholders).

**Post-incident reconstruction:** Recent orders query is a simple SELECT with ORDER BY/LIMIT — deterministic and reproducible. No side effects.

**Ownership:** AdminDashboardScreen is a standalone ConsumerWidget. Clear single file ownership. No cross-cutting concerns.

## 6. Final Release Bar

**What must be true before shipping:**
- `ReceiptPreviewScreen` navigation compiles and navigates correctly from admin dashboard
- Order status indicators render for all 3 states (created, delivered, cancelled)
- RefreshIndicator completes animation properly (not instant dismissal)
- All 3 dashboard sections load data for admin role without RLS errors

**Remaining risks if shipped as-is (after fixes):**
- Low: Admin and owner dashboards share providers — if admin triggers `ref.invalidate(topDebtorsProvider)`, it also invalidates for owner if both are logged in simultaneously on the same device. This is a non-issue for single-device usage.

**Sign-off:** I would approve this plan for production after the applied fixes.

---

**Summary:** Applied 1 must-have + 3 strongly-recommended upgrades. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
