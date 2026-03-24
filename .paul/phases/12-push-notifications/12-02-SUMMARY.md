---
phase: 12-push-notifications
plan: 02
subsystem: notifications
tags: [fcm, push-notifications, supabase-edge-functions, notification-preferences]

requires:
  - phase: 12-push-notifications
    plan: 01
    provides: FCM infrastructure (tokens, Edge Function, foreground/background display)
provides:
  - Notification triggers on all 6 business events
  - Per-user notification preferences with UI
  - Low stock check after order creation
  - Centralized sendNotification() helper
affects: []

tech-stack:
  added: []
  patterns: [fire-and-forget notification calls, optimistic UI toggle, COALESCE for nullable metadata]

key-files:
  created:
    - supabase/migrations/023_notification_preferences.sql
    - lib/features/auth/screens/notification_preferences_screen.dart
  modified:
    - lib/core/notifications/notification_service.dart
    - lib/features/orders/screens/create_order_screen.dart
    - lib/features/payments/screens/payment_form_screen.dart
    - lib/features/driver_loads/screens/create_load_screen.dart
    - lib/features/driver_loads/screens/shift_close_screen.dart
    - lib/features/auth/screens/settings_placeholder.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb
    - supabase/functions/send-notification/index.ts

key-decisions:
  - "COALESCE on active field: NULL active in user_metadata was excluding all users from notification delivery"
  - "Edge Function --no-verify-jwt: built-in JWT verification was rejecting valid tokens, function handles its own auth via getUser()"
  - "Driver role excluded from preferences UI: drivers don't receive notifications, showing toggles would be misleading"

patterns-established:
  - "Fire-and-forget notification pattern: unawaited calls with try/catch, never block core operations"
  - "Optimistic toggle pattern: update UI immediately, revert on RPC error"
  - "COALESCE for nullable metadata: always default NULL booleans in user_metadata queries"

duration: ~60min
completed: 2026-03-24
---

# Phase 12 Plan 02: Notification Triggers + Preferences Summary

**Hooked push notifications into all 6 business events (order, payment, discount, low stock, shift open/close) with per-user notification preferences UI and SQL-level preference filtering.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~60 min |
| Completed | 2026-03-24 |
| Tasks | 4 completed (2 auto + 2 checkpoints) |
| Files created | 2 |
| Files modified | 9 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Order Notification | Pass | new_order sent after repo.create(), fire-and-forget |
| AC-2: Discount Pending Notification | Pass | discount_pending sent when _hasDiscount is true |
| AC-3: Payment Notification | Pass | payment_collected sent after payment repo.create() |
| AC-4: Low Stock Notification | Pass | checkAndNotifyLowStock queries products in order, sends per-product |
| AC-5: Shift Opened Notification | Pass | shift_opened sent after repo.createLoad() |
| AC-6: Shift Closed Notification | Pass | shift_closed sent after repo.closeLoad() |
| AC-7: Notification Preferences Filtering | Pass | get_fcm_tokens_for_business filters by p_event_type via LEFT JOIN |
| AC-8: Preferences UI | Pass | 6 SwitchListTiles with optimistic toggle + error revert |
| AC-9: Best-Effort Non-Blocking | Pass | All calls wrapped in try/catch, unawaited |
| AC-10: Preferences Screen Error Handling | Pass | Error state with retry button on load failure |
| AC-11: Preferences Visibility by Role | Pass | Notifications card hidden for driver role |

## Accomplishments

- Centralized `sendNotification()` and `checkAndNotifyLowStock()` helpers in NotificationService — all Edge Function calls go through one place
- 6 notification triggers across 4 screens with fire-and-forget pattern
- Migration 023: notification_preferences table with RLS, 2 RPCs (get + upsert), updated get_fcm_tokens_for_business with preference filtering
- Notification preferences screen with optimistic toggle UI, error handling, retry
- Enterprise audit applied: deployment ordering, error handling, set_updated_at trigger, driver role exclusion

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/023_notification_preferences.sql` | Created | Preferences table, RLS, 3 RPCs, updated get_fcm_tokens_for_business |
| `lib/features/auth/screens/notification_preferences_screen.dart` | Created | 6 toggle switches for notification preferences |
| `lib/core/notifications/notification_service.dart` | Modified | Added sendNotification() + checkAndNotifyLowStock() |
| `lib/features/orders/screens/create_order_screen.dart` | Modified | new_order + discount_pending + low_stock triggers |
| `lib/features/payments/screens/payment_form_screen.dart` | Modified | payment_collected trigger |
| `lib/features/driver_loads/screens/create_load_screen.dart` | Modified | shift_opened trigger |
| `lib/features/driver_loads/screens/shift_close_screen.dart` | Modified | shift_closed trigger |
| `lib/features/auth/screens/settings_placeholder.dart` | Modified | Notifications card (owner/admin only) |
| `lib/core/l10n/app_ar.arb` | Modified | 9 notification l10n strings |
| `lib/core/l10n/app_en.arb` | Modified | 9 notification l10n strings |
| `supabase/functions/send-notification/index.ts` | Modified | Pass p_event_type to RPC for preference filtering |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| COALESCE on active field | NULL active in user_metadata excluded ALL users from notification delivery | Critical fix — without this, zero notifications would ever be sent |
| --no-verify-jwt on Edge Function | Built-in JWT verification rejected valid tokens; function already does its own auth via getUser() | Required for Edge Function to work; function-level auth is sufficient |
| Driver role excluded from preferences UI | Drivers never receive notifications (Edge Function targets owner/admin only) | Prevents confusing UX where toggles do nothing |
| CASE statements over dynamic SQL | Prevents SQL injection in upsert_notification_preference | Safer than format(%I) approach |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 2 | Critical — without these fixes, notifications would not work |
| Scope additions | 0 | — |
| Deferred | 0 | — |

**Total impact:** Two bugs discovered during device verification that were not anticipatable from code review alone.

### Auto-fixed Issues

**1. NULL active field in user_metadata**
- **Found during:** Task 4 (device verification)
- **Issue:** `(raw_user_meta_data->>'active')::boolean IS TRUE` returns false when active is NULL, excluding all users
- **Fix:** Added COALESCE: `COALESCE((raw_user_meta_data->>'active')::boolean, true) IS TRUE`
- **Files:** Migration 023 + live SQL fix in Supabase
- **Verification:** `sent: 1` after fix (previously `sent: 0`)

**2. Edge Function JWT verification rejection**
- **Found during:** Task 4 (device verification)
- **Issue:** Edge Function's built-in JWT verification returned 401 Invalid JWT for valid session tokens
- **Fix:** Redeployed with `--no-verify-jwt` flag; function already validates auth via `supabase.auth.getUser(token)`
- **Files:** Deployment configuration only (no code change)
- **Verification:** Edge Function returns 200 after redeploy

## Skill Audit

No required skills for this plan. UI UX Pro Max and Frontend Design were marked optional (standard settings pattern). Correct per SPECIAL-FLOWS.md.

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| Gradle daemon crash (JVM OOM) | Retried build — succeeded on second attempt |
| LDPlayer emulator no FCM support | Tested notification delivery on real phone instead |
| Debug snackbar needed for diagnosis | Added temporary sendNotificationDebug() method, removed after verification |

## Next Phase Readiness

**Ready:**
- All 6 notification triggers operational and verified on real device
- Notification preferences table and UI complete
- Phase 12 (Push Notifications) is now fully complete
- v0.3 milestone (Driver Stock Loading & Notifications) is complete

**Concerns:**
- None

**Blockers:**
- None

---
*Phase: 12-push-notifications, Plan: 02*
*Completed: 2026-03-24*
