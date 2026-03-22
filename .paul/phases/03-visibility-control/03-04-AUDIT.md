# Enterprise Plan Audit Report

**Plan:** .paul/phases/03-visibility-control/03-04-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable → Accepted after applying 1 must-have + 3 strongly-recommended upgrades

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **accepted** after applying findings.

The plan is well-scoped as the final Phase 3 plan. The store detail screen correctly leverages existing repository methods. The user management screen with role-based capability (owner creates admin+driver, admin creates driver only) is correctly layered with RLS enforcement as the safety net. A few data integrity and error handling gaps were addressed.

## 2. What Is Solid

- **Reusable UserManagementScreen with isOwner flag:** Clean pattern — single screen, role-based behavior via parameter. Avoids code duplication.
- **RLS as enforcement backstop:** Admin RLS policy only allows INSERT with role='driver'. Even if a bug sends role='admin', the server blocks it. Defense in depth.
- **Store detail as scrolling sections (not tabs):** Correct for mobile — avoids nested scroll regions, simpler implementation, better for variable-height content.
- **Existing repository method reuse:** PaymentRepository.getByStore and PackageRepository.getBalancesByStore are already built. Only OrderRepository needs the new method.
- **Deactivation over deletion:** Preserves referential integrity for orders/payments/packages linked to the user.
- **5th tab for owner:** Material allows up to 5. Discoverable and consistent with admin's structure.

## 3. Enterprise Gaps Identified

### Gap 1: files_modified frontmatter incorrect
Frontmatter listed old filenames (driver_list_screen, driver_repository, driver_provider) but Task 2 creates different files (user_management_screen, user_repository, user_management_provider).

### Gap 2: Session restoration failure in createUser
If `setSession(refreshToken)` fails after creating the new auth user, the caller (owner/admin) is logged out and the app is in the new user's session. The UI would break because the role-based routing changes. No error handling specified.

### Gap 3: Package balances RPC returns product_id without product name
`get_package_balances_for_store` returns `(product_id, balance)` only. The StoreDetailScreen needs to display product names. Without a join, the UI would show UUIDs instead of names.

### Gap 4: Orphaned auth user on users table insert failure
If Auth signUp succeeds but users table INSERT fails (e.g., RLS blocks admin creating admin role, or network error), an auth account exists with no matching users table entry. The user can't log in meaningfully. The plan doesn't handle this case.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | files_modified frontmatter mismatch | Frontmatter | Updated filenames to match Task 2 actual files |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 2 | Session restoration failure | Task 2 action (createUser step 3) | Added: throw on setSession failure, don't proceed with orphaned auth state |
| 3 | Package balances missing product names | Task 1 action (Package Balances section) | Added: watch productListProvider to map product_id → name client-side |
| 4 | Orphaned auth user awareness | Task 2 action (createUser step 4) | Added: catch insert failure, show meaningful error about non-functional auth account |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 5 | Search/filter on user list | <10 users total. Linear scan is fine. Phase 4 if scale increases. |
| 6 | Per-driver/per-product detail screens | Explicitly deferred in scope. Owner has existing all-data screens. |

## 5. Audit & Compliance Readiness

**Access control:** RLS policies enforce role-based creation at the database level. Admin can only INSERT role='driver'. Owner has full access. This is correct defense in depth — UI controls what's shown, RLS controls what's allowed.

**Data integrity:** Deactivation preserves all linked records (orders, payments, packages). No cascade deletes. Deactivated users are excluded from GPS map (Plan 03-02 RPC filters active=true).

**Session security:** The session save/restore pattern during user creation is inherently risky (signUp changes the active session). The added error handling ensures failures don't leave the caller in a broken state.

## 6. Final Release Bar

**What must be true before this plan ships:**
- Frontmatter matches actual files
- Session restoration has error handling
- Package balances show product names (not UUIDs)
- Insert failure handled gracefully with user-facing message

**Remaining risks:**
- Orphaned auth users (if insert fails) — rare but not automatically cleaned up. Acceptable for MVP.
- No user editing — deactivate + create new is the workaround. Acceptable.

**Sign-off:** With the applied upgrades, I would approve this plan for production.

---

**Summary:** Applied 1 must-have + 3 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
