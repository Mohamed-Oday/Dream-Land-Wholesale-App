# Enterprise Plan Audit Report

**Plan:** .paul/phases/09-security-atomicity/09-01-PLAN.md
**Audited:** 2026-03-23
**Verdict:** Conditionally acceptable → Enterprise-ready after applied fixes

---

## 1. Executive Verdict

**Conditionally acceptable → Enterprise-ready after 2 must-have + 2 strongly-recommended upgrades applied.**

This is the most security-critical plan in the remediation roadmap. The original plan had solid architecture (trigger-based metadata protection, silent revert instead of RAISE EXCEPTION, correct RLS redesign). However, two mutation functions were missing from the hardening list: `reject_expired_discounts` (modifies order totals and store balances — omitted from the original 5) and `update_store_balance_on_order` (has ZERO auth checks — the single most dangerous function in the codebase, confirmed by both AEGIS F-04-012 and F-02-009). The trigger function also needed its direct execute privilege revoked.

After applied fixes, I would sign my name to this plan.

## 2. What Is Solid

- **Trigger design (Task 1):** The silent-revert approach is superior to RAISE EXCEPTION. It prevents breaking legitimate updateUser calls while protecting critical fields. The NULL-check allows initial signUp to set fields freely. This is the correct design.
- **Role check placement:** Checks are at the top of each function body, before any data access. This is correct — fail fast, before locking any rows.
- **cancel_order driver ownership check:** Allows drivers to cancel their own orders but not others'. This matches the business model where a driver might need to correct a mistake at a store.
- **balance_adjustments RLS redesign:** Drop-and-recreate with explicit role policies is cleaner than patching. Append-only (no UPDATE/DELETE) is the correct pattern for audit tables.
- **Boundaries:** Correctly scopes to SQL-only. Dart changes are deferred to 09-02.

## 3. Enterprise Gaps Identified

1. **reject_expired_discounts missing from hardening list (must-have):** This SECURITY DEFINER function modifies order totals AND store credit balances. It was flagged in F-05-003. A driver calling this could trigger mass discount rejections affecting all pending orders in the business. Must have a role check.

2. **update_store_balance_on_order has ZERO auth (must-have):** This function has no auth.uid() check, no business_id check, no role check, and no explicit GRANT (defaults to PUBLIC). It's the most dangerous unprotected endpoint. While 09-02 will replace it with the atomic order RPC, leaving it wide open during the gap between 09-01 deployment and 09-02 deployment is unacceptable. A minimum auth guard is needed.

3. **protect_user_metadata() directly callable (strongly-recommended):** The trigger function defaults to PUBLIC execute permission. While calling it directly has no effect (it's designed as a trigger), revoking direct execution is defense-in-depth.

4. **Migration deployment step missing (strongly-recommended):** Consistent with 08-01 audit pattern — the file must be deployed to the live database.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | `reject_expired_discounts` missing role check | Task 2 action | Added as function #6 — requires owner/admin role |
| 2 | `update_store_balance_on_order` has zero auth | Task 2 action | Added as function #7 — minimum auth.uid() guard as stopgap until 09-02 |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | protect_user_metadata() directly callable | Task 3 action | Added REVOKE EXECUTE FROM PUBLIC on trigger function |
| 2 | Migration deployment step | Task 3 action | Added deploy step with driver-role verification test |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | SQL tests for trigger and role checks | Plan 09-03 scope — dedicated test plan |
| 2 | Admin INSERT policy on balance_adjustments | RPC uses SECURITY DEFINER (bypasses RLS), so direct INSERT is not the entry point |

## 5. Audit & Compliance Readiness

- **Audit evidence:** Migration file will document all security changes with AEGIS finding references. Good traceability.
- **Silent failure prevention:** Role checks use RAISE EXCEPTION for unauthorized access — these produce visible PostgREST errors to the caller. Good.
- **Post-incident reconstruction:** If a security incident occurs, the migration file documents exactly when each control was added.
- **Ownership:** All changes in one migration file with clear section headers. Good audit trail.
- **Concern:** No automated test validates the trigger works until 09-03. Manual deployment verification is the interim control.

## 6. Final Release Bar

**What must be true:**
- All 7 SECURITY DEFINER functions have role/auth checks
- JWT metadata trigger deployed and active on auth.users
- balance_adjustments is append-only with role-based SELECT
- protect_user_metadata() not directly callable

**Remaining risks if shipped as-is:**
- No automated test validates the trigger (09-03 will add this)
- `update_store_balance_on_order` still exists (replaced in 09-02) — stopgap auth check reduces but doesn't eliminate risk
- `deduct_stock_for_order`, `replenish_stock_from_purchase`, `restore_stock_for_cancellation` have no role checks — these are correctly excluded because drivers need them for order flows

**Sign-off:** I would sign my name to this plan after the applied upgrades.

---

**Summary:** Applied 2 must-have + 2 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
