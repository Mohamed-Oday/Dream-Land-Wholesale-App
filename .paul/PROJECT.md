# Dream Land Shopping — Tawzii

## What This Is

A mobile-first Arabic (RTL) wholesale distribution management app for a B2B bread/food distribution business in Algeria. Drivers operate as mobile salespeople — visiting stores on routes, taking orders, delivering products, collecting returnable packaging, and collecting payments. All transactions print via Bluetooth and sync in real-time to the owner's dashboard. Three roles: Owner (full visibility), Admin (manage drivers), Driver (field operations).

## Core Value

Owner gets real-time visibility into wholesale distribution field operations — orders, payments, returnable packaging, and driver locations — replacing paper-based tracking that causes cash leakage and packaging loss.

## Current State

| Attribute | Value |
|-----------|-------|
| Version | 0.2.0 |
| Status | Pre-production |
| Last Updated | 2026-03-22 |

## Requirements

### Validated (Shipped)

- [x] Phase 1: Core Loop — Auth, product catalog, store registry, order creation, receipt preview — v0.1
- [x] Phase 2: Money & Packaging — Payment collection, per-product package tracking, Bluetooth printing — v0.1
- [x] Phase 3: Visibility & Control — Owner dashboard, GPS tracking, live map, discount approval — v0.1
- [x] Phase 4: Polish & Hardening — In-app updates, filters, alerts, edge cases — v0.1
- [x] Phase 5: Admin Expansion — Admin dashboard, store location picker, driver store creation — v0.2
- [x] Phase 6: Procurement — Suppliers, purchase orders, profit margins — v0.2
- [x] Phase 7: Stock & Inventory — Stock tracking, low stock alerts, adjustment, movement history — v0.2

### Active (In Progress)

None — milestone v0.2 complete

### Planned (Next)

To be defined via /paul:discuss-milestone

### Out of Scope

- Store-facing portal or app — not needed for MVP
- Multi-language support — Arabic only
- Route optimization — manual routes for now
- Advanced analytics / Excel export — basic dashboard only
- Multiple payment methods — cash only
- Product images — text catalog sufficient
- Multi-tenant — single business (but business_id on all tables for future)
- iOS — Android APK sideload only

## Target Users

**Primary:** Business Owner
- Wholesale distribution business (bread/food products)
- Needs real-time visibility into field operations
- Currently has zero digital insight into driver activity, payments, packaging
- Goal: Know exactly what's happening in the field at all times

**Secondary:** Drivers (<10)
- Mobile salespeople visiting 10-20 stores
- Need fast order entry, receipt printing, package logging
- Work in the field — one-handed use, sunlight, unreliable connectivity
- Goal: Complete transactions quickly and move to next store

**Tertiary:** Admins
- Manage driver accounts and view operational data
- Bridge between owner and drivers

## Context

**Business Context:**
- Algerian wholesale distribution (DA currency)
- Bread is MVP product category, architecture supports multiple categories
- Returnable packaging (crates/trays) is a significant business concern — losses are costly
- Drivers collect cash — audit trail is critical for trust
- 10-20 stores, <10 drivers — small scale, high operational need

**Technical Context:**
- Flutter for single Android codebase with strong RTL/Arabic support
- Supabase Free Tier for backend (500MB DB, 50K MAU — well within limits)
- Drift (SQLite) for offline-first local storage with sync queue
- OpenStreetMap + flutter_map for free GPS visualization
- Bluetooth thermal printer for receipts (specific model TBD)
- APK sideload distribution (no app store)

## Constraints

### Technical Constraints
- Must run on Android (APK sideload)
- Must work offline with sync-when-connected
- Must support RTL Arabic layout throughout
- Must print receipts via Bluetooth thermal printer
- Supabase Free Tier limits: 500MB DB, 50K MAU, 2GB bandwidth

### Business Constraints
- Zero cost for backend infrastructure (Supabase free tier)
- No SMS/OTP costs — username/password auth only
- No Google Maps API costs — OpenStreetMap only
- Single business operation (not multi-tenant in MVP)

### Compliance Constraints
- None — private business tool, not handling EU personal data

## Key Decisions

| Decision | Rationale | Date | Status |
|----------|-----------|------|--------|
| Drift over Hive | Type-safe reactive SQL maps to Postgres schema | 2026-03-21 | Active |
| OpenStreetMap over Google Maps | Free, no API key, sufficient for <10 pins | 2026-03-21 | Active |
| Per-product package counts (not serial) | Matches business complexity without over-engineering | 2026-03-21 | Active |
| Username/password for all roles | Eliminates SMS/OTP costs | 2026-03-21 | Active |
| business_id on all tables | Zero-cost multi-tenancy future-proofing | 2026-03-21 | Active |
| Separate package collection screen | Standalone return visits are common | 2026-03-21 | Active |
| Discount auto-reject (2-3 min timeout) | Prevents field blocking | 2026-03-21 | Active |
| Append-only DriverLocation (7-day retention) | History without unbounded growth | 2026-03-21 | Active |
| In-app update via AppConfig | No Play Store dependency | 2026-03-21 | Active |
| Mobile-only (no web dashboard) | Same Flutter app for all roles, reduces scope | 2026-03-21 | Active |

## Success Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Order digitization | 100% of orders through app | 0% | Not started |
| Payment audit trail | Every payment recorded with balance | None | Not started |
| Package tracking | Per-product per-store balance accurate | None | Not started |
| Real-time visibility | Owner sees orders/payments within 3s | None | Not started |
| Offline reliability | Orders sync correctly after reconnect | None | Not started |

## Tech Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| Mobile | Flutter (Dart) | Single Android codebase, strong RTL support |
| Backend | Supabase Free Tier | Postgres + Realtime + Auth + Edge Functions + RLS |
| Local DB | Drift (SQLite) | Offline-first, type-safe, reactive queries |
| Maps | OpenStreetMap + flutter_map | Free, no API key |
| Bluetooth | esc_pos_bluetooth / flutter_blue_plus | TBD based on printer model |
| State Mgmt | Riverpod | Validated in Phase 1, used throughout |

## Links

| Resource | URL |
|----------|-----|
| PLANNING.md | projects/dream-land-shopping/PLANNING.md |
| PRD | PRD.md |

---
*PROJECT.md — Updated when requirements or context change*
*Last updated: 2026-03-22 after v0.2 Business Intelligence & Procurement*
