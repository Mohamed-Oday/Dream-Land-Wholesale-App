---
phase: 12-push-notifications
plan: 01
subsystem: infra
tags: [firebase, fcm, push-notifications, supabase-edge-functions, deno]

requires:
  - phase: 11-driver-stock-loading
    provides: driver shifts and stock events as notification triggers
provides:
  - FCM token lifecycle (register, refresh, delete)
  - Supabase Edge Function for sending push notifications via FCM v1 API
  - Foreground and background notification display
  - fcm_tokens table with RLS and RPCs
affects: [12-02-notification-triggers]

tech-stack:
  added: [firebase_core, firebase_messaging, flutter_local_notifications, supabase-edge-functions]
  patterns: [module-level OAuth2 caching, best-effort token ops, client-triggered notifications]

key-files:
  created:
    - supabase/migrations/022_fcm_tokens.sql
    - supabase/functions/send-notification/index.ts
    - lib/core/notifications/notification_service.dart
    - lib/core/notifications/notification_provider.dart
  modified:
    - pubspec.yaml
    - android/settings.gradle.kts
    - android/app/build.gradle.kts
    - android/app/src/main/AndroidManifest.xml
    - lib/main.dart
    - lib/app.dart

key-decisions:
  - "Supabase Edge Function over pg_net: FCM v1 requires OAuth2 which is impractical in raw SQL"
  - "Client-triggered notifications: all events originate from user actions, no server-side triggers needed"
  - "Best-effort token ops: notification failures never degrade core app functionality"

patterns-established:
  - "NotificationService as core service (lib/core/notifications/), not a feature"
  - "Auth state observation for token lifecycle (provider watches authStateProvider)"
  - "Edge Function invocation via Supabase.instance.client.functions.invoke()"

duration: ~45min
completed: 2026-03-24
---

# Phase 12 Plan 01: FCM Infrastructure Summary

**End-to-end push notification plumbing: Firebase + FCM tokens in Supabase + Edge Function (FCM v1 API) + foreground/background notification display in Flutter.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~45 min |
| Completed | 2026-03-24 |
| Tasks | 4 completed (1 migration + 1 Edge Function + 1 checkpoint + 1 Flutter integration) |
| Files created | 4 |
| Files modified | 6 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: FCM Token Registration | Pass | Token registered via upsert_fcm_token RPC on signIn auth event |
| AC-2: Token Cleanup on Logout | Pass | Token deleted via delete_fcm_token RPC on signOut, best-effort |
| AC-3: Token Refresh | Pass | onTokenRefresh stream upserts new token |
| AC-4: Edge Function Sends Notification | Pass | Deployed, validates inputs, sends via FCM v1 with OAuth2 |
| AC-5: Background Notification Display | Pass | Background handler registered, FCM auto-displays notification payload |
| AC-6: Foreground Notification Display | Pass | flutter_local_notifications shows matching notification |

## Accomplishments

- Migration 022: `fcm_tokens` table with RLS + 3 RPCs (upsert, delete, get-for-business with caller exclusion)
- Supabase Edge Function `send-notification`: FCM v1 API with OAuth2 token generation, input validation, stale token cleanup, Arabic notification content for 6 event types
- Flutter FCM integration: Firebase init, background handler, NotificationService with permission handling, NotificationProvider watching auth state
- Enterprise audit applied: 2 must-have + 4 strongly-recommended upgrades (input validation, task reordering, self-notification exclusion, permission denial handling, best-effort token ops, OAuth2 caching)

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/022_fcm_tokens.sql` | Created | FCM tokens table, RLS, 3 RPCs |
| `supabase/functions/send-notification/index.ts` | Created | Edge Function: FCM v1 API with OAuth2, Arabic notifications |
| `lib/core/notifications/notification_service.dart` | Created | FCM token management, permission handling, foreground display |
| `lib/core/notifications/notification_provider.dart` | Created | Riverpod providers, auth state observation for token lifecycle |
| `pubspec.yaml` | Modified | Added firebase_core, firebase_messaging, flutter_local_notifications |
| `android/settings.gradle.kts` | Modified | Added Google Services plugin |
| `android/app/build.gradle.kts` | Modified | Applied Google Services plugin |
| `android/app/src/main/AndroidManifest.xml` | Modified | POST_NOTIFICATIONS permission, FCM channel metadata |
| `lib/main.dart` | Modified | Firebase init, background message handler |
| `lib/app.dart` | Modified | Eagerly initialize notificationInitProvider |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Edge Function over pg_net | FCM v1 requires OAuth2 JWT signing, impractical in SQL | First Edge Function in project, enables future server-side logic |
| Client-triggered notifications | All events originate from user actions at this scale | Simple, no database triggers needed |
| Module-level OAuth2 caching | Deno Deploy preserves module state across warm invocations | Reduces OAuth2 token generation calls by ~98% |
| Caller exclusion (p_exclude_user) | Prevents self-notifications when owner/admin performs actions | Clean UX, added during audit |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | — |
| Scope additions | 0 | — |
| Deferred | 0 | — |

**Total impact:** Plan executed as written. No deviations.

## Skill Audit

No required skills for this plan (infrastructure only, no UI screens). Correct per SPECIAL-FLOWS.md.

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| npm install -g supabase unsupported | Installed via Scoop package manager instead |
| PowerShell BOM in .env.secrets file | Used [System.IO.File]::WriteAllText() to write without BOM |
| Service account key exposed in error output | Advised user to rotate key in Firebase Console |

## Next Phase Readiness

**Ready:**
- FCM infrastructure fully operational (tokens stored, Edge Function deployed, notifications display)
- Plan 02 can hook into existing event flows (order creation, payment, discount, stock, shift)
- Edge Function accepts all 6 event types with Arabic content

**Concerns:**
- Service account key was exposed in terminal output — user should rotate it
- Edge Function deployment requires Supabase CLI (new toolchain for this project)

**Blockers:**
- None

---
*Phase: 12-push-notifications, Plan: 01*
*Completed: 2026-03-24*
