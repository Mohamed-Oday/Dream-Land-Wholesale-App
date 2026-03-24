# Enterprise Plan Audit Report

**Plan:** .paul/phases/12-push-notifications/12-02-PLAN.md
**Audited:** 2026-03-24
**Verdict:** Conditionally Acceptable (accepted after applying upgrades below)

---

## 1. Executive Verdict

**Conditionally acceptable.** The plan's architecture is sound — client-triggered notifications via a centralized Edge Function with best-effort semantics is the right pattern for this scale. The preferences system correctly filters at the SQL level, and the CASE-based upsert avoids SQL injection. However, four gaps were identified that must be addressed before execution: a deployment ordering dependency that could break live notifications, missing error handling on the preferences screen, an inconsistency with the project's trigger pattern, and a misleading UI element for driver role.

Would I sign my name to this plan after the upgrades? Yes.

## 2. What Is Solid

- **Best-effort, non-blocking pattern:** Every notification path wraps in try/catch and uses fire-and-forget (unawaited). Notification failures never degrade core operations. This is the correct architectural decision for a system where orders and payments must always succeed.

- **Centralized sendNotification() helper:** Single point of contact for all Edge Function calls prevents scattered inline invocations and ensures consistent error handling.

- **SQL-level preference filtering:** Preferences are checked inside `get_fcm_tokens_for_business` via LEFT JOIN, not in the Edge Function or client. This means the Edge Function code stays unchanged except for passing one extra param. Clean separation.

- **CASE statements over dynamic SQL:** The upsert RPC validates event_type against an allowlist and uses CASE statements. No SQL injection vector. This is materially better than the `format(%I)` alternative.

- **Scoped low stock check:** Only queries products that were in the current order, not a full table scan. Targeted and efficient.

- **Fire-and-forget with double safety:** sendNotification() catches internally AND the call sites wrap in try/catch. Belt and suspenders approach appropriate for a best-effort system.

## 3. Enterprise Gaps Identified

### Gap A: Deployment Ordering Dependency (Critical)
The migration DROPs `get_fcm_tokens_for_business(UUID, TEXT[], UUID)` and CREATEs a new 4-param version. The Edge Function passes `p_event_type` to this RPC. If the Edge Function is redeployed BEFORE the migration runs, the old 3-param function will still exist and won't accept the new parameter. Notifications will fail with an RPC error until the migration is applied.

**Risk:** Complete notification outage during the deployment window if steps are done in wrong order.

### Gap B: Preferences Screen Has No Error/Offline Handling
The plan specifies loading preferences via RPC on initState and optimistic toggle updates. But if the RPC fails (offline, timeout), the plan doesn't specify error state behavior. The screen would show a loading spinner forever or crash.

**Risk:** Poor UX if device is offline when accessing preferences. Potential unhandled exception.

### Gap C: Missing set_updated_at Trigger
Phase 10 (migration 019) established a pattern: all tables with `updated_at` columns get a `set_updated_at` trigger. The `notification_preferences` table has `updated_at` but the plan doesn't apply this trigger. While the RPC manually sets `updated_at = now()`, any direct table access (admin operations, future RPCs) would leave `updated_at` stale.

**Risk:** Inconsistency with project pattern. Silent data integrity issue if table is accessed outside the RPC.

### Gap D: Notification Preferences Shown to Driver Role
The Edge Function's `getTargetRoles()` only sends notifications to `['owner', 'admin']` (or `['owner']` for discount_pending). Drivers never receive notifications. But the plan adds the Notifications card to SettingsPlaceholder without a role check, meaning drivers would see 6 toggle switches that control nothing.

**Risk:** Confusing UX. Driver toggles settings expecting behavior change, nothing happens. Erodes trust in the app.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Deployment ordering: migration MUST run before Edge Function redeploy | Task 3 (checkpoint) | Added explicit ordering warning, numbered steps as FIRST/SECOND, explained the failure mode |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Preferences screen error/offline handling | Task 2c action, AC-10 added | Added error state with retry button requirement, SocketException + PostgrestException handling |
| 2 | set_updated_at trigger on notification_preferences | Task 2a action | Added trigger creation step matching Phase 10 pattern |
| 3 | Hide Notifications from driver role | Task 2d action, AC-11 added | Added role check using existing currentUserProvider, explained rationale |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Low stock notification burst (multiple products → multiple notifications) | At current scale (10 products), a burst of 5-10 notifications is rare and tolerable. Aggregation adds complexity with no current user pain. |
| 2 | Client-side event_type validation in sendNotification() | Edge Function already validates and returns 400 on invalid type. Client validation is defense-in-depth but the try/catch already handles the 400 gracefully. |
| 3 | Notification deduplication / idempotency tracking | At current scale (<10 drivers, <50 orders/day), duplicate notifications from retries are rare. Deduplication requires a sent_notifications table with TTL cleanup — disproportionate complexity. |

## 5. Audit & Compliance Readiness

**Audit evidence:** Notifications are client-triggered with best-effort semantics. There is no notification delivery log — if an auditor asks "was notification X sent?", the only evidence is Edge Function invocation logs in Supabase. This is acceptable for the current use case (internal business tool) but would need a notification_log table for regulated environments.

**Silent failure prevention:** The plan correctly uses debugPrint for all notification failures. These are visible in debug console but NOT in production logs. For production observability, consider logging to Supabase `error_log` table (deferred — already in deferred issues from AEGIS).

**Post-incident reconstruction:** If a user claims they didn't receive a notification, the investigation path is: check Edge Function logs → check fcm_tokens table → check notification_preferences table. This is adequate.

**Ownership:** Clear — notification triggers are in screen files (the actor), preferences are in SQL (the filter), delivery is in the Edge Function (the mechanism). Three-layer separation is clean.

## 6. Final Release Bar

**What must be true before this plan ships:**
1. Migration 023 applied before Edge Function redeployment (must-have #1)
2. Preferences screen handles offline/error gracefully (strongly-recommended #1)
3. Drivers cannot access notification preferences (strongly-recommended #3)

**What risks remain if shipped as-is (after upgrades):**
- Low stock notifications could fire in bursts (deferred — acceptable at scale)
- No notification delivery audit log (deferred — internal tool)
- No notification deduplication (deferred — rare at scale)

**Sign-off:** With the 4 upgrades applied, this plan is enterprise-acceptable for a pre-production internal business tool at this scale. The architecture is clean, the failure modes are handled, and the deployment dependency is now explicit.

---

**Summary:** Applied 1 must-have + 3 strongly-recommended upgrades. Deferred 3 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
