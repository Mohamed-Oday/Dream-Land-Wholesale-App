# Enterprise Plan Audit Report

**Plan:** .paul/phases/12-push-notifications/12-01-PLAN.md
**Audited:** 2026-03-24
**Verdict:** Conditionally acceptable → Acceptable after applied upgrades

---

## 1. Executive Verdict

The plan is **acceptable after applied upgrades**. The architecture is sound — Supabase Edge Function as the notification backend, FCM v1 API, client-triggered notifications, Riverpod-based token lifecycle. These are correct choices for the project's scale and constraints.

Six gaps were identified, primarily around input validation in the Edge Function, task ordering, and error resilience in the Flutter client. All must-have and strongly-recommended findings have been applied. The plan is now ready for APPLY.

Would I sign off on this for production? **Yes, with the applied upgrades.**

---

## 2. What Is Solid

- **Token lifecycle via auth state observation:** Registering/unregistering tokens by watching `authStateProvider` rather than modifying `AuthService` is the correct decoupling pattern. No risk of breaking existing auth flow.

- **SECURITY DEFINER RPCs with REVOKE FROM PUBLIC:** Consistent with established project security pattern (migrations 015-021). `get_fcm_tokens_for_business` correctly restricted to service_role only.

- **ON DELETE CASCADE on user_id FK:** Automatic token cleanup when auth user is deleted. No orphaned tokens.

- **Edge Function over pg_net:** Correct choice. FCM v1 requires OAuth2 which is impractical in raw SQL. Edge Functions handle this cleanly in TypeScript.

- **Client-triggered notifications:** All notification-worthy events originate from user actions (driver creates order, collects payment, etc.). Server-side triggers would add complexity for zero benefit at this scale.

- **Infrastructure/integration split (Plan 01 / 02):** Clean separation. Plan 01 proves the plumbing works end-to-end before Plan 02 hooks into all event flows.

- **Checkpoint placement for Firebase setup:** Cannot be automated. Clear step-by-step instructions with verification checklist.

---

## 3. Enterprise Gaps Identified

### G-1: Edge Function accepts any event_type without validation (must-have)
The notification content builder uses event_type to select Arabic title/body. An unknown event_type would produce undefined notification content or crash. Any authenticated user can call the Edge Function with arbitrary event_type values.

### G-2: Edge Function proceeds with null business_id (must-have)
If a user's JWT has missing/corrupt business_id in user_metadata, the function would query `get_fcm_tokens_for_business` with NULL. Depending on PostgreSQL's NULL comparison behavior, this could return zero rows (safe) or unexpected results. Defensive validation required.

### G-3: Task ordering — Edge Function written after deployment checkpoint (must-have, structural)
Original plan had: Task 1 (migration) → Task 2 (checkpoint) → Task 3 (Flutter) → Task 4 (Edge Function). The checkpoint claimed "Edge Function code is written" but the Edge Function was Task 4, AFTER the checkpoint. This means the user cannot deploy the Edge Function during the checkpoint.

### G-4: Self-notifications — caller receives their own notification (strongly-recommended)
A driver creating an order triggers a notification to owner/admin. But if an owner creates an order (possible), they'd be notified of their own action. Annoying and unprofessional. The Edge Function should exclude the caller.

### G-5: No graceful handling of notification permission denial (strongly-recommended)
Android 13+ requires explicit POST_NOTIFICATIONS permission. If denied, the plan doesn't specify behavior. Without handling, the app could crash, show confusing errors, or register a token that can't display notifications.

### G-6: Token operations could block logout or crash app (strongly-recommended)
`unregisterToken` on logout calls an RPC. If the device is offline or the RPC fails, logout could hang or throw. Token operations should be best-effort — never degrade core app functionality.

### G-7: OAuth2 token caching strategy unspecified (strongly-recommended)
Plan says "cache for ~55 minutes" but doesn't specify where or how. In Deno Deploy, the approach matters: module-level variable works for warm instances, fails on cold starts.

---

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | event_type validation | Task 2 action, step 5 | Added validation of event_type against allowed enum, return 400 for unknown |
| 2 | business_id null check | Task 2 action, step 4 | Added non-null validation with 400 response before querying tokens |
| 3 | Task ordering | Tasks section | Moved Edge Function from Task 4 to Task 2 (before checkpoint). Checkpoint now includes Edge Function deployment + secrets + test invocation |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Self-notification prevention | Task 1 (RPC), Task 2 action step 7 | Added `p_exclude_user` parameter to `get_fcm_tokens_for_business`, Edge Function passes caller's user_id |
| 2 | Permission denial handling | Task 4 action section F | initialize() handles denial gracefully — log, don't throw, skip token registration |
| 3 | Best-effort token operations | Task 4 action sections F + constraints | registerToken and unregisterToken wrapped in try/catch, logout never blocked |
| 4 | OAuth2 caching strategy | Task 2 action step 9 | Specified module-level variable caching with 5-minute buffer before expiry, cold-start regeneration |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Rate limiting on Edge Function | <10 users on a private sideloaded APK. Abuse risk is negligible at current scale. Revisit if app distribution expands. |

---

## 5. Audit & Compliance Readiness

**Audit evidence:** The plan produces verifiable artifacts — migration SQL in version control, FCM token records in Supabase, Edge Function logs. Post-incident reconstruction is supported by the fcm_tokens table (who had what token when) and Edge Function response logging (sent/failed counts).

**Silent failure prevention:** With applied upgrades, the Edge Function validates all inputs (event_type, business_id) and returns explicit error codes rather than crashing. Flutter client handles all notification failures silently without degrading app functionality.

**Ownership:** Clear — Edge Function owned by project, deployed via Supabase CLI. Firebase project under user's Google account. No shared infrastructure beyond Supabase.

**One gap remains:** No notification delivery audit log (which notifications were sent to whom, when). This is acceptable for current scale but would be needed for compliance at larger scale. Not blocking for this plan.

---

## 6. Final Release Bar

**What must be true:**
- Edge Function validates all inputs before processing
- Caller excluded from notification targets
- Flutter app functions normally with or without notification permission
- Token operations never block auth flows
- All verification items in the plan pass

**Remaining risks if shipped as-is:**
- No rate limiting (acceptable at <10 users)
- No notification delivery audit log (acceptable for private business tool)
- OAuth2 token cache lost on cold starts (performance only, not correctness)

**Sign-off:** I would sign my name to this system with the applied upgrades. The architecture is appropriate for the project's scale, the security model is consistent with established patterns, and error handling covers the realistic failure modes.

---

**Summary:** Applied 2 must-have + 4 strongly-recommended upgrades. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
