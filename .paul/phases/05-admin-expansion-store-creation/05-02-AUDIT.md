# Enterprise Plan Audit Report

**Plan:** phases/05-admin-expansion-store-creation/05-02-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally Acceptable (now enterprise-ready after applying fixes)

---

## 1. Executive Verdict

**Conditionally acceptable** — upgraded to enterprise-ready after applying 1 must-have and 1 strongly-recommended fix.

The plan is well-researched: pre-verified that gps columns exist, driver RLS policies exist, flutter_map is already a dependency. Zero migrations needed. The scope is tight — tap-to-set location, no geocoding, no GPS auto-detection. Good discipline.

Would I sign off? **Yes**, after the applied fixes.

## 2. What Is Solid

- **Zero-migration design:** Correctly identified that `gps_lat`/`gps_lng` columns and `stores_driver_insert` RLS already exist. No schema changes avoids deployment risk.
- **Existing package reuse:** flutter_map and latlong2 already in pubspec. No new dependencies.
- **Scope boundaries:** Explicitly excludes geocoding, "use my location" button, store markers on driver map. Prevents scope creep.
- **Conditional detail map:** Only renders when coordinates exist. No empty map states to handle.
- **Driver tab placement:** Stores inserted at position 4 (before Settings), preserving existing tab order. Muscle memory preserved for drivers.
- **OSM attribution required:** Plan correctly specifies attribution widget (required by OSM tile usage policy).

## 3. Enterprise Gaps Identified

### Gap 1: Wrong attribution widget (compile risk)
Plan specifies `RichAttributionWidget` with `TextSourceAttribution` but existing codebase (`driver_map_screen.dart:173`) uses `SimpleAttributionWidget` with `source: Text(...)`. Either the API doesn't exist in this flutter_map version or creates visual inconsistency.

### Gap 2: Map accepts taps during save
Text fields use `enabled: !_isLoading` to prevent edits during save. Map `onTap` has no such guard — user could change location while the save request is in flight, causing the saved coordinates to differ from what's displayed.

### Gap 3: Driver can't edit stores (deferred)
Driver has `stores_driver_insert` but no `stores_driver_update`. After creating a store, the edit button is visible on StoreDetailScreen but `repo.update()` would throw an RLS error. Not blocking for CREATE scope, but creates a confusing UX path.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Wrong attribution widget | Task 1 Steps 3 & 4 | Changed `RichAttributionWidget(attributions: [TextSourceAttribution(...)])` to `SimpleAttributionWidget(source: Text(...))` matching existing codebase |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Map taps during save | Task 1 Step 3 (onTap callback) | Added `if (!_isLoading)` guard before setState in onTap |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Driver can't edit stores (no UPDATE RLS) | Plan scope is CREATE, not edit. Admin/owner can fix driver mistakes. Adding UPDATE policy would expand scope. Can be added in a future plan if field feedback shows drivers need edit capability. |

## 5. Audit & Compliance Readiness

**Audit evidence:** Store coordinates are standard database columns with nullable DOUBLE PRECISION — auditable via SQL queries. No side effects beyond INSERT/UPDATE. Location data is business-operational (store address), not personal tracking.

**Silent failure prevention:** Save errors display `_errorMessage` in the form. Map conditionally renders based on data presence. No silent drops.

**Post-incident reconstruction:** Coordinates stored in `gps_lat`/`gps_lng` columns with `created_at` timestamp. Standard Supabase audit trail.

**Ownership:** Changes span 4 feature files + 2 l10n files. Clear ownership boundaries (stores feature + driver shell).

## 6. Final Release Bar

**What must be true before shipping:**
- `SimpleAttributionWidget` renders correctly on all maps (form picker + detail mini-map)
- Map tap guard prevents coordinate changes during save
- Driver can create a store with coordinates without RLS error
- Editing a store as owner/admin preserves and updates coordinates

**Remaining risks if shipped as-is (after fixes):**
- Low: Driver sees edit button on stores but can't use it (RLS blocks UPDATE). Confusing but non-breaking — shows error message.

**Sign-off:** I would approve this plan for production after the applied fixes.

---

**Summary:** Applied 1 must-have + 1 strongly-recommended upgrade. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
