# Milestones

Completed milestone log for this project.

| Milestone | Completed | Duration | Stats |
|-----------|-----------|----------|-------|
| v0.1 Initial Release | 2026-03-22 | ~1 day | 4 phases, 16 plans |
| v0.2 Business Intelligence & Procurement | 2026-03-22 | ~1 day | 3 phases, 7 plans |

---

## v0.2 Business Intelligence & Procurement

**Completed:** 2026-03-22
**Duration:** ~2.5 hours (145 min across 7 plans)

### Stats

| Metric | Value |
|--------|-------|
| Phases | 3 |
| Plans | 7 |
| Files created | 13 |
| Files modified | 20 |
| Total files | 33 |

### Key Accomplishments

- Admin dashboard-lite with 3 sections (orders, debtors, packages) + 5-tab shell expansion
- Store location picker on OpenStreetMap with GPS auto-center for field store creation
- Supplier management (CRUD) + product cost_price column for procurement tracking
- Purchase order system (create, list, detail) with package-level pricing
- Owner dashboard expanded to 4 KPI cards (revenue, orders, purchases, profit with green/red)
- Product margin percentage badges on product list (color-coded)
- Stock tracking: stock_on_hand per product with automatic deduction on orders
- Stock replenishment from purchase orders + restoration on order cancellation
- Stock enforcement on order creation (out-of-stock disabled, quantity capped)
- Low stock alerts on dashboard with configurable thresholds
- Stock adjustment screen with projected result validation
- Stock movement history per product (4 movement types with distinct icons)

### Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| Dart-side column filtering for low stock | PostgREST can't compare columns | 07-02 |
| Stock enforcement at UI level, not DB CHECK | Owner may oversell intentionally | 07-01 |
| Denormalized stock_on_hand + stock_movements audit trail | Fast reads from column, reconstructibility from movements | 07-01 |
| RPC idempotency guards on all stock functions | Prevents double-deduction on network retry | 07-01 |
| Package-level pricing on purchase orders | User-requested during 06-02 checkpoint | 06-02 |

---

## v0.1 Initial Release

**Completed:** 2026-03-22
**Duration:** ~1 day

### Stats

| Metric | Value |
|--------|-------|
| Phases | 4 |
| Plans | 16 |

### Key Accomplishments

- Flutter scaffold with Supabase + Drift + Riverpod foundation
- Auth system with role-based routing (owner/admin/driver)
- Product & store CRUD with Arabic RTL support
- Order creation with receipt preview and Bluetooth printing
- Payment collection with credit balance tracking
- Per-product returnable package tracking
- Owner dashboard with KPIs, live driver map (OpenStreetMap)
- Discount approval flow with 3-min auto-reject
- Date range filters, driver performance views
- In-app update check, offline hardening, printer recovery

---
