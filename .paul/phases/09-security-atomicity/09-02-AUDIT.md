# Enterprise Plan Audit Report

**Plan:** .paul/phases/09-security-atomicity/09-02-PLAN.md
**Audited:** 2026-03-23
**Verdict:** Conditionally acceptable → **enterprise-ready after applied upgrades**

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to enterprise-ready after applying 2 must-have + 3 strongly-recommended fixes.

The plan's architecture is sound. Consolidating 5 separate database operations into a single atomic PostgreSQL RPC is the correct fix — it eliminates the primary data integrity risk in the application. The deactivation enforcement via `get_user_role()` is an elegant one-line-change-propagates-everywhere solution. The version check is straightforward and appropriate.

The gaps were: (1) missing idempotency guard on the most critical RPC in the system, and (2) missing cross-business validation in a SECURITY DEFINER function that bypasses RLS. Both are now addressed.

I would sign off on this plan after the applied upgrades.

## 2. What Is Solid

1. **Single-RPC atomic transaction** — Correct architecture. PostgreSQL's transactional guarantee means all 5 steps succeed or none persist. This is exactly how order creation should have been built from the start.

2. **auth.uid() for driver_id** — Eliminates client-side identity spoofing. The server derives the actor from the JWT, not from a client parameter. This is a security pattern worth carrying forward.

3. **get_user_role() returning NULL for inactive users** — One function change propagates to every RLS policy in the system. No need to audit dozens of policies individually. The fallthrough for NULL (user not in table yet) correctly handles the init edge case.

4. **Preserving existing RPCs** — The plan correctly identifies that `update_store_balance_on_order`, `create_package_log`, and `deduct_stock_for_order` are still used by other flows (cancellation, standalone package collection, purchase replenishment). Not dropping them avoids breaking working code.

5. **Boundaries section** — Well-scoped. Explicitly protects existing migrations, discount/cancellation flows, and defers test coverage to 09-03. The scope limits are realistic and defensible.

6. **Force-update routing architecture** — Using `GoRouter.redirect` with a `forceUpdate` flag is the correct pattern. It prevents any route from being accessed while the update is required, without requiring changes to individual screens.

## 3. Enterprise Gaps Identified

### Gap A: No idempotency guard on create_order_atomic (MUST-HAVE)
The existing `deduct_stock_for_order` RPC has an idempotency guard checking `stock_movements` for duplicate `reference_id`. The new atomic RPC — which is the single most critical transaction in the system — had no such protection. On mobile networks (the primary deployment environment: field drivers on cellular), network timeouts are common. A timeout after the server commits but before the client receives the response would lead to duplicate orders on retry. For a financial system tracking credit balances, this is unacceptable.

### Gap B: No cross-business store validation (MUST-HAVE)
The RPC is `SECURITY DEFINER`, meaning it bypasses all RLS policies. It validates `p_business_id = get_user_business_id()` but does not validate that the target store belongs to that business. A driver could theoretically create an order against a store from a different business. While the FK constraint on `store_id` ensures the store exists, it does not ensure business ownership. This is a data isolation failure.

### Gap C: No discount_status input validation (STRONGLY RECOMMENDED)
The RPC accepts `p_discount_status TEXT` directly from the client with no validation. Only `'none'` and `'pending'` are valid at order creation time (`'approved'` and `'rejected'` are set by other RPCs later). A malformed client could write arbitrary values, corrupting the discount workflow state machine.

### Gap D: Deactivated user gets cryptic errors (STRONGLY RECOMMENDED)
When `get_user_role()` returns NULL for an inactive user, every RLS policy denies access. The driver's UI will show generic `PostgrestException` errors. The driver has no way to know their account was deactivated vs. experiencing a server error. For a field worker who may have just been deactivated mid-shift, this is a poor experience that will generate support calls.

### Gap E: Force-update download URL not actionable (STRONGLY RECOMMENDED)
The plan specified "a text showing the download URL" but did not specify `SelectableText` or any copy/tap mechanism. On a mobile device, a non-selectable URL is useless. The existing settings screen already uses `SelectableText` for the same purpose — consistency requires the same treatment here.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Idempotency guard missing — duplicate orders on network retry | Task 1 action (PART 1 parameters + idempotency step), Task 2 action (client-generated UUID), AC-5 added | Added `p_order_id UUID DEFAULT NULL` parameter, idempotency check before insert, client-side UUID generation in Dart |
| 2 | Cross-business store validation missing — SECURITY DEFINER bypasses RLS | Task 1 action (store-business validation step), AC-6 added | Added `SELECT 1 FROM stores WHERE id = p_store_id AND business_id = p_business_id` check with RAISE EXCEPTION |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Discount status not validated — arbitrary values accepted | Task 1 action (discount status validation) | Added `IF p_discount_status NOT IN ('none', 'pending') THEN RAISE EXCEPTION` |
| 2 | Deactivated user sees cryptic errors | Task 2 action (deactivated user error handling), Task 2 verify | Added guidance to detect permission-denied errors, show Arabic deactivation message, and sign out |
| 3 | Force-update download URL not selectable | Task 3 action (SelectableText for URL) | Added `SelectableText` specification matching existing settings pattern |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Version check bypassed when network is down at startup | Blocking on network failure is worse — prevents all app usage when offline. Risk is acceptable for <10 drivers with owner-distributed APKs. |
| 2 | get_user_role() performance impact (users table lookup on every RLS eval) | Users table has <20 rows, query is on PRIMARY KEY. Negligible at current scale. Document if scaling. |
| 3 | Migration deployment tracking | Migrations 015, 016, 017 all need deployment. This is an ops concern, not a code plan concern. The migration file includes a deployment comment. |

## 5. Audit & Compliance Readiness

**Audit evidence:** The atomic RPC produces a single transaction — either all records exist or none do. This creates a clean audit trail: every order has complete lines, correct balance update, package logs, and stock movements. No more "orphaned order without balance update" state.

**Silent failure prevention:** The idempotency guard (audit-added) prevents the most dangerous silent failure: duplicate orders creating phantom debt on store balances. The discount status validation prevents silent state corruption.

**Post-incident reconstruction:** If a balance discrepancy is reported, investigators can query orders → order_lines → stock_movements → package_logs and find a complete, consistent chain for every order. Before this plan, the chain could be broken at any of the 5 steps.

**Ownership and accountability:** `driver_id = auth.uid()` (server-derived) means the actor identity is unforgeable. Combined with Plan 09-01's JWT metadata protection trigger, the audit trail is cryptographically bound to the authenticated user.

**Deactivation enforcement:** An owner can immediately cut off a compromised or terminated driver. The effect is global (all RLS policies) and immediate (next API call fails). This is a basic access control requirement that was missing.

## 6. Final Release Bar

**What must be true before this plan ships:**
- The atomic RPC must include all 5 operations in one transaction (no partial state)
- Idempotency guard must prevent duplicate orders on retry
- Store-business validation must prevent cross-business data writes
- get_user_role() must return NULL for inactive users
- Force-update screen must block all navigation when min_version exceeds current

**Remaining risks if shipped as-is (after upgrades):**
- Migrations 015, 016, 017 all need deployment to live Supabase (ops, not code)
- No automated test coverage yet (Plan 09-03 addresses this)
- Version check can be bypassed if Supabase is unreachable at startup (acceptable risk)

**Sign-off:** After the applied upgrades, I would sign my name to this plan. The architecture is correct, the security model is sound, and the remaining risks are documented and scheduled for resolution.

---

**Summary:** Applied 2 must-have + 3 strongly-recommended upgrades. Deferred 3 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
