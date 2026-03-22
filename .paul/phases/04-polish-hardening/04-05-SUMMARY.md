---
phase: 04-polish-hardening
plan: 05
subsystem: theme, sync, printing, data-retention
tags: [color-palette, cairo-font, sync-cleanup, printer-reconnect, driver-location, dropdown-ux]

requires:
  - phase: 01-01
    provides: Theme system, Drift sync queue
  - phase: 02-03
    provides: Print service
  - phase: 03-02
    provides: DriverLocation tracking
provides:
  - Brand color palette (warm amber, forest/cherry/navy accents)
  - Cairo font across entire app
  - Sync queue cleanup (auto-delete synced items)
  - Printer auto-reconnect on print attempt
  - DriverLocation 7-day retention cleanup function
  - Bottom sheet store picker replacing DropdownButtonFormField
  - Comprehensive theme fixes (cards, inputs, nav bar, dialogs)
affects: []

tech-stack:
  added:
    - "Cairo font (fonts/ directory, registered in pubspec.yaml)"
  patterns:
    - "Bottom sheet picker for store selection (replaces DropdownButtonFormField)"
    - "Explicit ColorScheme.copyWith for all surface/container variants"
    - "Printer _lastMacAddress + _lastName for auto-reconnect"

key-files:
  created:
    - supabase/migrations/009_remote_config.sql
    - supabase/migrations/010_location_retention.sql
    - fonts/Cairo-Regular.ttf
    - fonts/Cairo-Medium.ttf
    - fonts/Cairo-SemiBold.ttf
    - fonts/Cairo-Bold.ttf
    - fonts/Cairo-Light.ttf
  modified:
    - lib/core/theme/app_colors.dart
    - lib/core/theme/app_theme.dart
    - lib/core/sync/sync_queue.dart
    - lib/core/sync/sync_service.dart
    - lib/features/auth/screens/settings_placeholder.dart
    - lib/features/printing/services/print_service.dart
    - lib/features/dashboard/widgets/kpi_card.dart
    - lib/features/orders/screens/create_order_screen.dart
    - lib/features/payments/screens/payment_form_screen.dart
    - lib/features/packages/screens/package_collection_screen.dart
    - lib/features/stores/screens/store_list_screen.dart
    - lib/features/driver/screens/user_management_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb
    - pubspec.yaml

key-decisions:
  - "Explicit ColorScheme.copyWith for ALL surface variants — prevents Material 3 fromSeed from generating unwanted tints"
  - "Cairo font replaces NotoSansArabic — user preference for brand consistency"
  - "Bottom sheet store picker replaces DropdownButtonFormField — fixes full-width popup issue, better mobile UX"
  - "Cards get white bg + subtle border via global CardTheme — consistent across all screens"
  - "canvasColor + dropdownColor for legacy dropdown popups"
  - "Printer stores _lastMacAddress + _lastName separately for reconnect (audit finding)"

duration: ~45min
completed: 2026-03-22
---

# Phase 4 Plan 05: Offline Hardening + Brand Polish Summary

**Brand color palette (warm amber), Cairo font, sync queue cleanup, printer auto-reconnect, DriverLocation retention, comprehensive theme fixes including bottom sheet store picker and white card backgrounds.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~45 min |
| Completed | 2026-03-22 |
| Tasks | 4 completed (3 auto + 1 human-verify) |
| Files created | 7 (2 migrations + 5 font files) |
| Files modified | 15 |
| L10n strings added | 7 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-0: Brand Color Palette | Pass | Warm mist bg, ink text, orange primary, forest success, cherry error |
| AC-1: Sync Queue Cleanup + Status | Pass | cleanupSynced() deletes synced items, info card on settings |
| AC-2: Printer Auto-Reconnect | Pass | Stores last MAC, tryReconnect() in printFromWidget |
| AC-3: DriverLocation 7-Day Retention | Pass | cleanup_old_driver_locations() RPC deployed |

## Accomplishments

- Full brand color palette: primary orange, cream, light gold, ink, charcoal, slate, mist, forest, cherry, navy
- Cairo font registered and applied across entire app
- All surface container variants set to white — eliminates gray tints from Material 3
- Cards: white background with subtle gray border (global CardTheme)
- Input fields: white fill, gray border, mist label background, orange focus border
- Navigation bar: white background, gold indicator
- Dialogs, bottom sheets, popups: all white
- KPI cards: white with border (was invisible on mist bg)
- Store list items wrapped in Card
- User management items wrapped in Card
- DropdownButtonFormField replaced with bottom sheet picker on all 3 screens
- Sync queue cleanup after processQueue()
- Printer auto-reconnect with stored MAC/name
- DriverLocation 7-day retention RPC
- Remote config table for in-app update check
- Version display + update card on settings

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 4 | User-requested UI polish iterations |
| Auto-fixed | 1 | businesses FK reference |

**Total impact:** Significant UI polish beyond original plan scope, all user-requested.

### Scope Additions (User-Requested)

1. **Cairo font** — user provided font files, requested replacement of NotoSansArabic
2. **Comprehensive theme fixes** — cards, inputs, nav bar, dialogs all needed white backgrounds
3. **Bottom sheet store picker** — replaced DropdownButtonFormField across 3 screens
4. **KPI card, store list, user list** — all needed Card wrapping for visual separation

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**PHASE 4 COMPLETE — MILESTONE v0.1 COMPLETE**

All 5 plans delivered:
- 04-01: Discount UX (countdown, print blocking, cancellation)
- 04-02: Date range filters + driver performance
- 04-03: Package alert thresholds + balance adjustment
- 04-04: In-app update + performance optimizations
- 04-05: Offline hardening + brand polish

**Blockers:** None

---
*Phase: 04-polish-hardening, Plan: 05*
*Completed: 2026-03-22*
