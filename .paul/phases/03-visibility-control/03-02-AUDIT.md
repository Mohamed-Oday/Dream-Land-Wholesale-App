# Enterprise Plan Audit Report

**Plan:** .paul/phases/03-visibility-control/03-02-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable → Accepted after applying 2 must-have + 4 strongly-recommended upgrades

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **accepted** after applying findings.

The plan is well-structured with appropriate scope limits for MVP. However, two issues would have caused problems in production: an unnecessary dangerous permission that contradicts the stated scope, and a missing device-level GPS check that would crash the app if the user's GPS is turned off. Both corrected.

## 2. What Is Solid

- **Builds on existing infrastructure:** driver_locations table, RLS policies, indexes, and permission_handler are all already in place. This plan adds code on top without modifying stable foundations.
- **Scope limits are precise:** Foreground-only, no background service, no Realtime, no route history, no geofencing. Each exclusion is defensible for MVP.
- **On-duty toggle UX:** Persistent banner between body and bottom nav is the right pattern — visible on all tabs without modifying individual screens. Default off-duty on app launch prevents stale tracking.
- **Timer-based refresh:** Correct for <10 drivers. Supabase Realtime would add complexity with negligible benefit at this scale.
- **Empty state handling:** Specified for both the map (no active drivers) and the permission flow (denied → revert toggle).
- **RPC design:** DISTINCT ON for latest-per-driver with 1-hour window prevents stale data from appearing.

## 3. Enterprise Gaps Identified

### Gap 1: ACCESS_BACKGROUND_LOCATION contradicts scope (CRITICAL)
The plan adds `ACCESS_BACKGROUND_LOCATION` to AndroidManifest while simultaneously stating "Foreground-only tracking" in scope limits. This permission triggers Google Play policy review, requires a privacy policy disclosure, and shows a more alarming permission dialog to users. Since no background service is being built, the permission is unnecessary and harmful.

### Gap 2: Missing GPS service enabled check
The plan checks for location PERMISSION but not whether location SERVICES (GPS) are enabled on the device. `Geolocator.getCurrentPosition()` throws `LocationServiceDisabledException` if GPS is off. The app would crash or show an unhandled error when the driver taps on-duty with GPS disabled.

### Gap 3: Deactivated drivers appearing on map
The RPC joins `users` but doesn't filter by `users.active = true`. A driver who was deactivated by the admin but had recent location data would still appear on the owner's map as an active marker.

### Gap 4: Insert failure every 30s with no error handling
The location broadcast inserts to Supabase every 30 seconds. If the network drops, each insert throws an exception. Without try-catch, this would either crash the app or, if caught at widget level, potentially show an error toast every 30 seconds — terrible UX for a field worker.

### Gap 5: Missing OSM tile attribution
OpenStreetMap's tile usage policy requires attribution: "© OpenStreetMap contributors". flutter_map provides `RichAttributionWidget` for this. Missing attribution violates OSM terms and could result in tile access being blocked.

### Gap 6: ACCESS_FINE_LOCATION already exists
The plan adds `ACCESS_FINE_LOCATION` to the manifest, but it's already present at line 7 (added for Bluetooth scanning in Phase 2). Duplicate permission declaration is harmless but indicates incomplete codebase awareness.

### Gap 7: Migration deployment step missing
Same pattern as 03-01 — no verification step for deploying the migration before testing.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | ACCESS_BACKGROUND_LOCATION contradicts foreground-only scope | Task 1 action (AndroidManifest) | Removed ACCESS_BACKGROUND_LOCATION. Noted ACCESS_FINE_LOCATION already exists. Only ACCESS_COARSE_LOCATION needs adding. |
| 2 | Missing GPS service enabled check | Task 1 action (LocationService), AC-3 | Added `Geolocator.isLocationServiceEnabled()` check before permission request. AC-3 updated to include GPS-off scenario. |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 3 | Deactivated drivers on map | Task 1 action (RPC query) | Added `AND u.active = true` filter to RPC |
| 4 | Insert failure handling | Task 1 action (driver shell) | Added try-catch for insert, silent skip on failure, no error toast |
| 5 | OSM attribution missing | Task 2 action (DriverMapScreen) | Added RichAttributionWidget/SimpleAttributionWidget requirement |
| 6 | Migration deployment verification | Task 1 verify | Added deployment step to verify section |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 7 | Auto-refresh timer runs when Map tab not visible | For <10 drivers, network cost is negligible. Timer creates one lightweight RPC call per 30s. Phase 4 optimization candidate. |
| 8 | Geolocator version compatibility | Will be caught during `flutter pub get`. If version conflict, resolve at implementation time. |

## 5. Audit & Compliance Readiness

**Permission compliance:** Removing `ACCESS_BACKGROUND_LOCATION` prevents triggering Google Play's background location policy review. The remaining permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) are standard for foreground GPS apps and require no special disclosure beyond Android's runtime permission dialog.

**Silent failure prevention:** The GPS service check prevents a crash when GPS is disabled. The insert try-catch prevents repeated error disruption during normal field use with spotty connectivity.

**Data isolation:** The RPC includes business_id authorization check matching the established pattern. RLS policies on driver_locations ensure drivers can only insert their own data.

**Post-incident reconstruction:** Location data is append-only (INSERT, no UPDATE/DELETE from app). Full history exists in driver_locations table for audit purposes.

## 6. Final Release Bar

**What must be true before this plan ships:**
- No ACCESS_BACKGROUND_LOCATION in manifest
- GPS service check before tracking starts
- RPC filters out inactive drivers
- Insert failures handled silently
- OSM attribution displayed on map

**Remaining risks if shipped as-is (after fixes):**
- Foreground-only: tracking stops when app is backgrounded (acceptable for MVP)
- No offline location caching: positions lost if no network (acceptable — driver retries naturally)
- Timer refresh on invisible tab: minor network waste (negligible at this scale)

**Sign-off:** With the applied upgrades, I would approve this plan for production.

---

**Summary:** Applied 2 must-have + 4 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
