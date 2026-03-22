# Roadmap: Dream Land Shopping — Tawzii

## Overview

From zero to a production-ready wholesale distribution app in 4 phases. Phase 1 proves the core loop (driver takes order, owner sees it). Phase 2 adds financial and packaging accountability. Phase 3 gives the owner full operational visibility. Phase 4 hardens for daily field use. v0.2 adds business intelligence: admin expansion, procurement, and inventory.

## Milestones

### v0.1 Initial Release (v0.1.0) — COMPLETE
Status: Complete
Phases: 4 of 4 complete (Phases 1-4)
Completed: 2026-03-22

### v0.2 Business Intelligence & Procurement (v0.2.0) — IN PROGRESS
Status: In progress
Phases: 0 of 3 complete (Phases 5-7)

## Phases

| Phase | Name | Plans | Status | Completed |
|-------|------|-------|--------|-----------|
| 1 | Core Loop | 4 | Complete | 2026-03-21 |
| 2 | Money & Packaging | 3 | Complete | 2026-03-22 |
| 3 | Visibility & Control | 4 | Complete | 2026-03-22 |
| 4 | Polish & Hardening | 5 | Complete | 2026-03-22 |
| 5 | Admin Expansion + Store Creation | TBD | Not started | - |
| 6 | Procurement & Cost Tracking | TBD | Not started | - |
| 7 | Stock & Inventory | TBD | Not started | - |

## Phase Details

### Phase 1: Core Loop

**Goal:** A driver can take an order at a store and the owner can see it — end-to-end data flow works.
**Depends on:** Nothing (first phase)

**Plans:**
- [x] 01-01: Project foundation (Flutter scaffold + Supabase schema + Drift setup)
- [x] 01-02: Auth system (login/logout, role-based routing)
- [x] 01-03: Product & Store CRUD
- [x] 01-04: Order creation + receipt preview

### Phase 2: Money & Packaging

**Goal:** Full financial and packaging accountability — payments tracked, per-product packages counted, Bluetooth receipts printing.
**Depends on:** Phase 1

**Plans:**
- [x] 02-01: Payment collection + credit balance tracking
- [x] 02-02: Per-product package tracking + standalone collection
- [x] 02-03: Bluetooth receipt printing

### Phase 3: Visibility & Control

**Goal:** Owner has full operational visibility — dashboard with metrics, live driver map, discount approval control.
**Depends on:** Phase 2

**Plans:**
- [x] 03-01: Owner dashboard (KPI metrics, top debtors, package alerts)
- [x] 03-02: Driver GPS tracking + live map (OpenStreetMap)
- [x] 03-03: Discount approval flow (request → notify → approve/reject → auto-reject)
- [x] 03-04: Drill-down views + admin user management

### Phase 4: Polish & Hardening

**Goal:** Production-hardened app ready for daily field use.
**Depends on:** Phase 3

**Plans:**
- [x] 04-01: Discount UX polish (countdown timer, print blocking) + order cancellation
- [x] 04-02: Date range filters + driver performance view
- [x] 04-03: Package alert thresholds + owner manual balance adjustment
- [x] 04-04: In-app update check + performance tuning
- [x] 04-05: Offline hardening + printer recovery + DriverLocation retention + brand polish

### Phase 5: Admin Expansion + Store Creation

**Goal:** Give admins meaningful operational visibility and let drivers create stores in the field with map location.
**Depends on:** Phase 4 (all v0.1 features stable)
**Research:** Unlikely (extending existing patterns)

**Scope:**
- Admin dashboard-lite (revenue, orders, payments, packages visibility)
- Admin can manage products (view/create/edit — currently owner-only)
- Admin gets more tabs (payments, packages, dashboard)
- Drivers can create stores directly in the field
- Store location picker on OpenStreetMap (tap to set coordinates)
- Store location displayed on store detail screen

**Plans:**
- [ ] 05-01: TBD during /paul:plan

### Phase 6: Procurement & Cost Tracking

**Goal:** Track what the business buys (cost) vs what it sells (revenue) to calculate profit margins.
**Depends on:** Phase 5 (admin can manage products with cost fields)
**Research:** Likely (purchase order data model, supplier entity)

**Scope:**
- Cost price field on products (buy price vs sell price)
- Supplier management (name, contact, basic CRUD)
- Purchase orders (date, supplier, products, quantities, cost)
- Purchase order history with date filters
- Profit margin display per product (sell - cost)
- Dashboard profit/margin KPI cards
- Purchase receipt/record

**Plans:**
- [ ] 06-01: TBD during /paul:plan

### Phase 7: Stock & Inventory

**Goal:** Track current stock levels, deduct on orders, replenish from purchases, alert on low stock.
**Depends on:** Phase 6 (purchase orders feed stock replenishment)
**Research:** Likely (stock movement patterns, inventory data model)

**Scope:**
- Stock quantity field per product (current inventory level)
- Automatic stock deduction when order is created
- Stock replenishment from purchase orders
- Low stock threshold per product (configurable)
- Low stock alerts on dashboard (new section)
- Stock movement history log (orders out, purchases in, manual adjustments)
- Stock adjustment screen (manual corrections with reason)

**Plans:**
- [ ] 07-01: TBD during /paul:plan

---
*Roadmap created: 2026-03-21*
*Last updated: 2026-03-22*
