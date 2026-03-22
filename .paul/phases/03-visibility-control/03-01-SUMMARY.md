---
phase: 03-visibility-control
plan: 01
subsystem: dashboard
tags: [riverpod, supabase-rpc, material3, kpi, rtl-arabic]

requires:
  - phase: 02-01
    provides: Payment data (credit_balance on stores, payment records)
  - phase: 02-02
    provides: Package tracking (package_logs with balance_after)
provides:
  - Owner dashboard with live KPI metrics (revenue, order count)
  - Top debtors list (stores with outstanding credit balance)
  - Package alerts (stores with unreturned packages via RPC aggregation)
  - DashboardRepository + Riverpod provider pattern for dashboard data
affects: [phase-3-drill-downs, phase-4-performance]

tech-stack:
  added: []
  patterns:
    - "DashboardRepository: aggregation queries separate from CRUD repos"
    - "Algeria timezone (UTC+1) for 'today' date boundaries"
    - "Supabase RPC with business_id authorization check for cross-table aggregation"
    - "KpiCard widget: reusable metric display with tabular figures"

key-files:
  created:
    - supabase/migrations/004_dashboard_functions.sql
    - lib/features/dashboard/repositories/dashboard_repository.dart
    - lib/features/dashboard/providers/dashboard_provider.dart
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/features/dashboard/widgets/kpi_card.dart
  modified:
    - lib/features/owner/screens/owner_shell.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Client-side aggregation for revenue/order count — efficient enough for <20 stores"
  - "Server-side RPC for package alerts — DISTINCT ON aggregation too complex for client"
  - "Algeria timezone (UTC+1) hardcoded — no DST since 2014, safe assumption"
  - "Removed _showCreateDriverDialog from owner_shell — dead code after placeholder removal"

duration: ~20min
completed: 2026-03-22
---

# Phase 3 Plan 01: Owner Dashboard Summary

**Live dashboard replacing placeholder — KPI cards for today's revenue and order count, top debtors list sorted by credit balance, package alerts via Supabase RPC aggregation, pull-to-refresh with shimmer loading states.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~20 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 5 |
| Files modified | 3 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Today's Revenue Displayed | Pass | Aggregates payments using Algeria local time boundary |
| AC-2: Today's Order Count Displayed | Pass | Count query with same timezone logic |
| AC-3: Top Debtors Listed | Pass | Stores with credit_balance > 0, sorted DESC, limit 5 |
| AC-4: Package Alerts Listed | Pass | Via get_package_alerts RPC with DISTINCT ON aggregation |
| AC-5: Pull-to-Refresh | Pass | Invalidates all 4 providers, Future.wait before hiding indicator |
| AC-6: Loading State | Pass | Shimmer placeholders for cards and list sections |

## Accomplishments

- Owner dashboard with real-time KPI cards (Today's Revenue + Today's Orders)
- Top debtors section with store names and DA amounts in error color
- Package alerts section with store names and outstanding counts
- Supabase RPC `get_package_alerts` with business_id auth check + performance index
- Pull-to-refresh with Future.wait completion semantics
- Full Arabic l10n for all dashboard strings
- Shimmer loading states and empty state messages

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/004_dashboard_functions.sql` | Created | RPC for package alerts + performance index |
| `lib/features/dashboard/repositories/dashboard_repository.dart` | Created | Dashboard data queries with timezone-aware date boundaries |
| `lib/features/dashboard/providers/dashboard_provider.dart` | Created | Riverpod providers for all 4 dashboard metrics |
| `lib/features/dashboard/screens/owner_dashboard_screen.dart` | Created | Dashboard UI with KPI cards, debtors, alerts, shimmer loading |
| `lib/features/dashboard/widgets/kpi_card.dart` | Created | Reusable metric card with tabular figures |
| `lib/features/owner/screens/owner_shell.dart` | Modified | Replaced _DashboardPlaceholder with OwnerDashboardScreen, removed dead code |
| `lib/core/l10n/app_ar.arb` | Modified | Added 9 dashboard Arabic strings |
| `lib/core/l10n/app_en.arb` | Modified | Added 9 dashboard English strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 1 | Removed dead code (warnings) |
| Deferred | 1 | Performance tuning → Phase 4 |

**Total impact:** Clean execution with one dead code cleanup.

### Auto-fixed Issues

**1. Dead code: _showCreateDriverDialog removed**
- **Found during:** Task 2 (owner shell integration)
- **Issue:** Removing _DashboardPlaceholder left _showCreateDriverDialog unreferenced, causing analyzer warning
- **Fix:** Removed the method entirely (audit had flagged this as "can safely defer")
- **Files:** `lib/features/owner/screens/owner_shell.dart`
- **Verification:** `flutter analyze` passes with no warnings in this file

### Deferred Items

- App feels ~30fps laggy — user reported during verification. Logged to STATE.md deferred issues for Phase 4 (Polish & Hardening). Needs profiling: likely Riverpod rebuilds, heavy widget trees.

## Skill Audit

Skill audit: All required skills invoked ✓

| Skill | Phase | Invoked |
|-------|-------|---------|
| /ui-ux-pro-max | PLAN | ✓ |
| /frontend-design | APPLY | ✓ |

## Next Phase Readiness

**Ready:**
- Dashboard data layer established (DashboardRepository pattern)
- KpiCard widget reusable for future dashboard additions
- Phase 3 Plan 02 (GPS tracking + live map) can proceed independently

**Concerns:**
- ~30fps lag reported — needs profiling before production
- Migration 004 must be deployed to Supabase before testing

**Blockers:** None

---
*Phase: 03-visibility-control, Plan: 01*
*Completed: 2026-03-22*
