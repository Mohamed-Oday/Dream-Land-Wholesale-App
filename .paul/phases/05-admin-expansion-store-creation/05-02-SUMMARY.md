---
phase: 05-admin-expansion-store-creation
plan: 02
subsystem: ui, stores, location
tags: [flutter-map, openstreetmap, geolocator, store-creation, driver-shell]

requires:
  - phase: 03-02
    provides: flutter_map + latlong2 packages, OSM tile pattern
  - phase: 01-03
    provides: Store CRUD, store_form_screen, store_detail_screen
provides:
  - Store location picker (embedded flutter_map with tap-to-set)
  - GPS auto-center on current position for new stores
  - Store detail mini-map (conditional on coordinates)
  - Driver Stores tab (5-tab driver shell)
  - Safe insert pattern for driver RLS compatibility
affects: []

tech-stack:
  added: []
  patterns:
    - "GPS auto-center: Geolocator.getCurrentPosition() with 5s timeout, falls back to Algiers default"
    - "Safe insert: .insert().select() without .single() to avoid PGRST116 on driver RLS"
    - "Conditional map: only render FlutterMap when gps_lat/gps_lng are non-null"

key-files:
  created: []
  modified:
    - lib/features/stores/repositories/store_repository.dart
    - lib/features/stores/screens/store_form_screen.dart
    - lib/features/stores/screens/store_detail_screen.dart
    - lib/features/driver/screens/driver_shell.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Map auto-centers on driver's current GPS position when creating new stores (user-requested)"
  - "Safe insert pattern: .select() without .single() to handle driver RLS returning 0 rows on chained SELECT"
  - "SimpleAttributionWidget matches existing driver_map_screen.dart pattern (audit finding)"
  - "Driver can create stores but NOT edit them (no stores_driver_update RLS — deferred)"

duration: ~30min
completed: 2026-03-22
---

# Phase 5 Plan 02: Store Location Picker + Driver Store Creation Summary

**OpenStreetMap location picker on store form with GPS auto-center, mini-map on store detail, and driver Stores tab for field store creation.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~30 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files modified | 6 |
| L10n strings added | 3 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Store Form Has Location Picker | Pass | Embedded flutter_map with tap-to-set, red pin marker, remove button |
| AC-2: Store Created With Coordinates | Pass | gps_lat/gps_lng saved on create/update, persist on edit |
| AC-3: Store Detail Shows Location Map | Pass | Mini-map with marker when coordinates exist, hidden when null |
| AC-4: Driver Can Create Stores | Pass | 5-tab driver shell, FAB creates stores, RLS insert works |

## Accomplishments

- Store form embeds OpenStreetMap with tap-to-place red pin marker
- Map auto-centers on driver's current GPS position (Geolocator with 5s timeout)
- Falls back to Algiers default (36.75, 3.06) if GPS unavailable
- Store detail shows conditional mini-map card when coordinates exist
- Driver shell expanded from 4 to 5 tabs (Orders, Packages, Payments, Stores, Settings)
- Safe insert pattern fixes PGRST116 error for driver RLS
- OSM attribution widget on all maps (SimpleAttributionWidget)
- 3 l10n strings added: storeLocation, tapToSetLocation, removeLocation

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 1 | GPS auto-center (user-requested, improves field UX) |
| Auto-fixed | 1 | Safe insert for driver RLS compatibility |

**Total impact:** Both deviations improve production readiness.

### Scope Additions (User-Requested)

1. **GPS auto-center** — User noted that in real-life, a driver discovers a new store and the map should center on their current location. Added `_resolveCurrentLocation()` using `Geolocator.getCurrentPosition()` with 5s timeout, checking existing permissions without requesting new ones.

### Auto-fixed Issues

1. **PGRST116 on driver store creation** — `.insert().select().single()` threw "0 rows" for drivers because PostgREST's chained SELECT after INSERT didn't return the row under driver RLS policies. Fixed by using `.select()` without `.single()` and returning `rows.first` or fallback data.

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**PHASE 5 COMPLETE — All 2 plans delivered:**
- 05-01: Admin Tab Expansion (dashboard-lite + products)
- 05-02: Store Location Picker + Driver Store Creation

**Ready:**
- Phase 6: Procurement & Cost Tracking can proceed
- All store, product, and admin infrastructure in place

**Concerns:**
- Driver can't edit stores after creation (no UPDATE RLS) — low priority, admin/owner can fix

**Blockers:**
- None

---
*Phase: 05-admin-expansion-store-creation, Plan: 02*
*Completed: 2026-03-22*
