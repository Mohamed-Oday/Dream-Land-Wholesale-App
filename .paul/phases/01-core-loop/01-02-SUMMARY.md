---
phase: 01-core-loop
plan: 02
subsystem: auth
tags: [supabase-auth, riverpod, go_router, rtl, arabic, login]

requires:
  - phase: 01-01
    provides: Flutter scaffold, Supabase schema, GoRouter, Riverpod
provides:
  - Authentication system (login/logout/init)
  - Role-based routing (owner/admin/driver shells)
  - Init screen for first-time owner setup
  - Session persistence via Supabase Auth
affects: [01-03-crud, 01-04-orders, phase-2, phase-3]

tech-stack:
  added: [uuid]
  patterns: [AppRouterNotifier for auth+init state, username@tawzii.local email mapping]

key-files:
  created:
    - lib/features/auth/models/app_user.dart
    - lib/features/auth/services/auth_service.dart
    - lib/features/auth/providers/auth_provider.dart
    - lib/features/auth/screens/login_screen.dart
    - lib/features/auth/screens/init_screen.dart
    - lib/features/auth/screens/splash_screen.dart
    - lib/features/auth/screens/settings_placeholder.dart
    - supabase/migrations/002_seed_owner.sql
    - supabase/migrations/003_cleanup_and_allow_signup.sql
  modified:
    - lib/routing/app_router.dart
    - lib/app.dart
    - lib/features/*/screens/*_shell.dart

key-decisions:
  - "Init screen replaces manual SQL seeding for owner account creation"
  - "AppRouterNotifier manages auth+init state — not FutureProviders in redirect"
  - "Supabase Auth with username@tawzii.local format for email field"
  - "password_hash column defaults to '' — passwords managed by Supabase Auth"
  - "RLS allows first owner INSERT only when no users exist"

patterns-established:
  - "Auth flow: splash → init (if no users) → login (if not authed) → role shell"
  - "AppRouterNotifier: single source of truth for routing decisions"
  - "SettingsPlaceholder: shared logout widget across all role shells"
  - "ConsumerWidget/ConsumerStatefulWidget for Riverpod integration in screens"

duration: ~60min
completed: 2026-03-21
---

# Phase 1 Plan 02: Auth System Summary

**Login/logout with init screen for first-time setup, role-based routing via AppRouterNotifier, and session persistence via Supabase Auth.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~60 min |
| Completed | 2026-03-21 |
| Tasks | 3 completed (2 auto + 1 checkpoint) |
| Files created | 8 |
| Files modified | 5 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Login Screen Renders Correctly | Pass | Arabic RTL, orange theme, username/password fields, show/hide toggle |
| AC-2: Successful Login Routes to Correct Shell | Pass | Owner routes to /owner after login |
| AC-3: Invalid Credentials Show Error | Pass | Arabic error + Supabase error detail shown |
| AC-4: Session Persistence | Pass | App reopens to owner shell without login |
| AC-5: Logout Returns to Login | Pass | Logout clears session, returns to login |
| AC-6: Login Throttle | Pass | 30s lockout after 3 failed attempts |
| AC-7: App Start Shows Loading | Pass | Splash screen while auth state loads |

## Accomplishments

- Complete auth flow: splash → init (first-time) → login → role-based shell
- Init screen that creates owner account + Supabase Auth user + public.users row in one step
- AppRouterNotifier that manages auth + init state without FutureProvider issues in GoRouter redirect
- Shared SettingsPlaceholder with logout button across all role shells

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 1 | Init screen added (user request, better UX than manual SQL) |
| Auto-fixed | 3 | Router stability, RLS recursion, password_hash default |

**Total impact:** Significant improvement — init screen is better UX than manual SQL seeding.

### Scope Additions

**1. Init screen for first-time owner setup**
- **Reason:** User requested — manual SQL seeding was error-prone and failed
- **Files:** lib/features/auth/screens/init_screen.dart, supabase/migrations/003_cleanup_and_allow_signup.sql
- **Impact:** Better UX, self-service setup, no manual SQL needed

### Auto-fixed Issues

**1. GoRouter recreated on every build**
- **Issue:** `createAppRouter(ref)` called in build method created new router instances on each auth state change, resetting navigation
- **Fix:** Created `AppRouterNotifier` class that manages all state internally, exposed as stable Riverpod provider
- **Files:** lib/routing/app_router.dart

**2. RLS infinite recursion**
- **Issue:** `users_check_empty` policy queried `NOT EXISTS (SELECT 1 FROM users)` on the same table it guards
- **Fix:** Removed self-referencing policy, used authenticated-only SELECT + first-owner INSERT policies
- **Files:** supabase/migrations/003_cleanup_and_allow_signup.sql

**3. password_hash NOT NULL constraint**
- **Issue:** users table required password_hash but Supabase Auth manages passwords separately
- **Fix:** Changed to `DEFAULT ''` in schema and Drift table
- **Files:** 001_initial_schema.sql, users_table.dart

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| "Email signups are disabled" | User needed to enable Email provider in Supabase Auth settings |
| password_hash NOT NULL violation | Changed column to DEFAULT '' |
| RLS infinite recursion on users table | Replaced with non-self-referencing policies |
| GoRouter resetting navigation on auth state change | Moved to AppRouterNotifier pattern |
| Stuck on splash screen | FutureProvider not resolving in redirect — replaced with imperative init |

## Next Phase Readiness

**Ready:**
- Auth system fully functional (init, login, logout, session persistence)
- Role-based routing working (owner/admin/driver shells)
- Supabase project configured and connected
- All shells have logout functionality

**Concerns:**
- Debug error messages still shown on login screen (should be removed before production)
- Only owner account creation tested — admin/driver account creation is Phase 3

**Blockers:**
- None

---
*Phase: 01-core-loop, Plan: 02*
*Completed: 2026-03-21*
