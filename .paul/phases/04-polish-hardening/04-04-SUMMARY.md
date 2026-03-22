---
phase: 04-polish-hardening
plan: 04
subsystem: settings, performance
tags: [remote-config, in-app-update, repaint-boundary, semver, supabase]

requires:
  - phase: 01-02
    provides: Settings screen, auth flow
provides:
  - In-app update check via remote_config table
  - Version display on settings screen
  - RepaintBoundary on list card widgets for scroll performance
affects: []

tech-stack:
  added: []
  patterns:
    - "FutureProvider for cached remote config fetch"
    - "Semver comparison (split-by-dot integer compare)"
    - "RepaintBoundary on list items for paint isolation"

key-files:
  created:
    - supabase/migrations/009_remote_config.sql
  modified:
    - lib/features/auth/screens/settings_placeholder.dart
    - lib/features/orders/screens/order_list_screen.dart
    - lib/features/payments/screens/payment_list_screen.dart
    - lib/features/packages/screens/package_list_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "FutureProvider for remote config — caches result, no repeated fetches on rebuild (audit finding)"
  - "No url_launcher dependency — show download URL in selectable text dialog"
  - "Empty download_url hides download button gracefully (audit finding)"
  - "RepaintBoundary on list cards only — targeted, not indiscriminate"

duration: ~15min
completed: 2026-03-22
---

# Phase 4 Plan 04: In-App Update + Performance Summary

**In-app update check via remote_config table with version display and update prompt on settings screen, plus RepaintBoundary on all list card widgets for scroll performance.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~15 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 1 |
| Files modified | 6 |
| L10n strings added | 4 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Version Display in Settings | Pass | Shows AppConstants.appVersion (0.1.0) |
| AC-2: Update Check and Prompt | Pass | FutureProvider checks remote_config, shows card when newer |
| AC-3: Performance Optimizations | Pass | RepaintBoundary on order/payment/package list cards |

## Accomplishments

- remote_config table with RLS (SELECT-only for app, service_role for writes)
- remoteConfigProvider FutureProvider with graceful error handling
- Semver comparison function (_isNewerVersion)
- Update card with conditional download button (hidden when URL empty)
- RepaintBoundary on _OrderCard, _PaymentCard, _PackageLogCard

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/009_remote_config.sql` | Created | remote_config table with seed data |
| `lib/features/auth/screens/settings_placeholder.dart` | Modified | Version display, update check, remoteConfigProvider |
| `lib/features/orders/screens/order_list_screen.dart` | Modified | RepaintBoundary on _OrderCard |
| `lib/features/payments/screens/payment_list_screen.dart` | Modified | RepaintBoundary on _PaymentCard |
| `lib/features/packages/screens/package_list_screen.dart` | Modified | RepaintBoundary on _PackageLogCard |
| `lib/core/l10n/app_ar.arb` | Modified | 4 new strings |
| `lib/core/l10n/app_en.arb` | Modified | 4 new strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | None |
| Deferred | 0 | None |

**Total impact:** Clean execution. Dashboard RepaintBoundary skipped (list items there are static ListTiles inside Cards — RepaintBoundary overhead not justified).

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**Ready:**
- 1 plan remaining in Phase 4 (04-05: offline hardening + printer recovery + data retention)
- This is the FINAL plan of Phase 4 and Milestone v0.1

**Concerns:** None

**Blockers:** None

---
*Phase: 04-polish-hardening, Plan: 04*
*Completed: 2026-03-22*
