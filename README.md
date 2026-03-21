# Dream Land Shopping — Tawzii

> Mobile-first Arabic (RTL) wholesale distribution management app for B2B field operations: orders, payments, returnable packaging tracking, Bluetooth receipt printing, and real-time owner visibility.

**Type:** Application
**Stack:** Flutter + Supabase + Drift (SQLite) + OpenStreetMap
**Skill Loadout:** PAUL, CARL, UI UX Pro Max
**Quality Gates:** Offline sync integrity, RLS validation, RTL layout correctness, Bluetooth print test, real-time latency (<3s)

---

## Overview

A wholesale distribution business in Algeria has zero real-time visibility into field operations. Drivers deliver products (primarily bread), collect payments, and manage returnable packaging — all tracked by memory and paper. This app digitizes the entire workflow:

- **Drivers** take orders, print Bluetooth receipts, collect payments, and log package returns
- **Admins** manage drivers and view operational data
- **Owner** gets a real-time dashboard with GPS tracking, revenue metrics, and discount approval control

Scale: <10 drivers, 10-20 stores. Single business (with `business_id` on all tables for future multi-tenancy). Android only, distributed via APK sideload.

---

## Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Mobile | Flutter (Dart) | Single codebase, strong RTL/Arabic support, Bluetooth libraries |
| Backend | Supabase Free Tier | Postgres + Realtime + Auth + Edge Functions + RLS included |
| Local DB | Drift (SQLite) | Type-safe reactive queries, powers offline-first sync queue |
| Maps | OpenStreetMap + flutter_map | Free, no API key, sufficient for <10 driver pins |
| Bluetooth | esc_pos_bluetooth / flutter_blue_plus | Thermal receipt printing (TBD based on printer model) |

---

## Data Model

| Entity | Key Fields | Relationships |
|--------|-----------|---------------|
| User | id, business_id, name, username, password_hash, role (owner\|admin\|driver), created_by, active | Owner creates Admins, Admins create Drivers |
| Store | id, business_id, name, address, phone, contact_person, gps_lat, gps_lng, credit_balance | Has many Orders, Payments, PackageLogs |
| Product | id, business_id, name, unit_price, units_per_package, has_returnable_packaging (bool), active | Referenced by OrderLines and PackageLogs |
| Order | id, business_id, store_id, driver_id, subtotal, tax_percentage, tax_amount, discount, discount_status, total, status | Has many OrderLines, may trigger PackageLogs |
| OrderLine | id, order_id, product_id, quantity, unit_price, packages_count (nullable), line_total | Belongs to Order and Product |
| Payment | id, business_id, store_id, driver_id, amount, method, previous_balance, new_balance | Belongs to Store and Driver |
| PackageLog | id, business_id, store_id, driver_id, product_id, order_id (nullable), given, collected, balance_after | Per-product per-store package tracking |
| DriverLocation | driver_id, business_id, lat, lng, timestamp | Append-only, 7-day retention |
| AppConfig | id, business_id, key, value | latest_version, download_url, thresholds |

**Key design notes:**
- PackageLog tracks per-product per-store balances (not global counters)
- `business_id` on all tables for future multi-tenancy (single value for MVP)
- DriverLocation is append-only with scheduled 7-day purge
- `credit_balance` on Store is denormalized, kept in sync by Edge Functions

---

## API Surface

**Auth:** Username + password for all roles via Supabase Auth with custom role claims. No OTP.

**PostgREST (auto-generated CRUD):** products, stores, orders, order_lines, payments, package_logs, driver_locations — all protected by RLS.

**Edge Functions:**
- `discount-request` — driver sends request, owner notified, 2-3 min auto-reject timeout
- `recalc-balance` — triggered after order/payment to keep store credit_balance consistent

**Realtime Channels:**
- `payments` — owner notifications on payment collection
- `discount-requests` — owner ↔ driver approval flow
- `driver-locations` — owner's live map
- `orders` — dashboard refresh

---

## Deployment

- **Backend:** Supabase cloud free tier (500MB DB, 50K MAU, 2GB bandwidth)
- **Mobile:** APK sideload via WhatsApp/direct download
- **Updates:** AppConfig table with latest_version + download_url, in-app check on launch
- **Future:** Google Play listing when stable
- **No CI/CD for MVP** — manual build and distribution

---

## Security

- **RLS enforcement:** Drivers see own data only, Admins see their drivers, Owner sees all — scoped by business_id
- **Audit trail:** Immutable payment records (previous_balance → new_balance), discount request logs
- **GPS privacy:** Location tracked only while on-duty, 7-day retention
- **Secrets:** Supabase anon key in client (by design), service role key in Edge Functions only
- **Rate limiting:** Edge Function built-in limits + 30s client-side GPS throttle

---

## UI/UX

**Brand:** Orange/Amber `#F5A623` primary (from logo), white on-primary, Material Design 3 with orange seed color. Noto Sans Arabic typography. Full RTL layout, numbers LTR.

**Design principles:** Large tap targets (one-handed field use), high contrast, minimal text, functional over flashy.

**Driver (Bottom Nav — 4 tabs):** Orders | Packages | Payments | Settings
**Owner (Bottom Nav — 4 tabs):** Dashboard | Map | Stores | Settings
**Admin (Bottom Nav — 3 tabs):** Drivers | Stores | Settings

**Real-time:** Supabase Realtime for payment notifications, discount approvals, GPS updates, dashboard refresh.

---

## Implementation Phases

### Phase 1: Core Loop
Auth, product catalog CRUD, store registry CRUD, order creation flow, on-screen receipt preview, Drift local DB + sync queue, Flutter scaffold (RTL, Arabic, orange Material 3 theme).
**Outcome:** Driver takes an order, owner sees it.

### Phase 2: Money & Packaging
Payment collection, store financial ledger, per-product package tracking, standalone package collection screen, Bluetooth receipt printing, real-time payment notifications.
**Outcome:** Full financial and packaging accountability with printed receipts.

### Phase 3: Visibility & Control
Owner dashboard (metrics, drill-downs), driver GPS tracking + live map, discount approval flow (request → timeout → resolve), admin user management.
**Outcome:** Owner has full operational visibility and discount control.

### Phase 4: Polish & Hardening
In-app update check, date range filters, package alert thresholds, driver performance view, manual balance adjustment, 7-day location retention, offline edge cases, order cancellation.
**Outcome:** Production-hardened app ready for daily field use.

---

## Design Decisions

1. **Drift over Hive** — type-safe reactive SQL maps to Postgres schema
2. **OpenStreetMap over Google Maps** — free, no API key, sufficient for <10 pins
3. **Per-product package counts (not serial tracking)** — matches business complexity
4. **Username/password for all roles (no OTP)** — eliminates SMS costs
5. **business_id on all tables** — zero-cost multi-tenancy future-proofing
6. **Separate package collection screen** — standalone return visits are common
7. **Discount auto-reject on 2-3 min timeout** — prevents field blocking
8. **Append-only DriverLocation with 7-day retention** — history without unbounded growth
9. **In-app update via AppConfig** — no Play Store dependency
10. **Mobile-only (no web dashboard)** — same Flutter app for all roles, different nav

---

## Open Questions

1. **Printer model?** Blocking for Phase 2 Bluetooth SDK selection
2. **State management — Riverpod or Bloc?** Deferred to Phase 1
3. **Arabic thermal printer support?** Need hardware verification
4. **Discount timeout duration?** 2 min, 3 min, or owner-configurable?

---

## References

- PLANNING.md: `projects/dream-land-shopping/PLANNING.md`
- PRD: `PRD.md` (workspace root)
- Supabase Free Tier: 500MB DB, 50K MAU, 2GB bandwidth, 500K Edge Function invocations

---

*Last updated: 2026-03-21*
