# Enterprise Plan Audit Report

**Plan:** .paul/phases/03-visibility-control/03-01-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable → Accepted after applying 2 must-have + 5 strongly-recommended upgrades

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **accepted** after applying findings.

The plan is well-structured with clear acceptance criteria, specific task actions, and appropriate scope boundaries. However, it contained two release-blocking issues that would have caused incorrect data display in production:

1. A migration filename collision that would fail deployment
2. A timezone error that would miscount evening activity

Both have been corrected. I would approve this plan for production after the applied fixes.

## 2. What Is Solid

- **Repository pattern consistency:** DashboardRepository follows the established SupabaseClient + businessId pattern used by all Phase 1-2 repositories. This is correct — no new architectural patterns introduced.
- **Boundaries section:** Comprehensive and correctly protects all Phase 1-2 stable subsystems. The "DO NOT CHANGE" list covers every feature that should remain untouched.
- **Scope limits:** Correctly defers real-time subscriptions, GPS, discount approval, and drill-downs to separate plans. No scope creep risk.
- **UI/UX specifications:** Unusually detailed for a plan — specific Material 3 typography roles, spacing grid, touch target sizes, and RTL considerations. This will produce consistent implementation.
- **Acceptance criteria format:** All 6 ACs are testable Given/When/Then with explicit empty-state behavior specified.
- **No new dependencies:** Correct — uses existing intl package for number formatting.
- **Human-verify checkpoint:** Appropriate for a visual dashboard screen. The verification checklist is specific and actionable.

## 3. Enterprise Gaps Identified

### Gap 1: Migration filename collision (CRITICAL)
The plan specified `002_dashboard_functions.sql` but migrations `002_payment_functions.sql` and `003_package_functions.sql` already exist. Deploying this would either fail or overwrite critical payment/package RPC functions.

### Gap 2: Timezone boundary for "today" queries
The plan specified filtering by `created_at >= today 00:00 UTC`. Algeria operates in UTC+1 (Africa/Algiers). A payment collected at 23:30 local time would be timestamped 22:30 UTC and counted correctly, but a payment at 00:30 local (23:30 previous day UTC) would be misattributed to the wrong day. The owner expects "today" to mean their local day.

### Gap 3: RPC function missing authorization check
The plan specified SECURITY DEFINER but didn't include an explicit business_id authorization check. Existing RPCs (`create_package_log`) verify the caller's JWT business_id matches the parameter. Without this, any authenticated user could call the function with any business_id.

### Gap 4: Missing GRANT EXECUTE statements
Existing RPCs in 002 and 003 all include `GRANT EXECUTE ON FUNCTION ... TO anon; GRANT EXECUTE ... TO authenticated;`. The plan omitted these — without them, the RPC would be uncallable.

### Gap 5: No migration deployment verification
The plan's Task 1 verification only checks `flutter analyze`. If the migration isn't deployed to Supabase first, the RPC call will crash at runtime with "function does not exist".

### Gap 6: Package alerts query performance
The `get_package_alerts` RPC uses DISTINCT ON (store_id, product_id) across the entire package_logs table. Without an index on `(store_id, product_id, created_at DESC)`, this becomes a sequential scan as data grows.

### Gap 7: RefreshIndicator completion semantics
The plan said "invalidates all 4 providers via ref.invalidate()" but didn't specify that the RefreshIndicator.onRefresh future must await all provider resolutions. Without this, the refresh indicator disappears immediately while data is still loading, showing stale values briefly.

### Gap 8: Orphaned _showCreateDriverDialog
Removing the dashboard placeholder leaves `_showCreateDriverDialog` unreferenced in `owner_shell.dart`. Dead code.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Migration filename collision: 002 already exists | Frontmatter `files_modified`, Task 1 action | Changed `002_dashboard_functions.sql` → `004_dashboard_functions.sql` |
| 2 | Timezone: "today" must use Algeria local time (UTC+1) | AC-1, AC-2, Task 1 action (getTodayRevenue, getTodayOrderCount) | Added Africa/Algiers timezone requirement to ACs and repository method descriptions |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 3 | RPC missing business_id authorization check | Task 1 action, RPC specification | Added explicit JWT business_id verification check matching create_package_log pattern |
| 4 | Missing GRANT EXECUTE statements for RPC | Task 1 action | Added GRANT EXECUTE to anon and authenticated roles |
| 5 | No migration deployment verification step | Task 1 verify section | Added `supabase db push` deployment step |
| 6 | Package alerts query needs index | Task 1 action | Added CREATE INDEX on package_logs(store_id, product_id, created_at DESC) |
| 7 | RefreshIndicator completes before data resolves | Task 2 action, pull-to-refresh | Added Future.wait requirement for all provider futures |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 8 | Orphaned _showCreateDriverDialog after placeholder removal | Dead code, but harmless. Will be addressed in Plan 03-04 (admin user management) when driver creation is given a proper home. The method is private and causes no side effects. |

## 5. Audit & Compliance Readiness

**Audit evidence:** The dashboard is read-only — it queries existing data without mutations. No new audit trail requirements introduced. The business_id authorization check on the RPC function ensures data isolation between businesses (future multi-tenancy readiness).

**Silent failure prevention:** The timezone fix prevents a silent data misattribution that would have been nearly invisible to the owner (off-by-one-hour boundary, only noticeable for late-night activity). The migration filename fix prevents a deployment crash that would block the feature entirely.

**Post-incident reconstruction:** Not applicable — this plan introduces no write operations. All data displayed is sourced from existing tables with existing audit trails.

**Ownership:** Data flows are clear: Supabase → DashboardRepository → Riverpod providers → UI. Single responsibility at each layer.

## 6. Final Release Bar

**What must be true before this plan ships:**
- Migration file is correctly numbered (004) and deployed before app testing
- "Today" queries use Algeria local timezone boundary
- RPC function has business_id authorization check
- All GRANT EXECUTE statements present

**Remaining risks if shipped as-is (after fixes):**
- Package alerts query performance at scale (mitigated by added index)
- No real-time updates (acceptable — pull-to-refresh is sufficient for MVP)
- Dead code from removed placeholder (cosmetic, no functional risk)

**Sign-off:** With the applied upgrades, I would sign my name to this plan. The fixes address every gap that could cause incorrect data display or deployment failure.

---

**Summary:** Applied 2 must-have + 5 strongly-recommended upgrades. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
