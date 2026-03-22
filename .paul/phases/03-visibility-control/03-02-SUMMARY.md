---
phase: 03-visibility-control
plan: 02
subsystem: location
tags: [gps, flutter-map, openstreetmap, geolocator, real-time-tracking]

requires:
  - phase: 01-01
    provides: Auth system (driver identity, role-based routing)
provides:
  - Driver on-duty toggle with GPS tracking (30s broadcast)
  - Owner live map with OpenStreetMap + driver pins
  - LocationService for GPS permission + position streaming
  - LocationRepository for Supabase driver_locations inserts
  - Supabase RPC get_latest_driver_locations for owner map data
affects: [phase-3-discount-approval, phase-4-retention-cleanup, phase-4-performance]

tech-stack:
  added:
    - flutter_map ^7.0.2
    - latlong2 ^0.9.1
    - geolocator ^13.0.2
  patterns:
    - "On-duty toggle as persistent banner between body and bottom nav"
    - "LocationService wraps geolocator with stream + fallback timer"
    - "Silent insert failure for periodic GPS broadcasts (no error toast)"
    - "Supabase RPC with 1-hour window + active driver filter"

key-files:
  created:
    - supabase/migrations/005_location_functions.sql
    - lib/features/location/services/location_service.dart
    - lib/features/location/repositories/location_repository.dart
    - lib/features/location/providers/location_provider.dart
    - lib/features/location/screens/driver_map_screen.dart
  modified:
    - pubspec.yaml
    - android/app/src/main/AndroidManifest.xml
    - lib/features/driver/screens/driver_shell.dart
    - lib/features/owner/screens/owner_shell.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Foreground-only tracking — no background service, no workmanager"
  - "Silent insert failures — no error toast every 30s on network loss"
  - "Geolocator stream with fallback timer — handles devices where stream is unreliable"
  - "1-hour RPC window — only show drivers active in the last hour"
  - "Removed _PlaceholderScreen class from owner_shell — no more placeholders in app"

duration: ~20min
completed: 2026-03-22
---

# Phase 3 Plan 02: Driver GPS Tracking + Live Map Summary

**On-duty toggle banner in driver shell with 30s GPS broadcast, owner live map with OpenStreetMap tiles showing driver pins with tap-for-details bottom sheet, Supabase RPC for latest positions per active driver.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~20 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 5 |
| Files modified | 6 |
| Dependencies added | 3 (flutter_map, latlong2, geolocator) |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: On-Duty Toggle | Pass | Persistent banner between body and nav, switch + tap toggle |
| AC-2: Location Broadcasting | Pass | 30s interval via geolocator stream, inserts to Supabase |
| AC-3: Location Permission Flow | Pass | Checks GPS service + permission, reverts on deny |
| AC-4: Owner Map Shows Driver Pins | Pass | CircleAvatar markers with driver initial, auto-fit bounds |
| AC-5: Tap Driver Pin Shows Details | Pass | Bottom sheet with name + "last seen X min ago" |
| AC-6: Map Uses OpenStreetMap | Pass | OSM tiles, pinch-zoom, pan, attribution widget |
| AC-7: No Active Drivers Empty State | Pass | Overlay with location_off icon + Arabic message |

## Accomplishments

- On-duty toggle as persistent banner in driver shell (visible on all 4 tabs)
- LocationService with GPS service check + permission request + stream/fallback tracking
- Silent insert failure handling for 30s periodic broadcasts
- Owner live map with OpenStreetMap replacing last placeholder in app
- Driver markers with initial letter, tap for details bottom sheet
- Supabase RPC filtering by 1-hour window + active drivers only
- OSM attribution widget (required by tile usage policy)

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/005_location_functions.sql` | Created | RPC for latest driver positions with active filter |
| `lib/features/location/services/location_service.dart` | Created | GPS permission check + position stream with fallback |
| `lib/features/location/repositories/location_repository.dart` | Created | Insert positions + fetch latest via RPC |
| `lib/features/location/providers/location_provider.dart` | Created | Riverpod providers for location repo, service, on-duty state |
| `lib/features/location/screens/driver_map_screen.dart` | Created | Owner map with OSM tiles, driver markers, empty state |
| `pubspec.yaml` | Modified | Added flutter_map, latlong2, geolocator |
| `android/app/src/main/AndroidManifest.xml` | Modified | Added ACCESS_COARSE_LOCATION |
| `lib/features/driver/screens/driver_shell.dart` | Modified | Added on-duty toggle banner, converted to ConsumerStatefulWidget |
| `lib/features/owner/screens/owner_shell.dart` | Modified | Replaced Map placeholder with DriverMapScreen |
| `lib/core/l10n/app_ar.arb` | Modified | Added 4 location/map strings |
| `lib/core/l10n/app_en.arb` | Modified | Added 4 location/map strings |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | None |
| Deferred | 1 | Logged |

**Total impact:** Clean execution, no deviations from plan.

### Deferred Items

- Initial GPS cold start takes 30-60s (satellite acquisition). Not a bug — inherent to GPS. Subsequent updates arrive every ~30s as specified.

## Skill Audit

Skill audit: All required skills invoked ✓

| Skill | Phase | Invoked |
|-------|-------|---------|
| /ui-ux-pro-max | PLAN | ✓ |
| /frontend-design | APPLY | ✓ |

## Next Phase Readiness

**Ready:**
- GPS tracking infrastructure complete for Phase 3 Plan 03 (discount approval can use driver location context)
- No more placeholder screens in the app — all 4 tabs on both owner and driver are real
- Phase 3 Plan 03 (discount approval flow) can proceed independently

**Concerns:**
- ~30fps lag reported earlier (from Plan 03-01) — may worsen with map rendering. Deferred to Phase 4.
- Foreground-only tracking means positions stop when app is backgrounded

**Blockers:** None

---
*Phase: 03-visibility-control, Plan: 02*
*Completed: 2026-03-22*
