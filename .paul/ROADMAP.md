# Roadmap: Dream Land Shopping — Tawzii

## Overview

From zero to a production-ready wholesale distribution app in 4 phases. Phase 1 proves the core loop (driver takes order, owner sees it). Phase 2 adds financial and packaging accountability. Phase 3 gives the owner full operational visibility. Phase 4 hardens for daily field use.

## Current Milestone

**v0.1 Initial Release** (v0.1.0)
Status: In progress
Phases: 2 of 4 complete

## Phases

| Phase | Name | Plans | Status | Completed |
|-------|------|-------|--------|-----------|
| 1 | Core Loop | 4 | Complete | 2026-03-21 |
| 2 | Money & Packaging | 3 | Complete | 2026-03-22 |
| 3 | Visibility & Control | TBD | Not started | - |
| 4 | Polish & Hardening | TBD | Not started | - |

## Phase Details

### Phase 1: Core Loop

**Goal:** A driver can take an order at a store and the owner can see it — end-to-end data flow works.
**Depends on:** Nothing (first phase)
**Research:** Likely (Drift sync queue patterns, Supabase + Flutter offline-first architecture)

**Scope:**
- Supabase project setup (tables, RLS policies, auth)
- Flutter project scaffold (RTL, Arabic, Material 3 with orange `#F5A623` theme)
- Auth flow (login/logout, role-based routing to correct bottom nav)
- Product catalog CRUD (Owner/Admin)
- Store registry CRUD (Admin/Driver)
- Order creation flow (select store → add products → confirm)
- On-screen receipt preview
- Drift local database + sync queue (offline-first foundation)

**Plans:**
- [ ] 01-01: Project foundation (Flutter scaffold + Supabase schema + Drift setup)
- [ ] 01-02: Auth system (login/logout, role-based routing)
- [ ] 01-03: Product & Store CRUD
- [ ] 01-04: Order creation + receipt preview

### Phase 2: Money & Packaging

**Goal:** Full financial and packaging accountability — payments tracked, per-product packages counted, Bluetooth receipts printing.
**Depends on:** Phase 1 (order flow, store/product entities, sync infrastructure)
**Research:** Likely (Bluetooth thermal printer SDK, Arabic character encoding on thermal printers)

**Scope:**
- Payment collection flow (driver → store → amount → confirm)
- Store financial ledger (credit_balance tracking, transaction history)
- Per-product per-store package tracking (PackageLog with product_id)
- Standalone package collection screen (returns without an order)
- Order update: auto-calculate packages_given, prompt for packages_collected
- Bluetooth receipt printing (orders + payments)
- Real-time payment notifications to owner

**Plans:**
- [ ] 02-01: Payment collection + credit balance tracking
- [ ] 02-02: Per-product package tracking + standalone collection
- [ ] 02-03: Bluetooth receipt printing

### Phase 3: Visibility & Control

**Goal:** Owner has full operational visibility — dashboard with metrics, live driver map, discount approval control.
**Depends on:** Phase 2 (payment data, package data for dashboard metrics)
**Research:** Likely (OpenStreetMap tile servers, flutter_map real-time pin updates)

**Scope:**
- Owner dashboard (today's revenue, order count, top debtors, package alerts)
- Driver GPS tracking (on-duty toggle, 30s broadcast)
- Live driver map (OpenStreetMap, pins, tap for details)
- Discount approval flow (request → owner notification → approve/reject → 2-3 min auto-reject)
- Drill-down views: per-store, per-driver, per-product
- Admin user management (create/remove drivers)

**Plans:**
- [ ] 03-01: TBD during /paul:plan
- [ ] 03-02: TBD

### Phase 4: Polish & Hardening

**Goal:** Production-hardened app ready for daily field use — updates, filters, alerts, edge case handling.
**Depends on:** Phase 3 (all features exist, now polish and harden)
**Research:** Unlikely (internal patterns, refinement)

**Scope:**
- In-app update check (AppConfig version comparison, download prompt)
- Date range filters on all list/history views
- Package alert thresholds (configurable, flag stores exceeding N)
- Driver performance view (orders, payments, activity timeline)
- Owner manual balance adjustment (with reason log)
- DriverLocation 7-day retention (scheduled Supabase function)
- Offline edge cases: sync queue ordering, conflict resolution (server timestamp wins)
- Printer disconnection recovery (save order, reprint later)
- Order cancellation flow

**Plans:**
- [ ] 04-01: TBD during /paul:plan

---
*Roadmap created: 2026-03-21*
*Last updated: 2026-03-21*
