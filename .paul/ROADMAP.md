# Roadmap: Dream Land Shopping — Tawzii

## Overview

From zero to a production-ready wholesale distribution app in 4 phases. Phase 1 proves the core loop (driver takes order, owner sees it). Phase 2 adds financial and packaging accountability. Phase 3 gives the owner full operational visibility. Phase 4 hardens for daily field use. v0.2 adds business intelligence: admin expansion, procurement, and inventory.

## Milestones

### v0.1 Initial Release (v0.1.0) — COMPLETE
Status: Complete
Phases: 4 of 4 complete (Phases 1-4)
Completed: 2026-03-22

### v0.2 Business Intelligence & Procurement (v0.2.0) — COMPLETE
Status: Complete
Phases: 3 of 3 complete (Phases 5-7)
Completed: 2026-03-22

### v0.2.1 AEGIS Audit Remediation (v0.2.1)
Status: In Progress
Phases: 2 of 3 complete (Phases 8-10)
Source: `.aegis/report/AEGIS-REPORT.md` Section 5 — Remediation Roadmap

## Phases

| Phase | Name | Plans | Status | Completed |
|-------|------|-------|--------|-----------|
| 1 | Core Loop | 4 | Complete | 2026-03-21 |
| 2 | Money & Packaging | 3 | Complete | 2026-03-22 |
| 3 | Visibility & Control | 4 | Complete | 2026-03-22 |
| 4 | Polish & Hardening | 5 | Complete | 2026-03-22 |
| 5 | Admin Expansion + Store Creation | 2 | Complete | 2026-03-22 |
| 6 | Procurement & Cost Tracking | 3 | Complete | 2026-03-22 |
| 7 | Stock & Inventory | 2 | Complete | 2026-03-22 |
| 8 | Day-1 Fixes | 1 | Complete | 2026-03-23 |
| 9 | Security & Atomicity | 3 | Complete | 2026-03-23 |
| 10 | Structural Improvements | TBD | Not started | - |

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
- [x] 05-01: Admin Tab Expansion (Dashboard + Products tabs for admin shell)
- [x] 05-02: Store Location Picker + Driver Store Creation

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
- [x] 06-01: Suppliers + Product Cost Price (data foundation)
- [x] 06-02: Purchase Orders (create, list, detail with package pricing)
- [x] 06-03: Profit Margins + Dashboard KPIs

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
- [x] 07-01: Stock Data Model + Automatic Stock Flow (migration, RPCs, product stock display, order deduction, PO replenishment)
- [x] 07-02: Low Stock Alerts + Manual Stock Management (dashboard alerts, stock adjustment screen, movement history)

### Phase 8: Day-1 Fixes

**Goal:** Eliminate disproportionate risk with trivial one-line fixes. All items are <5 minutes each.
**Depends on:** Phase 7 (v0.2 complete)
**Source:** AEGIS Remediation Roadmap — Immediate tier
**Research:** None needed

**Scope:**
- Prevent Supabase free tier pause (upgrade or keep-alive cron)
- Fix version constant mismatch (0.1.0 → 0.2.0)
- Fix sync status text (remove false offline claim)
- Fix deactivation text or implement auth ban
- Fix broken location cleanup SQL (created_at → timestamp)
- Rename "Profit" to "Cash Flow" in l10n
- Revoke anon grants on 7 mutation RPCs

**Plans:**
- [x] 08-01: Day-1 fixes (version, l10n corrections, anon revokes, column fix)

### Phase 9: Security & Atomicity

**Goal:** Fix the critical security and data integrity issues — JWT metadata lockdown, atomic order creation, role checks, audit trail protection, deactivation enforcement, minimum test suite.
**Depends on:** Phase 8 (day-1 fixes applied)
**Source:** AEGIS Remediation Roadmap — Short-term tier
**Research:** Likely (Supabase auth hooks, app_metadata migration path)

**Scope:**
- Lock down JWT user_metadata (move to app_metadata or add trigger)
- Consolidate order creation into single atomic RPC (biggest single fix)
- Add role checks to all SECURITY DEFINER functions
- Fix balance_adjustments RLS (role-based, append-only)
- Make deactivation actually revoke access
- Write minimum test suite (~3 hours: _LineItem, financial calcs, SQL RPCs)
- Add startup version check with blocking dialog

**Plans:**
- [x] 09-01: SQL Security Hardening (JWT trigger, 7 role checks, append-only RLS)
- [x] 09-02: Atomic Order RPC + Deactivation + Version Check
- [x] 09-03: Minimum Test Suite (financial calcs + SQL RPC tests)

### Phase 10: Structural Improvements

**Goal:** Evolvability and maintainability improvements that prevent future issues as the codebase grows.
**Depends on:** Phase 9 (security hardened, tests exist)
**Source:** AEGIS Remediation Roadmap — Medium-term tier
**Research:** Unlikely (applying established patterns)

**Scope:**
- Create typed model classes (Order, OrderLine, Product, Store, Payment)
- Document role-operation matrix
- Add error logging (Supabase error_log table or Sentry)
- Add CHECK constraints (stock_on_hand >= 0, FOR UPDATE locking)
- Consolidate dashboard into single RPC (8 calls → 1)
- Add updated_at columns + cancelled_by/cancelled_at to orders
- Add package log reversal to cancellation flow
- Move inline RPC calls from screens into repositories
- Replace financial records FOR ALL with separate policies (no DELETE)

**Plans:**
- [ ] 10-01: TBD (defined during /paul:plan)

---
*Roadmap created: 2026-03-21*
*Last updated: 2026-03-23*
