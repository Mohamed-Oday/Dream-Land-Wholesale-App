---
phase: 04-polish-hardening
plan: 03
subsystem: dashboard, stores
tags: [package-alerts, threshold, balance-adjustment, supabase-rpc, audit-trail]

requires:
  - phase: 03-01
    provides: Dashboard with package alerts section
  - phase: 01-03
    provides: Store detail screen with balance display
provides:
  - Configurable package alert threshold on dashboard
  - Owner/admin balance adjustment with audit logging
affects: []

tech-stack:
  added: []
  patterns:
    - "StateProvider for configurable threshold (client-side filtering)"
    - "auth.uid() in RPC for non-spoofable audit trail"
    - "Balance adjustment dialog pattern with amount + reason"

key-files:
  created:
    - supabase/migrations/008_balance_adjustment.sql
  modified:
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/features/dashboard/providers/dashboard_provider.dart
    - lib/features/stores/screens/store_detail_screen.dart
    - lib/features/stores/repositories/store_repository.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "auth.uid() for adjusted_by — non-spoofable audit trail (audit finding)"
  - "Removed FK to businesses table — table doesn't exist, business_id is plain UUID"
  - "Client-side threshold filtering — no new RPC needed, StateProvider sufficient"

duration: ~15min
completed: 2026-03-22
---

# Phase 4 Plan 03: Package Alert Thresholds + Balance Adjustment Summary

**Configurable package alert threshold on dashboard (default >10, tune icon), owner/admin balance adjustment dialog on store detail with Supabase RPC audit logging.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~15 min |
| Completed | 2026-03-22 |
| Tasks | 2 completed (1 auto + 1 human-verify) |
| Files created | 1 |
| Files modified | 6 |
| L10n strings added | 8 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Package Alert Threshold | Pass | Header shows ">10", tune icon opens dialog, immediate re-filter |
| AC-2: Owner Balance Adjustment | Pass | Dialog with amount + reason, RPC with auth.uid() and logging |
| AC-3: Adjustment Only for Owner/Admin | Pass | Button hidden for drivers |

## Accomplishments

- Package alerts section header shows threshold, tune icon opens config dialog
- Client-side filtering of alerts by threshold (>= N outstanding)
- balance_adjustments table with RLS + adjust_store_balance RPC
- RPC uses auth.uid() (non-spoofable), rejects zero amounts, FOR UPDATE locking
- Balance adjustment dialog on store detail with amount + reason validation

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/008_balance_adjustment.sql` | Created | balance_adjustments table + adjust_store_balance RPC |
| `lib/features/dashboard/screens/owner_dashboard_screen.dart` | Modified | Threshold header, tune icon, filter logic, threshold dialog |
| `lib/features/dashboard/providers/dashboard_provider.dart` | Modified | packageAlertThresholdProvider StateProvider |
| `lib/features/stores/screens/store_detail_screen.dart` | Modified | Adjust Balance button + dialog (owner/admin only) |
| `lib/features/stores/repositories/store_repository.dart` | Modified | adjustBalance() method |
| `lib/core/l10n/app_ar.arb` | Modified | 8 new strings |
| `lib/core/l10n/app_en.arb` | Modified | 8 new strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 1 | Essential — businesses table FK doesn't exist |

**Total impact:** Single schema fix, clean execution otherwise.

### Auto-fixed Issues

**1. Database: businesses table does not exist**
- **Found during:** User testing (migration deployment)
- **Issue:** Migration referenced `REFERENCES businesses(id)` but no businesses table exists
- **Fix:** Changed to plain `UUID NOT NULL` matching existing pattern
- **Verification:** Migration deploys cleanly

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**Ready:**
- 2 plans remaining in Phase 4 (04-04, 04-05)
- All owner management tools complete (threshold, adjustment, cancellation)

**Concerns:** None

**Blockers:** None

---
*Phase: 04-polish-hardening, Plan: 03*
*Completed: 2026-03-22*
